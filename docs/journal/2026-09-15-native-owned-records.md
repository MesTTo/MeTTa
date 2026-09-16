# Native owned-record invariants

Goal: let native declaration rows govern partial-function records and their
owners across overlapping transactions, including class fields, cells and proxies.
Constraint: ordinary relations keep their multivalued snapshot behavior.

## 2026-09-15

Decided: derive unique record keys from the final native delta and catalog
patterns, then validate bounded value and owner counts in the existing refreshed
outer commit view. This is the combination of unique and foreign-key constraints.
The source occurrence remains part of the observed contract. Preparation runs
before the materialization mutex; validation calls native readers only.

Rejected: universal removal conflict checks, because ordinary relations retain
snapshot removal; per-instance field schemas, because per-class patterns already
determine each key; per-setter pending checks, because repeated writes share one
final key. No evaluator or host callback belongs under the commit mutex.

Tried: `sh engine/test.sh suites/spaces/owned_records.plt` initially passes
89 cases and fails 12 in `ai-tmp/ai-owned-record-base-native.log`. Eleven failures
lose a concurrently withdrawn prototype owner or declaration. A diagnostic
wraps preparation and original-row reading: the old transaction enumerates the
source reference, but bound-reference `clause/3` and `instance/2` both fail.
`'$clause'/4` returns the unchanged original term. The C source at
`fc7ef84b949378b729052c3ade79c90ce5416abb`, `src/pl-dbref.c:PL_get_clref` and
`src/pl-comp.c:clause`, distinguishes global `CL_ERASED` rejection from the
four-argument decompiler. The reader now decompiles only references already
admitted by its snapshot or native delta; this does not test liveness.
Logs: `ai-tmp/ai-owned-record-{prepare,original,decompile}-probe.log`.

Tried: the remaining test supplied an open-tail kind row to removal, which
raises `instantiation_error` in `spaces:metta_storage_term/4` before its intended
declaration check. It now removes the exact existing six-element kind row.

Tried: the decoder and fixture repairs leave 93 passing cases and eight failing
prototype retirement-first cases in `ai-tmp/ai-owned-record-base-repaired.log`.
The remaining cases have a distinct cause. At the same SWI source commit,
`src/pl-index.c:first_clause_guarded` returns immediately for a globally empty
clause list before testing the old transaction's visibility. A plain host
probe sees no direct or clause/3 answers, although unbound nth_clause/3 still
admits every original reference. Guarding a Prolog fallback with a separate
clause-count read races with concurrent changes; unconditional fallback makes
indexed misses linear. Both were rejected.

Tried: build the pinned SWI core under `ai-tmp/`, then route its empty-current
list through the existing visibility-aware reader. The unchanged private host
prints `present`; the three-line C repair prints `absent`. With only that private
kernel selected, `sh engine/test.sh suites/spaces/owned_records.plt` passes all
27 tests and 74 subtests, peak RSS 31128 KiB. Commands, exact hashes and logs
are in `ai-tmp/ai-swi-empty-indexed-snapshot-receipt.md`; the passing native
log is `ai-tmp/ai-owned-record-base-patched-swi.log`. The installed host remains
unchanged, so this is a repair experiment, not a shipping green claim.

Tried: the private kernel passes 286 tests and 125 subtests across the 13 native
suites listed in `ai-tmp/ai-owned-record-base-native-broad-private.log`, and
27 Python construction cases in `ai-tmp/ai-owned-record-base-python-private.log`.
Peak RSS is respectively 821332 and 281200 KiB. Host-workarounds and its
selftest, evidence and policy-inventory pass; closed-sets reports two separate
compiler consumer annotations in `ai-tmp/ai-owned-record-base-gates-private.log`.
The identical string-parameter checker finds zero at pristine c751 and two on
the feature, recorded in `ai-tmp/ai-owned-record-closed-set-control.log`.

Tried: `concurrent_withdrawal_does_not_hide_own_removed_contract` fails with
`conflict(committed,multiple_values)` in
`ai-tmp/ai-owned-record-delta-decode-before.log`. Another transaction's committed
withdrawal makes bound-reference decoding discard this transaction's own
removed schema. The shared admitted-reference decoder now also serves delta
and cache decoding. With the private C kernel, `sh engine/test.sh
suites/spaces/owned_records.plt` passes 28 tests and 74 subtests, peak RSS
30348 KiB, in `ai-tmp/ai-owned-record-delta-decode-after.log`. Decompilation
still establishes syntax only; physical provider admission remains separate.

## 2026-09-15, later: the host defect is worked around on the installed runtime

Decided (user: "do a workaround for now"): the installed SWI-Prolog stays unchanged and the
private patched kernel is not deployed. Every native storage predicate keeps one inert
clause from its first write on, head key `'$metta_sentinel'` and body `fail`, asserted by
the one write funnel `store_native_clause/3` in `engine/spaces/catalog.pl`, so the clause
count the host tests in `first_clause_guarded` never reads zero and the visibility-aware
walk still finds an older transaction's rows. No reader answers it: a direct call fails on
it, `clause/3` with body `true` never unifies with it, and the owned-record decoder reads
body `true` only. Host entry `swi-empty-indexed-snapshot` in `docs/host-workarounds.md`;
tracked reproduction `tests/checks/host_workarounds/swi-empty-indexed-snapshot.pl`.
Tried: the host probe matrix on the installed 10.1.13 (`ai-tmp/ai-swi-eis-*.pl`,
`ai-tmp/ai-swi-empty-indexed-snapshot-sentinel.pl`): every current clause erased by an
unbound `retractall/1` -> present with or without the inert clause (it erases the clause
too); by bound-key `retractall/1` -> present without it, absent with it; by `erase/1` on
each reference, the engine's own removal path -> present without it, absent with it; by
`retract/1` per value -> absent either way. So the engine's erase paths keep the inert
clause, and no storage erase uses an unbound retractall.
Rejected: deploying the private kernel, because a box-wide runtime change is the user's
call and the clause costs five inferences per write; a Prolog fallback on indexed misses
and a separate clause-count guard, as before.
Tried: `sh engine/test.sh suites/spaces/owned_records.plt` on the installed host -> before,
eight failing cases of `retirement_and_writes_conflict_in_both_commit_orders`
(prototype-remove, prototype-drop; `ai-tmp/ai-owned-record-root-before.log`); after, all
28 tests and 74 sub-tests pass (`ai-tmp/ai-owned-record-root-after.log`).
`sh check.sh host-workarounds host-workarounds-selftest` -> ok, 18 entries, 39 sites, every
reproduction present (`ai-tmp/ai-owned-record-root-workaround-lanes.log`).
Measured: 1000 add-atoms into a fresh space plus one full enumeration, three identical
samples each (`ai-tmp/ai-owned-record-cost-probe.py`): 43,157 inferences on the control
worktree at 3eb5acc22, 43,157 on this tree with the three funnel sites reverted to
`assertz/2`, 48,162 with the funnel, so the owned-record checks add nothing to this
workload and the inert clause costs five inferences per write.

## 2026-09-15, later: strict reads through one public door

Decided: `(owned-record-read (@owned-record Home Owner Storage Prefix))` holds its key as data,
requires it ground, resolves both storage identities through the native storage cache and the
`(owned-by Owner)` marker exactly once, and answers one expression of zero or one complete
rows inside one `snapshot/1` spanning validation and extraction, so a concurrent replacement
cannot erase the checked occurrence between them; the bounded collector
`metta_owned_checked_key/4` serves the reader and the outer-commit validator alike, with no
getter registry, foreign reader or new mutex. A stored declaration is not needed to read a
concrete key; declarations govern writes (`ai-tmp/ai-owned-record-reader-handoff.md`).
Decided: the result type is `Atom`, not `Expression`: an Atom result never re-enters the
evaluator, which is what keeps a stored `(+ 1 2)` in a row unevaluated and leaves no
re-entry choicepoint. Measured with `call_cleanup(Goal, Det = true)` around each stage
(`ai-tmp/ai-owned-record-read-det-probe{,2,3,4,5,6,7}.pl`): the direct Prolog read is
deterministic in and out of transactions and snapshots; through the evaluator the
`Expression`-declared read left a choicepoint for a plain and for an evaluable owner, as the
`Expression`-declared `collapse-bind` still does, while `get-metatype`, `quote`, `car-atom`,
`collapse`, `add-atom`, `remove-atom` and `new-space` are deterministic; with `Atom` the
evaluated read is deterministic and the stored `(+ 1 2)` reads back unevaluated either way.
Open: the re-entry choicepoint of `Expression`-declared grounded results is the evaluator's,
observed on `collapse-bind`, and is not repaired here.
Tried: `sh engine/test.sh suites/spaces/owned_records.plt suites/spaces/owned_record_reads.plt`
-> 28 + 74 and 39 + 88 checks pass, exit 0, no choicepoint (`ai-tmp/ai-owned-record-reader-root-native.log`).
Tried: the corpus example `examples/ch15-writing-transactions-and-worlds/07-owned_records.metta`
-> five assertions pass; its twin proves 5/5 claims with an equal store at 6051 twin against 9285
native inferences, three identical rounds (`ai-tmp/ai-owned-record-twin-{measure,lane}.log`);
the phrasebook row answers `((balance (Account 1) 12))` on both surfaces at 3425 native and
1846 Python inferences, two byte-identical runs (`ai-tmp/ai-owned-record-phrasebook-measure-{1,2}.json`).
The test form evaluates its expected side, so the example writes `(noeval (+ 5 5))` there;
the refused second value is asserted through `(if-error (catch (transaction ...)) refused committed)`.

## 2026-09-15, later: the atom count leaves out the inert clause

Tried: `sh extensions/python/test.sh tests/ch09_types/test_space_length_refinements.py -n 0` ->
both parametrizations red since c5bdd73e0: `space_atom_count_uncached/2` sums
`number_of_clauses` per storage predicate and counted the sentinel.
Decided: `native_storage_clause_count/3` beside the sentinel's builder in `engine/spaces/catalog.pl`
subtracts the inert clause when the predicate carries one, and only that reader counts: every
other clause-count site in the engine walks compiled-function modules, and every enumeration over
storage reads body `true`. The first guard raised `arg/3: Type error: compound expected` on the
storage module's arity-zero marker predicate `'$metta_native_storage'`, hence `compound/1` before
the sentinel head is built.
Tried: the two refinement cases -> pass; `sh engine/test.sh suites/spaces/length_refinements.plt
suites/evaluation/prelude.plt suites/spaces/hooks.plt suites/typecheck/refinements.plt` -> 8 + 2,
62 + 11, 45 + 11 and 21 + 2 pass (`ai-tmp/ai-owned-record-remedy-native-extra.log`).

## 2026-09-16: read refusals name the reader and the repair

Tried: the class getter on a record with a second value -> `metta_validate_owned_records/1: native
owned-record conflict multiple_values ...; retry the outer transaction`. No commit ran: the shared
collector threw with the validator's context and the renderer carried the retry, so a read of a
malformed store told the caller to retry a transaction that did not exist.
Decided: `metta_owned_key_problem/5` answers the problem and never throws; the validator throws
with `metta_validate_owned_records/1` and `retry the outer transaction`, the reader with
`'owned-record-read'/2` and the repair (`remove the surplus value rows`, `remove the surplus owner
rows`, `the native owner has retired`); the renderer carries no remedy, the context does, and
`metta_owned_ground/1` names no phase since preparation, validation and the reader all reach it.
Decided: removing an occurrence whose key is not ground derives no key and contributes no check
(`metta_owned_change_admits/2`), because a transaction had no way to repair a store no commit
admitted: the removal itself was refused with `ground_owned_record_key`. Adding one still refuses.
Measured: a plain `Space.add` outside a transaction runs no commit check and a duplicate value
lands; `home.transaction(lambda: storage.add(...))` refuses `multiple_values`, a duplicate owner
`multiple_owners`, and `del storage[pattern]` drains every occurrence
(`ai-tmp/ai-owned-record-unwrapped-probe.py`).
Tried: `sh engine/test.sh suites/spaces/owned_records.plt suites/spaces/owned_record_reads.plt`
-> 29 + 75 and 42 + 91 pass (`ai-tmp/ai-owned-record-remedy-native2.log`); the twin re-pins 6051
to 6058 and the native side moves 9285 to 9292, the problem-term answer and the per-change
admission check (`ai-tmp/ai-owned-record-remedy-twin-repin.log`).
