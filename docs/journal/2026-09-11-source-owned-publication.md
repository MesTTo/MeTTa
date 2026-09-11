# Source-owned publication

Goal: pay source ownership and fixed runnable and typing setup at publication while preserving exact withdrawal, transaction visibility, ordered effects, callbacks and error traces.

Constraint: preserve the parity estimator, upstream commit and every existing allowance. Keep changes to the concurrently owned lifecycle and translator units as explicit integration patches.

## 2026-09-11

Tried: `ai-tmp/publication-d9d1201b/ai-parity-measure.py` calls the parity lane's `prepare_artifacts` and `measure` against `b1d175f13b67baf1090f74f309407b763d421744`. The fixture produces 21 QLF artifacts. Accepted observations are functionremovalspec 12613500 instructions / 11932 inferences and plntest 32701204 / 28408. The pristine cut reports 12613617 / 11932 and 32727710 / 28408 respectively. Casenew and holfunctions have stable inference counts of 4791 and 17360, but their instruction observations were refused by the existing null-resolution check. Raw samples and refused verdicts remain in that directory.

Tried: the same estimator against upstream `ae66fa8e41dcd5539d614706bd4e5cfb34f9608d` accepts functionremovalspec 10540162 / 12790, casenew 4498703 / 7170, holfunctions 17059997 / 22389 and plntest 30021210 / 39839.

Tried: `swipl -q -s ai-tmp/publication-d9d1201b/ai-profile.pl -- <checkout> <program>` retains predicate call counts. Functionremovalspec calls `record_source_assertion/1` 89 times and the source-recompile owner reader 117 times. Plntest calls the recorder 114 times and interprets 455 shipped expected-type patterns in 91 calls to `typing_rule_expected_resolved/3`. Both profiles finish below the sampling period, so they supply call counts, not a time attribution.

Rejected: delaying a whole source's translation until publication, because a runnable changes what the next form compiles against. Revisit only if the language removes source-prefix effects.

Rejected: suppressing ownership rows or tuple retry callbacks. The existing withdrawal tests and the waiver journal's throwing callback control require their behavior. A list accumulator published only at source completion also repeats the August 19 design that added 80410 save-load inferences.

Decided: preserve indexed individual ownership rows and their immediate visibility. Probe hoisting the owner decision into the existing source, owner-pin and recompile scopes; batch publishers can then reuse that decision without changing reference identity or database ordering. Group retirement must still invoke each ordinary erase and callback in its established order, which gives an output-sensitive lower bound of one operation per retained reference.

Decided: use the existing shipped typing-rule term expansion as the basis for compiled expected-type witnesses. Keep user pattern normalization and rule order at query time. The relevant prior art is SWI's `library(record)` declaration expansion and `library(apply_macros)` compilation of fixed control structure at `fc7ef84b949378b729052c3ade79c90ce5416abb`; both are already in the local research corpus.

Open: measure a factored runnable boundary before choosing its final interface. Source observation must retain expression locations through the factored closure. Complete accepted cut controls and verify MORK execution before implementation.

Tried: the ordinary loader, source-observation, reference-loading, metadata and compiled-typing suites pass. The Python MORK suite executes all 28 cases with no skips. The runnable-boundary probe adds eight inferences per form and has no resolved instruction saving: functionremovalspec reads 12449329 / 11972 against its paired probe control 12422175 / 11932, with overlapping instruction ranges. Rejected: shipping this extra dispatch layer as a performance change. Revisit if a different compilation boundary removes a measured cost.

Tried: functionremovalspec's profile reaches specialization invalidation and equation retirement but never `withdraw_source_load/3` or `rollback_source_load/1`. A faster source rollback alone cannot explain a reduction in that program. Retirement work must reach the installed equation's artifacts as well.

Decided: implement the independent installed-witness lever first. Extend the existing declaration expansion with `shipped_typing_rule_expected/2`; the expected-pattern openness decision is fixed at declaration compilation. Preserve the user-tier normalization, rule order, directed matching and final cut in `typing_rule_expected_resolved/3`. An independent copy of the registry interpreter compares constrained and relational family queries, free expected values, shared variables and user rules. Runtime `get_type_rule/2` calls and tuple retries remain required observations.

Open: instruction comparisons are delegated to the integrator's release measurement window on the merged tree. The latest refused attempts retain their raw values and host load, which reached 54 on 32 logical CPUs. Exact inference controls are sufficient to continue implementation; no instruction allowance changes.

Tried: the compiled-pattern implementation passes the eight typing differential tests, four typing-scope tests and structural-alias suite. Its expected patterns still sit in clause bodies, which retains a linear scan of a family's patterns. Decided: emit indexed expected-pattern heads for bound inputs, and retain directed compiled checks for initially free inputs. The latter must test openness after family matching because the family and expected value can share a variable. Alias edit controls use unshipped tags so a shipped metatype cannot mask failed user normalization.

Tried: `sh engine/test.sh suites/typecheck/compiled_typing_rules.plt suites/typecheck/typing_rule_scope.plt suites/typecheck/structural_aliases.plt` passes 8, 4 and 32 tests plus 8 structural-alias subtests after indexed witness publication. `jscpd` scans both changed Prolog files with the Prolog tokenizer and reports zero clones over 685 lines and 5594 tokens. The earlier comma-separated file glob selected no files and supplies no clone evidence.
