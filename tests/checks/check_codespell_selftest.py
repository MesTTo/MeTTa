"""Purpose: prove check_codespell.py reads what a repository wrote and skips what it marks as not its own.

Running the lane on this repository proves only that today's tree is clean. It
says nothing about whether a vendored file is actually skipped, nor whether a
file the repository wrote is still read, and the second is the load-bearing
half: a runner that skipped too much would pass every tree. So a fixture
repository carries the same misspelling in four files, and the runner must name
exactly the two this repository wrote.

Assumes: git and codespell_lib importable by this interpreter; a writable ai-tmp/.
Guarantees:
  - a typo in a tracked file and in an untracked one, neither marked, is
    reported, and a typo in a linguist-vendored file and in a
    linguist-generated one is not [tested: this file; commit=WORKTREE]
  - the same fixture without git reports all four
    [tested: this file; commit=WORKTREE]
Fails when: run against a tree it did not write. It asserts on its own fixture.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = next(parent for parent in HERE.parents
            if (parent / "engine").is_dir() and (parent / "lib").is_dir())
RUNNER = HERE / "check_codespell.py"
# One misspelling codespell's default dictionary always knows, built in pieces
# so the lane reading this file never meets its own needle.
TYPO = "t" + "eh\n"
FILES = ("owned.txt", "untracked.txt", "vendor/theirs.txt", "made.txt")


def plant(fixture: Path, *, repository: bool) -> None:
    """Write the four files, and under git mark two of them as not this repository's."""
    (fixture / "vendor").mkdir()
    for name in FILES:
        (fixture / name).write_text(TYPO, encoding="utf-8")
    if not repository:
        return
    (fixture / ".gitattributes").write_text(
        "vendor/** linguist-vendored\nmade.txt linguist-generated\n", encoding="utf-8")
    environment = {**os.environ, "GIT_AUTHOR_NAME": "fixture", "GIT_AUTHOR_EMAIL": "fixture@example.invalid",
                   "GIT_COMMITTER_NAME": "fixture", "GIT_COMMITTER_EMAIL": "fixture@example.invalid"}
    subprocess.run(["git", "init", "-q"], cwd=fixture, check=True)
    subprocess.run(["git", "add", ".gitattributes", "owned.txt", "vendor/theirs.txt", "made.txt"],
                   cwd=fixture, check=True)
    subprocess.run(["git", "commit", "-q", "-m", "fixture"], cwd=fixture, env=environment, check=True)


def reported(fixture: Path) -> tuple[int, set[str]]:
    """The runner's status and the files its report names."""
    done = subprocess.run([sys.executable, str(RUNNER), *sorted({name.split("/")[0] for name in FILES})],
                          cwd=fixture, capture_output=True, text=True, check=False)
    return done.returncode, {line.split(":", 1)[0] for line in done.stdout.splitlines() if ":" in line}


def main() -> int:
    """Plant both fixtures and check the runner separates them."""
    scratch = ROOT / "ai-tmp"
    scratch.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=scratch) as first, tempfile.TemporaryDirectory(dir=scratch) as second:
        marked, bare = Path(first), Path(second)
        plant(marked, repository=True)
        plant(bare, repository=False)
        status, names = reported(marked)
        assert status != 0, "a typo in a file this repository wrote did not fail the run"
        assert names == {"owned.txt", "untracked.txt"}, f"under git, reported {sorted(names)}"
        status, names = reported(bare)
        assert status != 0, "outside git, a typo did not fail the run"
        assert names == set(FILES), f"outside git, reported {sorted(names)}"
    print("codespell selftest: a tracked and an untracked file of our own are read, a vendored "
          "and a generated one are skipped, and outside git all four are read")
    return 0


if __name__ == "__main__":
    sys.exit(main())
