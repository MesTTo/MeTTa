# Every host workaround is commented
Goal: every place the engine works around something its host does, rather than something this tree does, is findable by a later reader, an upstream fix or a port: a comment at the site that names a ledger entry, a ledger entry that names a reproduction, and a lane that holds all three in step and runs the reproduction on the host the tree runs on.
Constraint: the host stays SWI-Prolog and is not forked; a workaround is fixed at the engine, never by carrying a patch to the host; nothing lands as pending, so an entry exists only with a site and a reproduction in the same commit.

## 2026-09-10
Tried: the cleanup-registration window in plain SWI 10.1.13, four shapes under `call_with_inference_limit/3` at budgets 2..9 -> `setup_call_cleanup(asserta(g, R), true, erase(R))` leaks the guard at budget 4 and completes from 5; the same with `sig_atomic(asserta(g, R))` as Setup leaks at budget 5, one call later; an assert moved INSIDE Goal with the reference parked by `nb_setval/2` for the cleanup leaks at budgets 3..8, because the cleanup runs after the bindings Goal made are undone; a `b_setval/2` marker leaks at no budget in 1..40. `setup_call_cleanup/3` is `sig_atomic(Setup), '$call_cleanup'` (boot/init.pl:680-682), so the window is the one call port between Setup returning and the cleanup being registered, which is what the fuel scope's trailed marker already worked around on 2026-09-07 and what BINDING's whole-suite run met again in `lib_memo:memo_automatic_reconcile_dirty/0`.
Tried: the same defect class across the tree -> sixteen `setup_call_cleanup/3` sites whose Setup asserts a clause or a flag (engine/support_graph.pl, engine/specializer.pl, engine/filereader.pl, engine/filereader/source_lifecycle.pl, engine/source_observation.pl, engine/spaces/foreign.pl, engine/type_rules.pl, engine/materialize.pl, engine/metta/terms.pl, engine/metta/interop.pl, lib/lib_memo/lib_memo.pl twice, lib/lib_thread/lib_thread.pl, lib/lib_tabling/lib_tabling.pl), every one exposed to an inference limit that trips at that port.
Rejected: a hard fork of SWI-Prolog, because a single team would own a runtime's platform ports, GC and security stream to fix defects that are each a few lines here. Revisit if the maintainers stop merging.
Rejected: a soft fork carrying a patch queue on a vendored SWI, although one reordering in the host would close this class at every site; the user ruled no fork, so the host is worked around at the engine and the ledger is what makes the workaround findable when a port or an upstream fix arrives.
Rejected: semgrep for the Prolog side, because it has no Prolog parser and its generic mode cannot tell a Setup argument from any other; the structural rule belongs to `tests/prolog/static_checks.pl`, which reads clauses. Semgrep stays a candidate for the C, TypeScript and Python seats where ruff and pylint stop.
Rejected: a ledger that tolerates entries whose sites are pending, because an obligation that is open at landing is the thing CONTRIBUTING refuses; entries land with their sites.
Decided: the convention. A site carries `Workaround: <key> - <what this site does instead>` in its own comment syntax; `docs/host-workarounds.md` carries one `## <key>` entry with `Host:`, `Defect:`, `Reproduction:`, `Lifted when:` and optionally `Workaround:` and `Record:`; `tests/checks/check_host_workarounds.py` holds sites and entries to each other in both directions and runs every reproduction, reading `present` or `absent` from its last line, so a host upgrade that removes a defect fails the gate naming the sites to lift. The reproduction is the executable form of `Lifted when:`, the strict-xfail shape a known defect already has in this tree (the count that ran before it asked, 2026-09-05).
Decided: three entries open the ledger with the sites that are on trunk and outside the running packages' hunks: `swi-cleanup-window` at the fuel scope in engine/metta/control.pl, `swi-locale-default-encoding` at the boot's encoding pin in engine/qlf_boot.pl, `swi-qlf-extension-spec` at `metta_load_source/2` in engine/metta/interop.pl. On 10.1.13 the three reproductions answer present: budget 4 leaks; U+2705 reads back as three U+FFFD under LC_ALL=C; `'one.pl'` leaves no artifact while `two` writes one.
Decided: the remaining fifteen sites of the cleanup class are one package after the running wave merges, with one trailed-guard primitive beside the fuel scope, each site derived to it or, where a real clause must exist for the scope, made inert by an epoch the trail unwinds, and a `prolog-static` rule that refuses a Setup with a clause-database effect; every site carries the comment. `lib_memo:memo_automatic_reconcile_dirty/0` goes first, in BINDING's branch, because its leak is what turned BINDING's whole-suite run red.
Open: the older workarounds whose sites sit inside the running packages' hunks join the ledger as those packages land: the receipts frame listener, the eager Janus import after the file-search cache expiry, the engine that escapes its creator's transaction, the worker that settles in a cleanup handler.

## 2026-09-11

Goal: restore temporary engine contexts at every inference-limit call port.
Tried: the public `pragma! max-inferences` door at cut `b1d175f13b67baf1090f74f309407b763d421744`, budgets 1..600 around a registered operation that calls each scope and `spin(30)`. `support_atomic/1` leaves its flag at 75, `with_support_repairs_deferred/1` at 69, and `with_typing_policy_stable/1` at 72; each returns the named inference-limit exception. The provisioned `suites/spaces/tokens.plt` runs 29 tests and five subtests, including the MORK refusal test, with exit 0.
Tried: trailed entry and trailed ordinary restoration, budgets 1..100, nested values and two answers -> no leaked value; both answers read `inner` inside and `outer` outside. An initially absent key reads `[]` after ordinary success. SWI trails deletion on failure but has no backtrackable ordinary deletion door, so readers must treat absence and `[]` as the same inactive state.
Tried: assertion followed immediately by `catch/3`, with a catch as the cleanup goal -> no clause in 100 budgets; two answers retain the clause inside the goal and leave none outside; an explicit exception is preserved. Retiring an already erased reference fails, so recovery uses an idempotent retirement, not a second unconditional `erase/1` that could swallow the exception.
Rejected: `nb_setval/2`, `nb_linkval/2` or `nb_delete/1` on a scoped root, because each replaces the global hash entry and defeats its trailed restoration. Mutable scope payloads use `nb_setarg/3` or `nb_linkarg/3` instead. Source: SWI `fc7ef84b949378b729052c3ade79c90ce5416abb`, `src/pl-gvar.c:setval/3` and `nb_delete/1`.
Rejected: epoch retirement for clauses that can be physically released at exit, because it adds a read to every call and retains abandoned clauses. Revisit on a host without catch-port deferral. SWI's `raiseInferenceLimitException()` in `src/pl-prims.c` at the same revision defers a trip at `catch/3` until its first protected call.
Decided: `metta_with_trailed/3` beside the fuel scope; inactive default `[]`; trailed entry and ordinary restoration, with no cleanup. Stack contexts preserve enumeration and nesting. Existing cleanup with other obligations registers before entry, then runs with the prior context restored; its cleanup goal is a literal catch around idempotent retirement. Real clause acquisition is immediately followed by a literal catch. No budget increase, disabled limit, changed control signal or runtime patch is part of the mechanism.
Decided: the structural check reads Prolog terms, refuses the specified writes in Setup, and declares fixture exemptions beside the planted checker clauses. Its selftest exercises refusal and the exemption. The scan includes later source contexts and seat capture flags found on this cut, not only the earlier sixteen.

| Sites on the cut | Before | Planned replacement |
| --- | --- | --- |
| support lock, deferred repairs, typing snapshot, declared-type reader, specialization checking | asserted guard | trailed flag or context stack |
| source program, recompile owners, active load and owning-load pin | asserted context | trailed stack; registered cleanup retains source rollback |
| materialization owner, source candidates, batch | asserted context | trailed flag or stack; a mutable batch cell records early close |
| specialization stack, needed flag, segment stack | nonbacktrackable global roots | trailed roots; mutable needed cell |
| reference refresh, force, finishing frame, candidate program | asserted context | trailed flag or stack |
| working directories, module, compiler shortcuts, bridge depth, state fence | asserted or global context | trailed context with inactive default |
| granted hook, user transaction, occurrence load and removal selector | global context | trailed context; selector consumption is trailed |
| source-observation contexts and temporary executable clause | global contexts and asserted clause | trailed contexts and catch-protected retirement |
| early loader watcher and host registration probe | asserted clause | catch-protected acquisition and retirement |
| Python message forwarding and Node/C error capture | nonbacktrackable flags | trailed scopes through the engine service |
| owned library guards/hooks, deferred compilation and translator scopes | asserted or global context | exact integration changes in the landing receipt; owned files remain untouched |

Open: measure each changed scope, run the specified committed-tree lanes, attribute cut failures and deterministic counter movement, and record the exact owned-file integration needs.

Tried: `sh engine/test.sh suites/evaluation/trailed_scopes.plt suites/reader/source_observation.plt` after fixing a missing observation-body parenthesis and replacing the protected `length/2` probe fixture -> 24 scope cases and 37 observation cases passed.
Decided: source rollback retains a captured undo plan through retirement; materialized images retire their snapshot row last. Retrying after deleting ownership first loses the resources still owed.
Decided: collect raised exceptions through the existing debugger exception port and stop source-frame traversal at the observation's own frame. SWI `pl-trace.c:tracePort` calls `saveWakeup` before `traceInterception`; `pl-attvar.c:saveWakeup` saves and clears `exception_term`. Both were read at upstream `fc7ef84b949378b729052c3ade79c90ce5416abb`. Work in `prolog_exception_hook/5` runs with the ball pending. Repeated exception ports during the same unwind record one error, and a subsequent ordinary port reopens recording.

Rejected: bare assertion followed by catch as the whole clause-lifetime mechanism. The inference sweep proves the catch-port rule, but that rule does not establish asynchronous-signal protection at the same gap. Decided: register cleanup first; acquire the clause and publish its reference into a retained ownership cell under `sig_atomic/1`, with catch-port deferral protecting the publication from an inference trip. Only acquisition is signal-masked. The two-instruction registration probe masks its whole assert/erase pair. This preserves both the host's original signal guarantee and the new inference guarantee.

Tried: retained ownership scopes -> all 20 context sweeps and five internal-operation sweeps passed, including rollback of three owned clauses. The executable-clause sweep found an empty predicate left when acquisition was erased before its owner cell was published. Decided: retire the unique predicate name even when the cell is still empty.
Tried: the same observed failing `assertEqual` on the cut and branch -> one error on the cut, three on the debugger-only branch. Rejected: reopening exception recording on every ordinary port, because cleanup runs ordinary goals during the same unwind. Decided: the exception hook schedules a notification with `thread_signal/2` and performs no observation work; the debugger hook records once per notification after the host has saved and cleared the pending ball. The hook fails so another host repair hook can run.

Tried: compiler-context and signal coverage -> `with_equation_types/4` and `with_static_parameter_environment/5` needed the same trailed root, including caller-variable identity. The marker's `prolog_listen/2` assertion notification confirms that an asynchronous signal waits for owner publication. A watcher notification did not fire for the thread-local clone, so it does not prove that acquisition boundary; its in-use signal and complete inference sweep remain the evidence.
Tried: stopping a sweep at its first reported completion -> the cut reports completion at transaction budgets 6 and 7 despite doing 142 inferences. Decided: measure the unbounded operation first and sweep at least that far, then require completion. Every trial checks restoration and a clean second entry in a fresh engine. This does not assert that the host always delivers its bound correctly.
Tried: scanning a source term containing `zero()` -> `functor/3` raised `domain_error(compound_non_zero_arity,zero())`. Decided: inspect compounds with `compound_name_arity/3`; the parser selftest now includes a zero-arity compound as data.
Tried: a full observed equation under every outer inference budget -> SWI printed `foreign predicate trace/0 did not clear exception: inference_limit_exceeded` and later aborted in `mark_variable___LD` and `assignAttVar___LD`. Its unbounded operation measured 109460 inferences. Plain SWI reproduces lost bounds independently: `tracemode()` ignores `debugmode()`'s failure; `traceInterception()` catches callback exceptions, prints them, and continues with debugging disabled. Source: upstream `fc7ef84b949378b729052c3ade79c90ce5416abb`, `src/pl-trace.c:1553-1623,2128-2152,2217-2269`. Enabling the debug flag separately removes the `trace/0` warning but leaves callback exceptions swallowed. Catching and signalling from the callback, and signalling from an error-message hook, each still lose bounds. No such partial repair enters the runtime.
Decided: expose the existing observation resource scope as `with_observation/4`, keeping its actual installation, trailed roots and retirement together. Sweep that scope with a small body, and sweep the compiler and runnable context doors separately. Normal source-observation tests still exercise complete programs. The broader host tracing failure remains an explicit diagnostic; a scope test cannot establish a repaired debugger.
Tried: the compiler-context sweep with its stored-clause fixture outside the bound -> budget 26 fails before entering the context. `stored_atom_of_ref/4` in the owned lifecycle file catches every exception from `clause_property/2` and `clause/3`, including the bound. Decided: record that failed exit, check restored state and a clean second entry, and continue the sweep through completion. The owned-file receipt requests typed invalid-reference catches. A token-only provider also exposes an owned `unstore_atom/3` route that still requires `remove`; selector refusal and selector consumption are swept separately, with the dispatch correction in the same receipt.

Tried: `sh engine/test.sh suites/evaluation/trailed_scopes.plt` -> 17 tests and 40 subtests passed in 2.479 seconds. The separate `source_observation` suite passes 38 cases, including unchanged error multiplicity and destruction of an engine that observed an error. The final per-door report also passes all 46 rows after explicitly forcing the specialization fixture's three definitions; silent source loading alone had left the segment fixture uncompiled. Each budget checks restored state and a clean second entry. The loader watcher completes at 63, executable observation clause at 102, registration probe at 11, and failed loading marker at 53, with zero retained clauses at every earlier budget.

Tried: the actual Node and C rendering doors under every budget through completion -> 172 and 173, zero leaked capture flags, and a clean second render after each trial. Python's shipped Prolog hook and delivery body, with a guard-checking receiver replacing the external callback, complete at 51 with zero leaked guards. Its existing delivery catch suppresses the bounded attempt at 11..47; each trial then delivers unbounded and observes the active guard inside the receiver. The hook is thread-local to an engine, so the fixture installs the shipped clause in each fresh engine before applying the bound.

Tried: the structural parser over the pristine cut -> 61 direct setup-write findings at 60 source clauses. The changed tree has 15 findings, all in files owned by the concurrent packages: `engine/spaces/{foreign,lifecycle}.pl`, `engine/translator/lowering.pl`, and `lib/lib_{import,memo,tabling,thread}/`. There is no ownership exemption. The selftest covers both wrappers crossed with all 12 write predicates, eight parser fixtures, misplaced/unused exemptions, zero-arity compound data and malformed source. A cold cut scan lacked Janus's `@` operator and printed syntax errors; importing its declared operator source corrected that diagnostic. Decided: request `syntax_errors(error)` so a parsing error cannot skip a clause and leave the new check green.

The following table records the implemented sites. Budgets are the complete ranges `1..N` of the named fixtures in `trailed_scopes`, unless a seat receiver is stated. Every range has zero retained root or clause leaks and checks a clean second entry. A grouped row lists its budgets in predicate order. Calls that compose an already listed directory scope inherit its root proof; their file-loading behavior remains covered by the loader suites.

| File | Predicate | Class | Before | After | Complete budget |
| --- | --- | --- | --- | --- | --- |
| `engine/metta/control.pl` | `metta_with_trailed/3` | primitive | repeated setup/restore implementations | trailed entry and ordinary restoration | 39 |
| `engine/metta/control.pl` | `metta_with_state_write_fence/1` | flag | nonbacktrackable depth counter | trailed boolean, nested restoration | 41 |
| `engine/support_graph.pl` | `support_atomic/1`; `with_support_repairs_deferred/1` | flags | asserted markers | trailed flags; existing mutex/transaction | 51; 44 |
| `engine/type_rules.pl` | `with_typing_policy_stable/1` | context | asserted snapshot | trailed `snapshot/1`; existing mutex | 46 |
| `engine/metta/terms.pl` | `metta_argument_types_in/3` | flag | asserted declared-type guard | trailed flag | 48 |
| `engine/specializer.pl` | `maybe_specialize_call/4`; `segment_specialization/4`; `metta_verified_specialization/2` | stacks and flag | replaced roots; asserted checking marker | trailed stacks and retained `needed/1` payload | 1122; 702; 264 |
| `engine/filereader.pl` | `with_source_definition_order/3`; `with_source_recompile_owners/2` | contexts | asserted contexts | trailed stacks; protected pending-row retirement | 59; 53 |
| `engine/filereader.pl` | `with_working_directory/2`; `with_file_directory/2`; `metta_host_load_file/3` | directory | asserted directory stack and replacement | trailed stack or replacement list | directory scope 44 |
| `engine/metta/reference_loading.pl` | `metta_reference_check_manifest/5` | directory | asserted import directory | existing trailed directory door | directory scope 44 |
| `engine/filereader/source_lifecycle.pl` | `with_owning_source_load/2`; `with_source_load/3`; `rollback_source_load_stable/1` | ownership | asserted contexts; destructively consumed undo rows | trailed stacks; retained undo plan and retry | 44; 126; 278 |
| `engine/filereader/source_lifecycle.pl` | `run_with_loading_marker/2` | real clause | assertion before cleanup registration | registered rollback and retained clause owner | 53 |
| `engine/materialize.pl` | `materialization_transaction/1,2`; `with_source_materialization_batch/3`; `with_source_materialization/3` | ownership | asserted owner, batch and candidates | trailed roots, mutable early-close cell, protected retirement | 66; 77; 221 |
| `engine/materialize.pl` | `discard_space_rows/1`; `discard_image_rows/2` | retirement | ownership rows removed before effects | retain snapshot until retirement finishes | materialization and loader suites |
| `engine/translator_rules.pl` | `rollback_restored_translator_rule/3` | retirement | generation could disappear before cleanup ended | retry inside the captured rule identity | source rollback and rule suites |
| `engine/metta/effects.pl` | `metta_with_source_effect_program/3`; `metta_with_evaluation_context/2`; `metta_bridge_descend/1` | contexts | asserted program, copied global stack, depth setup | trailed roots; preserve input snapshot and depth cap | 58; 43; 29 |
| `engine/metta/references.pl` | `metta_reference_refresh/0`; `metta_reference_force/1`; `metta_reference_finish_frame/2` | flags and stacks | asserted guards | trailed flag and stacks | 90; 15; 111 |
| `engine/metta/registration.pl` | `with_metta_module/2` | context | setup/cleanup writes | trailed module; inactive root defaults to self | 43 |
| `engine/translator/analysis.pl` | `with_static_contract_shortcuts/2`; `with_equation_types/4` | contexts | nonbacktrackable roots | trailed policy and linked equation types | 40; 42 |
| `engine/translator/typing.pl` | `with_static_parameter_environment/5` | context | linked nonbacktrackable root | trailed environment preserving variable identity | 137 |
| `engine/metta/space_hooks.pl` | `metta_hook_apply_counted/6`; `metta_hook_apply/6`; `metta_hook_post_apply/4` | grants | setup/cleanup writes | trailed grants restoring the enclosing value | 32; 24; 161 |
| `engine/metta/space_hooks.pl` | `metta_outer_transaction_prepare/5`; `metta_speculate_prepare/4` | flags | setup/cleanup transaction markers | trailed ownership; unchanged transaction protocol | 137; 82 |
| `engine/spaces/receipts.pl` | `metta_with_occurrence_load/1`; `metta_receipt_forget_scope/1` | ownership | nonbacktrackable root; reservation erased before release | trailed root; retain retirement record | occurrence scope 57 |
| `engine/spaces/tokens.pl` | `metta_remove_occurrence/3`; `metta_remove_provider_occurrence/3` | selector | nonbacktrackable setup and deletion | trailed selection and consumption | 50; 58 |
| `engine/source_observation.pl` | `with_observation/4` | resource scope | context writes before cleanup registration | register teardown first; trail three roots; retain hook ownership | 760 |
| `engine/source_observation.pl` | `source_input/2`; `with_source/4`; `compile_clause/3` | contexts | linked nonbacktrackable roots | trailed roots; retained mutable pending-map cell | 60; 92; 84 |
| `engine/source_observation.pl` | `observe_form/4`; `observe_goals/3` | runnable contexts | replaced/deleted roots | trailed linked locations and runnable suspension | 88; 123 |
| `engine/source_observation.pl` | `execute_observed_goals/5` | real clause | assertion before registration | retained owner; erase and abolish on every exit | 102 |
| `engine/source_loading.pl` | `loading_loudly/1` | real clause | asserted watcher before registration | retained owner; protected watcher and source-module retirement | 63 |
| `engine/metta/interop.pl` | `metta_host_probe_function/2` | real clause | asserted probe before registration | signal-masked assert/catch-erase pair | 11 |
| `extensions/node/bridge.pl` | `metta_node_render/2` | capture | nonbacktrackable flag | engine trailed scope | 172 |
| `extensions/cmetta/bridge.pl` | `metta_c_error_text/2` | capture | nonbacktrackable flag | engine trailed scope | 173 |
| `extensions/python/metta/_binding/messages.pl` | `user:thread_message_hook/3` | reentrancy | nonbacktrackable guard | engine trailed scope; preserve delivery module | 51, test receiver |

The compiler-context budgets 26..29 and 33..34 return failure because the owned `stored_atom_of_ref/4` catches the bound. These are recorded failed exits, not successful propagation. The foreign selector row exercises the owned route's exact capability refusal; the following row exercises actual token consumption. Both still prove restoration. The three public-fuel reproductions now pass all budgets 1..600 without a leaked guard.

Tried: each direct scope warmed for 100 calls and measured over 1000 calls in three samples, using the provisioned cut and changed tree with engine/library QLF files cleared first. All three counts in each arm agree. Subtracting the common empty-loop cost gives the per-entry inference counts below. These are bounded constant-cost replacements; the change closes an interruption window rather than claiming an asymptotic speedup.

| Scope | Cut per entry | Changed per entry | Delta |
| --- | ---: | ---: | ---: |
| support lock | 12 | 13 | +1 |
| support deferral | 7 | 8 | +1 |
| typing snapshot | 10 | 10 | 0 |
| source program | 16 | 21 | +5 |
| source recompile | 9 | 10 | +1 |
| source owner | 6 | 6 | 0 |
| materialization owner | 28 | 30 | +2 |
| effect program | 18 | 18 | 0 |
| evaluation context | 10 | 7 | -3 |
| module context | 8 | 6 | -2 |
| compiler policy | 9 | 5 | -4 |
| equation types | 9 | 5 | -4 |
| parameter environment | 104 | 100 | -4 |
| state fence | 7 | 5 | -2 |
| occurrence load | 25 | 22 | -3 |
| transaction | 101 | 102 | +1 |
| speculation | 51 | 47 | -4 |

Tried: `jscpd --format prolog --formats-exts prolog:pl,plt --min-lines 5 --min-tokens 50 --max-lines 20000 --max-size 2mb --skipComments --noTips` over the 32 changed Prolog files -> six clones, 38 duplicated lines out of 35728, 0.11%. Five are outside the changed code. The counted and ordinary grant branches already shared their setup shape on the cut and now share the same primitive call. Rejected: another wrapper for that single call, because it would add indirection without merging the distinct counting policies. An earlier 8-line/80-token scan reported zero and is not used as evidence that the existing clones disappeared.

Open: run the prescribed whole-tree lanes on the committed state and record the exact counter movements in the landing receipt. The concurrent owners must remove their 15 direct setup findings and reconcile their indirect scopes, the umbrella export, exact foreign removal and compiler-reference catches. The broader plain-host tracing diagnostic above is not repaired by these scope changes.

## 2026-09-11, scope consumer contracts

Tried: the four prescribed gates on 20a1f54f2fd38237ec96002f99e347ae76b12b40
exit 1, 1, 0, 1. The engine finds 29 owned import fixtures still asserting
the directory reader, the owned umbrella's missing primitive export, and
two layering tests. Python finds the new service absent from its manifest,
changed twin costs, the cut's authoring-cost fixture and absolute-path
findings, and an existing 30-second subprocess timeout in the snippet test.
The checks pass prolog, evidence, provenance and both host-workaround lanes;
static refusal names the 15 owned sites, and engine-bench and twins report
changed counters. The receipt preserves every line and status.

Decided: export active_source_load/1 and with_working_directory/2 from their
owning reader, declare support_graph's use of the trailed primitive in the
layering contract, and classify the primitive as a host door in the binding
manifest. These are dependencies introduced by the scope change.

Tried: `sh engine/test.sh suites/seams/layering.plt` passes all seven tests.
The two service-manifest pytest tests pass. The owned umbrella export and
import fixtures remain explicit integration needs.
