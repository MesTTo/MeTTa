"""Purpose: prove the policy-inventory lane discriminates an undeclared closed list.

It is told apart from each valid exemption and from the catalog-owned forms.

Guarantees:
  - a planted unannotated list is reported with its file, line and values
    [tested: test_a_planted_closed_policy_list_is_reported_by_the_inventory_lane;
    commit=0d90e628b1f90c4b4464a2907efcb357d74b13d3]
  - all four exemption categories pass only with adjacent nonempty reason and
    evidence fields naming an in-range line or existing symbol; missing,
    unknown, stale-line and missing-symbol evidence fail independently
    [tested: tests/checks/check_policy_inventory_selftest.py;
    commit=0d90e628b1f90c4b4464a2907efcb357d74b13d3]
  - multiline member/2 and memberchk/2 lists, arbitrary Literal annotations,
    and Python list/set membership are planted independently; only catalog
    preset terms and generated vocabulary output are excluded [tested:
    tests/checks/check_policy_inventory_selftest.py; commit=0d90e628b1f90c4b4464a2907efcb357d74b13d3]
  - a Prolog list whose every element is a variable is skipped, and one
    literal element anywhere in it brings the finding back
    [tested: test_a_list_of_prolog_variables_carries_no_policy; commit=11afdcdbad5bbbe37168b5d8528c23a21c42b4b6]
  - computed Literal argument bundles are skipped; explicit alternatives and
    membership lists, including builtin references, remain findings
    [tested: test_reflected_literal_arguments_preserve_explicit_policy_checks; commit=5fef7004c21135210fd2c05255a2661aa7e46d5e]
  - semiring-claim validation rejects a missing required value, an undeclared
    semiring claim and a missing consumer seam [tested:
    tests/checks/check_policy_inventory_selftest.py; commit=5e0ae6c22d604c4b980766e3cc4811ee545e5c9e]
Fails when:
  - run against a tree it did not create; every assertion is against a fresh
    temporary fixture with exact findings
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

from check_policy_inventory import (
    EXEMPTION_REASONS,
    SEMIRING_CLAIM_SEAM,
    scan_closed_lists,
    validate_semiring_claims,
)


def _write(root: Path, relative: str, text: str) -> Path:
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return path


def test_a_planted_closed_policy_list_is_reported_by_the_inventory_lane() -> None:
    """The row's named acceptance proof: one list turns the lane red by name."""
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        _write(root, "engine/planted.pl", "% fixture\nallowed(X) :- memberchk(X, [red, blue]).\n")
        findings = scan_closed_lists(root)
    assert findings == [
        "engine/planted.pl:2: closed policy list [red, blue] has no adjacent exemption"
    ]


def test_each_recorded_exemption_reason_is_accepted() -> None:
    """Each allowed category uses the same strict adjacent grammar."""
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        path = "engine/exemptions.pl"
        lines: list[str] = []
        for index, category in enumerate(sorted(EXEMPTION_REASONS), start=1):
            lines.append(
                f"% policy-inventory-exempt: {category}; "
                f"reason=fixture reason {index}; evidence={path}:{index}"
            )
            lines.append(f"allowed_{index}(X) :- memberchk(X, [value_{index}, other_{index}]).")
        _write(root, path, "\n".join(lines) + "\n")
        findings = scan_closed_lists(root)
    assert findings == []


def test_an_exemption_without_a_reason_is_reported() -> None:
    """An empty reason cannot turn a closed list green."""
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        _write(
            root,
            "lib/missing_reason.pl",
            "% policy-inventory-exempt: mechanism-internal; reason=; "
            "evidence=lib/missing_reason.pl:2\n"
            "allowed(X) :- memberchk(X, [one, two]).\n",
        )
        findings = scan_closed_lists(root)
    assert any("lib/missing_reason.pl:1: malformed exemption" in item for item in findings)


def test_an_unknown_exemption_reason_is_reported() -> None:
    """A plausible fifth category cannot silently extend the grammar."""
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        _write(
            root,
            "engine/unknown.pl",
            "% policy-inventory-exempt: convenient-local-default; reason=fixture; "
            "evidence=engine/unknown.pl:2\n"
            "allowed(X) :- memberchk(X, [one, two]).\n",
        )
        findings = scan_closed_lists(root)
    assert findings == ["engine/unknown.pl:1: unknown exemption reason 'convenient-local-default'"]


def test_catalog_authority_and_generated_output_are_not_findings() -> None:
    """Only catalog presets and generated output avoid circular exemptions."""
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        _write(
            root,
            "engine/spaces.pl",
            "metta_catalog_preset([fixture, memberchk(_, [catalog, owned])]).\n"
            "allowed(X) :- memberchk(X, [one, two]).\n",
        )
        _write(
            root,
            "extensions/python/metta/vocabularies.py",
            'SaveFormat: TypeAlias = Literal["metta", "fast"]\n',
        )
        findings = scan_closed_lists(root)
    assert findings == [
        "engine/spaces.pl:2: closed policy list [one, two] has no adjacent exemption"
    ]


def test_a_list_of_prolog_variables_carries_no_policy() -> None:
    """Two module names iterated over are not a vocabulary a catalog could own.

    `member(From, [CallModule, Self])` names no values at all: what each
    element IS is decided wherever its binding came from, which is a place this
    scan cannot see and does not claim to. One literal element anywhere in the
    list brings the finding straight back, which is what keeps a real closed
    set from hiding behind a variable beside it.
    """
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        _write(
            root,
            "lib/variables.pl",
            "scoped(X, First, Second) :- member(X, [First, Second]).\n"
            "mixed(X, First) :- member(X, [First, blue]).\n"
            "anonymous(X, _Named) :- memberchk(X, [_Named, _]).\n",
        )
        findings = scan_closed_lists(root)
    assert findings == [
        "lib/variables.pl:2: closed policy list [First, blue] has no adjacent exemption"
    ]


def test_multiline_prolog_member_predicates_are_reported() -> None:
    """Both owned predicates stay visible when the list crosses lines."""
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        _write(
            root,
            "engine/multiline.pl",
            "first(X) :- memberchk(\n"
            "    X,\n"
            "    [red, blue]).\n"
            "second(X) :- member(\n"
            "    X,\n"
            "    [round, square]).\n",
        )
        findings = scan_closed_lists(root)
    assert findings == [
        "engine/multiline.pl:1: closed policy list [red, blue] has no adjacent exemption",
        "engine/multiline.pl:4: closed policy list [round, square] has no adjacent exemption",
    ]


def test_python_literal_and_list_set_membership_are_reported() -> None:
    """Python syntax is parsed, including multiline Literal expressions."""
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        _write(
            root,
            "extensions/python/metta/planted.py",
            "from typing import Literal\n"
            "Mode = Literal[\n"
            "    'one',\n"
            "    'two',\n"
            "]\n"
            "def accepts(value):\n"
            "    return value in ['red', 'blue'] or value not in {'up', 'down'}\n",
        )
        findings = scan_closed_lists(root)
    assert findings == [
        "extensions/python/metta/planted.py:2: closed policy list ['one', 'two'] "
        "has no adjacent exemption",
        "extensions/python/metta/planted.py:7: closed policy list ['red', 'blue'] "
        "has no adjacent exemption",
        "extensions/python/metta/planted.py:7: closed policy list ['up', 'down'] "
        "has no adjacent exemption",
    ]


def test_reflected_literal_arguments_preserve_explicit_policy_checks() -> None:
    """A computed argument bundle differs from explicit policy alternatives."""
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        _write(
            root,
            "extensions/python/metta/references.py",
            "from typing import Literal\n"
            "Bare = Literal[values]\n"
            "Alias = _Literal[values]\n"
            "Qualified = typing.Literal[values]\n"
            "Many = Literal[first, second]\n"
            "Mixed = Literal[values, 'fixed']\n"
            "Enum = Literal[Choice.first, Choice.second]\n"
            "def references(value, first, second):\n"
            "    return value in [first, second] or value not in {first, second}\n"
            "def builtins(value):\n"
            "    return value in {int, float}\n"
            "def mixed(value, first):\n"
            "    return value in [first, 'fixed']\n"
            "def empty(value):\n"
            "    return value in []\n",
        )
        findings = scan_closed_lists(root)
    assert findings == [
        "extensions/python/metta/references.py:5: closed policy list [first, second] "
        "has no adjacent exemption",
        "extensions/python/metta/references.py:6: closed policy list [values, 'fixed'] "
        "has no adjacent exemption",
        "extensions/python/metta/references.py:7: closed policy list [Choice.first, Choice.second] "
        "has no adjacent exemption",
        "extensions/python/metta/references.py:9: closed policy list [first, second] "
        "has no adjacent exemption",
        "extensions/python/metta/references.py:11: closed policy list [int, float] "
        "has no adjacent exemption",
        "extensions/python/metta/references.py:13: closed policy list [first, 'fixed'] "
        "has no adjacent exemption",
        "extensions/python/metta/references.py:15: closed policy list [] "
        "has no adjacent exemption",
    ]


def test_evidence_must_name_an_in_range_line_or_existing_symbol() -> None:
    """A syntactically local evidence token cannot point at stale content."""
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        path = "engine/evidence.pl"
        _write(
            root,
            path,
            "known(X) :- X = true.\n"
            "% policy-inventory-exempt: mechanism-internal; reason=valid symbol; "
            f"evidence={path}:known/1\n"
            "first(X) :- memberchk(X, [one, two]).\n"
            "% policy-inventory-exempt: mechanism-internal; reason=stale line; "
            f"evidence={path}:99\n"
            "second(X) :- memberchk(X, [three, four]).\n"
            "% policy-inventory-exempt: mechanism-internal; reason=missing symbol; "
            f"evidence={path}:absent/1\n"
            "third(X) :- memberchk(X, [five, six]).\n",
        )
        findings = scan_closed_lists(root)
    assert findings == [
        "engine/evidence.pl:4: exemption evidence line 'engine/evidence.pl:99' is outside 1..7",
        "engine/evidence.pl:6: exemption evidence symbol "
        "'engine/evidence.pl:absent/1' does not exist",
    ]


def test_semiring_claims_are_derived_and_validated() -> None:
    """Runtime claim rows must name the vocabulary and shipped ordering."""
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        seam_path, seam_pattern = SEMIRING_CLAIM_SEAM
        _write(
            root,
            seam_path,
            "metta_vocabulary_claim(semiring, Semiring, ordered).\n",
        )
        # Each ordered semiring claims its direction beside orderedness:
        # ranked and prob count down from the best, tropical and budget up
        # from the cheapest, mirroring the shipped catalog rows.
        good = [
            {"semiring": "budget", "laws": ["ordered", "ascending"]},
            {"semiring": "ranked", "laws": ["ordered", "descending"]},
            {"semiring": "prob", "laws": ["ordered", "descending"]},
            {"semiring": "tropical", "laws": ["ordered", "ascending"]},
        ]
        declared = ["bool", "ranked", "prob", "tropical", "budget"]
        assert validate_semiring_claims(root, good, declared) == []
        findings = validate_semiring_claims(
            root,
            [
                {"semiring": "budget", "laws": ["ordered", "ascending"]},
                {"semiring": "ranked", "laws": []},
                {"semiring": "prob", "laws": ["ordered", "descending"]},
                {"semiring": "tropical", "laws": ["ordered", "descending"]},
                {"semiring": "missing", "laws": ["ordered"]},
            ],
            declared,
        )
        _write(root, seam_path, "different_consumer.\n")
        missing_seam = validate_semiring_claims(root, good, declared)
    assert findings == [
        "&metta: semiring claim row names undeclared semiring 'missing'",
        "&metta: semiring ranked is missing law descending",
        "&metta: semiring ranked is missing law ordered",
        "&metta: semiring tropical is missing law ascending",
        "&metta: semiring tropical has unexpected law descending",
        "&metta: unexpected ordering claims for semiring missing",
    ], findings
    assert missing_seam == [
        f"{seam_path}: implementation seam for semiring claims no longer matches "
        f"{seam_pattern!r}"
    ]


def main() -> int:
    """Run every planted case without depending on pytest collection."""
    tests = (
        test_a_planted_closed_policy_list_is_reported_by_the_inventory_lane,
        test_each_recorded_exemption_reason_is_accepted,
        test_an_exemption_without_a_reason_is_reported,
        test_an_unknown_exemption_reason_is_reported,
        test_catalog_authority_and_generated_output_are_not_findings,
        test_a_list_of_prolog_variables_carries_no_policy,
        test_multiline_prolog_member_predicates_are_reported,
        test_python_literal_and_list_set_membership_are_reported,
        test_reflected_literal_arguments_preserve_explicit_policy_checks,
        test_evidence_must_name_an_in_range_line_or_existing_symbol,
        test_semiring_claims_are_derived_and_validated,
    )
    failures: list[str] = []
    for test in tests:
        try:
            test()
        except AssertionError as exc:
            failures.append(f"{test.__name__}: {exc}")
    for failure in failures:
        print(failure)
    print(f"policy inventory selftest: {len(tests)} planted case(s), {len(failures)} failure(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
