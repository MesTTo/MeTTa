#!/bin/sh
# Purpose: produce the patched SWI-Prolog source tree every host this
#   repository builds is built from, from this repository alone.
#
# Assumes: git, and network for the clone. Reads tools/pymetta-host/swipl.pin
#   and the patches of the two layers patch-root.sh names, every *.patch under
#   tests/checks/host_workarounds and then every one under
#   tools/pymetta-host/host-only, each at any depth.
# Guarantees:
#   - the tree is swipl-devel at the pinned COMMIT with every patch of the
#     stack applied, the ledger's before the host-only ones, or the script
#     exits nonzero naming the patch that failed; a half-patched tree never
#     reaches a build [measured 2026-09-25T13:56:25+10:00: a clone at
#     V10.1.14 took the ledger's 37 patches and then
#     swi-alarm-scheduler-exits-holding-lock.patch, and every file of the
#     result equals the tree the host compiled Sep 25 2026, 12:27:40 was
#     built from with the alarm fix added by hand]
#   - each patch is applied in the tree it sits under in its layer, so the
#     two under packages/swipy/ land in that submodule rather than failing at
#     the superproject
#     [tested 2026-09-25T13:56:49+10:00: tools/pymetta-host/fetch_selftest.sh]
# Fails when: the network is unavailable, or a patch no longer applies because
#   the pin or a patch beneath it moved. Both refuse rather than building
#   something unpinned.
# Decides: $DEST, defaulting to ai-tmp/swipl-src, because the tree is build
#   input rather than a deliverable.
#
# WHY THIS EXISTS. run.sh required SRC to name a swipl-devel checkout and
# refused without one, for the good reason that an absolute path only works
# on the machine it was written on. The consequence was that the host wheel
# could only be built by someone who had already prepared that tree by hand,
# so tools/build-distributions.sh skips pymetta-host and the release publishes
# 17 distributions of 18. The patches were committed all along; nothing
# applied them.
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$HERE/../.." && pwd)
PIN="$HERE/swipl.pin"
DEST=${DEST:-$ROOT/ai-tmp/swipl-src}
# Which patches the stack holds, and the tree each is applied in, are decided
# in patch-root.sh, which declare-host.sh reads too: the tree a patch is
# applied in and the tree it is later looked for in are one answer.
. "$HERE/patch-root.sh"
patch_layers "$ROOT"

field() { sed -n "s/^$1[[:space:]]\\+\\(.*\\)\$/\\1/p" "$PIN" | head -1; }
URL=$(field url); COMMIT=$(field commit); SWIPY=$(field swipy); TAG=$(field tag)
for name in URL COMMIT SWIPY TAG; do
    eval "value=\$$name"
    [ -n "$value" ] || { printf 'fetch-source: %s missing from %s\n' "$name" "$PIN" >&2; exit 1; }
done

# Shallow at the tag: this is build input at a fixed commit, so the history
# is weight with no reader. A full clone of swipl-devel is several hundred
# megabytes and every byte of it is discarded.
if [ ! -d "$DEST/.git" ]; then
    printf 'fetch-source: cloning %s at %s\n' "$URL" "$TAG"
    rm -rf "$DEST"
    git clone --quiet --depth 1 --branch "$TAG" "$URL" "$DEST"
fi
got=$(git -C "$DEST" rev-parse HEAD)
[ "$got" = "$COMMIT" ] || {
    printf 'fetch-source: %s resolves to %s, not the pinned %s\n' \
        "$TAG" "$got" "$COMMIT" >&2; exit 1; }
git -C "$DEST" submodule update --quiet --init --recursive --depth 1
got=$(git -C "$DEST/packages/swipy" rev-parse HEAD)
[ "$got" = "$SWIPY" ] || {
    printf 'fetch-source: packages/swipy is %s, not the pinned %s\n' \
        "$got" "$SWIPY" >&2; exit 1; }

# Start from the pinned tree every run, so a re-run is not a second
# application of the same patch onto an already-patched file.
pristine_tree "$DEST"
applied=0; host_only=0
for patch in $(every_patch); do
    root=$(patch_root "$DEST" "$patch") || {
        printf 'fetch-source: %s has no %s for %s\n' \
            "$DEST" "$(patch_tree "$patch")" "$(basename "$patch")" >&2; exit 1; }
    git -C "$root" apply "$patch" || {
        printf 'fetch-source: %s no longer applies to %s over the patches before it; the pin or one of them moved\n' \
            "$(basename "$patch")" "${root#$DEST}" >&2; exit 1; }
    applied=$((applied + 1))
    case $patch in "$HOST_ONLY"/*) host_only=$((host_only + 1)) ;; esac
done
printf 'fetch-source: %s at %s, %s patch(es) applied, %s of them host-only, in %s\n' \
    "$(basename "$URL" .git)" "$TAG" "$applied" "$host_only" "$DEST"
