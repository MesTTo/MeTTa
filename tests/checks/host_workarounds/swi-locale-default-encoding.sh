#!/bin/sh
# Purpose: answer whether this SWI-Prolog still derives its default source
#   encoding from the locale: a boot under LC_ALL=C reading a UTF-8 file
#   answers something other than the file's characters. Prints `present`
#   while it does and `absent` once the host reads UTF-8 whatever the locale.
# Assumes:
#   - HOST_WORKAROUND_SCRATCH names a writable directory of this run's own
#   - SWIPL names the interpreter, or `swipl` is on PATH
# Guarantees:
#   - `present` iff an atom written as U+2705 reads back under LC_ALL=C as any
#     other code sequence [measured 2026-09-10: three U+FFFD; command=sh
#     check.sh host-workarounds; fixture=SWI-Prolog 10.1.13; commit=WORKTREE]
# Open Obligations:
#   To Do: None
#   Hacks: None
#   Future Enhancements: None
set -eu
scratch=${HOST_WORKAROUND_SCRATCH:?}
swipl=${SWIPL:-swipl}
printf "mark('✅').\n" > "$scratch/mark.pl"
cat > "$scratch/read.pl" <<'PL'
main :-
    consult(mark),
    mark(Atom),
    atom_codes(Atom, Codes),
    (   Codes == [0x2705]
    ->  write(absent)
    ;   write(present)
    ),
    nl.
PL
cd "$scratch"
LC_ALL=C LANG=C LANGUAGE= "$swipl" -q -f none -s read.pl -g main -t halt 2>/dev/null
