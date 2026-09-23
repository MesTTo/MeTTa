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

### 35-math_lib

SWI's LibBF emulation of `mpz_powm()` (`src/libbf/bf_gmp.c:306`, unchanged on
master) sets its result to 1 and reduces it only inside the loop, so an
exponent of 0 returns 1 whatever the modulus; GMP answers `1 mod m`. The
WebAssembly host is configured `-DUSE_GMP=OFF`; the native host links GMP and
answers 0. Fixed in the host: `swi-libbf-powm-unreduced.patch` reduces the
initial 1. A GMP build never compiles the file, so the native host was
redeclared, not rebuilt, and its `compiled_at` is unchanged.
