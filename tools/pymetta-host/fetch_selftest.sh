#!/bin/sh
# Purpose: hold fetch-source.sh's root routing to the one thing it can get
#   wrong, without a network or a clone.
#
# Assumes: git and a writable ai-tmp. Plants its own trees and patches, so no
#   case here can pass or fail because swipl-devel moved.
# Guarantees:
#   - a patch is applied to the tree that CONTAINS its target, not to the
#     first tree tried
#   - a target no tree holds is refused rather than skipped
# Fails when: run where ai-tmp is not writable.
#
# Why only this. The clone, the pin check and the submodule checkout are all
# one git command each and fail loudly; the routing is the part with a choice
# in it, and the choice is wrong in a way that half-applies a patch set. Two
# of the nineteen real patches target packages/swipy, so a script that tried
# only the superproject would apply seventeen and refuse two, leaving a tree
# that builds and is missing fixes.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$HERE/../.." && pwd)
WORK=$ROOT/ai-tmp/fetch-selftest
failures=0

rm -rf "$WORK"; mkdir -p "$WORK/dest/packages/swipy/deep" "$WORK/patches"
printf 'outer\n' > "$WORK/dest/outer.txt"
printf 'inner\n' > "$WORK/dest/packages/swipy/deep/inner.txt"
( cd "$WORK/dest" && git init --quiet . && git add -A \
    && git -c user.email=t@t -c user.name=t commit --quiet -m plant )

# A patch per tree, each naming a file only that tree holds.
cat > "$WORK/patches/outer.patch" <<'PATCH'
--- a/outer.txt
+++ b/outer.txt
@@ -1 +1 @@
-outer
+outer patched
PATCH
cat > "$WORK/patches/inner.patch" <<'PATCH'
--- a/deep/inner.txt
+++ b/deep/inner.txt
@@ -1 +1 @@
-inner
+inner patched
PATCH
cat > "$WORK/patches/nowhere.patch" <<'PATCH'
--- a/absent/file.txt
+++ b/absent/file.txt
@@ -1 +1 @@
-x
+y
PATCH

# The routing rule itself, the one fetch-source.sh and declare-host.sh source,
# so this holds the decision they make rather than a copy of it.
. "$HERE/patch-root.sh"
route() { patch_root "$WORK/dest" "$1"; }

check() {
    want=$2
    if got=$(route "$WORK/patches/$1"); then got=${got#$WORK/dest}; got=${got:-/}
    else got=refused; fi
    if [ "$got" = "$want" ]; then return 0; fi
    printf '  %s: wanted %s, got %s\n' "$1" "$want" "$got"
    failures=$((failures + 1))
}

check outer.patch /
check inner.patch /packages/swipy
check nowhere.patch refused

# And the applications actually land where routing says.
git -C "$WORK/dest" apply "$WORK/patches/outer.patch"
grep -qx 'outer patched' "$WORK/dest/outer.txt" || {
    printf '  outer.patch did not reach outer.txt\n'; failures=$((failures + 1)); }
git -C "$WORK/dest/packages/swipy" apply "$WORK/patches/inner.patch"
grep -qx 'inner patched' "$WORK/dest/packages/swipy/deep/inner.txt" || {
    printf '  inner.patch did not reach packages/swipy/deep/inner.txt\n'; failures=$((failures + 1)); }

rm -rf "$WORK"
printf 'fetch-selftest: %s defect(s) over 5 cases\n' "$failures"
[ "$failures" -eq 0 ]
