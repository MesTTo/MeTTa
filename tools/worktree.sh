#!/bin/sh
# Purpose: make a git worktree of this repository run the SAME configuration
#   the main checkout runs, by populating its components and copying the build
#   artefacts git does not track.
# Assumes:
#   - run from inside the worktree that needs setting up, and the main
#     checkout has been built (`sh build.sh`).
# Guarantees:
#   - after this, a fresh worktree HAS its components: they are submodules, so
#     `git worktree add` leaves one empty directory per component and nothing
#     in this script, nor any suite, has an engine to run until they are
#     checked out.
#   - after this, the artefact `extensions/mork/extension.pl` declares is there
#     and the MORK backend loads, so the suites gate the same configuration in
#     both trees [tested: tests/shell/test_worktree_configuration.sh].
#   - the worktree's artefacts are COPIES, so a build in the worktree cannot
#     change the main checkout's engine. They were symlinks, and the target
#     directory itself was one, until 2026-09-05: check.sh runs build.sh on
#     every gate, cargo's fingerprint is keyed on the crate's path so every
#     worktree rebuilt on its first gate, and `cargo build --release` wrote
#     the new libmork_ffi.so THROUGH the link into the shared checkout,
#     under every measurement any other agent had running. A symlinked FILE
#     is no safer: File::create and cp both truncate in place through it
#     [measured 2026-09-05: write through a file symlink reached the target;
#     only unlink-then-create did not; commit=7f3473649f8e54e6265f9b054cb8bdb4f6d1fdff]. A copy costs 2.5 MB
#     and a build in the worktree lands in the worktree
#     [tested: tests/shell/test_worktree_configuration.sh; commit=7f3473649f8e54e6265f9b054cb8bdb4f6d1fdff].
#   - after this, every package with a package-lock.json (extensions/node,
#     website) has the node_modules its lockfile names, installed by npm ci, so
#     the suites that drive Node run here as they do in the main checkout
#     [measured 2026-09-24: without them a fresh worktree failed two Node
#     suites on ERR_MODULE_NOT_FOUND].
#   - the C extension example's cbump and handle shared objects are built in
#     the worktree exactly as check.sh builds them, so a direct pytest run
#     here exercises the same integration surface instead of skipping it.
#   - every engine C artefact is built from the worktree's OWN source through
#     engine/build.sh, exactly as check.sh builds them, so benchmarks and
#     suites here measure the configuration the main gate measures: artifact
#     presence alone moves file-load 8704891 to 722264 with zero code change,
#     and a worktree without the artifact silently benchmarks the Prolog
#     fallback against C pins [measured 2026-08-25 on a detached scratch
#     worktree, bench.py --counter-only, same commit both ways;
#     commit=f48e9d8e6fa62eeff46082b6f8584cfe44bc5b93]. It builds them ALL
#     rather than naming reader.c, because a second artefact that this script
#     did not know about is the same hole with a new name: json-wire reads
#     178013 inferences with engine/json_codec.so and 169336779 without
#     [measured 2026-08-28; commit=ddc48b3f48247e3db4bb9758d25767f3793d623f].
# Fails when:
#   - the main checkout has not been built. That is reported, because a
#     worktree quietly running a SMALLER configuration than the tree it was
#     cut from is the failure this script exists to prevent: a fresh
#     worktree has no extensions/mork/mork_ffi/target/ and no
#     extensions/mork/mork_ffi/morklib.so, both are gitignored build output,
#     and the artefact need in `extensions/mork/extension.pl` reads their
#     absence as "this backend was not built" rather than as an error. Every
#     suite then passes while testing one backend fewer.
# Open Obligations:
#   To Do: None
#   Hacks: None
#   Future Enhancements: None
set -eu

# The repository root, which is this script's PARENT: these drivers live in
# tools/ so the root stays short enough to read at a glance.
HERE=$(cd -- "$(dirname -- "$0")/.." && pwd)

# The main checkout is the first line of `git worktree list`, which git
# guarantees is the primary one. Deriving it beats naming a path, so this
# keeps working wherever the repository lives.
# One spelling of the bound, implemented in bounded.sh, which every runner in
# this tree and a command typed by hand all reach.
bounded() { sh "$HERE/tools/bounded.sh" "$@"; }

MAIN=$(cd "$HERE" && git worktree list | head -1 | awk '{print $1}')

if [ "$MAIN" = "$HERE" ]; then
    echo "worktree.sh: this IS the main checkout; nothing to link" >&2
    exit 0
fi

# FIRST, because everything below reads files that live in a component:
# engine/build.sh, engine/main.pl and the chapter 19 examples are all inside
# one, and `git worktree add` leaves each component as an empty directory.
# components.sh is the one mechanism for that, here and in an existing checkout
# adopting the mount, and it needs no relaxation of git's transport policy
# because it clones and fetches directly rather than through the submodule
# machinery CVE-2022-39253 restricted.
bounded sh "$HERE/tools/components.sh" ||
    { echo "worktree.sh: the components could not be checked out; this worktree has no engine to run" >&2
      exit 1; }

copied=0
for artefact in extensions/mork/mork_ffi/target/release/libmork_ffi.so extensions/mork/mork_ffi/morklib.so; do
    product=${artefact#extensions/mork/mork_ffi/}
    source=''
    # This product does not travel with git, which is the whole reason this
    # script exists, so a main checkout sitting on an older commit than the
    # worktree holds it under whatever path that commit used. It has moved
    # twice already -- once when the crate went into its integration's folder,
    # again when the seat folders merged -- so the crate directory is FOUND
    # under the main checkout rather than named. Refusing to link across a
    # layout change would demand a rebuild of a multi-gigabyte crate for a
    # rename.
    for candidate in "$MAIN/$artefact" \
                     "$MAIN"/*/*/mork_ffi/"$product" \
                     "$MAIN"/mork_ffi/"$product"; do
        if [ -e "$candidate" ]; then
            source=$candidate
            break
        fi
    done
    if [ -z "$source" ]; then
        echo "worktree.sh: $MAIN has no $artefact; run 'sh build.sh' there" >&2
        echo "worktree.sh: without it this worktree runs one backend fewer" >&2
        exit 1
    fi
    mkdir -p "$(dirname "$HERE/$artefact")"
    # rm first: if an earlier run left a symlink here, cp would write THROUGH
    # it into the main checkout, which is the exact fault the copy prevents.
    rm -f "$HERE/$artefact"
    cp "$source" "$HERE/$artefact"
    copied=$((copied + 1))
done

echo "worktree.sh: copied $copied artefact(s) from $MAIN"

# The C extension example's shared objects are build output check.sh compiles
# on every run; a worktree used for DIRECT suite runs needs them too, or the
# example and its tests quietly skip. Same recipe, same tolerance for a
# missing toolchain.
if command -v swipl-ld >/dev/null 2>&1; then
    for source in "$HERE"/examples/ch19-*/*/*.c; do
        [ -f "$source" ] || continue
        directory=$(dirname "$source")
        unit=$(basename "$source" .c)
        ( cd "$directory" && bounded swipl-ld -shared -o "$unit" "$unit.c" ) ||
            echo "worktree.sh: the C example $unit failed to build" >&2
    done
else
    echo "worktree.sh: swipl-ld not found, the chapter 19 C examples will skip" >&2
fi

# The engine's C artefacts are gitignored build output, each with its own
# presence gate: parses run in C only while engine/reader.so exists beside
# reader.c, and JSON only while engine/json_codec.so exists beside
# json_codec.c. Build them from THIS tree's sources (not a link from the main
# checkout, whose sources may differ across commits) through the same
# engine/build.sh check.sh runs, so a worktree cannot end up one C artefact
# short of the tree it was cut from. A missing toolchain notes the fallback; a
# build that is attempted and fails is fatal.
if ! command -v swipl-ld >/dev/null 2>&1; then
    echo "worktree.sh: swipl-ld not found, this worktree runs the engine's Prolog implementations and its counters will not compare against pins measured with the C ones" >&2
elif ! command -v cc >/dev/null 2>&1 &&
     ! command -v gcc >/dev/null 2>&1 &&
     ! command -v clang >/dev/null 2>&1; then
    # swipl-ld drives a C compiler it does not carry; without one the build
    # fails, so this rung notes the fallback the way engine/build.sh does.
    echo "worktree.sh: swipl-ld found but no C compiler, this worktree runs the engine's Prolog implementations and its counters will not compare against pins measured with the C ones" >&2
else
    bounded sh "$HERE/engine/build.sh" ||
        { echo "worktree.sh: an engine C artefact failed to build; suites here would measure a Prolog fallback against pins measured with the C one" >&2
          exit 1; }
fi

# The Node dependencies are gitignored build input too, and the suites that
# drive Node fail on a missing module rather than skip, so a worktree without
# them reports defects its tree does not have [measured 2026-09-24: a fresh
# worktree at 3620aa797 failed test_the_site_build_refuses_without_the_browser_kit
# and test_the_node_term_table_and_codec_legs_follow_the_catalog on
# ERR_MODULE_NOT_FOUND for extensions/node/node_modules/esbuild]. Each package
# with a lockfile gets exactly what its lockfile names through `npm ci`,
# offline first so a warm cache costs no network. A missing npm is noted, as a
# missing C toolchain is; an install that is attempted and fails is fatal.
for package in extensions/node website; do
    [ -f "$HERE/$package/package-lock.json" ] || continue
    [ -d "$HERE/$package/node_modules" ] && continue
    if ! command -v npm >/dev/null 2>&1; then
        echo "worktree.sh: npm not found, $package has no node_modules and the suites driving it will fail" >&2
        continue
    fi
    bounded npm ci --prefer-offline --no-audit --no-fund --prefix "$HERE/$package" >/dev/null ||
        { echo "worktree.sh: npm ci failed in $package; the suites driving it would fail for want of its modules" >&2
          exit 1; }
done

# Warm the engine once so the Quick Load Format artifacts generate in a
# single process before any concurrent lane first-boots this tree
# (engine/qlf_boot.pl carries the staleness and recovery story).
bounded swipl -g halt -s "$HERE/engine/main.pl" -- extensions >/dev/null 2>&1 || true
