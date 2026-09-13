# Python call values at native entries

Goal: pass computed Python argument values into native functions without
executing their data as source a second time.

## 2026-09-14

Tried: Defined and NativeCallable construct raw native applications from their
encoded arguments. All nine value-grain receiver cases reduce a stored
`(+ 1 2)` to 3 or fail its Expression/refinement contract. Eighteen mutable
receiver cases pass. A native let/noeval control preserves all twenty-seven
receiver values. Command: `python -m pytest -q -n 3 --benchmark-disable
--randomly-seed=1125382488 --tb=short
extensions/python/tests/ch09_types/test_class_receiver_values.py`.
Log: `ai-classes-c38-receiver-before.log`.

The corresponding syntax-argument matrix fails eight cases and passes one
across three input annotations and three callable entries. The same command
with `-k python_call_values` selects those nine cases. Log:
`ai-classes-c38-argument-values-before.log`. Each fixture first verifies the
native source/value distinction with a quoted value binding.

Decided: use the constructor source-binding rule at the Python callable
boundary. The existing application builder moves to call_values.apply_sources;
constructors, field setters and callable applications share it. Binding each
computation to a fresh native variable before applying the entry is the
ordinary administrative binding used in an A-normal form. Supplied Python
values use noeval computations; constructor factories retain executable
computations. No engine evaluator or argument type changes.

Rule-variable calls still stage the written term. Ground rule calls evaluate
their supplied values and fold only one answer; zero or multiple answers
retain the written term. Native callable applicators retain their two data
frames, while an ordinary callable receives its reflected parameter values.

Rejected: quote only frozen record arguments, because plain syntax arguments
have the same defect. Rewriting Atom's native meaning would change authored
metaprograms. Copying the constructor binder would add a second description
of the same native let composition.

Python's call rule evaluates argument expressions before invoking a callable:
[language reference](https://docs.python.org/3.14/reference/expressions.html#calls).
The source/value distinction is measured in the native controls above; the
native function-namespace door and explicit space evaluation keep their
existing source semantics.

Outer bindings alone pass 298 cases and fail ten native callable cases in
the combined constructor, field, callable and staging cohort. The lexical
evalc wrapper receives a substituted term and evaluates its arguments as
source again. This follows translate_special_dl(evalc, ...) and
metta_evalc_step/3. Log: `ai-classes-c38-call-values-after.log`.

Tried: remove a lambda's evalc wrapper when its home is already selected.
The probe passes 76 callable cases, `ai-classes-c38-call-home-probe.log`.
Rejected: that changes the explicit evalc boundary and does not cover an
applicator pointing to another home. The foreign-home frame probe fails with
`one() expected exactly one answer, got 0`,
`ai-classes-c38-foreign-application-before.log`.

Decided: retain the original lambda parameters and evalc home expression.
Rename the parameters' occurrences in the carried body to fresh variables,
then bind those variables from quoted matched values inside evalc. Parameter
patterns, segment binding, home selection and the evalc guard keep their
positions. Atom.subs supplies the existing simultaneous tree substitution.
No new native form or fixed-arity replacement is needed.

The rebinding probe passes the foreign-home frame and all 76 callable cases,
`ai-classes-c38-call-rebinding-direct.log`. An earlier version inserted an
extra inner lambda and also passed; direct let bindings express the same
value flow with fewer forms. Command:
`python ai-tmp/ai-classes-c38-call-rebinding-probe.py`.

The combined cohort passes 315 tests after rebinding, including seven new
foreign-home, patterned and segment cases. Log:
`ai-classes-c38-call-values-rebound.log`. Ruff and layering pass. Mypy
requires the known nonempty call head to be held as a Symbol rather than
read through Expression.head's optional type. The evidence scan also needs
the new fixture in Git's index before it can discover its names. Both are
pre-commit verification findings; `ai-classes-c38-call-values-shape.log`
records their exact diagnostics.

The full callable A run passes 1,659 Python cases and fails the existing
endless-producer cost check: Defined costs 930 inferences against the native
take expression's 624. Native suites pass 245 tests and 52 subtests, and
layering, Ruff, mypy and evidence pass. Five production files contain 2,889
lines and no clones. Commands and logs: `ai-classes-c38-call-values-A-*`.
The exact failing Python test passes on pristine c75181adc999adf0028616ee69565e2bbfbf739f,
`ai-classes-c38-call-cost-control.log`. Its command is the same pytest
selection below with only the endless-producer test, run in the cut archive.

The added let/noeval around an already literal argument forces a general
expression cursor instead of the direct named-function cursor. Decided:
propagate native variables and nonsymbol literals through apply_sources.
The wire decoder's v/n/g/o/h tags provide those shapes, and
translate_eager_argument_dl already leaves them unchanged. Retain bindings
for expressions and atoms, including Boolean and named-space tags, since
scalar equations can rewrite them. Argument assembly remains linear in the
number of arguments; the repaired cost is the unnecessary general-cursor
dispatch, not an asymptotic claim.

Nine additional cases install and remove two scalar rules on symbols and
booleans, comparing explicit native source calls with Python argument calls
through Defined, named callable and lexical lambda entries. All 46 focused
cases pass, including the cost regression. Command: `python -m pytest -q
-n 3 --benchmark-disable --randomly-seed=1125382488 --tb=short
extensions/python/tests/ch09_types/test_class_receiver_values.py
extensions/python/tests/ch11_python_as_a_notation/test_library_fixes.py::test_function_calls_suspend_endless_producers`.
Log: `ai-classes-c39-call-literals-corrected.log`. The first fixture used
Space.add as a context manager, although it returns None; its nine failures
are fixture errors, corrected to add/remove, `ai-classes-c39-call-literals.log`.

The standalone existing cursor fixture, observed at its return with
`python ai-tmp/ai-classes-c39-call-cost.py`, records native take616,
function handle273 and Defined358 inferences. The observer reads completed
Stats objects and does not add native calls inside a measured interval.
Log: `ai-classes-c39-call-cost.log`, exit0. These are the standalone process
deltas; the pytest process above has its own instrumented baseline.

The complete corrected run at 2028f851a316b2fd0e4a01c29f951028a504aaba
passes 1,669 Python tests and 245 native tests with 52 subtests. Layering,
mypy and evidence pass; 2,905 lines in five production files have no clones.
Ruff's two FBT003 findings are positional Boolean payloads in the new test.
They use keyword payload spelling before the final evidence snapshot.
Commands and logs: `ai-classes-c39-call-values-A-*`.
