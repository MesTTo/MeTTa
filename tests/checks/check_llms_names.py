"""Purpose: hold every llms.txt to the tree and the engine it describes.

llms.txt opens by promising this: "Names here are checked against the live
engine and the real file tree by `check.sh`'s `llms` lane, so a rename breaks
the build instead of misleading you." That lane did not exist. The promise was
written on 2026-08-29 and nothing behind it ever ran, which is how the library
roster came to name 33 of 34 libraries, omit `lib_dict` and `lib_gitimport`,
and say so in two places for three days without a red lane [measured
2026-09-01, the audit that found it].

A cheat sheet is the one document read by something that cannot notice a stale
claim, so the file that asserts its own gate and has none is worse off than one
admitting it is hand-kept. Nine checks cover both directions of each promise:

  PATHS       every backticked token that names a file or directory resolves,
              a glob resolving to at least one match, against THIS checkout's
              own files: scratch under ai-tmp/, a dependency's files under
              node_modules/, and any directory carrying its own .git (another
              checkout) never answer a claim. This is the "real file tree"
              half.
  LIBRARIES   the roster sentence's names and its count equal `lib/lib_*/`.
              The count is stated twice, in the sources table and in the
              roster, and both are read.
  COUNTS      every explicit source-table count is derived from the path or
              source it describes.
  OPERATORS   the count and the roster of `S` attributes that are operator
              words rather than spellings, derived from the live `S` by the
              claim's own definition. This is a PROSE count, the class COUNTS
              cannot reach, and it read thirteen against fourteen until the
              check existed.
  HEADS       every name in the language-surface block is one the engine gives
              meaning to, asked of the ENGINE rather than of a list. Both
              questions are asked, `fun/1` and the translator's own
              metta_translated_head/1, because a head has meaning through
              either and asking one alone reports the other's names as unknown.
  NEAR MISS   a head-shaped token the vocabulary does not know while its bang
              variant IS known, which is the typo the engine's own name ladder
              would have resolved. Library heads are read here, 289 across 24
              libraries, because the engine vocabulary does not carry them and
              nothing else checked them.
  USED HEADS  every engine-known call head exercised by the example corpus is
              named somewhere in the root cheat sheet. This is the reverse
              question HEADS did not ask.
  RETURNS     every documented `-> Type` agrees with the live return
              annotation, compared by HEAD name so a sheet may be more precise
              than the signature is. A method the annotation says nothing about
              is skipped rather than guessed at.
  CLOSED SETS every semiring, algebra-law, algebra-object, effect-class and
              provider-capability roster equals the implementation that owns
              it, and each alias expansion equals its catalog claim, all five
              read from the engine catalog rather than from a list kept here.
              The root sheet must carry each one, so deleting a roster cannot
              silence its check; a seat sheet is free not to cover a set and
              is held to what it does state.

Assumes:
  - swipl is on PATH; without it the HEADS half is skipped aloud rather than
    silently, the way the sibling lanes skip a missing toolchain.
  - it runs from a checkout of this repository.
Guarantees:
  - a path that stopped resolving, a roster that stopped matching `lib/`, a
    count that stopped matching its own roster, and a language-surface name the
    engine does not know each fail independently and name the file and line
    [tested: tests/checks/check_llms_selftest.py; commit=b089d4309f34b205c5fdaee46960d1fcd9c1ac42]
  - every llms.txt in the tree is read, including the root and each extension,
    so an extension sheet is not exempt from the promise the root makes
    [tested: tests/checks/check_llms_selftest.py; commit=b089d4309f34b205c5fdaee46960d1fcd9c1ac42]
  - each Python call is checked against the receiver's actual class, and an
    unlabelled API block containing such calls is still inspected
    [tested: tests/checks/check_llms_selftest.py; commit=b089d4309f34b205c5fdaee46960d1fcd9c1ac42]
  - source-table counts and reverse corpus-head coverage are derived from the
    files and live vocabulary, with independently planted omissions
    [tested: tests/checks/check_llms_selftest.py; commit=2c376be0bca6f85920288863ac89f09a44e6c0c7]
  - a documented head the vocabulary does not know while its bang variant does
    is reported both ways, library heads are read so all 24 libraries' surface
    is covered, and a path, a non-head and a real head are each left alone
    [tested: tests/checks/check_llms_selftest.py; commit=b4091abea5e9562c910d1284719b2a096b0fe2b7]
  - the operator-word count and roster are derived from the live `S` by the
    claim's own definition, so a wrong count, a dropped word, a plain spelling
    given a row, and deletion of the claim itself each fail separately
    [tested: tests/checks/check_llms_selftest.py; commit=d2e52f700bac9063b27d20fcf7001b35f6aa8bd1]
  - the library count is attached to the shipped directories rather than a
    `.metta`-only glob that omits a Prolog-only implementation [tested:
    tests/checks/check_llms_selftest.py;
    commit=1bfad3db85807fff774cad370ff8e57f7400ae99]
  - a documented return type the live annotation contradicts is reported, while
    a prose tail, a module qualifier, an omitted parameter, a positional tuple
    and a sheet more precise than the signature are not [tested:
    tests/checks/check_llms_selftest.py; commit=4ef96c94579db405fafed8fdaab20e33901a2298]
  - every required closed-value roster fails closed and is compared in both
    directions with the catalog or Python constant that owns it [tested:
    tests/checks/check_llms_selftest.py; commit=2e627a593413191cda3170f2eb716835f7f62543]
  - the algebra-law roster and its alias table are held to the catalog's own
    vocabulary row and expansion claims, the alias table by exact alias=target
    rows [tested: tests/checks/check_llms_selftest.py; commit=5e0ae6c22d604c4b980766e3cc4811ee545e5c9e]
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None.
"""

from __future__ import annotations

import argparse
import inspect
import os
import re
import subprocess
import sys
from collections.abc import Iterator, Mapping
from functools import cache
from pathlib import Path

from bounded_spawn import bounded

REPO = Path(__file__).resolve().parents[2]

#: A backticked token is a PATH claim only when it is unambiguously one: it
#: carries a known file extension, or it ends in a separator. Everything else
#: with a slash in it is a name -- `add-atom/3` is a predicate indicator,
#: `metta.run/match/eval` is a list of doors, `metta-node/spaces` is a module
#: specifier -- and reading those as paths reported nine names as missing
#: files on this lane's first run. A claim resolves against the sheet's OWN
#: directory or the repository root, and a multi-segment one may also name a
#: real path by suffix, which is how a sheet writes `tests/repository/` as
#: `repository/` in prose without lying about the tree.
_SUFFIXES = frozenset(
    {
        ".pl",
        ".plt",
        ".py",
        ".pyi",
        ".md",
        ".metta",
        ".c",
        ".h",
        ".ts",
        ".mjs",
        ".json",
        ".txt",
        ".sh",
        ".so",
        ".toml",
        ".yml",
        ".ipynb",
        ".rs",
        ".lean",
    }
)


#: A path is spelled in path characters. `#//` and its `#`-prefixed kin are
#: the relational-arithmetic operators, and a trailing-slash test alone read
#: the first of them as a directory.
_PATH_CHARACTERS = re.compile(r"^[\w.\-*/]+$")


def _is_path_claim(token: str) -> bool:
    if not _PATH_CHARACTERS.match(token):
        return False
    return token.endswith("/") or Path(token).suffix in _SUFFIXES


#: Directories that are not this tree, so the shorthand walk never enters
#: them: scratch (`ai-tmp/`, where agent worktrees also live), a dependency's
#: own files (`node_modules/`) and bytecode caches. A directory carrying its
#: own `.git` entry is another checkout and is pruned by that mark rather than
#: by name. Pruning at the directory is pytest's `norecursedirs` shape and
#: ripgrep's ignore walker's: a pruned directory is never read, so nothing
#: under it can supply a match. Before this, `REPO.rglob` answered the Node
#: sheet's `browser/` claim from an agent worktree under ai-tmp/ while this
#: checkout held no browser build at all
#: [source: https://docs.pytest.org/en/stable/reference/reference.html#confval-norecursedirs].
_PRUNED = frozenset({"ai-tmp", "node_modules", "__pycache__"})


@cache
def _own_components() -> frozenset[str]:
    """The paths this tree MOUNTS, read from the `.gitmodules` that mount them.

    A component holds a `.git` exactly as a foreign checkout does, so the bare
    marker test below called all eight of this superproject's submodules
    foreign and hid everything inside them. Every glob naming one then reported
    that it named nothing: `engine/metta/*.pl`, `lib/lib_*/`,
    `extensions/python/metta/*.py` and nine more
    [measured 2026-09-20: twelve of the lane's thirty-three findings].

    Derived from the files that decide it rather than listed here, and walked
    because a component mounts components of its own: the examples corpus is a
    submodule of the Python seat rather than of this tree.
    """
    found: set[str] = set()
    pending = [REPO]
    while pending:
        base = pending.pop()
        modules = base / ".gitmodules"
        if not modules.is_file():
            continue
        for relative in re.findall(r"^\s*path\s*=\s*(.+?)\s*$",
                                   modules.read_text(encoding="utf-8"),
                                   re.MULTILINE):
            component = (base / relative).resolve()
            if not component.is_dir():
                continue
            found.add(str(component.relative_to(REPO)))
            pending.append(component)
    return frozenset(found)


def _another_checkout(directory: Path) -> bool:
    """Whether `directory` is a nested worktree or clone rather than this tree."""
    if directory == REPO:
        return False
    if str(directory.relative_to(REPO)) in _own_components():
        return False
    return (directory / ".git").exists()


def _in_this_tree(path: Path) -> bool:
    """Whether an explicit glob hit lies in this checkout's own tree."""
    parts = path.relative_to(REPO).parts
    if any(part in _PRUNED for part in parts[:-1]):
        return False
    return not any(_another_checkout(REPO.joinpath(*parts[:depth])) for depth in range(1, len(parts)))


def _tree_paths_named(name: str) -> Iterator[Path]:
    """Every file or directory in THIS checkout whose last component is `name`.

    A pruning walk rather than `rglob`: `_PRUNED` names, dot-directories
    (an explicit claim may still name `.github/...`, since the direct check
    in `_resolves` reads it) and other checkouts are not entered.
    """
    for root, directories, files in os.walk(REPO):
        here = Path(root)
        directories[:] = sorted(
            d
            for d in directories
            if d not in _PRUNED and not d.startswith(".") and not _another_checkout(here / d)
        )
        for entry in (*directories, *files):
            if entry == name:
                yield here / entry


@cache
def _build_output(directory: str, token: str) -> bool:
    """Whether this tree deliberately does not hold the path.

    `extensions/node/llms.txt` names `browser/`, `_runtime/`, `runtime.json`
    and `wasm/`, and `extensions/node/.gitignore` lists the first two: they are
    what the build produces, so naming them is a claim about the kit a page
    serves rather than a broken claim about the tree. A checker that cannot
    tell the two apart reports the documentation for being accurate.

    git is asked rather than the ignore files read, because the rules nest and
    the answer is git's. A path outside a repository answers no.

    NOT every ignored path: the PATHS contract above says scratch under
    `ai-tmp/` and a dependency's files under `node_modules/` never answer a
    claim, and both are ignored, so asking git alone would let any typo under
    either resolve. `_PRUNED` is the same set the tree walk refuses to enter.
    """
    if any(part in _PRUNED for part in Path(token).parts):
        return False
    try:
        finished = subprocess.run(
            ["git", "check-ignore", "-q", "--no-index", token],
            cwd=directory, capture_output=True, check=False, timeout=10)
    except (OSError, subprocess.SubprocessError):
        return False
    return finished.returncode == 0


def _resolves(sheet: Path, token: str) -> bool:
    """Whether a path claim names something this checkout answers for.

    It answers for a path it actually holds, and for one it deliberately does
    not hold because a build is what produces it.
    """
    if _build_output(str(sheet.parent), token):
        return True
    bases = (sheet.parent, REPO)
    if "*" in token:
        return any(_in_this_tree(hit) for base in bases for hit in base.glob(token))
    if any((base / token.lstrip("/")).exists() for base in bases):
        return True
    # A prose shorthand names a real path by its tail: `repository/` for
    # tests/repository/, `gallery/` for the examples one.
    tail = token.strip("/")
    if "/" not in tail:
        # A bare name may be a file the sheet names without its directory,
        # `ext_points.plt` for the suite of that name, as well as a directory.
        return any(True for _ in _tree_paths_named(tail))
    return any(
        str(candidate.relative_to(REPO)).endswith(tail)
        for candidate in _tree_paths_named(Path(tail).name)
    )


#: The roster sentence, whose count and names both have to match `lib/`.
_ROSTER = re.compile(
    r"(?P<count>\d+) libraries load with .*?:(?P<names>.*?)\. Scored",
    re.DOTALL,
)
#: The same count where the sources table states it a second time.
_TABLE_COUNT = re.compile(r"\|\s*`lib/lib_\*/`\s*\|\s*(?P<count>\d+) MeTTa libraries")
ROSTER_BEGIN = "<!-- begin generated library roster -->"
ROSTER_END = "<!-- end generated library roster -->"

#: Closed-value prose is parsed only at a labelled contract. Pulling every
#: backticked word from a whole section would admit examples, aliases and
#: retired spellings into the roster. Each expression stops before the prose
#: that explains the set, so a closed set stays an exact list.
_CARRIER_ROSTER = re.compile(
    r"^\| carrier \|.*?\n\|---.*?\n(?P<body>(?:^\|.*(?:\n|$))+)",
    re.MULTILINE,
)
_OBJECT_ROSTER = re.compile(
    r"^(?P<count>[A-Za-z]+|\d+) are objects[:,]\s*(?P<body>.*?)"
    r"(?=^The |^`metta\.vocabularies\.Semiring`|^\s*$)",
    re.MULTILINE | re.DOTALL,
)
_SEMIRING_ROSTER = re.compile(
    r"^`metta\.vocabularies\.Semiring` names the closed set:\s*"
    r"(?P<body>.*?)(?=^\s*$)",
    re.MULTILINE | re.DOTALL,
)
_ALGEBRA_LAW_ROSTER = re.compile(
    r"^`metta\.vocabularies\.AlgebraLaw` names the accepted set:\s*"
    r"(?P<body>.*?)(?=^\s*$)",
    re.MULTILINE | re.DOTALL,
)
#: The alias table is a two-column roster, so each row is flattened to one
#: `alias=target` string and the whole table compared as a set of those. A row
#: naming one value is a row that lost its expansion, and reads as a difference.
_LAW_ALIAS_ROSTER = re.compile(
    r"^\| algebra-law alias \| expands to \|\n\|---.*?\n"
    r"(?P<body>(?:^\|.*(?:\n|$))+)",
    re.MULTILINE,
)
#: Both of these end at the roster SENTENCE rather than at a particular
#: following clause, so two sheets may introduce the same closed set in their
#: own words. Only backticked values are read out of the body, so prose that
#: names no value cannot join the roster.
_EFFECT_ROSTER = re.compile(
    r"^The ordered `EffectClass` members are:?\s*(?P<body>.*?)(?=\.\s|\.$)",
    re.MULTILINE | re.DOTALL,
)
_CAPABILITY_ROSTER = re.compile(
    r"^Capabilities are declared, not guessed:\s*(?P<body>.*?)(?=\.\s|\.$)",
    re.MULTILINE | re.DOTALL,
)

#: Each count is anchored to the table row that makes the claim. A missing
#: match is itself a finding, so deleting the number cannot disable its check.
#: Word forms are included because the prose uses them for several small
#: counts; treating only decimal digits as claims was the original blind spot.
_COUNT_CLAIMS = (
    (
        "Prolog library halves",
        re.compile(r"\| `lib/lib_\*/` \|[^\n]*?all (?P<count>\d+) shipped Prolog halves"),
        "prolog_library_halves",
    ),
    (
        "executable example programs",
        re.compile(r"\| `examples/\*\*/\*\.metta` \| (?P<count>\d+) executable programs"),
        "example_programs",
    ),
    (
        "example chapters",
        re.compile(
            r"\| `examples/\*\*/\*\.metta` \|[^\n]*? in (?P<count>\d+) "
            r"(?:numbered )?chapters"
        ),
        "example_chapters",
    ),
    (
        "highest example chapter number",
        re.compile(r"\| `examples/\*\*/\*\.metta` \|[^\n]*? numbered to (?P<count>\d+)"),
        "highest_example_chapter",
    ),
    (
        "skipped examples",
        re.compile(
            r"\| `examples/\*\*/\*\.metta` \|[^\n]*? names the (?P<count>[a-z]+|\d+) that do not"
        ),
        "skipped_examples",
    ),
    (
        "generated reference pages",
        re.compile(r"\| `website/reference/metta-\*\.md` \| (?P<count>\d+) pages"),
        "reference_pages",
    ),
    (
        "Python test chapters",
        re.compile(
            r"\| `extensions/python/tests/\*/test_\*\.py` \|[^\n]*? same (?P<count>\d+) chapters"
        ),
        "python_test_chapters",
    ),
    (
        "guide pages",
        re.compile(r"\| `website/guide/\*\.md` \| (?P<count>\d+) pages"),
        "guide_pages",
    ),
    (
        "tutorial pages",
        re.compile(r"\| `website/tutorials/\*\.md` \| (?P<count>\d+) numbered lessons"),
        "tutorial_pages",
    ),
    (
        "gallery programs",
        re.compile(
            r"\| `extensions/python/examples/\*/\*\.py` \|[^\n]*? the (?P<count>[a-z]+|\d+) under `gallery/`"
        ),
        "gallery_programs",
    ),
    (
        "engine metta units",
        re.compile(
            r"\| `engine/\*\*/\*\.pl` \|[^\n]*? the "
            r"(?P<count>[a-z]+|\d+) `engine/metta/\*\.pl` units"
        ),
        "metta_units",
    ),
    (
        "engine translator units",
        re.compile(
            r"\| `engine/\*\*/\*\.pl` \|[^\n]*? the "
            r"(?P<count>[a-z]+|\d+) `engine/translator/\*\.pl` units"
        ),
        "translator_units",
    ),
    (
        "engine spaces units",
        re.compile(
            r"\| `engine/\*\*/\*\.pl` \|[^\n]*? the "
            r"(?P<count>[a-z]+|\d+) `engine/spaces/\*\.pl` units"
        ),
        "spaces_units",
    ),
    (
        "reader.c lines",
        re.compile(
            r"\| `engine/\*\*/\*\.pl` \|[^\n]*?`engine/reader\.c`, "
            r"(?P<count>[\d,]+) lines"
        ),
        "reader_lines",
    ),
    (
        "json_codec.c lines",
        re.compile(
            r"\| `engine/\*\*/\*\.pl` \|[^\n]*?`engine/json_codec\.c`, "
            r"(?P<count>[\d,]+) lines"
        ),
        "json_codec_lines",
    ),
    (
        "extension-point kinds",
        re.compile(
            r"\| `engine/ext_points\.pl` \|[^\n]*? (?P<count>[A-Za-z]+|\d+) "
            r"of them, and the count of each"
        ),
        "extension_point_kinds",
    ),
    *(
        (
            f"{kind} extension points",
            re.compile(
                rf"\| `engine/ext_points\.pl` \|[^\n]*?`{kind}` "
                rf"(?P<count>\d+)"
            ),
            f"extension_points_{kind}",
        )
        for kind in ("host_service", "service", "ownership", "event", "declaration")
    ),
)

#: A clause head defined by a shipped library. The engine vocabulary answers
#: only the engine's own names, so all 24 libraries' surface, 289 heads, was
#: outside every check until this existed: a sheet could name a library head
#: that does not exist and nothing would say so.
_LIBRARY_HEAD = re.compile(r"^\(=\s*\(([^\s()]+)", re.MULTILINE)
#: A backticked token shaped like a call head. Paths, prose and signatures are
#: excluded by the characters they contain rather than by a list to maintain.
_HEAD_SHAPED = re.compile(r"`([^`\n]+)`")

#: The operator-word claim, which sits OUTSIDE the sources table. That is the
#: class COUNTS was blind to: a number in prose has no row to anchor it and
#: nothing derives it, so `S`'s thirteen mapping words plus the one that
#: refuses were written as thirteen and went unread for as long as the claim
#: existed. The roster is checked as well as the count, because swapping one
#: word for another keeps the count right and the table wrong.
_OPERATOR_CLAIM = re.compile(
    r"(?P<count>[A-Za-z]+) ATTRIBUTE NAMES ON `S` ARE OPERATOR WORDS"
)
#: One table cell naming an operator word. Pipes on both sides keep prose
#: mentions of `S.floordiv` and `S.sub(a, b)` out of the roster.
_OPERATOR_ROW = re.compile(r"\|\s*`S\.(?P<word>\w+)`\s*\|")

_NUMBER_WORDS = {
    "zero": 0,
    "one": 1,
    "two": 2,
    "three": 3,
    "four": 4,
    "five": 5,
    "six": 6,
    "seven": 7,
    "eight": 8,
    "nine": 9,
    "ten": 10,
    "eleven": 11,
    "twelve": 12,
    "thirteen": 13,
    "fourteen": 14,
    "fifteen": 15,
    "sixteen": 16,
    "seventeen": 17,
    "eighteen": 18,
    "nineteen": 19,
    "twenty": 20,
}

#: Receiver names used by the Python examples. The same spelling can denote a
#: different class in each sheet, so the class is selected before a method is
#: checked. ``self`` is the one supported property hop because the Python
#: extension sheet teaches context.self methods directly.
_RECEIVERS = frozenset({"m", "context", "ctx", "kb", "space", "store", "metta"})
_METHOD = re.compile(
    r"\b(?P<receiver>" + "|".join(sorted(_RECEIVERS)) + r")\.(?:(?P<via>self)\.)?(?P<method>\w+)"
)
_ROOT_SHEET = REPO / "llms.txt"
_PYTHON_SHEET = REPO / "extensions/python/llms.txt"
_PYTHON_DOCUMENTS = frozenset({_ROOT_SHEET, _PYTHON_SHEET})


def _python_blocks(sheet: Path, text: str) -> str:
    """Return Python examples with every other source line blanked.

    Explicit ``python`` fences always qualify. In the two Python documents, an
    unlabelled fence qualifies when it contains a recognized receiver call.
    That admits compact signature tables while leaving MeTTa source blocks
    alone. Blanking preserves each finding's source line.
    """
    lines = text.splitlines()
    kept = [""] * len(lines)
    inside = False
    language = ""
    body_start = 0

    def retain(body_end: int) -> None:
        body = lines[body_start:body_end]
        inferred = (
            language == ""
            and sheet in _PYTHON_DOCUMENTS
            and any(_METHOD.search(line) for line in body)
        )
        if language == "python" or inferred:
            kept[body_start:body_end] = body

    for index, line in enumerate(lines):
        if not line.startswith("```"):
            continue
        if not inside:
            inside = True
            language = line.removeprefix("```").strip()
            body_start = index + 1
            continue
        retain(index)
        inside = False
        language = ""
    if inside:
        retain(len(lines))
    return "\n".join(kept)


def _receivers(sheet: Path) -> tuple[dict[str, tuple[object, str]], list[str]]:
    """The documented receiver names bound to the live classes they stand for.

    The second element carries the import failure and is empty when the
    package loaded. The bindings read classes rather than instances, so they
    cost one import and never boot an engine. The root sheet binds ``m`` to
    ``Space``; the Python extension sheet binds it to ``MeTTa``. Named spaces
    always use ``Space``.
    """
    python_path = str(REPO / "extensions" / "python")
    if python_path not in sys.path:
        sys.path.insert(0, python_path)
    try:
        # Imported here, not at the top, so the lane costs nothing until it runs.
        import metta as package
    except ImportError as absent:
        # The package is IN THIS TREE, so failing to import it is a finding
        # rather than a skip: returning "nothing to check" would take this
        # half green on exactly the tree where the doors moved.
        return {}, [
            f"{sheet.relative_to(REPO)}: the metta package under "
            f"extensions/python did not import, so no method was checked: {absent}"
        ]

    m_class = package.Space if sheet == _ROOT_SHEET else package.MeTTa
    return {
        "m": (m_class, m_class.__name__),
        "context": (package.MeTTa, "MeTTa"),
        "ctx": (package.MeTTa, "MeTTa"),
        "kb": (package.Space, "Space"),
        "space": (package.Space, "Space"),
        "store": (package.Space, "Space"),
        "metta": (package, "the metta package"),
    }, []


#: A DOTTED PACKAGE PATH: `metta.` followed by two or more segments.
#: method_findings above reads ONE segment off the live package and stops, so
#: `metta._errors.errors.Remedy` passed on `_errors` alone and the last two
#: segments were resolved by nothing [measured 2026-09-20: planting
#: `metta._nonexistent.module.NoSuchThing(` in llms.txt left the lane at exit 0
#: with 0 findings, and the sheets spell twelve such paths across _errors,
#: _atoms, _spaces, _declare and _binding].
#:
#: Walking deeper is safe HERE and nowhere else in these sheets: the package is
#: a module tree whose attributes are modules and classes, so it resolves
#: statically, while a receiver chain like `m.space.atoms` runs through the
#: instances this lane deliberately never builds. That is also why the walk
#: reads prose rather than only Python blocks: a private path is named where the
#: shape is explained, not in an example.
#:
#: Anchored on the OPENING backtick and reading the path itself rather than the
#: whole span, because a span can cross a line break and the span pattern
#: path_findings uses is line-bounded on purpose, so an unclosed backtick cannot
#: swallow the file. `metta._errors.errors.Remedy(title, kind, applicability,
#: edit=,` wraps mid-argument-list and was invisible to the span reading; a
#: dotted path holds no whitespace, so the name alone is a safe anchor
#: [measured 2026-09-20: the span form caught one planted path of two].
@cache
def _dotted_pattern(root: str) -> re.Pattern[str]:
    """Backticked paths into ROOT that go deeper than the one segment above."""
    return re.compile(rf"`({re.escape(root)}(?:\.\w+){{2,}})")


def _unreachable(package: object, segments: list[str]) -> str | None:
    """The first segment of a dotted path that is ABSENT, or None if it resolves.

    A ModuleNotFoundError naming the very path asked for is absence. Any other
    import failure means the module IS there and broke while loading, which is a
    different fact about a different file: reporting it as a stale documentation
    claim would send a reader to edit the sheet over a broken module. It
    propagates and becomes its own finding instead.
    """
    # Imported here, not at the top, for the reason _receivers gives: the lane
    # costs nothing until it runs.
    import importlib

    here = package
    walked = getattr(package, "__name__", "metta")
    for segment in segments:
        step = getattr(here, segment, None)
        if step is None:
            path = f"{walked}.{segment}"
            try:
                step = importlib.import_module(path)
            except ModuleNotFoundError as absent:
                if absent.name == path:
                    return path
                raise
        here = step
        walked = f"{walked}.{segment}"
    return None


def dotted_findings(sheet: Path, text: str, package: object | None = None) -> list[str]:
    """Every dotted package path a sheet spells that no longer resolves.

    `package` is the root to resolve against and defaults to the live metta
    package. It is a parameter so a caller can inject a planted one: the
    selftest needs a module that raises while importing, and writing that into
    the shipped tree would pollute it and race a parallel run. The pattern
    derives its root from whatever package it is handed, so nothing here spells
    the name twice.
    """
    if package is None:
        if sheet not in _PYTHON_DOCUMENTS:
            return []
        receivers, failure = _receivers(sheet)
        if failure:
            return failure
        package, _label = receivers["metta"]
    findings: list[str] = []
    for match in _dotted_pattern(getattr(package, "__name__", "metta")).finditer(text):
        token = match.group(1)
        try:
            missing = _unreachable(package, token.split(".")[1:])
        except ImportError as broken:
            findings.append(
                f"{sheet.relative_to(REPO)}:{_line_of(text, match.start())}: "
                f"`{token}` could not be resolved: importing it raised {broken!r}"
            )
            continue
        if missing is not None:
            findings.append(
                f"{sheet.relative_to(REPO)}:{_line_of(text, match.start())}: "
                f"`{token}` names nothing: the package has no `{missing}`"
            )
    return findings


def method_findings(sheet: Path, text: str) -> list[str]:
    """Every taught Python method absent from its documented receiver."""
    receivers, failure = _receivers(sheet)
    if failure:
        return failure
    findings: list[str] = []
    # Only Python blocks teach Python calls. Prose can deny that a name exists,
    # and another language can correctly expose a different method set.
    code = _python_blocks(sheet, text)
    for match in _METHOD.finditer(code):
        receiver = match.group("receiver")
        via = match.group("via")
        method = match.group("method")
        target, label = receivers[receiver]
        whole = match.group(0)
        if via is not None:
            if via not in dir(target):
                findings.append(
                    f"{sheet.relative_to(REPO)}:{_line_of(code, match.start())}: "
                    f"teaches `{whole}`, but {label} has no `{via}` property"
                )
                continue
            target, label = receivers["kb"]
        if method in dir(target):
            continue
        findings.append(
            f"{sheet.relative_to(REPO)}:{_line_of(code, match.start())}: teaches "
            f"`{whole}`, but {label} has no `{method}` method"
        )
    return findings


#: A DOCUMENTED SIGNATURE: a receiver call carrying a return annotation. The
#: `->` is what makes this safe to read as a declaration. A signature line has
#: one and a call example never does, which keeps the check off the twenty-odd
#: `kw=value` lines in these sheets that PASS a value rather than state a
#: default.
#:
#: Checking those defaults was tried and abandoned. `m.trace`'s live default is
#: None, with the real 10,000 bound resolved in the body, so it is textually
#: identical to `m.limits(inferences=10_000)` passing a value: no rule
#: separates the one stale line from five correct ones [measured 2026-09-04,
#: 28 documented keyword arguments across the five sheets, 23 of them
#: call-example values]. pydoclint reaches the same split, checking return
#: types as DOC203 while documenting that it will not read argument defaults
#: [source: https://jsh9.github.io/pydoclint/violation_codes.html].
_RETURN = re.compile(
    r"\b(?P<receiver>" + "|".join(sorted(_RECEIVERS)) + r")\.(?:(?P<via>self)\.)?"
    r"(?P<method>\w+)\((?P<args>[^()]*(?:\([^()]*\)[^()]*)*)\)\s*->\s*(?P<returns>[^\n#]+)"
)


def _head_type(written: str) -> str:
    """The head name of a written type expression, prose tail removed.

    Both sides of the comparison are TEXT. `from __future__ import annotations`
    leaves a live annotation as its source string rather than an object, which
    is why nothing here evaluates one.

    The head is compared instead of the whole string because these sheets
    decorate a type four ways that are not disagreements: prose after it
    (`int   (atomic, fsynced)`), a module qualifier (`_ops_module.EffectPlan`),
    a parameter the sheet omits (`Answers` for a live `Answers[Any]`), and a
    positional tuple (`(groups, EngineProfile)` for `tuple[...]`). Comparing
    whole strings reported all four. The head survives them and is the part
    carrying the promise: `list` where the live type is `Trace` tells a reader
    the result is an ordinary list, which is the claim that hid
    `Trace.truncated` through two releases.
    """
    text = written.strip()
    depth = 0
    for index, character in enumerate(text):
        if character in "([{":
            depth += 1
        elif character in ")]}":
            depth -= 1
        elif depth == 0 and (character in ",;" or text[index : index + 2] == "  "):
            text = text[:index]
            break
    text = text.strip()
    if text.startswith("("):
        return "tuple"
    head = re.match(r"[A-Za-z_][\w.]*", text)
    # A module qualifier says where the type lives, not which type it is.
    return text if head is None else head.group(0).rsplit(".", 1)[-1]


def return_findings(sheet: Path, text: str) -> list[str]:
    """Every documented return type the live annotation contradicts.

    A live signature that says nothing is skipped rather than guessed at: an
    unannotated method and a bare `Any` have no claim to disagree with. A sheet
    is also allowed to be MORE precise than the annotation, so `list[Derivation]`
    against a live `list[Any]` agree on `list`, which is all this asks.
    """
    receivers, failure = _receivers(sheet)
    if failure:
        # method_findings reports the import failure; saying it twice per sheet
        # would only make one fact look like two.
        return []
    findings: list[str] = []
    code = _python_blocks(sheet, text)
    for match in _RETURN.finditer(code):
        target, label = receivers[match.group("receiver")]
        if match.group("via") is not None:
            target, label = receivers["kb"]
        name = match.group("method")
        door = getattr(target, name, None)
        if door is None:
            continue  # method_findings owns the name half of this promise.
        try:
            live = inspect.signature(door).return_annotation
        except (TypeError, ValueError):
            continue
        if live is inspect.Signature.empty:
            continue
        live_head = _head_type(
            live if isinstance(live, str) else getattr(live, "__name__", str(live))
        )
        if live_head in {"Any", "object"}:
            continue
        documented = _head_type(match.group("returns"))
        if documented == live_head:
            continue
        findings.append(
            f"{sheet.relative_to(REPO)}:{_line_of(code, match.start())}: teaches "
            f"`{match.group('receiver')}.{name}(...) -> {documented}`, but "
            f"{label}.{name} answers {live_head}"
        )
    return findings


#: The language-surface block: one fenced run of bare head names.
_SURFACE_BLOCK = re.compile(
    r"## The MeTTa language surface.*?```\n(?P<body>.*?)```",
    re.DOTALL,
)


def sheets() -> list[Path]:
    """Every llms.txt the tree ships, the root's first."""
    root = REPO / "llms.txt"
    extensions = sorted((REPO / "extensions").glob("*/llms.txt"))
    return [path for path in (root, *extensions) if path.is_file()]


def _line_of(text: str, index: int) -> int:
    return text.count("\n", 0, index) + 1


def _line_count(path: Path) -> int:
    with path.open(encoding="utf-8") as source:
        return sum(1 for _line in source)


def source_counts(root: Path = REPO) -> dict[str, int]:
    """Derive every explicit count in the root sheet's sources table."""
    chapters = sorted(path for path in (root / "examples").glob("ch[0-9][0-9]-*") if path.is_dir())
    examples = [
        path
        for path in (root / "examples").rglob("*.metta")
        if not path.is_symlink() and "_fixtures" not in path.parts
    ]
    skipped = [
        line
        for line in (root / "tests/data/example_skips.txt").read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
    test_chapters = [
        path for path in (root / "extensions/python/tests").glob("ch[0-9][0-9]_*") if path.is_dir()
    ]
    # `kind/2` is the source of truth and its few out-of-module clauses are
    # written as `seam:kind/2`. Anchoring to clause heads excludes prose and
    # tests while still following a seam moved to another engine unit.
    extension_kinds: dict[str, int] = {}
    kind_clause = re.compile(r"^(?:seam:)?kind\([^,\n]+,\s*(?P<kind>[a-z_]+)\)\.", re.MULTILINE)
    for path in (root / "engine").rglob("*.pl"):
        for match in kind_clause.finditer(path.read_text(encoding="utf-8")):
            kind = match.group("kind")
            extension_kinds[kind] = extension_kinds.get(kind, 0) + 1
    counts = {
        "prolog_library_halves": len(list((root / "lib").glob("*/*.pl"))),
        "example_programs": len(examples),
        "example_chapters": len(chapters),
        "highest_example_chapter": max(int(path.name[2:4]) for path in chapters),
        "skipped_examples": len(skipped),
        "reference_pages": len(list((root / "website/reference").glob("metta-*.md"))),
        "python_test_chapters": len(test_chapters),
        "guide_pages": len(list((root / "website/guide").glob("*.md"))),
        "tutorial_pages": len(list((root / "website/tutorials").glob("*.md"))),
        "gallery_programs": len(list((root / "extensions/python/examples/gallery").glob("*.py"))),
        "metta_units": len(list((root / "engine/metta").glob("*.pl"))),
        "translator_units": len(list((root / "engine/translator").glob("*.pl"))),
        "spaces_units": len(list((root / "engine/spaces").glob("*.pl"))),
        "reader_lines": _line_count(root / "engine/reader.c"),
        "json_codec_lines": _line_count(root / "engine/json_codec.c"),
        "extension_point_kinds": len(extension_kinds),
    }
    counts.update({f"extension_points_{kind}": count for kind, count in extension_kinds.items()})
    return counts


def _number(written: str) -> int:
    normalized = written.replace(",", "").lower()
    if normalized.isdecimal():
        return int(normalized)
    return _NUMBER_WORDS[normalized]


def refresh_source_claims(text: str, root: Path = REPO) -> str:
    """Refresh derived numbers and the library roster, retaining authored notes.

    The checker remains the authority for which prose makes a count claim.
    Missing claim anchors refuse regeneration rather than discarding prose
    [tested: tests/checks/check_llms_selftest.py; commit=9b22993447a5ddba93643895e3025661ba9f693e].
    """
    counts = source_counts(root)
    shipped = sorted(path.name for path in (root / "lib").glob("lib_*") if path.is_dir())
    changes = []
    for label, pattern, key in _COUNT_CLAIMS:
        match = pattern.search(text)
        if match is None:
            message = f"missing source-table count: {label}"
            raise ValueError(message)
        if _number(match.group("count")) != counts[key]:
            changes.append((*match.span("count"), str(counts[key])))
    changes.extend((*match.span("count"), str(len(shipped))) for match in _TABLE_COUNT.finditer(text))
    for start, end, value in sorted(changes, reverse=True):
        text = text[:start] + value + text[end:]
    roster = _ROSTER.search(text)
    if roster is None:
        message = "missing library roster; restore its authored context before regeneration"
        raise ValueError(message)
    names = ", ".join(f"`{name}`" for name in shipped)
    body = (f"{len(shipped)} libraries load with `!(import! &self (library lib_x))`:\n"
            f"{names}. Scored answers and every documented head are listed in\n"
            "`website/reference/metta-libraries.md`.\n")
    generated = ROSTER_BEGIN + "\n" + body + ROSTER_END
    if ROSTER_BEGIN in text or ROSTER_END in text:
        begin, end = text.find(ROSTER_BEGIN), text.find(ROSTER_END)
        if text.count(ROSTER_BEGIN) != 1 or text.count(ROSTER_END) != 1 or begin >= end:
            message = "missing, reversed or repeated generated library roster markers"
            raise ValueError(message)
        return text[:begin] + generated + text[end + len(ROSTER_END):]
    # Preserve the former roster's descriptive contracts as authored prose.
    # The short roster above is the only membership claim after this migration.
    notes = "Library contracts: " + roster.group("names").strip() + ". Scored"
    return text[:roster.start()] + generated + "\n\n" + notes + text[roster.end():]


def count_findings(
    sheet: Path,
    text: str,
    counts: Mapping[str, int] | None = None,
) -> list[str]:
    """Every source-table count against the source named by its row."""
    if sheet != _ROOT_SHEET:
        return []
    expected = source_counts() if counts is None else counts
    findings: list[str] = []
    for label, pattern, key in _COUNT_CLAIMS:
        match = pattern.search(text)
        if match is None:
            findings.append(
                f"{sheet.relative_to(REPO)}: the sources table no longer states "
                f"its {label} count, so that count goes unchecked"
            )
            continue
        stated = _number(match.group("count"))
        observed = expected[key]
        if stated != observed:
            findings.append(
                f"{sheet.relative_to(REPO)}:{_line_of(text, match.start())}: "
                f"the sources table says {stated} {label}, the tree has {observed}"
            )
    return findings


def library_vocabulary(root: Path = REPO) -> dict[str, str]:
    """Every clause head a shipped library defines, mapped to its library."""
    heads: dict[str, str] = {}
    for path in sorted((root / "lib").glob("lib_*/*.metta")):
        for match in _LIBRARY_HEAD.finditer(path.read_text(encoding="utf-8")):
            heads.setdefault(match.group(1), path.parent.name)
    return heads


def _head_shaped(text: str) -> set[str]:
    """Backticked tokens that could name a call head."""
    found: set[str] = set()
    for match in _HEAD_SHAPED.finditer(text):
        token = match.group(1).strip()
        if any(character in token for character in " /.(="):
            continue
        if "-" in token or token.endswith("!"):
            found.add(token)
    return found


def near_miss_findings(
    sheet: Path,
    text: str,
    known: set[str] | None = None,
) -> list[str]:
    """A documented head the engine does not know but nearly does.

    Asking whether every head-shaped token is known would be useless: 47 of the
    root sheet's 195 are carrier names, type names and vocabulary words that
    are not heads at all, and no list of those stays current. The NEAR MISS is
    the precise question. A token that is unknown while its bang variant IS
    known is a typo, because the bang is the engine's own side-effect suffix
    and `resolve_known_name` climbs exactly that ladder. Nothing else in the
    tree is shaped like that: the live sheets produce zero of these, and
    writing `ws-sample` for `ws-sample!` produces one.
    """
    vocabulary = set(library_vocabulary())
    if known:
        vocabulary |= known
    findings: list[str] = []
    for token in sorted(_head_shaped(text)):
        if token in vocabulary:
            continue
        for variant in (f"{token}!", token.rstrip("!")):
            if variant == token or variant not in vocabulary:
                continue
            index = text.find(f"`{token}`")
            findings.append(
                f"{sheet.relative_to(REPO)}:{_line_of(text, index)}: "
                f"`{token}` names nothing; the engine knows `{variant}`"
            )
            break
    return findings


def operator_words() -> dict[str, str]:
    """Every `S` attribute the mechanical name map does not explain.

    This is the sheet's own sentence made executable. An operator word is one
    where `S.<word>` is not the symbol `attribute_name(word)` would name, which
    is exactly what "reaches the engine head the word NAMES rather than a
    symbol spelled like the word" says. Deriving it that way excludes
    `S.and_` -> `and` and `S.is_none` -> `is-none` on their own, because the
    keyword escape and the underscore map already account for them, so no
    hand-kept exclusion list exists to fall out of date. Reading the live
    attribute rather than `OPERATOR_WORDS` also keeps the check honest about
    the refusal, which is a fourteenth word with no row in that table.
    """
    python_path = str(REPO / "extensions" / "python")
    if python_path not in sys.path:
        sys.path.insert(0, python_path)
    # Imported here, not at the top, so the lane costs nothing until it runs.
    import operator

    from metta import S
    from metta._atoms.names import attribute_name

    words: dict[str, str] = {}
    for name in sorted(name for name in dir(operator) if not name.startswith("_")):
        try:
            reached = str(getattr(S, name))
        except AttributeError:
            # A refusal is still an operator word: the attribute declines to
            # answer the symbol its own spelling names.
            words[name] = "refused"
            continue
        if reached != attribute_name(name):
            words[name] = reached
    return words


def operator_word_findings(sheet: Path, text: str) -> list[str]:
    """The operator-word count and roster against the live `S`."""
    if sheet != _ROOT_SHEET:
        return []
    match = _OPERATOR_CLAIM.search(text)
    if match is None:
        return [
            f"{sheet.relative_to(REPO)}: the operator-word claim is gone, so "
            "the `S` attributes that are not spellings go unchecked"
        ]
    try:
        live = operator_words()
    except ImportError as absent:
        # The package is in this tree, so a failed import is a finding rather
        # than a skip, the same way the receiver check treats it.
        return [
            f"{sheet.relative_to(REPO)}: the metta package under "
            f"extensions/python did not import, so the operator words went "
            f"unchecked: {absent}"
        ]
    line = _line_of(text, match.start())
    where = f"{sheet.relative_to(REPO)}:{line}"
    findings: list[str] = []
    stated = _number(match.group("count"))
    if stated != len(live):
        findings.append(
            f"{where}: the sheet says {stated} operator words on `S`, the "
            f"package has {len(live)}"
        )
    tabled = {row.group("word") for row in _OPERATOR_ROW.finditer(text)}
    findings.extend(
        f"{where}: `S.{word}` reaches {live[word]} and the table omits it"
        for word in sorted(set(live) - tabled)
    )
    findings.extend(
        f"{where}: the table names `S.{word}`, which is its own spelling "
        "rather than an operator word"
        for word in sorted(tabled - set(live))
    )
    return findings


def path_findings(sheet: Path, text: str) -> list[str]:
    """Every backticked path claim that no longer resolves."""
    findings: list[str] = []
    for match in re.finditer(r"`([^`\n]+)`", text):
        token = match.group(1).strip()
        if "://" in token or " " in token or not _is_path_claim(token):
            continue
        if not _resolves(sheet, token):
            findings.append(
                f"{sheet.relative_to(REPO)}:{_line_of(text, match.start())}: "
                f"`{token}` names nothing in the tree"
            )
    return findings


def library_findings(sheet: Path, text: str) -> list[str]:
    """The roster's names and both statements of its count, against `lib/`."""
    findings: list[str] = []
    shipped = {path.name for path in sorted((REPO / "lib").glob("lib_*")) if path.is_dir()}
    roster = _ROSTER.search(text)
    if roster is None and sheet == REPO / "llms.txt":
        # Absence is a finding for the sheet that HAS a roster and a skip for
        # the seat sheets that never did. Reading "no match" as "nothing to
        # check" everywhere would let the roster be deleted or reshaped into
        # a green lane, the fail-open shape this file exists to refuse. The
        # count half below still runs either way, because the two claims can
        # go stale independently.
        findings.append(
            f"{sheet.relative_to(REPO)}: the library roster is gone or no "
            f"longer reads as `N libraries load with ...: `lib_x`, ... . Scored`, "
            f"so its {len(shipped)} names go unchecked"
        )
    if roster is not None:
        named = set(re.findall(r"`(lib_\w+)`", roster.group("names")))
        line = _line_of(text, roster.start())
        findings.extend(
            f"{sheet.relative_to(REPO)}:{line}: the roster omits `{missing}`, which lib/ ships"
            for missing in sorted(shipped - named)
        )
        findings.extend(
            f"{sheet.relative_to(REPO)}:{line}: the roster names `{absent}`, "
            f"which lib/ does not ship"
            for absent in sorted(named - shipped)
        )
        stated = int(roster.group("count"))
        if stated != len(shipped):
            findings.append(
                f"{sheet.relative_to(REPO)}:{line}: the roster says {stated} "
                f"libraries, lib/ ships {len(shipped)}"
            )
    for match in _TABLE_COUNT.finditer(text):
        stated = int(match.group("count"))
        if stated != len(shipped):
            findings.append(
                f"{sheet.relative_to(REPO)}:{_line_of(text, match.start())}: the "
                f"sources table says {stated} libraries, lib/ ships {len(shipped)}"
            )
    return findings


def _inline_values(body: str) -> tuple[str, ...]:
    """The unqualified values in a labelled backtick roster."""
    return tuple(re.findall(r"`([A-Za-z][A-Za-z0-9-]*)`", body))


def _object_values(body: str) -> tuple[str, ...]:
    """Normalize `metta.name` and the documented `.name` shorthand."""
    values: list[str] = []
    for token in re.findall(r"`([^`]+)`", body):
        if token.startswith("metta."):
            values.append(token.removeprefix("metta."))
        elif token.startswith("."):
            values.append(token.removeprefix("."))
    return tuple(values)


def _roster_difference(
    sheet: Path,
    text: str,
    label: str,
    match: re.Match[str] | None,
    *,
    actual: tuple[str, ...],
    expected: tuple[str, ...],
    ordered: bool = False,
    opening: str = "",
    required: bool = True,
) -> list[str]:
    """Describe one exact roster disagreement in a stable, copyable form.

    A roster that is absent and one that disagrees are different edits, so
    they read differently: the absent one names the sentence the sheet has to
    carry, because "found no explicit values" alone sends the reader looking
    for a list that is not there.

    ``required`` is the fail-closed half. The root sheet promises the whole
    surface, so a roster deleted from it is a finding and the check cannot be
    silenced by removing the sentence. A seat sheet documents its own seat and
    is free not to cover a set; what it DOES state still has to be exact. This
    is the split ``library_findings`` already makes.
    """
    where = str(sheet.relative_to(REPO))
    if match is not None:
        where += f":{_line_of(text, match.start())}"
    if match is None and not required:
        return []
    wanted = ", ".join(f"`{value}`" for value in expected)
    duplicates = len(actual) != len(set(actual))
    same_values = len(actual) == len(expected) and set(actual) == set(expected)
    if same_values and not duplicates and (not ordered or actual == expected):
        return []
    qualifier = " in that order" if ordered else ""
    if match is None:
        return [
            f"{where}: the {label} roster is missing; this sheet must carry a "
            f"line beginning {opening!r} that names exactly "
            f"{wanted}{qualifier}"
        ]
    found = ", ".join(f"`{value}`" for value in actual) or "no explicit values"
    return [
        f"{where}: the {label} roster must be exactly {wanted}{qualifier}; found {found}"
    ]


def _alias_values(body: str) -> tuple[str, ...]:
    """Flatten the labelled alias table into stable alias=target rows."""
    rows: list[str] = []
    for line in body.splitlines():
        values = re.findall(r"`([A-Za-z][A-Za-z0-9-]*)`", line)
        if len(values) >= 2:
            rows.append("=".join(values))
    return tuple(rows)


def closed_value_source_findings(values: Mapping[str, tuple[str, ...]]) -> list[str]:
    """The algebra rows and their declared vocabulary are one closed set."""
    semirings = values["semiring"]
    presets = values["algebra-presets"]
    if presets == semirings:
        return []
    wanted = ", ".join(f"`{value}`" for value in semirings)
    found = ", ".join(f"`{value}`" for value in presets) or "no values"
    return [
        "llms: the catalog's algebra rows disagree with its semiring vocabulary: "
        f"expected {wanted}; found {found}"
    ]


def closed_value_findings(
    sheet: Path,
    text: str,
    values: Mapping[str, tuple[str, ...]],
) -> list[str]:
    """Every documented closed roster against the source that owns it."""
    if sheet not in _PYTHON_DOCUMENTS:
        return []
    findings: list[str] = []
    semirings = values["semiring"]
    if sheet == _ROOT_SHEET:
        carrier = _CARRIER_ROSTER.search(text)
        carrier_values = (
            tuple(re.findall(r"^\|\s*`([^`]+)`", carrier.group("body"), re.MULTILINE))
            if carrier is not None
            else ()
        )
        findings.extend(
            _roster_difference(
                sheet,
                text,
                "carrier",
                carrier,
                actual=carrier_values,
                expected=semirings,
                opening="| carrier |",
            )
        )

        objects = _OBJECT_ROSTER.search(text)
        object_values = _object_values(objects.group("body")) if objects is not None else ()
        findings.extend(
            _roster_difference(
                sheet,
                text,
                "module algebra object",
                objects,
                actual=object_values,
                expected=semirings,
                opening="<count> are objects:",
            )
        )
        if objects is not None and _number(objects.group("count")) != len(semirings):
            findings.append(
                f"{sheet.relative_to(REPO)}:{_line_of(text, objects.start())}: the module "
                f"algebra object roster says {_number(objects.group('count'))}, "
                f"the catalog has {len(semirings)}"
            )

    semiring = _SEMIRING_ROSTER.search(text)
    semiring_values = _inline_values(semiring.group("body")) if semiring is not None else ()
    findings.extend(
        _roster_difference(
            sheet,
            text,
            "Semiring",
            semiring,
            actual=semiring_values,
            expected=semirings,
            opening="`metta.vocabularies.Semiring` names the closed set:",
            required=sheet == _ROOT_SHEET,
        )
    )

    laws = _ALGEBRA_LAW_ROSTER.search(text)
    law_values = _inline_values(laws.group("body")) if laws is not None else ()
    findings.extend(
        _roster_difference(
            sheet,
            text,
            "AlgebraLaw",
            laws,
            actual=law_values,
            expected=values["algebra-law"],
            opening="`metta.vocabularies.AlgebraLaw` names the accepted set:",
            required=sheet == _ROOT_SHEET,
        )
    )

    aliases = _LAW_ALIAS_ROSTER.search(text)
    alias_values = _alias_values(aliases.group("body")) if aliases is not None else ()
    findings.extend(
        _roster_difference(
            sheet,
            text,
            "algebra-law alias",
            aliases,
            actual=alias_values,
            expected=values["algebra-law-aliases"],
            opening="| algebra-law alias | expands to |",
            required=sheet == _ROOT_SHEET,
        )
    )

    effects = _EFFECT_ROSTER.search(text)
    effect_values = _inline_values(effects.group("body")) if effects is not None else ()
    findings.extend(
        _roster_difference(
            sheet,
            text,
            "EffectClass",
            effects,
            actual=effect_values,
            expected=values["effect-class"],
            ordered=True,
            opening="The ordered `EffectClass` members are:",
            required=sheet == _ROOT_SHEET,
        )
    )

    capabilities = _CAPABILITY_ROSTER.search(text)
    capability_values = (
        _inline_values(capabilities.group("body")) if capabilities is not None else ()
    )
    findings.extend(
        _roster_difference(
            sheet,
            text,
            "SpaceProvider capability",
            capabilities,
            actual=capability_values,
            expected=values["provider-capabilities"],
            opening="Capabilities are declared, not guessed:",
            required=sheet == _ROOT_SHEET,
        )
    )
    return findings


class EngineUnavailableError(Exception):
    """swipl is not installed, which is a skip; anything else is a finding."""


def _query_values(disjunction: str) -> tuple[str, ...]:
    """Ask one engine process for the names a goal enumerates, in source order."""
    goal = (
        "ensure_loaded('engine/qlf_boot.pl'), ensure_loaded('engine/metta.pl'), "
        f"forall(({disjunction}), "
        "( print_message_lines(user_output, '', []), format('~w~n', [N]) ))"
    )
    try:
        finished = subprocess.run(
            bounded(["swipl", "-g", goal, "-t", "halt", "--", "extensions"]),
            cwd=REPO,
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError as absent:
        raise EngineUnavailableError from absent
    if finished.returncode != 0:
        detail = (finished.stderr or finished.stdout).strip().splitlines()
        tail = detail[-1] if detail else "no output"
        msg = f"the engine did not answer its vocabulary: {tail}"
        raise RuntimeError(msg)
    return tuple(line.strip() for line in finished.stdout.splitlines() if line.strip())


def _query_vocabulary(disjunction: str) -> set[str]:
    """Ask one engine process for the distinct names a goal enumerates."""
    return set(_query_values(disjunction))


def closed_value_catalog() -> dict[str, tuple[str, ...]]:
    """Read each closed Python-facing set from the implementation that owns it."""
    return {
        "semiring": _query_values(
            "metta_catalog_row([vocabulary,semiring|Vs]), member(N, Vs)"
        ),
        "algebra-presets": _query_values("metta_catalog_row([algebra,N|_])"),
        "algebra-law": _query_values(
            "metta_catalog_row([vocabulary,'algebra-law'|Vs]), member(N, Vs)"
        ),
        "algebra-law-aliases": _query_values(
            "metta_catalog_row([claim,'algebra-law',A,'expands-to'|Xs]), "
            "atomic_list_concat([A|Xs], '=', N)"
        ),
        "effect-class": _query_values(
            "metta_catalog_row([vocabulary,'effect-class'|Vs]), member(N, Vs)"
        ),
        # The engine's own row, like the four above it. This used to AST-parse
        # `foreign.py:CAPABILITIES` as a literal tuple; that tuple now reads
        # the catalog vocabulary, so parsing the source would only report the
        # expression that reads the row.
        "provider-capabilities": _query_values(
            "metta_catalog_row([vocabulary,'provider-capability'|Vs]), member(N, Vs)"
        ),
    }


def engine_vocabulary() -> set[str]:
    """Every head the forward documentation check accepts.

    Raises EngineUnavailableError only when swipl is not installed at all. An
    engine that RAN and failed is a finding, never a skip: returning the
    absent-toolchain answer for both would let a broken engine take this
    half of the lane quietly green, which is the fail-open shape a gate
    exists to refuse.

    BOTH questions are asked. A head has meaning through `fun/1` or through
    the translator, and asking one alone reports the other's names as unknown:
    of the special forms, `case`, `if`, `collapse`, `quote` and their kin
    answer false to `fun/1` and are still perfectly callable.
    """
    return _query_vocabulary(
        "metta_grounded_token(N) ; fun(N) "
        "; translator:metta_special_form_head(N) "
        "; translator:metta_translated_head(N)"
    )


def engine_corpus_vocabulary() -> set[str]:
    """The callable set used by the corpus-coverage audit.

    This is deliberately the ledger's measured question: `fun/1` plus
    `metta_translated_head/1`. Special forms are already enumerated by the
    forward language-surface block, while the reverse check guards ordinary
    engine heads that the corpus proves are live.
    """
    return _query_vocabulary("fun(N) ; translator:metta_translated_head(N)")


def head_findings(sheet: Path, text: str, known: set[str]) -> list[str]:
    """Every language-surface name the engine does not answer to."""
    block = _SURFACE_BLOCK.search(text)
    if block is None:
        # The third fail-open of the same shape: a heading renamed or a fence
        # dropped would take this half green. It is a finding for the sheet
        # that HAS the section and a skip for the seats that never did.
        if sheet == REPO / "llms.txt":
            return [
                f"{sheet.relative_to(REPO)}: the language-surface block is gone "
                f"or no longer reads as a fenced run under "
                f"'## The MeTTa language surface', so its names go unchecked"
            ]
        return []
    line = _line_of(text, block.start("body"))
    return [
        f"{sheet.relative_to(REPO)}:{line}: the language-surface block names "
        f"`{name}`, which the engine does not know"
        for name in sorted(set(block.group("body").split()) - known)
    ]


#: This deliberately matches the audit that produced the 64-name repair. It
#: asks only about written call heads, not data and declaration positions, and
#: removes full-line comments before scanning. The live engine intersection
#: below separates callable vocabulary from user-defined heads.
_CALL_HEAD = re.compile(r"\(([a-zA-Z][a-zA-Z0-9_?!*<>=/+\-]*)[\s)]")
_HEAD_CHARACTER = r"a-zA-Z0-9_?!*<>=/+#.\-:"


def corpus_head_uses(root: Path = REPO) -> dict[str, int]:
    """Count written call heads in every shipped MeTTa example."""
    used: dict[str, int] = {}
    for path in sorted((root / "examples").rglob("*.metta")):
        if path.is_symlink() or "_fixtures" in path.parts:
            continue
        body = "\n".join(
            line
            for line in path.read_text(encoding="utf-8").splitlines()
            if not line.lstrip().startswith(";")
        )
        for match in _CALL_HEAD.finditer(body):
            name = match.group(1)
            used[name] = used.get(name, 0) + 1
    return used


def _mentions_head(text: str, name: str) -> bool:
    return (
        re.search(
            rf"(?<![{_HEAD_CHARACTER}]){re.escape(name)}(?![{_HEAD_CHARACTER}])",
            text,
        )
        is not None
    )


def omitted_head_findings(
    sheet: Path,
    text: str,
    known: set[str],
    used: Mapping[str, int] | None = None,
) -> list[str]:
    """Every corpus-used engine head that the root sheet fails to name."""
    if sheet != _ROOT_SHEET:
        return []
    calls = corpus_head_uses() if used is None else used
    return [
        f"{sheet.relative_to(REPO)}: the corpus calls engine head `{name}` "
        f"{calls[name]} time(s), but the sheet never names it"
        for name in sorted(set(calls) & known)
        if not _mentions_head(text, name)
    ]


def main(argv: list[str] | None = None) -> int:
    """Report every stale claim, or say what was checked."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--write", action="store_true", help="regenerate source counts and the library roster")
    arguments = parser.parse_args(argv)
    if arguments.write:
        try:
            current = _ROOT_SHEET.read_text(encoding="utf-8")
            wanted = refresh_source_claims(current)
            if wanted != current:
                _ROOT_SHEET.write_text(wanted, encoding="utf-8")
        except (OSError, ValueError) as error:
            print(f"llms: {error}", file=sys.stderr)
            return 1
    findings: list[str] = []
    known: set[str] | None
    corpus_known: set[str] | None
    try:
        known = engine_vocabulary()
        corpus_known = engine_corpus_vocabulary()
    except EngineUnavailableError:
        known = None
        corpus_known = None
    except RuntimeError as broken:
        known = None
        corpus_known = None
        findings.append(f"llms: {broken}")
    closed_values: dict[str, tuple[str, ...]] | None
    try:
        closed_values = closed_value_catalog()
    except EngineUnavailableError:
        closed_values = None
    except (RuntimeError, SyntaxError, ValueError) as broken:
        closed_values = None
        findings.append(f"llms: {broken}")
    if closed_values is not None:
        findings.extend(closed_value_source_findings(closed_values))
    used = corpus_head_uses() if known is not None else {}
    for sheet in sheets():
        text = sheet.read_text(encoding="utf-8")
        findings.extend(path_findings(sheet, text))
        findings.extend(library_findings(sheet, text))
        findings.extend(count_findings(sheet, text))
        findings.extend(operator_word_findings(sheet, text))
        findings.extend(near_miss_findings(sheet, text, known))
        findings.extend(method_findings(sheet, text))
        findings.extend(dotted_findings(sheet, text))
        findings.extend(return_findings(sheet, text))
        if closed_values is not None:
            findings.extend(closed_value_findings(sheet, text, closed_values))
        if known is not None:
            assert corpus_known is not None
            findings.extend(head_findings(sheet, text, known))
            findings.extend(omitted_head_findings(sheet, text, corpus_known, used))
    for finding in findings:
        print(finding, file=sys.stderr)
    if known is not None:
        assert corpus_known is not None
        used_known = set(used) & corpus_known
        root_text = _ROOT_SHEET.read_text(encoding="utf-8")
        covered = sum(1 for name in used_known if _mentions_head(root_text, name))
        where = (
            f"against {len(known)} live engine names; {len(used_known)} of "
            f"{len(corpus_known)} callable names are corpus-used and {covered} "
            "are covered"
        )
    elif findings and findings[-1].startswith("llms: the engine"):
        where = "with the engine refusing to answer, so heads went unread"
    else:
        where = "with swipl absent, so heads went unread"
    print(f"llms: {len(sheets())} cheat sheet(s) read {where}, {len(findings)} finding(s)")
    return 1 if findings else 0


if __name__ == "__main__":
    raise SystemExit(main())
