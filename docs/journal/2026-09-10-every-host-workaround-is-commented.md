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

## 2026-09-11, receipt retirement after native completion

Goal: every budget 1..600 around a native transaction leaves its clauses
committed or rolled back together and retires the finished receipt scope,
including reservations in the standing engine.

Origin: the PUBLICATION finding came from the main checkout's
`ai-tmp/wt-publication/ai-tmp/publication-d9d1201b/ai-receipt-limit-probe.pl`.
The unchanged probe fails on this branch at budget 77 with
`receipt_limit_residue(77,inference_limit_exceeded,0,Frame-Scope,Refs)`:
four erasures committed, while the owner and four receipt rows remained.

Tried: catch the completion listener, keep its owner until retirement ends,
and schedule recovery with thread_signal/2. The listener's entry can still
be cut before its catch starts. The exception hook then sees the enclosing
host frame, so matching only the listener's predicate misses that entry.
A scheduling-only hook captures the owned scope and reconciles it at the
next clean call port; the original 600-budget reproduction then passes.

Tried: eight sweeps covering erasure and reservation through transaction/1,
transaction/2, transaction/3 and snapshot/1. Snapshot reservation leaks at
budget 142 after rollback removes the reserved row used to decide whether
the standing engine needs retirement. Retaining that obligation fixes all
eight. A nested snapshot then leaves an orphan claim at budget 92: its
rollback marker notification was cut. Reconciling the standing engine's
claim references against the caller's live marker view fixes all twelve
600-budget cohorts, including preservation of the live outer owner.

Rejected: trailing the cached transaction owner at first use. The first
use can run inside forall/2 or another local rollback boundary; its trail
ends before the native transaction does. Wrapping every native transaction
would move that trail boundary but adds a global mechanism to an existing
lazy ownership protocol. The receipt owner is retained retirement metadata:
native transaction state defines its lifetime, and completion removes it.
Its mutable reservation bit survives rollback of the transactional rows.

Decided: retain that owner through complete retirement; catch both native
listeners and schedule their interrupted work before propagating the same
ball from a clean port. An inference exception hook only schedules scope
reconciliation and fails so other hooks still run. A live scope drops only
claims whose markers rolled back; a finished scope drops every claim and
then its rows and owner. Publish the owner before native erasure and put
the erasure's journal write inside an immediately following catch, masking
signals across the pair. The standing engine answers a claims(Scope)
request only for recovery. Ordinary erasure-only scopes still send no
reservation retirement request.

The sites use swi-cleanup-window: interruption between cleanup goals is
already the ledger's host rule, including a listener called after native
commit. The existing tracked reproduction remains its host test; the new
receipt suite tests this application, including marker and reserved rows
and reservations read through an engine outside the caller's snapshot.

Probe correction: replacing a named atom listener with another atom changes
the stored closure but keeps its old procedure in SWI's add_event_hook;
the first throwaway replacement therefore never called its candidate.
Removing that probe listener before registration made the comparison valid.
Production retains its single boot registration and needs no workaround
for replacement. Source: pinned SWI pl-event.c:add_event_hook and
call_event_list at fc7ef84b949378b729052c3ade79c90ce5416abb.

## 2026-09-12, a deferred receipt limit retains its public envelope

Tried: the implemented receipt sweep passes 17 cohorts of 600 budgets,
including every completed scope's rows and standing-engine claims, clean
second entries, existing and newly allocated outer ownership, and a bound
caught inside a transaction after one erasure. The existing frame tests
pass 4 tests and 7 subtests; token and image tests pass 29 and 5 subtests.
The supplied reproduction passes all 600 budgets.

Found: a deferred callback can raise inference_limit_exceeded after SWI's
limiter has returned. The native sweep accepts that same ball as a raised
exception as well as a limiter result; its first assertion had incorrectly
accepted only the result. The shared public builder must still return its
documented control envelope: its direct erasure probe instead exposes the
raw atom at budgets 101..116.

Decided: one catch around the shared bounded conjunction converts that raw
atom through metta_inference_bound_exceeded/1. The positive budget, its
native limiter and its cumulative check are unchanged. Non-positive budgets
still return the original goal. A warmed direct counter probe measures one
additional inference at entry; the per-answer slope stays three. Extend
the receipt sweep through the public builder for all four native boundaries
and both operations, and update the affine cost assertion to three per
answer plus two at entry.

Tried: the final receipt suite passes all 25 cohorts of 600 budgets, 15000
trials. The public-envelope probe reports no raw ball at any budget. The
17 inference-budget tests pass with the changed entry charge; the 17 scope
tests and 40 subtests pass with native delayed balls counted as interrupted
exits. Every restoration and second-entry assertion remains in place.

Tried: load the main checkout's limits.pl unchanged beside this receipt
implementation, then run its four host-limit tests and all receipt cohorts:
all pass, and the process reports two exception-hook clauses. The temporary
compatibility fixture changes only source paths and explicitly loads that
file; the owned engine umbrella is unchanged.

Tried: regenerate all 46 production-door budget ranges after receipt
integration. Five completion budgets change: occurrence load 57 to 61,
source rollback 278 to 279, post hook 161 to 184, foreign selector 50 to 51,
and loading marker 53 to 54. Every range still has zero retained state and
a clean second entry. The remaining table values above are unchanged.
Three 1000-entry counter samples agree at every measured door. The standalone
empty occurrence load now costs 26 inferences per entry, versus 25 on the
cut and 22 before receipt reconciliation: its retirement checks the retained
transaction record before deciding that no engine request is owed. All other
direct scope costs above remain unchanged. The recovery-only claims request
reuses forget_claim/1; no additional protocol is needed for normal execution.

Tried: the same 5-line/50-token duplication scan over all 36 changed Prolog
files finds eight clones, 52 lines out of 37009, 0.14%. The two added clones
are the receipt tests' declared fixtures and budget loops. Their boundary,
operation, cleanup and state checks already share predicates; retaining each
plunit setup/cleanup declaration keeps ownership explicit. The other six
clones are the previously inspected pairs.

## 2026-09-12, committed-tree verification and cost attribution

Tried: the four prescribed commands on
2b820c2afa0962522651e19936979de8b44ad669, whose executable content is
cdcb23421809ec3a493059a381e0245cf08a1984:
sh engine/test.sh exits 1; sh extensions/python/test.sh exits 1;
sh test.sh exits 0; sh check.sh prolog prolog-static evidence
provenance-pin-selftest host-workarounds host-workarounds-selftest
engine-bench twins exits 1. Each complete output and captured status is
retained in the landing receipt. No extra shell deadline was added.

The engine has 29 owned import fixtures asserting the now-static
filereader:working_dir/1 and one owned umbrella export assertion:
[metta_with_trailed/3]==[]. The reader exports, support layering and Python
service-manifest corrections pass. The new receipt suite passes all 15000
trials within the complete engine run; the MORK-backed token test executes
and passes. The static rule still names the 15 owned sites, with its planted
and parser selftests green. Evidence finds 0 unbacked tags in 7455 claims,
0 WORKTREE placeholders and 13220 known test names. Provenance's selftest
reports 0 defects over 44 plants in 19 files. The host ledger reports all
11 reproductions present at 77 sites; its ten planted defects are reported.

Tried: ordinary counter-only engine benchmarks at the same physical control
path through each functional commit, clearing generated QLF files and
checking all 11 native artifact hashes before each stage. Three samples
agree in every row. All original movements enter with the contexts commit;
actual-clause, binding and consumer commits add zero to these four cases.
Receipt completion and the public envelope add 2 to evaluate and 58 to
translate.

| Case | Cut | Contexts | Clauses, bindings, consumers | Receipts and final |
| --- | ---: | ---: | ---: | ---: |
| evaluate | 558928 | 559093 | 559093 | 559095 |
| match | 267402 | 263802 | 263802 | 263802 |
| match-skew | 208102 | 208002 | 208002 | 208002 |
| translate | 315275 | 317877 | 317877 | 317935 |

The measured mechanisms are changed scope entry/exit costs and the extra
lookup when a formerly empty dynamic guard becomes a context reader.
Each of seven inactive guard readers costs two inferences through ignore/1,
versus one on the cut; the module reader remains three. All three warmed
1000-read samples agree. Direct scope costs are recorded above. The boot
counter is 320124 versus the earlier same-path cut's 319100, a 1024 increase.
The canonical boot PMU row is explicitly not measured at this checkout
shape; its pin is not advanced. Parse and parse-prolog inference counts
remain 152 and 3539934.

Twins prove all 2190 claims over 282 examples. Every claim-count and
storage-status row agrees with the cut. The 282 findings are cost findings:
257 pinned increases, six pinned decreases, twelve relative/authoring bands,
six empirical ranges and one obsolete overrun. The receipt's complete TSV
records each example's before/after MeTTa and twin counts and exact findings.
The cut already exceeds git_import's empirical range at 26263 versus 26247.
Redis is the only capability-dependent skipped budget in either arm; MORK
executes. No counter pin or allowance is changed here.

Found: the first final Python run stops after 5223 passes and 93 skips when
worker gw3 receives SIGSEGV in the compiled-tail-duals statement case. It
also reports the identity twin's 2622 versus 2586+20 and the cut's authored
cost fixture. The complete suite had collected 5691 items, leaving 372
unreported when the worker died. A read-only core backtrace enters stripped
libswipl frames from Janus. It does not establish the faulting predicate.
Matching debug-symbol downloads return HTTP 404; symbols for another
release are not substituted.

Tried: the six-case tail-duals file with seed 2092133236 passes on both arms.
The complete Python suite with that seed then finishes on both arms:
the branch has 5588 passes, 100 skips and three failures; the cut has
5589 passes, 100 skips and two failures. Both fail the authored cost fixture
and the owned classes journal's absolute path. Only the branch exceeds the
identity twin pin. The original native crash remains unassigned and is not
claimed fixed by a successful rerun.

Tried: a diagnostic using public wrap_predicate/4 passes the four benchmark
bodies on the branch but segfaults in translation on the cut. Its translation
call counts are excluded from attribution; this different instrumented
failure does not explain the Python crash. A module-reader-only profile
passes all four bodies on both arms. A process-only hook ablation first
abolished a predicate the host had cached and raised
Unknown procedure: prolog:prolog_exception_hook/5. Retaining the empty
dynamic predicate makes both ablation arms complete. These diagnostic
inference counts are not substituted for the ordinary benchmark samples.

Found: a gate rebuild replaces the final Rust MORK object after the initial
eleven-artifact equality check. Its text and data sections differ from the
control object, so equality cannot be inferred from unchanged source alone.
Tried: give both arms the same final Rust object, then run the token/image
suite and the MORK example/twin directly. Both suites pass 29 tests and five
subtests, including the MORK-conditioned refusal. Both twins prove two
claims with equal storage. The measured MeTTa/twin costs exactly repeat
the complete lanes: cut 55621/49959 and final 56849/51333. The cut twin exits
0; the final twin exits 1 for its unchanged cost pin. This focused check
closes the native-artifact comparability question for the MORK result.

Open: owners must apply the exact scope, reader-fixture, service-export and
foreign-removal corrections in the landing receipt. The broader debugger
bound failure described above and the non-reproduced Python native crash
remain unresolved diagnostics. They are not evidence of repaired host
debugging or permission to widen a bound.

## 2026-09-12, the reader tax and the resident hook

Goal: a trailed guard costs what the asserted guard it replaced cost, and a
process that never bounds pays nothing for the receipt listener's hook.

Tried: the PUBLICATION reproduction
`ai-tmp/wt-publication/ai-tmp/publication-d9d1201b/ai-receipt-limit-probe.pl`
(SHA256 75286fec11eb07d3ba0a9d9b9cd8a0ac296c949109786eae19839e841499f7ec)
against this branch at ebeb82e0a -> `passed_600_budgets`, exit 0; against the
pristine cut b1d175f13 -> `receipt_limit_residue(77,inference_limit_exceeded,0,-(299,60),[four clause refs])`,
exit 1. Both arms had their engine and library artifacts purged first.

Measured: each engine benchmark case under library(prolog_profile), branch
against cut (`ai-tmp/ai-guard3-profile-bench.pl`, `ai-tmp/guard3-receipts/profile-*.tsv`).
translate +4,522: nb_current/2 +2,142, lists:member/2 +791 and member_/3
+761, b_setval/2 +615, metta_with_trailed/3 +497, the wrapper readers
themselves 1,873 calls (source_recompile_context/2 838, active_source_load/1
761, typing_policy_snapshot/1 161, support_graph_locked/0 83,
active_source_program/1 30), prolog:prolog_exception_hook/5 +58 (one per
ball the workload throws). evaluate +433: nb_current +149, the hook +2.
match -3,683 and match-skew -156: the trailed door replaces
setup_call_cleanup/3, sig_atomic/1, nb_setval/2 and nb_delete/1 per query.
A 20,000-atom add loop reads +19,938, one nb_current/2 per
active_source_load/1 the loader asks per stored atom. So the tax is one
inference per reader call (the wrapper predicate around nb_current/2), one
more per stack read whose list is [] or non-empty (member/2), and one per
ball thrown while the hook clause is resident.

Measured: per read above an empty loop in bare SWI 10.1.13, key unset /
inactive [] / one element (`ai-tmp/tmp/gx/run.pl`): a dynamic fact under \+
2/2/1; the wrapper `head_read/1` 3/3/2; an inlined `nb_current(K, L),
member(X, L)` 2/3/4; an inlined `nb_current(K, [X0|More]), (More == [] -> X
= X0 ; (X = X0 ; member(X, More)))` 2/2/1, deterministic on one element,
the choicepoint member/2 would leave on two. So the wrapper call is the
whole tax in the unset state and the member call the rest, and only a
compile-time expansion removes the call.

Rejected: a predicate_property/2 guard on the caller's module, because on a
name the module does not have it walks the autoload index (15,265
inferences at compile time) and loads a library when the name is in one
(partition/4 became defined); `'$get_predicate_attribute'(Module:Head,
imported, Owner)` answers the same question at 4 to 7 inferences with no
autoload and resolves through the base chain
(docs/journal/2026-09-06-the-price-of-asking-whether-a-predicate-exists.md).
Rejected: a new `engine/contexts.pl` unit, because a module file loaded
through use_module/2 under qcompile(auto) is a 24th governed artifact, which
the C seat's `boot_qlf_count` refuses in update mode too, and the seam
already publishes the write side (`kind(metta_with_trailed/3, host_service)`)
and hosts declaration seams whose rows other files write (`engine_emitted/1`,
`builtin_type_declaration/2`). Rejected: a directive that calls
compile_aux_clauses/1 at load, because a directive is recorded in the
artifact and runs again when the artifact loads, so the clauses would be
added twice; library(record) and library(persistency) expand their
declaration directive away through term_expansion for the same reason.
Rejected: module-local goal_expansion/2 clauses in each subsystem, because an
imported reader called unqualified from another module is expanded through
the caller's module chain, which never reaches the owner (probe
`ai-tmp/tmp/gx/run.pl`: `caller:imported(X) :- rd(X)` stayed a call), and
metta_engine:goal_expansion/2 belongs to the umbrella, which another package
owns at this cut.

Decided: `:- seam:context_reader(Head, Key, Shape)` in engine/ext_points.pl,
a declaration seam. system:term_expansion/2 turns the directive into the
row `seam:context_reader(Head, Owner, Key, Shape)` and the clause
`Head :- Read`; system:goal_expansion/2 compiles a call to the read wherever
`Module == Owner` or `'$get_predicate_attribute'(Module:Head, imported,
Owner)`, the binding's guarded system:goal_expansion shape
(extensions/python/metta/_binding/source_macros.pl). Two shapes:
`value(Pattern)` and `stack(Pattern)`. Eighteen readers declared: filereader
4, materialize 3, support_graph 2, type_rules 1, specializer 1, and in the
engine fragments terms 1, effects 2, references 3, control 1.
materialization_batch/1 loses its arg/3 guard and its three callers ask for
`batch(open)`, the cell's own shape. A qcompile round trip keeps the rows and
the static clauses (`ai-tmp/tmp/gx/run2.pl`). One caller stays a call:
translator:runnable_head_awaits_its_definition/1 compiles before filereader
loads, so no row exists for it yet; that is the umbrella's load order, owned
by another package at this cut.

Decided: the receipt listener's exception hook is clausal only from the
process's first bound on. engine/source_observation.pl records why a
resident clause is refused (119 on translate, 2 per compiled host request),
and the profile above reads the same +58 on translate for this branch's
resident clause. receipts.pl wraps '$syspreds':call_with_inference_limit/3
once (`metta_receipt_first_bound`) and the wrapper asserts the clause under a
mutex if it is absent; the clause is its own armed record. A child process
reads `armed(0,1,7,8)`: no clause before its first bound, one after, a caught
ball 7 inferences before and 8 after
(tests/prolog/suites/spaces/receipt_limits.plt,
the_limit_hook_is_armed_by_the_first_bound). At the merge this wrapper folds
into engine/metta/limits.pl's `metta_host_first_bound_once/0`, which installs
the same kind of clause for the same reason.

Tried: `sh engine/test.sh suites/evaluation/trailed_scopes.plt` -> 22 tests
and 40 subtests passed, the new ones: every declared reader is compiled to
its read, a call site carries the read, an inactive and a one-element read
cost the dynamic fact's inferences (10,000-iteration loops, equal counts), a
one-element stack leaves no choicepoint, a malformed shape or key refuses.
`sh engine/test.sh suites/spaces/receipt_limits.plt` -> 5 tests and 21
subtests passed, 15,000 budget trials and the armed-hook child.

Tried: the four prescribed commands on 5dac08615593fffd7536cbd50e4fd4955b09f305
(engine 1, python 1, repository 0, checks 1; `ai-tmp/guard3-receipts/gates.tsv`).
The engine suite's reds are the 29 owned lib_import fixtures that assert
`filereader:working_dir/1` and the owned umbrella's missing
`metta_with_trailed/3` export, unchanged. The Python suite read 17 reds, 12
of them every profile door raising `//2: Arithmetic: evaluation error:
zero_divisor`; the same test is red on the pristine cut at today's load
(`ai-tmp/guard3-receipts/repro-profile-control.log`) and green in the
predecessor's runs at loadavg 30.
Found: SWI's profile/2 prints its report as the cleanup of the goal
(library/prolog_profile.pl:117), and time_data/7 divides each predicate's
ticks by the total, so a zero-sample profile raises from the report after
the goal answered; the absorb clause in
extensions/python/metta/_binding/profiling.pl tested `nonvar(Out)` in the
catch's recovery, where the goal's bindings have already been unwound, so it
never fired. A quiet box finishes `!(prof-stats 20000)` inside one 5 ms
sampling period (samples=0 ticks=0 time=0.0004 s), which is when the latent
defect shows.
Decided: the profiled goal records its answer into a cell with nb_setarg/3
before the report can raise; the recovery absorbs the report's zero divisor
only when the cell holds an answer, and the door answers from the cell. A
zero-sample profile keeps its call rows with zero ticks
(test_a_profile_with_no_samples_still_answers). The two remaining Python reds
are the cut's own: the authored-cost fixture (repaired on trunk after this
cut) and the owned classes journal's absolute path.
Decided: the profile and read-shape probes the seam's measured tags name are
tracked under tests/prolog/probes/, because the evidence lane refuses a
claim whose command lives under ai-tmp/.

## 2026-09-12, one write per answer

Tried: the twins lane on 5dac08615 against the pristine cut -> example costs
277 of 282 below the cut and twin costs 188 below, 85 above; the largest
twin increases 03-matespace +1,061,546 (24,117,750 to 25,179,296),
04-matespace2 +1,294,628, 01-thread_lib +12,393, 14-reflect_lib +3,056, all
present at the wrapper stage ebeb82e0a too, so none from the reader door.
Measured: the matespace twin profiled per predicate on both arms
(`tests/prolog/probes/twin_profile.py`): the whole difference is
system:b_setval/2, 1,585 calls on the cut against 1,064,767, one per
tabled answer boundary; counted by key, 1,064,711 writes of '$metta_module'
against the cut's 1,572, every one attributed to the frame of
metta_with_trailed/3 under metta_py_solution/4, the binding's per-solution
module scope.
Mechanism: metta_with_trailed/3 writes the prior value back on EVERY exit,
so a scope around a solution generator pays one write per answer and the
trail reinstates the inner value on each redo. The cut's with_metta_module/2
was setup_call_cleanup(b_setval(Module), Goal, b_setval(Previous)): the
value held across the enumeration and the prior returned once, when the goal
finished, cut, failed or raised. The engine's fuel scope has the same shape.
The rule refusing b_setval/2 in a Setup made the module door migrate with
the rest, and the evaluation context, whose push was already trailed,
followed it for uniformity; a trailed setup write was never the leak, the
unwinding undoes it.
Rejected: opening the module scope once around the binding's collector, so
the per-solution scope becomes a same-value no-op, because it costs +4
inferences on a one-answer evaluation, the common shape, to save N on an
N-answer one. Rejected: skipping the write when the value already held is
the same atom, because registration.pl records that skip measured and taken
out on 2026-08-16 (+2 on every annotated typed call), and it is not needed
once the generator scopes take the enumeration shape.
Decided: a second door beside the primitive, metta_with_trailed_enumeration/3:
setup_call_cleanup(true, (b_setval(Key, Value), Goal), b_setval(Key, Previous)).
The entry write comes after the cleanup is registered and is trailed, so a
limit tripping at any port unwinds it; the cleanup writes the prior back
once. with_metta_module/2 and metta_with_evaluation_context/2, the two doors
that wrap generators, take it; every other scope keeps the per-answer
primitive, cheaper by two inferences per deterministic entry. Not a seam
row: only engine fragments call it; a seat that needs it publishes it with
the scoreboard entry and the umbrella export.
Measured: the matespace twin reads 24,117,731 through the enumeration door,
19 below the cut, and its '$metta_module' writes 1,572, the cut's count.
The engine rows: evaluate 558,915, match 265,602, match-skew 208,042,
translate 314,835, every one below the cut (558,928 / 267,402 / 208,102 /
315,275). Python rows that went below their pins with the reader door
(foreign-match 779,234, eval-arith 275,234, run-source 435,234) read
787,234, 279,234 and 439,234 through the enumeration door, still at or
below the cut's pins; query-2k-rows, query-where, loop-1m and add-single at
their pins on both trees.

## 2026-09-12, what a bounded call pays for the armed hook

Tried: the Python seat's guarded query row against the cut's pin ->
query-limit-guarded 38,407 where the pin is 37,707, over one hundred guarded
queries [extensions/python/bench.py --counter-only query-limit-guarded, min of
three fresh processes; the pristine control at b1d175f13 passes the pin].
Mechanism: the wrapper this thread put on '$syspreds':call_with_inference_limit/3
runs on every bounded call of the process, and its body asked whether the hook
was armed with clause/2 over prolog:prolog_exception_hook/5, four inferences a
call. Placed by arms: the same tree with this unit at its pre-wrapper state
reads 37,807, so 600 of the 700 is the wrapper and 100 is the rest of the
package, one inference a guarded query.
Decided: a dynamic metta_receipt_bound_seen/0 is the memo every later bound
reads, asserted after the hook clause it records and under the same mutex, and
the test moves into the wrapper's own body so a bound pays one predicate call
and not two. The clause stays the armed record: the arming path re-checks it,
so a bound cut between the two assertions leaves a state the next bound
completes and neither assertion can happen twice. The row reads 38,107.
Measured: a meta-called bound costs 9 inferences against the cut's 6, 11 with
the previous body and 12 with a named wrapper predicate
(ai-tmp/ai-guard3-bound-cost.pl, min of three loops of a thousand).
Rejected: unwrap_predicate/2 after the first bound, which would make every
later bound free, because it releases the closure blob another thread may be
executing at that moment; trunk's engine/metta/limits.pl records the same
refusal for its own wrappers.
Note: trunk pins this row at 38,107 for its own first-bound wrapper, the same
number this branch now reads, so the merged tree pays the cost once and the
pin it already carries is the one that survives.
Note: two measurement traps cost a full round each, both silent. A probe under
ai-tmp/ that spells `../../engine/metta.pl` loads the NEIGHBOURING CHECKOUT,
not this worktree, and reads its engine; and an edit to a unit leaves its
umbrella's .qlf fresh by mtime, so a process started without the engine's own
warm boot measures the previous compile. Together they read identical
inference counts for three different versions of engine/spaces/receipts.pl,
the cut's included, which looks exactly like a change that costs nothing.

## 2026-09-12, the report that walked a directive in the wrong module

Tried: the prolog-reach REPORT on this branch against the pristine cut ->
1,995 findings on the cut and 2,007 here through the cut's own doors, 16 of
them new and 4 of the cut's rescued. The 16: six context readers of arity zero,
which no clause names because every call to one compiles to its read; the seven
predicates of the armed receipt hook, named only inside a wrapper body and an
asserted clause; retire_loading_marker/2 and metta_py_profile_answering/3; and
three bodies this thread extracted from callers the cut already reports,
mark_specialization_needed/0 with metta_receipt_finish_frame/1 and
metta_receipt_marker_change/2.
Decided: a root class for the declaration table, seam:context_reader/4, since
the row's head is the only place a reader is named. Worth 6.
Decided: the directive door globs '*/*.pl' as well, because a subsystem's units
live one directory down and install as much as any file at the top. Worth 63.
Decided: a module-qualified name held as data is a goal, at whatever arity that
module defines it with. prolog_listen/3 and thread_signal/2 take a handler NAME
and call it with the event's arguments, so receipts.pl spells its two listeners
as atoms and defines them at 1 and 2, and the body it asserts into
prolog:prolog_exception_hook/5 is an atom of arity 0. Worth 9, of which the
arity lower bound is 7. A BARE atom stays data: reading one as a name would
make every atom in the tree a reference.
Mechanism, and the largest of the four: a directive runs in the module its file
belongs to, and the probe clause that carries it is asserted here, in user. So
`:- metta_boot_receipts.` was walked as user:metta_boot_receipts/0, a predicate
nothing defines, and every predicate that directive reaches counted as dead.
The module a file declares answers through source_file_property/2, and a unit
that declares none is consulted into one, which its load_context answers.
Worth 120: the engine's builtin census and its prelude installation are both
reached only from their own file's directive.
Measured: 1,832 findings with all four, 2,007 with none of them, against the
cut's 1,995 [sh tests/prolog/probes/reachability_doors.sh, which disables one
door at a time and counts]. The one finding of the 16 that survives is
mark_specialization_needed/0, whose two callers, maybe_specialize_call/4 and
specialize_call/9, the cut already reports: a call from an unreachable clause
does not rescue its callee, which is this lane's own rule.
Tried: the plant for the directive door, which passed with the door disabled.
run_selftest matched planted(Door, Name/Arity, Expectation), and a row naming a
module is Module:Name/Arity, which does not unify with Name/Arity, so the row
was dropped from the findall in silence while the count still included it. The
mutation experiment is what caught it, which is the reason it exists.
Decided: the selftest reads a plant's whole indicator and plant_qualified/2
adds user: to a row that names no module, so the table can name one. Fifteen
plants now, five of them for the doors above, and the probe that disables each
door re-runs the discrimination: every mutation is caught naming exactly the
door it disabled.
