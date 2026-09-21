"""Purpose: hold check_example_references to the four things it can get wrong.

Three were live in earlier versions of it. A bare `git ls-files` at a
SUPERPROJECT root omits every submodule's contents, and most of this tree is
submodules, so the first version silently stopped reading extensions/python,
lib and the example repositories. A path inside a string literal is a
construction rather than a claim, so a fixture a test is about to write read
as a broken link. And a GitHub blob URL carries its own root, so the path
after `blob/<branch>/` is repository relative whatever the page's location is.

Assumes: nothing about the real tree. Each case plants a repository of its
    own, with a real `git init` and a real commit, because the checker asks
    git what the files are and a walked directory would not exercise that.
Guarantees:
  - a prose reference to an absent example is reported, or the check could not
    fail at all [tested: this file; commit=WORKTREE]
  - a reference inside a SUBMODULE's files is read, which a bare `git ls-files`
    at the superproject root would miss [tested: this file; commit=WORKTREE]
  - a path in a string literal is not a claim, and a path in a comment is
    [tested: this file; commit=WORKTREE]
  - a github blob URL resolves against the repository root, not the page's
    directory [tested: this file; commit=WORKTREE]
Fails when: git is absent, which it refuses on rather than skipping.
Owns resources: one temporary directory per case, removed by the context
    manager; abandonment leaves it for the OS to reap.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_example_references as checker


def _git(*arguments: str, cwd: Path) -> None:
    """Run one git command, refusing loudly rather than leaving a half tree."""
    subprocess.run(["git", *arguments], cwd=cwd, check=True, capture_output=True)


def _repository(root: Path) -> Path:
    """A committed git repository, because the checker asks git for the files."""
    root.mkdir(parents=True, exist_ok=True)
    _git("init", "-q", cwd=root)
    _git("config", "user.email", "selftest@example.invalid", cwd=root)
    _git("config", "user.name", "selftest", cwd=root)
    return root


def _commit(root: Path) -> None:
    _git("add", "-A", cwd=root)
    _git("commit", "-qm", "planted", cwd=root)


def _plant(root: Path, files: dict[str, str]) -> Path:
    """A repository holding exactly `files`, nothing else."""
    _repository(root)
    for relative, body in files.items():
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(body, encoding="utf-8")
    _commit(root)
    return root


def _plant_with_submodule(root: Path, inner: dict[str, str]) -> Path:
    """A superproject whose submodule holds the only reference.

    A bare `git ls-files` at the superproject lists the gitlink and none of
    the files under it, so a checker reading that listing sees nothing here.
    """
    _repository(root)
    (root / "README.md").write_text("# outer\n", encoding="utf-8")
    _commit(root)
    donor = root.parent / f"{root.name}-donor"
    _plant(donor, inner)
    _git("-c", "protocol.file.allow=always", "submodule", "add", "-q",
         str(donor), "seat", cwd=root)
    _commit(root)
    return root


def cases() -> list[tuple[str, object, int]]:
    """Each case: what it is for, how to plant it, how many findings it owes."""
    return [
        ("a prose reference to an absent example is reported",
         lambda root: _plant(root, {
             "guide.md": "See examples/basics/gone.py for the surface.\n"}), 1),
        ("a prose reference that resolves is not",
         lambda root: _plant(root, {
             "guide.md": "See examples/basics/here.py for the surface.\n",
             "examples/basics/here.py": "x = 1\n"}), 0),
        ("a comment is a claim",
         lambda root: _plant(root, {
             "tool.py": "# see examples/basics/gone.py\nx = 1\n"}), 1),
        ("a string literal is a construction, not a claim",
         lambda root: _plant(root, {
             "tool.py": 'path = "examples/basics/scratch.py"\n'}), 0),
        ("a github blob URL resolves against the repository root",
         lambda root: _plant(root, {
             "docs/deep/page.md":
                 "https://github.com/o/r/blob/main/examples/basics/here.py\n",
             "examples/basics/here.py": "x = 1\n"}), 0),
        ("and is reported when that root has no such file",
         lambda root: _plant(root, {
             "docs/deep/page.md":
                 "https://github.com/o/r/blob/main/examples/basics/gone.py\n"}), 1),
        # The blind spot: the reference lives in a submodule's own file.
        ("a reference inside a submodule is read",
         lambda root: _plant_with_submodule(root, {
             "notes.md": "See examples/basics/gone.py here.\n"}), 1),
    ]


def main() -> int:
    """Run every case against its own planted repository and report disagreements."""
    bad = 0
    given = cases()
    with tempfile.TemporaryDirectory(prefix="example-references-") as scratch:
        for index, (what, plant, owed) in enumerate(given):
            root = plant(Path(scratch) / f"case{index}")
            found = checker.findings(root)
            if len(found) != owed:
                print(f"  {what}: expected {owed}, got {len(found)}: {found}")
                bad += 1
    print(f"example-references-selftest: {len(given) - bad} of {len(given)} cases hold")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
