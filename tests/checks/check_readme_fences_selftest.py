"""Purpose: prove check_readme_fences reports a fence that does not run.

A check nobody has seen fail is a check that might be looking at nothing, which
is how the tools/ move disarmed this repository's process bound and how the
engine/c move disarmed the guard over eighteen unbounded lanes. So each case
plants a fence with a known defect in a fixture README and requires the finding
to name it.

Assumes: a python that can import `metta`, and `tools/bounded.sh`.
Guarantees:
  - a fence calling a head that does not exist is reported
    [tested: tests/checks/check_readme_fences_selftest.py; commit=c6ed562a1a6f964aba906206f2558489b107dc24]
  - a fence relying on an import an EARLIER fence performed is reported, which
    is the defect five fences in the MORK page actually had
    [tested: tests/checks/check_readme_fences_selftest.py; commit=c6ed562a1a6f964aba906206f2558489b107dc24]
  - a fence naming a network URL is reported WITHOUT being run
    [tested: tests/checks/check_readme_fences_selftest.py; commit=c6ed562a1a6f964aba906206f2558489b107dc24]
  - a fence that runs is not reported
    [tested: tests/checks/check_readme_fences_selftest.py; commit=c6ed562a1a6f964aba906206f2558489b107dc24]
Fails when: run outside a checkout, which it reports.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_readme_fences as checked

CASES: tuple[tuple[str, str, str | None], ...] = (
    (
        "a head that does not exist",
        "!(test (no-such-head 1) 2)\n",
        "does not run",
    ),
    (
        "an import the reader does not have",
        # lib_mm2's own operators, without the import an earlier fence did.
        "!(test (collapse (? (edge $x $y) ($x $y))) ())\n",
        "does not run",
    ),
    (
        "a fence that reaches the network",
        '!(git-import! "https://github.com/patham9/faiss_ffi" "build.sh")\n',
        "network",
    ),
    (
        "a fence that runs",
        "!(test (+ 1 1) 2)\n",
        None,
    ),
)


def main() -> int:
    """Run every planted case and report the ones that went unseen."""
    problems: list[str] = []
    for name, body, expected in CASES:
        finding = checked.run_one(("fixture/README.md", 0, body))
        if expected is None:
            if finding is not None:
                problems.append(f"{name}: reported a fence that runs: {finding}")
            continue
        if finding is None:
            problems.append(f"{name}: went unreported, so the check cannot see it")
        elif expected not in finding:
            problems.append(f"{name}: reported, but did not say {expected!r}: {finding}")
    for problem in problems:
        print(f"  {problem}")
    print(f"readme-fences-selftest: {len(problems)} finding(s) over {len(CASES)} planted case(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
