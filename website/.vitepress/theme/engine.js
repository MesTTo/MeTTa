/*
 * Purpose: the page's one engine, behind three functions: run a fence, drop the
 *   engine, and say what the boot cost.
 * Assumes: `scripts/bundle-browser.mjs` has put the worker and the browser kit
 *   under `<base>metta/`, which is where this looks for them.
 * Guarantees:
 *   - one worker for the whole page however many fences it holds, so the second
 *     fence a reader runs pays nothing for the engine
 *     [tested: npm run test:browser --prefix extensions/node,
 *     "answers the site's fences through one worker"; commit=a8b50dae12518adb626bf2594258eeaaf4a7f76d]
 *   - a fence that paid for the engine says `booting` and then `running`: the
 *     worker sends one progress message when the engine is up and before the
 *     program starts, because a boot and a run are one message and a page
 *     cannot see the moment between them otherwise
 *     [tested: npm run test:browser --prefix extensions/node,
 *     "clears a fence reset while its run was still going", which waits for
 *     that state; commit=a8b50dae12518adb626bf2594258eeaaf4a7f76d]
 *   - runs are served in the order they were asked for, because the engine is
 *     synchronous inside the worker and answering out of order would only mean
 *     a later fence had overtaken an earlier one
 *     [tested: npm run test:browser --prefix extensions/node,
 *     "answers the site's fences through one worker", whose last two messages
 *     are asked for at once; commit=a8b50dae12518adb626bf2594258eeaaf4a7f76d]
 *   - a worker that dies takes every waiting run with it, named, rather than
 *     leaving a fence saying `running` forever
 *     [tested: npm run test:browser --prefix extensions/node,
 *     "names a worker it cannot start rather than waiting on it";
 *     commit=a8b50dae12518adb626bf2594258eeaaf4a7f76d]
 * Owns resources: the Worker, until `reset()` or the page unloads.
 * Decides: the worker's URL is read from Vite's own `BASE_URL`, the same value
 *   VitePress publishes the site under, so the one place the base is written is
 *   the site's configuration.
 */

/** The page's worker, or undefined before the first run and after a reset. */
let worker;
/** Runs waiting for an answer, by the id they were asked under: what settles
 *  the promise, and what the fence wants told about its state. */
const waiting = new Map();
/** What the boot cost, once one has happened. */
let bootMs;
let nextId = 0;

/** Where the bundled worker is served, under whatever base the site has. */
function workerURL() {
  return new URL(`${import.meta.env.BASE_URL}metta/worker.js`, window.location.href);
}

/** Fail every waiting run, and forget the worker they were waiting on. */
function collapse(said) {
  const held = [...waiting.values()];
  waiting.clear();
  worker = undefined;
  for (const { settle } of held) {
    settle({ error: { code: "ERR_METTA_TRANSPORT", message: said }, stderr: [], ms: 0 });
  }
}

function engine() {
  if (worker !== undefined) return worker;
  const started = new Worker(workerURL(), { type: "module" });
  started.onmessage = (event) => {
    const held = waiting.get(event.data.id);
    if (typeof event.data.bootMs === "number" && event.data.bootMs > 0) bootMs = event.data.bootMs;
    // The engine is up and the program has not started: a progress message, not
    // an answer, so the run stays pending and only its state moves.
    if (event.data.ready === true) {
      held?.watch?.("running");
      return;
    }
    waiting.delete(event.data.id);
    held?.settle(event.data);
  };
  started.onerror = (event) => {
    started.terminate();
    collapse(
      `${event.message || "the engine worker stopped"} (${workerURL().href}). ` +
        "Reload the page, or check that the site was built with the browser kit beside it.",
    );
  };
  worker = started;
  return started;
}

/**
 * Run one fence's source, bounded by its own inference budget.
 *
 * `watch` is called with `booting` when this run is the one paying for the
 * engine and with `running` when the engine is up, so a fence can say which of
 * the two it is waiting for. Answers `{ groups, stderr, ms }` or
 * `{ error: { code, message }, stderr, ms }`; it never rejects, because a
 * refusal is what a reader came to see.
 */
export function run(source, inferences, watch) {
  const id = (nextId += 1);
  const booted = bootMs !== undefined && worker !== undefined;
  watch?.(booted ? "running" : "booting");
  return new Promise((settle) => {
    waiting.set(id, { settle, watch });
    engine().postMessage({ id, source, inferences });
  });
}

/** Drop the engine. The next run boots a new one. */
export function reset() {
  worker?.terminate();
  collapse("the engine was reset before this run answered");
  bootMs = undefined;
}

/** What the one boot cost in milliseconds, or undefined before it happened. */
export function bootCost() {
  return bootMs;
}
