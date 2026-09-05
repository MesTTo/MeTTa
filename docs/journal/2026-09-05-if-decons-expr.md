# Conditional expression deconstruction

Goal: provide a held expression test that binds head and tail on success and preserves its fallback on failure.

## 2026-09-05

Tried: three `Space.run` calls with nonempty, empty and symbolic operands returned the entire `if-decons-expr` call unchanged. The eight public evaluator regressions in `tests/prolog/suites/evaluation/if_decons_expr.plt` all failed before implementation.

Decided: follow the reference `if-decons-expr` signature and conditional deconstruction in [Hyperon stdlib](https://github.com/MesTTo/LeaTTa/blob/9afd0a5144f60e9d9195971bbda8ab60a6a2990b/MettaHyperonFull/Minimal/Stdlib.lean#L3169-L3183). Hold every operand, unify a nonempty expression with the head and tail inside the condition, and let the existing result mask evaluate the chosen branch. An unsuccessful condition rolls its bindings back before selecting fallback. The shape check reads one cons cell, preserving constant work in expression length.

Rejected: call `decons-atom` before selecting a branch, because its empty-input error would replace the intended fallback. Rejected: declare the type only in native source, because `the_table_is_built_from_the_file_rather_than_written_twice` requires the loaded type table to come from the shipped library and prelude.

Open: the native body and registry fit under `engine/metta/`; the one-line library signature needs the task's narrow metadata exception before the implementation can be integrated and tested.

### Signature and mask verification

Tried: `(-> Expression Variable Variable Atom Atom %Undefined%)` with the initial native selector. Six of eight provisional regressions passed. `(if-decons-expr (+ 1 2) $h $t $t fallback)` returned `fallback`, because ordinary `Expression` parameters eagerly evaluate in this engine. The reference's held metatype meaning therefore needs this engine's explicit modifier.

Decided: the authorized signature is `(-> (:Atom Expression) (:Atom Variable) (:Atom Variable) Atom Atom %Undefined%)`. The discriminating call now returns `(1 2)`. The selected-result mask still evaluates the chosen branch. The canonical masks are derived from `lib/lib_builtin_types/lib_builtin_types.metta`; `the_table_is_built_from_the_file_rather_than_written_twice` forbids duplicating those declarations in native source.

The native selector sends empty input, an unbound input and failed head/tail unification to fallback. Known non-expression inputs retain the ordinary `BadArgType` answer through `metta_operation_answer`; that recovery was added after the initial signature comparison. Already-bound binders constrain matching, and failed bindings unwind before fallback. These cases are distinct from the unchecked empty `decons-atom` path that previously lost its continuation.

Decided: explicitly classify the selector as `pureStructural`, because its successful native step selects one existing branch and binds structure. The effect planner separately walks both possible result branches. Its regression observes `writesState` for `println!` inside either held branch, and never executes either while planning.

Tried: `swipl -g 'set_test_options([format(log)]), run_tests' -t halt tests/prolog/suites/evaluation/if_decons_expr.plt` after the canonical declaration was installed: eleven tests passed, zero failures, exit 0. Two additional effect regressions previously failed with the unreviewed `oracleIO` default.

Measured: the ten-claim Python twin `16-if_decons_expr.py` costs 17,737 inferences in each of three fresh processes through `twin_coverage.run_twin`, using the same `Space.stats()` measurement harness as the corpus. It matches the paired example's ten claims and stores no hidden definitions.

Open: none for the operation. Full shared branch gates are recorded with the enclosing compiled-vocabulary work.

### Held error and final verification

Tried: a wrong Number input with `(Error bad held)` as the unselected success branch. The generic `metta_operation_answer` recovery returned that held error, replacing the input's type refusal. The new regression failed with `[['Error',bad,held]]` instead of the expected `BadArgType` result.

Decided: ask `metta_bad_argument_error` directly on the invalid-shape path. Its soft cut preserves declared refusal alternatives; an undecided non-expression stays unreduced, following this engine's ordinary partial-call contract. No held branch is interpreted as an already-produced error. All twelve dedicated tests pass after this correction. The ordinary runtime suite passes 246 tests plus 137 subtests, and the effects suite passes 22 tests.

Measured: the corrected twin costs 17,718 inferences in each of three fresh processes. The earlier 17,737 pin records the initial generic-error recovery and is superseded by this measurement. After source regeneration, one first sample was 17,715; the next five were 17,718. The published pin uses the three consecutive identical fresh-process samples after artifacts settled.

Verified: the twin coverage lane proves all ten paired claims, compares equal stored content and reports zero findings. The phrasebook row now executes both sides and returns `(yes a (b))`; its frozen answer and generated page were refreshed for this row only. The phrasebook/input-guard pytest subset passes 29 tests. The workspace path regression passes, Ruff reports no findings, and jscpd reports zero clones in the changed native files and new regression/twin files.


### Python spelling and corpus cost

The settled source-image measurement changed the MeTTa counterpart to 15,412
inferences, exposing the direct-call twin at 17,716 above its 16,953 ceiling.
A throwaway `m.eval` spelling cost 17,262/17,262/17,262 and still failed the
ceiling, so changing to that less direct spelling was rejected.

The phrasebook already states the idiomatic structural spelling: Python starred
unpacking. The twin now uses `head, *tail = expression` for its ordinary
nonempty structural claim and retains native calls for the continuation,
held-expression and refusal claims. This removes an unnecessary engine crossing
for data already held in Python. It does not weaken a compiled engine path or
add workload to dilute the cost ratio.

Final twin: 16,863/16,863/16,863 inferences in three fresh processes;
`BUDGET = 16863`. This supersedes the preceding direct-call pins. Its ten claims
remain unchanged.

Final verification after the Python spelling change: twelve dedicated tests,
246 runtime tests plus 137 subtests, 22 effect tests and the combined 30-test
Python subset pass. Twin coverage measures 15,414 source inferences against
16,863 twin inferences, ratio 1.09, ten claims proved, equal store and zero
findings. Three fresh final twin processes each measure 16,863 inferences.

### Rebased contract audit

The held-argument mask is derived from the canonical
`lib/lib_builtin_types/lib_builtin_types.metta` file, and
`tests/prolog/suites/evaluation/metta.plt:1554`'s
`the_table_is_built_from_the_file_rather_than_written_twice` exists precisely
to stop a second copy of a type fact appearing in `engine/metta`. A constraint
that forbade the canonical file would have forced the duplication that test
forbids. This is why the signature lives in the library.

The neighboring `atom-subst` declaration already uses `(:Atom Variable)` for
an operand consumed as structure. `engine/translator/typing.pl`'s
`non_evaluated_parameter_type/1` implements this policy. The rejected plain
signature and its `fallback` measurement above preserve the counterexample;
`the_operand_is_inspected_without_evaluation` keeps the discriminating
`(+ 1 2)` call and requires its written tail `(1 2)`.

Verified after rebasing onto `8f853f99`: an unknown symbol leaves its call
unreduced; a String or Bool produces `BadArgType 1 Expression String` or
`BadArgType 1 Expression Bool`, respectively. The undeclared symbol has no
type evidence that justifies either a destructuring success or a type refusal,
so it follows the existing partial-call policy. A new regression pins that
boundary. The effect regression now puts `println!` in each branch separately,
so it detects omission of either branch from the planner's walk.

Verified: `VIRTUAL_ENV=$VENV CHECK_PY=$VENV/bin/python sh engine/test.sh`
passes all 293 units, including thirteen `if_decons_expr` tests and four
`case_dual_patterns` tests, with zero load errors and zero choicepoint
warnings. The separate captured exit status is 0 in
`ai-tmp/ai-resume-engine-full.status`; the complete log is
`ai-tmp/ai-resume-engine-full.log`.
