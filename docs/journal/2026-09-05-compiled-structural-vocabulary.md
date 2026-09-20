# Compiled structural vocabulary

Goal: preserve structural bindings, ordered generator cases, empty-answer dispatch, answer collection and engine metatypes in compiled Python.

## 2026-09-05

Tried: public definition probes at e7cc36d2. Nested tuple assignment and generator match refuse; match over an empty subject returns no answers; type of an engine symbol returns a grounded Python class. list(superpose(...)) enters a host island and raises NameError. The regression file initially reports 12 failures and one passing control. Commands and outputs are retained in ai-tmp/ai-vocabulary-probes-before.log and ai-tmp/ai-vocabulary-regression-before.log.

Decided: reuse the existing structural pattern compiler and SSA binder for tuple/list assignment. Compile the right side before changing any target, retain native-number and container proofs from literal right sides, and test error results before destructuring inside a try body. Pattern mismatch follows the engine's relational let semantics and answers nothing.

Decided: generator branches share the existing ordered case lowering, with a continuation that compiles later statements in the selected branch's scope. A raise closes that path. This follows CPython 3.14.0 Python/codegen.c, codegen_match_inner: evaluate the subject once, install captures before the guard, skip an entire arm on guard failure, then execute the selected block. The existing engine case remains the pattern selector. Reference: https://github.com/python/cpython/blob/v3.14.0/Python/codegen.c#L6376 . The sequence/capture correspondence is also specified by https://peps.python.org/pep-0634/ .

Rejected: keep the subject in an ordinary let before selecting an Empty arm, because that let prunes an answerless source. Decided: an outer case evaluates the source once and selects the explicit Empty continuation only on absence. Ordinary answers enter the existing ordered tower. An unmatched value never takes the Empty branch.

Decided: list of a statically known engine answer stream lowers to collapse. A host iterable, including range, keeps its ordinary list value. The distinction reuses nondeterministic call metadata already used by for and yield-from. Explicit collapse collects an ambiguous engine expression; binding its result first and applying list to that binding collects returned data. Explicit py preserves a requested host evaluation.

Decided: unshadowed one-argument type uses get-metatype in compiled notation; py(type(value)) retains the host query. A shadowed type or the three-argument host class constructor remains host behavior. get-metatype retains the engine's held-operand semantics.

Tried: S[","] patterns at match produce the expected joined pair; S.case(value, arms) accepts runtime branches and S.case(empty(), arms) selects Empty. L039 and L045 are WRONG, and their existing behavior is retained as regression controls. L034, L041 and L043 retain the caller's measured WRONG verdicts without repeating that investigation.

Tried: moving the structural let after an if-error test still returned no answers for a caught source failure. The generated Prolog showed both branch operands evaluating before if-error. A reference-signature probe held the operands but returned the selected branch as data, so changing its signature would also change existing direct-subject behavior. Rejected: change if-error's semantics to serve statement lowering. Decided: select the error path with the existing lazy case and the `(Error ...)` pattern, which recognizes an Error expression of any arity. Four probes over Error expressions of zero through three payloads selected the error arm; ordinary data selected the continuation. The structural binding occurs only in that continuation.

Tried: the first generator guard regression referred to a variable rebound in the arm, because the guard compiled after the body had advanced SSA. Decided: compile the guard immediately after its pattern and before its body, following codegen_match_inner's capture-then-guard-then-body order. The guard now reads the captured value while later yields see the reassigned value.

### Value proofs and argument evaluation

Tried: fresh review found three additional discriminating failures. `type(1 + 2)` classified the unevaluated addition as Expression, starred assignment lost dictionary and native-number proofs at either end of its sequence, and a declared-global unpacking target silently became a local. The three regressions in `ai-tmp/ai-vocabulary-review-before.log` failed before repair; all eighteen vocabulary regressions then passed.

Decided: evaluate a computed type operand once in a let before calling the held get-metatype operation. A variable or atomic value needs no extra binding. This supersedes the earlier decision to retain held syntax for arbitrary Python type operands: Python evaluates call arguments before applying the call.

Decided: align literal source fields with target prefixes and suffixes around a starred middle, including an empty middle. Propagate the existing number, container, dictionary and space proofs only from aligned literal fields. A target declared global refuses with the remedy to capture into local names and then assign globals explicitly, so it cannot silently change the assignment's destination.

Measured: after rebasing onto 8f853f99, `ai-tmp/ai-vocabulary-costs.py` records three identical warmed inference samples for each spelling. Compiled list collection and explicit collapse both cost 151; structural unpacking and explicit let* both cost 203; a compiled Empty branch costs 117 versus 119 for the flat explicit case; compiled type and explicit get-metatype both cost 140. The sample evaluates lazy results inside Space.stats().

### Ordered tables and nested aliases

Tried: migrating the existing caseempty twin to Python match produced a redundant subject binding and nested case tower. The original engine example is a flat ordered table. A source-equivalence regression failed, and a nested pattern `((1, item) as pair, marker)` returned the fallback because `pair` incorrectly received the entire outer subject. Both regressions failed in `ai-tmp/ai-match-shape-before.log` and passed after the repair; the combined vocabulary/join/dual suite passed 37 tests.

Decided: emit the engine's existing first-match table directly when no guard or alias requires another pattern test. `engine/translator/runtime.pl:translate_case/5` already performs ordered row selection; `case_default_pair/3` separates the absence branch before key evaluation. The compiler therefore preserves the executable textbook form rather than rewriting the textbook to match a redundant tower.

Decided: an as-capture occupies its own structural position in the outer pattern. Its nested subpattern is checked before the guard, with pattern failure continuing to the next OR alternative and guard failure continuing past the entire arm. This follows the stack discipline of CPython's `codegen_pattern_as`: retain the value at the current pattern position, not the root subject. Explicit nested match tests preserve the case-dual tower witness now that simple tables no longer manufacture a tower.

### Alias constraints share the pattern decision

Tried: the delayed nested checks above leaked constraints from a failed
pattern. Given `((3, 0), $sibling)`, the pattern
`((1, item) as pair, 2)` returned the fallback with `$sibling` bound to 2.
The same pattern without its alias preserved the variable. A failed alias
also prevented a later OR alternative from matching, because that alternative
received the constrained subject. Three new regressions failed; the explicit
Empty-alias control passed. The log is
`ai-tmp/ai-alias-rollback-before.log`, exit 1.

Decided: make every alias equation part of one product pattern at the existing
case door. For that example, the key is `(noeval ($subject $pair))` and the
pattern is `(($pair 2) (1 $item))`. The native case decision unifies the whole
product before committing. A failure therefore unwinds all tentative source
bindings. `noeval` keeps the product and original subterms held, including
terms headed by executable symbols. This uses
`engine/translator/runtime.pl:translate_case/5` and its existing matcher;
no engine operation or alternate matcher was added. The relevant control
rule is [SWI-Prolog's conditional commit](https://www.swi-prolog.org/pldoc/man?predicate=-%3E/2),
applied to one structural unification rather than several committed tests.

Rejected: use `unify` as the selector, because its custom matching, numeric
promotion and branch reduction differ from case. The executable chapter
`examples/ch04-spaces-and-matching/04-02-patterns-and-bindings/07-unify.metta`
states those semantics. Rejected: match the full inner pattern first and
reconstruct each alias with `noeval`, because a starred pattern contains
`(:seg $rest)` syntax rather than the original sequence of children.

Tried: the first product ordered nested alias constraints from inner to
outer. A nested starred pattern then saw an unbound alias before its original
subterm arrived and exposed `($metta_seg (4 5) named)` in the captured value.
The existing nested-star regression caught this. The product now orders outer
alias constraints before inner ones, following their data dependencies, so
every segment pattern inspects its original subterm. Captured variables retain
their identity, and failed sibling bindings remain distinct variables.

Verified: the combined vocabulary, generator-join and case-dual regressions
pass all 42 tests, exit 0, in `ai-tmp/ai-alias-rollback-after.log`. Ruff passes
for both changed Python files. Separate ground dual probes negate true,
false and unmatched alias cases correctly. Existing false-guard constraint
retention on nonground inputs was reproduced on unchanged `8f853f99`; this
repair preserves that established guard behavior while fixing pattern failure.

Measured: after materializing each function's deferred metadata through
`m.fn[name].compiled`, the compiled alias, a minimal explicit product case,
and an exact source clone each cost 246/246/246 inferences. The log
`ai-tmp/ai-alias-cost-final.log` includes their compiled clauses. Earlier
246-versus-241 comparisons mixed materialized and deferred metadata and are
discarded. Ordinary patterns retain their previous flat-table or tower form;
only alias patterns use the product.

### Final measurements with the complete backend configuration

Measured: `ai-tmp/ai-vocabulary-costs-final.log` supersedes the earlier counts
from the worktree without MORK. Compiled list collection and explicit
collapse both cost 153/153/153; structural unpacking and explicit let* both
cost 205/205/205; the compiled Empty branch costs 119/119/119 against the
explicit case's 121/121/121; compiled type and explicit get-metatype both
cost 142/142/142. Each measurement forces the answers inside `Space.stats()`
with the same C artifacts and MORK backend loaded.


### Process-wide callback ownership in the vocabulary regressions

Tried: the final full Python gate reported one failure in the unchanged admission-route test. Its error said the hook did not cover `[plain,1]`, and a warning identified plain as a functional head pattern. A read-only pytest transition trace located the plain registration in the existing typed-flat-call test. Running that test before admission still passed, including with cyclic collection disabled. The registration and warning were incidental to the failure.

Tried: the exact ordered pair `test_as_pattern_or_retry_commits_only_the_complete_selected_alternative` followed by `test_public_space_add_observes_every_pre_add_verdict` reported `1 failed, 1 passed`, exit 1. The new alias test's `@m.op` callback named accept remained globally registered after its anonymous space dropped, replacing the admission `(accept)` verdict with a one-argument Python operation. The resulting message was `the pre-add hook on &pyspace_1 is claimed by route-guard-f00621d7, whose equations do not cover [plain,1]; a request no rule covers is a stuck state that says so, so cover the shape or give the handler its own catch-all`. The absence of a verdict caused the uncovered-input refusal; no definition of plain is needed to reproduce it.

Verified on unchanged `8f853f992a4c732eca39de34ff0a3dfe161508dd`: register the same callback in an anonymous space, drop the space, then run the admission test. It raises the same refusal. Calling public `unregister_op("accept")` restores every admission verdict. `ai-tmp/ai-admission-registration-baseline.log` records both observations, exit 0. This is the documented separation between storage lifetime and process-wide registration lifetime, not a new engine failure.

Decided: the three vocabulary tests that acquire process-wide callbacks own their release. Finally blocks call `unregister_op` for source, operand and accept, including when compilation or an assertion fails. Callback names and production behavior remain unchanged. This follows the existing operation lifetime cleanup in `test_ops.py`; an arbitrary rename would only conceal the leak.

Verified: `PYTHONPATH=extensions/python $VENV/bin/python -m pytest -q -p no:benchmark -n 0 extensions/python/tests/ch11_python_as_a_notation/test_compiled_vocabulary.py extensions/python/tests/ch15_writing_transactions_and_worlds/test_admission_routes.py` reports 31 passed, exit 0, in `ai-tmp/ai-admission-ordered-after.log`. Ruff accepts the changed file. The implementation and engine image did not change, so previously measured example budgets remain applicable.


### Retirement of the typed-flat test's global translator rule

Tried: a broader ordered diagnostic also exposed `test_a_rule_owned_head_obeys_its_orientation_through_the_flat_door` followed by `test_structural_assignment_preserves_dictionary_and_star_bindings`. The first test leaves a global unpack translator rule owned by its still-live anonymous space. The second test's singleton unpack returned `(unpack (1))` instead of `(1 ())`. `ai-tmp/ai-unpack-fixture-before.log` records `1 failed, 1 passed`, exit 1.

The fixture's bare `return MeTTa().space()` dates to `fd9ee4a4f` by MesTTo, as `git blame` against the fixed baseline confirms. The fixture claimed isolation but did not release its owned space. `engine/translator_rules.pl:retire_translator_rules_in/1` already retires global rules when their owning module is released; no engine change is needed. Source ownership is part of the registered rule rather than the module of whichever test happens to compile next.

Decided: yield the fixture value within managed MeTTa and Space contexts. The differential test's additional wildcard-control context uses the same deterministic lifetime. This retains each original test's separate anonymous home and exercises the existing release path, including on assertion failure. The fixture finalization pattern follows pytest 9.0's documented yield-fixture teardown: https://docs.pytest.org/en/9.0.x/how-to/fixtures.html#teardown-cleanup-aka-fixture-finalization .

Verified: `PYTHONPATH=extensions/python $VENV/bin/python -m pytest -q -p no:benchmark -n 0 extensions/python/tests/ch09_types/test_typed_flat_calls.py extensions/python/tests/ch11_python_as_a_notation/test_compiled_vocabulary.py extensions/python/tests/ch15_writing_transactions_and_worlds/test_admission_routes.py` reports 36 passed, exit 0. Evidence is `ai-tmp/ai-unpack-fixture-after.log`. Ruff accepts both changed test files and `git diff --check` exits 0. The callback cleanup and fixture teardown repairs preserve all operation and equation names rather than avoiding the namespace collision.

### Aggregate verification

Verified: `CHECK_PY=$VENV/bin/python sh extensions/python/test.sh` reports
3,084 passed, 48 skipped and zero failures, exit 0. `sh engine/test.sh` passes
all 294 units, exit 0. `sh tools/check.sh ruff artifact-paths benchmarks` passes
all three gates, including all 35 counter benchmarks and zero artifact-path
findings, exit 0. Logs and separate statuses are under `ai-tmp/` with the
`ai-compiled-vocabulary-3d96d263-` prefix. The final source/twin comparisons
prove 28 claims and identical stored content across five examples, each with
three identical fresh-process budget samples. The complete per-row evidence
is `ai-tmp/ai-compiled-vocabulary.md`.
