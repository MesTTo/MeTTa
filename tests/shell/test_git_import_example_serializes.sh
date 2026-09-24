#!/bin/sh
# Purpose: prove the git-import! example passes when several processes run it
#   at once in one tree, which every gate does: engine/check.sh's shell and
#   examples lanes each run the whole corpus, and the twins lane runs the
#   example's Python twin, all against the same ./repos.
# Guarantees:
#   - three concurrent runs of 06-git_import.metta, twice over, each exit 0
#     and print the example's passing check. Before its fixture took a lock,
#     5 of the 6 runs failed and this script exited 1, git
#     finding its working directory deleted by another run
#     [measured 2026-09-25T05:06:53+10:00: command=sh
#     tests/shell/test_git_import_example_serializes.sh]
# Open Obligations:
#   To Do: None
#   Hacks: None
#   Future Enhancements: None
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)

# One spelling of the bound, implemented in bounded.sh, which every runner in
# this tree and a command typed by hand all reach.
bounded() { sh "$project_dir/tools/bounded.sh" "$@"; }

example=examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/06-git_import.metta
logs=$(mktemp -d)
trap 'rm -rf "$logs"' EXIT HUP INT TERM

failed=0
for round in 1 2; do
    runs=
    for run in 1 2 3; do
        log="$logs/$round-$run.log"
        (cd "$project_dir" && bounded sh tools/run.sh "$example") > "$log" 2>&1 &
        runs="$runs $!:$log"
    done
    for entry in $runs; do
        log=${entry#*:}
        if wait "${entry%%:*}" && grep -q '✅' "$log"; then
            continue
        fi
        echo "FAILURE in concurrent run $log:" >&2
        cat "$log" >&2
        failed=$((failed + 1))
    done
done
if [ "$failed" -ne 0 ]; then
    echo "$failed of 6 concurrent runs of $example failed" >&2
    exit 1
fi
echo "concurrent git-import example runs passed"
