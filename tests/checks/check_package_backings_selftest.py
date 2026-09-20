"""Purpose: prove check_package_backings.py finds the call and spares the rest.

Running the pass over this repository proves the libraries have moved. It says
nothing about whether the pass can find the defect at all, nor about the three
shapes it must NOT flag. Two of those carry the rule: the call is MENTIONED in
the comments of libraries that do not make it, and `lib_import` must keep
making it.

Assumes: a writable ai-tmp/ in this repository.
Guarantees:
  - a library making the call is reported with its line
    [tested: this file; commit=WORKTREE]
  - the same text in a comment, and in a string, is NOT reported
    [tested: this file; commit=WORKTREE]
  - a library carrying the backing row is NOT reported
    [tested: this file; commit=WORKTREE]
  - `lib_import` is exempt [tested: this file; commit=WORKTREE]
  - an empty roster is refused [tested: this file; commit=WORKTREE]
Fails when: run against a directory it did not write. It asserts on its fixture.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

ROOT = next(parent for parent in Path(__file__).resolve().parents
            if (parent / "engine").is_dir() and (parent / "lib").is_dir())
sys.path.insert(0, str(Path(__file__).resolve().parent))

from check_package_backings import (  # noqa: E402  -- the path is installed above
    _seat_set,
    disagreements,
    findings,
)

MAKES_THE_CALL = '!(import_prolog_functions_from_file (library a.pl) (a-head))\n'

#: lib_memo and lib_zar both discuss the call while importing one head at a
#: time. A pattern over the raw text reports them and reads as a false alarm.
ONLY_MENTIONS_IT = (
    '; lib_import owns !(import_prolog_functions_from_file ...) and this does not use it.\n'
    '(= (a-head) 1)\n'
)

IN_A_STRING = '(= (doc) "see !(import_prolog_functions_from_file f (h))")\n'

CARRIES_THE_ROW = '(= (package backing) (prolog (library a.pl) (a-head)))\n'


def main() -> int:
    """Plant every shape the pass must separate, and check it separates them."""
    scratch = ROOT / "ai-tmp"
    scratch.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=scratch) as directory:
        libraries = Path(directory)
        for name, body in (("lib_calls", MAKES_THE_CALL),
                           ("lib_mentions", ONLY_MENTIONS_IT),
                           ("lib_quotes", IN_A_STRING),
                           ("lib_describes", CARRIES_THE_ROW),
                           ("lib_import", MAKES_THE_CALL)):
            (libraries / name).mkdir()
            (libraries / name / f"{name}.metta").write_text(body, encoding="utf-8")
        reported = {line.split("/")[1] for line in findings(libraries)}
    assert "lib_calls" in reported, f"a library making the call was not found: {reported}"
    assert "lib_mentions" not in reported, f"a comment was reported: {reported}"
    assert "lib_quotes" not in reported, f"a string was reported: {reported}"
    assert "lib_describes" not in reported, f"a backing row was reported: {reported}"
    assert "lib_import" not in reported, f"the bootstrap library was reported: {reported}"
    assert reported == {"lib_calls"}, f"unexpected: {reported}"

    # The reserved head is written on both sides of the engine boundary, since
    # neither can derive it from the other: the engine fixes it as law 1 and the
    # Python reader runs with no engine to ask. A disagreement either way is the
    # finding, and the shipped tree must have none.
    assert disagreements() == [], f"the two spellings disagree: {disagreements()}"
    assert _seat_set('RESERVED_HEADS = frozenset({"one", "two"})') == {"one", "two"}, \
        "the seat's set was not read as a literal"
    assert _seat_set("NOTHING_HERE = 1") == frozenset(), \
        "a file without the binding did not read as empty"
    with tempfile.TemporaryDirectory(dir=scratch) as empty:
        try:
            findings(Path(empty))
        except SystemExit as refusal:
            assert "cannot be empty" in str(refusal), f"wrong refusal: {refusal}"
        else:
            message = "an empty roster was accepted"
            raise AssertionError(message)
    print("package-backings selftest: a library making the call is found; a comment, a string, "
          "a backing row and lib_import are not; an empty roster is refused; "
          "and the reserved head agrees across the engine boundary")
    return 0


if __name__ == "__main__":
    sys.exit(main())
