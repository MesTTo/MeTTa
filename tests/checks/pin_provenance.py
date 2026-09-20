"""Purpose: resolve every in-progress commit placeholder to a real object ID.

The placeholder in an evidence tag becomes the object ID of the commit whose
tree supplied that evidence, and it is rewritten only where the file's own
grammar says the text is a comment.

A commit cannot contain its own object ID, so the scheme writes the functional
state as commit A, then replaces the placeholder with A's ID in a
provenance-only commit B. Doing that replacement by hand is a plain textual
substitution over the whole tree, and on 2026-08-31 one reached into twelve
STRING LITERALS: the re-pin tool's own tag template began writing a stale
object ID into every twin it priced, and the evidence gate's self-test planted
an object ID where the gate was still testing for the word, so the RELEASE=1
rule went untested and passed. Nothing said so, because a resolvable ID is
exactly what the gate wants to see.

The fix is that this pass exists, and that it decides per file class rather
than per byte:

  .py           a placeholder inside a string literal that is not a docstring
                belongs to code that EMITS or MATCHES pins, and is left alone.
                The distinction is `ast`'s, not a regex's.
  .pl .plt      a placeholder is a pin when a `%` opens a comment before it on
                its line, where most of this tree's Prolog pins sit, or when it
                sits inside a `/* ... */` block, which is Prolog's other
                comment form and how the plunit suites write their contract:
                tests/prolog/suites/spaces/catalog.plt keeps its whole
                Guarantees block in one, and its pin was declined for having no
                `%` until this rule matched the one `//` already had.
  .sh .mk       the same rule with `#`, and a Makefile by NAME, since it
  Makefile      carries the same contract header its neighbours do and has no
                suffix at all to key on.
  .ts .mjs .rs  the same rule with `//`, plus `/* ... */` blocks.
  .c .h .cpp    C and C++ comments are located after consuming literal and
  .cc .cxx      preprocessing tokens. Comment markers inside ordinary, raw
  .hpp .hh .hxx and macro strings remain data; continued comments retain
                their physical source positions.
  .json         commentless, so the measurement prose is the only place a pin
                can be, and every placeholder in one is a pin. This is the rule
                check_evidence_tags.provenance_sites already applies to them.
  .cmake        CMakeLists.txt shares CMake's line and bracket comments;
                quoted, bracket and escaped unquoted arguments remain data.

Anything else is REFUSED by name rather than guessed at, and every occurrence
the pass declines is printed with its reason, so a file class that starts
carrying pins is visible the first time rather than silently skipped.

That refusal only ever spoke for a file the gate's globs REACHED, though, and a
file outside them was not refused, it was invisible: on 2026-08-31 a Makefile, a
.mjs and a .c under a seat's tests/ each carried a real pin and --check still
exited 0, which would have shipped three claims naming the word WORKTREE as
their evidence tree forever. `unscanned` is the net under that. It asks git for
the file list instead of a glob, so the next class is caught the first time it
carries a pin rather than the first time somebody thinks to add its glob.

Assumes: it is run from a checkout of this repository, with git on PATH.
Guarantees:
  - a placeholder in a comment, a docstring or a JSON measurement is rewritten,
    and one in a non-docstring string literal or a backticked mention is not
    [tested: tests/checks/check_pin_provenance_selftest.py]
  - the scan covers exactly the files check_evidence_tags reads, because it
    imports that module's own globs rather than restating them, and a tracked
    file carrying a pin OUTSIDE those globs is reported and fails the run
    rather than being rewritten or ignored
    [tested: tests/checks/check_pin_provenance_selftest.py]
  - --check writes nothing and exits 1 when any pin would be rewritten, which
    is the same condition RELEASE=1 refuses on
    [tested: tests/checks/check_pin_provenance_selftest.py]
  - a commit that does not resolve is refused before any file is opened
    [tested: tests/checks/check_pin_provenance_selftest.py]
  - Rust line and block header pins resolve while bare string literals
    stay unchanged
    [tested: tests/checks/check_pin_provenance_selftest.py; commit=6da518669cb9e39557d537857c0aa7190dd2e78f]
  - TOML substitutions preserve the parsed configuration; keys and values
    cannot be rewritten as header comments
    [tested: tests/checks/check_pin_provenance_selftest.py; commit=f88b11ae305c4e1bfafa8387d1f24e51d0d8cb92]
  - C and C++ pins resolve inside comments while quoted and raw strings,
    macro strings and header names retain their bytes
    [tested: tests/checks/check_pin_provenance_selftest.py; commit=3aaad3435292e4c7d5cc3a01bfda39430aacc6e8]
  - CMake comment pins resolve while all three argument forms retain their
    bytes; unterminated quotes and brackets refuse before writing
    [tested: tests/checks/check_pin_provenance_selftest.py; commit=7b42d5ee5cecb82709617b7ed08dfa2c1441f268]
Fails when: a pin sits somewhere the file's grammar cannot distinguish from
  code. It is reported, not rewritten, and finishing it is a human's call.
Owns resources: none; it rewrites files in place and holds nothing open.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import argparse
import json
import ast
import re
import subprocess
import sys
import tomllib
from bisect import bisect_left
from functools import cache
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from check_evidence_tags import (  # noqa: E402  -- HERE must be on the path first
    CLAIM,
    PLACEHOLDER,
    PROVENANCE_SOURCES,
    ROOT,
    SOURCES,
    owned,
)

TOKEN = re.compile(rf"\bcommit={re.escape(PLACEHOLDER)}\b")
BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.DOTALL)
BLANK_LINE = re.compile(r"\n[ \t]*\n")

#: Which comment rule each file class uses. Keyed on the whole PATH rather than
#: on the suffix alone, because a Makefile carries the same contract header its
#: neighbours do and has no suffix at all to key on.
#:
#: `.js` and `.vue` joined when the site grew a worker and a component: the
#: worker is served as-is and cannot be TypeScript, and a single-file component
#: writes its header inside its `<script>` block, where the `//` rule's own
#: `/* ... */` form is what a file whose top level is markup can carry.
PERCENT_COMMENT = (".pl", ".plt")
HASH_COMMENT = (".sh", ".mk")
SLASH_COMMENT = (".ts", ".mjs", ".js", ".rs", ".vue")
C_COMMENT = (".c", ".h")
CPP_COMMENT = (".cpp", ".cc", ".cxx", ".hpp", ".hh", ".hxx", ".C")
SEMICOLON_COMMENT = (".metta",)
MAKEFILE_NAMES = ("Makefile", "GNUmakefile")

#: The grammars whose language ALSO has `/* ... */`, so a line marker is one of
#: two ways in rather than the only one. Prolog is here for the same reason C
#: is: ISO 13211-1 gives it both forms and the plunit suites use the block one
#: for their contract headers.
BLOCK_GRAMMARS = ("//", "%")

#: The grammars whose language has ONLY a line marker, so the marker has to
#: open a comment before the pin on the pin's own line and there is no block
#: form to fall back to. MeTTa joined when three shipped examples carried a
#: pin in a `;` header and this pass refused all three by name: that refusal
#: asks for an entry here rather than for the hand substitution it exists to
#: replace.
LINE_ONLY_GRAMMARS = ("#", ";")

# Consume literal and preprocessing tokens before considering their markers.
# Line splices are reversed inside raw strings as C++23 N4950 requires:
# https://timsong-cpp.github.io/cppwp/n4950/lex.pptoken#3.1
C_SPLICE = re.compile(r"\\[ \t\v\f]*\r?\n")
C_TOKEN = re.compile(
    r"(?P<space>\s+)|(?P<comment>//|/\*)|"
    r'(?P<raw>(?:u8|[uUL])?R")|'
    r'''(?P<quoted>"(?:\\[^\n]|[^"\\\n])*"|'(?:\\[^\n]|[^'\\\n])*')|'''
    r"(?P<number>(?:[0-9]|\.[0-9])(?:[eEpP][+-]|[\w.'])*)|"
    r"(?P<word>[^\W\d]\w*)|(?P<other>.)",
    re.DOTALL,
)
# The delimiter's sixteen-character bound and alphabet are the language's.
# https://timsong-cpp.github.io/cppwp/n4950/lex.string#2
C_RAW_DELIMITER = re.compile(r"([\x21-\x27\x2a-\x5b\x5d-\x7e]{0,16})\(")


def _c_comment_spans(path: Path, text: str) -> list[tuple[int, int]]:
    """Locate C-family comment prose while preserving physical source offsets."""
    chunks: list[str] = []
    offsets: list[int] = []
    last = 0
    for splice in C_SPLICE.finditer(text):
        chunks.append(text[last:splice.start()])
        offsets.extend(range(last, splice.start()))
        last = splice.end()
    chunks.append(text[last:])
    offsets.extend(range(last, len(text) + 1))
    logical = "".join(chunks)
    comments: list[tuple[int, int]] = []
    position, previous_end = 0, 0
    context = "line"

    def refuse(at: int, description: str) -> None:
        line = text.count("\n", 0, offsets[at]) + 1
        message = f"pin_provenance: {path}:{line}: {description}"
        raise SystemExit(message)

    while position < len(logical):
        # Header names have no escape syntax. Consume them before the quoted
        # literal rule, which would give a backslash a different meaning.
        if context == "header" and logical[position] in ('<', '"'):
            closing = ">" if logical[position] == "<" else '"'
            end = logical.find(closing, position + 1)
            newline = logical.find("\n", position + 1)
            if end < 0 or 0 <= newline < end:
                refuse(position, "unterminated C/C++ header name")
            position, context = end + 1, ""
            continue
        token = C_TOKEN.match(logical, position)
        assert token is not None
        kind, value = token.lastgroup, token.group()
        start, position = token.span()
        if kind == "space":
            if "\n" in value:
                context = "line"
            continue
        if kind == "comment":
            closing = "\n" if value == "//" else "*/"
            end = logical.find(closing, position)
            if end < 0 and value == "/*":
                refuse(start, "unterminated C/C++ block comment")
            position = len(logical) if end < 0 else end + (2 if value == "/*" else 0)
            span = (offsets[start], offsets[position])
            if comments and not logical[previous_end:start].strip():
                comments[-1] = (comments[-1][0], span[1])
            else:
                comments.append(span)
            previous_end = position
            continue
        if kind == "raw":
            opening = offsets[position - 1] + 1
            delimiter = C_RAW_DELIMITER.match(text, opening)
            if delimiter is None:
                refuse(start, "invalid C++ raw-string delimiter")
            closing = ")" + delimiter[1] + '"'
            end = text.find(closing, delimiter.end())
            if end < 0:
                refuse(start, "unterminated C++ raw string")
            position = bisect_left(offsets, end + len(closing))
        elif value in ('"', "'"):
            refuse(start, "unterminated C/C++ string or character literal")
        if value == "#" and context == "line":
            context = "directive"
        elif kind == "word" and context == "directive" and value in ("include", "include_next", "import"):
            context = "header"
        elif kind == "word" and value in ("__has_include", "__has_include_next"):
            context = "has_include"
        elif value == "(" and context == "has_include":
            context = "header"
        elif value == "export" and context == "line" and path.suffix in CPP_COMMENT:
            context = "export"
        elif value == "import" and context in ("line", "export") and path.suffix in CPP_COMMENT:
            context = "header"
        else:
            context = ""
    return comments


# Consume complete unquoted arguments before looking for brackets or comments.
# These productions follow CMake 3.18's lexer, including its legacy arguments:
# https://github.com/Kitware/CMake/blob/v3.18.0/Source/LexerParser/cmListFileLexer.in.l#L76-L79
CMAKE_MAKEVAR = r"\$\([A-Za-z0-9_]*\)"
CMAKE_UNQUOTED = r'(?:[^ \0\t\r\n()#\\"\[=]|\\[^\0\n])'
CMAKE_LEGACY = rf'(?:{CMAKE_MAKEVAR}|{CMAKE_UNQUOTED}|"(?:{CMAKE_MAKEVAR}|{CMAKE_UNQUOTED}|[ \t\[=])*")'
CMAKE_WORD = re.compile(rf'(?:{CMAKE_MAKEVAR}|{CMAKE_UNQUOTED}|=|\[=*{CMAKE_LEGACY})(?:{CMAKE_LEGACY}|[\[=])*')
CMAKE_BRACKET = re.compile(r"#?\[(=*)\[")
CMAKE_QUOTED = re.compile(r'"(?:\\[\s\S]|[^"\\\0])*"')


def _cmake_comment_spans(path: Path, text: str) -> list[tuple[int, int]]:
    """Locate comments after consuming CMake's bracket, quoted and bare tokens."""
    comments = []
    position = 0

    def refuse(description: str) -> None:
        line = text.count("\n", 0, position) + 1
        message = f"pin_provenance: {path}:{line}: {description}"
        raise SystemExit(message)

    while position < len(text):
        start = position
        if text[position] == "\0":
            refuse("NUL in CMake source")
        if bracket := CMAKE_BRACKET.match(text, position):
            closing = "]" + bracket[1] + "]"
            end = text.find(closing, bracket.end())
            if end < 0:
                refuse("unterminated CMake bracket argument or comment")
            position = end + len(closing)
            if text[start] == "#":
                comments.append((start, position))
        elif text[position] == "#":
            end = text.find("\n", position)
            position = len(text) if end < 0 else end
            comments.append((start, position))
        elif text[position] == '"':
            quoted = CMAKE_QUOTED.match(text, position)
            if quoted is None:
                refuse("unterminated CMake quoted argument")
            position = quoted.end()
        elif word := CMAKE_WORD.match(text, position):
            position = word.end()
        else:
            position += 1
    return comments


def _grammar(path: Path) -> str | None:
    """The comment rule this file's class implies, or None to refuse it."""
    if path.suffix == ".py":
        return "py"
    if path.name == "CMakeLists.txt" or path.suffix == ".cmake":
        return "cmake"
    if path.suffix in PERCENT_COMMENT:
        return "%"
    if path.suffix in HASH_COMMENT or path.name in MAKEFILE_NAMES:
        return "#"
    if path.suffix in (*C_COMMENT, *CPP_COMMENT):
        return "c"
    if path.suffix in SLASH_COMMENT:
        return "//"
    if path.suffix in SEMICOLON_COMMENT:
        return ";"
    if path.suffix == ".json":
        return "json"
    if path.suffix == ".toml":
        return "toml"
    # A guide pins inside its evidence tags and discusses the placeholder in
    # prose around them; the tag brackets are the comment rule.
    if path.suffix == ".md":
        return "md"
    return None


def _docstring_spans(text: str) -> list[tuple[int, int]]:
    """Byte spans of every string constant that is NOT a docstring.

    Inverted deliberately: the caller wants to know where NOT to write, and a
    docstring is the one string a Python file uses to speak about itself. The
    walk covers f-strings too, whose literal halves are Constant nodes under a
    JoinedStr and carry the same hazard: the gate's own refusal message is an
    f-string, and the hand sweep rewrote it.
    """
    try:
        tree = ast.parse(text)
    except SyntaxError:
        return []
    documented: set[int] = set()
    for node in ast.walk(tree):
        body = getattr(node, "body", None)
        if not isinstance(node, ast.Module | ast.ClassDef | ast.FunctionDef | ast.AsyncFunctionDef):
            continue
        if (
            body
            and isinstance(body[0], ast.Expr)
            and isinstance(body[0].value, ast.Constant)
            and isinstance(body[0].value.value, str)
        ):
            documented.add(id(body[0].value))
    lines = text.splitlines(keepends=True)
    starts = [0]
    for line in lines:
        starts.append(starts[-1] + len(line))

    def offset(row: int, column: int) -> int:
        return starts[row - 1] + column

    spans = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Constant) or not isinstance(node.value, str):
            continue
        if id(node) in documented or node.end_lineno is None or node.end_col_offset is None:
            continue
        spans.append((offset(node.lineno, node.col_offset), offset(node.end_lineno, node.end_col_offset)))
    return spans


@cache
def _code_spans(text: str) -> tuple[tuple[int, int], ...]:
    r"""Byte spans of every inline code span, CommonMark's rule.

    A span opens on a run of backticks and closes on the next run of EXACTLY
    that length, and it may wrap across lines but never across a blank line
    [source: https://spec.commonmark.org/0.31.2/#code-spans].

    Wrapping is why this is not a per-line backtick count. Prose wraps and a
    mention wraps with it: DEVELOPING.md's own explanation of the scheme opens
    its span on one line and closes it on the next, so a line-local count read
    that line as unbalanced and called the mention a pin.

    Run LENGTH is why this is not a ``(`+)...\1`` regex either. A backreference
    matches that many backticks anywhere, including the first few of a LONGER
    run, so a single-tick span would close inside a double-tick one. This is the
    same delimiter-length walk check_spec_status.split_table_row runs for the
    same rule, written separately because that one splits cells and this one
    wants spans.
    """
    spans: list[tuple[int, int]] = []
    position, end = 0, len(text)
    opened, fence = -1, 0
    while position < end:
        if text[position] != "`":
            # A code span cannot contain a blank line, so an opener still
            # waiting at one was never a span and is abandoned there.
            if opened >= 0 and BLANK_LINE.match(text, position):
                opened, fence = -1, 0
            position += 1
            continue
        run = position
        while run < end and text[run] == "`":
            run += 1
        length = run - position
        if opened < 0:
            opened, fence = position, length
        elif length == fence:
            spans.append((opened, run))
            opened, fence = -1, 0
        position = run
    return tuple(spans)


def _backticked(text: str, at: int) -> bool:
    """Whether the placeholder at `at` sits inside an inline code span.

    `commit=WORKTREE` in backticks is the word being DISCUSSED. Three of the
    twelve sites the hand sweep damaged were exactly that: prose in a docstring
    and in a corpus README explaining what the re-pin tool writes.
    """
    return any(low <= at < high for low, high in _code_spans(text))


# A hash-chained record is not a pin target. An agenticmind record stores every
# log entry beside `after`, the id of the entry before it, so rewriting one byte
# in place breaks the chain and the WHOLE record stops reading rather than just
# the line that moved [measured 2026-09-20: pinning the live record's five
# placeholders made every later read fail with `transaction 520578131a041d1a
# does not hash to its contents; was deleted at #551 outside the authoring
# interface`, and it had to be restored from the previous commit]. Nor is a pin
# owed there: a claim in that record is never edited, only attacked, so
# `commit=WORKTREE` inside a reason is an account of what was believed when the
# reason was given, not a source pin awaiting resolution.
#
# Keyed on the SHAPE rather than on the filename, because this tree has
# submodules and each can carry its own record, while a file that merely happens
# to share the name is not one. The glob decides what is LOOKED AT and this
# decides what is REWRITABLE, so a record reached by a future glob is declined
# without anyone having to remember it.
#
# Declining here rather than dropping the glob is what makes ONE change do both
# jobs: scan/0 still VISITS the file, so it lands in the seen set and unscanned/1
# does not then report it as a pin nothing reaches.
UNPINNABLE_REASON = (
    "a hash-chained record: rewriting it in place breaks the chain and the "
    "whole record stops reading"
)


def _hash_chained(text: str) -> bool:
    """Whether this is a record whose entries hash over the entries before them."""
    try:
        loaded = json.loads(text)
    except (ValueError, RecursionError):
        return False
    log = loaded.get("log") if isinstance(loaded, dict) else None
    return (isinstance(log, list) and bool(log) and isinstance(log[0], dict)
            and "after" in log[0] and "id" in log[0])


def sites(path: Path, text: str) -> list[tuple[int, int, str | None]]:
    """Every placeholder in one file as (offset, line, reason it is declined)."""
    if _hash_chained(text):
        return [(m.start(), text.count("\n", 0, m.start()) + 1, UNPINNABLE_REASON)
                for m in TOKEN.finditer(text)]
    grammar = _grammar(path)
    found = []
    # The TOML parser already knows every string form. A comment substitution
    # leaves its data unchanged; parse_float=str also preserves NaN equality.
    configuration = tomllib.loads(text, parse_float=str) if grammar == "toml" else None
    if grammar == "py":
        skip = _docstring_spans(text)
    elif grammar == "c":
        skip = _c_comment_spans(path, text)
    elif grammar == "cmake":
        skip = _cmake_comment_spans(path, text)
    elif grammar in BLOCK_GRAMMARS:
        skip = [match.span() for match in BLOCK_COMMENT.finditer(text)]
    elif grammar == "md":
        skip = [match.span() for match in CLAIM.finditer(text)]
    else:
        skip = []
    for match in TOKEN.finditer(text):
        at = match.start()
        line = text.count("\n", 0, at) + 1
        reason: str | None = None
        if grammar in ("c", "cmake"):
            comment = next(((low, high) for low, high in skip if low <= at < high), None)
            if comment is None:
                language = "C/C++" if grammar == "c" else "CMake"
                reason = f"outside a {language} comment: this code emits or matches pins"
            elif _backticked(text[comment[0]:comment[1]], at - comment[0]):
                reason = "a backticked mention of the placeholder, not a pin"
        elif _backticked(text, at):
            reason = "a backticked mention of the placeholder, not a pin"
        elif grammar == "toml":
            candidate = text[:at] + "commit=PROVENANCE" + text[match.end():]
            try:
                comment = tomllib.loads(candidate, parse_float=str) == configuration
            except tomllib.TOMLDecodeError:
                # Changing a quoted key can collide with another key.
                comment = False
            if not comment:
                reason = "a TOML key or value, not a comment"
        elif grammar == "py":
            if any(low <= at < high for low, high in skip):
                reason = "a string literal that is not a docstring: this code emits or matches pins"
        elif grammar in LINE_ONLY_GRAMMARS:
            head = text[text.rfind("\n", 0, at) + 1 : at]
            if grammar not in head:
                reason = f"no {grammar} opens a comment before it on its line"
        elif grammar in BLOCK_GRAMMARS:
            head = text[text.rfind("\n", 0, at) + 1 : at]
            if grammar not in head and not any(low <= at < high for low, high in skip):
                reason = f"neither {grammar} nor a /* */ block opens a comment around it"
        elif grammar == "md":
            if not any(low <= at < high for low, high in skip):
                reason = "outside an evidence tag, so prose about the placeholder rather than a pin"
        elif grammar is None:
            reason = f"{path.suffix or path.name} has no comment rule here; add one rather than guessing"
        found.append((at, line, reason))
    return found


def unscanned(seen: set[Path]) -> list[tuple[Path, int]]:
    """Tracked files holding a real pin that the gate's globs never visited.

    The per-file refusal in `sites` only speaks for a file the globs REACHED,
    so a pin in a class nobody listed was not refused, it was invisible: on
    2026-08-31 extensions/cmetta/Makefile, extensions/node/tools/dist-consumer.mjs
    and extensions/cmetta/tests/install_consumer.c each carried one and --check
    still exited 0, which would have shipped three claims whose evidence tree is
    named as the word WORKTREE forever.

    Widening the globs fixes those three; this fixes the CLASS, because it asks
    git for the file list rather than a glob and so catches the next new file
    class the first time it carries a pin. A backticked mention is skipped here
    for the same reason it is skipped there: DEVELOPING.md and the corpus README
    both spell the placeholder while explaining it.
    """
    listed = subprocess.run(
        ["git", "grep", "-l", "--untracked", "--", f"commit={PLACEHOLDER}"],
        cwd=ROOT, capture_output=True, text=True, check=False,
    )
    missed = []
    for name in listed.stdout.split():
        path = (ROOT / name).resolve()
        if path in seen or not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        pins = sum(1 for m in TOKEN.finditer(text) if not _backticked(text, m.start()))
        if pins:
            missed.append((path, pins))
    return missed


def scan() -> tuple[list[tuple[Path, list[tuple[int, int, str | None]], str]], set[Path]]:
    """Every file the evidence gate reads that holds a placeholder.

    Returns the visited set alongside the hits, because what was NOT visited is
    the question `unscanned` answers and only this walk knows it.
    """
    seen: set[Path] = set()
    out = []
    for glob in (*SOURCES, *PROVENANCE_SOURCES):
        for path in owned(ROOT.glob(glob), ROOT):
            if path in seen:
                continue
            seen.add(path)
            text = path.read_text(encoding="utf-8")
            if PLACEHOLDER not in text:
                continue
            found = sites(path, text)
            if found:
                out.append((path, found, text))
    return out, seen


def resolve(commit: str) -> str:
    """The full object ID of a commit, or a refusal naming what was asked."""
    done = subprocess.run(
        ["git", "rev-parse", "--verify", "--end-of-options", f"{commit}^{{commit}}"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    if done.returncode != 0:
        msg = f"pin_provenance: {commit} does not resolve to a commit in {ROOT}"
        raise SystemExit(msg)
    return done.stdout.strip()


def main(argv: list[str] | None = None) -> int:
    """Resolve the placeholders, or report the ones still open under --check."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    #No default. A bare run REPORTS, the way its sibling example_origins.py
    #does, because "resolve every placeholder in the tree to HEAD" is not what
    #someone typing the tool's name with no argument is asking for. With
    #default="HEAD" it was: three sets of pins were written and reverted in one
    #session that way, each carrying a measurement taken days earlier onto a
    #commit whose tree never produced it. The two documented forms, --check and
    #--commit <A>, are unchanged.
    parser.add_argument(
        "--commit",
        default=None,
        help="the commit whose tree supplied the evidence; its full object ID replaces the placeholder",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="write nothing and exit 1 if any placeholder would be rewritten",
    )
    arguments = parser.parse_args(argv)

    found, seen = scan()
    missed = unscanned(seen)
    pins = [(path, [item for item in items if item[2] is None], text) for path, items, text in found]
    declined = [
        (path, line, reason) for path, items, _ in found for _, line, reason in items if reason
    ]
    total = sum(len(items) for _, items, _ in pins)

    reporting = arguments.check or arguments.commit is None
    if reporting:
        for path, items, _ in pins:
            for _, line, _reason in items:
                print(f"{path.relative_to(ROOT)}:{line}: placeholder awaiting a provenance pin")
    else:
        oid = resolve(arguments.commit)
        for path, items, text in pins:
            if not items:
                continue
            rewritten = text
            for at, _line, _reason in reversed(items):
                rewritten = rewritten[:at] + f"commit={oid}" + rewritten[at + len(f"commit={PLACEHOLDER}") :]
            path.write_text(rewritten, encoding="utf-8")
            print(f"{path.relative_to(ROOT)}: {len(items)} pin(s) -> {oid}")

    for path, line, reason in declined:
        print(f"{path.relative_to(ROOT)}:{line}: left alone, {reason}")
    for path, pins_missed in missed:
        print(
            f"{path.relative_to(ROOT)}: {pins_missed} pin(s) OUTSIDE the evidence gate's globs, "
            f"so nothing reads this file's claims and nothing would ever resolve them; "
            f"add its glob to check_evidence_tags.SOURCES"
        )
    print(
        f"{total} pin(s) {'awaiting' if reporting else 'resolved'}, "
        f"{len(declined)} occurrence(s) left alone, "
        f"{len(missed)} file(s) outside the globs, over "
        f"{len(found)} file(s) carrying the placeholder"
    )
    return 1 if (reporting and total) or missed else 0


if __name__ == "__main__":
    sys.exit(main())
