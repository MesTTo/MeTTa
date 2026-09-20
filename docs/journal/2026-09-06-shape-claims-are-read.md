# Shape claims are read
Goal: declared tensor shapes, observed shapes, and inferred shapes use one type expression.
Constraint: preserve the existing `(Annotated DLTensor (Shape (...)))` vocabulary and ordinary argument checking.

## 2026-09-06
Tried: `PYTHONPATH=extensions/python "$CHECK_PY" ai-tmp/ai-shape-repro.py` on 749f5864a9cd84863fb177e0c1e985b14ab3772e -> user arrow `(-> DLTensor DLTensor)`, result `DLTensor`, live value types `ndarray` and `DLTensor`, and a `(4 1)` argument executed despite a `(2 3)` claim. All seven unary-capable preserving heads answered bare `DLTensor`.
Tried: `sh extensions/python/test.sh -n 0 tests/ch08_data/test_arrays.py -k 'declared_shape or live_tensor_type or preserving_unary'` -> ten failures on the shipped implementation.
Decided: preserve MeTTa atom metadata in Python annotation projection. Ordinary Python metadata remains a catalog claim. The engine already structurally unifies the canonical shaped arrow and shares its variables across inputs and output; the broken projection had denied it those terms.
Rejected: refining the arrow by joining separately stored catalog rows. Separate rows freshen their variables separately, while one arrow already preserves binder identity and lexical declaration ownership.
Decided: extend the grounded-object type projection to accept structural type atoms as well as names. Array protocol registration reports the current shape, retaining the ordinary DLTensor protocol answer.
Decided: one complete operation roster chooses shape behavior. Preserving operations publish a shared whole-shape variable in their input and result arrow. Broadcasting and rank-two matmul retain their existing relational inference. Constructors, transformations, reductions, and observations explicitly name their behavior in the roster and expose their actual result shape through the grounded value projection.
Rejected: interpreting the old binary `Shape($left_shape)` catalog roles as constraints. That spelling declares rank one, and its independent output variable does not express broadcasting. Binary arrows remain scalar-capable and the broadcast relation supplies the shape fact. Rank-two inference must also not restrict the backend's vector and batched matmul execution.
Research: the Array API 2024.12 exp specification defines elementwise output; jaxtyping's array annotation documentation matches named dimensions across arguments and binds result dimensions from those names. The transferable mechanism is shared variables, which the engine already implements. Sources: https://data-apis.org/array-api/2024.12/API_specification/generated/array_api.exp.html and https://docs.kidger.site/jaxtyping/api/array/.
Tried: first integrated array suite -> ten failures. A policy-strict witness required `ground(T)`, so a valid shape-variable arrow failed when a typing rule existed. Static checking also treated a constructor's bare DLTensor arrow as a contradiction of a required refinement before obtaining its live value.
Decided: preserve relational variables under strict policy and defer an unresolved base-to-refinement comparison until its evaluated value is available. A known incompatible shape remains a refusal, and an explicit typing-rule refusal remains authoritative.
Tried: duplication scan of arrays.py and its regression suite -> zero clones, 0.0% duplication. No extraction was indicated.
Tried: requested check lanes -> the optional MORK rebuild reported a missing sibling `MORK/kernel/Cargo.toml` in this isolated worktree layout. The supplied shared libraries were already provisioned; lane receipts below distinguish this build message from the requested checks.

Tried: isolate the policy-strict witness change -> all nine preserving and nested-activation checks passed. The apparent static refusal above was the runtime failure reporting the written constructor's base type. No static-checker production change is needed; the earlier inference that it was a separate static defect is superseded by this probe.
Tried: full Python suite -> 3,512 passed, 48 skipped, five failures. The nested-constructor diagnostic lacked its observed shape; reference generation used the older generator; an added lint suppression exceeded the existing TRY ledger; the release journal contained a pre-existing absolute workspace path; and the snippet gate test exceeded its existing 30-second wait.
Decided: regenerate with `extensions/python/tools/reference.py --write`, move callback-result validation outside its exception wrapper without suppressing lint, and respell the user-authored release journal citation as `../repin`. The citation's historical measurement is unchanged.
Tried: final regression collection against isolated 749f5864 -> 12 Python shape failures; engine shape suite -> nine failures and one passing policy-refusal control. The base lacks the new roster, so only test parameter collection uses its frozen final entries; implementation files are unchanged.
Tried: vector-vector matmul against both 749f5864 and this implementation -> no answer, because the NumPy backend returns numpy.float64 while the existing arrow requires DLTensor. Vector-matrix, matrix-vector, and batched matmul all pass. The scalar-return mismatch predates this work and remains outside the shape-claim repair.

Tried: property-based agreement between live output shape and inferred shape across ranks zero through four -> scalar `t-exp` returned no answer. NumPy exp returns a NumPy scalar for a zero-dimensional ndarray, which does not satisfy the DLTensor result arrow.
Decided: the preserving-rule registration boundary retains array results and converts a scalar backend result through the input array namespace. The output remains an array of the promised rank without copying existing array results. This boundary applies to every preserving head in the roster.

Tried: final table-parameterized scalar, empty-axis, and matrix checks plus the rank property -> 67 array tests passed. The final tests against unchanged 749f5864 implementation -> 29 Python failures and 13 engine failures, with one passing policy-refusal control.
Tried: every preserving head on rank-zero arrays -> six NumPy functions returned scalar values before normalization; all eight return the declared array shape afterward. Empty reduction-axis softmax still raises the backend `ValueError: zero-size array to reduction operation maximum which has no identity`, reproduced unchanged on 749f5864.

Decided: refined input checks precede callbacks and retain evaluated failure evidence in a cell owned by one call. Shared argument/result variables remain related; a successful overload suppresses earlier failure evidence, and a result mismatch does not become a fabricated argument refusal. A nested constructor executes once even when its result fails the input claim.
Tried: full Python suite after these changes -> 3,516 passed, 48 skipped, one inference-budget failure: identity twin 3,455 exceeded its existing 3,422 pin plus 20 allowance.
Rejected: changing the inference budget. A separate scan rediscovered refined parameters already traversed by arrow decomposition. Fusing those traversals and omitting evidence when checks are statically discharged lowered the measured twin count to 3,442, within the unchanged allowance. The fixture is `examples/ch05-equations-and-evaluation/05-01-an-equation-is-a-rewrite/01-identity.metta`; the exact focused regression receipt is retained below.

Tried: full Python gate after the compiler optimization -> 3,534 passed, 48 skipped, five third-party deprecation/benchmark warnings; exit 0.
Tried: independent masked-operand overload probe -> the optimized compiler fabricated two `BadArgType` errors after a DontEvalType branch accepted its held operand but failed its result. Reloading the pre-optimization compiler in the isolated probe produced the correct empty answer.
Rejected: treating an empty runtime argument-check list as permission to omit acceptance evidence from a refined branch. DontEvalType deliberately accepts a held operand without a runtime check; that acceptance must still suppress later argument failures. The traversal fusion remains independently valid.

Tried: the added held-operand regression -> 14 shape tests passed and the new case failed before the correction; all 15 passed after removing the empty-check exemption. Five surrounding engine suites also passed. The min-of-three identity measurement remains 2,356 engine and 3,442 twin inferences.
Decided: retain the single traversal for parameter/result decomposition and refinement detection. Every refined branch records acceptance, including held operands with no runtime checks.

Tried: all 15 final shape cases against unchanged 749f5864 -> 14 failures and one passing policy-refusal control. The held-operand failure also exists in that base; the repaired pre-optimization implementation had already removed it before the rejected exemption reintroduced it.
Tried: final full Python gate with the held-operand correction -> 3,534 passed, 48 skipped, five third-party warnings, exit 0 in 118.86 seconds.

Tried: final `sh engine/test.sh` -> exit 0, 2,188 tests and 1,438 sub-tests across 77 suite receipts, with no ERROR lines. The count includes the single-test receipt spelled `% test passed`.

Tried: `sh tools/check.sh llms llms-selftest layering kernel-ledger policy-inventory` -> exit 0; all five requested lanes passed. The final receipt has no build errors; the earlier optional rebuild failure is recorded above.
Tried: `"$CHECK_PY" extensions/python/tools/twin_coverage.py --measure --rounds 3 examples/ch05-equations-and-evaluation/05-01-an-equation-is-a-rewrite/01-identity.metta` after the held-operand correction -> exit 0, engine 2,356, twin 3,442, ratio 1.4610. The final full Python gate also includes both end-to-end twin checks.
Tried: changed-Python Ruff checks, reference generator `--check`, and `git diff --check` -> exit 0. `jscpd --noTips --silent --max-lines 10000 --max-size 2mb extensions/python/metta/arrays.py extensions/python/tests/ch08_data/test_arrays.py` -> zero clones across both files; the raised line limit includes the full array module.

## 2026-09-06: integration with evaluation context

Tried: replay the functional change onto `14e70c7a20fbaf74c380fee68af117f6f482dc53` -> content conflicts in the changelog, release journal and Python shim. The old provenance-only commit is omitted so its shape pins can be rebuilt after verification.
Decided: keep both changelog additions under the existing Unreleased Fixed section. Both release-journal edits replace the same absolute path with `../repin`; retain the trunk wording that explicitly attributes the length comparison to the absolute path, leaving every measurement and narrative section intact.
Decided: keep both shim guarantees. Trunk's `metta_py_in_evaluation_context/4`, held cursor context scopes and ordered provider limit remain unchanged. Shape projection uses `metta_py_decode_shared/3` at `seam:grounded_type_names/2`, which neither installs nor replaces evaluation context. The two changes compose at different boundaries: context governs execution, while protocol projection supplies ordinary type atoms.
Rejected: choosing either shim wholesale, because that would drop either evaluator context propagation or structured shape projection.

Tried: focused arrays, refined protocols and evaluation-context suites -> 104 passed in 3.74 seconds. The complete shape reproduction log is byte-identical before and after the rebase. Both trunk journals are byte-identical to `14e70c7a`.
Tried: full `sh extensions/python/test.sh` on the rebased implementation -> exit 0, 3,581 passed, 48 skipped and five third-party warnings in 117.11 seconds. All 76 inherited full evidence commit references in changed files resolve and are ancestors of the rebased implementation.

Tried: independent composed-source review and `ai-tmp/ai-shape-context-composition-probe.py` in the selected Python environment -> no integration defect. A tagged guard over a scoped `(2 3)` array runs once under ranked algebra, limit two and descending order. A `(4 1)` array produces no guard answer and never enters the body. Both outcomes hold with inference accounting disabled and with a 1,000,000-inference allowance; the outer algebra restores to None. The probe unregisters its operation between fixtures.
Tried: full `sh engine/test.sh` after the rebase -> exit 0, 2,194 tests and 1,438 sub-tests across 77 suite receipts; no ERROR lines.

Tried: `sh engine/test.sh suites/typecheck/tensor_shapes.plt` -> all 15 passed. `sh tools/check.sh llms llms-selftest layering kernel-ledger policy-inventory` -> exit 0, all five requested lanes passed. Reference generator `--check` and diff whitespace checks also pass.
Decided: amend the replayed functional commit with these integration receipts, then replace only its 17 WORKTREE evidence pins in a fresh provenance-only commit. All inherited evidence snapshots remain on the rebased ancestry.

## Unification
A declared claim and an inferred fact are the same type expression. Python
annotation projection, grounded-value projection, and array inference all
supply ordinary MeTTa atoms; the engine shares their dimension variables
through the same arrow relation. The metadata catalog retains written host
annotation syntax for inspection and does not become a second type authority.

Sibling claims inspected but not fixed in this thread:

- `extensions/python/metta/_type_annotations.py:140` publishes Literal members;
  `_literal_type_atoms` at line 316 projects their base types. Executed probe:
  `Literal['on', 'off']` accepts `"other"`. Membership remains unread at calls.
- `extensions/python/metta/_type_annotations.py:118` publishes constrained
  TypeVar alternatives; `_typevar_constraints` at line 325 expands each slot
  separately. Executed probe: a repeated constrained `T` permits a Number and
  a String in the same call. Cross-slot equality remains unread there.
- `extensions/python/metta/_type_annotations.py:142` publishes TypeIs and
  TypeGuard targets, but line 265 projects only Bool. This is source-confirmed
  erasure; no runtime reproduction was run for that family.
- `extensions/python/metta/_type_annotations.py:144` publishes `type[T]`'s
  target, but line 273 projects only Type. This is source-confirmed erasure;
  no runtime reproduction was run for that family.
- `extensions/python/metta/_type_annotations.py:109` publishes opaque Python
  Annotated metadata; the projection at line 277 retains only metadata already
  expressed as MeTTa atoms. Python strings and objects remain catalog-only by
  design, including the existing metres/feet test. PEP 593's consuming
  annotations section permits consumers to select the metadata they understand:
  https://peps.python.org/pep-0593/#consuming-annotations.
