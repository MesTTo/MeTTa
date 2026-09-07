# The array roster lives in the space
Goal: `arrays.install` records what it installed where the install happened, so
two spaces on two libraries answer their own rosters in any order.
Constraint: the operation registry is process-wide by NAME, so a per-space
roster may not unregister what another space still uses; the record must die
with its space, because anonymous space names are pooled.

## 2026-09-07

Tried: reading the defect back at its source. `install()` ended with
`ARRAY_OPS[:] = registered` (`extensions/python/metta/arrays.py:859` before
this change), a module-level list every install anywhere in the process
rewrote. `--randomly-seed=4` puts a JAX install before
`test_every_array_operation_is_typed_and_a_shape_is_a_constraint`, which then
asked the NumPy-installed space for the type of `tensor--jax.numpy` and read
`%Undefined%`. The Arrow follow-up branch fixed the three borrowing tests by
snapshotting the list (`0800a265`) and left the name to its owner
(`docs/journal/2026-09-07-merged-tree-reconciliations.md`, Open).

Decided: the roster is a row in `&metta`,
`(array-backend <space> <library> (ops <name> ...))`, kind
`(kind array-backend symbol symbol term)`. `ops(space)` and `backend(space)`
read it; `install` writes it; `uninstall` and a second install replace it.
Because it is catalog data rather than a Python attribute, a MeTTa program
reads the same fact: `!(match &metta (array-backend &s $lib $ops) $lib)`.

Rejected: `(kind array-backend symbol symbol (rest symbol))`, the flat form
`vocabulary` and `claim` use, which would have the engine check every roster
name is a symbol. It creates an `&metta` storage arity of 47, and the
open-tail catalog read walks `current_predicate` over every stored arity; the
same effect was measured at +2,302 inferences per `register-op` before the
write-path cache existed (`engine/spaces/catalog.pl`, the cache comment). The
wrapped payload keeps the row at arity 4, follows `algebra`'s own
`(laws ...)`/`(carrier ...)` fields, and leaves the row extensible. Revisit if
a reader ever needs the roster indexed by name rather than read whole.

Tried: making the row retire on drop. `metta_retire_space_catalog/1` walks
`metta_space_catalog_head/1`, which is one data-driven clause
(`metta_routed_head(Head, context)`) over twenty-two hardcoded ones. A
third-party kind therefore reaches the walk only by declaring
`(routed-by-shape H)`, and `metta_route_shape/3` forces the shape
`(H Ctx Pattern Payload...)` on it. A roster has nothing to dispatch on.

Decided: `(owned-by-space <head>)`, a new marker kind shipped as a preset,
with `metta_space_catalog_head(Head) :- metta_catalog_row(['owned-by-space',
Head]).` beside the routing clause. The library declares the marker for its
own head; the engine ships the marker's kind. Refused at the write unless the
head already has a kind row starting at `symbol`, the same eager check
`routed-by-shape` makes, because the walk reads position 1 as the owning space
and a kind keyed by something else would have rows deleted by whichever space
was spelled the same.

Research mapping: recording the ownership edge as data so the owner's teardown
walks stored edges is PostgreSQL's `pg_depend`, which is how `DROP ... CASCADE`
reaches an extension's own objects
(https://www.postgresql.org/docs/18/catalog-pg-depend.html), and Kubernetes'
`ownerReferences`, which is how garbage collection reaches a custom resource's
children. Both replaced exactly this: a list of dependent kinds compiled into
the server. The 2026-09-06 thread
(`2026-09-06-algebra-rows-die-with-their-space.md`) had already mapped this
walk onto cascading foreign keys; this makes the edge itself declarable.

Rejected: converting the twenty-two hardcoded heads into preset
`(owned-by-space ...)` rows for uniformity. Every space release would then do
twenty-two catalog lookups where it now does clause dispatch, and removing a
preset row would silently disable a shipped head's retirement. The file
already carries one data-driven clause above the hardcoded list, so the mixed
shape is its own. Revisit if a third head needs the marker and the hardcoded
list starts drifting from what the walk should cover.

Rejected: making `Space.drop` unregister the space's array operations the way
it calls `integrate._forget_space`. The engine retires the row inside
`metta_py_drop_space`, before the Python satellite hooks run, so the hook
would find no roster to work from. The division stands and is documented on
both doors: a drop retires the declaration saying which space had the
operations, `uninstall` hands the operations back.

Tried: `_SPACE_CONSTRUCTORS`, the other module-level dict keyed by
`(space name, constructor)`, is now derived. The alias equations to withdraw
follow from `_CONSTRUCTOR_ARITIES` and the library the outgoing row names, so
the dict is gone and the same pooled-name staleness it carried goes with it.
`_SPACE_STORES` is untouched: it belongs to `EmbeddingStore`, not to the
roster, and is recorded as open below.

Tried: the planted-defect run, one defect at a time, each reverted after
(`ai-tmp/ao-planted-verdict.txt` in the branch's worktree).

    p1  ownership clause removed from catalog.pl
        -> catalog_lifecycle:release_retires_a_third_party_owned_by_space_kind
           fails at its assertion; test_dropping_the_space_retires_its_
           installation_row reads `[[numpy]]` where it wants `[[]]`
    p2  ownership check short-circuited
        -> both catalog_self_description refusal tests fail
    p3  install stops draining the outgoing row
        -> test_a_second_install_replaces_the_roster_and_its_operations and
           test_the_roster_doors_refuse_an_uninstalled_space_and_a_doubled_row
    p4  _retire_unclaimed ignores other spaces' claims
        -> test_uninstall_retires_the_installation_and_keeps_shared_operations
    p5  the roster pattern stops keying on the space
        -> test_a_space_answers_its_own_roster_in_either_install_order, both
           parameters

Tried: `sh extensions/python/test.sh -n 0 tests/ch08_data tests/ch09_types
tests/ch01_getting_started/test_api_types.py` -> 368 passed, exit 0.
`--randomly-seed=4` over `test_arrays.py` -> 73 passed, exit 0, the seed that
exposed the process-global roster.

Tried: the first full run of the touched suites, which found the new
`uninstall` incomplete and then a defect underneath it.

Tried: `uninstall` on a space sharing numpy with another -> the space kept 160
declaration atoms and `!(t-shape (tensor--numpy (1.0 2.0)))` still answered
from it. `unregister_op` is whole-process and may not run while another space
claims the operation, and there was no per-space half.
Decided: `metta.ops.withdraw(runtime, name, space)`, modelled on `unregister`
directly above it: it releases one space's holdings through the same
`_release_declaration` and leaves the operation registered for the rest.
After it, the same measurement reads 0 atoms and the holdings drop the space.
A registered operation stays callable from any space by its namespaced name
while another space claims it, which is the engine's own semantics for a
registered operation and not something an uninstall can change.

Tried: `test_install_is_idempotent_and_uninstall_empties_the_space` then read
37 atoms after an install where a fresh process reads 197.
Root cause, measured (`ai-tmp/probe-ao-pooled.py`): `_DECLARATION_REFS` in
`ops.py` is refcounted by `(space name, declaration)`, anonymous space names
are POOLED, and nothing dropped the entries when a space was released. A
space that installed the arrays and was dropped left 160 entries under its
name; the next space to take that name found count > 0 and SKIPPED every
declaration add, so its operations were callable and declared nowhere. This
predates the branch: any space that registers an operation and is dropped
does it.
Decided: `ops._forget_space(space)`, called from `Space.drop` beside
`integrate._forget_space` and algebra's, dropping that space's refcounts and
holdings. After it the recycled name reads 0 stale entries and 197 atoms.
This is the third leak of this exact kind the lifecycle suite records, after
the stored clauses and the typing rules, and it joins them there.

Rejected: weakening the idempotence test to accept 37, because the number is
the defect rather than a property of the install.

Tried: the two further planted defects, same harness
(`ai-tmp/ao-planted-verdict2.txt`).

    p6  withdraw releases nothing
        -> test_withdrawing_one_space_leaves_the_other_space_declaring_it
    p7  drop stops calling ops._forget_space
        -> test_a_recycled_space_name_declares_its_own_operations

Tried: `sh extensions/python/test.sh -n 0 tests/ch08_data tests/ch09_types
tests/ch20_extending_the_engine tests/ch04_spaces_and_matching
tests/ch01_getting_started/test_api_types.py` -> 1001 passed, 1 skipped, 1
failed. The one failure is `test_the_vocabulary_module_is_generated`, which
is inherited from the base: `cost-class`, the vocabulary the cost-rows work
added, never reached `extensions/node/src/vocabularies.ts`. At 70ac99da that
file has no `CostClass`; the main checkout at 85b7c693 has four occurrences,
so trunk fixed it after this branch was cut and the merge carries the fix.
Regenerating it here was reverted rather than committed, to keep a generated
file from conflicting with the commit that already fixed it.
`--randomly-seed=4` over `test_arrays.py` -> 74 passed, exit 0.

Open: `_SPACE_STORES` in `arrays.py` is the same shape of process-global that
`_SPACE_CONSTRUCTORS` was, keyed by `(space name, store name)` and never
retired. Measured on this tree: a space holding an `EmbeddingStore` named
`probe` is dropped, the pooled name comes back as the next `space()`, and the
dead life's `('probe--store-1-knn', 'probe--store-1-embed')` entry is still in
the dict with both operations still in the process registry; a second store of
the same name in the new life answers correctly, because the serial makes its
internal names unique and the stale removal is a no-op on an absent atom. So
this is a leak, of dict entries and of orphaned process-wide operations, and
not a wrong answer. It belongs to the store rather than to the roster and is
untouched here; the shape of the fix is the roster's, a per-space row the drop
retires, plus a door that hands the internal operations back.
