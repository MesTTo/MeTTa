#!/bin/sh
# Purpose: hold fetch-source.sh's root routing and patch stack to the things
#   they can get wrong, without a network or a clone.
#
# Assumes: git and a writable ai-tmp. Plants its own trees and patches, so no
#   case here can pass or fail because swipl-devel moved.
# Guarantees:
#   - a patch is applied to the tree it sits under in its layer: a patch at
#     the top of the ledger's or the host-only directory to the source root,
#     one under packages/swipy/ to that submodule
#   - a patch whose tree the source lacks is refused rather than applied
#     somewhere else
#   - every_patch lists the ledger's patches and then the host-only ones, at
#     every depth, in byte order within each layer, whatever the byte order
#     of the two directories' names; a layer with no directory lists nothing;
#     and a host-only patch written on top of a ledger patch applies in that
#     order
# Fails when: run where ai-tmp is not writable.
#
# Why only this. The clone, the pin check and the submodule checkout are all
# one git command each and fail loudly; the routing is the part with a choice
# in it, and the choice is wrong in a way that half-applies a patch set. Two
# of the nineteen real patches target packages/swipy, so a script that tried
# only the superproject would apply seventeen and refuse two, leaving a tree
# that builds and is missing fixes. The order of the two layers is the other
# choice, and a host-only patch built on a ledger patch refuses in any other.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$HERE/../.." && pwd)
WORK=$ROOT/ai-tmp/fetch-selftest
failures=0; cases=0

rm -rf "$WORK"; mkdir -p "$WORK/dest/packages/swipy/deep" "$WORK/patches/packages/swipy" \
    "$WORK/patches/packages/absent" "$WORK/a-host-only/packages/swipy"
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
cat > "$WORK/patches/packages/swipy/inner.patch" <<'PATCH'
--- a/deep/inner.txt
+++ b/deep/inner.txt
@@ -1 +1 @@
-inner
+inner patched
PATCH
cat > "$WORK/patches/packages/absent/nowhere.patch" <<'PATCH'
--- a/absent/file.txt
+++ b/absent/file.txt
@@ -1 +1 @@
-x
+y
PATCH
# The host-only layer, at a directory that sorts BEFORE the ledger's, with a
# top patch whose name sorts before every ledger patch's: listed in byte
# order of whole paths it would come first, so only the layer order puts it
# after the ledger. It is written on top of outer.patch, so it also refuses
# to apply in any other order.
cat > "$WORK/a-host-only/0-on-outer.patch" <<'PATCH'
--- a/outer.txt
+++ b/outer.txt
@@ -1 +1 @@
-outer patched
+outer patched twice
PATCH
cat > "$WORK/a-host-only/packages/swipy/inner-only.patch" <<'PATCH'
--- a/deep/inner.txt
+++ b/deep/inner.txt
@@ -1 +1 @@
-inner patched
+inner patched twice
PATCH

# The routing rule and the stack themselves, the ones fetch-source.sh and
# declare-host.sh source, so this holds the decisions they make rather than
# a copy of them.
. "$HERE/patch-root.sh"
PATCHES=$WORK/patches
HOST_ONLY=$WORK/a-host-only
route() { patch_root "$WORK/dest" "$1"; }

check() {
    cases=$((cases + 1))
    want=$2
    if got=$(route "$WORK/$1"); then got=${got#$WORK/dest}; got=${got:-/}
    else got=refused; fi
    if [ "$got" = "$want" ]; then return 0; fi
    printf '  %s: wanted %s, got %s\n' "$1" "$want" "$got"
    failures=$((failures + 1))
}

check patches/outer.patch /
check patches/packages/swipy/inner.patch /packages/swipy
check patches/packages/absent/nowhere.patch refused
check a-host-only/0-on-outer.patch /
check a-host-only/packages/swipy/inner-only.patch /packages/swipy

# The walk every consumer shares finds the nested patches too, the ledger's
# layer first and each layer in byte order.
cases=$((cases + 1))
listed=$(every_patch | sed "s|^$WORK/||" | tr '\n' ' ')
want='patches/outer.patch patches/packages/absent/nowhere.patch patches/packages/swipy/inner.patch a-host-only/0-on-outer.patch a-host-only/packages/swipy/inner-only.patch '
[ "$listed" = "$want" ] || {
    printf '  every_patch listed [%s], wanted [%s]\n' "$listed" "$want"; failures=$((failures + 1)); }

# A layer whose directory is absent holds no patches, rather than failing the
# walk, so a checkout without host-only patches still lists the ledger's.
cases=$((cases + 1))
listed=$(HOST_ONLY=$WORK/absent-layer; every_patch | sed "s|^$WORK/||" | tr '\n' ' ')
want='patches/outer.patch patches/packages/absent/nowhere.patch patches/packages/swipy/inner.patch '
[ "$listed" = "$want" ] || {
    printf '  every_patch with no host-only directory listed [%s], wanted [%s]\n' \
        "$listed" "$want"; failures=$((failures + 1)); }

# And the applications actually land where routing says.
cases=$((cases + 1))
git -C "$WORK/dest" apply "$WORK/patches/outer.patch"
grep -qx 'outer patched' "$WORK/dest/outer.txt" || {
    printf '  outer.patch did not reach outer.txt\n'; failures=$((failures + 1)); }
cases=$((cases + 1))
git -C "$WORK/dest/packages/swipy" apply "$WORK/patches/packages/swipy/inner.patch"
grep -qx 'inner patched' "$WORK/dest/packages/swipy/deep/inner.txt" || {
    printf '  inner.patch did not reach packages/swipy/deep/inner.txt\n'; failures=$((failures + 1)); }

# The whole stack, applied the way fetch-source.sh applies it, from the
# pinned tree: every patch whose tree exists, in every_patch's order, lands,
# the host-only patches on top of the ledger's they are written against.
cases=$((cases + 1))
pristine_tree "$WORK/dest"
for patch in $(every_patch); do
    root=$(route "$patch") || continue
    git -C "$root" apply "$patch" 2>/dev/null || {
        printf '  %s did not apply in every_patch order\n' "${patch#$WORK/}"
        failures=$((failures + 1)); }
done
grep -qx 'outer patched twice' "$WORK/dest/outer.txt" &&
    grep -qx 'inner patched twice' "$WORK/dest/packages/swipy/deep/inner.txt" || {
    printf '  the stack did not leave both host-only patches on top of the ledger'"'"'s\n'
    failures=$((failures + 1)); }

# A re-run starts from the pinned tree: a patch at the top that reaches into a
# submodule's files, as swi-uuid-static-half-unlinked.patch does into
# packages/clib, applies again after pristine_tree, because the reset reaches
# every submodule and not only the one a patch is filed under.
cases=$((cases + 1))
mkdir -p "$WORK/sub" "$WORK/stack/packages/swipy"
printf 'deep\n' > "$WORK/sub/deep.txt"
( cd "$WORK/sub" && git init --quiet . && git add -A \
    && git -c user.email=t@t -c user.name=t commit --quiet -m plant )
printf 'top\n' > "$WORK/stack/top.txt"
printf 'inner\n' > "$WORK/stack/packages/swipy/inner.txt"
( cd "$WORK/stack" && git init --quiet . && git add -A \
    && git -c protocol.file.allow=always submodule --quiet add "$WORK/sub" packages/other \
    && git -c user.email=t@t -c user.name=t commit --quiet -m plant )
cat > "$WORK/reach.patch" <<'PATCH'
--- a/packages/other/deep.txt
+++ b/packages/other/deep.txt
@@ -1 +1 @@
-deep
+deep patched
PATCH
git -C "$WORK/stack" apply "$WORK/reach.patch"
pristine_tree "$WORK/stack"
git -C "$WORK/stack" apply "$WORK/reach.patch" 2>/dev/null || {
    printf '  a patch reaching into a submodule did not apply again after pristine_tree\n'
    failures=$((failures + 1)); }

# A patch that CREATES a file applies again too: the reset puts tracked files
# back and leaves an untracked one, which git apply then refuses as already
# there, so the removal of untracked files is what makes the re-run work.
cases=$((cases + 1))
cat > "$WORK/create.patch" <<'PATCH'
--- /dev/null
+++ b/created/by-patch.txt
@@ -0,0 +1 @@
+created
PATCH
git -C "$WORK/stack" apply "$WORK/create.patch"
pristine_tree "$WORK/stack"
[ ! -e "$WORK/stack/created/by-patch.txt" ] || {
    printf '  pristine_tree left the file a patch created\n'; failures=$((failures + 1)); }
git -C "$WORK/stack" apply "$WORK/create.patch" 2>/dev/null || {
    printf '  a patch that creates a file did not apply again after pristine_tree\n'
    failures=$((failures + 1)); }

rm -rf "$WORK"
printf 'fetch-selftest: %s defect(s) over %s cases\n' "$failures" "$cases"
[ "$failures" -eq 0 ]
