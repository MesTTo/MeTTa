"""Purpose: prove the refusal-ground gate turns planted omissions red.

Guarantees:
  - a missing TypeError ground, a non-central CompileError constructor, and a
    segment fence without its named MeTTa law fail independently, while the
    complete fixture passes [tested: tests/checks/check_refusal_grounds_selftest.py;
    commit=acb40f1912f131ae088083d1af29b4b283019bea]
  - an arbiter citation that names no captured corpus, and an unknown ground
    kind, are both refused [tested:
    test_a_planted_arbiter_ground_without_the_corpus_is_reported;
    commit=3fc5479961fd591b1884af118528c9a64a1afbb7]
  - a class the refusal rows name for a SPECIFIC kind, raised without going
    through its row, is reported, while the catch-all class raised directly is
    accepted [tested: test_a_taxonomy_class_raised_outside_its_row_is_reported,
    test_the_catch_all_class_may_be_raised_directly; commit=WORKTREE]
"""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

from check_refusal_grounds import scan_refusal_grounds, valid_ground


def _write(root: Path, relative: str, text: str) -> None:
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def _fixture(
    *,
    grounded_call: bool = True,
    central: bool = True,
    law: bool = True,
    row_raise: bool = False,
):
    directory = tempfile.TemporaryDirectory()
    root = Path(directory.name)
    # The generated refusal table, as two rows: one SPECIFIC kind whose class a
    # site must raise through its row, and the catch-all, whose class it may
    # raise directly.
    _write(
        root,
        "extensions/python/metta/_refusals.py",
        "REFUSALS = {\n"
        "    'capability': Refusal(kind='capability', cls='SpaceCapabilityError',\n"
        "                          origin='term'),\n"
        "    'engine': Refusal(kind='engine', cls='EngineError', origin='default'),\n"
        "}\n",
    )
    ground_argument = ", ground=PYTHON_GROUND" if grounded_call else ""
    central_value = (
        "ground=ground or _compile_ground(construct)" if central else "ground=ground"
    )
    _write(
        root,
        "extensions/python/metta/errors.py",
        "def _compile_ground(construct):\n"
        "    return construct\n"
        "class CompileError(Exception):\n"
        "    def __init__(self, message, *, construct=None, ground=None):\n"
        f"        super().__init__(message, {central_value})\n",
    )
    planted = (
        "    raise SpaceCapabilityError('inline')\n" if row_raise else ""
    )
    _write(
        root,
        "extensions/python/metta/refusal.py",
        "def refuse():\n"
        f"    raise _grounded_type_error('fixture'{ground_argument})\n"
        "\n"
        "def other():\n"
        "    raise EngineError('the catch-all class, raised directly')\n"
        f"{planted}",
    )
    segment_ground = "Kutsia; metta_seq_classify/3" if law else "a finite fragment"
    _write(root, "engine/spaces/segment_matching.pl", segment_ground + "\n")
    return directory, root


def test_a_complete_refusal_fixture_passes() -> None:
    """Accept a fixture whose refusal sites all carry valid grounds."""
    directory, root = _fixture()
    try:
        findings, counts = scan_refusal_grounds(root)
    finally:
        directory.cleanup()
    assert findings == []
    assert counts.compile_sites == 0
    assert counts.python_semantic_sites == 1
    assert counts.metta_law_fences == 1


def test_a_planted_semantic_type_error_without_ground_is_reported() -> None:
    """Reject a semantic TypeError helper call that omits ground data."""
    directory, root = _fixture(grounded_call=False)
    try:
        findings, _counts = scan_refusal_grounds(root)
    finally:
        directory.cleanup()
    assert findings == [
        "extensions/python/metta/refusal.py:2: semantic TypeError has no ground="
    ]


def test_a_planted_noncentral_compile_error_ground_is_reported() -> None:
    """Reject a CompileError constructor that bypasses central grounding."""
    directory, root = _fixture(central=False)
    try:
        findings, _counts = scan_refusal_grounds(root)
    finally:
        directory.cleanup()
    assert findings == [
        "extensions/python/metta/errors.py: CompileError does not derive ground "
        "from _compile_ground(construct)"
    ]


def test_a_planted_arbiter_ground_without_the_corpus_is_reported() -> None:
    """Reject an arbiter citation that describes the pin instead of naming it."""

    class _Ground:
        def __init__(self, kind: str, citation: str) -> None:
            self.kind = kind
            self.citation = citation

    assert valid_ground(
        _Ground("arbiter", "upstream PeTTa: tests/conformance/petta/HEADS.json")
    )
    assert not valid_ground(_Ground("arbiter", "upstream PeTTa answers it this way"))
    assert not valid_ground(_Ground("oracle", "tests/conformance/petta/HEADS.json"))


def test_a_planted_segment_fence_without_a_named_law_is_reported() -> None:
    """Reject the segment fence when its named MeTTa law is absent."""
    directory, root = _fixture(law=False)
    try:
        findings, _counts = scan_refusal_grounds(root)
    finally:
        directory.cleanup()
    assert findings == [
        "engine/spaces/segment_matching.pl: segment refusal must cite Kutsia "
        "and name metta_seq_classify"
    ]


def test_a_taxonomy_class_raised_outside_its_row_is_reported() -> None:
    """Reject a site that raises a specific kind's class without its row."""
    directory, root = _fixture(row_raise=True)
    try:
        findings, counts = scan_refusal_grounds(root)
    finally:
        directory.cleanup()
    assert counts.row_raises == 1
    assert len(findings) == 1
    assert "SpaceCapabilityError is a class the engine's refusal rows name" in findings[0]


def test_the_catch_all_class_may_be_raised_directly() -> None:
    """Accept the class the taxonomy gives a refusal with no specific kind."""
    directory, root = _fixture()
    try:
        findings, counts = scan_refusal_grounds(root)
    finally:
        directory.cleanup()
    assert counts.row_raises == 0
    assert findings == []


def main() -> int:
    """Run the planted cases without depending on pytest collection."""
    tests = (
        test_a_complete_refusal_fixture_passes,
        test_a_taxonomy_class_raised_outside_its_row_is_reported,
        test_the_catch_all_class_may_be_raised_directly,
        test_a_planted_semantic_type_error_without_ground_is_reported,
        test_a_planted_noncentral_compile_error_ground_is_reported,
        test_a_planted_arbiter_ground_without_the_corpus_is_reported,
        test_a_planted_segment_fence_without_a_named_law_is_reported,
    )
    failures: list[str] = []
    for test in tests:
        try:
            test()
        except AssertionError as exc:
            failures.append(f"{test.__name__}: {exc}")
    for failure in failures:
        print(failure)
    print(
        f"refusal-ground selftest: {len(tests)} planted case(s), "
        f"{len(failures)} failure(s)"
    )
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
