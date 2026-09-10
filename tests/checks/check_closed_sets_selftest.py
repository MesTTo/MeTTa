"""Purpose: prove the closed-set census gate turns planted defects red.

The gate admits three answers and a fourth is what it exists to refuse, so
this plants each way an answer can be wrong -- absent, a fourth kind, a
generator that does not exist, a lane nothing runs, a point the seam does not
declare, a missing field -- and requires the gate to say so about each. It also
plants the parameter rule's own case, and its escape.

Guarantees:
  - a closed set with no answer, and each of the five malformed answers, are
    reported independently while the well-formed fixture passes [tested:
    tests/checks/check_closed_sets_selftest.py; commit=c26b6a4d28ef8fb50742440feed2c0578ebb0f58]
  - a FOURTH answer kind is refused as malformed rather than admitted, which
    is the whole point of the three [tested:
    test_a_fourth_answer_is_refused; commit=c26b6a4d28ef8fb50742440feed2c0578ebb0f58]
  - a public str parameter defaulting to a vocabulary member is reported, and
    an adjacent enum-parameter line with its reason clears it [tested:
    test_a_string_parameter_with_a_vocabulary_default_is_reported,
    test_a_stated_reason_clears_the_parameter; commit=c26b6a4d28ef8fb50742440feed2c0578ebb0f58]
  - the shipped tree passes the same gate, so a red above is the fixture
    [tested: test_the_shipped_tree_passes_its_own_gate; commit=c26b6a4d28ef8fb50742440feed2c0578ebb0f58]
  - a table inside an output the artifact manifest declares is not asked, one
    outside a declared region is, and a region the tree cannot locate is
    reported [tested: test_a_table_inside_a_declared_output_is_generated,
    test_a_table_outside_a_declared_region_is_still_asked,
    test_a_declared_region_the_tree_cannot_locate_is_reported; commit=e492f2a5bb995b6c2b86bdeb90cb1d2f27282b07]
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from check_closed_sets import (
    _parameter_answer,
    _validate_parameter,
    closed_sets,
    main,
    scan_closed_sets,
    scan_string_parameters,
    validate_answer,
)

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = ROOT / "extensions" / "python" / "metta"

LANES = {"vocab-sync", "refusal-sync"}
POINTS = {"frame", "typing", "law"}

WELL_FORMED = (
    "# closed-set: generated; by=extensions/python/tools/vocabgen.py; lane=vocab-sync",
    "# closed-set: seam; point=typing; reason=a library registers its own rule kind",
    "# closed-set: decides; policy=what this seat chose; reads=none",
)

MALFORMED = {
    "# closed-set: inherited; from=somewhere": "malformed answer",
    "# closed-set: generated; by=extensions/python/tools/nosuchgen.py; lane=vocab-sync": (
        "does not exist"
    ),
    "# closed-set: generated; by=extensions/python/tools/vocabgen.py; lane=no-such-lane": (
        "no lane named"
    ),
    "# closed-set: seam; point=invented; reason=a fixture": "no point named",
    "# closed-set: decides; policy=only half of it": "needs reads",
}


def test_a_well_formed_answer_of_each_kind_passes() -> None:
    """Each of the three answers, complete, has nothing wrong with it."""
    for line in WELL_FORMED:
        problem = validate_answer(line, lanes=LANES, points=POINTS, root=ROOT)
        assert problem is None, f"{line} was refused: {problem}"


def test_a_fourth_answer_is_refused() -> None:
    """A kind outside the three is malformed rather than admitted."""
    problem = validate_answer(
        "# closed-set: inherited; from=somewhere",
        lanes=LANES,
        points=POINTS,
        root=ROOT,
    )
    assert problem is not None
    assert "malformed answer" in problem


def test_every_malformed_answer_is_reported_as_itself() -> None:
    """Each way an answer can be wrong is named, not lumped together."""
    for line, expected in MALFORMED.items():
        problem = validate_answer(line, lanes=LANES, points=POINTS, root=ROOT)
        assert problem is not None, f"{line} passed"
        assert expected in problem, f"{line} reported {problem!r}"


def test_the_census_finds_a_planted_set(tmp_path: Path) -> None:
    """The scan counts a module-level table of six names as one closed set."""
    text = 'PLANTED = ("a", "b", "c", "d", "e", "f")\nSMALL = ("a", "b")\n'
    found = closed_sets(text, tmp_path / "planted.py")
    assert [one.name for one in found] == ["PLANTED"]
    assert found[0].strings == 6


def test_a_string_parameter_with_a_vocabulary_default_is_reported(tmp_path: Path) -> None:
    """A public str parameter whose default is a vocabulary member is a finding."""
    package = tmp_path / "extensions" / "python" / "metta"
    package.mkdir(parents=True)
    (package / "planted.py").write_text(
        'def door(on: str = "add") -> None:\n    """A door."""\n', encoding="utf-8"
    )
    findings = scan_string_parameters(tmp_path, {"SubscriptionEdge": {"add", "remove"}})
    assert len(findings) == 1
    assert "door(on=)" in findings[0]
    assert "SubscriptionEdge" in findings[0]


def test_a_private_parameter_is_not_the_rule(tmp_path: Path) -> None:
    """The rule is about a PUBLIC signature; a private helper is not one."""
    package = tmp_path / "extensions" / "python" / "metta"
    package.mkdir(parents=True)
    (package / "planted.py").write_text(
        'def _helper(on: str = "add") -> None:\n    """A helper."""\n', encoding="utf-8"
    )
    assert scan_string_parameters(tmp_path, {"SubscriptionEdge": {"add"}}) == []


def test_a_stated_reason_clears_the_parameter(tmp_path: Path) -> None:
    """An adjacent enum-parameter line with a real enum name clears it."""
    package = tmp_path / "extensions" / "python" / "metta"
    package.mkdir(parents=True)
    (package / "planted.py").write_text(
        "# enum-parameter: enum=SubscriptionEdge; reason=a fixture\n"
        'def door(on: str = "add") -> None:\n    """A door."""\n',
        encoding="utf-8",
    )
    assert scan_string_parameters(tmp_path, {"SubscriptionEdge": {"add"}}) == []


def test_a_reason_naming_no_vocabulary_is_reported() -> None:
    """The escape names a real vocabulary or it is not an escape."""
    line = "# enum-parameter: enum=Invented; reason=a fixture"
    assert _parameter_answer([line, "def door(): ..."], 2) == line
    problem = _validate_parameter(line, {"SubscriptionEdge": {"add"}})
    assert problem is not None
    assert "no generated vocabulary" in problem


def test_a_table_inside_a_declared_output_is_generated(tmp_path: Path) -> None:
    """A table in a whole-file output the manifest declares is never asked."""
    package = tmp_path / "extensions" / "python" / "metta"
    package.mkdir(parents=True)
    (package / "vocabularies.py").write_text(
        '"""planted"""\nWORDS = ("a", "b", "c", "d", "e", "f")\n', encoding="utf-8"
    )
    assert scan_closed_sets(tmp_path) == []


def test_a_table_outside_a_declared_region_is_still_asked(tmp_path: Path) -> None:
    """A region output covers the tables between its markers and no other."""
    package = tmp_path / "extensions" / "python" / "metta" / "_spaces"
    package.mkdir(parents=True)
    (package / "execution.py").write_text(
        '"""planted"""\n'
        'OUTSIDE = ("a", "b", "c", "d", "e", "f")\n'
        "# begin generated evaluation keywords\n"
        'INSIDE = ("a", "b", "c", "d", "e", "f")\n'
        "# end generated evaluation keywords\n",
        encoding="utf-8",
    )
    findings = scan_closed_sets(tmp_path)
    assert len(findings) == 1, findings
    assert "OUTSIDE" in findings[0] and "INSIDE" not in findings[0]


def test_a_declared_region_the_tree_cannot_locate_is_reported(tmp_path: Path) -> None:
    """A declared region without its markers is a finding of its own, not a silent skip."""
    package = tmp_path / "extensions" / "python" / "metta" / "_spaces"
    package.mkdir(parents=True)
    (package / "execution.py").write_text('"""planted"""\n', encoding="utf-8")
    findings = scan_closed_sets(tmp_path)
    assert any("missing or repeated output region" in finding for finding in findings), findings


def test_the_shipped_tree_passes_its_own_gate() -> None:
    """Every closed set in the seat answers, so a red above is the fixture."""
    assert main() == 0


def main_selftest() -> int:
    """Run every case, printing the first failure."""
    import tempfile

    cases = [
        value
        for name, value in sorted(globals().items())
        if name.startswith("test_")
    ]
    for case in cases:
        if "tmp_path" in case.__code__.co_varnames[: case.__code__.co_argcount]:
            with tempfile.TemporaryDirectory() as directory:
                case(Path(directory))
        else:
            case()
    print(f"closed-set selftest: {len(cases)} planted case(s), all reported")
    return 0


if __name__ == "__main__":
    sys.exit(main_selftest())
