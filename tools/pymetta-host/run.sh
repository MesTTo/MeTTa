#!/bin/bash
# Drive the container stages from the host. One image, one mount set.
#
# TAGS is derived from the classifiers rather than written here, so adding an
# interpreter to pyproject.toml is the only edit a new Python needs.
#
# The image runs as root, because dnf does, so every stage hands ownership of
# the mounted trees back afterwards. Without it the build leaves root-owned
# files inside the repository that the user cannot delete.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
PKG=$REPO/ext/pymetta-host
OUT=${OUT:-$REPO/ai-tmp/host-build}
# The swipl-devel checkout this builds the host from. No default: an absolute
# path works only on the machine it was written on and this repository may be
# published, so the caller names it and an unset SRC refuses by name rather
# than mounting whatever sits at someone else's path.
: "${SRC:?name the swipl-devel checkout to build from, e.g. SRC=../swipl-devel}"
IMAGE=quay.io/pypa/manylinux_2_28_x86_64:latest

TAGS=$(python3 - "$PKG/pyproject.toml" <<'PY'
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
        -v "$SRC:/src" -v "$(cd "$OUT" && pwd):/out" -v "$REPO:/repo" -v "$PKG:/pkg" \
        "$IMAGE" bash -c \
        'set -e; trap "chown -R $HOST_OWNER /out /pkg 2>/dev/null || true" EXIT
         bash /repo/tools/pymetta-host/'"$1"
}

for WHICH in "$@"; do stage "$WHICH"; done
