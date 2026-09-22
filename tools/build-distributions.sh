#!/bin/sh
# Purpose: build every Python distribution this repository publishes into one
#   directory, which is what the publish workflow uploads and what
#   tools/publish-new-projects.sh reads. With --list, print the distribution
#   names instead of building them, which is how tools/pending-publishers.py
#   learns what the release produces without re-implementing the rule.
# Assumes: a python with `build` installed, or network to pip install it.
#   --list assumes neither, so it answers in a checkout with no interpreter.
# Guarantees:
#   - pymetta and every ext/metta-* land in $DIST as an sdist AND a wheel,
#     because `python -m build` with no flag builds the sdist and then the
#     wheel FROM IT, which is the path PyPI itself takes; building only the
#     wheel hides a MANIFEST.in shipping fewer resources than the wheel maps
#   - the member list is read from the directory, so a package added under
#     ext/ is built with no edit here
#   - a member is a directory CARRYING A pyproject.toml. Globbing ext/*/ alone
#     also matches build residue: ext/__pycache__ exists in any tree that has
#     run the suite, `python -m build` refuses it with "does not appear to be
#     a Python project", and under set -e that aborted the whole release
#     build. It survived review because a fresh CI checkout has no such
#     directory, so the local build broke where the runner passed. The rule is
#     structural rather than a list of names to skip, so the next stray
#     directory cannot reach the build either.
#     [tested: reproduced at exit 1 before the guard; commit=WORKTREE]
# Fails when: asked for ext/pymetta-host. That one carries a patched
#   SWI-Prolog built inside quay.io/pypa/manylinux_2_28_x86_64, one wheel per
#   interpreter, which is tools/pymetta-host/run.sh and needs both a container
#   and an SRC swipl-devel checkout that is not in this repository.
#   It is skipped by name rather than silently missed.
# Decides: $DIST, which defaults to dist/ because that is the directory the
#   workflow uploads and the publisher reads.
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

# TWO PRODUCERS, named apart. members() is what `python -m build` makes, and
# the loop below walks exactly it. released() is what the RELEASE publishes,
# which is members plus the host bundle: that one is built by
# tools/pymetta-host/run.sh in a manylinux container from a swipl-devel tree
# fetch-source.sh clones and patches, so it is not a build target here, and
# it is still a distribution this repository ships.
#
# Conflating them is what left pymetta-host out of every plan: it is skipped
# here for a real reason, and the planner read this list and concluded the
# project did not exist.
members() {
    printf 'pymetta\n'
    for member in "$HERE"/ext/*/; do
        name=$(basename "$member")
        # The host bundle is not a `python -m build` target; see Fails when.
        [ "$name" = pymetta-host ] && continue
        [ -f "$member/pyproject.toml" ] || continue
        printf '%s\n' "$name"
    done
}

released() {
    members
    [ -f "$HERE/ext/pymetta-host/pyproject.toml" ] && printf 'pymetta-host\n'
    return 0
}

# Answered before the interpreter search, so a caller that only wants the
# names is not refused by a machine that cannot build. --list answers the
# RELEASE set, because every caller of it so far asks what gets published
# rather than what this script builds.
if [ "${1:-}" = --list ]; then
    released
    exit 0
fi

. "$HERE/tools/select-python.sh" > /dev/null 2>&1
PYTHON=${PY:-}
if [ -z "$PYTHON" ]; then
    printf 'build-distributions: tools/select-python.sh found no interpreter; set CHECK_PY\n' >&2
    exit 1
fi
DIST=${DIST:-$HERE/dist}

"$PYTHON" -m build --outdir "$DIST" "$HERE"
for member in "$HERE"/ext/*/; do
    name=$(basename "$member")
    [ "$name" = pymetta-host ] && continue
    [ -f "$member/pyproject.toml" ] || continue
    "$PYTHON" -m build --outdir "$DIST" "$member"
done
printf 'built into %s:\n' "$DIST"
ls -1 "$DIST" | wc -l
