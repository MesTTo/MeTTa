"""Purpose: hold check_shared_intro to the four things it can get wrong.

Assumes: nothing about the real tree; each case plants its own pages, so a
    change to a README cannot make this pass or fail for a reason that is not
    about the checker.
Guarantees:
  - drift between two copies is reported, or the check could not fail at all
    [tested: this file]
  - a front page with no block is reported, which is the case a deletion gives
    [tested: this file]
  - a malformed marker is reported rather than read as absence
    [tested: this file]
  - a page OUTSIDE the front-page list is still held to the same text, so a
    fifth copy cannot drift quietly [tested: this file]
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

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from check_shared_intro import CLOSE, FRONT_PAGES, OPEN  # noqa: E402  -- HERE first

GOOD = "\n## What MeTTa is\n\nA language for rewriting metagraphs.\n"
DRIFTED = "\n## What MeTTa is\n\nA language for rewriting metagraphs, slightly reworded.\n"


def plant(root: Path, bodies: dict[str, str]) -> None:
    """A tree holding exactly these pages."""
    for name, text in bodies.items():
        path = root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
    tools = root / "tools" / "checks"
    tools.mkdir(parents=True, exist_ok=True)
    (tools / "check_shared_intro.py").write_text(
        (HERE / "check_shared_intro.py").read_text(encoding="utf-8"), encoding="utf-8")
    # A repository, because the checker asks git which files carry the marker
    # rather than globbing for them. An unplanted tree would answer nothing and
    # every case would pass for the wrong reason.
    for command in (
        ["git", "init", "-q"],
        ["git", "add", "-A"],
        ["git", "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "fixture"],
    ):
        subprocess.run(command, cwd=root, check=True, capture_output=True)


def run(root: Path) -> subprocess.CompletedProcess[str]:
    """The real checker, over the planted tree."""
    return subprocess.run(
        [sys.executable, str(root / "tools/checks/check_shared_intro.py")],
        capture_output=True, text=True, check=False)


def wrapped(text: str) -> str:
    """A page carrying the block."""
    return f"# Page\n\n{OPEN}{text}{CLOSE}\n\nmore prose\n"


def cases() -> list[tuple[str, dict[str, str], int, str]]:
    """Each case: what it is for, the pages, the exit wanted, text the output must carry."""
    every = {name: wrapped(GOOD) for name in FRONT_PAGES}
    drifted = dict(every); drifted["extensions/node/README.md"] = wrapped(DRIFTED)
    absent = dict(every); absent["extensions/cmetta/README.md"] = "# Page\n\nno block\n"
    twice = dict(every)
    twice["extensions/python/README.md"] = wrapped(GOOD) + wrapped(GOOD)
    reversed_markers = dict(every)
    reversed_markers["extensions/node/README.md"] = f"# Page\n\n{CLOSE}{GOOD}{OPEN}\n"
    extra = dict(every); extra["lib/README.md"] = wrapped(DRIFTED)
    # Nested, not at a repository root: the glob that answered this before
    # reached one level down and could not see it.
    nested = dict(every); nested["lib/lib_random/README.md"] = wrapped(DRIFTED)
    return [
        ("every copy agreeing", every, 0, "0 defect(s)"),
        ("one copy reworded", drifted, 1, "differs from README.md"),
        ("a front page with no block", absent, 1, "carries no"),
        ("the block opened twice", twice, 1, "2 opening"),
        ("the markers the wrong way round", reversed_markers, 1, "comes before"),
        ("a page outside the list drifting", extra, 1, "lib/README.md"),
        ("a NESTED page drifting", nested, 1, "lib/lib_random/README.md"),
    ]


def main() -> int:
    """Run every case against a planted tree and report the ones that disagree."""
    bad = 0
    with tempfile.TemporaryDirectory() as scratch:
        for index, (what, bodies, want, carries) in enumerate(cases()):
            root = Path(scratch) / str(index)
            root.mkdir()
            plant(root, bodies)
            done = run(root)
            out = done.stdout + done.stderr
            if done.returncode != want:
                print(f"  {what}: exit {done.returncode}, wanted {want}\n    {out.strip()[:160]}")
                bad += 1
            elif carries not in out:
                print(f"  {what}: exit {done.returncode} as wanted, but nothing said {carries!r}"
                      f"\n    {out.strip()[:160]}")
                bad += 1
    print(f"shared-intro-selftest: {len(cases()) - bad} of {len(cases())} cases hold")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
