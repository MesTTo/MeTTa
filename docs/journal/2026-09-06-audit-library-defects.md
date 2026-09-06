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
