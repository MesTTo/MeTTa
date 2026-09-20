"""Purpose: prove check_script_references reads a root variable as assigned.

It must resolve the variable the way the file writes it, and report a tail
that is not there.

Two earlier versions of that checker were refuted, and each planted case here
is one of those refutations held in place. A checker nobody has seen fail on a
planted defect is the shape this whole session kept finding.

Assumes: run inside a checkout.
Guarantees:
  - a suffix inside the command substitution is read
  - a suffix written AFTER the closing paren is read, which is the shape
    engine/test.sh uses and which one version missed by a directory
  - a variable the file does not assign is left alone rather than guessed at
  - a tail that resolves is not reported, and one that does not is
Fails when: run outside a checkout, which it reports.
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
import check_script_references as checked
from gate_layout import BOUNDED  # noqa: E402  -- the directory above is installed first

#: text, the file it stands for, the variable, and the directory it must name.
BASES: tuple[tuple[str, str, str, str], ...] = (
    ('HERE=$(cd -- "$(dirname -- "$0")" && pwd)\n', "tools/x.sh", "HERE", "tools"),
    ('HERE=$(cd -- "$(dirname -- "$0")/.." && pwd)\n', "tools/x.sh", "HERE", "."),
    # The suffix outside the parens, which engine/test.sh writes.
    ('HERE=$(cd -- "$(dirname -- "$0")" && pwd)/..\n', "tools/x.sh", "HERE", "."),
    ('ROOT=$(cd "$(dirname "$0")/../.." && pwd)\n', "a/b/x.sh", "ROOT", "."),
)


def planted_tree() -> list[str]:
    """findings() itself, over a tree that is a repository with a broken
    reference in it and a sound one beside it.

    The cases above exercise the two readers; this exercises what the module
    GUARANTEES, which is what it reports. check_process_bounds_selftest holds
    its own checker the same way, and without this the end-to-end promise was
    made by a docstring and proved only by hand.
    """  # noqa: D205  -- the narrative is one continuous invariant
    out: list[str] = []
    with tempfile.TemporaryDirectory(prefix="script-refs-") as scratch:
        root = Path(scratch)
        (root / "tools").mkdir()
        (root / BOUNDED).write_text("#!/bin/sh\n")
        head = 'HERE=$(cd -- "$(dirname -- "$0")/.." && pwd)\n'
        (root / "tools" / "sound.sh").write_text(
            head + 'bounded() { sh "$HERE/tools/bounded.sh" "$@"; }\n')
        (root / "tools" / "broken.sh").write_text(
            head + 'bounded() { sh "$HERE/bounded.sh" "$@"; }\n')
        for command in (["init", "-q"], ["add", "-A"]):
            subprocess.run(["git", "-C", str(root), *command],
                           capture_output=True, check=False)
        reported = checked.findings(root)
        named = [line for line in reported if "broken.sh" in line]
        if not named:
            out.append("findings() did not report a reference to a file that is not there")
        if any("sound.sh" in line for line in reported):
            out.append("findings() reported a reference that resolves")
    return out


def main() -> int:
    """Run every planted case and report the ones that went wrong."""
    problems: list[str] = []
    root = checked.ROOT
    for text, rel, name, wanted in BASES:
        found = checked.bases(text, root / rel)
        got = found.get(name)
        if got is None:
            problems.append(f"{text.strip()!r}: {name} was not read at all")
        elif got.resolve() != (root / wanted).resolve():
            problems.append(
                f"{text.strip()!r}: {name} read as {got}, wanted {(root / wanted).resolve()}"
            )
    # A variable the file never assigns says nothing about where its tail sits.
    if checked.bases("bounded() { sh \"$NOPE/x.sh\"; }\n", root / "tools/x.sh"):
        problems.append("a variable the file does not assign was resolved anyway")
    # The reference shape itself.
    pairs = checked.REFERENCE.findall('bounded() { sh "$HERE/tools/bounded.sh" "$@"; }')
    if pairs != [("HERE", BOUNDED)]:
        problems.append(f"the reference pattern read {pairs}")
    problems += planted_tree()
    for problem in problems:
        print(f"  {problem}")
    print(f"script-references-selftest: {len(problems)} finding(s) over "
          f"{len(BASES) + 4} planted case(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
