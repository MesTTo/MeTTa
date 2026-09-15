# Door bodies compose the primitive doors

Goal: each owned body composes the primitive that owns its engine crossing, and source-declared dependencies retain their identity through door analysis.
Constraint: preserve public answers and exact inference costs; classes files, binding Prolog, engine code and door generators belong to integration. Keep open callbacks, mixed crossings and cycles visible.

## 2026-09-15

Tried: `extensions/python/tools/doororder.py --json` at `efac42a31055f59a2ff0580f1ff138072c946fab` after deleting generated `.qlf` files. Result: exit 1; 227 doors, 94 mixed, 167 open, 77 recursive; 42 numbered, comprising 22 at order 0, 16 at 1 and 4 at 2. Evidence: `ai-tmp/ai-doors-order-0.json`.

Decided: inspect shared sites before callers, in this order: `seam.Point._expect` (62 cited doors), `_atoms/wire.py` (72), `_binding/json.py` (65), `_declare/declarations.py` (62), `_atoms/registry.py` (58), `_atoms/namespace.py` (57), `_atoms/templates.py` (55). `_DISPATCH` already declares string values; analysis must read that declaration before a body rewrite is justified.

Decided: then process door families in `_spaces/lifetime.py` (101), `_spaces/store.py` (96), `_spaces/profile.py` (56), `_spaces/query.py` (55), `_observe/diagnostics.py` (56), `_spaces/results.py` (42, shared), `_spaces/scope.py` (27), `_spaces/execution.py` (24), `_spaces/context.py` (12), `_spaces/cursor.py` (11), `_spaces/intents.py` (9), `_atoms/calls.py` (13). The numbers count doors citing each module, not independent defects.

Decided: finish the owned remainder: `_declare/prolog.py`, `events.py`, `foreign/_persistent.py`, `_catalog/arrow.py`, `subscribe.py`, `structures.py`, `_observe/debug.py`, `_observe/trace.py`, `_history/world.py`, `_atoms/library.py`, `library/_lock.py`, `_catalog/meaning.py`, `_catalog/documentation.py`, `_catalog/cast.py`, `integrate.py`, `_compile/facts.py`, `_catalog/declarations.py`, `derivation.py`, `_history/saga.py`, `spaces.py`, `live.py`. Record other-member findings as handovers. Review canonical names, guard budgets/truth, cursor refill and documentation extraction when reaching their owning families.

Open: known excluded dependencies include `_binding/runtime.py:runtime`, `_atoms/model.py:Expression.to_wire`, `_atoms/model.py:explicit_metta_atom`, `_atoms/mentions.py:callable_mention`, `_spaces/handle.py:SpaceHandle.__init__`, `_spaces/evaluate.py`, `_spaces/source.py`, `_catalog/annotations.py`, `_catalog/project.py`, `_declare/define.py`, `_atoms/factories.py`. Their precise body changes belong in the integration table after tracing the final residual graph.

### Source-declared containers

Tried: the unchanged analyser passes all 18 existing door-order tests. Added declaration witnesses expose a native callback and a recursive callback both incorrectly numbered 0, qualifiers treated as receiver classes, dropped list callbacks and tuple destructuring that binds the tuple instead of its fields. First witness run: 11 failed, 20 passed; two failures were a malformed expected set in the new test, corrected before using that assertion as evidence. Logs: `ai-tmp/ai-doors-order-tests-before.log`, `ai-tmp/ai-doors-declarations-witness-before.log`.

Decided: preserve container allocations and their contents in finite source-site slots, including writes through aliases. Tuple positions preserve declared receiver identity; mutable sequences and mappings conservatively join their possible elements. Unimplemented container operations remain open. Qualifiers describe a binding and cannot erase its concrete initializer. The transfer follows [PyCG's source allocation and content pointers](https://github.com/vitsalis/PyCG/blob/8d5dc40837803beef1d8d379fbf2cdad6cd94641/pycg/processing/postprocessor.py); [Python's qualifier contract](https://docs.python.org/3.14/library/typing.html#typing.Final) supplies no runtime receiver.

Rejected: treating every mapping lookup as host work, because a planted table value can invoke a native operation or recurse. Revisit only with a proof that the looked-up value is never called. No seam body change is needed for its existing string table.

Tried: 42 declaration witnesses pass, including literal keys, alias writes and builtin container copies. The first projection battery caught synthetic AST nodes lacking source locations; allocation sites now handle those nodes. Mypy from the seat root passes after annotating the call-result set. The second projection battery passes every requested lane and companion selftest. Its Griffe traversal printed `Timeout (0:03:00)!` as a diagnostic dump, then completed all 69 door-sync selftests successfully. Logs: `ai-tmp/ai-doors-declarations-witness-final.log`, `ai-tmp/ai-doors-analysis-mypy-seat.log`, `ai-tmp/ai-doors-projections-2.log`.

Measured: 94/167/77 mixed/open/recursive before, 103/168/101 after; numbered doors change from 42 to 41 (22/15/4 at orders 0/1/2). `Point._expect` disappears from every open finding. The graph now sees callable values carried by builtin copies, including provider length callbacks and additional helper cycles; these findings remain visible. Evidence: `ai-tmp/ai-doors-order-0.json`, `ai-tmp/ai-doors-order-3.json`. No runtime door body changes in this commit; inference cost probes accompany the body repairs.

### Declared supplied contracts

Decided: refine the 2026-09-08 gate verdict by the public signature. A supplied `Callable`, `Iterator`, `Iterable` or caller-implemented `Protocol` can re-enter any door, so it remains unordered and its owning site stays in `open`. A door depending solely on such a door also stays unordered. Both pass the gate. A registry callback, undeclared attribute, unresolved receiver or dynamic import remains a defect. Native crossings combined with supplied calls remain mixed. The catalog keeps its independent open and dependency reasons; no integer or allowlist replaces these facts.

Tried: the four required planted controls retain a registry callback as a defect, retain a native-plus-callback body as mixed, accept a declared callback while keeping its number absent, and accept its dependent door while retaining `blocked_by`. The existing unresolved-callback and supplied-iterator witnesses remain unchanged. Initial run: 3 failed, 43 passed. The first implementation exposed non-serializable `ContractCall` records, repaired by explicit dataclass projection. Additional protocol controls exposed an undeclared iterable method being accepted and premature abstract receiver seeding; declarations now identify their operations after import resolution. A malformed quoted test annotation was corrected. Evidence: `ai-tmp/ai-doors-contract-witness-before.log`, `ai-tmp/ai-doors-contract-witness-after.log`, `ai-tmp/ai-doors-contract-protocol-before.log`.

Tried: all 55 planted and existing witnesses pass; configured-seat mypy passes for the two analyzer modules, and Ruff passes for all four changed Python files. An initial mypy command including the standalone tool reported `Cannot find implementation or library stub for module named "doorgen"`; the tool is checked by its actual CLI witnesses and Ruff. Evidence: `ai-tmp/ai-doors-contract-protocol-after.log`, `ai-tmp/ai-doors-contract-mypy-seat.log`.

Measured: legacy mixed/open/recursive counts stay 103/168/101. The refined report identifies 167 defect-open doors and one door unordered solely by contract. The numbered distribution remains 22/15/4. Evidence: `ai-tmp/ai-doors-order-contract.json`.

Tried: the final 55 witnesses and all thirteen required projection lanes with their companion selftests pass. `door-sync-selftest` completes all 69 checks in 718.58 seconds. Evidence: `ai-tmp/ai-doors-contract-final.log`, `ai-tmp/ai-doors-projections-contract.log`.

### Definite wire decoding

Tried: both public decoder paths raise `RecursionError: maximum recursion depth exceeded` for 5000 nested undefined wrappers; three ordinary/deep/malformed controls pass. Evidence: `ai-tmp/ai-doors-wire-before.log`.

Decided: the complete-answer decoder recognizes the one outer undefined wrapper, then delegates to the definite atom decoder. That lower decoder rejects an undefined wrapper immediately. Expression decoding and leaf validation keep their existing implementation, including the dominant symbol path.

Tried: all 411 tests in chapters 03 and 06 pass; Ruff passes both changed Python files. Evidence: `ai-tmp/ai-doors-wire-chapters.log`.

Measured: the representative wire call remains 7/7/7 inferences with the same expression and undefined answer. The other fixed probes remain 55/55/55 for JSON rendering, 104/104/104 for matching and 437/437/437 for evaluation. The wire decoder component disappears from every cycle finding. Legacy mixed/open/recursive counts stay 103/168/101 because affected doors retain other cycles. Evidence: `ai-tmp/ai-doors-costs-before.log`, `ai-tmp/ai-doors-costs-wire-after.log`, `ai-tmp/ai-doors-order-wire.json`.

Tried: the projection battery found one stale generated reference page, `website/reference/metta-convert.md`; its dependent door-sync and ledger selftests refused the same drift. Regenerated it through `doorgen.py --write`. All thirteen requested lanes and their companion selftests now pass, combining the unchanged passing lanes with the repaired door-sync, ledger and reference run. Evidence: `ai-tmp/ai-doors-projections-wire.log`, `ai-tmp/ai-doors-wire-regenerate.log`, `ai-tmp/ai-doors-projections-wire-repaired.log`.
