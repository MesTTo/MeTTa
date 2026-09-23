#!/bin/sh
# Purpose: provision, verify and run a gate in a battery tree that is a
#   byte-identical snapshot of this working tree, so a verdict names a
#   known state instead of whatever the tree happened to hold.
# Assumes: rsync 3.x, and a source tree reachable from this script's own
#   location through `git rev-parse --show-toplevel`.
# Guarantees: after `provision`, the battery tree differs from the source in
#   nothing outside EXCLUDES; `verify` exits nonzero and names every drifted
#   path otherwise; `run` refuses to start unless `verify` passes, so no
#   command reports a verdict about an unknown tree.
# Fails when: a battery tree is occupied by a live run (it refuses rather than
#   corrupting it), or the source has uncommitted submodule state a reader
#   later cannot reconstruct -- the provenance file records the revision but
#   the snapshot is of the WORKING tree, which is the point.
# Owns resources: the battery directory, its ai-tmp/battery.pid occupancy
#   record and its ai-tmp/battery.provenance. A tree whose recorded PID no
#   longer answers `kill -0` is free whatever the file says.
# Decides: batteries are FILESYSTEM snapshots, not git worktrees. Every
#   submodule this repo mounts, whatever .gitmodules currently lists, is a
#   checkout of its own; `git worktree add` on the superproject does not
#   materialise a submodule's worktree and `git stash create` does not capture
#   one, so the documented worktree recipe cannot produce a faithful copy here
#   and produced four mismatched A/B comparisons before this existed
#   [measured 2026-09-19: wt-battery-6 ran the Python tree from one revision
#   against an engine from another and reported 169 failures against a
#   4-failure baseline, every one of them an artifact of the mismatch].
#   A battery is therefore NOT a git repository: it holds no .git at any level
#   [measured 2026-09-20: none of wt-battery-6 through 11 has one], so a `git`
#   run inside one walks up and answers about the ENCLOSING checkout, which is
#   why a lane that shells out to git still works and why its answers are about
#   the source rather than the snapshot. Older indices can also carry a stale
#   registration in the superproject's admin area, left by a `git worktree add`
#   that predates this tool -- wt-battery-6 is registered at 14f5c43b5 with no
#   gitfile in the tree. Neither is authoritative: ai-tmp/battery.provenance is.
#   This is the ONLY provisioner of a BATTERY. components.sh and worktree.sh
#   are back beside it and do different jobs: components.sh turns a component
#   directory into a checkout of its own repository around the files already
#   there, and worktree.sh makes a git worktree. Neither produces a tree a
#   gate verdict can name, because a worktree of this superproject does not
#   materialise a submodule's working tree [measured 2026-09-21: tools/ holds
#   battery.sh, battery_selftest.sh, bench.sh, bounded.sh, build.sh, check.sh,
#   components.sh, run.sh, select-python.sh, test.sh and worktree.sh; the
#   header said the first two were all of it and that the other two did not
#   exist; commit=c6ed562a1a6f964aba906206f2558489b107dc24]. What this does is copy the working tree as it
#   stands, which is how to ask what a gate says about the tree you are
#   editing right now, uncommitted state included.

set -eu

# Deriving the root rather than counting directories up from $0: this script
# is run from every tree and from any working directory. BATTERY_SOURCE names a
# different tree to snapshot, which is what an A/B needs: two revisions into two
# batteries, compared against each other rather than against whatever a tree
# happened to hold.
# HOME is where batteries live and ROOT is what gets copied into them. They
# are the same tree in the ordinary case and must not be conflated: batteries
# belong inside the repository being worked in, so pointing BATTERY_SOURCE at
# another tree must not scatter batteries through it.
HOME_TREE=$(cd "$(dirname "$0")" && git rev-parse --show-toplevel)
ROOT=$(cd "${BATTERY_SOURCE:-$HOME_TREE}" && pwd)

# ONE string, expanded by both the copy and the comparison, so "identical"
# cannot come to mean two things. Keeping them in step is otherwise an
# invariant held by hand, and the first thing it got wrong was -O.
#
# -O omits directory mtimes. A directory's mtime is not content: it moves
# whenever anything inside it is written, and this script writes the excluded
# ai-tmp/ into the tree it just copied, so comparing dir times reported drift
# the checker had caused. A directory present on one side only is still
# reported, because that is a creation or a deletion rather than a time.
# A function rather than a string of flags, because the .git rule needs a
# quoted argument that word-splitting would tear in half.
#
# `--exclude=.git` would be two rules fused: HIDE it from the sender, so no
# .git is copied, and PROTECT it at the receiver, so none is ever deleted.
# Only the first is wanted. A gate run leaves git repositories behind -- the
# packaging fixtures write repos/<name>/.git -- and a protected .git keeps its
# parent non-empty for ever, so the next provision dies with `cannot delete
# non-empty directory: repos` and that index is unusable from then on
# [measured 2026-09-20: wt-battery-6 refused for exactly this]. `H` is the
# hide-only half, and `P /.git` is the one protection worth keeping: the
# battery's OWN registration, which battery_git_identity below puts there and
# which --delete would otherwise take away on the next provision. The rule is
# asymmetric because the two .git entries are different things -- one is the
# battery's identity and the rest are litter a test dropped.
#
# The split between the two halves below is the same question asked of each
# pattern: does protecting it at the receiver ever strand a directory?
#
# A protected entry keeps its parent non-empty and rsync will not remove a
# non-empty directory, so ANY protected entry inside a directory the source
# does not have strands that directory for ever. A run left
# .mutmut/mutants/**/__pycache__ behind and `.mutmut/` could then never be
# removed [measured 2026-09-20, the same shape as repos/<name>/.git above].
# rsync cannot say "protect this unless its parent is doomed", and `--force`
# does not help: in rsync 3.x it covers only replacing a directory with a
# non-directory, and adding it left the same three refusals.
#
# So the pure CACHES are hidden from the sender always, and protected at the
# receiver only when the question is DRIFT. The two callers ask different
# things of one tree. `provision` is making the battery identical, so it
# sweeps them and nothing is left to strand a doomed directory. `verify` is
# asking whether it still is, and a cache the battery's own run wrote is not
# drift -- reporting it is the false positive the -O case below exists to
# stop. Sweeping costs a recompile and nothing else, which is the right price
# for never stranding a tree.
#
# Those last two carry NO trailing slash, because battery_link_installs puts a
# SYMLINK where the source has a directory, and a pattern ending in `/` matches
# directories only: with one, rsync did not protect the link it had just been
# given and `verify` reported `*deleting extensions/node/node_modules` as drift
# [measured 2026-09-20].
#
# ai-tmp/, node_modules and .venv* keep both halves, because losing them
# changes WHAT RUNS rather than how fast: ai-tmp/ holds this tree's own
# occupancy record, provenance and logs, and the other two are the installed
# configuration a lane gates on, whose absence makes a suite skip and report
# green.
snapshot() {
    caches=$1
    shift
    # Prepended, so rsync reads them before the caller's own arguments and the
    # two paths. Component paths carry no spaces in this repository and the
    # glob-free word split is what keeps this a list of separate arguments.
    for component in $(battery_component_paths); do
        set -- "--filter=P /$component/.git" "$@"
    done
    rsync -a -O --delete \
          --filter="H .git" --filter="P /.git" \
          --filter="H __pycache__/" --filter="H .pytest_cache/" \
          --filter="H .mypy_cache/" --filter="H .ruff_cache/" \
          ${caches:+--filter="P __pycache__/"} \
          ${caches:+--filter="P .pytest_cache/"} \
          ${caches:+--filter="P .mypy_cache/"} \
          ${caches:+--filter="P .ruff_cache/"} \
          --exclude=ai-tmp/ --exclude='ai-tmp-*' \
          --exclude='ai-battery-*' \
          --exclude=node_modules --exclude='.venv*' \
          "$@"
}

usage() {
    cat >&2 <<USAGE
usage: tools/battery.sh provision <index>
       tools/battery.sh verify    <index>
       tools/battery.sh path      <index>
       tools/battery.sh run       <index> -- <command...>

BATTERY_SOURCE=<dir> snapshots that tree instead of this one. Batteries always
live under this repository, whatever the source is.

Makes ai-tmp/wt-battery-<index> a byte-identical snapshot of this working tree
and runs a gate inside it. 'run' provisions, verifies, then executes, keeping
the log at ai-tmp/battery-<index>.log INSIDE that tree where no sibling run
can reach it, and preserving the command's own exit status.
USAGE
    exit 2
}

tree_for() { echo "$HOME_TREE/ai-tmp/wt-battery-$1"; }

# A tree is occupied only while its recorded PID still answers. A stale record
# from a killed run must not block the tree forever.
occupant() {
    pidfile="$1/ai-tmp/battery.pid"
    [ -f "$pidfile" ] || return 1
    pid=$(head -1 "$pidfile" 2>/dev/null) || return 1
    case "$pid" in ''|*[!0-9]*) return 1 ;; esac
    kill -0 "$pid" 2>/dev/null || return 1
    echo "$pid"
}

# A battery has to be able to answer `git` about ITSELF. Without a .git it has
# none, and because a battery lives INSIDE the checkout, every git command and
# every root-marker walk run in one then answers about the enclosing tree. That
# is not a smaller verdict, it is a verdict about the wrong tree, and it reads
# as lane failures that have nothing to do with the code under test: on
# 2026-09-20 the submodules lane read the superproject's index, found no gitlink
# at ai-tmp/wt-battery-6/engine and refused all eight components; root-walks
# resolved a marker in the parent checkout; the llms selftest resolved a path
# that exists only under ai-tmp/. It fails the other way too, and that is worse,
# because a lane asking git about the parent can pass while the snapshot is
# broken.
#
# Seeded through a fresh path rather than created in place, because the battery
# already holds content by the time anyone wants this and `git worktree add`
# refuses a path that is not empty. Moving the gitfile in and repairing is what
# `git worktree repair` is for: it rewrites the admin directory's back-pointer
# to wherever the tree now is.
#
# The submodules stay filesystem copies -- `git worktree add` does not
# materialise one, which is the reason this tool exists at all -- but the
# superproject's index carries their gitlinks, which is what the lanes ask for
# [measured 2026-09-20: after this, `git -C <tree> ls-files -s engine` reads
# `160000 59a5bb2b9 0 engine`].
# Every name here is prefixed, because sh has no locals and this is called
# from a loop over `tree`: assigning a bare `tree` rewrote the caller's and the
# loop walked engine, then engine/lib, then engine/lib/examples, giving the
# first component an identity and none of the rest one [measured 2026-09-20].
battery_git_identity() {
    identity_source=$1
    identity_tree=$2
    [ -d "$identity_tree" ] || return 0
    # An identity that is ALREADY THIS REVISION is kept; one from an earlier
    # provision is replaced. Testing only that a .git exists was an existence
    # check where a consistency check belongs, and the failure it allows is
    # silent: re-provisioning ai-tmp/wt-battery-1 on 2026-09-22 gave a tree
    # whose files were 01287442c and whose git answered cf282de8f, so
    # `git ls-files` omitted every file added since and each owned() lane read
    # a short tree and passed. The worktree lane was the only one that said
    # anything, and it said its probe could not check components out.
    if [ -e "$identity_tree/.git" ]; then
        identity_want=$(git -C "$identity_source" rev-parse HEAD 2>/dev/null || echo want)
        identity_have=$(git -C "$identity_tree" rev-parse HEAD 2>/dev/null || echo have)
        [ "$identity_want" = "$identity_have" ] && return 0
        rm -rf "$identity_tree/.git"
        git -C "$identity_source" worktree prune >/dev/null 2>&1 || true
    fi
    identity_seed="$identity_tree.gitseed"
    rm -rf "$identity_seed"
    git -C "$identity_source" worktree add --detach "$identity_seed" HEAD \
        >/dev/null 2>&1 || return 0
    mv "$identity_seed/.git" "$identity_tree/.git"
    rm -rf "$identity_seed"
    git -C "$identity_source" worktree repair "$identity_tree" >/dev/null 2>&1 || true
}

# Read from .gitmodules rather than from `git submodule`, so it answers before
# anything is initialised and needs no work tree of its own.
battery_component_paths() {
    [ -f "$ROOT/.gitmodules" ] || return 0
    git -C "$ROOT" config --file "$ROOT/.gitmodules" \
        --get-regexp '^submodule\..*\.path$' 2>/dev/null |
        while read -r _ component; do printf '%s\n' "$component"; done
}

# An install directory is EXCLUDED from the snapshot, which keeps a battery's
# own copy from being swept -- and also means a battery that never had one
# never gets one. A lane that needs it then fails in the battery while passing
# in the checkout, which is a verdict about provisioning rather than about the
# tree: binding-selftest refused a whole gate with
# `ERR_MODULE_NOT_FOUND ... extensions/node/node_modules/esbuild/lib/main.js`
# while the same lane was ok in the source [measured 2026-09-20].
#
# Linked rather than copied, because these are install artifacts of a declared
# lockfile rather than code under test: the battery must READ the same
# dependencies, and copying hundreds of megabytes per provision to own a second
# identical set buys nothing. A battery that already has its own is left alone.
#
# A LINK is not its own, though: it is what an earlier provision left, and it
# names the source THAT provision read. The exclusion keeps rsync from touching
# it, so a battery provisioned from one BATTERY_SOURCE and then another went on
# running the first tree's dependencies under the second tree's code, the
# mismatched A/B this tool exists to prevent [measured 2026-09-23: battery 4,
# provisioned from the checkout and then from a copy whose swipl-wasm had been
# replaced, still resolved node_modules into the checkout and measured the
# checkout's swipl-wasm]. So every link that does not point into this source is
# removed before the links are made.
battery_link_installs() {
    install_tree=$1
    for install_link in $(cd "$install_tree" && find . -maxdepth 4 -type l -name node_modules \
                              -not -path '*/node_modules/*' 2>/dev/null); do
        case $(readlink "$install_tree/${install_link#./}") in
            "$ROOT"/*) ;;
            *) rm -f "$install_tree/${install_link#./}" ;;
        esac
    done
    for install_dir in $(cd "$ROOT" && find . -maxdepth 4 -type d -name node_modules \
                             -not -path '*/node_modules/*' 2>/dev/null); do
        install_source=$ROOT/${install_dir#./}
        install_target=$install_tree/${install_dir#./}
        [ -d "$install_source" ] || continue
        [ -e "$install_target" ] && continue
        mkdir -p "$(dirname "$install_target")"
        ln -s "$install_source" "$install_target" 2>/dev/null || true
    done
}

# A component's Rust manifest can name a source tree OUTSIDE this repository by
# a RELATIVE path, and a relative path resolves somewhere different at every
# tree depth. mork_ffi names ../../../../MORK, which is PyPeTTa1/MORK from the
# checkout, PeTTa/ai-tmp/MORK from a worktree one level down, and nothing at all
# from a battery one level below that, so `mork-rust` failed with `failed to
# read .../ai-tmp/MORK/kernel/Cargo.toml`: a verdict about where the tree sits
# rather than about the tree [measured 2026-09-20]. Linking them in the control's
# parent is the correction this repository already made once, on 2026-09-09.
#
# DERIVED from the manifests rather than naming MORK and PathMap, so a component
# that grows a third sibling is carried without editing this. Linked for the
# reason the installs are: these are sources owned elsewhere, large, and the
# battery must read the same ones rather than own a second copy.
#
# The link lands OUTSIDE the battery, in the directory the battery's own
# relative path points at, which is the source tree's ai-tmp. That is scratch,
# the snapshot excludes it, and one link there serves every battery beneath it.
battery_link_sibling_sources() {
    sibling_tree=$1
    for sibling_manifest in $(cd "$ROOT" && find . -maxdepth 4 -name Cargo.toml \
                                  -not -path '*/target/*' 2>/dev/null); do
        sibling_dir=$(dirname "${sibling_manifest#./}")
        for sibling_path in $(sed -n 's/.*path *= *"\([^"]*\)".*/\1/p' \
                                  "$ROOT/${sibling_manifest#./}" 2>/dev/null); do
            case $sibling_path in /*) continue ;; esac
            # The TOPMOST component the path escapes into, not the dependency
            # directory itself. A crate inheriting from `workspace.dependencies`
            # resolves its workspace root by walking UP from its own manifest, so
            # a link to the crate alone leaves that walk inside the battery's
            # scratch where no root exists [measured 2026-09-20: linking
            # MORK/kernel gave `error inheriting env_logger from workspace root
            # manifest ... failed to find a workspace root`, where linking MORK
            # carries the root with it].
            sibling_rest=$sibling_path
            while :; do
                case $sibling_rest in ../*) sibling_rest=${sibling_rest#../} ;; *) break ;; esac
            done
            sibling_climb=${sibling_path%"$sibling_rest"}
            sibling_entry=$sibling_climb${sibling_rest%%/*}
            # -m rather than -f, because the battery-side path is exactly the
            # one that does not exist yet and -f refuses to resolve it.
            sibling_source=$(readlink -m "$ROOT/$sibling_dir/$sibling_entry")
            sibling_target=$(readlink -m "$sibling_tree/$sibling_dir/$sibling_entry")
            # A path inside the repository is the component's own business and
            # the snapshot already carries it; outside is what a battery at a
            # different depth cannot reach.
            case $sibling_source in "$ROOT"/*) continue ;; esac
            [ -d "$sibling_source" ] || continue
            [ -e "$sibling_target" ] && continue
            mkdir -p "$(dirname "$sibling_target")"
            ln -s "$sibling_source" "$sibling_target" 2>/dev/null || true
        done
    done
}

provision() {
    tree=$(tree_for "$1")
    if held=$(occupant "$tree"); then
        echo "battery $1 is running as PID $held; pick another index" >&2
        exit 1
    fi
    mkdir -p "$tree"
    battery_git_identity "$ROOT" "$tree"
    snapshot "" "$ROOT/" "$tree/"
    # AFTER the snapshot, because the component directories have to exist and
    # the snapshot is what creates them on a first provision.
    for component in $(battery_component_paths); do
        battery_git_identity "$ROOT/$component" "$tree/$component"
    done
    battery_link_installs "$tree"
    battery_link_sibling_sources "$tree"
    mkdir -p "$tree/ai-tmp"
    {
        echo "source:   $ROOT"
        echo "revision: $(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
        echo "taken:    $(date -Is)"
        echo "note:     a snapshot of the WORKING tree, uncommitted state included."
        echo "          this tree holds no .git, so git run here answers about"
        echo "          $ROOT, not about this snapshot."
    } > "$tree/ai-tmp/battery.provenance"
}

verify() {
    tree=$(tree_for "$1")
    [ -d "$tree" ] || { echo "battery $1 does not exist; provision it first" >&2; exit 1; }
    drift=$(snapshot keep -in "$ROOT/" "$tree/")
    if [ -n "$drift" ]; then
        echo "battery $1 is NOT a copy of $ROOT; it differs in:" >&2
        echo "$drift" >&2
        exit 1
    fi
    cat "$tree/ai-tmp/battery.provenance" 2>/dev/null || true
}

[ $# -ge 2 ] || usage
command=$1; index=$2; shift 2
case "$command" in
    provision) provision "$index" ;;
    path)      tree_for "$index" ;;
    verify)    verify "$index" ;;
    run)
        [ "${1:-}" = "--" ] || usage
        shift
        [ $# -ge 1 ] || usage
        provision "$index"
        verify "$index" > /dev/null
        tree=$(tree_for "$index")
        log="$tree/ai-tmp/battery-$index.log"
        echo "$$" > "$tree/ai-tmp/battery.pid"
        git -C "$ROOT" rev-parse HEAD >> "$tree/ai-tmp/battery.pid" 2>/dev/null || true
        # Never piped: a pipeline reports the filter's status and a failed gate
        # would read as a pass. The log is read separately.
        ( cd "$tree" && "$@" ) > "$log" 2>&1 && status=0 || status=$?
        rm -f "$tree/ai-tmp/battery.pid"
        echo "battery $index: exit $status, log $log"
        exit "$status"
        ;;
    *) usage ;;
esac
