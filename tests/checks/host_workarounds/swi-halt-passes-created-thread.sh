#!/bin/sh
# Purpose: answer whether SWI-Prolog's halt still passes over a thread that
#   thread_create/3 has marked PL_THREAD_CREATED and start_thread() has not
#   yet marked RUNNING. A C host creates eight detached threads running `true`
#   and calls PL_cleanup(0) at once, twenty times. Prints `present` when any
#   run dies, of SIGSEGV where cleanup frees the module tables a starting
#   thread is looking its goal up in, or of SIGABRT at one of SWI's own
#   assertions, and `absent` when all twenty halt cleanly.
# Assumes:
#   - HOST_WORKAROUND_SCRATCH names this run's private writable directory, and
#     SWIPL the host interpreter, whose --dump-runtime-variables names the
#     headers and the libswipl the probe is compiled against and runs on
#   - cc on PATH, which the CI image's build-essential provides
# Guarantees:
#   - exit 139 or 134 in any run answers present and twenty clean exits that
#     each printed the thread count answer absent; the probe's own setup
#     failures exit 2 to 4, which are a broken reproduction, so the condition
#     cannot pass unexercised
#     [measured 2026-09-24: the C seat's make runtime-halt-created-thread, the
#     same program, died 16 runs of 20 on SWI-Prolog 10.1.14 built with the
#     ledger's other patches (extensions/cmetta 697eff4)]
# Owns resources: bounded.sh joins each child; the lane removes the scratch
#   files.
set -eu
scratch=${HOST_WORKAROUND_SCRATCH:?}
swipl=${SWIPL:-swipl}
root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
ulimit -c 0

# PLBASE, PLLIBDIR and PLLIB, as the host under test reports them.
eval "$("$swipl" --dump-runtime-variables=sh)"

cat > "$scratch/halt_created.c" <<'C'
#include <SWI-Prolog.h>
#include <stdio.h>
#include <stdlib.h>

/* Each setup step fails with a status of its own, so a probe that could not
   build the condition is never read as a host that survived it. */
#define REQUIRE(cond, status) \
  do { if ( !(cond) ) { fprintf(stderr, "probe: %s\n", #cond); exit(status); } } while(0)

/* Few threads, so the last ones are still being created when cleanup starts. */
enum { THREADS = 8 };

int
main(int argc, char **argv)
{ char *options[] = {argv[0], "-q", "--no-signals", "--no-packs", NULL};
  char text[128];
  fid_t frame;
  term_t goal;
  (void)argc;

  REQUIRE(PL_initialise(4, options), 2);
  REQUIRE((frame = PL_open_foreign_frame()), 3);
  REQUIRE((goal = PL_new_term_ref()), 3);
  snprintf(text, sizeof text,
           "forall(between(1, %d, _), thread_create(true, _, [detached(true)]))",
           THREADS);
  REQUIRE(PL_chars_to_term(text, goal) && PL_call(goal, NULL), 3);
  PL_discard_foreign_frame(frame);
  REQUIRE(PL_cleanup(0) == PL_CLEANUP_SUCCESS, 4);
  printf("halted past %d threads just created\n", THREADS);
  return 0;
}
C

cc -I"$PLBASE/include" -pthread -o "$scratch/halt_created" "$scratch/halt_created.c" \
    -L"$PLLIBDIR" -Wl,-rpath,"$PLLIBDIR" $PLLIB

run=1
while [ "$run" -le 20 ]; do
    if SWI_HOME_DIR=$PLBASE sh "$root/tools/bounded.sh" "$scratch/halt_created" \
            > "$scratch/stdout" 2> "$scratch/stderr"; then
        status=0
    else
        status=$?
    fi
    case $status in
        0)
            if ! grep -q '^halted past [0-9]* threads just created$' "$scratch/stdout"; then
                cat "$scratch/stdout" "$scratch/stderr" >&2
                exit 1
            fi ;;
        134|139) printf 'present\n'; exit 0 ;;
        *) cat "$scratch/stderr" >&2; exit "$status" ;;
    esac
    run=$((run + 1))
done
printf 'absent\n'
