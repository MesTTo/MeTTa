# Retained foreign transaction participants

Goal: complete each foreign batch on the provider and operations selected at
enlistment, even when its registration changes before the native outcome.
Constraint: preserve ordinary snapshot relations, the shared owned-record
invariant, and Node's transaction/speculate callback refusal.

## 2026-09-15

Tried: source tracing from `metta_enlist_foreign/1` through Python and Node
completion. The old participant list kept space names; completion resolved
their current providers. Python's independent provider map also survived
native rollback. The V3 lifetime controls establish that host projections
cannot infer native outcome from Python flags.

Rejected: per-transaction host participant wrappers and a second provider
registry. Existing native applications retain provider and bound-operation
identities. Python's provider value belongs in a native owned record; Node's
existing HostValues already interns its original object/function identities.

Decided: one pure `foreign_participant/3` ownership lookup supplies a ground
registration identity and qualified capture closure. Capture validates every
completion operation before begin. A successful begin records its ready state
from cleanup before a deferred signal can escape. Completion consumes the
retained applications, preserving the existing partial-commit policy.

Decided: allocation producers obtain original owner and value references from
`metta_owned_record_occurrences/3`, sharing the strict reader and commit
validator. Raw source selection and admitted-reference decoding are published
engine services; the host binding does not copy the validator.

Open: native behavioral controls and binding regeneration must run after this
unit is integrated with the owned-record base and reader. The dependent
completion/lifetime unit must repair bare rollback failure, projection ordering,
resource admission and retirement; capture does not establish physical liveness.

## 2026-09-16

Applied onto the owned-record base, reader and consumer with `git apply --reject`; three
rejects hand-merged (the changelog bullet, the space_hooks.pl header, and the reader hunk, which
now shares `metta_owned_read_references/5` with `'owned-record-read'/2` and refuses under its
own door through `metta_owned_read_refusal/3`). `bindinggen.py --write` regenerated
`callbacks.py` and `provides_host_user.pl`; the capture-cleanup overlay applied with offsets.
Tried: `sh engine/test.sh suites/spaces/participant_capture.plt` -> 16 pass, 5 fail, all on
`fpc_provider/3` assertions that read no rows although the probe saw them: a `retractall` or
`assertz` written inside a test runs in the unit's module and creates a local `fpc_provider/3`
there, which then shadows the fixture's `user:fpc_provider/3` for every later test
(`implementation_module` answered `plunit_foreign_participant_capture` after the first test).
Decided: registration edits go through `fpc_register/3` and `fpc_unregister/1`, defined beside
the fixture in `user`. Rerun -> 16 (+5) pass.
Tried: `sh check.sh prolog-static` -> red on a compile warning, `Begin`, `Commit`, `Rollback`
introduced in one branch of `metta_capture_participant/2`; the protocol shape is now checked
first and the three goals bound after the branch. Lane green.
Tried: `sh extensions/python/test.sh ch15/test_participant_capture.py ch19/test_foreign.py
ch01/test_import_identity.py -n 0` -> 58 pass, 2 fail. (1) `test_failed_completion_never_uses_
the_replacement` expected `MettaError`; the transaction door re-raises the Python original it
finds behind the engine error (`_spaces/scope.py:transaction`), as the file's own body-abort
cases already expect, so a provider's own `ValueError` is what the caller receives. (2) `test_
completed_captures_do_not_keep_unregistered_providers_alive` expected the provider's weak
reference to die after unregister, drop, `gc.collect()` and the three engine collectors.
Measured: atom collection frees the janus blobs, but janus defers each Python decrement until
its next Prolog-to-Python call (`janus.c:MyPy_DECREF`, `py_gil_ensure`), so the same protocol
plus one `py_call` releases the three captured bound methods (refcount 6 -> 3 while registered).
The registration's own reference is another matter: a Python object passed as a query input is
not reliably released by this process after collection, with or without a provider (plain
`assertz(probe_p(Obj))` then `transaction(retract(probe_p(Obj)))` retains from the second flow
on; the first flow of each shape releases; plain SWI-Prolog 10.1.13 without the engine frees
the clause in every nesting tried), and one probe met `py_object <PyObject>(freed) does not
exist` on a fresh object. Decided: the test asserts what this unit controls, that completion
returns the provider to its registered reference count with no bound-method holders; the
registration reference and the input-object retention are the reclamation unit's questions
(`/home/user/Dev/PyPeTTa1/ai-notes/janus-deferred-decref-after-atom-gc.md`, probes
`ai-tmp/ai-participant-gc-probe*.py`, `ai-tmp/ai-janus-*-probe*.py`).
Tried: Node: `npm run --silent typecheck && npm run --silent test` -> 654 pass; the source
runner `node --test test/*.test.ts` needs a Node built with TypeScript support, which v22.22.1
here is not. Every spaces suite except materialization -> pass, apart from `references.plt:
visibility_is_a_checked_two_element_lattice` succeeding with a choicepoint, which the committed
HEAD shows as well (throwaway worktree run) and which is recorded as its own item.
Tried: `ai-tmp/ai-participant-bare-rollback-witness.pl` -> `observed(silently_failed,
[original-capture, original-begin, other-capture, other-begin, other-rollback])`: the original's
rollback is never attempted and the body's exception is lost when another participant's
rollback fails, as the completion unit expects to repair.
