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
#   - swipl on PATH. This suite drives the engine directly and needs no host,
#     no janus and no Python, which is why it is the one component test.sh that
#     takes no interpreter.
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
bounded() { sh "$HERE/bounded.sh" "$@"; }

# The suites drive Python through Janus, which follows VIRTUAL_ENV rather than
# any interpreter this script picks, so a run BY HAND has to export the same
# environment the gate does or shim.plt's 18 scalar-semantics cases fail on a
# missing module that is installed in the checkout's own virtual environment.
METTA_ROOT="$HERE"
. "$HERE/select-python.sh"

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
    for suite in "$@"; do
        [ -e "$suite" ] || suite=${suite#tests/prolog/}
        [ -e "$suite" ] || continue
        ran=$((ran + 1))
        # lock_order.pl loads before the suite, so every mutex acquisition and
        # every listener registration of the process is recorded; its header
        # says what it sees.
        bounded swipl -s lock_order.pl -g "set_test_options([format(log)]), run_tests" \
            -t halt "$suite" -- extensions >"$out" 2>&1 || ok=1
        cat "$out"; cat "$out" >>"$log"
    done
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
