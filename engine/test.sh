#!/bin/sh
# Purpose: run the engine's own test suites, as the gate runs them.
#
#   Usage: sh engine/test.sh [SUITE ...]
#
#   With no argument it runs every suite. With one it runs the named ones,
#   given as a path from tests/prolog or from the repository root:
#
#     sh engine/test.sh suites/spaces/materialization.plt
#     sh engine/test.sh tests/prolog/suites/reader/parser.plt
#
#   The argument exists because the alternative was typed by hand instead. The
#   documented way to run one suite used to be a raw
#   `cd tests/prolog && swipl -g "set_test_options([format(log)]), run_tests"
#   -t halt <suite>`, which carries no bound, no VIRTUAL_ENV, no
#   `-- extensions`, no choicepoint scan and no load-error scan; one such
#   command ran 7,540 seconds at 97.8% CPU on 2026-09-05 and needed SIGKILL.
#   This form is shorter than that one and gets all six.
#
# Assumes:
#   - swipl on PATH, and tools/select-python.sh sourced below is what puts the
#     PATCHED one there. It selects an interpreter, and prepending that venv's
#     bin/ carries its `swipl` symlink with it, so a developer typing
#     `sh engine/test.sh` runs the same host the gate does. Relying on that is
#     deliberate rather than incidental: a second probe here would be a second
#     answer to "which host", and check_host_workarounds.py already owns the
#     question of whether the one on PATH is patched.
#
#     A VERSION cannot tell the two apart. The stock host on PATH and the
#     patched one the venv selects both report
#     "SWI-Prolog version 10.1.14 for x86_64-linux" [measured 2026-09-22], so
#     only a patch reproduction distinguishes them, which is what that lane
#     runs.
# Guarantees:
#   - the gate's `plunit` lane and a developer typing `sh engine/test.sh` run
#     ONE body. Everything that makes the run trustworthy lives here: the
#     redirect that keeps swipl's exit status out of a pipeline, the working
#     directory the suites' relative paths resolve against, the choicepoint
#     scan, the load-time error scan that catches a test which never ran, and
#     the bound that keeps a suite from outliving the run or the session.
#   - the exit status is nonzero when any suite fails, prints an error while
#     LOADING, leaves a choicepoint, names a suite that does not exist, records
#     a mutex acquisition cycle, or runs without the lock-order recorder.
# Open Obligations:
#   To Do: None
#   Hacks: None
#   Future Enhancements: None

set -u

HERE=$(cd -- "$(dirname -- "$0")" && pwd)/..

# One spelling of the bound, implemented in bounded.sh. A plunit suite that
# does not terminate is the exact shape this repository has been bitten by
# twice, and a suite run BY HAND is the case a gate lane cannot reach.
bounded() { sh "$HERE/tools/bounded.sh" "$@"; }

# The suites drive Python through Janus, which follows VIRTUAL_ENV rather than
# any interpreter this script picks, so a run BY HAND has to export the same
# environment the gate does or shim.plt's 18 scalar-semantics cases fail on a
# missing module that is installed in the checkout's own virtual environment.
METTA_ROOT="$HERE"
. "$HERE/tools/select-python.sh"

run_plunit() {
    # The named suites are resolved AFTER this cd, so a path given from the
    # repository root has to be rewritten; the loop below does that.
    cd "$HERE/tests/prolog" || return 1
    ok=0
    log=$(mktemp)
    out=$(mktemp)
    # Redirect to a file rather than piping to tee: a pipeline's exit status is
    # the LAST command's, so swipl failing would be masked by tee succeeding.
    #
    # The suites sit under suites/<group>/, grouped by the engine unit each
    # one tests. A suite is named by its path from tests/prolog, which stays
    # the working directory: an initialization goal resolves a relative path
    # against the working directory at RUN time, so every
    # `initialization(consult('../../engine/metta.pl'))` in a suite still
    # names the engine, and so does every path a test body builds. The LOAD
    # time directives are the other half and are file-relative, which is why
    # `:- ensure_loaded('../../../../engine/metta.pl')` sits beside them.
    #
    # A named suite is accepted either as the path from here that the suites
    # themselves use, or as the path from the repository root that `find` and
    # an editor both print. Neither resolving is guessed: the one that exists
    # wins, and a name that is neither is an error rather than a silent skip.
    all=0
    if [ "$#" -eq 0 ]; then
        all=1
        set -- suites/*/*.plt
    else
        for named in "$@"; do
            [ -e "$named" ] || [ -e "${named#tests/prolog/}" ] || {
                echo "engine/test.sh: no such suite: $named" >&2
                echo "  Suites live under tests/prolog/suites/<group>/." >&2
                rm -f "$log" "$out"
                return 1
            }
        done
    fi
    ran=0
    # A suite is a swipl process of its own with no state shared with any
    # other, so they run CONCURRENTLY. Serially this loop was one core of
    # thirty-two: 24 suites took 13.6s wall against 12.1s of user time, and
    # the gate's plunit and dev-typed lanes paid that twice over 185 suites.
    #
    # Three things have to survive the change and each is why the shape below
    # is what it is. Each suite writes its OWN file, because one shared $out
    # would interleave two processes' output into one another's test report.
    # The files are concatenated in declaration order afterwards, so the log a
    # reader sees is the log they saw before. And failure is recorded as a
    # FILE rather than by setting ok=1, because a subshell cannot write its
    # parent's variable: the assignment would succeed, vanish, and leave a red
    # suite reporting green, which is the one failure a gate must not have.
    #
    # A BOUNDED QUEUE rather than batches of $slots with a wait between them.
    # Batching makes every batch cost its slowest member, and these suites are
    # very skewed: 292.6s of work across 183 suites with a single 87.29s one
    # in it, so barriers ran 219s where the floor is that one suite at 87.3s.
    #
    # `xargs -P` IS that queue. A FIFO holding one token per slot was written
    # here first and is wrong in a way worth recording, because it looks
    # correct: the worker returned its own token as its last act, so a worker
    # killed by a signal, by the OOM killer or by a failed exec never returned
    # one and the queue lost that slot for the rest of the run [measured
    # 2026-09-23, three slots and six jobs: one abnormal death still finished,
    # three deadlocked the loop after exactly three dispatches]. That is the
    # silent shape, since one lost slot only makes the run slower, and a
    # process-group signal loses EVERY token at once -- which is why
    # `timeout -s INT 6 sh engine/test.sh` was still alive 22 minutes later,
    # blocked in read(2) on a FIFO no living writer would ever feed again.
    #
    # xargs frees a slot by wait(2)ing on a PID instead, and the kernel
    # reports a child that crashed or was killed exactly as it reports one
    # that exited, so the slot cannot leak. It also deletes the pre-filled
    # token count, the long-lived file descriptor and the trap-resume hazard:
    # those are not satisfied here, they are unrepresentable.
    slots=$(nproc 2>/dev/null || echo 4)
    parts=$(mktemp -d)
    # Cleanup runs however the run ends, and a trapped signal CLEANS AND
    # RE-RAISES rather than returning. A POSIX trap that does not exit resumes
    # the script where it was interrupted, which is what turned a clean Ctrl-C
    # into the 22-minute hang above. Resetting the handler and signalling
    # ourselves is the standard form -- mbedtls ships these three lines
    # verbatim in framework/scripts/demo_common.sh -- and the reason is the
    # CALLER: a script that exits 130 looks like it chose to, where one that
    # dies by SIGINT tells its own caller to stop looping too.
    # http://mywiki.wooledge.org/SignalTrap#Special_Note_On_SIGINT
    queue_pid=
    # SIGTERM rather than SIGKILL, and to the `bounded` wrapper rather than to
    # xargs: bounded.sh's outer rung is a GNU timeout whose SIGTERM handler
    # passes the signal to the whole process group and escalates to SIGKILL
    # after the grace, which is what reaches the suites [tools/bounded.sh:376-386,
    # measured 2026-09-05: SIGTERM to a GNU timeout wrapper leaves neither its
    # child nor its grandchild alive]. A SIGKILL here would take the ceiling
    # program out before it could pass anything on.
    stop_queue() {
        [ -n "${queue_pid:-}" ] && kill -TERM "$queue_pid" 2>/dev/null
        :
    }
    cleanup() {
        stop_queue
        rm -rf "$parts" 2>/dev/null; rm -f "$log" "$out" 2>/dev/null
    }
    trap 'cleanup' EXIT
    trap 'cleanup; trap - HUP;  kill -HUP  $$' HUP
    trap 'cleanup; trap - INT;  kill -INT  $$' INT
    trap 'cleanup; trap - TERM; kill -TERM $$' TERM
    : >"$parts/queue"
    for suite in "$@"; do
        [ -e "$suite" ] || suite=${suite#tests/prolog/}
        [ -e "$suite" ] || continue
        ran=$((ran + 1))
        printf '%s\0%s\0' "$ran" "$suite" >>"$parts/queue"
    done
    # lock_order.pl loads before the suite, so every mutex acquisition and
    # every listener registration of the process is recorded; its header says
    # what it sees.
    #
    # The worker names bounded.sh as a PATH rather than reaching it through
    # the `bounded` function above: xargs execs, an exec cannot exec a shell
    # function, and check_process_bounds.py reads the spawn statically, so a
    # bound spelled "$0" is one it cannot see and correctly refuses. HERE is
    # exported for the same reason -- the inner shell is a new process.
    #
    # $1 is the scratch directory, fixed for every worker; xargs appends one
    # index and one suite as $2 and $3.
    export HERE
    # -r is why there is no `if [ "$ran" -gt 0 ]` here: xargs runs nothing on
    # empty input rather than once with no arguments. nixpkgs pairs two
    # NUL-separated fields per job the same way in
    # pkgs/build-support/setup-hooks/make-symlinks-relative.sh.
    bounded xargs -0 -n 2 -r -P "$slots" sh -c '
            sh "$HERE/tools/bounded.sh" swipl -s lock_order.pl \
                -g "set_test_options([format(log)]), run_tests" \
                -t halt "$3" -- extensions >"$1/$2.out" 2>&1 \
                || : >"$1/$2.bad"
    ' petta-suite-worker "$parts" <"$parts/queue" &
    queue_pid=$!
    # `wait` rather than running the queue in the foreground. A shell does not
    # run a trap handler while it is waiting for a FOREGROUND command -- POSIX
    # defers the handler until that command completes -- so with the dispatch
    # in front, Ctrl-C did nothing for the 97 seconds the whole run took
    # [measured 2026-09-23: `timeout -s INT 6 sh engine/test.sh` exited at 97s,
    # not at 6s]. `wait` is the documented exception and is interrupted by a
    # trapped signal, which is what makes the handlers above reachable at all.
    wait "$queue_pid"
    queue_pid=
    part=1
    while [ "$part" -le "$ran" ]; do
        if [ -f "$parts/$part.out" ]; then
            cat "$parts/$part.out"; cat "$parts/$part.out" >>"$log"
        fi
        [ -f "$parts/$part.bad" ] && ok=1
        part=$((part + 1))
    done
    rm -rf "$parts"
    if grep -q "succeeded with choicepoint" "$log"; then
        echo "plunit: a test succeeded with a choicepoint:"
        grep -B1 "succeeded with choicepoint" "$log"
        ok=1
    fi
    # An error printed while a suite LOADS fails this gate, because the exit
    # code above cannot see it: `-t halt` halts 0, run_tests only reports the
    # tests that got registered, and a clause whose body raises during goal
    # expansion is dropped along with the whole term expansion that produced
    # it -- for a plunit test that is BOTH the 'unit test'/4 registration and
    # the 'unit body'/2 clause, so the test does not run, does not fail, and
    # does not appear in the count. metta.plt printed
    # `Arithmetic: `foo' is not a function` at load and reported "All 233
    # tests passed" while the intact file has 234, in both configurations the
    # lane ran then, and nothing above detected it: the two checks this gate
    # had were the exit code and the choicepoint scan.
    #
    # A grep rather than swipl's own --on-error=status, which counts the same
    # errors but ALSO arms plunit: got_messages/2 and got_message/1
    # (library/ext/plunit/plunit.pl:643-665) treat on_error==status as "fail
    # any test that emits a message it did not declare", which turns the four
    # deliberate refusals in prolog_interface.plt red [measured 2026-08-26:
    # 88 suite runs, 85 rc=0 and 3 rc=1, against 0 lines matching ^ERROR in
    # all 88 of the same runs without the flag].
    if grep -q "^ERROR" "$log"; then
        echo "plunit: a suite printed an error; a clause that fails to compile"
        echo "is dropped silently and its test never runs:"
        grep -A1 "^ERROR" "$log"
        ok=1
    fi
    # Every suite runs under tests/prolog/lock_order.pl, which records the
    # order each thread acquires SWI mutexes, with the event-list lock SWI
    # holds across a listener callback as one more, and reports at halt. A
    # cycle is a deadlock some interleaving reaches; four hung this tree before
    # the recorder existed (docs/journal/2026-09-13-one-door-for-host-listeners.md).
    # The cycles the tree carries today are inventoried in the recorder, so a
    # new one fails here and a listed one is reported as known.
    if grep -q "^lock-order: cycle$" "$log"; then
        echo "plunit: the lock-order recorder found an acquisition cycle the"
        echo "inventory in tests/prolog/lock_order.pl does not list:"
        grep "^lock-order: new cycle" -A6 "$log"
        ok=1
    fi
    # A suite that printed neither verdict ran without the recorder, and that
    # silence is the silence a clean run prints, so the count is checked.
    reported=$(grep -cE "^lock-order: ([0-9]+ mutexes|cycle$)" "$log")
    if [ "$reported" -ne "$ran" ]; then
        echo "plunit: the lock-order recorder reported for $reported of $ran suites"
        ok=1
    fi
    # After a run of every suite, an inventoried cycle no suite showed is a
    # row to delete, which is how the inventory only shrinks.
    if [ "$all" -eq 1 ]; then
        if ! bounded swipl -q -s lock_order.pl -g "lock_order:lock_order_audit('$log')" \
                -t halt >"$out" 2>&1; then
            echo "plunit: the lock-order inventory has a row no suite shows any more:"
            grep "^lock-order: inventory row" "$out"
            ok=1
        fi
    fi
    rm -f "$log" "$out"
    return $ok
}

run_plunit "$@"
