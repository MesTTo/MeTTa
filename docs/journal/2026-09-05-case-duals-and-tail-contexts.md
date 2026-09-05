# Case duals and conditional tail contexts
Goal: preserve compiled ordered cases under constructive negation and establish whether conditional recursion retains tail position.

## 2026-09-05
Tried: `PYTHONPATH=extensions/python $VENV/bin/python ai-tmp/ai-probe-dual-forms.py` -> a flat wildcard case and nested wildcard cases raise `Type error: integer expected, found Empty` when their dual path runs. A flat case containing only literal patterns answers correctly. Three engine regression cases fail before the repair.

Decided: `engine/duals.pl:case_default/3` must extract the written pattern and compare it with `Empty` using `==/2`. Unifying the row with an Empty pattern changes the source wildcard while constructing the dual. The ordinary translator already separates default selection from pattern matching; the dual must preserve that separation.

Rejected: flattening Python's case tower to conceal the failure, because an ordinary flat case with a catch-all fails too, and nested cases are valid programs.

Tried: `PYTHONPATH=extensions/python $VENV/bin/python ai-tmp/ai-probe-tail-stack.py` -> conditional-expression recursion and statement recursion each complete 200,000 steps under an 8,000,000-byte combined stack bound. Three samples for each are 2,400,254 inferences. At 10,000 steps each costs 120,254 inferences in three samples. The existing return-merging pass therefore preserves these tail calls with linear inference cost and bounded stack.

Decided: follow Chez Scheme's `np-recognize-loops` tail-context rule when reviewing the lowering. The conditional test clears the tail context and both arms inherit it; a sequence clears the first expression's context and preserves the final expression's context. The implementation read is `racket/src/ChezScheme/s/cpnanopass.ss`, lines 1038-1093 at commit `50f1f60628c5b50f1aeeca27e50a5af42381731e`: https://github.com/racket/racket/blob/50f1f60628c5b50f1aeeca27e50a5af42381731e/racket/src/ChezScheme/s/cpnanopass.ss#L1038-L1093. PeTTa already applies the corresponding last-goal restoration in `engine/translator/runtime.pl:merge_branch_returns/3`; no Python AST change is justified by the measured conditional recursion.

Tried: the identity-only repair -> the wildcard exception disappears, but nested False arms answer nothing. The generated dual wraps case-pattern variables in `metta_forall_c/2`, although selecting the pattern binds them from the key. Extending the existing generator-bound-variable walk to case patterns restores those answers. The unmatched-arm Python regression then exposes `empty/1` being refused as a non-dualisable builtin. Its answer set equals `(superpose ())`, whose dual already succeeds; the empty form now has that same dual.

Rejected: `subsumes_term(['Empty', _], Found)` as the default discriminator, although the ordinary translator uses it, because it performs constraint-aware trial unification. The probe `clpfd:in(X,'..'(1,3)), subsumes_term(['Empty',_],[X,false])` raises `error(type_error(integer,Empty),_)`. Identity testing preserves the source pattern without invoking a constraint hook.

Verified: `test_compiled_tail_duals.py` reports 2 failed and 3 passed before the repair, then 5 passed afterward. `case_dual_patterns.plt` reports 3 failed before the repair; the completed suite, including explicit empty-body coverage, reports 4 passed. The new `08-case-duals` twin proves all seven claims, matches the MeTTa example's stored content, and costs 13,543 inferences in three identical fresh-process samples. The twin coverage lane reports zero findings.

Tried: replace the original tile puzzle's two rule clauses in a throwaway probe with one compiled conditional and early return -> all 181,441 states complete at 30,013,808 inferences. The older claim that this spelling necessarily overflows is no longer true.

Verified: the completed Python file also checks a captured structural field under negation and reports 6 passed. The existing dual suite reports 57 tests plus 13 sub-tests passed. The workspace-path tests report 1 passed.

### Rebased verification

Verified after rebasing onto `8f853f99`: the four dedicated engine regressions
pass, and `VIRTUAL_ENV=$VENV CHECK_PY=$VENV/bin/python sh engine/test.sh`
passes all 293 units with exit 0. The log contains no load errors and no
choicepoint warnings. No additional native or dual implementation change was
needed.

Measured again with `PYTHONPATH=extensions/python $VENV/bin/python
ai-tmp/ai-probe-tail-stack.py`: both the expression and statement spelling
retain 120,254/120,254/120,254 inferences at 10,000 recursive steps and
2,400,254/2,400,254/2,400,254 at 200,000 steps under the 8,000,000-byte stack
bound. The nested spelling also completes the 200,000-step stack check;
its three calls report 57,442,545/3,302/2,426 because that two-call-site form
uses existing tabling. Those cold and warm counts are not a deterministic
cost pin. The new log is `ai-tmp/ai-resume-tail-stack.log`, exit 0.

### Explicit regression-space lifetime

The final ownership review found that the six new dual/tail scenarios created
anonymous spaces directly without closing them. They now borrow the existing
`scratch_space` fixture, whose context manager closes the storage after each
scenario. The equations, assertions and fixed stack bound are unchanged.
This applies the same lifetime boundary established by the ordered translator
rule regression; it adds no runtime or engine workaround.

Verified: the complete Python gate after this fixture change reports
3,084 passed, 48 skipped and zero failures, exit 0. The exact tail and separate
status are in `ai-tmp/ai-compiled-vocabulary-3d96d263-python-final.log` and
its `.status` companion. Production code and inference pins are unchanged.
