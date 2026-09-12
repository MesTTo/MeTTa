#!/bin/sh
# Purpose: measure what each door of tests/prolog/reachability.pl is worth and
#   prove the doors added on 2026-09-12 are what their plants are attached to,
#   by taking one door away at a time and running both entry points.
#
#   Usage: sh tests/prolog/probes/reachability_doors.sh
#
# Assumes: swipl on PATH, and the door lines this script anchors on are still
#   spelled as they are in tests/prolog/reachability.pl. A mutation whose text
#   has moved is reported rather than skipped, which is the same rule
#   tests/checks/check_evidence_mutations.py states about its own mutants: a
#   mutation nothing applies looks exactly like a door nothing needs.
# Guarantees:
#   - the report is run once per door with that door disabled, so its worth is
#     a count and not a claim: the number of predicates that stop being
#     reachable when the door closes
#   - the self-test is run the same way, and the run FAILS unless every
#     mutation is caught and the unmutated control passes, so a plant that has
#     come loose from its door cannot pass unnoticed
#   - nothing is written inside the checkout: each mutant is a copy in a
#     temporary directory, and the analysis resolves the tree it walks against
#     the working directory, which stays tests/prolog
# Open Obligations:
#   To Do: None
#   Hacks: None
#   Future Enhancements: None

set -u

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
SOURCE=$ROOT/tests/prolog/reachability.pl
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT INT TERM
status=0

# One door, one copy. Every argument after the name is a sed script applied in
# turn, and the copy has to differ from the source afterwards.
mutant() {
    name=$1
    shift
    copy=$WORK/$name.pl
    cp "$SOURCE" "$copy"
    for edit in "$@"; do
        sed "$edit" "$copy" > "$copy.next" && mv "$copy.next" "$copy"
    done
    if cmp -s "$SOURCE" "$copy"; then
        echo "  $name: nothing to disable, the door has moved" >&2
        status=1
        return 1
    fi
    return 0
}

reported() {
    ( cd "$ROOT/tests/prolog" && \
      swipl -q -g reachability_report -t 'halt(0)' "$1" ) > "$WORK/report.out" 2>&1
    sed -n 's/^\([0-9]*\) predicates are reachable from no root.*/\1/p' "$WORK/report.out"
}

named_doors() {
    ( cd "$ROOT/tests/prolog" && \
      swipl -q --on-error=status -g reachability_selftest -t 'halt(0)' "$1" ) \
        > "$WORK/selftest.out" 2>&1
    echo "$?" > "$WORK/selftest.status"
    sed -n 's/^the \([a-z_]*\) door is broken.*/\1/p' "$WORK/selftest.out" \
        | tr '\n' ' '
}

READER="s|^root_of(context_reader, Owner:Name/Arity) :-$|root_of(context_reader, Owner:Name/Arity) :- fail,|"
NESTED="s|\['\*\.pl', '\*/\*\.pl'\]|['*.pl']|"
QUALIFIED="s|^constructed_indicator(Module:Name, Module:Name/Total) :-$|constructed_indicator(Module:Name, Module:Name/Total) :- fail,|"
ARITY_HEAD="s|^constructed_indicator(Module:Name, Module:Name/Total) :-$|constructed_indicator(Module:Name, Module:Name/0) :-|"
ARITY_BODY="s|tree_predicate_index(Name, Module:Name/Total)\.|tree_predicate_index(Name, Module:Name/0).|"
OWN_MODULE="s|^    (   source_file_property(File, module(Module))$|    (   fail, source_file_property(File, module(Module))|"
LOAD_MODULE="s|^    ;   source_file_property(File, load_context(Module, _, _))$|    ;   fail, source_file_property(File, load_context(Module, _, _))|"

cp "$SOURCE" "$WORK/control.pl"
base=$(reported "$WORK/control.pl")
echo "swipl: $(swipl --version)"
echo "loadavg: $(cut -d' ' -f1-3 /proc/loadavg)"
echo "control: $base reported"
echo
echo "door worth, the findings each door takes off that count"
printf 'door\treported\tworth\n'

worth() {
    name=$1
    shift
    mutant "$name" "$@" || return 0
    count=$(reported "$WORK/$name.pl")
    printf '%s\t%s\t%s\n' "$name" "$count" "$((count - base))"
}

worth directive_module   "$OWN_MODULE" "$LOAD_MODULE"
worth nested_directive   "$NESTED"
worth qualified_name     "$QUALIFIED"
worth closure_arity      "$ARITY_HEAD" "$ARITY_BODY"
worth context_reader     "$READER"
worth all_four           "$OWN_MODULE" "$LOAD_MODULE" "$NESTED" "$QUALIFIED" "$READER"

echo
echo "self-test discrimination, the door each mutation is caught by"
printf 'mutation\texit\tdoors named\n'
doors=$(named_doors "$WORK/control.pl")
control_status=$(cat "$WORK/selftest.status")
printf 'none\t%s\t%s\n' "$control_status" "${doors:-none}"
if [ "$control_status" -ne 0 ]; then
    echo "  the unmutated control is already red, so nothing below means anything" >&2
    status=1
fi

caught() {
    name=$1
    expected=$2
    doors=$(named_doors "$WORK/$name.pl")
    got=$(cat "$WORK/selftest.status")
    printf '%s\t%s\t%s\n' "$name" "$got" "${doors:-none}"
    if [ "$got" -eq 0 ]; then
        echo "  the $name mutation is caught by nothing: its plant has come loose" >&2
        status=1
    elif [ "$doors" != "$expected" ]; then
        echo "  the $name mutation was expected to name '$expected' and named '$doors'" >&2
        status=1
    fi
}

caught directive_module "directive_module "
caught nested_directive "nested_directive "
caught qualified_name   "qualified_atom closure_atom "
caught closure_arity    "closure_atom "
caught context_reader   "context_reader "

exit $status
