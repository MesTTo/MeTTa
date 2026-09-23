"""Purpose: hold the engine's patched-host requirement to the patches this tree carries, and the gate's own host to that requirement.

The engine refuses to boot on a SWI-Prolog that does not declare every patch
in tests/checks/host_workarounds at its current digest (engine/host_check.pl).
Two things can drift from that and this lane catches both:

  - engine/host_patches.pl is GENERATED from the patch directory by
    `sh tools/pymetta-host/declare-host.sh require`. A patch added or edited
    without regenerating it leaves the engine requiring a set the build no
    longer produces, so this regenerates it and reports any difference;
  - the host this gate runs on must pass the same check the engine makes at
    boot, so a lane run on an undeclared or stale host fails HERE, once and by
    name, rather than as every engine lane failing at its first boot.

Assumes:
  - sh and sha256sum, which declare-host.sh needs, and the interpreter chosen
    the way check_host_workarounds.py chooses it: SWIPL, else swipl on PATH
Guarantees:
  - a generated file that differs from the regenerated text is reported with
    the command that regenerates it, and a host the boot check refuses is
    reported with the engine's own refusal text [tested:
    tests/checks/check_host_declaration_selftest.py; commit=WORKTREE]
Fails when:
  - read as a test of the patches themselves. Whether each patch removes its
    defect is the host-workarounds lane's question; this one asks only that
    the requirement, the declaration and the patches name the same set.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DECLARE = Path("tools/pymetta-host/declare-host.sh")
GENERATED = Path("engine/host_patches.pl")
#: Every process this starts goes through the repository's one bound, so a
#: hung swipl dies with the lane rather than outliving it.
BOUNDED = Path("tools/bounded.sh")


def interpreter() -> str:
    """The swipl the gate runs on, chosen as the host-workarounds lane chooses it."""
    return os.environ.get("SWIPL") or shutil.which("swipl") or "swipl"


def stale_requirement(root: Path) -> str | None:
    """Why the generated requirement differs from its patches, or None when it does not."""
    ran = subprocess.run(
        ["sh", str(ROOT / BOUNDED), "sh", str(root / DECLARE), "require"],
        capture_output=True, text=True, check=False,
    )
    if ran.returncode != 0:
        return f"{DECLARE} require exited {ran.returncode}: {ran.stderr.strip()}"
    written = (root / GENERATED).read_text(encoding="utf-8") if (root / GENERATED).is_file() else ""
    if written == ran.stdout:
        return None
    return (
        f"{GENERATED} does not match the patches in tests/checks/host_workarounds; "
        f"regenerate it with `sh {DECLARE} require > {GENERATED}`"
    )


def refused_host(root: Path) -> str | None:
    """The engine's refusal of the gate's host, or None when the host passes."""
    goal = "use_module('engine/host_check'), metta_host_check:metta_require_patched_host"
    ran = subprocess.run(
        ["sh", str(ROOT / BOUNDED), interpreter(), "-q", "-g", goal, "-t", "halt"],
        cwd=root, stdin=subprocess.DEVNULL, capture_output=True, text=True, check=False,
    )
    if ran.returncode == 0:
        return None
    return f"{interpreter()} is refused by the engine's host check:\n{ran.stderr.strip()}"


def check_tree(root: Path) -> list[str]:
    """Every way the requirement or the gate's host disagrees with the patches."""
    return [f for f in (stale_requirement(root), refused_host(root)) if f is not None]


def main() -> int:
    """Check this tree and its host; print every finding; exit 1 when there is one."""
    findings = check_tree(ROOT)
    for finding in findings:
        print(finding)
    if findings:
        return 1
    count = (ROOT / GENERATED).read_text(encoding="utf-8").count("\nhost_patch(")
    print(f"host declaration: {GENERATED} matches its {count} patches and {interpreter()} declares them all")
    return 0


if __name__ == "__main__":
    sys.exit(main())
