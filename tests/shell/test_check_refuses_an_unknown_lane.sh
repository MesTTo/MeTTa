#!/bin/sh
# Purpose: prove tools/check.sh refuses a lane name that selects nothing even
#   beside one that does, and still accepts real lanes and selectors. Only a
#   request where NO name matched used to refuse, so a mistyped name beside a
#   real one shrank the run to the real one and exited 0 under a green
#   summary.
# Guarantees:
#   - `check.sh --list <lane> <name no lane has>` exits 2 and names the latter
#   - `check.sh --list <lane>` exits 0 and lists the lane
#   - the generated-artifacts selector and the seat-layering alias, which
#     stand for other lanes, are accepted
# Fails when: tools/check.sh cannot list its lanes. --list runs no lane, so
#   this reads the declarations and nothing else.
set -eu

project_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
fail() { echo "FAIL: $*" >&2; exit 1; }
# The gate's scratch when a gate runs this, ai-tmp when run alone, never /tmp.
mkdir -p "$project_dir/ai-tmp"
scratch=$(mktemp -d "${TMPDIR:-$project_dir/ai-tmp}/check-selection.XXXXXX")
trap 'rm -rf "$scratch"' EXIT

# A component gate selects only its own lanes, so the umbrella is asked
# whatever gate runs this.
listing() {
    env -u CHECK_COMPONENT sh "$project_dir/tools/bounded.sh" \
        sh "$project_dir/tools/check.sh" --list "$@" > "$scratch/out" 2>&1
}

listing evidence || fail "the real lane was refused: $(cat "$scratch/out")"
grep -qx 'GATE evidence' "$scratch/out" || fail "the real lane was not listed: $(cat "$scratch/out")"

if listing evidence no-lane-is-named-this; then
    fail "a name no lane has was accepted beside a real lane"
else
    status=$?
fi
[ "$status" -eq 2 ] || fail "the refusal exited $status, not 2: $(cat "$scratch/out")"
grep -q 'no-lane-is-named-this' "$scratch/out" ||
    fail "the refusal did not name what matched nothing: $(cat "$scratch/out")"

listing generated-artifacts || fail "the generated-artifacts selector was refused: $(cat "$scratch/out")"
listing seat-layering || fail "the seat-layering alias was refused: $(cat "$scratch/out")"
echo "ok   a name no lane has is refused beside a real one; lanes and selectors are accepted"
