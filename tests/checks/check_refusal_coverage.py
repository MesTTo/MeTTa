"""Purpose: name every refusal a library CONTRACT promises and no suite witnesses.

A `%!` block that says an operation raises, refuses, or that something "is an
error" has made a promise. Whether any test holds it to that promise is a
different question, and the two are never written side by side, so a promise
nobody witnesses looks exactly like a promise nobody made. Printed as a table
it is one line per unwitnessed claim.

The contract is the right subject, not the operations a suite happens to
exercise. An exercised head may be total and have no refusal to assert, which
made the first version of this check report eighteen heads of which most were
noise; a documented promise is a claim the library itself makes and a missing
witness is unambiguous.

It earns its place by what it found the day it was written. `lib_csv_surface`
refused none of csv-read!, csv-space or csv-append!, and writing those
witnesses showed csv-space accepting a DIRECTORY, because its path probe opened
the source with a goal of `true` and POSIX open(2) on a directory succeeds.
`lib_file` promised refusals for read-file! and list-dir! that nothing
asserted, and writing those showed four operations throwing a bare
existence_error instead of one of library_refusal/1, naming neither the caller
nor a remedy [measured 2026-09-21; both fixed].

Assumes: run inside a checkout.
Guarantees:
  - a witness counts from ANY suite, because a library's refusal may be
    asserted by a sibling suite: read-file! is promised in lib_file and
    witnessed in lib_text.plt, and counting per suite called it unwitnessed
    [tested: tests/checks/check_refusal_coverage_selftest.py; commit=9f6d98fcb24cd65e09a6b5a6eeb79826365361d7]
  - a witness counts in either spelling the suites use, `must_throw(...)`,
    plunit's `throws(...)`, a named refusal term carrying the operation, or a
    row in library_refusals.plt's case table
    [tested: tests/checks/check_refusal_coverage_selftest.py; commit=a6fe346c7bd065451d8fd1c085a54cc7ce97a63f]
  - a raise verb belonging to the caller's body is not a promise by the head
    [tested: tests/checks/check_refusal_coverage_selftest.py; commit=e8180b7cdd1ba6fe43edde1a9f885191fd9b8570]
Fails when: nothing. This reports; the count is the burn-down surface.
Open Obligations:
  To Do: gate at zero once the 24 open claims are witnessed
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

#: Derived, not counted.
ROOT = next(parent for parent in Path(__file__).resolve().parents
            if (parent / "engine").is_dir() and (parent / "lib").is_dir())

#: A `%!` block and the comment lines under it: the head it documents, then its
#: prose.
BLOCK = re.compile(r"((?:^%!.*\n)+)((?:^%.*\n)*)", re.MULTILINE)
HEAD = re.compile(r"^%!\s+\'?([a-z][a-z0-9-]*!?)\'?\(", re.MULTILINE)
#: The words a contract uses to promise a refusal OF THE HEAD IT DOCUMENTS.
#: `refus*` is deliberately absent: the libraries use it about a sibling far
#: more often than about the documented head, so it reported platform-keys and
#: process-signals for saying "the same list its refusal names" and
#: http-methods for "A request refuses a method outside this catalog", none of
#: which promise anything about the head. `raises` and `is an error` take the
#: documented head as their subject [measured 2026-09-21: 24 findings with
#: `refus*`, 19 without, and the five removed were all false].
PROMISE = re.compile(r"\b(raises?|is an error)\b", re.IGNORECASE)
#: A raise verb whose subject is the CALLER'S body, not the documented head.
#: A scope-taking combinator describes cleanup that happens "when the body
#: raises", which promises nothing about the head itself refusing. Stripping
#: the clause before testing for a promise keeps with-file, whose sentence
#: "A close failure raises unless the body already raised" still promises one,
#: and drops with-temp-dir, whose only mention is the body's [measured
#: 2026-09-21: three mentions in the tree, all in lib_file, and with-temp-dir
#: was reported as an unwitnessed promise it never made].
OTHER_ACTOR = re.compile(r"\bthe (?:body|caller)\b[^.;]*?\brais(?:e|es|ed)\b", re.IGNORECASE)
#: A refusal term: the library names them for what they refuse.
REFUSAL_TERM = r"\'[a-z-]*(?:error|refus|not-found|denied|mismatch|exists|overlap)[a-z-]*\'"


def _suite_text(root: Path) -> str:
    """Every suite as one string: a witness anywhere counts."""
    return " ".join(path.read_text(encoding="utf-8", errors="replace")
                    for path in sorted((root / "tests" / "prolog" / "suites").glob("*/*.plt")))


def _witnessed(operation: str, suites: str) -> bool:
    """Any spelling the suites use to assert that this operation refuses.

    A plunit test carries `throws(...)` in its OPTIONS and calls the operation
    in its BODY, lines apart, so a single-line window misses it: six witnesses
    written that way left the count unmoved at 19 [measured 2026-09-21]. The
    window is the clause, `test(...) ... .`, not the line.
    """
    name = re.escape(operation)
    if re.search(REFUSAL_TERM + r"\(\'" + name + r"\'", suites):
        return True
    if re.search(r"must_throw\(\s*\'" + name + r"\'", suites):
        return True
    # A row in library_refusals.plt's table: the head is the row's first
    # argument, and the law runs every row. not_inducible rows count too,
    # because that suite asserts the head still SUCCEEDS here, so losing the
    # provider turns the row red rather than leaving the promise unchecked.
    if re.search(r"(?:refusal_case|not_inducible)\(\s*\'" + name + r"\'", suites):
        return True
    # a whole test clause whose options promise a throw and whose body calls it
    for clause in re.finditer(r"^test\(.*?(?<!\.)\.\s*$", suites, re.DOTALL | re.MULTILINE):
        text = clause.group(0)
        if "throws(" in text and re.search(r"\'" + name + r"\'", text):
            return True
    return False


def findings(root: Path = ROOT) -> list[str]:
    """One line per documented refusal that no suite holds the library to."""
    suites = _suite_text(root)
    out: list[str] = []
    for library in sorted(root.glob("lib/lib_*/lib_*.pl")):
        text = library.read_text(encoding="utf-8", errors="replace")
        seen: set[str] = set()
        for heads, prose in BLOCK.findall(text):
            body = " ".join(line.lstrip("% ").rstrip() for line in prose.splitlines())
            if not PROMISE.search(OTHER_ACTOR.sub(" ", body)):
                continue
            for operation in HEAD.findall(heads):
                if operation in seen or _witnessed(operation, suites):
                    continue
                seen.add(operation)
                out.append(f"{library.parent.name}: {operation} is documented to refuse "
                           f"and no suite witnesses it -- {body[:70]}")
    return out


def main() -> int:
    """Report the table, and say what an unwitnessed promise means."""
    problems = findings()
    for problem in problems:
        print(f"  {problem}")
    print(f"refusal-coverage: {len(problems)} documented refusal(s) with no witness")
    return 0


if __name__ == "__main__":
    sys.exit(main())
