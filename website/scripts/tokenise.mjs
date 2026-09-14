/**
 * Purpose: tokenise files with the site's own TextMate grammar and print the
 *   scoped spans, so a second highlighter can be held to what the site shows.
 *
 * This is the oracle half of the `tokenisation` gate lane. The Python half,
 * tests/checks/check_tokenisation_parity.py, runs the generated Pygments lexer
 * over the same files and compares character by character; the grammar is the
 * one source and this is the reading of it that decides.
 *
 * It goes through shiki, which is what VitePress highlights with here, rather
 * than through a TextMate engine of its own: `shiki/core` gives the same
 * `Grammar` object the site's fences are coloured by, `shiki/textmate` is
 * shiki's re-export of Microsoft's vscode-textmate, and `shiki/engine/oniguruma`
 * runs the real Oniguruma through WebAssembly. Comparing against a
 * reimplementation would only say that two guesses agree.
 *
 * Usage, from anywhere:
 *
 *   printf '%s\n' a.metta b.metta |
 *     node website/scripts/tokenise.mjs website/.vitepress/metta.tmLanguage.json
 *
 * One JSON object per input line on stdout:
 *
 *   {"path": "a.metta", "spans": [[0, 11, "comment.line.semicolon.metta"]]}
 *
 * Guarantees: spans use Unicode code point offsets, including after astral
 * characters and across lines [tested: tests/checks/check_tokenisation_selftest.py;
 * commit=WORKTREE].
 *
 * A span is [start, end, scope) in Unicode code points of the file, holding the
 * innermost scope of a token TextMate gave more than the grammar's own
 * `source.metta`. Characters no pattern scoped are absent rather than listed,
 * because that is the one thing the two tokenisers are allowed to chunk
 * differently.
 *
 * Two details of vscode-textmate the offsets depend on. It is fed ONE LINE at a
 * time and threaded with the rule stack the previous line ended on, which is
 * how a string that spans lines stays a string; and it appends a newline to
 * each line internally, so a token's endIndex can be one past the line's own
 * length. Both are handled below: the ends are clamped to the line, and the
 * line terminators themselves are never part of a span, since the tokeniser
 * never sees them.
 */

import { readFileSync } from "node:fs";
import { createHighlighterCore } from "shiki/core";
import { createOnigurumaEngine } from "shiki/engine/oniguruma";
import { INITIAL } from "shiki/textmate";

const grammarPath = process.argv[2];
if (!grammarPath) {
  process.stderr.write("usage: node tokenise.mjs <grammar.json> < <file list>\n");
  process.exit(2);
}

const grammarJson = JSON.parse(readFileSync(grammarPath, "utf8"));
const shiki = await createHighlighterCore({
  langs: [{ ...grammarJson, name: "metta", scopeName: grammarJson.scopeName }],
  themes: [],
  engine: await createOnigurumaEngine(import("shiki/wasm")),
});
const grammar = shiki.getLanguage("metta");

/** The scoped spans of one source text, in file offsets. */
function spans(source) {
  const out = [];
  let stack = INITIAL;
  let offset = 0;
  for (const line of source.split("\n")) {
    // TextMate reports UTF-16 offsets; Python compares Unicode code points.
    const characterOffsets = [0];
    let units = 0;
    let characters = 0;
    for (const character of line) {
      units += character.length;
      characterOffsets[units] = ++characters;
    }
    const result = grammar.tokenizeLine(line, stack);
    stack = result.ruleStack;
    for (const token of result.tokens) {
      const start = Math.min(token.startIndex, line.length);
      const end = Math.min(token.endIndex, line.length);
      if (start < end && token.scopes.length > 1) {
        const first = characterOffsets[start];
        const last = characterOffsets[end];
        if (first === undefined || last === undefined) {
          throw new Error("TextMate split a Unicode code point");
        }
        out.push([offset + first, offset + last, token.scopes[token.scopes.length - 1]]);
      }
    }
    offset += characters + 1;
  }
  return out;
}

const paths = readFileSync(0, "utf8").split("\n").filter((line) => line.length > 0);
const lines = paths.map((path) =>
  JSON.stringify({ path, spans: spans(readFileSync(path, "utf8")) }),
);
process.stdout.write(lines.length ? `${lines.join("\n")}\n` : "");
