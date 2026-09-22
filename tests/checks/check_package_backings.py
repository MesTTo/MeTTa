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

The forms come from the engine's own reader, `positioned_forms`, which is what
`metta.library.LibrarySource` uses to read a library without loading or running
it. That matters twice. The call is MENTIONED in the comments of libraries that
do not make it, `lib_memo` and `lib_zar` both discuss it while importing one
head at a time, and a pattern over the raw text reports those. And a form's
HEAD is what decides, not a substring: the reader says where each top-level
form begins and ends, so a mention inside a larger form cannot be read as one.

Assumes: the shipped libraries are at `lib/*/*.metta`.
Guarantees:
  - a library making the call is reported with its line
    [tested: tests/checks/check_package_backings_selftest.py; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f]
  - the same text inside a comment or a string is NOT reported
    [tested: tests/checks/check_package_backings_selftest.py; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f]
  - `lib_import` is exempt, being where the operation is defined
    [tested: tests/checks/check_package_backings_selftest.py; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f]
  - a manifest holding any form that is not a package equation is reported,
    which is the rule rather than a list of banned instructions: `import!`,
    `bind!` and every other form are refused by the same clause
    [tested: tests/checks/check_package_backings_selftest.py; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f]
  - an empty roster is refused, because a pass that found nothing to check
    reads exactly like a pass that checked everything
    [tested: tests/checks/check_package_backings_selftest.py; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f]
  - the reserved head is named on both sides of the engine boundary or the
    disagreement is reported, since neither side can derive it from the other
    [tested: tests/checks/check_package_backings_selftest.py; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f]
Fails when: run outside a checkout with a lib/ directory, which it reports.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import ast
import re
import sys
from pathlib import Path

#: Derived, not counted, so moving this file cannot silently point it elsewhere.
ROOT = next(parent for parent in Path(__file__).resolve().parents
            if (parent / "engine").is_dir() and (parent / "lib").is_dir())
sys.path.insert(0, str(ROOT / "extensions" / "python"))

from metta._binding.positions import positioned_forms  # noqa: E402  -- the seat is installed above

LIBRARIES = ROOT / "lib"
OPERATION = "import_prolog_functions_from_file"
#: Where the operation is defined and applied to its own Prolog half.
EXEMPT = ("lib_import",)


def called_at(text: str) -> bool:
    """Whether this top-level form IS the importer call, by its head."""
    body = text.lstrip()
    if body.startswith("!"):
        body = body[1:].lstrip()
    return body.startswith("(" + OPERATION) and (
        len(body) <= len(OPERATION) + 1 or not body[len(OPERATION) + 1].isalnum())


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
        forms = positioned_forms(source.read_text(encoding="utf-8"))
        calls = [form for form in forms if called_at(form.text)]
        if not calls:
            continue
        line = calls[0].line
        out.append(f"lib/{source.parent.name}/{source.name}:{line}: tells the engine to load "
                   f"its Prolog body; write (= (package backing) (prolog <file> (heads))) instead, "
                   f"which the loader performs and another implementation can read")
    return out


#: The one file a library is entered through, and the only one this rule binds.
#: A git checkout resolves through the same name
#: [source: lib/lib_package/lib_package.pl:package_checkout_entry/4].
MANIFEST = "pkg.metta"

#: A package row, recognised the way the engine recognises it: the head is two
#: constants, `=` then `(package <key>)`. Recognising before matching is what
#: stops `(= ($x backing) ...)` reading as a package row
#: [source: engine/filereader/source_lifecycle.pl:package_row/3].
PACKAGE_ROW = re.compile(r"^\(\s*=\s*\(\s*package\s+([A-Za-z_][\w-]*)\s*\)")


def manifest_findings(libraries: Path) -> list[str]:
    """Each manifest form that instructs instead of describing.

    A manifest is an argument record, so every form in it is an equation on the
    reserved head. Stating it that way decides every form rather than the ones
    someone thought to ban: an `!(import! ...)` dependency, a `!(bind! ...)`, an
    equation on another head and a bare atom are each refused by this clause,
    and a reader that is not this engine can apply the same test
    [source: docs/journal/2026-09-09-packages-are-equations.md, laws 1 and 10].
    """
    out: list[str] = []
    for manifest in sorted(libraries.glob(f"*/{MANIFEST}")):
        for form in positioned_forms(manifest.read_text(encoding="utf-8")):
            if PACKAGE_ROW.match(form.text.strip()):
                continue
            shown = " ".join(form.text.split())[:60]
            out.append(f"lib/{manifest.parent.name}/{MANIFEST}:{form.line}: "
                       f"{shown!r} instructs rather than describes; a manifest holds "
                       f"only (= (package <key>) <value>) rows, which another "
                       f"implementation can read without evaluating them")
    return out


#: Where each side writes the reserved head down. The engine fixes it as law 1,
#: so that one library's package rows are never read as its importer's own; the
#: Python declarations reader runs with NO engine and cannot ask, so it carries
#: the name again. Neither can be derived from the other across that boundary,
#: which is what makes this a checkable duplication rather than a derivation.
RESERVED_IN_ENGINE = ROOT / "engine/metta/references.pl"
RESERVED_IN_SEAT = ROOT / "extensions/python/metta/_catalog/declarations.py"


def reserved_heads() -> tuple[frozenset[str], frozenset[str]]:
    """What each side calls reserved: the engine's clauses, then the seat's set."""
    engine = frozenset(re.findall(r"^metta_reference_internal\(_, ([a-z_][\w-]*)\)\.",
                                  RESERVED_IN_ENGINE.read_text(encoding="utf-8"),
                                  re.MULTILINE))
    return engine, _seat_set(RESERVED_IN_SEAT.read_text(encoding="utf-8"))


def _seat_set(source: str) -> frozenset[str]:
    """The seat's RESERVED_HEADS, read as a literal rather than imported.

    Imported, this lane would need the seat on `sys.path` and would answer what
    a stale installed copy holds; read, it answers what the file in this tree
    says. The binding is `frozenset({...})`, so the literal is the call's
    argument.
    """
    for node in ast.walk(ast.parse(source)):
        if not isinstance(node, ast.Assign):
            continue
        if not any(isinstance(target, ast.Name) and target.id == "RESERVED_HEADS"
                   for target in node.targets):
            continue
        value = node.value
        if isinstance(value, ast.Call) and value.args:
            value = value.args[0]
        return frozenset(ast.literal_eval(value))
    return frozenset()


def disagreements() -> list[str]:
    """Each head one side reserves and the other does not."""
    engine, seat = reserved_heads()
    here = "engine/metta/references.pl"
    there = "extensions/python/metta/_catalog/declarations.py"
    return ([f"{name}: reserved in {here} and not in {there}" for name in sorted(engine - seat)]
            + [f"{name}: reserved in {there} and not in {here}" for name in sorted(seat - engine)])


def main() -> int:
    """Report every library still instructing the engine, and any reserved head only one side knows."""
    problems = findings(LIBRARIES) + manifest_findings(LIBRARIES) + disagreements()
    for problem in problems:
        print(f"  {problem}")
    print(f"package-backings: {len(problems)} finding(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
