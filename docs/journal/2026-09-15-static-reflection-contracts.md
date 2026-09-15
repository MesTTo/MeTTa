# Static contracts for runtime reflection

Goal: preserve native annotation and callable data while making its Python
construction and validation explicit to static checking.

## 2026-09-15: runtime annotation alternatives

Observed: `python -m ty check --python /home/user/Dev/.venv-pypetta
metta/_catalog/annotations.py metta/_catalog/call_signatures.py
metta/_catalog/call_values.py`, run from extensions/python, reports five
diagnostics. The runtime_type_atoms return joins list[Expression] with
list[Atom] before checking the declared invariant list[Atom]. Three other
diagnostics treat dynamic Literal/Annotated subscriptions as type syntax;
the last loses the earlier Variable validation of forwarded binders.
Log: `ai-tmp/ai-classes-c56-ty-before.log`. Those providers are unchanged from
the earlier attribution against pristine c75181adc, which passes the lane.

Decided: use the existing type_atoms_for branch shape for runtime refinements.
Returning each branch separately gives the list expression its declared
element context. Both branches keep their values and ordering. No cast,
suppression, new annotation representation or runtime validation is needed.
The callable subscription and forwarding repairs remain separate commits.

Verification plan: run the annotation file through ty and mypy; exercise
container, callable, mapping and class-field refinements through the existing
consumer cases; check Ruff, evidence and layering; review local clones.

Verified: ty and mypy each pass on metta/_catalog/annotations.py from
extensions/python. The following root command passes 145 existing cases:

```sh
python -m pytest -q -n 0 --benchmark-disable --randomly-seed=1125382488 \
  extensions/python/tests/ch11_python_as_a_notation/test_container_call_types.py \
  extensions/python/tests/ch09_types/test_mapping_spaces.py \
  extensions/python/tests/ch09_types/test_refinements.py \
  extensions/python/tests/ch09_types/test_class_field_values.py \
  extensions/python/tests/ch09_types/test_refined_protocol_types.py \
  extensions/python/tests/ch09_types/test_refined_unions.py
```

`sh check.sh ruff evidence layering` passes, with four pending pins and no
unbacked evidence. `jscpd --reporters json --output ai-tmp/ai-classes-c56a-clones
--max-lines 10000 --max-size 1mb --formats-exts 'python:py' --format python
--no-gitignore --noTips extensions/python/metta/_catalog/annotations.py
extensions/python/metta/_declare/field_values.py` finds no clones. Logs use
`ai-tmp/ai-classes-c56a-{ty,mypy,python,checks,clones}.log`.

## 2026-09-15: reflected annotation subscription

The native record contains computed values and a Python annotation constructor.
Literal and Annotated subscription syntax is also a static type form, so ty
rejects those computed arguments before the runtime protocol can act.

Decided: operator.getitem applies that existing runtime subscription protocol.
CPython v3.14.4 implements it as a direct PyObject_GetItem call in
[Modules/_operator.c:_operator_getitem_impl](https://github.com/python/cpython/blob/v3.14.4/Modules/_operator.c#L528-L542).
The captured source is `ai-tmp/ai-classes-c56-cpython-operator.c`, SHA256
ed0328cd2c57da1b95b23b66f8dde3baa378077bf023c69c251a95381a33bc07.
Argument tuples, metadata identity and constructor refusals remain unchanged.
The ordinary generic-application branch already carries a runtime constructor.

Rejected: private typing alias constructors or diagnostic suppression. Public
subscription already supplies reconstruction and validates each constructor's
own arity; duplicating either rule would add a second annotation grammar.

Verification plan: check ty and mypy on call_signatures.py; run annotation
roundtrips, constructor refusals, live contract edits, callable ports and
callable values; then Ruff, evidence, layering and the local clone scan.

Verified: ty and mypy pass on metta/_catalog/call_signatures.py. The root
command below passes 86 cases, including literal and metadata annotations,
malformed constructor applications and later native contract replacement:

```sh
python -m pytest -q -n 0 --benchmark-disable --randomly-seed=1125382488 \
  extensions/python/tests/ch03_atoms_and_expressions/test_callable_annotations.py \
  extensions/python/tests/ch09_types/test_class_call_contracts.py \
  extensions/python/tests/ch03_atoms_and_expressions/test_callable_ports.py \
  extensions/python/tests/ch03_atoms_and_expressions/test_callable_values.py
```

`sh check.sh ruff evidence layering` passes with one pending pin and no
unbacked claim. The preceding clone command with call_signatures.py and
annotations.py as its two inputs and ai-classes-c56b-clones as its output
finds no clones. Logs use `ai-tmp/ai-classes-c56b-{ty,mypy,python,checks,clones}.log`.
