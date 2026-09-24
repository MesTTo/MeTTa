#!/bin/sh
# Purpose: answer whether a claim on a shared table still waits for an owner
#   suspended beneath the claimant on the same OS thread. Engine 1 completes
#   p/1 (`table p/1 as shared`), and p/1's first clause asks for the same
#   variant from a second engine that engine 1 holds in engine_next/2. The
#   second engine's claim_answer_table() in src/pl-tabling.c finds engine 1
#   owning the table and waits on GD->tabling.cvar. Engine 1 runs again only
#   once the second engine returns, and is_deadlock() sees no cycle because
#   engine 1 waits for no table, so the wait never ends. Prints `present`
#   while that happens and `absent` once the claim raises
#   permission_error(wait, shared_table, user:p(_)).
# Assumes:
#   - SWIPL names the interpreter and HOST_WORKAROUND_SCRATCH a fresh
#     directory, as the host-workarounds lane sets them
# Guarantees:
#   - `present` iff the program does not finish within 20 seconds (a known
#     hang, so the probe is bounded rather than left to the lane's own
#     bound); `absent` iff it exits 0 and prints the permission error for
#     user:p(_) whose context names the owner as suspended beneath this
#     call; `broken` otherwise. A host without threads answers `broken`: its
#     engines share no table without
#     swi-threadless-shared-table-private-per-engine.patch, and refuse
#     through tabling_wait/2 with it
#     [measured 2026-09-24: present on /home/user/Dev/.venv-pypetta/bin/swipl
#     (10.1.14 patched, threaded); absent on a threaded build of V10.1.14
#     with every patch of the ledger and
#     tests/checks/host_workarounds/swi-shared-table-waits-for-owner-beneath.patch,
#     broken on the single-threaded build of the same tree; commit=WORKTREE]
set -u
probe="$HOST_WORKAROUND_SCRATCH/owner_beneath.pl"
cat > "$probe" <<'EOF'
:- table p/1 as shared.

p(X) :-
    engine_create(Y, p(Y), Engine),
    call_cleanup(engine_next(Engine, X), engine_destroy(Engine)).
p(1).

main :-
    (   current_prolog_flag(threads, true)
    ->  engine_create(Xs, findall(X, p(X), Xs), Engine),
        catch(( engine_next(Engine, Xs0), Outcome = answers(Xs0) ),
              Error,
              Outcome = Error),
        engine_destroy(Engine)
    ;   Outcome = threadless
    ),
    report(Outcome).

report(error(permission_error(wait, shared_table, Variant), context(_, Why))) :-
    sub_string(Why, _, _, _, "suspended beneath this call"),
    !,
    \+ \+ ( numbervars(Variant, 0, _),
            format("refused ~q beneath~n", [Variant]) ).
report(Outcome) :-
    \+ \+ ( numbervars(Outcome, 0, _),
            format("~q~n", [Outcome]) ).
EOF
output=$(timeout 20 "$SWIPL" -q -f none -g main -t halt "$probe" < /dev/null 2>&1)
status=$?
if [ $status -eq 124 ]; then
    echo present
elif [ $status -eq 0 ] && [ "$output" = "refused user:p(A) beneath" ]; then
    echo absent
else
    echo broken
fi
