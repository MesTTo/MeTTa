#!/bin/sh
# Purpose: run a list of Prolog test suites concurrently through a bounded,
#   PID-managed queue, replay each suite's output in the order it was given,
#   and exit nonzero when any suite failed.
#
#   Usage: printf '%s\n' SUITE... | sh tools/suitequeue.sh 'COMMAND using "$1"'
#
#   COMMAND is a shell command run once per suite with the suite path as "$1".
#   That command is the only thing the two callers disagree about:
#
#     engine/test.sh   swipl -s lock_order.pl -g '...run_tests' -t halt "$1" -- extensions
#     engine/check.sh  swipl -q -g dev_typed_suites -t 'halt(0)' dev_typed.pl -- "$1"
#
#   Both ran the same serial loop before this file existed, which is one
#   concept wearing two names: the dispatch, the per-suite capture, the ordered
#   replay and the status aggregation were identical and only the command
#   differed. Copying the queue into the second caller would have written the
#   cross-product; taking the command as a parameter writes it once. Passing it
#   as a BODY rather than as argument words is what keeps `-g "a, b"` intact,
#   since re-splitting a word list through eval breaks exactly that argument.
#
# Assumes:
#   - the caller has chosen the working directory the suite paths resolve
#     against, HERE names the repository root, and no suite path contains a
#     newline, which is what makes one-per-line input unambiguous.
# Guarantees:
#   - output is byte-identical to running the suites one after another, timings
#     aside: each suite writes its own file and the files are concatenated in
#     the order the suites arrived.
#   - a suite that fails sets the exit status to 1 whatever else passed. The
#     failure travels as a FILE rather than a variable, because a subshell
#     cannot assign to its parent: the assignment would succeed, vanish, and
#     leave a red suite reporting green.
#   - an interrupted run stops, kills the queue and releases its scratch.
# Owns resources:
#   - one temporary directory holding the queue and one output file per suite,
#     removed on every exit path including a signal.
# Fails when:
#   - no command is given, or it is empty.
set -u

SUITE_BODY=${1:-}
[ -n "$SUITE_BODY" ] || { echo "suitequeue: a command is required" >&2; exit 2; }

slots=$(nproc 2>/dev/null || echo 4)
parts=$(mktemp -d)
queue_pid=
# SIGTERM to the `bounded` wrapper rather than SIGKILL to xargs: bounded.sh's
# outer rung is a GNU timeout whose SIGTERM handler passes the signal to the
# whole process group and escalates after the grace, which is what reaches the
# suites [tools/bounded.sh:376-386].
stop_queue() {
    [ -n "${queue_pid:-}" ] && kill -TERM "$queue_pid" 2>/dev/null
    :
}
cleanup() { stop_queue; rm -rf "$parts" 2>/dev/null; }
# A trapped signal CLEANS AND RE-RAISES rather than returning: a POSIX trap
# that does not exit resumes the script where it was interrupted. The form is
# the one mbedtls ships in framework/scripts/demo_common.sh, and the reason is
# the caller -- a script that exits 130 looks like it chose to, where one that
# dies by SIGINT tells its own caller to stop looping too.
# http://mywiki.wooledge.org/SignalTrap#Special_Note_On_SIGINT
trap 'cleanup' EXIT
trap 'cleanup; trap - HUP;  kill -HUP  $$' HUP
trap 'cleanup; trap - INT;  kill -INT  $$' INT
trap 'cleanup; trap - TERM; kill -TERM $$' TERM

# Number the suites as they arrive so the replay can restore their order.
ran=0
: >"$parts/queue"
while IFS= read -r suite; do
    [ -n "$suite" ] || continue
    ran=$((ran + 1))
    printf '%s\0%s\0' "$ran" "$suite" >>"$parts/queue"
done

# `xargs -P` is the queue rather than a FIFO of slot tokens. A token returned
# by the worker as its last act is never returned by a worker that is killed,
# which shrinks the pool by one slot per abnormal death and deadlocks once it
# reaches zero [measured 2026-09-23]. xargs frees a slot by waiting on a PID,
# and the kernel reports a killed child just as it reports one that exited.
#
# -r so an empty list runs nothing rather than once with no argument. $1 is the
# scratch directory; xargs appends one index and one suite as $2 and $3.
export SUITE_BODY HERE
sh "$HERE/tools/bounded.sh" xargs -0 -n 2 -r -P "$slots" sh -c '
    sh "$HERE/tools/bounded.sh" sh -c "$SUITE_BODY" petta-suite "$3" \
        >"$1/$2.out" 2>&1 && : >"$1/$2.ok"
' petta-suite-worker "$parts" <"$parts/queue" &
queue_pid=$!
# `wait` rather than the foreground: a POSIX shell does not run a trap handler
# while it waits for a FOREGROUND command, so with the dispatch in front a
# Ctrl-C does nothing until the whole run is over. `wait` is the documented
# exception a trapped signal interrupts.
wait "$queue_pid"
queue_pid=

# A suite PASSED only if it left an .ok marker. The polarity matters and the
# opposite way round is wrong: marking FAILURE needs the worker to survive
# long enough to write the marker, and a worker killed by the ceiling, by the
# OOM killer or by a signal runs no `||` branch at all, so it left nothing and
# read as green [measured 2026-09-23: with the ceiling firing, the queue
# exited 0 while every suite had been killed]. Absence cannot be forged, so a
# killed worker, a killed queue and a suite that was never dispatched all fail
# by default. This is the same shape as the slot token the worker had to hand
# back, and the same correction: never make the safe outcome depend on the
# worker staying alive.
ok=0
part=1
while [ "$part" -le "$ran" ]; do
    [ -f "$parts/$part.out" ] && cat "$parts/$part.out"
    [ -f "$parts/$part.ok" ] || ok=1
    part=$((part + 1))
done
exit "$ok"
