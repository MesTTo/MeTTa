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
