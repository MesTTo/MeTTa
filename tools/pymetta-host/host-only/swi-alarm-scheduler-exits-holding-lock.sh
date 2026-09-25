#!/bin/sh
# Purpose: answer whether library(time)'s alarm scheduler thread still returns
#   holding its mutex, the defect swi-alarm-scheduler-exits-holding-lock.patch
#   beside this file fixes. alarm_loop() in packages/clib/time.c takes the
#   mutex when it starts and leaves its loop when it sees the schedule's stop
#   flag; cleanup(), the library's halt hook, sets that flag, signals the
#   scheduler once per pending alarm it removes, and then takes the mutex
#   itself, so a scheduler that woke in between has left with the mutex and
#   halt waits for ever. Each of twenty processes installs a thousand alarms
#   due in a thousand seconds, all pending when it halts, which gives the
#   scheduler a thousand chances to wake between two removals. Prints
#   `present` when a process does not exit within its ceiling, and `absent`
#   when all twenty do.
# Assumes:
#   - HOST_WORKAROUND_SCRATCH names this run's private writable directory, and
#     SWIPL a native host interpreter built with threads, where library(time)
#     exists; the WebAssembly build compiles no time plugin
#     [source 2026-09-25T13:56:25+10:00: packages/clib/CMakeLists.txt:66-72
#     at clib a69cf00dcf0d, the commit tools/pymetta-host/swipl.pin's tag
#     checks out]
# Guarantees:
#   - `absent` needs every process to exit 0 having printed `armed`, so a host
#     that cannot run the program is a broken reproduction, never an absence;
#     a process the ceiling ends answers `present`
#     [measured 2026-09-25T13:56:25+10:00: present 3 of 3 on the stock
#     SWI-Prolog 10.1.14 (compiled Aug 30 2026, 09:21:19), its first process
#     hanging each time, where gdb finds the one thread left in PL_halt(),
#     PL_cleanup() and time.so's pthread_mutex_lock(), the scheduler thread
#     gone; absent 3 of 3 on 10.1.14 threaded with every ledger patch and
#     this one (compiled Sep 25 2026, 12:27:40), twenty processes in under a
#     second]
# Owns resources: bounded.sh joins each child and ends one that does not exit;
#   the lane removes the scratch files.
set -eu
scratch=${HOST_WORKAROUND_SCRATCH:?}
swipl=${SWIPL:-swipl}
root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
ulimit -c 0

run=1
while [ "$run" -le 20 ]; do
    if sh "$root/tools/bounded.sh" --ceiling 20 --grace 2 \
            "$swipl" -q -f none -g "use_module(library(time)), forall(between(1, 1000, _), alarm(1000, true, _)), writeln(armed)" \
            -t halt < /dev/null > "$scratch/stdout" 2> "$scratch/stderr"; then
        status=0
    else
        status=$?
    fi
    case $status in
        0)
            grep -qx armed "$scratch/stdout" || { cat "$scratch/stdout" "$scratch/stderr" >&2; exit 1; } ;;
        124|137|143) printf 'present\n'; exit 0 ;;
        *) cat "$scratch/stderr" >&2; exit "$status" ;;
    esac
    run=$((run + 1))
done
printf 'absent\n'
