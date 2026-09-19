#!/bin/sh
# Purpose: prove tools/battery.sh refuses a battery tree that is not a copy of
#   its source, by planting each shape of drift in a fixture and requiring a
#   refusal that names it, and prove it can CLEAR what a previous run left,
#   including a git repository a fixture wrote.
# Assumes: tools/battery.sh sits beside this file; a writable ai-tmp/.
# Guarantees: exits nonzero if any planted drift goes unreported, or if the
#   excluded-scratch case is reported (the false positive -O exists to stop).
# Fails when: run concurrently with itself, since it owns one fixture path.
# Decides: the drift shapes are enumerated rather than sampled. The space is
#   closed -- a file can differ, be extra, or be absent -- so exhausting it
#   discharges the claim outright instead of supporting it.
set -eu

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
BATTERY="$HERE/battery.sh"
FIXTURE=$(cd "$HERE/.." && pwd)/ai-tmp/battery-selftest
INDEX=selftest
failures=0

cleanup() { rm -rf "$FIXTURE"; }
trap cleanup EXIT

plant_source() {
    rm -rf "$FIXTURE"
    mkdir -p "$FIXTURE/src/package/inner"
    printf 'one\n'   > "$FIXTURE/src/top.txt"
    printf 'two\n'   > "$FIXTURE/src/package/mid.txt"
    printf 'three\n' > "$FIXTURE/src/package/inner/deep.txt"
}

# Each case names what it planted, so a failure says which shape went unseen
# rather than only that something did.
expect() {
    what=$1; want=$2; shift 2
    if BATTERY_SOURCE="$FIXTURE/src" sh "$BATTERY" verify "$INDEX" > "$FIXTURE/out" 2>&1
    then got=0; else got=$?; fi
    if [ "$got" -eq 0 ] && [ "$want" -eq 0 ]; then
        echo "  ok   $what: accepted, as it should be"
    elif [ "$got" -ne 0 ] && [ "$want" -ne 0 ]; then
        if [ $# -gt 0 ] && ! grep -q -- "$1" "$FIXTURE/out"; then
            echo "  FAIL $what: refused, but did not name $1"; cat "$FIXTURE/out"
            failures=$((failures + 1))
        else
            echo "  ok   $what: refused, naming ${1:-the drift}"
        fi
    else
        echo "  FAIL $what: wanted exit ${want} and got ${got}"; cat "$FIXTURE/out"
        failures=$((failures + 1))
    fi
}

plant_source
BATTERY_SOURCE="$FIXTURE/src" sh "$BATTERY" provision "$INDEX"
# Asked for rather than recomputed: a second copy of the layout rule here is a
# second thing to keep in step, and it was wrong the first time.
TREE=$(sh "$BATTERY" path "$INDEX")

echo "battery selftest:"
expect "an untouched copy" 0

printf 'CHANGED\n' > "$TREE/package/inner/deep.txt"
expect "a modified file" 1 "deep.txt"

BATTERY_SOURCE="$FIXTURE/src" sh "$BATTERY" provision "$INDEX"
printf 'stray\n' > "$TREE/package/extra.txt"
expect "a file the source does not have" 1 "extra.txt"

BATTERY_SOURCE="$FIXTURE/src" sh "$BATTERY" provision "$INDEX"
rm "$TREE/package/mid.txt"
expect "a file the battery is missing" 1 "mid.txt"

# The regression this tool was born with: provision writes ai-tmp/ into the
# tree it has just copied, which moves the parent directory's mtime. Before -O
# that read as drift, so the checker failed on its own writes.
BATTERY_SOURCE="$FIXTURE/src" sh "$BATTERY" provision "$INDEX"
mkdir -p "$TREE/ai-tmp" "$TREE/package/__pycache__"
printf 'log\n' > "$TREE/ai-tmp/run.log"
printf 'bytes\n' > "$TREE/package/__pycache__/mid.pyc"
expect "excluded scratch written into the battery" 0

# Drift is one half of the contract and clearing it is the other: a battery
# that cannot be re-provisioned is a battery lost. A gate run leaves what the
# source does not have, and some of it is git repositories -- the packaging
# fixtures write repos/<name>/.git. While the .git rule was an `--exclude` it
# protected those at the receiver, so `repos/` could never be emptied and
# survived the provision that was supposed to remove it -- loudly on the real
# tree, `cannot delete non-empty directory: repos` and exit 1, leaving that
# index unusable [measured 2026-09-20 on wt-battery-6], and SILENTLY at this
# fixture's depth, exit 0 with the directory still there. The quiet one is
# why this asserts the tree rather than the status.
BATTERY_SOURCE="$FIXTURE/src" sh "$BATTERY" provision "$INDEX"
mkdir -p "$TREE/repos/fixture_lib/.git/refs/heads"
printf 'ref: refs/heads/master\n' > "$TREE/repos/fixture_lib/.git/HEAD"
printf 'built\n' > "$TREE/repos/fixture_lib/setup.py"
if BATTERY_SOURCE="$FIXTURE/src" sh "$BATTERY" provision "$INDEX" \
       > "$FIXTURE/out" 2>&1
then
    if [ -e "$TREE/repos" ]; then
        echo "  FAIL a run's leftover git repository: provision said it worked" \
             "and repos/ is still there"
        failures=$((failures + 1))
    else
        echo "  ok   a run's leftover git repository: cleared by the next provision"
    fi
else
    echo "  FAIL a run's leftover git repository: provision refused"
    cat "$FIXTURE/out"
    failures=$((failures + 1))
fi
expect "the tree that provision has just cleared" 0

rm -rf "$TREE"
[ "$failures" -eq 0 ] || { echo "battery selftest: $failures case(s) failed"; exit 1; }
echo "battery selftest: every planted drift was refused, no excluded write was,"
echo "  and a leftover git repository did not strand the tree"
