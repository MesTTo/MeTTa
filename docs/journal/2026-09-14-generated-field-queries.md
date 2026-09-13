# Evaluating generated field queries

Goal: a generated getter returns the stored atom while preserving the native
evaluation rules for authored functions.

## 2026-09-14

An Atom result arrow quotes an equation's body. Generated entity, prototype
and class-variable getters use a match body, so that arrow returns the query
itself. Expression and Annotated Atom result arrows execute the query and
return its stored value. The native probe compares those arrows and Undefined
against the same field containing `(+ 1 2)`. Command:
`PYTHONPATH=extensions/python python ai-tmp/ai-classes-c35-metatype-getter-probe.py`.
Log: `ai-classes-c35-metatype-getter-complete.log`.

Decided: project a generated query's literal Atom result type to Undefined.
Both admit every atom; Undefined lets the query execute before returning its
data. Keep stored-field annotations, writer parameter types, refinements and
value-grain positional getter arrows. Class-variable getters query a space
in every grain and use the same projection.

Rejected: an extra eval on every getter result. The probe reduces an already
returned `(+ 1 2)` to 3. Changing the interpretation of authored Atom-returning
functions would change the native language instead of correcting the generated
query's contract.

The query regression covers 27 field and ClassVar cases across three grains,
with Atom, Expression and Annotated Atom declarations. It also checks stored
symbols, numbers, None and mutable replacement. Before the repair, eleven
cases return a match expression and sixteen pass. Command:
`python -m pytest -q -n 3 --benchmark-disable --randomly-seed=1125382488
extensions/python/tests/ch09_types/test_class_atom_fields.py`. Log:
`ai-classes-c36-atom-field-queries-before.log`.

The first fixture used an unsupported decorator factory and then a protected
native name, read. Those fixture errors are recorded in
`ai-classes-c36-atom-fields-before.log` and
`ai-classes-c36-atom-fields-fixture-before.log`. The final fixture declares
the class explicitly and uses distinct observer names.

Open: the earlier constructor-based fixture also exposed value crossings
that evaluate expression data before storage or receiver access. Preserve
that fixture separately in `ai-classes-c36-value-boundary-tests.py`; this
query test reconstructs or writes the stored value and quotes the native
receiver. The input probe shows why: Expression and refined Atom inputs
evaluate written expressions, while a value bound by let/noeval survives
all three input contracts. A written `(SyntaxDatum (+ 1 2))` also evaluates
its field, whereas a quoted receiver preserves it. Command:
`PYTHONPATH=extensions/python python ai-tmp/ai-classes-c36-metatype-input-probe.py`.
Log: `ai-classes-c36-metatype-input-complete.log`. The Python value boundary
needs its own repair; the query projection does not claim to repair it.

After the query repair, the field-query, field-value, construction and grain
cohort passes 80 tests. Command:
`python -m pytest -q -n 3 --benchmark-disable --randomly-seed=1125382488
extensions/python/tests/ch09_types/test_class_atom_fields.py
extensions/python/tests/ch09_types/test_class_field_values.py
extensions/python/tests/ch09_types/test_class_construction.py
extensions/python/tests/ch09_types/test_class_grains.py`.
Log: `ai-classes-c36-atom-field-queries-after.log`.

The same fixture at pristine c75181adc fails all 27 cases because that cut
predates the grain implementation, including the generated class-variable
queries and scoped type ownership. It cannot isolate the later query defect;
the eleven failures on the preceding functional tree do. The separate
metatype-input probe agrees at the cut and the current tree. Logs:
`ai-classes-c37-query-control.log`,
`ai-classes-c36-metatype-input-control.log`.
