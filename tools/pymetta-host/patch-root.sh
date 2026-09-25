# Purpose: say which patches a host is built from, in the order they are
#   applied, and name the tree each belongs to, for every script that applies
#   one, asks whether one is applied, or requires one, so each rule has one
#   implementation; and put a source tree back to the pinned state the
#   patches apply to.
#
# Sourced, never run. `patch_layers ROOT` names the two directories the
# patches sit in, and a host is built from both, in this order:
#
#   PATCHES    tests/checks/host_workarounds, the patches the ledger
#              (docs/host-workarounds.md) carries, which a host must carry
#              for the engine to boot on it
#   HOST_ONLY  tools/pymetta-host/host-only, the patches a host is built with
#              that nothing requires, because nothing this tree runs meets
#              their defect, so the ledger gives them no entry
#
# The second is a layer on top of the first, as Buildroot applies a
# package's own patches and then each BR2_GLOBAL_PATCH_DIR's in turn, every
# directory in alphabetical order [source 2026-09-25T13:33:51+10:00:
# https://github.com/buildroot/buildroot/blob/e7bbe36be89f5917329fb33051d8f702ebffb402/docs/manual/patch-policy.adoc,
# "How patches are applied"]. A host-only patch may then be written on top of
# a ledger patch, and no ledger patch can depend on a host-only one.
#
# A patch's paths are relative to the tree it was made in, so that tree is
# part of what the patch is, and it is written down once: by where the patch
# file sits under its layer, at that tree's own path inside swipl-devel. The
# two that patch janus live in packages/swipy/, because they are written
# against that submodule's own tree and `git apply` has to run inside it;
# every other patch sits at the top of its layer and is written against the
# swipl-devel root, where a plain `git apply` also reaches the files of a
# submodule's working tree, as swi-uuid-static-half-unlinked.patch does for
# packages/clib.
#
# The tree used to be FOUND, by looking for the patch's first target in each
# tree in turn. That needs a source tree to answer, and the requirement the
# engine boots against is generated with none, yet it has to leave out the
# patches only one host loads. Where the file sits answers both without a
# second description of which files live in the submodule.
#
# Assumes: a POSIX shell, and paths under both layers that hold no
#   whitespace.
# Guarantees:
#   - every_patch prints the stack a host is built from, one patch per line:
#     each *.patch under PATCHES, then each under HOST_ONLY, at any depth and
#     in byte order within its layer, so every consumer walks one list in one
#     order; a layer with no directory holds no patches
#     [tested 2026-09-25T13:56:49+10:00: tools/pymetta-host/fetch_selftest.sh]
#   - patch_tree PATCH prints the patch's tree relative to swipl-devel, read
#     from where it sits under its layer: an empty line for a patch at the
#     top, packages/swipy for one under packages/swipy/
#     [tested 2026-09-25T13:56:49+10:00: tools/pymetta-host/fetch_selftest.sh]
#   - patch_root SRC PATCH prints SRC joined with that tree, and returns 1
#     printing nothing when SRC has no such directory, so a tree that lacks
#     the submodule is refused rather than patched in the wrong place
#     [tested: tools/pymetta-host/fetch_selftest.sh; commit=f2822e2aec654cdb9cdb3ea43899322f9a6770b5]
#   - pristine_tree SRC puts every tracked file of SRC and of each of its
#     submodules, at any depth, back at its checked-out commit and removes
#     every untracked file git does not ignore, so a second application of the
#     patches meets the tree the first did. The removal is for a patch that
#     creates a file, as swi-threadless-shared-table-private-per-engine.patch
#     creates tests/tabling/test_engine_shared.pl: a reset leaves the file,
#     and the next application refuses it as already there [tested:
#     tools/pymetta-host/fetch_selftest.sh; commit=5a05a59e92852a6e805b121153b65daff7378159]. Every submodule
#     rather than the ones a patch is filed under, because a patch at the top
#     reaches into a submodule's files too: resetting the top tree and
#     packages/swipy alone left swi-unicode-map-empty-result-aborts.patch
#     applied in packages/utf8proc, and a second fetch-source.sh run refused
#     it as a moved pin [measured 2026-09-24: an existing clone at V10.1.14
#     with every patch applied; tested: tools/pymetta-host/fetch_selftest.sh;
#     commit=630a20e49e4aa29b4fab2617e2ae6dc474a06189]

patch_layers() {
    PATCHES=$1/tests/checks/host_workarounds
    HOST_ONLY=$1/tools/pymetta-host/host-only
}

pristine_tree() {
    git -C "$1" checkout --quiet --force -- . &&
    git -C "$1" clean --quiet --force -d &&
    git -C "$1" submodule --quiet foreach --recursive \
        'git checkout --quiet --force -- . && git clean --quiet --force -d'
}

layer_patches() {
    [ ! -d "$1" ] || find "$1" -type f -name '*.patch' | LC_ALL=C sort
}

every_patch() {
    layer_patches "$PATCHES"
    layer_patches "$HOST_ONLY"
}

patch_tree() {
    case $1 in
        "$HOST_ONLY"/*) patch_tree_rel=${1#"$HOST_ONLY"/} ;;
        *) patch_tree_rel=${1#"$PATCHES"/} ;;
    esac
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
