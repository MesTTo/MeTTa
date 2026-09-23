#!/bin/sh
# Purpose: answer whether the WebAssembly host still lacks uuid's C half:
#   packages/clib built it only where shared objects load, and uuid.pl looked
#   for it only through library(shlib), so a statically linked host answered
#   every uuid/2 call from the Prolog alternative, which makes version 4 and
#   refuses version 1. Prints `present` while a version 1 UUID is refused, and
#   `absent` once one is made.
# Assumes:
#   - node on PATH, and the host WASM_HOST_DIR names, or the vendored
#     extensions/node/_host (support/wasm_host.mjs)
# Guarantees:
#   - `present` iff a version 4 control is made while a version 1 UUID is not;
#     `broken` when the control fails too, so a host whose library(uuid) does
#     not load reads as neither answer
#     [measured 2026-09-24: present on the host vendored at extensions/node
#     ab9d98a, compiled at Sep 23 2026, 20:24:50, and absent on the host
#     tools/wasm-host/build.sh builds with
#     tests/checks/host_workarounds/swi-uuid-static-half-unlinked.patch,
#     compiled at Sep 23 2026, 21:34:12; commit=6456b9822f637bf3bd106e001abf862d3d6ab262]
set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$here/support"
exec node --input-type=module -e '
import { wasmHost } from "./wasm_host.mjs";
const swipl = await wasmHost();
const once = (goal) => swipl.prolog.query(goal).once();
const control = once(
  "use_module(library(uuid)), uuid(U, [version(4)]), uuid_property(U, version(V))");
const timed = once(
  "catch((uuid(U, [version(1)]), uuid_property(U, version(V))), _, V = refused)");
const verdict = control?.success !== true || Number(control.V) !== 4 ? "broken"
  : timed?.success === true && Number(timed.V) === 1 ? "absent"
  : "present";
console.log(verdict);
'
