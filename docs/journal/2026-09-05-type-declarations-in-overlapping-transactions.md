# Conflicting type declarations in overlapping transactions
Goal: identify whether the conflicting-alias race is specific to aliases or an existing transaction consistency limitation.
Constraint: record the reproducible limitation separately from structural alias substitution; this entry describes no repair.

## 2026-09-05

**Not fixed.** Raw concurrent outer transactions can publish conflicting declarations. Sequential alias conflicts and rollback are checked; the alias feature makes no guarantee of serializability for overlapping outer transactions.

The repository already states the surrounding rule. The [thread guide](../../website/guide/threads.md#state-cells-and-compound-updates) says individual engine calls serialize while compound read-modify-write operations do not, pinned by `test_state_increment_requires_a_lock_around_read_modify_write`. The [transaction tests](../../extensions/python/tests/ch15_writing_transactions_and_worlds/test_transaction.py) separately pin an inner commit as relative to its outer transaction: `test_nested_commit_dies_with_the_outer_rollback` and `test_an_inner_registration_dies_with_the_outer_rollback` require outer rollback to discard it. The guide already implies that a compound operation needs caller serialization; it did not state what raw `transaction/1` guarantees.

Tried: on clean `8f853f99`, a worker opens a raw SWI `transaction/1` and waits. The main thread registers a typing rule named `snapshot-probe-rule` with outcome `accept`. After that commit, the worker registers the same rule name with outcome `(refuse second)` and commits. Both definitions remain. This reproduces without alias support and establishes an existing engine-level isolation property.

The tracked probe is [`tests/prolog/probes/type_declaration_snapshot.pl`](../../tests/prolog/probes/type_declaration_snapshot.pl). It accepts the checkout to load and the declaration kind. From the alias checkout, with the clean base at `ai-tmp/wt-base`:

```sh
git -C ai-tmp/wt-base rev-parse HEAD
swipl -q --on-error=status -s tests/prolog/probes/type_declaration_snapshot.pl -g main -t halt -- ai-tmp/wt-base rule
```

Observed output, exit 0:

```text
status=true declarations=[accept,[refuse,second]]
```

The alias counterpart opens the same stale snapshot, lets the main thread add `(: Count (Alias Number))`, then adds `(: Count (Alias String))` inside that snapshot:

```sh
swipl -q --on-error=status -s tests/prolog/probes/type_declaration_snapshot.pl -g main -t halt -- . alias
```

Observed output, exit 0:

```text
status=true declarations=[['Alias','Number'],['Alias','String']]
```

Both `(Alias Number)` and `(Alias String)` are present. The probe uses message barriers, joins the worker, and cleans up its space and rules. Its success means the known conflicting end state was reproduced; it is deliberately outside the plunit gate.

Verified the substrate behavior in SWI-Prolog's own **10.1.13** source, the version installed for these runs. Release tag `V10.1.13` resolves to commit `fc7ef84b949378b729052c3ade79c90ce5416abb`. The [nested branch of `transaction()`](https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-transaction.c#L541) calls the constraint in the existing snapshot and merges changes into its parent. The [outer branch](https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-transaction.c#L624) alone refreshes `gen_start` under the constraint mutex and holds that mutex through commit. The probes and source read newly establish the raw substrate interpretation: `transaction/1` supplies snapshot isolation, not serializability; nested `transaction/3` neither refreshes the outer snapshot nor holds its lock through the outer commit.

Rejected: replacing only the alias's nested transaction with `transaction/3`, because it cannot validate against the final outer commit state. A fix must change the outer transaction boundary. A caller requiring serializability across a compound operation takes the lock the thread guide already prescribes, covering the whole operation; a transaction is not a substitute for that lock.

Decided: keep this transaction-consistency item open and separate. No transaction boundary, scheduler, or casting behavior was changed for this finding. Revisit when that boundary's consistency policy is designed and measured, or a later SWI version changes the pinned behavior.

## 2026-09-05, later the same day

**Fixed at the engine's own transaction boundary.** The "Not fixed" entry above
is superseded for the ENGINE's `metta_transaction/1`; it still stands for a raw
`transaction/1` a caller opens directly, which has no commit hook to carry a
check.

Tried: `transaction/3` at the two places the write can be outermost. SWI states
the order it needs: call Goal, lock the mutex, change visibility to the current
global state combined with Goal's changes, call the Constraint, then commit,
discarding everything on failure or exception. Only the OUTER branch refreshes,
which is why one placement cannot do it: a bare declaration's own transaction in
`engine/spaces/lifecycle.pl` is outermost for a bare write, and a declaration
made INSIDE a user transaction is nested there, so
`metta_outer_transaction_prepare/5` carries the second constraint over a
per-thread list of pending aliases.

Tried: a terminating two-thread probe, `tests/prolog/probes/type_alias_transaction_race.pl`,
driving both transactions from one thread so the interleaving is fixed rather
than sampled. Both snapshots open before either declares, both declare before
either commits, and the commits are ordered, so which transaction loses is the
probe's decision. Every receive carries a timeout and the whole orchestration
runs under `call_with_time_limit/2`; a worker still running at cleanup is
signalled and DETACHED rather than joined, because a join would put back the
hang the timeouts remove. Result on this tree:

```text
declarations=[['Alias','Number']]
outcomes=[a-committed,b-threw(error(metta_type_alias_conflict('&metta-space-1','Count','Number','String'),none))]
```

Control, the same probe with both `transaction/3` calls reverted to
`transaction/1` and nothing else changed:

```text
declarations=[['Alias','Number'],['Alias','String']]
outcomes=[a-committed,b-committed]
```

exit 1 against exit 0, so the constraint is what changes the outcome.

Tried: removing the survival guard in `validate_committed_type_alias/3`, which
asks whether the declaration being validated is in the refreshed state at all.
The pending list is recorded with `nb_setval`, which does not unwind on
backtracking, so a nested transaction that declares an alias and then rolls back
leaves its entry behind. Without the guard the outer commit is refused for a
declaration that no longer exists: `structural_aliases:a_rolled_back_nested_declaration_does_not_refuse_the_outer_commit`
fails with `conflicting type alias Count in &metta-space-43: 'String' versus
'Number'`, and it is the ONLY test that fails, so the guard does not weaken the
concurrent case it sits beside.

Decided: both placements, the guard, and both cases gated in
`tests/prolog/suites/typecheck/structural_aliases.plt`. The suite loads the
probe rather than restating its orchestration, so the standalone arm and the
gated arm cannot drift.

Open: a raw `transaction/1` the caller opens itself is still snapshot isolation
and nothing else; `tests/prolog/probes/type_declaration_snapshot.pl` reproduces
that and stays outside the gate.
