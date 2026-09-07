# The core names no library
Goal: pymetta ships zero integrations. Every library the Python seat knew becomes
its own distribution in this monorepo, discovered through the `metta.extensions`
entry-point group exactly as a stranger's package is; the registrant module and
the gate's integration allowlist disappear; the satellites the core survives
without move out with them.
Constraint: the ruling (CLAUDE.md, "No hardcoded integrations, ever", 2026-09-07)
is that the core may name only the engine it embeds and the tooling the seat is
written in. Every generic door keeps working with NO package installed. Upstream
PeTTa still arbitrates semantics; nothing binds for compatibility.

## 2026-09-07: the plan, before a file moved

Measured first, on `petta` at 90c08119b.

`metta/_registrants.py` (667 lines) carries ten library rows: pandas and polars
against `frame`, sqlite3 and duckdb against `sql`, numpy against `array`, faiss
against `index`, nanoarrow against `arrow`, pyarrow against `ipc`, websocket
against `transport-error`, pydantic against `image`. Four more rows there name no
library at all: the `argsort` index backend (the Array API path) and the `enum`,
`dataclass`, `namedtuple` and `match-args` images. `check_hardcoded_integrations`
admits the ten through an `ALLOWED` integration category and eleven more through
a dependency category.

The core reaches its satellites two ways. Statically, `git grep` finds four
module-level edges into a candidate mover: `manifest -> tables`,
`testing -> benchmarking`, and `_registrants -> arrays` twice. Dynamically,
`_space.py` calls `_satellite(name)` for fifteen names (foreign, algebra,
_lint_events, subscribe, remote, integrate, _trace, parallel, live, lint, events,
casting, _recording, _persistent, _debug), an `importlib.import_module` on a
computed name that import-linter cannot see.

The other direction decides what may move. Section 5 of
`ai-derived-not-hardcoded-discussion.md` rules that an `ext/` package reaches the
core "only through the seam and the public doors, never through underscore
names", which is the rule Airflow had to invent an SDK for and the rule pytest
plugins break every release by ignoring. Counting each public module's imports of
a private name, and subtracting the ones that already have a public spelling
(`atoms._encode`/`_decode`/`_from_wire`/`_atom_from_wire` are `metta.wire`'s four
exports; `_space.Space`/`MeTTa` are `metta.Space`/`metta.MeTTa`;
`_api_types.space_of` and `_optional.require_module` are the seam's `space-of`
and `module` services; `_arrow.Projection` is its `projection` service):

    benchmarking   0
    arrays         3   _ops.REGISTRY, atoms._alpha_eq, atoms._expr
    telemetry      4   _trace.{DEFAULT_MAX_EVENTS,Trace,_recorded,_selected_names}
    tables         5   _arrow.{read_batches,schema_capsule,stream_capsule},
                       atoms._is_ground, atoms._match
    structures     3   atoms._is_ground, atoms._match, atoms._variables
    live           9   + ops._REFLECTION_SPACE, structures._{as_atom,call_spelling,
                       canonical,table_report}, subscribe._capacity
    parallel       5   _engine.{Runtime,engine_thread,forked,runtime}, atoms._to_atom
    remote         6   _declarations.declared, _engine.{bridge,runtime},
                       _network.{HTTPEndpoint,validated_timeout}, _space_objects.Cursor
    spaces         7   _object_fields.field_names, foreign._{refusal_detail,
                       require_provider}, structures._canonical, atoms x3
    lint           8   _head_meaning.EngineRegistry, _source_forms.positioned_forms,
                       _lint_{analysis,events,model} (its own), atoms x3
    testing       18   _compliance, _gateway_compliance, _space_machine, _codec_kit,
                       _callable_mentions, _library, _refinements, _type_annotations,
                       _engine.runtime, _ops.REGISTRY, algebra._canonical_laws, ...
    algebra       14   _space_execution x4, _space_objects x2, _under x2,
                       _algebra_demand, _engine.active_runtime, ...

Three of the remaining blockers dissolve on reading rather than on publication:
`atoms._is_ground` is documented "public code reads `not atom.vars`",
`atoms._expr` is documented "public code calls a Symbol or Expression" and
`Expression([...])` encodes its children identically, and `_ops.REGISTRY` is
`metta.ops.registered()`, which is in that module's `__all__`.

Decided: the movers are `arrays` (`metta-arrays`), `benchmarking`
(`metta-benchmarking`), `telemetry` (`metta-otel`, an integration by the ruling
since every span and histogram in it is the OpenTelemetry API) and the GraphQL
executor half of `_schemas.py` (`metta-graphql`), beside the ten library rows.
Fourteen distributions under `extensions/python/ext/`, one library each.

Rejected: moving `tables`. `metta.manifest` builds a `TableBridge` from the
`bridge` boot form, and the boot vocabulary is CLOSED by an earlier ruling
(`website/live/boot.md:31`, `metta/manifest.py:78`, "the vocabulary is closed
(load, attach, bridge, serve)") whose reason is that an open one becomes a second
API surface. Cutting the edge means making the vocabulary rows and moving
`boot(connections=...)` into a row, which changes a public signature and belongs
with the door table (section 11). `tables.py` names no library after the seam
merge, so the ruling this thread exists for does not touch it. Revisit when
W-DOORS makes `Space`'s doors rows.

Rejected: moving `structures`, `spaces`, `live`, `lint`, `parallel`, `remote`,
`testing`, `algebra`. Each is either reached by the core through `_satellite`
(live, lint, parallel, remote, algebra) or needs core-private names that are the
binding's own (`_engine`, `_network`, `_space_execution`, `_space_objects`), and
`structures` is held by core-resident `spaces` reading `structures._canonical`.
The six atom primitives without a public spelling (`_match`, `_alpha_eq`,
`_variables`, `_to_atom`, `_map_atoms`, `_alpha`) are the shared wall; publishing
them is a ruling about the atom surface, which W-DERIVE-SEAT owns. Revisit when
those two land.

Decided: `_match` and `_alpha_eq` become SEAM SERVICES rather than public atom
functions, because `seam.service`'s own contract is "a registrant that needs the
seat's own machinery calls a published service instead of importing a private
module", and because `_match`'s bindings are keyed by NAME where public `unify`
keys by the variable, so publishing it as `atoms.match` would publish a second
key convention. Six services join the seam: `match`, `alpha-eq`, `arrow-schema`,
`arrow-stream`, `arrow-batches` and `observe`; one point joins it, `graphql`,
beside `arrow` and `ipc` as a protocol rather than a library.

Decided: a row may declare itself a FALLBACK, which is pluggy's `trylast`. The
seam merge recorded the reason it needed one file: "`index`'s `backend='auto'`
takes the first available row in registration order, and with the rows split
across two modules the order is import order ... the always-available fallback
registered FIRST and faiss could never win". Splitting the rows across
distributions makes that worse, since `importlib.metadata` promises no order over
entry points. `fallback=True` partitions `Point.rows()` stably, so the Array API
`argsort` backend and the four structural images are consulted after every
registrant whatever order they loaded in. This property is what lets the one file
go.

Decided: the `array` and `index` points are DECLARED BY `metta_arrays`, not by
the core, because their only reader is that package; `metta-numpy` and
`metta-faiss` depend on it and register against its points. `seam.at(name)` now
loads the advertised group before refusing an unknown name, so a point declared
by a package is found by a program that never imported it, the same lazy path a
row already takes.

## 2026-09-08: what was built, and the four corrections the measurements forced

Decided, correcting the plan above: the `array` and `index` points stay
DECLARED in `metta.seam`. The plan had them moving to `metta_arrays` on the
grounds that it was their only reader, and that was wrong: `metta.results`
reads the `array` point for `Column.__array__` and `metta.testing` reads its
`scalars` field for `library_scalars`, both core. `seam.py`'s own rule settles
it anyway ("one file declares every point of this seat, for the reason
ext_points.pl gives"), so the widening of `seam.at()` that the move would have
needed was reverted unused.

Built: fourteen distributions under `extensions/python/ext/`, eleven of them
one row each (`metta-pandas`, `metta-polars`, `metta-duckdb`, `metta-sqlite`,
`metta-numpy`, `metta-faiss`, `metta-nanoarrow`, `metta-pyarrow`,
`metta-websocket`, `metta-pydantic`, `metta-graphql`) and three of them
libraries a program imports (`metta-arrays`, `metta-otel`,
`metta-benchmarking`). `metta/_registrants.py` is gone; the four structural
images moved to `metta/_images.py` as fallback rows.

Tried: giving every member a `metta.extensions` entry point -> rejected on the
measurement. Discovery loads the whole group on the first dispatch of any point
a registrant writes, so what one advertised package costs to import, EVERY
program pays -- including one that never touches that package's subject.
Importing `metta_arrays` is 64 ms and 179 modules because it IS the array
layer, against 5 ms and 33 for a row package [measured 2026-09-08,
`python -c "import metta; import metta_arrays"` in extensions/python]. The
three libraries advertise nothing and lose nothing: the only door that reads
the `index` point is the embedding store inside `metta_arrays`, and the other
two register no row at all.

Measured, and the first version was far worse than that. With all fourteen
advertised, `import metta_pandas` cost 124 ms and pulled in 196 modules, the
whole core facade among them. The cause was not the packages: it was
`seam.at("module").call()`, the first line of most of them. Reading a SERVICE
point ran `_rows_of`, which loaded the advertised group, which imported every
other package. A service's one row is the seat's and no registrant may add
another, so discovery there could never change the answer.
Decided: `_rows_of` discovers only for a kind whose rows a REGISTRANT writes.
Eleven of the fourteen dropped to 5-9 ms and 33 modules on that one line.

Decided: a row may declare itself a FALLBACK, `register(..., fallback=True)`,
which is pluggy's trylast. The seam merge recorded why it needed one file:
"`index`'s `backend='auto'` takes the first available row in registration
order, and with the rows split across two modules the order is import order ...
the always-available fallback registered FIRST and faiss could never win"
(2026-09-07). Splitting across distributions makes that unarrangeable rather
than merely fragile, since `importlib.metadata` promises no order over a
group's entry points. `Point.rows()` now partitions stably, so the Array API
index backend and the four structural images are consulted last whatever order
they loaded in, and registration order still decides between rows of the same
rank. This property is what let the one file go.

Measured, the cost the ruling asked about, with `perf stat -e instructions:u`,
min of five, on a box at loadavg 26 (wall clock under 100 ms is bimodal here,
so the counter is the number):

    import metta, seat only                     177.76M
    import metta, one empty directory + seat    179.85M
    import metta, all fourteen packages + seat  179.84M

So the unwatched cost is FLAT: the 2.09M difference is one extra `sys.path`
entry, which an empty directory costs identically, and the fourteen packages
cost -5,521 instructions against it. The first dispatch of a point a registrant
writes is what loads the group:

    first dispatch, empty directory + seat      278.03M
    first dispatch, eleven advertised + seat    393.01M

which is one module per installed package, once per process, paid by a program
that actually dispatches. A user who installed `pymetta[dataframes]` loads two.

Rejected: moving `metta.tables` out with the others. `metta.manifest` builds a
`TableBridge` from the `bridge` boot form, and the boot vocabulary is CLOSED by
an earlier ruling (`website/live/boot.md:31`, `metta/manifest.py:78`) whose
reason is that an open one becomes a second API surface; cutting the edge means
making the vocabulary rows and moving `boot(connections=...)` into one, which
changes a public signature. `tables.py` names no library, so the ruling is
unaffected. Revisit when W-DOORS makes `Space`'s doors rows.

Rejected: moving `structures`, `spaces`, `live`, `lint`, `parallel`, `remote`,
`testing` and `algebra`. Each is either reached by the core through
`_satellite(...)` or needs core-private names that are the binding's own
(`_engine`, `_network`, `_space_execution`, `_space_objects`), and `structures`
is held by core-resident `spaces` reading `structures._canonical`. The eight
atom primitives with no public spelling (`_match`, `_alpha_eq`, `_variables`,
`_to_atom`, `_map_atoms`, `_alpha`) are the shared wall; two of them became
seam SERVICES for the movers that needed them, and publishing the rest is a
ruling about the atom surface that W-DERIVE-SEAT owns.

Decided: the survival boundary is recorded as a lane rather than as a list.
`tests/checks/check_layering.py` reads the workspace glob and holds five rules:
the core imports no member; no member imports a `metta._private` name; a member
names only the libraries its own manifest declares; the members and
`[tool.uv.sources]` agree in both directions; and importing every ADVERTISED
member does not load `metta._space`. Its selftest plants each one.

Open: `metta.tables`, and the six atom primitives, both named above with the
condition that would let them move. `benchmarks/` is still outside the `ruff`
lane, which is why `_workspace.on_path()` there is unlinted; that predates this
thread.
