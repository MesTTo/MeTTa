<!-- Purpose: how to get the patched SWI-Prolog the MeTTa engine runs on, for the installs that do not come with one. -->
# The patched host

The MeTTa engine runs only on a patched SWI-Prolog. Stock SWI-Prolog has
defects that crash the engine or change its answers:
[host-workarounds.md](host-workarounds.md) lists them, one entry each with a
reproduction, and a stock 10.1.14 binary answers `present` for 14 of those
reproductions and aborts the process on two. One of the two is the thread join
that any worker evaluating MeTTa can reach.

So the engine checks its host when it boots (`engine/host_check.pl`) and
refuses one that does not declare, at its current digest, every patch to
swipl-devel itself: the patches at the top of `tests/checks/host_workarounds/`.
The patches to janus sit under `packages/swipy/` there and are pymetta's to
require, since no other host loads janus, so pymetta checks them against the
same declaration once the engine has booted. Either refusal names each missing
patch and points here.

All of this belongs to the Prolog engine, which carries the 1.0 line and will
soon be replaced by an engine written in Rust; the README's Architecture
section says what carries over.

## Installs that already have it

pymetta's Linux x86_64 wheels for CPython 3.12, 3.13 and 3.14 carry the patched
host inside the package, as `metta/_host`, with the janus bridge built against
it. On those platforms this is the whole install:

```sh
pip install pymetta
```

pymetta activates that host before it loads janus. A `SWI_HOME_DIR` naming
another SWI home, or a `janus_swi` imported from somewhere else first, is
refused, because the bundled bridge and home are one build.

tsmetta, the TypeScript binding, carries its own. The WebAssembly SWI-Prolog it
boots on is built from the same patched source and ships inside the package, in
`extensions/node/_host/`, so on every platform Node runs on this is the whole
install:

```sh
npm install tsmetta
```

npm's `swipl-wasm` is refused like any other host without the declaration.

## Building it anywhere else

On macOS, Windows, ARM Linux, musl Linux, or any Python the wheels do not
cover, build the host from this repository. Every step below is a script the
release build runs too, so a host built this way is the one the Linux wheels
carry.

1. Fetch the pinned source with every patch applied:

   ```sh
   sh tools/pymetta-host/fetch-source.sh
   ```

   This clones swipl-devel at the commit `tools/pymetta-host/swipl.pin` names
   into `ai-tmp/swipl-src` (set `DEST` to put it elsewhere), and applies every
   patch in `tests/checks/host_workarounds/`, each in the tree it sits under,
   so the ones in `packages/swipy/` land in that submodule. It stops, naming
   the patch, if any one fails to apply.

2. Build and install it with CMake, into a prefix of your choosing:

   ```sh
   cmake -S ai-tmp/swipl-src -B ai-tmp/swipl-build -G Ninja \
       -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$HOME/swipl-patched" \
       -DSWIPL_PACKAGES_JAVA=OFF -DSWIPL_PACKAGES_X=OFF -DINSTALL_DOCUMENTATION=OFF
   cmake --build ai-tmp/swipl-build
   cmake --install ai-tmp/swipl-build
   ```

   `ai-tmp/swipl-src/CMAKE.md` is SWI-Prolog's own guide to the build and the
   libraries each package needs on each platform.

3. Declare it, so the engine can tell it from a stock host:

   ```sh
   sh tools/pymetta-host/declare-host.sh declare ai-tmp/swipl-src "$HOME/swipl-patched/lib/swipl"
   ```

   This writes `metta-host.pl` into the SWI home. For every patch the source
   tree carries, it records the patch's SHA-256, and it records the
   `compiled_at` of the launcher installed there. The engine believes that
   declaration only for that binary, because the C patches live in the
   binary. It exits nonzero if the tree lacks any patch.

4. Install the janus bridge from the PATCHED tree, not from PyPI:

   ```sh
   SWIPL="$HOME/swipl-patched/bin/swipl" pip install --force-reinstall ai-tmp/swipl-src/packages/swipy
   ```

   Limitation: janus's C half is compiled into the Python extension, not into
   `libswipl`, so the declaration, and pymetta's check of the janus patches
   against it, says only that the source tree carried them, not which janus
   the interpreter imports. A PyPI `janus-swi` on a patched home boots, and it
   still carries `janus-callback-exception-leak`, which keeps every exception
   a callback raised alive for the rest of the process.

Then install pymetta, put `$HOME/swipl-patched/bin` first on your `PATH`, and
leave `SWI_HOME_DIR` unset unless it names `$HOME/swipl-patched/lib/swipl`.

## The WebAssembly host

`sh tools/wasm-host/build.sh` builds the host tsmetta carries. It fetches the
patched source as step 1 does, compiles it with npm-swipl-wasm's own Docker
recipe at the emsdk, zlib and pcre2 versions `tools/wasm-host/wasm.pin` names,
declares the build with `declare-host.sh declare SRC HOME --built-by ...`,
which reads `compiled_at` by booting the built files under Node because the
host has no launcher to ask, and links the declaration into the host's home,
`/swipl`. It stops unless the engine's own check passes on the result.
`sh tools/wasm-host/build.sh vendor` then copies the host into
`extensions/node/_host/`. It needs Docker, Node and the network.

## When a patch changes

A patch edited in `tests/checks/host_workarounds/` has a new digest, so a host
built before the edit is refused as `built from an older version of the
patch`. Rebuild it from step 1, and the WebAssembly host with
`sh tools/wasm-host/build.sh && sh tools/wasm-host/build.sh vendor`.
Each requirement is regenerated in the same change: `engine/host_patches.pl`
with `sh tools/pymetta-host/declare-host.sh require > engine/host_patches.pl`,
and pymetta's `extensions/python/metta/_binding/host_patches.pl` with
`sh tools/pymetta-host/declare-host.sh require packages/swipy` into that file.
The `host-declaration` lane fails until both are, and it names any tree holding
patches that no requirement covers.
