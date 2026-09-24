#!/bin/sh
# Purpose: prove tools/components.sh moves an existing component checkout to
#   a moved pin, the case every worktree meets when its superproject advances,
#   and still refuses a component somebody modified.
#
#   The fixture is a component repository with two commits and a superproject
#   mounting it, carrying its own copy of the script so the script's derived
#   root is the fixture. Before the fix, the second run refused with "comp has
#   modified tracked files" about files that were exactly the first pin's.
# Guarantees:
#   - a component cloned at one pin follows the superproject to a second pin:
#     HEAD is the new pin, a file the new pin changed reads its new content, a
#     file it added exists, a file it removed is gone, untracked build output
#     survives, and the run exits 0
#   - a component whose tracked file was modified is refused when its pin
#     moves, naming the component, and neither its commit nor the
#     modification moves
# Fails when: git is missing.
# Open Obligations:
#   To Do: None
#   Hacks: None
#   Future Enhancements: None
set -eu

command -v git >/dev/null

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
# One spelling of the bound, implemented in bounded.sh, so a killed run leaves
# no provisioning child behind.
bounded() { sh "$project_dir/tools/bounded.sh" "$@"; }
# The gate's scratch when a gate runs this, which tools/check.sh exports as
# TMPDIR beneath ai-tmp/check-runs and reclaims after a killed run
# (tests/checks/gate_scratch.sh); ai-tmp when run alone, never /tmp.
mkdir -p "$project_dir/ai-tmp"
fixture=$(mktemp -d "${TMPDIR:-$project_dir/ai-tmp}/components-pin.XXXXXX")
trap 'rm -rf "$fixture"' EXIT

# An identity and a branch name of the fixture's own, so the outcome does not
# depend on the reader's git configuration.
g() { git -c user.name=fixture -c user.email=fixture@example.invalid -c init.defaultBranch=main "$@"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

remote="$fixture/remote"
g init -q "$remote"
printf 'one\n' > "$remote/kept.txt"
printf 'gone\n' > "$remote/gone.txt"
g -C "$remote" add -A
g -C "$remote" commit -q -m A
first=$(git -C "$remote" rev-parse HEAD)
printf 'two\n' > "$remote/kept.txt"
git -C "$remote" rm -q gone.txt
printf 'new\n' > "$remote/new.txt"
g -C "$remote" add -A
g -C "$remote" commit -q -m B
second=$(git -C "$remote" rev-parse HEAD)

super="$fixture/super"
g init -q "$super"
git -C "$super" config user.name fixture
git -C "$super" config user.email fixture@example.invalid
mkdir -p "$super/tools"
cp "$project_dir/tools/components.sh" "$super/tools/components.sh"
printf '[submodule "comp"]\n\tpath = comp\n\turl = %s\n' "$remote" > "$super/.gitmodules"
pin() {
    git -C "$super" update-index --add --cacheinfo "160000,$1,comp"
    git -C "$super" add .gitmodules tools
    g -C "$super" commit -q -m "pin $1"
}
comp="$super/comp"

pin "$first"
bounded sh "$super/tools/components.sh" > "$fixture/first.out" 2>&1 ||
    fail "the first provision refused: $(cat "$fixture/first.out")"
[ "$(git -C "$comp" rev-parse HEAD)" = "$first" ] || fail "the clone is not at the first pin"
[ -f "$comp/gone.txt" ] || fail "the first pin's gone.txt is missing"
printf 'built\n' > "$comp/build.out"

pin "$second"
bounded sh "$super/tools/components.sh" > "$fixture/second.out" 2>&1 ||
    fail "the component did not follow its moved pin: $(cat "$fixture/second.out")"
[ "$(git -C "$comp" rev-parse HEAD)" = "$second" ] || fail "HEAD is not the moved pin"
[ "$(cat "$comp/kept.txt")" = two ] || fail "kept.txt does not read the moved pin's content"
[ -f "$comp/new.txt" ] || fail "the moved pin's new.txt is missing"
[ ! -e "$comp/gone.txt" ] || fail "gone.txt, which the moved pin removed, is still there"
[ "$(cat "$comp/build.out")" = built ] || fail "untracked build output did not survive the move"
echo "ok   a component follows its moved pin, and untracked output survives"

printf 'mine\n' > "$comp/kept.txt"
pin "$first"
if bounded sh "$super/tools/components.sh" > "$fixture/third.out" 2>&1; then
    fail "a modified component was moved to another pin"
fi
grep -q 'comp has modified tracked files' "$fixture/third.out" ||
    fail "the refusal did not name the modified component: $(cat "$fixture/third.out")"
[ "$(git -C "$comp" rev-parse HEAD)" = "$second" ] || fail "the refused component's commit moved"
[ "$(cat "$comp/kept.txt")" = mine ] || fail "the modification was overwritten"
echo "ok   a modified component is refused, and its commit and edit are kept"
