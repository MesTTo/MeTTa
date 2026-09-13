# Defaults over dictionary relations

Goal: compile dictionary get into the native relation while retaining default
evaluation and stored atom values.

## 2026-09-14

The compiler lowers one-argument get directly to get-value, whose absent case
has no answer. The two-argument form falls into a Python island, where the
native space name is a string and has no get method. The focused cohort
passes five cases and fails twenty-two before the repair. Command:
`python -m pytest -q -n 3 --benchmark-disable --randomly-seed=1125382488
extensions/python/tests/ch11_python_as_a_notation/test_dictionary_lookup.py`.
Log: `ai-classes-c36-dictionary-before.log`.

The existing sequence matcher can enumerate every value in a collapsed
answer expression without evaluating that value. The native probe prints
`(+ 1 2)`, None, False and 0 unchanged with a segment on each side of its
selected variable. Command: `PYTHONPATH=extensions/python python
ai-tmp/ai-classes-c36-dict-value-probe.py`. Log:
`ai-classes-c36-dict-value.log`. The executable pattern precedent is
`examples/ch08-data/08-02-sequence-variables/01-segments.metta`.

Decided: bind the key and explicit default in source order, collapse one
get-value query, and choose the default only when that answer expression is
empty. The nonempty branch selects each stored value through a segment
pattern and noeval. An omitted default is the existing grounded None value.
Native relation edits and multiplicity remain visible through the same query.

Rejected: testing the value's truth, which loses False, zero and empty text;
returning the first row, which truncates a native relation; and applying
superpose to data, which can execute an expression-valued entry. A second
dictionary representation or host lookup would duplicate the indexed space.

The first relation-edit fixture incorrectly called one on Space.eval's eager
list and raised `AttributeError: 'list' object has no attribute 'one'`. The
corrected fixture edits a native writer equation before querying the space it
populates. The final 27-case fixture at pristine
c75181adc999adf0028616ee69565e2bbfbf739f passes five cases and fails twenty-two
with the original lookup defects. The same pytest command above produces
`ai-classes-c36-dictionary-fixture-control.log`. With the repair, that fixture
and test_compiled_statements.py pass all 50 cases in
`ai-classes-c36-dictionary-fixture-after.log`.
