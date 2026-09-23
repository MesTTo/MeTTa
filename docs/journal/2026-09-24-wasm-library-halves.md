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
procedure. Every row now starts with a reading clause,
`metta_platform_absent(C) :- metta_platform_status(C, absent)`, which answers
by the capability's verdict and, on the first read that finds none, decides it
by `exists_source/1` over the row, the answer a load would give. A present
verdict retires the clause, so `metta_require_platform/2`, which runs inside
compiled hyperpose code and every `(timeout N Expr)`, reads a present
capability exactly as before, and the Python seat's enumeration of
`metta_platform_absent/1` needs no change. The first version kept the verdict
in the clauses themselves, and the next section says why that changed.

Deciding by `exists_source/1` exposed three rows naming less than their load
needs. `http` gains `library(thread_pool)`, which `thread_httpd` loads;
`https` gains `library(crypto)`, which `ssl` loads; `persistency` loses
`library(shlib)`, which was only how the lock loaded and which a static host
neither has nor needs.

### The census under threads

The first version decided a capability by retracting its reading clause and
asserting a fact in its place, inside `metta_platform_absent/1` itself. A probe
that forced two threads through each ordering with `wrap_predicate/4` gates
found three failures on an absent capability. A second decision made after the
first had asserted read present, because a call never sees a clause asserted
after it started (SWI's logical update view). A read that began between the
retract and the assert found no clause and read present. And two decisions
that both passed the "no fact yet" check left two facts, so the enumeration the
Python seat reads listed the capability twice. Present on a host without the
capability is the undefined-procedure failure the census exists to replace.

Each verdict now lives outside the clause database, in an SWI flag per
capability, read without a lock and decided under a mutex that reads it again,
which is the shape of SWI's own autoloader index (`boot/autoload.pl`,
`load_library_index/3`). A flag also escapes `transaction/1`, where a clause
would not: `(atomically ...)` evaluates inside one, and a verdict asserted
there would be rolled back with it. The clauses of `metta_platform_absent/1`
now change only when a present verdict retires its reading clause, after the
flag says present, and never inside a transaction; an absent capability keeps
its clause as its one answer. A load that finds a library a read did not makes
the capability present, since a library can be installed while the process
runs, and one that loses a library a read found raises, since turning the
capability absent would change an answer threads have already acted on.
`platform_census_threads.plt` forces each interleaving against the new
decision points; a mutant that puts the first version's fact back fails all
eight of its tests, the three race tests on the check that an absent
capability holds its reading clause and nothing beside it. The boot pays for
the mutex and the flag writes of the capabilities it loads: 344,012 inferences
against 343,852 before, read by `sh engine/bench.sh --counter-only boot` in one
battery for both trees.

Two idioms were weighed and not taken. A table computes its answer from its
own goal, and a load's verdict is not the answer of any goal. And
`library(settings)` declares values rather than computing them on demand.

### Per call, not at import

`lib_process`, `lib_socket` and `lib_http` declared `metta_requires/1`, which
refuses the whole library at import, so every pure door went with the
capability. They now load their platform libraries through the census and
guard each door that needs the capability, after the door's own argument
checks and before its first platform call, naming the door:
`process-run! is refused: this build does not have the subprocess capability,
because library(process) is absent`. `process-signals`, `http-server-url` and
an empty `socket-wait!` answer on a build without them. `lib_socket` reaches
its native half through four helpers, so the guard is in those four with the
door's name passed in.

Rejected: defining every lost import as a stub raising the refusal. It needs
no per-door guard, but the refusal would name `socket_create/2` rather than
the form the user called, against `metta_require_platform/2`'s own rule; the
engine's import door relies on a lost name staying undefined; and `lib_http`
calls `http_open` and `thread_httpd` internals module-qualified, which an
import stub cannot cover.

`http-header` needed the capability too: it canonicalises names with
`http_header`'s grammar. The reduced-platform child caught it, answering
`Unknown procedure: http_header:field_name/3` where the probe expected an
answer.

### The lock under emscripten

emscripten's `flock()` always answers 0, "Emscripten programs are a single
process" (`system/lib/libc/emscripten_libc_stubs.c` in emsdk 6.0.9), so a
linked `lock.c` would let a second handle open a store the first owns, which
42-database_lib checks. Under `__EMSCRIPTEN__` the lock keeps its own table of
claimed files, keyed by device and inode, owned by the claiming stream and
released by an `Sclosehook`, which SWI runs for every stream it closes. It
answers as Linux does: the holder may claim again, any other stream on the
file gets `EWOULDBLOCK`, and the claim ends with the stream.

### 09-conformance

`library(dcg/high_order)` is in the host's home and loads. The error was
`js_eval_error('ReferenceError: window is not defined', [window, location, ...])`:
the probe runs forms through `m.run` with nothing mounted and the engine's
working directory at `/`, so the fixture's relative path did not exist, and
SWI's `library(wasm)` load hook then took it for a browser URL and evaluated
`window.location` (`library/wasm.pl:412`), which Node lacks. `dcg/high_order`
loads only to render that error. With the examples tree mounted at its host
path and the working directory at the repository root, which is how
`sh tools/run.sh` runs an original natively, the import succeeds and both
checks answer as the original expects. The fixture is right; a runner has to
give the engine the files the original names.

### 35-math_lib

SWI's LibBF emulation of `mpz_powm()` (`src/libbf/bf_gmp.c:306`, unchanged on
master) sets its result to 1 and reduces it only inside the loop, so an
exponent of 0 returns 1 whatever the modulus; GMP answers `1 mod m`. The
WebAssembly host is configured `-DUSE_GMP=OFF`; the native host links GMP and
answers 0. Fixed in the host: `swi-libbf-powm-unreduced.patch` reduces the
initial 1. A GMP build never compiles the file, so the native host was
redeclared, not rebuilt, and its `compiled_at` is unchanged.

### Text holding U+0000

Found by the TypeScript corpus worker on tsmetta bf758a5:
`m.fn.stringFromCodes([97, 0, 129418])` answered the JavaScript string "a",
while `(string-codes (string-from-codes (97 0 129418)))` evaluated in the
engine answered `(97 0 129418)` and JavaScript text going in kept its NUL.
`get_chars()` in `src/wasm/prolog.js` (line 1924 at V10.1.14) decodes the
engine's UTF-8 with `UTF8ToString(ptr)`, which stops at the first zero byte,
and every string, atom and error text the engine hands JavaScript goes
through it. Read against emsdk 6.0.9 before patching: `UTF8ToString(ptr,
maxBytesToRead, ignoreNul)` with `ignoreNul` true decodes exactly
`maxBytesToRead` bytes (`findStringEnd` in `src/lib/libstrings.js`), and
`_PL_get_nchars` is in the build's `exports.json`. So `get_chars()` now calls
`PL_get_nchars()` and decodes the length it reports. The reproduction reads a
string and an atom holding U+0000, one with a supplementary character after
it so a length in characters rather than bytes would show, through the
vendored host, and answers `present` there.

### The rebuilt host

`JOBS=8 sh tools/wasm-host/build.sh` built it with ctest 58 of 58 in the
image, where the upstream package set had 53. Activating each name on it,
`lib_string`, `metta_pcre`, `lib_database`, `lib_compression`, `archive4pl`,
`unicode4pl`, `unicode_security4pl`, `uniname4pl` and `yaml4pl` are linked
beside upstream's `pcre4pl`, and `uuid` is not, since SWI's clib builds that
package's Prolog half alone under emscripten. The declaration carries 21 of 21
patches and the engine's check passes with the 19 it requires.

Every original, run under tsmetta on it from the repository root with the
examples tree mounted: 37 of 44 run every form. The other 7 refuse at their
first failing form with `PlatformCapabilityError`: 06 and 16 and 33 on
crypto, 31 on the environment listing, 32 on subprocess, 38 on http, 40 on
socket. Of the 22 the corpus probe had failing, 15 now run whole. Two later
forms differ by host rather than by capability. 31's `(platform-info family)`
answers `"emscripten"`, the flag this host sets in place of `unix`, `linux`
and `apple`, where the original pins the native `"unix"`; lib_system read
only the other three and answered `"unknown"` until it read that flag too.
And 33's `uuid-time!` refuses with lib_uuid's own domain error naming OSSP
UUID, since version 1 rests on uuid's foreign half, which the census's
`library(X)` rows cannot name.

### Version 1 UUIDs on the WebAssembly host

`uuid-time!` still refused on the rebuilt host, with lib_uuid's own error
naming OSSP UUID, and the reason was SWI's rather than the library's.
`packages/clib/CMakeLists.txt` puts the uuid plugin inside
`if(NOT EMSCRIPTEN)` and gives an emscripten build the Prolog half alone,
whatever LibUUID finds, and `uuid.pl` looks for its C half only through
`load_foreign_library/1`, which a static host has none of. OSSP UUID itself
builds with the pinned emsdk: under Node, a probe made version 1 UUIDs whose
node field is random with the multicast bit set, OSSP's answer where no MAC
address is found (RFC 4122 section 4.5), and version 4 ones. Its
`make install` fails on the `uuid` program, whose install runs the build
machine's `strip` on emcc's output, so the image makes only `libuuid.la` and
puts the library and header where `UUID_LIBRARY` and `LIBUUID_INCLUDE_DIR`
name them, which `FindLibUUID.cmake` takes in place of a search.

`swi-uuid-static-half-unlinked.patch` moves the plugin out of the
conditional and gives `link_uuid/0` a static branch. It sits at the top of
the ledger rather than under `packages/clib/`: it is written against the
swipl-devel root, from which a plain `git apply` reaches the submodule's
files, and the engine requires the patches at the top, where a directory of
its own would have needed a requirement nothing holds. The native host was
redeclared rather than rebuilt: it never takes the static branch, and
replacing its installed `uuid.pl` alone would leave `uuid.qlf` older than its
source, so every load of `library(uuid)` would read source and move the twins
that import it. On the host built with the patch the reproduction answers
`absent`, `uuid` is in the static extension table, and `33-uuid_lib` runs 48
of its 53 forms, the other five refusing on crypto.

### A test that raced

`lib_database.plt`'s abandoned-engine test waited for `finish_store/3`, which
runs inside `store_owner/2`, so its reopen could reach the lock before the
owner's cleanup closed the lock stream: 2 of 3 runs failed with
`database_lock_failed(_, 11)` at load average 91. It now waits for a cleanup
wrapped around `store_owner/2`, which follows the close, and 6 of 6 runs pass.
The record had seen it pass on re-run before, which is what a race looks like.
