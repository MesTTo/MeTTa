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
    home's launcher and lists each patch with the sha256 of its file, a patch
    under packages/swipy/ applied in that nested repository included; with no
    launcher it refuses and writes nothing; over a tree lacking one patch it
    exits 1 and omits exactly that one; `require TREE` lists exactly the
    patches under TREE in name order under that tree's module header, and
    refuses two patches sharing a name [tested: this file; commit=WORKTREE]
  - `declare --built-by COMMAND...` binds a home with no launcher, the shape
    of the WebAssembly host, to the one line COMMAND prints, and refuses,
    writing nothing, when COMMAND exits nonzero, prints nothing or prints more
    than one line [tested: this file; commit=02dc5471b552c74826880441400114c798ea66ca]
  - the lane reports an edited requirement, a patched tree no requirement
    file covers, and a host that does not declare what a requirement names,
    and passes a matching pair [tested: this file; commit=WORKTREE]
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
PATCH_C = "--- a/three.txt\n+++ b/three.txt\n@@ -1 +1 @@\n-three\n+three patched\n"
NESTED = "packages/swipy"


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
    """A git tree holding every target, packages/swipy a repository of its own,
    with the named patches applied each in the tree it sits under."""
    tree = work / "src"
    (tree / NESTED).mkdir(parents=True)
    (tree / "one.txt").write_text("one\n")
    (tree / "two.txt").write_text("two\n")
    (tree / NESTED / "three.txt").write_text("three\n")
    run("git", "init", "--quiet", ".", cwd=tree)
    run("git", "init", "--quiet", ".", cwd=tree / NESTED)
    for name in applied:
        root = tree / Path(name).parent
        run("git", "apply", str(work / "repo/tests/checks/host_workarounds" / name), cwd=root)
    return tree


def nest(layout: Path) -> None:
    """Add the patch to packages/swipy, sitting where that tree's patches sit."""
    (layout / "tests/checks/host_workarounds" / NESTED).mkdir(parents=True)
    (layout / "tests/checks/host_workarounds" / NESTED / "c.patch").write_text(PATCH_C)


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
    """The declaration line for one planted patch, keyed by its file name."""
    path = layout / "tests/checks/host_workarounds" / name
    return f"host_patch('{Path(name).name}', '{digest(path)}')."


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


def case_declare_built_by_names_the_build(work: Path) -> list[str]:
    layout = plant(work)
    tree = source(work, "a.patch", "b.patch")
    home = work / "wasm-home"
    home.mkdir()
    built = "Sep 23 2026, 21:00:00"
    ran = run(
        "sh", "tools/pymetta-host/declare-host.sh", "declare", str(tree), str(home),
        "--built-by", "echo", built, cwd=layout,
    )
    out = []
    if ran.returncode != 0:
        out.append(f"a launcherless home declared --built-by exited {ran.returncode}: {ran.stderr.strip()}")
        return out
    text = (home / "metta-host.pl").read_text()
    if f"\nhost_build('{built}').\n" not in text:
        out.append(f"the declaration does not name the build the command printed: {text!r}")
    for name in ("a.patch", "b.patch"):
        if fact(layout, name) not in text:
            out.append(f"the declaration lacks {fact(layout, name)}")
    return out


def case_declare_built_by_fails_closed(work: Path) -> list[str]:
    layout = plant(work)
    tree = source(work, "a.patch", "b.patch")
    home = work / "wasm-home"
    home.mkdir()
    out = []
    for command in (("false",), ("true",), ("printf", "one\ntwo\n")):
        ran = run(
            "sh", "tools/pymetta-host/declare-host.sh", "declare", str(tree), str(home),
            "--built-by", *command, cwd=layout,
        )
        if ran.returncode != 1:
            out.append(f"--built-by {command} exited {ran.returncode}, wanted 1: {ran.stderr.strip()}")
        if (home / "metta-host.pl").exists():
            out.append(f"--built-by {command} wrote a declaration with no single build to bind it to")
            (home / "metta-host.pl").unlink()
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


def case_declare_applies_a_nested_patch_in_its_own_tree(work: Path) -> list[str]:
    layout = plant(work)
    nest(layout)
    tree = source(work, "a.patch", "b.patch", f"{NESTED}/c.patch")
    home = planted_home(work)
    ran = run("sh", "tools/pymetta-host/declare-host.sh", "declare", str(tree), str(home), cwd=layout)
    out = []
    if ran.returncode != 0:
        out.append(f"a fully patched tree with a nested patch exited {ran.returncode}: {ran.stderr.strip()}")
    text = (home / "metta-host.pl").read_text()
    if fact(layout, f"{NESTED}/c.patch") not in text:
        out.append(f"the nested patch is missing from the declaration: {text!r}")
    return out


def case_require_splits_by_tree(work: Path) -> list[str]:
    layout = plant(work)
    nest(layout)
    top = run("sh", "tools/pymetta-host/declare-host.sh", "require", cwd=layout).stdout
    nested = run("sh", "tools/pymetta-host/declare-host.sh", "require", NESTED, cwd=layout).stdout
    out = []
    if [line for line in top.splitlines() if line.startswith("host_patch(")] != [
            fact(layout, "a.patch"), fact(layout, "b.patch")]:
        out.append(f"require listed more than the top-level patches: {top!r}")
    if [line for line in nested.splitlines() if line.startswith("host_patch(")] != [
            fact(layout, f"{NESTED}/c.patch")]:
        out.append(f"require {NESTED} did not list exactly c.patch: {nested!r}")
    if ":- module(metta_host_patches_packages_swipy, [host_patch/2])." not in nested:
        out.append("require packages/swipy printed no module header of its own")
    return out


def case_require_refuses_a_shared_name(work: Path) -> list[str]:
    layout = plant(work)
    (layout / "tests/checks/host_workarounds" / NESTED).mkdir(parents=True)
    (layout / "tests/checks/host_workarounds" / NESTED / "a.patch").write_text(PATCH_C)
    ran = run("sh", "tools/pymetta-host/declare-host.sh", "require", cwd=layout)
    if ran.returncode == 1 and "more than one patch is named a.patch" in ran.stderr:
        return []
    return [f"two patches named a.patch were not refused: exit {ran.returncode}, {ran.stderr.strip()}"]


def case_lane_reports_a_stale_requirement(work: Path) -> list[str]:
    layout = plant(work)
    current = run("sh", "tools/pymetta-host/declare-host.sh", "require", cwd=layout).stdout
    (layout / "engine/host_patches.pl").write_text(current)
    out = []
    if findings := lane.stale_requirements(layout):
        out.append(f"a current requirement was reported: {findings}")
    (layout / "engine/host_patches.pl").write_text(current.replace("a.patch", "edited.patch"))
    if not lane.stale_requirements(layout):
        out.append("an edited requirement was not reported")
    return out


def case_lane_reports_an_unrequired_tree(work: Path) -> list[str]:
    layout = plant(work)
    (layout / "tests/checks/host_workarounds/packages/other").mkdir(parents=True)
    (layout / "tests/checks/host_workarounds/packages/other/d.patch").write_text(PATCH_C)
    findings = lane.unrequired_trees(layout)
    if len(findings) == 1 and "packages/other" in findings[0]:
        return []
    return [f"a tree no requirement covers was not reported once by name: {findings}"]


def case_lane_reports_an_undeclared_host(work: Path) -> list[str]:
    layout = plant(work)
    # A requirement no real host can declare: its patch exists only here.
    (layout / "engine/host_patches.pl").write_text(
        run("sh", "tools/pymetta-host/declare-host.sh", "require", cwd=layout).stdout
    )
    findings = lane.refused_host(layout)
    out = []
    if not any("a.patch" in finding for finding in findings):
        out.append(f"a host lacking the planted patches was not refused by name: {findings}")
    return out


CASES: list[Callable[[Path], list[str]]] = [
    case_declare_every_patch,
    case_declare_built_by_names_the_build,
    case_declare_built_by_fails_closed,
    case_declare_fails_closed,
    case_declare_refuses_a_home_without_a_launcher,
    case_require_lists_every_patch,
    case_declare_applies_a_nested_patch_in_its_own_tree,
    case_require_splits_by_tree,
    case_require_refuses_a_shared_name,
    case_lane_reports_a_stale_requirement,
    case_lane_reports_an_unrequired_tree,
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
