#!/bin/sh
# Purpose: run engine_join_window.pl in every mode and tally the outcomes, so
#   the claim "engine_destroy/1 makes a thread unsafe to join and engine_post/3
#   does not" is a count rather than an assertion.
#
#   Usage: sh tests/prolog/probes/engine_join_window.sh [RUNS]
#
# Assumes: swipl on PATH. This is a DIAGNOSTIC, not a gate lane: the `destroy`
#   mode is expected to kill its process, and no check.sh lane runs it.
# Guarantees:
#   - every run is bounded, so a mode that hangs is counted as hung rather
#     than stalling the caller
#   - the exit status is nonzero if `post`, `next` or `create_idle` ever
#     crashes, which is the direction that would falsify the fix in
#     engine/materialize.pl; `destroy` and `create_churn` crashing is the
#     expected reading and does not fail this script
#   - the crashing mode writes no core. It dumped a 55MB core per run under
#     systemd-coredump, and six of those in a row starved the modes that ran
#     after them: one run of each of `post`, `next` and `create_idle` was
#     counted hung at a 60 second bound while the same three, run alone,
#     finished in 2.2 seconds twelve times out of twelve. Raise it with
#     `ulimit -c unlimited` in a shell of your own if you want the core.
# Open Obligations:
#   To Do: None
#   Hacks: None
#   Future Enhancements: None

set -u

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
RUNS=${1:-6}
LIMIT=${METTA_PROBE_LIMIT:-120}
status=0
ulimit -c 0 2>/dev/null || true

# bounded.sh rather than a bare `timeout`, which on this box is the uutils
# reimplementation: it costs 102ms a call against GNU's 0.65ms and signals the
# command's pid alone. bounded.sh prefers the GNU one where both are installed.
bounded() { sh "$ROOT/bounded.sh" --ceiling "$LIMIT" "$@"; }

tally() {
    mode=$1
    ok=0; segv=0; hung=0; other=0
    i=1
    while [ "$i" -le "$RUNS" ]; do
        # A file rather than $(...): the command substitution's subshell is a
        # parent bounded.sh's PR_SET_PDEATHSIG link can outlive, and a run
        # reaped that way reports 143 and reads as a hang.
        bounded swipl "$HERE/engine_join_window.pl" "$mode" >"$log" 2>&1
        rc=$?
        if grep -q "fatal signal 11" "$log"; then
            segv=$((segv+1))
        else
            case $rc in
                0)   ok=$((ok+1)) ;;
                124|137|143) hung=$((hung+1)) ;;
                *)   other=$((other+1)) ;;
            esac
        fi
        i=$((i+1))
    done
    echo "$mode: runs=$RUNS joined=$ok segv=$segv hung=$hung other=$other"
    if [ "$mode" != destroy ] && [ "$mode" != create_churn ] && [ "$segv" -gt 0 ]; then
        echo "  $mode crashed, which the window map says it cannot" >&2
        status=1
    fi
}

log=$(mktemp)
trap 'rm -f "$log"' EXIT INT TERM

echo "swipl: $(swipl --version)"
echo "loadavg: $(cut -d' ' -f1-3 /proc/loadavg)"
tally post
tally next
tally create_idle
tally destroy
tally create_churn
exit $status
