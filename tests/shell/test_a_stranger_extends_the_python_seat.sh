#!/bin/sh
# Purpose: build a library this repository has never heard of, install it, and
#   watch it extend the Python seat through ten doors with no core edits.
#   The library is called `solars`, it is written by this script into a scratch
#   directory, and nothing about it exists in the checkout: no fixture package,
#   no test double, no name in any source file. If the seat can be extended
#   without forking, this passes; if a coupling comes back, it does not.
# Guarantees:
#   - every capability is reached through a DECLARED point of metta.seam, and
#     the program prints which door each one came through, so the proof says
#     what it proved rather than only that it passed.
#   - discovery is the shipped path: the package advertises one callable under
#     the `metta.extensions` entry-point group and the seat loads it on the
#     first dispatch that needs it, never at import. That half is its own
#     program because importing metta.tables is already such a dispatch.
#   - the checkout is read, never written: the package installs into a scratch
#     --target directory that goes on PYTHONPATH, so `importlib.metadata` finds
#     a real distribution with real entry points.
#   - a package-owned door reaches both Space and MeTTa as solars.frame, and
#     a retained method refuses after withdrawal. Its typed contract is
#     queryable at boot [tested: sh check.sh stranger-python; commit=485c29c11666dc7421b751c9189d091ab7dbdf4b].
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
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

mkdir -p "$scratch/solars/solars/metta" "$scratch/solars/tests"

cat > "$scratch/solars/pyproject.toml" <<'TOML'
[build-system]
requires = ["setuptools>=61"]
build-backend = "setuptools.build_meta"

[project]
name = "solars"
version = "0.1.0"
description = "a frame, query and vector library nobody in PeTTa has heard of"

[project.entry-points."metta.extensions"]
solars = "solars:register"

[project.entry-points."metta.spaces"]
solars = "solars:SolarSpace"

[project.entry-points."metta.libraries"]
solars = "solars:sources"

[tool.setuptools.packages.find]
include = ["solars*"]

[tool.setuptools.package-data]
solars = ["metta/*.metta"]
TOML

cat > "$scratch/solars/solars/metta/solars.metta" <<'METTA'
(= (solar-flare $x) (* 2 $x))
METTA

cat > "$scratch/solars/solars/__init__.py" <<'SOLARS'
"""solars: a library PeTTa has never heard of, extending its Python seat.

Nothing here is imported by PeTTa. One entry point in the `metta.extensions`
group names `register`, and the seat calls it the first time a dispatch has no
answer without it.
"""

import pathlib

from metta import seam
from metta.doors import (
    AnswersAs, Body, Determinism, Door as DoorContract, EffectClass, Kind,
    Owner, Provider, Receiver, Signature, Tier,
)
from metta.foreign import SpaceProvider


# ------------------------------------------------------------------- frames

class Frame:
    """A solars frame: named columns, and the values under them."""

    def __init__(self, columns):
        self.columns = dict(columns)

    def __repr__(self):
        return f"solars.Frame({list(self.columns)})"

    def column(self, name):
        return list(self.columns[name])

    def iter_rows(self):
        """Rows, the way a frame library already offers them to tables.add."""
        return zip(*self.columns.values(), strict=True)


class Door:
    """What `frame.metta` becomes: solars' own spelling of an accessor."""

    installed = None

    def __init__(self, frame):
        self.frame = frame


def install_accessor(module, name, door):
    """solars installs an accessor by putting the door on its frame class."""
    Door.installed = (name, door)
    setattr(module.Frame, name, property(door))


def build(source, projection, view):
    """A solars frame from the rows.

    Through the Arrow capsule when the seat has a builder for one, which is
    what makes solars a frame library rather than a list wrapper, and through
    the typed projection when it does not.
    """
    del source
    if view is not None:
        names, batches = seam.at("arrow").claim().row.batches(view)
        columns = {name: [] for name in names}
        for batch in batches:
            for row in batch:
                for name, cell in zip(names, row, strict=True):
                    columns[name].append(cell)
        return Frame(columns)
    return Frame(projection.table())


# -------------------------------------------------------------- a SQL engine

class Connection:
    """A solars query connection, with functions a program registers into."""

    def __init__(self):
        self.functions = {}

    def sql(self, name, *arguments):
        return self.functions[name](*arguments)


def claims_connection(connection):
    return connection if isinstance(connection, Connection) else None


def define(connection, name, call, head, signature):
    del head, signature
    connection.functions[name] = call


# ------------------------------------------------------------- a vector index

def index_available():
    return True


def index_build(matrix):
    return matrix


def index_search(matrix, query, count):
    """Brute force, in Python: enough to prove the door, not to win a race."""
    scores = [
        sum(float(a) * float(b) for a, b in zip(row, query, strict=True))
        for row in matrix
    ]
    order = sorted(range(len(scores)), key=lambda i: (-scores[i], i))
    return [(i, scores[i]) for i in order[:count]]


# --------------------------------------------------------- a transport error

class Timeout(Exception):
    """solars' own timeout, which deliberately does not subclass OSError."""


def transport_classes(module):
    return (module.Timeout,)


# ------------------------------------------------------------ a default image

class Model:
    """A solars model: a class this seat has no structural rule for."""

    solars_fields = ("first", "second")

    def __init__(self, first, second):
        self.first = first
        self.second = second


def image(cls):
    if not (isinstance(cls, type) and issubclass(cls, Model)):
        return None
    names = cls.solars_fields
    return seam.image_of(
        "expression",
        lambda obj: tuple(getattr(obj, name) for name in names),
        cls,
        cls.__name__,
        fields=names,
    )


# ---------------------------------------------------------- a space provider

class SolarSpace(SpaceProvider):
    """Atoms held in a solars store, reached through the foreign-space seam."""

    def __init__(self):
        self.held = []

    def add(self, atom):
        self.held.append(atom)

    def remove(self, atom):
        if atom in self.held:
            self.held.remove(atom)
            return True
        return False

    def atoms(self):
        return list(self.held)


# ---------------------------------------------------------------- a reflector

def reflects(value):
    return isinstance(value, Model)


def lower(value, head, space):
    space.add(space.parse(f"({head} first {value.first})"))
    space.add(space.parse(f"({head} second {value.second})"))
    return 2


def sources():
    """The directory of MeTTa sources this package ships."""
    return pathlib.Path(__file__).parent / "metta"


def frame(space, rows):
    """Build a solars frame through the declared rows.to conversion."""
    del space
    return rows.to("solars")


DOORS = (
    DoorContract(
        owner=Owner.namespace, name="frame", kind=Kind.provider,
        signatures=(Signature("space, rows"),), answers=AnswersAs.value,
        effect=EffectClass.oracleIO, determinism=Determinism.det,
        tiers=(Tier.sync, Tier.context),
        body=Body("solars", "frame", Receiver.space),
        provider=Provider("solars", "solars"),
        docs="Build a solars frame through the declared rows.to conversion.",
        evidence=("tests/test_solars.py::test_frame",),
    ),
)


def register():
    """Every row solars adds, against points the seat declared."""
    seam.frame.register(
        "solars", module="solars", accessor=install_accessor, build=build
    )
    seam.sql.register("solars", claims=claims_connection, define=define)
    seam.index.register(
        "solars", available=index_available, build=index_build, search=index_search
    )
    seam.transport_error.register(
        "solars", module="solars", classes=transport_classes
    )
    seam.image.register("solars", claims=image)
    # `reflector` is declared by metta.integrate, where its reader and adder
    # live; seam.at() finds it whether or not this package imported that
    # module, which is what the seam's declaring-module list is for.
    seam.at("reflector").register("solars", claims=reflects, lower=lower)
    seam.door.register("solars", doors=DOORS)
SOLARS

cat > "$scratch/solars/tests/test_solars.py" <<'DOOR_TEST'
"""Purpose: witness the frame door declared by the installed solars package."""

from metta import G, MeTTa, S
from metta._spaces.results import Rows


def test_frame():
    """The namespace converts binding rows through the advertised provider."""
    with MeTTa() as context:
        rows = Rows(("who", "n"), [(S.Ada, G(1)), (S.Bob, G(2))])
        assert context.solars.frame(rows).column("n") == [1, 2]
        assert context.self.solars.frame(rows).column("who") == ["Ada", "Bob"]
DOOR_TEST

cat > "$scratch/free.py" <<'FREE'
"""Discovery costs nothing: the name is advertised, the package is not loaded.

Its own program, because the first dispatch of any point is what LOADS an
advertised registration and importing metta.tables is already such a dispatch.
Pygments has the same property and the same reason to check it apart:
`get_all_lexers(plugins=False)` is the cheap call and every lookup is the
expensive one.
"""

import sys

from metta import seam

advertised = seam.advertised()
assert "solars" in advertised, advertised
assert "solars" not in sys.modules, "advertised() must not import the package"
# This repository's own row packages advertise under the same group and are
# found the same way, which is the ruling of 2026-09-08 read from the outside:
# there is no built-in tier for a dispatch to prefer. metta-arrays advertises
# its lightweight door metadata, keeping the implementation unloaded here.
assert "metta-numpy" in advertised, advertised
assert "metta-arrays" in advertised, advertised
assert "metta_numpy" not in sys.modules, "nor may listing load one of ours"
assert "metta_arrays" not in sys.modules, "listing must leave implementations unloaded"
print("discovery       :", len(advertised), "packages advertised, none imported")
FREE

cat > "$scratch/prove.py" <<'PROVE'
"""Every door solars reaches, named, from a program that imports only metta."""

import metta
from metta import seam, tables
from metta_arrays import EmbeddingStore
from metta.convert import project
from metta._errors.errors import is_transport_failure
from metta.integrate import LIBRARIES_GROUP, load_entry_point
from metta._spaces.results import Rows

m = metta.MeTTa()
rows = Rows(("who", "n"), [(metta.S.Ada, metta.G(1)), (metta.S.Bob, metta.G(2))])

# 1. the frame point, reached by rows.to(<library>), loaded on this dispatch.
frame = rows.to("solars")
assert type(frame).__name__ == "Frame", frame
assert frame.column("who") == ["Ada", "Bob"], frame.column("who")
assert frame.column("n") == [1, 2], frame.column("n")
print("frame           : rows.to(solars) -> solars.Frame, seam point 'frame'")

import solars  # noqa: E402  -- imported only after the seat loaded it

# 2. the same point's accessor half: frame.metta on a solars frame.
assert "solars" in tables.accessors(), tables.accessors()
assert solars.Door.installed[0] == "metta", solars.Door.installed
into = solars.Frame({"a": [1, 2], "b": ["x", "y"]}).metta
assert into.into(m, "row") == 2
assert len(m.self.match(m.self.parse("(row $a $b)"))) == 2
print("accessor        : frame.metta.into(m, 'row') -> 2 atoms, point 'frame'")

# 3. the sql point: a MeTTa head registered into a connection solars owns.
m.run("(: dbl (-> Number Number))\n(= (dbl $x) (* 2 $x))")
connection = solars.Connection()
assert tables.sql_function(connection, m.fn.dbl) == "dbl"
assert connection.sql("dbl", 21) == 42, connection.sql("dbl", 21)
print("sql             : sql_function(solars.Connection(), m.fn.dbl), point 'sql'")

# 4. the index point: an EmbeddingStore searching through solars.
store = EmbeddingStore(m, name="emb", backend="solars")
store.add(metta.S.dog, [1.0, 0.0])
store.add(metta.S.cat, [0.0, 1.0])
best = list(store.ranked([1.0, 0.0], 1))
assert [str(key) for key, _ in best] == ["dog"], best
print("index           : EmbeddingStore(backend='solars').ranked, point 'index'")

# 5. the transport-error point: solars' own timeout reads as an absent backend.
assert is_transport_failure(solars.Timeout("gone"))
assert not is_transport_failure(ValueError("wrong, not absent"))
print("transport-error : is_transport_failure(solars.Timeout), point 'transport-error'")

# 6. the image point: a solars model projects with nothing registered for it.
projected = project(solars.Model(1, 2))
assert str(projected.atom) == "(Model 1 2)", projected
print("image           : project(solars.Model(1, 2)) -> (Model 1 2), point 'image'")

# 7. the provider point: a space backed by solars' own store.
provider = load_entry_point("solars")
backed = m.space("&solars", provider)
backed.add(backed.parse("(star sol)"))
assert len(provider.held) == 1, provider.held
assert len(backed.match(backed.parse("(star $which)"))) == 1
print("provider        : the metta.spaces entry point -> a solars space, point 'provider'")

# 8. the library point: MeTTa sources solars ships, imported by name.
m.register_library_path(load_entry_point("solars", group=LIBRARIES_GROUP), "solars")
m.run("!(import! &self (library solars solars.metta))")
assert m.run("!(solar-flare 21)") == [[42]], m.run("!(solar-flare 21)")
print("library         : (library solars solars.metta) -> 42, point 'library'")

# 9. the reflector point: solars decides how its own objects become facts.
reflector = seam.at("reflector")
assert "solars" in {row.name for row in reflector.rows()}
claimed = reflector.claim(solars.Model(3, 4))
assert claimed is not None and claimed.name == "solars", claimed
assert claimed.row.lower(solars.Model(3, 4), "model", m.self) == 2
assert len(m.self.match(m.self.parse("(model $field $value)"))) == 2
print("reflector       : the reflector point lowers a solars.Model to facts")

# 10. a package-owned accessor, reached through both generated receivers.
assert m.solars.frame(rows).column("n") == [1, 2]
assert m.self.solars.frame(rows).column("who") == ["Ada", "Bob"]
held_frame = m.solars.frame
# The row is matched through gaps rather than by spelling every field: the
# proof is that a door row named frame, of kind provider and owner namespace,
# carries solars as its provider, whatever other fields the catalog projects.
door_pattern = "(door frame provider namespace ... (door-provider door solars solars) ...)"
assert m.run(f"!(match &metta {door_pattern} True)") == [[True]]
print("door            : m.solars.frame(rows), package contract present at boot")

# The seam says who registered what, as data, and the catalog says it in MeTTa.
mine = sorted(row.point for row in seam.rows() if row.name == "solars")
assert mine == [
    "door",
    "frame",
    "image",
    "index",
    "library",
    "provider",
    "reflector",
    "sql",
    "transport-error",
], mine
seam.publish(m)
answers = m.run("!(match &metta (extension python $point solars $fields) $point)")
published = sorted({str(atom) for group in answers for atom in group})
assert published == mine, (published, mine)
print("catalog         :", " ".join(published), "as (extension python ...) rows")

seam.door.unregister("solars")
try:
    held_frame(rows)
except AttributeError as error:
    assert "withdrawn" in str(error), error
else:
    raise AssertionError("a retained accessor invoked a withdrawn door")
seam.publish(m)
assert m.run(f"!(match &metta {door_pattern} True)") == [[]]
seam.door.register("solars", doors=solars.DOORS)
assert held_frame(rows).column("n") == [1, 2]
backed.drop()
m.close()
print("solars extended the Python seat through 10 doors with no edit to PeTTa")
PROVE

uv pip install --quiet --target "$scratch/site" --no-deps "$scratch/solars"
test -d "$scratch/site/solars-0.1.0.dist-info"

# Two of this repository's OWN packages, installed the same way and into the
# same directory, because the point of the ruling is that they are the same
# kind of thing as solars: `metta-arrays` holds the embedding store this proof
# uses and `metta-numpy` is the row that makes NumPy its default library.
# --python, because a member declares requires-python and uv would otherwise
# resolve against whatever interpreter it found.
uv pip install --quiet --python "$CHECK_PY" --target "$scratch/site" --no-deps \
    "$project_dir/extensions/python/ext/metta-arrays" \
    "$project_dir/extensions/python/ext/metta-numpy"
test -d "$scratch/site/metta_arrays-0.8.0.dist-info"

run_with_solars() {
    PYTHONPATH="$scratch/site:$project_dir/extensions/python" \
        "$CHECK_PY" "$1" >> "$scratch/proof.log" 2>&1 || {
        cat "$scratch/proof.log"
        exit 1
    }
}

: > "$scratch/proof.log"
run_with_solars "$scratch/free.py"
run_with_solars "$scratch/prove.py"
PYTHONPATH="$scratch/site:$project_dir/extensions/python" \
    "$CHECK_PY" -m pytest --noconftest -c /dev/null --import-mode=importlib -q \
    -o "cache_dir=$scratch/pytest-cache" -W error \
    "$scratch/solars/tests/test_solars.py::test_frame" >> "$scratch/proof.log" 2>&1 || {
    cat "$scratch/proof.log"
    exit 1
}
cat "$scratch/proof.log"

grep -Fq "solars extended the Python seat through 10 doors with no edit to PeTTa" \
    "$scratch/proof.log"

echo "a stranger extends the Python seat: passed"
