# Purpose: name the tree a host-workaround patch belongs to, for every script
#   that applies one or asks whether one is applied, so the rule has one
#   implementation.
#
# Sourced, never run. Two of the patches target packages/swipy, which is a
# submodule of swipl-devel with its own history, so `git apply` has to run in
# whichever tree CONTAINS the patch's first target. That is found rather than
# matched on a path prefix: a prefix rule is a second description of which
# files live in the submodule, and it is wrong the day one moves.
#
# Assumes: a POSIX shell, and a patch in `git diff` form whose first
#   `+++ b/<path>` line names a file the tree already has.
# Guarantees:
#   - patch_root SRC PATCH prints the first of SRC and SRC/packages/swipy that
#     holds the target, and returns 1 printing nothing when neither does or
#     the patch names no target
#     [tested: tools/pymetta-host/fetch_selftest.sh; commit=WORKTREE]

patch_root() {
    patch_root_target=$(grep -oE '^\+\+\+ b/[^ 	]+' "$2" | head -1 | sed 's|^+++ b/||')
    [ -n "$patch_root_target" ] || return 1
    for patch_root_candidate in "$1" "$1/packages/swipy"; do
        if [ -f "$patch_root_candidate/$patch_root_target" ]; then
            printf '%s\n' "$patch_root_candidate"
            return 0
        fi
    done
    return 1
}
