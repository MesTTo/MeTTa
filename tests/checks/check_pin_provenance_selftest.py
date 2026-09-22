"""Purpose: prove pin_provenance.py tells a pin from the code that writes one.

It plants one of every shape in a tree and runs the real pass over it.

Running the pass on THIS repository proves the repository is clean. It says
nothing about whether the pass can tell a pin from a string literal, which is
the whole of its job and the exact distinction a hand sweep got wrong on
2026-08-31: twelve string literals were rewritten, the re-pin tool began
writing a stale object ID into every twin it priced, and the evidence gate's
own RELEASE=1 rule stopped being tested because its self-test planted an
object ID where the gate tested for the word.

Every planted citation is built from variables rather than written out, the
same discipline check_evidence_selftest.py keeps: a literal one in this file is
a claim about THIS repository as far as the evidence gate is concerned, and
these fixtures are deliberately unbacked.

Assumes: git on PATH, and a writable temporary directory.
Guarantees:
  - nested Prolog suite helpers resolve header pins and preserve code atoms
    [tested: tests/checks/check_pin_provenance_selftest.py; commit=6471fbad35eced5ed6440ebf2c25a053b20221f3]
  - each planted shape lands on the side the pass documents, and
    the pass reports the declined ones with a reason
    [tested: tests/checks/check_pin_provenance_selftest.py]
  - a placeholder outside the evidence gate's own globs is REPORTED and fails
    the run, and is never rewritten: the pass writes only where the gate reads,
    and says so loudly where the gate does not
    [tested: tests/checks/check_pin_provenance_selftest.py]
  - --check exits 1 while pins remain and 0 once they are resolved, and a
    commit that does not resolve is refused before any file changes
    [tested: tests/checks/check_pin_provenance_selftest.py]
  - Rust header pins and MORK's Python selftest pins are reached and resolved
    [tested: tests/checks/check_pin_provenance_selftest.py; commit=6da518669cb9e39557d537857c0aa7190dd2e78f]
  - nested example fixtures resolve their comment pins and preserve code
    [tested: tests/checks/check_pin_provenance_selftest.py; commit=90ba93eb8f6e98ebfefc55416859bf13de6a8427]
  - nested C Prolog fixtures resolve their header pins and preserve code atoms
    [tested: tests/checks/check_pin_provenance_selftest.py; commit=8ca8a387fc61d0918484b19a1a3baf85b6523043]
  - root build hooks and component shell tests resolve header pins and
    preserve code strings
    [tested: tests/checks/check_pin_provenance_selftest.py; commit=8ee8fcd4e43a932131909f7c58ad4fbe4dcf8d1d]
  - TOML comments resolve while quoted keys, all four string forms and
    hash characters inside values stay unchanged, including beside NaN
    [tested: tests/checks/check_pin_provenance_selftest.py; commit=f88b11ae305c4e1bfafa8387d1f24e51d0d8cb92]
  - C and C++ literal, macro and header data survive pinning, and malformed
    lexical forms refuse before any file changes
    [tested: tests/checks/check_pin_provenance_selftest.py; commit=3aaad3435292e4c7d5cc3a01bfda39430aacc6e8]
  - CMake argument data survives comment pinning, malformed delimiters refuse
    before writing, and nested host fixtures and provider headers are reached
    [tested: tests/checks/check_pin_provenance_selftest.py; commit=7b42d5ee5cecb82709617b7ed08dfa2c1441f268]
Fails when: run against a tree it did not write. It asserts on a fixture it
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

from check_evidence_tags import PLACEHOLDER  # noqa: E402  -- HERE must be on the path first
from fixture_modules import sibling_closure  # noqa: E402  -- HERE must be on the path first
from pin_provenance import sites  # noqa: E402

WORD = f"commit={PLACEHOLDER}"
TAG = "tested"
WHEN = "2026-08-31"

# (path, text, lines that must be rewritten, lines that must be declined)
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
    # Outside every glob check_evidence_tags reads. The pass must not REWRITE
    # it, and must report it: an unscanned pin is a claim nothing would ever
    # resolve, which is the defect the out-of-glob net exists to catch.
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
        [],
        [],
    ),
)


def build(root: Path) -> str:
    """The fixture tree, committed, with the pass beside its imports."""
    tools = root / "tools/checks"
    tools.mkdir(parents=True)
    # Derived, not listed: `sibling_closure` reads the imports, so an import
    # added to a copied checker is carried without an edit here. Three
    # fixtures kept this answer by hand and one import to evidence_runners.py
    # broke all three.
    for module in sibling_closure(("pin_provenance.py",)):
        # The pass under test, with its OWN placeholders spent. These three
        # carry evidence tags like every other hand-written file, so while
        # their thread is in progress they hold the in-progress spelling, and a
        # verbatim copy carries it into a tree where nothing reads their glob:
        # the out-of-glob net then reports the checker rather than the fixture
        # and --check exits 1 on a tree whose every planted pin is resolved.
        # This is the same separation that puts the copies under tools/checks
        # rather than tests/, one level further in.
        (tools / module).write_text(
            (HERE / module).read_text(encoding="utf-8").replace(
                WORD, "commit=(pinned in the tree this copy was taken from)"
            ),
            encoding="utf-8",
        )
    (root / "check.sh").write_text("# a gate script the runner model expects\n")
    # engine/*.sh is one of the pass's globs, so the shell plant below is only
    # reached when the fixture writes it before the loop that writes the rest.
    for name, lines, _rewritten, _declined in PLANTS:
        path = root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("\n".join(lines) + "\n")
    for command in (
        ["git", "init", "-q"],
        ["git", "add", "-A"],
        ["git", "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "fixture"],
    ):
        # unbounded: git over a temporary directory, which returns.
        subprocess.run(command, cwd=root, check=True, capture_output=True)
    return subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=root, check=True, capture_output=True, text=True
    ).stdout.strip()


def run(root: Path, *arguments: str) -> subprocess.CompletedProcess[str]:
    """The real pass, run over the fixture tree with the given arguments."""
    return subprocess.run(
        [sys.executable, str(root / "tools/checks/pin_provenance.py"), *arguments],
        cwd=root,
        capture_output=True,
        text=True,
        check=False,
    )


def complaints() -> list[str]:
    """Everything the pass got wrong on a tree whose right answers are known."""
    found: list[str] = []
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        live = build(root)

        # A commit that names nothing is refused before a file is opened.
        missing = run(root, "--commit", "0" * 40)
        if missing.returncode == 0:
            found.append("a commit that does not resolve was accepted")
        if any((root / name).read_text().count(WORD) != sum(1 for line in lines if WORD in line)
               for name, lines, _r, _d in PLANTS):
            found.append("a refused commit still rewrote a file")

        checked = run(root, "--check")
        if checked.returncode != 1:
            found.append(f"--check exited {checked.returncode} with pins outstanding, wanted 1")
        found.extend(
            f"--check did not name {name}:{line}, which is a pin"
            for name, _lines, rewritten, _declined in PLANTS
            for line in rewritten
            if f"{name}:{line}: placeholder awaiting" not in checked.stdout
        )
        found.extend(
            f"--check named {name}:{line} a pin, which is code"
            for name, _lines, _rewritten, declined in PLANTS
            for line in declined
            if f"{name}:{line}: placeholder awaiting" in checked.stdout
        )

        resolved = run(root, "--commit", live)
        unscanned = ""
        if resolved.returncode == 0:
            found.append("the pass exited 0 with a pin outside the gate's globs, wanted nonzero")
        for name, lines, rewritten, declined in PLANTS:
            text = (root / name).read_text().splitlines()
            found.extend(
                f"{name}:{line} was not rewritten: {text[line - 1].strip()!r}"
                for line in rewritten
                if f"commit={live}" not in text[line - 1]
            )
            for line in declined:
                if WORD not in text[line - 1]:
                    found.append(f"{name}:{line} was rewritten and should not have been: "
                                 f"{text[line - 1].strip()!r}")
                if f"{name}:{line}: left alone" not in resolved.stdout:
                    found.append(f"{name}:{line} was left alone without saying why")
            if not rewritten and not declined and len(lines) == 1:
                unscanned = name
                if WORD not in text[0]:
                    found.append(f"{name} is outside the gate's globs and was rewritten anyway")
                if f"{name}: 1 pin(s) OUTSIDE" not in resolved.stdout:
                    found.append(f"{name} is outside the gate's globs and went unreported")

        # An unscanned pin fails the run on its own, with every other pin
        # already resolved: without this the net could report and still exit 0,
        # which is the silence it exists to end.
        again = run(root, "--check")
        if again.returncode != 1:
            found.append(
                f"--check exited {again.returncode} with an unscanned pin outstanding, wanted 1"
            )
        (root / unscanned).unlink()
        cleared = run(root, "--check")
        if cleared.returncode != 0:
            found.append(f"--check exited {cleared.returncode} on a resolved tree, wanted 0")

        # Scan every candidate before opening the first output for writing.
        # A valid earlier file must survive a malformed later file unchanged.
        early = root / "engine/plant.pl"
        failures = (
            (f"/* {WORD}", "unterminated C/C++ block comment"),
            (f'const char *p = "{WORD}', "unterminated C/C++ string or character literal"),
            (f'R"tag({WORD}', "unterminated C++ raw string"),
            (f'R"bad delimiter({WORD})bad delimiter"', "invalid C++ raw-string delimiter"),
            (f'#include <{WORD}', "unterminated C/C++ header name"),
        )
        refusal_cases = [("lib/lib_plant/support/plant.cpp", content, reason)
                         for content, reason in failures]
        refusal_cases.extend(("lib/lib_plant/support/CMakeLists.txt", content, reason)
                             for content, reason in (
                                 (f'set(X "{WORD}', "unterminated CMake quoted argument"),
                                 (f"#[=[ {WORD}", "unterminated CMake bracket argument or comment"),
                                 (f"set(X [==[{WORD}", "unterminated CMake bracket argument or comment"),
                             ))
        for name, content, reason in refusal_cases:
            malformed = root / name
            original = malformed.read_bytes()
            early.write_text(f"% A header pin {WORD}.\n")
            malformed.write_text(content + "\n")
            before = {path: path.read_bytes() for path in root.rglob("*")
                      if path.is_file() and ".git" not in path.parts}
            refused = run(root, "--commit", live)
            if refused.returncode == 0 or reason not in refused.stderr:
                found.append(f"{name} did not refuse with {reason!r}: {refused.stderr!r}")
            if any(path.read_bytes() != data for path, data in before.items()):
                found.append(f"{name} rewrote files before refusing {reason!r}")
            malformed.write_bytes(original)
    return found


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


#: What a pin resolves to is a function of DEPTH and of WHEN the superproject
#: took the content, so the fixture below separates the two rather than
#: planting a case per combination: three depths, and the two submodule depths
#: arriving at different superproject commits. A tree where every file is added
#: in one commit cannot tell a correct answer from HEAD.
def derive_complaints() -> tuple[list[str], int]:
    """Whether --derive names the superproject commit that carries each pin."""
    found: list[str] = []
    checked = 0
    with tempfile.TemporaryDirectory() as directory:
        scratch = Path(directory)
        root = scratch / "root"

        # R1: the superproject alone, carrying its own pin.
        tools = root / "tools/checks"
        tools.mkdir(parents=True)
        for module in sibling_closure(("pin_provenance.py",)):
            (tools / module).write_text(
                (HERE / module).read_text(encoding="utf-8").replace(
                    WORD, "commit=(pinned in the tree this copy was taken from)"
                ),
                encoding="utf-8",
            )
        (root / "check.sh").write_text("# a gate script the runner model expects\n")
        (root / "probe.py").write_text(f'"""Purpose: p.\n\nGuarantees: r [{TAG} {WHEN}: a case; {WORD}]\n"""\n')
        _git(root, "init", "-q")
        _git(root, "add", "-A")
        _git(root, "commit", "-qm", "root alone")
        r1 = _git(root, "rev-parse", "HEAD")

        # The nested pair, built outside and mounted in afterwards, so the
        # superproject commit that carries them is NOT the one that carries
        # probe.py.
        deep = scratch / "deepsrc"
        _repo(deep, "vendor.h", f"/* Purpose: v. Guarantees: g [{TAG} {WHEN}: a case; {WORD}] */\n")
        sub = scratch / "subsrc"
        _repo(sub, "thing.pl", f"% Purpose: t. Guarantees: g [{TAG} {WHEN}: a case; {WORD}]\n")
        _git(sub, "submodule", "add", "-q", str(deep), "vendor")
        _git(sub, "commit", "-qm", "sub takes deep")

        # R2: the superproject takes both at once.
        _git(root, "submodule", "add", "-q", str(sub), "lib/libx")
        _git(root, "commit", "-qm", "root takes sub")
        r2 = _git(root, "rev-parse", "HEAD")

        # R3: a SECOND file in the deepest repository, arriving later, so the
        # two pins inside one submodule must resolve to different commits.
        (deep / "extra.h").write_text(f"/* Purpose: e. Guarantees: g [{TAG} {WHEN}: a case; {WORD}] */\n")
        _git(deep, "add", "-A")
        _git(deep, "commit", "-qm", "deep grows")
        _git(sub / "vendor", "fetch", "-q", "origin")
        _git(sub / "vendor", "checkout", "-q", _git(deep, "rev-parse", "HEAD"))
        _git(sub, "add", "-A")
        _git(sub, "commit", "-qm", "sub bumps deep")
        _git(root / "lib/libx", "fetch", "-q", "origin")
        _git(root / "lib/libx", "checkout", "-q", _git(sub, "rev-parse", "HEAD"))
        _git(root / "lib/libx", "submodule", "update", "--init", "-q")
        _git(root, "add", "-A")
        _git(root, "commit", "-qm", "root bumps sub")
        r3 = _git(root, "rev-parse", "HEAD")

        wanted = {
            "probe.py": r1,
            "lib/libx/thing.pl": r2,
            "lib/libx/vendor/vendor.h": r2,
            "lib/libx/vendor/extra.h": r3,
        }
        done = run(root, "--check", "--derive")
        seen = {
            line.split(":", 1)[0]: line.rsplit(" ", 1)[1]
            for line in done.stdout.splitlines()
            if "would pin to" in line
        }
        for where, expected in wanted.items():
            checked += 1
            got = seen.get(where)
            if got is None:
                found.append(f"--derive never reached {where}; it saw {sorted(seen)}")
            elif got != expected:
                rung = {r1: "the root's own commit", r2: "the commit taking the submodule",
                        r3: "the commit bumping it"}.get(got, got)
                found.append(
                    f"--derive put {where} on {got[:9]} ({rung}), wanted {expected[:9]}"
                )
        # A submodule's OWN object ID never resolves in the superproject, which
        # is the failure the climb exists to prevent, so it is worth naming
        # rather than only implying through the expectations above.
        checked += 1
        inside = {_git(sub, "rev-parse", "HEAD"), _git(deep, "rev-parse", "HEAD")}
        if inside & set(seen.values()):
            found.append("--derive pinned a submodule file to the submodule's own commit")

        # The WRITE path, which is not the reporting path: --derive carries a
        # commit per site where --commit carries one for the sweep, so a
        # correct report says nothing about which oid reaches which file.
        written = run(root, "--derive")
        for where, expected in wanted.items():
            checked += 1
            body = (root / where).read_text(encoding="utf-8")
            if f"commit={expected}" not in body:
                found.append(
                    f"--derive reported {where} correctly but wrote "
                    f"{body.strip()[:90]!r}, which does not carry {expected[:9]}"
                )
        checked += 1
        if written.returncode != 0:
            found.append(f"--derive exited {written.returncode}: {written.stderr.strip()[:160]}")
        checked += 1
        if run(root, "--check", "--derive").returncode != 0:
            found.append("--check still reports a pin after --derive wrote every one")

        # An uncommitted line has no tree that produced it, and is refused
        # rather than pinned to whatever commit happens to be current.
        checked += 1
        (root / "probe.py").write_text(
            f'"""Purpose: p.\n\nGuarantees: r [{TAG} {WHEN}: a case; {WORD}]\nAnd: s [{TAG} {WHEN}: a second case; {WORD}]\n"""\n'
        )
        refused = run(root, "--derive")
        if refused.returncode == 0 or "not committed" not in refused.stdout + refused.stderr:
            found.append(
                f"--derive accepted an uncommitted placeholder: rc={refused.returncode} "
                f"{(refused.stdout + refused.stderr).strip()[:160]}"
            )
    return found, checked


def main() -> int:
    """Report the defects and exit nonzero if there are any."""
    found = complaints()
    lexical, cases = c_lexical_complaints()
    found.extend(lexical)
    cmake, cmake_cases = cmake_lexical_complaints()
    found.extend(cmake)
    derived, derived_cases = derive_complaints()
    found.extend(derived)
    for one in found:
        print(one)
    planted = sum(len(rewritten) + len(declined) for _n, _l, rewritten, declined in PLANTS)
    print(
        f"pin-provenance selftest: {len(found)} defect(s), over {planted} planted placeholders "
        f"in {len(PLANTS)} files, one of them outside the gate's globs; "
        f"{cases} C-family and {cmake_cases} CMake lexical cases; eight pre-write refusals; "
        f"{derived_cases} --derive cases over a superproject, a submodule and a submodule of one"
    )
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
