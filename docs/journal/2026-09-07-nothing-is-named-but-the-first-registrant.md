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

## 2026-09-07: the gate

Decided: the names the lane looks for are DERIVED, not listed. A list of
library names in a checker is the same defect the checker exists to catch, and
it goes stale the day someone adds a library it never heard of. For Python the
scan reads the SYNTAX TREE: any import of a module that is neither the standard
library nor this package, plus any string literal reaching `optional_module`,
`require_module`, `importlib.import_module`, `sys.modules.get` or
`importlib.util.find_spec`, which is how a coupling with no import statement
(`optional_module("faiss")`) is seen at all. For TypeScript it is any import
specifier that is neither relative nor `node:`; for C, any `#include` that is
neither the C standard library nor the seat's own.

Reading the tree rather than the text is what makes prose free. A docstring
naming polars because polars was measured is not a node, so it is invisible by
construction rather than by an exception list; the TypeScript and C scans strip
comments for the same reason. The selftest plants a docstring, a comment and an
ordinary `cache.get("pandas")` as NEGATIVES so that decision cannot be quietly
reversed into a grep, which would be turned off within a day.

Tried: `PROBES` matching any call whose function name is `get` -> 400 findings
on the first run, every `dict.get("...")` in the seat among them. A probe is
matched with its RECEIVER now: `sys.modules.get`, not `.get`.

Tried: one allowed SITE per library -> wrong for a DEPENDENCY. pytest is in
three compliance kits and rich in two renderers, and a wrapper module whose
only job is to satisfy the checker would be worse than the checker. A site is a
tuple of paths with one stated reason, and the ALLOWED table's two halves are
labelled: integrations, which share the registrant module, and dependencies,
which are this seat's own implementation of a service it provides.

A registration names its library as `module="websocket"`, a keyword no probe
sees, so the scan reads a `module=` keyword on a `.register(...)` call too.
Without it the registrant file looked as though it named nothing and the lane
reported its own ALLOWED entry as stale.

## 2026-09-07: what each seat gained

| seat | before | after |
|---|---|---|
| Python | fifteen couplings across six library classes, each a branch | one seam, thirteen declared points, every library a row in `metta._registrants`; a stranger reaches nine doors |
| Node | six unrelated registration functions, no group for a registration that is not an integration | one seam, six declared points, a fourth `package.json` group; a stranger reaches six doors, one of them a point it declared itself |
| C | five API doors, no way to be loaded, no provider, no repr, no library | one seam, four declared points and three new capabilities behind a loader; a stranger reaches five doors |

Open: nothing in this thread. The Node seat has no `frame` or `array` point
because it has neither notion, which is a decision rather than a gap and is
pinned by a test; the C seat has no frame or array notion either, and C has no
universal for one to be built on.

## 2026-09-07: two layers the design had wrong, both found by a gate

Tried: declaring every Python point in `metta.seam`, the way `ext_points.pl`
declares every engine seam in one file -> broke three import-linter contracts
at once, and the diagnosis is the whole reason those contracts exist.
`metta.errors.is_transport_failure` reads the transport-error rows on every
refusal, so `metta.seam` is BELOW the base layer; a seam that imported
`metta.integrate` for the `type`, `repr` and `reflector` readers, `metta.ops`
for the registry-undo frame, or `metta._space` for the catalog dragged
`metta.errors` and `metta.results` up the stack behind it.

Decided, three fixes each running with the layering rather than against it:

- The six points whose readers and adders are `metta.integrate`'s are declared
  THERE. `metta.seam` names that module in `_DECLARING` and imports it only
  when `seam.at` is asked for a name the table does not already hold, so the
  dispatch path never pays the 41 ms `metta.integrate` costs to import
  [measured 2026-09-06, `python -X importtime`, recorded in `_api_types`'s own
  header] and `seam.points()` still answers all thirteen.
- The registry-undo enlistment inverts into a listener. `metta.ops` owns the
  transaction frame, so it subscribes with `seam.on_registration`, which is
  the direction `metta._contract` already takes with
  `_convert_registry.subscribe_registrations`.
- `publish()` reaches `&metta` through a `catalog` SERVICE that
  `metta._space` publishes, because a space is that module's and a service is
  the seam's own word for what the seat provides and a caller calls.

`metta.seam` joined the core roster in the contract, so the constraint is
written down: a satellite imported from the seam is now a broken contract
rather than a slow import nobody notices.

Tried: exporting the Node seam from the package index -> the browser build
refused, `Could not resolve "node:fs"`, three errors out of esbuild. The Node
seam reads a `package.json` to answer what packages advertise, which is
`metta-node/integrate`'s own reason for being in that build's `nodeOnly` set
since it was written. `./seam` joined it, lost its `browser` condition and its
re-export, and is reached as `import * as seam from "metta-node/seam"`.
`registerType` and `registerRepr` stay reachable in a browser through
`metta-node/convert` and `metta-node/atom`; what a page loses is a table about
packages it does not have.

Measured, and NOT this package's: `engine-bench` and `benchmarks` are red on
the base. A control worktree cut at `31d54e19` and built with `sh tools/build.sh`
reads boot 250270 against a pinned 248968, parse 126,111,592 instructions
against 111,718,052, and the same 23 benchmark cases failing in the same
order, `annotated-relation` at 830,767 inferences against a pinned 315,385
where this branch reads 830,765. `engine/bench-baseline.json` was last
re-pinned at `dd161fbcf` and merges landed on `petta` after it without one.

Measured, and THIS package's: the C seat's ownership row cost one inference on
every space operation. Against the same control worktree, `c-bench`'s
`space-pair` case, which runs 20,000 add-and-match pairs, read 1,160,032
inferences on this branch against 1,140,032 on the base, deterministic across
all three samples on both trees, and exactly one per pair. The cause was a
resident clause: `seam:foreign_space(Space) :- metta_c_provider(Space).` sits in
the database of every process that loads this seat, and the engine asks that
ownership seam once per space operation, so the clause is tried on every
operation whether or not a C provider was ever opened.

Rejected: re-pinning the baseline and recording the mechanism, which is what
the harness offers for a deliberate cost. `engine/spaces/foreign.pl` already
records the rule this breaks, beside its own 2026-08-20 measurement of four
benchmarks moving when one shared test was put in front of every space door:
the ownership question is answered off the operation path or not at all.

Decided: the row is asserted when a provider opens and retracted when it
closes, which is the shape `extensions/node/bridge.pl` already uses and
measured for itself. `space-pair` came back to 1,140,032, byte-identical to the
base. Three things came with it, because the door had been doing less than the
header promised:

- `metta_claim_space(Space, cmetta)` and `metta_disclaim_space/2`, the engine's
  claim door, which every other provider in the tree already calls and which
  `cmetta.h` already promised `mt_provider_open()` went through. Before this a
  C provider could take a name MORK, redis or the Python seat owned, and the
  collision would have surfaced later as a wrong answer.
- `metta_space_name/1` at the door. `tests/prolog/static_checks.pl` enforces the
  ampersand rule by reading `seam:foreign_space/1` clause HEADS in the source,
  and this seat now writes none, so the refusal moves to where the Python and
  Node seats keep theirs.
- `retract/1` rather than `retractall/1` when the row goes. `retractall/1`
  unifies HEADS alone, so on a predicate other seats bridge into it would take
  their clause for the same name with it.

`test_seam.c` gained the two refusals and a reopen after close, which is what
proves the claim was given back rather than leaked.

The one cost that stays is at boot, and it was measured rather than assumed:
cutting the seam block out of `extensions/cmetta/bridge.pl` and running the
`boot` case again reads 371,837 inferences against 379,212 with it, so the
seat's Prolog seam costs 7,375 inferences once per process to consult. Boot
stays 3,394 inferences under its pinned 382,606. Deferring the five capability
hooks into a file the door loads on first open would take about half of that
back and was rejected: it buys 0.4% of a boot that is already inside its pin,
and costs a file and a load-time branch on the path that opens a provider.
