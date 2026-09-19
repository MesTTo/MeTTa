#!/bin/sh
# Purpose: make every component of this checkout a checkout of its own
#   repository, pinned where the superproject pins it, without deleting
#   anything git does not track.
# Assumes:
#   - run from anywhere; the checkout is this script's own directory.
#   - the component repositories named in .gitmodules are reachable.
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
# Fails when:
#   - a component repository cannot be fetched, which it reports per component
#     and exits nonzero for, because a checkout missing a component has no
#     engine to run and every suite would pass while testing nothing.
# Open Obligations:
#   To Do: None
#   Hacks: None
#   Future Enhancements: None
set -eu

HERE=$(cd -- "$(dirname -- "$0")" && pwd)
status=0

component() {
    tree=$1
    path=$2
    url=$3
    sha=$4
    here="$tree/$path"
    if [ ! -d "$here" ] || [ -z "$(ls -A "$here" 2>/dev/null)" ]; then
        mkdir -p "$(dirname "$here")"
        git clone --quiet "$url" "$here" || { echo "components.sh: cannot clone $url" >&2; return 1; }
    elif [ ! -e "$here/.git" ]; then
        git init --quiet "$here"
        git -C "$here" remote add origin "$url"
    fi
    # Set every time: a repository that was renamed leaves an existing checkout
    # pointing at a path that no longer exists, and the fetch is where it shows.
    git -C "$here" remote set-url origin "$url"
    git -C "$here" fetch --quiet --no-tags origin main ||
        { echo "components.sh: cannot fetch main from $url" >&2; return 1; }
    git -C "$here" update-ref refs/heads/main "$sha"
    git -C "$here" symbolic-ref HEAD refs/heads/main
    git -C "$here" reset --quiet --mixed main
    git -C "$here" checkout --quiet -- .gitmodules 2>/dev/null || true
    printf '  %-34s %s\n' "$path" "$(echo "$sha" | cut -c1-9)"
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

populate "$HERE" || status=1
exit "$status"
