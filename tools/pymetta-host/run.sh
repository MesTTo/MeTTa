#!/bin/bash
# Purpose: drive the container stages that build pymetta's host wheels, each
#   stage named on the command line (build-swipl.sh, build-janus.sh,
#   assemble.sh) run from the host in one manylinux image over one mount set,
#   skipping the two compile stages when OUT already holds their output for
#   exactly this tree's inputs.
# Decides: OUT, defaulting to ai-tmp/host-build, where the stages write; DIST,
#   defaulting to dist/, where the pure wheel waits; SRC, defaulting to the
#   tree fetch-source.sh produces.
# Guarantees:
#   - OUT/host-inputs lists every input the compile stages read (the
#     interpreters, the image, each file of this directory, and each patch of
#     the stack in the order fetch-source.sh applies it, with its sha256). A
#     run writes it only when both compile stages ran in it from the derived
#     tree, and removes it before either runs, so a half-rebuilt OUT, or one
#     built from a SRC someone supplied, is never vouched for
#     [tested 2026-09-25T22:10:45+10:00: tools/pymetta-host/run_selftest.sh]
#   - a compile stage is skipped when OUT/host-inputs equals this tree's
#     inputs and OUT/swipl and OUT/janus exist, and fetch-source.sh runs, and
#     /src is mounted, only when a compile stage runs; the lines that differ
#     are printed before a rebuild
#     [tested 2026-09-25T22:10:45+10:00: tools/pymetta-host/run_selftest.sh]
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
# A failure inside $(inputs) must stop the run, not leave a shorter key.
shopt -s inherit_errexit
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
PYMETTA=$REPO/extensions/python/pyproject.toml
OUT=${OUT:-$REPO/ai-tmp/host-build}
DIST=${DIST:-$REPO/dist}
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
# Every stage runs in the image, so it is fetched now rather than by the first
# `docker run`, and inputs() can name the image the stages will use.
docker image inspect "$IMAGE" > /dev/null 2>&1 || docker pull -q "$IMAGE"

# The stages that compile from the source tree. Their output, OUT/swipl and
# OUT/janus, is a function of inputs() alone, keyed the way build-swipl.sh
# keys its cmake configuration: by the inputs themselves, so a build from
# other inputs cannot pass for this one. The key errs toward rebuilding. It
# holds every file of this directory, assemble.sh and this script included,
# though neither is read by a compile stage, because a file left out would
# let a stale home through and one kept in costs only a rebuild.
COMPILE_STAGES="build-swipl.sh build-janus.sh"
inputs() {
    printf 'tags %s\n' "$TAGS"
    printf 'image %s %s\n' "$IMAGE" "$(docker image inspect --format '{{.Id}}' "$IMAGE")"
    find "$HERE" -maxdepth 1 -type f | LC_ALL=C sort | while read -r file; do
        printf 'file %s %s\n' "${file#"$REPO"/}" "$(sha256sum < "$file" | cut -d' ' -f1)"
    done
    . "$HERE/patch-root.sh"
    patch_layers "$REPO"
    for patch in $(every_patch); do
        printf 'patch %s %s\n' "${patch#"$REPO"/}" "$(sha256sum < "$patch" | cut -d' ' -f1)"
    done
}
current=$(inputs)

# A supplied SRC is a tree someone is editing, which no list of inputs
# describes, so only the derived tree's builds are vouched for or reused.
vouched=0
if [ -z "${SRC:-}" ] && [ -f "$OUT/host-inputs" ]; then
    if [ "$(cat "$OUT/host-inputs")" != "$current" ]; then
        echo "OUT/host-inputs names a build of other inputs; the lines that differ (< built, > this tree):"
        diff "$OUT/host-inputs" <(printf '%s\n' "$current") | grep '^[<>]' || true
    elif [ ! -d "$OUT/swipl" ] || [ ! -d "$OUT/janus" ]; then
        echo "OUT/host-inputs matches this tree, but OUT/swipl or OUT/janus is gone"
    else
        vouched=1
    fi
fi

compiles=0
for WHICH in "$@"; do
    case " $COMPILE_STAGES " in *" $WHICH "*) [ "$vouched" = 1 ] || compiles=1 ;; esac
done
derived=0
if [ "$compiles" = 1 ]; then
    rm -f "$OUT/host-inputs"
    # The swipl-devel checkout the compile stages build from. An absolute path
    # works only on the machine it was written on, which is why this used to
    # refuse without one -- and the consequence was that only someone who had
    # already prepared that tree by hand could build the wheel, so the release
    # shipped 17 distributions of 18 and build-distributions.sh skipped this
    # one by name.
    #
    # The tree is DERIVED now: fetch-source.sh clones swipl-devel at the pinned
    # commit and applies every patch in tests/checks/host_workarounds and then
    # every one in tools/pymetta-host/host-only, all of which are committed
    # here. SRC stays as an override for a tree someone is actively editing.
    if [ -z "${SRC:-}" ]; then
        sh "$HERE/fetch-source.sh"
        SRC=${DEST:-$REPO/ai-tmp/swipl-src}
        derived=1
    fi
fi

stage() {
    echo "===== $1 ====="
    # Only a compile stage reads the source tree, so only it mounts one.
    local mounts=()
    case " $COMPILE_STAGES " in *" $1 "*) mounts=(-v "$SRC:/src") ;; esac
    docker run --rm \
        -e TAGS="$TAGS" -e HOST_OWNER="$(id -u):$(id -g)" \
        "${mounts[@]}" -v "$(cd "$OUT" && pwd):/out" -v "$REPO:/repo" -v "$(cd "$DIST" && pwd):/dist" \
        "$IMAGE" bash -c \
        'set -e; trap "chown -R $HOST_OWNER /out 2>/dev/null || true" EXIT
         bash /repo/tools/pymetta-host/'"$1"
}

compiled=" "
for WHICH in "$@"; do
    case " $COMPILE_STAGES " in
        *" $WHICH "*)
            if [ "$vouched" = 1 ]; then
                echo "===== $WHICH: skipped, OUT/host-inputs vouches for OUT/swipl and OUT/janus ====="
                continue
            fi
            compiled="$compiled$WHICH " ;;
    esac
    stage "$WHICH"
done

if [ "$derived" = 1 ]; then
    for WHICH in $COMPILE_STAGES; do
        case $compiled in *" $WHICH "*) ;; *) exit 0 ;; esac
    done
    printf '%s\n' "$current" > "$OUT/host-inputs.new"
    mv "$OUT/host-inputs.new" "$OUT/host-inputs"
    echo "OUT/host-inputs records what OUT/swipl and OUT/janus were built from"
fi
