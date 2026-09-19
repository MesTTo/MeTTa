"""Purpose: refuse a shipped library that tells the engine to load its Prolog body.

A library used to write an instruction:

    !(import_prolog_functions_from_file (library lib_x.pl) (head ...))

and now writes a description:

    (= (package backing) (prolog (library lib_x.pl) (head ...)))

The row is data. Any implementation that can read atoms can read it, decide
whether it can perform it, perform it through a registrant it does not name,
and refuse the rest by name; the call was an instruction only this engine
understands [source: docs/journal/2026-09-09-packages-are-equations.md, law 14].

`lib_import` is exempt and must stay a call. It DEFINES
`import_prolog_functions_from_file` as an equation and applies it to load its
own Prolog half, so it cannot reach a claim whose body is that operation. That
is the bootstrap bottoming out at a library that requires nothing.

The scan strips comments and strings before looking, because the call is
MENTIONED in the comments of libraries that do not make it: `lib_memo` and
`lib_zar` both discuss it while importing one head at a time. A pattern over
the raw text reports those and reads as a false alarm on the first run.

Assumes: the shipped libraries are at `lib/*/*.metta`.
Guarantees:
  - a library making the call is reported with its line
    [tested: tests/checks/check_package_backings_selftest.py; commit=WORKTREE]
  - the same text inside a comment or a string is NOT reported
    [tested: tests/checks/check_package_backings_selftest.py; commit=WORKTREE]
  - `lib_import` is exempt, being where the operation is defined
    [tested: tests/checks/check_package_backings_selftest.py; commit=WORKTREE]
  - an empty roster is refused, because a pass that found nothing to check
    reads exactly like a pass that checked everything
    [tested: tests/checks/check_package_backings_selftest.py; commit=WORKTREE]
Fails when: run outside a checkout with a lib/ directory, which it reports.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import sys
from pathlib import Path

#: Derived, not counted, so moving this file cannot silently point it elsewhere.
ROOT = next(parent for parent in Path(__file__).resolve().parents
            if (parent / "engine").is_dir() and (parent / "lib").is_dir())
LIBRARIES = ROOT / "lib"
CALL = "!(import_prolog_functions_from_file"
#: Where the operation is defined and applied to its own Prolog half.
EXEMPT = ("lib_import",)


def code_only(source: str) -> str:
    """The source with comments and string contents blanked, keeping offsets.

    Blanked rather than removed so a reported position still names the line it
    came from. A `;` opens a comment to end of line, and neither a `;` nor a
    parenthesis inside a string means anything.
    """
    out, index, in_string, in_comment = [], 0, False, False
    while index < len(source):
        char = source[index]
        if in_comment:
            out.append("\n" if char == "\n" else " ")
            in_comment = char != "\n"
        elif in_string:
            if char == "\\":
                out.append("  ")
                index += 2
                continue
            out.append(" ")
            in_string = char != '"'
        elif char == '"':
            in_string = True
            out.append(" ")
        elif char == ";":
            in_comment = True
            out.append(" ")
        else:
            out.append(char)
        index += 1
    return "".join(out)


def findings(libraries: Path) -> list[str]:
    """Each shipped library that still tells the engine to load its body."""
    if not libraries.is_dir():
        message = f"no libraries to check: {libraries}"
        raise SystemExit(message)
    sources = sorted(libraries.glob("*/*.metta"))
    if not sources:
        message = f"no libraries found under {libraries}; the roster cannot be empty"
        raise SystemExit(message)
    out: list[str] = []
    for source in sources:
        if source.parent.name in EXEMPT:
            continue
        code = code_only(source.read_text(encoding="utf-8"))
        start = code.find(CALL)
        if start < 0:
            continue
        line = code.count("\n", 0, start) + 1
        out.append(f"lib/{source.parent.name}/{source.name}:{line}: tells the engine to load "
                   f"its Prolog body; write (= (package backing) (prolog <file> (heads))) instead, "
                   f"which the loader performs and another implementation can read")
    return out


def main() -> int:
    """Report every library still making the call."""
    problems = findings(LIBRARIES)
    for problem in problems:
        print(f"  {problem}")
    print(f"package-backings: {len(problems)} finding(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
