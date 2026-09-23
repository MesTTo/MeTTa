// Purpose: boot the WebAssembly SWI-Prolog this tree ships, for a reproduction
//   whose defect lives only in that host.
// Assumes: node, and WASM_HOST_DIR naming a built host's directory; without it
//   the host is the one the Node seat vendors, extensions/node/_host, which is
//   the WebAssembly host this tree runs on.
// Guarantees: wasmHost() resolves to the booted module through
//   tools/wasm-host/host.mjs's own bootHost, printing only to stderr, so a
//   reproduction's stdout carries its verdict alone.
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { bootHost } from "../../../../tools/wasm-host/host.mjs";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "../../../..");

export const wasmHost = () =>
  bootHost(process.env.WASM_HOST_DIR ?? resolve(root, "extensions/node/_host"));
