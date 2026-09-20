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
import check_submodules_populated as pass_under_test

ROOT = Path(__file__).resolve().parents[2]


def git(*args: str, cwd: Path) -> str:
    """Run a git command in the scratch checkout, failing loudly, and answer its stdout."""
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True,
                          check=True).stdout.strip()


#: The two step shapes this repository writes, each with and without the key.
#: They are independent of the gitlink cases above, so they are named rather
#: than crossed with them.
LIST_STEP = "jobs:\n  a:\n    steps:\n      - uses: actions/checkout@v4\n"
NAMED_STEP = "jobs:\n  a:\n    steps:\n      - name: Checkout code\n        uses: actions/checkout@v4\n"
#: One spelling serves both: a `- uses:` at indent 6 and a `- name:` step's
#: `uses:` at indent 8 both take their `with:` at indent 8.
POPULATED = "        with:\n          submodules: recursive\n"
#: Prose naming the action is not a step, and a rule that reads it as one
#: would fire on this file's own explanation of itself.
COMMENTED = "jobs:\n  a:\n    steps:\n      # actions/checkout needs asking\n      - run: true\n"


def plant_workflow(scratch: Path, name: str, text: str) -> None:
    """Write one workflow into a planted checkout."""
    target = scratch / ".github" / "workflows" / name
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding="utf-8")


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

        # A workflow that clones without the components leaves every lane
        # scanning empty directories, and says so as a dangling symlink rather
        # than as a missing submodule. Both step shapes, because the repository
        # writes both and an indentation reader can see one and miss the other.
        for name, step in (("list.yml", LIST_STEP), ("named.yml", NAMED_STEP)):
            plant(scratch, entry=True, link=True, populated=True)
            plant_workflow(scratch, name, step)
            found = pass_under_test.findings(scratch)
            assert any("without `submodules: recursive`" in line for line in found), (name, found)

            plant_workflow(scratch, name, step + POPULATED)
            found = pass_under_test.findings(scratch)
            assert found == [], (name, found)

        # The KEY is not the answer: `false` is the default that caused this,
        # and `true` stops at the first level while this repository mounts a
        # component inside a component. A rule matching only `submodules:`
        # accepts both as a fix.
        for value in ("false", "true", "''"):
            plant(scratch, entry=True, link=True, populated=True)
            plant_workflow(scratch, "value.yml",
                           LIST_STEP + f"        with:\n          submodules: {value}\n")
            found = pass_under_test.findings(scratch)
            assert any("without `submodules: recursive`" in line for line in found), (value, found)

        # A quoted or loosely spaced `recursive` is the same answer, so the
        # rule reads the value rather than matching one exact line.
        for spelling in ("submodules: recursive", "submodules:  recursive",
                         "submodules: 'recursive'", 'submodules: "recursive"'):
            plant(scratch, entry=True, link=True, populated=True)
            plant_workflow(scratch, "spelling.yml", LIST_STEP + f"        with:\n          {spelling}\n")
            found = pass_under_test.findings(scratch)
            assert found == [], (spelling, found)

        # Prose naming the action is not a step. Without this the rule fires on
        # every comment that explains why the key is there, this file included.
        plant(scratch, entry=True, link=True, populated=True)
        plant_workflow(scratch, "comment.yml", COMMENTED)
        found = pass_under_test.findings(scratch)
        assert found == [], found

        # The rule is silent until the split lands: a checkout mounting nothing
        # needs no populating checkout, however its workflows are written.
        plant(scratch, entry=False, link=False, populated=True)
        plant_workflow(scratch, "list.yml", LIST_STEP)
        found = pass_under_test.findings(scratch)
        assert found == [], found
    finally:
        shutil.rmtree(base, ignore_errors=True)
    print("check_submodules_populated selftest passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
