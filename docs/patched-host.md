<!-- Purpose: how to get the patched SWI-Prolog the MeTTa engine runs on, for the installs that do not come with one. -->
# The patched host

The MeTTa engine runs only on a patched SWI-Prolog. Stock SWI-Prolog has
defects that crash the engine or change its answers:
[host-workarounds.md](host-workarounds.md) lists them, one entry each with a
reproduction. Of the entries a patch fixes, a stock 10.1.14 binary answers
`present` for 21 and aborts the process on one, the thread join that any
worker evaluating MeTTa can reach; the two janus entries reproduce through the
Python bridge, and three read the WebAssembly host rather than a native binary
(measured 2026-09-24 with `/usr/bin/swipl`).

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
   patch in `tests/checks/host_workarounds/` and then every patch in
   `tools/pymetta-host/host-only/` (see [Patches nothing
   requires](#patches-nothing-requires)), each in the tree it sits under, so
   the ones in `packages/swipy/` land in that submodule. It stops, naming the
   patch, if any one fails to apply.

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
   tree carries, host-only ones included, it records the patch's SHA-256, and
   it records the `compiled_at` of the launcher installed there. The engine
   believes that declaration only for that binary, because the C patches live
   in the binary. It exits nonzero if the tree lacks any patch step 1
   applies.

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
`extensions/node/_host/`. It needs Docker, Node and the network; `JOBS=8` in
its environment holds the compile to eight cores.

The recipe adds what the shipped libraries need beyond upstream's. SWI's
archive, utf8proc and yaml packages are built, over libarchive (from
lib_compression's own pinned snapshot), utf8proc and libyaml at the versions
the native host links, so `library(archive)`, `library(unicode)` and
`library(yaml)` load in the browser too, and clib's uuid binding is linked
over OSSP UUID 1.6.2, so version 1 UUIDs are made there as well. And every
library carrying
`support/static.cmake` (lib_string, lib_regex, lib_database, lib_compression)
has its native half linked into the host as a static extension, which the
library activates by name where a native host builds and loads a shared object
(`lib/_support/native_install.pl`). What the host still lacks is refused per
call, naming the capability: threads, time limits, processes, sockets, HTTP and
OpenSSL, since a WebAssembly module has none of them.

It also links emscripten's NODEFS (`-lnodefs.js` in the Dockerfile's
`LDFLAGS`), so a program running the host under Node can mount a host
directory into the host's file system with
`FS.mount(FS.filesystems.NODEFS, {root: dir}, dir)`. Mounting the working
directory at its own path and changing into it lets a relative path resolve
as it does on a native host. A browser never takes that path.

## Patches nothing requires

A host also carries fixes no requirement names: for defects nothing in this
repository meets, and for one met only inside the home
`tools/pymetta-host/assemble.sh` grafts into pymetta's Linux wheels, which is
built from every patch of both layers and so carries the fix by construction.
Each such patch sits in `tools/pymetta-host/host-only/`, at the path of the
swipl-devel tree it patches as the ledger's patches sit in
`tests/checks/host_workarounds/`, beside a reproduction of its defect that
carries its name. `fetch-source.sh` applies them after the ledger's, so one
may be written on top of a ledger patch, and `declare-host.sh declare` lists
them in `metta-host.pl` and exits nonzero on a tree that lacks one. No
requirement names them, so the engine boots on a host without them, and
[host-workarounds.md](host-workarounds.md) gives them no entry.

There are two. `swi-alarm-scheduler-exits-holding-lock.patch` unlocks
library(time)'s scheduler mutex after `alarm_loop()`'s loop in
`packages/clib/time.c`. Without it, a process that halts with alarms pending
can wait for ever in the library's halt hook: on a stock 10.1.14 the first of
the reproduction's twenty processes did, in each of three runs (measured
2026-09-25). The engine never halts that way, because `halt/1`
unwinds `call_with_time_limit/2`'s cleanup and removes its alarm first. The
WebAssembly build compiles no time plugin, so there the patch changes a file
nothing reads.

`swi-qlf-recompiles-unchanged-newer-source.patch` is upstream swipl-devel
b5da8260476b, which SWI-Prolog 10.1.15 ships: a `.qlf` file records a hash of
every source it was compiled from, in QLF format 72, and a `.pl` newer than its
`.qlf` recompiles it only when that hash says the content changed. 10.1.14
decided by time alone, and a home that arrives by installation carries the
times its installer wrote, in the installer's order: a fresh uv install of the
pymetta 0.9.2 wheel recompiled up to 51 of its bundled library `.qlf` files on
its first boot and wrote them into site-packages (measured 2026-09-25). A home
`ninja install` lays down keeps each source's time, and the WebAssembly home
ships its library as `.qlf` files alone, so only the wheels meet the defect,
and `tests/checks/check_wheel_first_boot.py` holds each wheel to a first boot
that rewrites nothing, with every bundled `.qlf` dated before its source. A
host carrying the patch writes format 72, which a host without it cannot load
and so recompiles; it still loads formats 68 to 71, whose files record no
hash and stay judged by time.

The `host-workarounds` lane runs each reproduction on the host it checks and
prints its answer: `absent` for a host built the way step 1 builds one,
`present` for one built without the patch. Neither answer fails the lane. A
patch with no reproduction beside it, or with two, and a reproduction that
answers neither word, do.

To add one, put the patch, `git diff` output against swipl-devel at the pin,
and its reproduction, `<name>.sh` or `<name>.pl` answering `present` or
`absent` on its last line, in `tools/pymetta-host/host-only/`. A patch whose
defect the engine, one of its seats or a shipped library meets on a host the
engine may boot on goes in the ledger instead.

## When a patch changes

A patch edited in `tests/checks/host_workarounds/` has a new digest, so a host
built before the edit is refused as `built from an older version of the
patch`, and a host built before a patch was added is refused as missing it.
A host-only patch is in no requirement, so no host is refused for lacking it
or for an older version of it; rebuild to carry the new one, and the
`host-workarounds` lane's `host-only` line says whether a host does.
Rebuild it from step 1, and the WebAssembly host with
`sh tools/wasm-host/build.sh && sh tools/wasm-host/build.sh vendor`. A patch to
a file the host never compiles needs no rebuild, only the declaration:
`swi-libbf-powm-unreduced.patch` changes LibBF, which a build linking GMP
leaves out; `swi-wasm-text-nul-truncation.patch` changes `src/wasm/prolog.js`,
which only the WebAssembly link reads; and
`swi-uuid-static-half-unlinked.patch` changes clib's build for an emscripten
build and a branch of `uuid.pl` only a statically linked host takes. So for a
native host apply them to the source tree and rerun `declare-host.sh declare`,
whose `compiled_at` is unchanged. A patch to one package's plugin or library
file needs that package rebuilt and installed, not the host:
`swi-unicode-map-empty-result-aborts.patch` and
`swi-unicode-nfkc-casefold-keeps-ignorables.patch` change packages/utf8proc,
so run `ninja plugin_unicode4pl library_qlf` in the host's build tree, install
the package with `cmake -DCMAKE_INSTALL_PREFIX=<prefix> -P
<build>/packages/utf8proc/cmake_install.cmake`, which puts `unicode.qlf` in
beside `unicode.pl` so the library still loads from its compiled form, and
rerun `declare-host.sh declare`.
A host other processes are running from is replaced, not rebuilt in place.
Install the new build into a prefix of its own, `swipl-patched.2`, declare it,
and move the path everything names onto it by renaming a symlink over it:
`ln -s swipl-patched.2 swipl-patched.next && mv -T swipl-patched.next
swipl-patched`. The first time, while that path is still the installed
directory, `ln -s swipl-patched.1 swipl-patched.1 && mv --exchange
swipl-patched swipl-patched.1` turns it into a symlink to the moved tree in one
step, since the exchange swaps the two names and the symlink's target is its
own old name. A running process keeps the libswipl it has mapped, so the old
tree stays. It is no longer a host of its own, though: its launcher finds
libswipl through a RUNPATH naming the original path, which now leads to the
new tree, so it runs as itself only with `LD_LIBRARY_PATH` and `SWI_HOME_DIR`
naming its own directories. A rebuild in an existing build tree recompiles
only what changed, and `compiled_at` is the `__DATE__` and `__TIME__` of
`src/os/pl-prologflag.c`, so touch that file first; otherwise the new binary
keeps the old identity, and a declaration cannot tell the two builds apart.

Each requirement is regenerated in the same change: `engine/host_patches.pl`
with `sh tools/pymetta-host/declare-host.sh require > engine/host_patches.pl`,
and pymetta's `extensions/python/metta/_binding/host_patches.pl` with
`sh tools/pymetta-host/declare-host.sh require packages/swipy` into that file.
The `host-declaration` lane fails until both are, and it names any tree holding
patches that no requirement covers.
