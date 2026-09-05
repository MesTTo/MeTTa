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

## 2026-09-05 complete CPU cost and metadata projection

Correction: the earlier O(n+q) conclusion was established only for SWI inference ports. It did not establish the complete CPU bound. A call to a dynamic fact copies its full retained body even when the caller writes an anonymous variable for that field; this work occurs inside SWI and does not add inference ports. The repeated public driver sends only its fixed 22-character invocation, not the large definition. The first public call compiles the source, and each later source call translates that short invocation again.

Tried: three-sample attribution at list sizes 64, 256, 1,024, 4,096, and 16,384, with 2,048 completed public queries. CPU medians were 67,627,186; 76,839,378; 99,054,073; 231,209,364; and 810,379,929 ns, while inference counts stayed 806,949 after the first row's two-port startup difference. A native SWI loop collected 262,144 complete singleton bags from each compiled predicate in 160 to 191 ms across those sizes. Bypassing only the materialization source wrapper left the public growth: 63,210,675; 78,366,378; 103,043,124; 211,806,839; and 809,638,998 ns.

Tried: replace only `fun_meta_module/3` with a temporary projected presence relation -> the public CPU curve fell but still grew, reaching 296,898,569 ns at 16,384. Replacing the body-free head reads as well -> 56,962,304; 56,549,613; 59,313,553; 57,059,383; and 56,207,943 ns. The native source-running loop likewise stayed between 39.2 and 39.9 ms. These temporary substitutions were confined to the measurement process. Raw rows and source hashes are in `ai-tmp/ai-folding-final-a20256a5-attribution4-*.jsonl` and `ai-tmp/ai-folding-final-a20256a5-attribution5-full-projection.jsonl`.

Purpose: answer questions about a stored definition without retrieving its unused payload. The analogies are database covering indexes, symbol-table descriptors, filesystem directory entries, object handles, and separated component arrays. The current mechanism copies one complete dynamic metadata fact for each existence or head query. PostgreSQL 18's index-only scan requires every requested field in the index and preservation of source visibility: https://www.postgresql.org/docs/18/indexes-index-only-scans.html. Here the projection is maintained in the same dynamic database and source journal as its original occurrence, rather than using a separate visibility cache.

Reviewed: `c12009829891f671e3dceeff5505c28f59be138f` replaced a growing metadata list with one fact per equation; `3aa13a592d93230cd59ed809800e3bd72f81f446` kept native reducer calls off the metadata ancestry walk. The remaining cost is payload copying inside successful metadata lookups, not a return to the earlier list append.

Decided before implementation: retain `fun_meta_clause/4` as the source authority, add a head-only fact per occurrence, and link each original clause reference to that exact head reference in a compact presence row. Journal both derived clauses through `record_source_assertion/1`. Insertions, removals and clears use one serialized transaction, so errors roll back all rows and concurrent writers preserve their shared occurrence order. Dropping one variant removes its exact linked projection. Source withdrawal erases every journalled row. Fast images continue serializing source equations and regenerate projections through ordinary compilation; runtime clause references do not enter the image payload.

The CURRENT public repeated cost is O(q*(body size + head size)); the TARGET removes body-size work from those reads, leaving O(q*head size), hence O(q) for fixed-size heads. Total cost is P(n)+O(q*n) before folding and projection, and P(n)+O(q) afterward. P(n) is measured separately with CPU time, not inferred from the call counter. The scalar scan still requires O(n) preprocessing and O(n) retained source memory.

Tried before implementation: the new `translator_metadata_projection` differential compared 14 ground and adversarial complete bags through the actual runnable compiler and runtime, including aliases, misses, duplicate equations, duplicate generators, variable-headed calls and sequence heads. All 14 passed against the unchanged source-reading implementation. Thirteen tests requiring the proposed head relation and exact-reference ownership failed with `Unknown procedure: translator:fun_meta_head/3` or `Unknown procedure: translator:fun_meta_projection/4`, as expected. The first harness attempt also exposed a missing test-module qualification for `runtime_bag/2`; qualifying that callback fixed the fixture before production changes.

Tried: a separate preparation sweep uses one-digit repeated list elements, making source length proportional to list length. At list sizes 256, 1,024, 4,096, 16,384 and 65,536, folded first-query CPU medians were 518,230; 846,701; 2,547,451; 9,742,222; and 40,741,449 ns. Control medians were 705,980; 802,910; 2,786,831; 10,958,413; and 51,315,542 ns. At nested-addition depths 128, 512, 2,048, 8,192 and 16,384, folded first-query CPU medians were 1,820,710; 5,941,301; 26,701,506; 99,077,223; and 194,112,715 ns; control medians were 1,507,951; 6,418,492; 20,783,135; 75,082,077; and 150,981,685 ns. These pre-projection CPU curves are consistent with linear preparation over the measured range; they do not show the suspected quadratic nested-AST preparation. Raw registration, first-answer and combined preparation values are preserved in `ai-tmp/ai-folding-final-a20256a5-preprojection-preparation-*.jsonl`.

Verified: the metadata projection and existing folding, metadata-store and source-rollback selection passes 448 Prolog cases with no warnings or errors. The public projection lifecycle and folding tests pass 11 cases. Ruff and `git diff --check` pass. Logs and separate zero statuses are `ai-tmp/ai-folding-final-a20256a5-projection-prolog-final.log`, `ai-tmp/ai-folding-final-a20256a5-projection-python.log`, and `ai-tmp/ai-folding-final-a20256a5-projection-ruff.log`. Final paired CPU sweeps remain a separate evidence obligation.

## 2026-09-05 paired complete-workload checkpoint

Tried: `PYTHONPATH=extensions/python "$VENV/bin/python" ai-tmp/ai-folding-final-a20256a5-complete-sweep.py --mode MODE --metadata ai-tmp/ai-folding-final-a20256a5-complete-MODE-metadata.json` for `optimized`, `folding-control`, and `metadata-control`. Each process exited 0 and recorded 69 complete workloads at three samples per point. Their source hash dictionaries match and every before/after comparison is unchanged. The source snapshot is commit `14702fd4ab37f5c9af33f1cd327733eae9aea82f` plus the concurrent materialization and persistence work recorded by those hashes. These numbers precede the later materialization transaction-publication repair; they are a preserved attribution checkpoint, not pins carried onto that later source.

Tried: the summary audit checked all 207 workloads, exact per-sample phase sums, completed answer counts, deferred registration, completed compilation, and absence of materialized arithmetic predicates -> exit 0. The report and all raw samples are in `ai-tmp/ai-folding-final-a20256a5-complete-summary.md` and `.json`.

### Complete public workloads at q=n

Each number is the median of three completed workloads on the same source bytes. Registration stores the definition; the first query compiles it and returns one answer; the repeated phase completes q additional public calls and checks every full bag. Preparation is registration plus first query, and total is preparation plus repeated calls. The raw per-sample phases sum exactly. Medians of different columns need not add, because their middle samples can differ.

The folding control disables only `fold_native_scalar_call/5`. The metadata control restores source-reading existence/head consumers while retaining the ownership tables and folding. The optimized mode uses both changes. Every fixed-list fixture contains n one-digit integers and answers 1, so its source length is linear in n and output length stays fixed.

SWI inferences count predicate ports and omit work inside native predicates and Python. The metadata control demonstrates that blind spot directly: similar port counts coexist with quadratic total CPU. `process_time_ns` measures process user plus system CPU, including transport, decoding and the `m.stats()` calls; it excludes interpreter startup, source-string construction and diagnostics.

#### fixed-list-maximum: SWI inferences

| n=q | Mode | Registration | First query | Preparation | Repeated q calls | Total |
| ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 256 | folding-control | 553 | 5,247 | 5,800 | 363,795 | 369,595 |
| 256 | metadata-control | 553 | 5,838 | 6,391 | 100,873 | 107,264 |
| 256 | optimized | 553 | 5,838 | 6,391 | 100,873 | 107,264 |
| 1,024 | folding-control | 553 | 17,535 | 18,088 | 4,601,021 | 4,619,109 |
| 1,024 | metadata-control | 553 | 19,662 | 20,215 | 403,477 | 423,692 |
| 1,024 | optimized | 553 | 19,662 | 20,217 | 403,477 | 423,694 |
| 4,096 | folding-control | 553 | 66,689 | 67,242 | 68,737,731 | 68,804,973 |
| 4,096 | metadata-control | 553 | 74,960 | 75,513 | 1,613,893 | 1,689,406 |
| 4,096 | optimized | 553 | 74,960 | 75,513 | 1,613,893 | 1,689,406 |
| 16,384 | folding-control | 553 | 263,303 | 263,856 | 1,080,289,489 | 1,080,553,345 |
| 16,384 | metadata-control | 553 | 296,152 | 296,705 | 6,455,559 | 6,752,264 |
| 16,384 | optimized | 553 | 296,152 | 296,705 | 6,455,559 | 6,752,264 |

#### fixed-list-maximum: Process CPU, nanoseconds

| n=q | Mode | Registration | First query | Preparation | Repeated q calls | Total |
| ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 256 | folding-control | 250,830 | 379,901 | 630,731 | 15,193,413 | 15,824,144 |
| 256 | metadata-control | 421,870 | 514,580 | 936,450 | 10,599,633 | 11,724,473 |
| 256 | optimized | 242,320 | 378,620 | 597,230 | 7,990,532 | 8,694,552 |
| 1,024 | folding-control | 423,640 | 923,231 | 1,334,460 | 138,553,262 | 139,887,722 |
| 1,024 | metadata-control | 490,440 | 848,651 | 1,327,670 | 58,271,894 | 60,257,144 |
| 1,024 | optimized | 433,880 | 878,710 | 1,316,340 | 28,655,097 | 29,971,437 |
| 4,096 | folding-control | 1,001,181 | 3,035,050 | 4,036,231 | 1,776,257,753 | 1,780,896,824 |
| 4,096 | metadata-control | 1,086,020 | 2,716,541 | 3,802,561 | 475,045,671 | 478,848,232 |
| 4,096 | optimized | 955,220 | 2,596,911 | 3,552,131 | 112,131,536 | 115,486,846 |
| 16,384 | folding-control | 2,802,490 | 11,096,083 | 13,898,573 | 28,528,866,981 | 28,542,060,764 |
| 16,384 | metadata-control | 3,230,141 | 11,022,183 | 14,150,493 | 6,387,470,083 | 6,400,688,476 |
| 16,384 | optimized | 2,886,831 | 10,863,142 | 14,369,424 | 473,829,941 | 488,328,784 |

#### nested-additions: SWI inferences

| n=q | Mode | Registration | First query | Preparation | Repeated q calls | Total |
| ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 128 | folding-control | 553 | 40,067 | 40,620 | 82,825 | 123,445 |
| 128 | metadata-control | 553 | 50,938 | 51,491 | 50,439 | 101,930 |
| 128 | optimized | 553 | 50,938 | 51,491 | 50,439 | 101,930 |
| 512 | folding-control | 553 | 181,810 | 182,363 | 724,515 | 906,878 |
| 512 | metadata-control | 553 | 201,088 | 201,641 | 201,741 | 403,382 |
| 512 | optimized | 553 | 201,088 | 201,641 | 201,741 | 403,382 |
| 2,048 | folding-control | 553 | 724,040 | 724,593 | 9,189,749 | 9,914,342 |
| 2,048 | metadata-control | 553 | 801,686 | 802,239 | 806,949 | 1,609,188 |
| 2,048 | optimized | 553 | 801,688 | 802,241 | 806,949 | 1,609,190 |
| 8,192 | folding-control | 553 | 2,892,958 | 2,893,511 | 137,426,303 | 140,319,814 |
| 8,192 | metadata-control | 553 | 3,204,084 | 3,204,637 | 3,227,783 | 6,432,420 |
| 8,192 | optimized | 553 | 3,204,086 | 3,204,639 | 3,227,783 | 6,432,422 |

#### nested-additions: Process CPU, nanoseconds

| n=q | Mode | Registration | First query | Preparation | Repeated q calls | Total |
| ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 128 | folding-control | 307,720 | 1,399,421 | 1,707,141 | 4,495,811 | 6,202,952 |
| 128 | metadata-control | 275,670 | 1,669,560 | 1,958,270 | 4,169,271 | 6,127,541 |
| 128 | optimized | 259,950 | 1,752,490 | 2,020,040 | 3,712,561 | 5,732,601 |
| 512 | folding-control | 559,040 | 7,402,012 | 7,961,052 | 26,918,776 | 34,879,828 |
| 512 | metadata-control | 644,120 | 6,325,772 | 7,068,732 | 29,154,086 | 36,222,818 |
| 512 | optimized | 505,340 | 5,829,012 | 6,334,352 | 13,814,903 | 20,149,255 |
| 2,048 | folding-control | 1,541,590 | 30,515,938 | 32,057,528 | 288,553,096 | 310,044,631 |
| 2,048 | metadata-control | 1,543,980 | 24,189,236 | 25,762,526 | 317,200,294 | 342,962,820 |
| 2,048 | optimized | 1,296,061 | 23,235,755 | 24,531,816 | 60,952,914 | 85,484,730 |
| 8,192 | folding-control | 5,751,561 | 85,432,010 | 90,156,861 | 3,673,935,655 | 3,764,092,516 |
| 8,192 | metadata-control | 5,599,191 | 115,307,547 | 120,867,408 | 4,221,281,493 | 4,323,577,646 |
| 8,192 | optimized | 5,103,691 | 97,473,273 | 102,576,964 | 275,942,454 | 383,722,909 |

#### Fixed q=256

| Computation | n | Mode | Repeated inferences | Repeated CPU, ns |
| --- | ---: | --- | ---: | ---: |
| fixed-list-maximum | 256 | folding-control | 363,795 | 15,193,413 |
| fixed-list-maximum | 256 | metadata-control | 100,873 | 10,599,633 |
| fixed-list-maximum | 256 | optimized | 100,873 | 7,990,532 |
| fixed-list-maximum | 1,024 | folding-control | 1,150,259 | 33,528,248 |
| fixed-list-maximum | 1,024 | metadata-control | 100,873 | 12,564,173 |
| fixed-list-maximum | 1,024 | optimized | 100,873 | 7,710,051 |
| fixed-list-maximum | 4,096 | folding-control | 4,296,113 | 109,279,615 |
| fixed-list-maximum | 4,096 | metadata-control | 100,873 | 27,919,627 |
| fixed-list-maximum | 4,096 | optimized | 100,873 | 7,895,182 |
| fixed-list-maximum | 16,384 | folding-control | 16,879,529 | 395,995,693 |
| fixed-list-maximum | 16,384 | metadata-control | 100,873 | 98,136,873 |
| fixed-list-maximum | 16,384 | optimized | 100,873 | 7,076,832 |
| nested-additions | 128 | folding-control | 165,643 | 8,626,632 |
| nested-additions | 128 | metadata-control | 100,873 | 9,297,622 |
| nested-additions | 128 | optimized | 100,873 | 7,330,852 |
| nested-additions | 512 | folding-control | 362,259 | 12,880,473 |
| nested-additions | 512 | metadata-control | 100,873 | 13,978,453 |
| nested-additions | 512 | optimized | 100,873 | 7,846,152 |
| nested-additions | 2,048 | folding-control | 1,148,723 | 33,327,878 |
| nested-additions | 2,048 | metadata-control | 100,873 | 39,879,639 |
| nested-additions | 2,048 | optimized | 100,873 | 7,951,452 |
| nested-additions | 8,192 | folding-control | 4,294,577 | 120,938,478 |
| nested-additions | 8,192 | metadata-control | 100,873 | 175,481,000 |
| nested-additions | 8,192 | optimized | 100,873 | 9,719,702 |

All three mode metadata files report `source_unchanged=true`; their engine, library and Python source hash dictionaries match. Exact samples and every q=16, q=256 and q=n workload remain in `ai-folding-final-a20256a5-complete-summary.json` and the three raw JSONL files.

Outcome: over the largest fourfold list-size increase, total CPU grows from 1,780,896,824 to 28,542,060,764 ns with folding disabled, from 478,848,232 to 6,400,688,476 ns with metadata reads reverted, and from 115,486,846 to 488,328,784 ns with both optimizations enabled. The source and output bounds explain the class difference: the controls repeat a list scan or retained-body copy for each query; the optimized path scans the fixed list once during preparation and returns a fixed-size value thereafter. The complete workload therefore changes from O(n+q*n) to O(n+q) for this fixed-head, fixed-result fixture, rather than merely shifting cost into its first call. Arbitrary-precision arithmetic and result copying remain dependent on operand and output bit sizes.

Tried: `jscpd --noTips --reporters ai engine/translator/analysis.pl engine/translator/lowering.pl engine/translator/typing.pl engine/translator/runtime.pl tests/prolog/suites/translator/metadata_projection.plt extensions/python/tests/ch18_performance/test_metadata_projection.py` -> exit 0, zero clones, 0.0% duplication. Its log is `ai-tmp/ai-folding-final-a20256a5-projection-jscpd.log`; no extraction was warranted.

## 2026-09-05 reproducible complete-workload driver

Decided: move the existing complete-workload sweep and its helper dependency into `extensions/python/benchmarks/query_planning_folding.py`. The fixtures, modes, measured phases and full-bag checks remain the same. It runs as `PYTHONPATH=extensions/python "$VENV/bin/python" -m benchmarks.query_planning_folding --mode MODE --metadata PATH`; its default three samples produce 69 completed workloads per mode. The fourth mode combines the two independent controls. This removes the scratch `runpy` dependency from the repeatable command.

Decided: share `source_snapshot()` and `finish_metadata()` with the other query-planning benchmark drivers. They fingerprint relative engine, library, Python and `query_planning*.py` source paths, excluding scratch files and metadata outputs. A mismatched before/after fingerprint writes the changed path names into the metadata and then refuses the run. It does not detect a transient source edit restored between those snapshots. Three-way reuse removes a duplicated finalization policy; `jscpd` reports zero clones across the join/demand and folding modules after that extraction.

Verified: `--samples 0`, `--samples -1` and a nonnumeric value exit 2 before engine startup or metadata creation. Values 1 and 101 reach the source-snapshot boundary; there is no arbitrary upper cap. A planted fingerprint mismatch covering changed, added and removed paths writes `source_unchanged=false` before raising `AssertionError(['engine/example.pl', 'lib/new.pl', 'lib/removed.pl'])`; a matching fingerprint preserves the mode and row fields and succeeds. No source files were changed by these probes. Logs and separate zero statuses are `ai-tmp/ai-folding-final-a20256a5-benchmark-module-validation3.log`, `ai-tmp/ai-folding-final-a20256a5-benchmark-metadata-control.log`, `ai-tmp/ai-folding-final-a20256a5-benchmark-module-ruff4.log` and `ai-tmp/ai-folding-final-a20256a5-benchmark-module-jscpd3.log`.

Open: run the final paired measurements through the module after the materialization transaction-publication source is frozen. The earlier checkpoint remains unchanged.


## 2026-09-05 final module measurements

Tried: `PYTHONPATH=extensions/python timeout -s KILL 290 "$VENV/bin/python" -m benchmarks.query_planning_folding --mode MODE --metadata ai-tmp/ai-folding-final-a20256a5-module-MODE-metadata.json` for `optimized`, `folding-control` and `metadata-control`, with the default three samples. Every process exited 0 and recorded 69 complete workloads. The preserved `combined-control` mode also exited 0 with `--samples 1`, recording another 23 workloads. All four stderr logs are empty. Each JSONL row states that SWI inferences exclude Python and native-call internals, beside its phase numbers. The external process bound was explicitly required for this verification; no process reached it.

Verified: all four before/after checks report unchanged source, and all 206 engine, library, Python and benchmark-driver source fingerprints match across the processes and the tree at measurement close. The first two processes record HEAD `b9f0e7f3842ec0a5ae9c3a7f8a709cfefc76b5c0`; the later two record `4d0713ac74c49e60dfda40116a663b6e61c02932`. A local commit advanced HEAD while those source bytes remained unchanged. The first final audit incorrectly required equal HEAD names and failed with `AssertionError`; `ai-tmp/ai-folding-final-a20256a5-module-audit2.log` records the corrected source-equality audit, both HEADs, exact phase sums, fixed 22-character calls and all 230 completed workloads, with exit 0. The independent three-mode summary audit checks all 207 sampled workloads and exits 0 in `ai-tmp/ai-folding-final-a20256a5-module-summary.log`.

The tables below replace the earlier checkpoint as the measured result for this implementation. They measure completed public source calls within an existing context; context creation, context teardown, source-string construction and inspection calls are outside the reported phases.

### Complete public workloads at q=n

Each number is the median of three completed workloads on the same source bytes. Registration stores the definition; the first query compiles it and returns one answer; the repeated phase completes q additional public calls and checks every full bag. Preparation is registration plus first query, and total is preparation plus repeated calls. The raw per-sample phases sum exactly. Medians of different columns need not add, because their middle samples can differ.

The folding control disables only `fold_native_scalar_call/5`. The metadata control restores source-reading existence/head consumers while retaining the ownership tables and folding. The optimized mode uses both changes. Every fixed-list fixture contains n one-digit integers and answers 1, so its source length is linear in n and output length stays fixed.

SWI inferences count predicate ports and omit work inside native predicates and Python. The metadata control demonstrates that blind spot directly: similar port counts coexist with quadratic total CPU. `process_time_ns` measures process user plus system CPU, including transport, decoding and the `m.stats()` calls; it excludes interpreter startup, source-string construction and diagnostics.

#### fixed-list-maximum: SWI inferences

| n=q | Mode | Registration | First query | Preparation | Repeated q calls | Total |
| ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 256 | folding-control | 565 | 5,247 | 5,812 | 363,797 | 369,609 |
| 256 | metadata-control | 565 | 5,838 | 6,403 | 100,873 | 107,276 |
| 256 | optimized | 565 | 5,838 | 6,403 | 100,873 | 107,276 |
| 1,024 | folding-control | 565 | 17,537 | 18,102 | 4,601,021 | 4,619,123 |
| 1,024 | metadata-control | 565 | 19,664 | 20,229 | 403,477 | 423,706 |
| 1,024 | optimized | 565 | 19,664 | 20,229 | 403,477 | 423,706 |
| 4,096 | folding-control | 565 | 66,689 | 67,254 | 68,737,731 | 68,804,985 |
| 4,096 | metadata-control | 565 | 74,960 | 75,525 | 1,613,893 | 1,689,418 |
| 4,096 | optimized | 565 | 74,960 | 75,525 | 1,613,893 | 1,689,418 |
| 16,384 | folding-control | 565 | 263,303 | 263,868 | 1,080,289,489 | 1,080,553,357 |
| 16,384 | metadata-control | 565 | 296,152 | 296,717 | 6,455,559 | 6,752,276 |
| 16,384 | optimized | 565 | 296,152 | 296,717 | 6,455,559 | 6,752,276 |

#### fixed-list-maximum: Process CPU, nanoseconds

| n=q | Mode | Registration | First query | Preparation | Repeated q calls | Total |
| ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 256 | folding-control | 361,040 | 435,910 | 806,400 | 15,162,373 | 15,949,524 |
| 256 | metadata-control | 344,390 | 460,790 | 805,180 | 12,495,923 | 13,301,103 |
| 256 | optimized | 404,160 | 524,040 | 917,460 | 9,664,123 | 10,549,063 |
| 1,024 | folding-control | 536,190 | 975,510 | 1,503,220 | 180,516,932 | 182,020,152 |
| 1,024 | metadata-control | 646,890 | 1,184,671 | 1,831,561 | 61,915,584 | 63,747,145 |
| 1,024 | optimized | 535,830 | 1,079,140 | 1,638,490 | 36,997,158 | 38,757,819 |
| 4,096 | folding-control | 1,576,730 | 4,690,172 | 6,335,251 | 2,013,654,066 | 2,020,111,088 |
| 4,096 | metadata-control | 1,025,221 | 3,443,190 | 4,440,891 | 569,548,193 | 575,268,254 |
| 4,096 | optimized | 1,482,960 | 3,527,731 | 5,010,691 | 140,880,963 | 145,891,654 |
| 16,384 | folding-control | 4,584,301 | 13,893,843 | 18,478,144 | 29,743,802,706 | 29,762,280,850 |
| 16,384 | metadata-control | 4,972,481 | 14,950,733 | 20,459,605 | 6,677,838,790 | 6,698,298,395 |
| 16,384 | optimized | 3,322,041 | 11,164,862 | 14,595,863 | 509,013,868 | 523,609,731 |

#### nested-additions: SWI inferences

| n=q | Mode | Registration | First query | Preparation | Repeated q calls | Total |
| ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 128 | folding-control | 565 | 40,065 | 40,630 | 82,825 | 123,455 |
| 128 | metadata-control | 565 | 50,938 | 51,503 | 50,439 | 101,942 |
| 128 | optimized | 565 | 50,938 | 51,503 | 50,439 | 101,942 |
| 512 | folding-control | 565 | 181,812 | 182,377 | 724,513 | 906,890 |
| 512 | metadata-control | 565 | 201,088 | 201,653 | 201,741 | 403,394 |
| 512 | optimized | 565 | 201,088 | 201,653 | 201,741 | 403,394 |
| 2,048 | folding-control | 565 | 724,040 | 724,605 | 9,189,749 | 9,914,354 |
| 2,048 | metadata-control | 565 | 801,688 | 802,253 | 806,949 | 1,609,202 |
| 2,048 | optimized | 565 | 801,686 | 802,251 | 806,949 | 1,609,200 |
| 8,192 | folding-control | 565 | 2,892,958 | 2,893,523 | 137,426,301 | 140,319,824 |
| 8,192 | metadata-control | 565 | 3,204,084 | 3,204,651 | 3,227,783 | 6,432,432 |
| 8,192 | optimized | 565 | 3,204,084 | 3,204,649 | 3,227,783 | 6,432,432 |

#### nested-additions: Process CPU, nanoseconds

| n=q | Mode | Registration | First query | Preparation | Repeated q calls | Total |
| ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 128 | folding-control | 409,000 | 1,651,900 | 2,003,010 | 5,922,372 | 7,925,382 |
| 128 | metadata-control | 353,030 | 1,895,601 | 2,140,551 | 4,479,621 | 6,620,172 |
| 128 | optimized | 284,300 | 1,899,431 | 2,170,420 | 4,492,391 | 6,723,062 |
| 512 | folding-control | 610,310 | 7,026,582 | 7,636,892 | 27,480,176 | 35,117,068 |
| 512 | metadata-control | 551,280 | 6,058,482 | 6,651,552 | 30,775,257 | 39,271,199 |
| 512 | optimized | 575,780 | 6,965,922 | 7,759,562 | 16,715,684 | 24,599,586 |
| 2,048 | folding-control | 1,295,521 | 23,522,815 | 24,818,336 | 272,457,813 | 297,276,149 |
| 2,048 | metadata-control | 1,366,630 | 27,822,227 | 29,188,857 | 312,519,762 | 337,641,098 |
| 2,048 | optimized | 1,394,670 | 24,124,596 | 25,491,156 | 67,691,936 | 97,432,582 |
| 8,192 | folding-control | 6,400,612 | 89,416,431 | 94,409,772 | 3,857,940,398 | 3,952,350,170 |
| 8,192 | metadata-control | 4,798,651 | 104,599,054 | 108,944,315 | 5,213,538,091 | 5,389,902,600 |
| 8,192 | optimized | 4,841,411 | 107,787,385 | 113,212,146 | 330,517,116 | 440,677,882 |

#### Fixed q=256

| Computation | n | Mode | Repeated inferences | Repeated CPU, ns |
| --- | ---: | --- | ---: | ---: |
| fixed-list-maximum | 256 | folding-control | 363,797 | 15,162,373 |
| fixed-list-maximum | 256 | metadata-control | 100,873 | 12,495,923 |
| fixed-list-maximum | 256 | optimized | 100,873 | 9,664,123 |
| fixed-list-maximum | 1,024 | folding-control | 1,150,259 | 35,288,748 |
| fixed-list-maximum | 1,024 | metadata-control | 100,873 | 15,133,084 |
| fixed-list-maximum | 1,024 | optimized | 100,873 | 8,606,152 |
| fixed-list-maximum | 4,096 | folding-control | 4,296,113 | 140,537,843 |
| fixed-list-maximum | 4,096 | metadata-control | 100,873 | 39,558,070 |
| fixed-list-maximum | 4,096 | optimized | 100,873 | 9,983,791 |
| fixed-list-maximum | 16,384 | folding-control | 16,879,529 | 457,679,117 |
| fixed-list-maximum | 16,384 | metadata-control | 100,873 | 122,865,476 |
| fixed-list-maximum | 16,384 | optimized | 100,873 | 8,190,682 |
| nested-additions | 128 | folding-control | 165,643 | 11,946,083 |
| nested-additions | 128 | metadata-control | 100,873 | 10,178,492 |
| nested-additions | 128 | optimized | 100,873 | 8,089,662 |
| nested-additions | 512 | folding-control | 362,261 | 14,021,014 |
| nested-additions | 512 | metadata-control | 100,873 | 15,298,523 |
| nested-additions | 512 | optimized | 100,873 | 9,028,682 |
| nested-additions | 2,048 | folding-control | 1,148,723 | 34,947,918 |
| nested-additions | 2,048 | metadata-control | 100,873 | 37,190,298 |
| nested-additions | 2,048 | optimized | 100,873 | 8,036,262 |
| nested-additions | 8,192 | folding-control | 4,294,577 | 113,630,547 |
| nested-additions | 8,192 | metadata-control | 100,873 | 141,192,824 |
| nested-additions | 8,192 | optimized | 100,873 | 9,087,722 |

All three mode metadata files report `source_unchanged=true`; their engine, library and Python source hash dictionaries match. Exact samples and every q=16, q=256 and q=n workload remain in `ai-folding-final-a20256a5-module-summary.json` and the three raw JSONL files.

Outcome: for the fixed-head list fixture, preparation is linear in source length and every answer is the integer 1. At q=n, the largest fourfold size increase raises total process CPU from 2,020,111,088 to 29,762,280,850 ns with folding disabled, from 575,268,254 to 6,698,298,395 ns with source-reading metadata restored, and from 145,891,654 to 523,609,731 ns with both changes enabled. The complete workload changes from O(n+q*n) to O(n+q). This includes first compilation rather than relying only on a warmed plateau. At fixed q=256, optimized repeated CPU stays between 8,190,682 and 9,983,791 ns over n=256 through 16,384, while the two controls rise to 457,679,117 and 122,865,476 ns respectively.

The metadata control and optimized mode have identical q=n total SWI counts for every list size, ending at 6,752,276 ports, despite their different CPU classes. Folding disabled ends at 1,080,553,357 ports. Thus the source-reading control proves why inference counts alone did not establish the earlier total-cost claim. The retained input consumes O(n) source memory; preparation must inspect the input, and q completed calls must return q values. Arbitrary-precision operands and results keep their bit-size costs; the nested-addition fixture is supplementary evidence rather than a claim that all scalar arithmetic has constant-size values.

## 2026-09-05: folding yields to an open observation

Found by rebasing onto the trunk that had gained source observation:
`source_observation:nested_controls_preserve_each_source_branch` failed, and
disabling `fold_native_scalar_call/5` alone made it pass. The fixture is
`(= (obs-nested $a $b) (if $a (if $b (+ 1 2) (+ 3 4)) (+ 5 6)))`, three
constant integer calls, all foldable. A folded call leaves no goal to attribute,
so the three `source-coverage` rows do not read zero, they are absent: the
report stops naming the branch that ran as well as the two that did not.

Decided: the optimization yields while an observation is open, tested as
`\+ nb_current('$metta_observation', _)` placed after every other admission
test rather than first, which is what makes it free: run-source reads 427,855
with it last and 429,855 with it first, because most of what passes the
argument shape is rejected by the effect or mode test before the question is
worth asking. This is what a coverage build
does everywhere else, and coverage is what the observation is for. Rejected:
teaching the observer to attribute a span whose goal was folded away, which
would need the pre-folding tree carried into the compiled clause; that is the
observer's own design and a larger change than the interaction warrants.

Limitation: an equation compiled before an observation opens stays folded, so
observing it later still misses those spans. Deferred translation compiles at
first call, and the observer's own door takes source text, so the shipped path
compiles inside the observation; a program that ran a definition first and
observed it afterwards is the case this does not cover.

