#!/bin/sh
# Purpose: prove a git worktree of this repository runs the SAME backend
#   configuration the main checkout runs, once worktree.sh has linked the
#   build artefacts git does not track.
#
#   A worktree with its components checked out still has no
#   extensions/mork/mork_ffi/target/ and no extensions/mork/mork_ffi/morklib.so,
#   both gitignored build output, and extensions/mork/extension.pl reads their absence
#   as "this backend was not built" rather than as an error, exactly as it
#   should for a tree that never built it. The consequence for a worktree
#   is that every suite passes while testing one backend fewer, and nothing
#   says so. This test is the thing that says so.
# Guarantees:
#   - a fresh worktree does NOT load the MORK backend, and after
#     `sh tools/worktree.sh` it DOES, so the difference is demonstrated in both
#     directions rather than assumed.
# Fails when:
#   - the main checkout has not been built, which it reports and skips,
#     because "not built" is not the failure under test here.
# Open Obligations:
#   To Do: None
#   Hacks: None
#   Future Enhancements: None
set -eu

command -v git >/dev/null
command -v swipl >/dev/null

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)

# One spelling of the bound, implemented in bounded.sh, which every runner in
# this tree and a command typed by hand all reach.
bounded() { sh "$project_dir/tools/bounded.sh" "$@"; }

if [ ! -e "$project_dir/extensions/mork/mork_ffi/target/release/libmork_ffi.so" ]; then
    echo "skipped: the main checkout has no MORK build to compare against"
    exit 0
fi

probe=$(mktemp -d)
tree="$probe/worktree"
branch="worktree-config-probe-$$"
cleanup() {
    git -C "$project_dir" worktree remove --force "$tree" 2>/dev/null || true
    git -C "$project_dir" branch -D "$branch" 2>/dev/null || true
    rm -rf "$probe"
}
trap cleanup EXIT HUP INT TERM

git -C "$project_dir" worktree add --quiet -b "$branch" "$tree"

# The components are submodules, so `git worktree add` leaves one EMPTY
# directory per component and the worktree has no engine to probe at all.
# Checking them out is not the property under test -- the artefacts git does
# not track are -- so it happens before the first probe, and the before-state
# stays the precise one this test needs: an engine that is there, running one
# backend fewer. Without this the probe answers nothing and the test reports
# that it can no longer show its own difference.
cp "$project_dir/tools/components.sh" "$tree/components.sh"
bounded sh "$tree/components.sh" >/dev/null 2>&1 ||
    { echo "FAIL: the probe worktree's components could not be checked out" >&2; exit 1; }

# The probe asks the ENGINE whether the backend registered, rather than
# looking for a file, because the file being present is not the property
# that matters.
probe_backend() {
    bounded swipl --stack_limit=2g -q -g "
        consult('$1/engine/main.pl'),
        ( current_predicate(mork/3) -> writeln(loaded) ; writeln(absent) ),
        halt" -t 'halt(1)' -- extensions 2>/dev/null | tail -1
}

before=$(probe_backend "$tree")
if [ "$before" != absent ]; then
    echo "FAIL: a fresh worktree already reports the backend as '$before';" >&2
    echo "      this test can no longer show the difference it exists for" >&2
    exit 1
fi

cp "$project_dir/tools/worktree.sh" "$tree/worktree.sh"
bounded sh "$tree/worktree.sh" >/dev/null

after=$(probe_backend "$tree")
if [ "$after" != loaded ]; then
    echo "FAIL: after worktree.sh the backend is still '$after'," >&2
    echo "      so a worktree still runs a smaller configuration" >&2
    exit 1
fi

# The backend is one of the artefacts a worktree lacks; the engine's own C is
# the other, and it is checked the same way rather than by naming a file,
# because an artefact this test did not know about is the same hole with a new
# name. Skipped where nothing can build C at all, which is the one case
# worktree.sh reports rather than fails.
if command -v swipl-ld >/dev/null 2>&1 &&
   { command -v cc >/dev/null 2>&1 || command -v gcc >/dev/null 2>&1 ||
     command -v clang >/dev/null 2>&1; }; then
    for source in "$tree"/engine/*.c; do
        [ -f "$source" ] || continue
        unit=${source%.c}
        if [ ! -f "$unit.so" ]; then
            echo "FAIL: worktree.sh left $(basename "$unit").c without its .so," >&2
            echo "      so this worktree runs that unit's Prolog fallback while" >&2
            echo "      its counters are compared against pins measured in C" >&2
            exit 1
        fi
    done
fi

# The provisioned artefacts must be the worktree's OWN bytes. They were
# symlinks until 2026-09-05, and check.sh runs build.sh at the top of every
# gate: cargo rebuilt in each worktree (its fingerprint is keyed on the crate's
# path) and wrote the new libmork_ffi.so THROUGH the link into the main
# checkout, under every other agent's running measurement. A symlinked file is
# no safer than a symlinked directory, since File::create and cp truncate in
# place through it. So this appends one byte to the worktree's copy and asserts
# the main checkout's file did not change, which a link of either kind fails.
for product in target/release/libmork_ffi.so morklib.so; do
    main_file="$project_dir/extensions/mork/mork_ffi/$product"
    tree_file="$tree/extensions/mork/mork_ffi/$product"
    if [ -L "$tree_file" ]; then
        echo "FAIL: worktree.sh left $product as a symlink; a build here would" >&2
        echo "      write through it into the main checkout" >&2
        exit 1
    fi
    before=$(wc -c < "$main_file")
    printf 'x' >> "$tree_file"
    after=$(wc -c < "$main_file")
    if [ "$before" != "$after" ]; then
        echo "FAIL: writing to the worktree's $product changed the main checkout's" >&2
        echo "      ($before -> $after bytes); the artefact is shared, not copied" >&2
        exit 1
    fi
done

echo "ok: a worktree runs one backend fewer, and no engine C, until worktree.sh provisions it, and its artefacts are its own"
