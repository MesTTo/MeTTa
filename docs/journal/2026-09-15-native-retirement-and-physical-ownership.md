# Native retirement and physical resource ownership

Goal: a space retired inside a transaction follows the transaction's outcome
on every side at once: native rows, models and ownership, the lifetime
scope's record, the host handle and the resources it owns.
Constraint: no user or foreign callback, evaluator, engine join or resource
release runs under the SWI event-list, execution-module, support-graph or
scope-bookkeeping locks; the durable native outcome stays separate from a
fallible completion result; nursery ownership stays outside rollback.

## 2026-09-15

Measured (`ai-tmp/ai-general-lifetime-retirement-probe-v3.py`, 12 cases in
fresh processes, feature and pristine c751 agreeing): a `Space.drop()` or
`scope_drop_space/1` inside `home.transaction(...)` followed by an abort
restored the rows and the storage cache but left the Python handle
`dropped=true` and, for a scoped space, the scope record revoked so that
cleanup refused `released_scope_space`. An unscoped native drop that
committed left the retained Python handle live.
Decided (`ai-tmp/ai-retirement-state-contract.md`): separate the database
decision from physical ownership. Logical retirement runs with the
transaction and records a witness; physical revocation, provider
unregistration, backing close, queue destruction, host registry mutation and
name pooling wait for the outer outcome and its foreign participants; a
unique native registration per shared weak host cell replaces any per-name
counter; provider admission spans the whole use and a close waits for it;
class withdrawal splits into `prepare_withdrawal` and `reconcile_withdrawal`.
Rejected: a per-name retirement counter, because temporary names would keep
tombstones. Rejected: a `_dropped` inverse, because it cannot restore
subscriptions, provider state, backing resources, scope ownership or pooled
names.

## 2026-09-16

Decided: `metta_release_space/2` keeps the existing logical teardown inside
the caller's transaction and appends `assertz(metta_space_retired(Space,
Token))` to the same `transaction/1` block, so the witness rolls back with an
abort; `seam:space_released/1` and the host completion move to
`metta_engine:metta_after_foreign/2`, which runs after the outer native
outcome and the captured foreign participants, or before the call returns
when no transaction is open. The completion reads the witness, reports
`retired` or `restored` to the host goal, and fires the seam hooks only for
`retired`. This is Django's `transaction.on_commit`: registered inside the
transaction, run after the outermost commit, discarded on rollback. A second
release of a space already pending in the transaction is a no-op; with a
host goal it refuses `permission_error(release, pending_retirement, Space)`.
Decided: the host completion runs before the seam hooks. Measured: with the
hooks first, lib_thread's `seam:space_released/1` marked the scope record
`retired` and the handle's cleanup, whose bookkeeping handle reaches the
name through ordinary doors, was refused `released_scope_space`
(test_space_retirement.py, both scoped commit cases). The old flow ran that
cleanup inside `scope_release_/4`'s `$metta_scope_cleanup` window.
Decided: `scope_release_/4` no longer forgets the record after the host's
drop returns; the host's completion forgets it after the outcome, and
lib_thread's hook marks `retired` only when a host never does.
Decided: the Python handle passes `_released` to `metta_py_drop_space/2`;
`_released(retired)` runs the former in-drop cleanup as `_finish_drop`,
`_released(restored)` unpends the handle; a pending handle refuses every
operation with a message naming the transaction; `dropped` reports the
durable state. Measured: an `OSError` raised by a backing close inside the
completion crossed the engine and reached `drop()` as `EngineError` holding
its transcript (test_drop_recovery.py); `drop()` now re-raises the original
the way `transaction()` already does, through `_original_python_error`.
Tried: host completion first, hooks only after a successful host -> ch17
test_scopes.py::test_cleanup_failure_revokes_aliases_attempts_all_and_can_retry
red: a backing close that fails inside the host's cleanup raised out of the
completion before lib_thread's hook revoked the scoped name, so an alias read
live. Decided: the hook phase is the cleanup of `setup_call_cleanup/3` around
the host call, so it runs whatever the host did and the host's exception still
propagates; the host retries its own half through another `drop()`.
Decided: the door docstrings feed generated projections, so `doorgen.py
--write` and `reference.py --write` regenerated `aio/_mirror.py`,
`python-door-contracts.md` and five reference pages; `metta-foreign.md` had
drifted since the participant-capture commit 05fae56ad and `metta-aio.md` and
`metta-parallel.md` carry the same drop paragraph through the mirror.
Verified: space_retirement 9 native controls; release_preparation, spaces,
lib_thread_scope, lib_thread_cancellation, lib_thread_completion, hooks,
completion_results, host_transactions, participant_capture,
catalog_lifecycle, tabling_transactions, lib_import, base_spaces; Python
test_space_retirement.py 11 (the V3 matrix as 8 cases plus pending refusal,
immediate completion and late-cleanup retry), test_drop_recovery.py 3,
test_algebra_lifecycle.py.
Open: an unscoped native drop that commits still leaves the retained Python
handle reporting `dropped=False`; the host registration lease (next unit)
marks retained handles dead from the native side. Open: `untable/1` inside
`metta_host_clear_tabling/2` is physical and precedes the outcome; V3's table
control showed answers and properties restored after abort, so no repair is
selected. Open: commit validation of writes against a retired allocation and
of retirement over concurrent live state, provider admission intervals with a
waiting close, the class withdrawal producer and reclamation counts remain.

### R2 host registration lease

Decided: one engine row `metta_py_lease(Space, Lease)` per live name with a
Python handle, opened by `metta_py_lease_open/2` inside the caller's
transaction on the first handle and shared by every later handle of the name
through `metta._spaces.lease` (`_BY_NAME` and `_BY_LEASE`, both weak). The
lease number, not the name, is the identity every report carries, so a name
reused after a drop starts a second life a first-life handle cannot reach. A
`metta_after_foreign/2` completion registered at open reads the row after the
outcome; its absence means the birth was aborted and the cell learns that by
lease number (`metta_ops:lease_aborted/1`). Retirement reaches the binding
through a permanent `seam:space_released/1` provision that retracts the
name's rows and reports each lease (`metta_ops:space_released/1`); it runs in
the hook phase, after the retiring handle's own completion. A collected cell
releases its row through `defer_engine_call("metta_py_lease_release", ...)`.
Tried: the provision as a `provides_template/4` row like `atom_added` ->
never installed. Templates become `provided_template/2` facts that a
subscription installs on demand through `metta_py_provided_clause/2`, so
`seam:space_released/1` had only its multifile declaration and no retained
handle read dropped: 16 reds across test_space_leases.py,
test_space_retirement.py and test_scopes.py (ai-tmp/ai-lease-python-1.log).
Decided: a permanent `provides/3` row; the hook runs only at release
completion and the retract is a no-op without rows.
Tried: the aborted-birth completion holding the cell's bound method as a
crossed host, `py_call(Host:'__call__'())` -> janus retained the crossed
object until atom GC (2026-09-15-foreign-participant-capture.md), so
the transient cell, every handle of it and its row survived `gc.collect()`:
test_lease_rows_follow_outstanding_handles read 1 row where 0 were owed.
Decided: both reports name the lease through `metta_ops` callbacks; no
Python object crosses, and no `Capability` row for a dynamic `__call__` is
needed.
Measured: the two above also explain the last false reading. A name released
without the hook kept a live cell in `_BY_NAME`; the pooled name was minted
again inside an aborted transaction; the new handle shared the stale cell
instead of opening a lease, so the abort never reached it
(test_a_handle_born_in_an_aborted_transaction_is_dead read dropped=False),
and the same stale cell reported `did not commit` on a live handle in
test_a_rolled_back_allocation_cannot_recycle_a_revoked_name.
Decided: the per-handle cleanup obligation stays separate from the shared
life. `dropped` is `_dropped or (cell dead and not _drop_engine_done)`, so a
retiring handle whose engine half committed but whose backing close failed
reads False and its gate says `call drop() again` before the cell's refusal
(test_cleanup_failure_after_a_committed_drop_is_retryable,
test_backing_close_failure_keeps_the_name_and_cleanup_retryable). The
`lib_thread:scope_engine_released/1` and `scope_space_dead/1` queries leave
`drop()` and `dropped`: the scope's release fires the same hook.
Decided: a dead alias refuses in Python with the cause before any engine
crossing. ch17 test_cleanup_failure_revokes_aliases_attempts_all_and_can_retry
expects `is dead: its space was dropped` where it read the engine's
`released_scope_space`, which still guards raw names reaching the engine.
Decided: `name` stays a live-state door; the rolled-back allocation control
reads the name inside the transaction body while the handle is live.
Measured: with the shared life reporting truthfully, `MeTTa().space()` was
a silent use-after-release: chapters 04/15/17/19 read 12 reds and 22 fixture
errors, every one `is dead: its space was dropped` on a handle the test
still used (ai-tmp/ai-lease-chapters-1.log), and the memory-scale benchmark
CLI, the digest subprocess control, the C-space, TypeScript-space and
compliance fixtures all mint through an unreferenced context. The context's
home handle is what the abandoned-world backstop watches; nothing minted
inside the world held it, so the collector dropped the world under the
child and the child kept writing into a revived name, which the pool scan
tolerates by design. test_a_borrowed_context_leaves_its_minted_handle_with_the_caller
asserted both halves of that: the child's name gone from the engine and
`dropped` still False.
Decided: a space minted with an equation home holds that home handle
(`SpaceHandle._world`), the rule the backstop already stated for
`MeTTa().self` extended to every reference handed out of a world; the
borrowed-context control now reads the child dropped once the owner
closes, and test_a_child_handle_outliving_its_context_keeps_the_world is
the fresh-process control. Rejected: teaching the idiom away in tests and
docs, because the idiom is documented (website tutorial, multishot, the
integrations page, `metta/__main__.py`, sixteen examples) and the rule is
the library's own.
Measured: a bare crossing costs 12 inferences, a first handle of a name 32,
a cached attach 14, a named-space door 40, a first handle inside a no-op
transaction 511 (the transaction wrapper, not the lease)
(ai-tmp/probe/ai-lease-cost-probe.py). The completion that reports an
aborted birth is scheduled only inside a transaction, since nothing else
can take the row back. The spaces3 twin reads 545 here against a pin of
371; in provisioned worktrees the chain is 371 within budget at c80041350,
383 at 709e556c1 (completion and admission-law units), 524 at 1a8c00f93
(the FROM source-origins reader, +141 on this twin's four written forms),
524 at c1961afeb and 9d7d4164c, 545 here (+21, the lease). Re-pinned with
that chain through twin_coverage.py --repin.
Decided: a name's lease stays weak rather than cached for the process: a
strong cache would drop the finalizer and the release crossing but leak a
row for every name a handle ever named and never created, and the measured
cost of the weak design is one crossing per first handle, not per handle.
Measured: the repository suite at 9d7d4164c was already red on four static
checks the recent units never ran: the host-service scoreboard lacked nine
declared rows, the llms sources table's unit and kind counts, the ruff
suppression ceilings (68/64/157 observed against 67/62/152, identical at
HEAD and here), and four journal citations by absolute path. Repaired in
their own commit ahead of this unit's.

### R3 commit validation, plan

Goal: a write cannot commit against an allocation retired since its
snapshot, and a retirement cannot commit over live state its prepared
withdrawal did not remove.
Decided: one more `seam:transaction_constraint/1` row beside the owned
records' (engine/spaces/owned_records.pl), collected at the outer boundary
in engine/metta/space_hooks.pl and run by SWI's transaction/3 after the view
is refreshed to the global state plus this transaction's changes. The
preparation reads `transaction_updates/1` once, the validation reads only
native clauses; no evaluator, provider, host callback or source loader runs
under the materialization mutex.
Decided: three checks from the contract. (1) A writer's allocation: every
storage module this transaction asserted into or erased from maps to
`native_storage_module_cache(Space, Module)`; the cache clause reference
the writer observed must still be live in the refreshed view unless this
transaction asserted it itself, and a retirement committed by another
transaction erased it. (2) A retirement's residue: for every
`metta_space_retired(Space, Token)` witness this transaction asserted, the
refreshed view holds no clause in the storage module and no
`metta_exec_module_known`, `native_storage_module_cache`,
`space_equation_home` or `space_parent` row for the space beyond the ones
this transaction erased; a concurrently added equal-valued occurrence is a
surviving clause, so clauses are counted, never compared. (3) A retirement's
attachments: no `space_parent(_, Space)`, `space_equation_home(_, Space)` or
source-owned publication (`filereader:source_owned_space/2`) for the space
survives in the refreshed view. Empty and row-only allocations take part
through their cache clause, which is their native identity.
Decided: the refusal is an error term with its own message, the way
`metta_owned_record_conflict/2` is, not a catalog refusal row:
`metta_retirement_conflict(writer(Space), retired)` and
`metta_retirement_conflict(retirement(Space), Problem)` with Problem one of
`occurrences(N)`, `children(N)`, `publications(N)`, each naming the outer
transaction retry as its remedy. A losing retirement's witness rolls back
with the transaction, so its completion reports `restored`, its scope keeps
the name and its backing stays open, which R1 already guarantees.
Decided: the two-worker overlap harness (`overlap/4`, `worker/4`, `stage/3`,
`with_queues/2`, `worker_cleanup/2`) leaves owned_records.plt for
tests/prolog/overlap_transactions.pl, consulted by both suites, since the
retirement suite is its second user and the two are one harness by
construction.
Controls: writer-first and retirement-first commit on both roots, same-value
occurrence replacement, a definition publication and a source publication,
a new owned child and a new equation-home child, an empty allocation and a
row-only allocation, nested commit and abort, inner abort with outer commit,
snapshot entry, and native-origin entry; disjoint and multivalued writes as
positive controls; a losing retirement keeps its scope record and its
Python handle live (restored). Python: ch15 controls through two engines
of one process, the refusal arriving as MettaError from transaction() with
the retry remedy, the handle usable afterwards.
Open: whether `transaction_updates/1` lists the storage-module asserts of a
foreign-backed space (it should not; a provider's rows are not native
clauses), and whether a retirement of a space with tabled equations leaves
table clauses the residue count must ignore (untable/1 runs before the
outcome, so none are expected).

### R3 commit validation, results

Verified: the two SWI facts the plan rests on, in a throwaway probe
(ai-tmp/probe/ai-r3-swi-probe.pl): a nested transaction's asserts are in the
outer constraint's `transaction_updates/1`, and a clause reference erased
by another thread's committed transaction fails a bound-reference
`clause/3` inside the refreshed constraint view, discarding the writer.
Tried: counting every clause of the retired storage module ->
`occurrences(1)` on a solo retirement: the storage funnel keeps an inert
sentinel clause with body fail (`native_storage_sentinel/2`, catalog.pl).
Decided: the residue reader enumerates with body true, as every row reader
does.
Tried: `native_storage_module/2` for the retired space's module -> no
residue for parametric spaces, whose mapping needs the registration the
retirement withdrew, so the owned-record validator answered instead and a
retirement of an unowned parametric space would have committed over a
concurrent write. Decided: preparation takes the storage module from the
cache clause the retirement erased, through `metta_owned_cache_reference/3`,
the owned records' own recovery of a retired identity.
Decided: the retirement validator's clause loads before the owned records'
(spaces.pl consults lifecycle.pl first), so a write racing an owned record's
storage retirement is refused with the space-level root cause; the owned
records suite's four prototype-drop cases expect
`metta_retirement_conflict` with the same retry remedy.
Measured: space_retirement 24 (fifteen new overlap controls: both commit
orders, removal, equal-valued replacement both ways, a definition, an
equation-home child, an heir, an empty allocation both ways, a nested
commit, an inner abort, a snapshot, disjoint and multivalued writes);
owned_records 29 with 75 subtests on the shared harness; Python
test_commit_validation 3 and test_class_owned_records 33 on the `overlap`
fixture.

### R4 provider admission intervals, plan

Goal: a provider's registration is held for the whole of every operation
that uses it, iterator pulls included; a close stops new admission, waits
for admitted uses, then runs its callbacks outside the bookkeeping locks;
an older snapshot cannot invoke a closed provider; a callback that retires
its own admitted provider does not wait on itself.
Found: `metta.foreign.PROVIDERS` is a read-only view over the engine's
`@python-provider` owned-record rows (one crossing per lookup); every
`foreign_*` door looks the provider up once at entry and streams through
`guarded/2` with no admission held, so `unregister_provider` can remove the
row and a backing can close while a pull is mid-flight. The remote gateway
already has the shape wanted (`_gateway.py:close`: stop accepting, stop the
worker, release cursors last, refuse to close itself), and
test_remote_close_waits_for_worker_detach is its control.
Prior art: RCU/SRCU read-side sections with a grace period; Go's WaitGroup
behind a closed flag; Python's Executor.shutdown(wait=True); asyncio
Server.wait_closed. The shape is a per-registration admission record:
count, closing flag, condition; admit at every door entry (refuse with the
provider's own closing error once closing), release when the door returns
or its generator finishes, closes or is collected (release in the
guarded stream's finally); close sets closing, waits for count 0, then
removes the engine row and calls the provider's close outside the lock.
Decided (plan): the record lives beside the provider in the binding's
Python registry rather than in the engine, because pulls never cross the
engine; the engine row remains the authority for WHICH provider a name
has, and the admission decides WHEN it may be used. A close requested from
inside an admitted use of the same provider (self-retirement) marks closing
and hands the physical close to the deferred queue, reporting pending
rather than deadlocking; a close from another engine thread waits.
Controls: a provider callback and an iterator held open in another engine
while close is requested (close waits, new admission refused); an older
snapshot holding the provider name cannot invoke it after close; failure,
cut and cursor close as release paths; self-retirement from a callback
completes after the callback exits; the two-resource prefix fixture.
Open: whether the engine's `seam:foreign_*` clauses should ask admission
before `py_iter` (one more crossing per operation) or Python's doors alone
carry it; the plan is Python-only, since every use enters through a door.

### R4 provider admission intervals, results

Decided: the admission record lives in `metta.foreign` beside the registry
view (`_Admission`: count, per-thread holders, closing flag, condition,
pending action); `_admit` checks the engine row of the caller's snapshot
still names the record's provider, so a registration rolled back leaves a
record that is dropped on its next use and a row from outside the registry
is refused. Every door admits through `_admitted` (synchronous) or
`_admit` plus `_admitted_stream` (streams, released in the generator's
finally, so exhaustion, a closed cursor, a backend failure and an engine cut
all release; janus closes the iterator on the cut). The transactional
participant admits in its wrapped begin and releases in commit or rollback.
Tried: a `then` callback on `unregister_provider` for the owner's backing
close -> unnecessary once the drop path itself goes through the close: the
handle's `drop()` used `metta_py_unregister_foreign` directly, bypassing the
admission, and a self-retiring drop then had the engine's own foreign clear
refused as closing. Decided: `drop()` calls `unregister_provider`, and a
drop requested while the calling thread holds an admission of the same
provider (`self_admitted`) sets the handle pending and retains the whole
teardown through `after_last_release`; the last release runs it from the
generator's finally, one nested engine query deep, the same depth every
provider callback's own crossing already uses.
Measured: the first control's new-use refusal came from the pending
handle's own gate, not the provider's; the control reaches the provider by
name. Eight controls pass (test_provider_admission.py): close waits for a
held pull and refuses new admission by name; exhaustion, closed cursor,
backend failure and cut each release; an older snapshot's transaction
cannot invoke the closed provider; a self-retiring drop completes at the
last release with `closing` True until then; an enlisted participant is
held from begin to commit. test_foreign 46 and test_drop_recovery pass.
Open: the two-resource prefix fixture named by the contract's controls is
not written; the reading of "two resources" (a provider and a cursor of one
registration, or two registrations sharing a prefix) is settled when the
class withdrawal producer (R5) names which it needs.
Tried: `unregister_provider` as the waiting close (row removal after the
admitted uses drain) -> ch15 test_participant_capture deadlocked under the
battery: test_an_independent_snapshot_keeps_its_original_provider replaces
the registration from the main thread while another engine's transaction
holds the provider enlisted and waits for the replacement, and the
same-transaction replacement controls found the row still standing. The
existing design already lets a registration change under an admitted
batch: the captured begin/commit/rollback keep the old provider callable.
Decided: the row goes at once, inside the caller's transaction, and the
registration's `Admission` is returned instead; it admits nothing new (a
transaction whose snapshot still holds the row is refused), and the owner's
PHYSICAL retirement waits on it (`Space.drop` waits before the engine
retirement, or retains the teardown through `after_last_release` when the
caller holds one of its uses). A record whose row was edited natively
follows the row: the stale record closes to new uses and a fresh one is
made for the row's provider (test_native_provider_edits_change_the_public_projection).
The participant suite is unchanged; nine admission controls pass, the
same-transaction replacement among them.

### R5 class withdrawal producer, plan

Goal: split `_declare/classes.py:release` into the agreed producer pair
(ai-tmp/ai-class-withdrawal-contract.md): `prepare_withdrawal(home_names)
-> ClassWithdrawal`, whose native writes ride the surrounding transaction
while every affected home is still admitted, and
`reconcile_withdrawal(receipt, retired_homes)`, which changes Python
instrumentation, registrations and owned provider records only for the
homes the native outcome retired and refreshes surviving projections once.
Found: `release(space)` today runs after the engine retired the space
(`_finish_drop` -> `release_definitions` -> `classes.release`): it closes
the dependency graph, withdraws native rows outside the retirement's
transaction, restores instrumentation, and drops dependent class homes
itself (`plan.space.drop()`), a second lifetime mechanism; borrowers and
`space.dropped` decide retention on the Python side.
Decided (plan): `ClassWithdrawal` is a frozen dataclass carrying the
requested homes, the additional class homes of the dependency closure
(`homes`), the retired candidate plans, the surviving plans, and a
progress set so a failed reconciliation retries only the plans not yet
done. Preparation closes dependents through `bases` and `references` (the
standing class edges), withdraws the candidates' record, method and
inherited rows through `_withdraw_rows` inside the caller's transaction,
and returns; it touches no Python state. The consumer is `Space.drop()`:
when the name is a class home, the drop runs its group in one engine
transaction (prepare, drop each additional home, drop itself with the host
completion), each home's completion records its outcome on the receipt,
and the requesting handle's `_finish_drop` reconciles with the set of homes
whose completion reported retired; an abort passes the empty set and the
rows return with the transaction. A native-origin retirement reaches the
same reconciliation through the lease hook (`metta._spaces.lease.released`)
with the retired name alone, since the engine's clear withdrew the rows.
`classes.release` goes.
Controls (contract): commit, rollback, a rejected outer commit (the R3
validator), nested transfer, native-origin and Python-origin retirement,
cyclic class dependencies, exact surviving-home projection withdrawal, a
retained class provider snapshot, and a failure followed by an explicit
reconciliation retry.
Open: whether the additional homes are dropped through their own handles
(one completion each) or through one engine group release
(`metta_space_release_plan/2` closes owned children, not class homes);
the plan uses handles, since each home's completion is what records its
outcome.
