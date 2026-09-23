# Purpose: build the WebAssembly SWI-Prolog the TypeScript seat runs the engine
#   on, from THIS repository's patched swipl-devel tree rather than from a
#   clone of an unpatched one.
#
# This is npm-swipl-wasm's own docker/Dockerfile at the commit
# tools/wasm-host/wasm.pin names, with one change: where upstream clones
# swipl-devel and checks out a commit, this copies the build context, which
# tools/wasm-host/build.sh has already filled with the output of
# tools/pymetta-host/fetch-source.sh -- the pinned source with every
# host-workaround patch applied. Everything else (the emsdk image, the zlib and
# pcre2 builds, the cmake flags, ctest) is upstream's, unedited, because the
# recipe is maintained there and the only thing this build changes is the
# source it compiles.
#
# Assumes: the build context IS the patched swipl-devel tree, with its
#   submodules checked out, and the EMSDK_VERSION, ZLIB_VERSION and PCRE2_NAME
#   build arguments come from tools/wasm-host/wasm.pin.
# Guarantees: /swipl-devel/build.wasm holds a complete wasm build tree, so the
#   swipl-web target can be relinked against an edited preload directory
#   without recompiling an object, which is how the host declaration gets into
#   the image the seat ships [tested: tools/wasm-host/build.sh, whose
#   host.mjs check passes on the relinked host only when its compiled_at is
#   the first link's].
# Fails when: a patch changes a file ctest covers and breaks it; the build then
#   stops at the ctest layer rather than shipping a host nothing checked.
ARG EMSDK_VERSION=latest
FROM emscripten/emsdk:$EMSDK_VERSION

# Installs build dependencies.
RUN apt-get update && apt-get install -y ninja-build rsync

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

# Upstream clones swipl-devel here and checks out SWIPL_COMMIT. The patched
# tree is the build context instead: fetch-source.sh has already cloned that
# commit, checked out the submodules and applied every patch, and a clone here
# would silently build an unpatched host.
COPY . /swipl-devel

# Build SWIPL
WORKDIR /swipl-devel/build.wasm
RUN mkdir -p /swipl-devel/build.wasm
ENV LDFLAGS="-s STACK_SIZE=1048576"
RUN cmake -DCMAKE_TOOLCHAIN_FILE=/emsdk/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_FIND_ROOT_PATH=/wasm \
  -DUSE_GMP=OFF \
  -DINSTALL_DOCUMENTATION=OFF \
  -DINSTALL_QLF=ON \
  -DINSTALL_PROLOG_SRC=OFF \
  -G Ninja ..
RUN ninja

RUN ctest -j $(nproc) --stop-on-failure --output-on-failure
