"""Purpose: prove the specialization-differential gate detects a live defect.

Guarantees:
  - reverting only the specialization arity policy in an isolated loaded copy
    makes the exact four-line wrap-one/sleep fixture raise
    ``metta_specialization_disagrees`` through the production detector, while
    the plain-call control stays clean under the same plant
    [tested: tests/checks/check_specialization_differential_selftest.py;
    commit=de2a69fbea43d7bbc641fd93240cf7572285bb5c]
  - a specialization whose call WRITES is still compared, and the write lands
    once rather than three times, because the comparison runs in a snapshot
    [tested: the effectful control below, whose second assertion counts the
    writes; commit=WORKTREE]
  - a clean specialized call reports an agreed count and a one-inference
    budget reports the same attempted check as unverified
    [tested: tests/checks/check_specialization_differential_selftest.py;
    commit=694dff934a11dbc2ee99267b60f39564053baf87]
  - the engine's own report for a failing assertion is let past the ERROR:
    scan while an unrelated engine error beside it is still reported
    [tested: tests/checks/check_specialization_differential_selftest.py;
    commit=71de27a76dd16684941e3e090de0d17299d96493]
Fails when:
  - the production detector, specializer verification, or fixture stops
    exercising the same disagreement; this imports the detector rather than
    reimplementing its output scan.
"""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

from check_specialization_differential import (
    MARKER,
    ROOT,
    specialization_finding,
    specialization_result,
    verifier_errors,
)

PLANTED = """(: wrap-one (-> %Undefined% %Undefined%))
(= (wrap-one $x) ($x))
!(println! (plain  (wrap-one plain)))
!(println! (native (wrap-one sleep)))
"""

CONTROL = """(: wrap-one (-> %Undefined% %Undefined%))
(= (wrap-one $x) ($x))
!(println! (plain  (wrap-one plain)))
"""

COVERED = """(= (coverage-inc $x) (+ $x 1))
(= (coverage-twice $f $x) ($f ($f $x)))
!(test (coverage-twice coverage-inc 20) 22)
"""

#: The same shape with a WRITE in the inner function. Comparing a
#: specialization runs the clone and then the generic, and the wrapper then
#: runs the call the program actually made, so without a sandbox each write
#: lands three times instead of once. The second assertion is the one that
#: catches it: it counts the writes rather than the arithmetic, which stays 22
#: either way. This is the shape
#: examples/ch08-data/08-03-the-shipped-libraries/12-dict_lib.metta found in
#: the corpus, where the same tripling answered 22 against an asserted 10
#: because 4 + 6 + 6 + 6 is 22.
EFFECTFUL = """!(bind! &tally (new-space))
(= (effectful-inc $x) (let $seen (add-atom &tally (bumped $x)) (+ $x 1)))
(= (effectful-twice $f $x) ($f ($f $x)))
!(test (effectful-twice effectful-inc 20) 22)
!(test (size-atom (collapse (get-atoms &tally))) 2)
"""

#: The engine's own three-line report for a failing assertion, byte for byte
#: as examples/ch12-testing/03-assertion_difference.metta produces it, and one
#: unrelated engine error beside it. The scan must let the first block past and
#: report the second, which is the wall and the door of the same check.
DEMONSTRATED_REPORT = (
    "ERROR: [Thread main] MeTTa assertion failed: (assertEqual (+ 1 1) 3)\n"
    "ERROR: [Thread main]   missing: (3)\n"
    "ERROR: [Thread main]   excess: (2)\n"
)
UNRELATED_ERROR = "ERROR: [Thread main] the specialization verifier fell over\n"

FIXED_CALL = "translate_specialized_clause(CompiledInput, Clause, false),"
PLANTED_CALL = "translate_tracked_clause(CompiledInput, Clause, false),"


def _quoted(path: Path) -> str:
    """Quote one absolute path as a Prolog atom."""
    return "'" + path.resolve().as_posix().replace("'", "''") + "'"


def _planted_entrypoint(directory: Path) -> Path:
    """Reload the specializer with only the fixed arity policy removed."""
    source = (ROOT / "engine" / "specializer.pl").read_text(encoding="utf-8")
    if source.count(FIXED_CALL) != 1:
        msg = "the specialization compile seam changed; the selftest plant is stale"
        raise RuntimeError(msg)
    planted_specializer = directory / "specializer_with_old_arity_bug.pl"
    planted_specializer.write_text(
        source.replace(FIXED_CALL, PLANTED_CALL), encoding="utf-8"
    )
    bootstrap = directory / "planted_main.pl"
    bootstrap.write_text(
        ":- ensure_loaded(" + _quoted(ROOT / "engine" / "qlf_boot.pl") + ").\n"
        ":- ensure_loaded(" + _quoted(ROOT / "engine" / "metta.pl") + ").\n"
        ":- unload_file(" + _quoted(ROOT / "engine" / "specializer.pl") + ").\n"
        ":- load_files(" + _quoted(planted_specializer) + ", [if(true)]).\n"
        ":- ensure_loaded(" + _quoted(ROOT / "engine" / "main.pl") + ").\n"
        ":- initialization(metta_main:main, main).\n",
        encoding="utf-8",
    )
    return bootstrap


def main() -> int:
    """Run the isolated old-arity plant and its no-specialization control."""
    problems: list[str] = []
    scratch = ROOT / "ai-tmp"
    scratch.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(
        prefix="spec-differential-selftest-", dir=scratch
    ) as name:
        directory = Path(name)
        planted = directory / "wrap_one_sleep.metta"
        control = directory / "wrap_one_plain.metta"
        covered = directory / "covered.metta"
        effectful = directory / "effectful.metta"
        planted.write_text(PLANTED, encoding="utf-8")
        control.write_text(CONTROL, encoding="utf-8")
        covered.write_text(COVERED, encoding="utf-8")
        effectful.write_text(EFFECTFUL, encoding="utf-8")
        entrypoint = _planted_entrypoint(directory)

        planted_finding = specialization_finding(planted, entrypoint=entrypoint)
        control_finding = specialization_finding(control, entrypoint=entrypoint)
        covered_result = specialization_result(covered)
        bounded_result = specialization_result(
            covered, environment={"METTA_VERIFY_BUDGET": "1"}
        )
        effectful_result = specialization_result(effectful)

        if planted_finding is None:
            problems.append("the production detector stayed quiet on wrap-one/sleep")
        elif MARKER not in planted_finding:
            problems.append(
                "the planted file failed without exposing "
                f"{MARKER}: {planted_finding}"
            )
        if control_finding is not None:
            problems.append(
                f"the plain-call control was reported: {control_finding}"
            )
        if covered_result.finding is not None:
            problems.append(f"the covered control failed: {covered_result.finding}")
        elif (
            covered_result.coverage.checked < 1
            or covered_result.coverage.agreed < 1
            or covered_result.coverage.unverified != 0
        ):
            problems.append(
                "the covered control did not report agreed coverage: "
                f"{covered_result.coverage}"
            )
        if verifier_errors(DEMONSTRATED_REPORT):
            problems.append(
                "a demonstrated assertion report was read as a verifier error: "
                f"{verifier_errors(DEMONSTRATED_REPORT)}"
            )
        if verifier_errors(DEMONSTRATED_REPORT + UNRELATED_ERROR) != [
            UNRELATED_ERROR.rstrip("\n")
        ]:
            problems.append(
                "an unrelated engine error beside a demonstrated report was "
                f"not reported: {verifier_errors(DEMONSTRATED_REPORT + UNRELATED_ERROR)}"
            )
        if effectful_result.finding is not None:
            problems.append(
                f"the effectful control failed: {effectful_result.finding}"
            )
        elif effectful_result.coverage.agreed < 1:
            problems.append(
                "the effectful control was not actually compared: "
                f"{effectful_result.coverage}"
            )
        if bounded_result.finding is not None:
            problems.append(f"the bounded control failed: {bounded_result.finding}")
        elif (
            bounded_result.coverage.checked < 1
            or bounded_result.coverage.unverified < 1
            or bounded_result.coverage.agreed != 0
        ):
            problems.append(
                "the bounded control did not report unverified coverage: "
                f"{bounded_result.coverage}"
            )

    for problem in problems:
        print(problem, file=sys.stderr)
    print(
        "spec-differential selftest: "
        f"{len(problems)} problem(s), 1 planted disagreement, 1 plain control, "
        "1 agreed control, 1 inference-bounded control, 1 effectful control "
        "and 2 assertion-report scans"
    )
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
