#!/bin/sh
# Purpose: answer whether destroying an engine suspended inside a tabled
#   leader still skips discarding the leader's component. The engine's frames
#   are discarded, so setup_call_catcher_cleanup/4 hands finished_leader/4 in
#   boot/tabling.pl the catcher `!`, which it reports as
#   tabling(unexpected_result(...)) instead of calling
#   '$tbl_table_discard_all'/1. The component is freed with the engine while
#   a shared table still names the destroyed engine as its owner and points
#   at its worklist. The next claim then either waits on GD->tabling.cvar
#   for an owner that is gone (a claimant with another thread id, as the
#   main engine here) or treats the table as its own and reads the freed
#   worklist (one attached as the dead engine's id). Prints `present` while
#   that happens and `absent` once the next call recomputes the table.
# Assumes:
#   - SWIPL names the interpreter and HOST_WORKAROUND_SCRATCH a fresh
#     directory, as the host-workarounds lane sets them
# Guarantees:
#   - `present` iff the next call crashes the process (exit 134 or 139),
#     never returns within 20 seconds (a known hang, so the probe is bounded
#     rather than left to the lane's own bound), or the host reports the
#     unexpected catcher; `absent` iff the process exits 0, prints
#     `answers [a,b]` and reports nothing; `broken` otherwise
#     [measured 2026-09-24: present on /home/user/Dev/.venv-pypetta/bin/swipl
#     (10.1.14 patched, threaded), where the main engine waits forever and a
#     second engine instead exits 139 in unify_table_status(); present on a
#     single-threaded build of V10.1.14, which prints the message; absent on
#     both builds with
#     tests/checks/host_workarounds/swi-destroyed-leader-keeps-shared-table.patch;
#     commit=WORKTREE]
set -u
probe="$HOST_WORKAROUND_SCRATCH/destroyed_leader.pl"
cat > "$probe" <<'EOF'
:- table p/1 as shared.

p(X) :-
    (   flag(p_yield, 0, 1)
    ->  engine_yield(inside)
    ;   true
    ),
    member(X, [a,b]).

main :-
    engine_create(X, p(X), E),
    engine_next(E, inside),
    engine_destroy(E),
    findall(Y, p(Y), Ys0),
    msort(Ys0, Ys),
    format("answers ~w~n", [Ys]).
EOF
output=$(timeout 20 "$SWIPL" -q -f none -g main -t halt "$probe" < /dev/null 2>&1)
status=$?
case $status in
    124|134|139) echo present; exit 0 ;;
esac
case $output in
    *unexpected_result*) echo present ;;
    "answers [a,b]") if [ $status -eq 0 ]; then echo absent; else echo broken; fi ;;
    *) echo broken ;;
esac
