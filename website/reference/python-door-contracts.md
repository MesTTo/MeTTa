# Python door contracts

Generated from `metta.doors` and workspace packages' `DOORS` declarations.

The same contracts are typed `(door ...)` atoms in `&metta` at boot. `seam.publish(context)` refreshes the snapshot after registration or withdrawal.

## space:name

```python
name -> _SpaceId
```

Kind: `introspection`. Answer: `value`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._space:Space._door_name`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-type metta._space _SpaceId)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> The live engine name represented by this handle.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_space_identity_doors_follow_the_handle_lifetime`.

## space:self

```python
self -> Space
```

Kind: `introspection`. Answer: `space`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._space:Space._door_self`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `SpaceType` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> The space this receiver's doors work in, which for a space is itself.
>
> MeTTa's own `&self` is the space a form is evaluated in, and a form
> stored in a space is evaluated in THAT space, so a space's `&self` is
> the space. `MeTTa.self` answers the same question for a context, whose
> answer is its home space, which is what makes `m.self` one attribute
> read at every door that takes either.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_space_identity_doors_follow_the_handle_lifetime`.

## space:space-names

```python
space_names() -> list[str]
```

Kind: `introspection`. Answer: `list`. Effect: `readOnlyLookup`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_space_names`, receiving `method`.

Engine binding: `metta_py_space_names`, wire `prolog-goal`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-apply (host-type metta._space list) (String))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Every space name this engine registers, sorted: '&self' and
> '&metta' from boot, every native space something created or wrote to,
> and every foreign space currently bound. (new-space) and (spawn ...)
> create, so their answers are here at once; naming a space never
> registers it, so Space('&kb') is not here until a write, and a bind!
> token's target appears once something is stored under it.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_space.py::test_space_names_lists_the_registered_spaces`.

## space:drop

```python
drop() -> None
```

Kind: `lifecycle`. Answer: `None`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_drop`, receiving `method`.

Engine binding: `metta_py_drop_space`, wire `prolog-goal`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `NoneType` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Clear this space and release an anonymous name for reuse.
>
> Dropping retires every space-owned catalog declaration, including
> algebra rows and their Python mirrors.
> Dropping unregisters a Python provider and closes only backing state
> owned by this handle. A foreign provider with a clear/drop lifecycle,
> such as MORK, releases its provider state.
> A named space's public name is not an anonymous allocation and never
> enters the anonymous pool. The engine-owned &self and &metta roots
> refuse before any Python-side state changes; drop the caller's own
> context or a named space instead.
> Subscriptions on the space cancel with it: a pooled name reused later
> must not deliver to the old life's watchers. The handle itself dies
> here, and dropping twice is a no-op, as closing twice is.
>
> Engine teardown must succeed before Python cleanup is discarded.
> If later cleanup fails, call drop() again to finish it. The handle
> refuses other operations in that state and retains its anonymous name
> until cleanup succeeds; retrying does not repeat engine teardown.

Evidence: `extensions/python/ext/metta-arrays/tests/test_arrays.py::test_dropping_the_space_retires_its_installation_row`, `extensions/python/tests/ch04_spaces_and_matching/test_algebra_lifecycle.py::test_drop_retires_algebra_before_redeclaration`, `extensions/python/tests/ch04_spaces_and_matching/test_drop_recovery.py::test_backing_close_failure_keeps_the_name_and_cleanup_retryable`.

## space:dropped

```python
dropped -> bool
```

Kind: `lifecycle`. Answer: `bool`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._space:Space._door_dropped`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `Bool` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Whether :meth:`drop` has released this handle's space.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_space_identity_doors_follow_the_handle_lifetime`.

## space:to-wire

```python
to_wire() -> list
```

Kind: `introspection`. Answer: `list`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._space:Space._door_to_wire`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-type metta._space list)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Encode the live engine reference as a portable space operand.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_space_identity_doors_follow_the_handle_lifetime`.

## space:metatype

```python
metatype -> str
```

Kind: `introspection`. Answer: `str`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._space:Space._door_metatype`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `String` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Read Space.metatype.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_space_identity_doors_follow_the_handle_lifetime`.

## space:bind

```python
bind(values: _abc.Mapping[str, Any] | None=None, /, **named: Any) -> _BoundValues
```

Kind: `scope`. Answer: `context`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_bind`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `values` | `(host-union ((host-apply (host-type metta._space _abc.Mapping) (String %Undefined%)) NoneType))` | `None` | `values` | `positional_only` |
| `named` | `%Undefined%` | `required` | `values` | `var_keyword` |

Guarantees result type `(host-type metta._space _BoundValues)` with the answer shape, effect, and determinism above.

Declared local refusals:

- `type`: `extensions/python/tests/repository/test_door_refusals.py::test_door_type_refusals[space:bind]`.
- `value`: `extensions/python/tests/repository/test_door_refusals.py::test_bind_refuses_the_reserved_template_namespace`.

Implementation failures propagate, including failures from callees and providers.

> Scope named host values for :meth:`run` without a call flag.

Evidence: `extensions/python/tests/ch03_atoms_and_expressions/test_atoms.py::test_bind_reaches_a_variable_hole_through_an_atom_key`, `extensions/python/tests/ch04_spaces_and_matching/test_space.py::test_bind_carries_identity_into_a_term`, `extensions/python/tests/ch04_spaces_and_matching/test_variadic_doors.py::test_eval_batches_with_one_bind_scope`.

## space:run

```python
run(source: str | TemplateLike, /, *, timeout: float | None=None, inferences: int | None=None, **values: Any) -> list[list[Atom]]
```

Kind: `evaluation`. Answer: `list`. Effect: `oracleIO`. Determinism: `nondet`.

Tiers: `sync`, `async`, `module`, `context`.

Implementation: `metta._space:Space._door_run`, receiving `method`.

Engine binding: `metta_py_run`, wire `prolog-goal`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `source` | `(host-union (String (host-type metta._space TemplateLike)))` | `required` | `values` | `positional_only` |
| `timeout` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `inferences` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `values` | `%Undefined%` | `required` | `values` | `var_keyword` |

Guarantees result type `(host-apply (host-type metta._space list) ((host-apply (host-type metta._space list) (Atom))))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Run MeTTa source: one list of answers per ! directive.
>
> The pipeline is the engine's own reader, compiler and evaluator, so
> the answers are exactly what the CLI would print, kept grouped per
> directive instead of flattened. Equations and facts in the source
> land in this space.
>
> The source may carry HOLES, which are bindings by position:
>
>     m.run(t"!(fib {n})")            # a 3.14 t-string literal
>     m.run("!(fib {n})", n=10)       # the same on every version
>
> Each hole is spliced into the text as a generated symbol and bound to
> its value, so a str stays one String atom and never has to be escaped.
> Values enter through `encode`: an int is a Number, a str a String, an
> Atom itself, a Space its handle. The markers at a hole are the atom
> constructors, `{Symbol(name)}`, `{Grounded(obj)}` and `{parse(text)}`,
> with the specs `:sym`, `:py` and `:expr` as their short forms; `!r`
> and `!s` convert in Python first and enter the result as text. A hole
> inside a string literal, a comment or a symbol is refused with its
> line and column.
>
> `bind()` is the same substitution by NAME, for a value several calls
> share, the way DuckDB reads a local dataframe by its variable name:
>
>     with m.bind({"graph": my_graph}):
>         m.run("!(py-len graph)")
>
> Each named symbol substitutes to its value (objects by identity),
> after reading, before anything runs. It is a BLOCK rather than a
> keyword because a binding mapping is the kind of value that grows,
> and a block grows down the page where a keyword has to fit beside
> everything else on the call. Every call that accepts a target reads the
> same scope, so one block covers run(), eval(), and answers() together.
> A binding names a symbol and so replaces EVERY occurrence of it,
> including one the author meant as a symbol; a hole is positional and
> cannot reach anything but itself.
>
> `timeout` (seconds) and `inferences` (engine steps) bound the call
> with the engine's own guards; passing either raises TimeLimitError
> or InferenceLimitError when the bound is hit, and whatever the
> source completed before the stop, writes included, stands.
>
> `with m.capture() as output` collects printed text in `output.text`
> without changing this method's return shape. `with m.atomic()`
> and `with m.speculative()` scope execution policy without boolean
> combinations on each call. Atomic commits or rolls
> back each complete source; speculative answers and discards its
> writes. Both cover engine state; Python side effects and subscription
> callbacks already fired stay where they happened.
>
> A term the engine hands back unevaluated is an ordinary MeTTa value,
> not a failure: `!(hello world)` answers `(hello world)` and that is
> the whole of hello world in this language. eval_status() reports
> which answers reduced and which did not, as data, for a caller who
> wants to decide about it.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_space.py::test_run_groups_answers_per_directive`.

## space:explain

```python
explain(query: Any, /, *, analyze: bool=False, allow_writes: bool=False, **values: Any) -> Explanation
```

Kind: `introspection`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_explain`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `query` | `%Undefined%` | `required` | `values` | `positional_only` |
| `analyze` | `Bool` | `False` | `values` | `keyword_only` |
| `allow_writes` | `Bool` | `False` | `values` | `keyword_only` |
| `values` | `%Undefined%` | `required` | `values` | `var_keyword` |

Guarantees result type `(host-type metta._space Explanation)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> What the engine will do with this query, reflected rather than run.
>
>     e = m.self.explain(
>         "(match &self (, (edge $x $y) (edge $y $z) (edge $z $x)) ($x $y $z))"
>     )
>     e.plan          # (plan generic-join (order ...) (relations ...))
>     e["writes"]     # (writes transactional)
>
> SQL's EXPLAIN, over this engine's own decisions. A match form answers
> which seam entry handles it and with what fidelity, whether a bound
> pushes into the provider, the source, the context world, the
> annotation semiring, emission, event delivery, writes, the error mode,
> the merge policy, whether the space's source relations are
> materialised, and the PLAN: `generic-join` with the variable order and
> each conjunct's columns, `nested-loop` with the conjunct the matcher
> leads with, or `empty-factor` with the conjunct that has no candidate.
> An operation call answers its effect, whether it has an inverse, its
> annotations, its error mode and the cache decision the memo made.
>
> The plan names the join the engine RUNS. Deciding that costs the
> query's shape and one scan of each conjunct's relation, because a
> conjunction whose stored rows are not all ground declines the Generic
> Join and must read `nested-loop`; nothing is sorted and no trie is
> built, so explaining a triangle over 2,048 stored edges cost 7,350
> engine inferences against the query's own 237,473, and the share falls
> as the data grows: 10.1%, 4.6% and 3.1% at 128, 512 and 2,048 rows
> .
>
> `analyze=True` is EXPLAIN ANALYZE: the same items plus `(inferences
> N)`, `(answers N)` and `(cputime S)` measured by running the query
> inside `stats()`. It REFUSES the query when the engine can NAME an
> operation in it that writes, because an analysis that mutates is not an
> analysis; `allow_writes=True` says to measure it anyway. A match
> TEMPLATE is evaluated once per answer, so `(match &s (edge $x $y)
> (add-atom &s (seen $x)))` is a writing query.
>
> The longhand is the MeTTa form: `m.run("!(explain <query>)")` answers
> the same atoms, and `analyze=True` is that run with a `stats()` block
> around `eval()` of the same query. A form that is neither a match nor
> an operation call keeps the engine's own `type_error(explainable, ...)`.

Evidence: `extensions/python/tests/ch14_seeing_your_program/test_explain_plan.py::test_a_rows_with_no_query_behind_it_refuses_to_explain`, `extensions/python/tests/ch14_seeing_your_program/test_explain_plan.py::test_an_explanation_is_a_mapping_over_its_item_heads`, `extensions/python/tests/ch14_seeing_your_program/test_explain_plan.py::test_an_explanation_is_data_a_space_stores_and_matches_back`.

## space:profile

```python
profile(source: str | TemplateLike, /, *, timeout: float | None=None, inferences: int | None=None, **values: Any) -> tuple[list[list[Atom]], EngineProfile]
```

Kind: `introspection`. Answer: `tuple`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_profile`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `source` | `(host-union (String (host-type metta._space TemplateLike)))` | `required` | `values` | `positional_only` |
| `timeout` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `inferences` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `values` | `%Undefined%` | `required` | `values` | `var_keyword` |

Guarantees result type `(host-apply (host-type metta._space tuple) ((host-apply (host-type metta._space list) ((host-apply (host-type metta._space list) (Atom)))) (host-type metta._space EngineProfile)))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Run source under the engine's statistical profiler, answering
> (groups, profile): the groups exactly as run() answers them, and
> the profile carrying sample counters plus one row per predicate,
> self-ticks first.
>
>     groups, prof = m.profile("!(big-computation)")
>     prof.top(5)     # the five predicates the samples landed in
>
> A row carries the predicate's calls and redos, its ticks, the file
> and line its clauses were defined at, and its share of the sampled
> seconds. `prof.as_stats()` answers the same run as a `pstats.Stats`,
> so `sort_stats("cumulative").print_stats()` reads it and
> `dump_stats(path)` writes what snakeviz and tuna open.
>
> The sampler is statistical: a program that finishes in
> milliseconds carries few samples, so profile something that runs.
> Profiling changes execution; it is a debugging surface, not a
> mode to leave on.

Evidence: `extensions/python/tests/ch14_seeing_your_program/test_features.py::test_a_profile_exports_as_pstats`, `extensions/python/tests/ch14_seeing_your_program/test_features.py::test_a_profile_is_the_same_table_every_other_door_answers`, `extensions/python/tests/ch14_seeing_your_program/test_features.py::test_profile_counts_samples_on_real_work`.

## space:profile-extension

```python
profile_extension(source: str | TemplateLike, /, *, extension: str | None=None, names: _abc.Sequence[str] | None=None, timeout: float | None=None, inferences: int | None=None, **values: Any) -> tuple[list[list[Atom]], list[FunctionCost]]
```

Kind: `introspection`. Answer: `tuple`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_profile_extension`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `source` | `(host-union (String (host-type metta._space TemplateLike)))` | `required` | `values` | `positional_only` |
| `extension` | `(host-union (String NoneType))` | `None` | `values` | `keyword_only` |
| `names` | `(host-union ((host-apply (host-type metta._space _abc.Sequence) (String)) NoneType))` | `None` | `values` | `keyword_only` |
| `timeout` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `inferences` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `values` | `%Undefined%` | `required` | `values` | `var_keyword` |

Guarantees result type `(host-apply (host-type metta._space tuple) ((host-apply (host-type metta._space list) ((host-apply (host-type metta._space list) (Atom)))) (host-apply (host-type metta._space list) ((host-type metta._space FunctionCost)))))` with the answer shape, effect, and determinism above.

Declared local refusals:

- `value`: `extensions/python/tests/repository/test_door_refusals.py::test_door_value_refusals[space:profile-extension]`.

Implementation failures propagate, including failures from callees and providers.

> Run source under the profiler, reporting only YOUR functions.
>
> `profile()` answers "which predicate did the samples land in", over
> every predicate in the process. The question a library author has is
> narrower: of the functions my library registered, which one is
> costing me, and is anything wrong with how it was installed.
>
>     groups, costs = m.profile_extension("!(my-workload)",
>                                         extension="mylib")
>     for cost in costs:
>         print(cost)
>     # <mylib-join/3 prolog: 40100 calls, 39900 redos, 812 ticks, index 1x>
>
> Name the `extension` and its registered members are looked up, or
> pass `names` for an explicit list. Each row carries the tier that
> installed the function and where from, its exact call and redo
> counts, the sampler's ticks, and its clause index.
>
> The two columns worth reading first are `redos` and `speedup`. Redos
> on a function meant to be deterministic are a leftover choice point,
> which costs the caller about twice and is invisible to the inference
> counter. A `speedup` of 1 means no argument discriminates, so every
> call walks the clause list; `indexed` False on a function nothing has
> called much only means SWI has not built one yet.
>
> The sampler is statistical, so profile something that runs, and
> profiling changes execution: this is a debugging surface.

Evidence: `extensions/python/tests/ch14_seeing_your_program/test_features.py::test_profile_extension_needs_exactly_one_of_extension_or_names`, `extensions/python/tests/ch14_seeing_your_program/test_features.py::test_profile_extension_reports_every_declared_member`, `extensions/python/tests/ch14_seeing_your_program/test_features.py::test_profile_extension_separates_an_indexed_table_from_a_single_clause`.

## space:save

```python
save(path: str | os.PathLike[str], *, format: SaveFormat=SaveFormat.metta, timeout: float | None=None, inferences: int | None=None) -> int
```

Kind: `introspection`. Answer: `int`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`.

Declared option vocabularies:

- `format`: `metta`, `fast`.

Implementation: `metta._space:Space._door_save`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `path` | `(host-union (String (host-apply (host-type metta._space os.PathLike) (String))))` | `required` | `values` | `positional_or_keyword` |
| `format` | `(host-type metta._space SaveFormat)` | `SaveFormat.metta` | `values` | `keyword_only` |
| `timeout` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `inferences` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |

Guarantees result type `Number` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Write every stored atom of this space, equations included, as
> MeTTa source by default. ``format="fast"`` writes a version-pinned
> image of the receiver's equation world: its own atoms, owned child
> spaces, aliases bound to those spaces, and translator rules. Loading
> the image mints fresh runtime space identities and preserves their
> graph relationships. The returned count remains the receiver's own
> atom count. Text variables are numbered by first occurrence within
> each atom, so saving unchanged content twice is byte-stable. A path
> ending .gz writes gzip compressed in either format, and load and
> import! read it back under the same name. The completed sibling file
> is synced and then atomically replaces the target, so a failed save
> leaves the old file intact. Atoms carrying live host objects cannot
> survive either file and are refused.
>
> `timeout` (seconds) and `inferences` (engine steps) bound the save with
> the engine's own guards, exactly as they bound load(). A text save
> examines the receiver; a fast save also traverses its reachable
> equation-world graph and registries. Those guards therefore bound all
> state the chosen format writes, and the atomic replace above makes a
> stopped save safe: the sibling is never moved into place.
>
> There is no `format` on load(), and that is not an omission. When you
> save, the file does not exist and something has to say which of the two
> to write; when you load, load() reads which it is, `.gz` included.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_digest.py::test_a_specialized_program_saves_and_digests`, `extensions/python/tests/ch04_spaces_and_matching/test_digest.py::test_save_keeps_every_number_it_accepts`, `extensions/python/tests/ch04_spaces_and_matching/test_digest.py::test_save_keeps_every_symbol_it_accepts`.

## space:source

```python
source() -> str
```

Kind: `introspection`. Answer: `str`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_source`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `String` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Return this space's directly stored atoms as loadable MeTTa text.
>
> This is exactly the text that ``save(path, format="metta")`` writes:
> one atom per line, including equations, with a final newline when the
> space is nonempty. Variables are numbered by first occurrence within
> each atom, making independent views of unchanged content byte-stable.
> Inherited prelude and library atoms, the global
> ``&metta`` catalog, and child spaces are outside that save boundary.
> Live host objects and atoms whose printed form cannot round-trip are
> refused for the same reason a text save refuses them.

Evidence: `extensions/python/tests/ch18_performance/test_fast_bindings.py::test_fast_images_preserve_each_equations_binding`.

## space:load

```python
load(path: str | os.PathLike[str], *, timeout: float | None=None, inferences: int | None=None) -> list[list[Atom]]
```

Kind: `introspection`. Answer: `list`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`, `module`, `context`.

Implementation: `metta._space:Space._door_load`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `path` | `(host-union (String (host-apply (host-type metta._space os.PathLike) (String))))` | `required` | `values` | `positional_or_keyword` |
| `timeout` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `inferences` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |

Guarantees result type `(host-apply (host-type metta._space list) ((host-apply (host-type metta._space list) (Atom))))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Add a text program or trusted fast cache to this space.
>
> This is a consult, so it always loads and what it loads REPLACES
> what the same file put in this space before. Edit the file, load it
> again, and the space holds the new definitions and not both; the
> engine says on stderr which file it replaced and how many atoms
> went. Atoms from other sources, and ones you added yourself, stay.
> A load that raises leaves the previous definitions standing, so a
> broken edit costs nothing but the error.
>
> `!(import! &self path)` is the other form and loads a file that is
> new or edited, skipping one that is neither. The two agree on what
> a reload means and differ only in whether an unchanged file runs
> again, which is SWI's consult/1 against its if(changed).
>
> A .gz path is detected and read through the decompressed bytes.
>
> `timeout` (seconds) and `inferences` (engine steps) bound the load
> with the engine's own guards, raising TimeLimitError or
> InferenceLimitError. A load is all or nothing: a stop takes back
> everything the file had put in a space, the same way a load that
> fails on a bad form does, because a file the space holds half of is
> not a file it can replace later. run() is the entry point that
> keeps finished work when a bound stops it. This is the one most
> likely to be handed code the caller did not write, since a file can
> carry `!` directives and an import graph, so it takes the same pair
> its siblings take.
>
> Program text with holes is refused here. A hole is a binding, and a
> PATH has nowhere to bind one: run() takes holes, and an f-string or a
> Path builds a computed filename.

Evidence: `extensions/python/tests/ch01_getting_started/test_lock.py::test_a_lock_refuses_while_a_load_is_in_flight`, `extensions/python/tests/ch04_spaces_and_matching/test_digest.py::test_a_second_load_of_a_specialized_program_still_round_trips`, `extensions/python/tests/ch04_spaces_and_matching/test_space.py::test_load_adds_to_existing_space`.

## space:parse

```python
parse(source: str | TemplateLike, /, **values: Any) -> Atom
```

Kind: `introspection`. Answer: `Atom`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_parse`, receiving `method`.

Engine binding: `metta_py_parse`, wire `prolog-goal`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `source` | `(host-union (String (host-type metta._space TemplateLike)))` | `required` | `values` | `positional_only` |
| `values` | `%Undefined%` | `required` | `values` | `var_keyword` |

Guarantees result type `Atom` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Read one form into an atom without evaluating it.
>
> Holes work here as they do at run(), and land in the term this
> answers rather than crossing to the engine, since nothing runs:
> `m.parse(t"(person {name} 36)")` is the built term with the value
> already in it.

Evidence: `extensions/python/tests/ch03_atoms_and_expressions/test_reader_tokens.py::test_a_registered_token_class_parses_like_a_shipped_one`, `extensions/python/tests/ch03_atoms_and_expressions/test_reader_tokens.py::test_a_token_constructor_failure_is_a_reader_error_not_a_symbol_fallback`.

## space:register-token

```python
register_token(pattern: str | _re.Pattern[str], constructor: Callable[[str], Any]) -> None
```

Kind: `provider`. Answer: `None`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_register_token`, receiving `method`.

Engine binding: `metta_py_register_token`, wire `prolog-goal`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `pattern` | `(host-union (String (host-apply (host-type metta._space _re.Pattern) (String))))` | `required` | `values` | `positional_or_keyword` |
| `constructor` | `(host-apply (host-type metta._space Callable) ((String) %Undefined%))` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `NoneType` with the answer shape, effect, and determinism above.

Declared local refusals:

- `type`: `extensions/python/tests/repository/test_door_refusals.py::test_door_type_refusals[space:register-token]`.

Implementation failures propagate, including failures from callees and providers.

> Register a full-token regex and its Atom constructor.
>
> The constructor receives the complete matched lexeme. It may return an
> Atom or any value accepted by :func:`metta.ground`. A later registration
> of the same pattern replaces the constructor. Only future parses read
> the new mapping; atoms already returned are immutable values.

Evidence: `extensions/python/tests/ch03_atoms_and_expressions/test_reader_tokens.py::test_a_registered_token_class_parses_like_a_shipped_one`, `extensions/python/tests/ch03_atoms_and_expressions/test_reader_tokens.py::test_compiled_reader_patterns_preserve_flags_and_unregister`, `extensions/python/tests/ch03_atoms_and_expressions/test_reader_tokens.py::test_a_token_constructor_failure_is_a_reader_error_not_a_symbol_fallback`.

## space:unregister-token

```python
unregister_token(pattern: str | _re.Pattern[str]) -> None
```

Kind: `provider`. Answer: `None`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_unregister_token`, receiving `method`.

Engine binding: `metta_py_unregister_token`, wire `prolog-goal`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `pattern` | `(host-union (String (host-apply (host-type metta._space _re.Pattern) (String))))` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `NoneType` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Remove a reader-token class; an absent pattern is already removed.

Evidence: `extensions/python/tests/ch03_atoms_and_expressions/test_reader_tokens.py::test_compiled_reader_patterns_preserve_flags_and_unregister`, `extensions/python/tests/ch03_atoms_and_expressions/test_reader_tokens.py::test_a_registered_token_class_parses_like_a_shipped_one`, `extensions/python/tests/ch03_atoms_and_expressions/test_reader_tokens.py::test_a_token_constructor_failure_is_a_reader_error_not_a_symbol_fallback`.

## space:add

```python
add(*atoms: Any) -> None
```

Kind: `write`. Answer: `None`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`, `module`, `context`.

Implementation: `metta._space:Space._door_add`, receiving `method`.

Engine binding: `metta_py_add_many`, wire `prolog-goal`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `atoms` | `%Undefined%` | `required` | `values` | `var_positional` |

Guarantees result type `NoneType` with the answer shape, effect, and determinism above.

Declared local refusals:

- `type`: `extensions/python/tests/repository/test_door_refusals.py::test_door_type_refusals[space:add]`.

Implementation failures propagate, including failures from callees and providers.

> Add atoms to this space, one engine round-trip for the lot.
> An (= ...) atom compiles as an equation. Every Atom shape crosses
> unchanged, including a bare Symbol, Grounded value, and empty
> Expression; a free Variable receives the engine's own
> insufficient-instantiation refusal. The MeTTa longhand is
> `!(add-atoms <space> (<atom> ...))`. It is NOT `add-atom`, which is
> upstream PeTTa's spelling and takes upstream's domain: a headless atom
> cannot become a fact in a space there, so `!(add-atom &self b)` has no
> answer on either engine. This space is wider and `add-atoms` is the
> door onto the wider part.
>
> A variable's NAME is not stored. `(rule $x $y)` reads back as
> `(rule $_17902 $_17904)`, because a variable is an identity and not a
> spelling. That is the right property for a logic engine and it is the
> one thing about storage that surprises everybody once.
>
> A library IS knowledge, so the same operator imports it: ``m += lib.he``
> performs ``!(import! <m> (library lib_he))`` with this space as the
> target. An import is an effect, so it refuses to hide inside an atom
> batch or share a call with stored atoms.

Evidence: `extensions/python/ext/metta-arrays/tests/test_arrays.py::test_embedding_store_validates_added_vectors`, `extensions/python/tests/ch04_spaces_and_matching/test_r2_space_handle.py::test_add_atom_accepts_a_computed_space_handle`, `extensions/python/tests/ch04_spaces_and_matching/test_space.py::test_add_query_atoms`.

## space:remove

```python
remove(atom: Any, *more: Any) -> bool | int
```

Kind: `write`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`, `module`, `context`.

Implementation: `metta._space:Space._door_remove`, receiving `method`.

Engine binding: `metta_py_remove_many`, wire `prolog-goal`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `atom` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |
| `more` | `%Undefined%` | `required` | `values` | `var_positional` |

Guarantees result type `(host-union (Bool Number))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Remove ONE unifying occurrence and say whether one was there,
> which is Python's own `list.remove` grain.
>
> Variadic like `add` and `transfer`: several atoms ride one engine
> crossing inside one transaction, and the answer counts the found,
> so the one-atom call still reads as the truth value it always
> was.
>
> `space -= atom` is this same grain without the report, the way
> `+=` is `add` without one: Python's in-place difference over a
> MULTISET, whose own Python spelling is `collections.Counter`,
> subtracts the multiplicity given rather than clearing the key.
> That is the only reading under which the operators are inverses,
> so `s += a; s -= a` leaves the space it found. `-=` classifies its
> operand exactly as `+=` does, so `-=` subtracts the same fact stream
> `+=` stores, one occurrence per element, in one
> transactional crossing.
>
> `del m[pattern]` is the draining form: it takes every
> unifying occurrence in one crossing and raises when nothing
> matched, as Python's `del` does, and MeTTa spells it `remove-atom`
> .
> MeTTa spells this method's grain `subtract-atom`. This is the one
> method that reports absence.
>
> A bare variable is the remove-everything reading a multiset space
> gives it, each atom leaving through its own proper path, equations
> and their compiled clauses included.

Evidence: `extensions/python/tests/ch03_atoms_and_expressions/test_structures.py::test_matchindex_routes_and_removes`, `extensions/python/tests/ch04_spaces_and_matching/test_space.py::test_atoms_count_contains_remove_clear`, `extensions/python/tests/ch04_spaces_and_matching/test_space.py::test_delitem_removes_every_unifying_occurrence`.

## space:transfer

```python
transfer(*atoms: Any, to: Space) -> int
```

Kind: `write`. Answer: `int`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_transfer`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `atoms` | `%Undefined%` | `required` | `values` | `var_positional` |
| `to` | `SpaceType` | `required` | `atoms` | `keyword_only` |

Guarantees result type `Number` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Move ONE unifying occurrence of each atom into another space.
>
> Variadic and atomic: however many atoms ride the call, one engine
> transaction moves them in one crossing, so a mid-move failure
> rolls every side back and nothing is lost between the spaces. The
> answer counts the moved; an absent atom moves nothing and counts
> nothing, which is ``remove``'s own found-reporting grain, so the
> one-atom call still reads as a truth value. The longhand stays
> reachable: a :meth:`transaction` around ``remove`` and ``add``
> says the same thing one atom at a time. :meth:`take` is the
> WAITING kin for a pattern.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_variadic_doors.py::test_transfer_moves_a_batch_atomically`.

## space:atoms

```python
atoms() -> list[Atom]
```

Kind: `introspection`. Answer: `list`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_atoms`, receiving `method`.

Engine binding: `metta_py_atoms`, wire `prolog-goal`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-apply (host-type metta._space list) (Atom))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Every stored atom in this space.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_generated_space_protocols_preserve_storage_and_identity`.

## space:peek

```python
peek(pattern: Any, *, where: Any | None=None, deadline: float | None=None) -> Atom
```

Kind: `query`. Answer: `Atom`. Effect: `oracleIO`. Determinism: `nondet`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_peek`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `pattern` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |
| `where` | `(host-union (%Undefined% NoneType))` | `None` | `values` | `keyword_only` |
| `deadline` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |

Guarantees result type `Atom` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Wait for one matching atom and leave it in this space.
>
> A finite deadline raises ``Timeout`` when no match arrives.
>
> `where` is match()'s guard on a blocking wait: a term over the
> pattern's variables, evaluated once a candidate binds them and
> required true, so "wait for a job whose priority is above five" is one
> call. Without it the guard had to live in the caller, as a wait and a
> re-wait around every candidate the guard rejected, and the deadline
> restarted each time round.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_r2_space_handle.py::test_space_handle_peek_and_take_are_linda_verbs`, `extensions/python/tests/ch11_python_as_a_notation/test_library_fixes.py::test_peek_does_not_import_linda_into_the_waited_space`, `extensions/python/tests/ch11_python_as_a_notation/test_r5_unbuilt_doors.py::test_take_peek_and_watch_retire_the_thread_linda_fn_strings`.

## space:take

```python
take(pattern: Any, *, where: Any | None=None, deadline: float | None=None) -> Atom
```

Kind: `write`. Answer: `Atom`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_take`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `pattern` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |
| `where` | `(host-union (%Undefined% NoneType))` | `None` | `values` | `keyword_only` |
| `deadline` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |

Guarantees result type `Atom` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Wait for and remove exactly one matching atom from this space.
>
> Competing takers cannot receive the same occurrence. A finite
> deadline raises ``TimeoutError`` when no match arrives. `where` is
> peek()'s guard, and it is checked BEFORE the removal, so an atom the
> guard rejects stays where it is for whoever does want it.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_r2_space_handle.py::test_space_handle_peek_and_take_are_linda_verbs`, `extensions/python/tests/ch04_spaces_and_matching/test_r2_space_handle.py::test_the_linda_verbs_take_matchs_guard`, `extensions/python/tests/ch11_python_as_a_notation/test_r5_unbuilt_doors.py::test_take_peek_and_watch_retire_the_thread_linda_fn_strings`.

## space:cast

```python
@overload
cast(type_: _builtins.type[_CastT], /) -> _CastT
@overload
cast(type_: Atom | str, /) -> Any
@overload
cast(value: Any, type_: _builtins.type[_CastT], /) -> _CastT
@overload
cast(value: Any, type_: Atom | str, /) -> Any
cast(value: Any, type_: Any=..., /) -> Any
```

Kind: `introspection`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_cast`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `value` | `%Undefined%` | `required` | `values` | `positional_only` |
| `type_` | `%Undefined%` | `...` | `values` | `positional_only` |

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Cast this space atom ambiently with one argument, or answer value
> narrowed by this space's type discipline with two arguments. The
> explicit form has the same acceptance a typed call compiles, ':'
> declarations here and &self in scope, protocol types included. A
> refusal raises metta.CastError naming the value's actual types.

Evidence: `extensions/python/tests/ch01_getting_started/test_api_types.py::test_cast_target_is_positional_only`, `extensions/python/tests/ch09_types/test_casting.py::test_arrow_typed_expressions_cast_structurally`, `extensions/python/tests/ch09_types/test_casting.py::test_atom_cast_delegates_to_the_ambient_space`.

## space:trace

```python
trace(source: Atom | str, max_events: int | None=None, *, filter: Symbol | str | Iterable[Symbol | str] | None=None, timeout: float | None=None, inferences: int | None=None) -> Trace
```

Kind: `scope`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`, `module`, `context`.

Implementation: `metta._space:Space._door_trace`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `source` | `(host-union (Atom String))` | `required` | `values` | `positional_or_keyword` |
| `max_events` | `(host-union (Number NoneType))` | `None` | `values` | `positional_or_keyword` |
| `filter` | `(host-union ((host-union ((host-union (Symbol String)) (host-apply (host-type metta._space Iterable) ((host-union (Symbol String)))))) NoneType))` | `None` | `values` | `keyword_only` |
| `timeout` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `inferences` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |

Guarantees result type `(host-type metta._space Trace)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Run a TERM, or source, under the engine's reduction trace and
> answer TraceEvent records: what entered reduction at which depth,
> what it answered, and which reductions failed (a call with no
> exit). `m.trace(S.fib(10))` is the ordinary spelling, the same
> argument `answers` and `eval` take; a string is still a string.
> What is traced executes for real, writes included, like run();
> the wrap exists only while tracing, so untraced calls pay
> nothing and the wrapping itself is not charged to the bounds
> below. max_events bounds the RECORDING and timeout,
> inferences and stack bound the RUN, defaulting to whatever
> `m.limits()` scopes; they are independent because a program can
> retire millions of inferences inside a handful of recorded
> events. Whichever one stops it, the events already recorded are
> ANSWERED and `stopped` names the bound, so a caller told a trace
> was cut knows which bound to raise.
> filter selects exact function Symbols or names, singly or in an iterable.
> None records all functions; [] records none. Selection happens before
> the recording bounds, while excluded calls still execute and add depth.

Evidence: `extensions/python/ext/metta-otel/tests/test_otel.py::test_a_reduction_a_bound_cut_ends_with_the_trace`, `extensions/python/ext/metta-otel/tests/test_otel.py::test_a_trace_becomes_one_span_per_reduction`, `extensions/python/ext/metta-otel/tests/test_otel.py::test_a_trace_inside_an_observed_block_refuses`.

## space:debug

```python
debug(source: Atom | str, *, on: Any=None, inferences: int | None=None, at: int | None=None) -> Debugger
```

Kind: `scope`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`, `module`, `context`.

Implementation: `metta._space:Space._door_debug`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `source` | `(host-union (Atom String))` | `required` | `values` | `positional_or_keyword` |
| `on` | `%Undefined%` | `None` | `values` | `keyword_only` |
| `inferences` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `at` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |

Guarantees result type `(host-type metta._space Debugger)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Run a TERM, or source, under breakpoints, stepped from Python.
>
> Iterating the Debugger runs the program to each breakpoint, the loop
> body is where the program is SUSPENDED, and leaving the body resumes
> that same execution:
>
>     with m.debug(S.quad(3), on=[S.double]) as d:
>         for stop in d:
>             print(stop)      # halted here
>             if stop.depth > 2:
>                 d.step()     # stop at the next reduction instead
>         print(d.answers)
>
> on= names the functions that stop it, the way every door here names a
> head; naming none runs the program to the end in one advance.
> `step()` stops at the very next reduction, breakpoint or not, and
> lasts one advance. `breakpoints` is a live set, so one added while
> the program is suspended stops it.
>
> at= is the third kind of breakpoint, a COUNT: it stops at the event
> with that sequence number, numbering reductions from 0 the way a
> Recording numbers them, so `at=200` is "put me where event 200 is".
> `Recording.debug(at=k)` is the convenience over this one.
>
> inferences bound the WHOLE session cumulatively, so a resume that
> would never reach another breakpoint stops. There is no timeout:
> the session is suspended by design and a clock would run while a
> person reads a stop. What is debugged executes for real, writes
> included, and inherits the caller's scope. Close it, or leave its
> with-block: the session holds a wrapper on every compiled function
> until it does.

Evidence: `extensions/python/ext/metta-otel/tests/test_otel.py::test_observing_inside_a_debug_session_refuses`, `extensions/python/tests/ch14_seeing_your_program/test_debug.py::test_a_breakpoint_inside_a_host_operation_refuses_with_its_remedy`, `extensions/python/tests/ch14_seeing_your_program/test_debug.py::test_a_breakpoint_suspends_the_program_and_resuming_carries_it_on`.

## space:record

```python
record(source: Atom | str, *, seed: int | None=None, max_events: int | None=None, timeout: float | None=None, inferences: int | None=None) -> Recording
```

Kind: `scope`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`, `module`, `context`.

Implementation: `metta._space:Space._door_record`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `source` | `(host-union (Atom String))` | `required` | `values` | `positional_or_keyword` |
| `seed` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `max_events` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `timeout` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `inferences` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |

Guarantees result type `(host-type metta._space Recording)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Run a TERM, or source, and keep the whole run as data.
>
> The data walks backwards, saves to a file, and re-runs.
> `m.trace` is the rung below: it answers the events alone. A Recording
> is those events plus the state that produced them, which is what makes
> them re-runnable rather than only readable:
>
>     rec = m.record(S.fib(12))
>     rec.save("fib.metta-rec.json")
>     rec.at(-1)               # the last event, with its call stack
>     rec.back()               # a step backwards costs a lookup
>     rec.replay(other)        # the same run, in another engine
>     with rec.debug(at=17) as d:   # live, stopped where event 17 is
>         print(d.stop)
>
> A recorded run always has a seed, minted when you do not name one,
> because a replay that cannot reproduce the draws is not a replay; the
> generator is restored afterwards. `(with-seed S expr)` is the MeTTa
> spelling of the same scope.
>
> max_events bounds the RECORDING and timeout and inferences bound the
> RUN, exactly as on trace(); a cut recording says so through
> `rec.events.stopped` and replays to the same length. A program whose
> effect plan reaches oracleIO is recorded with `replayable` false and
> the reason naming what it reached, and replay() then refuses rather
> than re-reading the host.

Evidence: `extensions/python/tests/ch14_seeing_your_program/test_recording.py::test_a_cut_recording_says_so_and_replays_to_the_same_length`, `extensions/python/tests/ch14_seeing_your_program/test_recording.py::test_a_file_that_is_not_a_recording_refuses_by_name`, `extensions/python/tests/ch14_seeing_your_program/test_recording.py::test_a_frame_outside_the_recording_refuses`.

## space:lint

```python
lint() -> list[Finding]
```

Kind: `introspection`. Answer: `list`. Effect: `readOnlyLookup`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_lint`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-apply (host-type metta._space list) ((host-type metta._space Finding)))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Diagnose this space for the silently-wrong class: declared
> types nothing defines, arity mismatches, unbound body variables,
> duplicate equations, and references no function or fact carries.
> Answers metta.lint.Finding records, empty when nothing looks
> wrong.

Evidence: `extensions/python/tests/ch14_seeing_your_program/test_lint.py::test_a_canonicalised_read_of_a_tabled_function_is_not_a_finding`, `extensions/python/tests/ch14_seeing_your_program/test_lint.py::test_a_declaration_for_a_name_with_no_equations_is_data`, `extensions/python/tests/ch14_seeing_your_program/test_lint.py::test_a_declaration_that_cannot_type_its_function`.

## space:effect-plan

```python
effect_plan(target: Any) -> _ops_module.EffectPlan
```

Kind: `introspection`. Answer: `value`. Effect: `readOnlyLookup`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_effect_plan`, receiving `method`.

Engine binding: `metta_py_world_effect_plan`, wire `prolog-goal`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `target` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `(host-type metta._space _ops_module.EffectPlan)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Return operations the target may execute and their joined effect.
>
> The engine translates the same atom or source form ``eval`` accepts,
> follows nested compiled calls, and reads current operation metadata.
> It does not execute the target. A later registration change is visible
> on the next call. This is the analysis reified-world admission uses.

Evidence: `extensions/python/tests/ch11_python_as_a_notation/test_effect_plan.py::test_async_effect_plan_retains_the_sync_contract`, `extensions/python/tests/ch11_python_as_a_notation/test_effect_plan.py::test_effect_plan_reads_replaced_operation_classification`, `extensions/python/tests/ch11_python_as_a_notation/test_effect_plan.py::test_effect_plan_reports_nested_calls_without_executing_them`.

## space:copy

```python
copy() -> Space
```

Kind: `lifecycle`. Answer: `space`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_copy`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `SpaceType` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> This space's contents in a new anonymous space, cloned through
> one bulk write, so equations copy as equations and keep running:
> "a scratch space set up like production" is one line. The handle
> is ``space()``'s kind, so drop it, or use it as a context
> manager, to return the name. copy.copy(m) answers the same
> through the copy protocol. There is deliberately no __deepcopy__:
> stored Python objects keep their identity across the clone, the
> shallow reading, and a deep clone of a live engine handle has no
> meaning to promise.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_space.py::test_a_copy_reproduces_the_space_it_copied`.

## space:reify

```python
reify()
```

Kind: `lifecycle`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_reify`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Capture this space as an immutable, independently evaluable world.

Evidence: `extensions/python/tests/ch15_writing_transactions_and_worlds/test_worlds.py::test_reify_refuses_an_effectful_captured_compilation_before_replay`, `extensions/python/tests/ch15_writing_transactions_and_worlds/test_worlds.py::test_reify_refuses_and_names_a_live_composite_member`, `extensions/python/tests/ch11_python_as_a_notation/test_arrow_products.py::test_world_coverage_uses_the_annotated_effect`.

## space:commit

```python
commit(world: Any) -> None
```

Kind: `write`. Answer: `None`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_commit`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `world` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `NoneType` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Apply one reified world's diff through this originating space.

Evidence: `extensions/python/tests/ch15_writing_transactions_and_worlds/test_worlds.py::test_a_journaled_world_commit_replays_its_ordinary_diff`, `extensions/python/tests/ch15_writing_transactions_and_worlds/test_worlds.py::test_commit_applies_the_world_diff_as_post_commit_events`, `extensions/python/tests/ch15_writing_transactions_and_worlds/test_worlds.py::test_world_commit_preserves_multiplicity_and_refuses_stale_or_wrong_origins`.

## space:digest

```python
digest() -> str
```

Kind: `introspection`. Answer: `str`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_digest`, receiving `method`.

Engine binding: `metta_py_digest`, wire `prolog-goal`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `String` with the answer shape, effect, and determinism above.

Declared local refusals:

- `engine`: `extensions/python/tests/repository/test_door_refusals.py::test_digest_refuses_an_invalid_engine_reply`.
- `value`: `extensions/python/tests/repository/test_door_refusals.py::test_digest_refuses_live_host_identity`.

Implementation failures propagate, including failures from callees and providers.

> A sha256 hex digest of this space's content: every stored atom,
> equations included, canonicalized (variables numbered, multiset
> sorted) so the same atoms answer the same digest in any insertion
> order and in any process. Two spaces agree on digest() exactly
> when save() would write the same content. Live host objects have
> no cross-process identity and are refused, like save().

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_digest.py::test_a_second_load_of_a_specialized_program_still_round_trips`, `extensions/python/tests/ch04_spaces_and_matching/test_digest.py::test_a_specialized_program_saves_and_digests`, `extensions/python/tests/ch04_spaces_and_matching/test_digest.py::test_digest_counts_duplicates`.

## space:__len__

```python
__len__() -> int
```

Kind: `introspection`. Answer: `int`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `context`.

Implementation: `metta._space:Space._door___len__`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `Number` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Read Space.__len__.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_generated_space_protocols_preserve_storage_and_identity`.

## space:__bool__

```python
__bool__() -> bool
```

Kind: `introspection`. Answer: `bool`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`, `context`.

Implementation: `metta._space:Space._door___bool__`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `Bool` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Always true: a space is a handle to a store, not a value that
> dwindles. Without this, bool() falls through to __len__ and an
> empty space is falsy, so `if space:` skips a perfectly good empty
> space, the bug class that made datetime stop treating midnight as
> false in 3.5. Existence is an ask: use
> ``bool(space.match(V.x))`` rather than ``bool(space)``.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_space_identity_doors_follow_the_handle_lifetime`.

## space:__contains__

```python
__contains__(atom: Any) -> bool
```

Kind: `introspection`. Answer: `bool`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `context`.

Implementation: `metta._space:Space._door___contains__`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `atom` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `Bool` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Read Space.__contains__.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_generated_space_protocols_preserve_storage_and_identity`.

## space:clear

```python
clear() -> None
```

Kind: `write`. Answer: `None`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_clear`, receiving `method`.

Engine binding: `metta_py_clear`, wire `prolog-goal`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `NoneType` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Remove everything stored here, compiled equations included.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_space.py::test_atoms_count_contains_remove_clear`, `extensions/python/tests/ch04_spaces_and_matching/test_space.py::test_clear_removes_equations_too`, `extensions/python/tests/ch05_equations_and_evaluation/test_reload.py::test_a_cleared_space_forgets_what_a_file_put_in_it`.

## space:__iadd__

```python
__iadd__(atom: Any) -> Self
```

Kind: `write`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `context`.

Implementation: `metta._space:Space._door___iadd__`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `atom` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `(host-type metta._space Self)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> add()'s operator spelling for one atom or one fact stream.
>
> ``m += (S.Edge, a, b)`` adds one fact. ``m += [(S.Edge, a, b),
> (S.Edge, b, c)]`` and a generator yielding those rows add two. A built
> Expression is always one atom even though it implements Sequence.
> Dataframes use ``iter_rows`` or ``itertuples(index=False)``. The
> explicit ``add(list_value)`` method remains available when a list itself
> is intended as one transparent expression.
>
> Relative ``S.admits(Type)``, ``S.capacity(n)``, and
> ``S.covers(effect)`` values are declared data: they install the same
> contract as the receiver methods and are not stored in this space.
> Explicit ``add(...)`` remains the raw storage method for those shapes.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_generated_space_protocols_preserve_storage_and_identity`.

## space:__isub__

```python
__isub__(atom: Any) -> Self
```

Kind: `write`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `context`.

Implementation: `metta._space:Space._door___isub__`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `atom` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `(host-type metta._space Self)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Read Space.__isub__.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_generated_space_protocols_preserve_storage_and_identity`.

## space:__ior__

```python
__ior__(other: Any) -> Self
```

Kind: `write`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `context`.

Implementation: `metta._space:Space._door___ior__`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `other` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `(host-type metta._space Self)` with the answer shape, effect, and determinism above.

Declared local refusals:

- `type`: `extensions/python/tests/repository/test_door_refusals.py::test_door_type_refusals[space:__ior__]`.

Implementation failures propagate, including failures from callees and providers.

> Merge into this space in one bulk crossing: every atom of
> another space, of a registered space name, or of an iterable.
>
>     m |= other_space     # every atom, equations included
>     m |= "&kb"           # the space registered under this name
>     m |= [a, b, c]       # each element becomes one atom
>
> Equations in the merge compile on arrival, the same rule add()
> enforces. A space is a multiset, so merging a space into itself
> doubles every atom. A Mapping is refused because add(d) reads the
> same dict as ONE grounded atom and its values would silently
> vanish here; spell the reading you mean. Strings name spaces, so
> an unregistered name is a KeyError rather than a parse.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_generated_space_protocols_preserve_storage_and_identity`.

## space:__iter__

```python
__iter__()
```

Kind: `introspection`. Answer: `stream`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `context`.

Implementation: `metta._space:Space._door___iter__`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Iterate one assembly-order snapshot of the stored atoms.
>
> A native or inherited-native space materializes its readable chain
> when ``iter(space)`` is called, so later additions and removals do not
> alter that iterator. A Python-backed space likewise materializes its
> provider's ``atoms()`` result before returning the iterator; the
> provider owns and must document how concurrent mutation behaves while
> that one enumeration itself is being produced.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_space_container_protocol.py::test_native_iteration_snapshots_before_mutation`.

## space:__getitem__

```python
__getitem__(i: Any) -> Rows
```

Kind: `introspection`. Answer: `Rows`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `context`.

Implementation: `metta._space:Space._door___getitem__`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `i` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `(host-type metta._space Rows)` with the answer shape, effect, and determinism above.

Declared local refusals:

- `type`: `extensions/python/tests/repository/test_door_refusals.py::test_door_type_refusals[space:__getitem__]`.

Implementation failures propagate, including failures from callees and providers.

> Subscription is query. A tuple headed by an atom is one built
> expression pattern; a tuple of complete expression patterns is a join:
>
>     m[(S.Parent, V.x, S.Bob)]
>     m[S.edge(V.a, V.b), S.edge(V.b, V.c)]
>
> Python hands both spellings to ``__getitem__`` as a tuple, so shape is
> the visible classifier. A mixed tuple beginning with a complete
> pattern and followed by a bare atom can only be the tuple mistake; it
> raises and names the one-pattern and join spellings instead of
> silently asking an impossible bare-atom conjunct.
>
> A str key parses first, matching match()'s tolerance. A slice is
> refused: a slice of a space has no one meaning, and the bounded
> readings have their own methods, match(limit=) for a bounded answer
> set and stream() for rows pulled until you have seen enough.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_generated_space_protocols_preserve_storage_and_identity`.

## space:__delitem__

```python
__delitem__(pattern: Any) -> None
```

Kind: `write`. Answer: `None`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `context`.

Implementation: `metta._space:Space._door___delitem__`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `pattern` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `NoneType` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Del m[pattern] removes every unifying occurrence, the bulk
> spelling of remove()'s multiset subtraction: m[pattern] is a
> query answering many rows, so deleting it deletes them all, the
> way DELETE WHERE does. Nothing unifying raises KeyError, as
> del d[k] does on a missing key; remove() is the method that
> reports absence as False instead.
>
> It asks the engine's own drain, so the whole pattern costs ONE
> crossing rather than one per removed atom.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_generated_space_protocols_preserve_storage_and_identity`.

## space:match

```python
match(*patterns: Any, where: Any | None=None, limit: int | None=None, timeout: float | None=None, inferences: int | None=None, under: Any=_UNSET, into: _builtins.type | None=None, **values: Any) -> Any
```

Kind: `query`. Answer: `value`. Effect: `oracleIO`. Determinism: `nondet`.

Tiers: `sync`, `async`, `module`, `context`.

Implementation: `metta._space:Space._door_match`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `patterns` | `%Undefined%` | `required` | `values` | `var_positional` |
| `where` | `(host-union (%Undefined% NoneType))` | `None` | `values` | `keyword_only` |
| `limit` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `timeout` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `inferences` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `under` | `%Undefined%` | `_UNSET` | `values` | `keyword_only` |
| `into` | `(host-union ((host-type metta._space _builtins.type) NoneType))` | `None` | `values` | `keyword_only` |
| `values` | `%Undefined%` | `required` | `values` | `var_keyword` |

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Lazily match patterns against this space as one conjunction.
>
> Variables shared between patterns join, the engine's own match/4
> doing the joining. Columns are the variable names in first
> appearance order. `where` is a guard term over the same variables,
> evaluated per join and required true, so restrictions a pattern
> cannot spell (an inequality) compose onto the match:
>
>     m.match(S.person(V.name, V.age), where=V.age.ge(18))
>
> `limit` bounds the answers, the engine stopping at the count
> rather than trimming afterwards. `timeout` (seconds) and
> `inferences` (engine steps) bound the whole call, raising
> TimeLimitError or InferenceLimitError when hit, for joins whose
> size is not known in advance.
>
> The returned Answers view pulls only what Python observes. ``bool``
> pulls one row, exact-one operations pull at most two, and slicing
> retains an Answers view. ``len`` uses an engine-side aggregate when
> no row has yet been pulled.
>
> ``under=`` interprets the same ask through an annotation algebra.
> ``under=counting`` answers one ``TaggedAnswer`` whose annotation is
> the engine-computed count, including duplicate derivations without
> crossing their rows into Python. Ordered carriers sort in their
> declared direction before slicing, so
> ``m.match(q, under=ranked)[:3]`` is top-k and
> ``under=tropical`` puts the cheapest annotation first. Other carriers
> answer ``TaggedAnswer`` values with ``annotation``, ``why()`` and
> ``under(other)``; the latter two reuse the retained derivation rather
> than querying the space again. ``with metta.under(carrier)`` supplies
> the carrier when this call has no explicit ``under=``.
>
> `into=Rows` explicitly chooses the eager Rows face. Other `into=`
> values shape each row into a dataclass, NamedTuple, or
> TypedDict matched by field name, sqlite3's row_factory reading:
> `m.match(S.edge(V.a, V.b), into=Edge)` answers `list[Edge]`,
> and Rows stays the default so nothing is lost. A one-variable query
> whose column holds complete constructor expressions rebuilds those
> expressions instead: `m.match(V.edge, into=Edge)`.
>
>     m.match(S.Edge(V.x, V.y), S.Edge(V.y, V.z))
>
> A text pattern may carry HOLES, as run()'s source may:
> `m.match(t"(person {name} $age)")` matches the value itself, so a name
> holding a space stays one String atom rather than reading as two
> symbols. Keyword values apply across every pattern of the call.

Evidence: `extensions/python/tests/ch03_atoms_and_expressions/test_identity_wire.py::test_store_and_match_preserve_python_object_identity`, `extensions/python/tests/ch04_spaces_and_matching/test_algebra_lifecycle.py::test_drop_retires_algebra_before_redeclaration`, `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_a_recorded_session_replays_verbatim`.

## space:stream

```python
stream(*patterns: Any, where: Any | None=None, limit: int | None=None, timeout: float | None=None, inferences: int | None=None, under: Any=_UNSET) -> Cursor
```

Kind: `query`. Answer: `stream`. Effect: `oracleIO`. Determinism: `nondet`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_stream`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `patterns` | `%Undefined%` | `required` | `values` | `var_positional` |
| `where` | `(host-union (%Undefined% NoneType))` | `None` | `values` | `keyword_only` |
| `limit` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `timeout` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `inferences` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `under` | `%Undefined%` | `_UNSET` | `values` | `keyword_only` |

Guarantees result type `(host-type metta._space Cursor)` with the answer shape, effect, and determinism above.

Declared local refusals:

- `type`: `extensions/python/tests/repository/test_door_refusals.py::test_door_type_refusals[space:stream]`.

Implementation failures propagate, including failures from callees and providers.

> match(), pulled: the same conjunction and guard, answered one
> row at a time through a cursor the engine holds open.
>
>     with m.stream(S.edge(V.a, V.b), S.edge(V.b, V.c)) as rows:
>         for row in rows:
>             if wanted(row):
>                 break            # nothing further is even joined
>
> The join's state lives inside an SWI engine between pulls, each
> pull is one ordinary call, and unrelated calls interleave freely,
> so a huge join costs one row of work per row actually taken where
> match() computes and decodes every answer up front. `timeout`
> bounds each pull's wall time; `inferences` is one budget for the
> cursor's whole engine work, spent across pulls, and the cursor
> stops on the answer that passes it. Because the budget counts the
> cursor's own engine, it is not the number ``stats()`` reports for
> the same work: ``stats()`` reads the calling thread's counters,
> which see the pull loop rather than the engine. The cursor
> enumerates under the engine's logical update view: writes made
> after the first pull are not seen by this cursor.
>
> `limit` and `under` mean what they mean on match(), because this is
> match() and the cursor underneath already carried both: a tagging
> algebra (ranked, tropical, prov) answers one TaggedAnswer per pull,
> the same value match() answers. `under='counting'` is refused by
> name, because a counting fold is ONE aggregate over the whole answer
> set and a cursor exists not to have one.
>
> What this method does NOT take is match()'s `into=`, the same kind of
> difference: `into` builds a container out of every row.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_space.py::test_wide_query_projection_is_identical_through_every_answer_door`, `extensions/python/tests/ch04_spaces_and_matching/test_space.py::test_nonpositive_limits_are_refused_by_match_stream_and_prepared`.

## space:assuming

```python
assuming(*facts: Any) -> _Assuming
```

Kind: `scope`. Answer: `context`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_assuming`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `facts` | `%Undefined%` | `required` | `values` | `var_positional` |

Guarantees result type `(host-type metta._space _Assuming)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Facts held only inside a with-block: the assumptions reading of
> a what-if query, added on entry, removed on exit, exceptions
> included.
>
>     with m.assuming(S.closed(S.bridge)):
>         detour = m.match(S.route(V.r), where=...)

Evidence: `extensions/python/tests/ch11_python_as_a_notation/test_adoptions.py::test_assuming_groups_multiple_cleanup_failures_after_removing_all`, `extensions/python/tests/ch11_python_as_a_notation/test_adoptions.py::test_assuming_removes_every_fact_after_one_cleanup_fails`, `extensions/python/tests/ch11_python_as_a_notation/test_adoptions.py::test_assuming_scopes_facts`.

## space:transaction

```python
@overload
transaction(target: Callable[[], _R], /) -> _R
@overload
transaction(target: Atom | str, /) -> list[Atom | Undefined]
transaction(target: Callable[[], _R] | Any, /) -> Any
```

Kind: `scope`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_transaction`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `target` | `(host-union ((host-apply (host-type metta._space Callable) (() (host-type metta._space _R))) %Undefined%))` | `required` | `values` | `positional_only` |

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Declared local refusals:

- `engine`: `extensions/python/tests/repository/test_door_refusals.py::test_transaction_refuses_an_unreported_engine_failure`.

Implementation failures propagate, including failures from callees and providers.

> Run one callable or term inside a closed engine transaction.
>
> The two inputs preserve their native failure laws. A zero-argument
> Python callable commits its return value and rolls back on a Python
> exception. A term returns its engine answers and rolls back when that
> answer set is empty, exactly like ``(transaction ...)``.
>
>     m.transaction(lambda: migrate(m))
>     m.transaction(S.progn(write, verify))
>
> Every engine write the callable makes, stored atoms, equations
> and their compiled clauses included, commits or rolls back
> together. An exception is the callable's rollback trigger, because a
> Python callable cannot fail the Prolog way, and it re-raises AS
> ITSELF: your ValueError arrives as ValueError with the engine
> boundary in its chain. Only the engine's dynamic state rolls
> back; what the callable did on the Python side (a list appended,
> a file written) is yours to undo, SWI transactions being
> database-scoped.
>
> Transactions nest, SWI's own semantics: an inner commit is
> relative to its outer transaction, so an outer rollback discards
> inner work too.
>
> There is deliberately no `with m.transaction():` form. SWI's
> transaction/1 takes a closed goal; there is no open begin/commit
> to hold across a block, and pretending otherwise would lie about
> the isolation actually provided. transactional() is the
> decorator twin.

Evidence: `extensions/python/tests/ch11_python_as_a_notation/test_ladder.py::test_batch_composes_with_transaction`, `extensions/python/tests/ch11_python_as_a_notation/test_r5_unbuilt_doors.py::test_transaction_term_uses_empty_answer_rollback_law`, `extensions/python/tests/ch15_writing_transactions_and_worlds/test_saga.py::test_saga_refuses_transaction_speculation_and_batch_boundaries`.

## space:saga

```python
saga(receipts: Space)
```

Kind: `scope`. Answer: `context`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_saga`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `receipts` | `SpaceType` | `required` | `atoms` | `positional_or_keyword` |

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Declared local refusals:

- `type`: `extensions/python/tests/repository/test_door_refusals.py::test_door_type_refusals[space:saga]`.

Implementation failures propagate, including failures from callees and providers.

> Open a committed-receipt saga over this execution space.
>
> ``receipts`` is an ordinary space that stores ``(did op args result)``
> atoms. Run each forward term with the returned context manager's
> ``run`` method. A normal exit keeps its work and receipts; an
> exceptional exit invokes declared compensations in reverse commit
> order and removes each successfully recovered receipt.
>
>     with orders.saga(receipts) as saga:
>         saga.run(S.charge(S.order_7))
>
> Operations ranked writesState or oracleIO leave receipts. Declare a
> handler with ``compensates`` before recovery. Handlers receive the
> complete receipt, written at the call site as ``(quote <receipt>)`` so
> it is not evaluated on the way in, and must be idempotent, because a
> failed compensation remains queryable and is retried by
> ``rollback()``.

Evidence: `extensions/python/tests/ch15_writing_transactions_and_worlds/test_saga.py::test_a_discarded_step_runs_no_compensation`, `extensions/python/tests/ch15_writing_transactions_and_worlds/test_saga.py::test_a_failed_compensation_can_be_retried_without_losing_its_receipt`, `extensions/python/tests/ch15_writing_transactions_and_worlds/test_saga.py::test_a_lost_participant_leaves_the_saga_in_doubt_rather_than_compensating`.

## space:solve

```python
solve(pattern: Any, subject: Any) -> Any
```

Kind: `evaluation`. Answer: `value`. Effect: `oracleIO`. Determinism: `nondet`.

Tiers: `sync`, `async`, `module`, `context`.

Implementation: `metta._space:Space._door_solve`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `pattern` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |
| `subject` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Declared local refusals:

- `value`: `extensions/python/tests/repository/test_door_refusals.py::test_door_value_refusals[space:solve]`.

Implementation failures propagate, including failures from callees and providers.

> Run relational ``let`` and return bindings keyed by its variables.
>
> ``solve(4, V.x - 1).x`` places the known value on let's pattern side,
> lets the arithmetic relation solve backwards, and projects ``x``.
> The answer template is derived from the pattern's variables followed
> by any new subject variables, so either relational direction can
> introduce the bindings and the third hand-written ``let`` argument
> disappears.

Evidence: `extensions/python/tests/ch11_python_as_a_notation/test_library_fixes.py::test_solve_projects_variables_from_the_winning_pattern`, `extensions/python/tests/ch11_python_as_a_notation/test_r5_unbuilt_doors.py::test_set_is_the_unique_image_of_solve_answers`, `extensions/python/tests/ch11_python_as_a_notation/test_r5_unbuilt_doors.py::test_solve_refuses_an_anonymous_only_subject`.

## space:watch

```python
watch(pattern: Any, *, on: SubscriptionEdge=SubscriptionEdge.add, where: Any | None=None, deadline: float | None=None, queue_max: int | None=None)
```

Kind: `scope`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`.

Declared option vocabularies:

- `on`: `add`, `remove`, `both`.

Implementation: `metta._space:Space._door_watch`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `pattern` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |
| `on` | `(host-type metta._space SubscriptionEdge)` | `SubscriptionEdge.add` | `values` | `keyword_only` |
| `where` | `(host-union (%Undefined% NoneType))` | `None` | `values` | `keyword_only` |
| `deadline` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `queue_max` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Yield matching changes, raising Timeout after each quiet deadline.
>
> `queue_max` bounds the subscription underneath, the same bound
> subscribe() takes; a watch could not name it before, though the
> subscription it builds always had one.

Evidence: `extensions/python/tests/ch11_python_as_a_notation/test_r5_unbuilt_doors.py::test_take_peek_and_watch_retire_the_thread_linda_fn_strings`, `extensions/python/tests/ch11_python_as_a_notation/test_r5_unbuilt_doors.py::test_watch_close_before_first_event_cancels_its_eager_subscription`, `extensions/python/tests/ch16_events_and_standing_queries/test_events.py::test_an_abandoned_watch_cancels_itself`.

## space:limits

```python
limits(*, timeout: float | None=None, inferences: int | None=None, stack: int | None=None) -> ScopedLimits
```

Kind: `scope`. Answer: `context`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`, `module`, `context`.

Implementation: `metta._space:Space._door_limits`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `timeout` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `inferences` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `stack` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |

Guarantees result type `(host-type metta._space ScopedLimits)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Scoped default bounds for every call in the with-block:
>
>     with m.limits(inferences=1_000_000, timeout=2.0):
>         m.match(...)      # bounded without saying so again
>
> decimal.localcontext's shape, contextvars underneath, so the
> scope is async-correct and per-task. A per-call timeout= or
> inferences= still overrides, which is the whole ladder: one
> block replaces the parameter forest, and the forest remains
> for whoever wants per-call control.
>
> stack= is SWI's combined stack ceiling in BYTES, the bound a
> runaway recursion hits as a StackOverflow error atom. It is NOT
> MeTTa's reduction depth: that is the max-stack-depth pragma,
> `(with-pragma! ((max-stack-depth N)) expr)`, which counts
> reduction steps and is scoped in the program text.

Evidence: `extensions/python/tests/ch11_python_as_a_notation/test_ladder.py::test_scoped_limits_apply_and_per_call_overrides`, `extensions/python/tests/ch11_python_as_a_notation/test_ladder.py::test_scoped_limits_validate_at_the_block`, `extensions/python/tests/ch17_concurrency_and_the_loop/test_aio.py::test_aio_scoped_limits_cross_to_the_worker`.

## space:capture

```python
capture() -> CapturedOutput
```

Kind: `scope`. Answer: `context`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_capture`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-type metta._space CapturedOutput)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Collect printed engine text without changing answer shapes.
>
> with m.capture() as output:
>     groups = m.run("!(println! hello) !(+ 1 2)")
> assert groups == [[3]]
> assert output.text == "hello\n"

Evidence: `extensions/python/tests/ch14_seeing_your_program/test_features.py::test_capture_composes_with_limits`, `extensions/python/tests/ch14_seeing_your_program/test_features.py::test_eval_capture`, `extensions/python/tests/ch14_seeing_your_program/test_features.py::test_lazy_capture_collects_held_engine_output`.

## space:atomic

```python
atomic() -> ScopedExecution
```

Kind: `scope`. Answer: `context`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_atomic`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-type metta._space ScopedExecution)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Make each CALL in the block one committing engine transaction.
>
> Per call, the write doors included: ``m.add(a, b)`` inside the block
> is one transaction, so a provider that refuses the second atom takes
> the first back with it. Across SEVERAL calls the boundary is
> :meth:`transaction`, because SWI's transaction/1 takes a closed goal
> and an engine cannot yield out of one, so no with-block can hold one
> open; a raise later in the block does not undo a call that already
> committed.

Evidence: `extensions/python/tests/ch14_seeing_your_program/test_features.py::test_an_atomic_scope_makes_one_python_write_one_transaction`, `extensions/python/tests/ch14_seeing_your_program/test_features.py::test_atomic_run_commits_or_rolls_back_whole`, `extensions/python/tests/ch14_seeing_your_program/test_features.py::test_lazy_atomic_rolls_back_after_a_late_cursor_failure`.

## space:speculative

```python
speculative() -> ScopedExecution
```

Kind: `scope`. Answer: `context`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`, `module`, `context`.

Implementation: `metta._space:Space._door_speculative`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-type metta._space ScopedExecution)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Run each CALL against a snapshot and discard its writes.
>
> Per call, the write doors included: ``m.add(atom)`` inside the block
> leaves nothing behind, exactly as ``m.run("!(add-atom &self ...)")``
> in the same block does, and a later call in the block does not see
> what an earlier one wrote, because each call is its own what-if.

Evidence: `extensions/python/tests/ch08_data/test_state_cell.py::test_speculative_state_write_is_fenced`, `extensions/python/tests/ch14_seeing_your_program/test_features.py::test_every_public_execution_door_honours_speculative_policy`, `extensions/python/tests/ch14_seeing_your_program/test_features.py::test_speculative_lazy_execution_preserves_every_answer`.

## space:batch

```python
batch() -> _Batch
```

Kind: `scope`. Answer: `context`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_batch`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-type metta._space _Batch)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Collect this space's add() calls and cross once at exit:
>
>     with m.batch():
>         for edge in edges:
>             m.add(edge)          # collected, no crossing yet
>     # one add_many crossing happened here
>
> The write forms are add for one or several atoms, batch for a region,
> transaction for all-or-nothing work, and a provider's bulk method
> underneath them. A batch is a transport economy and must not invent
> semantics, so the sharp edges are stated and enforced: reads
> inside the block see the space WITHOUT the pending adds; a
> remove() or clear() on this space inside the block refuses,
> because it would otherwise silently order around writes the
> program already made; and an exception discards the pending
> batch rather than landing writes the code after the raise never
> saw. Compose with transaction() for atomicity: batch for
> economy, transaction for all-or-nothing, or both.

Evidence: `extensions/python/tests/ch11_python_as_a_notation/test_ladder.py::test_batch_composes_with_transaction`, `extensions/python/tests/ch11_python_as_a_notation/test_ladder.py::test_batch_crosses_once_and_reads_see_the_pre_batch_space`, `extensions/python/tests/ch11_python_as_a_notation/test_ladder.py::test_batch_edges_are_enforced`.

## space:transactional

```python
transactional(fn: Callable[_P, _R], /) -> Callable[_P, _R]
```

Kind: `scope`. Answer: `callable`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._space:Space._door_transactional`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `fn` | `(host-apply (host-type metta._space Callable) ((host-type metta._space _P) (host-type metta._space _R)))` | `required` | `values` | `positional_only` |

Guarantees result type `(host-apply (host-type metta._space Callable) ((host-type metta._space _P) (host-type metta._space _R)))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> transaction()'s decorator twin, the atomic shape Django made
> familiar: each CALL of the wrapped function runs inside its own
> engine transaction. Decorating runs nothing, exactly as a
> decorator should not; reach for transaction() to run one
> callable now.
>
>     @m.transactional
>     def migrate():
>         m.add(...)
>         m.remove(...)
>
>     migrate()     # one transaction; a raise rolls it all back

Evidence: `extensions/python/tests/ch15_writing_transactions_and_worlds/test_transaction.py::test_transactional_is_the_decorator_twin`.

## space:prepare

```python
prepare(*patterns: Any, where: Any | None=None) -> Prepared
```

Kind: `query`. Answer: `value`. Effect: `readOnlyLookup`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_prepare`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `patterns` | `%Undefined%` | `required` | `values` | `var_positional` |
| `where` | `(host-union (%Undefined% NoneType))` | `None` | `values` | `keyword_only` |

Guarantees result type `(host-type metta._space Prepared)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> A query whose shape is fixed and whose facts are not: the wire
> form and columns build once, and each solve() may bring per-call
> facts (given=) that leave nothing behind.
>
>     route = m.prepare(S.path(V.a, V.b), where=V.a != ...)
>     route.solve()
>     route.solve(given=[S.edge(S.x, S.y)])

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_space.py::test_nonpositive_limits_are_refused_by_match_stream_and_prepared`, `extensions/python/tests/ch11_python_as_a_notation/test_adoptions.py::test_prepared_query_with_given`, `extensions/python/tests/ch14_seeing_your_program/test_features.py::test_limits_on_query_eval_value_and_prepared`.

## space:eval

```python
@overload
eval(target: Any, /, *more: Any, timeout: float | None=None, inferences: int | None=None, under: Any=_UNSET, theory: Any | None=None, interpreter: Any | None=None, answer: EvaluationAnswer | str='all', delivery: ArgumentDelivery | str, limit: int | None=None, image: ImageMode | str | None=None, on_error: OnError | str='keep', determinism: Determinism | str='nondet', **values: Any) -> Any
@overload
eval(target: Any, /, *more: Any, timeout: float | None=None, inferences: int | None=None, under: Any=_UNSET, theory: Any | None=None, interpreter: Any | None=None, answer: EvaluationAnswer | str, delivery: ArgumentDelivery | str='atoms', limit: int | None=None, image: ImageMode | str | None=None, on_error: OnError | str='keep', determinism: Determinism | str='nondet', **values: Any) -> Any
@overload
eval(target: Any, /, *, timeout: float | None=..., inferences: int | None=..., under: Any=..., theory: Any | None=..., interpreter: Any | None=..., **values: Any) -> list[Atom | Undefined]
@overload
eval(target: Any, _second: Any, /, *more: Any, timeout: float | None=..., inferences: int | None=..., under: Any=..., theory: Any | None=..., interpreter: Any | None=..., **values: Any) -> list[list[Atom | Undefined]]
eval(target: Any, /, *more: Any, timeout: float | None=None, inferences: int | None=None, under: Any=_UNSET, theory: Any | None=None, interpreter: Any | None=None, answer: EvaluationAnswer | str='all', delivery: ArgumentDelivery | str='atoms', limit: int | None=None, image: ImageMode | str | None=None, on_error: OnError | str='keep', determinism: Determinism | str='nondet', **values: Any) -> Any
```

Kind: `evaluation`. Answer: `value`. Effect: `oracleIO`. Determinism: `nondet`.

Tiers: `sync`, `async`, `module`, `context`.

Declared option vocabularies:

- `answer`: `all`, `answers`, `rows`, `atom`, `one`, `first`, `count`, `exists`, `none`, `stream`.
- `delivery`: `atoms`, `values`.
- `image`: `opaque`, `transparent`, `auto`.
- `on_error`: `keep`, `empty`, `abort`.
- `determinism`: `det`, `semidet`, `nondet`.

Implementation: `metta._space:Space._door_eval`, receiving `method`.

Engine binding: `metta_py_eval_all`, wire `prolog-goal`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `target` | `%Undefined%` | `required` | `values` | `positional_only` |
| `more` | `%Undefined%` | `required` | `values` | `var_positional` |
| `timeout` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `inferences` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `under` | `%Undefined%` | `_UNSET` | `values` | `keyword_only` |
| `theory` | `(host-union (%Undefined% NoneType))` | `None` | `values` | `keyword_only` |
| `interpreter` | `(host-union (%Undefined% NoneType))` | `None` | `values` | `keyword_only` |
| `answer` | `(host-union ((host-type metta._space EvaluationAnswer) String))` | `'all'` | `values` | `keyword_only` |
| `delivery` | `(host-union ((host-type metta._space ArgumentDelivery) String))` | `'atoms'` | `values` | `keyword_only` |
| `limit` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `image` | `(host-union ((host-union ((host-type metta._space ImageMode) String)) NoneType))` | `None` | `values` | `keyword_only` |
| `on_error` | `(host-union ((host-type metta._space OnError) String))` | `'keep'` | `values` | `keyword_only` |
| `determinism` | `(host-union ((host-type metta._space Determinism) String))` | `'nondet'` | `values` | `keyword_only` |
| `values` | `%Undefined%` | `required` | `values` | `var_keyword` |

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Declared local refusals:

- `assertion`: `extensions/python/tests/ch05_equations_and_evaluation/test_evaluation_options.py::test_evaluation_options_check_cardinality_before_truncation`.
- `inference_limit`: `extensions/python/tests/ch05_equations_and_evaluation/test_evaluation_options.py::test_evaluation_options_preserve_bounds_and_capture`.
- `value`: `extensions/python/tests/ch05_equations_and_evaluation/test_evaluation_options.py::test_evaluation_options_refuse_invalid_values`.

Implementation failures propagate, including failures from callees and providers.

> Evaluate a term, returning every answer.
>
> This is what !(...) runs, minus the printing: the engine's
> translate_expr over the term, then its goals. Nondeterminism means
> the list can hold any number of answers, including none.
>
> Variadic, and that is how evaluation BATCHES: several terms ride
> one engine crossing and the answer is one group per term in call
> order, run()'s own grouping carried to the term form. One term
> keeps its flat list, so the scalar reading never changes shape.
>
> Every answer carries its truth: an answer that is undefined under
> Well Founded Semantics (a tabled loop through tnot, reachable via
> translatePredicate or injected Prolog) arrives as an Undefined
> holding the answer and the delay condition that makes it
> undefined, never as an ordinary-looking value. A term to which no
> rule applies is the ordinary answer itself; `eval_status()` names
> that path `not-reducible`. run() does not carry the third truth
> value; evaluate through eval() when it matters.
>
> A text target may carry HOLES, exactly as run()'s source may:
> `m.eval(t"(decide {tensor})")` and `m.eval("(decide {x})", x=tensor)`
> hand the object itself to the rule, by identity. One call's holes are
> numbered together, so a batch and a nested template cannot collide.
>
> `bind()` binds named host values into the term before it evaluates,
> exactly as it does for run(): inside `with m.bind({"x": tensor})`,
> `m.eval("(decide x)")` hands the tensor itself to the rule, by
> identity, rather than a printed form of it. The name is the SYMBOL x
> and not the variable $x, in this call and the source form alike. The
> evaluation calls take the same vocabulary as the source form, so using
> a term instead of source text costs no change of spelling.
>
> A key may be a NAME or an ATOM. A name means the symbol of that name,
> which is what the engine's own substitution matches and what run()
> takes. An atom means exactly that atom, so `bind({V.x: 5})` fills a
> VARIABLE hole -- the one substitution `unify` reports and the one no
> evaluation call could apply, because a variable crosses the wire as ['v', 'x']
> where a symbol crosses as ['s', 'x'] and the engine matches names.
>
> `timeout` (seconds) and `inferences` (engine steps) bound the call,
> raising TimeLimitError or InferenceLimitError when hit. A surrounding
> `capture()` scope collects printed text without changing the list.
>
> `under`, `theory` and `interpreter` are answers()' three, and mean
> exactly what they mean there; `eval()` materialises that query as a list. A
> surrounding `with metta.under(carrier)` reaches here too, which it did
> not before: match() and answers() both honoured such a scope while
> eval() ignored it in silence.
>
> The answer, delivery, limit, image, on_error and determinism options
> select one evaluation contract. answer=answers retains a replayable
> cursor; answer=stream returns a closable single-pass stream. count,
> exists and none consume only the requested shape. A determinism
> promise is checked before a limit truncates the answers. Image
> projection publishes the type declarations its values require.

Evidence: `extensions/python/tests/ch05_equations_and_evaluation/test_evaluation_options.py::test_evaluation_options_preserve_the_eager_kernel`, `extensions/python/tests/ch05_equations_and_evaluation/test_evaluation_options.py::test_evaluation_options_compose_without_losing_answers`.

## space:answers

```python
answers(target: Any, /, *, timeout: float | None=None, inferences: int | None=None, under: Any=_UNSET, theory: Any | None=None, interpreter: Any | None=None, **values: Any) -> Answers[Any]
```

Kind: `evaluation`. Answer: `Answers`. Effect: `oracleIO`. Determinism: `nondet`.

Tiers: `sync`.

Longhand: `space:eval(..., answer='answers')`.

Implementation: `metta._space:Space._door_answers`, receiving `method`.

Engine binding: `metta_py_eval_cursor`, wire `prolog-goal`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `target` | `%Undefined%` | `required` | `values` | `positional_only` |
| `timeout` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `inferences` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `under` | `%Undefined%` | `_UNSET` | `values` | `keyword_only` |
| `theory` | `(host-union (%Undefined% NoneType))` | `None` | `values` | `keyword_only` |
| `interpreter` | `(host-union (%Undefined% NoneType))` | `None` | `values` | `keyword_only` |
| `values` | `%Undefined%` | `required` | `values` | `var_keyword` |

Guarantees result type `(host-apply (host-type metta._space Answers) (%Undefined%))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Evaluate lazily as an immutable, cached and replayable view.
>
> Creating the view performs no engine work. Existence pulls at most
> one answer, ``one()`` at most two, and ordinary iteration resumes the
> same held evaluation.
>
> ``under=`` has the same carrier semantics as ``match``. In
> particular, ``space.answers(call, under=counting).one()`` returns one
> ``TaggedAnswer`` whose annotation counts the call's answer
> derivations inside the engine, and ordered carriers
> order their annotated ``TaggedAnswer`` values before a slice pulls
> its prefix. A surrounding ``metta.under(carrier)`` is used only when
> this call does not pass an explicit carrier.
>
> ``theory=`` treats an atom or iterable of atoms as the theory value for
> this ask. That value replaces the receiver's own equational program.
> Engine builtins and the shared ``&self`` session space remain in scope
> exactly as they are for every space, and names the theory defines
> shadow inherited ones. It installs the theory in an isolated scratch
> space on the first pull, evaluates there, and drops the space when the
> view is exhausted or abandoned. The receiver is unchanged. This
> mirrors reflective descent functions whose inputs are a reified module
> and term.
>
> ``interpreter=`` instead evaluates the explicit full-interpreter
> application ``(interpreter target %Undefined% space)`` for this ask,
> which is the shape MeTTa's own evaluation function has: it says
> "reduce with YOURS rather than the engine's".
>
> The two COMPOSE, and are the head and the third argument of one
> application rather than rival answers to one question: with both, the
> interpreter is handed the theory's space, so it interprets the theory
> . They used to refuse together.
>
> The INTERPRETER must declare its first parameter `Atom`, MeTTa's own
> way to receive an argument unevaluated, or the engine reduces the
> target before the interpreter ever sees it; and its RETURN metatype
> `%Undefined%`, or the interpreter's own answer is not reduced either.
> `(: e (-> Atom Atom Atom %Undefined%))` is the declaration.
>
> A text target may carry HOLES, as run()'s source may:
> `m.answers(t"(near {point})")`. A theory, an interpreter or a carrier
> makes this view ask through another door, so the holes are read into
> the term itself there rather than sent as pairs a hand-off would drop.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_answers_scalar_doors_raise_error_atoms_but_iteration_retains_them`, `extensions/python/tests/ch04_spaces_and_matching/test_arrow_doors.py::test_term_answers_refuse_the_arrow_doors`, `extensions/python/tests/ch04_spaces_and_matching/test_results.py::test_term_answers_never_render_as_a_binding_table`.

## space:parallel

```python
parallel(*targets: Any, timeout: float | None=None) -> list[Atom | Undefined]
```

Kind: `evaluation`. Answer: `list`. Effect: `oracleIO`. Determinism: `nondet`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_parallel`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `targets` | `%Undefined%` | `required` | `values` | `var_positional` |
| `timeout` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |

Guarantees result type `(host-apply (host-type metta._space list) ((host-union (Atom (host-type metta._space Undefined)))))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Evaluate every target concurrently, answering every branch's answers.
>
> This is the engine's `hyperpose`, the parallel twin of `superpose`:
> one SWI thread per branch through concurrent_and/2, so independent
> branches cost about one branch's wall clock rather than their sum.
>
>     m.run("(= (sq $x) (* $x $x))")
>     m.parallel(S.sq(1), S.sq(2), S.sq(3))    # 1, 4 and 9, in any order
>
> This is the **in-engine** fan-out: one janus call, the branches split
> below it. The other route is `pool()`, the **Python-side** fan-out
> across several engines. Reach for this one when the fan-out is a MeTTa
> expression, and for `pool()` when it is a Python loop. They compose,
> so a pool worker may itself evaluate a `parallel()`.
>
> (Before 2026-08-15 this docstring said in-engine fan-out was the only
> route to a second core, because every janus call took one process-wide
> lock. That lock is now per-engine, and Python threads holding their own
> engine measured 1.94x, 3.90x and 7.26x at 2, 4 and 8 threads.)
>
> **Answers arrive in completion order, not argument order**, because
> the branches race. Compare sets rather than sequences, and evaluate a
> `superpose` instead when order carries meaning.
>
> Each target is a term or its source text, as everywhere else. No
> targets answers nothing without calling the engine.
>
> `timeout` bounds the call and is the bound to use here. There is
> deliberately no `inferences=`: the engine's inference limit counts
> the calling thread, and `concurrent_and/2` runs every branch in a
> worker, so a limit of 50,000 does not stop two branches spending six
> million. An unenforceable bound is worse than
> an absent one, so eval() over a `superpose` is the way to bound this
> work by inferences, at the cost of running it on one core.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_hyperpose_is_parallel_under_the_languages_name`, `extensions/python/tests/ch14_seeing_your_program/test_engine_pool.py::test_pool_composes_with_in_engine_parallel`, `extensions/python/tests/ch17_concurrency_and_the_loop/test_parallel.py::test_parallel_accepts_text_and_atoms`.

## space:pool

```python
pool(workers: int | None=None) -> Any
```

Kind: `provider`. Answer: `value`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._space:Space._door_pool`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `workers` | `(host-union (Number NoneType))` | `None` | `values` | `positional_or_keyword` |

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> A pool of worker threads that each hold their own Prolog engine.
>
> The Python-side twin of `parallel()`. Each worker attaches its own
> engine, so the process lock that serialises the home engine does not
> apply to it and the calls genuinely run at once.
>
>     m.run("(= (sq $x) (* $x $x))")
>     with m.pool(workers=4) as p:
>         list(p.map(lambda n: m.eval(S.sq(n))[0], range(64)))
>
> Use it as a context manager so every engine is released. `workers`
> defaults to os.cpu_count(). This handle stays usable from the workers:
> a MeTTa is a space name over the process runtime, not thread-owned.
>
> Reach for `parallel()` instead when the fan-out is a MeTTa expression
> rather than a Python loop; the two compose.

Evidence: `extensions/python/tests/ch14_seeing_your_program/test_engine_pool.py::test_metta_pool_is_the_same_pool`, `extensions/python/tests/ch14_seeing_your_program/test_engine_pool.py::test_several_failures_raise_together_one_raises_plain`.

## space:reducible

```python
reducible(target: Any) -> bool
```

Kind: `introspection`. Answer: `bool`. Effect: `readOnlyLookup`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_reducible`, receiving `method`.

Engine binding: `metta_py_reducible`, wire `prolog-goal`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `target` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `Bool` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Whether a head reduces here, asked without evaluating anything.
>
>     m.reducible(S.double(4))     # True
>     m.reducible(S.Point(1, 2))   # False, nothing applies to that head
>
> The same head test eval_status() uses, published on its own because a
> caller who wants to DECIDE about an unreduced term should not have to
> run the term to find out. That decision is the caller's: a term
> nothing applies to is its own answer, which is ordinary MeTTa and how
> `!(hello world)` works, so there is no scope here that refuses one.
>
> The Node extension has had m.reducible() since it existed; Python had
> only eval_status(), which evaluates to tell you.

Evidence: `extensions/python/tests/ch05_equations_and_evaluation/test_nothing_outcomes.py::test_reducible_asks_the_question_without_running_the_term`.

## space:eval-status

```python
eval_status(target: Any, /, *, timeout: float | None=None, inferences: int | None=None, theory: Any | None=None, interpreter: Any | None=None, **values: Any) -> list[tuple[str, Atom | Undefined | None]]
```

Kind: `evaluation`. Answer: `list`. Effect: `oracleIO`. Determinism: `nondet`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_eval_status`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `target` | `%Undefined%` | `required` | `values` | `positional_only` |
| `timeout` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `inferences` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `theory` | `(host-union (%Undefined% NoneType))` | `None` | `values` | `keyword_only` |
| `interpreter` | `(host-union (%Undefined% NoneType))` | `None` | `values` | `keyword_only` |
| `values` | `%Undefined%` | `required` | `values` | `var_keyword` |

Guarantees result type `(host-apply (host-type metta._space list) ((host-apply (host-type metta._space tuple) (String (host-union ((host-union (Atom (host-type metta._space Undefined))) NoneType))))))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Evaluate a term, pairing each answer with how it was produced.
>
>     m.eval_status(S.double(4))       # [("value", Grounded(8))]
>     m.eval_status(S.Point(1, 2))     # [("not-reducible", Expression(...))]
>     m.eval_status(S.empty())         # [("empty", None)]
>
> `value` means an equation, builtin or special form applied.
> `not-reducible` means no rule applied, so the answer is the term
> itself, which is what MeTTa does with any head it cannot call.
> `empty` means the goal produced no answer at all, and its atom is
> None. Reading the last two as the same thing is the mistake this
> exists to prevent: an unevaluated term and a pruned branch look
> alike from the answers alone. An error is not a status here,
> because it arrives as an exception.
>
> A `bind()` scope binds host values into the term exactly as it
> does for eval(), and it has to: the substitution lands BEFORE the
> reducibility question, so the status of an evaluation that binds
> anything was unaskable without it. Name keys mean symbols and atom
> keys mean themselves, so `bind({V.x: 5})` fills a variable hole.
>
> `theory` and `interpreter` are eval()'s own, and mean the same here.
> This is the method that says which evaluation path produced an answer, so
> being unable to point it at an alternative evaluation relation was the
> sharpest form of the gap: `m.eval_status(target, interpreter=my_eval)`
> is how you see whether an explicit interpreter reduced a term or handed
> it back. `under=` is deliberately NOT here: a carrier annotates every
> answer with an algebra value, so it would make a status row a triple
> rather than the pair it is, which is a question about what a status IS.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_space.py::test_eval_status_reports_the_four_outcomes`, `extensions/python/tests/ch05_equations_and_evaluation/test_per_ask_evaluation.py::test_eval_status_selects_the_same_relations_answers_does`, `extensions/python/tests/ch05_equations_and_evaluation/test_nothing_outcomes.py::test_eager_eval_keeps_empty_and_not_reducible_distinct`.

## space:run-status

```python
run_status(source: str, *, timeout: float | None=None, inferences: int | None=None) -> list[list[tuple[str, Atom | Undefined | None]]]
```

Kind: `evaluation`. Answer: `list`. Effect: `oracleIO`. Determinism: `nondet`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_run_status`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `source` | `String` | `required` | `values` | `positional_or_keyword` |
| `timeout` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `inferences` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |

Guarantees result type `(host-apply (host-type metta._space list) ((host-apply (host-type metta._space list) ((host-apply (host-type metta._space tuple) (String (host-union ((host-union (Atom (host-type metta._space Undefined))) NoneType))))))))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> run(), with each directive's answers paired with how they arose.
>
> The grouping and the answers are run()'s own; see eval_status() for
> what the three paths mean.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_space.py::test_run_status_registers_signatures_before_any_form_runs`, `extensions/python/tests/ch04_spaces_and_matching/test_space.py::test_run_status_reports_each_directive`, `extensions/python/tests/ch11_python_as_a_notation/test_template_holes.py::test_run_status_refuses_program_text_with_holes`.

## space:one

```python
one(target: Any, *, timeout: float | None=None, inferences: int | None=None) -> Any
```

Kind: `evaluation`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `async`.

Longhand: `space:eval(..., answer='one', delivery='values', on_error='abort')`.

Implementation: `metta._space:Space._one`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `target` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |
| `timeout` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `inferences` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Return the sole answer as a plain Python value for internal callers.
>
>     m.eval(S.fact(5))[0]         # Grounded(120)
>
> Exactly one answer is the contract: none or several raise naming
> the count, because a caller asking for the value has asserted
> there is one. Grounded answers unwrap to their Python values;
> symbols and structure stay atoms.
>
> This is one point on the answer-cardinality axis, spelled the
> same everywhere it appears: eval() takes every answer (MeTTa's
> collapse), while this private helper demands exactly one. The same
> timeout/inferences bounds apply throughout.
>
> An `(Error ...)` answer raises MettaResultError carrying the
> atom: an error among the answers is the evaluation reporting
> failure, and failure outranks the count. eval() is the method
> that keeps errors as data.

Evidence: `extensions/python/tests/ch10_errors_and_refusals/test_error_answers.py::test_one_raises_a_structured_error_on_an_error_answer`, `extensions/python/tests/ch10_errors_and_refusals/test_error_answers.py::test_one_still_answers_plain_values`, `extensions/python/tests/ch14_seeing_your_program/test_features.py::test_value_answers_the_one_answer`.

## space:first

```python
first(target: Any, *, timeout: float | None=None, inferences: int | None=None) -> Any
```

Kind: `evaluation`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `async`.

Longhand: `space:eval(..., answer='first', delivery='values', on_error='abort')`.

Implementation: `metta._space:Space._first`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `target` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |
| `timeout` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `inferences` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> The first answer as a plain Python value, or None for no answers.
>
> The tolerant member of one()'s family: one() asserts exactly
> one, eval() answers all, first() answers the first or nothing,
> decoded by the same rule as one(). An Undefined first answer
> still raises, since None here MEANS no answers. Tolerance is
> about cardinality, not content: a first answer that is an
> `(Error ...)` atom raises MettaResultError exactly as one()
> does, because None must keep meaning "no answers" and an error
> used as a value is the silent kind of wrong.

Evidence: `extensions/python/tests/ch10_errors_and_refusals/test_error_answers.py::test_first_raises_on_an_error_first_answer_only`, `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_the_three_families_share_the_tolerant_member`.

## space:stats

```python
stats() -> _StatsBlock
```

Kind: `introspection`. Answer: `context`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`, `module`, `context`.

Implementation: `metta._space:Space._door_stats`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-type metta._space _StatsBlock)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> The engine's own counters over a with-block, as deltas.
>
>     with m.stats() as s:
>         m.match(S.edge(V.x, V.y), S.edge(V.y, V.z))
>     s.inferences        # engine steps the block spent
>     s.cputime           # engine CPU seconds
>     s.walltime          # wall seconds, Python's clock
>     s.gc_count, s.gc_freed, s.gc_time
>     s.table_bytes       # answer-table bytes grown, tabling's memory
>
> The counters are SWI's statistics/2 read on the CALLING thread, so
> a block that runs other threads' engine work counts that work too;
> the honest reading is "what this thread saw the engine do while the
> block ran". A lazy cursor is the exception, and a large one: its
> goal runs in an SWI engine, an engine counts its own inferences,
> and this thread cannot see them. Draining 20,000 rows through the
> match cursor reports 40,049 inferences against about 381,000 the
> cursor's engine really spent, 10.5% of the work; the real cost is
> readable off the `inferences` budget, which does count the engine
> . The evaluation cursor behind `answers()`
> does report its engine's spend, so that one is whole. The z3py
> Solver.statistics() reading, on the engine this library actually
> has.

Evidence: `extensions/python/tests/ch14_seeing_your_program/test_explain_plan.py::test_analyze_numbers_equal_the_stats_of_the_same_query`, `extensions/python/tests/ch14_seeing_your_program/test_features.py::test_a_profile_exports_as_pstats`, `extensions/python/tests/ch14_seeing_your_program/test_features.py::test_a_stats_counter_is_unreadable_until_its_block_closes`.

## space:op

```python
@overload
op(fn: Callable[_P, _R], /, *, name: str | None=..., transport: Literal['encoded', 'raw']=..., effect: EffectClass | str, declarations: Iterable[Atom]=..., arities: list[int] | None=..., inverse: Callable | None=...) -> Callable[_P, _R]
@overload
op(*, name: str | None=..., transport: Literal['encoded', 'raw']=..., effect: EffectClass | str, declarations: Iterable[Atom]=..., arities: list[int] | None=..., inverse: Callable | None=...) -> Callable[[Callable[_P, _R]], Callable[_P, _R]]
op(fn: Callable | None=None, *, name: str | None=None, transport: Literal['encoded', 'raw']='encoded', effect: EffectClass | str | None=None, declarations: Iterable[Atom]=(), arities: list[int] | None=None, inverse: Callable | None=None) -> Any
```

Kind: `provider`. Answer: `value`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`, `module`, `context`.

Declared option vocabularies:

- `effect`: `pureStructural`, `readOnlyLookup`, `nondeterministicReadOnly`, `writesState`, `oracleIO`.

Implementation: `metta._space:Space._door_op`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `fn` | `(host-union ((host-type metta._space Callable) NoneType))` | `None` | `values` | `positional_or_keyword` |
| `name` | `(host-union (String NoneType))` | `None` | `values` | `keyword_only` |
| `transport` | `(host-literal ("encoded" "raw"))` | `'encoded'` | `values` | `keyword_only` |
| `effect` | `(host-union ((host-union ((host-type metta._space EffectClass) String)) NoneType))` | `None` | `values` | `keyword_only` |
| `declarations` | `(host-apply (host-type metta._space Iterable) (Atom))` | `()` | `values` | `keyword_only` |
| `arities` | `(host-union ((host-apply (host-type metta._space list) (Number)) NoneType))` | `None` | `values` | `keyword_only` |
| `inverse` | `(host-union ((host-type metta._space Callable) NoneType))` | `None` | `values` | `keyword_only` |

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Register a Python callable as a MeTTa function, decorator-style.
>
>     @m.op(effect=EffectClass.pureStructural)
>     def double(x: int) -> int:
>         return 2 * x                    # !(double 21) -> 42
>
>     @m.op(effect=EffectClass.nondeterministicReadOnly)
>     def neighbours(n: int):
>         yield n - 1                     # a generator is nondeterministic
>         yield n + 1
>
> An implicit Python name maps underscores to MeTTa hyphens. ``name=``
> is exact, for source vocabularies that deliberately use underscores.
>
> A name must read back as one MeTTa symbol. A space, parenthesis,
> quote, comment opener, variable spelling, number, boolean, or another
> registered reader token is refused before any registry changes, with
> the name and the conflicting character in the error.
>
> Annotations become ordinary `(: ...)` declarations. An unannotated
> callable makes no type claim. `transport="raw"` skips wire encoding
> both ways and is reflected as raw_det or raw_many in `(op ...)`;
> symbols then reach Python as strings, so encoded transport is the
> fidelity-preserving default. unregister_op(name) removes every
> registered arity and every declaration the registration owns.
>
> An `Atom` parameter changes evaluation order. The declaration tells
> the compiler to pass the argument as written, before it reduces:
>
>     @m.op(effect=EffectClass.pureStructural)
>     def anyatom(term: Atom) -> Atom:
>         return term
>
>     # with (= (side) 42), !(anyatom (side)) answers (side)
>
> An unconstrained parameter receives the evaluated value instead, so
> the otherwise identical `def anyval(term): return term` answers 42.
> Use `Atom` only when the operation deliberately implements syntax or
> a control form; it is not just a static hint.
>
> An encoded generator may instead yield exact tuples as positional
> relation rows, or exact dicts keyed by parameter name as sparse rows.
> The engine unifies each candidate against the written call, so one
> implementation serves free, partially bound, and ground arguments:
>
>     @m.op
>     def route(origin, destination):
>         yield (S.paris, S.lyon)
>         yield {"destination": S.nice}  # origin is unconstrained
>
>     # route(V.origin, S.lyon).rows[0].origin == S.paris
>
> Each matching occurrence answers unit and duplicate yields remain
> duplicate answers. Use `Answer(value=...)` when an exact tuple or dict
> is the result value rather than a parameter row. Relational rows
> require encoded transport; raw calls cannot carry unbound argument
> positions.
>
> When evaluation order stays ordinary but the callable needs the
> resulting Atom wrappers, declare that policy as data:
>
>     m.op(
>         inspect_atom,
>         name="inspect-atom",
>         effect=EffectClass.pureStructural,
>         declarations=[parse("(arguments inspect-atom atoms)")],
>     )
>
> The declaration is matchable in &metta and is retired with the
> operation. Raw transport refuses this declaration because it bypasses
> the atom codec entirely.
>
> The cost ladder, measured on the maintained box in inferences per
> call, explains the transport choice:
>
>     native MeTTa function            9.11   the floor
>     transport="raw"                10.11   opaque handles, near-native
>     encoded                        17.11   encoded values
>     encoded, typed literal         17.11   the check hoists to compile
>     py-call, dotted                 22.11   the ad-hoc escape hatch
>
> The ergonomic default (encoded, typed) costs about 1.7x raw on the
> counter and more on wall clock, since encoding walks the value both
> ways; a registered raw operation measured 0.85us against 2.26us
> encoded. Bulk data should stay opaque: one transparent 64-float
> crossing costs 330 inferences where the handle costs 10.
>
> `inverse=` remains the distinct-output form. Use it when the forward
> operation returns a result and a separate callable must recover the
> arguments from that result:
>
>     m.op(
>         cons,
>         name="cons",
>         inverse=uncons,
>         effect=EffectClass.pureStructural,
>     )
>     # !(let (cons $h $t) (1 2 3) ($h $t))  ->  (1 (2 3))
>
> It takes the result and returns the arguments, as a tuple, or the
> bare value at arity one; a generator enumerates every preimage, and
> None or NotReducible means there is none. It runs only when the arguments
> are not ground and the result is, so a forward call never reaches it,
> and an operation without one compiles exactly what it did before.
>
> A parameter annotated `metta.MeTTa` is the framework's to fill,
> FastAPI's Depends read with the house convention that the
> annotation is the request. The engine injects itself bound to the
> CALLING context's space, so an operation invoked from a program
> running in &kb queries &kb; the slot never counts toward MeTTa
> arities or the declared arrow, and only operations that ask pay
> the weaving:
>
>     @m.op(effect=EffectClass.nondeterministicReadOnly)
>     def related(term, engine: metta.MeTTa):
>         for row in engine.match(Expression(S.link, term, V.x)):
>             yield row[0]
>
> Every operation declares its strongest observable effect. The five
> ordered choices are ``pureStructural``, ``readOnlyLookup``,
> ``nondeterministicReadOnly``, ``writesState``, and ``oracleIO``:
>
>     m.op(
>         len,
>         name="size",
>         effect=EffectClass.pureStructural,
>     )
>     # (= (count-of $x) (size $x))  is cacheable
>
> It is an allow-list on purpose. An operation that does not say so is
> refused by name in a cached body, loudly, rather than cached and
> quietly wrong.

Evidence: `extensions/python/tests/ch11_python_as_a_notation/test_effect_lattice.py::test_every_effect_rank_registers_and_reflects`.

## space:pure

```python
pure(fn: Callable | None=None, /, **options: Any) -> Any
```

Kind: `provider`. Answer: `value`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`, `module`, `context`.

Longhand: `space:op(..., effect='pureStructural')`.

Implementation: `metta._space:Space._door_pure`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `fn` | `(host-union ((host-type metta._space Callable) NoneType))` | `None` | `values` | `positional_only` |
| `options` | `%Undefined%` | `required` | `values` | `var_keyword` |

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> An operation whose answer depends only on its arguments.
>
>     @m.pure
>     def double(x: int) -> int:
>         return 2 * x
>
> The cache-safe class, and the only one memoization and tabling admit
> without an explicit policy.
>
> A GENERATOR written this way is lifted to `nondeterministicReadOnly`,
> because a generator is nondeterministic whatever it declares, and the
> registration reads that off the function rather than asking. The lift
> only ever raises the rank, so it widens the answer-count claim and
> never weakens the effect claim -- but it does mean a generator is not
> cache-safe, which is the whole reason it is lifted out of this class
> .
>
> Every ``op`` keyword applies: ``name``, ``arities``,
> ``declarations``, ``inverse`` and ``transport``. They arrive as
> ``**options`` and forward unchanged, so the signature above shows
> the mechanism and this line shows the surface.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_effect_sugars_are_their_declared_parameter_points`.

## space:reads

```python
reads(fn: Callable | None=None, /, **options: Any) -> Any
```

Kind: `provider`. Answer: `value`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`, `module`, `context`.

Longhand: `space:op(..., effect='readOnlyLookup')`.

Implementation: `metta._space:Space._door_reads`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `fn` | `(host-union ((host-type metta._space Callable) NoneType))` | `None` | `values` | `positional_only` |
| `options` | `%Undefined%` | `required` | `values` | `var_keyword` |

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> An operation that reads stable state without changing it.
>
> Every ``op`` keyword applies: ``name``, ``arities``,
> ``declarations``, ``inverse`` and ``transport``. They arrive as
> ``**options`` and forward unchanged, so the signature above shows
> the mechanism and this line shows the surface.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_effect_sugars_are_their_declared_parameter_points`.

## space:writes

```python
writes(fn: Callable | None=None, /, **options: Any) -> Any
```

Kind: `provider`. Answer: `value`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`, `module`, `context`.

Longhand: `space:op(..., effect='writesState')`.

Implementation: `metta._space:Space._door_writes`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `fn` | `(host-union ((host-type metta._space Callable) NoneType))` | `None` | `values` | `positional_only` |
| `options` | `%Undefined%` | `required` | `values` | `var_keyword` |

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> An operation that changes engine or host state.
>
> Every ``op`` keyword applies: ``name``, ``arities``,
> ``declarations``, ``inverse`` and ``transport``. They arrive as
> ``**options`` and forward unchanged, so the signature above shows
> the mechanism and this line shows the surface.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_effect_sugars_are_their_declared_parameter_points`.

## space:io

```python
io(fn: Callable | None=None, /, **options: Any) -> Any
```

Kind: `provider`. Answer: `value`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`, `module`, `context`.

Longhand: `space:op(..., effect='oracleIO')`.

Implementation: `metta._space:Space._door_io`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `fn` | `(host-union ((host-type metta._space Callable) NoneType))` | `None` | `values` | `positional_only` |
| `options` | `%Undefined%` | `required` | `values` | `var_keyword` |

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> An operation that observes an external oracle.
>
> A clock, randomness, a network, a file, another runtime.
>
>     @m.io
>     def now() -> float:
>         return time.time()
>
> The fail-closed top of the lattice. Declare it when what the operation
> reaches is decided at run time or by a library the engine cannot bound.
>
> Every ``op`` keyword applies: ``name``, ``arities``,
> ``declarations``, ``inverse`` and ``transport``. They arrive as
> ``**options`` and forward unchanged, so the signature above shows
> the mechanism and this line shows the surface.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_effect_sugars_are_their_declared_parameter_points`.

## space:unregister-op

```python
unregister_op(name: str) -> None
```

Kind: `provider`. Answer: `None`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_unregister_op`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `name` | `String` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `NoneType` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Remove a registered operation, every arity of it.
>
> An absent name raises KeyError, as convert.unregister_type does:
> removing something that was never there is a mistake worth hearing
> about, not a no-op to absorb.

Evidence: `extensions/python/tests/ch11_python_as_a_notation/test_adoptions.py::test_shared_class_declarations_survive_one_unregister`, `extensions/python/tests/ch11_python_as_a_notation/test_ops.py::test_unregistering_a_name_a_system_predicate_shares_does_not_throw`, `extensions/python/tests/ch20_extending_the_engine/test_contract.py::test_unregister_removes_the_effect_atom_with_the_op_facts`.

## space:builtins

```python
builtins() -> list[str]
```

Kind: `introspection`. Answer: `list`. Effect: `readOnlyLookup`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_builtins`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-apply (host-type metta._space list) (String))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Every function callable from this space, plus every special form.
>
> Its own equations, the ones it inherits, ``&self``'s shared ones and
> the engine's builtins, with the translator's special-form heads,
> sorted without duplicates. A head another space defines is
> registered process-wide (the translator's call-or-data question,
> which ``is_function`` answers) but is not callable here and is not
> listed here.

Evidence: `extensions/python/tests/ch11_python_as_a_notation/test_mention_doors.py::test_catalogue_membership_answers_the_builtins_union`, `extensions/python/tests/ch18_performance/test_builtins_generation_cache.py::test_eval_definitions_reach_the_next_namespace_access`, `extensions/python/tests/ch20_extending_the_engine/test_builtins.py::test_builtins_equals_the_union_of_functions_and_special_forms`.

## space:is-function

```python
is_function(name: str) -> bool
```

Kind: `introspection`. Answer: `bool`. Effect: `readOnlyLookup`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_is_function`, receiving `method`.

Engine binding: `metta_py_is_function`, wire `prolog-goal`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `name` | `String` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `Bool` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Report whether the name is registered as a function anywhere.
>
> This is the translator's call-or-data question and holds wherever a
> term compiles; ``is_function_here`` asks whether the head answers
> from THIS space, and ``builtins()`` lists what this space can call.

Evidence: `extensions/python/tests/ch11_python_as_a_notation/test_adoptions.py::test_registration_failure_leaves_nothing_half_registered`, `extensions/python/tests/ch11_python_as_a_notation/test_adoptions.py::test_union_expansion_is_bounded`, `extensions/python/tests/ch11_python_as_a_notation/test_fn_protocol.py::test_a_namespace_lists_and_resolves_only_what_its_space_can_call`.

## space:is-function-here

```python
is_function_here(name: str) -> bool
```

Kind: `introspection`. Answer: `bool`. Effect: `readOnlyLookup`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_is_function_here`, receiving `method`.

Engine binding: `metta_py_function_visible`, wire `prolog-goal`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `name` | `String` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `Bool` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Whether a function would answer from THIS space: it has clauses
> this space's module sees, its own or the shared ones in user.
> Another space's equations are invisible here and do not count.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_r2_space_handle.py::test_a_space_is_the_grounded_handle_species_and_import_operand`, `extensions/python/tests/ch11_python_as_a_notation/test_fn_protocol.py::test_a_namespace_lists_and_resolves_only_what_its_space_can_call`, `extensions/python/tests/ch11_python_as_a_notation/test_host_island.py::test_unknown_host_callee_islands_implicitly`.

## space:arities

```python
arities(name: str) -> list[int]
```

Kind: `introspection`. Answer: `list`. Effect: `readOnlyLookup`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_arities`, receiving `method`.

Engine binding: `metta_py_arities`, wire `prolog-goal`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `name` | `String` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `(host-apply (host-type metta._space list) (Number))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Compiled predicate arities for a name: MeTTa arity plus one each.

Evidence: `extensions/python/tests/ch11_python_as_a_notation/test_ide_surface.py::test_declarations_carry_arrows_arities_and_documentation`, `extensions/python/tests/ch17_concurrency_and_the_loop/test_aio.py::test_aio_plain_methods_forward_on_the_worker`.

## space:register-prolog

```python
register_prolog(source: str | None=None, *, path: str | os.PathLike[str] | None=None, names: _abc.Sequence[str] | _abc.Mapping[str, str]=()) -> tuple[str, ...]
```

Kind: `provider`. Answer: `tuple`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_register_prolog`, receiving `method`.

Engine binding: `import_prolog_functions`, wire `prolog-goal`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `source` | `(host-union (String NoneType))` | `None` | `values` | `positional_or_keyword` |
| `path` | `(host-union ((host-union (String (host-apply (host-type metta._space os.PathLike) (String)))) NoneType))` | `None` | `values` | `keyword_only` |
| `names` | `(host-union ((host-apply (host-type metta._space _abc.Sequence) (String)) (host-apply (host-type metta._space _abc.Mapping) (String String))))` | `()` | `values` | `keyword_only` |

Guarantees result type `(host-apply (host-type metta._space tuple) (String ...))` with the answer shape, effect, and determinism above.

Declared local refusals:

- `value`: `extensions/python/tests/repository/test_door_refusals.py::test_door_value_refusals[space:register-prolog]`.

Implementation failures propagate, including failures from callees and providers.

> Register Prolog predicates as MeTTa functions, at native speed.
>
> This is the extension point for a library that wants to run fast.
> op() is the one most people find first, and every call it
> serves crosses the janus boundary: 25.16 inferences and 2.34us per
> call, against 7.16 inferences and 0.13us for the same operation
> written in Prolog.
>
> Read the microseconds, not the inferences. The crossing counts as ONE
> inference and costs real time, so inferences say a Python operation is
> 3.1x a Prolog one while wall clock says 18x. That is a fine price for
> reaching NumPy or an LLM and a bad one for arithmetic in a loop.
>
> A registered predicate keeps its nondeterminism: one that offers three
> solutions gives the MeTTa function three answers.
>
> A predicate follows the compiled calling convention, inputs first and
> one output last:
>
>     m.register_prolog(
>         "'vec-dot'(A, B, Out) :- ... .",
>         names=["vec-dot"],
>     )
>     m.eval("(vec-dot (1 2) (3 4))")[0]
>
> or, for a library shipping a file beside its Python:
>
>     m.register_prolog(path=Path(__file__).parent / "fast.pl",
>                       names=["vec-dot", "vec-norm"])
>
> Every name is registered explicitly rather than discovered, because
> registering a name whose predicate is absent records no arity and then
> compiles every call to it into a partial application instead of
> failing, which is a silent wrong answer rather than an error. This
> raises instead: a name with no predicate behind it is refused before
> it can do that.
>
> The refusals are the engine's, through check_prolog_function_names/3
> and import_prolog_functions/2, so this and the MeTTa spelling enforce
> one rule rather than two copies of it. Three names are refused: one
> with no predicate behind it, a builtin, and a special form.
>
> Nothing is registered unless every name can be, so a typo in the list
> changes nothing. The consulted SOURCE does stay loaded on failure,
> which is deliberate rather than overlooked: loading it again is the
> retry, and it is idempotent, since the source is identified by a hash
> of its own content.
>
> **This is a method on a space and it registers PROCESS-WIDE.** So do
> op and define. Only equations are space-scoped, so an anonymous
> space() isolates one of the three things you can register and
> shares the other two. That is deliberate rather than overlooked: a
> Prolog predicate lives in `user`, every space has to be able to call
> it, and a library loaded inside a named space would define itself
> where the registration could not see it. The method sits on the space
> because that is where the rest of the surface is, not because the
> registration is scoped to it.
>
> The name is owned by one tier. A second registration of the same name
> from another tier is refused, in both directions, naming the owner, so
> two libraries cannot silently take the same name from each other.
>
> A parameter a MeTTa caller should reach unevaluated needs a type
> declaration, which this call does not take yet:
>
>     m.register_prolog("'shape-of'(A, Out) :- Out = [shape, A].",
>                       names=["shape-of"])
>     m.run("(: shape-of (-> Atom Atom))")
>     m.eval("(shape-of (+ 1 2))")[0] # (shape (+ 1 2)), not (shape 3)
>
> Declare it BEFORE anything calls the function. A call site compiled
> while the declaration is absent keeps evaluating the argument even
> after it lands.

Evidence: `extensions/python/tests/ch20_extending_the_engine/test_register_prolog.py::test_a_builtin_name_is_refused_and_the_builtin_still_works`, `extensions/python/tests/ch20_extending_the_engine/test_register_prolog.py::test_a_declaration_without_an_extension_still_reports_its_names`, `extensions/python/tests/ch20_extending_the_engine/test_register_prolog.py::test_a_declared_det_function_answers_normally`.

## space:register-foreign-library

```python
register_foreign_library(path: str | os.PathLike[str], *, entry: str | None=None, names: _abc.Sequence[str]=()) -> tuple[str, ...]
```

Kind: `provider`. Answer: `tuple`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_register_foreign_library`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `path` | `(host-union (String (host-apply (host-type metta._space os.PathLike) (String))))` | `required` | `values` | `positional_or_keyword` |
| `entry` | `(host-union (String NoneType))` | `None` | `values` | `keyword_only` |
| `names` | `(host-apply (host-type metta._space _abc.Sequence) (String))` | `()` | `values` | `keyword_only` |

Guarantees result type `(host-apply (host-type metta._space tuple) (String ...))` with the answer shape, effect, and determinism above.

Declared local refusals:

- `source`: `extensions/python/tests/repository/test_door_refusals.py::test_foreign_library_refuses_a_missing_source`.

Implementation failures propagate, including failures from callees and providers.

> Load a compiled `.so` and register its predicates as MeTTa functions.
>
> The C tier is the cheapest one on this page's cost table, one
> inference per call, and reaching it used to mean hand-writing two
> Prolog directives into `register_prolog`:
>
>     m.register_foreign_library(Path(__file__).parent / "cbump.so",
>                                entry="install_cbump", names=["c-bump"])
>
> `entry` is the C initialiser, `install_cbump` in
> `install_t install_cbump(void)`; leave it out for a library whose
> entry is plain `install`.
>
> The path is resolved to an ABSOLUTE one here, which is the trap this
> exists to close: `use_foreign_library/2` accepts a path relative to
> the working directory, resolves it, and SWI deprecates that and warns
> on every load, so a library that shipped one worked from the repo root
> and warned or failed anywhere else. A file that is not there is
> refused here rather than inside the engine's loader.
>
> Everything after the load is `register_prolog`, so the same refusals
> apply: a name with no predicate behind it, a builtin, a special form,
> and a name another tier owns.

Evidence: `extensions/python/tests/ch20_extending_the_engine/test_register_prolog.py::test_a_compiled_library_registers_from_python`, `extensions/python/tests/ch20_extending_the_engine/test_register_prolog.py::test_an_absent_compiled_library_is_refused_here`, `extensions/python/tests/ch14_seeing_your_program/test_trace.py::test_a_foreign_predicate_does_not_break_tracing`.

## space:register-library-path

```python
register_library_path(directory: Any, name: str) -> None
```

Kind: `provider`. Answer: `None`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_register_library_path`, receiving `method`.

Engine binding: `register_metta_library_path`, wire `prolog-goal`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `directory` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |
| `name` | `String` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `NoneType` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Point MeTTa at a directory of files your package ships.
>
>     # in your package's __init__
>     m.register_library_path(Path(__file__).parent / "prolog", "pettorch")
>
> Subject first, as every register_* call: the directory being
> registered, then the library name it serves.
>
> `(library pettorch fast.pl)` then resolves, from MeTTa and from
> `register_prolog(path=...)`. Without it a pip-installed library is
> under neither `<engine>/../lib` nor a git checkout, so it has to pass
> absolute paths and compute them from `__file__` by hand.
>
> This is SWI's own `file_search_path/2`, so an alias registered here is
> one every SWI tool already understands, and aliases compose: the
> second argument of one may be another alias. Registering the same
> directory twice is a no-op; a directory that is not there is refused
> here rather than at the first import that needs it.

Evidence: `extensions/python/tests/ch11_python_as_a_notation/test_integrate.py::test_an_explicitly_shared_library_alias_keeps_all_directories`, `extensions/python/tests/ch11_python_as_a_notation/test_integrate.py::test_a_failed_integration_unwinds_every_framework_registration`.

## space:unregister-prolog

```python
unregister_prolog(extension: str) -> tuple[str, ...]
```

Kind: `provider`. Answer: `tuple`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_unregister_prolog`, receiving `method`.

Engine binding: `metta_py_unregister_extension`, wire `prolog-goal`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `extension` | `String` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `(host-apply (host-type metta._space tuple) (String ...))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Release everything one extension registered, and its clauses.
>
> The unit is the extension, not the name. `register_prolog` used to
> load a bunch of loose predicates: the engine recorded that each name
> was a function and nothing at all about the library it came from, so
> there was no uninstall to write and a partly-failed registration left
> debris nobody could enumerate.
>
>     :- metta_extension(pettorch, [version('0.3.1')]).
>     :- metta_export("(: vec-dot (-> Number Number Number))").
>
>     m.register_prolog(path="fast.pl")     # names come from the file
>     m.unregister_prolog("pettorch")       # everything it installed
>
> PostgreSQL's rule, and its reason: an individual member cannot be
> dropped on its own, only the whole extension, which is what stops one
> registry keeping a claim on a name another route already replaced.
> The clauses go too, through SWI's own `unload_file/1`, so a name is
> not left callable through a predicate nothing records.
>
> Answers the names it released. Raises when no extension of that name
> is loaded, rather than reporting success for a no-op.

Evidence: `extensions/python/tests/ch20_extending_the_engine/test_register_prolog.py::test_a_provider_only_file_registers_no_functions_and_is_accepted`, `extensions/python/tests/ch20_extending_the_engine/test_register_prolog.py::test_an_extension_unloads_whole`, `extensions/python/tests/ch20_extending_the_engine/test_register_prolog.py::test_an_unloaded_extension_does_not_leave_its_names_behind`.

## space:subscribe

```python
subscribe(pattern: Any, callback: Callable | None=None, *, on: SubscriptionEdge=SubscriptionEdge.add, where: Any | None=None, queue_max: int | None=None)
```

Kind: `scope`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`.

Declared option vocabularies:

- `on`: `add`, `remove`, `both`.

Implementation: `metta._space:Space._door_subscribe`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `pattern` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |
| `callback` | `(host-union ((host-type metta._space Callable) NoneType))` | `None` | `values` | `positional_or_keyword` |
| `on` | `(host-type metta._space SubscriptionEdge)` | `SubscriptionEdge.add` | `values` | `keyword_only` |
| `where` | `(host-union (%Undefined% NoneType))` | `None` | `values` | `keyword_only` |
| `queue_max` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Declared local refusals:

- `type`: `extensions/python/tests/repository/test_door_refusals.py::test_door_type_refusals[space:subscribe]`.

Implementation failures propagate, including failures from callees and providers.

> A standing query on this space: every added (or removed, or
> both) atom unifying with the pattern becomes an Event.
>
>     seen = []
>     sub = m.subscribe(S.order(V.id), lambda e: seen.append(e))
>     m.add(S.order(1))          # seen[0].bindings["id"] == 1
>     sub.cancel()
>
> With a callback, delivery is synchronous. An unscoped write delivers
> before it returns; a transaction delivers its ordered segment only
> after the complete commit, while rollback and speculation deliver
> nothing. The callback may write back; the engine re-enters cleanly,
> and an infinite add-triggers-add loop is the author's own.
> Without one, events queue on the subscription and drain() empties
> them: the mailbox reading. That queue is bounded by `queue_max`,
> and a write arriving at a full queue raises SubscriberError rather
> than discarding the oldest event: nobody draining is a bug in the
> consumer, and a silently shortened history is how it stays hidden.
> A removal event fires only when something was removed, and carries
> the pattern that was asked for rather than the occurrence that
> left. The two are the same atom for a ground removal and differ
> for a pattern one: removal is multiset subtraction, so
> `remove(S.alert(V.q))` takes one of the alerts and the event
> cannot say which. Re-read the space when you need to know;
> `m.live(pattern)` is the worked instance, and it is the rung above
> this one: a view is this subscription maintaining what a match would
> have answered.

Evidence: `extensions/python/tests/ch11_python_as_a_notation/test_fn_protocol.py::test_subscribe_is_the_function_watcher`, `extensions/python/tests/ch16_events_and_standing_queries/test_dispatch_index.py::test_dispatch_through_the_index_delivers_the_same_subscribers_in_the_same_order`, `extensions/python/tests/ch16_events_and_standing_queries/test_events.py::test_subscribe_bridge_and_reaction_are_expressible_over_the_public_event_stream`.

## space:prolog

```python
prolog() -> None
```

Kind: `introspection`. Answer: `None`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._space:Space._door_prolog`, receiving `method`.

Engine binding: `janus.prolog`, wire `prolog-goal`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `NoneType` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Drop into the engine's own interactive Prolog toplevel, the
> deepest debugging lever there is: listing/1 shows compiled
> equations, trace/0 steps through them, and quitting the toplevel
> returns here with the session intact. janus's own janus.prolog(),
> surfaced where the debugging happens.
>
> This is the only Prolog-facing surface here besides register_prolog,
> and that is a decision rather than a gap. There is no public
> "call any Prolog goal" method: the supported way to reach your own
> Prolog from Python is to register it and call it as a MeTTa function,
> which keeps one set of conversion rules, one error taxonomy and one
> lock. A raw goal is janus's job and janus is importable directly.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_the_interactive_door_reaches_the_owned_runtime`.

## space:derivation

```python
derivation(target: Any, depth: int | None=None, *, timeout: float | None=None, inferences: int | None=None) -> list[Any]
```

Kind: `introspection`. Answer: `list`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_derivation`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `target` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |
| `depth` | `(host-union (Number NoneType))` | `None` | `values` | `positional_or_keyword` |
| `timeout` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `inferences` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |

Guarantees result type `(host-apply (host-type metta._space list) (%Undefined%))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Every proof of an answer, as trees in MeTTa terms.
>
> Each tree names the equations that fired and the stored atoms at the
> leaves, read from the translated_from links the engine keeps for
> every compiled clause. Meta-interpreted, so slower than evaluation;
> a diagnostic, not an evaluation path. The default walks each proof
> without a depth cutoff. A positive depth returns a partial tree with
> Truncated nodes when its budget ends, so an empty list means no proof.
> `timeout` and `inferences` guard the whole search. An evaluation error
> inside a proof surfaces as itself rather than as an empty proof list.
>
> Building a proof executes every premise it records, including
> effectful operations. Engine writes persist and repeated derivations
> accumulate them, just as repeated evaluations do. Use
> ``with space.speculative():`` when the proof should return while its
> engine writes are discarded. That scope cannot undo Python side
> effects, I/O, or subscription callbacks that already fired, so do not
> derive an effectful target when those effects must not happen.
>
> A `bind()` scope binds host values into the term, for the reason
> eval_status needs it: the substitution lands BEFORE the search, so the
> proof of an evaluation that binds anything was unaskable. Name keys
> mean symbols and atom keys mean themselves, so `bind({V.x: 5})` fills
> a variable hole. It takes no `theory` or
> `interpreter`, because a meta-interpreted diagnostic does not select an
> evaluation relation.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_per_space.py::test_derivation_follows_the_spaces_module`, `extensions/python/tests/ch05_equations_and_evaluation/test_per_ask_evaluation.py::test_derivation_binds_host_values_like_the_doors_beside_it`, `extensions/python/tests/ch14_seeing_your_program/test_derivation.py::test_a_cut_inside_once_stays_inside_it`.

## space:why

```python
why(pattern: Any, *, where: Any | None=None) -> str
```

Kind: `introspection`. Answer: `str`. Effect: `readOnlyLookup`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_why`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `pattern` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |
| `where` | `(host-union (%Undefined% NoneType))` | `None` | `values` | `keyword_only` |

Guarantees result type `String` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Why a pattern matches nothing here, in words.
>
> Checks the cheap explanations in order: unknown function, wrong
> arity, no stored atoms with that head. Honest when it cannot tell,
> and honest about the PREMISE too: a pattern that does match is a
> question with a false premise, and this refuses it the way
> Answers.why() always did rather than answering it. Asking why
> `(job $id $pri)` matched nothing, when it matches two atoms, used to
> answer "2 job atom(s) exist here but none unifies with it"
> .
>
> `where` is match()'s guard, and asking with one is where the answer
> gets interesting: a query can be empty because the pattern found
> nothing OR because the guard rejected everything it found, and only
> the guarded question can tell you which.
>
> One implementation, because there were two and they agreed word for
> word on every genuine miss while disagreeing about the premise.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_space.py::test_why`, `extensions/python/tests/ch14_seeing_your_program/test_lint.py::test_lint_and_why_agree_on_whether_a_head_is_known`, `extensions/python/tests/ch14_seeing_your_program/test_lint.py::test_why_and_lint_agree_about_a_call_at_an_undefined_arity`.

## space:define

```python
@overload
@dataclass_transform(eq_default=False)
define(fn: _builtins.type[_T], /, *, accessors: bool=..., methods: bool=...) -> _builtins.type[_T]
@overload
define(fn: Callable[_P, _R], /, *, name: str | None=..., accessors: bool=..., methods: bool=...) -> Defined[_P, _R]
@overload
define(*, name: str) -> Callable[[Callable[_P, _R]], Defined[_P, _R]]
@overload
define(*, prolog: str | os.PathLike[str], name: str | None=None) -> Callable[[Callable[_P, _R]], PrologBacked[_P, _R]]
define(fn: Callable[..., Any] | None=None, *, prolog: str | os.PathLike[str] | None=None, name: str | None=None, accessors: bool=True, methods: bool=True) -> Any
```

Kind: `provider`. Answer: `value`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`, `module`, `context`.

Implementation: `metta._space:Space._door_define`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `fn` | `(host-union ((host-apply (host-type metta._space Callable) (... %Undefined%)) NoneType))` | `None` | `values` | `positional_or_keyword` |
| `prolog` | `(host-union ((host-union (String (host-apply (host-type metta._space os.PathLike) (String)))) NoneType))` | `None` | `values` | `keyword_only` |
| `name` | `(host-union (String NoneType))` | `None` | `values` | `keyword_only` |
| `accessors` | `Bool` | `True` | `values` | `keyword_only` |
| `methods` | `Bool` | `True` | `values` | `keyword_only` |

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Declared local refusals:

- `type`: `extensions/python/tests/repository/test_door_refusals.py::test_door_type_refusals[space:define]`.

Implementation failures propagate, including failures from callees and providers.

> Compile a Python function into MeTTa equations, decorator-style.
>
> With `prolog=`, the Prolog file is registered and becomes the
> function, and the Python stays as the reference twin rather than
> being compiled:
>
>     @m.define(prolog=Path(__file__).parent / "fast.pl")
>     def vec_dot(a, b):
>         return sum(x * y for x, y in zip(a, b))
>
>     m.eval("(vec-dot (1 2) (3 4))")[0] # the Prolog answer
>     vec_dot.py((1, 2), (3, 4))          # the reference answers
>
> Rewriting a defined function in Prolog for speed used to mean
> deleting the Python and the differential oracle with it. Here both
> are declared together and `metta.testing.check_twin` proves they
> agree on ground inputs. The file must register the function's own
> MeTTa name and at the twin's arity, inputs then one output, and
> says so if it does not; its `metta_export` declaration owns the
> types, so annotations on the Python are documentation only.
>
> Written for whoever is fluent in Python rather than s-expressions:
> the body is read as syntax and lowered deterministically, refusals
> name the construct, the line and what to write instead, and the
> original stays reachable as .py, a twin the equations can be checked
> against on any ground input.
>
>     @m.define
>     def add_one(n):
>         return n + 1
>
>     add_one(5)                  # [6], evaluated by the engine
>     S.add_one(5)                # (add_one 5), staged as data
>     add_one.py(5)               # 6, ordinary Python
>
> The equation's implicit name applies the factories' total mechanical
> map, replacing each underscore with a hyphen. ``name=`` is the exact
> quoted-name escape for punctuation that map cannot preserve:
>
>     @m.define(name="add-one")
>     def add_one(n):
>         return n + 1
>
> The same attribute mapping applies to the definition name itself:
> ``def not_provable`` lands as ``not-provable``. An authored
> MeTTa underscore therefore uses explicit ``name="not_provable"``.
>
> A generator compiles to nondeterminism (each yield one answer), a
> lambda to the engine's own |->, a comprehension to map-atom and
> filter-atom, and match(Pattern(x, y), template) to a match against
> the running space, lowercase free names in the pattern binding as
> variables.

Evidence: `extensions/python/tests/ch09_types/test_refinements.py::test_a_defined_head_refuses_a_violating_argument_by_name_and_accepts_the_rest`, `extensions/python/tests/ch11_python_as_a_notation/test_adoptions.py::test_define_decorator_declares_field_types`, `extensions/python/tests/ch11_python_as_a_notation/test_authoring_surface.py::test_calling_a_defined_object_evaluates_and_an_unmatched_call_answers_itself`.

## space:rules

```python
rules(fn: Callable[..., Any]) -> _Rules
```

Kind: `provider`. Answer: `value`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_rules`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `fn` | `(host-apply (host-type metta._space Callable) (... %Undefined%))` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `(host-type metta._space _Rules)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Collect and land a non-exclusive equation bundle in this space.

Evidence: `extensions/python/tests/ch11_python_as_a_notation/test_authoring_surface.py::test_a_rules_generator_scopes_its_variables_to_its_parameters`, `extensions/python/tests/ch11_python_as_a_notation/test_r5_unbuilt_doors.py::test_rules_lower_emits_queryable_declaration_and_registers_the_head`, `extensions/python/tests/ch11_python_as_a_notation/test_r5_unbuilt_doors.py::test_rules_lower_refuses_an_empty_rule_set_before_mutating`.

## space:pre-add

```python
pre_add(fn: Defined[..., Any] | Callable[..., Any]) -> Defined[..., Any]
```

Kind: `write`. Answer: `callable`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_pre_add`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `fn` | `(host-union ((host-apply (host-type metta._space Defined) (... %Undefined%)) (host-apply (host-type metta._space Callable) (... %Undefined%))))` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `(host-apply (host-type metta._space Defined) (... %Undefined%))` with the answer shape, effect, and determinism above.

Declared local refusals:

- `type`: `extensions/python/tests/repository/test_door_refusals.py::test_door_type_refusals[space:pre-add]`.

Implementation failures propagate, including failures from callees and providers.

> Compile or accept one unary judge and claim this space's write hook.
>
> The common decorator stack places ``@pre_add`` above ``@define``, so
> an existing Defined keeps the module that owns its equations. A raw
> function is compiled into this space before claiming the hook.

Evidence: `extensions/python/tests/ch11_python_as_a_notation/test_library_surface_wave2.py::test_pre_add_compiles_the_four_verdict_judge`, `extensions/python/tests/ch17_concurrency_and_the_loop/test_aio.py::test_async_rules_and_pre_add_land_as_awaitable_calls`.

## space:type

```python
type(atom: Any) -> Atom
```

Kind: `introspection`. Answer: `Atom`. Effect: `readOnlyLookup`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_type`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `atom` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `Atom` with the answer shape, effect, and determinism above.

Declared local refusals:

- `engine`: `extensions/python/tests/repository/test_door_refusals.py::test_door_refuses_a_missing_engine_answer[type]`.

Implementation failures propagate, including failures from callees and providers.

> Return this space's first ``get-type`` answer, including undefined.

Evidence: `extensions/python/tests/ch03_atoms_and_expressions/test_p5_annotations.py::test_an_atom_in_annotation_position_is_the_type_itself`, `extensions/python/tests/ch09_types/test_inference.py::test_declaring_adds_exactly_the_proposals`, `extensions/python/tests/ch09_types/test_structural_aliases.py::test_a_failed_cycle_and_conflict_leave_previous_behavior_intact`.

## space:infer-types

```python
infer_types(*, declare: bool=False) -> list[Atom]
```

Kind: `write`. Answer: `list`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_infer_types`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `declare` | `Bool` | `False` | `values` | `keyword_only` |

Guarantees result type `(host-apply (host-type metta._space list) (Atom))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Propose a `(: head (-> ...))` for every head here that has none.
>
>     m.infer_types()                 # the proposals, nothing added
>     m.infer_types(declare=True)     # add exactly those proposals
>
> One walk of the stored atoms names the narrowest kind covering the
> children observed at each argument position: all numbers `Number`,
> all strings `String`, all booleans `Bool`, all symbols `Symbol`, all
> expressions sharing one head that head's declared result type when it
> has one and `Expression` otherwise, mixed `Atom`. A variable observed
> at a position stands for anything and constrains nothing, so a
> position with only variables is `%Undefined%`. That is
> `pandas.api.types.infer_dtype` moved from a column's values to an
> argument position's children, its `skipna` included.
>
> An equation head's RESULT is what its body answers: a literal's own
> type, or the declared result of the head the body calls, which is how
> `(= (double $x) (* $x 2))` proposes `(-> %Undefined% Number)`.
> Anything else, a bare symbol included, is `%Undefined%`, because a
> symbol's own type is `%Undefined%` here too. A head observed at two
> arities gets one proposal per arity, and a head this space already
> declares gets none.
>
> `declare=True` adds exactly the returned atoms and nothing else, so
> `get-type` then answers them. One thing changes with the program's
> BEHAVIOUR and is worth reading before a proposal is accepted: `Atom`
> in an argument position is a metatype and stops the engine evaluating
> that argument, so a mixed position turns `(f (+ 1 2))` from `3` into
> the term `(+ 1 2)`. Proposing and adding are
> two calls for that reason.
>
> Cost is O(atoms x arity): one pass over the space, plus one type
> lookup per distinct head. `metta.stubs()` and `inspect.signature()`
> show the same arrows, marked inferred, without adding anything.

Evidence: `extensions/python/tests/ch09_types/test_inference.py::test_a_catalogue_row_is_not_data_about_a_head`, `extensions/python/tests/ch09_types/test_inference.py::test_a_declared_head_is_skipped`, `extensions/python/tests/ch09_types/test_inference.py::test_a_nested_call_carries_its_heads_declared_result`.

## space:doc

```python
doc(atom: Any) -> Atom
```

Kind: `introspection`. Answer: `Atom`. Effect: `readOnlyLookup`. Determinism: `det`.

Tiers: `sync`, `async`, `module`, `context`.

Implementation: `metta._space:Space._door_doc`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `atom` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `Atom` with the answer shape, effect, and determinism above.

Declared local refusals:

- `engine`: `extensions/python/tests/repository/test_door_refusals.py::test_door_refuses_a_missing_engine_answer[doc]`.

Implementation failures propagate, including failures from callees and providers.

> Return this space's structured ``get-doc`` answer for one subject.
>
> The answer is the ``(@doc ...)`` atom the engine holds for the
> subject, whether it was documented in MeTTa source or built from a
> Python docstring:
>
>     m.doc(S.area)
>     # (@doc-formal (@item area) (@kind function) (@desc "Circle area.") ...)
>
> A subject with no documentation raises, exactly as ``type`` raises
> for a subject ``get-type`` cannot answer.

Evidence: `extensions/python/tests/ch08_data/test_library_card.py::test_a_card_documents_what_the_library_documents`, `extensions/python/tests/ch09_types/test_refinements.py::test_doc_and_timezone_stay_in_the_annotation_claim`, `extensions/python/tests/ch11_python_as_a_notation/test_define.py::test_one_docstring_reaches_help_dot_doc_and_get_doc`.

## space:fn

```python
fn -> _FunctionNamespace
```

Kind: `introspection`. Answer: `value`. Effect: `readOnlyLookup`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._space:Space._door_fn`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-type metta._space _FunctionNamespace)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Functions visible here, as bound attribute or exact-name handles.
>
>     car = m.fn.car_atom
>     car(m.parse("(1 2 3)"))     # [1]
>     m.fn["=="](1, 1).one()      # True
>
> Underscores transliterate to hyphens. Brackets preserve exact
> punctuation, and an unknown name raises at access rather than
> becoming a later empty evaluation.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_fn_decodes_exactly_as_value`, `extensions/python/tests/ch10_errors_and_refusals/test_error_answers.py::test_fn_doors_split_the_same_way`, `extensions/python/tests/ch11_python_as_a_notation/test_fn_protocol.py::test_a_namespace_lists_and_resolves_only_what_its_space_can_call`.

## space:integrate

```python
integrate(target: Any) -> str
```

Kind: `provider`. Answer: `str`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_integrate`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `target` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `String` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Install a library integration; see metta.integrate.

Evidence: `extensions/python/tests/ch11_python_as_a_notation/test_integrate.py::test_a_failed_integration_restores_registry_preimages`, `extensions/python/tests/ch11_python_as_a_notation/test_integrate.py::test_a_failed_integration_unwinds_every_framework_registration`, `extensions/python/tests/ch11_python_as_a_notation/test_integrate.py::test_a_failed_outer_installation_unwinds_its_completed_dependency`.

## space:handles

```python
handles(pattern: str | Atom, fidelity: Fidelity, *, det: Determinism | None=None) -> Atom
```

Kind: `provider`. Answer: `Atom`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`.

Declared option vocabularies:

- `fidelity`: `Exact`, `Partial`, `Sound`, `Refuse`.
- `det`: `det`, `semidet`, `nondet`.

Implementation: `metta._space:Space._door_handles`, receiving `method`.

Engine binding: `metta_py_declare_handles`, wire `prolog-goal`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `pattern` | `(host-union (String Atom))` | `required` | `values` | `positional_or_keyword` |
| `fidelity` | `(host-type metta._space Fidelity)` | `required` | `values` | `positional_or_keyword` |
| `det` | `(host-union ((host-type metta._space Determinism) NoneType))` | `None` | `values` | `keyword_only` |

Guarantees result type `Atom` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Declare how faithfully a space answers queries of one shape.
>
> The declaration is one (handles ...) atom in &metta, and queries
> are routed by the most specific declared shape that matches:
> Exact licenses pushing the caller's bound to the provider, Partial
> and Sound stay candidates the engine re-unifies, and Refuse makes
> the query a loud error instead of a silent partial answer. Write
> (in $x) at a position to match only queries arriving with it
> bound, so a scan-only source is three words:
>
>     rows.handles("(edge (in $a) $b)", "Refuse")
>
> Coherence is checked eagerly in the same transaction as the
> write: a new entry that can disagree with an existing one on some
> query fails here, naming both, rather than on the first query
> that falls into their overlap. The atom is returned; removing it
> from &metta withdraws the declaration.

Evidence: `extensions/python/tests/ch20_extending_the_engine/test_contract.py::test_a_sql_backed_space_under_declared_handles`, `extensions/python/tests/ch20_extending_the_engine/test_contract.py::test_declare_handles_keeps_repeated_variables_shared`, `extensions/python/tests/ch20_extending_the_engine/test_contract.py::test_declare_handles_rejects_a_conflict_eagerly`.

## space:annotations

```python
annotations(subject_or_algebra: str, algebra: str | None=None, *, capabilities: _abc.Iterable[str]=()) -> Atom
```

Kind: `provider`. Answer: `Atom`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_annotations`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `subject_or_algebra` | `String` | `required` | `values` | `positional_or_keyword` |
| `algebra` | `(host-union (String NoneType))` | `None` | `values` | `positional_or_keyword` |
| `capabilities` | `(host-apply (host-type metta._space _abc.Iterable) (String))` | `()` | `values` | `keyword_only` |

Guarantees result type `Atom` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Declare the algebra a context's answer annotations live in.
>
> A context is a space name or an operation name. bool is the
> default at which everything vanishes; ranked admits ordered
> annotations, which is what (top k ...) consumes. A custom name must
> first be introduced with :meth:`algebra`. A one-argument call uses
> this space as the context; the two-argument form keeps an operation
> context as the explicit first subject. Capabilities are
> checked against the algebra's requirements before the catalog write;
> amplitude programs, for example, must explicitly declare ``finite``,
> ``contractive`` and ``staged``. Declaring replaces any earlier row for the
> context, so the reader never meets two disagreeing atoms.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_declare_annotations_validates_and_replaces`, `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_prov_annotations_carry_source_terms`, `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_top_orders_mixed_integer_and_float_annotations_by_value`.

## space:algebra

```python
algebra(name: str, *, combine: str, extend: str, zero: Any, one: Any, laws: _abc.Iterable[str]=(), carrier: _abc.Iterable[Any]=(), type: Any=None, requires: _abc.Iterable[str]=(), order: SemiringOrder | None=None) -> Atom
```

Kind: `provider`. Answer: `Atom`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`.

Declared option vocabularies:

- `order`: `ascending`, `descending`.

Implementation: `metta._space:Space._door_algebra`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `name` | `String` | `required` | `values` | `positional_or_keyword` |
| `combine` | `String` | `required` | `values` | `keyword_only` |
| `extend` | `String` | `required` | `values` | `keyword_only` |
| `zero` | `%Undefined%` | `required` | `values` | `keyword_only` |
| `one` | `%Undefined%` | `required` | `values` | `keyword_only` |
| `laws` | `(host-apply (host-type metta._space _abc.Iterable) (String))` | `()` | `values` | `keyword_only` |
| `carrier` | `(host-apply (host-type metta._space _abc.Iterable) (%Undefined%))` | `()` | `values` | `keyword_only` |
| `type` | `%Undefined%` | `None` | `values` | `keyword_only` |
| `requires` | `(host-apply (host-type metta._space _abc.Iterable) (String))` | `()` | `values` | `keyword_only` |
| `order` | `(host-union ((host-type metta._space SemiringOrder) NoneType))` | `None` | `values` | `keyword_only` |

Guarantees result type `Atom` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Declare operations with carrier membership and optional checked laws.
>
> ``type`` accepts a Python type, MeTTa type atom, or Boolean predicate
> and checks every input and result. A type alone grants no laws or
> fusion. ``carrier`` enumerates the finite domain required for exhaustive
> law checking; it may accompany ``type`` to constrain that domain.
> Use ``prov`` and ``.under()`` to reinterpret uncertified tensor traces.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_algebra_lifecycle.py::test_drop_retires_algebra_before_redeclaration`, `extensions/python/tests/ch04_spaces_and_matching/test_algebra_lifecycle.py::test_rollback_releases_an_algebra_mirror`, `extensions/python/tests/ch04_spaces_and_matching/test_algebra_lifecycle.py::test_rollback_restores_a_replaced_algebra_mirror`.

## space:covers

```python
covers(effect: EffectClass | str) -> Atom
```

Kind: `write`. Answer: `Atom`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`.

Declared option vocabularies:

- `effect`: `pureStructural`, `readOnlyLookup`, `nondeterministicReadOnly`, `writesState`, `oracleIO`.

Implementation: `metta._space:Space._door_covers`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `effect` | `(host-union ((host-type metta._space EffectClass) String))` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `Atom` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Declare the strongest effect this reified world can handle.
>
> Coverage is a catalog fact ``(covers <space> <effect>)``. World
> evaluation always admits pureStructural plans. A stronger joined plan
> runs only when this declaration is at least as strong; redeclaring
> replaces the previous row atomically.
>
>     orders.covers("writesState")
>     world = orders.reify()

Evidence: `extensions/python/tests/ch11_python_as_a_notation/test_arrow_products.py::test_world_coverage_uses_the_annotated_effect`, `extensions/python/tests/ch15_writing_transactions_and_worlds/test_worlds.py::test_a_closed_world_releases_its_plan_image`, `extensions/python/tests/ch15_writing_transactions_and_worlds/test_worlds.py::test_a_collected_world_does_not_take_the_name_a_live_mint_released`.

## space:compensates

```python
compensates(operation: str, compensation: str) -> Atom
```

Kind: `write`. Answer: `Atom`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_compensates`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `operation` | `String` | `required` | `values` | `positional_or_keyword` |
| `compensation` | `String` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `Atom` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Declare one recovery operation for an effectful operation.
>
> The catalog row is ``(compensates operation compensation)``. The
> source operation must already be registered at writesState or
> oracleIO, because weaker operations leave no saga receipt. The
> recovery name must already be a host operation or compiled MeTTa
> function. It receives the complete ``(did ...)`` receipt. The runner writes
> the call as ``(quote <receipt>)`` so the receipt is not evaluated
> on the way in; the quote is a barrier and does not survive, so the
> handler is handed the receipt itself.
> Redeclaring replaces the old row atomically.

Evidence: `extensions/python/tests/ch15_writing_transactions_and_worlds/test_saga.py::test_a_refused_recovery_receipt_still_compensates_the_effect_it_could_not_record`, `extensions/python/tests/ch15_writing_transactions_and_worlds/test_saga.py::test_saga_compensates_in_reverse_commit_order`, `extensions/python/tests/ch15_writing_transactions_and_worlds/test_saga.py::test_a_discarded_step_runs_no_compensation`.

## space:add-tagged-fact

```python
add_tagged_fact(tag: Any, proposition: Any) -> Atom
```

Kind: `write`. Answer: `Atom`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_add_tagged_fact`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `tag` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |
| `proposition` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `Atom` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Store ``(fact tag proposition)``, the normative annotation form.

Evidence: `extensions/python/tests/ch18_performance/test_algebra_rates.py::test_invalid_rates_are_refused_before_the_tagged_fact_lands`, `extensions/python/tests/ch06_many_answers/test_under_algebra.py::test_tagged_call_answers_use_the_carrier_without_hijacking_other_calls`, `extensions/python/tests/ch06_many_answers/test_under_algebra.py::test_tagged_derivations_flow_through_match_and_reinterpret_without_requery`.

## space:add-tagged-rule

```python
add_tagged_rule(tag: Any, head: Any, *premises: Any) -> Atom
```

Kind: `write`. Answer: `Atom`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_add_tagged_rule`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `tag` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |
| `head` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |
| `premises` | `%Undefined%` | `required` | `values` | `var_positional` |

Guarantees result type `Atom` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Store one rule generated by the algebra-agnostic tag threader.

Evidence: `extensions/python/tests/ch06_many_answers/test_under_algebra.py::test_tagged_derivations_flow_through_match_and_reinterpret_without_requery`, `extensions/python/tests/ch14_seeing_your_program/test_features.py::test_tagged_algebra_debits_inferences_across_operations`, `extensions/python/tests/ch14_seeing_your_program/test_features.py::test_tagged_algebra_forwards_bounds_to_every_evaluating_door`.

## space:image

```python
image(type_name: str, setting: ImageMode) -> Atom
```

Kind: `write`. Answer: `Atom`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`.

Declared option vocabularies:

- `setting`: `opaque`, `transparent`, `auto`.

Implementation: `metta._space:Space._door_image`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `type_name` | `String` | `required` | `values` | `positional_or_keyword` |
| `setting` | `(host-type metta._space ImageMode)` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `Atom` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Choose how one Python type crosses one context boundary.
>
> opaque carries the live object by identity; transparent projects its
> structural MeTTa image; auto makes that choice from the value's size
> and replayability. A later declaration for the same context and type
> replaces the earlier one, so an attached provider reads one policy.
> Use ``_`` as the type name for a context-wide fallback.

Evidence: `extensions/python/ext/metta-pydantic/tests/test_pydantic.py::test_the_row_is_registered_against_the_image_point`, `extensions/python/tests/ch11_python_as_a_notation/test_integrate.py::test_a_failed_integration_restores_registry_preimages`, `extensions/python/tests/ch20_extending_the_engine/test_catalog_kinds.py::test_the_image_declaration_is_catalog_validated`.

## space:sample

```python
sample(query: str | Atom, *, k: int=10, seed: int=7) -> list[Atom]
```

Kind: `evaluation`. Answer: `list`. Effect: `oracleIO`. Determinism: `nondet`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_sample`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `query` | `(host-union (String Atom))` | `required` | `values` | `positional_or_keyword` |
| `k` | `Number` | `10` | `values` | `keyword_only` |
| `seed` | `Number` | `7` | `values` | `keyword_only` |

Guarantees result type `(host-apply (host-type metta._space list) (Atom))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Choose ``k`` tagged alternatives with replacement by ``(rate n)``.
>
> The argument names and list result follow ``random.choices``. A local
> seeded generator makes repeated calls reproducible without changing
> Python's process-global random state.

Evidence: `extensions/python/tests/ch06_many_answers/test_under_algebra.py::test_space_sample_is_seeded_and_uses_k_vocabulary`, `extensions/python/tests/ch18_performance/test_algebra_rates.py::test_declared_rates_make_seeded_selection_match_their_distribution`.

## space:consumption

```python
consumption(kind: SourceKind) -> Atom
```

Kind: `write`. Answer: `Atom`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`.

Declared option vocabularies:

- `kind`: `linear`, `repeated`, `peek`.

Implementation: `metta._space:Space._door_consumption`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `kind` | `(host-type metta._space SourceKind)` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `Atom` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Declare a space's consumption discipline.
>
> repeated is the default: the source re-enumerates. linear is a
> one-shot source, a cursor or a feed: its SECOND consumption is a
> loud error naming the space, where the undeclared floor answers a
> silently empty set from the drained object; re-registering the
> provider resets the mark, because a fresh provider is a fresh
> source. peek promises reads do not consume, which the conformance
> kit checks by enumerating twice. The Python door is named
> ``consumption`` so ``source()`` can show program text; the MeTTa
> catalog row deliberately keeps its language-level ``source`` head.

Evidence: `extensions/python/tests/ch20_extending_the_engine/test_contract.py::test_a_linear_source_refuses_its_second_consumption`, `extensions/python/tests/ch20_extending_the_engine/test_contract.py::test_consumption_validates`, `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_explain_answers_the_route_and_the_route_is_honest`.

## space:on-error

```python
on_error(subject_or_pattern: str | Atom, pattern_or_mode: str | Atom, mode: OnError | None=None) -> Atom
```

Kind: `write`. Answer: `Atom`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`.

Declared option vocabularies:

- `mode`: `keep`, `empty`, `abort`.

Implementation: `metta._space:Space._door_on_error`, receiving `method`.

Engine binding: `metta_py_add`, wire `prolog-goal`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `subject_or_pattern` | `(host-union (String Atom))` | `required` | `values` | `positional_or_keyword` |
| `pattern_or_mode` | `(host-union (String Atom))` | `required` | `values` | `positional_or_keyword` |
| `mode` | `(host-union ((host-type metta._space OnError) NoneType))` | `None` | `values` | `positional_or_keyword` |

Guarantees result type `Atom` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Declare what a context's failure becomes, per query shape.
>
> abort is the undeclared floor: the provider's error propagates.
> keep delivers the failure as one (Error &lt;query> &lt;reason>) answer
> beside the answers that already streamed, the language's own
> error-as-alternative reading. empty ends the stream silently, BY
> declaration, which is what separates it from a swallowed error.
> Shapes route most-specific-first exactly as (handles ...) entries
> do. Control signals and transport failures are never kept or
> emptied: an interrupt is the caller's, and an absent backend has
> said nothing about the data.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_declare_on_error_validates`, `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_an_op_keeps_its_failure_as_the_error_atom`, `extensions/python/tests/ch11_python_as_a_notation/test_ops.py::test_relational_candidate_shape_errors_are_contract_errors`.

## space:merge

```python
merge(pattern: str | Atom, policy: AnswerPolicy) -> Atom
```

Kind: `write`. Answer: `Atom`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`.

Declared option vocabularies:

- `policy`: `depth`, `fair`, `best-first`.

Implementation: `metta._space:Space._door_merge`, receiving `method`.

Engine binding: `metta_py_add`, wire `prolog-goal`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `pattern` | `(host-union (String Atom))` | `required` | `values` | `positional_or_keyword` |
| `policy` | `(host-type metta._space AnswerPolicy)` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `Atom` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Declare how the engine merges one query shape's answers
> ACROSS contexts, for the multi-context idiom
> (match (superpose (&a &b)) ...).
>
> depth is today's space-after-space order and the undeclared
> floor. fair interleaves the streams round-robin. best-first is a
> k-way ordered merge by annotation, sound only when every merged
> context declares (emits &lt;ctx> best-first), and loudly refused
> without. Shapes route most-specific-first as everywhere.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_a_best_first_merge_orders_across_contexts`, `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_a_declared_fair_merge_interleaves`, `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_declare_merge_validates`.

## space:context

```python
context(world: World) -> Atom
```

Kind: `write`. Answer: `Atom`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`.

Declared option vocabularies:

- `world`: `closed-world`, `open-world`.

Implementation: `metta._space:Space._door_context`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `world` | `(host-type metta._space World)` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `Atom` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Record what a space's absence means.
>
> Negation as failure reads absence as falsity, which is only
> sound over a world the answerer holds whole, so a negated goal
> may consult a foreign space only when it declares closed-world;
> an undeclared one refuses under negation loudly. Native spaces
> are the engine's own database and closed by construction.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_declare_context_validates`, `extensions/python/ext/metta-otel/tests/test_otel.py::test_spans_nest_by_the_events_own_depth`, `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_explain_answers_the_route_and_the_route_is_honest`.

## space:agenda

```python
agenda(policy: AgendaPolicy, function: str | None=None) -> Atom
```

Kind: `write`. Answer: `Atom`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`.

Declared option vocabularies:

- `policy`: `declaration`, `recency`, `specificity`, `priority`, `user`.

Implementation: `metta._space:Space._door_agenda`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `policy` | `(host-type metta._space AgendaPolicy)` | `required` | `values` | `positional_or_keyword` |
| `function` | `(host-union (String NoneType))` | `None` | `values` | `positional_or_keyword` |

Guarantees result type `Atom` with the answer shape, effect, and determinism above.

Declared local refusals:

- `value`: `extensions/python/tests/repository/test_door_refusals.py::test_door_value_refusals[space:agenda]`.

Implementation failures propagate, including failures from callees and providers.

> Declare which reaction fires first when several match one write.
>
> declaration is the default and the order they were declared, which is
> what the engine produced by accident before this was a policy;
> recency is the most recently declared first; specificity is the most
> tests in the pattern first; priority reads each reaction's own
> declared number, highest first; and user names a MeTTa function that
> SCORES a reaction, highest first. Every policy breaks ties on
> declaration order.
>
>     alarms.reacts("(alert $w)", "(insert &log (all $w))")
>     alarms.reacts("(alert fire)", "(insert &log (fire))", priority=9)
>     alarms.agenda("priority")

Evidence: `extensions/python/tests/ch15_writing_transactions_and_worlds/test_worlds.py::test_every_declaration_door_removes_every_stale_duplicate`.

## space:reacts

```python
reacts(pattern: str | Atom, operation: str | Atom, priority: int | None=None) -> Atom
```

Kind: `write`. Answer: `Atom`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_reacts`, receiving `method`.

Engine binding: `metta_install_bridges`, wire `prolog-goal`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `pattern` | `(host-union (String Atom))` | `required` | `values` | `positional_or_keyword` |
| `operation` | `(host-union (String Atom))` | `required` | `values` | `positional_or_keyword` |
| `priority` | `(host-union (Number NoneType))` | `None` | `values` | `positional_or_keyword` |

Guarantees result type `Atom` with the answer shape, effect, and determinism above.

Declared local refusals:

- `type`: `extensions/python/tests/repository/test_door_refusals.py::test_door_type_refusals[space:reacts]`.

Implementation failures propagate, including failures from callees and providers.

> Declare a reaction, stored as an (on ...) atom: when an atom
> matching PATTERN lands in the space, OPERATION runs under the
> match's bindings.
>
> The managed heads are (insert &lt;ctx> &lt;atom>), (retract &lt;ctx>
> &lt;atom>) and (revise &lt;ctx> &lt;old> &lt;new>), engine-routed rules
> going through the same write paths as direct writes. Declaring
> installs the engine's write hook, which is why reactions go
> through here or metta_install_bridges rather than a bare
> add-atom.
>
> A subscription bridge is the NEIGHBOUR, not a special case of this:
> a reaction's operation runs engine-side, so it reaches registered
> spaces, while the bridge rule delivers Python-side to anything
> with add and remove, an unregistered or remote target included.
> Same multi-context-systems idea, two delivery tiers.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_a_bridge_cascade_is_bounded`, `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_a_bridge_inserts_under_the_matched_bindings`, `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_a_revise_bridge_replaces`.

## space:admits

```python
admits(type_name: str) -> Atom
```

Kind: `write`. Answer: `Atom`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_admits`, receiving `method`.

Engine binding: `metta_admission_claim`, wire `prolog-goal`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `type_name` | `String` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `Atom` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Type a pool's membership: only TYPE-carrying atoms enter.
>
> A thread pool is a space whose atoms are spaces, and this is its
> declaration: (admits &pool Space) plus per-atom (: &lt;space> Space)
> declarations make membership a type judgement the ontology
> already knows how to make.

Evidence: `extensions/python/tests/ch15_writing_transactions_and_worlds/test_admission_routes.py::test_relative_admits_declaration_installs_the_receiver_contract`, `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_admission_is_sugar_over_the_pre_add_hook`, `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_admission_types_the_pool`.

## space:capacity

```python
capacity(limit: int) -> Atom
```

Kind: `write`. Answer: `Atom`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`.

Implementation: `metta._space:Space._door_capacity`, receiving `method`.

Engine binding: `metta_admission_claim`, wire `prolog-goal`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `limit` | `Number` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `Atom` with the answer shape, effect, and determinism above.

Declared local refusals:

- `value`: `extensions/python/tests/repository/test_door_refusals.py::test_door_value_refusals[space:capacity]`.

Implementation failures propagate, including failures from callees and providers.

> Bound a pool: an add beyond LIMIT atoms is refused loudly.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_capacity_bounds_the_pool`, `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_declare_capacity_validates`, `extensions/python/tests/ch15_writing_transactions_and_worlds/test_admission_routes.py::test_relative_capacity_declaration_installs_the_receiver_contract`.

## space:atomicity

```python
atomicity(atomicity: Atomicity) -> Atom
```

Kind: `write`. Answer: `Atom`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`.

Declared option vocabularies:

- `atomicity`: `transactional`, `atomic-single`, `best-effort`.

Implementation: `metta._space:Space._door_atomicity`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `atomicity` | `(host-type metta._space Atomicity)` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `Atom` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Declare what a space's writes promise inside a transaction.
>
> Named for what it declares rather than for the atom it stores, which
> stays `(writes <ctx> ...)`: `writes` on a Space is the effect
> decorator for an OPERATION, and one object cannot spell two concepts
> one way.
>
> transactional providers implement metta.foreign.Transactional and
> are committed or rolled back WITH the engine's transaction;
> best-effort is the author's declared acceptance of a write that
> survives a rollback; atomic-single refuses transactional writes.
> Undeclared spaces refuse them loudly too, because a foreign write
> silently surviving a rolled-back transaction is the wrong answer
> the declaration exists to replace.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_a_failed_file_transaction_rolls_a_foreign_provider_back`, `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_a_failed_transaction_rolls_both_stores_back`, `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_a_file_transaction_enlists_and_commits_a_foreign_provider`.

## space:emits

```python
emits(policy: AnswerPolicy) -> Atom
```

Kind: `write`. Answer: `Atom`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`, `async`.

Declared option vocabularies:

- `policy`: `depth`, `fair`, `best-first`.

Implementation: `metta._space:Space._door_emits`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `policy` | `(host-type metta._space AnswerPolicy)` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `Atom` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Declare the order a context emits its own answers in.
>
> best-first is the promise (top k ...) needs before its bound may
> reach the provider: the first k of a best-first emission ARE the
> k best. Distinct from the (merge &lt;pattern> &lt;policy>) strategy,
> which is how the ENGINE merges answers across several contexts.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_declare_emits_validates`, `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_a_best_first_merge_orders_across_contexts`, `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_top_pushes_the_bound_under_three_declarations`.

## space:events

```python
events(delivery: Delivery | None=None, order: EventOrder=EventOrder.unordered) -> Atom | Any
```

Kind: `write`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `async`.

Declared option vocabularies:

- `delivery`: `at-most-once`, `at-least-once`, `per-write-exactly`.
- `order`: `ordered`, `unordered`.

Implementation: `metta._space:Space._door_events`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `delivery` | `(host-union ((host-type metta._space Delivery) NoneType))` | `None` | `values` | `positional_or_keyword` |
| `order` | `(host-type metta._space EventOrder)` | `EventOrder.unordered` | `values` | `positional_or_keyword` |

Guarantees result type `(host-union (Atom %Undefined%))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Return the event stream, or declare what this context promises.
>
> Subscribability is a promise about the context, not something its
> methods alone establish. A native space needs no declaration:
> every write into it runs the engine's own hooks, so it delivers
> per-write-exactly and ordered by construction. A FOREIGN context
> declares, and one that declares nothing refuses a subscription
> instead of serving one that silently misses writes.
>
>     shared.events("at-most-once")   # redis pub/sub
>     mirror.events("per-write-exactly", "ordered")
>
> delivery is at-most-once, at-least-once or per-write-exactly, and
> order is ordered or unordered, defaulting to unordered because an
> omitted promise is the weaker one. A Python provider says the same
> thing by overriding delivers(), which registration writes here.

Evidence: `extensions/python/tests/ch14_seeing_your_program/test_features.py::test_events_delivers_leftovers_queued_before_cancel`, `extensions/python/tests/ch14_seeing_your_program/test_features.py::test_events_times_out_quiet_and_refuses_callback_mode`, `extensions/python/tests/ch14_seeing_your_program/test_features.py::test_subscription_is_a_context_manager_and_events_stream`.

## space:runtime

```python
runtime -> Runtime
```

Kind: `introspection`. Answer: `value`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._space:Space._door_runtime`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-type metta._space Runtime)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> The engine bridge itself, for callers going under the surface.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_space_identity_doors_follow_the_handle_lifetime`.

## space:metta

```python
metta -> MeTTa
```

Kind: `introspection`. Answer: `value`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._space:Space._door_metta`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-type metta._space MeTTa)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> The owning evaluation context, so a handle can reach every
> context-level method: ``m.metta.space(S.kb)`` creates a sibling space
> in THIS handle's own context rather than the process default, which
> is the creation method the twins' known-issue asked for. The context
> BORROWS this handle's space as its home, so answering it mints
> nothing, and two answers compare equal because they share the
> runtime and the home.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_space_identity_doors_follow_the_handle_lifetime`.

## space:alpha

```python
alpha(other: Any) -> Expression
```

Kind: `introspection`. Answer: `Atom`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._atoms_core:Atom.alpha`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `other` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `Expression` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> The alpha-equality TERM, (=alpha self other); alpha_eq answers now.
>
> The nearest-relative spelling of the head whose `=` marker Python
> cannot carry, exactly as eq() spells ==; compiled bodies write the
> same test as a bare alpha(x, y) call, and fn["=alpha"] stays the
> exact form.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_inherited_atom_doors_remain_declared`.

## space:alpha-eq

```python
alpha_eq(other: Atom) -> bool
```

Kind: `introspection`. Answer: `bool`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._atoms_core:Atom.alpha_eq`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `other` | `Atom` | `required` | `atoms` | `positional_or_keyword` |

Guarantees result type `Bool` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Whether two atoms differ only by consistent variable renaming.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_inherited_atom_doors_remain_declared`.

## space:args

```python
args -> tuple[Atom, ...]
```

Kind: `introspection`. Answer: `tuple`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._atoms_core:Atom.args`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-apply (host-type metta._atoms_core tuple) (Atom ...))` with the answer shape, effect, and determinism above.

Declared local refusals:

- `type`: `extensions/python/tests/repository/test_door_refusals.py::test_door_type_refusals[space:args]`.

Implementation failures propagate, including failures from callees and providers.

> Read Space.args.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_inherited_atom_doors_remain_declared`.

## space:children

```python
children -> tuple[Atom, ...]
```

Kind: `introspection`. Answer: `tuple`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._atoms_core:Atom.children`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-apply (host-type metta._atoms_core tuple) (Atom ...))` with the answer shape, effect, and determinism above.

Declared local refusals:

- `type`: `extensions/python/tests/repository/test_door_refusals.py::test_door_type_refusals[space:children]`.

Implementation failures propagate, including failures from callees and providers.

> Read Space.children.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_inherited_atom_doors_remain_declared`.

## space:eq

```python
eq(other: Any) -> Expression
```

Kind: `introspection`. Answer: `Atom`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._atoms_core:Atom.eq`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `other` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `Expression` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> The equality TERM, (== self other); == itself compares atoms.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_inherited_atom_doors_remain_declared`.

## space:ge

```python
ge(other: Any) -> Expression
```

Kind: `introspection`. Answer: `Atom`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._atoms_core:Atom.ge`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `other` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `Expression` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> The greater-or-equal TERM, (>= self other).

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_inherited_atom_doors_remain_declared`.

## space:gt

```python
gt(other: Any) -> Expression
```

Kind: `introspection`. Answer: `Atom`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._atoms_core:Atom.gt`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `other` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `Expression` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> The strictly-greater TERM, (> self other).

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_inherited_atom_doors_remain_declared`.

## space:head

```python
head -> Atom | None
```

Kind: `introspection`. Answer: `Atom`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._atoms_core:Atom.head`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-union (Atom NoneType))` with the answer shape, effect, and determinism above.

Declared local refusals:

- `type`: `extensions/python/tests/repository/test_door_refusals.py::test_door_type_refusals[space:head]`.

Implementation failures propagate, including failures from callees and providers.

> Read Space.head.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_inherited_atom_doors_remain_declared`.

## space:le

```python
le(other: Any) -> Expression
```

Kind: `introspection`. Answer: `Atom`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._atoms_core:Atom.le`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `other` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `Expression` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> The less-or-equal TERM, (&lt;= self other).

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_inherited_atom_doors_remain_declared`.

## space:lt

```python
lt(other: Any) -> Expression
```

Kind: `introspection`. Answer: `Atom`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._atoms_core:Atom.lt`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `other` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `Expression` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> The strictly-less TERM, (&lt; self other).

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_inherited_atom_doors_remain_declared`.

## space:map

```python
map(transform: Callable[[Atom], Atom]) -> Atom
```

Kind: `introspection`. Answer: `Atom`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._atoms_core:Atom.map`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `transform` | `(host-apply (host-type metta._atoms_core Callable) ((Atom) Atom))` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `Atom` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Transform every node, children before parents, without recursion.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_inherited_atom_doors_remain_declared`.

## space:ne

```python
ne(other: Any) -> Expression
```

Kind: `introspection`. Answer: `Atom`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._atoms_core:Atom.ne`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `other` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `Expression` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Read Space.ne.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_inherited_atom_doors_remain_declared`.

## space:subs

```python
subs(bindings: Mapping[Atom, Any] | Any) -> Atom
```

Kind: `introspection`. Answer: `Atom`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._atoms_core:Atom.subs`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `bindings` | `(host-union ((host-apply (host-type metta._atoms_core Mapping) (Atom %Undefined%)) %Undefined%))` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `Atom` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Replace each atom the bindings name, everywhere it occurs.
>
>     pattern = S.job(V.who, V.rank)
>     pattern.subs(pattern.unify(S.job(S.ada, 9)))   # (job ada 9)
>     S.hired(V.who).subs(space.match(pattern)[0])   # (hired ada)
>     S.greet(S.name).subs({S.name: "ada"})          # (greet "ada")
>
> The KEY says what is being replaced, so a variable hole and a
> placeholder symbol are different substitutions rather than one
> ambiguous string. ``unify`` produces variable keys; a ``bind()`` scope
> at the evaluation methods accepts either.
>
> An answer ``Row`` is accepted directly, because its columns ARE the
> query's variable names. It is the library's other producer of
> bindings, and it could not be fed back either.
>
> Sugar over :meth:`map`, which stays available as the lower-level method:
> this is ``atom.map(lambda item: bindings.get(item, item))`` with the
> keys and values encoded. Nothing consumed a substitution before this,
> so both producers answered in a currency the library did not accept,
> and two tests had written the recursive walk by hand.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_inherited_atom_doors_remain_declared`.

## space:unify

```python
unify(other: Atom, *more: Atom) -> Mapping[Atom, Atom] | None
```

Kind: `introspection`. Answer: `mapping`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._atoms_core:Atom.unify`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `other` | `Atom` | `required` | `atoms` | `positional_or_keyword` |
| `more` | `Atom` | `required` | `atoms` | `var_positional` |

Guarantees result type `(host-union ((host-apply (host-type metta._atoms_core Mapping) (Atom Atom)) NoneType))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Unify with the others, returning bindings or ``None``.
>
> Variadic means SIMULTANEOUS: every operand must agree under ONE
> substitution, folded through one shared binding store, so several
> rule heads unify at once the way two always did. The keys are the
> VARIABLES themselves, which is the currency :meth:`subs` accepts,
> so ``template.subs(pattern.unify(fact))`` is the round trip. They
> were plain names once, and a name cannot say whether it means a
> variable or a symbol in a language that has both.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_inherited_atom_doors_remain_declared`.

## space:vars

```python
vars -> tuple[Variable, ...]
```

Kind: `introspection`. Answer: `tuple`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._atoms_core:Atom.vars`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-apply (host-type metta._atoms_core tuple) (Variable ...))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> The variables in first-appearance order; none means ground.
>
> The variables THEMSELVES, not their names, so what this answers is
> what :meth:`subs` and :meth:`unify` accept and a round trip composes:
> ``template.subs(dict(zip(pattern.vars, values)))``. Names were what it
> answered once, and a name cannot say whether it means a variable or a
> symbol on a surface that has both. ``not atom.vars`` still reads
> "ground", because an empty tuple is still empty.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_inherited_atom_doors_remain_declared`.

## context:close

```python
close() -> None
```

Kind: `lifecycle`. Answer: `None`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._space:MeTTa._door_close`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `NoneType` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Release the context's own home space; closing twice is a no-op.
>
> A borrowed home, the process default included, is the caller's
> and survives; only a home this context minted is dropped, and the
> drop takes the whole world with it: every space minted inside the
> context, by this object or by the program's own new-space, is
> released first, since it read the home's equations and cannot
> outlive it. A space the program declared with (inherits ...) still
> refuses, naming the heir, because that relationship is the
> program's own.
>
> What a context OPENED by name it borrows and leaves alone, the way
> it leaves a borrowed home alone: ``m.space("&kb")`` may be a space
> that already existed, that another context is reading, or that the
> engine owns, and closing a reader is not how any of those end.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_drop_recovery.py::test_backing_close_failure_keeps_the_name_and_cleanup_retryable`, `extensions/python/tests/ch04_spaces_and_matching/test_space.py::test_a_borrowed_home_survives_close`, `extensions/python/tests/ch04_spaces_and_matching/test_space.py::test_a_context_close_leaves_a_named_space_it_only_opened`.

## context:closed

```python
closed -> bool
```

Kind: `lifecycle`. Answer: `bool`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._space:MeTTa._door_closed`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `Bool` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Whether :meth:`close` has released this context's own home.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_space_identity_doors_follow_the_handle_lifetime`.

## context:self

```python
self -> Space
```

Kind: `introspection`. Answer: `space`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._space:MeTTa._door_self`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `SpaceType` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> The context's home space handle, its own ``&self``.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_space_identity_doors_follow_the_handle_lifetime`.

## context:runtime

```python
runtime -> Runtime
```

Kind: `introspection`. Answer: `value`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._space:MeTTa._door_runtime`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-type metta._space Runtime)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> The engine bridge itself, for callers going under the surface.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_space_identity_doors_follow_the_handle_lifetime`.

## context:info

```python
info() -> dict[str, str | None]
```

Kind: `introspection`. Answer: `mapping`. Effect: `readOnlyLookup`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._space:MeTTa._door_info`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-apply (host-type metta._space dict) (String (host-union (String NoneType))))` with the answer shape, effect, and determinism above.

Declared local refusals:

- `engine`: `extensions/python/tests/repository/test_door_refusals.py::test_info_refuses_an_unreported_engine_version`.

Implementation failures propagate, including failures from callees and providers.

> Return backend versions and the consulted MeTTa runtime tree.

Evidence: `extensions/python/tests/ch01_getting_started/test_backend_info.py::test_backend_info_reports_versions_and_consulted_tree`.

## context:lock

```python
lock() -> Lock
```

Kind: `introspection`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._space:MeTTa._door_lock`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-type metta._space Lock)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Pin the knowledge this context has loaded, as a `Lock`.
>
>     m.load("kb/facts.metta")
>     m.lock().write("metta.lock")
>     python -m metta lock kb/facts.metta -o metta.lock
>
> One `[[library]]` row per shipped library imported, one `[]`
> row per other file loaded with the space it landed in, one `[[pin]]`
> row per repository revision acquired, and an `[engine]` table naming
> this build and a digest over its own sources: what a second machine
> needs to load exactly this program. `metta.Lock.read` reads one back
> and :meth:`check` says what a tree no longer matches.
>
> The scope is the PROCESS, not this context. The engine's loads,
> registrations and git pins are process-wide, and a program that loads
> knowledge into `&kb` from one place and reads it from another is one
> program; a lock naming only one context's own loads would omit the
> rest of what has to be reproduced. Two contexts in one process
> therefore take the same lock.
>
> A lock taken while a source is still loading is refused, because it
> would record a program that is only half there.

Evidence: `extensions/python/tests/ch01_getting_started/test_lock.py::test_a_drifted_engine_names_the_field_that_moved`, `extensions/python/tests/ch01_getting_started/test_lock.py::test_a_lock_drift_refusal_names_every_entry_and_its_repair`, `extensions/python/tests/ch01_getting_started/test_lock.py::test_a_lock_is_readable_toml_with_the_documented_tables`.

## context:check

```python
check(lock: Lock) -> list[Drift]
```

Kind: `introspection`. Answer: `list`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._space:MeTTa._door_check`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `lock` | `(host-type metta._space Lock)` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `(host-apply (host-type metta._space list) ((host-type metta._space Drift)))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Every entry of a lock this tree no longer matches, as `Drift` rows.
>
>     for drift in m.check(metta.Lock.read("metta.lock")):
>         print(drift)
>
> An empty list is agreement. Nothing is loaded to answer it: each entry
> names something on disk, so the answer is what a fresh process would
> find rather than what this one happens to hold. `metta run --locked`
> is the same check with a refusal instead of a list.

Evidence: `extensions/python/tests/ch01_getting_started/test_lock.py::test_a_drifted_engine_names_the_field_that_moved`, `extensions/python/tests/ch01_getting_started/test_lock.py::test_a_lock_round_trips_through_its_file`, `extensions/python/tests/ch01_getting_started/test_lock.py::test_a_removed_source_drifts_as_not_present`.

## context:space

```python
space(name: str | Symbol | Expression | Space | None=None, backing: Any=None, *, inherits: Space | None=None, restricted: bool=False, grants: _abc.Iterable[str]=(), journal: str | os.PathLike[str] | None=None, schema: _abc.Mapping[str, Any] | None=None, sync: JournalSync=JournalSync.none, rename: _abc.Mapping[str, str] | None=None, _created_at: tuple[str, int] | None=None) -> Space
```

Kind: `lifecycle`. Answer: `space`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Declared option vocabularies:

- `sync`: `none`, `flush`, `close`.

Implementation: `metta._space:MeTTa._door_space`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `name` | `(host-union ((host-union ((host-union ((host-union (String Symbol)) Expression)) SpaceType)) NoneType))` | `None` | `values` | `positional_or_keyword` |
| `backing` | `%Undefined%` | `None` | `values` | `positional_or_keyword` |
| `inherits` | `(host-union (SpaceType NoneType))` | `None` | `atoms` | `keyword_only` |
| `restricted` | `Bool` | `False` | `values` | `keyword_only` |
| `grants` | `(host-apply (host-type metta._space _abc.Iterable) (String))` | `()` | `values` | `keyword_only` |
| `journal` | `(host-union ((host-union (String (host-apply (host-type metta._space os.PathLike) (String)))) NoneType))` | `None` | `values` | `keyword_only` |
| `schema` | `(host-union ((host-apply (host-type metta._space _abc.Mapping) (String %Undefined%)) NoneType))` | `None` | `values` | `keyword_only` |
| `sync` | `(host-type metta._space JournalSync)` | `JournalSync.none` | `values` | `keyword_only` |
| `rename` | `(host-union ((host-apply (host-type metta._space _abc.Mapping) (String String)) NoneType))` | `None` | `values` | `keyword_only` |
| `_created_at` | `(host-union ((host-apply (host-type metta._space tuple) (String Number)) NoneType))` | `None` | `values` | `keyword_only` |

Guarantees result type `SpaceType` with the answer shape, effect, and determinism above.

Declared local refusals:

- `type`: `extensions/python/tests/repository/test_door_refusals.py::test_door_type_refusals[context:space]`.

Implementation failures propagate, including failures from callees and providers.

> Create one native, provider-backed, remote, or journaled space.
>
> The BACKING value derives the implementation, so the common calls
> carry no options at all: with no name the engine mints an anonymous
> handle; a ``Space`` reopens that same space, which is what an engine
> answer naming one arrives as; a ``SpaceProvider`` backing is
> attached directly; an HTTP(S) URL becomes a remote provider (build
> the transport with ``metta.remote.connect`` when it needs a token,
> headers, or its own timeout, and hand THAT in as the backing); and
> ``journal=`` constructs ``PersistentFactSpace`` from ``schema=`` or
> a schema mapping supplied as the backing. ``sync`` paces the
> journal and ``rename`` performs its one-open schema migration; neither
> means anything without ``journal``, so either refuses alone.
>
> ``inherits``, ``restricted`` and ``grants`` choose the space MODEL and
> are independent of whether the space is named. MeTTa's own
> ``!(new-space &locked (restricted))`` names a restricted space, and
> ``metta.space(S.locked, restricted=True)`` is that call. Declaring a
> model on a name that already carries the same one is a no-op; a
> different one raises, because a space cannot have two models.
>
> The context OWNS what it mints and BORROWS what it opens by name:
> :meth:`close` releases the anonymous mints and leaves ``&kb``,
> ``&metta`` and every other named space exactly as it found them,
> whether or not the handle is still referenced.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_space.py::test_a_context_owns_and_releases_its_minted_home`, `extensions/python/tests/repository/test_door_rows.py::test_remote_storage_doors_use_the_declared_operation_protocol`.

## context:fn

```python
fn -> _FunctionNamespace
```

Kind: `introspection`. Answer: `value`. Effect: `readOnlyLookup`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._space:MeTTa._door_fn`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-type metta._space _FunctionNamespace)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> The bound function namespace of this context's self space.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_answer_protocol.py::test_fn_decodes_exactly_as_value`, `extensions/python/tests/ch10_errors_and_refusals/test_error_answers.py::test_fn_doors_split_the_same_way`, `extensions/python/tests/ch11_python_as_a_notation/test_fn_protocol.py::test_a_namespace_lists_and_resolves_only_what_its_space_can_call`.

## context:unregister-op

```python
unregister_op(name: str) -> None
```

Kind: `provider`. Answer: `None`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._space:MeTTa._door_unregister_op`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `name` | `String` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `NoneType` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Release an operation installed through :meth:`op`.

Evidence: `extensions/python/tests/ch11_python_as_a_notation/test_adoptions.py::test_shared_class_declarations_survive_one_unregister`, `extensions/python/tests/ch11_python_as_a_notation/test_ops.py::test_unregistering_a_name_a_system_predicate_shares_does_not_throw`, `extensions/python/tests/ch20_extending_the_engine/test_contract.py::test_unregister_removes_the_effect_atom_with_the_op_facts`.

## context:capture

```python
capture() -> CapturedOutput
```

Kind: `scope`. Answer: `context`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._space:MeTTa._door_capture`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-type metta._space CapturedOutput)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Capture printed engine text across this context.

Evidence: `extensions/python/tests/ch14_seeing_your_program/test_features.py::test_capture_composes_with_limits`, `extensions/python/tests/ch14_seeing_your_program/test_features.py::test_eval_capture`, `extensions/python/tests/ch14_seeing_your_program/test_features.py::test_lazy_capture_collects_held_engine_output`.

## context:atomic

```python
atomic() -> ScopedExecution
```

Kind: `scope`. Answer: `context`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._space:MeTTa._door_atomic`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-type metta._space ScopedExecution)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Scope source execution to committing transactions.

Evidence: `extensions/python/tests/ch14_seeing_your_program/test_features.py::test_an_atomic_scope_makes_one_python_write_one_transaction`, `extensions/python/tests/ch14_seeing_your_program/test_features.py::test_atomic_run_commits_or_rolls_back_whole`, `extensions/python/tests/ch14_seeing_your_program/test_features.py::test_lazy_atomic_rolls_back_after_a_late_cursor_failure`.

## context:transaction

```python
@overload
transaction(target: Callable[[], _R], /) -> _R
@overload
transaction(target: Atom | str, /) -> list[Atom | Undefined]
transaction(target: Any, /) -> Any
```

Kind: `scope`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._space:MeTTa._door_transaction`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `target` | `%Undefined%` | `required` | `values` | `positional_only` |

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Run one callable or term in an engine transaction.

Evidence: `extensions/python/tests/ch11_python_as_a_notation/test_ladder.py::test_batch_composes_with_transaction`, `extensions/python/tests/ch11_python_as_a_notation/test_r5_unbuilt_doors.py::test_transaction_term_uses_empty_answer_rollback_law`, `extensions/python/tests/ch15_writing_transactions_and_worlds/test_saga.py::test_saga_refuses_transaction_speculation_and_batch_boundaries`.

## context:register-prolog

```python
register_prolog(*args: Any, **kwargs: Any) -> tuple[str, ...]
```

Kind: `provider`. Answer: `tuple`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._space:MeTTa._door_register_prolog`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `args` | `%Undefined%` | `required` | `values` | `var_positional` |
| `kwargs` | `%Undefined%` | `required` | `values` | `var_keyword` |

Guarantees result type `(host-apply (host-type metta._space tuple) (String ...))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Install a declared Prolog extension.

Evidence: `extensions/python/tests/ch20_extending_the_engine/test_register_prolog.py::test_a_builtin_name_is_refused_and_the_builtin_still_works`, `extensions/python/tests/ch20_extending_the_engine/test_register_prolog.py::test_a_declaration_without_an_extension_still_reports_its_names`, `extensions/python/tests/ch20_extending_the_engine/test_register_prolog.py::test_a_declared_det_function_answers_normally`.

## context:register-foreign-library

```python
register_foreign_library(*args: Any, **kwargs: Any) -> tuple[str, ...]
```

Kind: `provider`. Answer: `tuple`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._space:MeTTa._door_register_foreign_library`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `args` | `%Undefined%` | `required` | `values` | `var_positional` |
| `kwargs` | `%Undefined%` | `required` | `values` | `var_keyword` |

Guarantees result type `(host-apply (host-type metta._space tuple) (String ...))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Install a compiled SWI foreign library.

Evidence: `extensions/python/tests/ch20_extending_the_engine/test_register_prolog.py::test_a_compiled_library_registers_from_python`, `extensions/python/tests/ch20_extending_the_engine/test_register_prolog.py::test_an_absent_compiled_library_is_refused_here`, `extensions/python/tests/ch14_seeing_your_program/test_trace.py::test_a_foreign_predicate_does_not_break_tracing`.

## context:register-library-path

```python
register_library_path(directory: Any, name: str) -> None
```

Kind: `provider`. Answer: `None`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._space:MeTTa._door_register_library_path`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `directory` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |
| `name` | `String` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `NoneType` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Register one named Prolog library directory.

Evidence: `extensions/python/tests/ch11_python_as_a_notation/test_integrate.py::test_an_explicitly_shared_library_alias_keeps_all_directories`, `extensions/python/tests/ch11_python_as_a_notation/test_integrate.py::test_a_failed_integration_unwinds_every_framework_registration`.

## context:unregister-prolog

```python
unregister_prolog(extension: str) -> tuple[str, ...]
```

Kind: `provider`. Answer: `tuple`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._space:MeTTa._door_unregister_prolog`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `extension` | `String` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `(host-apply (host-type metta._space tuple) (String ...))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Release one declared Prolog extension.

Evidence: `extensions/python/tests/ch20_extending_the_engine/test_register_prolog.py::test_a_provider_only_file_registers_no_functions_and_is_accepted`, `extensions/python/tests/ch20_extending_the_engine/test_register_prolog.py::test_an_extension_unloads_whole`, `extensions/python/tests/ch20_extending_the_engine/test_register_prolog.py::test_an_unloaded_extension_does_not_leave_its_names_behind`.

## context:prolog

```python
prolog() -> None
```

Kind: `introspection`. Answer: `None`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._space:MeTTa._door_prolog`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `NoneType` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Enter SWI-Prolog's interactive toplevel.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_the_interactive_door_reaches_the_owned_runtime`.

## rows:insert

```python
insert(i: int, item: Iterable[Any]) -> None
```

Kind: `write`. Answer: `None`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Rows._door_insert`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `i` | `Number` | `required` | `values` | `positional_or_keyword` |
| `item` | `(host-apply (host-type metta.results Iterable) (%Undefined%))` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `NoneType` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Read Rows.insert.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_results.py::test_rows_mutations_preserve_invariants`.

## rows:append

```python
append(item: Iterable[Any]) -> None
```

Kind: `write`. Answer: `None`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Rows._door_append`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `item` | `(host-apply (host-type metta.results Iterable) (%Undefined%))` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `NoneType` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Read Rows.append.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_results.py::test_rows_mutations_preserve_invariants`.

## rows:extend

```python
extend(other: Iterable[Iterable[Any]]) -> None
```

Kind: `write`. Answer: `None`. Effect: `writesState`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Rows._door_extend`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `other` | `(host-apply (host-type metta.results Iterable) ((host-apply (host-type metta.results Iterable) (%Undefined%))))` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `NoneType` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Read Rows.extend.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_results.py::test_rows_mutations_preserve_invariants`.

## rows:copy

```python
copy() -> Rows
```

Kind: `query`. Answer: `Rows`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Rows._door_copy`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-type metta.results Rows)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Read Rows.copy.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_results.py::test_rows_copy_and_pickle_protocols`.

## rows:column

```python
column(name: str) -> Column
```

Kind: `query`. Answer: `value`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Rows._door_column`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `name` | `String` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `(host-type metta.results Column)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Project one exact column name.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_results.py::test_binding_rows_group_by_their_column_atom`.

## rows:group-by

```python
group_by(column: str) -> dict[Atom, Rows]
```

Kind: `query`. Answer: `mapping`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Rows._door_group_by`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `column` | `String` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `(host-apply (host-type metta.results dict) (Atom (host-type metta.results Rows)))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Group rows by the atom in one exact column.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_results.py::test_binding_rows_group_by_their_column_atom`.

## rows:first

```python
first(*, default: Any=_MISSING) -> Row | Any
```

Kind: `query`. Answer: `value`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Rows._door_first`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `default` | `%Undefined%` | `_MISSING` | `values` | `keyword_only` |

Guarantees result type `(host-union ((host-type metta.results Row) %Undefined%))` with the answer shape, effect, and determinism above.

Declared local refusals:

- `engine`: `extensions/python/tests/repository/test_door_refusals.py::test_empty_rows_refuse_an_asserted_scalar[first]`.

Implementation failures propagate, including failures from callees and providers.

> Return the first row, or the caller's explicit default.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## rows:one

```python
one(*, default: Any=_MISSING) -> Row | Any
```

Kind: `query`. Answer: `value`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Rows._door_one`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `default` | `%Undefined%` | `_MISSING` | `values` | `keyword_only` |

Guarantees result type `(host-union ((host-type metta.results Row) %Undefined%))` with the answer shape, effect, and determinism above.

Declared local refusals:

- `engine`: `extensions/python/tests/repository/test_door_refusals.py::test_empty_rows_refuse_an_asserted_scalar[one]`.

Implementation failures propagate, including failures from callees and providers.

> THE row, when the query is asserted to have exactly one answer;
> none or several raise naming the count, so a lookup that silently
> picked an arbitrary row cannot hide.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## rows:raise-for-errors

```python
raise_for_errors() -> Self
```

Kind: `query`. Answer: `value`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Rows._door_raise_for_errors`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-type metta.results Self)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Raise when any cell carries an `(Error ...)` atom; answer self
> otherwise, so the call chains.
>
>     m.match(pattern).raise_for_errors()
>
> Query rows are BINDINGS, not evaluation answers, so a stored
> error record stays data through every Rows method, one() and
> first() included; this is the explicit bridge for callers who
> want the raise_for_status reading. One error raises it plainly,
> several raise one ExceptionGroup carrying each.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## rows:why

```python
why() -> str
```

Kind: `query`. Answer: `str`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Rows._door_why`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `String` with the answer shape, effect, and determinism above.

Declared local refusals:

- `type`: `extensions/python/tests/repository/test_door_refusals.py::test_door_type_refusals[rows:why]`.
- `value`: `extensions/python/tests/repository/test_door_refusals.py::test_door_value_refusals[rows:why]`.

Implementation failures propagate, including failures from callees and providers.

> Explain why this eager query returned no rows.
>
> The explanation reads the space's current state. A nonempty result
> has nothing to explain, and a manually constructed or transformed
> Rows has no query to inspect, so both uses fail loudly.
>
> One of nine observability methods: metta.derivation answers HOW a
> result was derived, and prepare(...).explain() answers what a
> query will do before it runs; the guide's observability page maps
> the family.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## rows:explain

```python
explain(*, analyze: bool=False, allow_writes: bool=False) -> Explanation
```

Kind: `query`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Rows._door_explain`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `analyze` | `Bool` | `False` | `values` | `keyword_only` |
| `allow_writes` | `Bool` | `False` | `values` | `keyword_only` |

Guarantees result type `(host-type metta.results Explanation)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> What the engine did with the query that produced these rows.
>
> The same answer `Space.explain` gives, over the match form this result
> came from: the seam entry, pushdown, source, writes, error mode and the
> PLAN, `generic-join` with its variable order and columns or
> `nested-loop` with the conjunct the matcher leads with. Nothing is
> pulled and nothing is re-matched.
>
> `analyze=True` RE-RUNS the query inside `stats()` and adds
> `(inferences N)`, `(answers N)` and `(cputime S)`; it refuses a query
> whose operations write unless `allow_writes=True`.
>
> The longhand is `m.explain(form)` on the match form itself, and under
> that `m.run("!(explain <form>)")`.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## rows:build

```python
@overload
build[BuildT](cls: type[BuildT], /) -> list[BuildT]
@overload
build[BuildT](column: str, cls: type[BuildT]) -> list[BuildT]
build(column: str | type, cls: type | None=None) -> list
```

Kind: `query`. Answer: `list`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Rows._door_build`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `column` | `(host-union (String (host-type metta.results type)))` | `required` | `values` | `positional_or_keyword` |
| `cls` | `(host-union ((host-type metta.results type) NoneType))` | `None` | `values` | `positional_or_keyword` |

Guarantees result type `(host-type metta.results list)` with the answer shape, effect, and determinism above.

Declared local refusals:

- `type`: `extensions/python/tests/repository/test_door_refusals.py::test_door_type_refusals[rows:build]`.

Implementation failures propagate, including failures from callees and providers.

> Rebuild constructor atoms through the two-way translator.
>
> ``build(column, cls)`` projects a named column. ``build(cls)`` is the
> query reconstruction form when exactly one column holds complete
> constructor expressions.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## rows:into

```python
into(cls: type) -> list
```

Kind: `query`. Answer: `list`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Rows._door_into`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `cls` | `(host-type metta.results type)` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `(host-type metta.results list)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Each row as one ``cls``, matched by field name.
>
> ``match(..., into=cls)`` is sugar for this and says so: the
> conversion was only ever reachable through that keyword, so a
> prepared query's solve(), or any other Rows, could not ask for it
> even though rows_into() never cared where the rows came from
> . build(cls) is the neighbouring method and a
> different question: it rebuilds ONE column of complete constructor
> expressions, where this maps every column onto a field.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## rows:to-dicts

```python
to_dicts() -> list[dict[str, Any]]
```

Kind: `query`. Answer: `list`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Rows._door_to_dicts`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-apply (host-type metta.results list) ((host-apply (host-type metta.results dict) (String %Undefined%))))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Return one Python-native column-to-value mapping per row.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## rows:table

```python
table() -> dict[str, list[Any]]
```

Kind: `query`. Answer: `mapping`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Rows._door_table`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-apply (host-type metta.results dict) (String (host-apply (host-type metta.results list) (%Undefined%))))` with the answer shape, effect, and determinism above.

Declared local refusals:

- `value`: `extensions/python/tests/repository/test_door_refusals.py::test_door_value_refusals[rows:table]`.

Implementation failures propagate, including failures from callees and providers.

> The columns as a dict of plain values, the one shape every
> DataFrame constructor takes: pl.DataFrame(rows.table()),
> pd.DataFrame(rows.table()). Grounded values unwrap to Python;
> symbols and structure become their text.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## rows:arrow

```python
arrow() -> ArrowView
```

Kind: `query`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Rows._door_arrow`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-type metta.results ArrowView)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> These rows wearing nothing but the Arrow protocol.
>
> `Rows` is a sequence, and polars' `DataFrame()` constructor tests for
> a sequence before it looks for the capsule, so `pl.DataFrame(rows)`
> reads the atoms row by row instead. `pl.DataFrame(rows.arrow())` is
> the stream. Consumers that ask for the protocol first, pyarrow,
> DuckDB, pandas 3 and `pl.scan_arrow_c_stream`, take `rows` itself.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## rows:to

```python
to(library: Any)
```

Kind: `query`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Rows._door_to`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `library` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Declared local refusals:

- `type`: `extensions/python/tests/repository/test_door_refusals.py::test_door_type_refusals[rows:to]`.

Implementation failures propagate, including failures from callees and providers.

> These rows as a frame of `library`: the general frame door.
>
>     rows.to(polars)          # the module itself, never its name
>     rows.to("polars")        # the escape, for a library not imported here
>
> Sugar over `__arrow_c_stream__` where the library reads it, which is
> typed BY the projection rather than inferred from Python objects, and
> over the projected columns where it does not; either way the values
> are the same. The library is the caller's dependency, and its absence
> raises naming the need. Which libraries are reachable is the `frame`
> point's rows: a library registers once and every rows object answers
> it, with no method added here.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## rows:pipe

```python
pipe(fn: Callable[..., Any], *args: Any, **kwargs: Any) -> Any
```

Kind: `query`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Rows._door_pipe`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `fn` | `(host-apply (host-type metta.results Callable) (... %Undefined%))` | `required` | `values` | `positional_or_keyword` |
| `args` | `%Undefined%` | `required` | `values` | `var_positional` |
| `kwargs` | `%Undefined%` | `required` | `values` | `var_keyword` |

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> fn(self, *args, **kwargs), pandas' chaining shape, so a
> pipeline reads left to right instead of inside out:
>
>     m.match(pattern).pipe(clean).pipe(score, weight=2)

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## rows:render

```python
render(source: Any, /, **values: Any) -> str
```

Kind: `query`. Answer: `str`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Rows._door_render`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `source` | `%Undefined%` | `required` | `values` | `positional_only` |
| `values` | `%Undefined%` | `required` | `values` | `var_keyword` |

Guarantees result type `String` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> These rows through a template, as text: `metta.render` with `rows` bound.
>
>     rows.render("| {rows:table}")
>     rows.render(t"{len(rows)} answers")   # 3.14
>
> The longhand is `metta.render(source, rows=rows)`. The receiver is
> bound under the name `rows` on both result faces, so one template
> renders an eager result and a lazy one alike; a template carries its
> own values, so the binding is what the STRING face resolves `{rows}`
> against. That binding is always there, so this door always reads its
> text as fields, where `metta.render("{x}")` with no values leaves the
> braces alone. Every row is written, where `__rich__` stops at
> `config.display_rows`: a document is not a terminal.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## answers:columns

```python
columns -> tuple[str, ...]
```

Kind: `query`. Answer: `tuple`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Answers._door_columns`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-apply (host-type metta.results tuple) (String ...))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Caller-variable names available for projection.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## answers:index

```python
index(value: T, start: int=0, stop: int | None=None) -> int
```

Kind: `query`. Answer: `int`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Answers._door_index`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `value` | `(host-type metta.results T)` | `required` | `values` | `positional_or_keyword` |
| `start` | `Number` | `0` | `values` | `positional_or_keyword` |
| `stop` | `(host-union (Number NoneType))` | `None` | `values` | `positional_or_keyword` |

Guarantees result type `Number` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Return a row position, with a remedy for column-name collisions.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## answers:column

```python
column(name: str) -> Answers[Any]
```

Kind: `query`. Answer: `Answers`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Answers._door_column`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `name` | `String` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `(host-apply (host-type metta.results Answers) (%Undefined%))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Project one exact caller-variable column.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_results.py::test_binding_rows_group_by_their_column_atom`.

## answers:group-by

```python
group_by(column: str) -> dict[Atom, Rows]
```

Kind: `query`. Answer: `mapping`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Answers._door_group_by`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `column` | `String` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `(host-apply (host-type metta.results dict) (Atom (host-type metta.results Rows)))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Materialize binding rows grouped by one atom-valued column.

Evidence: `extensions/python/tests/ch04_spaces_and_matching/test_results.py::test_binding_rows_group_by_their_column_atom`.

## answers:rows

```python
rows -> Answers[Row]
```

Kind: `query`. Answer: `Answers`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Answers._door_rows`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-apply (host-type metta.results Answers) ((host-type metta.results Row)))` with the answer shape, effect, and determinism above.

Declared local refusals:

- `type`: `extensions/python/tests/repository/test_door_refusals.py::test_answer_rows_refuses_an_answer_without_bindings`.

Implementation failures propagate, including failures from callees and providers.

> The caller-binding row paired with each evaluation answer.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## answers:into

```python
into(cls: type) -> list
```

Kind: `query`. Answer: `list`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Answers._door_into`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `cls` | `(host-type metta.results type)` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `(host-type metta.results list)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Materialize, then convert through Rows.into.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## answers:build

```python
build(*args: Any) -> list[Any]
```

Kind: `query`. Answer: `list`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Answers._door_build`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `args` | `%Undefined%` | `required` | `values` | `var_positional` |

Guarantees result type `(host-apply (host-type metta.results list) (%Undefined%))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Materialize, then rebuild one column through Rows.build.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## answers:to-dicts

```python
to_dicts() -> list[dict[str, Any]]
```

Kind: `query`. Answer: `list`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Answers._door_to_dicts`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-apply (host-type metta.results list) ((host-apply (host-type metta.results dict) (String %Undefined%))))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Materialize as plain column-to-value records.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## answers:table

```python
table() -> dict[str, list[Any]]
```

Kind: `query`. Answer: `mapping`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Answers._door_table`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-apply (host-type metta.results dict) (String (host-apply (host-type metta.results list) (%Undefined%))))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Materialize as a column mapping.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## answers:to

```python
to(library: Any)
```

Kind: `query`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Answers._door_to`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `library` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Materialize, then build a frame of `library`: Rows.to.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## answers:arrow

```python
arrow() -> ArrowView
```

Kind: `query`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Answers._door_arrow`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-type metta.results ArrowView)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> These answers wearing nothing but the Arrow protocol.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## answers:pipe

```python
pipe(fn: Callable[..., Any], *args: Any, **kwargs: Any) -> Any
```

Kind: `query`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Answers._door_pipe`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `fn` | `(host-apply (host-type metta.results Callable) (... %Undefined%))` | `required` | `values` | `positional_or_keyword` |
| `args` | `%Undefined%` | `required` | `values` | `var_positional` |
| `kwargs` | `%Undefined%` | `required` | `values` | `var_keyword` |

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Materialize and pass the eager Rows face to ``fn``.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## answers:raise-for-errors

```python
raise_for_errors() -> Self
```

Kind: `query`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Answers._door_raise_for_errors`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-type metta.results Self)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Raise stored error cells after materializing the row view.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## answers:why

```python
why() -> str
```

Kind: `query`. Answer: `str`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Answers._door_why`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `String` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Explain an empty query after materializing it.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## answers:explain

```python
explain(*, analyze: bool=False, allow_writes: bool=False) -> Explanation
```

Kind: `query`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Answers._door_explain`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `analyze` | `Bool` | `False` | `values` | `keyword_only` |
| `allow_writes` | `Bool` | `False` | `values` | `keyword_only` |

Guarantees result type `(host-type metta.results Explanation)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> What the engine did with the query behind this view, pulling nothing.
>
> `why()` materializes because an empty answer set is what it explains;
> this one reads the query the view holds, so a lazy stream stays exactly
> where it was and an infinite one is explainable at all. Otherwise it is
> `Rows.explain` and answers the same `Explanation`.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## answers:render

```python
render(source: Any, /, **values: Any) -> str
```

Kind: `query`. Answer: `str`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Answers._door_render`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `source` | `%Undefined%` | `required` | `values` | `positional_only` |
| `values` | `%Undefined%` | `required` | `values` | `var_keyword` |

Guarantees result type `String` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> These answers through a template, as text: `Rows.render`'s lazy twin.
>
> The receiver is bound under the same name, `rows`, so a template
> written for one face renders the other unchanged. Rendering reads the
> answers, so an unbounded view is bounded first, the way `to_dicts`
> and `table` are.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## answers:one

```python
one(*, default: Any=_MISSING) -> Any
```

Kind: `query`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Answers._door_one`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `default` | `%Undefined%` | `_MISSING` | `values` | `keyword_only` |

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Declared local refusals:

- `engine`: `extensions/python/tests/repository/test_door_refusals.py::test_empty_answers_refuse_an_asserted_scalar[one]`.

Implementation failures propagate, including failures from callees and providers.

> Return at most one decoded value, defaulting only on absence.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## answers:first

```python
first(*, default: Any=_MISSING) -> Any
```

Kind: `query`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Answers._door_first`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `default` | `%Undefined%` | `_MISSING` | `values` | `keyword_only` |

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Declared local refusals:

- `engine`: `extensions/python/tests/repository/test_door_refusals.py::test_empty_answers_refuse_an_asserted_scalar[first]`.

Implementation failures propagate, including failures from callees and providers.

> Return the first decoded value, or the caller's explicit default.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## answers:close

```python
close() -> None
```

Kind: `lifecycle`. Answer: `None`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta.results:Answers._door_close`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `NoneType` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Release the engine cursor this view holds, now rather than later.
>
>     with metta.answers(S.fact(V.n)) as rows:
>         for row in rows:
>             if enough(row):
>                 break
>
> A lazy view owns a cursor and the engine behind it, and a view that is
> abandoned part-way holds both until the collector runs. `Space` has
> owned a resource and said so from the start, with `drop()` and the
> `with` form; this is the same vocabulary for the other type that owns
> one, which had only a finalizer.
>
> The finalizer stays as the backstop, and being only a backstop is the
> point: a `__del__` runs during interpreter shutdown with module globals
> already cleared, which is how an abandoned cursor printed
> "Exception ignored ... catching classes that do not inherit from
> BaseException" out of a torn-down module.
>
> Closing twice is a no-op, as it is for `drop()`. Answers already pulled
> stay readable, because they are cached values rather than engine state;
> only what has NOT been pulled is given up.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_result_door_projections_preserve_fields_and_host_conversions`.

## remote-space:delivers

```python
delivers() -> tuple[str, str] | None
```

Kind: `query`. Answer: `None`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `remote`.

Implementation: `metta.remote:RemoteSpace._door_delivers`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-union ((host-apply (host-type metta.remote tuple) (String String)) NoneType))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Nothing: the wire carries no event.
>
> The wire has four operations, match, enumerate, add and remove, and
> none of them carries an event, while a remote space's contents change
> on the server, which is the whole reason it is remote. So a watcher
> here would hear only the writes this process made and silently miss
> every other one. Declaring nothing is what refuses the subscription; the
> sentence below is what a caller reads.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_remote_door_contracts_preserve_capability_refusals`.

## remote-space:refusal

```python
refusal(capability: str, /, **_request: Any) -> str | None
```

Kind: `query`. Answer: `value`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `remote`.

Implementation: `metta.remote:RemoteSpace._door_refusal`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `capability` | `String` | `required` | `values` | `positional_only` |
| `_request` | `%Undefined%` | `required` | `values` | `var_keyword` |

Guarantees result type `(host-union (String NoneType))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Read RemoteSpace.refusal.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_remote_door_contracts_preserve_capability_refusals`.

## remote-space:match

```python
match(pattern: Atom, *, limit: int | None=None) -> Iterator[Atom]
```

Kind: `query`. Answer: `stream`. Effect: `oracleIO`. Determinism: `nondet`.

Tiers: `remote`.

Implementation: `metta.remote:RemoteSpace._door_match`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `pattern` | `Atom` | `required` | `atoms` | `positional_or_keyword` |
| `limit` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |

Guarantees result type `(host-apply (host-type metta.remote Iterator) (Atom))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Candidates for a pattern; `limit` crosses as the wire's optional
> `bound` field. Sending it is sound whatever the server does: a
> server that honors it exactly saves the work, one that ignores it
> over-answers, and the local engine re-unifies and truncates either
> way. Whether it is honored is advertised in
> `server_capabilities()`.
>
> One crossing carries the whole answer set unless this space was
> built with a `batch`, in which case the ask/next/stop lifecycle
> carries it a chunk at a time and an engine that stops pulling
> stops the server.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_remote_storage_doors_use_the_declared_operation_protocol`.

## remote-space:stream

```python
stream(pattern: Atom, *, batch: int=_DEFAULT_BATCH, limit: int | None=None, arrow: bool=False) -> RemoteCursor
```

Kind: `query`. Answer: `stream`. Effect: `oracleIO`. Determinism: `nondet`.

Tiers: `remote`.

Implementation: `metta.remote:RemoteSpace._door_stream`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `pattern` | `Atom` | `required` | `atoms` | `positional_or_keyword` |
| `batch` | `Number` | `_DEFAULT_BATCH` | `values` | `keyword_only` |
| `limit` | `(host-union (Number NoneType))` | `None` | `values` | `keyword_only` |
| `arrow` | `Bool` | `False` | `values` | `keyword_only` |

Guarantees result type `(host-type metta.remote RemoteCursor)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> The lazy method: answers pulled a chunk at a time, so taking two
> of a large enumeration costs the server two answers' work instead
> of the whole join's.
>
> match() remains eager, matching the in-process split between match()
> and stream(). Reach for this to take answers
> until you have seen enough, or when the answer set is larger than
> one HTTP body.
>
> `limit` is the wire's `bound` and carries the same advice it
> carries on match(): a server that can honor it exactly stops at
> the count, one that cannot ignores it and over-answers. It is not
> truncated again here, because a server may answer candidates
> rather than answers, and cutting an over-approximated stream at
> the count is the under-approximation the protocol forbids. The
> first ask crosses when the cursor is built, as the in-process
> cursor opens its engine when it is built.
>
> `arrow=True` asks for Arrow record batches instead of tagged atoms: the
> server fixes ONE schema for the whole stream when the cursor opens, from
> what it declares about the pattern's positions, and each chunk crosses
> as a complete IPC stream at that schema. Such a cursor answers
> `to_arrow()` and the PyCapsule protocol rather than atoms, because
> converting a batch back to atoms would go through canonical text and
> lose what the tagged wire carries exactly.

Evidence: `extensions/python/tests/ch19_spaces_backed_by_anything/test_remote.py::test_the_lifecycle_answers_exactly_what_the_eager_door_answers`.

## remote-space:server-capabilities

```python
server_capabilities() -> dict[str, Any]
```

Kind: `query`. Answer: `mapping`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `remote`.

Implementation: `metta.remote:RemoteSpace._door_server_capabilities`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-apply (host-type metta.remote dict) (String %Undefined%))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> The server's own advertisement from GET /health: `capabilities`
> names the protocol operations it admits, so a client can ask before
> writing, and `bound` says whether /match honors the bound field
> exactly. A transport built by connect() knows its URL; a
> hand-built transport must carry its own `health` callable, or
> this refuses rather than guessing.

Evidence: `extensions/python/tests/ch19_spaces_backed_by_anything/test_remote.py::test_server_capabilities_refuses_a_health_less_transport`, `extensions/python/tests/ch19_spaces_backed_by_anything/test_remote.py::test_a_gateway_is_a_drop_in_transport`, `extensions/python/tests/ch19_spaces_backed_by_anything/test_remote.py::test_health_advertises_the_projection`.

## remote-space:atoms

```python
atoms() -> Iterator[Atom]
```

Kind: `query`. Answer: `stream`. Effect: `oracleIO`. Determinism: `nondet`.

Tiers: `remote`.

Implementation: `metta.remote:RemoteSpace._door_atoms`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-apply (host-type metta.remote Iterator) (Atom))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Read RemoteSpace.atoms.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_remote_storage_doors_use_the_declared_operation_protocol`.

## remote-space:add

```python
add(atom: Atom) -> None
```

Kind: `write`. Answer: `None`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `remote`.

Implementation: `metta.remote:RemoteSpace._door_add`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `atom` | `Atom` | `required` | `atoms` | `positional_or_keyword` |

Guarantees result type `NoneType` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Store one atom on the serving side.
>
> A lost response raises OutcomeUnknown. Its retry() replays the
> original acknowledgement when the server advertised idempotency;
> otherwise retry refuses to send and the caller must reconcile with
> the server. Calling add again starts a NEW logical mutation.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_remote_storage_doors_use_the_declared_operation_protocol`.

## remote-space:add-many

```python
add_many(atoms: list[Atom]) -> None
```

Kind: `write`. Answer: `None`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `remote`.

Implementation: `metta.remote:RemoteSpace._door_add_many`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `atoms` | `(host-apply (host-type metta.remote list) (Atom))` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `NoneType` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> One request carries the batch, the engine's own bulk-write law on
> the wire: a batch is a transport optimisation and never a semantic
> one, and the engine already routes only plain stores through it.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_remote_storage_doors_use_the_declared_operation_protocol`.

## remote-space:remove

```python
remove(atom: Atom) -> bool
```

Kind: `write`. Answer: `bool`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `remote`.

Implementation: `metta.remote:RemoteSpace._door_remove`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `atom` | `Atom` | `required` | `atoms` | `positional_or_keyword` |

Guarantees result type `Bool` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Read RemoteSpace.remove.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_remote_storage_doors_use_the_declared_operation_protocol`.

## remote-cursor:__next__

```python
__next__() -> Atom
```

Kind: `query`. Answer: `Atom`. Effect: `oracleIO`. Determinism: `nondet`.

Tiers: `remote`.

Implementation: `metta.remote:RemoteCursor._door___next__`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `Atom` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Read the next remote answer.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_remote_generated_doors_release_their_cursor`.

## remote-cursor:to-arrow

```python
to_arrow() -> Any
```

Kind: `query`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `remote`.

Implementation: `metta.remote:RemoteCursor._door_to_arrow`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> The whole remaining stream as one pyarrow Table.
>
>     with space.stream(pattern, arrow=True) as answers:
>         table = answers.to_arrow()
>
> Every chunk crosses as its own complete IPC stream at ONE schema, fixed
> by the server when the cursor opened, so the batches concatenate. The
> columns are the pattern's variables at the types the served space
> declares for them, plus `atom`, the canonical text of each instantiated
> answer, which stays exact where a typed column cannot hold a cell.
>
> The longhand is the ask/next/stop lifecycle with
> `Accept: application/vnd.apache.arrow.stream` and reading each body with
> `pyarrow.ipc.open_stream`; this is that loop, drained.

Evidence: `extensions/python/tests/ch19_spaces_backed_by_anything/test_remote_arrow.py::test_a_client_cursor_drains_to_one_table`.

## remote-cursor:__arrow_c_stream__

```python
__arrow_c_stream__(requested_schema: Any=None) -> Any
```

Kind: `query`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `remote`.

Implementation: `metta.remote:RemoteCursor._door___arrow_c_stream__`, receiving `method`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `requested_schema` | `%Undefined%` | `None` | `values` | `positional_or_keyword` |

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> The drained stream as the Arrow PyCapsule Interface's own object.
>
> Sugar over `to_arrow()`, so a consumer that dispatches on the protocol
> rather than on a type reaches the same batches
> .

Evidence: `extensions/python/tests/ch19_spaces_backed_by_anything/test_remote_arrow.py::test_a_client_cursor_answers_the_capsule_protocol`.

## remote-cursor:__iter__

```python
__iter__() -> Iterator[Atom]
```

Kind: `query`. Answer: `stream`. Effect: `pureStructural`. Determinism: `nondet`.

Tiers: `remote`.

Implementation: `metta.remote:RemoteCursor._door___iter__`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-apply (host-type metta.remote Iterator) (Atom))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Iterate the receiver.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_remote_generated_doors_release_their_cursor`.

## remote-cursor:close

```python
close() -> None
```

Kind: `lifecycle`. Answer: `None`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `remote`.

Implementation: `metta.remote:RemoteCursor._door_close`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `NoneType` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Release the server's cursor; idempotent, and distinct from
> exhaustion, which released it already.
>
> The token survives a failed /stop and the cursor stays open, because
> a close that discarded it first could never release the server's
> cursor afterwards: every later close returned at the flag while the
> server held the engine to its idle deadline.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_remote_generated_doors_release_their_cursor`, `extensions/python/tests/ch19_spaces_backed_by_anything/test_remote.py::test_a_failed_stop_leaves_the_remote_cursor_retryable`.

## remote-cursor:__enter__

```python
__enter__() -> Self
```

Kind: `query`. Answer: `value`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `remote`.

Implementation: `metta.remote:RemoteCursor._door___enter__`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-type metta.remote Self)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Enter the receiver lifetime.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_remote_generated_doors_release_their_cursor`.

## remote-cursor:__exit__

```python
__exit__(exc_type, exc, tb) -> None
```

Kind: `lifecycle`. Answer: `None`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `remote`.

Implementation: `metta.remote:RemoteCursor._door___exit__`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `exc_type` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |
| `exc` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |
| `tb` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `NoneType` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Stop the server's cursor without letting the stop displace the
> diagnosis: a transport that broke mid-stream breaks the /stop too,
> and the failure a caller needs to read is the first one. Both are
> raised together, the same shape serve()'s own startup path uses.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_remote_generated_doors_release_their_cursor`.

## space:value

```python
value -> Any
```

Kind: `introspection`. Answer: `value`. Effect: `pureStructural`. Determinism: `det`.

Tiers: `sync`.

Implementation: `metta._atoms_core:Grounded.value`, receiving `method`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> The inherited payload slot remains unset: a Space is a Handle, and reading value raises AttributeError.

Evidence: `extensions/python/tests/repository/test_door_rows.py::test_inherited_atom_doors_remain_declared`.

## arrays:install

```python
install(default: Any=None) -> list[str]
```

Kind: `provider`. Answer: `list`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `context`.

Provider: `metta-arrays` through `seam.door`, namespace `arrays`.

Implementation: `metta_arrays:install`, receiving `space`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `default` | `%Undefined%` | `None` | `values` | `positional_or_keyword` |

Guarantees result type `(host-apply (host-type metta_arrays list) (String))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Register the array operation set on the shared engine.
>
> default names the library the constructors build in: a module, a module
> name, or None for NumPy. Every other operation dispatches on its
> argument's own namespace, so arrays from any conforming library flow
> through the same MeTTa functions, and a mixed binary call converts the
> right operand into the left's library through from_dlpack.
>
> Every installed name has one or more arrow declarations. Constructors
> with optional or variadic dimensions have one arrow per accepted arity.
>
> broadcast-shape is the CLP(FD) relation over shape expressions. It can
> compute a result before any tensor exists, infer an unknown input
> dimension from a required result, or reject incompatible shapes:
>
>     !(let True (broadcast-shape (4 1) (3) $shape) $shape)  ; (4 3)
>     !(let True (broadcast-shape ($d 1) (1 3) (4 3)) $d)   ; 4
>     !(broadcast-shape (2 3) (4 3) (4 3))                  ; no answer
>
> t-shape remains observation of an existing tensor. Use broadcast-shape
> when compatibility or inference must happen before materialisation.
>
> ``Shape`` carries those expressions through Python ``Annotated`` claims.
> User operation arrows retain the claim: argument dimensions unify and
> bind shared result dimensions. Live values report the same type expression.
> ``SHAPE_RULES`` names every installed head's behavior; preserving heads
> share their entire input shape with the result. Other transformations
> expose their actual shape when their result value exists.
> A declared ``(Annotated DLTensor (Shape ...))`` remains a valid DLTensor
> argument, elementwise binary operations derive their output shape with
> ``broadcast-shape``, and rank-two matmul unifies the two inner dimensions:
>
>     (: image (Annotated DLTensor (Shape (4 1))))
>     (: bias  (Annotated DLTensor (Shape (3))))
>     !(get-type (t+ image bias))  ; (Annotated DLTensor (Shape (4 3)))
>
> m may be a context or a space. The operations are registered into the
> space either way, which is the object whose storage and introspection
> doors this needs; `install(m)` on a context used to raise
> `MeTTa has no 'is_function'` and leave every operation unregistered.
>
> What this space installed becomes one catalog row,
> ``(array-backend <space> <library> (ops ...))`` in ``&metta``, which
> ``ops(m)`` and ``backend(m)`` read back and a MeTTa program can match for
> itself. Installing again REPLACES that row, the space's constructor
> aliases, and every operation of the outgoing roster that no other space's
> row still names; ``uninstall(m)`` retires the whole installation, and
> dropping the space retires the row with it. Two spaces may therefore hold
> two libraries at once, in either install order, each answering its own.

Evidence: `extensions/python/ext/metta-arrays/tests/test_arrays_doors.py::test_array_namespace_preserves_installation_and_withdrawal`.

## arrays:uninstall

```python
uninstall() -> list[str]
```

Kind: `provider`. Answer: `list`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `context`.

Provider: `metta-arrays` through `seam.door`, namespace `arrays`.

Implementation: `metta_arrays:uninstall`, receiving `space`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-apply (host-type metta_arrays list) (String))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Retire this space's array installation; answers what it unregistered.
>
> The inverse of `install`. The space's roster row goes, with its
> constructor aliases and the bare-name arrows those carried, the `get-type`
> shape equations and the shaped-DLTensor typing rule; then every operation
> the roster named is unregistered UNLESS another space's row still names
> it, because the operation registry is process-wide by name and two spaces
> on numpy share `zeros--numpy` and the whole backend-agnostic set. The
> answer is therefore what actually left the registry, in roster order.
>
>     arrays.install(space, default=numpy)
>     arrays.uninstall(space)
>     arrays.ops(space)            # refuses: nothing is installed here
>
> An operation another space claims stays registered, and this space stops
> DECLARING it: `ops.withdraw` releases the rows that would otherwise keep
> the space describing a function it no longer routes to.
>
> Dropping the space retires the row without this call, the catalog
> retiring a space's declarations with it, but the process-wide operations
> are the registry's and only this door hands them back.
>
> Two registrations deliberately survive, both keyed on the DLPack
> predicate rather than on a space, so one registration serves every space
> and withdrawing it here would change another space's answers: the
> DLTensor type and array printing hooks, whose own doors are
> `integrate.unregister_object_type` and `integrate.unregister_repr`, and
> the `broadcast-shape` CLP(FD) relation, which `register_prolog` has no
> withdrawal for.
>
> m may be a context or a space, as `install` takes either.

Evidence: `extensions/python/ext/metta-arrays/tests/test_arrays_doors.py::test_array_namespace_preserves_installation_and_withdrawal`.

## arrays:ops

```python
ops() -> list[str]
```

Kind: `introspection`. Answer: `list`. Effect: `readOnlyLookup`. Determinism: `det`.

Tiers: `sync`, `context`.

Provider: `metta-arrays` through `seam.door`, namespace `arrays`.

Implementation: `metta_arrays:ops`, receiving `space`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-apply (host-type metta_arrays list) (String))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> The array operation names installed in this space, in install order.
>
> `install` returns the same list; this reads it back from the space long
> afterwards, so two spaces on two libraries answer their own rosters
> whatever order they were installed in:
>
>     numpy_space, jax_space = m.space(), m.space()
>     arrays.install(jax_space, default=jax.numpy)
>     arrays.install(numpy_space, default=numpy)
>     arrays.ops(numpy_space)      # ... 'zeros--numpy' ...
>     arrays.backend(jax_space)    # 'jax.numpy'
>
> m may be a context or a space. The longhand is the row itself, which is
> ordinary matchable data: `!(match &metta (array-backend &s $lib $ops) $ops)`.
> A space with no install refuses, naming install as the remedy.

Evidence: `extensions/python/ext/metta-arrays/tests/test_arrays_doors.py::test_array_namespace_preserves_installation_and_withdrawal`.

## arrays:backend

```python
backend() -> str
```

Kind: `introspection`. Answer: `str`. Effect: `readOnlyLookup`. Determinism: `det`.

Tiers: `sync`, `context`.

Provider: `metta-arrays` through `seam.door`, namespace `arrays`.

Implementation: `metta_arrays:backend`, receiving `space`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `String` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> The array library this space's constructors build in.
>
> The fully qualified module name install() recorded, `numpy` or
> `jax.numpy`, which is the same name its constructor registrations carry
> after the `--` in `zeros--numpy`. `ops` answers the roster beside it, and
> the row behind both is `(array-backend <space> <library> (ops ...))` in
> `&metta`.

Evidence: `extensions/python/ext/metta-arrays/tests/test_arrays_doors.py::test_array_namespace_preserves_installation_and_withdrawal`.

## live:view

```python
view(*query: Any, on: SubscriptionEdge=SubscriptionEdge.both, strategy: str | None=None) -> Any
```

Kind: `query`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `context`, `async`.

Declared option vocabularies:

- `on`: `add`, `remove`, `both`.

Provider: `metta-live` through `seam.door`, namespace `live`.

Implementation: `metta_live:view`, receiving `space`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `query` | `%Undefined%` | `required` | `values` | `var_positional` |
| `on` | `(host-type metta_live SubscriptionEdge)` | `SubscriptionEdge.both` | `values` | `keyword_only` |
| `strategy` | `(host-union (String NoneType))` | `None` | `values` | `keyword_only` |

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Maintain a query's multiset through this space's committed writes.
>
> The returned Live owns its subscriptions. close() releases them, and
> changes() reads its progress and deltas. strategy selects pattern, heads,
> or tabled maintenance; omitting it selects from the query's shape.

Evidence: `extensions/python/ext/metta-live/tests/test_live_doors.py::test_live_namespace_preserves_view_lifecycle`.

## tables:to-df

```python
to_df(rows: Any) -> Any
```

Kind: `query`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `context`.

Longhand: `rows:to(..., library='pandas')`.

Provider: `metta-pandas` through `seam.door`, namespace `tables`.

Implementation: `metta_pandas:to_df`, receiving `none`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `rows` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> These rows as a pandas DataFrame; the declared point rows.to('pandas').

Evidence: `extensions/python/ext/metta-pandas/tests/test_pandas_doors.py::test_pandas_namespace_and_short_sugars_share_the_row`.

## rows:to-df

```python
to_df() -> Any
```

Kind: `query`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Longhand: `rows:to(..., library='pandas')`.

Provider: `metta-pandas` through `seam.door`, namespace `tables`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> These rows as a pandas DataFrame; the declared point rows.to('pandas').

Evidence: `extensions/python/ext/metta-pandas/tests/test_pandas_doors.py::test_pandas_namespace_and_short_sugars_share_the_row`.

## answers:to-df

```python
to_df() -> Any
```

Kind: `query`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Longhand: `answers:to(..., library='pandas')`.

Provider: `metta-pandas` through `seam.door`, namespace `tables`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> These rows as a pandas DataFrame; the declared point rows.to('pandas').

Evidence: `extensions/python/ext/metta-pandas/tests/test_pandas_doors.py::test_pandas_namespace_and_short_sugars_share_the_row`.

## tables:to-pl

```python
to_pl(rows: Any) -> Any
```

Kind: `query`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `context`.

Longhand: `rows:to(..., library='polars')`.

Provider: `metta-polars` through `seam.door`, namespace `tables`.

Implementation: `metta_polars:to_pl`, receiving `none`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `rows` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> These rows as a polars DataFrame; the declared point rows.to('polars').

Evidence: `extensions/python/ext/metta-polars/tests/test_polars_doors.py::test_polars_namespace_and_short_sugars_share_the_row`.

## rows:to-pl

```python
to_pl() -> Any
```

Kind: `query`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Longhand: `rows:to(..., library='polars')`.

Provider: `metta-polars` through `seam.door`, namespace `tables`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> These rows as a polars DataFrame; the declared point rows.to('polars').

Evidence: `extensions/python/ext/metta-polars/tests/test_polars_doors.py::test_polars_namespace_and_short_sugars_share_the_row`.

## answers:to-pl

```python
to_pl() -> Any
```

Kind: `query`. Answer: `value`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`.

Longhand: `answers:to(..., library='polars')`.

Provider: `metta-polars` through `seam.door`, namespace `tables`.

Assumes receiver state `any`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `%Undefined%` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> These rows as a polars DataFrame; the declared point rows.to('polars').

Evidence: `extensions/python/ext/metta-polars/tests/test_polars_doors.py::test_polars_namespace_and_short_sugars_share_the_row`.

## remote:connect

```python
connect(url: str, timeout: float=30.0, *, token: str | None=None, headers: dict[str, str] | None=None, ssl_context: Any=None) -> Transport
```

Kind: `provider`. Answer: `callable`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `context`.

Provider: `metta-remote` through `seam.door`, namespace `remote`.

Implementation: `metta.remote:connect`, receiving `none`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `url` | `String` | `required` | `values` | `positional_or_keyword` |
| `timeout` | `Number` | `30.0` | `values` | `positional_or_keyword` |
| `token` | `(host-union (String NoneType))` | `None` | `values` | `keyword_only` |
| `headers` | `(host-union ((host-apply (host-type metta.remote dict) (String String)) NoneType))` | `None` | `values` | `keyword_only` |
| `ssl_context` | `%Undefined%` | `None` | `values` | `keyword_only` |

Guarantees result type `(host-type metta.remote Transport)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> The HTTP transport for a serve()d engine: one POST per operation,
> JSON both ways, errors surfaced with the remote's own message.
>
> token sends Bearer authentication, headers adds anything else a
> deployment needs (an API key, a tenant id), and ssl_context is
> Python's own ssl.SSLContext for https urls, certificate pinning
> included, so the transport composes with whatever security the
> serving side asks for. Only absolute http and https URLs are accepted.
> Credentials require https. Each mutation negotiates a replay key through
> GET /health before its POST; authorization policies must permit that read.
> An unadvertised extension leaves mutations unkeyed, and OutcomeUnknown
> refuses to resend those requests after a lost response.

Evidence: `extensions/python/ext/metta-remote/tests/test_remote_doors.py::test_remote_namespace_preserves_transport_and_server_lifetimes`.

## remote:serve

```python
serve(host: str='127.0.0.1', port: int=0, spaces: list[str] | None=None, *, token: str | None=None, authorize: Callable[[Request], bool] | None=None, ssl_context: Any=None, cursor_idle: float=_CURSOR_IDLE, cursor_limit: int=_CURSOR_LIMIT, mutation_ttl: float=_MUTATION_TTL, mutation_limit: int=_MUTATION_LIMIT) -> Server
```

Kind: `lifecycle`. Answer: `context`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `context`.

Provider: `metta-remote` through `seam.door`, namespace `remote`.

Implementation: `metta.remote:serve`, receiving `space`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `host` | `String` | `'127.0.0.1'` | `values` | `positional_or_keyword` |
| `port` | `Number` | `0` | `values` | `positional_or_keyword` |
| `spaces` | `(host-union ((host-apply (host-type metta.remote list) (String)) NoneType))` | `None` | `values` | `positional_or_keyword` |
| `token` | `(host-union (String NoneType))` | `None` | `values` | `keyword_only` |
| `authorize` | `(host-union ((host-apply (host-type metta.remote Callable) (((host-type metta.remote Request)) Bool)) NoneType))` | `None` | `values` | `keyword_only` |
| `ssl_context` | `%Undefined%` | `None` | `values` | `keyword_only` |
| `cursor_idle` | `Number` | `_CURSOR_IDLE` | `values` | `keyword_only` |
| `cursor_limit` | `Number` | `_CURSOR_LIMIT` | `values` | `keyword_only` |
| `mutation_ttl` | `Number` | `_MUTATION_TTL` | `values` | `keyword_only` |
| `mutation_limit` | `Number` | `_MUTATION_LIMIT` | `values` | `keyword_only` |

Guarantees result type `(host-type metta.remote Server)` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Expose this engine's spaces over HTTP; port 0 picks a free one.
>
> Every operation answers for the space the request names, restricted
> to `spaces` when given. Security is the caller's to define, library
> fashion: token requires Bearer authentication, authorize is the
> general hook (a Request in, carrying the operation, the space and
> the headers, and a verdict out, so read-only, per-space and
> per-tenant policies all fit), and ssl_context, Python's own
> ssl.SSLContext with a certificate loaded, serves TLS directly;
> anything heavier still composes behind a fronting proxy. match runs
> the engine's own match with the pattern as its template, so the
> instantiated atoms cross, and the caller's engine re-unifies them.
>
> `cursor_idle` and `cursor_limit` bound the ask/next/stop lifecycle's
> server-side state: how long a cursor nobody pulls from survives, and
> how many live at once before a further ask is refused. The defaults
> are pengines' own, 300 seconds and a ceiling.
>
> mutation_ttl and mutation_limit bound the keyed mutation replay ledger,
> as documented on Gateway. Authorization must admit health for clients
> that negotiate mutation keys.
>
> A context is a PROCESS: serving and attaching within one process
> cannot join through the local engine, because one runtime lock guards
> both sides of that call and the serving thread would wait on the very
> evaluation that is waiting on it. Two engines, two processes, is the
> deployment this exists for; in-process, spaces already share the
> engine and need no wire. Gateway is the same protocol with no
> transport under it, for a test or a framework that wants the
> operations without a socket.
>
> m may be a context or a space, as Gateway takes either.

Evidence: `extensions/python/ext/metta-remote/tests/test_remote_doors.py::test_remote_namespace_preserves_transport_and_server_lifetimes`.

## tables:add

```python
add(head: Any, data: Any) -> int
```

Kind: `write`. Answer: `int`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `context`.

Provider: `metta-tables` through `seam.door`, namespace `tables`.

Implementation: `metta.tables:add`, receiving `space`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `head` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |
| `data` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `Number` with the answer shape, effect, and determinism above.

Declared local refusals:

- `type`: `extensions/python/ext/metta-tables/tests/test_tables_doors.py::test_tables_add_refuses_an_unsupported_source`.

Implementation failures propagate, including failures from callees and providers.

> Add a tabular source to a space as ``(head column...)`` facts.
>
> space may be a context or a space.
>
> The source may offer rows its own way (``iter_rows()`` for polars,
> ``itertuples()`` for pandas, a mapping of columns, any iterable of rows)
> or speak the Arrow PyCapsule Interface, which is how a DuckDB relation, a
> pyarrow Table, a Parquet reader or an Ibis expression hands over rows
> without a row-at-a-time Python door. A source with both keeps its own:
> the two produce identical atoms, and the row door is the faster of them
> .
>
> An Arrow source is written one record batch at a time, so a reader larger
> than memory loads, and the writes are one transaction each; wrap the call
> in ``m.transaction(...)`` to make the whole load one.

Evidence: `extensions/python/ext/metta-tables/tests/test_tables_doors.py::test_table_namespace_preserves_ingestion_and_conversions`.

## tables:declare

```python
declare(name: str, declaration: Atom | str) -> Atom
```

Kind: `write`. Answer: `Atom`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `context`.

Provider: `metta-tables` through `seam.door`, namespace `tables`.

Implementation: `metta.tables:declare`, receiving `space`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `name` | `String` | `required` | `values` | `positional_or_keyword` |
| `declaration` | `(host-union (Atom String))` | `required` | `values` | `positional_or_keyword` |

Guarantees result type `Atom` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Write one ctx-scoped bridge declaration into &metta, where explain
> and any program can read the schema, and from_context will.
>
> m may be a context or a space.

Evidence: `extensions/python/ext/metta-tables/tests/test_tables_doors.py::test_table_namespace_preserves_ingestion_and_conversions`.

## tables:accessors

```python
accessors() -> tuple[str, ...]
```

Kind: `provider`. Answer: `tuple`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `context`.

Provider: `metta-tables` through `seam.door`, namespace `tables`.

Implementation: `metta.tables:accessors`, receiving `none`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|

Guarantees result type `(host-apply (host-type metta.tables tuple) (String ...))` with the answer shape, effect, and determinism above.

Implementation failures propagate, including failures from callees and providers.

> Install the metta accessor for every registered frame library already imported.
>
> Answers the libraries that now carry it, so a program can ask.
>
> Registration never imports a frame library. `import metta.tables` costs
> 15 ms and `import pandas` costs 531 ms, so a module
> that registered by importing would charge every tables user for a library
> the program may never touch. It installs for whichever registered module
> is in `sys.modules`, every door in this module calls it first, and a
> program that imports a frame library afterwards and touches nothing else
> here calls this by name. Idempotent, because a library warns when an
> accessor name is replaced.
>
> Which libraries these are is the `frame` point's rows, not a list here:
> each row says which module it is and how that library spells an accessor,
> so a third one installs `df.metta` by registering
> (`metta.seam.frame.register(...)`, or the `metta.extensions` entry point).

Evidence: `extensions/python/ext/metta-tables/tests/test_tables_doors.py::test_table_namespace_preserves_ingestion_and_conversions`.

## tables:sql-function

```python
sql_function(connection: Any, head: Any, name: str | None=None) -> str
```

Kind: `provider`. Answer: `str`. Effect: `oracleIO`. Determinism: `det`.

Tiers: `sync`, `context`.

Provider: `metta-tables` through `seam.door`, namespace `tables`.

Implementation: `metta.tables:sql_function`, receiving `none`.

Assumes receiver state `live`.

| argument | MeTTa type | default | delivery | parameter kind |
|---|---|---|---|---|
| `connection` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |
| `head` | `%Undefined%` | `required` | `values` | `positional_or_keyword` |
| `name` | `(host-union (String NoneType))` | `None` | `values` | `positional_or_keyword` |

Guarantees result type `String` with the answer shape, effect, and determinism above.

Declared local refusals:

- `type`: `extensions/python/ext/metta-tables/tests/test_tables_doors.py::test_tables_sql_function_refuses_noncallable_heads`.

Implementation failures propagate, including failures from callees and providers.

> Register a MeTTa head as a scalar SQL function, and answer its SQL name.
>
>     m.run("(: dbl (-> Number Number))  (= (dbl $x) (* 2 $x))")
>     tables.sql_function(connection, m.fn.dbl)
>     connection.sql("select dbl(age) from people")
>
> The head is the callable from a space's `fn` namespace, which already
> carries its own name, its arity and its arrow, so nothing about the
> function is restated here; `name=` is the escape for a SQL identifier the
> head's own name cannot be.
>
> WHICH engines are known is the `sql` point's rows, and the first row that
> claims the connection declares the function its own way: sqlite3 wants the
> arity and no types, DuckDB wants the types and reads them from the head's
> DECLARED arrow, refusing by name when there is none (an arrow
> `inspect.signature` merely infers is a proposal, not a promise). A third
> engine registers rather than being added here. A row that produces no
> answer is SQL NULL and one that produces several refuses, because a scalar
> function has one result per row; a SQL NULL argument reaches the head as
> `Grounded(None)` and MeTTa decides what it means.

Evidence: `extensions/python/ext/metta-tables/tests/test_tables_doors.py::test_table_namespace_preserves_ingestion_and_conversions`.
