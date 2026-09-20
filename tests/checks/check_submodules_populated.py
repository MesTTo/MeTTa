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
  - a workflow step that runs `actions/checkout` without `submodules:` is reported, in both the
    `- uses:` and `- name:`/`uses:` shapes, while prose naming the action is not; a tree mounting
    nothing is silent here too [tested: tests/checks/check_submodules_populated_selftest.py;
    commit=c6ed562a1a6f964aba906206f2558489b107dc24]
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
#: `sh tools/components.sh` rather than `git submodule update --init --recursive`, which
#: refuses a component directory that already holds the files and is therefore the
#: wrong advice for every checkout that predates the mount.
REMEDY = "sh tools/components.sh"


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


#: The action that clones a workflow's tree, and the key that makes it bring
#: the components with it.
CHECKOUT = "actions/checkout"
#: `recursive`, not merely present and not `true`: this repository mounts a
#: component inside a component (the twins under `extensions/python/examples/`),
#: and `true` stops at the first level while `false` is the default that caused
#: this. Matching the KEY alone would accept `submodules: false` as a fix.
POPULATES = "recursive"


def _populates(block: list[str]) -> bool:
    """Whether a step's block asks for the components, recursively."""
    for line in block:
        key, sep, value = line.strip().partition(":")
        if sep and key.strip() == "submodules":
            return value.strip().strip("'\"") == POPULATES
    return False


def _step_block(lines: list[str], start: int) -> list[str]:
    """The lines belonging to the step whose `uses:` is at `start`.

    A step ends at the next line that is either less indented or a new list
    item at the same indent, which covers both shapes this repository writes:
    `- uses: actions/checkout@v4` with `with:` indented under it, and a
    `- name:` step whose `uses:` and `with:` sit at the same depth.
    """
    indent = len(lines[start]) - len(lines[start].lstrip())
    block = []
    for line in lines[start + 1:]:
        if not line.strip():
            continue
        here = len(line) - len(line.lstrip())
        if here < indent or (here == indent and line.lstrip().startswith("- ")):
            break
        block.append(line)
    return block


def unpopulating_checkouts(root: Path) -> list[str]:
    """Every workflow checkout that would leave the components empty.

    `actions/checkout` does not populate a submodule unless asked, and the
    failure does not name submodules: the root `pyproject.toml` is a symlink
    into `extensions/python/`, so it dangles and `setup-python` reports that
    the file "doesn't exist" before any check runs. Every job of one run
    failed that way, `report` included, whose own step is `|| true` and
    cannot fail [measured 2026-09-21: run 35521501467 failed 11 of 11 jobs,
    against 13 checkout steps across five workflows with no `submodules:`
    between them; commit=c6ed562a1a6f964aba906206f2558489b107dc24].

    Read by indentation rather than through a YAML parser, because the
    property is whether one key appears in one block: `pyyaml` is not a
    declared dependency here and `deptry` refuses an undeclared import, so a
    parser would trade this lane for that one.
    """
    found: list[str] = []
    for path in sorted((root / ".github" / "workflows").glob("*.yml")):
        lines = path.read_text(encoding="utf-8").splitlines()
        for index, line in enumerate(lines):
            bare = line.lstrip()
            if bare.startswith("#") or CHECKOUT not in bare:
                continue
            # The `uses:` line itself, not a comment or a job name mentioning it.
            if bare.partition(":")[0].removeprefix("- ").strip() != "uses":
                continue
            if not _populates(_step_block(lines, index)):
                where = f".github/workflows/{path.name}:{index + 1}"
                found.append(
                    f"{where}: checks out without `submodules: recursive`, so every component "
                    f"is an empty directory and the root pyproject.toml symlink dangles before "
                    f"any check runs"
                )
    return found


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
    # Appended rather than returned early, so a workflow finding never hides a
    # gitlink one. Only once the split has landed: a checkout with no
    # components needs no populating checkout, which is the silence the rules
    # above already keep.
    if mounted:
        found += unpopulating_checkouts(root)
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
