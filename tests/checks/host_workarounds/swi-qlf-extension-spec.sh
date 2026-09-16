#!/bin/sh
# Purpose: answer whether this SWI-Prolog still compiles from source for a
#   load_files/2 spec that names its .pl extension under qcompile(auto), with
#   only a bare stem reaching the artifact rule. Prints `present` while it
#   does and `absent` once an extension-bearing spec writes an artifact too.
# Assumes:
#   - HOST_WORKAROUND_SCRATCH names a writable directory of this run's own
#   - SWIPL names the interpreter, or `swipl` is on PATH
# Guarantees:
#   - `present` iff loading `'one.pl'` leaves no one.qlf while loading `two`
#     writes two.qlf; a stem that writes nothing prints neither word, which
#     the lane reports as a broken reproduction [measured 2026-09-10: source,
#     artifact; command=sh check.sh host-workarounds; fixture=SWI-Prolog
#     10.1.13; commit=2bd6b250a22d9898ced449595c168a8dc3a78768]
# Open Obligations:
#   To Do: None
#   Hacks: None
#   Future Enhancements: None
# [measured 2026-09-17: present on SWI-Prolog 10.1.13 and 10.1.14 as shipped,
#  absent on 10.1.14 built with tests/checks/host_workarounds/swi-qlf-extension-spec.patch;
#  command=sh check.sh host-workarounds;
#  fixture=SWI-Prolog 10.1.14 with the patch; commit=b045ab60c186e14b700fd689c3195b196b7778ec]
set -eu
scratch=${HOST_WORKAROUND_SCRATCH:?}
swipl=${SWIPL:-swipl}
printf 'one(1).\n' > "$scratch/one.pl"
printf 'two(2).\n' > "$scratch/two.pl"
cat > "$scratch/load.pl" <<'PL'
main :-
    load_files('one.pl', [qcompile(auto)]),
    load_files(two, [qcompile(auto)]),
    (   exists_file('one.qlf') -> ByExtension = artifact ; ByExtension = source ),
    (   exists_file('two.qlf') -> ByStem = artifact ; ByStem = source ),
    (   ByStem == source
    ->  format("undecided: a stem wrote no artifact~n")
    ;   ByExtension == source
    ->  write(present), nl
    ;   write(absent), nl
    ).
PL
cd "$scratch"
"$swipl" -q -f none -s load.pl -g main -t halt
