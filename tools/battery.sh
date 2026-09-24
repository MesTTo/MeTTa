#!/bin/sh
# Purpose: provision, verify and run a gate in a battery tree that is a
#   byte-identical snapshot of this working tree, so a verdict names a
#   known state instead of whatever the tree happened to hold.
# Assumes: rsync 3.x, and a source tree reachable from this script's own
#   location through `git rev-parse --show-toplevel`.
# Guarantees: after `provision`, the battery tree differs from the source in
#   nothing outside EXCLUDES, and with BATTERY_KEEP set in nothing outside
#   EXCLUDES and the paths it does not name that differ from their
#   repository's base, which hold the base's content. A repository's base is
#   its HEAD, except that under BATTERY_KEEP a component no kept path equals,
#   contains or sits inside has the commit its parent's base records at its
#   path, and the git of every repository in the battery answers its base
#   [tested: tools/battery_selftest.sh;
#   commit=6ab321d7d488f95bc7cc9f60cc2f803f5018398c]; `verify` exits
#   nonzero and names every drifted path otherwise;
#   `run` refuses to start unless `verify` passes, so no command reports a
#   verdict about an unknown tree, and runs its command with git's search for
#   a repository stopped at the battery's parent, so no git command in it
#   reaches the checkout the battery sits inside. `run` naming no index takes
#   the lowest one no run holds, so a finished battery is reused and the pool
#   grows only to the most runs in flight at once; `prune <hours>` removes the
#   batteries no run holds, no process is inside and nothing has touched for
#   that long.
# Fails when: a battery tree is occupied by a live run (it refuses rather than
#   corrupting it); a repository's battery cannot be given a git identity of
#   its own (it refuses rather than run a command git would hand to the
#   enclosing checkout); or the source has uncommitted submodule state a
#   reader later cannot reconstruct -- the provenance file records the
#   revision but the snapshot is of the WORKING tree, which is the point.
# Owns resources: the battery directory, its ai-tmp/battery.pid occupancy
#   record, its ai-tmp/battery.provenance and, restricted, its
#   ai-tmp/battery.restricted. A tree whose recorded PID no longer answers
#   `kill -0` is free whatever the file says. battery-identity.lock in each
#   repository's common git directory is held only while an identity is made.
# Decides: batteries are FILESYSTEM snapshots, not git worktrees. Every
#   submodule this repo mounts, whatever .gitmodules currently lists, is a
#   checkout of its own; `git worktree add` on the superproject does not
#   materialise a submodule's worktree and `git stash create` does not capture
#   one, so the documented worktree recipe cannot produce a faithful copy here
#   and produced four mismatched A/B comparisons before this existed
#   [measured 2026-09-19: wt-battery-6 ran the Python tree from one revision
#   against an engine from another and reported 169 failures against a
#   4-failure baseline, every one of them an artifact of the mismatch].
#   A battery's git is the identity battery_git_identity gives it: a linked
#   worktree of the source's repository, and of each component's, at that
#   repository's base (battery_bases), over the snapshot's files, so git run
#   in a battery answers about the battery. `run` refuses a battery of a repository that does not,
#   and stops git's search for a repository at the battery's parent, so a
#   battery that lost its identity answers nothing instead of handing its
#   command the enclosing checkout. ai-tmp/battery.provenance names what the
#   snapshot holds.
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
# A compiled Prolog artifact, `*.qlf`, is a cache of the same kind with one
# difference that makes copying it WRONG rather than merely slow: SWI records
# the directory a .qlf was compiled in and loads one found anywhere else as
# MOVED, charging every process that loads it 8 inferences per recorded
# source, and the qlf-provenance lane refuses such an artifact outright. A
# battery handed the source's artifacts read 83 twin findings, 60 of them
# exactly +8, on an otherwise identical tree [measured 2026-09-24:
# lib/lib_import/lib_import.qlf written in wt-merge by an import probe]. So
# the source's are never copied, provision sweeps the battery's, and the
# gate's own warm-up compiles a fresh set in place before any lane boots.
#
# `.agenticmind/` takes the caches' two halves for a reason of its own. It is
# the reasoning record's lock and session directory for this machine, ignored
# by git, touched by every write any session makes to the record, and read by
# no lane; the record itself is the tracked agenticmind.json, which is copied
# like any tracked file. A copy of the directory is stale as soon as it is
# taken, so `run`'s verify read one lock's new mtime as drift and refused the
# battery while other sessions were writing the record [measured 2026-09-24:
# battery 2, `>f..t......` on .agenticmind/locks/99fbbe16….lock].
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
          --filter="H *.qlf" --filter="H .agenticmind/" \
          ${caches:+--filter="P __pycache__/"} \
          ${caches:+--filter="P .pytest_cache/"} \
          ${caches:+--filter="P .mypy_cache/"} \
          ${caches:+--filter="P .ruff_cache/"} \
          ${caches:+--filter="P *.qlf"} \
          ${caches:+--filter="P .agenticmind/"} \
          --exclude=ai-tmp/ --exclude='ai-tmp-*' \
          --exclude='ai-battery-*' \
          --exclude=node_modules --exclude='.venv*' \
          "$@"
}

usage() {
    cat >&2 <<USAGE
usage: tools/battery.sh run       [<index>] -- <command...>
       tools/battery.sh provision <index>
       tools/battery.sh verify    <index>
       tools/battery.sh path      <index>
       tools/battery.sh prune     <hours>

'run' with no index takes the lowest index no other run holds, reusing a
finished battery, and prints the index and the log path when it ends. Name an
index only when a comparison needs two particular batteries. 'prune' removes
this checkout's batteries that no run holds, no process is inside and nothing
has touched for <hours>.

BATTERY_SOURCE=<dir> snapshots that tree instead of this one. Batteries always
live under this repository, whatever the source is.

BATTERY_KEEP='<path> ...' restricts the battery to the committed tree plus the
uncommitted state of those paths, relative to the repository root and allowed
to reach into a component. A component a kept path equals, contains or sits
inside is carried at its own HEAD; every other one holds the commit its
parent's tree pins, so its unpinned commits stay out. Every other uncommitted
change is put back. BATTERY_KEEP= (set to nothing) gives the committed tree
alone. Pass the same value to verify.

Makes ai-tmp/wt-battery-<index> a byte-identical snapshot of this working tree
and runs a gate inside it. 'run' provisions, verifies, then executes, keeping
the log at ai-tmp/battery-<index>.log INSIDE that tree where no sibling run
can reach it, and preserving the command's own exit status.
USAGE
    exit 2
}

tree_for() { echo "$HOME_TREE/ai-tmp/wt-battery-$1"; }

# A tree is occupied only while its recorded PID still answers. A stale record
# from a killed run must not block the tree forever, and the claimant's own
# record, written at the claim below, is not somebody else's occupancy.
occupant() {
    pidfile="$1/ai-tmp/battery.pid"
    [ -f "$pidfile" ] || return 1
    pid=$(head -1 "$pidfile" 2>/dev/null) || return 1
    case "$pid" in ''|*[!0-9]*) return 1 ;; esac
    [ "$pid" = "$$" ] && return 1
    kill -0 "$pid" 2>/dev/null || return 1
    echo "$pid"
}

# Claimed before anything is written and held until the command ends. The
# occupancy check above ran inside provision while `run` wrote its PID only
# after provisioning and verifying, so the longest window, the copy and the
# component identities, was unclaimed: two runs that picked one free index at
# once both passed the check and provisioned the tree together, and each one's
# rsync --delete or seed removal took the other's component identity out from
# under it [the record, 2026-09-24: "mv: cannot stat
# .../extensions/python.gitseed/.git" in battery 2, and a seed left holding
# only its gitfile in battery 75]. flock(1) is released by the kernel when the
# holder exits, so a killed run leaves nothing to clear, which a PID record
# cannot promise; the PID record is still written, at the claim, for anyone
# reading occupancy from it. The lock is a file beside the tree rather than in
# it, because the tree may not exist yet and the snapshot owns its contents.
claim() {
    mkdir -p "$HOME_TREE/ai-tmp"
    exec 9>"$HOME_TREE/ai-tmp/wt-battery-$1.lock"
    flock -n 9 || {
        echo "battery $1 is claimed by another run; pick another index" >&2
        exit 1
    }
}

# The lowest index no run holds, claimed on descriptor 9 for the rest of this
# process exactly as claim takes a named one. Callers used to name their own,
# each settling on a range of its own (31 to 40, 99 to 125), so batteries only
# accumulated: 228 trees holding 461 GiB under Dev on 2026-09-24, most idle
# for days, where the runs actually in flight never needed more than about
# twenty. Taking the lowest free index reuses a finished battery, whose next
# provision copies only what changed, so the pool grows to the most runs ever
# in flight at once and no further. It sets `index` rather than printing it,
# because a command substitution's subshell would release the lock on exit.
allocate() {
    mkdir -p "$HOME_TREE/ai-tmp"
    index=1
    while :; do
        exec 9>"$HOME_TREE/ai-tmp/wt-battery-$index.lock"
        if flock -n 9; then
            occupant "$(tree_for "$index")" >/dev/null || return 0
        fi
        index=$((index + 1))
    done
}

# Removes each of this checkout's batteries that no run holds, whose recorded
# PID is gone, that no process is working inside, and that nothing has touched
# for the given number of hours. How long a finished battery's log is still
# wanted is known only to whoever will read it, so the window is an argument
# and never a default. A removed tree's worktree identities are unregistered
# under the per-repository lock battery_git_identity takes, so a prune cannot
# delete the admin entry of a seed a concurrent provision is moving
# [c-gp-seed-race]. Paths are taken to hold no whitespace, as elsewhere here.
prune() {
    case ${1:-} in ''|*[!0-9]*) usage ;; esac
    prune_minutes=$(($1 * 60))
    # Another user's process, PID 1 included, refuses readlink; it cannot be
    # working inside this user's battery, so its refusal is skipped, not fatal.
    prune_cwds=$(for prune_proc in /proc/[0-9]*; do
                     readlink "$prune_proc/cwd" 2>/dev/null || true
                 done)
    prune_count=0
    for prune_tree in "$HOME_TREE"/ai-tmp/wt-battery-*; do
        [ -d "$prune_tree" ] || continue
        prune_index=${prune_tree##*/wt-battery-}
        case $prune_index in *.gitseed) continue ;; esac
        exec 9>"$HOME_TREE/ai-tmp/wt-battery-$prune_index.lock"
        flock -n 9 || continue
        occupant "$prune_tree" >/dev/null && continue
        prune_busy=
        for prune_cwd in $prune_cwds; do
            case $prune_cwd in "$prune_tree"|"$prune_tree"/*) prune_busy=yes ;; esac
        done
        [ -z "$prune_busy" ] || continue
        [ -z "$(find "$prune_tree" "$prune_tree/ai-tmp" -maxdepth 1 \
                     -mmin "-$prune_minutes" -print -quit 2>/dev/null)" ] || continue
        rm -rf -- "${prune_tree:?}" "${prune_tree:?}.gitseed"
        rm -f -- "$HOME_TREE/ai-tmp/wt-battery-$prune_index.lock"
        prune_count=$((prune_count + 1))
        echo "pruned battery $prune_index"
    done
    exec 9>&-
    for prune_repository in . $(battery_component_paths); do
        battery_repository_root "$ROOT/$prune_repository" || continue
        prune_common=$(git -C "$ROOT/$prune_repository" rev-parse --path-format=absolute \
                           --git-common-dir)
        ( flock 8 && git -C "$ROOT/$prune_repository" worktree prune ) \
            8>"$prune_common/battery-identity.lock"
    done
    echo "pruned $prune_count batteries idle for over $1 hours"
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
# Whether a directory is the top of a repository of its own. A directory that
# merely sits inside one is not: `git -C` walks up from it, so a battery given
# an identity from such a source became a worktree of the ENCLOSING repository
# at that repository's HEAD, a git that knew none of the battery's files.
battery_repository_root() {
    [ "$(git -C "$1" rev-parse --show-toplevel 2>/dev/null)" = "$(cd "$1" && pwd -P)" ]
}

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
    #
    # A source that is not a repository has no identity to give. One that IS a
    # repository must give one, and failing to is fatal rather than skipped: a
    # battery without its own .git hands every git command run in it to the
    # checkout it sits inside, and on 2026-09-24 at 11:06:03 a `git reset
    # --hard HEAD` meant for battery 33 reverted every uncommitted file in
    # wt-merge that way [the record, c-gp-seed-race and the reset's reflog].
    #
    # The sequence runs under one lock per repository, held on the common git
    # directory every worktree of it shares, so two provisions never interleave
    # prune, add and move. The back-link a moved worktree needs is written
    # directly, to worktrees/<id>/gitdir, the file gitrepository-layout(5)
    # documents as "the absolute path back to the .git file that points to
    # here". `git worktree repair` wrote the same file but, run in the main
    # worktree, also rewrites the gitfile of every linked worktree still
    # pointing at it, which is how battery 34's provision broke battery 33's
    # seed between its move and its own repair [c-gp-seed-race].
    # A tree once provisioned from a repository keeps that identity when the
    # same index is provisioned from a source that is not one, so git in it
    # would answer about the earlier repository's worktree; it is removed, and
    # the discovery ceiling then leaves git in the battery answering nothing.
    battery_repository_root "$identity_source" || {
        rm -rf -- "${identity_tree:?}/.git"
        return 0
    }
    # The commit the identity names: the base battery_bases gives the
    # repository as $3, or the source's own HEAD. A base the repository does not
    # hold is a pin nobody fetched, and the refusal names both ways out.
    identity_want=${3:-$(git -C "$identity_source" rev-parse HEAD)}
    git -C "$identity_source" cat-file -e "$identity_want^{commit}" 2>/dev/null || {
        echo "battery: $identity_source does not hold $identity_want, the commit" \
             "its parent pins; fetch it there, or name the component in BATTERY_KEEP" >&2
        exit 1
    }
    identity_common=$(git -C "$identity_source" rev-parse --path-format=absolute \
                          --git-common-dir)
    (
        flock 8
        if [ -e "$identity_tree/.git" ]; then
            identity_have=$(git -C "$identity_tree" rev-parse HEAD 2>/dev/null || echo have)
            [ "$identity_want" = "$identity_have" ] && exit 0
            rm -rf "$identity_tree/.git"
            git -C "$identity_source" worktree prune >/dev/null 2>&1 || true
        fi
        identity_seed="$identity_tree.gitseed"
        rm -rf "$identity_seed"
        git -C "$identity_source" worktree add --detach "$identity_seed" "$identity_want" \
            >/dev/null 2>&1 || {
            echo "battery: cannot give $identity_tree a git identity at $identity_want" \
                 "from $identity_source" >&2
            exit 1
        }
        mv "$identity_seed/.git" "$identity_tree/.git"
        rm -rf "$identity_seed"
        identity_admin=$(sed -n 's/^gitdir: //p' "$identity_tree/.git")
        [ -n "$identity_admin" ] && [ -d "$identity_admin" ] || {
            echo "battery: $identity_tree/.git names no worktree admin directory" >&2
            exit 1
        }
        printf '%s\n' "$identity_tree/.git" > "$identity_admin/gitdir"
    ) 8>"$identity_common/battery-identity.lock" || exit 1
}

# Read from .gitmodules rather than from `git submodule`, so it answers before
# anything is initialised and needs no work tree of its own. Every component's
# own .gitmodules is read too, parents before children, because a component
# can mount one of its own: the seat's twins repository,
# extensions/python/examples/language-feature-examples, is declared only in
# the seat's .gitmodules, and reading the superproject's alone left it with no
# identity, no protected .git and its uncommitted edits outside BATTERY_KEEP's
# reach [the record, 2026-09-24: battery 121 carried another session's five
# uncommitted twins under BATTERY_KEEP='']. Paths are relative to ROOT.
battery_component_paths() {
    battery_components_under "$ROOT" ""
}

battery_components_under() {
    [ -f "$1/.gitmodules" ] || return 0
    git -C "$1" config --file "$1/.gitmodules" \
        --get-regexp '^submodule\..*\.path$' 2>/dev/null |
        while read -r _ component; do
            printf '%s\n' "$2$component"
            battery_components_under "$1/$component" "$2$component/"
        done
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
        # Only into a directory the battery holds. One it lacks is excluded
        # scratch, where three of wt-merge's five installs sit
        # (ai-tmp/wasm-libs/seat among them), or a component battery_restrict
        # dropped because the committed tree has none, and a link would
        # recreate that component for verify to refuse [measured 2026-09-24].
        [ -d "$(dirname "$install_target")" ] || continue
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

# BATTERY_KEEP restricts a battery to what is COMMITTED plus the paths it names.
# Several sessions edit one working tree, and a snapshot of that tree carries
# every session's uncommitted work into every battery, so a verdict meant for
# one change is a verdict on all of them: a layering test failed on another
# session's engine edits, and twin readings taken while another session's
# tries change sat on disk moved by that change, not by the one being measured
# [the record, 2026-09-24: batteries 1, 2 and 3, provisioned between 10:10 and
# 10:55]. Unset, the battery is the whole working tree, as it always was. Set,
# even to nothing, every path of the tree and its components that differs from
# its repository's base (battery_bases) is put back to the base in the battery,
# unless it equals or sits under one of BATTERY_KEEP's space-separated paths,
# which are relative to the repository root and may reach into a component. Set
# to nothing, that is the committed tree alone. The pre-commit framework's
# staged_files_only asks the same question, whether a check sees only the
# change it is about, and answers it by stashing everything else in the one
# working tree; that tree here is shared by sessions still editing it, so this
# answers it in the copy instead. Ignored files are not uncommitted state and
# are carried as the snapshot carries them, since build output and installs
# are the environment a gate reads.
battery_is_kept() {
    for kept_path in $BATTERY_KEEP; do
        kept_path=${kept_path#./}
        kept_path=${kept_path%/}
        case $1 in "$kept_path"|"$kept_path"/*) return 0 ;; esac
    done
    return 1
}

# Whether BATTERY_KEEP carries a component at its own HEAD: a kept path equals
# it, contains it or sits inside it. A kept edit inside a component was made on
# top of that HEAD, so holding the component anywhere else would mix two bases.
battery_component_carried() {
    battery_is_kept "$1" && return 0
    for carried_path in $BATTERY_KEEP; do
        carried_path=${carried_path#./}
        carried_path=${carried_path%/}
        case $carried_path in "$1"/*) return 0 ;; esac
    done
    return 1
}

# Each repository's BASE, the commit its battery holds and its git answers, one
# `<repository> <commit>` line each: the superproject `.` first and every
# component after its parent, leaving out a component the source has not
# initialised, which the snapshot cannot hold either. The base is the source's
# HEAD, except that under BATTERY_KEEP a component battery_component_carried
# does not carry takes the gitlink its parent's base records at its path, and is
# listed with no commit when that base records none, since the committed tree
# then has no such component. That is the committed tree the way `git submodule
# update --recursive` checks it out, every gitlink read from the parent's
# checked-out commit, except that the superproject's is its HEAD rather than its
# index. It was each component's own HEAD until the evidence lane, run on the
# committed tree, read extensions/node at its unpinned e0874c3 where the
# superproject pins 2ea06e2e, and failed a Node test title e0874c3 had renamed
# [the record, i-keep-component-head, at superproject 59c432756].
battery_bases() {
    battery_repository_root "$ROOT" || return 0
    bases_head=$(git -C "$ROOT" rev-parse HEAD)
    echo ". $bases_head"
    battery_bases_under "$ROOT" "" "$bases_head"
}

# $1 is a source repository, $2 its path under ROOT with a trailing slash, and
# $3 its base. Every name is prefixed, as in battery_git_identity: sh has no
# locals, and the recursion runs inside the caller's loop.
battery_bases_under() {
    [ -f "$1/.gitmodules" ] || return 0
    git -C "$1" config --file "$1/.gitmodules" \
        --get-regexp '^submodule\..*\.path$' 2>/dev/null |
        while read -r _ bases_relative; do
            bases_path=$2$bases_relative
            [ -e "$ROOT/$bases_path/.git" ] || continue
            if [ "${BATTERY_KEEP+set}" != set ] || battery_component_carried "$bases_path"; then
                bases_commit=$(git -C "$ROOT/$bases_path" rev-parse HEAD)
            elif [ -n "$3" ]; then
                bases_commit=$(git -C "$1" ls-tree "$3" -- "$bases_relative" |
                    while read -r bases_mode _ bases_object _; do
                        if [ "$bases_mode" = 160000 ]; then echo "$bases_object"; fi
                    done)
            else
                bases_commit=
            fi
            echo "$bases_path $bases_commit"
            battery_bases_under "$ROOT/$bases_path" "$bases_path/" "$bases_commit"
        done
}

# The source's state outside BATTERY_KEEP that differs from its repository's
# base, one line per path: `R <repository> <path>` where the base holds the
# path, so the battery takes the base's copy back, modified and deleted files
# alike, and `X <repository> <path>` where it does not, an untracked file git
# does not ignore or one the base lacks, so the battery drops it. <repository>
# is `.` or the component the path belongs to, and <path> is relative to it. A
# component its parent's base does not record is one `X . <component>` line,
# dropped whole. A component is listed by its own pass, so the superproject's
# pass leaves every path under a component out. Read from the SOURCE, whose
# index git keeps current, rather than from the battery, where the copy has
# moved every file's mtime and a status would hash the whole tree again. Paths
# are taken to hold no newline or tab, as battery_component_paths already
# takes them to hold no space.
battery_uncommitted() {
    uncommitted_root=$1
    uncommitted_components=$(battery_component_paths)
    uncommitted_tab=$(printf '\t')
    battery_bases | while read -r uncommitted_repository uncommitted_base; do
        if [ -z "$uncommitted_base" ]; then
            echo "X . $uncommitted_repository"
            continue
        fi
        case $uncommitted_repository in
            .) uncommitted_prefix= ;;
            *) uncommitted_prefix=$uncommitted_repository/ ;;
        esac
        {
            git -C "$uncommitted_root/$uncommitted_repository" -c core.quotePath=false \
                diff --name-status --no-renames --ignore-submodules=all \
                "$uncommitted_base" -- |
                while IFS=$uncommitted_tab read -r uncommitted_status uncommitted_name; do
                    case $uncommitted_status in
                        A) printf 'X %s\n' "$uncommitted_name" ;;
                        *) printf 'R %s\n' "$uncommitted_name" ;;
                    esac
                done
            git -C "$uncommitted_root/$uncommitted_repository" -c core.quotePath=false \
                ls-files --others --exclude-standard |
                sed 's/^/X /'
        } | while read -r uncommitted_kind uncommitted_path; do
            uncommitted_full=$uncommitted_prefix$uncommitted_path
            battery_is_kept "$uncommitted_full" && continue
            if [ "$uncommitted_repository" = . ]; then
                uncommitted_inside=
                for uncommitted_component in $uncommitted_components; do
                    case $uncommitted_full in
                        "$uncommitted_component"|"$uncommitted_component"/*)
                            uncommitted_inside=yes ;;
                    esac
                done
                [ -n "$uncommitted_inside" ] && continue
            fi
            printf '%s %s %s\n' "$uncommitted_kind" "$uncommitted_repository" "$uncommitted_path"
        done
    done
}

# Puts every path outside BATTERY_KEEP that differs from its repository's base
# back to the base in the battery, through the battery's OWN git, whose HEAD is
# that base, so neither the source's index nor its working tree is touched. The
# paths it put back are listed in ai-tmp/battery.restricted.
battery_restrict() {
    restrict_tree=$1
    [ "${BATTERY_KEEP+set}" = set ] || return 0
    battery_bases | while read -r restrict_repository restrict_base; do
        [ -n "$restrict_base" ] || continue
        # Without the battery's own git a component's paths cannot be put back,
        # and verify's check of them would read the enclosing checkout instead.
        [ -e "$restrict_tree/$restrict_repository/.git" ] || {
            echo "battery: $restrict_repository has no git identity in the battery," \
                 "so BATTERY_KEEP cannot restrict it" >&2
            exit 1
        }
    done
    mkdir -p "$restrict_tree/ai-tmp"
    battery_uncommitted "$ROOT" > "$restrict_tree/ai-tmp/battery.restricted"
    while read -r restrict_kind restrict_repository restrict_path; do
        [ -n "$restrict_path" ] || continue
        case $restrict_kind in
            R) GIT_CEILING_DIRECTORIES=$(dirname "$restrict_tree") \
               git -C "$restrict_tree/$restrict_repository" --literal-pathspecs \
                   checkout -q HEAD -- "$restrict_path" ;;
            X) rm -rf -- "${restrict_tree:?}/${restrict_repository:?}/${restrict_path:?}" ;;
        esac
    done < "$restrict_tree/ai-tmp/battery.restricted"
}

# Whether the battery holds the base at every path battery_uncommitted lists
# for the source now: the base's copy where the base has one, nothing where it
# has none. Names each path that does not, one per line. verify has already
# checked that each repository's git answers its base, so HEAD here is it.
battery_restricted_drift() {
    battery_uncommitted "$ROOT" | while read -r drift_kind drift_repository drift_path; do
        case $drift_kind in
            R) GIT_CEILING_DIRECTORIES=$(dirname "$1") \
               git -C "$1/$drift_repository" --literal-pathspecs \
                   diff --quiet HEAD -- "$drift_path" 2>/dev/null ||
                   echo "$drift_repository/$drift_path differs from its base" ;;
            X) if [ -e "$1/$drift_repository/$drift_path" ] ||
                  [ -L "$1/$drift_repository/$drift_path" ]; then
                   echo "$drift_repository/$drift_path is not in its base and is present"
               fi ;;
        esac
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
    # A directory the source lacks is removed by --delete unless something the
    # excludes keep sits inside it, an install link, a scratch directory or a
    # component's identity. That strands it, and rsync says so and still exits
    # 0, so the battery can then never verify against this source. Reuse
    # across sources, which the lowest-free allocation makes common, meets it:
    # battery 1, last provisioned from wt-merge, refused a clone without
    # extensions/node/build [2026-09-24, the gate-perf job's rung runs]. The
    # source does not have those directories, so each is removed whole and the
    # copy is taken again.
    provision_report=$(snapshot "" "$ROOT/" "$tree/" 2>&1) || {
        printf '%s\n' "$provision_report" >&2
        exit 1
    }
    provision_stranded=$(printf '%s\n' "$provision_report" |
                         sed -n 's/^cannot delete non-empty directory: //p')
    if [ -n "$provision_stranded" ]; then
        printf '%s\n' "$provision_stranded" | while IFS= read -r provision_directory; do
            [ -n "$provision_directory" ] && rm -rf -- "${tree:?}/$provision_directory"
        done
        snapshot "" "$ROOT/" "$tree/"
    elif [ -n "$provision_report" ]; then
        printf '%s\n' "$provision_report" >&2
    fi
    # AFTER the snapshot, because the component directories have to exist and
    # the snapshot is what creates them on a first provision. Each identity
    # names the component's base. One battery_bases lists with no base gets
    # none, since battery_restrict drops it whole; one it does not list is not
    # a repository in the source, and battery_git_identity drops whatever
    # identity an earlier provision left in its copy.
    provision_bases=$(battery_bases)
    for component in $(battery_component_paths); do
        provision_base=$(printf '%s\n' "$provision_bases" |
                         awk -v path="$component" '$1 == path { print ($2 == "" ? "none" : $2) }')
        [ "$provision_base" = none ] && continue
        battery_git_identity "$ROOT/$component" "$tree/$component" "$provision_base"
    done
    battery_restrict "$tree"
    battery_link_installs "$tree"
    battery_link_sibling_sources "$tree"
    mkdir -p "$tree/ai-tmp"
    {
        echo "source:   $ROOT"
        echo "revision: $(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
        echo "taken:    $(date -Is)"
        if [ "${BATTERY_KEEP+set}" = set ]; then
            echo "kept:     ${BATTERY_KEEP:-(nothing)}"
            echo "note:     the COMMITTED tree, each component at the base below, plus"
            echo "          the uncommitted state of the kept paths; the"
            echo "          $(wc -l < "$tree/ai-tmp/battery.restricted") other paths that differed from their base"
            echo "          were put back to it, listed in ai-tmp/battery.restricted."
        else
            echo "note:     a snapshot of the WORKING tree, uncommitted state included."
        fi
        printf '%s\n' "$provision_bases" | while read -r provision_repository provision_base; do
            [ -n "$provision_repository" ] || continue
            echo "base:     $provision_repository ${provision_base:-(none, so dropped)}"
        done
        echo "          git run in each repository here answers its base above."
    } > "$tree/ai-tmp/battery.provenance"
}

verify() {
    tree=$(tree_for "$1")
    [ -d "$tree" ] || { echo "battery $1 does not exist; provision it first" >&2; exit 1; }
    verify_index=$1
    # Every repository's git has to answer its base, restricted or not. Files
    # that match while git names another commit give every lane reading the
    # tracked set a different tree, the way battery 1 held 01287442c's files
    # under a git answering cf282de8f [2026-09-22, battery_git_identity above].
    stray=$(battery_bases | while read -r verify_repository verify_base; do
                [ -n "$verify_base" ] || continue
                verify_have=$(GIT_CEILING_DIRECTORIES=$(dirname "$tree") \
                              git -C "$tree/$verify_repository" rev-parse HEAD 2>/dev/null || true)
                [ "$verify_have" = "$verify_base" ] ||
                    echo "$verify_repository answers ${verify_have:-no commit}, not its base $verify_base"
            done)
    if [ -n "$stray" ]; then
        echo "battery $verify_index does not answer git at each repository's base:" >&2
        echo "$stray" >&2
        exit 1
    fi
    # Restricted, the source's paths outside the kept ones that differ from
    # their base are held to it rather than compared with the source, which the
    # battery is meant to differ from there.
    set --
    if [ "${BATTERY_KEEP+set}" = set ]; then
        stray=$(battery_restricted_drift "$tree")
        if [ -n "$stray" ]; then
            echo "battery $verify_index does not hold each repository's base outside BATTERY_KEEP:" >&2
            echo "$stray" >&2
            exit 1
        fi
        while read -r _ verify_repository verify_path; do
            [ -n "$verify_path" ] || continue
            case $verify_repository in
                .) set -- "$@" "--exclude=/$verify_path" ;;
                *) set -- "$@" "--exclude=/$verify_repository/$verify_path" ;;
            esac
        done <<EXCLUDED
$(battery_uncommitted "$ROOT")
EXCLUDED
    fi
    drift=$(snapshot keep -in "$@" "$ROOT/" "$tree/")
    if [ -n "$drift" ]; then
        echo "battery $verify_index is NOT a copy of $ROOT; it differs in:" >&2
        echo "$drift" >&2
        exit 1
    fi
    cat "$tree/ai-tmp/battery.provenance" 2>/dev/null || true
}

[ $# -ge 1 ] || usage
command=$1; shift
case "$command" in
    provision) [ $# -eq 1 ] || usage; claim "$1"; provision "$1" ;;
    path)      [ $# -eq 1 ] || usage; tree_for "$1" ;;
    verify)    [ $# -eq 1 ] || usage; verify "$1" ;;
    prune)     [ $# -eq 1 ] || usage; prune "$1" ;;
    run)
        if [ "${1:-}" = "--" ]; then
            shift
            allocate
        else
            [ $# -ge 2 ] && [ "$2" = "--" ] || usage
            index=$1
            shift 2
            claim "$index"
        fi
        [ $# -ge 1 ] || usage
        tree=$(tree_for "$index")
        # The occupancy record goes in with the claim, before the copy, so a
        # reader of it sees the tree taken for the whole provision too.
        if held=$(occupant "$tree"); then
            echo "battery $index is running as PID $held; pick another index" >&2
            exit 1
        fi
        mkdir -p "$tree/ai-tmp"
        echo "$$" > "$tree/ai-tmp/battery.pid"
        git -C "$ROOT" rev-parse HEAD >> "$tree/ai-tmp/battery.pid" 2>/dev/null || true
        provision "$index"
        verify "$index" > /dev/null
        # A repository's battery must answer git about itself before anything
        # runs in it, since the command may write through git.
        if battery_repository_root "$ROOT"; then
            answered=$(GIT_CEILING_DIRECTORIES=$(dirname "$tree") \
                       git -C "$tree" rev-parse --show-toplevel 2>/dev/null || true)
            [ "$answered" = "$tree" ] || {
                echo "battery $index answers git about '${answered:-nothing}', not about itself;" \
                     "refusing to run in it" >&2
                exit 1
            }
        fi
        log="$tree/ai-tmp/battery-$index.log"
        # Never piped: a pipeline reports the filter's status and a failed gate
        # would read as a pass. The log is read separately. The claim's
        # descriptor is closed for the command, so a daemon the gate leaves
        # running cannot hold the battery after this run has ended. Git's
        # search for a repository stops at the battery's parent, so a command
        # in a tree or component whose own .git has gone missing is told it is
        # not in a repository rather than handed the enclosing checkout
        # [GIT_CEILING_DIRECTORIES, git(1): the directories git will not chdir
        # up into while looking for a repository].
        ( cd "$tree" && GIT_CEILING_DIRECTORIES=$(dirname "$tree") && \
          export GIT_CEILING_DIRECTORIES && "$@" 9>&- ) > "$log" 2>&1 && status=0 || status=$?
        rm -f "$tree/ai-tmp/battery.pid"
        echo "battery $index: exit $status, log $log"
        exit "$status"
        ;;
    *) usage ;;
esac
