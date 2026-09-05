# Immutable scalar calls during planning
Goal: move repeated computation of an immutable scalar into retained-clause planning while preserving each answer bag.
Constraint: planning cannot execute arbitrary host or recursive calls based only on their effect rank, and stored source remains the dependency authority.

## 2026-09-05
Tried: 32 warmed public evaluations of nested constant additions at depths 8, 32, 128 and 512 -> 12,263; 13,797; 19,941 and 44,519 inferences. Every answer was depth + 1. A declared immutable host operation was invoked once per call, not at definition load.

Tried: existing determinism and volatility declarations -> they state answer cardinality and immutable results, but no termination or opaque-result lifetime. They cannot prove that an unselected branch is safe to execute during planning.

Rejected: forcing arbitrary pureStructural calls, because a recursive or host call can diverge during compilation and a grounded result can retain a mutable resource. Revisit when an explicit finite reduction and immutable result contract covers those calls.

Decided: fold a closed native scalar fragment during tracked compilation. The current repeated cost is O(q*n); the target is O(n+q), where n is the fixed computation and q is the number of calls. Preserve the source dependency edges and every existing type/error guard. Verify the full bag against untracked translation before accepting the fast path.

The scalar admission follows PostgreSQL 18 `evaluate_function`, which requires constant inputs and immutable functions and rejects set-returning calls: https://github.com/postgres/postgres/blob/REL_18_0/src/backend/optimizer/util/clauses.c. Residualizing failed pre-evaluation follows DuckDB 1.4.0 `ConstantFoldingRule::Apply`: https://github.com/duckdb/duckdb/blob/v1.4.0/src/optimizer/rule/constant_folding.cpp.

Local history `9aaabecfee3872429c4342109a1584983ab419a8` had a literal arithmetic fold whose failure stayed at runtime. Its later removal is why the current runtime repeats the work. The new gate requires source tracking and module ownership in addition to the immutable scalar argument shape.

## 2026-09-05 verification after rebase

Verdict: L092 was REAL on the measured baseline. The retained compiler now folds the proved native integer fragment. Arbitrary immutable host and recursive calls remain runtime calls because the available declarations do not establish termination or the lifetime of opaque results. The public host test records zero invocations while loading the definitions and exactly three invocations for three demanded calls.

Tried: the differential was written before the implementation. Its 395 ground and adversarial cases passed against the unchanged translator, while the tests requiring constant replacement failed. The first differential fixture incorrectly omitted the generator variable bindings from its expected bag; its expectation was corrected to `[[1]-7, [1]-7, [2]-7]`. A later test requiring folding lacked the stable typing-policy scope that production retained compilation establishes. The fixture now enters `with_typing_policy_stable/1` rather than weakening the compiler gate.

Decided: the closed fragment admits integer `+`, `-`, `*`, `%`, `min`, `max`, `floor-div`, `bit-and`, `bit-or`, `bit-xor`, `abs-math`, and `bit-not`; `size-atom` admits proper integer lists; `min-atom` and `max-atom` require nonempty integer lists. It requires a direct native goal, an unshadowed name, the canonical `pureStructural` effect, tracked source dependencies, and a stable default typing policy. All solutions are collected and folding requires exactly one integer answer. Ordinary failures stay at runtime; control exceptions retain the engine's existing `catch_recover/2` behavior. Floats remain sensitive to the runtime numeric policy, and powers or shifts can amplify a short input into an enormous allocation, so those modes stay at runtime.

Tried: targeted verification on base `8f853f992a4c732eca39de34ff0a3dfe161508dd`, with the query-planning worktree changes applied:

- `VIRTUAL_ENV="$VENV" swipl -q -g "set_test_options([format(log)]),run_tests(translator_constant_folding)" -t halt tests/prolog/suites/translator/constant_folding.plt -- extensions`: exit 0, all 405 cases passed, no load errors or choicepoint warnings.
- `PYTHONPATH=extensions/python HYPOTHESIS_PROFILE=ci "$VENV/bin/python" -m pytest extensions/python/tests/ch18_performance/test_constant_folding.py -q`: exit 0, 6 passed. The generated test compares 50 arithmetic trees in complete duplicate-producing bags against variable-input runtime expressions. Public replacement and removal of the native `+` equation rebuild the retained caller and return 3, 42, and 3.
- `"$VENV/bin/python" -m ruff check extensions/python/tests/ch18_performance/test_constant_folding.py`: exit 0.
- `jscpd --noTips --reporters ai engine/translator/folding.pl tests/prolog/suites/translator/constant_folding.plt extensions/python/tests/ch18_performance/test_constant_folding.py`: exit 0, zero clones. The short native admission clauses remain explicit because an abstraction would obscure their input modes.

Tried: `PYTHONPATH=extensions/python "$VENV/bin/python" ai-tmp/ai-folding-sweep.py` and the same command with `--control`: both exited 0. The control starts a separate process, replaces only `translator:fold_native_scalar_call/5` with failure, and leaves every other optimization enabled. All answers are checked. The output files are `ai-tmp/ai-folding-rebase-sweep-folded.jsonl` and `ai-tmp/ai-folding-rebase-sweep-control.jsonl`.

The following counts include 256 repeated public queries after the first call has compiled the stored definition. The first-call columns include both compilation and one answer.

| Fixed computation | n | Control queries | Folded queries | Control first call | Folded first call |
| --- | ---: | ---: | ---: | ---: | ---: |
| Nested additions | 32 | 110,857 | 95,241 | 10,629 | 13,341 |
| Nested additions | 128 | 160,011 | 95,241 | 39,783 | 50,654 |
| Nested additions | 512 | 356,627 | 95,241 | 180,762 | 200,036 |
| Nested additions | 2,048 | 1,143,091 | 95,241 | 719,918 | 797,562 |
| Integer list maximum | 64 | 161,547 | 95,241 | 2,148 | 2,354 |
| Integer list maximum | 256 | 358,165 | 95,241 | 5,217 | 5,808 |
| Integer list maximum | 1,024 | 1,144,627 | 95,241 | 17,505 | 19,632 |
| Integer list maximum | 4,096 | 4,290,481 | 95,241 | 66,659 | 74,930 |

The sweep also varies the number of queries, separating a per-query constant from one fixed measurement:

| Fixed computation | q | Control queries | Folded queries |
| --- | ---: | ---: | ---: |
| 2,048 additions | 16 | 71,447 | 5,957 |
| 2,048 additions | 64 | 285,777 | 23,815 |
| 2,048 additions | 256 | 1,143,091 | 95,241 |
| 4,096-element maximum | 16 | 268,161 | 5,957 |
| 4,096-element maximum | 64 | 1,072,623 | 23,815 |
| 4,096-element maximum | 256 | 4,290,481 | 95,241 |

Outcome: first compilation scales linearly in n, and repeated evaluation changes from O(q*n) to O(q). Including preprocessing, these fixtures change from O(n+q*n) to O(n+q). The scalar answer has constant representation size over the sweep; arbitrary-precision numeric work and result serialization remain output-sensitive. The original source stays stored for invalidation, so the total source-memory bound remains O(n).

Correction: the first sweep labeled definition registration as planning, although definitions compile lazily on the first demanded call. The final script records registration separately and includes the first compiling query. Registration cost is 395 inferences for the first definition and 365 for later definitions in both modes; it is excluded from the first-call columns above.

## 2026-09-05 composition boundary

Tried: repeated squaring through nested `let` bindings in an unselected `if` branch. At depths 2, 4, 6, 8, 10, and 12, the source lengths were 72, 116, 160, 204, 250, and 300 characters. Tracked translation retained exactly 2, 4, 6, 8, 10, and 12 multiplication goals, and the largest integer constant in every plan remained two bits. The probe is recorded in `ai-tmp/ai-folding-let-amplification-before.log`. The existing binder lowering emits runtime equality and does not propagate the computed constant into subsequent binders.

Reviewed: CPython 3.13.7 `safe_multiply` uses the sum of operand bit lengths and a 128-bit limit to refuse expensive constant multiplication before computing it: https://github.com/python/cpython/blob/v3.13.7/Python/ast_opt.c. That resource guard would matter if binders started propagating arbitrary-precision values during planning. The measured binder boundary already prevents the reported exponential composition here, so no extra numeric policy constant was added.

Decided: add `let_bound_repeated_squaring_retains_runtime_bindings` at the six measured depths. It checks retained multiplication goals, bounded planned constants, and the complete fast/reference answer bags. This establishes the specific composition boundary tested; the per-primitive bound is not a claim that every future source transformation preserves the same resource bound.

Tried: reran `run_tests(translator_constant_folding)` with the composition cases -> exit 0, 411 passed, no load errors or choicepoint warnings. The final log is `ai-tmp/ai-folding-rebase-prolog-final.log`. The production implementation did not change after the size sweep or the six passing public Python tests.
