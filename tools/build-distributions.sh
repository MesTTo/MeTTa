#!/bin/sh
# Purpose: build every Python distribution this repository publishes into one
#   directory, which is what the publish workflow uploads and what
#   tools/publish-new-projects.sh reads.
# Assumes: a python with `build` installed, or network to pip install it.
# Guarantees:
#   - pymetta and every ext/metta-* land in $DIST as an sdist AND a wheel,
#     because `python -m build` with no flag builds the sdist and then the
#     wheel FROM IT, which is the path PyPI itself takes; building only the
#     wheel hides a MANIFEST.in shipping fewer resources than the wheel maps
#   - the member list is read from the directory, so a package added under
#     ext/ is built with no edit here
# Fails when: asked for ext/pymetta-host. That one carries a patched
#   SWI-Prolog built inside quay.io/pypa/manylinux_2_28_x86_64, one wheel per
#   interpreter, which is tools/pymetta-host/run.sh and needs a container.
#   It is skipped by name rather than silently missed.
# Decides: $DIST, which defaults to dist/ because that is the directory the
#   workflow uploads and the publisher reads.
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
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
    # The host bundle is not a `python -m build` target; see Fails when.
    [ "$name" = pymetta-host ] && continue
    "$PYTHON" -m build --outdir "$DIST" "$member"
done
printf 'built into %s:\n' "$DIST"
ls -1 "$DIST" | wc -l
