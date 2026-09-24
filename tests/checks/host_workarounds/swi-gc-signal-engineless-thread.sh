#!/bin/sh
# Purpose: answer whether SWI-Prolog's signalGCThread() still reads the calling
#   thread's Prolog flags when that thread has no engine. A C host records
#   twice the atom-GC margin of fresh atoms and erases every record on a plain
#   pthread; erasing unregisters the atoms, and the unregister that crosses the
#   margin asks for atom GC from that thread. Prints `present` when it dies of
#   SIGSEGV there and `absent` when every record is erased and PL_cleanup()
#   succeeds.
# Assumes:
#   - HOST_WORKAROUND_SCRATCH names this run's private writable directory, and
#     SWIPL the host interpreter, whose --dump-runtime-variables names the
#     headers and the libswipl the probe is compiled against and runs on
#   - cc on PATH, which the CI image's build-essential provides
# Guarantees:
#   - exit 139 answers present and a clean exit that printed the erase count
#     answers absent; any other result is a broken reproduction, including an
#     erasing thread that has an engine, which the probe refuses with exit 3,
#     so the condition cannot pass unexercised
#     [measured 2026-09-24: present 3 runs of 3 on SWI-Prolog 10.1.14 built
#     with the ledger's other patches, absent 3 of 3 with
#     tests/checks/host_workarounds/swi-gc-signal-engineless-thread.patch
#     added; commit=79a48d315c7c2178fdf7979497c80d0d2770913e]
# Owns resources: bounded.sh joins the child; the lane removes the scratch files.
set -eu
scratch=${HOST_WORKAROUND_SCRATCH:?}
swipl=${SWIPL:-swipl}
root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
ulimit -c 0

# PLBASE, PLLIBDIR and PLLIB, as the host under test reports them.
eval "$("$swipl" --dump-runtime-variables=sh)"

cat > "$scratch/engineless_erase.c" <<'C'
#include <SWI-Prolog.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

/* Each setup step fails with a status of its own, so a probe that could not
   build the condition is never read as a host that survived it. */
#define REQUIRE(cond, status) \
  do { if ( !(cond) ) { fprintf(stderr, "probe: %s\n", #cond); exit(status); } } while(0)

static record_t *records;
static size_t count;

static void *
erase_all(void *unused)
{ (void)unused;
  REQUIRE(PL_thread_self() < 0, 3);	/* the point: no engine here */
  for(size_t i = 0; i < count; i++)
    PL_erase(records[i]);
  return NULL;
}

int
main(int argc, char **argv)
{ char *options[] = {argv[0], "-q", "--no-signals", "--no-packs", NULL};
  atom_t flag;
  int64_t margin = 0;
  pthread_t thread;
  (void)argc;

  REQUIRE(PL_initialise(4, options), 2);
  flag = PL_new_atom("agc_margin");
  REQUIRE(PL_current_prolog_flag(flag, PL_INTEGER, &margin) && margin > 0, 2);
  PL_unregister_atom(flag);
  count = 2 * (size_t)margin;		/* the crossing lands on the eraser */
  REQUIRE((records = malloc(count * sizeof *records)), 2);
  { fid_t frame = PL_open_foreign_frame();
    term_t t = PL_new_term_ref();
    char name[48];

    for(size_t i = 0; i < count; i++)
    { snprintf(name, sizeof name, "engineless-erase-%zu", i);
      REQUIRE(PL_put_atom_chars(t, name) && (records[i] = PL_record(t)), 2);
    }
    PL_discard_foreign_frame(frame);
  }
  REQUIRE(pthread_create(&thread, NULL, erase_all, NULL) == 0, 2);
  REQUIRE(pthread_join(thread, NULL) == 0, 2);
  free(records);
  REQUIRE(PL_cleanup(0) == PL_CLEANUP_SUCCESS, 4);
  printf("erased %zu records on a thread with no engine\n", count);
  return 0;
}
C

cc -I"$PLBASE/include" -pthread -o "$scratch/engineless_erase" "$scratch/engineless_erase.c" \
    -L"$PLLIBDIR" -Wl,-rpath,"$PLLIBDIR" $PLLIB

if SWI_HOME_DIR=$PLBASE sh "$root/tools/bounded.sh" "$scratch/engineless_erase" \
        > "$scratch/stdout" 2> "$scratch/stderr"; then
    status=0
else
    status=$?
fi
case $status in
    0)
        if grep -q '^erased [0-9]* records on a thread with no engine$' "$scratch/stdout"; then
            printf 'absent\n'
        else
            cat "$scratch/stdout" "$scratch/stderr" >&2
            exit 1
        fi ;;
    139) printf 'present\n' ;;
    *) cat "$scratch/stderr" >&2; exit "$status" ;;
esac
