# Three library defects the cheat-sheet release audit found
Goal: fix the three Python-seat defects the release audit recorded without
fixing (a context that cannot close, a door set that refuses a context, and a
scope that silently keeps a write), at the root, before 0.8.0.
Constraint: the engine decides what is possible; the library's own rulings
decide what is right. A pinned default is a ruling, not a defect.

## 2026-09-06, the handle a close mistook for a possession

Reported as `MeTTa.close()` raising `metta_assert_space_destructible/2: No
permission to release metta_base_space '&metta'` when `catalog =
m.space("&metta")` is still referenced, and succeeding when it is not.

Root cause found one line above the loop that raises: `MeTTa.space()` appended
EVERY handle it returned to `self._minted`, and `close()` released them all.
The name says mints; the code recorded borrows too. Measured on `petta`
(`ai-tmp/probe_named.py`), the second consequence is worse than the reported
one: two contexts open `&probe-shared`, the first writes one atom, the first
CLOSES, and the second context's live handle answers `len` 0 with the name gone
from `space_names()`. A named space is process-wide state; a reader closing is
not its end.

Third consequence: the record was a `weakref.ref`, so which of those releases
happened depended on when the collector ran. The reported symptom is exactly
that (`[True]` red, `[False]` green in the parametrised regression on trunk).

Decided: record only `name is None` mints, STRONGLY, in a
`dict[str, Space]` keyed by the engine name. Strong, because the set of spaces
a close releases must be decided at mint time and not by the collector. A dict
keyed by the name, because a dropped anonymous name goes back to the engine's
pool and the next mint draws it again, so a churn of scratch spaces replaces
its own entry instead of accumulating one record per mint; the engine's pool is
what bounds the container.

Rejected: releasing the mints newest-first, which a resource stack would.
`parent = m.space(); m.space(inherits=parent)` is an uncloseable context under
creation order (measured: `EngineError &pyspace_2 cannot be dropped while live
child &pyspace_3 inherits from it`), and LIFO would close it. But
`test_close_still_refuses_for_a_declared_heir` pins that refusal as the ruling:
an `(inherits ...)` relationship is the program's own declaration and the world
teardown refuses rather than sweeping the heir away. The refusal is loud, names
the heir, and states the remedy, and `metta_assert_space_releasable/1` performs
it before anything is torn down. Revisit only if that ruling is revisited.

Evidence: `test_a_context_closes_the_same_way_whether_a_base_space_handle_lives`
(parametrised on whether the handle is still referenced) and
`test_a_context_close_leaves_a_named_space_it_only_opened`, both red against
`petta`'s `_space.py` planted under the branch's tests (`[True]` raises the
permission error, the named space answers 0), both green on the branch;
`tests/ch04_spaces_and_matching` and `tests/ch19_spaces_backed_by_anything`
pass whole, 795 passed and 51 skipped.

## 2026-09-06, the doors that drifted apart

Reported as `metta.tables.declare` and `TableBridge.from_context` refusing a
context with `AttributeError: MeTTa has no 'parse'` while `metta.arrays.install`
and `metta.integrate.integrate` had learned to take either through
`metta.integrate.space_of` (2026-09-04, `a-tracer-is-an-array-of-its-own-library`).

Enumerated rather than guessed: every public callable with a space-shaped
parameter was called with a `MeTTa` and its failure recorded
(`ai-tmp/probe_context_refusals.py`, `probe_context_refusals2.py`). Eleven doors
across seven modules refused, not two: `tables.declare`,
`tables.TableBridge.from_context`, `casting.cast`, `lint.lint`,
`lint.lint_file`, `structures.TabledMap`, `structures.LiveView`,
`structures.ClosureView`, `algebra.declare/evaluate/sample`,
`arrays.EmbeddingStore`, and `remote.Gateway` (hence `serve`), each on a
different Space door: `parse`, `name`, `arities`, `subscribe`, `_space`.
`tables.add`, `spaces.union` and `algebra.resolve` accepted a context by
accident, because they happen to touch only doors `MeTTa` forwards.

Decided: one resolution, at each door's own boundary. The implementation moves
to `metta._api_types`, which imports nothing but `typing`, and
`metta.integrate.space_of` stays the public spelling and delegates to it.

Rejected: importing `metta.integrate` from the leaf modules. The import-linter
contracts stay green with the edge (measured), but `metta.casting` costs 10.9ms
to import and `metta.integrate` 41.2ms, so `casting` and `lint` would have
quadrupled their own import for a two-line duck-typed resolver, which is the
cost the "leaf modules do not import the facade" contract exists to prevent.
Revisit if `integrate` ever becomes as cheap as `atoms`.

Rejected: a bare re-export, `from ._api_types import space_of` in
`integrate.py`. `tools/reference.py` builds `website/reference/metta-*.md` from
each module's own AST, so a re-export is not a `def` and the public door would
have vanished from its reference page.

Evidence: `test_every_space_door_takes_a_context_or_a_space`, fifteen doors
times two receivers. Against `petta`'s copy of the nine modules, 12 of the 15
context cases fail and all 15 space cases pass; on the branch all 30 pass, with
`test_embedding_store_takes_a_context_as_well_as_a_space` beside its `install`
sibling in the arrays suite. Import contracts stay at 3 kept, 0 broken.

## 2026-09-06, the scope that covered the sources and missed the writes

Reported as `with m.speculative(): m.add(atom)` leaving the atom behind, and
`with m.atomic():` keeping a write when the block raises, with the audit's
reading that the scopes are source-shaped by design and Python-side writes are
simply outside them.

Measured first, because the reading decides the fix. The scopes are per-CALL
policies, and that is already observable: inside `with sp.speculative():` an
engine-source write is invisible to the very next call in the same block
(`[[]]`), and `with sp.atomic():` rolls back a multi-statement run that trips
an inference bound (`[[]]` scoped against `[[yes]]` unscoped) while a raise
after a committed call keeps its work in either scope. `_controlled_run` in
`_space_execution.py` is the one place the policy is applied, by design ("No
caller selects individual wrappers"), and `add`, `remove`, `__delitem__`,
`transfer` and `clear` were the doors that bypassed it, calling `rt.do_must`
and `rt.apply_must` directly.

Tried: holding one boundary open across the whole block, which is what the
report's "route the block's Python writes through the scope's snapshot engine"
would need. SWI has no begin/commit pair, and the one mechanism that suspends
a goal across host calls is an engine, so the question is whether an engine can
yield inside `transaction/1` or `snapshot/1`. It cannot:
`engine_yield/1` raises `permission_error(execute, vmi, 'I_YIELD')` with
context "not an engine" inside either, on SWI-Prolog 10.1.13
(`ai-tmp/probe_held_tx2.pl`, `probe_held_snap.pl`; the same file's control
without the wrapper yields normally). The shim's own held cursor already works
around this by materializing every answer inside the boundary and replaying
after it, which a with-block cannot do because the block's statements are the
host's, not a goal's answers. So `Space.transaction`'s standing ruling holds:
there is no `with m.transaction():` and cannot be one.

Decided: not a refusal but the policy. A scope is per CALL, so a write door is
a call like any other and goes through the same wrapper. Refusing a write
inside a speculative block would be a wall neither language requires, since
the snapshot covers a write call exactly as it covers a run call, and refusing
one inside an atomic block would refuse the Python door while the source door
beside it in the same block commits.

The engine's own precedent decides where a refusal WOULD belong:
`metta_with_state_write_fence/1` fences `new-state` inside a speculative scope
because `nb_setval` state is not rolled back by `snapshot/1`. The Python
equivalent is `clear`'s definition registries, which the snapshot cannot undo
either; they are held back until the engine write stands rather than being
refused, which leaves the whole clear discarded and the mirror describing what
the space still holds.

Rejected: routing every write through the output-carrying crossing so one
helper serves both shapes. `janus.apply_once` costs 6.7% more instructions per
write than `janus.cmd` (44,782 against 41,966 instructions:u per
`metta_py_add` over 100,000 writes, control-subtracted, min of 3, three rounds
agreeing within 0.05%), and the idiomatic write must also be the fast one. The
void doors keep `cmd` outside a scope and answer through a unit-carrying face
of one greater arity inside one, `metta_py_add/3` beside `metta_py_add/2`.

Evidence: `test_every_public_write_door_honours_the_execution_scopes`, nine
doors each with its own control, plus
`test_an_atomic_scope_makes_one_python_write_one_transaction` (a transactional
provider that refuses the second row: unscoped leaves `(row 1)` with no
begin/commit ever issued, atomic leaves nothing and records
`['begin', 'rollback']`) and
`test_an_async_write_door_inherits_the_scope_across_the_worker`. All ten are
red against `petta`'s `_space.py`, `_space_execution.py`,
`_space_definitions.py` and `shim.pl` and green on the branch.
