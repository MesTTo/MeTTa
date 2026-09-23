#!/bin/sh
# Purpose: answer whether library(unicode)'s unicode_map/3 still treats an
#   empty result as an error: utf8proc_map() answers 0 when every code point
#   is removed, which unicode4pl.c's unicode_map() sends to assert(0), so a
#   build with assertions aborts the process and one without fails the call.
#   Prints `present` while mapping a lone soft hyphen with ignore does either,
#   and `absent` once it answers the empty atom.
# Assumes: SWIPL names the interpreter the host-workarounds lane runs, as it
#   does for every reproduction, or swipl on PATH.
# Guarantees:
#   - `present` iff a non-empty control maps while the empty result does not;
#     `broken` when the control fails too, so a host without library(unicode)
#     reads as neither answer. The mapping runs in a child process, because
#     the defect ends the process that meets it
#     [measured 2026-09-24: the native host aborted with unicode4pl.c:464
#     unicode_map: Assertion `0' failed; commit=WORKTREE]
set -u
swipl=${SWIPL:-swipl}
map() {
    "$swipl" -q -f none -g "use_module(library(unicode)),
        string_codes(S, [$1]), unicode_map(S, R, [ignore]),
        atom_codes(R, C), format('~w~n', [C])" -t halt </dev/null 2>/dev/null
}
control=$(map "0'a, 0xAD, 0'b")
if [ "$control" != "[97,98]" ]; then
    echo broken
    exit 0
fi
empty=$(map "0xAD") && [ "$empty" = "[]" ] && echo absent || echo present
