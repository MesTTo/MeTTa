# Audit acceptance tests and repairs
Goal: verify all 48 Python-seat audit findings on efac42a31055f59a2ff0580f1ff138072c946fab and repair every live finding in the owned files.
Constraint: shared seam and result symbols require coordination. Classes files, binding Prolog, engine, library sources and the door/artifact generators remain integration responsibilities.

## 2026-09-15

### Opening citation map

Paths below are relative to `extensions/python/metta/` unless they start with `tools/`, `tests/`, or a repository document. Status is unchecked until the finding's acceptance result is recorded below. A source change is not a passing reproduction.

| Finding | Original citation | Current file and symbol | Owner |
|---|---|---|---|
| F01 | seam.py:_restore,_unregister | seam.py:_restore,_unregister | shared, audits mutation functions |
| F02 | seam.py:_both | seam.py:_both | shared, audits |
| F03 | seam.py:_enlist; ops._record_seam_undo | seam.py:_enlist; _declare/operations.py:_record_seam_undo | audits; classes consumer |
| F04 | seam.py:_register,_enlist; door_catalog.pl | seam.py:_register,_enlist; _catalog/kinds.py:_doors_changed; _binding/door_catalog.pl | audits; unassigned consumer; binding integration |
| F05 | seam.py:Row; doors.py:_snapshot | seam.py:Row; doors/__init__.py:_snapshot | audits; doors |
| F06 | doors.py:validate | doors/__init__.py:validate | doors |
| F07 | seam.py:advertised,_LOADED_ENTRIES | seam.py:advertised,_load_entries,discover,_load_advertised | audits |
| F08 | _aio_evaluation.py:EvaluationView.__aexit__; _evaluation_door.py:_Stream.__exit__; results.py:Answers.__exit__; _space_objects.py assumption exit | aio/_evaluation.py:EvaluationView.__aexit__; _spaces/evaluate.py:_Stream.__exit__; _spaces/results.py:Answers.__exit__; _spaces/scope.py assumption contexts | unassigned async; classes; audits; doors |
| F09 | _space_definitions.py plain class preparation/replacement | _declare/definitions.py:_prepare_plain_data_class,_plain_replacer; _catalog/build.py | classes |
| F10 | _object_fields.py:field_names; spaces.ObjectSpace | _atoms/fields.py:field_names; spaces.py:ObjectSpace; integrate.py reflection | unassigned helper; doors consumers |
| F11 | results.py:_into_fields,rows_into,_constructor_rows | _spaces/results.py:_into_fields,rows_into,_constructor_rows; _catalog/build.py | audits; classes |
| F12 | tables.py:add,_add_arrow_stream | tables.py:add,_add_arrow_stream; _catalog/arrow.py:read_batches; provider frame/arrow registrations | audits; doors; external providers |
| F13 | _space.py:_door_register_foreign_library,_door_register_library_path | _declare/prolog.py:register_foreign_library,register_library_path | doors |
| F14 | results.py:Answers,_AnswerItem; _aio_evaluation.py | _spaces/results.py:Answers,_AnswerItem; aio/_evaluation.py:_EvaluationGroup._cached | audits; unassigned async consumer |
| F15 | results.py:Answers.__getitem__ | _spaces/results.py:Answers.__getitem__ | audits |
| F16 | _config.py defaults,configure,getters,publish | _catalog/bounds.py:Setting,Config,settings,publish; tools/configgen.py | unassigned configuration/generator |
| F17 | _contract.py:install | _catalog/kinds.py:install,_SENTINEL; _binding/door_catalog.pl | unassigned ontology; binding integration |
| F18 | _door_catalog.py:_contract,_types; _contract.py | doors/_catalog.py:_contract,_types; _catalog/kinds.py:ONTOLOGY | doors; unassigned ontology |
| F19 | _callbacks.py callback map,typing,__all__ | _binding/callbacks.py generated region; _binding/interface.py:CALLBACK_GROUPS; tools/bindinggen.py:callback_projection | generated; classes declaration; generator integration |
| F20 | parallel.py:_CALLABLE_HOPS,_reachable,capture refusal | parallel.py:_CALLABLE_HOPS,_reachable,_refuse_engine_capture | classes |
| F21 | doors.py answers Sugar/Body,_invoke; doorgen.py | _spaces/evaluate.py:answers; doors/__init__.py:Sugar,_invoke; tools/doorgen.py:contract_findings | classes; doors; generator integration |
| F22 | doorgen.py test selector and raises AST coverage | tools/doorgen.py:contract_findings; tools/evidence.py | generator integration |
| F23 | check_generated_artifact_group.py,check.sh,DEVELOPING.md | tools/artifacts.py:ARTIFACTS,ordered,projections; tests/checks/check_generated_artifact_group.py; check.sh; DEVELOPING.md | generator and repository integration |
| F24 | _parameterized.py:_typed_dict_fields | _catalog/containers.py:_typed_dict_fields,TYPED_DICT_HOOK; _catalog/annotations.py | classes |
| F25 | paths.py:Path,_remember_identity,_path_step; shim path base case | paths.py:Path,_remember_identity,_path_step; _binding/operations.pl | unassigned path; binding integration |
| F26 | _define_context.py:CompilerContext and lowering mixins | _compile/context.py:CompilerContext; _compile/expressions.py:ExpressionCompilerMixin; _compile/statements.py:StatementCompilerMixin; _compile/loops.py:LoopCompilerMixin | classes |
| F27 | _space.py:name,dropped,to_wire,_space; _scope.current; doors rows | _spaces/handle.py:SpaceHandle._space,name,dropped,to_wire; _spaces/lifetime.py:current; colocated door effects | classes; doors lifetime |
| R1 | _space.py:drop; _persistent.py:close | _spaces/handle.py:SpaceHandle.drop; foreign/_persistent.py:PersistentSpace.close | classes; doors provider |
| R2 | remote.py timeout,worker,HTTP response | remote/_transport.py:OutcomeUnknown,_mutate; remote/_gateway.py:Gateway._mutate,_RemoteWorker,_worker_response,serve; remote/_network.py:HTTPEndpoint.request | audits |
| R3 | parallel.py:FutureSpace,every | parallel.py:FutureSpace,every | classes |
| R4 | remote.py ordinary response and cursor validation | remote/_transport.py:_response; remote/_client.py:RemoteSpace | audits |
| R5 | remote.py:RemoteCursor.__init__,_absorb,close | remote/_client.py:RemoteCursor.__init__,_absorb,close; remote/_transport.py:ProtocolError | audits |
| R6 | parallel.py:EnginePool workers,close | parallel.py:EnginePool | classes |
| A1 | _space.py:add,remove,take,__isub__,__delitem__ | _spaces/store.py:add,remove,take,__isub__,__delitem__; _spaces/handle.py atom normalization | doors; classes normalization |
| A2 | _space.py:remove,__isub__ | _spaces/store.py:remove,__isub__ | doors |
| A3 | results.py:Answers.__eq__,__hash__ | _spaces/results.py:Answers.__eq__,__hash__ | audits |
| A4 | aio.py:AsyncMeTTa.define; _space.py:define | aio/_mirror.py generated define projection; _declare/definitions.py:define; tools/aiogen.py | classes; generator integration |
| A5 | aio.py:AsyncMeTTa.space; _space.py:space | aio/_worker.py:AsyncMeTTaBase.space; _spaces/handle.py:SpaceHandle.space; generated mirror | unassigned worker; classes |
| A6 | aio.py:AsyncMeTTa.eval; _space.py:eval | aio/_evaluation.py and generated evaluation projection; _spaces/evaluate.py:eval | unassigned async; classes |
| A7 | __init__.py:space; _space.py:space | __init__.py generated exports; __init__.pyi; _spaces/handle.py:SpaceHandle.space; tools/initstubgen.py | generated; classes; generator integration |
| A8 | results.py:Rows.one,Rows.first | _spaces/results.py:Rows.one,Rows.first | audits |
| T1 | __init__.py lazy exports,__getattr__,TYPE_CHECKING | __init__.pyi; __init__.py lazy exports; tools/initstubgen.py | generated; generator integration |
| T2 | _space.py:Space.op,Space.define,MeTTa forwards | _faces/metta.py generated forwards; _faces/space.py; _declare/operations.py; _declare/definitions.py; tools/doorfaces.py | generated; classes; generator integration |
| T3 | py.typed; _atom_namespace.py namespace type/methods | py.typed; _atoms/namespace.py:Namespace; all exported modules measured by basedpyright | doors namespace; audits owned annotations; other owners |
| T4 | pyproject.toml deptry; notebooks/tour.ipynb | extensions/python/pyproject.toml tool.deptry; extensions/python/notebooks/tour.ipynb; extensions/python/check.sh | repository integration |
| G1 | EXTENDING.md extension cost; test_documentation.py | EXTENDING.md; extensions/python/tests/repository/test_documentation.py:test_the_extension_cost_tables_match_the_committed_pins; extensions/python/benchmarks/extension_cost.py | repository integration |
| G2 | pyproject.toml mypy overrides; check.sh diagnostic comments | extensions/python/pyproject.toml tool.mypy; extensions/python/check.sh | repository integration |
| WT1 | test_twin_coverage.py identity twin budget | extensions/python/tests/repository/test_twin_coverage.py:test_a_shipped_twin_agrees_with_its_example_end_to_end | integrator cost ownership |

Tried: clean Git status and `git log -1 --format=fuller` establish the unchanged cut and MesTTo identity. `getrecent -n 15` prioritized generated QLF files; modification times did not establish source changes. Semantic journal search found the September 5 remote recovery record and September 9 binding record. The main checkout has no `ai-notes` directory. Semantic Git index refresh and source lookup are recorded in the worktree scratch receipt.

Decided: classify each row only after its executable check. Existing remote recovery, generated configuration, callback projections and abstract compiler requirements are candidate prior fixes, pending execution and Git attribution.

### Repair design foundations

Purpose: preserve mutation identity, preimages, resource ownership and every independent failure. Database undo logs map to exact registry inverses; saga compensation maps to observer rollback; immutable inputs map to coherent cached projections; Python signatures map to accepted constructor inputs; distributed request identities map to mutation-outcome uncertainty.

Source: Python 3.12 `contextlib.ExitStack` calls every registered cleanup in reverse registration order but preserves nested exception context. Explicit exception groups are required for the audit's simultaneous-failure contract. Python 3.12 `inspect.BoundArguments` projects one binding into `args` and `kwargs`, with defaults omitted until `apply_defaults`. `EntryPoint.dist` supplies distribution metadata; Distribution instances do not provide value equality. References: https://docs.python.org/3.12/library/contextlib.html#contextlib.ExitStack, https://docs.python.org/3.12/library/inspect.html#inspect.BoundArguments, https://docs.python.org/3.12/library/importlib.metadata.html#entry-points.

Rejected: parsing escaped prose for registration identity, using one replacement inverse for insertion and deletion, dropping later cleanup failures, or counting duplicate metadata objects as distinct ownership. Each loses information already available at the operation boundary.

Open: baseline checks, exact historical fix attribution, owned repairs, coordinated handovers and final gate attribution.

### Unchanged-cut acceptance results

Tried: `sh extensions/python/test.sh -n 0` with absolute node paths. The initial owned checks reported 35 failed and 4 passed; integration checks reported 65 failed and 9 passed. Python 3.14 defers module annotations, so the callback-generation probe now checks the generated annotation syntax. The evidence probe now supplies a standalone base row. The combined run reported 65 failed and 128 passed in 32.20 seconds; all 119 existing regression cases passed. Logs are `ai-tmp/ai-audits-baseline-owned.log`, `ai-tmp/ai-audits-baseline-integration.log`, and `ai-tmp/ai-audits-baseline-existing.log`.

Tried: the additional native-store/HTTP/lifecycle checks reported 7 failed and 8 passed in 5.65 seconds. Arrow ingestion retained `(ingested 1)` after a late reader error; Symbol and Grounded removal returned false through both gateway and HTTP; an abandoned pool retained its owner; FutureSpace has no explicit close method. An initial probe import used absent `metta.E`; using `Expression` corrected collection. The log is `ai-tmp/ai-audits-baseline-extra-corrected.log`.

Tried: the exit/MDL/carrier battery reported 11 failed and 10 passed in 3.96 seconds. All six owned exit cases displaced the body failure. Both subtraction branches bypassed speculative execution; keyword mapping and two multi-proof event guards failed. The log is `ai-tmp/ai-audits-baseline-mdl-exits.log`.

Measured: basedpyright 1.39.6 consumer verification of the unchanged cut reports completeness 0.7098844672657253, 1106 known, 65 ambiguous and 387 unknown exported symbols. Consumer checking rejects invalid Space, spawn, define and op calls and preserves S/V types; `Spcae` remains Any. The original deptry command reports the notebook SyntaxError and 29 tool-import issues; the actual `. tools` gate passes while retaining that notebook omission. Mypy passes 175 source files with no unused override report; the ty gate still carries the obsolete 67-diagnostic comment. Logs use the `ai-audits-baseline-` prefix.

Source corrections: F08 and F14's hand-written `aio/_evaluation.py` is assigned here. F16's generator is `extensions/python/tools/boundsgen.py`. F22's evidence checker remains `tools/doorgen.py:contract_findings`; no separate evidence runner repairs it. A4-A6's async applied surface is `aio/_worker.py:AsyncMeTTaBase.define,space,eval`. A2's corrected Counter contract is explicit in c6a40460b1db341198a6150e3600f502831a6e83; the one-copy behavior now agrees with its documentation.

Prior fixes: settings, compiler abstraction and artifact dependencies are in cd62330ceacc8f1254eed9791c3f6203b48a1c9e; callback derivation is in 8358dfc233bf299bb23eceddd94593a62372fe4b. Remote recovery starts at 089bc6036ae5039bce3963d8b4e80ecaf04dfb49; drop recovery is completed by 914f47132b53e7eec2f5650ce2abc16d3700c3c8. Async applied Prolog registration and later pool joins are in e7266ad0d3d3b37ca2151f1666ef97228e83a5f3. Current-source acceptance, rather than these historical descriptions, determines each disposition.

### F03: structured registration identity

Tried: five names, with a point itself containing ` registration `, all failed the original identity check.

Decided: pass point and name directly through `_enlist`. `_record_seam_undo` already accepts that structure and renders descriptions only for diagnostics. No consumer change is needed.

Verified: `test_registration_identity.py`, 5 passed in 0.02 seconds; `ai-tmp/ai-audits-f03.log`.

### F01: deletion restores by insertion

Tried: removal and rollback at every position in registries of sizes 0, 1, 2 and 5. Every nonempty registry lost a row because replacement overwrote the successor or ignored the last position.

Decided: keep replacement's inverse and deletion's inverse distinct. `_reinsert` uses the saved row object and position; `_restore` remains the replacement inverse. No list snapshot can erase another registration as a side effect of restoring one.

Verified: the identity and deletion acceptance files report 9 passed in 0.02 seconds; `ai-tmp/ai-audits-f01.log`. The F03 chapter run passed; later chapter receipts accompany each mutation repair.

### F02: all inverse actions remain observable

Tried: no failure, first failure, second failure and both failures, using ValueError and KeyboardInterrupt. A failure in the first action skipped the table inverse on the cut.

Decided: attempt both actions in their existing order. Reraise one failure unchanged and group simultaneous failures with BaseExceptionGroup, preserving control exceptions. The F01 chapter reports 285 passed and 2 skipped in 14.46 seconds.

Verified: `test_inverse_failures.py`, 4 passed in 0.05 seconds; `ai-tmp/ai-audits-f02.log`.

### F15: lossless sequence indices

Tried: six positional cases and custom indices in every slice position against the unchanged result implementation; all seven failed. Float and int-only objects remain refusal controls.

Decided: normalize indices with `operator.index`, including slice bounds before lazy range comparisons. Column strings and Variable projections keep their existing dispatch. A bounded slice still stops before the next source item. The F02 chapter reports 289 passed and 2 skipped in 28.41 seconds.

Verified: `test_answers_index_protocol.py`, 7 passed in 0.65 seconds; `ai-tmp/ai-audits-f15.log`.

### F07: validate ownership before collecting entry points

Tried: both permutations of competing distributions silently selected the last target on the unchanged cut. F15's chapter reports 487 passed in 52.43 seconds.

Decided: compare normalized distribution name, version, group, entry name and target before collecting a name-keyed mapping. Repeated metadata from one distribution deduplicates; competing origins refuse in sorted diagnostic order. No provider runs until the complete advertisement passes validation. The existing once-per-group/name loading and wait-cycle protocol remains valid because each validated group has one owner per name. Installed metadata changes require a new discovery lifecycle, as before.

Rejected: enumeration precedence and Distribution object equality. Neither identifies the declared provider. Python 3.12 importlib.metadata documents that Distribution instances do not provide value equality.

Verified: the focused seam/discovery battery reports 85 passed and two generated-reference failures in 230.55 seconds, `ai-tmp/ai-audits-f07.log`. Both failures report `reference: 3 stale projections: website/reference/metta-results.md, website/reference/metta-seam.md, website/reference/metta.md`. The reference generator refreshes the advertised contract and the two F15 index-signature projections omitted from that commit. No behavioral acceptance failed.

Verified: `sh check.sh reference` exits 0 after regeneration; `ai-tmp/ai-audits-f07-reference.log`.

### F05: immutable registry records

Tried: a caller could mutate the registered field mapping without changing the row identity observed by the cached door snapshot. Mutating the original input mapping was already harmless because Row copied it.

Decided: a frozen slotted dataclass retains Row's identity equality and owns a MappingProxyType over that copy. Registration metadata is immutable; the seam does not acquire or freeze field payloads. Replacement remains the sole way to publish a changed registration. This matches the immutable Door tuple already required by doors.validate_registration and removes the stale-snapshot path without a generation counter.

Integration: F17 remains live at _catalog/kinds.py:install. Replace the first-row sentinel with complete publication state and transactional retry of the whole owned ontology. That unassigned file and binding predicates are held for integration. Every interrupted-prefix witness is retained in the baseline bundle, with 40 failures and a passing empty-prefix control. F10's storage inventory belongs to unassigned _atoms/fields.py; enumerate MRO storage, normalize a string __slots__ to one slot, omit bookkeeping, and use static descriptor inspection.

Verified: immutable mapping/metadata plus retained-namespace replacement and nested immutability checks report 11 passed in 1.14 seconds; `ai-tmp/ai-audits-f05.log`. F07's chapter reports 294 passed and 2 skipped in 9.75 seconds.

### F11: construct rows through the accepted inputs

Tried: five expanded witnesses all fail the original row-conversion implementation. Defaults are treated as required columns, computed storage is treated as input, InitVar is omitted, registered ordinary classes are refused, and optional mapping keys are required. `ai-tmp/ai-audits-f11-expanded-baseline.log` reports 5 failed in 0.66 seconds. Only unrelated registration and indexing repairs precede that run; constructor functions still match the cut.

Decided: inspect.Signature identifies named constructor inputs and their defaults. BoundArguments.apply_defaults preserves positional-only holes and keyword-only delivery. Dataclass factory sentinels remain the generated initializer's inputs, so each construction gets its own factory value. TypedDict keeps its declared key set and required-key metadata; absent optional keys never become default values. Existing complete-constructor expression conversion retains priority.

Rejected: selecting dataclasses.fields, which describes stored state, and calling every constructor with keyword arguments. The accepted-parameter model removes both mismatches. F09 must make the same binding change in held _declare/constructors.py and related classes consumers; its inherited-default, keyword-only and positional-only witnesses remain integration obligations.

Verified: F05's chapter reports 295 passed and 2 skipped in 10.26 seconds.

Verified: the five constructor witnesses and both existing result-door projection cases report 7 passed in 3.15 seconds; `ai-tmp/ai-audits-f11.log`. Duplication checking over seam.py and results.py reports 27 clones and 7.2 percent, all in existing result-door declarations or forwarded result methods; none intersects the constructor conversion. `ai-tmp/ai-audits-duplication-rows.log` uses `jscpd --reporters ai --format python --max-lines 10000 --max-size 1mb --no-gitignore --noTips`. The initial default-max-lines invocation scanned neither large file and supplied no useful measurement.

### F04: publication owns its inverse and observer compensations

Tried: insertion, replacement and removal each fail at every listener position; additional witnesses cover observer reconciliation, inverse failures and compensation order. The first expanded fixture incorrectly combined a validator and external adder; point() already refuses that combination with `ValueError: a validated point owns its rows in the seam registry`. It is retained as an unchanged passing control. The corrected baseline log is `ai-tmp/ai-audits-f04-corrected-baseline.log`.

Decided: mutation, publication and inverse execution share the reentrant seam lock. Each inverse owns ordered actions, consumes successes and retains failed actions for retry. External and local preimages restore before completed observers compensate in reverse order. A stateful observer returns its compensation; a None observer rereads the restored registry. A failing observer must undo its own partial work before raising. Catching an arbitrary callback failure cannot manufacture that callback's missing preimage.

Rejected: a one-shot undo flag with the existing transaction consumer. A caught publication failure would consume the first receipt while its coalescing key suppresses a later valid registration's inverse. The held _declare/operations.py:_record_seam_undo must record every supplied inverse and return compensation removing the exact journal record from its captured frames. The executable proposed replacement and both consumer controls are in the main-checkout handoff. This consumer remains an integration obligation; the seam must not reach into a higher layer's ContextVar to repair it.

Handover: integrate.py:_add_type discards replacement preimages by returning unregister_type alone. Doors accepted its repair and the corresponding repr/reflector adder checks. The seam relies on each adder's returned inverse to restore the state that adder owns.

Verified: F11's chapter reports 492 passed in 11.79 seconds; reference and reference-selftest pass. Further gates unset DISPLAY and WAYLAND_DISPLAY after the integrator isolated the unchanged-cut SWI/GLX artifact; no source workaround is added here.

Verified: corrected F04 baseline, 12 failed and 1 passed in 0.14 seconds. Publication plus the existing identity/deletion/inverse witnesses now report 26 passed in 0.04 seconds, `ai-tmp/ai-audits-f04.log`. The held-consumer control reports 1 failed and 1 passed in 0.22 seconds: the current callback leaves `Row(audit-caught-retry held: value)` after outer rollback, while the proposed compensating callback restores the empty registry. `ai-tmp/ai-audits-f04-held-consumer.log` is an explicit integration red, not a passing branch gate.

Verified: expanding the consumer control to nested frames reports 2 failed and 2 passed in 0.24 seconds, with the same current/proposed split; `ai-tmp/ai-audits-f04-held-consumer-nested.log`. The exact replacement is supplied to the integrator for coordination with the classes work.

Decision superseding the held-consumer obligation above: ownership now includes only _declare/operations.py:_record_seam_undo, after the classes branch diff established that function is untouched there. The seam and consumer repair land together. Each seam inverse is recorded without the (point, name) coalescing key; compensation removes that exact _RegistryUndo record from its captured frames; None is returned only when no frame exists. This function remains a known classes-merge site carrying that contract.

Tried: the seam-only state passes its chapter with 308 passed and 2 skipped in 9.77 seconds, plus reference and reference-selftest, but the explicit consumer controls remain red. Those greens do not close F04; the functional commit is replaced with the complete consumer repair and retained ordinary/nested retry tests.

Verified: the complete seam/consumer repair reports 34 passed in 0.16 seconds, including all four current/proposed handoff controls and retained ordinary/nested tests of repeated replacement, removal and reinsertion. `ai-tmp/ai-audits-f04-complete.log`. The operations.py diff is confined to _record_seam_undo.

Verified: the complete F04 chapter reports 312 passed and 2 skipped in 9.91 seconds. Reference and reference-selftest pass; `ai-tmp/ai-audits-f04-complete-chapter.log` and `ai-tmp/ai-audits-f04-complete-reference.log`.

### F08: one exit-error policy

Tried: zero, body-only, cleanup-only and simultaneous failures across Answers, the engine stream, RemoteCursor, Gateway, Server and asynchronous EvaluationView. The expanded baseline reports 13 failed and 20 passed in 0.37 seconds; ten failures belong to these owned views, two to assumption cleanup and one to the asynchronous assumption wrapper. `ai-tmp/ai-audits-f08-expanded-baseline.log`.

Decided: one aggregation operation accepts the body and cleanup outcomes. Successful cleanup leaves the body to normal context propagation. A lone cleanup failure is raised unchanged; simultaneous failures form a BaseExceptionGroup with the body first. Native and asynchronous exits keep their existing close, cancellation, shielding and retry mechanisms. The engine stream already follows this policy and is a passing control.

Handover: _spaces/scope.py:_Assuming.__exit__ attempts all removals but omits the body from its cleanup group. Its two exact failing fixtures are in the main-checkout handoff. The unassigned aio/_views.py:_AsyncAssuming.__aexit__ forwards (None, None, None), so integration must forward the real exception triple. _AsyncBatch already forwards it. The classes-held stream requires no behavioral repair.

Verified: focused exit, asynchronous worker and remote ownership tests report 154 passed in 22.59 seconds. With a source-close retry control added, the three affected chapters report 1256 passed and 85 skipped in 39.81 seconds; `ai-tmp/ai-audits-f08.log` and `ai-tmp/ai-audits-f08-chapters.log`. Reference and reference-selftest pass after regenerating the remote/results/root pages. Ruff first reported I001 and TRY301 in the new fixture; one misplaced exemption then reported RUF100. Corrected imports and exact test-body exemptions pass; `ai-tmp/ai-audits-f08-ruff-passed.log`.

### F14: retain the paired record

Tried: replay and slicing must preserve the original _AnswerItem, and early close must preserve both cached faces without resuming the source. The expanded baseline reports 2 failed in 0.90 seconds, both on reconstructed record identity; `ai-tmp/ai-audits-f14-expanded-baseline.log`. The original audit reported redundant representation, not an observed misalignment bug.

Decided: the existing immutable _AnswerItem becomes the cache element. Every public face projects its value or row. A locked non-pulling accessor supplies the asynchronous consumer, including the same cached-prefix and error-frontier behavior.

Verified: the five paired-record controls pass in 1.07 seconds, including reverse and negative-bound slices and a None-valued record. The spaces and concurrency chapters report 742 passed in 27.56 seconds; `ai-tmp/ai-audits-f14.log` and `ai-tmp/ai-audits-f14-chapters.log`. No production consumer reads `_row_cache`; asynchronous replay uses `_cached_item` instead of reading cache or error fields.

Verified: reference and reference-selftest pass after regenerating the constructor signatures. Mypy reports three diagnostics in earlier owned repairs: seam._enlist's reconciler return type, _into_fields' TypedDict metadata access and Answers.__getitem__'s Variable/SupportsIndex overload order. The record migration adds none; these remain in the T3 annotation repair. Exact diagnostics are in `ai-tmp/ai-audits-f14-reference-mypy.log`.

### F12: one transaction owns every input representation

Tried: late read, conversion, write and close failures across iterable rows, declared frames, Arrow batches and column mappings. The corrected unchanged-implementation fixture reports 62 failed and 1 passed in 4.46 seconds; `ai-tmp/ai-audits-f12-corrected-baseline.log`. An earlier success control incorrectly required global native atom order; comparing occurrence counters corrects that control without changing the implementation under test.

Decided: one ingestion callback runs inside the existing store transaction. It verifies and enlists a transactional foreign provider before acquiring input, then owns every acquired outer iterator by identity through read, conversion, write and close. Arrow batches retain their boundaries; other representations use the existing chunk capacity. Every close is attempted, and the shared exit-error policy retains the body and all release failures. An empty first mapping record fixes a zero-column schema instead of acting as an unset sentinel.

Decided: the core admits structural Arrow streams, column mappings and row iterables. Each frame provider declares its native extraction on seam.frame. The provider claims only its already imported DataFrame type; an empty iterator still claims the source. No vendor method spelling remains in the core.

Rejected: a nested foreign load that silently leaves a prefix after its failure is caught. The classes branch at d362153bae6333602f3877f79f2f811848d86f6e changes transaction value handling but still shares outer foreign enlistments in metta_nested_transaction_prepare and only finishes observations in the nested finish path. Its lifecycle changes do not supply provider savepoints. The provisional capability refusal occurs before input acquisition. Remove that refusal by implementing the nested provider protocol and declaring savepoint, not by bypassing the check.

Integration: the catalog reserves savepoint as a provider capable of rolling a nested transaction back to its entry point. The engine must enlist a provider savepoint in metta_nested_transaction_prepare, roll it back on nested failure and release or merge it on success; providers must implement that protocol before advertising the word. The refusal test then becomes a successful nested rollback test. The catalog vocabulary row is disjoint from the classes branch's Literal refinement addition; regenerate the Python and Node vocabulary artifacts with both rows after integration. No refusal kind or error class is added.

Measured: seven alternating runs of 10,000 two-column rows, including the ingestion transaction and excluding frame construction, give median native/Arrow times of 55.4805/73.3269 ms for polars 1.43.2 and 66.0629/82.2867 ms for pandas 3.0.5. Every run validates the written count and stored occurrence count. `ai-tmp/ai-audits-frame-benchmark.py` and `ai-tmp/ai-audits-f12-frame-benchmark-verified.log` retain the fixture and all samples. The previous header's September 6 measurements were 14.07/14.36 ms and 20.39/25.11 ms respectively; that older fixture did not exercise this single-transaction contract, so these are path comparisons, not a cross-fixture speedup claim.

Tried: initial vocabulary generation loaded 19 stale local QLF artifacts and returned no source changes. Removing those generated artifacts and rerunning vocabgen produced both vocabulary projections. The initial benchmark omitted the optional Arrow provider and raised the exact no-arrow-registration ImportError retained in `ai-tmp/ai-audits-f12-frame-benchmark.log`; explicitly loading the installed provider made the measured run pass.

Verified: 63 new controls plus both providers' tests report 77 passed in 6.78 seconds. The complete dataset chapter and both provider suites report 124 passed in 10.38 seconds. Ruff passes for every F12 Python source and test. All 14 selected lanes pass, including no-hardcoded-integration and its selftest, extension-scaffold, closed-sets and its selftest, vocab-sync and its selftest, refusals and its selftest, refusal-grounds and its selftest, door-refusals, reference and its selftest; `ai-tmp/ai-audits-f12-gates.log`.

### R2/R4/R5 and MDL H.1: the store owns the atom domain

Tried: Symbol and Grounded removal fail against the local store through both Gateway and HTTP. Empty and compound expressions pass. The eight controls are in `ai-tmp/ai-audits-baseline-extra-corrected.log`; the same run separately records lifecycle and ingestion findings.

Decided: decode the wire atom and delegate removal to the store. The gateway's leaf refusal duplicates a false storage model. Duplicate occurrence, absent atom and malformed-wire controls stay on both transports. R2/R4/R5's existing mutation uncertainty, schema validation and cursor release laws remain independent protocol owners.

Source: `git diff c75181adc..feat/classes-on-metta -- extensions/python/metta/remote` is empty at d362153bae6333602f3877f79f2f811848d86f6e. No classes repair duplicates this change.

Verified: all 133 removal, remote lifecycle, mutation recovery and response-schema cases pass in 22.63 seconds; `ai-tmp/ai-audits-h1-verified.log`. The malformed HTTP mutation correctly preserves the wire refusal inside the OutcomeUnknown cause chain. Two over-specific fixture assertions expected the outer message, then its immediate cause, to be the wire refusal; the retained test follows the complete cause chain. Ruff reports three pre-existing BLE001 sites in the worker/HTTP error boundaries; their explicit boundary annotations belong to the T3 pass.

Found: the broader provider chapter reported 4 fixture failures, 523 passed, 85 skipped and 8 compliance teardown errors in 35.67 seconds. The teardown errors name the newly reserved savepoint capability with no suite case. Ownership now includes testing/_providers.py to add the nested rollback law and false-declaration control; `ai-tmp/ai-audits-h1-chapter.log` retains that F12 consumer failure.

### F12: the reserved capability carries its compliance law

Decided: SpaceComplianceSuite.test_a_nested_transaction_restores_its_provider_savepoint uses the existing requires gate. An undeclared capability receives an explicit skip. A declaring provider must restore the occurrence bag at nested entry after a caught failure, retain an earlier outer removal, accept the restoring outer write and commit the outer return value. The fixture uses an existing restorable atom, so it imposes no new schema on the provider.

Verified: a provider advertising savepoint but implementing only begin/commit/rollback fails the nested law; the resulting outer rollback restores its original bag. The same law passes through the native engine's nested transactions. No foreign provider support is claimed by that positive control. The compliance and occurrence-token suites report 103 passed and 77 skipped in 4.45 seconds; `ai-tmp/ai-audits-f12-compliance.log`. The complete provider chapter reports 529 passed and 93 skipped in 31.70 seconds; `ai-tmp/ai-audits-f12-compliance-chapter.log`. Ruff, reference, reference-selftest and closed-sets pass.

Integration: this compliance law is the support test for the future nested provider savepoint protocol. The table-specific refusal control must also switch to successful nested rollback once the engine hook and a declaring provider implement it. A false declaration remains a failing law rather than a coverage waiver.

### A3: broad sequence equality has no common hash

Tried: equivalent string, bytes and range peers have different hashes from Answers on the unchanged cut; the tuple control passes. These are the three A3 failures in `ai-tmp/ai-audits-baseline-owned.log`.

Decided: retain the existing broad sequence equality and remove Answers.__hash__. Python's equality override makes the class unhashable. Hashing cannot choose among the incompatible hash contracts of all its equal peers, and restricting equality would remove the established list and sequence comparisons. Python's data model states the equal-object hash requirement: https://docs.python.org/3/reference/datamodel.html#object.__hash__.

Source: results.py remains unchanged on the classes branch at d362153bae6333602f3877f79f2f811848d86f6e. The repair is confined to the reserved hash symbol and its direct tests.

Verified: all 95 answer-protocol and new equality/hash cases pass in 4.85 seconds; `ai-tmp/ai-audits-a3.log`. Tests retain string, bytes, range, tuple and list equality in both directions and prove hash refusal never pulls the source. Ruff passes. The first reference check reports two stale projections; after regeneration reference and reference-selftest pass in `ai-tmp/ai-audits-a3-reference-verified.log`.

### A8: the suggested absence expression runs

Tried: Rows.one recommends first() for an empty result, but first() itself requires an explicit default. The A8 unchanged-cut witness fails in `ai-tmp/ai-audits-baseline-owned.log`.

Decided: recommend first(default=None), retaining the cardinality behavior of both methods. The same expression works for zero rows and several rows. The one() docstring now states that its own default applies only to absence. The classes branch does not change results.py.

Verified: the complete spaces and matching chapter reports 542 passed in 12.38 seconds, including both absence-remedy cardinalities and the A3 hash controls; `ai-tmp/ai-audits-a8-chapter.log`. Ruff, reference and reference-selftest pass after regenerating the results and root pages.

### HTTP context resolution found during T3

Tried: GET health and POST atoms with both a context and its home space. The context cases fail with `AttributeError: MeTTa has no 'name': it is a Space door, and a context is not its space`; both space controls pass. `ai-tmp/ai-audits-http-context-baseline.log` reports 2 failed and 2 passed in 4.84 seconds. The classes branch at b62a0d5e49cfd54c7685eabe1a3f01ce31de036e does not change remote/.

Decided: both authorization paths use Gateway's already resolved home. Re-resolving the original receiver at each request would duplicate the construction boundary. The retained test checks the authorizer's exact operation and space, as well as each successful reply.

Verified: all 87 context and existing HTTP controls pass in 22.21 seconds; `ai-tmp/ai-audits-http-context.log`.
