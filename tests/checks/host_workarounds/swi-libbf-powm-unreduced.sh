#!/bin/sh
# Purpose: answer whether powm/3 returns an unreduced 1 for a zero exponent,
#   which SWI-Prolog's LibBF emulation of mpz_powm() does in a build without
#   GMP. The WebAssembly host is this tree's one such build, so the question is
#   asked of it; a GMP build answers `absent` whatever it carries. Prints
#   `present` while it does and `absent` once the result is reduced by the
#   modulus.
# Assumes:
#   - node on PATH, and the host WASM_HOST_DIR names, or the vendored
#     extensions/node/_host (support/wasm_host.mjs)
# Guarantees:
#   - `present` iff powm(42, 0, 1) is 1 while powm(2, 10, 1000) is 24 and
#     powm(5, 0, 7) is 1; `broken` when a control fails or powm/3 raises
#     [measured 2026-09-24: present on the host vendored at extensions/node
#     b18f7d3, compiled at Sep 23 2026, 11:30:04, and absent on the host
#     tools/wasm-host/build.sh builds with
#     tests/checks/host_workarounds/swi-libbf-powm-unreduced.patch;
#     commit=WORKTREE]
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$here/support"
exec node --input-type=module -e '
import { wasmHost } from "./wasm_host.mjs";
const swipl = await wasmHost();
const answer = swipl.prolog.query(
  "catch((24 =:= powm(2, 10, 1000), 1 =:= powm(5, 0, 7), Unit is powm(42, 0, 1)), _, fail)").once();
const verdict = answer?.success !== true ? "broken"
  : answer.Unit === 0 ? "absent" : answer.Unit === 1 ? "present" : "broken";
console.log(verdict);
'
