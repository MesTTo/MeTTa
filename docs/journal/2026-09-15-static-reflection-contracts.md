# Static contracts for runtime reflection

Goal: preserve native annotation and callable data while making its Python
construction and validation explicit to static checking.

## 2026-09-15: runtime annotation alternatives

Observed: `python -m ty check --python <the venv select-python.sh selects>
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

## 2026-09-15: retain validated forwarding binders

Found: _forwarded first verifies that every binder is a distinct Variable,
then later reads each binder's name. Static checking does not carry the all()
predicate's element narrowing to that later comprehension. Variable equality
is exactly name equality in `_atoms/model.py:Variable.__eq__`.

Decided: collect the names of variable binders once. Equal cardinality with
the original binder tuple proves that every binder is a variable and no name
repeats. The segment result extends that same set. Capture exclusion consumes
the retained names directly. This keeps the existing eta-contraction rule and
linear binder processing while avoiding another tuple and name-set rebuild.
The GHC side condition and original design remain recorded in
`2026-09-14-expanded-call-values.md`.

Rejected: another traversal through _variables for the binders. Its general
atom walk deduplicates through a list, so distinct flat binders would acquire
quadratic name comparisons. A cast would carry a static assertion but leave
the repeated runtime construction intact. The existing guard already supplies
the useful name set when verification and construction share one pass.

Verification plan: run callable values, ports, frames, expanded applications,
parameter binding and class contracts; run the full ty and mypy lanes, Ruff,
evidence and layering; review clones and finish the series' provenance checks.

Verified: `sh check.sh ty mypy ruff evidence layering` passes. Ty reports no
diagnostics; mypy passes the 185-file core and the separate one-, three- and
one-file public typing checks. Evidence has two pending pins and no unbacked
claims. The following command passes 139 existing callable cases:

```sh
python -m pytest -q -n 0 --benchmark-disable --randomly-seed=1125382488 \
  extensions/python/tests/ch03_atoms_and_expressions/test_callable_values.py \
  extensions/python/tests/ch03_atoms_and_expressions/test_callable_ports.py \
  extensions/python/tests/ch03_atoms_and_expressions/test_callable_applications.py \
  extensions/python/tests/ch03_atoms_and_expressions/test_compiled_parameters.py \
  extensions/python/tests/ch11_python_as_a_notation/test_expanded_call_values.py \
  extensions/python/tests/ch09_types/test_class_call_contracts.py
```

The local clone command with call_values.py as its input and
ai-classes-c56c-clones as its output finds none. Logs are
`ai-tmp/ai-classes-c56c-{checks,python,clones}.log`. All three static reflection
repairs are verified independently on their own functional trees.
