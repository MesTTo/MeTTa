# Transaction completion retains original attempts

Goal: finish each required foreign participant and reconcile native ownership
before observation, preserving the durable native decision.
Constraint: capture migration is atomic across Python and Node; no callback
runs under native commit, event-list or application locks.

## 2026-09-15

Tried: source inspection of `metta_rollback_participants/1` found that bare
failure escapes `forall/2`, skipping later participants and suppressing the
body exception. Thrown rollback errors were printed and discarded. The
separate `ai-participant-bare-rollback-witness.pl` preserves this failing
witness for the native execution owner; it has not been run in this source
unit.

Decided: retain each captured completion as one mutable native attempt, derive
partial commit and failure receipts from the ordered results, and finish every
required rollback despite false or throw. The existing saga query reads the
same receipt. A failed rollback is an explicit result during speculation too.

Decided: the current coordinator owns its participant list and reconciliation
queue. A transaction begun by a completion callback gets a new trailed context
and restores its parent. `metta_after_foreign/2` uses the existing native
on-exit hook, transfers through native parents, then drains after foreign
completion and before observers. Native repair callbacks retain their existing
immediate on-exit timing. Their completion walk attempts every registered
repair before rethrowing and retrying failed idempotent repairs. Raw host
repair failures use SWI's existing exception urgency; user phases keep the
first ordinary error and preserve registered engine control signals.

Decided: nested and outer user transactions share one protected native and
observation scope. The outer coordinator alone owns foreign participants and
the reconciliation queue. The inference-cut control checks both forms and
their final observation frames. Independent scheduled callbacks have no
registration-order guarantee across native parent transfers; their phase
order and single-attempt result are the contract.

Tried: the unchanged `ai-native-completion-outcome-witness.pl` registers a
failing raw on-exit repair after writing one row. The feature run exits 2 with
`result(threw(error(goal_failed(host_transactions:fail),
context(host_transaction_on_exit/1,'transaction reconciliation must succeed'))),
[committed],[rolled_back])`. Its complete error is retained in
`ai-native-completion-outcome-before.err`. Pristine c751 instead refuses before
writing with `existence_error(procedure,host_transactions:host_transaction_on_exit/1)`;
`ai-native-completion-outcome-c751.err` preserves that distinct preparation
failure. It does not reproduce the feature defect. Source history introduces
the on-exit seam in `592dd1ea2d87485a7c3ffa37b6a56deaa70f0cff`; its native result
was previously inferred from the wrapper's return after running repairs.

Decided: expose the original Catcher/Policy outcome through the same journal's
`host_transaction_on_exit/2`. The engine retains it separately from the late
wrapper error, so notifications and foreign verbs use the actual native
decision. The late error remains outward failure after completion. The direct
host matrix and unchanged witness remain required after integration.

Rejected: a Python flag inverse for retirement, because the native abort
witness restores rows while recorded scope lifetime remains revoked. Rejected:
calling physical close inside native on-exit while a user coordinator still
owes foreign completion. Rejected: rerunning a failed host callback as native
cleanup recovery. A retained result makes bookkeeping retry idempotent;
explicit resource retry schedules a new attempt.

Open: native execution of `foreign_completion_results`,
`transaction_completion`, the existing participant/host suites and the Python
participant controls. Physical admission, native allocation lifetime and class
withdrawal consume this boundary in their dependent unit; this source unit
does not claim that those consumers are implemented.

## 2026-09-16

Applied onto the landed participant capture (four rejects hand-merged: the changelog bullet,
two header tags, and the enlistment hunk that now reads the coordinator's registry). The
completion contract's controls then ran for the first time.
Tried: `sh engine/test.sh suites/spaces/completion_results.plt` -> 28 fail. Test bodies edited
the fixture's `fco_provider/4` and `fco_native/1` from the unit's own module, creating shadowing
locals there (the same trap the participant suite met); the edits go through `fco_register/4`
and `fco_mark/1` in `user`. The first replacement dropped a parenthesis per call and the parser
silently skipped those tests; the suite reported fewer tests, not errors.
Tried: `sh tools/check.sh prolog-static` -> red twice: `Begin`/`Commit`/`Rollback` and `Error`
introduced in one branch each (`metta_capture_participant/2`, `metta_transaction_decision/3`);
the shape is checked first and the variables bound after the branch.
Tried: the Python controls -> `test_reconciliation_runs_after_original_completion_and_attempts_
every_callback[True]` raised `py_call/2: Arguments are not sufficiently instantiated`: a host
callback schedules from its own janus query, whose foreign frame is discarded when it returns to
Python, undoing the trailed bindings its inputs made inside the linked goal. `metta_after_foreign/2`
now stores `duplicate_term/2` of the goal.
Tried: `transaction_completion:inference_cuts_retain_attempts_without_replaying_callbacks` ->
`seam:observation_frames/1` grew by one on eleven budgets. The observation attempt records a
control signal that lands before its pop as that attempt's result and the coordinator goes on.
Decided: the open frame is the state: `metta_transaction_scope_prepare` records the frame depth
before begin, `metta_transaction_scope_observe` runs while the frame is still open, repeats the
attempt once after a recorded failure, and throws `metta_observation_frame_open/1` if the frame
still stands. An attempt cut after the pop is not repeated.
Tried: `host_transaction_completion:reconciliation_keeps_the_hosts_exception_urgency` -> the
less urgent error escaped. `host_transaction_finalize/3` linked the retained repair list whose
tails a recursion bound afterwards; the throw unwound those bindings and the cleanup retry saw
`[First|_]`. The list is now accumulated onto bound tails and reversed; `metta_finish_capture/2`
rebuilds `exclude/3`'s spine the same way before linking it.
Tried: the sweep still reported `!` at budgets far below the goal's cost, with `[outer, outer]`
runs and an empty receipt for the nested form. `metta_in_user_transaction/0` wrapped `b_getval/2`
in a catch-all: an inference limit landing on that read was swallowed, `call_with_inference_limit/3`
then lifted the limit for the rest of the goal, and the inner transaction ran as a fresh outer
coordinator whose receipt the real outer overwrote with an empty one. The five `catch(b_getval(...),
_, fail)` reads in space_hooks.pl and effects.pl now use `nb_current/2`, which fails quietly on an
unset key and lets a signal through.
Decided: `the_original_native_outcome_survives_a_later_repair_error`'s exception row asserts no
second outward error: the body exception stays primary, as the contract says, and its helper
consumes it.
Tried: completion_results 18 (+29), participant_capture 16 (+5), hooks 45 (+11),
host_transactions 23 (+17) -> pass (`ai-tmp/ai-completion-native8.log`); both witnesses pass:
the bare-rollback witness observes `threw(error(original_body_failure, none))` with
`other-rollback` and `original-rollback` both attempted, and the native-outcome witness reports
`[committed], [committed]` beside the repair error (`ai-tmp/ai-completion-witness-*.log`); ch15,
ch19 foreign and ch01 import-identity Python -> 158 pass.
