# Native callbacks entering Python operations

Goal: preserve the lexical program of native callback arguments at every
host operation direction and answer cardinality.

## 2026-09-13

Tried: a host operation annotated with Callable receives a native function
symbol and returns an unevaluated application. `_binding/dispatch.py` calls
`build` without its lexical space, so the callable converter cannot resolve
the symbol. The same failure appears on pristine c75181adc in
`ai-classes-c31-container-callable-control.log`. A broader initial matrix
also exposed fixture interference when one operation name alternated between
deterministic and streaming kinds; those shapes now have separate names.
The original trace is `ai-classes-c31-callable-arguments-before.log`.

Decided: supply the current native program to structured annotated argument
conversion. `current_metta_space/1` is already the operation injection
mechanism's source of context; encode its actual term before opening the
lexical handle so parametric identities survive. Recursive `build` already
carries that context through containers and fields, and explicit evalc
homes override it. Deterministic, streaming and inverse calls share
`_decode_arg`. Async calls decode while preparing on the calling engine.
Grounded values, unannotated values and syntax-taking arguments need no
lexical lookup.

Rejected: using the registration space, because one operation can run in
several programs. Rejected: ambient converter state or another callable
representation, because the existing explicit build context and native
lambda home already carry the required information.

Tried: the first context repair passes four of nine cases. Four nested
fixtures supplied an executable singleton expression instead of a quoted
list; those now pass native data explicitly. The evaluated-lambda case
exposed an independent call-assembly defect: binding the cons-atom result
before eval fixes it. That repair is recorded in
`2026-09-13-native-call-assembly.md` and lands separately.

Verified: the final sixteen-case matrix covers named and parametric homes,
scalar and nested callbacks, deterministic, streaming and async producers,
quoted and evaluated explicit-home lambdas, and deterministic or streaming
inverse conversion. Every callback kept after its operation observes a
later native body edit. Each operation registration is explicitly retired.

```sh
PYTHONPATH=extensions/python "$CHECK_PY" -m pytest -q -n 3 \
  --benchmark-disable --randomly-seed=1125382488 \
  extensions/python/tests/ch03_atoms_and_expressions/test_callable_operation_arguments.py
```

All sixteen pass in `ai-classes-c31-callable-arguments-complete.log`. The
same fixture copied into pristine c75181adc's ai-tmp, with its own
METTA_ROOT and PYTHONPATH, fails all sixteen:
`ai-classes-c31-callable-arguments-control-complete.log`. The quoted lambda
raises `'Expression' object is not callable`; the remaining cases return
unevaluated applications. Ruff identified one import layout and an unused
negative-witness parameter with its inline exception message; all four
findings were corrected before final commit verification.
