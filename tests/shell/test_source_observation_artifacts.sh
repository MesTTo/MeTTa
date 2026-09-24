#!/bin/sh
# Purpose: prove a warm shipping run of the source-errors example answers what
#   the cold run answered and keeps the artifacts the cold run wrote. The
#   example observes execution through engine/source_observation.pl, which a
#   cold boot compiles to engine/source_observation.qlf beside
#   engine/metta.qlf; a warm boot loads both.
# Guarantees:
#   - with every engine/ and lib/ artifact purged, a cold run of
#     examples/ch20-extending-the-engine/20-05-observing-execution/03-source-errors.metta
#     through tools/run.sh exits 0, and a second run exits 0 and leaves
#     engine/metta.qlf and engine/source_observation.qlf with the modification
#     times the first run gave them
#     [tested 2026-09-25T03:48:11+10:00: sh tools/check.sh source-artifacts]
# Assumes:
#   - swipl on PATH, as tools/run.sh needs.
#   - no other lane boots the engine while this runs. It purges the governed
#     set every other lane and suite boots from, which is why engine/check.sh
#     runs it alone.
#   - GNU or uutils stat, whose %.9Y prints a modification time to the
#     nanosecond, the resolution SWI's time_file/2 reads.
# Owns resources: the governed artifact set, purged at the start and left
#   regenerated; a scratch directory under ai-tmp for the two runs' output,
#   removed by the EXIT trap.
# Open Obligations:
#   To Do: None
#   Hacks: None
#   Future Enhancements: None
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$ROOT"

# One spelling of the bound, implemented in bounded.sh. run.sh bounds its own
# swipl and this bounds run.sh, so the tighter ceiling is the one in force.
bounded() { sh "$ROOT/tools/bounded.sh" "$@"; }

mkdir -p "$ROOT/ai-tmp"
probe=$(mktemp -d "$ROOT/ai-tmp/source-artifacts.XXXXXX")
trap 'rm -rf "$probe"' EXIT HUP INT TERM

example=examples/ch20-extending-the-engine/20-05-observing-execution/03-source-errors.metta
artifacts='engine/metta.qlf engine/source_observation.qlf'

shipping_run() {
    if ! bounded sh tools/run.sh "$example" >"$probe/$1.out" 2>&1; then
        printf 'source-artifacts: the %s run of %s failed:\n' "$1" "$example" >&2
        cat "$probe/$1.out" >&2
        exit 1
    fi
}

find engine lib -name '*.qlf' -delete
shipping_run cold
for artifact in $artifacts; do
    [ -f "$artifact" ] || {
        printf 'source-artifacts: the cold run wrote no %s\n' "$artifact" >&2
        exit 1
    }
done
# shellcheck disable=SC2086 # the two paths hold no whitespace
cold_times=$(stat -c '%.9Y %n' $artifacts)
shipping_run warm
# shellcheck disable=SC2086
warm_times=$(stat -c '%.9Y %n' $artifacts)
if [ "$cold_times" != "$warm_times" ]; then
    printf 'source-artifacts: the warm run rewrote an artifact the cold run wrote:\n' >&2
    printf '  after the cold run:\n%s\n  after the warm run:\n%s\n' "$cold_times" "$warm_times" >&2
    exit 1
fi
printf 'source-artifacts: a cold and a warm shipping run of the source-errors example both pass, and the warm run kept %s\n' "$artifacts"
