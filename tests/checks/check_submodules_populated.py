"""Purpose: every component this checkout mounts is present, and every mount is declared.

The components are submodules, so `git ls-files` stops at each gitlink unless it is asked to
recurse, and `--recurse-submodules` SKIPS a gitlink whose working tree was never populated rather
than failing. Those two together are how a lane can scan a fraction of the tree and still report a
pass, which is worse than a lane that fails, so the population is checked once here instead of
guarded at each of the nine places that enumerate tracked files.

The second direction matters as much: a gitlink with no `.gitmodules` entry names no repository,
so nobody else can populate it at all, and `git submodule update` passes over it in silence.

Assumes: a git checkout. A tree git will not enumerate is reported, never assumed empty.
Guarantees:
  - a gitlink whose working tree is absent or empty is reported with the command that fixes it
    [tested: tests/checks/check_submodules_populated_selftest.py; commit=500290ef67f6198adc1ce17c1f70e5a5173647bb]
  - a gitlink absent from `.gitmodules`, and a `.gitmodules` entry with no gitlink, are each
    reported [tested: tests/checks/check_submodules_populated_selftest.py; commit=500290ef67f6198adc1ce17c1f70e5a5173647bb]
  - a checkout with no submodules passes and says so, so this lane is silent until the split
    lands rather than needing to be added with it [tested:
    tests/checks/check_submodules_populated_selftest.py; commit=500290ef67f6198adc1ce17c1f70e5a5173647bb]
Fails when: run outside a git checkout, which it reports rather than passing.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
#: `sh components.sh` rather than `git submodule update --init --recursive`, which
#: refuses a component directory that already holds the files and is therefore the
#: wrong advice for every checkout that predates the mount.
REMEDY = "sh components.sh"


def gitlinks(root: Path) -> list[str]:
    """Every path the index holds as a gitlink, in reading order."""
    listing = subprocess.run(["git", "ls-files", "--stage"], cwd=root,
                             capture_output=True, text=True, check=False)
    if listing.returncode != 0:
        message = f"git will not enumerate {root}: {listing.stderr.strip()[:200]}"
        raise SystemExit(message)
    return sorted(line.split("\t", 1)[1] for line in listing.stdout.splitlines()
                  if line.startswith("160000 "))


def declared(root: Path) -> list[str]:
    """Every path `.gitmodules` names, or nothing when the file is absent."""
    if not (root / ".gitmodules").is_file():
        return []
    read = subprocess.run(["git", "config", "-f", ".gitmodules", "--get-regexp", r"^submodule\..*\.path$"],
                          cwd=root, capture_output=True, text=True, check=False)
    return sorted(line.split(" ", 1)[1] for line in read.stdout.splitlines() if " " in line)


def findings(root: Path = ROOT) -> list[str]:
    """Every component that is mounted but unusable, in reading order."""
    mounted, named = gitlinks(root), declared(root)
    found = [f"{path}: a gitlink with no entry in .gitmodules, so nothing can populate it; "
             f"add one naming the repository it points at"
             for path in mounted if path not in named]
    found += [f"{path}: .gitmodules names it and the index holds no gitlink there; "
              f"remove the entry or mount the component"
              for path in named if path not in mounted]
    for path in mounted:
        if path in named and not any((root / path).glob("*")):
            found.append(f"{path}: mounted and empty, so every lane that walks the tree silently "
                         f"skips it; populate it with `{REMEDY}`")
    return found


def main() -> int:
    """Report every unusable component, exiting nonzero when there is one."""
    reported = findings()
    for finding in reported:
        print(finding)
    if reported:
        print(f"{len(reported)} component(s) not usable; {REMEDY}")
        return 1
    count = len(gitlinks(ROOT))
    print(f"every component is populated and declared: {count} submodule(s)" if count
          else "this checkout mounts no components")
    return 0


if __name__ == "__main__":
    sys.exit(main())
