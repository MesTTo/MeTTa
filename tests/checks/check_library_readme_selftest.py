"""Purpose: prove check_library_readme reports each defect it exists to catch.

A check nobody has seen fail might be looking at nothing. So each case plants
one defect in a copy of a small fixture pack -- a page, three libraries and
three corpus programs -- and requires a finding that names it, after a control
proves the unplanted fixture reads clean. The engine reads the fixture's own
sources, so the superset rule runs through the engine predicates the lane uses
rather than through a stand-in.

Assumes: the engine boots from this checkout with `swipl` on PATH.
Guarantees:
  - the unplanted fixture has no finding, and each planted defect has the one
    that names it: a library directory without an entry, whether named lib_*
    or made a library by its manifest, an entry without an example, a fence
    that is not its lines, a range starting on a comment, a
    runnable excerpt fenced `text` and a fixture-reading one fenced `metta`, a
    listed head no source spells, a wrong section count, a stale superset
    table, and a library that starts writing a sequence variable, a variadic
    signature or an annotated arrow
    [tested 2026-09-25T16:13:37+10:00: tests/checks/check_library_readme_selftest.py]
  - the superset table carries a library that only requires one writing the
    syntax, naming the requirement [tested 2026-09-25T16:13:37+10:00:
    tests/checks/check_library_readme_selftest.py]
  - `--write` fills an empty fence, follows an excerpt moved down its file, and
    refuses one whose text changed [tested 2026-09-25T16:13:37+10:00:
    tests/checks/check_library_readme_selftest.py]
Fails when: run outside a checkout, which it reports.
"""

from __future__ import annotations

import re
import shutil
import sys
import tempfile
from collections.abc import Callable
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_library_readme as checked

BASE = "https://example.invalid/Corpus/blob/main/"

CORPUS = {
    "ch/01-a.metta": ("; Purpose: the fixture's first program.\n"
                      "!(import! &self (library lib_a))\n"
                      "\n"
                      "; A comment the page does not quote.\n"
                      "!(test (a-double 2) 4)\n"
                      "!(test (a-double 3) 6)\n"),
    "ch/02-b.metta": ('!(import_prolog_functions_from_file "./examples/ch/_fixtures/b.pl" ())\n'
                      "!(import! &self (library lib_b))\n"
                      "!(test (b-first (1 2 3)) 1)\n"),
    "ch/03-c.metta": ("!(import! &self (library lib_c))\n"
                      "!(test (c-id 7) 7)\n"),
}

SOURCES = {
    "lib_a/pkg.metta": '(= (package requires) "lib.metta")\n',
    "lib_a/lib.metta": "(= (a-double $x) (* 2 $x))\n",
    "lib_b/pkg.metta": '(= (package requires) "lib.metta")\n',
    "lib_b/lib.metta": "(= (b-first ($x (:seg $rest))) $x)\n",
    "lib_c/pkg.metta": '(= (package requires) lib_b)\n(= (package requires) "lib.metta")\n',
    "lib_c/lib.metta": "(= (c-id $x) $x)\n",
}

ENTRY = """### {name}

| Feature | Heads |
|---|---|
| Heads | `{head}` |

Its example ([source]({base}{path}#L{start}-L{end})).

```{info}
{body}```

"""


def page() -> str:
    """The fixture page, its superset region already rendered."""
    entries = [
        ("lib_a", "a-double", "ch/01-a.metta", 2, 6, "metta",
         "!(import! &self (library lib_a))\n\n!(test (a-double 2) 4)\n!(test (a-double 3) 6)\n"),
        ("lib_b", "b-first", "ch/02-b.metta", 1, 3, "text", CORPUS["ch/02-b.metta"]),
        ("lib_c", "c-id", "ch/03-c.metta", 1, 2, "metta", CORPUS["ch/03-c.metta"]),
    ]
    region = checked.render({"lib_b": None, "lib_c": "lib_b"}, 3)
    return ("# Fixture pack\n\nThe fixture supplies 3 libraries.\n\n"
            "| Section | Libraries |\n|---|---:|\n| [Only](#only) | 3 |\n\n"
            f"{checked.BEGIN}\n{region}\n{checked.END}\n\n## Only\n\n"
            + "".join(ENTRY.format(name=name, head=head, base=BASE, path=path, start=start,
                                   end=end, info=info, body=body)
                      for name, head, path, start, end, info, body in entries))


def fixture(root: Path) -> Path:
    """Write the fixture pack under `root`."""
    root.mkdir(parents=True)
    (root / ".gitmodules").write_text(
        '[submodule "examples"]\n\tpath = examples\n\turl = https://example.invalid/Corpus.git\n',
        encoding="utf-8")
    for rel, text in {**{f"examples/{k}": v for k, v in CORPUS.items()},
                      **{f"lib/{k}": v for k, v in SOURCES.items()},
                      "lib/README.md": page()}.items():
        (root / rel).parent.mkdir(parents=True, exist_ok=True)
        (root / rel).write_text(text, encoding="utf-8")
    return root


def edit(root: Path, rel: str, old: str, new: str) -> None:
    """Replace one occurrence of `old` in a fixture file, refusing a miss."""
    path = root / rel
    text = path.read_text(encoding="utf-8")
    if text.count(old) != 1:
        msg = f"the fixture's {rel} holds {old!r} {text.count(old)} times"
        raise AssertionError(msg)
    path.write_text(text.replace(old, new), encoding="utf-8")


def plant_library(root: Path) -> None:
    """A library directory the page has no entry for."""
    (root / "lib/lib_d").mkdir()
    (root / "lib/lib_d/pkg.metta").write_text('(= (package requires) "lib.metta")\n')
    (root / "lib/lib_d/lib.metta").write_text("(= (d-id $x) $x)\n")


#: The name of every check main() made, so the tally counts what ran.
CHECKED: list[str] = []

#: Each page-level case: what it plants, and the text its finding must hold.
PAGE_CASES: tuple[tuple[str, Callable[[Path], None], str], ...] = (
    ("an entry without an example",
     lambda root: edit(root, "lib/README.md",
                       f"Its example ([source]({BASE}ch/03-c.metta#L1-L2)).", "No example."),
     "lib_c has no worked example"),
    ("a fence that is not its lines",
     lambda root: edit(root, "lib/README.md", "!(test (a-double 3) 6)\n```",
                       "!(test (a-double 3) 7)\n```"),
     "the fence is not those lines"),
    ("a range starting on a comment",
     lambda root: edit(root, "lib/README.md", "01-a.metta#L2-L6", "01-a.metta#L1-L6"),
     "line 1 is not code"),
    ("a runnable excerpt fenced text",
     lambda root: edit(root, "lib/README.md", "```metta\n!(import! &self (library lib_c))",
                       "```text\n!(import! &self (library lib_c))"),
     "readme-fences can run is fenced `metta`"),
    ("an excerpt reading a fixture fenced metta",
     lambda root: edit(root, "lib/README.md", '```text\n!(import_prolog_functions_from_file',
                       '```metta\n!(import_prolog_functions_from_file'),
     "is fenced `text`"),
    ("a listed head no source spells",
     lambda root: edit(root, "lib/README.md", "| Heads | `c-id` |", "| Heads | `c-id`, `c-gone` |"),
     "lib_c lists `c-gone`"),
    ("a wrong section count",
     lambda root: edit(root, "lib/README.md", "| [Only](#only) | 3 |", "| [Only](#only) | 4 |"),
     "the section table says Only holds 4"),
    ("a stale superset table",
     lambda root: edit(root, "lib/README.md", "| `lib_c` | `lib_b`, which it requires |\n", ""),
     "superset table disagrees"),
    # minimal_metta_lib's case: a manifest makes a library whatever it is named.
    ("a manifest directory not named lib_*",
     lambda root: ((root / "lib/extra").mkdir(),
                   (root / "lib/extra/pkg.metta").write_text('(= (package requires) "lib.metta")\n')),
     "extra is a library directory with no entry"),
)


def expect(problems: list[str], name: str, found: list[str], wanted: str | None) -> None:
    """Record a problem unless `found` is exactly what the case expects."""
    CHECKED.append(name)
    if wanted is None:
        if found:
            problems.append(f"{name}: expected no finding, got {found}")
    elif not any(wanted in finding for finding in found):
        problems.append(f"{name}: no finding says {wanted!r}; got {found}")


def main() -> int:
    """Run the control and every planted case; report what went unseen."""
    problems: list[str] = []
    with tempfile.TemporaryDirectory(prefix="library-readme-selftest-") as scratch:
        base = fixture(Path(scratch) / "base")
        pack = checked.read_pack(base / "lib")
        CHECKED.append("the superset rule over a requirement")
        if checked.superset(pack) != {"lib_b": None, "lib_c": "lib_b"}:
            problems.append(f"the superset rule read {checked.superset(pack)}, where lib_b "
                            f"writes a sequence variable and lib_c requires lib_b")
        expect(problems, "the unplanted fixture", checked.page_findings(base, pack), None)
        for index, (name, plant, wanted) in enumerate(PAGE_CASES):
            root = Path(scratch) / f"case{index}"
            shutil.copytree(base, root)
            plant(root)
            expect(problems, name, checked.page_findings(root, pack), wanted)

        # The two cases that change a library directory need the engine to
        # read the changed pack, which is what the lane itself does.
        root = Path(scratch) / "planted-library"
        shutil.copytree(base, root)
        plant_library(root)
        found = checked.findings(root)
        expect(problems, "a library directory without an entry", found,
               "lib_d is a library directory with no entry")
        # A pattern gap, and the two signature spellings upstream refuses, each
        # alone in lib_a, have to put lib_a in the table.
        for name, declaration in (
                ("a sequence variable", "(= (a-double $x (:seg $more)) (* 2 $x))\n"),
                ("a variadic signature", "(: a-double (-> (:seg Number) Number))\n"),
                ("an annotated arrow", "(: a-double (-[det]-> Number Number))\n")):
            root = Path(scratch) / f"planted-{name.replace(' ', '-')}"
            shutil.copytree(base, root)
            with (root / "lib/lib_a/lib.metta").open("a", encoding="utf-8") as source:
                source.write(declaration)
            expect(problems, f"a library that starts writing {name}",
                   checked.findings(root), "superset table disagrees")

        # --write: an empty fence is filled, a moved excerpt followed, and a
        # changed one refused rather than rewritten.
        root = Path(scratch) / "write"
        shutil.copytree(base, root)
        text = (root / "lib/README.md").read_text(encoding="utf-8")
        text = re.sub(r"(01-a\.metta#L2-L6\)\)\.\n\n```metta\n).*?```", r"\1```", text,
                      flags=re.DOTALL)
        (root / "lib/README.md").write_text(text, encoding="utf-8")
        edit(root, "examples/ch/03-c.metta", "!(import!", "; moved down\n\n!(import!")
        refused = checked.write_page(root, pack)
        expect(problems, "--write over an empty fence and a moved excerpt", refused, None)
        expect(problems, "the page --write refreshed", checked.page_findings(root, pack), None)
        CHECKED.append("--write following a moved excerpt")
        if "03-c.metta#L3-L4" not in (root / "lib/README.md").read_text(encoding="utf-8"):
            problems.append("--write did not move lib_c's range to where its excerpt went")
        edit(root, "examples/ch/01-a.metta", "(a-double 3) 6", "(a-double 3) 60")
        expect(problems, "--write over a changed excerpt", checked.write_page(root, pack),
               "no longer hold the fence's text")
    for problem in problems:
        print(f"  {problem}")
    print(f"library-readme-selftest: {len(problems)} finding(s) over {len(CHECKED)} check(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
