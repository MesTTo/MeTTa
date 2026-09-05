# Demand transformation for tagged derivations
Goal: derive only the proof trees needed for an eligible tagged query while preserving duplicate answers and failure behavior.

## 2026-09-05

Verified: the tagged evaluator computed a full bottom-up closure before matching its query. Two identical source facts used by two premises produced a counting tag of 4 and four retained proof trees. A wanted fact beside an unrelated productive self-rule raised `algebra_derivation_did_not_reach_fixpoint(counting, rounds=4)`. Ordinary compiled equations already propagate query arguments through their top-down calls; the measured defect is the tagged evaluator.

Research: [Tekle and Liu, *Extended Magic for Negation*, section 3.2 and theorem 4.10](https://arxiv.org/html/1909.08246v1), provides the positive demand transformation and its correspondence with subqueries. [Drabent, *A Simple Correctness Proof for Magic Transformation*, lemmas 1 and 2](https://arxiv.org/html/1012.2299v1), gives the proof-tree erasure and completeness argument. [Souffle's `MagicSet.cpp`](https://github.com/souffle-lang/souffle/blob/a1303be3c0166400dee3d1f36f0d96abe03e6901/src/ast/transform/MagicSet.cpp#L624-L727) implements bound-position propagation; its [magic-rule construction](https://github.com/souffle-lang/souffle/blob/a1303be3c0166400dee3d1f36f0d96abe03e6901/src/ast/transform/MagicSet.cpp#L1135-L1167) constrains each later premise by the preceding prefix.

Decided before implementation: each relation and bound-position/value projection is a unique demand control fact. Each request specializes the original rule's head bindings and propagates known prefix bindings into its premises. An explicit generator stack evaluates these dependencies. Completed demands cache entire proof bags. Both evaluators use `_derive_rule_steps`, so directional matching, tag extension, token ledgers and proof construction remain identical. Original proof height, source order and premise order determine output order before fusion.

The admissible fragment has flat positive rules, ground immutable scalar facts, range-restricted heads, acyclic predicate dependencies, exact integer tags, direct integer operations `+`, `*`, `min` or `max`, and no linear requirement. The whole graph's depth must fit below `max_rounds`, including the final empty fixpoint round. Other programs use full evaluation. Integer bit bounds additionally preserve failures from Python's decimal-rendering limit: an unrelated `10**2200 * 10**2200` caused `ValueError: Exceeds the limit (4300 digits) for integer string conversion; use sys.set_int_max_str_digits() to increase the limit` in the reference evaluator.

Rejected: replacing proof bags with set relations or ordinary tabling, because the duplicate-source witness requires four derivations. Demand controls have no contribution to proof multiplicity. Removing their guards leaves exactly an original derivation; conversely, induction over the acyclic dependency graph makes every original premise derivation available for each demanded head binding. Repeated demand requests reuse the same complete bag. Original source IDs distinguish duplicate facts and duplicate rules.

Rejected: pruning unrestricted programs, because unrelated cycles and custom operation effects or errors are observable in full evaluation. Revisit that boundary only if a declared semantics changes these obligations. Recursive programs retain the existing path. A productive recursive proof cycle has infinitely many finite proof trees under bag semantics; set convergence cannot provide an equivalent finite bag.

Current complexity: for `pair(x,y) <- seed(x), seed(y)` over n distinct seeds, full evaluation retains n squared pair answers, then scans them in the next round. Its matching work is `n^3 + 4*n^2 + 3*n` even when the query requests only `pair(0,0)`. Space is quadratic in n.

Target complexity: linear certification and fact indexing, then one demanded proof with two premise matches and one final match. Time and space on this family are linear in n. General queries still pay for every demanded proof and prefix combination; a request for n squared answers has a quadratic output lower bound.

Measured: `PYTHONPATH=extensions/python $VENV/bin/python ai-tmp/ai-demand-sweep.py` profiled the actual Python matcher and also sampled `m.stats()`. The reference control disables demand dispatch alone. Every pair of runs returned the same value, tag, source tokens, proof IDs and rendered derivation.

| Seeds | Reference `_match` calls | Demand `_match` calls | Demand shape checks | Reference inferences | Demand inferences |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 16 | 5,168 | 3 | 42 | 16,218 | 16,215 |
| 32 | 36,960 | 3 | 74 | 16,647 | 16,649 |
| 64 | 278,720 | 3 | 138 | 17,511 | 17,513 |
| 128 | 2,163,072 | 3 | 266 | 19,239 | 19,241 |

The reference matcher ratios approach eight per doubling. Demand shape checks are exactly `2*n + 10`. SWI inferences count atom transport here; they do not count the Python join. The inference columns are recorded to show this limitation, not as evidence of the class change.

Verified: the initial differential passed 16 cases while the performance gate failed at 5,168 demanded-path match calls. One additional fixture initially failed because operation registration requires explicit `effect=` metadata; after declaring its actual `writesState` effect it exercises the intended fallback. With demand enabled, the complete algebra regression selection passed 53 tests with one existing skip. Planted proof loss and duplication are both rejected by the differential. Generated programs, repeated variables and anonymous variables, duplicate rules, heterogeneous scalar keys, nested or nonground fallback, an eighty-rule chain, cycle and depth failures, and integer-rendering failure are covered in `test_algebra_demand.py`.

Maintenance: jscpd found one existing constructor-signature clone in `algebra.py`, 0.5 percent over the three changed code files. It belongs to the established module constructor and its forwarding call; demand transformation adds no clone and does not change that separate API.

### Rebased verification and complete-call CPU measurement

Verified on base `8f853f992a4c732eca39de34ff0a3dfe161508dd`: the demand differential and existing algebra, linear, amplitude, gradient, Scallop, rate and `under=` suites pass with 56 tests and one existing skip. Ruff passes for both implementation files and the differential. Mypy reports no issue in `_algebra_demand.py`; its earlier local error was a reused loop variable with incompatible annotated types, corrected by naming the shape-valued loop variable separately.

Measured: `PYTHONPATH=extensions/python $VENV/bin/python ai-tmp/ai-demand-sweep-rebased.py` pairs the Python work count with five unprofiled `time.process_time_ns()` measurements of the complete `evaluate` call. All measured calls pass the full answer/proof differential. CPU medians and observed ranges appear below. SWI inference counts in the same table measure atom transport only and exclude the Python join body.

| Seeds | Reference matches | Demand matches / shape checks | Reference CPU ms, median [min, max] | Demand CPU ms, median [min, max] | SWI inferences, reference / demand; excludes Python join |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 16 | 5,168 | 3 / 42 | 10.600 [8.662, 11.491] | 2.684 [2.502, 2.954] | 16,215 / 16,215 |
| 32 | 36,960 | 3 / 74 | 28.870 [27.312, 32.508] | 2.840 [2.692, 3.384] | 16,647 / 16,647 |
| 64 | 278,720 | 3 / 138 | 180.887 [152.121, 191.547] | 4.992 [4.554, 5.687] | 17,511 / 17,511 |
| 128 | 2,163,072 | 3 / 266 | 1,133.515 [1,039.318, 1,420.445] | 5.124 [4.725, 6.555] | 19,241 / 19,239 |

CPU samples varied; allocator, garbage-collector and execution conditions were not isolated. The samples confirm that the removed Python work dominated the complete call at larger sizes. The exact matcher formula and linear certification/indexing count establish the complexity change; the noisy CPU ratios are supplementary evidence. The source-level inference counts remain nearly equal because that counter cannot observe the optimized code.
