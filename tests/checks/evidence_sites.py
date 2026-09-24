"""Purpose: say whether a place in a file is prose or code, by its grammar.

Prose is where the file's own grammar puts it: a comment, a docstring, JSON
measurement prose or an evidence tag. Everything else is code or data, and
the evidence gate reads a tag or a commit pin only where it is a claim.

classify(path, text, offsets) answers None for an offset in prose and, for
any other offset, the reason it is code or data. The gate asks it which
`commit=WORKTREE` placeholders are pins to count, and which tags and pins on a
line written since check_evidence_tags.RULE_INSTANT are held to the stamp rule.
A placeholder in a string literal that is not a docstring belongs to code that
EMITS or MATCHES pins: on 2026-08-31 a hand sweep that could not tell the
difference rewrote twelve string literals, the twin re-pin tool's own tag
template among them, which then wrote a stale object ID into every twin it
priced.

It decides per file class rather than per byte:

  .py            a place inside a string literal that is not a docstring is
                 code. The distinction is `ast`'s, not a regex's.
  .pl .plt       prose when a `%` opens a comment before it on its line, or
                 inside a `/* ... */` block, Prolog's other comment form and
                 how the plunit suites write their contract headers.
  .sh .mk .yml   the same rule with `#`. A Makefile, a Dockerfile and the
  .yaml          example skip list are keyed by NAME, since their suffix
  Makefile       says nothing of their grammar.
  Dockerfile
  example_skips.txt
  .ts .mjs .js   the same rule with `//`, plus `/* ... */` blocks.
  .rs .vue
  .metta         the same rule with `;`.
  .c .h .cpp     C and C++ comments are located after consuming literal and
  .cc .cxx .C    preprocessing tokens, so a comment marker inside an
  .hpp .hh .hxx  ordinary, raw or macro string or a header name stays data.
  .json          commentless, so measurement prose is the only place a pin
                 can be, and every place in one is prose.
  .toml          prose where changing the one character at the offset leaves
                 the parsed configuration equal, which only a comment allows.
  .cmake         CMake's line and bracket comments; quoted, bracket and
  CMakeLists.txt escaped unquoted arguments stay data.
  .md llms.txt   prose inside an evidence tag.

In every class a mention inside an inline code span is the word discussed and
not a pin, and a span opens and closes only within what the class calls prose.
A class with no rule, and a C, C++, CMake or TOML file too malformed to read,
raise UnclassifiableError naming it rather than being guessed at, so a file
class that starts carrying tags is refused the first time rather than skipped.

Assumes: the text is the file's whole content, since the C, CMake and TOML
  rules read it from its start.
Guarantees:
  - each planted shape lands on the side its class's rule documents, at the
    placeholder and at the bracket of the tag around it
    [tested 2026-09-25T04:18:23+10:00: tests/checks/check_evidence_sites_selftest.py]
  - C and C++ literal, macro and header data stay data beside real comment
    pins, CMake's three argument forms stay data beside its comments, and a
    malformed C, C++, CMake or TOML form raises UnclassifiableError naming the form
    [tested 2026-09-25T04:18:23+10:00: tests/checks/check_evidence_sites_selftest.py]
  - a class with no rule raises UnclassifiableError naming the class, and only when
    something in it needs placing
    [tested 2026-09-25T04:18:23+10:00: tests/checks/check_evidence_sites_selftest.py]
  - unscanned reports a tracked file holding a real placeholder that the
    gate's globs never reach, in the repository and its components, and
    neither a backticked mention, a file the globs do reach nor an untracked
    file [tested 2026-09-25T04:18:23+10:00: tests/checks/check_evidence_sites_selftest.py]
Fails when: a `#`, `%`, `//` or `;` inside a quoted string precedes a pin on its
  line, which the line rules read as a comment opening. It errs toward calling
  the place prose, so the gate holds such a line to the stamp rule rather than
  skipping it.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import ast
import json
import re
import subprocess
import tomllib
from bisect import bisect_left
from collections.abc import Sequence
from functools import cache
from pathlib import Path

from check_evidence_tags import CLAIM, PLACEHOLDER

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
#:
#: Four joined when the gate began reading every file git sees, since each
#: carried tags and pins no rule placed [measured 2026-09-25T01:10:02+10:00:
#: over the 4,100 files the checkout and its components track, eleven in two
#: Dockerfiles, six in two workflows, six in two llms.txt files and four in
#: tests/data/example_skips.txt, and no other class without a rule carried
#: any]. A Dockerfile comments a line that begins with `#` and hands a RUN
#: line's `#` to the shell, where it opens a comment too [source
#: 2026-09-25T01:08:24+10:00: https://docs.docker.com/reference/dockerfile/,
#: "BuildKit treats lines that begin with # as a comment"]; YAML's `#` opens
#: one after white space [source 2026-09-25T01:08:24+10:00:
#: https://yaml.org/spec/1.2.2/, 6.6 Comments]; llms.txt is Markdown [source
#: 2026-09-25T01:08:24+10:00: https://llmstxt.org/, Format]; and the skip list
#: states its own rule in its first two lines, that a line starting with `#`
#: is ignored and every other one is a path and its reason.
PERCENT_COMMENT = (".pl", ".plt")
HASH_COMMENT = (".sh", ".mk", ".yml", ".yaml")
SLASH_COMMENT = (".ts", ".mjs", ".js", ".rs", ".vue")
C_COMMENT = (".c", ".h")
CPP_COMMENT = (".cpp", ".cc", ".cxx", ".hpp", ".hh", ".hxx", ".C")
SEMICOLON_COMMENT = (".metta",)
HASH_NAMES = ("Makefile", "GNUmakefile", "Dockerfile", "example_skips.txt")
MARKDOWN_NAMES = ("llms.txt",)

#: The grammars whose language ALSO has `/* ... */`, so a line marker is one of
#: two ways in rather than the only one. Prolog is here for the same reason C
#: is: ISO 13211-1 gives it both forms and the plunit suites use the block one
#: for their contract headers.
BLOCK_GRAMMARS = ("//", "%")

#: The grammars whose language has ONLY a line marker, so the marker has to
#: open a comment before the pin on the pin's own line and there is no block
#: form to fall back to. MeTTa joined when three shipped examples carried a
#: pin in a `;` header and all three were refused by name: that refusal asks
#: for an entry here rather than for a guess.
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
        message = f"{path}:{line}: {description}"
        raise UnclassifiableError(message)

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
        message = f"{path}:{line}: {description}"
        raise UnclassifiableError(message)

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


def grammar(path: Path) -> str | None:
    """The comment rule this file's class implies, or None when it has none."""
    if path.suffix == ".py":
        return "py"
    if path.name == "CMakeLists.txt" or path.suffix == ".cmake":
        return "cmake"
    if path.suffix in PERCENT_COMMENT:
        return "%"
    if path.suffix in HASH_COMMENT or path.name in HASH_NAMES:
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
    if path.suffix == ".md" or path.name in MARKDOWN_NAMES:
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
# decides what is a PIN, so a record reached by a future glob is declined
# without anyone having to remember it.
#
# Declining here rather than dropping the glob is what makes ONE change do both
# jobs: the gate's glob walk still VISITS the file, so it lands in the seen set
# and unscanned does not then report it as a pin nothing reaches.
UNPINNABLE_REASON = (
    "a hash-chained record: rewriting it in place breaks the chain and the "
    "whole record stops reading"
)



#: What precedes a line grammar's first marker on each line, which the line
#: rule calls code; a line holding no marker is code whole.
CODE_BEFORE = {
    marker: re.compile(rf"^(?:(?!{re.escape(marker)})[^\n])*", re.MULTILINE)
    for marker in ("#", ";", "%", "//")
}
NOT_NEWLINE = re.compile(r"[^\n]")


def _blank(found: re.Match[str]) -> str:
    return " " * len(found.group())


def _prose(kind: str, text: str, skip: list[tuple[int, int]]) -> str:
    """The text with what this grammar calls code blanked, so backticks pair within prose alone.

    A code span is Markdown in prose, so a backtick the grammar calls code
    cannot open or close one: a Python regex's `["'`]`, a TypeScript template
    literal, a shell command substitution. Paired over the whole file, one of
    them shifted every pairing after it until a blank line, and a bare
    placeholder written below check_evidence_tags.py's NODE_TEST regex read as
    backticked [measured 2026-09-25T01:25:11+10:00: in that file as this
    change's parent holds it, the regex's backtick on line 640 shifted eleven
    spans across lines, 640->643 through 710->713].
    Blanking keeps every offset and every newline, so the lines of one comment
    stay one paragraph a span may wrap across, as a highlighter injects
    Markdown into a comment's text, and a line of code alone becomes a blank
    line, which ends one.

    Code is what classify reads as code: in Python a string that is not a
    docstring, and in a line or block grammar what precedes the first marker
    on a line outside a block comment, TOML's comments opening at `#` as the
    shell's do. Markdown is prose whole, and JSON, C and CMake are placed by
    their own spans, so their text comes back as it is.

    Time: one regular-expression pass and one splice per block comment or
    string, O(T + B) for T characters and B spans.
    """
    if kind == "py":
        spans = [(low, high, "") for low, high in skip]
        base = text
    elif kind in (*LINE_ONLY_GRAMMARS, *BLOCK_GRAMMARS, "toml"):
        base = CODE_BEFORE["#" if kind == "toml" else kind].sub(_blank, text)
        blocks = BLOCK_COMMENT.finditer(text) if kind in BLOCK_GRAMMARS else ()
        spans = [(found.start(), found.end(), found.group()) for found in blocks]
    else:
        return text
    pieces: list[str] = []
    last = 0
    for low, high, kept in sorted(spans):
        if low < last:
            continue
        pieces += [base[last:low], kept or NOT_NEWLINE.sub(" ", text[low:high])]
        last = high
    pieces.append(base[last:])
    return "".join(pieces)


def hash_chained(text: str) -> bool:
    """Whether this text has a hash-chained record's shape, for the reason the comment above gives."""
    try:
        loaded = json.loads(text)
    except (ValueError, RecursionError):
        return False
    log = loaded.get("log") if isinstance(loaded, dict) else None
    return (isinstance(log, list) and bool(log) and isinstance(log[0], dict)
            and "after" in log[0] and "id" in log[0])


class UnclassifiableError(ValueError):
    """A file whose grammar cannot be read far enough to place an offset in it."""


def classify(path: Path, text: str, offsets: Sequence[int]) -> list[str | None]:
    """None for each offset where this file's grammar puts prose, else why it is code or data.

    An offset is where a tag's bracket or a pin's `commit=` begins. Asking
    about no offset reads nothing, so a class with no rule is refused only
    when something in it needs placing.

    Raises UnclassifiableError for a class with no rule here, and for a C, C++,
    CMake or TOML file too malformed to read, rather than guessing.

    Time: one pass over the text to find its prose spans, then one scan of
    the spans per offset, O(T + K * S) for T characters, K offsets and S
    spans; TOML instead parses the text once per offset, O(K * T).
    """
    if not offsets:
        return []
    if hash_chained(text):
        return [UNPINNABLE_REASON] * len(offsets)
    kind = grammar(path)
    if kind is None:
        msg = (f"{path}: {path.suffix or path.name} has no comment rule here; "
               f"add one to evidence_sites.grammar rather than guessing")
        raise UnclassifiableError(msg)
    configuration = None
    if kind == "toml":
        # The TOML parser already knows every string form, and parse_float=str
        # keeps NaN equal to itself.
        try:
            configuration = tomllib.loads(text, parse_float=str)
        except tomllib.TOMLDecodeError as error:
            msg = f"{path}: not TOML, so a comment cannot be told from a value: {error}"
            raise UnclassifiableError(msg) from error
    if kind == "py":
        skip = _docstring_spans(text)
    elif kind == "c":
        skip = _c_comment_spans(path, text)
    elif kind == "cmake":
        skip = _cmake_comment_spans(path, text)
    elif kind in BLOCK_GRAMMARS:
        skip = [match.span() for match in BLOCK_COMMENT.finditer(text)]
    elif kind == "md":
        skip = [match.span() for match in CLAIM.finditer(text)]
    else:
        skip = []
    prose = _prose(kind, text, skip)
    found: list[str | None] = []
    for at in offsets:
        reason: str | None = None
        if kind in ("c", "cmake"):
            comment = next(((low, high) for low, high in skip if low <= at < high), None)
            if comment is None:
                language = "C/C++" if kind == "c" else "CMake"
                reason = f"outside a {language} comment: this code emits or matches pins"
            elif _backticked(text[comment[0]:comment[1]], at - comment[0]):
                reason = "a backticked mention, the word discussed rather than a claim"
        elif kind == "json":
            # A JSON string holds no raw newline, so no code span in one
            # crosses a line, and a backtick left open in one string cannot
            # close in the next.
            low = text.rfind("\n", 0, at) + 1
            high = text.find("\n", at) % (len(text) + 1)
            if _backticked(text[low:high], at - low):
                reason = "a backticked mention, the word discussed rather than a claim"
        elif _backticked(prose, at):
            reason = "a backticked mention, the word discussed rather than a claim"
        elif kind == "toml":
            # One character at the offset, changed. A comment's text is not
            # data, so only inside one does the parsed configuration stay
            # equal; a change that collides with another key fails to parse,
            # and is a key for the same reason.
            changed = text[:at] + ("X" if text[at] != "X" else "Y") + text[at + 1:]
            try:
                comment = tomllib.loads(changed, parse_float=str) == configuration
            except tomllib.TOMLDecodeError:
                comment = False
            if not comment:
                reason = "a TOML key or value, not a comment"
        elif kind == "py":
            if any(low <= at < high for low, high in skip):
                reason = "a string literal that is not a docstring: this code emits or matches pins"
        elif kind in LINE_ONLY_GRAMMARS:
            head = text[text.rfind("\n", 0, at) + 1 : at]
            if kind not in head:
                reason = f"no {kind} opens a comment before it on its line"
        elif kind in BLOCK_GRAMMARS:
            head = text[text.rfind("\n", 0, at) + 1 : at]
            if kind not in head and not any(low <= at < high for low, high in skip):
                reason = f"neither {kind} nor a /* */ block opens a comment around it"
        elif kind == "md" and not any(low <= at < high for low, high in skip):
            reason = "outside an evidence tag, so prose about a pin rather than a pin"
        found.append(reason)
    return found


def sites(path: Path, text: str) -> list[tuple[int, int, str | None]]:
    """Every placeholder in one file as (offset, line, why it is not a pin or None)."""
    offsets = [match.start() for match in TOKEN.finditer(text)]
    return [(at, text.count("\n", 0, at) + 1, reason)
            for at, reason in zip(offsets, classify(path, text, offsets), strict=True)]


def unscanned(seen: set[Path], root: Path) -> list[tuple[Path, int]]:
    """Tracked files under `root` holding a real pin that the gate's globs never visited.

    The per-file refusal in `classify` only speaks for a file the globs REACHED,
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

    Across the components too, since the gate's own walks read their files,
    and a net stopping at the superproject left two of their pins unread
    [measured 2026-09-25T01:17:45+10:00: ext/check.sh:11 and ext/README.md:5,
    each carrying a placeholder no glob reached].

    Tracked files only. An untracked file is read by the gate's rule-era check,
    which dates every line of it after the rule and refuses a placeholder
    there, and saying "add its glob" of a file that only lacks `git add` would
    name the wrong remedy.
    """
    listed = subprocess.run(
        ["git", "grep", "-l", "-z", "-F", "--recurse-submodules", "--", f"commit={PLACEHOLDER}"],
        cwd=root, capture_output=True, text=True, check=False,
    )
    # git grep answers 1 for no match, and anything above 1 for a failure.
    if listed.returncode > 1:
        msg = f"git grep refused {root}: {listed.stderr.strip()}"
        raise RuntimeError(msg)
    missed = []
    for name in filter(None, listed.stdout.split("\0")):
        path = (root / name).resolve()
        if path in seen or not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        pins = sum(1 for m in TOKEN.finditer(text) if not _backticked(text, m.start()))
        if pins:
            missed.append((path, pins))
    return missed
