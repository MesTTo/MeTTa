# Installing an integration unwinds
Goal: make a failed `integrate()` restore every framework-managed mutation to its pre-installation state.
Constraint: consulted Prolog source, loaded native code, best-effort foreign writes, and arbitrary process-global effects do not all have safe inverses.

## 2026-09-04
Tried: a failing installer registered an operation, marker atom, library path, and converted type, then raised `RuntimeError`. Running it through `PYTHONPATH=extensions/python $CHECK_PY` left all four registrations live while `_INSTALLED` alone stayed absent.
Tried: an engine transaction around a typed operation removed its engine declarations but left their `_DECLARATION_REFS` ownership counts in Python. A later registration could therefore skip re-adding declarations the engine no longer held.
Tried: restoring a replaced converted type through its public unregister/register calls after engine rollback produced two identical old `(type-image ...)` rows. The listener had already been rolled back by the engine transaction, so notifying it again was not an inverse.
Tried: `TMPDIR="$PWD/ai-tmp/tmp" CHECK_PY=<the janus venv python> sh extensions/python/test.sh` after regenerating the reference pages -> 2 failed, 2893 passed, 79 skipped, 1 xfailed. Both failures were the branch tip's twin inference pins: identity measured 3524 against 3575 and spaces3 measured 254 against 262. A detached `dca33c9f` worktree reproduced both after `sh engine/build.sh`, so neither pin was changed here.
Tried: `TMPDIR="$PWD/ai-tmp/tmp" GATE_ONLY=1 sh tools/check.sh` after confirming no other gate and recording load average `25.81 24.96 23.19` -> failed `engine-bench`, `c-bench`, `mork-bench`, `pytest`, `vulture`, `ty`, and `artifact-paths`. The MORK benchmark lost the shared PMU with `perf stat failed with exit 2: Events disabled`; the Python failure was the load-sensitive inference-limit test; the artifact checker lacked the expected sibling LeaTTa checkout. The two local diagnostics were actionable: `vulture` found the private protocol helpers made dead by this change, and `ty` rejected function attribute syntax. Those helpers were removed and the Prolog path receipt now uses the function dictionary; both checks then passed directly.
Rejected: wrapping only the installer in a new integration-local cleanup context, because a successful nested `integrate()` must still unwind when its enclosing `Space.transaction()` later rolls back. Revisit if integration state becomes independent of engine transactions.
Rejected: refusing every installer that might consult Prolog or load a native library, because arbitrary installers can perform the same effects and refusing declarative `METTA_PROLOG` would remove the supported extension path without enforcing the rule. Revisit if installers declare a complete effect manifest that can be preflighted.
Decided: use the ambient `ops.registry_undo()` frame as a unit-of-work log. It restores keyed operation/declaration preimages and exact reverse-order integration registrations; successful child frames merge into their parent, matching SWI savepoints. `integrate()` places both the installer and its `_INSTALLED` receipt inside the home space's closed transaction.
Decided: restore converted registry internals silently. The enclosing engine transaction owns listener-written atoms, while the Python undo owns `_REGISTRY`, `_CONSTRUCTORS`, and `_TYPE_OWNERS`.
Decided: refuse a home space declared `best-effort` before calling the installer, because its atom writes are known to survive rollback. On a started installer failure, retain the original exception and add a note that consulted Prolog, loaded native code, custom listener effects, and arbitrary process-global effects may remain. A declarative Prolog installer also names every affected file in a second note.
Open: exact residue receipts for ad hoc `register_prolog()` and `register_foreign_library()` calls require instrumentation at those doors; an unconditional failure note is the truthful boundary until that owner records them.

Evidence: Python's `contextlib.ExitStack` specifies reverse-order callbacks and all-or-nothing setup; SWI documents that `transaction/1` rolls back dynamic database changes while loaded source becomes immediately global; `engine/spaces/foreign.pl` permits declared `best-effort` writes to survive rollback.

Result: `TMPDIR="$PWD/ai-tmp/tmp" CHECK_PY=<the janus venv python> sh extensions/python/test.sh tests/ch11_python_as_a_notation/test_integrate.py tests/ch15_writing_transactions_and_worlds/test_transaction.py` passed 37 tests. The regression's real two-file `METTA_PROLOG` integration leaves `metta_extension_info/3`, its MeTTa operation, and `user:file_search_path/2` all absent while the already consulted predicate remains visible through `current_predicate/1`. The raised `ValueError` retains both rollback-boundary notes and names both source paths.

- https://docs.python.org/3/library/contextlib.html#contextlib.ExitStack
- https://www.swi-prolog.org/pldoc/man?section=db
- https://docs.osgi.org/specification/osgi.core/7.0.0/framework.lifecycle.html

## 2026-09-05
Tried: `TMPDIR="$PWD/ai-tmp/tmp" GATE_ONLY=1 sh tools/check.sh engine-bench c-bench mork-bench pytest vulture ty artifact-paths` began just before a concurrent main-tree gate was announced. The correctness lanes are load-independent and passed: 2922 Python tests passed with 52 skipped and 1 xfailed; `vulture`, `ty`, and `artifact-paths` passed. The three timing/instruction lanes are invalid evidence from an overlapping run: `engine-bench` and `c-bench` exceeded instruction or CPU bands, while `mork-bench` lost the shared PMU with `perf stat failed with exit 2: Events disabled`.
Decided: do not infer a code defect or a good baseline from the three contended timing lanes, and do not re-pin them. Wait for the main-tree gate to finish before any further timing or full-gate run.
Correction: the earlier process and load snapshot did not establish that the first full gate ran alone. A snapshot reports current and past activity but cannot reserve the next interval, so its cost-lane failures are unclassified rather than evidence against this change.
Decided: serialize every full gate, benchmark, and performance-counter run with `sh ../ai-gate-lock.sh <owner> <command>`. The lock reserves the whole measurement interval and propagates the wrapped command's exit status.
Tried: the seven lanes from the overlapping retry split into three cost lanes (`engine-bench`, `c-bench`, and `mork-bench`) and four correctness or static-contract lanes (`pytest`, `vulture`, `ty`, and `artifact-paths`). `vulture` and `ty` identified two source defects and passed after repair; `pytest` and `artifact-paths` also passed in the later serialized run. No cost verdict from that overlapping retry was used.
Tried: `sh ../ai-gate-lock.sh integrate env GATE_ONLY=1 sh tools/check.sh` with both MORK shared objects copied from the main checkout -> every lane passed except `engine-bench`, `dev-typed`, `c-bench`, and `mork-bench`. The Python lane passed 2,922 tests with 52 skipped and one expected failure. `mork-seat` printed `mork: both shared objects are present, so the whole suite runs` and passed all 25 tests. `dev-typed` failed only `lib_thread:a_saturated_timer_pool_does_not_block_scheduler_deadlines` at its 10.001-second deadline; the same 68-test suite passed later in that gate in 5.181 seconds, and a locked targeted rerun passed the `dev-typed` lane.
Tried: equal-length detached `dca33c9f` controls, with the three changed Python modules applied only to the modified arm and `engine/build.sh` rebuilding each arm's QLF, measured three identical inference samples per row. The pristine and modified engine rows were identical: boot 539606, evaluate 559327, match 338002, match-skew 210482, parse 152, parse-prolog 3076184, and translate 380634. The C operational rows were also identical: cursor-step 2200005, term-in 5220009, term-out 1560005, space-pair 1140032, and error-ball 406008; C boot changed from 1494624 to 1494622. The integration change therefore adds no measured engine or C workload inferences and changes only C setup by -2, inside the four-inference band.
Tried: a direct equal-path `space_name_case` control under the same lock rebuilt each QLF, then ran three fresh processes per arm. Every pristine process returned `[4200419, 4202799, 4202772]`; every modified process returned `[4200421, 4202799, 4202772]`. The fixed +2 first-sample movement is inside the four-inference band. The committed benchmark's documented upper mode explains why a separate modified-only roster run reported minimum 4200421 against 4200416 plus four, while the serialized full gate's `benchmarks` lane passed; no baseline was changed.
Decided: hardware-counter rows are unrun for final attribution while an unrelated repository owns the exclusive PMU with `perf stat -x, -e instructions:u`. An unopened counter window is not a measurement. `engine-bench` and `c-bench` inference rows remain valid and are attributed by the equal-path controls above; `mork-bench` and every `instructions:u` verdict await a free PMU and are neither blamed on this diff nor re-pinned.

## 2026-09-14: the uninspectable-callable fixture releases its module operation

Tried: the callable/compiler cohort passes 1117 cases and fails the host
expanded-call witness with `missing a required argument: 'x2'`. The earlier
integration witness leaves its `target` operation visible in the session's
home space, so a later source name selects that native function. Log:
`ai-classes-c35-application-A-python.log`.

The same integration witness leaves `target` present on pristine
`c75181adc999adf0028616ee69565e2bbfbf739f`. The probe invokes the existing test,
checks visibility, and unregisters the residue. Command: `python
ai-tmp/ai-classes-c35-integration-fixture-probe.py`. Logs:
`ai-classes-c35-integration-fixture-ai-call-signature-check.log` and
`ai-classes-c35-integration-fixture-ai-classes-c75181adc-control.log` both end
`present`.

Decided: save the names returned by `module_ops` and unregister each in
`finally`. The classifier assertions and native vocabulary precedence remain
unchanged. This completes the fixture's registration ownership.
