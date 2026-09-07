/*
 * Purpose: put the browser kit the `::: run` fences need under the site's
 *   `public/` directory, or refuse and name the command that builds it.
 *
 * Usage: node scripts/bundle-browser.mjs [<seat directory>]
 *
 * The seat directory defaults to the one `runnable.mjs` names and is an
 * argument because the site and the seat do not have to stay siblings: after
 * the textbook split the seat is an installed package and its `browser/` and
 * `_runtime/` are inside `node_modules`.
 *
 * What is copied is exactly what a browser FETCHES, which is four things: the
 * ESM bundle, the source manifest, and the two wasm assets. `_runtime/` also
 * carries the `engine/` and `lib/` trees as files, which is how the NODE
 * platform mounts them; a browser reads their text out of `runtime.json`
 * instead and never asks for one of them
 * [source: extensions/node/src/platform-browser.ts:prepareBase, which fetches
 * runtime.json, wasm/swipl-web.wasm and wasm/swipl-web.data and nothing else;
 * commit=a8b50dae12518adb626bf2594258eeaaf4a7f76d]. Copying the trees as well would put 5 MB no reader ever
 * downloads into the site, and then again into its built output
 * [measured 2026-09-07: 7.8 MB copied where the seat's two directories hold
 * 11.4 MB, which this script's own last line prints the first half of;
 * command=npm run bundle:browser --prefix website;
 * fixture=the browser build `npm run build:browser` makes; commit=a8b50dae12518adb626bf2594258eeaaf4a7f76d].
 *
 * [tested: test_the_site_build_refuses_without_the_browser_kit; commit=a8b50dae12518adb626bf2594258eeaaf4a7f76d]
 */

import { cpSync, existsSync, mkdirSync, readdirSync, rmSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import process from "node:process";

import { ROOTS } from "../.vitepress/runnable.mjs";

/** How many bytes a file holds, or a directory's files together. */
function weigh(path) {
  if (!statSync(path).isDirectory()) return statSync(path).size;
  let total = 0;
  for (const entry of readdirSync(path, { withFileTypes: true })) {
    total += weigh(join(path, entry.name));
  }
  return total;
}

/** Everything a browser fetches, named under the seat and under the site. */
const ASSETS = [
  "browser",
  "_runtime/runtime.json",
  "_runtime/wasm/swipl-web.wasm",
  "_runtime/wasm/swipl-web.data",
];

const seat = process.argv[2] ?? ROOTS.seat;
const missing = ASSETS.filter((asset) => !existsSync(join(seat, asset)));
if (missing.length > 0) {
  process.stderr.write(
    `bundle-browser: ${missing.join(", ")} ${missing.length === 1 ? "is" : "are"} not in ${seat}.\n` +
      "The site serves the browser kit, so build it first:\n" +
      "  npm run build:browser --prefix extensions/node\n",
  );
  process.exit(1);
}

// The whole of each top-level copy goes first, so a chunk the last build
// emitted and this one does not cannot be served beside the current one.
for (const stale of ["browser", "_runtime"]) {
  rmSync(join(ROOTS.assets, stale), { recursive: true, force: true });
}
let bytes = 0;
for (const asset of ASSETS) {
  const source = join(seat, asset);
  const target = join(ROOTS.assets, asset);
  mkdirSync(dirname(target), { recursive: true });
  cpSync(source, target, { recursive: true });
  bytes += weigh(source);
}
process.stdout.write(
  `bundle-browser: ${(bytes / 1024 / 1024).toFixed(1)} MB copied into ${ROOTS.assets} from ${seat}\n`,
);
