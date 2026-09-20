# The textbook runs in the browser

Goal: a reader presses Run on any example in the documentation site and it runs,
in the page, from the site's own static assets, with no server beyond the static
host the site already needs.
Constraint: the page runs the bytes the gate runs. An example is a corpus file
`sh tools/test.sh` runs, and a fence that has drifted from its file is a lie the site
build has to refuse.

## 2026-09-07

Decided: one engine per PAGE, in a Web Worker, booted on the first press.
`m.run` is synchronous once the engine is up, so a reduction holds whatever
thread it is on until it finishes or its budget stops it; on the page's thread
that is a frozen page for the length of the program.

Rejected: a boot per fence. Measured 1,176 ms mean for a boot on a prepared
root across 258 of them at loadavg 54, and the first boot on a page also
fetches 7.8 MB.
`prepareRuntime` already memoises a root per realm, so twelve boots in one page
are one fetch, but they are still twelve wasm instances and twelve engine
starts. Revisit if a fence ever needs an engine another fence has poisoned;
today the space per run below is what that would buy.

Rejected: an inline worker built from a Blob. It would remove one static file
and cost the `import` of `./browser/index.js` its base-relative resolution,
which is the whole reason the worker needs no configuration.

Decided: each run gets a space of its own, released after it. Sharing `&self`
across a page makes a fence read what an earlier fence defined, and makes
pressing Run twice on one fence double its equations. Measured through the
worker: six messages on one worker, where the third defines `(= (only-here) 1)`
and the fourth asks `!(only-here)` and is answered `(only-here)` unreduced,
which is what isolation looks like.

Tried: running every corpus example in the browser engine, one shared engine and
a space per example -> the first WebAssembly abort killed the module and the 40
examples after it answered `Unknown procedure: system:metta_node_do/2`. So the
worker drops an engine that has aborted: after a failed run it asks the engine
`!(+ 1 1)`, and an engine that cannot answer that is forgotten.

Measured: the census again with a FRESH engine per example, 258 runnable corpus
files (263 listed, 5 skipped by `tests/data/example_skips.txt`), one Chromium
page per 20:

```
225  ran                       median run 7.0 ms, mean boot 934 ms
  9  ERR_METTA_INFERENCES      past a 20,000,000 bound: ch06 permutations,
                               ch18 scale/holbenchmark/matespacefast, ch22 search
  7  ERR_METTA_SOURCE          an import! of a file beside the example; only the
                               fence's own bytes cross
  7  ERR_METTA_ENGINE          six of them ch11, where a py- call answered itself
                               and then failed the file's own (test ...)
  6  ERR_METTA_CAPABILITY      library(thread) and library(time), named by the
                               engine's own census with what the absence costs
  3  RuntimeError: Aborted()   the wasm heap
  1  ExitStatus                ch20 standard-streams
```

That run was a throwaway probe; it is committed as
`extensions/node/tools/measure-browser-corpus.mjs` so the number can be
reprinted, since the site, `llms.txt` and the changelog all state it. So 87% of
the corpus runs in a page, and every refusal but one is already the engine's
own, by name.

The one that is not: a call to a door the standard library DECLARES and this
build does not implement answers itself. `!(py-atom "1 + 1")` answers
`(py-atom "1 + 1")`, which reads as an answer rather than as a refusal, and six
ch11 examples reach a reader as `MeTTa test failed` with nothing saying that
there is no Python here.

Tried: finding an exact test for that, in the engine, four ways.

- The engine's platform census (`metta_platform/4`, read through the Node
  bridge's `platform` command as `m.refusals`) covers PLATFORM libraries and
  answers concurrency, deadlines, subprocess, crypto and redis for this build.
  It says nothing about a seat, because a seat is not a library.
- `metta_extension_loaded/1` and `require-extension!` cover SEATS and refuse by
  name -- `!(import! &self (library lib_mm2))` answers `extension mork is
  required and not loaded: artefact ... is absent` in the browser -- but only
  when a program asks. Nothing maps a HEAD to the seat that provides it.
- The head set the engine knows (`fun/1`) is too coarse: `(add-atom &self
  (parent tom bob))` has an unknown head and is data.
- `reducible` alone is too coarse for the same reason.

Decided: a head is unimplemented HERE when the engine declares an arrow type for
it, cannot reduce it, and the arrow's result is `%Undefined%`. The last clause is
what separates a door from a constructor: a constructor names the type it
builds, and `%Undefined%` is the engine's own word for a result it cannot
describe.

Measured over the whole corpus, 1,435 distinct (head, arity) shapes: 204
declared-and-reducible; 19 declared and not reducible, of which 6 are `->` in a
type position and 1 is `Error`, declared `(-> Atom Atom ErrorType)`. The
remaining 12 shapes are 8 names: `py-atom`, `py-call`, `py-dot`, `py-list`,
`py-tuple`, `py-dict`, `py-iter` and `Kwargs`. The `->` cases are also excluded
by position, since a type in a `(: name Type)` declaration is not a call, so the
two exclusions are independent. That classification is now the linter's own
test, "flags exactly the doors the corpus needs a host for", which asserts the
eight names over the whole corpus, so a door this build gains or loses moves a
red line rather than nothing.

It landed as the linter's sixth rule, `unimplemented-head`, rather than as a
door of its own: `lint` is already "diagnostics over declarations, equations and
calls, without running any of them", it already takes the surface, and the
suppression comment, the rule list, the CLI and the reference come with it. The
worker raises the seat's `UnsupportedError` from its findings.

Decided: the fence's text travels to the component percent-encoded.
`encodeURIComponent` leaves nothing that an HTML attribute or the Vue template
compiler has a rule about, and it is what mermaid's own VitePress integration
does with a diagram's source for the same reason
[source: https://github.com/mermaid-js/mermaid/blob/develop/packages/mermaid/src/docs/.vitepress/mermaid-markdown-all.ts].

Decided: copy only what a browser FETCHES into `public/metta/`. `_runtime/` is
12 MB on disk and holds the `engine/` and `lib/` trees as files, which is how
the NODE platform mounts them; `platform-browser.ts` reads their text out of
`runtime.json` and asks for three files in all. Copying the trees too would put
5 MB no reader downloads into the site and again into its built output. What is
copied is 7.8 MB, and a page fetches exactly four things: `worker.js`,
`runtime.json`, `swipl-web.wasm`, `swipl-web.data`.

Measured on the BUILT site, served under its own `/MeTTa-Kernel/` base to
headless Chromium, box at loadavg 77: first press 6,087 ms wall, of which a
4,675 ms boot and a 93 ms run; the second fence on the same page 195 ms wall and
a 28 ms run. On a quieter box the same boot through a bare page measured 1,511 ms
(both throwaway probes over a static server). Read the wall numbers with the
load beside them; the run numbers are what the engine did.
`npm run test:browser` now prints the boot, the identity run and the second
fence's run beside the loadavg, from the case that drives the worker, so the
claim has a command behind it.

Decided: the docs lane BUILDS the browser kit when the tree can, rather than
skipping over a tree that has not. `bundle-browser.mjs` refuses the site build
without it, which is the right answer to a site published with dead Run buttons
and the wrong answer to a developer who has not run one command; the build is
3.2 s of esbuild and a copy. Same shape as `check_node_dist`, which builds
`dist/` inside the `npm pack` its consumer program runs.

Decided: `npm ci --prefix website` moves BEFORE `npm run test:browser` in the CI
gate. The browser suite compiles `MettaRun.vue` with the site's own vite and
`@vitejs/plugin-vue`, and after it those two are not installed yet, so the two
component cases would have skipped by name on every CI run.

Found by its own test: "a running fence shows its state" was half true. The
client told a fence `booting` when it was the one paying for the engine and
never told it anything after, because a boot and a run are ONE message to the
worker and `run` does not return until the program is done. The case that
resets a fence mid-run waited for `running` and timed out. The worker now sends
one `{ id, ready: true, bootMs }` progress message when the engine is up and
before the program starts, which is the only moment a page can see between the
two, and the client moves the fence's state on it without settling the run.

Found, and left open: the evidence gate does not read a QUOTED test name. A
name written as a sentence, which is how a `node --test` or a `describe`/`it`
case names itself, fails `IDENTIFIER` in `resolve/3` and returns no targets, so
a correct citation and a renamed one are accepted for the same reason -- that
nothing reads either. Six citations written in this change named cases that had
been renamed and passed; they are corrected by hand here. Moving the quoted
lookup ahead of the identifier check reports 45 citations across
`extensions/node/src`, `extensions/node/test`, `extensions/cmetta/cmetta.c` and
the TypeScript-space example, most of them REAL names the harvester never sees:
`_node_targets/1` globs `extensions/node/test/*.test.ts` alone, so
`tools/browser.test.mjs` and the example servers' own suites are invisible to
it. Repairing that means widening the harvester AND auditing 45 citations
across four seats, which is its own change. The citations added here name
`npm run test:browser --prefix extensions/node`, the command shape the gate
does check, with the case quoted after it as the pointer.

Open: an example that imports a file beside it cannot run from a fence, because
only the fence's own bytes cross. Seven corpus files are in that shape. Sending
the example's directory as a mount would fix it and would also stop the fence
being the whole program, which is the property the docs lane exists to keep.
