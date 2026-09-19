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
# Decides: batteries are FILESYSTEM snapshots, not git worktrees. This repo
#   has eight submodules (engine, lib, examples, ext, extensions/{python,
#   cmetta,node,mork}); `git worktree add` on the superproject does not
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
#   Three provisioners exist and each does a different job. components.sh makes
#   one checkout's components into repositories pinned where the superproject
#   pins them. worktree.sh makes a git worktree run the same CONFIGURATION as
#   the main checkout, checking components out at their pinned commits and
#   copying the build artefacts git does not track. Both work from COMMITTED
#   state, which is why neither can serve a gate run before a commit: 134
#   modified files and an untracked module are exactly what a pinned checkout
#   does not carry. This copies the working tree as it stands. Use
#   components.sh or worktree.sh to make a checkout valid; use this to ask what
#   a gate says about the tree you are editing right now.

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
# hide-only half. Protecting nothing costs nothing here, because a battery has
# no .git of its own, as the header says.
#
# The other entries stay `--exclude`, where BOTH halves are wanted: ai-tmp/
# holds this tree's own occupancy record, provenance and logs, and deleting
# those is how a run loses the evidence it was started to produce.
snapshot() {
    rsync -a -O --delete \
          --filter="H .git" \
          --exclude=ai-tmp/ --exclude='ai-tmp-*' \
          --exclude=__pycache__/ --exclude=.pytest_cache/ \
          --exclude=.mypy_cache/ --exclude=.ruff_cache/ \
          --exclude=node_modules/ --exclude='.venv*/' \
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

provision() {
    tree=$(tree_for "$1")
    if held=$(occupant "$tree"); then
        echo "battery $1 is running as PID $held; pick another index" >&2
        exit 1
    fi
    mkdir -p "$tree"
    snapshot "$ROOT/" "$tree/"
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
    drift=$(snapshot -in "$ROOT/" "$tree/")
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
