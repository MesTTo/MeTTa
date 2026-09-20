#!/bin/sh
# Purpose: detect that SWI holds a channel's event-list lock across the
#   callbacks it delivers, so a callback that waits for a mutex another thread
#   holds while that thread registers on the same channel never returns.
# Assumes: HOST_WORKAROUND_SCRATCH is this run's private writable directory;
#   SWIPL names the interpreter, or swipl is on PATH.
# Guarantees: a control whose worker registers after releasing the mutex joins
#   before the cycle is tried; a contained deadlock answers present, a joined
#   worker absent [tested: sh tools/check.sh host-workarounds host-workarounds-selftest;
#   commit=5837e2077cf16be3f8223b4ab8b1a2c86c6f076f].
# Owns resources: the private child processes hold their own listener, mutex
#   and queue; bounded.sh links children to their owner and its selected
#   timeout contains the known deadlocking child.
# Decides: ten seconds contains only the known deadlocking cycle; an error or
#   a failure before the callback announces its arrival is not present.
set -eu
scratch=${HOST_WORKAROUND_SCRATCH:?}
swipl=${SWIPL:-swipl}
root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
enforcer=$(sh "$root/tools/bounded.sh" --enforcer)
cat > "$scratch/cycle.pl" <<'PL'
:- dynamic watched/1.
% The callback runs with the watched/1 channel's list lock held. It tells the
% worker to register, then waits for the mutex the worker holds.
inside(_Action, _Context) :-
    writeln('callback-entered'), flush_output,
    thread_send_message(worker_queue, register),
    with_mutex(shared, true),
    writeln('callback-left'), flush_output.
main :-
    current_prolog_flag(argv, [Variant]),
    message_queue_create(_, [alias(worker_queue)]),
    prolog_listen(watched/1, inside),
    thread_create(worker(Variant), Worker, []),
    thread_get_message(holding),
    assertz(watched(1)),
    thread_join(Worker, true),
    writeln(joined).
% cycle: register on the channel while holding the mutex the callback waits
% for. control: the same registration with the mutex released first.
worker(cycle) :-
    with_mutex(shared, ( thread_send_message(main, holding),
                         thread_get_message(worker_queue, register),
                         prolog_listen(watched/1, inside) )).
worker(control) :-
    with_mutex(shared, thread_send_message(main, holding)),
    thread_get_message(worker_queue, register),
    prolog_listen(watched/1, inside).
PL
"$swipl" -q -f none -s "$scratch/cycle.pl" -g main -t halt -- control > "$scratch/control.log" 2>&1
grep -qx joined "$scratch/control.log"
status=0
# The enforcer's default status distinguishes expiry (124) from a child's
# unrelated signal. bounded.sh itself preserves the child's signal status.
# https://github.com/coreutils/coreutils/blob/v9.7/src/timeout.c
sh "$root/tools/bounded.sh" --ceiling 0 "$enforcer" -k 1 10 "$swipl" -q -f none \
    -s "$scratch/cycle.pl" -g main -t halt -- cycle \
    > "$scratch/cycle.log" 2>&1 || status=$?
case "$status" in
    0)
        grep -qx joined "$scratch/cycle.log"
        printf 'absent\n'
        ;;
    124)
        grep -qx callback-entered "$scratch/cycle.log"
        printf 'present\n'
        ;;
    *)
        cat "$scratch/cycle.log" >&2
        exit "$status"
        ;;
esac
