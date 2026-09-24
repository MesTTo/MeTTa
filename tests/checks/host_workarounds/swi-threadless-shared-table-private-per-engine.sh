#!/bin/sh
# Purpose: answer whether the WebAssembly host still keeps a table declared
#   `as shared` private to each engine: without threads, get_answer_table()
#   in src/pl-tabling.c decided shared = false for every table, so two
#   engines asking one shared table each evaluated it, and a table died with
#   the engine that filled it. Prints `present` while the table's body runs
#   once per engine and `absent` once the second engine reads the first
#   one's table.
# Assumes:
#   - node on PATH, and the host WASM_HOST_DIR names, or the vendored
#     extensions/node/_host (support/wasm_host.mjs)
# Guarantees:
#   - `present` iff both engines answer [a,b,c] and the body ran twice;
#     `absent` iff both answer [a,b,c] and it ran once; `broken` otherwise,
#     so a host that answers wrongly reads as neither
#     [measured 2026-09-24: present on the host vendored at extensions/node
#     2ea06e2 (WebAssembly build 6); the same program answers Runs=2 on a
#     native single-threaded build of V10.1.14 and Runs=1 on that build with
#     tests/checks/host_workarounds/swi-threadless-shared-table-private-per-engine.patch;
#     commit=WORKTREE]
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$here/support"
exec node --input-type=module -e '
import { wasmHost } from "./wasm_host.mjs";
const swipl = await wasmHost();
const program =
  ":- table p/1 as shared. " +
  "p(X) :- flag(p_body, N, N+1), member(X, [a,b,c]). " +
  "ask(Xs) :- engine_create(L, findall(X, p(X), L), E), " +
  "engine_next(E, Xs0), engine_destroy(E), msort(Xs0, Xs).";
const answer = swipl.prolog.query(
  `open_string("${program}", S), load_files(shared_table_repro, [stream(S)]), ` +
  "close(S), ask(A), ask(B), flag(p_body, Runs, Runs), " +
  "format(atom(Answers), \"~w/~w\", [A, B])").once();
const runs = Number(answer?.Runs);
const verdict = answer?.success !== true || String(answer.Answers) !== "[a,b,c]/[a,b,c]" ? "broken"
  : runs === 2 ? "present"
  : runs === 1 ? "absent"
  : "broken";
console.log(verdict);
'
