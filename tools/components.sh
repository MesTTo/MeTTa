#!/bin/sh
# Purpose: make every component of this checkout a checkout of its own
#   repository, pinned where the superproject pins it, without deleting
#   anything git does not track.
# Assumes:
#   - run from anywhere; the checkout is this script's own directory.
#   - the component repositories named in .gitmodules are reachable, OR a
#     sibling worktree of this superproject already holds the pinned commit.
# Guarantees:
#   - an EMPTY component directory is cloned, which is the fresh-worktree case
#     and the one `git submodule update --init` already serves.
#   - a component directory that already holds the files is turned into a
#     repository AROUND them, which `git submodule update` refuses outright
#     ("destination path already exists and is not an empty directory"). That
#     case is not rare: it is every checkout that predates the mount, and the
#     files there are byte-identical to the component's tip because that is how
#     the split was made. Cloning over it would mean deleting first, and the
#     untracked build output under a component is 676 MB that no clone brings
#     back: 604 MB of Rust target/ under the MORK seat and 72 MB under the
#     Python one, none of it tracked and all of it wanted.
#   - components a component itself mounts are done too, because the twins
#     carry the .metta corpus they are twins OF.
#   - the index is read from the pinned commit and the WORKING TREE is left
#     alone (`reset --mixed`), so files that already match come out clean and
#     files that do not are reported as modified rather than silently replaced.
#     That report is for files that PREDATE the run: a directory this run
#     cloned is brought to the pin instead, because nobody's work is there.
#   - a pinned commit the remote does not carry is taken from a sibling
#     worktree that holds it, and SAYS SO on that component's line. An
#     unpushed component commit is the ordinary state while work is in
#     progress, and without the fallback every worktree of that work is
#     unprovisionable: measured 2026-09-21, lib and extensions/python were
#     pinned at commits on no remote branch and the worktree GATE failed.
#     Provisioning and publication are separate obligations and the marker is
#     what keeps them separate: a release still owes a fresh recursive clone,
#     so `components.sh | grep UNPUBLISHED` is the check that the pointers
#     were pushed, and the fallback hides nothing from it.
#   - a pin that cannot be set refuses, naming the commit and the component.
#   - a derived root that is not the repository refuses instead of reporting
#     success over zero components, which is how a wrong root used to pass.
# Fails when:
#   - a component repository cannot be fetched, which it reports per component
#     and exits nonzero for, because a checkout missing a component has no
#     engine to run and every suite would pass while testing nothing.
#   - no reachable source carries the pinned commit. That is reported as the
#     missing pin it is; it used to fall through an UNCHECKED update-ref and
#     surface as "has modified tracked files", which named the wrong problem
#     and sent a reader after somebody's edits that did not exist. set -e does
#     not catch it because component() runs in a `|| exit 1` condition, where
#     set -e is disabled for the whole body.
# Open Obligations:
#   To Do: None
#   Hacks: None
#   Future Enhancements: None
set -eu

# The repository root, which is this script's PARENT: these drivers live in
# tools/ so the root stays short enough to read at a glance.
HERE=$(cd -- "$(dirname -- "$0")/.." && pwd)
status=0

# Every name here is prefixed, because this shell has no scoping and the
# caller's `here`, `path` and `sha` are live across the call; the recursion
# defect this file already carries a subshell for came from exactly that.
supply_pin() {
    pin_here=$1
    pin_rel=$2
    pin_sha=$3
    pin_source=origin
    git -C "$pin_here" cat-file -e "$pin_sha" 2>/dev/null && return 0
    pin_source=sibling
    # A sibling worktree of this superproject that already holds the component
    # has the objects on this disk, so fetching them there needs no network and
    # no push. This is what `git clone --reference` is for.
    git -C "$HERE" worktree list --porcelain 2>/dev/null |
    while read -r pin_key pin_value; do
        [ "$pin_key" = worktree ] || continue
        pin_donor="$pin_value/$pin_rel"
        [ "$pin_donor" = "$pin_here" ] && continue
        [ -e "$pin_donor/.git" ] || continue
        git -C "$pin_donor" cat-file -e "$pin_sha" 2>/dev/null || continue
        git -C "$pin_here" fetch --quiet --no-tags "$pin_donor" "$pin_sha" 2>/dev/null && break
    done
    git -C "$pin_here" cat-file -e "$pin_sha" 2>/dev/null
}

component() {
    tree=$1
    path=$2
    url=$3
    sha=$4
    here="$tree/$path"
    cloned=no
    if [ ! -d "$here" ] || [ -z "$(ls -A "$here" 2>/dev/null)" ]; then
        mkdir -p "$(dirname "$here")"
        git clone --quiet "$url" "$here" || { echo "components.sh: cannot clone $url" >&2; return 1; }
        cloned=yes
    elif [ ! -e "$here/.git" ]; then
        git init --quiet "$here"
        git -C "$here" remote add origin "$url"
    fi
    # Set every time: a repository that was renamed leaves an existing checkout
    # pointing at a path that no longer exists, and the fetch is where it shows.
    git -C "$here" remote set-url origin "$url"
    git -C "$here" fetch --quiet --no-tags origin main ||
        { echo "components.sh: cannot fetch main from $url" >&2; return 1; }
    supply_pin "$here" "${here#"$HERE"/}" "$sha" || {
        echo "components.sh: neither $url nor a sibling worktree carries $sha for $path" >&2
        return 1
    }
    git -C "$here" update-ref refs/heads/main "$sha" || {
        echo "components.sh: cannot pin $path at $sha" >&2
        return 1
    }
    git -C "$here" symbolic-ref HEAD refs/heads/main
    # A component repository is created here rather than cloned from a host that configured
    # it, so it carries no author identity and a commit inside it refuses. Take the
    # superproject's, which is whose work it is.
    git -C "$here" config user.name "$(git -C "$HERE" config user.name)"
    git -C "$here" config user.email "$(git -C "$HERE" config user.email)"
    git -C "$here" reset --quiet --mixed main
    # `reset --mixed` sets the index and leaves the working tree, which is what
    # preserves the untracked build output. It does NOT bring back a tracked
    # file the tree is missing, and a directory that git has just turned from
    # tracked content into a gitlink is missing ALL of them, so reporting and
    # stopping there leaves a component that cannot be used. Modifications are
    # a different thing and are never overwritten: they are somebody's work.
    # Gitlinks are excluded: a NESTED component sitting at a different commit
    # reads as a modified path here, and it is not somebody's work, it is the
    # thing the recursion below is about to set. The raw format's second field
    # is the destination mode, and 160000 is a gitlink.
    # Only where the files predate this run. A directory THIS run cloned holds
    # the remote tip, which differs from the pin whenever the pin is ahead of
    # or behind it, and every one of those files reads as modified here; there
    # is nobody whose work it could be, so refusing made a fresh worktree
    # unprovisionable the moment its pin was not the remote's tip
    # [measured 2026-09-21: the probe worktree refused on lib after the clone].
    if [ "$cloned" = no ] &&
       [ -n "$(git -C "$here" diff --raw --diff-filter=M | awk '$2 != "160000"')" ]; then
        echo "components.sh: $path has modified tracked files; commit or discard them first" >&2
        return 1
    fi
    git -C "$here" checkout --quiet -- .
    if [ "$pin_source" = sibling ]; then
        printf '  %-34s %s  UNPUBLISHED: supplied from a sibling worktree; %s does not carry it\n' \
            "$path" "$(echo "$sha" | cut -c1-9)" "$url"
    else
        printf '  %-34s %s\n' "$path" "$(echo "$sha" | cut -c1-9)"
    fi
    populate "$here"
}

populate() {
    tree=$1
    [ -f "$tree/.gitmodules" ] || return 0
    git -C "$tree" config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null |
    while read -r key path; do
        url=$(git -C "$tree" config -f .gitmodules "${key%.path}.url")
        sha=$(git -C "$tree" ls-files --stage -- "$path" | awk '$1 == "160000" { print $2 }')
        [ -n "$sha" ] || { echo "components.sh: $path is declared and not mounted" >&2; continue; }
        # In a SUBSHELL: this shell has no scoping, so the recursive call inside
        # `component` would otherwise reassign the `tree` this loop is walking
        # and every later component would be looked up under the wrong one. A
        # subshell makes that impossible rather than guarded against.
        ( component "$tree" "$path" "$url" "$sha" ) || exit 1
    done
}

# populate() returns 0 for a tree that declares no components, which is right
# for a RECURSIVE call and wrong for this one: at the top level a missing
# .gitmodules means the derived root is not the repository, and returning 0
# there is how a wrong root provisions nothing and reports success. The test
# that found this records the shape -- "it populated nothing here, exited 0"
# -- and an exit 0 from a provisioning step is the worst answer available,
# because every suite then passes while testing an empty checkout.
[ -f "$HERE/.gitmodules" ] || {
    echo "components.sh: $HERE declares no components (.gitmodules is not there);" >&2
    echo "  this is not the repository root, so nothing would be provisioned" >&2
    exit 1
}
populate "$HERE" || status=1
exit "$status"
