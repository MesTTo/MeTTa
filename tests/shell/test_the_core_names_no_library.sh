#!/bin/sh
# Purpose: run the core with ZERO extension packages installed, and then with a
#   subset, and watch every generic door behave.
#
#   This is the other half of the stranger proof. That one shows a library
#   nobody here has heard of reaching nine doors; this one shows what those
#   doors do when NOTHING has registered against them: they refuse by name,
#   naming the point and the command that installs the packages this repository
#   ships for it, and everything that does not need a registrant keeps working.
#   Between them the two say what "pymetta ships zero integrations" means in
#   both directions.
#
#   The environment is built rather than assumed. `PYTHONPATH` is the seat's
#   own directory and nothing else, so none of `ext/` is
#   importable and `importlib.metadata` finds no `metta.extensions` entry
#   point; the second half installs two members into a scratch --target
#   directory, which is a real distribution with real entry points, so the
#   subset case is the shipped discovery path and not an import.
# Guarantees:
#   - with no package: the frame, sql, arrow, ipc, index, array and graphql
#     doors each refuse naming their point and their extra, is_transport_failure
#     still classes an OSError, a dataclass still projects, and the seam still
#     answers its whole surface.
#   - with metta-pandas alone: to_df() builds a frame through the ENTRY POINT
#     with nothing imported by hand. Unregistered namespace members and short
#     sugars are absent; rows.to(library) retains the named missing-provider
#     refusal [tested: sh tools/check.sh no-packages; commit=485c29c11666dc7421b751c9189d091ab7dbdf4b].
# Fails when: uv is absent, which it refuses on rather than skipping.
# Open Obligations:
#   To Do: None
#   Hacks: None
#   Future Enhancements: None
set -eu

PYTHONFAULTHANDLER=1
export PYTHONFAULTHANDLER

command -v uv >/dev/null

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
: "${CHECK_PY:=python3}"
mkdir -p "$project_dir/ai-tmp"
# Under the repository rather than under /tmp, which is RAM-backed on the
# machines this runs on and where a killed run leaks a site directory nobody
# reclaims; ai-tmp is on disk, is visible in `git status`, and goes with the
# checkout.
scratch=$(mktemp -d "$project_dir/ai-tmp/no-packages-XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

cat > "$scratch/none.py" <<'NONE'
"""Every generic door, with nothing registered against any point."""

import dataclasses

import metta
from metta import G, S, seam
from metta.convert import project
from metta._errors.errors import is_transport_failure
from metta._spaces.results import Rows

assert seam.advertised() == {}, seam.advertised()

# Every point is still declared and still answers as data: what a program can
# extend does not depend on what happens to be installed.
points = seam.points()
for name in ("frame", "sql", "array", "index", "arrow", "ipc", "graphql",
             "transport-error", "image"):
    assert name in points, sorted(points)
print("seam            :", len(points), "points declared with nothing installed")

# The four rows this package DOES ship are structural and name no library.
# A service's one row is the SEAT's by construction, so the claim is about the
# three kinds a REGISTRANT writes.
shipped = sorted(
    row.name
    for row in seam.rows()
    if row.source == "shipped"
    and seam.WRITTEN_BY[seam.at(row.point).kind] == "registrant"
)
assert shipped == ["dataclass", "enum", "match-args", "namedtuple"], shipped
print("shipped rows    :", " ".join(shipped), "-- not one library among them")


@dataclasses.dataclass
class Reading:
    """A class the seat reads structurally, with no package involved."""

    value: int


assert str(project(Reading(1)).atom) == "(Reading 1)"
print("image           : a dataclass projects with no package installed")

rows = Rows(("who", "n"), [(S.Ada, G(1)), (S.Bob, G(2))])
assert rows.table() == {"who": ["Ada", "Bob"], "n": [1, 2]}
print("table           : rows.table() is the plain dict any constructor takes")

for door, library in (("to_df", "pandas"), ("to_pl", "polars")):
    assert not hasattr(rows, door), f"{door} has no registered sugar row"
    try:
        rows.to(library)
    except TypeError as refusal:
        assert "no frame registration handles" in str(refusal), refusal
        assert "pymetta[dataframes]" in str(refusal), refusal
        assert "metta.extensions" in str(refusal), refusal
    else:
        message = f"rows.to({library!r}) answered with no frame package installed"
        raise AssertionError(message)
print("frame           : package sugars are absent; rows.to names the missing point and extra")

try:
    rows.__arrow_c_stream__()
except ImportError as refusal:
    assert "no arrow registration handles" in str(refusal), refusal
    assert "pymetta[arrow]" in str(refusal), refusal
else:
    message = "the Arrow capsule answered with no builder installed"
    raise AssertionError(message)
print("arrow           : the capsule doors refuse naming the point and the extra")

# A generic door that needs NO registrant keeps its whole meaning: an OSError
# is a transport failure whatever transports are installed.
assert is_transport_failure(OSError("gone"))
assert not is_transport_failure(ValueError("wrong, not absent"))
print("transport-error : an OSError still reads as an absent backend")

m = metta.MeTTa()
assert m.run("!(+ 1 2)") == [[3]], m.run("!(+ 1 2)")
for receiver in (m, m.self):
    for name in ("tables", "arrays", "live", "remote"):
        assert not hasattr(receiver, name), f"{name} has no registered namespace"
from metta.doors import Owner, table

# With nothing installed, discovery contributes no row: the discovered table
# and the core-only table are the same rows.
assert len(table()) == len(table(discover=False))
assert all(row.owner is not Owner.namespace for row in table().values())
m.close()
print("engine          : the engine runs, which is what zero integrations buys")
print("the core answers with no extension package installed")
NONE

cat > "$scratch/subset.py" <<'SUBSET'
"""One package installed, found through its entry point and nothing else."""

import sys

from metta import G, S, seam
from metta._spaces.results import Rows

assert sorted(seam.advertised()) == ["metta-pandas"], sorted(seam.advertised())
assert "metta_pandas" not in sys.modules, "advertising must import nothing"

rows = Rows(("who", "n"), [(S.Ada, G(1)), (S.Bob, G(2))])
frame = rows.to_df()
assert list(frame["who"]) == ["Ada", "Bob"], frame
assert "metta_pandas" in sys.modules, "the dispatch loads the advertised package"
print("subset          : to_df() through the entry point, with no import here")

try:
    rows.to("polars")
except TypeError as refusal:
    assert "registered: pandas" in str(refusal), refusal
else:
    message = "to_pl() answered with only metta-pandas installed"
    raise AssertionError(message)
assert not hasattr(rows, "to_pl"), "the absent provider contributes no short sugar"
from metta import MeTTa

with MeTTa() as context:
    assert list(context.tables.to_df(rows)["n"]) == [1, 2]
    assert not hasattr(context.tables, "to_pl")
    assert not hasattr(context, "arrays")
print("subset          : only registered sugars and namespace members exist")
print("a subset of the packages is a configuration, not a broken install")
SUBSET

# The core alone: the seat's directory and nothing under ext/.
PYTHONPATH="$project_dir/extensions/python" "$CHECK_PY" "$scratch/none.py"

# --python, because a member declares requires-python and uv would otherwise
# resolve against whatever interpreter it found rather than the one running the
# proof.
uv pip install --quiet --python "$CHECK_PY" --target "$scratch/site" --no-deps \
    "$project_dir/ext/metta-pandas"
# The version is NOT spelled here. It lives in ext/metta-pandas/pyproject.toml, and a copy of it in this
# file is a second representation that drifts on the next bump with no build
# error: the 0.8.0 to 0.9.0 bump left this line reading 0.8.0 and the lane
# failed with a bare `test -d`, printing NOTHING, because set -e stops the
# script and the EXIT trap wipes the scratch directory [measured 2026-09-22,
# two lanes down for one stale literal]. What is being claimed is that the
# install landed, so that is what is checked, by identity rather than version,
# and it says so when it has not.
installed=$(find "$scratch/site" -maxdepth 1 -type d -name 'metta_pandas-*.dist-info' | wc -l)
if [ "$installed" -ne 1 ]; then
    echo "expected exactly one metta_pandas-*.dist-info in $scratch/site, found $installed;" >&2
    echo "  uv pip install of ext/metta-pandas did not land" >&2
    exit 1
fi

PYTHONPATH="$scratch/site:$project_dir/extensions/python" "$CHECK_PY" "$scratch/subset.py"

echo "the core names no library: passed"
