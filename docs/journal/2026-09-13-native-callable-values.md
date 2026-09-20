# Native callable values through Python conversion

Goal: retain native callable programs and their editable contracts when a
Python value is returned, stored, rebuilt or kept by a scope.

## 2026-09-13

Decided: reconstruct the existing lambda or partial as a value carrying its
native `evalc` home. Application evaluates that value in the engine. Native
`@python-callable` and `@python-binding` records supply the current signature,
captured parameter count and answer cardinality. An evaluated closure recovers
its written lambda from the existing translated source relation. Changes to
the native body or signature therefore govern the next call.

Tried: constructing `Symbol(space.name)` rejected expression identities, and
opening an unknown expression home with `Space(home)` declared it. The named
and parametric home witnesses originally had three failures and two passes
in `ai-classes-c28-callable-homes-before.log`. Carrying the existing Space
handle and checking the native `metta_space_operand` relation before opening
an expression home makes all five pass. The same run passes 38 method
consumers, recorded in `ai-classes-c28-callable-homes-after.log`.

Rejected: stringifying a lexical identity or retaining a Python method body
as the executable program. The native space and source relations already
carry the required meaning and lifetime. Scope retention follows the ordinary
native value graph; stream results use the existing closable selection.
Conversion composes `build` with that cursor, preserving both conversion and
cleanup failures and allowing a failed cleanup to be retried.

Tried: applying a fixed native binder list using `BoundArguments.args` lost
keyword-only and keyword mapping parameters and flattened positional
variadics. The witness returned `(partial lambda_1 (1 2 3))` where it required
four bound parameter values. `ai-classes-c28-lambda-parameters-before.log`
records that failure. Fixed binders now receive the ordered parameter values
from `BoundArguments.arguments`, including defaults. Segment binders retain
the existing native `Kwargs` call syntax. Container storage policy belongs
to storage; passing a parameter borrows its ordinary value.

Tried: conversion of `Callable[[int], list[int]] | None` lost the return
annotation for a lambda, left a partial as an Expression, and left a symbol
as an unevaluated call. The grounded callable passed. These three failures
and one pass are in `ai-classes-c29-callable-union-before.log`. Union
selection now uses the same callable reconstruction as direct conversion.
Native catalogue and visibility membership distinguish a function symbol
from another alternative's symbol, including Enum members. Recursive
conversion passes the lexical context through containers and record fields.

Verified: the following command passes 134 cases after the union repair:

```sh
PYTHONPATH=extensions/python "$CHECK_PY" -m pytest -q -n 3 \
  --benchmark-disable --randomly-seed=1125382488 \
  extensions/python/tests/ch03_atoms_and_expressions/test_callable_values.py \
  extensions/python/tests/ch03_atoms_and_expressions/test_convert.py \
  extensions/python/tests/ch03_atoms_and_expressions/test_p5_annotations.py \
  extensions/python/tests/ch05_equations_and_evaluation/test_evaluation_options.py
```

Log: `ai-classes-c29-callable-union-after.log`. A further source-recovery
witness passes with the same pytest options and selector
`extensions/python/tests/ch03_atoms_and_expressions/test_callable_values.py::test_an_evaluated_bound_lambda_keeps_its_native_signature`.
It evaluates a partially applied native lambda, rebuilds it, then changes
the canonical signature's default and observes the changed result through
the retained callback. Log: `ai-classes-c29-captured-contract.log`.

The initial cleanup fixture used a dataclass reverse hook that its registered
constructor bypasses. Constructor validation supplies the actual rejected
value boundary; its corrected witness passes in
`ai-classes-c28-callable-conversion-after.log`. `sh tools/check.sh ruff mypy`
passes all type checks; the Ruff run reports 32 findings across this work and
the pending method implementation. Import order, slot order, conversion
control flow and the two new fixtures were corrected before partition.
Log: `ai-classes-c29-callable-checks.log`.

The isolated callable tree passes 135 Python cases and native reflection,
Python surface and scope suites with 84 tests plus ten subtests. Commands:
the pytest cohort above and `sh engine/test.sh
tests/prolog/suites/libraries/lib_reflect.plt
tests/prolog/suites/host/python_surface.plt
tests/prolog/suites/libraries/lib_thread_scope.plt`. Logs:
`ai-classes-c29-callable-A-python.log` and
`ai-classes-c29-callable-A-native.log`. Ruff, mypy and evidence pass, but
Python layering rejects the converter's static import of `_spaces.lifetime`.
Log: `ai-classes-c29-callable-A-checks.log`.

Decided: the existing stream selection owns scope enrolment, alongside its
cursor cleanup. The value converter composes that owner. A direct stream
witness reproduces `engine_next/2: engine ... does not exist` after scope
exit on both this tree and pristine `c75181adc`: the native enumerator had
retired while its Python cursor remained open. Logs:
`ai-classes-c29-stream-scope-before.log` and
`ai-classes-c29-stream-scope-control.log`. Both commands use the same pytest
options and selector `test_a_stream_selection_closes_with_its_scope`, in
`test_evaluation_options.py` for the working tree and the copied
`test_stream_scope_probe.py` for the pristine control. Scope registration now
lives in `_Stream` rather than each consumer. A dynamic import would hide
the misplaced ownership without correcting it and was rejected.
