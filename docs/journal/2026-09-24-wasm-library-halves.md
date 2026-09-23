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

### 35-math_lib

SWI's LibBF emulation of `mpz_powm()` (`src/libbf/bf_gmp.c:306`, unchanged on
master) sets its result to 1 and reduces it only inside the loop, so an
exponent of 0 returns 1 whatever the modulus; GMP answers `1 mod m`. The
WebAssembly host is configured `-DUSE_GMP=OFF`; the native host links GMP and
answers 0. Fixed in the host: `swi-libbf-powm-unreduced.patch` reduces the
initial 1. A GMP build never compiles the file, so the native host was
redeclared, not rebuilt, and its `compiled_at` is unchanged.
