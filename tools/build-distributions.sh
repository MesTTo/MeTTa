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
# Fails when: asked for pymetta's manylinux wheels. Those carry the patched
#   SWI-Prolog, compiled inside quay.io/pypa/manylinux_2_28_x86_64 and grafted
#   onto the pure wheel this builds, one wheel per interpreter, which is
#   tools/pymetta-host/run.sh and needs a container this script does not run.
#   They are the same distribution, pymetta, so nothing here names them.
# Decides: $DIST, which defaults to dist/ because that is the directory the
#   workflow uploads and the publisher reads.
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

# The distributions this repository publishes: pymetta, and every directory
# under ext/ that carries a pyproject.toml. pymetta's Linux wheels are grafted
# from its pure one by tools/pymetta-host/run.sh and are the same distribution,
# so they add no name here. A separate host distribution, pymetta-host, used to
# be listed beside these and was retired on 2026-09-23 when the host moved into
# pymetta: PyPI never created that project, and 0.9.1's engine extra named it.
members() {
    printf 'pymetta\n'
    for member in "$HERE"/ext/*/; do
        [ -f "$member/pyproject.toml" ] || continue
        basename "$member"
    done
}
# Answered before the interpreter search, so a caller that only wants the
# names is not refused by a machine that cannot build.
if [ "${1:-}" = --list ]; then
    members
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
    [ -f "$member/pyproject.toml" ] || continue
    "$PYTHON" -m build --outdir "$DIST" "$member"
done
printf 'built into %s:\n' "$DIST"
ls -1 "$DIST" | wc -l
