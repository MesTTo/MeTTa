"""Purpose: hold declare-host.sh and the host-declaration lane to their contracts over planted trees.

Each case builds a small repository layout holding COPIES of the real
tools/pymetta-host/declare-host.sh, patch-root.sh and engine/host_check.pl,
because declare-host.sh finds its patches from its own location: a copy in a
planted layout reads the planted patches, so the script is tested as it ships
rather than through a knob added for the test.

Assumes: git, sh and sha256sum on PATH, a TMPDIR the run may write (a root
    gate run allocates one beneath ai-tmp/check-runs/), and the interpreter the
    lane itself uses for the host case.
Guarantees:
  - `declare` over a tree carrying every patch exits 0, names the build of the
    home's launcher and lists each patch with the sha256 of its file; with no
    launcher it refuses and writes nothing; over a tree lacking one patch it
    exits 1 and omits exactly that one; `require` lists every patch in name
    order under the module header [tested: this file; commit=WORKTREE]
  - the lane reports an edited requirement and a host that does not declare
    what the requirement names, and passes a matching pair
    [tested: this file; commit=WORKTREE]
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import hashlib
import shutil
import subprocess
import sys
import tempfile
from collections.abc import Callable
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_host_declaration as lane  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
PATCH_A = "--- a/one.txt\n+++ b/one.txt\n@@ -1 +1 @@\n-one\n+one patched\n"
PATCH_B = "--- a/two.txt\n+++ b/two.txt\n@@ -1 +1 @@\n-two\n+two patched\n"


def run(*command: str, cwd: Path) -> subprocess.CompletedProcess[str]:
    """Run a command in a planted tree without raising on its exit status."""
    return subprocess.run(list(command), cwd=cwd, capture_output=True, text=True, check=False)


def plant(work: Path) -> Path:
    """A repository layout with two patches, the real scripts and the real check."""
    layout = work / "repo"
    (layout / "tools/pymetta-host").mkdir(parents=True)
    (layout / "tests/checks/host_workarounds").mkdir(parents=True)
    (layout / "engine").mkdir()
    for name in ("declare-host.sh", "patch-root.sh"):
        shutil.copy(ROOT / "tools/pymetta-host" / name, layout / "tools/pymetta-host" / name)
    shutil.copy(ROOT / "engine/host_check.pl", layout / "engine/host_check.pl")
    (layout / "tests/checks/host_workarounds/a.patch").write_text(PATCH_A)
    (layout / "tests/checks/host_workarounds/b.patch").write_text(PATCH_B)
    return layout


def source(work: Path, *applied: str) -> Path:
    """A git tree holding the two targets with the named patches applied."""
    tree = work / "src"
    tree.mkdir()
    (tree / "one.txt").write_text("one\n")
    (tree / "two.txt").write_text("two\n")
    run("git", "init", "--quiet", ".", cwd=tree)
    for name in applied:
        run("git", "apply", str(work / "repo/tests/checks/host_workarounds" / name), cwd=tree)
    return tree


def planted_home(work: Path) -> Path:
    """A home whose bin/<arch>/swipl is the gate's interpreter, so `declare` can read its build."""
    home = work / "home"
    (home / "bin/x86_64-linux").mkdir(parents=True)
    real = shutil.which(lane.interpreter()) or lane.interpreter()
    (home / "bin/x86_64-linux/swipl").symlink_to(Path(real).resolve())
    return home


def digest(path: Path) -> str:
    """The sha256 declare-host.sh records for a patch file."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fact(layout: Path, name: str) -> str:
    """The declaration line for one planted patch."""
    return f"host_patch('{name}', '{digest(layout / 'tests/checks/host_workarounds' / name)}')."


def case_declare_every_patch(work: Path) -> list[str]:
    layout = plant(work)
    tree = source(work, "a.patch", "b.patch")
    home = planted_home(work)
    ran = run("sh", "tools/pymetta-host/declare-host.sh", "declare", str(tree), str(home), cwd=layout)
    text = (home / "metta-host.pl").read_text()
    out = []
    if ran.returncode != 0:
        out.append(f"a fully patched tree exited {ran.returncode}: {ran.stderr.strip()}")
    for name in ("a.patch", "b.patch"):
        if fact(layout, name) not in text:
            out.append(f"the declaration lacks {fact(layout, name)}")
    if "\nhost_build('" not in text:
        out.append("the declaration names no build")
    return out


def case_declare_refuses_a_home_without_a_launcher(work: Path) -> list[str]:
    layout = plant(work)
    tree = source(work, "a.patch", "b.patch")
    home = work / "bare-home"
    home.mkdir()
    ran = run("sh", "tools/pymetta-host/declare-host.sh", "declare", str(tree), str(home), cwd=layout)
    out = []
    if ran.returncode != 1 or "no launcher" not in ran.stderr:
        out.append(f"a home with no launcher exited {ran.returncode}: {ran.stderr.strip()}")
    if (home / "metta-host.pl").exists():
        out.append("a declaration was written with no build to bind it to")
    return out


def case_declare_fails_closed(work: Path) -> list[str]:
    layout = plant(work)
    tree = source(work, "a.patch")
    home = planted_home(work)
    ran = run("sh", "tools/pymetta-host/declare-host.sh", "declare", str(tree), str(home), cwd=layout)
    text = (home / "metta-host.pl").read_text()
    out = []
    if ran.returncode != 1:
        out.append(f"a tree lacking b.patch exited {ran.returncode}, wanted 1")
    if fact(layout, "a.patch") not in text:
        out.append("the carried a.patch is missing from the declaration")
    if "b.patch" in text.replace("% ", ""):
        out.append("the absent b.patch was declared")
    return out


def case_require_lists_every_patch(work: Path) -> list[str]:
    layout = plant(work)
    ran = run("sh", "tools/pymetta-host/declare-host.sh", "require", cwd=layout)
    facts = [line for line in ran.stdout.splitlines() if line.startswith("host_patch(")]
    out = []
    if ":- module(metta_host_patches, [host_patch/2])." not in ran.stdout:
        out.append("require printed no module header")
    if facts != [fact(layout, "a.patch"), fact(layout, "b.patch")]:
        out.append(f"require listed {facts}")
    return out


def case_lane_reports_a_stale_requirement(work: Path) -> list[str]:
    layout = plant(work)
    current = run("sh", "tools/pymetta-host/declare-host.sh", "require", cwd=layout).stdout
    (layout / "engine/host_patches.pl").write_text(current)
    out = []
    if (finding := lane.stale_requirement(layout)) is not None:
        out.append(f"a current requirement was reported: {finding}")
    (layout / "engine/host_patches.pl").write_text(current.replace("a.patch", "edited.patch"))
    if lane.stale_requirement(layout) is None:
        out.append("an edited requirement was not reported")
    return out


def case_lane_reports_an_undeclared_host(work: Path) -> list[str]:
    layout = plant(work)
    # A requirement no real host can declare: its patch exists only here.
    (layout / "engine/host_patches.pl").write_text(
        run("sh", "tools/pymetta-host/declare-host.sh", "require", cwd=layout).stdout
    )
    finding = lane.refused_host(layout)
    out = []
    if finding is None or "a.patch" not in finding:
        out.append(f"a host lacking the planted patches was not refused by name: {finding}")
    return out


CASES: list[Callable[[Path], list[str]]] = [
    case_declare_every_patch,
    case_declare_fails_closed,
    case_declare_refuses_a_home_without_a_launcher,
    case_require_lists_every_patch,
    case_lane_reports_a_stale_requirement,
    case_lane_reports_an_undeclared_host,
]


def main() -> int:
    """Run every case in its own scratch directory; exit 1 when any defect is found."""
    defects = 0
    for case in CASES:
        work = Path(tempfile.mkdtemp(prefix=f"host-declaration-{case.__name__}-"))
        try:
            for failure in case(work):
                print(f"  {case.__name__}: {failure}")
                defects += 1
        finally:
            shutil.rmtree(work, ignore_errors=True)
    print(f"host-declaration selftest: {defects} defect(s) over {len(CASES)} cases")
    return 1 if defects else 0


if __name__ == "__main__":
    sys.exit(main())
