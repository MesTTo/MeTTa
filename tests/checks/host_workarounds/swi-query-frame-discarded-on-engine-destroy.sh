#!/bin/sh
# Purpose: reproduce an unsafe frame-finished notification during engine destruction.
# Assumes: HOST_WORKAROUND_SCRATCH names this run's private writable directory;
#   SWIPL names the host interpreter. No repository engine source is loaded.
# Guarantees: the host's PL_open_query assertion or its subsequent segfault
#   answers present, a normal exit answers absent, and every other failure
#   remains an error [tested: sh check.sh host-workarounds; commit=5a1127efe0f575668061e8a24c59b8ab60e6122a].
# Owns resources: bounded.sh joins the child; the lane removes the scratch files.
# [measured 2026-09-17: present on SWI-Prolog 10.1.13 and 10.1.14 as shipped,
#  absent on 10.1.14 built with
#  tests/checks/host_workarounds/swi-query-frame-discarded-on-engine-destroy.patch,
#  three runs of three; command=sh check.sh host-workarounds;
#  fixture=SWI-Prolog 10.1.14 with the patch; commit=WORKTREE]
set -eu
scratch=${HOST_WORKAROUND_SCRATCH:?}
swipl=${SWIPL:-swipl}
root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
ulimit -c 0

# Freeze the unsafe walk here. Calling a repaired engine helper would make
# the host appear fixed when only its consumer had stopped triggering it.
cat > "$scratch/frame.pl" <<'PL'
watch(Frame, Prior, Outer) :-
    prolog_frame_attribute(Frame, predicate_indicator, Predicate),
    ( memberchk(Predicate, [system:'$transaction'/2, system:'$transaction'/3,
                           system:'$snapshot'/1]) -> Found = Frame ; Found = Prior ),
    ( prolog_frame_attribute(Frame, parent, Parent)
    -> watch(Parent, Found, Outer)
    ; Outer = Found ).
scope :-
    prolog_current_frame(Frame),
    watch(Frame, none, Outer),
    nb_setval('$frame_probe', Outer).
finished(Frame) :-
    ( nb_current('$frame_probe', Frame) -> nb_delete('$frame_probe') ; true ).
main :-
    prolog_listen(frame_finished, finished),
    engine_create(ready, (transaction(scope), engine_yield(ready)), Engine),
    engine_next(Engine, ready),
    engine_destroy(Engine).
PL

if sh "$root/bounded.sh" "$swipl" -q -f none -s "$scratch/frame.pl" -g main -t halt \
        > "$scratch/stdout" 2> "$scratch/stderr"; then
    status=0
else
    status=$?
fi
case $status in
    0) printf 'absent\n' ;;
    139) printf 'present\n' ;;
    134)
        if grep -Fq 'PL_open_query: Assertion failed: (void*)fli_context > (void*)environment_frame' "$scratch/stderr"; then
            printf 'present\n'
        else
            cat "$scratch/stderr" >&2
            exit "$status"
        fi ;;
    *) cat "$scratch/stderr" >&2; exit "$status" ;;
esac
