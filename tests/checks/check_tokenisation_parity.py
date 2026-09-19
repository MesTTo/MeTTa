r"""Purpose: hold the generated Pygments lexer to the TextMate grammar the site
highlights with, character by character, over every `.metta` file the
repository tracks and a file of shapes chosen for being able to diverge.

One grammar is the point of generating the lexer at all, and a generator that
is merely RUN proves only that it ran. The two engines behind the one grammar
are different programs: vscode-textmate compiles Oniguruma to WebAssembly and
is fed one line at a time, and Pygments compiles Python's `re` and is given the
whole file. The places they can part company are the reason this lane exists.

  - `\s` is Unicode's White_Space property to Oniguruma and White_Space plus
    the four ASCII separators U+001C-U+001F to Python, because `str.isspace()`
    counts those four and Unicode does not. Measured here on the first run,
    which reported the one divergence a wrong `re.ASCII` guess produced; the
    generator spells the set out rather than writing `\s`, and the probes
    hold all four separators so removing that is a red lane.
  - A line-at-a-time tokeniser sees the end of the string where a whole-file
    one sees `\n`, which the two lookarounds this grammar uses read through.
  - A TextMate list is scanned for the earliest match ahead; a Pygments state
    is tried anchored at the cursor. They agree wherever anything matches at
    the cursor and differ in how they chunk what nothing matches.

What is compared is therefore the TOKEN of every character, with the grammar's
scopes carried into Pygments' vocabulary by the generated SCOPE_TOKENS, and
with the characters no pattern scoped compared as the absence of a token. Line
terminators are outside the comparison: vscode-textmate is never shown one, so
it has nothing to say about them.

Assumes:
  - node on PATH and shiki installed under website/node_modules, which is
    where `npm ci --prefix website` puts it and what the `docs` lane already
    requires; absent, this refuses under CI and prints a skip elsewhere
Guarantees:
  - a grammar change the generated lexer does not carry is reported with the
    file, the offset, the line and column, and both verdicts [tested:
    tests/checks/check_tokenisation_selftest.py; commit=7ba114f280ec3b132658cacb562064d0bac23f41]
  - a scope the grammar emits that SCOPE_TOKENS does not name fails the run,
    so a new group cannot reach a reader as plain text [tested:
    tests/checks/check_tokenisation_selftest.py; commit=7ba114f280ec3b132658cacb562064d0bac23f41]
Fails when: asked to judge a tree whose website dependencies are not
  installed. It says so and passes, because a developer who has not run one
  npm command has not broken anything; under CI it refuses instead.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""  # noqa: D205  -- the contract is one continuous invariant, not summary-and-body prose

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(ROOT / "extensions" / "python"))

from bounded_spawn import bounded  # noqa: E402  -- the paths are installed above

from metta._pygments import SCOPE_TOKENS, MettaLexer  # noqa: E402  -- the same

GRAMMAR = ROOT / "website" / ".vitepress" / "metta.tmLanguage.json"
ORACLE = ROOT / "website" / "scripts" / "tokenise.mjs"
NODE_MODULES = ROOT / "website" / "node_modules" / "shiki"
PROBES = ROOT / "tests" / "data" / "tokenisation_probes.txt"

#: The one probe re-run with CRLF endings. A `\r` is inside the line as far as
#: vscode-textmate is concerned and outside it as far as Python's `$` is, which
#: is exactly the kind of difference this lane is for.
CRLF_PROBE = "the operators next to each other and inside words"

#: How many characters of context a mismatch prints on each side.
CONTEXT = 30


def probes(text: str) -> list[tuple[str, str]]:
    """The named probes of tokenisation_probes.txt, in the order it lists them."""
    out: list[tuple[str, str]] = []
    name: str | None = None
    body: list[str] = []
    for line in text.splitlines(keepends=True):
        if line.startswith(">>>> "):
            if name is not None:
                out.append((name, "".join(body)))
            name, body = line[5:].strip(), []
            continue
        if name is not None:
            body.append(line)
    if name is not None:
        out.append((name, "".join(body)))
    return out


def corpus() -> list[tuple[str, str]]:
    """Every tracked `.metta` file, as (label, source)."""
    listed = subprocess.run(
        ["git", "ls-files", "--recurse-submodules", "-z", "--", "*.metta"],
        cwd=ROOT, capture_output=True, text=True, check=True,
    )
    return [
        (name, (ROOT / name).read_text(encoding="utf-8"))
        for name in listed.stdout.split("\0")
        if name
    ]


def inputs() -> list[tuple[str, str]]:
    """The corpus, the probes, and the one probe again with CRLF endings."""
    named = probes(PROBES.read_text(encoding="utf-8"))
    crlf = [
        (f"{name} (CRLF)", body.replace("\n", "\r\n"))
        for name, body in named
        if name == CRLF_PROBE
    ]
    if not crlf:
        msg = f"{PROBES.name} no longer holds a probe named {CRLF_PROBE!r}"
        raise SystemExit(msg)
    return [*corpus(), *((f"probe: {name}", body) for name, body in named), *crlf]


def grammar_spans(sources: list[tuple[str, str]], grammar: Path) -> list[list[list]]:
    """The scoped spans of each source, as the site's own tokeniser sees them."""
    with tempfile.TemporaryDirectory(prefix="tokenisation-", dir=ROOT / "ai-tmp") as name:
        scratch = Path(name)
        paths = []
        for index, (_label, body) in enumerate(sources):
            path = scratch / f"{index}.metta"
            path.write_text(body, encoding="utf-8")
            paths.append(path)
        done = subprocess.run(
            bounded(["node", str(ORACLE), str(grammar)]),
            input="\n".join(str(path) for path in paths),
            cwd=ROOT, capture_output=True, text=True, check=False,
        )
    if done.returncode != 0:
        msg = f"the TextMate oracle exited {done.returncode}:\n{done.stderr}"
        raise SystemExit(msg)
    read = {json.loads(line)["path"]: json.loads(line)["spans"] for line in done.stdout.splitlines()}
    return [read[str(path)] for path in paths]


def grammar_tokens(source: str, spans: list[list], unknown: set[str]) -> list[object]:
    """One entry per character: the Pygments token the grammar's scope means."""
    out: list[object] = [None] * len(source)
    for start, end, scope in spans:
        token = SCOPE_TOKENS.get(scope)
        if token is None:
            unknown.add(scope)
            continue
        for at in range(start, min(end, len(source))):
            out[at] = token
    return out


def lexer_tokens(source: str, lexer: object) -> list[object]:
    """One entry per character: the token the lexer gives it, unscoped as None."""
    out: list[object] = [None] * len(source)
    scoped = set(SCOPE_TOKENS.values())
    for at, token, value in lexer.get_tokens_unprocessed(source):
        if token not in scoped:
            continue
        for offset in range(len(value)):
            out[at + offset] = token
    return out


def _place(source: str, at: int) -> str:
    """`line:column`, counting from one, of a file offset."""
    line = source.count("\n", 0, at) + 1
    return f"{line}:{at - (source.rfind(chr(10), 0, at) + 1) + 1}"


def mismatches(
    sources: list[tuple[str, str]],
    grammar: Path = GRAMMAR,
    lexer_class: type = MettaLexer,
) -> list[str]:
    """Every character the grammar and the lexer disagree about, first per file.

    `grammar` and `lexer_class` are arguments so the selftest beside this can
    plant a change on either side and require the disagreement to be found; the
    lane itself always passes the repository's own two.
    """
    lexer = lexer_class()
    unknown: set[str] = set()
    found = []
    for (label, source), spans in zip(sources, grammar_spans(sources, grammar), strict=True):
        theirs = grammar_tokens(source, spans, unknown)
        ours = lexer_tokens(source, lexer)
        terminators = {at for at, char in enumerate(source) if char in "\r\n"}
        for at, (mine, yours) in enumerate(zip(ours, theirs, strict=True)):
            if mine == yours or at in terminators:
                continue
            excerpt = source[max(0, at - CONTEXT) : at + CONTEXT].replace("\n", "\\n")
            found.append(
                f"{label}:{_place(source, at)}: the grammar says {yours} and "
                f"the lexer says {mine} for {source[at]!r}, in ...{excerpt}..."
            )
            break
    found.extend(
        f"the grammar scopes something {scope!r}, which "
        f"extensions/python/metta/_pygments.py names no token for"
        for scope in sorted(unknown)
    )
    return found


def prerequisite() -> int | None:
    """None when the oracle can run, or the exit status when it cannot."""
    missing = None
    if subprocess.run(["sh", "-c", "command -v node"], capture_output=True, check=False).returncode:
        missing = "node is not on PATH"
    elif not NODE_MODULES.is_dir():
        missing = "shiki is not installed; run `npm ci --prefix website`"
    if missing is None:
        return None
    if os.environ.get("CI") == "true":
        print(
            f"error: {missing}; refusing to pass the tokenisation gate without "
            f"the grammar's own tokeniser to compare against",
            file=sys.stderr,
        )
        return 1
    print(f"note: {missing}; the lexer was not compared against the grammar")
    return 0


def main() -> int:
    """Report every character the two tokenisers disagree about."""
    refusal = prerequisite()
    if refusal is not None:
        return refusal
    sources = inputs()
    found = mismatches(sources)
    for line in found:
        print(line)
    print(
        f"{len(sources)} sources, "
        f"{sum(len(body) for _, body in sources)} characters, "
        f"{len(found)} disagreement(s) with {GRAMMAR.relative_to(ROOT)}"
    )
    return 1 if found else 0


if __name__ == "__main__":
    raise SystemExit(main())
