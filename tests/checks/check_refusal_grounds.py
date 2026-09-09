"""Purpose: gate semantic refusals on one of the three admitted authorities.

The kinds are the host language's own reference, which on this seat is a
Python Language Reference section, a named MeTTa law, and a measured answer of
upstream PeTTa under the captured parity corpus. They are the catalog's own
`ground-kind` vocabulary, held equal to metta._errors.errors' tuple by
extensions/python/tests/repository/test_refusal_rows.py.

Assumes:
  - compiler refusals use ``CompileError`` and non-compiler Python semantic
    refusals use ``_grounded_type_error``
Guarantees:
  - every compiler refusal site inherits a structured ground from the central
    ``CompileError`` constructor, every explicit semantic TypeError supplies a
    structured ground, and the segment fence names its MeTTa-law sources
    [tested: tests/checks/check_refusal_grounds_selftest.py; commit=acb40f1912f131ae088083d1af29b4b283019bea]
  - an "arbiter" ground is admitted only when its citation names the captured
    parity corpus, so a claim about what upstream PeTTa answers points at the
    file that measures it [tested:
    test_a_planted_arbiter_ground_without_the_corpus_is_reported;
    commit=3fc5479961fd591b1884af118528c9a64a1afbb7]
Decides:
  - input-shape validation errors are not semantic refusals; this gate owns the
    compiler, Python data-model fences, and MeTTa fragment fences classified by
    GG4-005/GG4-012 at
    ai-python-first-revamp-discussion.md:7493-7502,7568-7573
"""

from __future__ import annotations

import ast
import builtins
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
PYTHON_PACKAGE = Path("extensions/python/metta")
ERRORS = PYTHON_PACKAGE / "_errors/errors.py"
SEGMENTS = Path("engine/spaces/segment_matching.pl")
#: A `host-reference` ground stands on the HOST language's own specification,
#: which the engine spells without naming a host because it names none. This
#: gate walks the PYTHON package, so the host here is Python and a section
#: number is what makes the claim checkable.
PYTHON_CITATION = re.compile(r"Python Language Reference section\s+\d")
METTA_LAWS = ("EffectSafety", "SeqFragment", "UnifierMostGeneral", "HostLaws")
#: An arbiter ground is upstream PeTTa's own measured answer, so its citation
#: has to name the captured corpus rather than describe it: the parity pin is
#: what makes the claim checkable and re-measurable.
ARBITER_CORPUS = "tests/conformance/petta"


#: Where the seat's own refusal table lives. Every class it names is a MeTTa
#: refusal the engine declares a kind for, and a site that raises one has a
#: row to raise it through.
REFUSALS = PYTHON_PACKAGE / "_errors/refusals.py"

#: The one door that builds a refusal from its row, and the two spellings a
#: site may still use directly: `refusing(...)` attaches the parts by hand,
#: which the classes with no kind still need, and re-raising an error the
#: crossing already dressed is not a raise site at all.
REFUSAL_DOOR = "refuse"

#: WHY an inline `raise` is still allowed, stated once so nobody has to guess:
#:
#: - A Python-level TypeError, ValueError or AttributeError for an argument of
#:   the wrong SHAPE is not a MeTTa refusal. It is the host language refusing
#:   its own call, `except TypeError` is what a caller writes for it, and the
#:   engine's taxonomy has no kind for it because no other seat would spell it
#:   the same way. Those sites carry a Remedy where the repair is mechanical,
#:   which extensions/python/tests/repository/test_refusal_remedies.py gates.
#: - A class the taxonomy does NOT name is the seat's own meaning, and it has
#:   no row to raise through until the engine declares a kind for it.
#: - errors.py itself DEFINES the classes and the door, so its own raises are
#:   about a malformed Remedy rather than refusals that carry one.
#: - The CATCH-ALL kind, the one whose origin is `default`, is by definition
#:   the class with no specific meaning: the taxonomy gives it to a ball
#:   nothing shaped, and the seat gives it to an engine answer this side
#:   cannot use. Raising it directly IS what it is for, and its row's remedy
#:   ("report the ball with the message it carries") is true of a ball rather
#:   than of a seat-side reading, so attaching it would put a false repair on
#:   a true refusal.
#:
#: What is NOT allowed is raising a class the taxonomy names for a SPECIFIC
#: kind without going through its row: the class, the ground and the remedy
#: would then be three decisions at the site instead of one row, which is the
#: drift the table exists to prevent.
INLINE_RAISE_REASONS = (
    "a Python-level refusal of an argument's shape is not a MeTTa refusal",
    "a class the taxonomy does not name has no row to raise through",
    "errors.py defines the classes and the door",
    "the catch-all class is what a refusal with no specific kind IS",
)


@dataclass(frozen=True)
class GateCounts:
    """The refusal populations proved by one gate pass."""

    compile_sites: int
    python_semantic_sites: int
    metta_law_fences: int
    row_raises: int = 0


def valid_ground(ground: Any) -> bool:
    """Whether structured data names one of the two admitted authorities."""
    kind = getattr(ground, "kind", None)
    citation = getattr(ground, "citation", None)
    if not isinstance(citation, str):
        return False
    if kind == "host-reference":
        return PYTHON_CITATION.search(citation) is not None
    if kind == "metta-law":
        return any(law in citation for law in METTA_LAWS)
    if kind == "arbiter":
        return ARBITER_CORPUS in citation
    return False


def _call_name(call: ast.Call) -> str | None:
    if isinstance(call.func, ast.Name):
        return call.func.id
    if isinstance(call.func, ast.Attribute):
        return call.func.attr
    return None


def _compile_error_is_central(text: str, filename: str) -> bool:
    tree = ast.parse(text, filename=filename)
    definition = next(
        (
            node
            for node in tree.body
            if isinstance(node, ast.ClassDef) and node.name == "CompileError"
        ),
        None,
    )
    if definition is None:
        return False
    initializer = next(
        (
            node
            for node in definition.body
            if isinstance(node, ast.FunctionDef) and node.name == "__init__"
        ),
        None,
    )
    if initializer is None:
        return False
    for call in (node for node in ast.walk(initializer) if isinstance(node, ast.Call)):
        for keyword in call.keywords:
            if keyword.arg == "ground" and "_compile_ground(construct)" in ast.unparse(
                keyword.value
            ):
                return True
    return False


def taxonomy_classes(root: Path) -> frozenset[str]:
    """Every class the engine's refusal rows name on this seat.

    Read out of the generated table's source rather than by importing it, so
    the scan stays a source walk and needs no engine. A tree with no table
    yields nothing and the row-raise rule simply finds no sites, which is what
    the missing-file finding below is for.

    The catch-all kind's class is left OUT, for the reason INLINE_RAISE_REASONS
    states: it is the class a refusal with no specific kind already is.
    """
    path = root / REFUSALS
    if not path.is_file():
        return frozenset()
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(REFUSALS))
    named: set[str] = set()
    catch_all: set[str] = set()
    for call in (node for node in ast.walk(tree) if isinstance(node, ast.Call)):
        if _call_name(call) != "Refusal":
            continue
        row = {
            keyword.arg: keyword.value.value
            for keyword in call.keywords
            if isinstance(keyword.value, ast.Constant)
        }
        spelled = row.get("cls")
        if spelled is None:
            continue
        named.add(str(spelled))
        if row.get("origin") == "default":
            catch_all.add(str(spelled))
    named -= catch_all
    # A builtin the seat borrows for a kind is Python's own word for the
    # condition, and `except ValueError` has to stay the caller's spelling, so
    # a site raising one is not a row-raise finding.
    return frozenset(name for name in named if not hasattr(builtins, name))


def scan_refusal_grounds(root: Path) -> tuple[list[str], GateCounts]:
    """Scan every owned refusal site and its central ground mechanism."""
    findings: list[str] = []
    compile_sites = 0
    python_semantic_sites = 0
    row_raises = 0
    named = taxonomy_classes(root)
    if not (root / REFUSALS).is_file():
        findings.append(f"{REFUSALS}: the seat's refusal table is missing")
    package = root / PYTHON_PACKAGE
    if not package.is_dir():
        findings.append(f"{PYTHON_PACKAGE}: Python package is missing")
    else:
        for path in sorted(package.rglob("*.py")):
            relative = path.relative_to(root)
            text = path.read_text(encoding="utf-8")
            try:
                tree = ast.parse(text, filename=str(relative))
            except SyntaxError as exc:
                findings.append(
                    f"{relative}:{exc.lineno or 1}: cannot scan Python: {exc.msg}"
                )
                continue
            defining = relative == ERRORS
            for raise_of in (node for node in ast.walk(tree) if isinstance(node, ast.Raise)):
                if defining or not isinstance(raise_of.exc, ast.Call):
                    continue
                raised = _call_name(raise_of.exc)
                if raised not in named:
                    continue
                row_raises += 1
                findings.append(
                    f"{relative}:{raise_of.lineno}: {raised} is a class the "
                    f"engine's refusal rows name, so it is raised through its "
                    f"row: `raise {REFUSAL_DOOR}(<kind>, message, **fields)`. "
                    f"An inline raise is for the three cases the lane states: "
                    f"{'; '.join(INLINE_RAISE_REASONS)}"
                )
            for call in (node for node in ast.walk(tree) if isinstance(node, ast.Call)):
                name = _call_name(call)
                if name == "CompileError":
                    compile_sites += 1
                elif name == "_grounded_type_error":
                    python_semantic_sites += 1
                    ground = next(
                        (keyword for keyword in call.keywords if keyword.arg == "ground"),
                        None,
                    )
                    if ground is None:
                        findings.append(
                            f"{relative}:{call.lineno}: semantic TypeError has no ground="
                        )

    errors_path = root / ERRORS
    if not errors_path.is_file():
        findings.append(f"{ERRORS}: central refusal-ground source is missing")
    elif not _compile_error_is_central(
        errors_path.read_text(encoding="utf-8"), str(ERRORS)
    ):
        findings.append(
            f"{ERRORS}: CompileError does not derive ground from _compile_ground(construct)"
        )

    segment_path = root / SEGMENTS
    metta_law_fences = 0
    if not segment_path.is_file():
        findings.append(f"{SEGMENTS}: MeTTa segment refusal source is missing")
    else:
        segment_text = segment_path.read_text(encoding="utf-8")
        if "Kutsia" not in segment_text or "metta_seq_classify" not in segment_text:
            findings.append(
                f"{SEGMENTS}: segment refusal must cite Kutsia and name metta_seq_classify"
            )
        else:
            metta_law_fences = 1
    return findings, GateCounts(
        compile_sites,
        python_semantic_sites,
        metta_law_fences,
        row_raises,
    )


def runtime_ground_findings(root: Path) -> list[str]:
    """Exercise the constructors so data shape, not source spelling, is gated."""
    package_parent = str(root / "extensions/python")
    if package_parent not in sys.path:
        sys.path.insert(0, package_parent)
    from metta._errors.errors import (
        _EFFECT_SAFETY_GROUND,
        _PYTHON_COMPARISON_GROUND,
        _PYTHON_RICH_COMPARISON_GROUND,
        _compile_ground,
    )
    from metta._spaces.results import _ERROR_IS_A_VALUE

    grounds = (
        _PYTHON_COMPARISON_GROUND,
        _PYTHON_RICH_COMPARISON_GROUND,
        _EFFECT_SAFETY_GROUND,
        _ERROR_IS_A_VALUE,
        _compile_ground("free identifier"),
        _compile_ground("floor division"),
        _compile_ground(None),
    )
    return [
        f"runtime refusal ground is malformed: {ground!r}"
        for ground in grounds
        if not valid_ground(ground)
    ]


def main() -> int:
    """Print the owned refusal populations and fail on an ungrounded site."""
    findings, counts = scan_refusal_grounds(ROOT)
    findings.extend(runtime_ground_findings(ROOT))
    for finding in findings:
        print(finding)
    print(
        "refusal grounds: "
        f"{counts.compile_sites} CompileError site(s), "
        f"{counts.python_semantic_sites} Python semantic site(s), "
        f"{counts.metta_law_fences} MeTTa-law fence(s), "
        f"{counts.row_raises} taxonomy class(es) raised outside their row, "
        f"{len(findings)} finding(s)"
    )
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
