#!/bin/sh
# Purpose: answer whether the definition SWI-Prolog's abolishProcedure() makes
#   when it removes an import link still differs from the one
#   lookupProcedure() makes, with its share count at 0 and its argument info
#   uninitialised. A C host consults a file that imports system:exists_file/1
#   into user, redefines it there, and has a second module link user's new
#   definition, then calls PL_cleanup(0), which unallocates both procedures.
#   Under valgrind that run reads the argument info uninitialised, and the
#   first unallocation frees the definition the second then reads. Prints
#   `present` when valgrind traces an error to abolishProcedure() and
#   `absent` when the run is clean.
# Assumes:
#   - HOST_WORKAROUND_SCRATCH names this run's private writable directory, and
#     SWIPL the host interpreter, whose --dump-runtime-variables names the
#     headers and the libswipl the host program is compiled against and runs
#     on
#   - cc and valgrind on PATH, which the CI image's build-essential and
#     valgrind packages provide
# Guarantees:
#   - the same program without the import line, whose redefinition makes its
#     definition through lookupProcedure(), must run clean under the same
#     valgrind, or the reproduction is broken rather than answering, so an
#     error valgrind finds elsewhere in SWI is never read as this defect
#   - present needs a valgrind error whose allocation or origin is
#     abolishProcedure(); any other error, or a host program that does not
#     exit 0, is broken
#     [measured 2026-09-24: present 3 runs of 3 on SWI-Prolog 10.1.14 built
#     with the ledger's other patches, absent 3 of 3 with
#     tests/checks/host_workarounds/swi-unlinked-definition-uninitialised.patch
#     added, the control clean on both; commit=79a48d315c7c2178fdf7979497c80d0d2770913e]
# Owns resources: bounded.sh joins each child; the lane removes the scratch files.
set -eu
scratch=${HOST_WORKAROUND_SCRATCH:?}
swipl=${SWIPL:-swipl}
root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
ulimit -c 0
command -v valgrind > /dev/null || { echo "valgrind is not on PATH" >&2; exit 1; }

# PLBASE, PLLIBDIR and PLLIB, as the host under test reports them.
eval "$("$swipl" --dump-runtime-variables=sh)"

cat > "$scratch/cleanup_host.c" <<'C'
#include <SWI-Prolog.h>

int
main(int argc, char **argv)
{ char *options[] = {argv[0], "-q", "--no-signals", "--no-packs", NULL};
  fid_t frame;
  term_t file;

  if ( argc != 2 || !PL_initialise(4, options) )
    return 2;
  frame = PL_open_foreign_frame();
  file = PL_new_term_ref();
  if ( !PL_put_atom_chars(file, argv[1]) ||
       !PL_call_predicate(NULL, PL_Q_NORMAL,
			  PL_predicate("consult", 1, "user"), file) )
    return 3;
  if ( !PL_call_predicate(NULL, PL_Q_NORMAL,
			  PL_predicate("probe", 0, "user"), 0) )
    return 4;
  PL_discard_foreign_frame(frame);
  return PL_cleanup(0) == PL_CLEANUP_SUCCESS ? 0 : 5;
}
C

# The import makes user's exists_file/1 a link to system's, so the redefinition
# goes through abolishProcedure()'s link branch; probe_m inherits from user, so
# its call links user's new definition, the second reference.
cat > "$scratch/linked.pl" <<'PL'
:- import(system:exists_file/1).
:- redefine_system_predicate(exists_file(_)).
exists_file(_).
probe :- probe_m:exists_file(x).
PL
grep -v '^:- import' "$scratch/linked.pl" > "$scratch/control.pl"

cc -I"$PLBASE/include" -o "$scratch/cleanup_host" "$scratch/cleanup_host.c" \
    -L"$PLLIBDIR" -Wl,-rpath,"$PLLIBDIR" $PLLIB

# Runs one program under valgrind and prints its error count; a host program
# that does not exit 0 is a broken reproduction. Origins are tracked so an
# uninitialised read names the allocation it came from.
errors() {
    if DEBUGINFOD_URLS= SWI_HOME_DIR=$PLBASE sh "$root/tools/bounded.sh" \
            valgrind --track-origins=yes --log-file="$scratch/$1.valgrind" \
            "$scratch/cleanup_host" "$scratch/$1.pl" > "$scratch/$1.out" 2>&1; then
        sed -n 's/^==[0-9]*== ERROR SUMMARY: \([0-9]*\) errors.*/\1/p' "$scratch/$1.valgrind"
    else
        status=$?
        cat "$scratch/$1.out" >&2
        exit "$status"
    fi
}

control=$(errors control)
if [ "$control" != 0 ]; then
    printf 'the control reported %s valgrind errors:\n' "${control:-no}" >&2
    cat "$scratch/control.valgrind" >&2
    exit 1
fi
linked=$(errors linked)
case $linked in
    0) printf 'absent\n' ;;
    '') cat "$scratch/linked.valgrind" >&2; exit 1 ;;
    *)
        if grep -q 'abolishProcedure' "$scratch/linked.valgrind"; then
            printf 'present\n'
        else
            cat "$scratch/linked.valgrind" >&2
            exit 1
        fi ;;
esac
