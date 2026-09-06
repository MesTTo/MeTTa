"""Purpose: run the specialization differential over the shipped example corpus.

Assumes:
  - ``engine/main.pl`` is the standalone engine entry point and the caller has
    rebuilt the QLF set before asking this gate for evidence
  - ``example_parity.corpus`` is the single definition of runnable examples
Guarantees:
  - every corpus file runs in its own process with specialization verification
    enabled, and a disagreement or failed verifier process makes the gate fail
    while naming the file
    [tested: spec-differential-selftest;
    commit=de2a69fbea43d7bbc641fd93240cf7572285bb5c]
  - ``specialization_finding`` is the same per-file detector imported by the
    planted selftest, so the selftest cannot drift from the production scan
    [tested: tests/checks/check_specialization_differential_selftest.py;
    commit=de2a69fbea43d7bbc641fd93240cf7572285bb5c]
  - a clean corpus is accepted only when the engine reports at least one
    checked specialization, and the final line gives agreed and inference-
    bounded totals rather than discarding the verifier's coverage
    [tested: tests/checks/check_specialization_differential_selftest.py;
    commit=694dff934a11dbc2ee99267b60f39564053baf87]
  - an example whose SUBJECT is a failing assertion prints the engine's own
    report, and that report is not read as a verifier fault, while any other
    ERROR: line in the same output still is
    [tested: tests/checks/check_specialization_differential_selftest.py;
    commit=WORKTREE]
Fails when:
  - SWI-Prolog or the engine cannot start; infrastructure failure is loud
    rather than being mistaken for a corpus with no disagreements.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
from collections.abc import Iterable, Mapping
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path

from bounded_spawn import bounded

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "extensions" / "python" / "tools"
sys.path.insert(0, str(TOOLS))

from example_parity import corpus  # noqa: E402

MARKER = "metta_specialization_disagrees"
#: The engine's report for a program-level falsehood, and the one ERROR: block
#: the scan below lets past. A failing assertion is the PROGRAM saying
#: something false rather than the engine breaking, which is the distinction
#: the tree already draws by exception type, and
#: examples/ch12-testing/03-assertion_difference.metta demonstrates one on
#: purpose: it is the corpus's first file whose SUBJECT is an engine
#: diagnostic. Every other ERROR: line, in that file and any other, is still a
#: finding.
ASSERTION_REPORT = "MeTTa assertion failed"
#: print_message/2 writes the report's continuation lines through the same
#: prefix as its headline, so a continuation is told from a fresh error by the
#: indent that survives the prefix and the optional thread tag.
ERROR_PREFIX = re.compile(r"^\s*ERROR:\s*(?:\[[^\]]*\]\s?)?")
COVERAGE = re.compile(
    r"verify-specializations checked (?P<checked>\d+) specialization\(s\): "
    r"(?P<agreed>\d+) agreed, (?P<unverified>\d+) could not be checked inside "
    r"the (?P<budget>\d+)-inference bound"
)


@dataclass(frozen=True, slots=True)
class SpecializationCoverage:
    """One engine process's reported specialization-verification coverage."""

    checked: int
    agreed: int
    unverified: int


@dataclass(frozen=True, slots=True)
class SpecializationResult:
    """One source's failure, if any, and every reported coverage count."""

    finding: str | None
    coverage: SpecializationCoverage


def _display(path: Path, root: Path) -> str:
    """A stable repository-relative label, or the absolute external path."""
    resolved = path.resolve()
    try:
        return str(resolved.relative_to(root.resolve()))
    except ValueError:
        return str(resolved)


def verifier_errors(output: str) -> list[str]:
    """Every ERROR: line that is not part of a demonstrated assertion report.

    The scan is a two-state walk rather than a per-file exemption, so a real
    verifier fault inside the one example that demonstrates a failing
    assertion still lands: only the report's own headline and the indented
    lines under it are let past.
    """
    errors: list[str] = []
    reporting = False
    for line in output.splitlines():
        said, prefixed = ERROR_PREFIX.subn("", line)
        if not prefixed:
            reporting = False
            continue
        if ASSERTION_REPORT in said:
            reporting = True
            continue
        if reporting and said.startswith("  "):
            continue
        reporting = False
        errors.append(line)
    return errors


def _diagnostic_lines(text: str, marker: str | None = None) -> str:
    """At most three lines around the decisive output, matching the old lane."""
    lines = text.strip().splitlines()
    if not lines:
        return "no output"
    if marker is None:
        return "\n".join(lines[-3:])
    index = next(i for i, line in enumerate(lines) if marker in line)
    return "\n".join(lines[index:index + 3])


def specialization_result(
    path: Path,
    *,
    root: Path = ROOT,
    entrypoint: Path | None = None,
    environment: Mapping[str, str] | None = None,
) -> SpecializationResult:
    """Return one source's parity failure and observable verifier coverage."""
    label = _display(path, root)
    argument = label if path.resolve().is_relative_to(root.resolve()) else str(path)
    entrypoint = root / "engine" / "main.pl" if entrypoint is None else entrypoint
    entrypoint_argument = _display(entrypoint, root)
    process_environment = os.environ.copy()
    process_environment["METTA_VERIFY_SPECIALIZATIONS"] = "1"
    if environment is not None:
        process_environment.update(environment)
    done = subprocess.run(
        bounded([
            "swipl",
            "--stack_limit=8g",
            "-q",
            "-s",
            entrypoint_argument,
            "--",
            argument,
            "extensions",
            "silent",
        ]),
        cwd=root,
        env=process_environment,
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        check=False,
    )

    output = done.stdout + done.stderr
    reports = tuple(COVERAGE.finditer(output))
    coverage = SpecializationCoverage(
        checked=sum(int(report["checked"]) for report in reports),
        agreed=sum(int(report["agreed"]) for report in reports),
        unverified=sum(int(report["unverified"]) for report in reports),
    )
    if MARKER in output:
        finding = f"{label}: {_diagnostic_lines(output, MARKER)}"
        return SpecializationResult(finding, coverage)
    if verifier_errors(output):
        finding = f"{label}: verifier reported an error\n{_diagnostic_lines(output)}"
        return SpecializationResult(finding, coverage)
    if done.returncode != 0:
        finding = (
            f"{label}: specialization verifier exited {done.returncode}\n"
            f"{_diagnostic_lines(output)}"
        )
        return SpecializationResult(finding, coverage)
    return SpecializationResult(None, coverage)


def specialization_finding(
    path: Path,
    *,
    root: Path = ROOT,
    entrypoint: Path | None = None,
) -> str | None:
    """Return the named reason one source did not prove specialization parity."""
    return specialization_result(path, root=root, entrypoint=entrypoint).finding


def specialization_results(
    paths: Iterable[Path], *, root: Path = ROOT
) -> list[SpecializationResult]:
    """Run independent source files concurrently and preserve corpus order."""
    ordered = list(paths)
    with ThreadPoolExecutor() as pool:
        return list(
            pool.map(lambda path: specialization_result(path, root=root), ordered)
        )


def specialization_findings(
    paths: Iterable[Path], *, root: Path = ROOT
) -> list[str]:
    """Run independent source files concurrently and preserve corpus order."""
    return [
        result.finding
        for result in specialization_results(paths, root=root)
        if result.finding is not None
    ]


def main() -> int:
    """Print every corpus failure and return whether the differential held."""
    results = specialization_results(corpus(ROOT))
    findings = [result.finding for result in results if result.finding is not None]
    for finding in findings:
        print(finding)
    if findings:
        return 1
    checked = sum(result.coverage.checked for result in results)
    agreed = sum(result.coverage.agreed for result in results)
    unverified = sum(result.coverage.unverified for result in results)
    if checked == 0:
        print(
            "specialization differential: no specialization coverage was reported",
            file=sys.stderr,
        )
        return 1
    print(
        "specialization differential: 0 disagreements; "
        f"{checked} checked, {agreed} agreed, {unverified} unverified"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
