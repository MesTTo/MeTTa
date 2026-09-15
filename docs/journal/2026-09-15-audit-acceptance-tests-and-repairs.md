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
