# Purpose: name the tree a host-workaround patch belongs to, for every script
#   that applies one, asks whether one is applied, or requires one, so the
#   rule has one implementation.
#
# Sourced, never run. A patch's paths are relative to the tree it was made
# in, so that tree is part of what the patch is, and it is written down once:
# by where the patch file sits under PATCHES, at that tree's own path inside
# swipl-devel. The two that patch janus live in packages/swipy/, because
# packages/swipy is a submodule of swipl-devel with its own history and
# `git apply` has to run inside it; every other patch sits at the top and
# applies to swipl-devel itself.
#
# The tree used to be FOUND, by looking for the patch's first target in each
# tree in turn. That needs a source tree to answer, and the requirement the
# engine boots against is generated with none, yet it has to leave out the
# patches only one host loads. Where the file sits answers both without a
# second description of which files live in the submodule.
#
# Assumes: a POSIX shell; PATCHES names the tests/checks/host_workarounds
#   directory, and its paths hold no whitespace.
# Guarantees:
#   - every_patch prints each *.patch under PATCHES, at any depth, one per
#     line in byte order, so every consumer walks one list in one order
#     [tested: tools/pymetta-host/fetch_selftest.sh; commit=WORKTREE]
#   - patch_tree PATCH prints the patch's tree relative to swipl-devel: an
#     empty line for a patch at the top, packages/swipy for one under
#     packages/swipy/ [tested: tools/pymetta-host/fetch_selftest.sh;
#     commit=WORKTREE]
#   - patch_root SRC PATCH prints SRC joined with that tree, and returns 1
#     printing nothing when SRC has no such directory, so a tree that lacks
#     the submodule is refused rather than patched in the wrong place
#     [tested: tools/pymetta-host/fetch_selftest.sh; commit=WORKTREE]

every_patch() {
    find "$PATCHES" -type f -name '*.patch' | LC_ALL=C sort
}

patch_tree() {
    patch_tree_rel=${1#"$PATCHES"/}
    case $patch_tree_rel in
        */*) printf '%s\n' "${patch_tree_rel%/*}" ;;
        *) printf '\n' ;;
    esac
}

patch_root() {
    patch_root_tree=$(patch_tree "$2")
    patch_root_dir=$1${patch_root_tree:+/$patch_root_tree}
    [ -d "$patch_root_dir" ] || return 1
    printf '%s\n' "$patch_root_dir"
}
