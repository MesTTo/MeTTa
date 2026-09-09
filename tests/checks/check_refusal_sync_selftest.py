"""Purpose: prove the refusal-sync gate turns planted defects red.

The lane joins the engine's `(refusal ...)` rows to this seat's spellings and
requires the generated table, the classes and their fields to agree. A lane
that cannot be shown failing is evidence of nothing, so this plants each of the
four ways the join can be wrong and requires the lane to say so.

Guarantees:
  - a row naming a class this seat does not have, a class that is not an
    exception, and a class that will not take a field its kind declares are
    each reported [tested: tests/checks/check_refusal_sync_selftest.py;
    commit=c26b6a4d28ef8fb50742440feed2c0578ebb0f58]
  - a kind in the engine's rows with no entry in the shared list, and a seat
    spelling that differs from the row with no reason, each stop the run
    [tested: tests/checks/check_refusal_sync_selftest.py; commit=c26b6a4d28ef8fb50742440feed2c0578ebb0f58]
  - the shipped tree passes the same lane, so the fixtures are what fail
    [tested: tests/checks/check_refusal_sync_selftest.py; commit=c26b6a4d28ef8fb50742440feed2c0578ebb0f58]
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "extensions" / "python" / "tools"))

import refusalgen  # noqa: E402  -- the generator, reached through the path above


def _row(**overrides) -> dict:
    """One well-formed engine row, so a case changes exactly one thing."""
    row = {
        "kind": "capability",
        "class": "SpaceCapabilityError",
        "ground": ["ground", "metta-law", "HostLaws: a fixture"],
        "remedy": ["remedy", "grant <capability>", "quickfix", "maybe"],
    }
    row.update(overrides)
    return row


def _seats(**overrides) -> dict:
    """The shared list's entry for that row, with the same one-change shape."""
    seat = {
        "origin": "term",
        "fields": ["space", "operation", "capability"],
        "python": {"error": "SpaceCapabilityError", "attributes": {}},
    }
    seat.update(overrides)
    return {"capability": seat}


def test_the_shipped_tree_passes_its_own_lane() -> None:
    """The tree as it stands has no finding, so a red below is the fixture."""
    assert refusalgen.main([]) == 0


def test_a_row_naming_an_absent_class_is_reported() -> None:
    """A class neither metta._errors.errors nor builtins has is named."""
    joined = refusalgen.join(
        [_row(**{"class": "NoSuchRefusalError"})],
        _seats(python={"error": "NoSuchRefusalError", "attributes": {}}),
    )
    findings = refusalgen.class_findings(joined)
    assert findings == [
        "the capability row names NoSuchRefusalError, which is neither in "
        "metta._errors.errors nor a builtin"
    ]


def test_a_row_naming_a_class_that_is_not_an_exception_is_reported() -> None:
    """A name that resolves to something that cannot be raised is named."""
    joined = refusalgen.join(
        [_row(**{"class": "Ground"})],
        _seats(python={"error": "Ground", "attributes": {}}),
    )
    assert refusalgen.class_findings(joined) == [
        "Ground, named by the capability row, is not an exception"
    ]


def test_a_class_that_will_not_take_a_declared_field_is_reported() -> None:
    """A field the kind carries that its class has no parameter for."""
    joined = refusalgen.join(
        [_row()],
        _seats(fields=["space", "operation", "capability", "ceiling"]),
    )
    assert refusalgen.class_findings(joined) == [
        "the capability refusal carries ceiling, which SpaceCapabilityError "
        "does not take"
    ]


def test_a_kind_the_shared_list_omits_stops_the_run() -> None:
    """The engine's rows and the shared list are held to one set of kinds."""
    try:
        refusalgen.join([_row(), _row(kind="invented")], _seats())
    except SystemExit as refusal:
        assert "only in the rows: invented" in str(refusal)
    else:
        unreported = "a kind with no entry in the shared list passed"
        raise AssertionError(unreported)


def test_a_silent_seat_departure_stops_the_run() -> None:
    """A seat spelling that differs from the row must carry its reason."""
    try:
        refusalgen.join(
            [_row()], _seats(python={"error": "ValueError", "attributes": {}})
        )
    except SystemExit as refusal:
        assert "with no reason" in str(refusal)
    else:
        unreported = "a silent departure from the row's class passed"
        raise AssertionError(unreported)


def test_a_duplicate_kind_stops_before_dictionary_projection() -> None:
    """Two source rows cannot silently collapse to one generated mapping entry."""
    try:
        refusalgen.join([_row(), _row()], _seats())
    except SystemExit as refusal:
        assert str(refusal) == "duplicate refusal kinds in the engine rows: capability"
    else:
        unreported = "a duplicate source kind reached the generated mapping"
        raise AssertionError(unreported)


def test_a_drifted_module_is_reported() -> None:
    """The checked-in table has to be what the rows produce."""
    text = refusalgen.MODULE.read_text(encoding="utf-8")
    refusalgen.MODULE.write_text(text + "\n# planted drift\n", encoding="utf-8")
    try:
        assert refusalgen.main([]) == 1
    finally:
        refusalgen.MODULE.write_text(text, encoding="utf-8")


def main() -> int:
    """Run every case, printing the first failure."""
    cases = [value for name, value in sorted(globals().items()) if name.startswith("test_")]
    for case in cases:
        case()
    print(f"refusal-sync selftest: {len(cases)} planted case(s), all reported")
    return 0


if __name__ == "__main__":
    sys.exit(main())
