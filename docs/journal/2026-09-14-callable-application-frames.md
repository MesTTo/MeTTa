# Native application facts for callable argument frames

Goal: preserve Python argument binding when a native callable consumes
positional and keyword collections through a different entry signature.

## 2026-09-14

Tried: fixed native lambda parameters for method and constructor values
preserve a direct literal `Kwargs` argument, but fail seven of thirty-nine
class cases. Default factories lose their evaluation context and native
variadic containers are treated as host tuples. The classes journal records
that rejected replacement and `ai-classes-c34-fixed-methods.log`.

Decided: an optional `(@python-application callable applicator)` record
accompanies the callable's existing `@python-callable` or `@python-binding`
contract. The applicator is a native value taking a positional expression and
an expression of string/value keyword pairs. Signature binding validates the
call; the applicator receives only explicitly supplied arguments. Its own
native program evaluates defaults and materializes parameter collections.
The usual lambda layout remains the meaning when no application row exists.
Multiple application rows refuse rather than choosing an occurrence order.

Lookup reads both records through the same native occurrence query. Directional
subsumption keeps distinct binders distinct. No Python application registry or
copied body is introduced. A forwarded partial composes its captures through
`cons-atom` before calling the current applicator. The original callable image
continues to carry its lexical home and native ownership graph.

Tried: a positional frame headed by `+` reduces during a raw lambda call and
fails an Expression-typed symbol call. Binding each `noeval` frame through
`let` preserves the exact data for both applicator shapes. Command:
`PYTHONPATH=extensions/python $CHECK_PY
ai-tmp/ai-classes-c34-application-frame-probe.py`; log
`ai-classes-c34-application-frame.log`.

The twelve standalone frame witnesses fail before the change: existing
callable bodies run and ignore the new application rows. Command:
`python -m pytest -q -n3 --benchmark-disable --randomly-seed=1125382488
extensions/python/tests/ch03_atoms_and_expressions/test_callable_applications.py`.
Log: `ai-classes-c35-application-before.log`. The matrix covers symbols and
lambdas, written and evaluated images, named and parametric homes, native
rewrites, partial captures, duplicate refusal and scoped streams.

Verified: that command with `test_callable_values.py` and
`../ch11_python_as_a_notation/test_expanded_call_values.py` added passes all
71 cases. The paths are relative to `extensions/python/tests/ch03_atoms_and_expressions/`.
Log: `ai-classes-c35-application-after.log`. `sh tools/check.sh ruff mypy` passes,
in `ai-classes-c35-application-shape.log`.

The keyword-name matrix initially fails `self` with
`NativeCallable.__call__() got multiple values for argument 'self'`; `args`
and `kwargs` pass. The wrapper's receiver is now positional-only. Captured
signature parameters retain their own keyword rule: a positional-or-keyword
capture refuses a duplicate name, while a positional-only capture leaves that
name available to `**kwargs`. The expanded cohort passes all 76 cases. Logs:
`ai-classes-c35-application-keywords-before.log` and
`ai-classes-c35-application-keywords-after.log`.

The initial full cohort passes 1117 cases and fails the host-callee fixture
because an earlier integration test leaves `target` registered with anonymous
parameter labels. The integration witness leaves the same operation present
on pristine `c75181adc999adf0028616ee69565e2bbfbf739f` and on this tree.
Commands: `python ai-tmp/ai-classes-c35-integration-fixture-probe.py` in each
checkout; logs `ai-classes-c35-integration-fixture-ai-call-signature-check.log`
and `ai-classes-c35-integration-fixture-ai-classes-c75181adc-control.log`.
The fixture cleanup is a separate change.
