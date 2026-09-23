#!/bin/bash
# Drive the container stages from the host. One image, one mount set.
#
# TAGS is derived from pymetta's classifiers rather than written here, so adding
# an interpreter to extensions/python/pyproject.toml is the only edit a new
# Python needs, and the engine extra's marker, which a packaging test holds to
# the same classifiers, stays the complement of what this builds.
#
# DIST is where the pure pymetta wheel waits: assemble.sh grafts the host onto
# it rather than building pymetta a second way.
#
# The image runs as root, because dnf does, so every stage hands ownership of
# the mounted trees back afterwards. Without it the build leaves root-owned
# files inside the repository that the user cannot delete.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
PYMETTA=$REPO/extensions/python/pyproject.toml
OUT=${OUT:-$REPO/ai-tmp/host-build}
DIST=${DIST:-$REPO/dist}
# The swipl-devel checkout this builds the host from. An absolute path works
# only on the machine it was written on, which is why this used to refuse
# without one -- and the consequence was that only someone who had already
# prepared that tree by hand could build the wheel, so the release shipped 17
# distributions of 18 and build-distributions.sh skipped this one by name.
#
# The tree is DERIVED now: fetch-source.sh clones swipl-devel at the pinned
# commit and applies every patch in tests/checks/host_workarounds, all of
# which were committed here all along. SRC stays as an override for a tree
# someone is actively editing.
if [ -z "${SRC:-}" ]; then
    sh "$HERE/fetch-source.sh"
    SRC=${DEST:-$REPO/ai-tmp/swipl-src}
fi
IMAGE=quay.io/pypa/manylinux_2_28_x86_64:latest

TAGS=$(python3 - "$PYMETTA" <<'PY'
import sys, tomllib
data = tomllib.load(open(sys.argv[1], "rb"))
prefix = "Programming Language :: Python :: 3."
print(" ".join("cp3" + c[len(prefix):].replace(".", "")
               for c in data["project"]["classifiers"] if c.startswith(prefix)))
PY
)
echo "interpreters: $TAGS"
mkdir -p "$OUT"

stage() {
    echo "===== $1 ====="
    docker run --rm \
        -e TAGS="$TAGS" -e HOST_OWNER="$(id -u):$(id -g)" \
        -v "$SRC:/src" -v "$(cd "$OUT" && pwd):/out" -v "$REPO:/repo" -v "$(cd "$DIST" && pwd):/dist" \
        "$IMAGE" bash -c \
        'set -e; trap "chown -R $HOST_OWNER /out 2>/dev/null || true" EXIT
         bash /repo/tools/pymetta-host/'"$1"
}

for WHICH in "$@"; do stage "$WHICH"; done
