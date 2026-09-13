# Constructor values and computations

Goal: preserve supplied and default atom data while executing default factories
before typed initialization and field storage.

## 2026-09-14

Tried: a typed initializer receives a written expression directly. Atom inputs
quote it, so an Atom factory does not run; Expression and refined Atom inputs
evaluate it, so supplied `(+ 1 2)` becomes 3. Binding each computation through
let before passing its value preserves all nine grain/type combinations for
supplied arguments and factories. Literal defaults still reduce in all nine
cases. Command: `python ai-tmp/ai-classes-c37-class-values-probe.py bound`.
Log: `ai-classes-c37-class-values-query-fixed-bound.log`. The earlier logs
without query-fixed also include the independently repaired getter defect.

Decided: argument_sources describes computations. Explicit values and literal
defaults use noeval; factory defaults remain executable native terms. One
application builder evaluates each source through let and passes its bound
value to the typed native entry. Keyword-pair collections use the same value
binding before dict-space materialization. Default field computations also
finish before their results enter writers or subsequent initialization steps.
Python calls, compiled class calls and native default arities share that rule.

Rejected: quoting every parameter expression, because factories would remain
data. Evaluating every raw expression reduces literal defaults. Changing the
native meaning of Atom would alter authored metaprograms. The native input
probe agrees with pristine c75181adc; the mismatch belongs to construction's
generated value flow.

Before the repair, the 162-case matrix fails 66 cases and passes 96. It crosses
three grains, three atom annotations, Python/compiled/native entry and six
argument/default forms, including fields excluded from __init__. Command:
`python -m pytest -q -n 3 --benchmark-disable --randomly-seed=1125382488
--tb=short extensions/python/tests/ch09_types/test_class_argument_values.py`.
Log: `ai-classes-c37-class-arguments-before.log`.

After the repair, that matrix plus the existing construction and field-value
suites passes all 206 cases. The same command adds
`extensions/python/tests/ch09_types/test_class_construction.py` and
`extensions/python/tests/ch09_types/test_class_field_values.py`.
Log: `ai-classes-c37-class-arguments-after.log`.

The ordering witness records argument, factory and post-init effects through
all three entries and grains. The expanded fixture passes 171 cases;
layering, Ruff, mypy and evidence checks pass. Commands: the fixture command
above, then `sh check.sh layering ruff mypy evidence`. Logs:
`ai-classes-c37-class-arguments-order.log` and
`ai-classes-c37-class-arguments-shape.log`.
