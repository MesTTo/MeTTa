"""Purpose: prove the component-population lane reports each way a mount can be unusable.

A lane whose whole job is to stop a silent under-scan is exactly the kind that can itself pass on
nothing, so each case is planted in a scratch checkout and the finding is asserted.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_submodules_populated as pass_under_test  # noqa: E402  -- the path is arranged just above

ROOT = Path(__file__).resolve().parents[2]


def git(*args: str, cwd: Path) -> str:
    """Run a git command in the scratch checkout, failing loudly, and answer its stdout."""
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True,
                          check=True).stdout.strip()


def plant(scratch: Path, *, entry: bool, link: bool, populated: bool) -> Path:
    """A checkout mounting one component, with each of the three facts chosen."""
    shutil.rmtree(scratch, ignore_errors=True)
    (scratch / "seat").mkdir(parents=True)
    git("init", "--quiet", cwd=scratch)
    (scratch / "README.md").write_text("# scratch\n", encoding="utf-8")
    git("add", "README.md", cwd=scratch)
    # A gitlink names a real object, so the scratch repository's own commit stands in for the
    # component's tip; the lane reads the index and the working tree, never the object.
    git("-c", "user.name=selftest", "-c", "user.email=selftest@example.invalid",
        "commit", "--quiet", "-m", "scratch", cwd=scratch)
    tip = git("rev-parse", "HEAD", cwd=scratch)
    if entry:
        (scratch / ".gitmodules").write_text(
            '[submodule "seat"]\n\tpath = seat\n\turl = /nowhere/seat.git\n', encoding="utf-8")
        git("add", ".gitmodules", cwd=scratch)
    if link:
        git("update-index", "--add", "--cacheinfo", f"160000,{tip},seat", cwd=scratch)
    if populated:
        (scratch / "seat" / ".git").write_text("gitdir: ../.git/modules/seat\n", encoding="utf-8")
    return scratch


def main() -> int:
    """Plant each case and assert the finding it must produce."""
    base = Path(tempfile.mkdtemp(dir=ROOT / "ai-tmp", prefix="submodules-selftest-"))
    scratch = base / "checkout"
    try:
        found = pass_under_test.findings(plant(scratch, entry=True, link=True, populated=True))
        assert found == [], found

        found = pass_under_test.findings(plant(scratch, entry=False, link=True, populated=True))
        assert any("no entry in .gitmodules" in line for line in found), found

        found = pass_under_test.findings(plant(scratch, entry=True, link=False, populated=True))
        assert any("holds no gitlink there" in line for line in found), found

        found = pass_under_test.findings(plant(scratch, entry=True, link=True, populated=False))
        assert any("mounted and empty" in line for line in found), found

        # And a checkout with nothing mounted is clean rather than suspicious.
        found = pass_under_test.findings(plant(scratch, entry=False, link=False, populated=True))
        assert found == [], found
    finally:
        shutil.rmtree(base, ignore_errors=True)
    print("check_submodules_populated selftest passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
