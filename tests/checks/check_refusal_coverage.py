"""Purpose: name every effectful library head the suites exercise and never refuse.

A suite written as prose hides its own gaps. Which operations a library test
file EXERCISES and which it ever asserts a REFUSAL for are two sets, and the
difference is invisible while the tests are read one at a time: a missing
refusal looks exactly like a test nobody wrote. Printed as a table it is one
line per empty cell.

That difference found a real defect the day this was written. `lib_csv_surface`
exercised `csv-read!` nine times, `csv-space` four and `csv-append!` eight
while refusing none of them, against five refusals each for `csv-snapshot!` and
`csv-write!`. Writing the three missing ones showed `csv-space` accepting a
DIRECTORY, because its path probe opened the source with a goal of `true` and
POSIX open(2) on a directory succeeds -- read(2) is what answers EISDIR
[measured 2026-09-21; fixed in lib_csv.pl by making the probe peek a byte].

An effectful head is the subject: a `!` name holds a resource or mutates
something, so it has a failure path by construction. A total operation has no
refusal to assert and would be noise here.

Assumes: run from a checkout; the suites live under
    tests/prolog/suites/libraries/.
Guarantees:
  - a refusal counts wherever it appears inside `must_throw(...)` or a plunit
    `throws(...)`, including nested in `findall/3` or `let`, because matching
    only the head of the call under-reported four operations that WERE covered
    [measured 2026-09-21: 24 reported against 20 real]
    [tested: tests/checks/check_refusal_coverage_selftest.py; commit=WORKTREE]
  - an operation used fewer than THRESHOLD times is not reported, because one
    incidental use in a fixture is not evidence the suite owns that operation
Fails when: nothing. This reports; the count is the burn-down surface.
Open Obligations:
  To Do: gate this at zero once the 20 open cells are closed
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import collections
import re
import sys
from pathlib import Path

#: Derived, not counted.
ROOT = next(parent for parent in Path(__file__).resolve().parents
            if (parent / "engine").is_dir() and (parent / "lib").is_dir())
SUITES = ROOT / "tests" / "prolog" / "suites" / "libraries"

#: An effectful head: `!` is this language's mark for one, so the set needs no
#: list beside it that would then have to be kept equal by hand.
EFFECTFUL = re.compile(r"'([a-z][a-z0-9-]*!)'\s*\(")
REFUSAL = re.compile(r"(?:must_throw|throws)\s*\(")
NAME = re.compile(r"'([a-z][a-z0-9-]*!)'")

#: Below this a use is incidental setup rather than the suite owning the head.
THRESHOLD = 3


def _refused(text: str) -> set[str]:
    """Every effectful head named anywhere inside a refusal, brackets balanced."""
    found: set[str] = set()
    for opening in REFUSAL.finditer(text):
        index, depth = opening.end(), 1
        while index < len(text) and depth:
            depth += (text[index] == "(") - (text[index] == ")")
            index += 1
        found |= set(NAME.findall(text[opening.end():index]))
    return found


def findings(suites: Path = SUITES) -> list[str]:
    """One line per effectful head a suite exercises and never refuses."""
    out: list[str] = []
    for suite in sorted(suites.glob("*.plt")):
        text = suite.read_text(encoding="utf-8", errors="replace")
        used = collections.Counter(EFFECTFUL.findall(text))
        refused = _refused(text)
        for operation, count in sorted(used.items(), key=lambda row: -row[1]):
            if count >= THRESHOLD and operation not in refused:
                out.append(f"{suite.name}: {operation} is exercised {count} times "
                           f"and refused none; its failure path is untested")
    return out


def main() -> int:
    """Report the table, and say what an empty cell means."""
    problems = findings()
    for problem in problems:
        print(f"  {problem}")
    print(f"refusal-coverage: {len(problems)} effectful head(s) with no failure test")
    return 0


if __name__ == "__main__":
    sys.exit(main())
