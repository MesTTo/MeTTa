#!/bin/sh
# Purpose: build the patched WebAssembly SWI-Prolog the TypeScript seat runs the
#   engine on, declare it the way every patched host is declared, check it with
#   the engine's own boot check, and on request vendor it into the seat.
#
# Usage:
#   sh tools/wasm-host/build.sh          build, declare and check the host, in
#                                        ai-tmp/wasm-host-build/host/
#   sh tools/wasm-host/build.sh vendor   copy that checked host into
#                                        extensions/node/_host/ and check the copy
#
# The recipe is not ours. SWI-Prolog publishes swipl-wasm from
# SWI-Prolog/npm-swipl-wasm, whose docker/Dockerfile builds zlib and pcre2 with
# emscripten, clones swipl-devel and builds it with cmake and ninja, then runs
# ctest. tools/wasm-host/Dockerfile is that file with its clone replaced by the
# patched tree tools/pymetta-host/fetch-source.sh produces, and wasm.pin holds
# the emsdk, zlib and pcre2 versions upstream built this exact swipl commit
# with. Their package.json then `docker cp`s src/swipl-web.{js,wasm,data} out
# of the image; so does this.
#
# One step is ours, because upstream has no declaration to carry. The engine
# reads swi('metta-host.pl'), and in this host the home is /swipl, packed from
# build.wasm/src/wasm-preload by `--preload-file ...@swipl` at the swipl-web
# link (cmake/EmscriptenTargets.cmake). The declaration names the build's
# compiled_at, which exists only once the host is linked, so the host is
# linked twice: once to learn its identity by booting it, and again with the
# declaration in the preload directory. The second link recompiles nothing, so
# compiled_at is unchanged, and the engine's check on the result is what
# proves that rather than this comment.
#
# The second link runs the one command ninja records for src/swipl-web.js, not
# `ninja swipl-web`. SWI's cmake generates library/chr.pl,
# library/chr/chr_translate.pl and library/chr/guard_entailment.pl into the
# preload directory and then deletes them there (the rsync with
# --delete-excluded --exclude=[a-z]*.pl in cmake/EmscriptenTargets.cmake), so
# any later ninja run finds those outputs missing, regenerates them, and a link
# after it packs 1.6 MB of CHR source no swipl-wasm ships [measured
# 2026-09-23: a relink through ninja grew swipl-web.data from 1654266 to
# 2230862 bytes, the three files and the declaration being the whole
# difference]. So the file sets of the two links are compared too, and may
# differ by /swipl/metta-host.pl alone.
#
# One more step is ours: the library pack's native halves. A library whose
# native half belongs in a host that links foreign code statically carries
# support/static.cmake, and this script stages each such library's support/ and
# vendor/ directories into the source tree as packages/metta, beside
# metta-package/CMakeLists.txt, which includes every staged fragment. The
# library then activates its half by name on this host
# (lib/_support/native_install.pl:native_install/2), where the native host builds
# and loads a shared object instead.
#
# Assumes: docker, node, git and sha256sum on PATH, and network for the clone
#   and the image's downloads.
# Guarantees:
#   - the host compiles swipl-devel at tools/pymetta-host/swipl.pin with every
#     patch under tests/checks/host_workarounds applied, since fetch-source.sh
#     refuses a tree it could not patch whole
#   - packages/metta is staged fresh on every build from lib/, so the host links
#     the halves of exactly the libraries that carry support/static.cmake now
#   - host/ is written only after `node tools/wasm-host/host.mjs check` passes
#     on the relinked artefacts, so a host whose declaration misses a patch, or
#     whose relink changed its build, never reaches it
#     [tested: this script, 2026-09-23; commit=02dc5471b552c74826880441400114c798ea66ca]
#   - the relinked host's /swipl holds exactly the first link's files plus
#     metta-host.pl, each the same size, or the build stops showing the diff
#   - `vendor` copies host/'s three artefacts and SWI-Prolog's LICENSE, the
#     glue renamed to swipl-web.cjs because the seat is an ES module package
#     and the glue is CommonJS, writes _host/README.md from the pins and the
#     copy's own compiled_at, then runs the same check on the copy
# Fails when: the network is down, or a patch no longer applies to the pin;
#   both stop before an image is built.
# Decides: OUT, defaulting to ai-tmp/wasm-host-build, since everything but the
#   vendored copy is build input or scratch; JOBS, the compile and ctest job
#   count inside the image, defaulting to every core as upstream's recipe
#   does, which a shared machine lowers.
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$HERE/../.." && pwd)
OUT=${OUT:-$ROOT/ai-tmp/wasm-host-build}
SRC=$OUT/swipl-src
HOST=$OUT/host
SEAT=$ROOT/extensions/node/_host
IMAGE=metta-swipl-wasm:patched
ARTEFACTS='src/swipl-web.js src/swipl-web.wasm src/swipl-web.data'
OWNER="$(id -u):$(id -g)"

field() { sed -n "s/^$1[[:space:]]\\+\\(.*\\)\$/\\1/p" "$HERE/wasm.pin" | head -1; }

EMSDK=$(field emsdk); ZLIB=$(field zlib); PCRE2=$(field pcre2)
LIBYAML=$(field libyaml); LIBYAML_SHA256=$(field libyaml_sha256)
UTF8PROC=$(field utf8proc); UTF8PROC_SHA256=$(field utf8proc_sha256)
OSSP_UUID=$(field ossp_uuid); OSSP_UUID_SHA256=$(field ossp_uuid_sha256)
for name in EMSDK ZLIB PCRE2 LIBYAML LIBYAML_SHA256 UTF8PROC UTF8PROC_SHA256 \
            OSSP_UUID OSSP_UUID_SHA256; do
    eval "value=\$$name"
    [ -n "$value" ] || { printf 'build: %s missing from %s/wasm.pin\n' "$name" "$HERE" >&2; exit 1; }
done

if [ "${1:-}" = vendor ]; then
    for name in swipl-web.js swipl-web.wasm swipl-web.data; do
        [ -f "$HOST/$name" ] || {
            printf 'build: %s/%s is missing; run sh tools/wasm-host/build.sh first\n' "$HOST" "$name" >&2
            exit 1; }
    done
    mkdir -p "$SEAT"
    cp "$HOST/swipl-web.js" "$SEAT/swipl-web.cjs"
    cp "$HOST/swipl-web.wasm" "$HOST/swipl-web.data" "$SEAT/"
    cp "$SRC/LICENSE" "$SEAT/LICENSE"
    # emcc marks the binary executable; it is an asset the loader reads.
    chmod 0644 "$SEAT/swipl-web.cjs" "$SEAT/swipl-web.wasm" "$SEAT/swipl-web.data" "$SEAT/LICENSE"
    built=$(node "$HERE/host.mjs" compiled-at "$SEAT")
    pinned() { sed -n "s/^$1[[:space:]]\\+\\(.*\\)\$/\\1/p" "$ROOT/tools/pymetta-host/swipl.pin" | head -1; }
    {
        echo "<!-- Purpose: say what the files beside this one are and where they come from."
        echo "Written by tools/wasm-host/build.sh vendor in MesTTo/MeTTa; rerun it rather than editing this. -->"
        echo "# The WebAssembly SWI-Prolog this package runs on"
        echo
        echo "\`swipl-web.cjs\` (emscripten's loader), \`swipl-web.wasm\` and \`swipl-web.data\`"
        echo "are one link of SWI-Prolog $(cat "$SRC/VERSION"), swipl-devel commit"
        echo "$(pinned commit), with every patch in MesTTo/MeTTa's"
        echo "\`tests/checks/host_workarounds/\` applied. They were compiled by"
        echo "npm-swipl-wasm's own Docker recipe at commit $(field upstream_commit), with"
        echo "emsdk $EMSDK, zlib $ZLIB and $PCRE2, and report \`compiled_at\` $built."
        echo
        echo "Beyond that recipe the build links SWI's archive, utf8proc and yaml packages"
        echo "and clib's uuid binding over libarchive (MesTTo/MeTTa-Library-Pack's pinned"
        echo "lib_compression snapshot), utf8proc $UTF8PROC, libyaml $LIBYAML and OSSP UUID"
        echo "$OSSP_UUID, and the native half of every library"
        echo "in that pack carrying \`support/static.cmake\`, which the library activates by"
        echo "name here where a native host loads a shared object. It also links"
        echo "emscripten's NODEFS, so under Node a program can mount a host directory into"
        echo "the host's file system through \`FS.filesystems.NODEFS\`; a browser never"
        echo "takes that path."
        echo
        echo "The data image holds SWI's library and, at /swipl/metta-host.pl, the"
        echo "declaration of the patches this build carries, which the engine checks at every"
        echo "boot. Rebuild with \`sh tools/wasm-host/build.sh && sh tools/wasm-host/build.sh"
        echo "vendor\` in MesTTo/MeTTa. SWI-Prolog's licence is \`LICENSE\` beside this file."
    } > "$SEAT/README.md"
    node "$HERE/host.mjs" check "$SEAT"
    printf 'build: vendored into %s\n' "$SEAT"
    exit 0
fi
[ $# -eq 0 ] || { echo "usage: build.sh [vendor]" >&2; exit 2; }

mkdir -p "$OUT"
DEST=$SRC sh "$ROOT/tools/pymetta-host/fetch-source.sh"

# fetch-source.sh resets the tree it fetched, untracked files included, and the
# package is removed and staged whole here each time rather than updated.
PACKAGE=$SRC/packages/metta
rm -rf "$PACKAGE"
mkdir -p "$PACKAGE/lib"
cp "$HERE/metta-package/CMakeLists.txt" "$PACKAGE/CMakeLists.txt"
staged=0
for fragment in "$ROOT"/lib/*/support/static.cmake; do
    [ -f "$fragment" ] || continue
    library=$(basename "$(dirname "$(dirname "$fragment")")")
    mkdir -p "$PACKAGE/lib/$library"
    for part in support vendor; do
        [ -d "$ROOT/lib/$library/$part" ] && cp -R "$ROOT/lib/$library/$part" "$PACKAGE/lib/$library/"
    done
    staged=$((staged + 1))
done
[ "$staged" -gt 0 ] || { printf 'build: no lib/*/support/static.cmake under %s\n' "$ROOT/lib" >&2; exit 1; }
printf 'build: staged the native halves of %s libraries as packages/metta\n' "$staged"

docker build \
    --build-arg EMSDK_VERSION="$EMSDK" \
    --build-arg ZLIB_VERSION="$ZLIB" \
    --build-arg PCRE2_NAME="$PCRE2" \
    --build-arg LIBYAML_VERSION="$LIBYAML" \
    --build-arg LIBYAML_SHA256="$LIBYAML_SHA256" \
    --build-arg UTF8PROC_VERSION="$UTF8PROC" \
    --build-arg UTF8PROC_SHA256="$UTF8PROC_SHA256" \
    --build-arg OSSP_UUID_VERSION="$OSSP_UUID" \
    --build-arg OSSP_UUID_SHA256="$OSSP_UUID_SHA256" \
    --build-arg JOBS="${JOBS:-}" \
    -f "$HERE/Dockerfile" -t "$IMAGE" "$SRC"

# The first link, taken out only to be booted: its compiled_at is the build's.
FIRST=$OUT/first-link
rm -rf "$FIRST"; mkdir -p "$FIRST"
docker run --rm -e OWNER="$OWNER" -e ARTEFACTS="$ARTEFACTS" -v "$FIRST:/out" "$IMAGE" \
    sh -euc 'cp $ARTEFACTS /out/ && chown "$OWNER" /out/*'

DECLARED=$OUT/declaration
rm -rf "$DECLARED"; mkdir -p "$DECLARED"
sh "$ROOT/tools/pymetta-host/declare-host.sh" declare "$SRC" "$DECLARED" \
    --built-by node "$HERE/host.mjs" compiled-at "$FIRST"

# The second link, with the declaration in the directory the link packs as
# /swipl. ninja lists the commands a target needs in dependency order, so the
# last is the target's own link; it is refused unless it links swipl-web.js.
# The old artefacts go first so a failed link cannot leave them behind to be
# copied out as if they were the new ones.
STAGE=$OUT/second-link
rm -rf "$STAGE"; mkdir -p "$STAGE"
docker run --rm -e OWNER="$OWNER" -e ARTEFACTS="$ARTEFACTS" \
    -v "$DECLARED/metta-host.pl:/declaration/metta-host.pl:ro" -v "$STAGE:/out" "$IMAGE" \
    sh -euc 'link=$(ninja -t commands src/swipl-web.js | tail -n 1)
             case $link in
                 *" -o src/swipl-web.js "*) ;;
                 *) echo "build: ninja lists no link for src/swipl-web.js last: $link" >&2; exit 1 ;;
             esac
             cp /declaration/metta-host.pl src/wasm-preload/metta-host.pl
             rm -f $ARTEFACTS
             sh -c "$link"
             cp $ARTEFACTS /out/ && chown "$OWNER" /out/*'

TAB=$(printf '\t')
node "$HERE/host.mjs" files "$FIRST" > "$OUT/first-link.files"
node "$HERE/host.mjs" files "$STAGE" > "$OUT/second-link.files"
if ! grep -q "$TAB/swipl/metta-host.pl\$" "$OUT/second-link.files" ||
   ! grep -v "$TAB/swipl/metta-host.pl\$" "$OUT/second-link.files" |
     cmp -s - "$OUT/first-link.files"; then
    printf 'build: the relinked /swipl is not the first link'"'"'s plus metta-host.pl:\n' >&2
    diff "$OUT/first-link.files" "$OUT/second-link.files" >&2 || true
    exit 1
fi

node "$HERE/host.mjs" check "$STAGE"
rm -rf "$HOST"
mv "$STAGE" "$HOST"
printf 'build: checked host in %s\n' "$HOST"
ls -l "$HOST"
