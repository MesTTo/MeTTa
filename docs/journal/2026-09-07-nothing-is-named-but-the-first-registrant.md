# Nothing is named but the first registrant

Goal: a stranger's library extends any seat with zero edits to this repository.
The engine already has that property, written down in `engine/ext_points.pl` and
`EXTENDING.md`: a seam is declared with a KIND, an extension writes rows against
it, and nothing in the engine names a library. The three seats do not. This
thread gives each seat the same seam and moves every hardcoded library name
into a row against it.

Constraint: the shipped registrants keep byte-identical behaviour (pandas,
polars, DuckDB, sqlite3, numpy, jax, faiss, nanoarrow, websocket-client), their
existing tests being the differential. No MeTTa answer changes. The seam's
vocabulary is the engine's, so `EXTENDING.md` reads as one document from the
engine out to the satellites.

## 2026-09-07: the audit

`grep -nE 'pandas|polars|duckdb|numpy|jax|torch|pyarrow|nanoarrow|redis|faiss|websocket'`
over `extensions/python/metta/*.py`, plus the same list widened for each other
seat's ecosystem (`danfo|arquero|apache-arrow|acorn|swipl-wasm|better-sqlite`
for Node, every `#include` and `dlopen` for C).

The verdict rule, settled before reading the sites so the sites could not bend
it:

> A third-party name is a COUPLING when the seat's behaviour toward a CLASS of
> libraries is decided by that name: the code asks "is this pandas?", and a
> second member of the class cannot answer yes without an edit here. It is a
> DEPENDENCY when the name is the seat's own chosen implementation of a service
> the seat itself provides and the class has one member by construction. It is
> PROSE when it names a library only in a docstring, a comment or a refusal
> sentence, where a reader is being told which libraries were measured.

Prose is left alone: a comment saying polars reads `iter_rows` faster than the
stream is a measurement, and deleting it would delete the measurement. What the
gate forbids is a name in a BRANCH.

### Python seat (`extensions/python/metta`)

| name | site | verdict | door it now goes through |
|---|---|---|---|
| pandas, polars | `tables.py:805` `accessors()`, the literal pair `(("pandas", _install_pandas), ("polars", _install_polars))` | coupling | `frame` point, rows `pandas` and `polars` |
| pandas | `tables.py:813` `_install_pandas` | coupling | the `pandas` row's `accessor` field |
| polars | `tables.py:817` `_install_polars` | coupling | the `polars` row's `accessor` field |
| duckdb, sqlite3 | `tables.py:876` `sql_function`, `isinstance(connection, sqlite3.Connection)` and the else branch | coupling | `sql` point, rows `sqlite3` and `duckdb` |
| duckdb | `tables.py:853` `_undeclared_arrow_message`, prose naming DuckDB inside a refusal the seat raises | coupling | the `duckdb` row's own refusal |
| pandas | `results.py:859` `Rows.to_df` | coupling | `frame` point; `to_df` is the `pandas` row's declared sugar |
| polars | `results.py:882` `Rows.to_pl` | coupling | `frame` point; `to_pl` is the `polars` row's declared sugar |
| pandas, polars | `results.py:1509,1513` `Answers.to_df`, `Answers.to_pl` | coupling | same, forwarded |
| numpy | `results.py:403` `Column.__array__` | coupling | `array` point, the row that declares `arrays=True` |
| nanoarrow | `_arrow.py:309` `_nanoarrow()` and its five call sites | coupling | `arrow` point, row `nanoarrow` |
| numpy | `arrays.py:441` `_numpy()`, `arrays.py:486` the no-argument default, `arrays.py:788` `install`'s default | coupling | `array` point, row `numpy` with `default=True` |
| faiss | `arrays.py:448` `_faiss()`, `1257`-`1261` the backend name check, `1381` `_use_faiss`, `1411`-`1428` the search branch | coupling | `index` point, rows `argsort` and `faiss` |
| numpy | `arrays.py:1330`, `1415`-`1426` float32 staging for the faiss path | coupling | inside the `faiss` row |
| websocket | `errors.py:965` `is_transport_failure` | coupling | `transport-error` point, row `websocket` |
| numpy | `testing.py:281` `numpy_scalars` | coupling | `array` point; the row's `scalars` field |
| array-api-compat | `arrays.py:434` `_compat()` | dependency | the Array API standard's own compatibility layer; one member by construction |
| torch, jax, cupy, dask | `arrays.py` docstrings and `_compat`'s refusal sentence | prose | none needed; they already install through `arrays.install(m, default=...)` |
| polars, pandas, pyarrow, DuckDB | `results.py:103`, `831`-`852`, `_arrow.py:423`, `tables.py:156`-`163`, `690`, `703` | prose | the Arrow PyCapsule interface is the door and these name who reads it |
| redis | `library.py:312`, `_space.py:5927`, `aio.py:2959` | prose | `library(redis)` is an SWI capability name the engine reports |
| duckdb | `_space_machine.py:214` | prose | inside a docstring example |
| torch | `_engine.py:732`, `define.py:4` | prose | a cited upstream source and a cited precedent |
| pettorch | `_space.py:4870`, `aio.py:2460` | prose | a docstring example of `register_library_path`; pettorch is a satellite, not a branch |

Twenty-two sites, fifteen of them couplings across six library classes.

### Node seat (`extensions/node/src`)

The same grep, widened: `swipl-wasm` (`wasm.ts:13`) and `acorn`
(`define/lower.ts:42`) are the only non-relative imports in 20,864 lines. Both
are DEPENDENCIES by the rule: swipl-wasm is the engine this seat mounts, and
acorn is the seat's own JavaScript parser for `define`'s lowering. Neither
decides the seat's behaviour toward a class of libraries. There is no frame
library and no array library named anywhere: `arrays.ts` is built on the
platform's own `TypedArray` family, which every numeric library in this runtime
already produces, and `tables.ts` takes a `TableSource` interface and says so in
its `Decides:` line.

So the Node seat has no coupling to remove. Its gap is the other half of the
question: the doors exist (`registerType`, `registerRepr`, `registerProvider`,
`registerReflector`, `registerCustomMatch`, `registerToken`, the
`package.json` groups `integrations`, `spaces`, `libraries`) but they are six
unrelated functions, not one seam a program can query, and there is no group a
package uses to advertise a registration that is not a whole integration.

### C seat (`extensions/cmetta`)

No third-party name at all: `cmetta.c` includes SWI-Prolog and the C standard
library. The gap is capability. A stranger linking against `cmetta.h` can
publish functions (`mt_def`) and carry C values through MeTTa (`mt_object`,
`mt_function`). They cannot register a space provider, cannot say how their
object type prints, cannot register a directory of MeTTa or Prolog sources, and
have no way to be loaded at all except by being compiled into the host program.
Three capabilities and the loader are missing.

## 2026-09-07: the seam

Rejected: a registry per kind (`tables.register_frame`, `arrays.register_index`,
`errors.register_transport`), which is what the sites suggest one at a time.
Six registries have six spellings, six refusals, six discovery stories and no
answer to "what can I extend here"; the engine already rejected this shape for
itself, which is why `kind/2` is one multifile table and not a comment.

Decided: ONE seam per seat, the seat-level twin of `engine/ext_points.pl`, with
the engine's own vocabulary.

**Kinds.** The engine declares five (`declaration`, `event`, `ownership`,
`service`, `host_service`) and derives the cut rule from `clauses_from/2` rather
than restating it. A seat has FOUR: `host_service` splits `service` by an
audience distinction (host bindings against extensions) internal to the engine,
and a seat has one audience. The rest carry over unchanged, and so does the
derivation:

| kind | rows written by | dispatch | the rule that follows |
|---|---|---|---|
| `declaration` | a registrant | read as data | every row stays visible |
| `ownership` | a registrant | first row that CLAIMS answers | a row declines by answering nothing |
| `event` | a registrant | every row runs, result discarded | a row must not claim |
| `service` | the SEAT | a registrant CALLS it | the seat may implement it as it likes |

This is pluggy's split with pluggy's own semantics: `@hookspec(firstresult=True)`
stops at the first non-`None` result, which is `ownership`, and the default
collects every implementation's result, which is `event`
[source: https://pluggy.readthedocs.io/en/stable/, "First result only" and
"Collecting results"]. Registering against a point nobody declared is pluggy's
`check_pending()` refusal, `unknown hook <name> in plugin <plugin>`
[source: pluggy `_manager.py`, `PluginManager.check_pending`], and a row missing
a declared field is its `_verify_hook` argument check read the other way round.

**Rows may live where they already live.** `ext_points.pl` does not store a
seam's clauses; it declares the seam and Prolog's own database holds the
clauses. The seat seam is the same: a point may declare `rows=` and `add=`
naming where its rows are kept and how one is added, so a point whose store
already exists (`convert`'s type registry, the atom repr registry, the reflector
list, the entry-point groups) is DECLARED here and read through here without its
storage moving and without its hot path changing. A point with no store yet gets
the seam's own. Either way `seam.rows()` answers all of them and there is one
door to register through.

**Discovery.** Python reads the `metta.extensions` entry-point group, and reads
it LAZILY, at the first dispatch that has no answer, which is what Pygments does
for lexers: `find_plugin_lexers()` iterates the entry points inside the lookup
functions, so `pygments.lexers.get_all_lexers(plugins=False)` costs nothing and
an installed plugin is found without an import
[source: https://pygments.org/docs/plugins, and `pygments/plugin.py`,
`find_plugin_lexers`]. `seam.advertised()` answers the names without loading
anything, which is the property `integrate.entry_points` already keeps. Node
reads a fourth group, `extensions`, from the same `package.json` `metta` field
its three existing groups come from. C loads a shared object with
`mt_extension(runtime, path)` and calls its `mt_extension_init`, which is
sqlite3's loadable-extension shape
[source: https://www.sqlite.org/loadext.html].

**The seam is data in `&metta` too.** `metta.arrays` already writes
`(array-backend <space> <library> (ops ...))` into the catalog under a declared
`(kind array-backend symbol symbol term)`, so a MeTTa program can match its own
array installation. The seam does the same for itself: two kind rows,
`(kind extension-point symbol symbol symbol term)` and
`(kind extension symbol symbol symbol term)`, and one row per point and per
registrant, so `!(match &metta (extension python frame $who $fields) $who)`
answers which frame libraries are registered. The Python-side table stays the
store, because a registration happens at import time when there may be no engine
at all; the catalog rows are published when an engine asks, the way the array
roster is written when an install happens.

## 2026-09-07: the Python seat

Decided: `metta.seam` holds the declarations and `metta._registrants` holds the
shipped rows, one file, loaded LAZILY by the point that names it in `shipped=`.
The two-file split is what makes the gate exact: `_registrants.py` is the one
Python-seat site where a library may be named, and the checker's ALLOWED table
says so per library with the door it registers through.

Tried: the shipped rows registering from the module that owns their domain
(pandas in `tables.py`, faiss in `arrays.py`) -> rejected. `index`'s
`backend="auto"` takes the first available row in registration order, and with
the rows split across two modules the order is import order: `arrays.py` is
imported before a dispatch loads `_registrants`, so the always-available
fallback registered FIRST and faiss could never win. One file, one reading
order.

Tried: `Point` declaring `reader=`/`adder=` and NOT keeping a row of its own,
so a point whose store already exists (the reflector list, the repr list) is
purely a view -> rejected by the solars proof. `integrate.register_reflector`
stores `(predicate, callable)` and no name, so a row registered as `solars`
read back as `lower`, the callable's own name. The seam now keeps the row
whatever else happens to it and the adder performs the side effect, with the
reader supplying only rows registered through the older door directly, matched
out by identity of the fields the store does keep.

Rejected: generating `to_solars()` onto `Rows` from a registrant's `sugar`
field. It needs `Rows.__getattr__`, which types every attribute of Rows as
`Any` and turns off the mypy gate for the whole class. `rows.to(<module>)` is
the door every registrant gets, takes the module rather than its name (the
library's own rule about strings), and `to_df` / `to_pl` are the two shipped
rows' declared `sugar`, checked both ways by
`test_a_shipped_sugar_is_a_declared_row_and_not_a_privilege` so a third
library cannot arrive as a third method.

Decided: the seat's kind rows go into `&metta` with plain `symbol` argspecs
rather than `(one-of seam-kind)`. A vocabulary row is generated from
`engine/spaces/catalog.pl` by `tools/vocabgen.py` and would put a seat's
closed set into the ENGINE's presets, which is the wrong direction for a
package about not reaching into what you extend. The closed set is checked
where the registration happens, at `seam.point`, which is also where the
refusal can name the four kinds.

Measured: the shipped suites are the differential and they pass unchanged.
`sh extensions/python/test.sh` over ch04, ch08, ch11, ch13 and ch20: 1467
passed. One test changed its assertion rather than its subject:
`test_sql_function_refuses_a_connection_without_the_door` asserted
"has no create_function", and an unclaimed connection is now refused naming
the `sql` point, its registrants and the registration it lacks, where before
anything that was not sqlite3 took DuckDB's branch.

Tried: asserting "advertised() loaded nothing" inside the same program that
then uses the doors -> it cannot be. Importing `metta.tables` runs
`accessors()`, which IS a dispatch, which is what loads the group. The free
half is its own program in the shell test, which is the same reason Pygments
documents `get_all_lexers(plugins=False)` apart from the lookups.

## 2026-09-07: the Node seat

Decided: no `frame` point and no `array` point. The audit found no coupling to
remove, and the brief's "where the seat has frames or arrays" is the condition
that decides it: this seat has no frame notion at all, and its array notion is
the platform's own `TypedArray` family, which every numeric library in the
runtime already produces, so neither point has a class of libraries to admit.
Declaring them would be inventing a door for a room that is not there.
`test/seam.test.ts` pins the absence, so a later reader meets the decision
rather than the omission.

Decided: loading is EXPLICIT here, where the Python seat loads an advertised
registration on the first dispatch that needs it. ESM `import()` is
asynchronous and `Point.claim` is synchronous, so a dispatch cannot await one;
`await seam.discover()` is the app's call and a package's own module body is
the primary door, which is what `npm` packages do anyway. The difference is in
the module header, the README and llms.txt rather than left for a reader to
find.

Tried: `reader=`/`adder=` deduping a foreign store's row against the seam's own
by requiring every field of the read-back row to match -> wrong, and the Node
solars proof is what caught it. A store records what IT keeps, which is rarely
what the registration supplied: `convert`'s registry hands back `image` where
the registration gave `toAtom`, so `type` answered the same registration twice.
The rule is now same NAME, or the same values under every field the two spell
in common. The Python seat had the same latent defect and took the same fix.

Measured: `sh extensions/node/test.sh` after the change, 638 tests, 638 pass.
Two conventions caught the first draft and both were real: every exported name
carries its own doc comment, and `.sort()` takes `byCodePoint` rather than
JavaScript's default lexicographic-by-UTF-16 comparator.

## 2026-09-07: the C seat

The audit found no name to move and four things missing, so this seat's work
was capability rather than decoupling: a space provider, a rendering for an
object type, a directory of sources, and any way to be loaded at all.

Decided: a C provider speaks canonical MeTTa TEXT and enumerates by INDEX.
Text because that is what this seat already speaks over its bridge, and the
engine's own reason for having a `service` kind is a provider that speaks text
over a wire. Index because the alternatives are worse in C: a returned array
needs an ownership rule for the array AND the strings, and a cursor needs three
callbacks where `atom_at(user, i)` needs one and is the same shape `mt_arg`
already has in this header. A store of n atoms costs n+1 calls and never a
length query a C store may not be able to answer.

Tried: naming the seam's registration type `mt_row` -> rejected by the
compiler, and rightly. `mt_row` is already an ANSWER row in `cmetta.h`
(`mt_row_next`, `mt_bound`), and one header has one meaning per name. The
registration is `mt_seam_row` and its readers are `mt_seam_count` and
`mt_seam_at`, which also stops `mt_row_at` reading as an answer accessor.

Tried: `pl_cmetta_repr` reading its object through `blob_box()` -> broke
`test_a_refusal_carries_the_engines_remedy_and_ground`'s neighbour, "an engine
alias left by explicit release is refused without a dereference". `blob_box`
RAISES an existence error for a released object, and `grounded_text` is an
ownership seam where declining is failing, so the release's own refusal came
back as this predicate's. It reads the blob quietly now and fails.

Measured: `sh extensions/cmetta/test.sh`, 486 checks, 0 failures, with the new
`tests/test_seam.c` among them. The extension proof compiles a library against
`cmetta.h` alone and drives five doors through it, including a point the
library declared for itself.

## 2026-09-07: what each seat gained

Recorded as the work landed; the numbers are in the commits' own tests.
