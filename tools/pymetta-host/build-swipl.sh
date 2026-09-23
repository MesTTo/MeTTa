#!/bin/bash
# Build the patched SWI-Prolog inside manylinux and stage its whole home,
# alias-free and relocatable, ready to package.
#
# SWI is not a single shared library: it needs its HOME -- boot files, the
# Prolog library tree and the foreign .so set -- located at run time. That is
# why pyswip, swiplserver and the official janus-swi all decline to bundle it
# and require a system install. jdk4py is the precedent that does bundle a
# runtime with a home, and this follows it.
#
# OpenSSL comes from EPEL, not from the base image. AlmaLinux 8 ships OpenSSL
# 1.1.1k, which reached end of life in September 2023, and lib_http reaches
# library(http/http_ssl_plugin), so building against the base would hand every
# user of this wheel an EOL TLS stack. openssl3 3.5.5 is a parallel install:
# headers under /usr/include/openssl3, link libraries under /usr/lib64/openssl3,
# and the runtime sonames libssl.so.3 and libcrypto.so.3 in the default lib
# directory, which is where auditwheel later finds them to vendor.
set -euxo pipefail

source /repo/tools/pymetta-host/host-deps.sh
install_host_packages

cd /src
mkdir -p /out/build

# Found rather than spelled: a parallel install's prefix is the packager's
# choice and moves between releases, and a wrong guess is a ten-minute build
# that fails at the ssl package.
SSL_HEADER=$(find /usr/include -path '*openssl3*' -name opensslv.h | head -1)
[ -n "$SSL_HEADER" ] || { echo "openssl3 headers not found after install"; exit 1; }
SSL_INCLUDE=$(dirname "$(dirname "$SSL_HEADER")")
SSL_LIBDIR=$(dirname "$(find /usr/lib64 -path '*openssl3*' -name 'libssl.so' | head -1)")
[ -n "$SSL_LIBDIR" ] || { echo "openssl3 link libraries not found"; exit 1; }
echo "openssl3: include=$SSL_INCLUDE libdir=$SSL_LIBDIR"

CMAKE_ARGS=(
    -G Ninja
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX=/out/swipl
    -DOPENSSL_INCLUDE_DIR="$SSL_INCLUDE"
    -DOPENSSL_SSL_LIBRARY="$SSL_LIBDIR/libssl.so"
    -DOPENSSL_CRYPTO_LIBRARY="$SSL_LIBDIR/libcrypto.so"
    -DSWIPL_PACKAGES_JAVA=OFF
    -DSWIPL_PACKAGES_X=OFF
    -DINSTALL_DOCUMENTATION=OFF
    -DSWIPL_PACKAGES_TEST=OFF
)

# Reconfigure when the CONFIGURATION changes, not when build.ninja is absent.
# ninja re-runs cmake for an edited CMakeLists.txt and knows nothing about the
# argument list in this script, so keying on the file's existence would let an
# edited -DOPENSSL_* or a flipped -DSWIPL_PACKAGES_* be silently ignored and
# ship a tree built from the old cache. The key is the arguments themselves,
# so a stale configuration is unrepresentable rather than watched for.
CONFIG_KEY=$(printf '%s\n' "${CMAKE_ARGS[@]}" "$(cmake --version | head -1)" | sha256sum | cut -d' ' -f1)
cd /out/build
if [ "$(cat .config-key 2>/dev/null)" != "$CONFIG_KEY" ]; then
    echo "configuration changed, reconfiguring from scratch"
    cd / && rm -rf /out/build && mkdir -p /out/build && cd /out/build
    cmake "${CMAKE_ARGS[@]}" /src
    printf '%s' "$CONFIG_KEY" > .config-key
else
    echo "configuration unchanged, building incrementally"
fi
ninja -j "$(nproc)"
rm -rf /out/swipl
ninja install

# Alias-free and relocatable before anything links against it. Doing this here
# rather than after packaging is what makes the invariant hold by construction:
# janus then compiles against a libswipl whose soname is already the shipped
# one, so its _swipl.so records the right NEEDED instead of being repaired
# later. relocate.py runs second because canonicalise renames files and an
# RPATH is a function of where a file finally sits.
python3 /repo/tools/pymetta-host/canonicalise.py /out/swipl --built-prefix /out/swipl
python3 /repo/tools/pymetta-host/relocate.py /out/swipl
/out/swipl/lib/swipl/bin/x86_64-linux/swipl --version

# The declaration the engine's boot check reads (engine/host_check.pl): every
# patch the source tree carries, and the build of the launcher that ships. It
# runs last, so the launcher it reads its compiled_at from is the relocated one
# that goes into the wheel, and it fails the build when any patch is missing,
# so a half-patched host never reaches a wheel.
git config --global --add safe.directory /src
git config --global --add safe.directory /src/packages/swipy
sh /repo/tools/pymetta-host/declare-host.sh declare /src /out/swipl/lib/swipl
