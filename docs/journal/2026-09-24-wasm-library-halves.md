# The shipped libraries on the WebAssembly host

Goal: under tsmetta on the WebAssembly host `tools/wasm-host/build.sh` builds,
every shipped-library original in
`examples/ch08-data/08-03-the-shipped-libraries/` either runs agreeing with its
expected answers, or refuses at the first form that needs a capability the
host lacks, with the platform capability refusal (`PlatformCapabilityError`)
naming it. A library whose capability is missing still imports, and only the
call that needs the capability refuses, as `lib_crypto` has always done.

## 2026-09-24

Measured: 22 of the 44 originals failed a form under tsmetta e5849bc (engine
49e2b25, lib 33c2d50) on the host built at 02dc5471b. Three shapes:

- a library's native half was an undefined procedure: `lib_string_native`,
  `lib_regex_pcre`, `lib_database_native`, `lib_compression_native`;
- an SWI library the host does not carry was an undefined procedure inside a
  library that had imported without complaint: `library(yaml)`,
  `library(unicode)`, `library(socket)`, `http_open` and `thread_httpd`;
- 09-conformance died on `Loading /swipl/library/dcg/high_order ...`, and
  35-math_lib's `(math-power-mod 42 0 1)` answered 1.

### Why a native half was undefined

The halves load as shared objects: `support/native_build.pl` compiles them with
`swipl-ld -shared` and `support/native.pl` loads them with
`load_foreign_library/2`. The WebAssembly SWI links foreign code statically
(`cmake/port/Emscripten.cmake` sets `STATIC_EXTENSIONS ON` and
`BUILD_SWIPL_LD OFF`) and ships no `library(shlib)`, so the directive failed,
the load carried on, and the module exported names nothing defined.

A static host activates a linked extension by name,
`'$activate_static_extension'(Name)`, which calls `install_<Name>` from the
table `swipl_plugin(<Name> ...)` fills (`src/pl-load.c`,
`packages/cmake/PrologPackage.cmake`). Every half already names its install
function `install_<Name>`, so the name is the install function's own suffix
and needs no second spelling. All five C halves compile with the pinned emcc
6.0.9 and each object defines no global symbol but its install function, so
they can share one link with SWI's own packages.

Decided, per library:

| Library | Native half | On the WebAssembly host |
|---|---|---|
| lib_string | `string_native.cpp`, RapidFuzz, ISub | linked; compiled with `-fexceptions` because its error path throws |
| lib_regex | vendored `pcre4pl.c` over PCRE2 | linked against the PCRE2 the recipe already builds |
| lib_database | `lock.c` | linked; claims kept in process, see below |
| lib_compression | `archive_locale.c` with the vendored binding | linked against libarchive built from its own pinned snapshot |
| lib_unicode | SWI's `packages/utf8proc` | built, over utf8proc 2.10.0 |
| lib_yaml | SWI's `packages/yaml` | built, over libyaml 0.2.5 |
| lib_socket | `socket_native.c` over `library(socket)` | refused per call: a WebAssembly module has no sockets |
| lib_http | `http_open`, `thread_httpd` over sockets and threads | refused per call, for the same reason and for threads |
| lib_process | `library(process)` | refused per call: there are no processes to start |
| lib_crypto | OpenSSL | refused per call, as before |

A library that belongs in a static host carries `support/static.cmake`, its
own `swipl_plugin` call beside the `native_build.pl` that builds the shared
object, and `tools/wasm-host/build.sh` stages every such library as
`packages/metta`. `lib/_support/native_install.pl` activates the extension on
a static host and builds and loads the object anywhere else. It is its own
file because `native_build.pl` is an input of every object's build, and a
change to how a half is loaded is not a change to the object.

`lib_string`'s adapter turns every failed `PL_*` call into a thrown `Pending`,
and emscripten leaves exception catching off unless the compile and the link
both ask for it, so without `-fexceptions` an ordinary type error would abort
the instance. Every program linking `libswipl` links with it for that reason.

`lib_compression`'s libarchive is built by `lib_compression/support/CMakeLists.txt`
itself, configured without `NATIVE_STAGE`, which builds and installs the
provider alone; the checksum, the ZIP correction and the provider options are
then one description for both hosts. Under emcmake it found zlib and musl's
iconv, which is enough for ZIP, tar and CP437 names. The first attempt ran the
container as my own uid, and every `try_compile` link failed writing
emscripten's root-owned cache, which libarchive's configure reported as
`pid_t doesn't exist`; the image runs as root.

### Why an absent SWI library read as present

The capability census answered `present` for any capability nothing had
loaded: `metta_platform_absent/1` held a fact only where a load had FAILED, and
nothing loads yaml, unicode, socket, http, https, uri, markup, archive,
memory-files or persistency at boot. So `metta_requires(yaml)` admitted
`lib_yaml` on the WebAssembly host and its first call died on Unknown
procedure. Every row now starts with a clause
`metta_platform_absent(C) :- metta_platform_decide(C)`, which a load of that
capability retracts before deciding it, and which otherwise decides by
`exists_source/1` over the row on first read and retracts itself. A decided
capability then has no clause but its fact, so `metta_require_platform/2`,
which runs inside compiled hyperpose code and every `(timeout N Expr)`, reads
it exactly as before, and the Python seat's enumeration of
`metta_platform_absent/1` needs no change.

Deciding by `exists_source/1` exposed three rows naming less than their load
needs. `http` gains `library(thread_pool)`, which `thread_httpd` loads;
`https` gains `library(crypto)`, which `ssl` loads; `persistency` loses
`library(shlib)`, which was only how the lock loaded and which a static host
neither has nor needs.

### The lock under emscripten

emscripten's `flock()` always answers 0, "Emscripten programs are a single
process" (`system/lib/libc/emscripten_libc_stubs.c` in emsdk 6.0.9), so a
linked `lock.c` would let a second handle open a store the first owns, which
42-database_lib checks. Under `__EMSCRIPTEN__` the lock keeps its own table of
claimed files, keyed by device and inode, owned by the claiming stream and
released by an `Sclosehook`, which SWI runs for every stream it closes. It
answers as Linux does: the holder may claim again, any other stream on the
file gets `EWOULDBLOCK`, and the claim ends with the stream.

### 35-math_lib

SWI's LibBF emulation of `mpz_powm()` (`src/libbf/bf_gmp.c:306`, unchanged on
master) sets its result to 1 and reduces it only inside the loop, so an
exponent of 0 returns 1 whatever the modulus; GMP answers `1 mod m`. The
WebAssembly host is configured `-DUSE_GMP=OFF`; the native host links GMP and
answers 0. Fixed in the host: `swi-libbf-powm-unreduced.patch` reduces the
initial 1. A GMP build never compiles the file, so the native host was
redeclared, not rebuilt, and its `compiled_at` is unchanged.
