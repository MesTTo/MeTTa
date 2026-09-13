# Container types at native call boundaries

Goal: keep one callable contract across structural images and borrowed host
containers, preserving annotation refinements and abstract membership.

## 2026-09-13

Tried: the pending concrete-container projection passes ten of eighteen
public call cases. Eight fail: Sequence with a tuple or UserList,
MutableSequence with UserList, Mapping and MutableMapping with UserDict,
Set with frozenset, Required[list[int]] and a TypeVar bound to list[int].
Command, with the repository's selected Python and PYTHONPATH=extensions/python:

```sh
python -m pytest -q -n 3 --benchmark-disable --randomly-seed=1125382488 \
  extensions/python/tests/ch11_python_as_a_notation/test_container_call_types.py
```

Log: `ai-classes-c30-container-types-before-corrected.log`, exit 1. An earlier
fixture incorrectly expected EngineError for a native Error value instead
of MettaResultError, and used an untyped object as a negative type witness.
The corrected fixture uses a known Number. The initial trace is retained in
`ai-classes-c30-container-types-before.log`.

Rejected: obtaining an abstract container's runtime class from its conversion
hook. Sequence shares list's structural hook, but that does not make every
Sequence a list. Enumerating concrete classes also misses virtual subclasses.

Decided: each container contributes one native union of its structural type
and retained type. Concrete containers use the existing host MRO type names.
Abstract containers use `(Annotated Grounded (Predicate <instancecheck>))`:
ABCMeta's instance test decides membership through the existing grounded
callable refinement. `engine/metta/refinements.pl:metta_refinement_predicate/2`
already applies that predicate to a completed value. No new type registry,
engine primitive or duplicate container inventory is needed. Required,
NotRequired and bounded or constrained TypeVars recurse through the same
projection. Full Python annotation records stay unchanged. Native Annotated
constraints surround the representations they govern.

Tried: that projection passes 57 of 67 cases in the container, adoption and
field cohorts. Nine abstract-container cases fail in the native checker;
one adoption assertion compared a variable spelling instead of alpha
equivalence. `python ai-tmp/ai-classes-c30-container-predicate.py` isolates
the engine result: the grounded ABC predicate returns True, a standalone
Annotated Grounded parameter accepts the list, and placing that same type
inside `(| Expression ...)` yields BadArgType. The three results are in
`ai-classes-c30-container-predicate.log`, exit 0. The general refined-union
repair is a dependency, not a Python-only alternative encoding.

The corrected eighteen-case fixture fails all eighteen on pristine
`c75181adc999adf0028616ee69565e2bbfbf739f`, including the original borrowed
list/dict/tuple/set cases. Control command uses the same pytest flags on
`ai-tmp/test_container_call_types_probe.py` in the pristine archive with its
own METTA_ROOT and PYTHONPATH. Log:
`ai-classes-c30-container-types-control-corrected.log`, exit 1.

Result: the native refined-union dependency at
`7e2de138f59cd8137f55dce9e7f2f955906c76d1` makes all 67 container, adoption
and field cases pass. The exact dependency tree passes 58 Python cases and
157 native tests with 50 subtests. The container cohort command above with
`test_adoptions.py` and `../ch09_types/test_class_field_values.py` added
produced `ai-classes-c30-container-types-verified.log`, exit 0.

Tried: pass a compiled list-parameter function through
`Callable[[list[int]], int]`, and a list-returning function through
`Callable[[int], list[int]]`. Both fail with BadArgType: the nested arrow
still names Expression while the function names `(| Expression list)`.
Command: the container pytest command above with `-k callable`, without
xdist. Log: `ai-classes-c30-container-callable-before.log`, exit 1.

Decided: parameterize `_callable_type_atoms` by its recursive projection.
`type_atoms_for` retains the written structural view; `runtime_type_atoms`
composes representation admission through each arrow parameter and result.
Both use the existing bounded arrow product and deduplication.

Tried: the recursive projection passes 86 of 87 cases. The remaining host
operation receives the count symbol and constructs an unevaluated term;
the same parameter test fails at pristine c75181adc. The return test's
length assertion could mistake that term for a two-element list. Those
logs are `ai-classes-c31-container-types-after.log` and
`ai-classes-c31-container-callable-control.log`. The container witnesses
now use compiled higher-order consumers and assert the returned list's
contents. Missing lexical context during host argument conversion is a
separate defect in `_binding/dispatch.py:_decode_arg`, which calls build
without a space; it needs its own behavioral regression and repair.

Verified: the isolated container tree passes 134 Python cases and 149 native
tests with 15 subtests. Commands:

```sh
PYTHONPATH=extensions/python "$CHECK_PY" -m pytest -q -n 3 \
  --benchmark-disable --randomly-seed=1125382488 \
  extensions/python/tests/ch11_python_as_a_notation/test_container_call_types.py \
  extensions/python/tests/ch11_python_as_a_notation/test_adoptions.py \
  extensions/python/tests/ch09_types/test_class_field_values.py \
  extensions/python/tests/ch03_atoms_and_expressions/test_p5_annotations.py \
  extensions/python/tests/ch03_atoms_and_expressions/test_callable_values.py \
  extensions/python/tests/ch03_atoms_and_expressions/test_convert.py
sh engine/test.sh tests/prolog/suites/typecheck/union_types.plt \
  tests/prolog/suites/typecheck/refinements.plt \
  tests/prolog/suites/libraries/lib_reflect.plt \
  tests/prolog/suites/host/python_surface.plt \
  tests/prolog/suites/libraries/lib_thread_scope.plt
```

Logs: `ai-classes-c31-container-A-python.log` and
`ai-classes-c31-container-A-native.log`, both exit 0. Layering, mypy and
evidence pass; Ruff identifies import order and two non-raw regex literals
in the new fixture. Those three style findings were corrected before the
final commit verification. Log: `ai-classes-c31-container-A-checks.log`.
