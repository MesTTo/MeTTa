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
