# Goals the classes branch writes into bodies
Goal: every goal the engine emits or constructs for a body it does not call itself is a name a space module can reach and no MeTTa equation can take.
Constraint: `seam:engine_emitted/1` is the one protection list, and `tests/prolog/static_checks.pl` recompiles the corpus and reads what the engine constructs; a red there blocks the gate.

## 2026-09-16
Tried: `env -u DISPLAY -u WAYLAND_DISPLAY sh tools/check.sh prolog-static` on `feat/classes-on-metta` ->
`the engine emits metta_transaction/2 into compiled bodies and a MeTTa equation can take it`.
6a27885bf made the transaction form emit `metta_transaction(Conj, Out)` and left the list naming
`metta_transaction/1`; the corpus half sees it through
`examples/ch15-writing-transactions-and-worlds/01-mutex_and_transaction.metta`
(`ai-tmp/ai-emitted-transaction-probe.pl`: that equation compiles arity two on this branch and arity
one on the audits worktree, which lacks 6a27885bf). The trunk baseline never reached this check: its
lane died on X_GLXCreateContext first, and this branch was cut before c4e75b320 made the gate headless.
Decided: the list names `metta_transaction/2`; the arity-one service stays exported and engine-called,
never written into a body, so it is not an emission. `spaces.plt` derives its capture tests from the
list, so the entry is covered without a new test.
Tried: the lane again -> the next check, constructed goals a space module cannot see:
`typing_policy_snapshot/1` (e7ba2730f, `type_rules`) and `host_record_assertion/3` (560aaa42b,
`host_transactions`).
Decided: `typing_policy_snapshot/1` is exported. Its `seam:context_reader` declaration inlines every
call inside `type_rules`, so the predicate is reached only from outside, where an unexported name is
invisible; `reference_scopes.plt` already calls it qualified. `host_record_assertion/3` is qualified
where `host_assertion_body/5` builds it: that body runs as `system`'s assert wrapper, not as a clause
of `host_transactions`, and the qualification says so to the check and to the reader alike.
