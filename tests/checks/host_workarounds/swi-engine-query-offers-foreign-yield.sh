#!/bin/sh
# Purpose: answer whether an engine_create/3 engine's query still offers a
#   foreign yield that engine_next/2 cannot take. engine_create/3 opens its
#   query with PL_Q_ALLOW_YIELD so engine_yield/1 works, and '$can_yield', the
#   test library(wasm)'s is_async/0 and its sleep/1 and await/2 rest on, reads
#   only that flag; a foreign yield (PL_yield_address()) from inside the engine
#   then returns PL_S_YIELD to engine_next/2, which handles engine_yield/1's
#   code alone. A C host with a foreign predicate that yields once prints what
#   it saw. Prints `present` when '$can_yield' succeeds inside an engine, when
#   the yield there is not refused with a permission error, or when the process
#   dies there, and `absent` when the engine refuses both.
# Assumes:
#   - HOST_WORKAROUND_SCRATCH names this run's private writable directory, and
#     SWIPL the host interpreter, whose --dump-runtime-variables names the
#     headers and the libswipl the probe is compiled against and runs on
#   - cc on PATH, which the CI image's build-essential provides
# Guarantees:
#   - absent needs both controls to hold: in a query opened with
#     PL_Q_ALLOW_YIELD '$can_yield' succeeds, and the same foreign predicate
#     yields and is resumed; a host where either fails is a broken reproduction
#     (exit 1), so a fix that made '$can_yield' false everywhere cannot pass
#   - the probe's own setup failures exit 2 or 3, a broken reproduction too
# Owns resources: bounded.sh joins the child; the lane removes the scratch
#   files.
set -eu
scratch=${HOST_WORKAROUND_SCRATCH:?}
swipl=${SWIPL:-swipl}
root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
ulimit -c 0

# PLBASE, PLLIBDIR and PLLIB, as the host under test reports them.
eval "$("$swipl" --dump-runtime-variables=sh)"

cat > "$scratch/engine_yield.c" <<'C'
#include <SWI-Prolog.h>
#include <stdio.h>
#include <stdlib.h>

/* Each setup step fails with a status of its own, so a probe that could not
   build the condition is never read as a host that survived it. */
#define REQUIRE(cond, status) \
  do { if ( !(cond) ) { fprintf(stderr, "probe: %s\n", #cond); exit(status); } } while(0)

static int anchor;			/* the address yield_once/0 yields */

/* yield_once/0 yields to whoever opened the query, once, and succeeds when
   it is resumed. */
static foreign_t
yield_once(term_t a0, int arity, void *context)
{ (void)a0; (void)arity;
  if ( PL_foreign_control(context) == PL_FIRST_CALL )
    PL_yield_address(&anchor);
  return TRUE;
}

/* Run Text as a goal in a query opened with Flags; answer the last status
   PL_next_solution() returned, resuming after each foreign yield. */
static int
run(const char *text, int flags, int *yields)
{ fid_t frame;
  term_t goal;
  qid_t qid;
  int rc;

  REQUIRE((frame = PL_open_foreign_frame()), 3);
  REQUIRE((goal = PL_new_term_ref()) && PL_chars_to_term(text, goal), 3);
  REQUIRE((qid = PL_open_query(NULL, flags,
			       PL_predicate("call", 1, "system"), goal)), 3);
  while ( (rc = PL_next_solution(qid)) == PL_S_YIELD )
    (*yields)++;
  PL_close_query(qid);
  PL_discard_foreign_frame(frame);
  fflush(stdout);
  return rc;
}

int
main(int argc, char **argv)
{ char *options[] = {argv[0], "-q", "--no-signals", "--no-packs", NULL};
  int yieldable = PL_Q_NORMAL|PL_Q_ALLOW_YIELD|PL_Q_EXT_STATUS;
  int plain = PL_Q_NORMAL|PL_Q_EXT_STATUS;
  int yields = 0;
  (void)argc;

  REQUIRE(PL_register_foreign("yield_once", 0, yield_once,
			      PL_FA_NONDETERMINISTIC|PL_FA_VARARGS), 2);
  REQUIRE(PL_initialise(4, options), 2);

  /* The two controls: a yieldable query can yield to its opener. */
  run("( '$can_yield' -> writeln('control-can-yield: yes')"
      "              ; writeln('control-can-yield: no') )", yieldable, &yields);
  yields = 0;
  run("yield_once, writeln('control-yield: resumed')", yieldable, &yields);
  printf("control-yields: %d\n", yields);

  /* Inside an engine, whose opener is engine_next/2. */
  run("engine_create(X, ('$can_yield' -> X = yes ; X = no), E),"
      "engine_next(E, A), engine_destroy(E),"
      "format('engine-can-yield: ~w~n', [A])", plain, &yields);
  run("engine_create(X, catch((yield_once, X = resumed),"
      "                       error(Err, _), X = refused(Err)), E),"
      "catch(engine_next(E, A), Outer, A = outer(Outer)),"
      "format('engine-yield: ~q~n', [A])", plain, &yields);

  printf("done\n");
  return 0;
}
C

cc -I"$PLBASE/include" -o "$scratch/engine_yield" "$scratch/engine_yield.c" \
    -L"$PLLIBDIR" -Wl,-rpath,"$PLLIBDIR" $PLLIB

if SWI_HOME_DIR=$PLBASE sh "$root/tools/bounded.sh" "$scratch/engine_yield" \
        > "$scratch/stdout" 2> "$scratch/stderr"; then
    status=0
else
    status=$?
fi
out=$scratch/stdout
if ! grep -qx 'control-can-yield: yes' "$out" ||
   ! grep -qx 'control-yield: resumed' "$out" ||
   ! grep -qx 'control-yields: 1' "$out"; then
    cat "$out" "$scratch/stderr" >&2
    exit 1
fi
case $status in
    0)
        grep -qx done "$out" || { cat "$out" "$scratch/stderr" >&2; exit 1; }
        if grep -qx 'engine-can-yield: no' "$out" &&
           grep -q '^engine-yield: refused(permission_error(yield,' "$out"; then
            printf 'absent\n'
        elif grep -q '^engine-can-yield: \(yes\|no\)$' "$out" &&
             grep -q '^engine-yield: ' "$out"; then
            printf 'present\n'
        else
            cat "$out" "$scratch/stderr" >&2
            exit 1
        fi ;;
    134|139)
        # Died at the yield inside the engine, after the controls held.
        printf 'present\n' ;;
    *) cat "$out" "$scratch/stderr" >&2; exit "$status" ;;
esac
