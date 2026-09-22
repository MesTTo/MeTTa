#!/bin/sh
# Purpose: produce the patched SWI-Prolog source tree the host wheel is built
#   from, from this repository alone.
#
# Assumes: git, and network for the clone. Reads tools/pymetta-host/swipl.pin
#   and every tests/checks/host_workarounds/*.patch.
# Guarantees:
#   - the tree is swipl-devel at the pinned COMMIT with every recorded patch
#     applied, or the script exits nonzero naming the patch that failed; a
#     half-patched tree never reaches a build
#   - each patch is applied at the root that actually contains its target, so
#     the two patches under packages/swipy land in the submodule rather than
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

# Start from the pinned tree every run, so a re-run is not a second
# application of the same patch onto an already-patched file.
git -C "$DEST" checkout --quiet --force -- .
git -C "$DEST/packages/swipy" checkout --quiet --force -- .

# The root for a patch is the tree that CONTAINS its first target, found
# rather than matched on a path prefix: a prefix rule is a second description
# of which files live in the submodule, and it is wrong the day one moves.
applied=0
for patch in "$PATCHES"/*.patch; do
    target=$(grep -oE '^\+\+\+ b/[^ 	]+' "$patch" | head -1 | sed 's|^+++ b/||')
    [ -n "$target" ] || { printf 'fetch-source: %s names no target\n' "$patch" >&2; exit 1; }
    root=
    for candidate in "$DEST" "$DEST/packages/swipy"; do
        [ -f "$candidate/$target" ] && { root=$candidate; break; }
    done
    [ -n "$root" ] || {
        printf 'fetch-source: no tree under %s holds %s, named by %s\n' \
            "$DEST" "$target" "$(basename "$patch")" >&2; exit 1; }
    git -C "$root" apply "$patch" || {
        printf 'fetch-source: %s no longer applies to %s; the pin moved\n' \
            "$(basename "$patch")" "${root#$DEST}" >&2; exit 1; }
    applied=$((applied + 1))
done
printf 'fetch-source: %s at %s, %s patch(es) applied, in %s\n' \
    "$(basename "$URL" .git)" "$TAG" "$applied" "$DEST"
