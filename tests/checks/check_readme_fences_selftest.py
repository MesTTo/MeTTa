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
  - a temporary directory a fence mints is inside the fence's own directory
    [tested 2026-09-25T16:13:38+10:00: tests/checks/check_readme_fences_selftest.py]
  - a fence DEMONSTRATING a refusal, whose comment is the message the engine
    raises, is not reported, and one whose comment is not that message still is
    [tested: tests/checks/check_readme_fences_selftest.py; commit=c6ed562a1a6f964aba906206f2558489b107dc24]
  - the repository root README is among the pages run, so no fence of any
    README shares an engine with what runs after it
    [tested 2026-09-25T12:45:49+10:00: tests/checks/check_readme_fences_selftest.py]
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
    (
        # A temporary directory the fence mints has to be inside the fence's own
        # directory, which is removed with it. Without the fence's own TMP it is
        # minted wherever the caller's TMP points, and this assertion fails.
        "a temporary directory minted inside the fence",
        "!(import! &self (library lib_file))\n"
        "!(import! &self (library lib_string))\n"
        '!(test (string-starts-with (path-resolve (temp-dir! "fence")) (path-resolve ".")) True)\n',
        None,
    ),
    (
        # The page DEMONSTRATES a guard, so the run must fail and the comment
        # under the form must be the message it failed with.
        "a refusal the fence states",
        "!(add-translator-rule! if)\n"
        "; No permission to register metta_protected_core `if'\n",
        None,
    ),
    (
        # And the excuse has to be earned: a comment long enough to be a claim
        # but not the message is still a broken fence, which is what stops the
        # branch above from becoming a blanket skip for anything commented.
        "a refusal the fence states wrongly",
        "!(add-translator-rule! if)\n"
        "; this comment is long enough to be a claim and is not the message\n",
        "does not run",
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
    # The root README was exempted as covered elsewhere, and elsewhere ran its
    # fences inside a pytest worker, where one left &Point behind for the rest
    # of that worker's items.
    if "README.md" not in checked.readmes():
        problems.append("the repository root README is not among the pages run, "
                        "so its fences share an engine with whatever runs them")
    for problem in problems:
        print(f"  {problem}")
    print(f"readme-fences-selftest: {len(problems)} finding(s) over {len(CASES)} planted case(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
