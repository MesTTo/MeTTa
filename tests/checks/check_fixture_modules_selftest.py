"""Purpose: prove `fixture_modules.sibling_closure` answers what a tree must carry.

Measured over a tree planted for the purpose rather than over this one.

Every case here plants its own modules, so the answers do not move when a real
checker gains an import. The one case read against the repository is the one
that matters in practice: the entry each fixture actually copies must reach
`gate_layout.py`, which is the import that broke three fixtures at once.

Assumes: a writable scratch directory under `ai-tmp/`.
Guarantees:
  - transitive siblings are reached, and a name that is not a file beside the
    source is dropped [tested 2026-09-25T04:18:23+10:00: this file]
  - an import cycle terminates [tested 2026-09-25T04:18:23+10:00: this file]
Fails when: a checker reaches a module without an import statement naming it;
    that is outside what reading the source can decide and the module says so.
"""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))

from fixture_modules import HERE, sibling_closure  # noqa: E402  -- installed above

#: Each case is a planted tree and the closure its entry must answer. The
#: dimensions are independent -- how a module is imported, and what the import
#: reaches -- so they are named rather than crossed.
CASES: tuple[tuple[str, dict[str, str], tuple[str, ...], tuple[str, ...]], ...] = (
    (
        "a plain import of a sibling is followed",
        {"a.py": "import b\n", "b.py": ""},
        ("a.py",), ("a.py", "b.py"),
    ),
    (
        "a from-import of a sibling is followed",
        {"a.py": "from b import thing\n", "b.py": "thing = 1\n"},
        ("a.py",), ("a.py", "b.py"),
    ),
    (
        "the closure is TRANSITIVE, which is the case three hand-kept lists lost",
        {"a.py": "import b\n", "b.py": "import c\n", "c.py": ""},
        ("a.py",), ("a.py", "b.py", "c.py"),
    ),
    (
        "a standard-library import is not a sibling and is dropped",
        {"a.py": "import json\nimport os.path\nfrom pathlib import Path\n"},
        ("a.py",), ("a.py",),
    ),
    (
        "a cycle terminates rather than recurring",
        {"a.py": "import b\n", "b.py": "import a\n"},
        ("a.py",), ("a.py", "b.py"),
    ),
    (
        "an entry that is not there is dropped, not raised",
        {"a.py": ""},
        ("a.py", "absent.py"), ("a.py",),
    ),
    (
        "a relative import names no sibling file and is dropped",
        {"a.py": "from . import b\n", "b.py": ""},
        ("a.py",), ("a.py",),
    ),
    (
        "a module that will not parse is carried but not followed",
        {"a.py": "import b\n", "b.py": "def (\n"},
        ("a.py",), ("a.py", "b.py"),
    ),
)


def findings() -> list[str]:
    """Every case whose answer is not the one it states."""
    out: list[str] = []
    with tempfile.TemporaryDirectory(prefix="ai-fixture-modules-", dir=ROOT / "ai-tmp") as scratch:
        for index, (why, files, entries, wanted) in enumerate(CASES):
            # One directory per case, so a name planted by one case cannot be
            # reached by the next and make a dropped import look followed.
            tree = Path(scratch) / f"case-{index}"
            tree.mkdir(parents=True, exist_ok=True)
            for name, text in files.items():
                (tree / name).write_text(text, encoding="utf-8")
            answered = sibling_closure(entries, tree)
            if answered != wanted:
                out.append(f"{why}: answered {answered}, wanted {wanted}")

    # The repository's own case, and the reason this module exists: the entry
    # each fixture copies must reach gate_layout.py, because evidence_runners
    # imports it and a fixture tree without it cannot import the checker.
    for entry in ("check_evidence_tags.py", "check_spec_status.py"):
        answered = sibling_closure((entry,), HERE)
        if "gate_layout.py" not in answered:
            out.append(f"{entry} does not reach gate_layout.py, which evidence_runners imports: {answered}")
    return out


def main() -> int:
    """Report every case whose answer moved."""
    problems = findings()
    for problem in problems:
        print(f"  {problem}")
    print(f"fixture-modules selftest: {len(problems)} defect(s), over {len(CASES)} planted trees "
          f"and the two entries this repository's fixtures copy")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
