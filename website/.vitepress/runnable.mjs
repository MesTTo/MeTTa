/*
Purpose: the `::: run` container, and the one place that knows where the
  runnable-example machinery's directories are.
Assumes:
  - `extensions/node`'s browser kit has been built, which scripts/bundle-browser.mjs
    is what checks and what copies it under `public/metta/`
  - the corpus runner lists an example when it is a `.metta` file under
    `examples/` outside a `_fixtures/` directory and
    tests/data/example_skips.txt does not name it
    [source: test.sh, the find and the SKIPS read; commit=a8b50dae12518adb626bf2594258eeaaf4a7f76d]
Guarantees:
  - a `::: run` fence names an example the corpus runner runs and carries that
    file's own bytes, or the site build refuses by name, so the page cannot
    run a program the gate does not
    [tested: test_every_run_fence_runs_the_corpus_file_it_names; commit=a8b50dae12518adb626bf2594258eeaaf4a7f76d]
  - the fence's text reaches the component unchanged: it travels
    percent-encoded, which is what survives an HTML attribute and the Vue
    template compiler without a quoting rule of its own, and is the transport
    mermaid's own VitePress integration uses for the same reason
    [source: https://github.com/mermaid-js/mermaid/blob/1fad9e6eefd1e9ab6fe6aa708c8e2fa4df7cb3ce/packages/mermaid/src/docs/.vitepress/mermaid-markdown-all.ts,
    `graph="${encodeURIComponent(token.content)}"`; commit=a8b50dae12518adb626bf2594258eeaaf4a7f76d]
Decides: ROOTS below is the whole of what changes when `examples/` and this
  site move into the textbook repository. Nothing else in the site knows where
  the corpus or the browser kit is.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
*/

import container from "markdown-it-container";
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

/**
 * Every directory this machinery reads or writes, relative to this file.
 *
 * The site lives at `<repository>/website/`, the corpus at
 * `<repository>/examples/`, and the seat whose browser build the site ships at
 * `<repository>/extensions/node/`. After the split the site and the corpus are
 * siblings in one repository and the seat is a dependency, which changes these
 * five lines and nothing else.
 */
const REPOSITORY = new URL("../../", import.meta.url);
export const ROOTS = Object.freeze({
  /** Where the examples a fence may name live. */
  examples: fileURLToPath(new URL("examples/", REPOSITORY)),
  /** The list of examples the shell runner does NOT run. */
  skips: fileURLToPath(new URL("tests/data/example_skips.txt", REPOSITORY)),
  /** The seat whose `browser/` and `_runtime/` the site serves. */
  seat: fileURLToPath(new URL("extensions/node/", REPOSITORY)),
  /** Where the site serves them from, under the site's own base. */
  assets: fileURLToPath(new URL("website/public/metta/", REPOSITORY)),
  /** The corpus path prefix a fence writes, which is what the docs lane reads. */
  prefix: "examples/",
});

/** Every `.metta` under a directory, less the `_fixtures/` trees. */
function walk(directory, into) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      if (entry.name !== "_fixtures") walk(path, into);
    } else if (entry.name.endsWith(".metta")) {
      into.push(path);
    }
  }
  return into;
}

/**
 * Every example the shell runner runs, as repository-relative paths.
 *
 * The same two rules `test.sh` applies -- every `.metta` under `examples/`
 * outside a `_fixtures/` directory, less what
 * `tests/data/example_skips.txt` names -- so a fence over an example that
 * needs a terminal, or torch, or the network is refused here rather than
 * hanging in a reader's browser. Walked rather than shelled out to `find`,
 * because a site build runs on whatever machine publishes.
 */
export function corpusExamples() {
  const skipped = new Set(readFileSync(ROOTS.skips, "utf8").split("\n")
    .filter((line) => line.trim() !== "" && !line.startsWith("#"))
    .map((line) => line.split(/\s+/)[0]));
  const root = fileURLToPath(REPOSITORY);
  return walk(ROOTS.examples, [])
    // Forward slashes whatever the platform joined with: a fence writes the
    // path the repository writes, and the skip file spells it the same way.
    .map((path) => path.slice(root.length).replaceAll("\\", "/"))
    .filter((path) => !skipped.has(path))
    .sort();
}

/** The default inference budget a fence runs under, and the only place it is
 *  written: the component takes it as a required prop rather than defaulting. */
const DEFAULT_INFERENCES = 1_000_000;

/** `run <path>` with an optional `inferences=<n>`, and nothing else. */
const PARAMS = /^run\s+(\S+)(?:\s+inferences=(\d+))?\s*$/;

/**
 * What a refusal from here says, so every one of them reads the same way.
 *
 * VitePress prints a render error without the page it came from, and a site has
 * many pages; `env.relativePath` is the page markdown-it is rendering.
 */
function refuse(env, said) {
  const page = typeof env?.relativePath === "string" ? env.relativePath : "a page";
  return new Error(`::: run in ${page}: ${said}`);
}

/**
 * The tokens a `::: run` block encloses, which must be one `metta` fence.
 *
 * Reading the slice rather than searching it for a fence is what makes "one
 * fence and nothing else" a single check: a second fence, a paragraph, or a
 * nested container all arrive here as an extra token.
 */
function fenceInside(tokens, open, env) {
  const close = tokens.findIndex((token, at) => at > open && token.type === "container_run_close");
  if (close < 0) throw refuse(env, "the block is not closed");
  const inside = tokens.slice(open + 1, close);
  if (inside.length !== 1 || inside[0].type !== "fence") {
    throw refuse(env, `the block must hold exactly one fenced block, and holds ${String(inside.length)} thing(s)`);
  }
  if (inside[0].info.trim() !== "metta") {
    throw refuse(env, `the fenced block must be tagged \`metta\`, and is tagged \`${inside[0].info.trim()}\``);
  }
  return inside[0];
}

/**
 * Register `::: run <example> [inferences=<n>]` on a markdown-it instance.
 *
 * The block renders its fence exactly as any other `metta` fence renders, with
 * `MettaRun` around it: the component adds the button, the state and the answer
 * groups, and the highlighted source under it is the theme's own.
 *
 * The checks run HERE, at render, so `npm run docs:build` is what refuses a
 * fence that has drifted from the file it names. The same two facts are checked
 * again from Python in the pytest lane, which needs neither node nor the site's
 * dependencies.
 */
export function runContainer(md) {
  const corpus = new Set(corpusExamples());
  md.use(container, "run", {
    validate: (params) => /^run(\s|$)/.test(params.trim()),
    render(tokens, index, options, env) {
      if (tokens[index].nesting !== 1) return "</MettaRun>\n";
      const params = PARAMS.exec(tokens[index].info.trim());
      if (params === null) {
        throw refuse(env, `the block takes an example path and an optional inferences=<n>, not \`${tokens[index].info.trim()}\``);
      }
      const [, example, inferences] = params;
      if (!corpus.has(example)) {
        throw refuse(env,
          `${example} is not an example the corpus runner runs; it must be a path under ` +
          `${ROOTS.prefix} that \`sh tools/test.sh\` lists and tests/data/example_skips.txt does not skip`,
        );
      }
      const fence = fenceInside(tokens, index, env);
      let text = readFileSync(join(ROOTS.examples, example.slice(ROOTS.prefix.length)), "utf8");
      // A fenced block always ends in a newline, so a file that does not is
      // unrepresentable in one; the file's own bytes plus that newline is what
      // the fence can carry and what this compares against.
      if (!text.endsWith("\n")) text += "\n";
      if (fence.content !== text) {
        throw refuse(env,
          `the fence under ${example} is not that file's text. The page runs the bytes the gate ` +
          `runs, so paste the file back into the fence (its first difference is at character ` +
          `${String(firstDifference(fence.content, text))}).`,
        );
      }
      return `<MettaRun example="${example}" inferences="${inferences ?? String(DEFAULT_INFERENCES)}" ` +
        `source="${encodeURIComponent(text)}">\n`;
    },
  });
}

/** Where two texts first differ, counting from one, for a refusal to name. */
function firstDifference(left, right) {
  const shortest = Math.min(left.length, right.length);
  for (let at = 0; at < shortest; at += 1) if (left[at] !== right[at]) return at + 1;
  return shortest + 1;
}
