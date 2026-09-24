"""Purpose: prove evidence_sites tells a pin or a tag in prose from the code that writes one.

It plants one of every shape and asks evidence_sites which side each lands on:
prose, where the file's grammar puts a comment, a docstring, JSON measurement
prose or an evidence tag, or code and data.

Running the gate on THIS repository proves the repository is clean. It says
nothing about whether the classifier can tell a pin from a string literal,
which is the whole of its job and the exact distinction a hand sweep got wrong
on 2026-08-31: twelve string literals were rewritten, the re-pin tool began
writing a stale object ID into every twin it priced, and the evidence gate's
own release rule stopped being tested because its self-test planted an object
ID where the gate tested for the word.

This file replaces check_pin_provenance_selftest.py, which drove the
provenance pass, tests/checks/pin_provenance.py, over a planted tree: --commit
rewrote every placeholder into the object ID of the commit whose tree produced
its evidence, --check reported what was left, and --derive read each pin's own
history. The pass is retired and so are those cases. Since the
obligation-header rule of check_evidence_tags.RULE_INSTANT a tag carries the
time its evidence ran, as `date -Iseconds` prints it, and names no commit of
its own repository, so no commit waits on a second one to pin its tags and
nothing is left for a pass to rewrite. Where a placeholder or a tag sits is
still the question the gate asks, of the legacy placeholders it counts and of
every line written since the rule, and it is this file's question.

Every planted citation is built from variables rather than written out, the
same discipline check_evidence_selftest.py keeps: a literal one in this file is
a claim about THIS repository as far as the evidence gate is concerned, and
these fixtures are deliberately unbacked.

Assumes: git on PATH, and a writable temporary directory.
Guarantees:
  - each planted shape lands on the side its class's rule documents, at the
    placeholder and at the bracket of the tag around it, in every class with
    a rule, the Dockerfile, workflow, llms.txt and skip-list rules included
    [tested 2026-09-25T04:18:23+10:00: tests/checks/check_evidence_sites_selftest.py]
  - a backtick in code pairs with none in prose, so a bare pin below a
    regex's backtick, a template literal's, a command substitution's or one
    left open in another JSON string is still a pin, and a mention in
    backticks beside it is not
    [tested 2026-09-25T04:18:23+10:00: tests/checks/check_evidence_sites_selftest.py]
  - C and C++ literal, macro and header data and CMake's three argument forms
    stay data beside real comment pins, and a malformed C, C++, CMake or TOML
    form raises UnclassifiableError naming the form
    [tested 2026-09-25T04:18:23+10:00: tests/checks/check_evidence_sites_selftest.py]
  - a class with no rule raises UnclassifiableError naming it when asked
    about an offset, and answers nothing when asked about none
    [tested 2026-09-25T04:18:23+10:00: tests/checks/check_evidence_sites_selftest.py]
  - unscanned reports a tracked file holding a real placeholder that no glob
    reaches, in the repository and in a component two submodules down, and
    reports neither a backticked mention, nor a file the globs reach, nor an
    untracked file
    [tested 2026-09-25T04:18:23+10:00: tests/checks/check_evidence_sites_selftest.py]
Fails when: run against a tree it did not write. It asserts on fixtures it
  generates and nothing else.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from check_evidence_tags import CLAIM, PLACEHOLDER  # noqa: E402  -- HERE must be on the path first
from evidence_sites import TOKEN, UnclassifiableError, classify, sites, unscanned  # noqa: E402

WORD = f"commit={PLACEHOLDER}"
TAG = "tested"
WHEN = "2026-08-31"

# (path, text, lines holding a pin in prose, lines holding one in code or data)
PLANTS = (
    # The record is hash-chained, so a rewrite destroys it rather than moving a
    # line. Both pins here must be DECLINED, and the pass must still visit the
    # file, because a file it does not visit is reported by the out-of-glob net
    # instead [measured 2026-09-20: pinning the live record made every later
    # read fail on the hash of a transaction the pass had not touched].
    (
        "agenticmind.json",
        ['{"format": 1, "log": [',
         f'  {{"id": "a", "after": null, "assert": "a case [{TAG} {WHEN}: measured; {WORD}]"}},',
         f'  {{"id": "b", "after": "a", "assert": "a next [{TAG} {WHEN}: measured; {WORD}]"}}]}}'],
        [], [2, 3],
    ),
    *(
        (name,
         [f"# A configuration pin [{TAG} {WHEN}: a case; {WORD}].",
          f'basic = "# {WORD}"',
          f"literal = '# {WORD}'",
          'multiline_basic = """',
          f"# {WORD}",
          '"""',
          "multiline_literal = '''",
          f"# {WORD}",
          "'''",
          f'"{WORD}" = "a key"',
          '"commit=PROVENANCE" = "a colliding key"',
          f"nan = nan # A trailing pin [{TAG} {WHEN}: a case; {WORD}]."],
         [1, 12], [2, 3, 5, 8, 10])
        for name in ("pyproject.toml", "extensions/plant/pyproject.toml")
    ),
    *(
        (name,
         [f"# A build pin [{TAG} {WHEN}: a case; {WORD}].",
          f'set(QUOTED "# {WORD}")',
          f"#[=[ A bracket pin [{TAG} {WHEN}: a case; {WORD}]. ]=]",
          f"set(BRACKET [==[# {WORD}]==])",
          rf"set(BARE \#{WORD})"],
         [1, 3], [2, 4, 5])
        for name in ("lib/lib_plant/support/CMakeLists.txt", "extensions/plant/build.cmake")
    ),
    *(
        (name, [f"{prefix} A fixture pin [{TAG} {WHEN}: a case; {WORD}].{suffix}"], [1], [])
        for name, prefix, suffix in (
            ("lib/lib_plant/vendor/config.h", "/*", " */"),
            ("tests/checks/host_workarounds/support/probe.pl", "%", ""),
            ("tests/checks/host_workarounds/support/probe.py", "#", ""),
            ("tests/checks/host_workarounds/support/probe.sh", "#", ""),
        )
    ),
    (
        "examples/ch-plant/_fixtures/nested/library.metta",
        [
            "; Purpose: a library loaded by an example.",
            f"; A fixture pin [{TAG} {WHEN}: test_collected; {WORD}].",
            f'(= (emitted-pin) "{WORD}")',
        ],
        [2],
        [3],
    ),
    (
        "extensions/mork/mork_ffi/src/plant.rs",
        [
            f"// A Rust header pin [{TAG} {WHEN}: a case; {WORD}].",
            "/* A block header.",
            f"   Its pin [{TAG} {WHEN}: a case; {WORD}]. */",
            f'const EMITTED: &str = "{WORD}";',
        ],
        [1, 3],
        [4],
    ),
    *(
        (name,
         [f'"""A Python header pin [{TAG} {WHEN}: a case; {WORD}]."""',
          f'EMITTED = "{WORD}"'],
         [1], [2])
        for name in ("extensions/mork/tests/plant.py", "setup.py")
    ),
    # A guide at the root: its pins sit inside evidence tags in prose, and the
    # same prose discusses the placeholder, backticked or bare, beside them.
    (
        "EXTENDING.md",
        [
            f"A guide pin [{TAG} {WHEN}: a case; {WORD}].",
            f"The word discussed rather than pinned: `{WORD}`.",
            f"A bare mention of {WORD} outside any tag is prose too.",
        ],
        [1],
        [2, 3],
    ),
    (
        "engine/plant.pl",
        [
            "% Purpose: a fixture.",
            f"%   - a Prolog pin [{TAG} {WHEN}: a_plunit_test; {WORD}].",
            f"an_atom('{WORD}').",
        ],
        [2],
        [3],
    ),
    *(
        (name,
         ["% Purpose: a native suite fixture.",
          f"% A header pin [{TAG} {WHEN}: a_plunit_test; {WORD}].",
          f"an_atom('{WORD}')."],
         [2], [3])
        for name in ("extensions/cmetta/tests/plant.pl",
                     "tests/prolog/suites/spaces/support/plant.pl")
    ),
    # Prolog's OTHER comment form. A plunit suite writes its whole contract in
    # one `/* ... */`, so a pin there has no `%` on its line and was declined
    # as code until the `%` grammar learned the block the `//` grammar knew.
    (
        "tests/prolog/suites/spaces/plant.plt",
        [
            "/* Purpose: a fixture suite.",
            f"   Guarantees: a block pin [{TAG} {WHEN}: a_plunit_test; {WORD}].",
            "*/",
            f"an_atom('{WORD}').",
        ],
        [2],
        [4],
    ),
    (
        "extensions/python/tools/plant.py",
        [
            '"""A fixture.',
            "",
            f"A docstring pin [{TAG} {WHEN}: test_collected; {WORD}].",
            f"The word itself, discussed rather than pinned: `{WORD}`.",
            '"""',
            "",
            f"#: A comment pin [{TAG} {WHEN}: test_collected; {WORD}].",
            f'TEMPLATE = "[{{kind}} {{date}}: emitted; {WORD}]"',
        ],
        [3, 7],
        [4, 8],
    ),
    (
        "extensions/node/src/plant.ts",
        [
            f"// A TypeScript pin [{TAG} {WHEN}: a case; {WORD}].",
            f"/* A block pin [{TAG} {WHEN}: a case; {WORD}]. */",
            f'export const emitted = "{WORD}";',
        ],
        [1, 2],
        [3],
    ),
    *(
        (name,
         ["# Purpose: a fixture runner.",
          f"# Guarantees: it runs [{TAG} {WHEN}: a case; {WORD}].",
          f'echo "{WORD}"'],
         [2], [3])
        for name in ("engine/plant.sh", "extensions/mork/tests/plant.sh")
    ),
    (
        "extensions/cmetta/plant.h",
        [
            "/* Purpose: a fixture header.",
            f" * Guarantees: the block half [{TAG} {WHEN}: a case; {WORD}].",
            " */",
            f'static const char *emitted = "{WORD}";',
            f"// The line half [{TAG} {WHEN}: a case; {WORD}].",
            f'#define EMITTED "/* {WORD} */"',
            f'static const char *markers = "// {WORD}";',
        ],
        [2, 5],
        [4, 6, 7],
    ),
    (
        "engine/plant.json",
        [
            "{",
            f'  "measures": "a commentless baseline [{TAG} {WHEN}: a case; {WORD}]."',
            "}",
        ],
        [2],
        [],
    ),
    # A seat's build file, keyed by NAME because a Makefile has no suffix.
    (
        "extensions/plant/Makefile",
        [
            "# Purpose: a fixture build file.",
            f"# Guarantees: its install lane proves it [{TAG} {WHEN}: a case; {WORD}].",
            "all:",
            f"\t@echo '{WORD}'",
        ],
        [2],
        [4],
    ),
    # The Node consumer's class, and the C program a seat's install lane
    # compiles: both carried a real pin on 2026-08-31 that no glob reached.
    (
        "extensions/plant/tools/plant.mjs",
        [
            "/* Purpose: a fixture consumer.",
            f" * Guarantees: the dist lane boots it [{TAG} {WHEN}: a case; {WORD}].",
            " */",
            f'export const emitted = "{WORD}";',
            f"// The line half [{TAG} {WHEN}: a case; {WORD}].",
        ],
        [2, 5],
        [4],
    ),
    (
        "extensions/plant/tests/plant.c",
        [
            "/* Purpose: a fixture consumer program.",
            f" * Guarantees: the install lane compiles it [{TAG} {WHEN}: a case; {WORD}].",
            " */",
            f'static const char *emitted = "{WORD}";',
            f'#define EMITTED "/* {WORD} */"',
            f'static const char *markers = "// {WORD}";',
        ],
        [2],
        [4, 5, 6],
    ),
    (
        "lib/lib_plant/support/plant.cpp",
        [
            "/* Purpose: a native C++ provider.",
            f" * Guarantees: its header pin [{TAG} {WHEN}: a case; {WORD}].",
            " */",
            f"// A line pin [{TAG} {WHEN}: a case; {WORD}].",
            f'const char *emitted = "/* {WORD} */";',
            f'#define EMITTED "// {WORD}"',
            f'const char *raw = R"tag(" /* {WORD} */)tag";',
            "// A continued comment \\",
            f"   with a pin [{TAG} {WHEN}: a case; {WORD}].",
            "/\\",
            f"* A spliced block pin [{TAG} {WHEN}: a case; {WORD}]. */",
            f'#include <dir/*{WORD}*/header>',
            f'const char *unicode = "🦊"; // A pin [{TAG} {WHEN}: a case; {WORD}].',
        ],
        [2, 4, 9, 11, 13],
        [5, 6, 7, 12],
    ),
    # Prose WRAPS, and a backtick span wraps with it. Line 5's mention sits
    # inside a span opened on line 4, which a per-line backtick count reads as
    # unbalanced and rewrites: DEVELOPING.md's own explanation is this shape.
    (
        "engine/plant_wrap.pl",
        [
            "% Purpose: a fixture whose prose wraps.",
            f"%   While working, write `{WORD}`, which names no tree yet.",
            f"%   A real pin reads [{TAG} {WHEN}: a_plunit_test; {WORD}].",
            # `{TAG}` rather than the word, so this line is a fixture and not a
            # claim about THIS repository. Written out, the bracket opened a tag
            # the evidence gate read across the next two lines and into the
            # Python quoting around them, and it reported a citation of `, f`.
            f"%   The span below opens here: `[{TAG}: <name>;",
            f"%   {WORD}]` and closes on this line, one span over two lines.",
            # A run of one closes only on a run of ONE, so the run of three is
            # skipped and this mention sits inside one span. A ``(`+)...\1``
            # regex instead pairs the ticks off two at a time, leaving the
            # mention between two spans and rewriting it as a pin.
            f"%   Opens `A```{WORD} and closes` here.",
        ],
        [3],
        [2, 5, 6],
    ),
    # Outside every glob check_evidence_tags reads. Its grammar makes it a
    # pin, and unscanned must report it: an unscanned pin is a claim nothing
    # would ever resolve, which is the defect the out-of-glob net exists to
    # catch.
    #
    # website/, not extensions/python/tests/: the gate's globs GREW on
    # 2026-09-07, when the Python seat's own conftest.py started carrying pins
    # and `extensions/python/tests/*.py` joined SOURCES to make them readable.
    # This plant then landed inside the globs it exists to sit outside, the
    # pass rewrote it as it should, and the selftest read that as four
    # defects. A fixture that names the CONDITION rather than a path is not
    # available here -- the globs are the thing under test -- so the path is
    # one the gate has no reason to read: generated documentation.
    (
        "website/plant.py",
        [f"#: An unscanned pin [{TAG} {WHEN}: test_collected; {WORD}]."],
        [1],
        [],
    ),
    # The four classes that joined when the gate began reading every file git
    # sees: a Dockerfile and a workflow comment with `#`, llms.txt is
    # Markdown, and the skip list says in its own first lines that a line
    # starting with `#` is a comment.
    (
        "tools/plant/Dockerfile",
        [f"# A build pin [{TAG} {WHEN}: a case; {WORD}].",
         f"RUN echo {WORD}"],
        [1],
        [2],
    ),
    (
        ".github/workflows/plant.yml",
        [f"# A workflow pin [{TAG} {WHEN}: a case; {WORD}].",
         f"run: echo {WORD}"],
        [1],
        [2],
    ),
    (
        "extensions/plant/llms.txt",
        [f"A cheat-sheet pin [{TAG} {WHEN}: a case; {WORD}].",
         f"The word discussed rather than pinned: `{WORD}`.",
         f"A bare mention of {WORD} outside any tag is prose too."],
        [1],
        [2, 3],
    ),
    (
        "tests/data/example_skips.txt",
        ["# One path per line, then its reason.",
         f"# A skip's measured reason [{TAG} {WHEN}: a case; {WORD}].",
         f"examples/plant.metta   needs {WORD}"],
        [2],
        [3],
    ),
    # A backtick in CODE opens no code span. Paired over the whole file, the
    # first line's backtick opened one that the mention's first backtick
    # closed, so the bare pin between them read as a mention and the mention
    # as a pin; each grammar's own code carries one here.
    *(
        (name,
         [code,
          f"{marker} A bare pin below it [{TAG} {WHEN}: a case; {WORD}].",
          f"{marker} The word discussed rather than pinned: `{WORD}`."],
         [2], [3])
        for name, code, marker in (
            ("extensions/python/tools/plant_ticks.py", 'TICKS = re.compile(r"[`]")', "#"),
            ("extensions/node/src/plant_ticks.ts", 'const tick = "`";', "//"),
            ("engine/plant_ticks.sh", "quote='`'", "#"),
            ("engine/plant_ticks.pl", "tick('`').", "%"),
        )
    ),
    # A JSON string holds no raw newline, so a backtick one leaves open does
    # not close in the next.
    (
        "engine/plant_ticks.json",
        ["{",
         '  "a": "a backtick ` left open in one string",',
         f'  "b": "a measured pin [{TAG} {WHEN}: a case; {WORD}]",',
         f'  "c": "the word discussed rather than pinned: `{WORD}`"',
         "}"],
        [3],
        [4],
    ),
)


def plant_complaints() -> tuple[list[str], int]:
    """Every planted placeholder on its class's side, and every tag's bracket beside the pin it carries."""
    found: list[str] = []
    checked = 0
    for name, lines, pins, code in PLANTS:
        path = Path(name)
        text = "\n".join(lines) + "\n"
        read: dict[int, list[str | None]] = {}
        try:
            placed = sites(path, text)
        except UnclassifiableError as error:
            found.append(f"{name} was refused, where its class has a rule: {error}")
            continue
        for _at, line, reason in placed:
            read.setdefault(line, []).append(reason)
        for line, wanted in [(line, "prose") for line in pins] + [(line, "code") for line in code]:
            checked += 1
            sides = {"prose" if reason is None else "code" for reason in read.get(line, [])}
            if sides != {wanted}:
                found.append(f"{name}:{line} is {wanted} and was read as {sorted(sides)}: "
                             f"{lines[line - 1].strip()!r}")
        # The rule-era check asks about a tag's BRACKET, where the count asks
        # about the placeholder inside it, so the two must land together.
        tags = [(match.start(), match.start() + inner.start())
                for match in CLAIM.finditer(text)
                if (inner := TOKEN.search(match.group(0)))]
        outer = classify(path, text, [bracket for bracket, _pin in tags])
        within = classify(path, text, [pin for _bracket, pin in tags])
        for (bracket, _pin), side, pin_side in zip(tags, outer, within, strict=True):
            checked += 1
            if (side is None) != (pin_side is None):
                line = text.count("\n", 0, bracket) + 1
                found.append(f"{name}:{line}: the tag's bracket reads as {side!r} and its pin as {pin_side!r}")
    return found, checked


#: A form each whole-file grammar cannot read, with the reason it is refused
#: by, and a class with no rule at all. Each is raised rather than guessed at.
REFUSALS = (
    *(("lib/lib_plant/support/plant.cpp", content, reason) for content, reason in (
        (f"/* {WORD}", "unterminated C/C++ block comment"),
        (f'const char *p = "{WORD}', "unterminated C/C++ string or character literal"),
        (f'R"tag({WORD}', "unterminated C++ raw string"),
        (f'R"bad delimiter({WORD})bad delimiter"', "invalid C++ raw-string delimiter"),
        (f"#include <{WORD}", "unterminated C/C++ header name"),
    )),
    *(("lib/lib_plant/support/CMakeLists.txt", content, reason) for content, reason in (
        (f'set(X "{WORD}', "unterminated CMake quoted argument"),
        (f"#[=[ {WORD}", "unterminated CMake bracket argument or comment"),
        (f"set(X [==[{WORD}", "unterminated CMake bracket argument or comment"),
    )),
    ("extensions/plant/pyproject.toml", f'x = "{WORD}', "not TOML"),
    ("extensions/plant/notes.txt", f"# A pin {WORD}", ".txt has no comment rule here"),
)


def refusal_complaints() -> tuple[list[str], int]:
    """Every refusal raised with its reason, and nothing asked of a class with no rule when nothing needs placing."""
    found: list[str] = []
    for name, content, reason in REFUSALS:
        try:
            sites(Path(name), content + "\n")
        except UnclassifiableError as error:
            if reason not in str(error):
                found.append(f"{name} refused {content!r} with {str(error)!r}, not {reason!r}")
        else:
            found.append(f"{name} did not refuse {content!r} with {reason!r}")
    if classify(Path("extensions/plant/notes.txt"), f"# A pin {WORD}\n", []):
        found.append("a class with no rule answered something when asked about no offset")
    return found, len(REFUSALS) + 1


def c_lexical_complaints() -> tuple[list[str], int]:
    """Vary independent literal forms and delimiters around real comment pins."""
    cases: list[tuple[str, list[bool]]] = [
        (f'char c = \'\\\'\'; // {WORD}', [True]),
        (f"auto n = 1'000; // {WORD}", [True]),
        (f'const char *p = "`"; // {WORD}\nconst char *q = "`";', [True]),
        (f'const char *p = "a\\\nb//{WORD}"; // {WORD}', [False, True]),
        (f'// A wrapped `{WORD}\n// mention` and a pin {WORD}', [False, True]),
        (f'/\\\n* {WORD} */', [True]),
        (f'/\\ \t\n/ {WORD}', [True]),
        (f'#define DATA <a /* {WORD} */ >', [True]),
        (f'x <a /* {WORD} */ >', [True]),
        (f'(import <a /* {WORD} */ >)', [True]),
        (f'#include "dir\\" // {WORD}', [True]),
        (f'#include /* {WORD} */ <dir/*{WORD}*/header>', [True, False]),
        (f'#if __has_include(<dir/*{WORD}*/header>) // {WORD}', [False, True]),
        (f'export import <dir/*{WORD}*/header>; // {WORD}', [False, True]),
        (f'R"tag()ta\\\ng" /* {WORD} */)tag"; // {WORD}', [False, True]),
    ]
    for prefix in ("", "u8", "u", "U", "L"):
        for delimiter in ("", "tag", "sixteen_chars_ok"):
            cases.extend((f'{prefix}R"{delimiter}({payload}){delimiter}"; // {WORD}',
                          [False, True])
                         for payload in (f"// {WORD}", f'" /* {WORD} */', f"\\\n{WORD}"))
    found = []
    for index, (source, expected) in enumerate(cases):
        actual = [reason is None for _at, _line, reason in sites(Path("plant.cpp"), source)]
        if actual != expected:
            found.append(f"C++ lexical case {index}: expected {expected}, got {actual}: {source!r}")
    for suffix in ("c", "h", "cpp", "cc", "cxx", "hpp", "hh", "hxx", "C"):
        source = f'#define DATA "/* {WORD} */"\n// {WORD}'
        actual = [reason is None for _at, _line, reason in sites(Path(f"plant.{suffix}"), source)]
        if actual != [False, True]:
            found.append(f".{suffix} does not share the C-family string/comment rule: {actual}")
    return found, len(cases) + 9


def cmake_lexical_complaints() -> tuple[list[str], int]:
    """Vary independent CMake argument forms and bracket lengths around pins."""
    cases = [
        (f'set(X "# {WORD}") # {WORD}', [False, True]),
        (rf'set(X \#{WORD}) # {WORD}', [False, True]),
        (f'set(X "a\\\n# {WORD}") # {WORD}', [False, True]),
        (f'set(X -Da="a {WORD}") # {WORD}', [False, True]),
        (f'set(X abc[[) # {WORD}', [True]),
        (f'set(X "`{WORD}`") # {WORD}', [False, True]),
        (f'# A `{WORD}` mention and a pin {WORD}', [False, True]),
    ]
    for length in range(8):
        delimiter = "=" * length
        for payload in (f"# {WORD}", f'"# {WORD}"', f"\\\n{WORD}"):
            cases.append((f'set(X [{delimiter}[{payload}]{delimiter}]) # {WORD}', [False, True]))
            cases.append((f'#[{delimiter}[{payload}]{delimiter}]', [True]))
    found = []
    for name in ("CMakeLists.txt", "plant.cmake"):
        for index, (source, expected) in enumerate(cases):
            actual = [reason is None for _at, _line, reason in sites(Path(name), source)]
            if actual != expected:
                found.append(f"{name} lexical case {index}: expected {expected}, got {actual}: {source!r}")
    return found, len(cases) * 2


def _git(root: Path, *arguments: str) -> str:
    """One git command over a fixture tree, with an identity it can commit under."""
    done = subprocess.run(
        ["git", "-c", "user.name=t", "-c", "user.email=t@t",
         "-c", "protocol.file.allow=always", *arguments],
        cwd=root, capture_output=True, text=True, check=True,
    )
    return done.stdout.strip()


def _repo(path: Path, name: str, body: str) -> str:
    """A repository holding one placeholder-carrying file, committed."""
    path.mkdir(parents=True, exist_ok=True)
    (path / name).parent.mkdir(parents=True, exist_ok=True)
    (path / name).write_text(body, encoding="utf-8")
    _git(path, "init", "-q")
    _git(path, "add", "-A")
    _git(path, "commit", "-qm", "one")
    return _git(path, "rev-parse", "HEAD")


def unscanned_complaints() -> tuple[list[str], int]:
    """The out-of-glob net over a repository and a component two submodules down.

    Tracked, outside the globs and holding a real pin is reported, in the
    repository and in the nested component; a file the globs reach, a
    backticked mention and an untracked file are not.
    """
    found: list[str] = []
    name, lines, _pins, _code = next(plant for plant in PLANTS if plant[0] == "website/plant.py")
    body = "\n".join(lines) + "\n"
    with tempfile.TemporaryDirectory() as directory:
        scratch = Path(directory)
        deep = scratch / "deepsrc"
        _repo(deep, "docs/deep.py", body)
        sub = scratch / "subsrc"
        _repo(sub, "README.md", f"A mention only: `{WORD}`.\n")
        _git(sub, "submodule", "add", "-q", str(deep), "vendor/deep")
        _git(sub, "commit", "-qm", "sub takes deep")
        root = scratch / "root"
        _repo(root, name, body)
        (root / "reached.py").write_text(f"# A pin the globs reach {WORD}\n", encoding="utf-8")
        (root / "mention.md").write_text(f"The word discussed: `{WORD}`.\n", encoding="utf-8")
        _git(root, "add", "-A")
        _git(root, "commit", "-qm", "two")
        _git(root, "submodule", "add", "-q", str(sub), "lib/sub")
        _git(root, "submodule", "update", "--init", "--recursive", "-q")
        _git(root, "commit", "-qm", "root takes sub")
        (root / "untracked.py").write_text(f"# An untracked pin {WORD}\n", encoding="utf-8")
        top = root.resolve()
        reported = {
            path.relative_to(top).as_posix(): count
            for path, count in unscanned({top / "reached.py"}, root)
        }
        wanted = {name: 1, "lib/sub/vendor/deep/docs/deep.py": 1}
        if reported != wanted:
            found.append(f"unscanned reported {reported}, wanted {wanted}")
    return found, 5


def main() -> int:
    """Report the defects and exit nonzero if there are any."""
    found: list[str] = []
    counts: list[int] = []
    for check in (plant_complaints, refusal_complaints, c_lexical_complaints,
                  cmake_lexical_complaints, unscanned_complaints):
        defects, cases = check()
        found.extend(defects)
        counts.append(cases)
    for one in found:
        print(one)
    planted = sum(len(pins) + len(code) for _name, _lines, pins, code in PLANTS)
    print(
        f"evidence-sites selftest: {len(found)} defect(s), over {planted} planted lines in "
        f"{len(PLANTS)} files and the brackets of their tags, {counts[0]} placements in all; "
        f"{counts[1]} refusals; {counts[2]} C-family and {counts[3]} CMake lexical cases; "
        f"{counts[4]} out-of-glob cases over a repository and a component two submodules down"
    )
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
