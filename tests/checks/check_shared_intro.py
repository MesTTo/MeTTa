"""Purpose: hold the shared "What MeTTa is" introduction identical wherever it appears.

Each repository here is published on its own and read on its own, so each
front page has to tell a newcomer what MeTTa is rather than assuming they
arrived through another one. That means the same paragraphs deliberately
appear in several READMEs, and deliberate duplication is still duplication: on
2026-09-22 the root page and lib/README.md described lib_crypto two different
ways, because nothing compared them.

So the copies are marked and compared. A block between
`<!-- shared:what-is-metta -->` and its closing marker must be byte-identical
in every file that carries one, and the front pages below must carry it.

WHICH PAGES is declared rather than derived, because it is a decision and not
a fact: these are the four a reader arrives at cold, the language's own page
and the three surfaces it is written through. `.gitmodules` cannot answer it,
since lib, examples and ext are components too and are not front doors, and
nothing in the tree declares a surface apart from a backend. A file outside
this list that carries the marker is still held to the same text, so a fifth
copy is allowed and cannot drift.

Assumes: run from a checkout; submodules populated, or their pages are
    reported absent rather than skipped.
Guarantees:
  - a copy whose text differs from the others is reported, naming both
    [tested: tests/checks/check_shared_intro_selftest.py]
  - a front page missing the block entirely is reported
    [tested: tests/checks/check_shared_intro_selftest.py]
  - an unclosed or duplicated marker is reported rather than read as absent
    [tested: tests/checks/check_shared_intro_selftest.py]
Fails when: a submodule is not populated. Its page is reported missing, which
    is the same finding a deleted block gives, because from here they are the
    same thing: the page a reader would arrive at does not carry the intro.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

#: The pages a reader arrives at cold. The language's own, and the three
#: surfaces it is written through; a backend and a library pack are reached
#: from one of these rather than landed on.
FRONT_PAGES = (
    "README.md",
    "extensions/python/README.md",
    "extensions/node/README.md",
    "extensions/cmetta/README.md",
)

OPEN = "<!-- shared:what-is-metta -->"
CLOSE = "<!-- /shared:what-is-metta -->"
BLOCK = re.compile(re.escape(OPEN) + r"\n(.*?)" + re.escape(CLOSE), re.DOTALL)


def carriers() -> list[Path]:
    """Every tracked README that could hold the block: the front pages and each repository root."""
    found = list(dict.fromkeys(
        [ROOT / name for name in FRONT_PAGES]
        + sorted(ROOT.glob("*/README.md"))
        + sorted(ROOT.glob("extensions/*/README.md"))
    ))
    return [path for path in found if path.is_file()]


def findings() -> list[str]:
    """Everything wrong with the shared block across the pages that carry it."""
    problems: list[str] = []
    texts: dict[Path, str] = {}
    for path in carriers():
        body = path.read_text(encoding="utf-8")
        opens, closes = body.count(OPEN), body.count(CLOSE)
        if opens == 0 and closes == 0:
            continue
        where = path.relative_to(ROOT)
        if opens != 1 or closes != 1:
            problems.append(
                f"{where}: {opens} opening and {closes} closing marker(s); the block is "
                f"one region, and a second one cannot be compared against anything"
            )
            continue
        found = BLOCK.search(body)
        if not found:
            problems.append(f"{where}: the closing marker comes before the opening one")
            continue
        texts[path] = found.group(1)

    for name in FRONT_PAGES:
        path = ROOT / name
        if not path.is_file():
            problems.append(f"{name}: the front page is not in the tree, so a reader of it gets no intro")
        elif path not in texts:
            problems.append(
                f"{name}: carries no {OPEN} block, and it is a page a reader arrives at "
                f"cold, so it has to say what MeTTa is"
            )

    if len(set(texts.values())) > 1:
        # Compared against the ROOT copy rather than pairwise, so N pages that
        # have drifted give N-1 findings naming what to fix instead of N*(N-1)/2
        # naming each other.
        reference = texts.get(ROOT / "README.md")
        if reference is None:
            reference = next(iter(texts.values()))
        for path, text in texts.items():
            if text != reference:
                problems.append(
                    f"{path.relative_to(ROOT)}: the shared intro differs from README.md's; "
                    f"it is one text in several places and every copy has to be the same"
                )
    return problems


def main() -> int:
    """Report the defects and exit nonzero if there are any."""
    problems = findings()
    for one in problems:
        print(one)
    carrying = sum(1 for path in carriers() if OPEN in path.read_text(encoding="utf-8"))
    print(
        f"shared-intro: {len(problems)} defect(s), over {carrying} page(s) carrying the "
        f"block and {len(FRONT_PAGES)} that must"
    )
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
