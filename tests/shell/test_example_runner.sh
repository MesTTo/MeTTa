#!/bin/sh
# Purpose: prove the example runner uses process status, not assertion glyphs,
#   as its pass/fail oracle.
# Open Obligations:
#   To Do: None
#   Hacks: None
#   Future Enhancements: None

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)

# One spelling of the bound, implemented in bounded.sh, which every runner in
# this tree and a command typed by hand all reach.
bounded() { sh "$ROOT/tools/bounded.sh" "$@"; }
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT HUP INT TERM

printf '!(quote no-assertion-glyph)\n' > "$fixture/succeeds.metta"
printf '!(test expected actual)\n' > "$fixture/fails.metta"

bounded sh "$ROOT/tools/test.sh" "$fixture/succeeds.metta" > "$fixture/success.log"
grep -q "OK: $fixture/succeeds.metta" "$fixture/success.log"

if bounded sh "$ROOT/tools/test.sh" "$fixture/fails.metta" \
        > "$fixture/failure.log" 2>&1; then
    echo "failing MeTTa test returned success" >&2
    exit 1
fi
grep -q "FAILURE in $fixture/fails.metta" "$fixture/failure.log"

printf 'example runner status checks passed\n'
