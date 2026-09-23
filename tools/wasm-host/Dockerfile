# Purpose: build the WebAssembly SWI-Prolog the TypeScript seat runs the engine
#   on, from THIS repository's patched swipl-devel tree rather than from a
#   clone of an unpatched one, with the C the shipped libraries' native halves
#   need linked in.
#
# This is npm-swipl-wasm's own docker/Dockerfile at the commit
# tools/wasm-host/wasm.pin names, with five changes, each marked "Ours" below:
#   - where upstream clones swipl-devel and checks out a commit, this copies
#     the build context, which tools/wasm-host/build.sh has filled with the
#     output of tools/pymetta-host/fetch-source.sh (the pinned source with
#     every host-workaround patch applied) and with packages/metta, the
#     library pack's native halves;
#   - libyaml, utf8proc, libarchive and OSSP UUID are built into /wasm beside
#     upstream's zlib and pcre2, because SWI's yaml, utf8proc, archive and
#     clib uuid packages and lib_compression's binding link them; libarchive
#     comes from lib_compression's own pinned snapshot and ZIP correction;
#   - cmake is given the package list: every package whose source the context
#     carries, which Dockerfile.dockerignore decides, so that file is the one
#     statement of what this host is built with; and the static libarchive and
#     OSSP UUID, by the variables their packages take in place of a search;
#   - ninja and ctest take JOBS, so a shared machine can hold the build to a
#     share of its cores;
#   - LDFLAGS links emscripten's NODEFS beside upstream's stack size, so a
#     program running the host under Node can mount a host directory into its
#     file system.
# Everything else (the emsdk image, the zlib and pcre2 builds, the cmake
# flags, ctest) is upstream's, unedited.
#
# Assumes: the build context IS the patched swipl-devel tree with its
#   submodules checked out and packages/metta staged, and the build arguments
#   come from tools/wasm-host/wasm.pin and build.sh.
# Guarantees: /swipl-devel/build.wasm holds a complete wasm build tree, so the
#   swipl-web target can be relinked against an edited preload directory
#   without recompiling an object, which is how the host declaration gets into
#   the image the seat ships [tested: tools/wasm-host/build.sh, whose
#   host.mjs check passes on the relinked host only when its compiled_at is
#   the first link's]. A downloaded source whose sha256 is not the pinned one
#   stops the build.
# Fails when: a patch changes a file ctest covers and breaks it; the build then
#   stops at the ctest layer rather than shipping a host nothing checked.
ARG EMSDK_VERSION=latest
FROM emscripten/emsdk:$EMSDK_VERSION

# Installs build dependencies. Ours: pkg-config, which packages/utf8proc's
# CMakeLists requires to find libutf8proc.
RUN apt-get update && apt-get install -y ninja-build rsync pkg-config

# Download dependency sources
WORKDIR /wasm
ARG ZLIB_VERSION
ARG PCRE2_NAME
RUN wget --no-verbose -qO- https://zlib.net/zlib-$ZLIB_VERSION.tar.gz | tar xvz
RUN git clone --branch=$PCRE2_NAME --depth 1 https://github.com/PCRE2Project/pcre2

# Build the dependencies and install them in /wasm
WORKDIR /wasm/zlib-$ZLIB_VERSION
RUN emconfigure ./configure --static --prefix=/wasm
RUN EMCC_CFLAGS=-Wno-deprecated-non-prototype emmake make
RUN emmake make install

WORKDIR /wasm/pcre2/build
RUN emcmake cmake -DCMAKE_INSTALL_PREFIX=/wasm \
  -DPCRE2GREP_SUPPORT_JIT=OFF \
  -G Ninja .. $@
RUN ninja && ninja install

# Ours: the libraries the added packages link, static, into /wasm, each at
# the version the native host this tree runs on links (tools/wasm-host/wasm.pin
# says why), and each checked against its pinned sha256 before it is used.
ARG JOBS
ARG LIBYAML_VERSION
ARG LIBYAML_SHA256
ARG UTF8PROC_VERSION
ARG UTF8PROC_SHA256
WORKDIR /wasm
RUN wget --no-verbose -O libyaml.tar.gz \
      https://github.com/yaml/libyaml/archive/refs/tags/$LIBYAML_VERSION.tar.gz \
 && echo "$LIBYAML_SHA256  libyaml.tar.gz" | sha256sum -c - \
 && tar xzf libyaml.tar.gz && rm libyaml.tar.gz \
 && emcmake cmake -S libyaml-$LIBYAML_VERSION -B libyaml-build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/wasm \
      -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF \
 && ninja -C libyaml-build -j ${JOBS:-$(nproc)} install
RUN wget --no-verbose -O utf8proc.tar.gz \
      https://github.com/JuliaStrings/utf8proc/archive/refs/tags/v$UTF8PROC_VERSION.tar.gz \
 && echo "$UTF8PROC_SHA256  utf8proc.tar.gz" | sha256sum -c - \
 && tar xzf utf8proc.tar.gz && rm utf8proc.tar.gz \
 && emcmake cmake -S utf8proc-$UTF8PROC_VERSION -B utf8proc-build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/wasm \
      -DBUILD_SHARED_LIBS=OFF -DUTF8PROC_ENABLE_TESTING=OFF \
 && ninja -C utf8proc-build -j ${JOBS:-$(nproc)} install
# libarchive through lib_compression's own project, which checks the pinned
# snapshot's sha256, applies the ZIP correction and fixes the provider's
# options; configured without NATIVE_STAGE it builds and installs the provider
# alone. Only the project file and vendor/ are copied, and before the tree, so
# an edit elsewhere in the library keeps this layer.
COPY packages/metta/lib/lib_compression/support/CMakeLists.txt /wasm/lib_compression/support/CMakeLists.txt
COPY packages/metta/lib/lib_compression/vendor /wasm/lib_compression/vendor
RUN emcmake cmake -S /wasm/lib_compression/support -B /wasm/libarchive-build \
      -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/wasm \
      -DCMAKE_FIND_ROOT_PATH=/wasm \
 && ninja -C /wasm/libarchive-build -j ${JOBS:-$(nproc)} install
# OSSP UUID, whose C half packages/clib's uuid binding links for version 1
# UUIDs, from Debian's copy of the 1.6.2 release (OSSP's own server is gone),
# the source the native host is built from. Only libuuid.la is made:
# `make install` also installs the uuid program through shtool's `install -s`,
# which runs the build machine's strip on emcc's output and fails, and nothing
# here runs that program. The library and its header go where UUID_LIBRARY
# and LIBUUID_INCLUDE_DIR below name them.
ARG OSSP_UUID_VERSION
ARG OSSP_UUID_SHA256
RUN wget --no-verbose -O ossp-uuid.tar.gz \
      https://deb.debian.org/debian/pool/main/o/ossp-uuid/ossp-uuid_$OSSP_UUID_VERSION.orig.tar.gz \
 && echo "$OSSP_UUID_SHA256  ossp-uuid.tar.gz" | sha256sum -c - \
 && tar xzf ossp-uuid.tar.gz && rm ossp-uuid.tar.gz \
 && cd uuid-$OSSP_UUID_VERSION \
 && emconfigure ./configure --disable-shared --with-cxx=no --with-perl=no \
      --with-php=no --with-pgsql=no \
 && emmake make -j ${JOBS:-$(nproc)} libuuid.la \
 && install -m 644 .libs/libuuid.a /wasm/lib/ \
 && install -m 644 uuid.h /wasm/include/
# The Emscripten toolchain file replaces pkg-config's search path with the
# emscripten sysroot's; PKG_CONFIG_PATH is searched first and names /wasm.
ENV PKG_CONFIG_PATH=/wasm/lib/pkgconfig

# Upstream clones swipl-devel here and checks out SWIPL_COMMIT. The patched
# tree is the build context instead: fetch-source.sh has already cloned that
# commit, checked out the submodules and applied every patch, and a clone here
# would silently build an unpatched host.
COPY . /swipl-devel

# Build SWIPL
WORKDIR /swipl-devel/build.wasm
RUN mkdir -p /swipl-devel/build.wasm
# Ours: -lnodefs.js. SWI's swipl-web link names no emscripten file system
# library, and emscripten puts NODEFS in FS.filesystems only when one is
# linked [source: emscripten 6.0.9 src/lib/libfs.js, FS__deps and
# FS.staticInit], so the host saw its preloaded /swipl and memory alone, and
# tsmetta could not reach a repository-relative path the native engine opens.
# With NODEFS a Node program mounts a host directory into the host's file
# system; its setup runs only under Node, so the browser path is unchanged.
# CPython's and Pyodide's emscripten builds link it into their main program
# the same way [source: CPython configure.ac, LINKFORSHARED; Pyodide
# Makefile.envs, MAIN_MODULE_LDFLAGS]. It goes here because cmake takes
# LDFLAGS as CMAKE_EXE_LINKER_FLAGS, which every executable link carries,
# including the command build.sh's second link reruns. Appending it to that
# command instead links nothing new, since the Ninja generator closes a link
# with `&& :` and the flag lands after it [measured 2026-09-24: a swipl-web.js
# byte-identical to the image's own; commit=6456b9822f637bf3bd106e001abf862d3d6ab262].
# The swipl binary ctest runs links NODEFS already, through NODERAWFS.
ENV LDFLAGS="-s STACK_SIZE=1048576 -lnodefs.js"
# Ours: SWIPL_PACKAGE_LIST, every packages/*/CMakeLists.txt the context holds,
# which SWI takes verbatim and still closes over dependencies
# (cmake/PackageSelection.cmake). LibArchive_LIBRARIES names zlib beside the
# static libarchive, which packages/archive/CMakeLists.txt accepts in place of
# find_package, because its feature probes link libarchive alone and a static
# libarchive needs the codec it was built with. UUID_LIBRARY and
# LIBUUID_INCLUDE_DIR are what packages/clib's FindLibUUID.cmake takes in place
# of its search, which looks for OSSP's uuid-config and would otherwise find
# none.
RUN cmake -DCMAKE_TOOLCHAIN_FILE=/emsdk/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_FIND_ROOT_PATH=/wasm \
  -DUSE_GMP=OFF \
  -DINSTALL_DOCUMENTATION=OFF \
  -DINSTALL_QLF=ON \
  -DINSTALL_PROLOG_SRC=OFF \
  -DSWIPL_PACKAGE_LIST="$(cd .. && ls packages/*/CMakeLists.txt | cut -d/ -f2 | paste -sd';')" \
  -DLibArchive_LIBRARIES="/wasm/lib/libarchive.a;/wasm/lib/libz.a" \
  -DLibArchive_INCLUDE_DIRS=/wasm/include \
  -DUUID_LIBRARY=/wasm/lib/libuuid.a \
  -DLIBUUID_INCLUDE_DIR=/wasm/include \
  -G Ninja ..
RUN ninja -j ${JOBS:-$(nproc)}

RUN ctest -j ${JOBS:-$(nproc)} --stop-on-failure --output-on-failure
