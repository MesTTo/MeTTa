#!/bin/sh
# Purpose: detect the event-list lock retained by named listener replacement.
# Assumes: HOST_WORKAROUND_SCRATCH is this run's private writable directory;
#   SWIPL names the interpreter, or swipl is on PATH.
# Guarantees: the single-registration control completes before replacement
#   is tested; a contained deadlock answers present, a joined worker absent
#   [tested: sh check.sh host-workarounds host-workarounds-selftest;
#   commit=WORKTREE].
# Owns resources: the private child processes hold their own event handlers;
#   bounded.sh links children to their owner; its selected timeout contains
#   the known deadlocking replacement process and its worker.
# Decides: ten seconds contains only the known deadlocking replacement child;
#   an error or failure before the worker announces its arrival is not present.
set -eu
scratch=${HOST_WORKAROUND_SCRATCH:?}
swipl=${SWIPL:-swipl}
root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
enforcer=$(sh "$root/bounded.sh" --enforcer)
cat > "$scratch/listener.pl" <<'PL'
event.
main :-
    current_prolog_flag(argv, [Variant]),
    prolog_listen(abort, event, [name(host_workaround_listener)]),
    (   Variant == replace
    ->  prolog_listen(abort, event, [name(host_workaround_listener)])
    ;   true
    ),
    thread_create((thread_send_message(main, started),
                   prolog_unlisten(abort, event)), Worker, []),
    thread_get_message(started),
    writeln('waiter-started'), flush_output,
    thread_join(Worker, true),
    writeln(joined).
PL
"$swipl" -q -f none -s "$scratch/listener.pl" -g main -t halt -- once > "$scratch/control.log" 2>&1
grep -qx joined "$scratch/control.log"
status=0
# The enforcer's default status distinguishes expiry (124) from a child's
# unrelated signal. bounded.sh itself preserves the child's signal status.
# https://github.com/coreutils/coreutils/blob/v9.7/src/timeout.c
sh "$root/bounded.sh" --ceiling 0 "$enforcer" -k 1 10 "$swipl" -q -f none \
    -s "$scratch/listener.pl" -g main -t halt -- replace \
    > "$scratch/replacement.log" 2>&1 || status=$?
case "$status" in
    0)
        grep -qx joined "$scratch/replacement.log"
        printf 'absent\n'
        ;;
    124)
        grep -qx waiter-started "$scratch/replacement.log"
        printf 'present\n'
        ;;
    *)
        cat "$scratch/replacement.log" >&2
        exit "$status"
        ;;
esac
