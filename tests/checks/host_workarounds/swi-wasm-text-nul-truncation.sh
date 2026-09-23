#!/bin/sh
# Purpose: answer whether the WebAssembly host still cuts text at U+0000 on its
#   way into JavaScript: prolog.js's get_chars read the engine's UTF-8 with
#   UTF8ToString up to the first zero byte. Prints `present` while a string
#   and an atom holding U+0000 arrive shortened, and `absent` once both arrive
#   whole.
# Assumes:
#   - node on PATH, and the host WASM_HOST_DIR names, or the vendored
#     extensions/node/_host (support/wasm_host.mjs)
# Guarantees:
#   - `present` iff a NUL-free control arrives whole while "a", U+0000, U+1F98A
#     arrives as anything else; `broken` when the control does not, so a host
#     that decodes nothing right reads as neither answer
#     [measured 2026-09-24: present on the host vendored at extensions/node
#     b18f7d3, compiled at Sep 23 2026, 11:30:04, and absent on the host
#     tools/wasm-host/build.sh builds with
#     tests/checks/host_workarounds/swi-wasm-text-nul-truncation.patch;
#     commit=WORKTREE]
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$here/support"
exec node --input-type=module -e '
import { wasmHost } from "./wasm_host.mjs";
const swipl = await wasmHost();
const answer = swipl.prolog.query(
  "string_codes(Plain, [97,98]), string_codes(Text, [97,0,129418]), " +
  "atom_codes(Name, [97,0,98])").once();
const text = (value) => (value === undefined ? undefined : String(value));
const verdict = answer?.success !== true || text(answer.Plain) !== "ab" ? "broken"
  : text(answer.Text) === "a\u0000\u{1F98A}" && text(answer.Name) === "a\u0000b" ? "absent"
  : "present";
console.log(verdict);
'
