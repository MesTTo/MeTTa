#!/bin/sh
# Purpose: reproduce thread_join/2 handing glibc the pthread_t that
#   detach_engine zeroed while the joined thread was inside engine_destroy/1.
# Assumes: HOST_WORKAROUND_SCRATCH names this run's private writable directory;
#   SWIPL names the host interpreter. No repository engine source is loaded.
# Guarantees: a segfault of the joining process answers present, a clean join
#   answers absent, and every other failure remains an error
#   [tested: sh tools/check.sh host-workarounds; commit=32335687084e4d8ad43cf8800f2dedce707fa137].
# Owns resources: bounded.sh joins the child; the lane removes the scratch files.
# [measured 2026-09-18: present on SWI-Prolog 10.1.14 built with the ledger's
#  earlier patches, absent on the same tree built with
#  tests/checks/host_workarounds/swi-thread-join-detach-window.patch;
#  command=sh tools/check.sh host-workarounds;
#  fixture=SWI-Prolog 10.1.14 with the patch; commit=32335687084e4d8ad43cf8800f2dedce707fa137]
set -eu
scratch=${HOST_WORKAROUND_SCRATCH:?}
swipl=${SWIPL:-swipl}
root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
ulimit -c 0

# Freeze the parking shape here (tests/prolog/probes/engine_join_window.pl,
# destroy mode): a worker parked inside engine_destroy/1, whose pending
# cleanup runs between PL_set_engine's detach and re-attach of the worker's
# own engine, joined from the main thread by plain thread_join/2. A detached
# sleeper releases the worker, so a join that does not crash terminates.
cat > "$scratch/join.pl" <<'PL'
park :-
    thread_send_message(parked, now),
    thread_get_message(release, go).
worker :-
    engine_create(x, setup_call_cleanup(true, member(_, [a,b]), park), E),
    engine_next(E, _),
    thread_send_message(ready, now),
    engine_destroy(E).
main :-
    message_queue_create(_, [alias(parked)]),
    message_queue_create(_, [alias(ready)]),
    message_queue_create(_, [alias(release)]),
    thread_create(worker, Worker, []),
    thread_get_message(ready, now),
    thread_get_message(parked, now),
    thread_create(( sleep(2), thread_send_message(release, go) ), _,
                  [detached(true)]),
    thread_join(Worker, Status),
    Status == true.
PL

if sh "$root/bounded.sh" "$swipl" -q -f none -s "$scratch/join.pl" -g main -t halt \
        > "$scratch/stdout" 2> "$scratch/stderr"; then
    status=0
else
    status=$?
fi
case $status in
    0) printf 'absent\n' ;;
    139) printf 'present\n' ;;
    *) cat "$scratch/stderr" >&2; exit "$status" ;;
esac
