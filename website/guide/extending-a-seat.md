# Extending a seat

There are two levels of extension. `EXTENDING.md` covers the first: the engine's
nine seams, which is how a translator rule, a Prolog predicate, a space provider
or a reader token reaches MeTTa itself. This page covers the second, which is
the one most libraries want: extending a SEAT.

A seat is a host binding with its own build and scripts, `extensions/python`,
`extensions/node` and `extensions/cmetta`. A satellite is a package that extends
one from outside this repository. `pettorch` is a satellite of the Python seat,
and so is a dataframe library that wants `rows.to(...)` to answer its own
frames.

## One table per seat

Each seat declares every point a library can plug into, with a KIND and the
fields a row carries, and a registrant is a ROW against a declared point. Both
read back as data:

```python
from metta import seam

seam.points()                 # every point, with its kind and its fields
seam.rows()                   # every registration, from any of them
seam.at("frame").table()      # one point's rows
```

The kinds are the engine's own, four rather than five:

| kind | rows written by | dispatch |
|---|---|---|
| `declaration` | a registrant | every row is read, as data |
| `ownership` | a registrant | the FIRST row that claims answers |
| `event` | a registrant | every row runs |
| `service` | the seat | a registrant CALLS it |

The engine splits `service` into `service` and `host_service` by an audience
(host bindings against extensions) a seat does not have, which is the one
difference.

## How solars would do it

Say there is a new dataframe library called `solars`. It wants `df.metta`, it
wants `rows.to(solars)` to answer a solars frame, it wants MeTTa heads
registered into its query connections, and it wants its vector index behind
`EmbeddingStore`. None of that needs an edit to this repository.

```python
# in solars/__init__.py
from metta import seam

def register():
    seam.frame.register(
        "solars", module="solars", accessor=install_accessor, build=build
    )
    seam.sql.register("solars", claims=claims_connection, define=define)
    seam.index.register(
        "solars", available=available, build=build_index, search=search
    )
```

```toml
# in solars' pyproject.toml
[project.entry-points."metta.extensions"]
solars = "solars:register"
```

`pip install solars` is the whole of the wiring. `seam.advertised()` answers
its name without importing any of it, and the group is loaded on the first
dispatch that has no answer without it, which is how Pygments finds a plugin
lexer.

## The points each seat declares

**Python** has fourteen. `frame` (a dataframe library), `sql` (a SQL engine),
`array` (an Array API library), `index` (a nearest-neighbour backend), `arrow`
(who builds the Arrow C structs), `ipc` (who writes and reads the Arrow IPC
stream), `transport-error` (which exceptions mean an
absent backend), `image` (how a class of host types projects by default), and
`type`, `repr`, `reflector`, `provider`, `library` and `integration` for the
doors that already existed, whose rows stay where they always lived. Those six
are declared by `metta.integrate`, where their readers and adders are, and
reached with `seam.at(<name>)`, which loads that module only when a name is not
already declared. The shipped libraries are its first registrants and nothing else about them is in
the code paths: pandas and polars are rows against `frame`, DuckDB against
`sql`, numpy against `array`, faiss against `index`.

**Node** has six: `type`, `repr`, `reflector`, `provider`, `library` and
`integration`. A package registers from its own module body and advertises the
same call under an `extensions` group in its `package.json`; loading is
explicit, `await seam.discover()`, because ESM `import()` is asynchronous and a
synchronous dispatch cannot await one. That seat declares no `frame` or `array`
point, deliberately: it has no frame notion, and its array notion is the
platform's own `TypedArray` family, which every numeric library in that runtime
already produces.

**C** has four: `op`, `repr`, `provider` and `library`. A library includes
`cmetta.h`, exports `bool mt_extension_init(metta *runtime)` and is loaded by
path with `mt_extension(m, "/usr/lib/solars.so")`, which is sqlite3's
loadable-extension shape.

## Declaring a point of your own

A library is not limited to the points a seat ships. `seam.point(...)` declares
one, which is `seam:kind/2` being multifile one level out, and the seat
dispatches it like any other:

```python
freshness = seam.point(
    "freshness", "ownership", fields=("claims",), doc="how stale a row may be"
)
```

`seam.publish(m)` writes the whole table into `&metta` under declared kind rows,
so a MeTTa program can ask what it is running on:

```metta
!(match &metta (extension python frame $who $fields) $who)
```

## What the refusals say

Every refusal names the door. A dispatch nobody claims says which point it was,
which registrants there are, and the registration the caller lacks. Registering
against a point nobody declared lists every point that is declared. A row
missing a declared field, or carrying one the point does not declare, names the
field.

## The gate behind it

`sh check.sh no-hardcoded-integration` reads all three seats and reports a
library named outside the one site that registers it. The names are derived
from what the sources reach for rather than from a list, so a library the
checker has never heard of is still seen, and three shell tests build a package
called `solars` during the gate and extend each seat with it, with no edit to
this repository.
