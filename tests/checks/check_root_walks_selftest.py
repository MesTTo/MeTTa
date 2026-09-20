"""Purpose: prove check_root_walks.py finds a counted root walk and spares the rest.

Running the pass on this repository proves the seat is clean today. It says nothing
about whether the pass can find the defect at all, nor about the three shapes it
must NOT flag, and the third is the load-bearing one: a count that lands INSIDE the
seat is package-relative and legitimate, so a pass that refused every `parents[N]`
would be turned off within a day. All four are planted here in a fixture seat the
test builds and throws away.

Assumes: a writable ai-tmp/ in this repository.
Guarantees:
  - a walk reaching the seat, and one reaching above it, are both reported with
    their lines [tested: this file; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f]
  - a walk landing inside the seat is NOT reported [tested: this file; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f]
  - the derivation, which names the marker instead of a depth, is NOT reported
    [tested: this file; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f]
  - `metta/_roots.py` is exempt, being where the derivation is written down
    [tested: this file; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f]
  - a derivation using a CORRECT marker for the wrong root is reported through the
    path it then fails to name, which no check on the spelling could see
    [tested: this file; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f]
  - a correct derivation, and one naming scratch the program writes, are NOT
    reported [tested: this file; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f]
Fails when: run against a tree it did not write. It asserts on its own fixture.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))

from check_root_walks import findings  # noqa: E402  -- the path is installed above

# Planted at seat/metta/doors/, so parents[0] is doors, [1] is metta, [2] is the seat
# and [3] is above it. The depths are written for that position deliberately: the
# pass decides by where a count LANDS, so the fixture has to land somewhere real.
REACHES_THE_SEAT = '''
from pathlib import Path
SEAT = Path(__file__).resolve().parents[2]
'''

REACHES_ABOVE_THE_SEAT = '''
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
'''

STAYS_INSIDE_THE_SEAT = '''
from pathlib import Path
CATALOG = Path(__file__).resolve().parents[0] / "door_catalog.pl"
'''

THE_DERIVATION = '''
from pathlib import Path
SEAT = next(parent for parent in Path(__file__).resolve().parents
            if (parent / "pyproject.toml").exists() or (parent / ".git").exists())
'''

# The marker set matters even when the root it reaches is right here. A component
# is a distribution OR a repository, and a tree copied without its history has only
# the first, which is the tree every gate in this repository runs in. Asking for
# `.git` alone therefore answers a different directory there, and the failure
# arrives as whatever reads the path rather than at the walk.
DERIVES_FROM_ONE_MARKER = '''
from pathlib import Path
SEAT = next(parent for parent in Path(__file__).resolve().parents if (parent / '.git').exists())
'''

# The defect a marker check cannot see. `.git` is a CORRECT seat marker, and every
# component of a superproject has one, so a walk looking for it stops at the nearest
# component. Nothing about the spelling is wrong; what is wrong is where it lands,
# and that only becomes observable on the next line, where a workspace-only name is
# joined onto it. This is the shape that put 29 sites on the wrong root.
DERIVES_THE_WRONG_ROOT = '''
from pathlib import Path
ROOT = next(parent for parent in Path(__file__).resolve().parents if (parent / '.git').exists())
ENGINE = ROOT / "engine"
'''

DERIVES_THE_RIGHT_ROOT = '''
from pathlib import Path
ROOT = next(parent for parent in Path(__file__).resolve().parents
            if (parent / "engine").is_dir() and (parent / "lib").is_dir())
ENGINE = ROOT / "engine"
'''

# Scratch this repository writes rather than reads, so naming something absent is
# the normal case and not a wrong root.
WRITES_ITS_OWN_SCRATCH = '''
from pathlib import Path
ROOT = next(parent for parent in Path(__file__).resolve().parents
            if (parent / "engine").is_dir() and (parent / "lib").is_dir())
OUTPUT = ROOT / "ai-tmp" / "written-when-this-runs.metta"
'''


def main() -> int:
    """Plant every shape the pass must separate, and check it separates them."""
    scratch = ROOT / "ai-tmp"
    scratch.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=scratch) as directory:
        workspace = Path(directory)
        seat = workspace / "extensions" / "python"
        package = seat / "metta" / "doors"
        package.mkdir(parents=True)
        # The two markers, so both derivations resolve: the workspace holds engine/
        # and lib/, and the seat carries a component marker the way a submodule does.
        (workspace / "engine").mkdir()
        (workspace / "lib").mkdir()
        (seat / ".git").write_text("gitdir: elsewhere\n", encoding="utf-8")
        # The package-relative case names a real sibling, as it does in the seat. A
        # derived path that names nothing is a finding whatever built it, so the
        # fixture has to carry the file rather than assert the check ignores it.
        (package / "door_catalog.pl").write_text("% fixture\n", encoding="utf-8")
        (seat / "metta" / "_roots.py").write_text(
            "from pathlib import Path\nROOT = Path(__file__).resolve().parents[2]\n",
            encoding="utf-8")
        (package / "reaches_the_seat.py").write_text(REACHES_THE_SEAT, encoding="utf-8")
        (package / "reaches_above.py").write_text(REACHES_ABOVE_THE_SEAT, encoding="utf-8")
        (package / "stays_inside.py").write_text(STAYS_INSIDE_THE_SEAT, encoding="utf-8")
        (package / "derives_it.py").write_text(THE_DERIVATION, encoding="utf-8")
        (package / "one_marker.py").write_text(DERIVES_FROM_ONE_MARKER, encoding="utf-8")
        (package / "wrong_root.py").write_text(DERIVES_THE_WRONG_ROOT, encoding="utf-8")
        (package / "right_root.py").write_text(DERIVES_THE_RIGHT_ROOT, encoding="utf-8")
        (package / "scratch_output.py").write_text(WRITES_ITS_OWN_SCRATCH, encoding="utf-8")
        reported = {line.split(":")[0].rsplit("/", 1)[1] for line in findings(seat)}
    assert "reaches_the_seat.py" in reported, f"a walk to the seat was not found: {reported}"
    assert "reaches_above.py" in reported, f"a walk above the seat was not found: {reported}"
    assert "stays_inside.py" not in reported, f"a package-relative walk was reported: {reported}"
    assert "derives_it.py" not in reported, f"the derivation was reported: {reported}"
    assert "one_marker.py" in reported, f"a `.git`-only derivation was not found: {reported}"
    assert "_roots.py" not in reported, f"the file defining the derivation was reported: {reported}"
    assert "wrong_root.py" in reported, f"a derivation on the wrong root was not found: {reported}"
    assert "right_root.py" not in reported, f"a correct derivation was reported: {reported}"
    assert "scratch_output.py" not in reported, f"a scratch output was reported: {reported}"
    assert reported == {"reaches_the_seat.py", "reaches_above.py", "wrong_root.py",
                        "one_marker.py"}, f"unexpected: {reported}"
    print("root-walks selftest: a walk to the seat, one above it, a derivation that "
          "lands on the wrong root, and one asking for `.git` alone are found; a walk "
          "inside the seat, a correct derivation, a scratch output, and _roots.py "
          "itself are not")
    return 0


if __name__ == "__main__":
    sys.exit(main())
