#!/bin/sh
# Purpose: produce the patched SWI-Prolog source tree the host wheel is built
#   from, from this repository alone.
#
# Assumes: git, and network for the clone. Reads tools/pymetta-host/swipl.pin
#   and every *.patch under tests/checks/host_workarounds, at any depth.
# Guarantees:
#   - the tree is swipl-devel at the pinned COMMIT with every recorded patch
#     applied, or the script exits nonzero naming the patch that failed; a
#     half-patched tree never reaches a build
#   - each patch is applied in the tree it sits under in the patch directory,
#     so the two under packages/swipy/ land in that submodule rather than
#     failing at the superproject
#     [tested: tools/pymetta-host/fetch_selftest.sh; commit=WORKTREE]
# Fails when: the network is unavailable, or a patch no longer applies because
#   the pin moved. Both refuse rather than building something unpinned.
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
PATCHES="$ROOT/tests/checks/host_workarounds"
DEST=${DEST:-$ROOT/ai-tmp/swipl-src}

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

# The root for a patch is the tree it sits under in the patch directory,
# decided in patch-root.sh, which declare-host.sh reads too: the tree a patch
# is applied in and the tree it is later looked for in are one answer.
. "$HERE/patch-root.sh"

# Start from the pinned tree every run, so a re-run is not a second
# application of the same patch onto an already-patched file.
pristine_tree "$DEST"
applied=0
for patch in $(every_patch); do
    root=$(patch_root "$DEST" "$patch") || {
        printf 'fetch-source: %s has no %s for %s\n' \
            "$DEST" "$(patch_tree "$patch")" "$(basename "$patch")" >&2; exit 1; }
    git -C "$root" apply "$patch" || {
        printf 'fetch-source: %s no longer applies to %s; the pin moved\n' \
            "$(basename "$patch")" "${root#$DEST}" >&2; exit 1; }
    applied=$((applied + 1))
done
printf 'fetch-source: %s at %s, %s patch(es) applied, in %s\n' \
    "$(basename "$URL" .git)" "$TAG" "$applied" "$DEST"
