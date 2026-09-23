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
  - the same count is found however it is spelled: a `.parent` chain, a base
    without `.resolve()`, a count through a name, one inside a function, an
    `os.path.dirname` chain, and a count from `seat()` or from a path inside the
    seat [tested: this file; commit=WORKTREE]
  - a step onto the file's own directory, wheel-only data beside the file, and
    a walk that starts above the seat to leave the checkout are NOT reported, and
    evaluating a module line runs no `open` [tested: this file; commit=WORKTREE]
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

# The same counts, spelled every other way the language allows. Where a count lands
# is evaluated rather than matched, so none of these may slip past the rule the
# first two cases state.
REACHES_THE_SEAT_BY_PARENT_STEPS = '''
from pathlib import Path
SEAT = Path(__file__).resolve().parent.parent.parent
'''

REACHES_ABOVE_UNRESOLVED = '''
from pathlib import Path
ROOT = Path(__file__).parents[3]
'''

REACHES_ABOVE_THROUGH_A_NAME = '''
from pathlib import Path
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
'''

COUNTS_INSIDE_A_FUNCTION = '''
from pathlib import Path
def root():
    return Path(__file__).parents[3]
'''

COUNTS_BY_DIRNAME = '''
import os.path as osp
SEAT = osp.dirname(osp.dirname(osp.dirname(osp.abspath(__file__))))
'''

# A count from a DERIVED root is still a count: this is the seat's depth in the
# workspace written as a number, and it goes stale on the same move.
COUNTS_FROM_THE_SEAT = '''
from metta._roots import seat
WORKSPACE = seat().parents[1]
'''

# And from a path inside the seat, reached through a relative import.
COUNTS_FROM_INSIDE_THE_SEAT = '''
from .._roots import seat
CORE = seat() / "metta"
IMPORT_ROOT = CORE.parent
'''

# The file's own directory moves with the file, so it is no count. Planted at the
# seat's top, where that directory IS the seat, since only there could it be mistaken
# for a walk to a root.
NAMES_ITS_OWN_DIRECTORY = '''
from pathlib import Path
HERE = Path(__file__).resolve().parent
'''

# metta/_host's shape: data a built wheel carries beside the module, absent in a
# checkout, in a file that says `.parents` for another reason.
CARRIES_WHEEL_DATA = '''
from pathlib import Path
HERE = Path(__file__).resolve().parent
BUNDLED = HERE / "present-only-in-a-built-wheel"
def carried(module_file):
    return HERE in Path(module_file).parents
'''

# Starting above the seat, a step leaves the checkout rather than counting a level
# of it: a sibling repository is found beside the workspace.
LEAVES_THE_CHECKOUT = '''
from metta._roots import workspace
def upstream():
    return workspace().parent / "PeTTa-base"
'''

# Evaluating a module's bindings must not run them: were `open` reachable, this
# line would create the file the check below looks for.
WOULD_WRITE_A_FILE = '''
from pathlib import Path
HERE = Path(__file__).resolve().parent
TOUCHED = open(str(HERE / "touched-by-the-lane"), "w")
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
        # The seat's real derivation, so `seat()` answers the fixture seat, plus a
        # count that would be reported were the file not exempt.
        (seat / "metta" / "_roots.py").write_text(
            (ROOT / "extensions/python/metta/_roots.py").read_text(encoding="utf-8")
            + "\n_COUNTED = Path(__file__).resolve().parents[1]\n",
            encoding="utf-8")
        (package / "reaches_the_seat.py").write_text(REACHES_THE_SEAT, encoding="utf-8")
        (package / "reaches_above.py").write_text(REACHES_ABOVE_THE_SEAT, encoding="utf-8")
        (package / "stays_inside.py").write_text(STAYS_INSIDE_THE_SEAT, encoding="utf-8")
        (package / "derives_it.py").write_text(THE_DERIVATION, encoding="utf-8")
        (package / "one_marker.py").write_text(DERIVES_FROM_ONE_MARKER, encoding="utf-8")
        (package / "wrong_root.py").write_text(DERIVES_THE_WRONG_ROOT, encoding="utf-8")
        (package / "right_root.py").write_text(DERIVES_THE_RIGHT_ROOT, encoding="utf-8")
        (package / "scratch_output.py").write_text(WRITES_ITS_OWN_SCRATCH, encoding="utf-8")
        planted = {
            "parent_steps.py": REACHES_THE_SEAT_BY_PARENT_STEPS,
            "unresolved.py": REACHES_ABOVE_UNRESOLVED,
            "through_a_name.py": REACHES_ABOVE_THROUGH_A_NAME,
            "in_a_function.py": COUNTS_INSIDE_A_FUNCTION,
            "by_dirname.py": COUNTS_BY_DIRNAME,
            "from_the_seat.py": COUNTS_FROM_THE_SEAT,
            "from_inside.py": COUNTS_FROM_INSIDE_THE_SEAT,
            "wheel_data.py": CARRIES_WHEEL_DATA,
            "leaves.py": LEAVES_THE_CHECKOUT,
            "would_write.py": WOULD_WRITE_A_FILE,
        }
        for name, source in planted.items():
            (package / name).write_text(source, encoding="utf-8")
        (seat / "own_directory.py").write_text(NAMES_ITS_OWN_DIRECTORY, encoding="utf-8")
        reported = {line.split(":")[0].rsplit("/", 1)[1] for line in findings(seat)}
        touched = (package / "touched-by-the-lane").exists()
    assert not touched, "evaluating a module line ran `open`"
    assert "reaches_the_seat.py" in reported, f"a walk to the seat was not found: {reported}"
    assert "reaches_above.py" in reported, f"a walk above the seat was not found: {reported}"
    assert "stays_inside.py" not in reported, f"a package-relative walk was reported: {reported}"
    assert "derives_it.py" not in reported, f"the derivation was reported: {reported}"
    assert "one_marker.py" in reported, f"a `.git`-only derivation was not found: {reported}"
    assert "_roots.py" not in reported, f"the file defining the derivation was reported: {reported}"
    assert "wrong_root.py" in reported, f"a derivation on the wrong root was not found: {reported}"
    assert "right_root.py" not in reported, f"a correct derivation was reported: {reported}"
    assert "scratch_output.py" not in reported, f"a scratch output was reported: {reported}"
    respelled = {"parent_steps.py", "unresolved.py", "through_a_name.py", "in_a_function.py",
                 "by_dirname.py", "from_the_seat.py", "from_inside.py"}
    assert respelled <= reported, f"a respelled count was not found: {respelled - reported}"
    spared = {"own_directory.py", "wheel_data.py", "leaves.py", "would_write.py"}
    assert not spared & reported, f"reported what the rule spares: {spared & reported}"
    assert reported == {"reaches_the_seat.py", "reaches_above.py", "wrong_root.py",
                        "one_marker.py"} | respelled, f"unexpected: {reported}"
    print("root-walks selftest: a walk to the seat, one above it, the same counts spelled "
          "seven other ways, a derivation that lands on the wrong root, and one asking "
          "for `.git` alone are found; a walk inside the seat, a correct derivation, a "
          "scratch output, the file's own directory, wheel-only data, a walk leaving the "
          "checkout and _roots.py itself are not, and no module line ran")
    return 0


if __name__ == "__main__":
    sys.exit(main())
