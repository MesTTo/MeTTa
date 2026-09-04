# One roster for the algebra
Goal: make algebra names, scope, checking, answer shape, typing, and ranked-provider demand agree across the Python and engine surfaces.
Constraint: shared release and cheat-sheet files are integrator-owned; this track records their exact required edits without changing them.

## 2026-09-04 - D1 one shipped-semiring roster
Tried: compared `_PRESETS`, the catalog semiring vocabulary, generated `Semiring`, and root objects -> counts were 10, 8, 8, and 5 at `dca33c9f`.
Rejected: deleting `budget` and `amplitude`, because both have shipped algebra descriptor rows and executable behavior.
Decided: the catalog vocabulary remains the generated-enum authority, and one regression asserts that its ten values exactly equal `_PRESETS` and the root object surface. `python extensions/python/tools/vocabgen.py --write` carries the catalog change into the generated enum.
Open: the integrator-owned cheat sheets still carry stale rosters; the closed-value lane added later in this thread will report them.

## 2026-09-04 - D2 one law checker in one space
Tried: `METTA_PATH="$PWD" PYTHONPATH="$PWD/extensions/python" "$CHECK_PY" ai-tmp/probe_d2.py` -> local `(pmax ...)` evaluated to `1.0`, then declaration failed with `algebra_carrier_not_closed` because the engine retried it in `&self`.
Rejected: retaining Python's exhaustive checker as a preflight, because two executable certificates can diverge again and direct catalog declarations must still be checked by the engine.
Decided: remove Python's duplicate law walk. `metta_py_declare_algebra/2` adds the row through the ordinary catalog door while the declaring space's equation module is active, so the engine checker is the sole certificate and uses the same definitions later evaluation sees.

## 2026-09-04 - closed-value contract lane
Tried: `METTA_PATH="$PWD" PYTHONPATH="$PWD/extensions/python" "$CHECK_PY" tests/checks/check_llms_selftest.py` -> 47 planted cases and 0 failures, including missing, extra, reordered, miscounted and absent rosters.
Tried: ran `tests/checks/check_llms_names.py` against the untouched cheat sheets -> exit 1, with the root module-object and `Semiring` disagreements plus all three absent Python-sheet rosters named exactly.
Rejected: applying the documented roster edits in this worktree, because the cheat sheets are shared integrator-owned files.
Decided: derive semirings and effect classes from the live catalog, provider capabilities from `foreign.py:CAPABILITIES`, and fail closed only in the root and Python sheets that promise this surface. Generated `Semiring` remains covered by the existing vocabulary-sync lane.
Open: paths to build products also fail before a build produces them. Constructor behavior and prose are still a separate fifth blind spot: a closed-set parser cannot prove whether `Answer(k=...)` is accepted or refused, so its docstring needs an executable regression rather than pretending this lane covers it.

## 2026-09-04 - D3 one context lifetime
Tried: declared `same-life` on one anonymous space, then called `get` from a sibling -> the sibling received the declaration, proving the nine-field row was process-global.
Rejected: treating a whole equation world as one algebra context, because sibling spaces have independent `(annotations <context> ...)` rows and the defect is specifically the mismatch between those keys.
Rejected: an optional owner field preserving ambiguous nine-field custom rows, because that would retain two lifetimes and make global scope implicit.
Decided: every algebra row has a required final owner. Shipped presets spell that owner `global`; Python and direct custom rows spell the exact annotation context. Descriptor caches, requirement checks and the Python registry use `(context, name)`, with `global` only as the explicit preset fallback.
Tried: the six affected Python algebra files plus `tests/prolog/suites/spaces/catalog.plt` -> 39 passed, 1 intentionally skipped, and 27 Prolog cases passed.

## 2026-09-04 - D4 ambient constructor target
Tried: called the module constructor inside `with scratch:` -> its row landed in `&self`, so the new context-owned registry made the old fixed target observable as a missing declaration in `scratch`.
Rejected: passing a receiver into the module constructor, because the root already has `current_space()` and module-tier context-sensitive helpers use `engine().space(current_space())`.
Decided: resolve the constructor target through that established ambient-space path before registering callable operations or declaring the row.
Tried: `test_algebra_module_constructor_targets_the_ambient_space` -> the declaration and a tagged query resolve in the scratch space, while `&self` reports `algebra_not_declared`.

## 2026-09-04 - D5 one answer protocol
Tried: listed ordinary and tagged queries under `counting` -> each crossed one engine aggregate but yielded a bare `int`, unlike all nine sibling carriers.
Rejected: materializing the contributing rows to make a full derivation tree, because it would discard the counting route's measured no-row-crossing property.
Decided: preserve the aggregate and wrap its scalar as `TaggedAnswer(value=(), tag=Grounded(count))`. The empty value states that no proposition row was manufactured; `annotation`, `why()`, and `under()` remain available through the shared protocol.
Tried: the counting match, call, scoped, async, and tagged regressions -> both engine count routes yield one TaggedAnswer and continue to open no materializing cursor.
Tried: `jscpd --min-lines 5 --min-tokens 50` over the three implementation files -> it reported the pre-existing nine-line signature overlap between `evaluate_count` and `evaluate_count_if_repeatable`, and no new cross-file clone.
Rejected: merging those two functions, because the repeatable form is an optional cardinality hint for a view that also owns rows, while the counting-carrier form is the answer itself and now deliberately changes its public element type.
Tried: `twin_coverage.py --measure --rounds 1` on `04-peanofast.metta` and `03-matespace.metta` -> the protocol-shaped aggregate completed at 89,211 and 24,108,963 twin inferences respectively, still crossing no proposition rows.

## 2026-09-04 - Answer's four live slots
Tried: compared `Answer`'s docstring with the provider and operation regressions -> the prose said residue and k were staged and refused, while both were already executed end to end.
Rejected: extending the closed-value-set lane to parse this promise, because a roster parser can prove spellings and order but cannot prove constructor behavior or engine interpretation.
Decided: document `Answer(theta, *, value=, residue=, k=)` as the live wire contract, including the annotation declaration fence and `get-metatype` as the observer of encoded value content.
Tried: `test_every_answer_constructor_slot_is_live` -> one Answer used all four slots, its false residue alternative dropped, its k arrived as `0.75`, and its numeric content reported `Grounded`.

## 2026-09-04 - F2 current algebra observer
Tried: derived the answer from `_under.selected()` alone -> it cannot observe an explicit `under=` while a held engine goal invokes a Python operation.
Rejected: returning `metta_effective_algebra/2` directly, because its intentional silent-context default is `bool`, while the observer's contract is an explicitly selected name or `None`.
Decided: one engine service resolves active per-call selection, a singleton task-scope input, then the current context's annotations row. The root observer returns `None` only when all three are absent.
Tried: `test_current_algebra_follows_each_selection_layer` -> two context declarations remain distinct, a task scope overrides its context, and an explicit call carrier overrides the task scope from inside a Python operation.

## 2026-09-05 - F3 shape-carrying tensor types
Tried: declared two tensor symbols with `(Annotated DLTensor (Shape ...))`, then supplied them to an ordinary `(-> DLTensor ...)` operation -> the declaration was preserved by `get-type` but did not satisfy the base arrow.
Rejected: changing the elementwise Python arrows from their existing scalar-capable second argument to two strict DLTensor inputs, because that would trade shape reporting for a runtime regression.
Decided: install one module-scoped compatibility rule from shaped DLTensor to its base, publish symbolic `Shape` metadata through Python `Annotated`, and add module-local `get-type` equations. Elementwise equations call the existing `broadcast-shape` relation; rank-two matmul unifies one shared dimension directly.
Tried: `test_annotated_tensor_shapes_flow_through_broadcast_and_matmul` -> `(4 1)` with `(3)` inferred `(4 3)` through a nested operation, `(2 3)` by `(3 4)` inferred `(2 4)`, both incompatible pairs produced no shaped type, and a shaped symbol satisfied a DLTensor input before any array was built.

## 2026-09-05 - F1 bounded Answers source seam
Tried: applied `[:k]` to an ordered Answers view -> `_slice` pulled the original cursor through `islice`, so no producer ever learned `k`.
Rejected: inspecting a generator's frame to find and mutate its captured cursor, because closure layout is not an interface and ordered cursors deliberately withhold their limit until the best-first promise is proved.
Rejected: replacing a source after any answer was observed, because replay state and effects make a second query observably different.
Decided: an Answers producer may supply a bounded-source factory. Only a finite nonnegative slice of a pristine view offers its `stop`; `stop` covers both skip and fetch, and an observed, negative, open-ended, or empty slice stays on the shared source. The factory receives that shared source as its exact fallback, so the producer can defer its own correctness test until pull.
Open: VIEWER owns the match source constructors in `_space.py`; it must pass factories that retain the ordinary cursor unless the ranked source has ordered annotations and a best-first emission declaration.

## 2026-09-06 - D1 landing: half of it was already on trunk
Tried: rebasing this thread onto `petta` -> the catalog half of D1 had landed
independently as `2026-09-05-the-carrier-the-vocabulary-would-not-admit.md`.
The `(vocabulary semiring ...)` row already names ten, `vocabularies.Semiring`
is already regenerated, `check_policy_inventory.REQUIRED_ALGEBRA_LAWS` already
carries `budget`, and `(claim semiring budget ordered ascending)` is already
there with a comment above it. Those hunks are dropped as already applied.
Decided: what remains is the third roster, which that thread did not touch:
`metta.<carrier>` as a root object. Trunk exported five of the ten, so
`metta.budget` raised AttributeError for a carrier `under="budget"` already
answered. The regression narrows to that claim plus the catalog ORDER, and
says in its docstring that the set equality is ch20's
`test_every_algebra_the_catalog_defines_is_one_its_vocabulary_admits`.
Tried: `ruff check metta/algebra.py metta/__init__.py` -> `bool` and `set` as
module-level names are A001, and `mypy metta/algebra.py` -> 14 errors, because
a module-level `bool` makes every `-> bool` in that module a variable
annotation and a TYPE_CHECKING import of the same name does it to the root too.
Rejected: qualifying the root's eight annotations as `_builtins.bool`. Three
are inside the block `aiogen.py` GENERATES from `Space`, which renders `bool`
from that signature, so the hand edit reverts on the next run.
Decided: `metta/algebra.py` qualifies its own six annotations and carries two
A001 suppressions naming the catalog spelling; `metta/__init__.py` does not
import either name, so both stay reachable through `__getattr__` typed `Any`
like any lazy attribute the block omits. The A-family ruff burn-down rises
17 -> 19 for the two that remain.
Tried: `ty check metta/algebra.py` and `pylint metta/algebra.py`, which read
what mypy did not -> two dataclass fields annotated `bool`, and every `budget`
identifier in the module, which the new `budget` carrier shadows. The fields
are qualified and the identifiers read `resources`, which is what they hold;
`_algebra_demand.evaluate_demand` keeps its own `budget=` keyword, the one call
that crosses the module. Three pylint findings remain and are trunk's: the same
E1101 pair and E1133 read on the unchanged tree.

## 2026-09-06 - closed-value lane landing: who has to carry a roster
Tried: running the lane against trunk's cheat sheets -> the six predicted
findings, exactly. The root sheet still said "Five are objects" and
"`Semiring` names eight of the ten"; the seat sheet stated none of the three
rosters and was reported for all three.
Rejected: writing a Semiring roster into `extensions/python/llms.txt` to
satisfy the lane. That sheet is 347 lines about the Python seat and never
mentions semirings or `under=`; a lane that makes a sheet document a set it
does not cover is dictating scope, not checking a claim.
Decided: split it the way `library_findings` already splits. The ROOT sheet
must carry every roster, so deleting one cannot silence its check, and any
other sheet is held only to what it states. Two planted cases now hold that
door: a seat sheet with no roster is silent, a seat sheet with an invented
member is reported.
Tried: the effect and capability expressions ended at a specific FOLLOWING
clause, `. A plan's class` and `, and an unsupported operation`, which forces
every sheet stating the set into the root sheet's exact wording. Both now end
at the roster sentence, and only backticked values are read out of it.
Decided: the seat sheet gains the `EffectClass` roster on its own merits. It
told a reader to declare an effect class and named only the four shorthands,
so the five names `effect=` actually takes were nowhere on that sheet.
Tried: `tests/checks/check_llms_selftest.py` -> 59 planted cases, 0 failures;
`tests/checks/check_llms_names.py` -> 5 sheets, 0 findings.

## 2026-09-06 - D3 landing: the consumers the tenth field reached
Tried: the algebra suites on trunk with the owner field in place ->
`test_demand_retains_custom_operation_effects` and
`test_demand_keeps_lawless_integer_proof_order` failed with
`algebra_not_declared`. Both arrived on trunk after this thread was cut and
both declare the algebra on the fixture space and evaluate in a sibling, which
is the process-global reading D3 removes. Each declares on the space it
evaluates in now; the host op it names stays engine-wide.
Tried: `examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/`
`09-carrier_vocabulary.metta`, also newer than this thread, matched
`(algebra budget $combine ... $requires)` with eight fields after the name and
answered nothing once there were nine. It reads the owner now and asserts it is
`global`, which is the field teaching itself; its Python twin does the same.
Tried: min-of-3 on both arms, `petta` at 4f20c052 and this tree -> the twin is
119 either way, so its BUDGET does not move. The MeTTa half is 2,621 -> 2,794,
+173 for one more variable in two matches and a wider template. The 13,733 that
pin's prose states is trunk's drift, not this change's: the unchanged tree reads
2,621.
Tried: the same pair for `01-identity.metta`, which this thread never touches.
Against `petta` at 903a42e6 it read 3,422 unchanged and 3,417 here, outside the
twin lane's +-4 allowance, and the controls said what the move was: extracting
`metta_check_algebra_fields/9` alone read 3,417, an inert nine-arity predicate
at the same point read 3,417, while a no-op goal inside the same clause and
inert clauses in `engine/metta/effects.pl` both read 3,422. One more predicate
in `engine/spaces/catalog.pl`, which is the move this corpus records elsewhere.
Decided: no re-pin. Against `petta` at fcfac73f both arms read 3,432, the value
trunk itself re-pinned to for the specialization coverage report, so on the tree
this lands on the row does not move and trunk's number stands unedited.
Decided: `EXTENDING.md`'s row shape and `llms.txt`'s "PROCESS-GLOBAL" paragraph
are corrected here, because both state the lifetime this commit changes.
Tried: `cd extensions/node && npm test` -> 3 of 600 failed. That seat writes
the row itself, so the tenth field is its obligation too: `Algebra.atom` became
`rowOwnedBy(owner)` and `declare(space, ...)` names that space, its catalog
reader takes ten items and prefers the asking context's row before `global` the
way the engine does, and two of its own tests declared on `m.self` and
evaluated in a `fresh()` space, which is the reading this removes.
Tried: the owner read back with `instanceof Sym` -> `algebra_catalog_owner_malformed`.
A space name is an ordinary symbol in the row a preset writes and a space
operand in the row a declaration writes, so the reader compares the atom's text.
Tried: `npm test` again -> 600 pass, 0 fail.

## 2026-09-06 - D5 landing: the consumers a changed element type reached
Tried: the full Python suite with counting wrapped -> the gallery program
`family_algebras.py` rendered `(Count <TaggedAnswer>)` against its own shown
output `(Count 1)`, because it did `S.Count(answers.one())`. It reads
`.annotation` now, and its shown output is unchanged.
Tried: `README.md`, which asserts the same call in the doctested snippet, and
`llms.txt`'s "answers the integer ITSELF, so those answers are `int`" -> both
stated the old element type and are corrected here.
Decided: `_space.py`, `aio.py` and `__init__.py`'s `under=counting` docstrings,
the counting view's `Answers[int]` annotation and the three refusal messages
that call the fold "one number" move with the behaviour rather than in a later
commit; `website/reference/metta-space.md` and `metta-aio.md` are regenerated
from them.
Tried: `lint-imports` after wrapping the count inside `query_count` and
`evaluate_count` -> two of the three contracts BROKEN over seven modules. Those
two modules are imported BY `_space`, so reaching `algebra` from them made
`core does not import satellites` false for `_space`, `_space_diagnostics`,
`_space_execution`, `_space_objects`, `_space_persistence` and `_space_query`,
and importing `Space` back to build the receiver made `leaf modules do not
import the facade` false for `_debug` and `_trace`. Deferring both imports
inside the function did not help: import-linter reads a function-local import
as an edge, which is why `_space` reaches its own satellites through
`_satellite(name)` and `importlib` instead.
Rejected: two `ignore_imports` lines beside the `_space -> _world` and
`_space -> _saga` pair. Those two are one-directional deferrals; this one was a
CYCLE, `_space -> _space_execution -> _space`, and an ignore would have written
it down as intended. Revisit if a future edge is genuinely one-directional.
Decided: the count doors stay `-> int` and `Space` puts the protocol on. It
already holds `algebra_api` and `self` at both call sites, so the wrap is one
call there and `counting_answer` joins `captured_answer` and `count_tagged` as
a builder the facade calls. Three contracts kept.
Tried: the stdlib phrasebook lane, which the per-commit verification had not
run -> `match: the python side raised assertionerror`, from
`assert space.match(S.f(V.x), under=metta.counting).one() == 1` in
`phrasebook_entries.py`. It is the eleventh reader of the element type and the
only one outside `metta/`, `examples/` and the docs, so the sweep that found
the other ten missed it. It reads `.one().annotation` now and the row's frozen
answer is unchanged, because the row's VALUE is its last expression.

## 2026-09-06 - F2 landing: a twin row that tracks engine shape, not work
Tried: the full Python suite -> `01-identity.metta`'s twin missed its pin, and
a twelve-point bisect across `petta` and every landed commit found two moves,
one at the algebra-owner commit and one here.
Tried: the same bisect on the previous base, `petta` at 754df32f -> the moves
were 0 and +5 there and are -5 and -30 here, and on that base removing the
single line `kind(metta_current_algebra/3, host_service)` restored the earlier
number while removing the predicate it names, the root door or the algebra
door each did not. Replacing `engine/` with trunk's at the branch tip restored
it too, while replacing `extensions/python/metta/` changed nothing.
Tried: the same row on the unchanged tree at 84bb5aa9 -> 3,437 against its own
pinned 3,432, so trunk's lane is red on this row before this branch touches the
file; +5 of the distance is trunk's own drift and is reported rather than
absorbed.
Decided: re-pin, and record the base with it. Trunk's own memoisation work
reached the same row on the same day and wrote the same conclusion at length,
including a four-base table showing the sign of an identical change flipping
with the surrounding image; this thread's twelve-point bisect saw exactly that,
0 and +5 against 754df32f and -5 and -30 against 84bb5aa9, db307494 and
9b944a94. On the base this lands on the two movers read 3432 and 3402, so the
pin follows. What the row tracks is the engine's shape: `metta=2357` on every
one of those arms and on every base, which is the control saying no reduction,
clause or answer differs.
Tried: `pylint metta/algebra.py` -> the module-level `current_space` this
commit adds is shadowed inside `_construct`, which imported the root door of
the same name. That import goes: the two doors answer the same space and the
root's only difference is the implementation-module rehide, so the constructor
reads the module-level one `current_algebra` already reads.
Tried: the llms lane on the landing tip -> `llms.txt:41: the sources table says
86 host_service extension points, the tree has 87`. The same
`kind(metta_current_algebra/3, host_service)` line that moved the twin row is
also counted by a cheat sheet, and `check_llms_selftest` uses the real table as
its clean control, so one stale number failed two GATE lanes rather than one.
Decided: the count moves in this commit, with the row it counts.

## 2026-09-06 - F3 landing: a shape rule that claimed an unbound subject
Tried: the full Python suite -> `test_the_empty_expressions_type_follows_the_arbiters_ruling`
and two cost tests failed, in different combinations on different runs, and the
suite was green on trunk. Reproduced in fifteen lines: install the arrays
operations into the process home space, then ask a sibling space
`!(get-type $subject)` -> `Stack limit (7.5Gb) exceeded`, depth 44,071,263.
`(get-type (t+ $l $r))` unifies with an unbound subject, and the body then asks
`(get-type $l)` about a variable it has just invented, which invents two more.
Decided: every shape equation reads its operand through one guarded reader,
`metta-arrays-tensor-shape`, whose first act is to refuse a subject whose
`get-metatype` is `Variable`. The equation then fails, which is the answer a
shape rule owes a subject that has no shape yet, and the engine's own answer
stands. The regression asks the same question and was proven to discriminate:
without the guard it does not fail, it exhausts the stack.
Decided: the arrays fixture removes the typing rule and every equation
`install()` added, not only the operations. This suite drives the process home
space, so what `install()` leaves there is left for every later test in that
worker.
Tried: three full Python runs with the teardown removing only the `get-type`
equations, leaving the shape reader behind -> one failure per run, a different
test each time and none reproducible alone: an extension-cost row, a
first-evaluation cost row, a gradual-typing answer, a grounded-iterator cache.
Three runs of the same suite on `petta` in the same configuration were clean.
With the reader removed too, three runs read 3,400 passed and 48 skipped, one
of them interrupted only by a Hypothesis wall-clock deadline in
`test_segments.py`, which is unrelated and timing-only.
Tried: `test_the_ruff_configuration_enables_every_family_or_records_why_not`
-> the N family reads 38 against a maximum of 37, for `Shape`. Python spells an
`Annotated[...]` metadata position with a type, so the ledger rises with that
reason.
