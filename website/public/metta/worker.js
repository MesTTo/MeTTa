/*
 * Purpose: hold ONE engine for the page and answer a run on it.
 * Assumes: it is served beside the browser kit `scripts/bundle-browser.mjs`
 *   copies, so `./browser/` and `./_runtime/` resolve against this file's own
 *   URL and the site's base needs no configuration here.
 * Guarantees:
 *   - the engine boots once, on the first message, and every later run reuses
 *     it: the boot fetches about 8 MB, and a page that booted per fence would
 *     pay that per fence. One `{ id, ready: true, bootMs }` message goes out
 *     when the engine is up and before the program starts, which is the only
 *     moment a page can see between the two. The suite that drives this worker
 *     PRINTS the three numbers beside the box's load, so the claim can be
 *     reprinted rather than believed
 *     [measured 2026-09-07 over HTTP to headless Chromium, four runs of the
 *     command below on a shared box whose loadavg moved between 54 and 78:
 *     boot 1,631 to 4,832 ms, the identity example 9.1 to 42.4 ms, the next
 *     fence on the same worker 3.5 to 9.8 ms. Read the boot with the load
 *     beside it and the runs as what the engine did; a quiet box booted in
 *     1,511 ms;
 *     command=npm run test:browser --prefix extensions/node, the diagnostic
 *     line of "answers the site's fences through one worker";
 *     fixture=extensions/node/browser and _runtime served from a local server;
 *     commit=WORKTREE]
 *   - a program naming a door this build has no implementation for is REFUSED
 *     before it runs, rather than answering itself unreduced, which is what
 *     `(py-atom "1 + 1")` does in an engine with no Python seat behind it
 *     [tested: npm run test:browser --prefix extensions/node,
 *     "refuses a fence the browser has no seat or no budget for";
 *     commit=WORKTREE]
 *   - a run costs at most the fence's own inference budget, and the engine
 *     stops itself with its own `InferenceLimitError` text when it passes it
 *     [tested: npm run test:browser --prefix extensions/node,
 *     "refuses a fence the browser has no seat or no budget for";
 *     commit=WORKTREE]
 *   - an engine that has aborted is dropped rather than reused: a WebAssembly
 *     abort leaves the module dead, and every later run in a census that
 *     shared one inherited the corpse and reported a transport failure
 *     [measured 2026-09-07: one aborting example turned the 40 after it into
 *     `Unknown procedure: system:metta_node_do/2`;
 *     command=extensions/node/tools/measure-browser-corpus.mjs run with ONE
 *     shared engine rather than the engine per example it uses;
 *     fixture=examples/ over the browser build; commit=WORKTREE]
 *     [assumed: the drop itself has no test. The example that aborted a shared
 *     engine, examples/ch08-data/08-03-the-shipped-libraries/09-conformance.metta,
 *     raises `ERR_METTA_ENGINE` and leaves the engine usable in the
 *     space-per-run this worker gives it, and nothing else aborts a
 *     WebAssembly engine on demand; commit=WORKTREE]
 *   - each run gets a space of its own, released after it, so one fence cannot
 *     change what another answers and running one fence twice answers the same
 *     thing twice rather than doubling its equations
 *     [tested: npm run test:browser --prefix extensions/node,
 *     "answers the site's fences through one worker"; commit=WORKTREE]
 * Owns resources: the engine, until a message drops it or the page discards
 *   this worker.
 * Decides: a WORKER rather than the page, because `run` is synchronous once the
 *   engine is up -- a reduction holds the thread it is on until it finishes or
 *   its budget stops it -- so running it on the page's thread would freeze the
 *   page for the length of the program.
 */

import { metta } from "./browser/index.js";
import { lint } from "./browser/lint.js";
import { UnsupportedError } from "./browser/errors.js";

/** The one engine, and what its boot cost, or null before the first message. */
let engine = null;
let bootMs = 0;
/** How many runs this worker has served, which is what names their spaces. */
let served = 0;

/** Boot on demand, once. */
async function booted() {
  if (engine !== null) return engine;
  const at = performance.now();
  // `import.meta.url` rather than an absolute path: this file is served under
  // the site's base, and reading the base from here would be a second place
  // that has to agree with the site's configuration.
  const started = await metta({ root: new URL("./_runtime/", import.meta.url).href });
  bootMs = performance.now() - at;
  engine = started;
  return engine;
}

/** Forget an engine that cannot answer any more. */
function drop() {
  const held = engine;
  engine = null;
  try {
    held?.dispose();
  } catch {
    // An aborted module cannot be disposed, and it is already unreachable.
  }
}

/** The two fields a refusal crosses as: the code to match, the prose to read. */
function refusalOf(error) {
  return {
    code: typeof error?.code === "string" ? error.code : (error?.name ?? "Error"),
    message: String(error?.message ?? error),
  };
}

/**
 * Run one fence.
 *
 * The order is deliberate: the doors this build has no implementation for are
 * named BEFORE anything runs, because the engine's answer to a call it cannot
 * make is the call itself, which reads as an answer rather than as a refusal.
 */
async function answer({ id, source, inferences }) {
  let m;
  try {
    m = await booted();
  } catch (error) {
    postMessage({ id, error: refusalOf(error), stderr: [], ms: 0, bootMs: 0 });
    return;
  }
  // One progress message before the program starts, so the fence that paid for
  // the engine can stop saying `booting` and start saying `running`. The page
  // cannot see the moment between the two otherwise: a boot and a run are one
  // message, and `run` does not return until the program is done.
  postMessage({ id, ready: true, bootMs });
  // After the boot, not before it: `bootMs` is what the engine cost and `ms` is
  // what the program cost, and adding the first into the second made the fence
  // that paid for the engine report a one-second run of a four-line program.
  const at = performance.now();
  let said;
  served += 1;
  // A space per run, which is what `&self` means for this program. Sharing one
  // would let a fence read what an earlier fence defined and would double a
  // fence's own equations when a reader presses Run twice.
  const where = m.space(`&fence${String(served)}`);
  try {
    const blocked = await lint(m, source, { rules: ["unimplemented-head"], space: where });
    if (blocked.length > 0) {
      throw new UnsupportedError(blocked.map((finding) => finding.message).join("\n"));
    }
    const bound = m.limits({ inferences });
    try {
      said = { groups: m.run(source, where).map((group) => group.texts) };
    } finally {
      bound.release();
    }
  } catch (error) {
    said = { error: refusalOf(error) };
    // A refusal the ENGINE raised leaves it usable; an abort does not, and the
    // difference is only visible by asking it something.
    try {
      m.run("!(+ 1 1)");
    } catch {
      drop();
    }
  }
  if (engine !== null) {
    try {
      where.release();
    } catch {
      // A space the program made a parent of another cannot be released, and
      // holding one more of them costs the page nothing.
    }
  }
  const stderr = engine === null ? [] : m.drainStderr();
  postMessage({ id, ...said, stderr, ms: performance.now() - at, bootMs });
}

onmessage = (event) => {
  void answer(event.data);
};
