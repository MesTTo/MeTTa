"""Purpose: every metta fence in a component README runs on a fresh engine.

Each runs in a directory of its own too, so a page that shows the language
cannot show something the engine will not do.

`test_readme.py` covers the repository root README, and the website's run-fence
rule covers `website/` pages. That left the component front pages ungated: the
engine's, the library pack's, the examples index's, each library's own, and the
MORK backend's, 130 fences between them. A showcase that shows code which does
not run is worse than one that shows none.

WHY A PROCESS EACH, rather than a pytest parametrisation sharing one engine.
Both isolations are load-bearing and neither is available in-process:

  - a fresh ENGINE, because state outlives a fence. Run together in one engine,
    fences collided on `bind!` names, inherited spaces another had filled, and
    one read `[a,c]` four times where it asserts once.
  - a fresh DIRECTORY, because fences write. Run in the checkout, the file and
    CSV examples left `report.txt`, `blob.bin`, `sales.csv` and `prices.csv` in
    the repository root.

A reader pastes one block into a fresh session in their own project, which is
exactly what this does.

Cost: one engine boot per fence, about 1.5s, so 130 fences are around 195s
serially and a quarter of that at this pool size.

Assumes: `tools/bounded.sh`, and a python that can import `metta`.
Guarantees:
  - a fence that does not run fails the check and is named with its file and
    index [tested: tests/checks/check_readme_fences_selftest.py]
  - a fence naming a network URL or `git-import!` fails without being run, for
    the reason test_readme.py gives: documentation that clones a repository is
    remote code execution inside a test
Fails when: run outside a checkout, which it reports.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import re
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
# The sys.path line above is what makes this importable.
from bounded_spawn import bounded

#: Derived, not counted.
ROOT = next(parent for parent in Path(__file__).resolve().parents
            if (parent / "engine").is_dir() and (parent / "lib").is_dir())
SEAT = ROOT / "extensions/python"
#: The root README has its own executor, which also mirrors its ts and c fences.
COVERED_ELSEWHERE = ("README.md",)
NOT_HERMETIC = ("git-import!", "https://", "http://")
#: Every component that is its own repository, plus the superproject.
COMPONENTS = ("", "lib", "ext", "examples", "engine", "extensions/python",
              "extensions/node", "extensions/cmetta", "extensions/mork")
WORKERS = 8
CEILING = 90.0

_RUNNER = """
import sys
sys.path.insert(0, {seat!r})
import metta
metta.space().run(sys.stdin.read())
"""


def readmes() -> list[str]:
    """Every README this repository or one of its components TRACKS.

    Asked of git rather than globbed: `extensions/node/_runtime/` and
    `extensions/cmetta/build/install-check/` each carry a copy of the library
    pack, and a copy is not a page anyone reads.
    """
    found: list[str] = []
    for component in COMPONENTS:
        directory = ROOT / component if component else ROOT
        if component and not (directory / ".git").exists():
            continue
        listed = subprocess.run(
            ["git", "-C", str(directory), "ls-files", "*README.md", "README.md"],
            capture_output=True, text=True, check=False,
        ).stdout.split()
        found += [f"{component}/{path}" if component else path for path in listed]
    return sorted(set(found) - set(COVERED_ELSEWHERE))


def fences() -> list[tuple[str, int, str]]:
    """Each metta fence, with the file and the position that names it."""
    out: list[tuple[str, int, str]] = []
    for rel in readmes():
        path = ROOT / rel
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8")
        for index, body in enumerate(re.findall(r"```metta\n(.*?)```", text, re.DOTALL)):
            out.append((rel, index, body))
    return out


def run_one(item: tuple[str, int, str]) -> str | None:
    """Run one fence; the reason it failed, or None."""
    rel, index, body = item
    found = [mark for mark in NOT_HERMETIC if mark in body]
    if found:
        return (f"{rel} fence {index} names {found}, so running it would reach the "
                f"network; show the feature locally and link the corpus file that "
                f"exercises the network one")
    if not body.strip():
        return None
    with tempfile.TemporaryDirectory(prefix="metta-fence-") as scratch:
        # bounded() WRAPS the command rather than running it, so the bound
        # shares this process's fate and an orphan cannot outlive the check.
        finished = subprocess.run(
            bounded([sys.executable, "-c", _RUNNER.format(seat=str(SEAT))],
                    ceiling=CEILING),
            cwd=scratch, input=body, capture_output=True, text=True,
            check=False, timeout=CEILING,
        )
    if finished.returncode == 0:
        return None
    last = [line for line in (finished.stderr or "").strip().splitlines() if line.strip()]
    return (f"{rel} fence {index} does not run on a fresh space: "
            f"{last[-1][:200] if last else 'no output'}")


def main() -> int:
    """Run every fence and name the ones that do not."""
    items = fences()
    if not items:
        print("readme-fences: no metta fences found, so this check proves nothing", file=sys.stderr)
        return 1
    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        problems = [problem for problem in pool.map(run_one, items) if problem]
    for problem in problems:
        print(f"  {problem}")
    pages = len({rel for rel, _, _ in items})
    print(f"readme-fences: {len(problems)} finding(s) over {len(items)} metta "
          f"fence(s) in {pages} component README(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
