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

### NFKC_Casefold, and a result with nothing left in it

The C corpus found `nfkc-casefold` keeping U+00AD. UCD 16.0.0 constructs
NFKC_CF from NFKC, case folding "and removal of Default_Ignorable_Code_Points"
(DerivedNormalizationProps.txt, line 2986) and maps U+00AD, U+034F, U+115F,
U+180E, U+200B, U+2060, U+FEFF and U+E0001 to nothing; utf8proc's own
`utf8proc_NFKC_Casefold()` sets `UTF8PROC_IGNORE` for it. lib_unicode had
copied the flag set of SWI's `unicode_nfkc_casefold/2`, and that set omits
`ignore`. A test over those eight code points failed first, then passed with
`ignore` in the row.

The same suite's law comparing every form with SWI's own predicate then
aborted its process: `unicode4pl.c:464: unicode_map: Assertion '0' failed`.
`utf8proc_map()` answers 0, with an allocated buffer, when every code point is
removed, and SWI's `unicode_map()` takes only a positive length for success,
so a legitimately empty result reaches the `assert(0)` in its error switch; a
build without assertions fails the call instead. `ignore` makes a text of
soft hyphens such a result, and `stripmark` on a lone combining mark already
was one. So the fix is two host patches beside the library's one line:
`unicode_map()` answers the empty atom for a length of 0, and
`unicode_nfkc_casefold/2` passes `ignore`. The random alphabet of the law now
holds a soft hyphen, so the comparison with SWI's predicate covers the
removal too.

A native host needs the package, not the host, rebuilt: `ninja
plugin_unicode4pl library_qlf` in its build tree relinked `unicode4pl.so`
and recompiled `unicode.qlf` without touching `libswipl`, and the package's
own `cmake_install.cmake`, staged through `DESTDIR` and moved into the home
file by file, installed them. `unicode.qlf` has to go in with `unicode.pl`:
a source newer than its `.qlf` is loaded from source, which changes the cost
of every load of `library(unicode)`.

### A test that raced

`lib_database.plt`'s abandoned-engine test waited for `finish_store/3`, which
runs inside `store_owner/2`, so its reopen could reach the lock before the
owner's cleanup closed the lock stream: 2 of 3 runs failed with
`database_lock_failed(_, 11)` at load average 91. It now waits for a cleanup
wrapped around `store_owner/2`, which follows the close, and 6 of 6 runs pass.
The record had seen it pass on re-run before, which is what a race looks like.

### The host's own files

The TS corpus job found three originals failing under tsmetta 6663d06 on
build-5 by path alone: 41-compression_lib's
`examples/.../_fixtures/compression-data.zip` raised `SourceNotFoundError`,
and 09-conformance's `import_prolog_functions_from_file
"./examples/.../_fixtures/demo_provider.pl"` failed, while the same import by
an absolute path it had copied in answered true. The WebAssembly host sees
its preloaded `/swipl` and whatever a program writes into memory, and nothing
of the directory the native engine resolves those paths against.

Emscripten's bridge to Node's file system is NODEFS, and a link includes it
only when asked: `src/lib/libfs.js` in emsdk 6.0.9 adds `$NODEFS` to
`FS__deps`, and `NODEFS` to `FS.filesystems`, under
`LibraryManager.has('libnodefs.js')`. SWI's swipl-web link names no file
system library, so build-5's loader holds `FS.filesystems={MEMFS}`. CPython's
emscripten `configure.ac` and Pyodide's `Makefile.envs` link `-lnodefs.js`
into their main program. NODEFS's setup is a postset guarded by
`ENVIRONMENT_IS_NODE`, and it reads Node's `fs` through the loader's own
Node branch, so it brings no `require` the browser build does not already
map to an empty module.

The flag's home is the Dockerfile's `LDFLAGS`, which cmake takes as
`CMAKE_EXE_LINKER_FLAGS`, so it is in the command ninja records for
`src/swipl-web.js` and therefore in build.sh's second link. Appending it to
that recorded command does nothing, which was the first probe's result: the
Ninja generator writes a link as `: && em++ ... && :`, the flag landed after
the closing `:`, and the loader came out byte-identical. Put where `LDFLAGS`
lands, right after `-O3 -DNDEBUG`, the same relink of build-5's objects gave
`FS.filesystems={MEMFS,NODEFS}` and a loader of 223399 bytes against 216495,
with the `.wasm` and `.data` byte-identical. Under Node that relink mounted
the checkout at its own path and, with SWI's working directory changed into
it, resolved, sized, read and wrote repository-relative paths, saw a file the
host wrote after the mount, and still loaded `library(lists)` from `/swipl`.
Vendored into the node seat, it bundled for the browser and passed the
Chromium suite 24 of 24, as build-5 does in the same battery. The other link
the flag reaches is the `swipl` binary ctest runs, which links NODEFS already
through `NODERAWFS`. Giving the flag to swipl-web alone would have meant
target options in `packages/metta`, which holds the library pack's halves and
nothing else, or a patch to SWI's cmake, and the ledger is for SWI's defects.

Both builds' browser bundles print one esbuild warning, from SWI's
`src/wasm/prolog.js:1094`: `url_properties` tests `! size instanceof
Number`, which is `(!size) instanceof Number` and always false, so a URL
answered without a Content-Length reports size NaN rather than -1. It is
still there on swipl-devel master. Patching it changes what every host must
declare, which this build was asked not to do, so it is left for a later
one (`i-url-size-nan` in the record).

### Build-6, and two SWI defects the C seat found

Build-6 is the NODEFS recipe built from a fresh clone carrying 26 patches,
the two below among them: compiled at Sep 24 2026, 00:02:59, ctest 58 of 58,
26 of 26 declared, and the engine's check passing with the patches it
requires. Against build-5 it is unchanged where it should be. Its browser
bundle passes the Chromium suite 24 of 24 with none skipped, the packed
consumer boots, and the 44 originals give 37 runs and 7 refusals with no
verdict or count moved. The census and the U+0000 probe print the same
lines. It adds what it should: packed into tsmetta 692d696, with the
checkout mounted at its own path through NODEFS and the engine's working
directory changed into it, 41-compression_lib runs 70 of 70 and
09-conformance 4 of 4, and 16-the_prolog_rung loses its three relative-path
failures, keeping only its crypto refusals. With nothing mounted, the TS
corpus job's `SourceNotFoundError`s come back.

The first defect is item 2 of docs/journal/2026-09-06-swi-defects-to-report-upstream.md,
met again from the C seat. `signalGCThread()` reads the calling thread's
Prolog flags before anything else, so a plain pthread whose erases
unregister atoms past the atom-GC margin dies of SIGSEGV. The C corpus job's
probe, erasing twice `agc_margin` records on such a thread, died 3 runs of 3.
The suggested fix, returning when there is no engine, removes the crash and
drops the request with it. With the GC thread already started by the main
thread, 20000 records erased on an engineless thread left the atom-GC count
at 1 for five seconds, 3 of 3. So the patch hands the request to a GC thread
that is already running, which `gc_running()` finds from `GD` alone, and the
count reaches 2, 3 of 3. Whether to start a GC thread is the per-thread
`gc_thread` flag, which an engineless thread has no copy of, so that stays
with engines.

The second is `abolishProcedure()`'s imported-link branch, which builds the
procedure's new definition by hand beside `lookupProcedure()`. The C corpus
job traced an invalid read to its share count of 0. Setting the count alone
was built and run: the invalid read went, and valgrind still read the
branch's argument info uninitialised, a second field the two initialisations
disagree on. The fix is one initialiser, `newDefinition()`, for both. The
engine meets the branch on every boot: on the host before the patch, both
the source boot and the qlf boot read that argument info uninitialised,
allocated in `abolishProcedure()` under the engine's own
`redefine_system_predicate(exists_file(_))`. With the patch the source boot
is clean. The qlf boot keeps one unrelated context, 169 reads of a stack
buffer in `expand_file_name/2` that the host before the patch shows too, on
the same regeneration path.

That patch rewrites the lines `swi-concurrent-import-removal-resets-provider`
rewrote, so it sorts after it and is written against its result. The stack
then broke the declaration. `declare-host.sh` asked each patch alone whether
it could be reverse-applied, and the earlier patch could not while the later
one held its context, so the native tree read 25 of 26. It now reads the
stack as quilt pops a series, last first, on a copy of the files the patches
name. Rebuilding also showed `fetch-source.sh` could not run twice on one
clone: it reset only the top tree and `packages/swipy`, while the uuid and
unicode patches edit `packages/clib` and `packages/utf8proc` from the top.

The native host was switched, not rebuilt in place, since a dozen jobs had
its libswipl mapped. The source tree took both patches, the build tree
installed into `swipl-patched.2`, with `pl-prologflag.c`
touched so the build stamped its own `compiled_at` (Sep 24 2026, 09:57:51),
and that was declared 26 of 26. `swipl-patched` then became a symlink to the
moved old tree by one `mv --exchange`, and a symlink to the new one by one
rename. Both reproductions read present 3 of 3 before the switch and absent 3
of 3 after it. One consequence: the old tree's launcher finds libswipl
through a RUNPATH naming the original path, so it now loads the new library
unless `LD_LIBRARY_PATH` says otherwise.

The two patches land with the requirement. The host-declaration lane
regenerates `engine/host_patches.pl` from every patch at the top, so carrying
a patch is requiring it. The change therefore went in with the Node seat's
advance to build-6, the first commit at which both hosts declare them.

### Build 9: ten more patches, and a 4 GiB memory

Build 9 carries 36 patch files, build 6's 26 and ten more, and links the
WebAssembly host with a 4 GiB memory maximum. It is two hosts built from one
source stack. The WebAssembly one was compiled at Sep 24 2026, 06:12:34 UTC:
ctest 58 of 58, 36 of 36 declared. The native one is
`swipl-patched.5`, compiled at Sep 24 2026, 16:08:19: ctest
91 of 93, with `pldoc:man_links` and `utf8proc:uts39` failing as they do on
every build here. Items 6 to 15 of
docs/journal/2026-09-06-swi-defects-to-report-upstream.md describe all ten for
upstream. Nine are carried here as `Patch:` entries in
docs/host-workarounds.md, each with its reproduction, and the engine requires
them at boot. The alarm scheduler's is built into both hosts and not carried,
below. Every native reproduction carried answers present on the build-6 host
and absent 3 of 3 on `.5`. The two WebAssembly ones answer present on build 6
and absent on build 9.

A patch is carried only where the engine, one of its seats or a shipped
library meets its defect, or where a carried patch is written on top of it,
and each entry now says which: the C seat for the halt patch, the Python seat
for the owner-beneath one, and the Node seat for the engine-query, window,
heap, destroyed-leader and threadless ones. Two carried patches meet no defect
of the engine's own. The reeval-prepare patch is carried because the
threadless patch is written on top of it and of the owner-beneath patch, and
applied to the pinned source without either it fails in `src/pl-tabling.c`.
The trie patch is the other, below. The rule follows from this engine's being
replaced by one in Rust: a host patch earns its keep by a defect the engine
meets, not by one it could.

Builds 7 and 8 came first, and neither landed. Build 7 carried 34 files, two
of them the TypeScript corpus work's first tabling pair, and was vendored as
node a9e3b4b. That work then replaced its pair with four patches. Two of the
four are new, and native `.3` answers present to both, so build 8 and native
`.4` were made from the 36, and build 8 was vendored as node 579cdd2. Build 8
then read `(complete-call 3)` where a threaded host reads 2, and the
threadless patch was corrected (below), so build 9 and `.5` are build 8 and
`.4` made again with the corrected patch. Build 9 was vendored as node
9e693bd, which the superproject has pinned since b988bd2bc. The vendoring of
build 7 also missed a step every earlier host had:
`sh extensions/node/bench.sh --update`, which stamps
`benchmarks/baseline.json` with the host's digest. So node-bench refused on
counter-configuration drift from a9e3b4b until build 8's vendoring re-stamped
it, and build 9's re-stamps it again.

The trie patch, `swi-trie-gen-empty-hashed-root`, is the qlf-halves work's,
and the one carried patch whose defect nothing here meets:
engine/metta/reference_refresh.pl builds a fresh trie instead of emptying
one. Its entry keeps that `Workaround:` site beside the new `Patch:` field.
Both hosts were built with the patch, and the host-workarounds lane fails a
Workaround-only entry once its host no longer shows the defect: on `.5` the
reproduction answers absent, and the lane asked to lift the site at
engine/metta/reference_refresh.pl:179. So the entry names the patch the hosts
carry rather than a host being rebuilt to take a real fix back out, and the
requirement it adds is one every shipped host already meets.

#### Halt and a thread being created

The C seat's corpus found that halt passes over a thread `thread_create/3`
has marked created and `start_thread()` has not yet marked running
(extensions/cmetta 697eff4, `make runtime-halt-created-thread`). Upstream
master at d7d2a2bb8f5b has the same `default: break;` in
`exitPrologThreads()`, so there was no upstream fix to take. The C probe,
eight detached threads and an immediate `PL_cleanup(0)`, died 3 runs of 3
on the build-6 host (each run is twenty processes). The patch counts a
created thread and tells it to leave before it runs its goal. It also closes
the window where a creation straddles the start of halt, by repeating the
halt test under `L_THREAD`.

On the WebAssembly host the question does not arise. `exitPrologThreads()`,
`start_thread()` and the rest are inside `O_PLMT`, which that build leaves
undefined (`build.wasm/src/config.h` holds `#undef O_PLMT`), so none of it is
compiled. The `threads` flag there is false and `thread_create/3` does not
exist, so there is no thread to be created during halt. Carrying the patch
in that tree changes nothing it builds.

#### Sleep under Node

`(sleep 0.01)` failed in every tsmetta job, for two reasons, and fixing the
first exposed the second.

library(wasm)'s `sleep/1` asks `is_async/0`, which is `'$can_yield'`, and
takes the asynchronous path when it succeeds: it builds a promise with
`X := prolog.promise_sleep(S)` and awaits it. `prolog.js`'s `eval_chain()`
starts a chain with no receiver from `window`, which Node does not have, so
the call raised `ReferenceError: window is not defined` before looking at the
chain (`swi-wasm-js-bridge-assumes-window`, fixed by `globalThis`).

With the chain evaluating, the await ran, and inside an engine it aborted the
process. `engine_create/3` opens its query with `PL_Q_ALLOW_YIELD` so that
`engine_yield/1` works, and that flag is all `'$can_yield'` and the foreign
yield check read, so a foreign yield inside an engine is let through to
`engine_next/2`, which handles only `engine_yield/1`'s code. Its default
branch raises without restoring the caller's engine. Natively the same C
probe dies of SIGSEGV. The patch (`swi-engine-query-offers-foreign-yield`)
marks an engine's query with a kernel-only `PL_Q_INTERACTOR` flag and makes
one test, `takes_foreign_yield()`, the thing every yield check asks. Inside
an engine `'$can_yield'` then fails, library(wasm) falls back to
`system:sleep/1`, and a foreign yield there is refused with the existing
permission error. Lua refuses a yield across a C call boundary the same way.
Through the seat on build 9, `(sleep 0.01)` answers in 15 ms and
`(sleep 0.25)` in 252 ms, and the next form answers.

#### 2 GiB and 4 GiB

At 2 GiB, emscripten's default maximum, the Node seat refused ch18's
02-holbenchmark at the stack limit with 1.55 GiB resident, and the corpus's
upto3 at 1.54 GiB. At 4 GiB build 9 runs them at 2.32 GiB and 2.27 GiB.
Above 2 GiB emscripten's JavaScript has to read pointers as unsigned, which
it does only for a build that asks, and V8 has grown a wasm32 memory to
4 GiB since Chrome 83. Here Chromium 153, Firefox 155 and WebKit 26.6 each
grew one past 2 GiB, to 2,621,440,000 bytes. The Chromium suite passes 24 of 24
on build 9 as on build 8.

05-matespacefast does not fit either way. Natively it peaks at 3.83 GiB
resident. On the 4 GiB link it hits "Stack limit (1.0Gb) exceeded" with
1.66 GiB resident, and with the stack limit raised to 3.5 GB the heap refuses
a growth first, with 1.56 GiB resident.

#### A refused heap reported as a stack limit

That last refusal used to read "Stack limit (1.0Gb) exceeded", at the same
depth whatever the limit was. When `stack_realloc()` fails, `grow_stacks()`
returns the stack's own overflow code, the one a stack at its limit returns,
so the message names the wrong resource. Natively the same shows under
`ulimit -v 1000000` with an 8 GB stack limit: the refusal comes at a
`globalused` of 524,287 KB.

The first patch returned `MEMORY_OVERFLOW` so that `raiseStackOverflow()`
would raise `ERR_NOMEM`, and it crashed. `PL_error()` builds its ball on the
global stack the heap had just refused, asks the heap again, and under gdb
recursed through `PL_copy_term_ref()` and `growStacks()` until the C stack
overflowed. The patch that landed (`swi-heap-refusal-reported-as-stack-limit`)
keeps the codes. `grow_stacks()` records per thread that its last growth
failed in `malloc()`, and `outOfStack()`, the one path that can raise with no
heap left because it writes its ball into the spare stacks, names
`no_memory` then. The WebAssembly message now reads "Not enough resources:
no_memory".

#### The alarm scheduler

Build 7's native ctest hung for forty minutes in `swipl:engines`. The core
had the main thread in `PL_cleanup()`, then library(time)'s `cleanup()`,
then `pthread_mutex_lock()`, and no scheduler thread left: `alarm_loop()`
returns with its mutex held when it sees the stop flag, and `cleanup()`
signals it once per pending alarm before taking that mutex itself. Twenty
processes that each install a thousand far alarms and halt reproduce it in
each of three runs on the build-6 host and in none of three on `.5`
(`swi-alarm-scheduler-exits-holding-lock`). The WebAssembly build compiles
none of it, because packages/clib/CMakeLists.txt declares the time plugin
only off emscripten and with threads, and library(time) is absent there.

The engine never meets it, so the patch is built into `.5` and not carried.
A program that exits inside a max-time bound halts through `halt/1`, which
unwinds `call_with_time_limit/2`'s cleanup and removes the alarm before
`cleanup()` runs: twenty runs of `!(pragma! max-time 30)` then `!(exit! 0)`
all exited on `.2`. So it has no ledger entry and no requirement, and item 11
of the upstream list records it.

#### Shared tables between engines

The TypeScript corpus work brought four tabling patches.

- A leader destroyed inside its engine left its shared tables owned by the
  dead engine. Natively that hangs or crashes the next claim, and without
  threads it prints `tabling(unexpected_result(...))` on every destroyed job
  (`swi-destroyed-leader-keeps-shared-table`).
- In a threaded build `'$tbl_reeval_prepare'/2` unified a clause reference
  past its two arguments after waiting for a thread that re-evaluated the
  table, and succeeded where it should fail
  (`swi-reeval-prepare-writes-past-its-arguments`).
- A claim whose owner is suspended beneath it on the same OS thread waited
  for ever, because the owner runs again only once the claimant returns
  (`swi-shared-table-waits-for-owner-beneath`). The claim now walks the chain
  of engines suspended beneath it and raises
  `permission_error(wait, shared_table, Variant)` when it finds the owner.
- Without threads, a table declared `as shared` was private to each engine,
  so a table never outlived the tsmetta ask that filled it
  (`swi-threadless-shared-table-private-per-engine`). The patch, regenerated
  over the two above, moves the shared variant table and table ownership
  from `O_PLMT` to `O_ENGINES`. An engine that meets a table another engine
  owns then suspends through `prolog:tabling_wait/1`, and where no hook is
  defined it raises `permission_error(wait, shared_table, Goal)`.

The third is the one the Python seat met. The provider-carry work's
reproduction, ai-tmp/ai-pc/tabling/same-thread.py, has a Python op that
Prolog calls while one engine completes a shared table, and that op pulls a
lazy view of the same call. Its `callback` and `callback-incremental`
variants hung on the build-6 host. On `.5`, through janus, both raise the
permission error 0.37 s into the run, naming
`'$metta_exec:&pyspace_1':reach(n0,_,_)` and saying the engine completing it
is suspended beneath the call on the same OS thread. The private and
other-variant callbacks, and the plain collapse, complete as before.

#### One completed call per re-evaluation

Build 8 carried an earlier form of the threadless patch, and on Node it read
`(complete-call 3)` in
examples/ch18-performance/18-02-memoisation-and-tabling/12-tabling_statistics.metta,
which expects 2. Pure SWI shows the difference. For a table declared
`(incremental,shared)`, `table_statistics/3` reads `complete_call` as 1, 1,
2, 3 across call, assert, call and call on `.2`, `.4` and `.5`, and as 1, 1,
3, 4 on build 8. That form's threadless branch of
`'$tbl_reeval_prepare_top'/2` claimed a complete table without its compiled
clause and answered the table's trie, which is a private table's path, so
`trie_gen_compiled/2` counted one more completed call per re-evaluation. The
corrected patch claims with a clause reference, as the threaded branch does,
except for a moded table, which still answers its trie for
`moded_gen_answer/3`. Build 9 reads 1, 1, 2, 3, and 12-tabling_statistics
passes on it, where build 8 fails its last form with `(complete-call 3)`.

On a threaded build the threadless patch compiles to the same instructions
apart from `__LINE__` immediates: `.5`'s `libswipl.so` differs from `.4`'s in
one instruction, a line number 8 lines on, the lines the corrected branch
grew by. Its boot file gains branches a threaded build never takes. Without
threads, the four patches together differ from the source build 7 was made
from in the re-evaluation count above, and otherwise in `__LINE__`
immediates and one builtin atom, `shared_table`. The threadless patch creates
`tests/tabling/test_engine_shared.pl`, and `fetch-source.sh` then refused it
on a clone it had already patched: `pristine_tree` reset tracked files and
left the created one. It now also removes untracked files that are not
ignored (5a05a59e9).

#### One recorded, not patched

An answer holding a compound named `[]`, which SWI-7's block syntax builds,
leaves `type_error(atom, [])` pending in `prolog.js`'s `toJSON()`, and the
next query from JavaScript fails with it once. Nothing this engine sends
across the bridge has that shape, so it is item 16 of the upstream list and
not a patch.
