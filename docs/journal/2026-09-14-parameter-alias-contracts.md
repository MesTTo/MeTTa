# Checked contracts across variable bindings

Goal: retain an established parameter contract through native variable
bindings while preserving live program rewrites and runtime refusals.

## 2026-09-14

Measured: a typed caller forwarding its parameter through `let` or `chain`
costs `133*n+2` inferences, against `5*n+2` for forwarding the parameter
directly. The repeated check walks the constructor's type after the emitted
unification aliases the parameter to another variable. The static parameter
environment names only the original variable.

Command: `sh engine/test.sh
tests/prolog/suites/translator/parameter_aliases.plt`, with
`METTA_CHILD_CEILING=0`, after deleting engine and library `.qlf` files.
`ai-classes-c42-alias-warm-before.log` records counts at 100, 1000 and 10000
calls, one failed cost test and five passing behavioral tests. A pristine
`c75181adc999adf0028616ee69565e2bbfbf739f` control with the same test file also
fails the cost comparison in `ai-classes-c42-alias-warm-control.log`.
Its direct and aliased costs are `6*n+2` and `134*n+2`, the same extra 128
inferences per call. Two error-payload tests also fail there because a typed
result drops the inner Error, a behavior repaired earlier in this branch.

Decided: copy an existing parameter proof across the binding's equality for
the continuation only. Preserve its owner and declaration identity, deduplicate
already known proofs, and restore the outer environment on exit. Both binding
directions establish the same equality. A computed value receives no proof
unless the equality actually connects it to a checked variable.

The existing implementation follows [soft contract verification](https://doi.org/10.1145/2628136.2628156)
in `engine/translator/typing.pl:static_parameter_proof_goal/3`. Extending that
environment preserves its owner guard, discharge audit and policy invalidation.
No runtime alias table or second type checker is needed.

Rejected: omit Python operand bindings, because native handwritten aliases
have the same defect and operand sequencing preserves Python evaluation order.
Rejected: unify source variables during translation, because a sibling branch
can run without the binding and must retain its independent argument check.

Verified: the six native regression cases pass in
`ai-classes-c42-alias-after.log`. Both aliases now equal the direct call at all
three sizes. The suite also exercises nondeterministic operands, reverse
bindings, unrelated values, sibling branches, removal of the enclosing arrow,
replacement of the callee arrow, and a changed typing policy.

The extended native command adds `check_commits.plt`, `translator.plt`,
`constructors.plt`, `refinements.plt` and `union_types.plt`; it passes 317 tests
and 127 sub-tests in `ai-classes-c42-alias-native.log`.

The Python consumer command passes 1707 cases in
`ai-classes-c42-alias-python.log`: `python -m pytest -q -n 6
--benchmark-disable --randomly-seed=1125382488
extensions/python/tests/ch03_atoms_and_expressions
extensions/python/tests/ch09_types
extensions/python/tests/ch11_python_as_a_notation
extensions/python/tests/ch05_equations_and_evaluation/test_reload.py
extensions/python/tests/ch14_seeing_your_program/test_source_observation.py
extensions/python/tests/ch14_seeing_your_program/test_features.py::test_every_public_write_door_honours_the_execution_scopes
extensions/python/tests/repository/test_layout_projections.py
extensions/python/tests/ch19_spaces_backed_by_anything/test_restricted_space.py`.

`sh check.sh layering ruff mypy evidence` passes in
`ai-classes-c42-alias-checks.log`. `jscpd --format prolog --formats-exts
prolog:pl,plt --min-lines 8 --min-tokens 80 --max-lines 10000 --max-size 1mb
--no-gitignore --noTips --reporters console,json --output
ai-tmp/ai-classes-c42-alias-clones engine/translator/typing.pl
engine/translator/special_forms.pl
tests/prolog/suites/translator/parameter_aliases.plt` scans all three files,
3366 lines, and finds no clones.
