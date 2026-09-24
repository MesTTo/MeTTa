#!/bin/sh
# Purpose: answer whether the WebAssembly host's JavaScript bridge still starts
#   every := chain from `window`: prolog.js's eval_chain defaults its receiver
#   to `window` before it reads the chain, and Node and Web Workers have none,
#   so there every library(wasm) := call raises ReferenceError, the one
#   library(wasm)'s own sleep/1 makes on its asynchronous path included. Prints
#   `present` while X := 'Math'.max(1, 2), goal-expanded the way a compiled
#   clause is, raises that, and `absent` once it answers 2.
# Assumes:
#   - node on PATH, and the host WASM_HOST_DIR names, or the vendored
#     extensions/node/_host (support/wasm_host.mjs)
# Guarantees:
#   - `present` iff the call raises js_eval_error naming the missing window,
#     `absent` iff it answers 2, and `broken` for anything else, a query that
#     does not run included, so a host that evaluates nothing reads as neither
#     [measured 2026-09-24: present on build 7 as built without the patch,
#     absent on the same image relinked with
#     tests/checks/host_workarounds/swi-wasm-js-bridge-assumes-window.patch]
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$here/support"
exec node --input-type=module -e '
import { wasmHost } from "./wasm_host.mjs";
const swipl = await wasmHost();
const q = String.fromCharCode(39);  // a quote the shell string cannot carry
const answer = swipl.prolog.query(
  "expand_goal((X := " + q + "Math" + q + ".max(1, 2)), Goal), " +
  "catch((call(Goal), Result = value(X)), error(E, _), Result = raised(E)), " +
  "format(atom(Out), \"~q\", [Result])").once();
const out = answer?.success === true ? String(answer.Out) : "";
const verdict = out === "value(2)" ? "absent"
  : out.startsWith("raised(js_eval_error(") && out.includes("window is not defined") ? "present"
  : "broken";
console.log(verdict);
'
