/**
 * Purpose: boot a built WebAssembly SWI-Prolog from its artefacts and answer
 *   the two questions its build asks of it: which build it is, and whether the
 *   engine's own boot check accepts it.
 *
 * Usage:
 *   node tools/wasm-host/host.mjs compiled-at DIR   print the compiled_at flag
 *   node tools/wasm-host/host.mjs check DIR         run engine/host_check.pl's
 *                                                   metta_require_patched_host
 *   node tools/wasm-host/host.mjs files DIR         list every file the host
 *                                                   sees under its home, /swipl
 *   DIR holds swipl-web.cjs or swipl-web.js beside swipl-web.wasm and
 *   swipl-web.data: what tools/wasm-host/build.sh takes out of the image, and
 *   what extensions/node/_host/ ships.
 *
 * Assumes: node, and a DIR whose three artefacts are one link. The glue is
 *   CommonJS as emscripten emits it, so it is required through createRequire.
 * Guarantees:
 *   - `compiled-at` prints the flag and nothing else on stdout; the host's own
 *     output goes to stderr, so a noisy boot is never read as an identity,
 *     and a host reporting no flag exits 1 [measured 2026-09-23: through a
 *     pipe it printed the one line `Sep 23 2026, 11:30:04` for the vendored
 *     host and `Aug 18 2026, 00:21:51` for npm's swipl-wasm 8.0.6;
 *     commit=02dc5471b552c74826880441400114c798ea66ca]
 *   - `files` prints one `size<TAB>path` line per regular file under /swipl,
 *     sorted by path, read from the booted host's own filesystem rather than
 *     from the loader's packing metadata, so it is what the engine would see
 *   - `check` exits 0 exactly when metta_require_patched_host succeeds inside
 *     the booted host, with this checkout's engine/host_check.pl and
 *     engine/host_patches.pl mounted at /metta/engine, the paths the seat
 *     mounts them at; a refusal prints the engine's own message and exits 1
 *     [measured 2026-09-23: exit 0 on the vendored host with 19 of 19 patches
 *     declared, and exit 1 naming all 19 missing on npm's swipl-wasm 8.0.6;
 *     commit=02dc5471b552c74826880441400114c798ea66ca]
 * Fails when: DIR's .data belongs to another link; the boot then fails, or
 *   describes a host nobody ships, which is why build.sh asks the artefacts it
 *   is about to vendor rather than the image they came from.
 */

import { createRequire } from "node:module";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");

// The answer is an exit CODE the event loop drains to, never process.exit():
// stdout to a pipe is asynchronous here, and exiting after a write kept the
// first 8 KB of `files` and dropped the rest [measured 2026-09-23: 199 of 331
// lines through `| cut`, all 331 into a file].
process.exitCode = await main(process.argv.slice(2));

async function main([verb, where]) {
  if (!["compiled-at", "check", "files"].includes(verb ?? "") || where === undefined) {
    console.error("usage: node tools/wasm-host/host.mjs compiled-at|check|files DIR");
    return 2;
  }
  const directory = resolve(where);
  const glue = ["swipl-web.cjs", "swipl-web.js"]
    .map((name) => join(directory, name))
    .find((path) => existsSync(path));
  if (glue === undefined) {
    console.error(`host: ${directory} holds no swipl-web.cjs or swipl-web.js`);
    return 1;
  }

  const SWIPL = createRequire(import.meta.url)(glue);
  const swipl = await SWIPL({
    arguments: ["-q", "--"],
    locateFile: (name) => join(directory, name),
    print: (line) => console.error(line),
    printErr: (line) => console.error(line),
  });
  const once = (goal) => swipl.prolog.query(goal).once();

  const at = once("current_prolog_flag(compiled_at, At).")?.At;
  if (typeof at !== "string" || at.length === 0) {
    console.error(`host: the host in ${directory} reported no compiled_at`);
    return 1;
  }
  if (verb === "compiled-at") {
    process.stdout.write(`${at}\n`);
    return 0;
  }
  if (verb === "files") {
    const lines = [];
    const walk = (path) => {
      for (const name of swipl.FS.readdir(path)) {
        if (name === "." || name === "..") continue;
        const child = `${path}/${name}`;
        const stat = swipl.FS.stat(child);
        if (swipl.FS.isDir(stat.mode)) walk(child);
        else lines.push([child, `${String(stat.size)}\t${child}`]);
      }
    };
    walk("/swipl");
    lines.sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0));
    process.stdout.write(lines.map(([, line]) => `${line}\n`).join(""));
    return 0;
  }

  swipl.FS.mkdirTree("/metta/engine");
  for (const name of ["host_check.pl", "host_patches.pl"]) {
    swipl.FS.writeFile(`/metta/engine/${name}`, readFileSync(join(ROOT, "engine", name)));
  }
  const loaded = once("consult('/metta/engine/host_check.pl').");
  if (loaded?.success !== true) {
    console.error(`host: engine/host_check.pl did not load in ${directory}: ${JSON.stringify(loaded)}`);
    return 1;
  }
  const checked = once(
    "catch((metta_host_check:metta_require_patched_host, Verdict = passed), " +
    "Error, (print_message(error, Error), Verdict = refused)), " +
    "aggregate_all(count, metta_host_patches:host_patch(_, _), Required).",
  );
  if (checked?.Verdict !== "passed") {
    console.error(`host: the engine's host check refuses ${directory}`);
    return 1;
  }
  console.log(`host: the engine's host check passes on ${directory}, compiled at ${at}, ` +
    `every one of the ${String(checked.Required)} required patches declared`);
  return 0;
}
