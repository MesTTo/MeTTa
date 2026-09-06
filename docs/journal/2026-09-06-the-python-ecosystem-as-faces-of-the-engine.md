# The Python ecosystem as faces of the engine

Goal: name every Python-language, standard-library and ecosystem mechanism
that carries a MeTTa meaning or a repository practice this library does not yet
spell, each checked against the source before it is proposed, each as a face
of a mechanism the engine already has, with its prior art, the class of cost it
removes or capability it adds, and a verdict; and, where several proposed
faces turn out to want the same information, name the one home that
information gets.

Constraint: the supported Python floor stays 3.12 (ruling of 2026-09-06:
template strings are wanted, and 3.12 must keep working); one mechanism
wearing many faces, never a second mechanism for a face; nothing is adopted by
being listed; a cost claim is measured on the existing instruments before it
is pinned; the declarations thread (`2026-09-06-declarations-the-engine-can-trust.md`)
owns decorators, freezing, sealing, interning and memo declarations and this
thread does not restate them; the repository split (`ai-todo.md`, K0 and the
seven repositories) executes first, and a face lands after it unless the split
itself needs the face.

## 2026-09-06

### Method: read first, propose second

The correction appended to the declarations thread (9f413e07) established that
a survey written from the language outward lists mechanisms the library
already uses. This thread therefore started from a coverage read of the tree
at ed83a5bc, one pass over the data model and typing surface, one over the
doors and the test tooling, one over the engine's SWI mechanisms and the
repository's metadata, every row backed by a `git grep` or a probe. The two
merges since (ff997ad3, d58b26a9) touched `extensions/python`, `shim.pl`,
`tests/checks` and journals; line numbers below are from ed83a5bc unless
marked. What the read changed before a proposal was written:

- Values already enter program text as values: `m.bind(graph=g)` is a block
  that substitutes the bare symbol `graph` with the object after the text is
  read and before it runs, on `run`, `eval` and `answers`, with `using=` as
  the per-call merge (`_space.py:1260`, `:576`, `:3283`). The placeholder is
  the symbol itself.
- Dataclasses, NamedTuples, pydantic models and Enums destructure by default,
  fields to children and class to head, with a derived registration memoised
  per class (`_convert_registry.py:358-456`); `register_type(cls, image=,
  to_atom=, from_atom=, name=, fields=)` is the pytree-style door for the
  rest (`:90`), and `install_type` equips an annotated class with
  `__match_args__`, `__init__`, `__replace__` and `__metta__`
  (`_space_definitions.py:1005`).
- The expression DSL exists and is closed: twenty-two operator dunders build
  terms from atoms through a validated table of twenty-six rows, the six
  comparisons are reserved for order and equality, and a test pins the count,
  the dunder set and that the table refuses mutation
  (`_atoms_core.py:468`, `:1499`; `_operator_lowerings.py:43`;
  `tests/repository/test_operator_documentation.py:114`).
- A space answers `|`, `&`, `-` and `^` already, as the terms `(or a b)`,
  `(and a b)`, `(- a b)` and `(xor a b)`, because `Space` is an `Atom`
  (`Space(Handle) -> Grounded -> Atom`), while `|=`, `-=` and `+=` are
  container operations on the space itself (`_space.py:2131`, `:2096`,
  `:2038`). Set algebra on the operators is not a hole to fill.
- The what-if family is five doors, not one: `transaction(callable | term)`
  is SWI's closed `transaction/1`; `atomic()` and `speculative()` are
  per-call `with` scopes over `snapshot/1` through execution policies;
  `transactional` is the decorator twin; `assuming(*facts)` adds facts on
  entry and removes them on exit, with cleanup failures aggregated into a
  `BaseExceptionGroup`; `reify()` captures a frozen world that `world.eval`
  branches and `commit(world)` applies as a multiset diff in one
  transaction; `saga(receipts)` runs declared compensations in reverse on an
  exceptional exit (`_space.py:2681`, `:2868`, `:2881`, `:2913`, `:2665`,
  `:1967`, `:1973`, `:2759`; `engine/metta/space_hooks.pl:737-767`).
- Memoisation already preserves bag multiplicity through mode-directed
  tabling: `lib_memo` tables the exact memo with `sum` in the last argument
  as a multiplicity coefficient and replays the bag with `between/3`
  (`lib/lib_memo/lib_memo.pl:900-953`), and `lib_tabling` emits
  `table Name/Arity as (incremental, shared)` with every resolvable space
  read declared `dynamic ... as incremental`, verified back through
  `predicate_property` (`lib/lib_tabling/lib_tabling.pl:271-300`). There is
  no Python memo verb, by ruling (`tests/.../test_memoization.py:52-62`).
- A journaled persistent space exists on SWI `library(persistency)`, with a
  `flock(2)` claim, torn-tail recovery and a measured sync ladder
  (`_persistent.py:829`, `:427`, `:744-749`), and whole-space snapshots
  write canonical MeTTa text or a versioned fast image
  (`_space_persistence.py:245`, `:371`).
- `metta.strategies` is the Stratego rewriting basis (`id`, `fail`, `seq`,
  `choice`, `try_`, `repeat`, `all`, `one`, `topdown`, `bottomup`,
  `innermost`, `TP`, `TU`), every export a `Symbol` (`strategies.py:26`);
  the Hypothesis strategies live in `metta.testing` (`testing.py:81`).
- `contextlib.redirect_stdout` does not capture `println!`, by measurement:
  SWI writes to file descriptors 1 and 2; the door is `m.capture()`, which is
  `with_output_to/2` per goal and a `current_output` swap around
  `engine_yield` for held cursors (`_space.py:2858`, `shim.pl:1195`,
  `:1246-1256`); tests use `capfd`.
- `Ctrl-C` interrupts a running goal through janus's heartbeat, installed at
  startup with `config.heartbeat_interval` (default 100,000 inferences), and
  a test sends SIGINT mid-goal (`_engine.py:717-726`,
  `tests/ch10_errors_and_refusals/test_interrupt.py:18`).
- A head reached from Python already carries `__signature__` from its arrow,
  `__doc__` from `(get-doc name)`, `.type`, `.equations` and `.compiled`, the
  last being SWI `listing/1` (`_space_objects.py:1224-1380`); `help(m.fn.x)`
  works with no engine through the generated `_fn.py` documentation map.
- The site colours MeTTa through `website/.vitepress/metta.tmLanguage.json`
  (45ea348b) and GitHub's linguist lists MeTTa with the same `source.metta`
  scope, so `.metta` files colour on GitHub without a `.gitattributes` entry.
- `import metta` measures 18.9 ms in total (`python -X importtime`), the
  largest child `metta._fn` at 13.3 ms cumulative; lazy imports are not a
  candidate.

Facts measured on this box that bound the designs: CPython 3.14.4 in the dev
venv with the GIL enabled, so `string.templatelib` imports there and the 3.14
face of the template door is testable locally; SWI-Prolog 10.1.13; janus's
`_swipl` extension carries no `Py_mod_gil` or `PyUnstable_Module_SetGIL`
symbol, so a free-threaded interpreter re-enables the GIL on import;
`sum` and `min` tabling modes answer (`s(1,X)` over three facts gives 5,
`mn(a,M)` gives 1); `transaction_updates/1` inside `snapshot/1` answers
`[assertz(<clause>)]` and the snapshot discards it; `library(prolog_coverage)`
(`coverage/1,2`, `show_coverage/1,2`, `report_hook/2`),
`library(solution_sequences)`, `library(persistency)` and
`library(prolog_profile)` are all installed, and `library(rocksdb)`,
`library(bdb)`, `prosqlite` and `library(odbc)` are not. Installed in the dev
venv and usable for tests without new dependencies: hypothesis 6.165.2,
annotated-types 0.8.0, pydantic 2.13.4, pyarrow 25.0.0, polars 1.43.2,
pandas 3.0.5, duckdb 1.5.5, numpy 2.5.1, rich 15.0.0, ipykernel 7.3.0,
ipython 9.16.1, pygments 2.20.0.

### 1. Template strings on a 3.12 floor, as sugar over `bind`

PEP 750 shipped in 3.14.0 (2025-10-07). A `t"..."` literal evaluates to
`string.templatelib.Template`, immutable, with `.strings` (the literal
segments) and `.interpolations`, each `Interpolation(value, expression,
conversion, format_spec)`; iterating a template yields the non-empty strings
and the interpolations in order; format specs are stored, not applied; the
debug form `t"{x=}"` folds `x=` into the preceding string and sets conversion
`r` [source: https://docs.python.org/3/library/string.templatelib.html]. The
core developers will not backport it. Two third-party routes exist for older
Pythons: `tstrings-backport` gives `t("...")`, a call returning a drop-in
`Template` with the same two attributes, and `future-tstrings` transpiles the
literal at import time, the `future-fstrings` trick [source:
https://github.com/abilian/tstrings-backport,
https://discuss.python.org/t/100997].

The library already has the semantics a template needs: `bind` substitutes a
symbol with a value after the reader and before the run. What it lacks is a
positional hole. A binding is by name, so it replaces every occurrence of the
symbol, including one the author meant as a symbol; a hole is by position and
cannot collide. The template door is therefore `bind` with generated names.

Decided: one door reads "program text with holes"; three faces produce its
input; all three feed `_BoundValues`.

| Face | Python version | What produces the (strings, interpolations) pair |
| --- | --- | --- |
| `m.run(t"!(fib {n})")` | 3.14 | the literal; accepted structurally, any object with `strings` and `interpolations` tuples, never by `isinstance` against a class that does not exist below 3.14 |
| `m.run(t("!(fib {n})"))` with `tstrings-backport` | 3.12, 3.13 | the backport's `Template`, which satisfies the same structural check |
| `m.run("!(fib {n})", n=10)` | every version | `string.Formatter().parse(text)`, whose 4-tuples `(literal_text, field_name, format_spec, conversion)` are the same shape; a field name resolves against the keywords, a name with no keyword refuses naming the field, and `{{` and `}}` are the brace escapes, as in `str.format` |

Decided: each hole is bound to a generated symbol of a spelling user programs
do not use, spliced into the text in the hole's place, and bound through the
mechanism `bind` already has; the value enters through `encode`, so an `int`
is a Number, a `str` a String atom, an `Atom` itself, a `Space` its handle and
a callable a grounded atom. A hole that falls inside a `"..."` string literal
or inside a symbol is refused with its position, the way SQL parameterisation
forbids a parameter inside an identifier.

Decided: there is no new marker vocabulary. A `str` that should enter as a
symbol is written `{Symbol(name)}`, a `str` of MeTTa text that should be
spliced as expressions is written `{m.parse(text)}` (the explicit escape into
text, visible at the hole), and an object that should stay opaque is written
`{Grounded(obj)}`; the atom constructors are the markers, which is the
psycopg distinction between `sql.Identifier` and `sql.Literal` spelled with
types the library already has. The short forms `{name:sym}`, `{text:expr}`
and `{v:py}` are sugar for exactly those three constructors and are documented
as such; `{v!r}` and `{v!s}` apply Python's conversion first and enter the
result as text.

Rejected: rendering the template to text and handing it to the reader,
because the value's identity is lost on the way (a `str` containing a space
would read as two symbols; a `str` containing a quote would need escaping,
which is the injection PEP 750 exists to remove).

Rejected: transpiling the literal for 3.12 users inside this library;
`future-tstrings` already does it for those who want the literal, and an
import-time transpiler is not a library concern.

Decided: the door's annotation is a `Protocol` (`strings: tuple[str, ...]`,
`interpolations: tuple[InterpolationLike, ...]`, `InterpolationLike` with
`value`, `expression`, `conversion`, `format_spec`) that the 3.14 class and
the backport satisfy structurally.

Decided: the same face on the Node seat is a tagged template literal,
`` metta`!(fib ${n})` ``, the construct PEP 750 was modelled on; the strings
and values reach the tag function exactly as `.strings` and `.interpolations`,
so one door design serves both seats and lands in the metta-node repository
after the split.

Cost class: reading the text plus one `encode` per hole; the string escaping
and the re-parse of values disappear.

Open: `Space.run` does not dedent its source (`_space.py:643` checks only
`isinstance(source, str)`), while the Python compiler dedents function source
before `ast.parse` (`define.py:575`); a triple-quoted MeTTa program with
leading indentation reads fine because the reader ignores whitespace, so
`textwrap.dedent` buys nothing there and is not adopted.

### 2. Answers and spaces as ecosystem citizens

What exists: `Rows.table()` (dict of columns), `to_dicts()`, `to_df()`
(pandas, DuckDB's conversion naming), `to_pl()` (polars) and `pipe(fn)`,
each raising a named `require_module` message when the optional library is
missing (`results.py:572-624`), with `Answers` delegating to `_eager_rows()`
and refusing term answers (`:1197-1209`); `_repr_html_` on `Rows`, `Answers`,
`Space`, derivations and definitions, bounded by `config.display_rows` with an
explicit remainder line (`results.py:651`, `:1242`, `_space.py:1213`,
`derivation.py:149`, `define.py:464`); `__rich__` building a real
`rich.table.Table` with the import inside the method (`results.py:632`,
`:1236`); `__rich_repr__` on `Expression` yielding its children
(`_atoms_core.py:1282`); `Answers[:3]` as a new lazy view that pulls three
(`results.py:1000-1033`), with the engine-side bound offered only when the
view is pristine, there is one pattern, no `where=`, an ordered algebra
declaration and a non-linear foreign seam source (`_space.py:2487-2529`),
the explicit door being `match(limit=n)` (`:2259`); `__bool__` pulling one
row and `__len__` preferring an engine-side count aggregate (`results.py:954`,
`:957`); `any()` and `all()` short-circuiting through the progressive pull;
DLPack recognition through `array-api-compat` (`arrays.py:349`,
`integrate.py:809`); and `tables.py`, which is a DB-API space provider driven
by `(bridge <atom shape> (row <table> (col $v) ...))` declarations that derive
`WHERE` from a query and `INSERT` from an add, read back from `&metta` by
`TableBridge.from_context`, with `pushdown(pattern)` answering `exact` or
`inexact` (`tables.py:433`, `:460`, `:516`, `:625`), and `tables.add(space,
head, data)` accepting anything with `iter_rows()`, `itertuples()`, a column
mapping or an iterable of rows (`:130`).

Absent, zero hits in the tree: `__arrow_c_stream__`, `__arrow_c_schema__`,
`__arrow_c_array__`, `__dataframe__`, `__array__`, `_repr_pretty_`,
`__length_hint__`, any named CSV, JSON, Parquet or Arrow ingest door.

The Arrow PyCapsule Interface is one method: `__arrow_c_stream__(self,
requested_schema=None)` returns a PyCapsule named `"arrow_array_stream"`;
`__arrow_c_schema__()` one named `"arrow_schema"` [source:
https://arrow.apache.org/docs/format/CDataInterface/PyCapsuleInterface.html].
Every consumer this library's users hold reads it: Polars from 1.3
(`pl.DataFrame(obj)`, `pl.from_arrow(obj)`, and `pl.scan_arrow_c_stream(obj)`
for a lazy scan), DuckDB's replacement scans (`duckdb.sql("select ... from
rows")` where `rows` is any object with the method), pandas 3
(`DataFrame.from_arrow`), pyarrow 15 (`pa.table(obj)`) [source:
https://docs.pola.rs/user-guide/misc/arrow,
https://github.com/duckdb/duckdb/discussions/10716]. A producer needs no
pyarrow: `nanoarrow` builds the C structs from buffers.

| Face | Rides on | Status | Gain and class |
| --- | --- | --- | --- |
| `__arrow_c_schema__` and `__arrow_c_stream__` on `Rows` and on a space's row view | `table()`'s columns; the wire kinds map to Arrow types (int64, float64, utf8, bool; a nested atom as its canonical text) | absent | every consumer works with no glue; `to_df` and `to_pl` become sugar over it and their `require_module` refusal is replaced by the consumer's own presence; crossings go from one per row to one per batch |
| the inward door: `tables.add` accepting any object with `__arrow_c_stream__` | the duck-typed shapes `tables.add` already accepts | absent | a Polars frame, a DuckDB relation, a Parquet reader or a pandas frame loads as `(head col1 col2 ...)` atoms one batch per crossing, which is the same cursor chunk discipline the read side has |
| `TableBridge.__arrow_c_stream__` | the SQL provider's own cursor | absent | a SQL-backed space streams its rows to a consumer without materialising atoms: the provider's capability declared as the dunder, which is how the rest of the ecosystem declares it |
| `__array__` on a homogeneous numeric column | the projection | absent | `np.asarray(rows["x"])` without a Python list; tensors already cross through `__dlpack__` |
| `_repr_pretty_` on atoms | the width-78 s-expression printer (`atoms.py:280`) | absent | IPython's pretty printer gets the same grouping and breakables `__rich_repr__` already gives rich; both dunders cost nothing when the printer is absent |
| `__length_hint__` on `Answers` | the count aggregate `__len__` already prefers | absent | `list(answers)` preallocates from the engine's count when it is known and never forces a drain to learn it |
| the general slice pushdown | SWI `library(solution_sequences)`: `limit/2`, `offset/2`, `order_by/2`, `distinct/1`, `group_by/4`, `call_nth/2`, all installed here | partial: the bound is offered only in the ordered-algebra case | `rows[:n]` becomes `limit/2`, `rows[5:10]` `limit/2` under `offset/2`, `rows.order_by(key)` `order_by/2`, `set(rows)` `distinct/1`; the Django and SQLAlchemy precedent is that slicing a lazy query compiles to LIMIT and OFFSET rather than draining; the current gate exists because an unordered bag under a limit is a different answer set, which stays true, so the general form is `limit/2` on the goal with the same gate on ordering |
| `pandas.api.extensions.register_dataframe_accessor("metta")`, `pl.api.register_dataframe_namespace("metta")` | the inward door | absent | `df.metta.into(space, head="row")`, registered only when the library is importable |
| `duckdb.create_function(name, head)` | a head as a Python callable, which `_EngineFunction` already is | absent | a MeTTa head as a SQL function; the arrow-typed variant applies it per batch |

Decided: the Arrow methods are the general mechanism and the frame doors are
their sugar, documented as such, in the order (1) the two methods on `Rows`,
(2) the inward acceptance in `tables.add`, (3) `to_df` and `to_pl` rewritten
over (1), (4) `TableBridge`'s own stream, (5) accessors and the DuckDB
function. The producer uses `nanoarrow` as an optional dependency for the C
structs, with buffers from the wire encoding the library already carries
zero-copy (`_convert_project.py:154-156`).

Decided: the routing candidate this opens is recorded beside the MORK Θ(N²)
item rather than here: a conjunctive `match` with large fan-out is a
nested-loop join today (`a-conjunctive-match-is-a-nested-loop-join`), and a
hash join over the same rows in DuckDB through two capsule streams is a class
change; it is measured on the match-skew rows of `engine/bench-baseline.json`
after the split, under the per-workload routing rule the MORK item has.

Decided, on the critical pair the read found: `space_a <= space_b` answers
the engine's term order today, a bool that is not subset and never raises
(`_atoms_core.py:934-966`, `_standard_order_le`), while `|` builds `(or a b)`.
The dispatch rule says a conflicting pair is a loud defect, never a coin toss.
Two handles compared with `<`, `<=`, `>` or `>=` refuse with the remedy
(`spaces.diff(a, b)`, `spaces.union(a, b)`), the way `Handle.__call__` refuses
(`:1085`); term order between handles has no reading a program wants. Set
algebra stays on the function doors `spaces.union`, `overlay`, `diff`,
`readonly` and `mapped` (`spaces.py:530-821`), and `structures.AlphaSet`
(`structures.py:419`) remains the precedent for a `MutableSet` that inherits
the whole algebra from its five methods.

Rejected: `Space` registered as a `collections.abc.Set`, because its
operators are the term-builders and a second meaning on the same spelling is
the coin toss the rule forbids.

Prior art beyond Arrow: Narwhals (one function over any frame through the
capsule alone), Ibis (`__arrow_c_stream__` on `Table`), the DataFrame
Interchange Protocol (`__dataframe__`, older and heavier, not adopted: Polars
switched `from_dataframe` to the capsule in 1.23).

### 3. Foreign objects as expressions

What exists: `encode(value)` with the precedence exact-class fast table,
class-owned `__metta__` fetched with `inspect.getattr_static`, callable
mention, `singledispatch` by MRO, then `Grounded(value)` (`_atoms_core.py:1721`,
`:1607`, `:1756`); `__from_metta__` and `build(atom, cls)` for the reverse
(`_convert_build.py:130`, `:193`); the derived default registration for
dataclasses, NamedTuples, pydantic models and Enums, refusing `init=False`
fields and required `InitVar`s rather than losing data
(`_convert_registry.py:358-456`); the TypedDict hook (`_parameterized.py:158-247`);
`register_type` (`_convert_registry.py:90`) and `register_object_type(predicate,
name)` (`integrate.py:801`) for the rest; `install_type` equipping an annotated
class with `__match_args__`, `__init__`, `__replace__` and `__metta__`
(`_space_definitions.py:1005`); `__match_args__` on every atom class and
`Expression` registered as a `Sequence` so `case [head, *args]` matches
(`_atoms_core.py:1581`); `ObjectView` presenting a live object as
`(py-field obj name value)` atoms, writable through `setattr`, and
`paths.path(...)` reading named attributes after a stored match
(`spaces.py:205`, `paths.py:65`).

Absent: attrs and msgspec classes (zero hits); an unregistered `__slots__`
object falls to an opaque handle unless it carries `__metta__`
(`_convert_project.py:145`), although `field_names(obj)` reads `__slots__`
for the object view (`_object_fields.py:18`).

Decided: the derived default registration reads `__match_args__` before it
gives up. PEP 634's `__match_args__` is the class's own statement of its
positional fields, `dataclass`, `NamedTuple` and attrs all populate it, and
the reverse direction is the positional constructor call `__match_args__`
guarantees works; JAX's `register_pytree_node(cls, flatten, unflatten)` and the
`unification` package's per-type dispatch are the same shape with a
registration call, and this is that shape with none. A class opts out, or
overrides, with `__metta__`, which wins as the more specific declaration.
Pydantic models do not set `__match_args__` and stay on their existing
derived registration.

Rejected: `dataclasses.field(metadata=...)` as a place for per-field MeTTa
claims, because `Annotated` (section 4) is one vocabulary read by the checker,
the engine and the tests, and field metadata would be a second spelling.

### 4. Declarations the checker reads

What exists in `_type_annotations.py`: `TypeVar` to `$t` with `one_of` and
`bound` forms (`:118-135`, `:175-180`); PEP 695 `__type_params__` copied onto
the probe function so `item: T` resolves one annotation at a time (`:525`);
`Literal[...]` as `(Literal v1 v2 ...)` in annotation position and as the set
of its values' types in type position (`:140`, `:316`); `NewType` (`:136`);
`Callable[[A], B]` as the bounded product of arrows (`:197`); `None` and
unions (`:173`, `:289`); `Self` to `$t`, `Never` to `Empty`, `LiteralString`
to `String`, `type[X]` to `(type X)` (`:144-149`, `:271`, `:301`);
`Annotated` refined by Atom-valued metadata only, all metadata kept in the
annotation projection (`:277-285`, `:109-117`), with `arrays.Shape` the one
shipped metadata constructor and `SHAPE_RULES` driving symbolic shape
propagation through `broadcast-shape` and `matmul` (`arrays.py:203`, `:113`,
`:483-495`); `typing.get_overloads` read into one arrow per distinct
overload, arity-checked, tracked per `(space, name)` and retracted on failure
(`_space_definitions.py:729`); `ParamSpec` on `transactional`, `op` and
`define` (`_space.py:387`, `:2913`, `:3677`, `:4568`); deprecation as a MeTTa
catalog row `metta_deprecation(Name, Since, Remedy)` raised as a Python
`DeprecationWarning` from the caller's frame (`_space.py:424`, `:3973`);
`__signature__` and `__doc__` on heads (`_space_objects.py:1331`, `:1359`).

Absent: `annotated_types`, `dataclass_transform`, `TypeVarTuple`,
`typing.override` read as a declaration, stubs generated from a user's
space, `stubtest` and `pyright --verifytypes` lanes.

| Python | MeTTa meaning | Status | Face |
| --- | --- | --- | --- |
| `Annotated[int, Gt(0)]` with the `annotated_types` vocabulary (`Gt`, `Ge`, `Lt`, `Le`, `Interval`, `MultipleOf`, `MinLen`, `MaxLen`, `Len`, `Predicate`, `Timezone`, `Unit`, `doc`) | a refinement: a guard on the argument, a refined return type, a unit on a number | absent, and one registration away | the existing rule refines a type by Atom-valued metadata; `encode.register(annotated_types.Gt, ...)` turning `Gt(0)` into the atom `(Gt 0)` makes `(Annotated Number (Gt 0))` appear with no change to the reader, and one typing rule per constraint gives the engine the guard; pydantic, msgspec, beartype and Hypothesis read the same objects, Hypothesis `from_type()` since 6.89.0 (2023-11-16) with TypedDict fields, `Timezone` and `TypeAliasType` added through 6.157.0 |
| `-> Annotated[int, Ge(0)]` | a postcondition | absent | pydantic's `validate_return` shape; checked at the return crossing |
| contract rows: `raises=`, effects | the exception contract and the effect class | partly: one Error per bad call is the ruling; `EffectClass` is a rank lattice with `join` and `compose` (`vocabularies.py:47`) | deal (life4/deal, 4.24.6) spells the same set as `@deal.raises`, `@deal.has("stdout", "network")`, `@deal.pure`, `@deal.safe`, and `deal.cases(fn)` generates the property test from them; this library reads the facts from `Annotated` and the effect rows rather than adding deal's decorators |
| `deal.dispatch` (the first implementation whose precondition holds) | clause selection by guard | rejected | clause selection is by literal head pattern already: `def fib(n=0)` reads the literal default as the head pattern `0` (`define.py:755`), and a `match` statement inside one compiled body carries the rest |
| `@typing.dataclass_transform` on the class door `install_type` | the checker treats a MeTTa-defined constructor like a dataclass | absent | `install_type` already builds `__init__`; the decorator tells pyright and mypy so, and `Point(1, 2)` type-checks and completes |
| `metta stubs` from a loaded space | a `.pyi` with one signature per declared head | absent for user spaces; the package's own stubs are generated by `initstubgen.py` and `fngen.py` from the shipped catalog | `_EngineFunction.__signature__` already computes the positional-only signature from the arrow; the generator writes it per head, `stubtest` checks the stub against the runtime, and the `init-stub` gate lane is the precedent |
| `@typing.override` on a `@define`d head | the definition shadows an imported space's definition | absent as a declaration | the inherited-declarations ruling (C++ name hiding) makes shadowing deliberate; `override` says the deliberateness, and the checker refuses when nothing was there to override, which is `typing.override`'s own contract |
| `beartype.door.TypeHint` order | the Python side of `:<` | considered, not adopted | the annotation reader decides subtyping on the MeTTa side |
| `pydantic.TypeAdapter` at the seam | coercion of complex annotations | rejected | two validators disagree; `casting.cast(space, value, type)` is the typed acceptance door |

Decided: `annotated_types` is adopted as the refinement spelling because it is
the vocabulary pydantic, msgspec, Hypothesis and beartype already read,
`Annotated` is PEP 593's designated slot for it, and the library's existing
refinement rule admits it through `encode.register` alone.
`metta.testing.cases(fn)` is the deal-shaped face: it builds the Hypothesis
strategy from the arrow and the refinements through `from_type()`, runs the
declared contracts, and the algebra laws use Hypothesis's ghostwriter
vocabulary (`binary_operation(associative=, commutative=, identity=,
distributes_over=)`, `idempotent`, `roundtrip`, `equivalent`), which is the
vocabulary the catalog's `AlgebraLaw` rows should name.

### 5. Scope, time and interruption

What exists: `limits(*, timeout, inferences, stack)` as a context manager
over a `ContextVar`, per-call `timeout=` and `inferences=` overriding it,
`stack=` being SWI's stack ceiling in bytes (`_space.py:2832`,
`_space_objects.py:191`, `:221`); `under(EvaluationContext(algebra, limit,
order))`, the algebra demand context, whose `limit` is an answer-count demand
and not a resource (`_under.py:26`); the five what-if doors of the Method
section; `capture()`; the heartbeat interrupt and `thread_signal/2`
interrupts of a specific engine (`remote.py:1862`, `aio`); `(with-seed 42
body)` as a MeTTa scope saving and restoring `random_property(state(_))`
(`engine/translator/special_forms.pl:592-600`, `engine/metta/control.pl:858-863`);
`call_with_time_limit/2` platform-gated behind `metta_platform_load(deadlines)`
so a build without `library(time)` refuses by name and the wasm seat offers no
time scope (`engine/metta/control.pl:365`, `extensions/node/bridge.pl:553-557`);
`call_with_inference_limit/3` on every seat.

Absent: `contextlib.ContextDecorator` (zero hits; `transactional` is the one
decorator twin); `call_with_depth_limit/3`; tabling restraints and
`prolog:tripwire/2`; a `(speculate ...)` special form (the engine's
`metta_speculate/1` is reached from Python and Node only); a `random.Random`
accepted at a door (`Space.sample` takes an `int` seed, `_space.py:5049`).

| Face | Rides on | Status | Gain |
| --- | --- | --- | --- |
| every scope door usable as a decorator | `ContextDecorator` on `ScopedLimits`, the atomic and speculative scopes, `assuming`, `capture` | absent | one mechanism, two faces, Python's own idiom; `transactional` already shows the shape |
| tabling restraints as the memo-side limit | `as max_answers(N)`, `subgoal_abstract(Size)`, `answer_abstract(Size)`, the flags `max_answers_for_subgoal` and `max_table_subgoal_size`, and `prolog:tripwire(Wire, Context)` | absent | a memoised head that explodes trips a wire; the hook's three outcomes are a Python callback's three outcomes (return `True` handled, return `False` default action, raise); the `bounded_rationality` action ignores the answer, prunes the goal's choice points and adds an answer conditional on the undefined `answer_count_restraint/0`, a tagged answer the algebra rows can carry as "restrained" [source: https://www.swi-prolog.org/pldoc/man?section=tabling-restraints] |
| `(speculate body)` and `(assuming facts body)` as special forms | `metta_speculate/1`, which exists; `assuming` as add-then-remove under `setup_call_cleanup` | absent | a MeTTa program reasons hypothetically from within, the way `(with-seed ...)` already scopes randomness from within; kernel builtins are sanctioned where the arbiter is silent |
| `reify()` and `commit(world)` computing their diff in the engine | `transaction_updates/1` inside `snapshot/1`, which answers the pending `assertz` and `erased` clause references (probe above) | absent: the world's diff is a Python multiset diff today | Datomic's `d/with` returns `:db-after` and `:tx-data` from one speculative application, and `d/transact` is that data applied; the engine already knows the world's `tx-data` and the Python side recomputes it |
| a `random.Random` at `sample` and a `with m.seed(...)` twin of `(with-seed ...)` | `set_random/1` | partial | the Python word for a seeded generator is the object, not the integer; the MeTTa scope already exists and only its Python face is missing |

Decided: the scope doors are one family (section 18) and each new face is
added by declaring a parameter, never by a new context manager class.

Rejected: `with m.transaction():` as an open block, for the recorded reason
at `_space.py:2681`: SWI's `transaction/1` takes a closed goal, and an open
begin/commit would lie about the isolation provided.

### 6. Memo that stays right

The memoisation ruling (`2026-09-06-memoisation-is-a-library.md`) is that
the developer's word decides what is memoised and the library adds no purity
check; `test_memoization.py:52-62` records that a Python memo decorator was
removed as a hardcoded verb for one library, and the nine `lib_memo` forms
(`memoize`, `memoize-exact`, `config-memoize`, `get-memoize-config`,
`clear-memoize`, `invalidate-memoize`, `is-memoized`, `get-memoize-stats`,
`clear-memoize-stats`) are reached as terms from every seat, with a per-name
policy declared as the catalog row `(cache Name Policy)`. The declarations
thread's face is Python's own `@functools.cache` on a `@define`d function
read as `(memoize f)`, which adds no verb.

What the engine offers that the policy vocabulary does not yet name:

- Incremental tabling: `lib_tabling` emits `table Name/Arity as (incremental,
  shared)` and declares every resolvable space read `dynamic ... as
  incremental`, or `as shared` alone when the body walk meets an impure or
  higher-order goal, then verifies the install through `predicate_property`
  (`lib/lib_tabling/lib_tabling.pl:271-300`); `structures.TabledMap` is the
  Python view over it, with `stats()` answering `tables`, `answers`,
  `complete-call`, `invalidated`, `reevaluated` and `clear()` dropping the
  tables (`structures.py:475-571`).
- Multiplicity: `lib_memo` tables the exact memo with `sum` in the last
  argument as the multiplicity coefficient, every raw proof contributing 1,
  and replays the bag with `between(1, Multiplicity, _)`
  (`lib/lib_memo/lib_memo.pl:900-953`). That is the counting semiring
  spelled as a tabling mode, which is why a memo does not drop duplicates.
- Monotonic tabling: `:- table connected/2 as monotonic.` with `:- dynamic
  link/2 as monotonic.` propagates the consequences of an assert without
  recomputing the tables (semi-naive forward propagation); a retract falls
  back to the incremental algorithm; `as (monotonic,lazy)` queues new answers
  until the table is next used; the external-data variant triggers the same
  propagation for facts a foreign store adds [source:
  https://www.swi-prolog.org/pldoc/man?section=tabling-monotonic].
- Mode-directed tabling beyond `sum`: `lattice(PI)`, `po(PI)`, `min`,
  `max`, `first`, `last` [source:
  https://www.swi-prolog.org/pldoc/man?section=tabling-mode-directed]; `min`
  answers on this box.
- Answer subsumption: `as subsumptive` reuses a completed table for a more
  general goal.

| Policy row | Rides on | Status | Class |
| --- | --- | --- | --- |
| `(cache f monotonic)` | `as monotonic` on the head and on the space's storage predicates | absent | an `add-atom` propagates only its new consequences: forward chaining at delta cost, which the asymptotic-wins survey found absent in every MeTTa engine |
| `(cache f (lattice join))` | mode-directed tabling with the carrier's join in the answer position | absent | a least fixpoint over a cyclic space (shortest paths, PLN strengths) becomes computable where plain evaluation loops; `sum` over the count is the case already shipped, so the general row generalises what `lib_memo` does for multiplicity |
| `(cache f subsumptive)` | `as subsumptive` | absent | a specific call reuses a completed general table |
| restraints as a policy argument | section 5 | absent | a memo declares its own bound |

Decided: the policy vocabulary is a catalog vocabulary (a `StrEnum` by the
existing generator), spelled as MeTTa words because Python has none for
these, reachable as terms from every seat, and compiled to SWI's `as` option
list; the library invents no option the engine lacks and refuses no option
the engine has. Incremental is present; monotonic comes first among the
absent, lattice second, subsumptive third, each measured on the shared-head
suite and the match-skew rows before it is pinned. MORK-backed spaces are not
dynamic predicates, so their face is the external-data hook, measured
separately.

Rejected: a `memo=` keyword on `define` or a `cache_info()`-shaped Python
door, because the ruling holds and the terms already reach every seat.

Prior art: XSB's incremental tabling; DRed and semi-naive evaluation for
Datalog (Gupta, Mumick and Subrahmanian); Salsa and Adapton for demand-driven
incremental computation; Materialize for the streaming form. In Python,
`functools.lru_cache` has no invalidation, `cachetools` invalidates by time,
`joblib.Memory` by argument hash on disk.

### 7. Objects as views over a space

What exists is the view direction: `spaces.object_view(obj)` presents a live
object's fields as `(py-field obj name value)` atoms, enumerable, matchable
by root and field, writable through `setattr`; `spaces.view(obj)` presents a
`Mapping`, `Set` or `Sequence` as a space; `spaces.union(stored, view)`
composes them (`spaces.py:205`, `:303`, `:89`, `:186`; `llms.txt:445`).
Absent: descriptors (`__set_name__`, `__get__`, `__set__`), class keyword
arguments on `__init_subclass__`, and a class-declared mapping where the
Python class is the schema.

Decided: the view direction is the one that fits "everything is data" and
stays the design. The class-declared direction (a `class Agent(m.Object)`
with descriptor fields and rule methods that answer on an instance and are
patterns on the class, SQLAlchemy's `hybrid_property`, Django's instrumented
attributes, pyDatalog's `Mixin`, owlready2's `with onto:`) is not adopted
now; it would ride `install_type` for the constructor and `object_view` for
the fields, and its cost depends on the crossing cache of the freeze spike in
the declarations thread. Open until that spike answers.

### 8. Modules and import

What exists: `m += metta.lib.he`, which performs `!(import! <m> (library
lib_he))` (`_library.py:218`); `import!` reloading by content digest,
`metta_source_changed/1` and `replaced_source_spaces/3` withdrawing and
replacing a changed file's atoms and compiled definitions in every space that
holds them (`engine/filereader/source_lifecycle.pl:905-1031`); `Space.load()`
as `consult/1`; the live head namespace `m.fn` with `__getattr__`,
`__getitem__`, `__dir__` and `_ipython_key_completions_`, the generated
offline `metta.fn` with a documentation map, and the underscore-to-hyphen map
on attributes with the exact bracket door (`_space_objects.py:1410`,
`_fn.py:707`, `_atom_namespace.py:134-275`); `importlib.resources` for the
bundled runtime with `as_file` because SWI consults files
(`_engine.py:574-582`); the consumed entry-point groups `metta.integrations`,
`metta.spaces` and `metta.libraries` (`integrate.py:137-147`, `:351-362`),
documented at `website/integrations/index.md:20-30`, with only `pytest11`
declared by this package. Absent: a `sys.meta_path` finder for `.metta`
files; a Python-side reload, refused on purpose (`engine/metta/interop.pl:1530`:
"importlib.reload/1 is what would implement it; nothing here pretends to").

| Face | Rides on | Status | Gain |
| --- | --- | --- | --- |
| `import lib_list` for a `.metta` file on `sys.path` through a `MetaPathFinder` and `Loader` | `import_library` and the live `_FunctionNamespace` | absent | a module object with heads as attributes, `__all__`, `__doc__`, `__file__`; tooling that understands modules (pickling by qualified name, `-m`, a stub beside the file) works; `importlib.reload(lib_list)` is `import!`'s digest reload under Python's word |
| the library pack repository publishing through `metta.libraries` | the consumed group | present as a consumer; the split's item as a producer | a pip-installed package declares its MeTTa libraries the way pytest plugins declare themselves |

Prior art: Hy (importing `hy` installs the finder for `.hy` modules), rpy2's
`importr` (an R package as a Python module with functions as attributes),
Cython's `pyximport`, Julia's `PythonCall`.

### 9. Observation and diagnosis

What exists: `m.trace(term)` wrapping every compiled function with
`wrap_predicate` and recording `call` and `exit` events (a reduction that
fails leaves its call without an exit; there is no `redo` port)
(`_trace.py:174`, `engine/tracer.pl:1-124`); `m.debug(term, on=[...])`, a
debugger held inside an SWI engine through `engine_yield/1` with breakpoints,
`step()` and `resume()` (`_debug.py:266`); source observation through
`prolog_trace_interception/4` for the `call` and `unify` ports
(`engine/source_observation.pl:386-434`); `MeTTa.profile()` reading one
`profile_data/1` under `with_output_to` (`shim.pl:352`, `:1502`,
`_space.py:1345`); `m.stats()` from four `statistics/2` keys in one crossing
(`shim.pl:1204-1208`); nine module loggers under `metta.` with a
`NullHandler` (`remote.py:140`); five `add_note` sites, one of which names the
evaluated term (`results.py:160`); hand-built did-you-mean through
`difflib.get_close_matches` at cutoff 0.8 over `fun/1` names and special
forms (`_head_meaning.py:37-125`, `results.py:1103`); the dunder guard and
`_ipython_key_completions_` on the namespaces; `listing/1` as `.compiled`;
`clause_property(Ref, file(File))` read for registration refusals only
(`engine/metta/interop.pl:107-129`); `assertEqualToResult` computing
`$Missed` and `$Excessive` and discarding both, so a failing assertion prints
the form as written (`engine/prelude.metta:122-128`,
`engine/metta/runtime.pl:307-315`).

Absent: `faulthandler`, `sys.audit`, `sys.unraisablehook`, `sys.monitoring`,
library `Warning` classes, `filterwarnings` in pytest configuration, a
`print_message` bridge to `logging`, `AttributeError(name=, obj=)`, a
source-location door for a head, `library(prolog_coverage)` in the tree
(installed on this box), `dwim_predicate/2`.

| Face | Rides on | Status | Gain |
| --- | --- | --- | --- |
| the bag diff carried into the assertion failure | `$Missed` and `$Excessive`, already computed | absent | `MettaAssertionError` gains `.missing` and `.excess` beside `.actual` and `.expected` (`errors.py:310-315`) and the message shows the difference rather than the form; the cheapest gap on the list |
| `faulthandler.enable()` under the gate, `filterwarnings = error`, `PytestUnraisableExceptionWarning` as an error | pytest configuration | absent | this week's finaliser crashes were unraisable exceptions before they were segmentation faults; the gate should have read them as failures |
| a source-location door: `head.origin` answering file and line per clause | `clause_property/2` with `file(F)` and `line_count(L)`, given the clause references `nth_clause/3` yields | absent | tracebacks and IDE "go to definition" name the `.metta` file and line; the engine reads the file half already |
| a `metta.engine` logger fed by `user:message_hook/3` | the Node seat's capture window precedent (`extensions/node/bridge.pl:126-145`) and the engine's failing `thread_message_hook/3` (`interop.pl:1208-1214`) | absent | engine messages are filtered and formatted by the tool every Python program already configures; the hook must fail after recording so SWI still prints, which is the thread hook's shape |
| `AttributeError(name=, obj=)` beside the existing `difflib` suggestion | CPython's own suggestion machinery (3.10) | absent | the interpreter's "Did you mean" agrees with the library's, from the same two fields |
| a `sys.monitoring`-shaped tracer | the `wrap_predicate` tracer, which is already per compiled function | partial | a tool id, `set_local_events` per head and a `DISABLE` return that unwraps that head; PEP 669's shape was designed for near-zero cost when no tool listens |
| `sys.audit("metta.host", ...)` at the host-evaluation doors | the `py-atom` and load doors | absent | the doors that evaluate host code raise audit events the way `exec` does |
| `m.profile()` exported as `pstats`-compatible data | `profile_data/1`, already read | absent | SWI's profile becomes viewable in every `pstats` consumer (`snakeviz`, `tuna`), the way `yappi` and `pyinstrument` export |
| a clause-coverage report over the corpus | `library(prolog_coverage)`, installed and unused | absent | the clauses of `lib/*.metta` never reached by the corpus and the suites are the dead-rule candidates, which is `vulture` for MeTTa; a REPORT lane |
| `sys.remote_exec` (PEP 768, 3.14) | nothing to build | note | a stuck process can be inspected from outside on 3.14 |

### 10. Notebooks and documents

What exists: the `%%metta` cell magic whose line names a space, and `use(m)`
to retarget it (`ipython.py:56-73`); the tour notebook executed under
`nbclient` in an isolated kernelspec the test writes, requiring the `Rows`
HTML table to survive (`tests/repository/test_notebook.py:50-100`); the
recorded decision that the full-notebook experience is
`trueagi-io/jupyter-petta-kernel` and this package composes with it
(`ipython.py:3`); that kernel exists (Python, updated 2026-04-09, requiring
PeTTa installed separately, janus-swi and ipykernel, with a `%cd` magic);
twenty-six reference pages regenerated from the AST by `tools/reference.py`
and gated, with `libdoc.py`, `codecdoc.py`, `vocabgen.py`, `aiogen.py` and
`initstubgen.py` on the same contract; the `source.metta` grammar loaded by
Shiki. Absent: a Pygments lexer, a `%metta` line magic, a tree-sitter grammar,
`nbval`, Jupyter Book.

| Face | Rides on | Status | Gain |
| --- | --- | --- | --- |
| a Pygments lexer registered through the `pygments.lexers` entry point, mirroring the grammar's twelve token groups, with a test that both tokenise the corpus alike | `website/.vitepress/metta.tmLanguage.json` | absent | Sphinx, rich, IPython, Jupyter and mkdocs highlight MeTTa once `pymetta` is installed; the grammar stays the one source |
| the upstream kernel verified against this fork's launcher | the `metta` console script, which keeps upstream's launcher contract for exactly this reason (`cli.py:37`) | present upstream; unverified here | the textbook's notebooks run in a MeTTa kernel; verification is one CI job |
| `%metta` line magic | `ipython.py` | absent | one-line evaluations without a cell |
| one grammar across the seven repositories | the same file imported by each site's VitePress config, the same scope MeTTa-LSP ships | present here | the split repositories reuse rather than copy |

Rejected: Jupyter Book for the textbook repository, because the corpus runner
already executes every example under the gate and the site colours them from
the grammar; the executable-document property the Book would add is the one
the gate already provides, and the notebooks stay the interactive medium.

### 11. Testing faces

What exists: `metta.testing` with twelve atom strategies (`names`,
`symbols`, `variables`, `numbers`, `numpy_scalars`, `texts`, `grounded`,
`atoms`, `expressions`, `ground_atoms`, `patterns`, `from_pattern`), the
conformance checks (`check_space_provider`, `check_codec`, `check_twin`,
`check_replay`, `check_minted_handles`) and the compliance suites, and the
benchmarking helpers (`measure_counters`, `measure_instructions`,
`benchmark_counter_slope`, `BenchmarkBaseline`) (`testing.py:81`); a
`RuleBasedStateMachine` over `testing.expressions` in the library's own
suite (`tests/ch04_spaces_and_matching/test_space_stateful.py:23-36`); the
two pytest fixtures `metta` and `scratch_space` under `pytest11`
(`pytest_plugin.py:25-38`); Hypothesis profiles `metta`, `petta`, `ci`
(`tests/conftest.py:119-127`); xdist with `--dist loadfile`; process bounding
through `bounded.sh` wrapped around `subprocess.Popen` (`conftest.py:41-104`);
the benchmark lanes `benchmarks`, `instructions`, `scaling`, `extcost`,
`engine-bench`, `boot-determinism`, `node-bench`, `c-bench`, `mork-bench`
run in CI with `perf stat -e instructions:u` verified readable first
(`.github/workflows/checks.yml:27-36`, `:74`). Absent: `pytest-randomly`,
`pytest-timeout`, `pytest-memray`, mutation testing, `[tool.coverage]`, a
`pytest_collect_file` hook for `.metta` files (a hardcoded `FILES` list is
parametrised instead, `tests/repository/test_metta_examples.py:22-47`),
an exported bag-equality assertion with a diff, CodSpeed.

| Face | Rides on | Status | Gain |
| --- | --- | --- | --- |
| `metta.testing.cases(fn)` | `from_type()` over the arrow's types and the `annotated_types` refinements; `register_type_strategy` for atoms | absent | the property test the developer would have written, from the declarations |
| `metta.testing.SpaceMachine` exported for downstream providers | the suite's own stateful machine and the compliance-suite pattern | partial | a third-party provider proves add, remove, match and speculate commute with a `Counter` model, the bag-multiplicity ruling as a machine |
| `pytest-randomly` | ordering and seeding | absent | the order-dependent pins item becomes a lane |
| `pytest-timeout` per item | wall ceilings | absent | an untimed lane green-masks cost classes (the recorded lesson) |
| `pytest-memray` | allocation tracking | absent | leaked engine handles and cursors across the seam show as growth |
| mutation testing (`mutmut`) as a REPORT lane | the suite | absent | a lane that cannot fail is not a lane; the mutation score says which tests can |
| `pyright --verifytypes metta` and `stubtest` | the generated stubs | absent | the public surface's typing completeness is a number, and the stub is checked against the runtime |
| a `pytest_collect_file` hook collecting `.metta` files | the corpus runner | absent | `-k`, `-x`, xdist and junit output over the corpus, one item per file |
| instruction-count benchmarks in CI (CodSpeed) | `pytest-codspeed`, which measures instructions rather than wall time | absent; an external service, the user's decision | the discipline the repository already has, with PR comments |

### 12. Persistence and data

What exists: `PersistentFactSpace(path, schema, sync, rename=)` over
`library(persistency)`, an append-only journal with `db_attach/2`,
`db_sync(reload | close | gc)`, a `flock(2)` claim on `<journal>.lock`, a
torn final record copied to `<journal>.tail`, and the sync ladder measured at
3000 adds (`none` 169k adds/s, `flush` 166k, `close` 86k)
(`_persistent.py:829-874`, `:427`, `:744-749`); `save_space` and `load_space`
with `format="metta"` (canonical, byte-stable) or `"fast"` (a versioned
image), `.gz` detected on load, temp-sibling write, fsync, atomic replace
(`_space_persistence.py:245`, `:371`); `Space.__reduce__` by name and a loud
`__deepcopy__` refusal pointing at `space.copy()` (`_space.py:1248-1253`);
`tables.add` and `TableBridge` (section 2); sqlite and DuckDB as example
providers over the foreign-space seam. Absent: any other database library,
an Arrow or CSV ingest door, pickle protocol 5 for a space.

Decided: the persistent store stays `library(persistency)`; the inward Arrow
door (section 2) is the bulk ingest for every columnar source; a space
crosses processes through `save_space(format="fast")` bytes, and a
`PickleBuffer` over those bytes is the protocol-5 face if a process pool
(section 13) needs it.

### 13. Parallelism, with the janus facts

What exists: `EnginePool`, fixed worker threads each holding its own attached
engine for the pool's lifetime, with `pool`, `imap_unordered`,
`FutureSpace`, `spawn`, `every`, `race`, `par_map` and `Channel`
(`parallel.py:131-527`); `AsyncMeTTa` proxying a space onto one worker
thread holding an engine, `async for` over answers and events, cancellation
firing `interrupt()` on the engine's thread (`aio.py`); the HTTP JSON gateway
with bearer tokens, a space allowlist, held cursors and `python -m metta
serve` (`remote.py:599-2049`). Absent: an `Executor` subclass, a process
pool, `asyncio.TaskGroup`, a free-threaded CI job.

Janus's documentation states that it holds the GIL only while it touches
Python and runs Prolog inside `Py_BEGIN_ALLOW_THREADS`, attaching a
temporary engine per call for a thread that did not initiate Janus unless one
is associated persistently [source:
https://www.swi-prolog.org/pldoc/man?section=janus-threads]. `EnginePool`'s
branches run at once on that basis. The library also records a measured
refusal: attaching a space served by the same process over HTTP times out
and then breaks the pipe, because while one thread is inside an evaluation
no other thread can run Prolog (`remote.py:826-838`). [assumed: the two
statements reconcile as "a Python callback inside an evaluation holds the GIL
while it waits, and the server's handler needs it"; not measured as such.]

| Face | Rides on | Status | Gain |
| --- | --- | --- | --- |
| a `concurrent.futures.Executor` face on `EnginePool` | the pool | absent | `executor.map(m.query, patterns)` and `as_completed` in Python's own words; the pool already imports `Future` and `as_completed` |
| a process pool with a booted engine per worker | `ProcessPoolExecutor(initializer=boot)` and the fast image | absent | isolation between programs; the default start method on Linux became `forkserver` in 3.14, and a forked child must not inherit a booted engine's threads, so `os.register_at_fork(after_in_child=...)` refuses the inherited engine |
| the free-threaded build | janus declaring `Py_mod_gil` | blocked upstream | until janus declares support, importing it re-enables the GIL |
| subinterpreters (PEP 734) | nothing | corrected: SWI-Prolog is one process-global system, so "an engine per interpreter" would be a Prolog engine or thread, and janus support for subinterpreters is unconfirmed; the declarations thread's row is superseded by this one | |

### 14. The compiler's extension points

What exists: the closed operator table (Method section); `encode.register`
as the public open extension for classes one does not own
(`_atoms_core.py:1756`), `register_type` and `register_object_type`;
clause selection by literal head pattern (`define.py:755`); `casting.cast`.

Rejected: a runtime lowering hook in the numba `@overload` shape, because
the table's closure is a decided and pinned property, and the need it would
serve, a MeTTa definition standing in for a Python callable, is served by
defining the head with `@m.define` and calling it. A `Transformer` visitor
with `visit_<head>` methods is not adopted either: `__match_args__` and the
`Sequence` registration already make a `match` statement the visitor.

### 15. Repository and distribution practice

What exists (the root `pyproject.toml`, reached through the
`extensions/python/pyproject.toml` symlink): `license = "MIT"` with
`license-files`, the PEP 639 form (`:26-27`); `project.urls` with `Homepage`,
`Repository`, `Issues` (`:71-74`); seven classifiers without `Typing ::
Typed` although `py.typed` ships (`:57-69`, `:140`); `dynamic = ["version"]`
from the attribute `metta._version.__version__`, with `CITATION.cff:13` and
`README.md:715` bumped by hand and no gate binding the three; six extras
(`engine`, `arrays`, `das`, `dataframes`, `test`, `checks`) with `checks`
self-referencing `test`; twenty-three `[tool.*]` sections; the `metta`
console script; `pytest11` as the one declared entry-point group; five
workflows and fourteen jobs, the gate in a container with `seccomp=unconfined`
for `perf stat`, a `versions` job on a bare floor, a `platforms` job on macOS
and Windows installing before SWI exists, a `wheel` job installing from the
sdist into a fresh venv; trusted publishing through
`pypa/gh-action-pypi-publish@release/v1` with no `with:` block, so PEP 740
attestations depend on the action's default; the Node package `private` with
a `prepublishOnly` guard; actions pinned by tag; a hand-edited Keep a
Changelog file of 9,250 lines; `SECURITY.md`, `CONTRIBUTING.md`, issue
templates including a `divergence.yml` form, a pull-request template; the CI
image at `ghcr.io/mestto/metta-kernel-ci`; the C binding built by a
`Makefile` with `swipl --dump-runtime-variables` discovery, a versioned `.so`,
`cmetta.pc` and `make install-check` compiling a consumer that knows only
what pkg-config says; a pure-Python wheel by decision (`MANIFEST.in:6-10`).
Absent: `Typing :: Typed`, a `Documentation` URL, VCS-derived versions,
`[dependency-groups]`, changelog fragments, CodeQL, Scorecard, Dependabot,
SHA-pinned actions, a free-threaded job, a Pygments entry point, a conda
recipe, a user-facing Dockerfile, `CODE_OF_CONDUCT.md`, `CODEOWNERS`,
`.editorconfig`, `.gitattributes`, `pre-commit`, SPDX headers,
`codemeta.json`, a DOI.

| Practice | Status | Reason and prior art |
| --- | --- | --- |
| a version gate binding `_version.py`, `CITATION.cff` and `README.md`, then a VCS-derived version | absent | 0.8.0 bumped three places by hand; the gate is the same class of drift `test_the_minimal_version_matrix_installs_every_required_dependency` catches for the CI matrix; `hatch-vcs` or `setuptools-scm` removes two of the three sites |
| changelog fragments (`towncrier` or `scriv`) | absent | every merge this week conflicted on `## [Unreleased]` and a consolidation script had to exist; fragments merge without conflict and the release compiles them into `CHANGELOG.md`, which the repository rule still requires |
| `[dependency-groups]` for the checks tools | absent | groups are not published as extras of the wheel; `checks` is a developer group, not a user extra |
| `Typing :: Typed` and a `Documentation` URL | absent | one line each; the site exists at the address `CITATION.cff:11` names |
| a conda-forge recipe with `swi-prolog >=10` as a run dependency | absent | PEP 725's `[external]` table is still Draft (round two posted 2025-09), so PyPI metadata cannot say "needs SWI-Prolog", and the library's answer today is to keep `janus-swi` optional and refuse at the first engine call with the platform's install command (`_engine.py:309`); conda-forge can declare it and ships SWI 10.0.0 for linux-64, so the recipe is Linux-only until the feedstock grows |
| PEP 740 attestations set explicitly, and npm `--provenance` when the Node package publishes | to decide | provenance for both registries from the same trusted-publishing workflow; the action's default should not be the thing deciding it |
| a DOI per release through Zenodo's GitHub integration, `doi` in `CITATION.cff` | absent | the citation block gains a resolvable identifier |
| CodeQL (python, javascript, c) and OpenSSF Scorecard on the public repositories | absent | free for public repositories; Scorecard flags tag-pinned actions, which the release waived and which stays the user's call |
| `.gitattributes` with `text eol=lf` for `.metta` and the fixtures | absent | linguist already lists MeTTa, so colouring needs nothing; line-ending normalisation is what the file would buy, and the Windows job is where it would show |
| `pre-commit` with ruff, codespell and the MeTTa-LSP formatter | absent | MeTTa-LSP ships `metta-lsp` with formatting; the Python side calls it rather than growing a second formatter |
| `[tool.metta]` in `pyproject.toml` for boot profile, libraries and backends | absent | the ruff and pytest convention; the split's units and manifest can be read from it |
| PEP 723 inline script metadata in the examples | absent | `uv run example.py` runs an example with no environment set up |
| `abi3` through `cibuildwheel` | not needed | the wheel is pure Python by decision and the engine's C files are SWI foreign libraries, not CPython extensions; the only compiled Python is the opt-in `mypyc` build (`setup.py:102-113`) |

### 16. Ranking and the order of work

Ranked by the class of cost removed or the class of capability added, placed
after the split unless the split needs it:

1. The bag diff carried into assertion failures (section 9): computed today,
   discarded today, one line to carry.
2. The Arrow doors both ways and `TableBridge`'s stream (section 2):
   crossings per row become crossings per batch, the frame doors stop
   coupling to pandas and polars, and the join-routing candidate opens.
3. Monotonic and lattice memo policies (section 6): recomputation after a
   mutation goes from the table to the delta; cyclic fixpoints become
   computable; incremental and `sum` are already there to build on.
4. The template door as sugar over `bind` (section 1): program text without
   string building on every supported Python.
5. Refinements through `annotated_types` and `encode.register`, contracts,
   and `metta.testing.cases` (section 4): one vocabulary read by the engine,
   the checker, the tests and the documentation, admitted by the existing
   refinement rule.
6. `dataclass_transform`, `override`, stubs from a space and the
   `__match_args__` default (sections 3 and 4): the IDE experience.
7. The observation bundle (section 9): `faulthandler` and the warning filters
   first, then the logger bridge, the source-location door, the `pstats`
   export and the coverage lane.
8. The scope family as decorators and the two MeTTa special forms, and the
   engine-computed world diff (section 5).
9. The Pygments lexer and the kernel verification (section 10).
10. The import hook (section 8).
11. The testing lanes (section 11): randomly, timeout, memray, mutation,
    stubtest, the collection hook.
12. The distribution practices (section 15), folded into the split's
    packaging commits where they touch packaging, the changelog fragments
    first because the conflict cost is measured.

Decided: nothing in this thread is adopted by being listed; each face enters
as a catalog row where it declares something, rides the mechanism named in
its row, and is measured on the existing instruments where it claims a cost.

### 17. Unifications: where several faces are one parameter

Writing sections 1 to 15 side by side showed the same information wanted by
several faces at once. Where that happened, the information gets one home and
the faces become projections of it.

1. A hole is a binding. A template hole and `bind(name=value)` both
   substitute a symbol with a value after the reader and before the run; the
   hole is positional, the binding is by name, and both feed `_BoundValues`.
   The markers at a hole are the atom constructors the library already has,
   so the entry vocabulary is the atom vocabulary.

2. The projection is one object. The `table()` columns, the Arrow schema,
   `__array__`, `_repr_html_`, the stub's return annotation, the Hypothesis
   strategy for an answer, the DuckDB function signature and an MCP tool
   schema all derive from the head's arrow and the pattern's variables.
   Decided: a `Projection` (columns with MeTTa types) computed once and one
   projection function per target; the vocabularies are already generated
   from catalog rows by projection (`tools/vocabgen.py`), and the type table
   gets the same shape, one row per MeTTa type and one column per target.

3. Resource budgets and answer demands are two records, deliberately. The
   read found them separate (`limits` over inferences, seconds and stack
   bytes; `under` over algebra, answer count and order), and a rank can
   encode a different axis, so they stay two frozen records varied with
   `copy.replace`. What they share is the carrier (a `ContextVar`) and the
   tripwire shape: one callback whose three outcomes are Python's own.

4. Cache policies are catalog rows, and the engine's `as` option list is
   their compilation target. `(cache f Policy)` with a policy vocabulary
   (`plain`, `incremental`, `monotonic`, `lazy`, `shared`, `subsumptive`,
   `(lattice join)`, `(max-answers N)`) compiles to SWI's option algebra; the
   `sum` coefficient `lib_memo` already tables is the counting case of
   `lattice`. No Python keyword; `@functools.cache` remains the one Python
   face and means `plain`.

5. Pushdown is `library(solution_sequences)`. A slice, `order_by`,
   `distinct`, `group_by`, `call_nth` and `bool()` are one wrapping of the
   goal each; the Python face is the builtin where Python has the concept
   (`rows[:n]`, `set(rows)`, `bool(rows)`) and a named method where it does
   not; an operation on a lazy answer object that has an engine spelling is
   pushed, one that has none drains, and the ordering gate the read found
   stays the rule for when a bound is honest.

6. Events are one channel. `prolog_listen` channels, the trace ports, the
   tripwires, audit events, engine messages and the library's subscriptions
   are events with a channel name and a payload. Decided: one event record
   `(event channel payload)` so a subscription is a `match` over the event
   stream; the sinks are faces: a callback with the `sys.monitoring` shape and
   its `DISABLE` return, a `logging` record, an `asyncio.Queue`, an audit hook.

7. The stream contract is the seam. A Python generator driving a Prolog
   engine, a Prolog engine driving a Python generator, an Arrow stream
   (`get_next`, `release`), an async iterator (`__anext__`, `aclose`) and
   every `py_iter` door share three operations: next, a terminal frame
   (exhausted, or raised with the exception carried as data, which ff997ad3
   made uniform across the eight doors), and release. Decided: the contract
   is named once and every crossing states it in its header; a crossing
   without a terminal frame is this week's defect class.

8. A head is one object with many surfaces. The namespace attribute, the
   module the import hook produces, the stub, `help()`, a CLI from the arrow,
   a DuckDB function, an MCP tool description and Jupyter's `do_inspect` read
   the arrow, the documentation rows and the clauses' source locations.
   `_EngineFunction` already carries the first two; the third is the
   source-location door. Every surface reads the head object; none reads the
   space directly.

9. Stores are a parameter of the space. Dynamic clauses, the persistency
   journal, the SQL bridge, MORK's trie, a remote engine and a read-only Arrow
   view are providers of one `Space`, published through `metta.spaces`; the
   what-if doors belong to the providers that can isolate (the enlistment
   protocol of `space_hooks.pl:656-660`), and a provider that cannot refuses
   with `metta_transaction_unsupported/2`.

10. Configuration is one record. Constructor keywords, environment variables,
    `[tool.metta]` in `pyproject.toml`, and the split's `units.json` and
    runtime manifest describe the runtime layout the engine reads at boot.
    Decided: one frozen `Config` (the existing `_config.py`) whose fields are
    the manifest's, filled in the ruff order (pyproject, then environment, then
    keywords), and printed by `llms()` so a reader sees the layout in force.

11. Documentation is one set of rows. `(@doc ...)` atoms, the doc register
    the engine consults first, `__doc__`, the `llms.txt` roster, the stubs'
    docstrings, the generated reference pages, Jupyter inspection and the
    textbook read catalog rows; the generators already exist on one contract
    and the missing surfaces are more consumers of it.

12. A capability is a dunder. `SpaceProvider._PROTOCOLS` maps each engine
    capability word to the `Protocol`s that satisfy it and refuses with
    `SpaceCapabilityError(space, operation, capability)` when absent
    (`foreign.py:133-313`, `errors.py:216`); the ecosystem declares
    capabilities the same way (`__arrow_c_stream__`, `__dlpack__`,
    `__metta__`), which is NumPy's NEP 18 rule that a library dispatches on
    the presence of a method to the object's own implementation. Decided: the
    Arrow methods are provider capabilities with a default that materialises
    and a native override for providers that can stream.

13. A world is an uncommitted transaction. `reify()`, `speculative()` and
    `assuming()` are three isolation mechanisms for one question, and Datomic
    answers it with one: `d/with` applies data to a value and returns
    `:db-after` with `:tx-data`, `d/transact` applies that data for real, and
    `as-of` and `since` are filters on the value [source:
    https://docs.datomic.com/transactions/model.html,
    https://docs.datomic.com/reference/filters.html]. The engine's
    `transaction_updates/1` is the `:tx-data`; the three doors are documented
    as a ladder by cost and reach (a Python compensation for one fact list, an
    engine snapshot for a goal, a reified value for a branch), and the
    branch's diff moves from Python to the engine.

Elegances that fell out of the mapping, each one line: the tripwire hook's
three outcomes are a Python callback's three outcomes; `bool(rows)` is
`once/1`; a slice is `limit/2`; `__match_args__` is the pytree protocol with
no registration call; a tagged template literal is the t-string on the other
seat; `ContextDecorator` makes every `with` door a decorator for nothing;
`AttributeError(name=, obj=)` makes did-you-mean free; the `sum` tabling mode
is the counting semiring, so multiplicity is an algebra like the others; a
hole is a binding with a generated name.

Rejected, with the reason each time: a type-checker plugin, because pyright
has no plugin interface and stubs serve every checker; a second validator at
the seam, because two validators disagree; `dataclasses.field(metadata=)`
beside `Annotated`, because it is a second spelling; an import-time
transpiler for the template literal, because it is not a library's concern;
set algebra on the space operators, because the spellings are taken by the
term builders; a `memo=` keyword, because the memo ruling holds; a runtime
operator remap, because the table's closure is pinned; Jupyter Book, because
the gate is already the executable document.

### 18. Deeper patterns, from the prior art

Dynamic scope is the family every scope door belongs to. Common Lisp's
special variables, Racket's parameters, Clojure's dynamic vars, Scala's
`DynamicVariable` and Python's `contextvars` are the same mechanism, a
binding visible to everything called within an extent and restored on exit;
algebraic effect handlers (Koka, Eff, OCaml 5) generalise it by letting the
handler resume the computation [source:
https://users.dcc.uchile.cl/~etanter/scope/Dynamic_Scope_in_Programming_Languages.html;
de Vilhena and Pottier, "A Type System for Effect Handlers and Dynamic
Labels"]. This library's `limits`, `under`, `bind`, `capture`, `atomic`,
`speculative` and `assuming` are seven parameters of that one mechanism, each
with its own class today, and `(with-seed ...)` is the same mechanism on the
engine side (`setup_call_cleanup` around `set_random`). Decided: a scope door
is declared as a parameter (its name, its `ContextVar`, its engine goal
wrapper, and whether the engine seat gets a `(with-<name> value body)` twin),
and the context manager, the decorator and the special form are generated
from the declaration, which is how the vocabularies, the stubs and the
reference pages are already produced. The two special forms this adds first
are `(speculate ...)` and `(assuming ...)`, because the engine goals exist.

Multiplicity is a semiring. The bag ruling (order unspecified, multiplicity
never dropped) and `lib_memo`'s `sum` coefficient say the same thing twice:
an answer's count is a value in the counting semiring, and a memo that stores
`(answer, count)` is a `lattice` table under `+`. The algebra rows already
carry tagged answers under a carrier; a memo under a carrier is the same
table with the carrier's join in the mode position. One mechanism for
multiplicity, PLN strengths, costs and provenance.

Views, not copies, is the library's own pattern and deserves its audit
table. `ObjectView`, `view()`, `TabledMap`, `Rows`, the read-only registry
proxy, `readonly(space)`, `overlay`, and a reified world are all Python-facing
objects over engine state with a stated write policy (write-through, refuse,
or copy-on-write) and a stated liveness (live, or a snapshot at a generation).
`Space.__deepcopy__` refusing with `space.copy()` as the remedy is the rule
made loud. Open: one table in the reference listing every Python-facing
object with its liveness and write policy, generated from the same contract
the reference pages use, so a new view cannot omit the two answers.

The discarded diff is the general lesson. `assertEqualToResult` computes the
two directed bag differences and keeps only their emptiness; the memo stores
counts and the printer shows bags; `transaction_updates/1` knows a world's
changes and Python recomputes them. In each case the engine holds the richer
value and the surface asks for the poorer one. Decided: when a door computes
a value on the way to a verdict, the door returns the value and the verdict
is derived at the surface; this is the order `Rows` already follows for
`why()` (`results.py:651`).

Open: whether the seven repositories share the scope-parameter declarations
as data (the kernel's catalog) so the Node seat's tagged template, the
Python seat's `with` doors and the C seat's scopes are generated from one
list, which is the split's runtime manifest question asked one level up.

Open: symbol names that differ only by Unicode normalisation form (`é` as one
code point or two) are two symbols in every MeTTa engine; whether the seat
normalises to NFC at the crossing is a semantics question for the arbiter, not
a Python one.

Open: whether `dis`-shaped naming (`m.dis(head)`) or the existing `.compiled`
is the right word for "print the compiled definition"; Python has the concept
in `dis.dis` and `inspect.getsource`, and the attribute already answers.

### 19. The library at its limit

Asked the same evening: picture the library perfect, ideas only, no
constraint of scope or cost. What follows is that picture, written as what a
reader could count on, each item with the mechanism that would make it true.
None of it is decided by being here; the items that already have a row above
point at it.

1. The library can describe itself completely. A reader is never surprised
   by a capability the library ships, because the capability roster is not
   written but derived: every public door (every module's `__all__`, every
   catalog row, every special form, every CLI subcommand, every entry-point
   group) is a row the generator reads, and `llms.txt`'s capability sections
   are produced from those rows the way the reference pages, the
   vocabularies and the stubs already are. The lane that checks `llms.txt`
   today asks whether every name it mentions exists; the perfect lane also
   asks the inverse, whether every door that exists is mentioned, and fails
   on the first door that is not. This evening's finding, that persistence,
   the snapshot doors, the SQL bridge and the engine pool ship without a line
   in `llms.txt`, is the class of defect that lane removes.

2. The seam costs nothing. An atom is one object with one identity on both
   sides: the Python object and the Prolog term share a heap, so a value
   crossing is a pointer and a conversion never happens. The C substrate is
   where that becomes possible (`cmetta`, the pack-with-C shape), and the
   idiomatic spelling being the fast one stops being an aspiration.

3. Every answer carries its reasons. `why()` exists on rows; perfect is
   `why()` on everything: an answer knows its derivation, a refusal knows the
   rule it applied and the remedy, a cost knows its class and the instrument
   that measured it, a routing decision knows the measurement that chose it.
   The derivation is checkable: a proof term that the arbiter's semantics
   (LeaTTa, Lean 4) accepts, so an answer can carry a certificate.

4. Time is a dimension of every space. A space value at a generation is a
   first-class object (`as-of`, `since`, `history`), so a program can ask
   what was true, what changed and when, and a speculative branch is a value
   like any other; SWI's logical update view already keeps generations, and
   the reified world is the first such value.

5. Nondeterminism is parallelism. Independent branches of a nondeterministic
   evaluation run on as many engines as there are cores without the program
   saying so, with the engine pool as the executor and the bag semantics
   guaranteeing the answers are the same set in any schedule; the program
   opts out per head where order or effects matter.

6. One catalog, every seat. A capability defined once is reachable from
   Python, Node, C, MeTTa text, the notebook, the CLI, the language server
   and an agent tool the moment it exists, because every seat is generated
   from the catalog rows (the scope parameters, the vocabularies, the
   documentation, the type projections), and a seat that lacks a face is a
   generator omission, not a design.

7. Gradual everything. A space becomes durable by one declaration
   (`persistent`), remote by one declaration, memoised by one, frozen by one,
   observed by one, typed by one, and the declarations compose; the library
   never asks a program to be rewritten to gain a property.

8. The IDE knows. Stubs from every loaded space, hover text from the arrow
   and the documentation rows, the clause's file and line for "go to
   definition", the last measured cost beside the signature, and the same
   analyzer in the editor, the notebook and the agent tool, which is what
   MeTTa-LSP already does for its own runtime and what a shared catalog would
   let both engines do together.

9. Every run is reproducible by its receipt. A run's seed, engine build,
   library digests, configuration and inputs are one record; the record
   replays the run and the replay is compared (`check_replay` is the seed of
   this), so a measurement or a bug report is never "on my machine".

10. The engine routes itself. Per-workload routing between the Prolog path,
    MORK's trie and a columnar join is decided from the benchmark baselines
    the repository already keeps, re-decided when a baseline moves, and
    explained on request through item 3.

11. Installation is one command everywhere. `pip install pymetta` brings the
    engine with it, because SWI-Prolog ships as a binary wheel the way
    `cmake`, `ninja` and `ziglang` do, or through conda-forge where the
    dependency can be declared, and the first call never refuses for a
    missing runtime.

12. The perfect refusal. Every refusal names the rule, cites where the rule
    is written (the language surface section, the arbiter's clause), shows
    the remedy as a runnable form, and is one exception class per meaning;
    "did you mean" agrees between the library and the interpreter; a refusal
    inside a callback arrives as the exception it is (this week's repair) on
    every seat.

13. Composability with laws. Spaces compose (`union`, `overlay`, `diff`,
    `mapped`, `readonly`) and so do providers (a persistent overlay of a
    remote space of a SQL bridge), and the laws of that algebra (union is
    associative, overlay is left-biased, diff inverts union) are property
    tests generated from the same vocabulary the algebra rows use.

14. The machinery is a space, with no exception. The catalog, the events,
    the metrics, the profile, the trace, the routing decisions and the
    receipts are spaces a program can match over; nothing about the engine is
    reachable only through a Python attribute.

15. Exactness by default. Rationals cross as rationals (they do), units
    travel with numbers (`Annotated[..., Unit]`), intervals and shapes
    propagate symbolically (shapes do), and a lossy conversion is a refusal
    or a declared cast, never a silent rounding.

16. Equality is identity. Every atom is hash-consed, so structural equality
    is pointer equality, a frozen space is a persistent trie shared with its
    forks, and the intern table's lifetime is the atom garbage collector's;
    the wire intern table and the boxes are the first two pieces.

17. The notebook is the program. MeTTa and Python cells share one space, a
    derivation renders as a tree, a space renders as a table that stays live,
    an interrupt returns cleanly, and the kernel is the same runtime as the
    library rather than a separate process, which is what the upstream kernel
    plus the `%%metta` magic approximate today.

18. The textbook executes. Every chapter of the textbook repository is the
    corpus the gate runs, with expected outputs in the text and the site
    rendering what ran, so a sentence in the book cannot drift from what the
    engine answers; the corpus and the drift lanes are the seed.

19. Capability security at the host seam. Host evaluation (`py-atom`, a
    foreign provider, a callback) runs under a declared capability set the
    program asked for, audited (item 12 of section 17), and a library that
    needs the network or the file system says so in a row a consumer can
    read before loading it.

20. Measurement is the language of every decision. A change that claims a
    cost ships with its measurement on the repository's counters, a routing
    rule cites the row that chose it, a benchmark comparison against another
    engine nets out the null program (this week's parity floor), and the
    numbers appear in the documentation where the claim is made, derived, so
    they cannot go stale.

The thread through the twenty is the same as the thread through the
seventeen sections above it: the library already has the mechanism for most
of them, in one seat or one direction, and perfection is the rule that every
mechanism has every face, generated rather than written, with the roster that
proves it.

### 20. A second pass, from other fields

Asked for more, the same evening. Each item maps a mechanism another field
settled onto a mechanism this engine already has, with the source it was
checked against.

1. One token per fact. Git identifies a change by its commit, Datomic writes
   every datom as `[entity attribute value tx added?]` so that `as-of`,
   `since`, `history` and speculative `with` are filters and applications
   over the transaction id [source: https://docs.datomic.com/transactions/model.html],
   Automerge and Yjs identify every operation by an actor and a counter so
   that concurrent replicas merge without coordination, an observed-remove
   set removes exactly the additions it has seen so a concurrent add wins
   (Shapiro, Preguiça, Baquero and Zawirski, "Conflict-free replicated data
   types", SSS 2011), and provenance polynomials are built from one
   indeterminate per base fact [source: Green, Karvounarakis and Tannen,
   "Provenance semirings", PODS 2007, https://dl.acm.org/doi/10.1145/1265530.1265535].
   Those four are one construct: a unique token minted at every `add-atom`,
   carrying the engine (actor) that added it and the generation at which it
   did. The engine already mints half of it: `assertz(Module:Term, Ref)` in
   `engine/spaces/catalog.pl:287-306` returns a clause reference per added
   atom, SWI's logical update view stamps every clause with the generation
   it was created and erased in, `transaction_updates/1` lists the
   references a transaction touched, and the persistency journal records
   every assert and retract in order. Decided as the design to build on: a
   space's atoms carry tokens; the journal is the token log; `reify()` is a
   branch at a generation, `commit(world)` a fast-forward merge, and a merge
   of two worlds that branched from the same generation is the union of
   their token sets, which is the observed-remove multiset (every add is a
   distinct token, a remove names the tokens it observed, a concurrent add
   survives), so it never conflicts and keeps the bag ruling; `blame(atom)`
   answers the token's actor and generation; `as-of(t)` filters tokens by
   generation; `diff` is a token-set difference; and shipping the journal
   between processes replicates a space the way Automerge ships operations.
   Prior art for the replication: Automerge's op log, Yjs, Datomic's
   transactor log, Materialize's CDC. Cost class: a merge is linear in the
   tokens exchanged, never in the space.

2. The derivation is the free carrier. Green, Karvounarakis and Tannen
   prove that provenance polynomials `N[X]` are universal: any valuation of
   the tokens into a commutative semiring extends uniquely to a homomorphism,
   and query evaluation commutes with it, so bag counts (`N`), boolean truth
   (`B`), why-provenance, the tropical semiring for costs, the Viterbi
   semiring for confidences and access-control lattices are all images of the
   one polynomial [source: the PODS 2007 paper; Green and Tannen, "The
   semiring framework for database provenance", PODS 2017]. This library
   has both halves apart: `metta.derivation` builds proof trees, and the
   algebra rows evaluate tagged answers under a carrier. Decided as the
   design to build on: a `provenance` carrier whose answers are polynomials
   over the tokens of item 1 (product across a conjunction, sum across
   alternatives, multiplicity as the coefficient), so `why()` is the
   polynomial and every other carrier is `under(algebra)` applied to it by
   homomorphism; incremental maintenance falls out, because a removed token
   invalidates exactly the answers whose polynomial mentions it, which is
   the deletion propagation the paper names, and the monotonic and
   incremental tabling of section 6 are its engine-side implementation.

3. Effect handlers are the general scope. SWI's `reset/3` and `shift/1`
   implement delimited continuations, described in Schrijvers, Demoen,
   Desouter and Wielemaker, "Delimited continuations for Prolog", TPLP
   13(4-5), 2013, whose worked examples are effect handlers (state, DCG
   input, iterators, and their composition by propagating unknown operations
   to the next handler), and SWI's own tabling is built on them (Desouter,
   van Dooren and Schrijvers, "Tabling as a library with delimited control",
   TPLP 2015) [source: https://www.swi-prolog.org/pldoc/man?section=delcont,
   https://www.swi-prolog.org/download/publications/iclp2013.pdf]. The scope
   family of section 18 (limits, seed, capture, isolation, algebra demand,
   bound values) and the search strategies of `lib_strategy` are handlers
   for effects the program performs (consume a resource, draw a random number,
   write output, mutate a space, choose among alternatives). Decided as the
   design to build on, engine side: a `(with-handler effect handler body)`
   special form compiled to `reset/3` with the handler resuming through the
   continuation, `(with-seed ...)` re-expressed as the first handler, and
   nondeterminism's strategy (depth-first, breadth-first, best-first, the
   Stratego combinators) as a handler of the choice effect, which is what
   makes a strategy a value the program installs rather than a mode the
   engine has. The manual's caveat is recorded with it: `shift/1` does not
   capture choice points and a cut in a saved continuation does not commit,
   so a handler that saves continuations is bounded to the shapes tabling
   already proves safe.

4. A cost knows its class, declared and measured. Ciao's assertion language
   states types, modes, determinism and cost bounds on a predicate
   (`:- pred p(A) : int(A) + (det, cost(ub, steps, O(length(A))))`) and
   CiaoPP checks or infers them statically; this repository already installs
   Ciao-grade packs in its gate and already measures counter slopes
   (`metta.testing.benchmark_counter_slope`, the `scaling` lane). Decided as
   the design to build on: a `(cost head class)` catalog row (`constant`,
   `log`, `linear`, `quadratic`, `exponential`, in inferences over the
   declared size argument) checked by the slope instrument as a lane, so a
   head's declared class is a claim the gate can fail, shown beside the
   signature (section 19 item 8) and in the library card (item 6). Static
   inference of the class is the research half and is not claimed.

5. Fuzz the arbiter. Differential testing of two implementations on random
   programs is how compilers are kept honest (CSmith for C; QuickCheck-style
   property tests for interpreters); the parity lane already runs a corpus
   against upstream PeTTa at the pin, and `metta.testing.expressions` already
   generates well-formed programs. Decided as the design to build on: a
   REPORT lane that generates programs from the strategies, runs them on
   this engine and on upstream PeTTa, compares answer bags, and shrinks a
   disagreement to a minimal program through Hypothesis, with the arbiter's
   answer recorded as the expectation; the lane's disagreements are the
   divergence issues the repository's `divergence.yml` template already asks
   for.

6. Library cards and a lockfile. A model card states what a model does,
   its inputs, its limits and its provenance; a library card is the same
   document for a `lib_*`: heads and arrows, `(@doc ...)` text, effect
   classes, declared cost classes, examples that run under the gate, the
   measurements the library cites, and its digest. `tools/libdoc.py`
   already writes the documentation half from the catalog. A `metta.lock`
   records the library digests, the engine build and the pins a program
   loaded, and `import!`'s digest check (which already decides reloads)
   verifies a load against it, so a program's knowledge is reproducible the
   way a Python environment is under `uv.lock`.

7. More projections of the one schema. The gateway (`python -m metta serve`)
   gains an OpenAPI document generated from the served space's heads and
   arrows; a GraphQL schema is the same projection with types from `:`
   declarations and queries from patterns; trace events become OpenTelemetry
   spans, `m.stats()` deltas become metrics, and the `metta.engine` logger's
   records become logs, through one exporter; the gateway's cursors stream
   Arrow IPC batches (section 2's capsule serialised) so a remote consumer
   receives columns. Each is a column of the projection table of section 17
   item 2, never a new mechanism.

8. Explain and advise. A query's plan should answer `explain()` the way SQL,
   Polars and DuckDB explain theirs (the query-planning work of this week is
   the plan to print); and the engine can advise: from `profile_data/1` and
   the call counts, a REPORT lane proposes `(cache head policy)` rows for the
   heads that would pay (a memo advisor, the shape of PostgreSQL's index
   advisors and Soufflé's automatic index selection, Subotić et al., VLDB
   2018), never applying them, because the developer's word decides.

9. The textbook runs in the reader's browser. The Node seat already boots
   the engine under swipl-wasm in a browser (the gate installs Chromium and
   runs the browser binding), and MeTTa-LSP already ships a browser IDE with
   the same analyzer in a Web Worker. Every example in the textbook
   repository gets a run button that executes it in the page with no server,
   which is the executable-document property Jupyter Book would have added,
   from the seat the split already builds.

10. Reversible debugging over the trace. `m.trace()` records events as data
    and `m.debug()` holds an evaluation in an engine; recording the trace
    with the seed, the bound values and the space's generation gives a run
    that can be stepped backwards and forwards through its recorded events
    (the shape of `rr` and of Jane Street's magic-trace), and `check_replay`
    already proves a recorded run is replayable.

11. Refusals as code actions. Every refusal names a remedy in prose; a
    structured `remedy` field carrying the runnable form (an atom, or a
    Python call) lets MeTTa-LSP offer it as a quick fix, the way a compiler's
    fix-it hints become editor actions, and lets `metta lint` apply it.

12. Standing queries as reactive views. `examples/live/standing_queries.py`
    exists, the subscriptions deliver events, and incremental tabling keeps
    a table current; a `live(query)` object that re-answers as the space
    changes, iterable with `async for`, rendering as a table that updates in
    a notebook, is those three composed, the shape of Materialize and of a
    spreadsheet cell.

13. Small faces: `metta -` reads a program from standard input and `--json`
    prints answers one per line for pipelines, making the CLI a Unix filter;
    `space.digest()` (the canonical `save_space` bytes hashed) names a
    fixture in an evidence tag exactly, which the obligations framework
    wants; `space.infer_types()` proposes `:` declarations from the facts a
    space holds, the way `pandas.api.types.infer_dtype` reads a column, and
    feeds the stub generator and the library card.

Decided: items 1, 2 and 3 are one design (tokens, the free carrier over
them, handlers as the scope) and enter the program as its own wave after the
faces above, since they change the engine's storage and control; items 4 to
13 are faces of mechanisms that exist and enter by the ranking rule of
section 16, measured where they claim a cost.

### Ruling, later the same day: the arbiter is PeTTa

The user ruled that the semantics arbiter is upstream PeTTa at the pinned
commit the parity lane clones, not LeaTTa. Three places above were written
against LeaTTa and are corrected here rather than edited in place, per the
journal's own rule: item 3 of section 19 (a derivation checkable against the
arbiter's semantics) reads against PeTTa's measured answers, the parity
corpus, and a Lean certificate is a research idea rather than the arbiter's;
the Open on Unicode normalisation is a question for PeTTa's behaviour at the
pin; "where the arbiter is silent" in section 5 means where PeTTa has no
measured answer. LeaTTa citations elsewhere in the tree are the provenance
of a behaviour, not its authority, and the sentences that still say otherwise
are swept separately (`ai-todo.md`).
