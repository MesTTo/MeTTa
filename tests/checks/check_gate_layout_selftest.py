"""Purpose: prove the gate's driver layout is stated once and that every
    statement of it agrees.

The layout has two unavoidable homes, because `extensions/python/tools/
artifacts.py` is seat tooling inside a submodule and cannot import a
superproject test module: `gate_layout.CHECK` serves `tests/checks/`, and
`artifacts.CHECK_SH` serves the generator. Two homes across a boundary nothing
can cross is duplication that must be made CHECKABLE instead of removed, which
is what the agreement case here does.

Assumes: a checkout of this repository with the drivers in place.
Guarantees:
  - every driver `gate_layout` names resolves in the tree [tested: this file;
    commit=c6ed562a1a6f964aba906206f2558489b107dc24]
  - every value is relative, so joining it onto a fixture root plants the
    shape the repository has [tested: this file; commit=c6ed562a1a6f964aba906206f2558489b107dc24]
  - `artifacts.CHECK_SH` and `gate_layout.CHECK` are the same path, so the
    generator and the checkers cannot disagree about where the driver lives
    [tested: this file; commit=c6ed562a1a6f964aba906206f2558489b107dc24]
Fails when: run against a tree whose drivers have not been built or checked
    out, which it reports as a missing driver rather than passing.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(ROOT / "extensions" / "python" / "tools"))

import artifacts  # noqa: E402  -- the seat's tools directory is installed above
import gate_layout  # noqa: E402  -- this directory is installed above


def findings() -> list[str]:
    """Every disagreement between a statement of the layout and the tree."""
    out: list[str] = []
    for driver in gate_layout.DRIVERS:
        if Path(driver).is_absolute():
            out.append(f"gate_layout names {driver!r} absolutely; a fixture cannot join it onto its own root")
        if not (ROOT / driver).is_file():
            out.append(f"gate_layout names {driver!r}, which is not in the tree")
    if artifacts.CHECK_SH != gate_layout.CHECK:
        out.append(
            f"artifacts.CHECK_SH is {artifacts.CHECK_SH!r} and gate_layout.CHECK is "
            f"{gate_layout.CHECK!r}; the generator writes one file and the checkers read another"
        )
    if gate_layout.CHECK not in gate_layout.DRIVERS:
        out.append("DRIVERS does not carry CHECK, so a caller planting a whole tree omits the driver")
    return out


def planted() -> list[str]:
    """Each rule reports when its own defect is planted, and not otherwise."""
    out: list[str] = []
    original = artifacts.CHECK_SH
    try:
        artifacts.CHECK_SH = "somewhere/else/check.sh"
        if not any("the generator writes one file" in line for line in findings()):
            out.append("a generator naming a different driver than the checkers went unreported")
    finally:
        artifacts.CHECK_SH = original

    original_drivers = gate_layout.DRIVERS
    try:
        gate_layout.DRIVERS = (*original_drivers, "tools/not-a-driver.sh")
        if not any("not in the tree" in line for line in findings()):
            out.append("a driver that is not in the tree went unreported")
        gate_layout.DRIVERS = (*original_drivers, "/absolute/check.sh")
        if not any("absolutely" in line for line in findings()):
            out.append("an absolute driver path, which no fixture root can carry, went unreported")
    finally:
        gate_layout.DRIVERS = original_drivers

    if findings():
        out.append(f"the restored tree still reports: {findings()}")
    return out


def main() -> int:
    """Report the tree's own disagreements and every planted case that was missed."""
    problems = [*findings(), *planted()]
    for problem in problems:
        print(f"  {problem}")
    print(f"gate-layout selftest: {len(problems)} defect(s), over {len(gate_layout.DRIVERS)} drivers "
          f"and three planted cases")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
