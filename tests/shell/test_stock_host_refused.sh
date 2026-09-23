#!/bin/sh
# Purpose: prove the engine boots through qlf_load_engine/0 on a declared
#   patched host and refuses, as that boot's own error, a stock host and a
#   stock binary started on a patched home.
#
#   The failure this exists for shipped in pymetta 0.9.1: the engine had
#   relied on a patched SWI since 2026-09-16, nothing checked for one, and a
#   stock host answers present for 14 of the ledger's reproductions and dumps
#   core on two [measured 2026-09-23]. The third case is the hole a home-only
#   declaration leaves: SWI_HOME_DIR starts any binary on any home, and the
#   venv this tree develops in exports it to every process it starts.
# Guarantees:
#   - the gate's own swipl boots the engine and prints its marker
#   - a stock swipl on its own home exits nonzero naming a missing patch
#   - that stock swipl on the patched home exits nonzero naming the build
#     mismatch, so a home's declaration never vouches for a foreign binary
# Fails when:
#   - no stock swipl distinct from the gate's exists on this machine: the
#     refusal halves are then unmeasured and this exits 125, which check.sh
#     reports as MEASURED NOTHING rather than as a pass.
# Open Obligations:
#   To Do: None
#   Hacks: None
#   Future Enhancements: None
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
bounded() { sh "$project_dir/tools/bounded.sh" "$@"; }
cd "$project_dir"

patched=${SWIPL:-$(command -v swipl)}
stock=${STOCK_SWIPL:-/usr/bin/swipl}
boot="consult('engine/qlf_boot.pl'), metta_qlf_boot:qlf_load_engine, writeln(metta_booted)"
failures=0

fail() { printf '  %s\n' "$*"; failures=$((failures + 1)); }

# Each run keeps its own output, and a status from `|| status=$?` rather than
# a pipeline, so a refusal's exit code is the process's own.
run_boot() {
    status=0
    out=$(bounded "$@" -q -g "$boot" -t halt < /dev/null 2>&1) || status=$?
}

run_boot "$patched"
[ "$status" -eq 0 ] && printf '%s\n' "$out" | grep -qx metta_booted ||
    fail "the gate's swipl ($patched) did not boot: exit $status: $out"

compiled_at() {
    env -u SWI_HOME_DIR "$1" -q -g 'current_prolog_flag(compiled_at, C), write(C)' -t halt < /dev/null
}
if [ ! -x "$stock" ] || [ "$(compiled_at "$stock")" = "$(compiled_at "$patched")" ]; then
    printf 'stock-host-refused: no stock swipl distinct from %s (tried %s), refusal unmeasured\n' \
        "$patched" "$stock"
    [ "$failures" -eq 0 ] || exit 1
    exit 125
fi

status=0
out=$(env -u SWI_HOME_DIR sh "$project_dir/tools/bounded.sh" "$stock" -q -g "$boot" -t halt < /dev/null 2>&1) || status=$?
[ "$status" -ne 0 ] || fail "stock $stock booted the engine"
printf '%s\n' "$out" | grep -q 'patch(es) missing' ||
    fail "stock $stock was not refused for missing patches: $out"
# -x, because SWI echoes the whole -g goal in its error line, marker included.
printf '%s\n' "$out" | grep -qx metta_booted && fail "stock $stock reached the marker"

home=$(env -u SWI_HOME_DIR "$patched" -q -g 'current_prolog_flag(home, H), write(H)' -t halt < /dev/null)
status=0
out=$(SWI_HOME_DIR=$home sh "$project_dir/tools/bounded.sh" "$stock" -q -g "$boot" -t halt < /dev/null 2>&1) || status=$?
[ "$status" -ne 0 ] || fail "stock $stock on the patched home $home booted the engine"
printf '%s\n' "$out" | grep -q 'vouches for the SWI-Prolog build' ||
    fail "stock $stock on the patched home was not refused as a foreign build: $out"

printf 'stock-host-refused: %s defect(s) over 3 cases\n' "$failures"
[ "$failures" -eq 0 ]
