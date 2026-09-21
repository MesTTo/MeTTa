"""Purpose: hold check_refusal_coverage to the two things it can get wrong.

Both were live. Matching only the HEAD of a refusal call reported four
operations that were covered, because a suite may write
`must_throw(findall(Row, 'csv-read!'(File, Row), _), ...)` and the operation is
then nested rather than first [measured 2026-09-21: 24 reported against 20
real]. And reporting every use would name any head a fixture touches once,
which is not the suite owning it.

Assumes: nothing about the real suites; each case plants its own .plt text, the
    way check_process_bounds_selftest does, so a change to the tree cannot make
    this pass or fail for a reason that is not about the checker.
Guarantees:
  - a refusal nested inside another goal counts as coverage
    [tested: this file; commit=WORKTREE]
  - a head used fewer than THRESHOLD times is not reported
    [tested: this file; commit=WORKTREE]
  - a head exercised often and never refused IS reported, or the check could
    not fail at all, which is the way a checker dies quietly
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


def _plant(root: Path, body: str) -> Path:
    """A suite directory holding one planted .plt, so no case reads the tree."""
    suites = root / "libraries"
    suites.mkdir(parents=True, exist_ok=True)
    (suites / "lib_planted.plt").write_text(body, encoding="utf-8")
    return suites


def _uses(name: str, count: int) -> str:
    return "\n".join(f"    '{name}'(X{n})." for n in range(count))


def cases() -> list[tuple[str, str, int]]:
    """Each case: what it plants, what it is for, how many findings it owes."""
    nested = _uses("thing-do!", 4) + \
        "\n    must_throw(findall(R, 'thing-do!'(F, R), _), error(_, _)).\n"
    return [
        # The case the check exists for. Without it the check cannot fail at all,
        # which is how a checker dies quietly.
        (_uses("thing-do!", 4), "exercised and never refused", 1),
        # The miss that over-reported four covered operations on 2026-09-21.
        (nested, "refusal nested inside another goal", 0),
        # One incidental use in a fixture is not the suite owning the head.
        (_uses("thing-do!", checker.THRESHOLD - 1), "below the threshold", 0),
        # No `!`, no resource, no failure path to assert.
        (_uses("pure-thing", 6), "a total operation is not the subject", 0),
    ]


def main() -> int:
    """Run every case against a planted tree and report the ones that disagree."""
    bad = 0
    with tempfile.TemporaryDirectory() as scratch:
        for index, (body, what, owed) in enumerate(cases()):
            suites = _plant(Path(scratch) / str(index), body)
            found = checker.findings(suites)
            if len(found) != owed:
                print(f"  {what}: expected {owed} finding(s), got {len(found)}: {found}")
                bad += 1
    print(f"refusal-coverage-selftest: {len(cases()) - bad} of {len(cases())} cases hold")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
