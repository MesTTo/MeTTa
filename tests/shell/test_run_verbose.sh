#!/bin/sh
# Purpose: prove the standalone launcher's explicit verbosity door exposes an
#   informational engine report while its default invocation stays quiet.
#
#   The engine has two print_message(informational, ...) reports, the
#   equation-head authoring note in engine/translator/analysis.pl and the
#   source-replacement report in engine/filereader/source_lifecycle.pl. run.sh
#   always passed swipl -q, which suppresses that channel, so neither had a
#   standalone invocation that could reach a person. Both are optional
#   authoring detail, so the default stays quiet and the door is explicit.
# Assumes: swipl on PATH; without one there is no engine to report anything,
#   and the check says so and exits 0 rather than failing.
# Guarantees:
#   - the head-pattern note is absent from a default run and present under
#     --verbose, over the same fixture through the same launcher, so the
#     difference is the option rather than the program
#   - --verbose is stripped before the file argument is chosen, which the
#     fixture's own !(test ...) proves by running at all
# Fails when: the note's wording changes. It is matched literally, because a
#   pattern loose enough to survive rewording would also match a run that
#   reported nothing.
# Open Obligations:
#   To Do: None
#   Hacks: None
#   Future Enhancements: None
set -eu

command -v swipl >/dev/null || {
    printf 'run.sh verbosity check: no swipl on PATH, skipped\n'
    exit 0
}

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)

# One spelling of the bound, implemented in bounded.sh, which every runner in
# this tree and a command typed by hand all reach. run.sh bounds its own swipl
# and this bounds run.sh, so the tighter of the two ceilings is the one in
# force for both.
bounded() { sh "$ROOT/tools/bounded.sh" "$@"; }

probe=$(mktemp -d)
trap 'rm -rf "$probe"' EXIT HUP INT TERM

fixture=$ROOT/tests/fixtures/verbose_head_pattern.metta
bounded sh "$ROOT/tools/run.sh" "$fixture" >"$probe/quiet.out" 2>&1
bounded sh "$ROOT/tools/run.sh" --verbose "$fixture" >"$probe/verbose.out" 2>&1

NOTE='the head of (= (visible-head ...) ...) holds the call (visible-inner ...)'
if grep -F "$NOTE" "$probe/quiet.out" >/dev/null; then
    echo "run.sh exposed informational diagnostics without --verbose" >&2
    cat "$probe/quiet.out" >&2
    exit 1
fi
if ! grep -F "$NOTE" "$probe/verbose.out" >/dev/null; then
    echo "run.sh --verbose suppressed the requested head-pattern report" >&2
    cat "$probe/verbose.out" >&2
    exit 1
fi

printf 'run.sh verbosity checks passed\n'
