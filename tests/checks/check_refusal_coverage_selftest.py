"""Purpose: hold check_refusal_coverage to the three things it can get wrong.

All three were live. Counting witnesses per SUITE called read-file! unwitnessed
while lib_text.plt asserted it. Matching `refus*` as a promise reported five
heads whose prose was about a sibling, not themselves. And a witness is written
three ways in these suites, so recognising one spelling misses the others.

Assumes: nothing about the real tree; each case plants its own library and
    suite text, so a change to either cannot make this pass or fail for a
    reason that is not about the checker.
Guarantees:
  - a promise about the documented head is reported when nothing witnesses it,
    or the check could not fail at all [tested: this file; commit=WORKTREE]
  - a witness in ANY suite counts [tested: this file; commit=WORKTREE]
  - `refuses` in prose about a sibling is not a promise
    [tested: this file; commit=WORKTREE]
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_refusal_coverage as checker  # noqa: E402


def _plant(root: Path, doc: str, suite: str) -> Path:
    """A tree holding one library and one suite, and nothing else."""
    (root / "engine").mkdir(parents=True, exist_ok=True)
    lib = root / "lib" / "lib_planted"
    lib.mkdir(parents=True, exist_ok=True)
    (lib / "lib_planted.pl").write_text(doc, encoding="utf-8")
    suites = root / "tests" / "prolog" / "suites" / "libraries"
    suites.mkdir(parents=True, exist_ok=True)
    (suites / "lib_planted.plt").write_text(suite, encoding="utf-8")
    return root


PROMISED = "%! 'thing-do!'(+A:any) is det.\n%\n% A missing thing raises.\n"


def cases() -> list[tuple[str, str, str, int]]:
    """Each case: the doc, the suite, what it is for, how many findings it owes."""
    return [
        (PROMISED, "    true.\n", "promised and unwitnessed", 1),
        (PROMISED, "    must_throw('thing-do!'(X), error(_, _)).\n",
         "witnessed by must_throw", 0),
        (PROMISED, "    test(t, [throws(error(_, _))]) :- 'thing-do!'(X).\n",
         "witnessed by plunit throws", 0),
        (PROMISED, "    'thing-not-found'('thing-do!', a, b).\n",
         "witnessed by a named refusal term", 0),
        # The five false positives: prose using `refuses` about a sibling.
        ("%! 'thing-list'(-L:list) is det.\n%\n% The same list its refusal names.\n",
         "    true.\n", "a sibling's refusal is not a promise", 0),
    ]


def main() -> int:
    """Run every case against a planted tree and report the ones that disagree."""
    bad = 0
    with tempfile.TemporaryDirectory() as scratch:
        for index, (doc, suite, what, owed) in enumerate(cases()):
            root = _plant(Path(scratch) / str(index), doc, suite)
            found = checker.findings(root)
            if len(found) != owed:
                print(f"  {what}: expected {owed}, got {len(found)}: {found}")
                bad += 1
    print(f"refusal-coverage-selftest: {len(cases()) - bad} of {len(cases())} cases hold")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
