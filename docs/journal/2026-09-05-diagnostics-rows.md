# Developer-facing diagnostics: annotations, why/lint, trace filter, repl, debugger
Goal: five backlog rows about the diagnostics surface, each run before it is
believed and built only where it reproduces.
Constraint: the rows arrived as source READINGS labelled reproductions. Every
verdict here comes from an executed program, and the ones that turned out to be
pinned rulings stay unbuilt.

## 2026-09-05

Tried: reproducing L081 (`resolve type hints per annotation`) by registering a
callable with one `TYPE_CHECKING`-only annotation among three ->
`m.op(widen)` raised `TypeError: the annotations of widen do not resolve (name
'Decimal' is not defined)` while `n: int` and `-> int` were both perfectly
resolvable. Reproduces.

Tried: deciding whether the refusal is a defect or a ruling. `test_adoptions.py`
`test_registration_failure_leaves_nothing_half_registered` pins ATOMICITY, not
the refusal, and `test_define.py`
`test_an_unresolvable_annotation_is_not_a_space_parameter` already states the
governing rule in its own docstring: "the strict refusal belongs only where an
annotation is consumed as a type. A bare NAME that resolves nowhere keeps
refusing loudly".
Decided: keep every refusal that a declared call form reaches, and remove only
the ones nothing consumes. The sharp case is
`def joiner(a: int, *rest: Decimal) -> int` at `arities=[1]`: `rest` is in no
declared arrow, and refusing over it threw away a working registration.

Rejected: `annotationlib.Format.FORWARDREF` as the resolver. It leaves an
unresolvable name as a `ForwardRef` instead of raising, which is exactly the
shape wanted, but only for PEP 649 lazy annotations: with
`from __future__ import annotations` the annotations are already strings and
every format answers the string unevaluated
(measured on 3.14.4: `VALUE`, `FORWARDREF` and `STRING` all answer
`{'n': 'int', 'precision': 'Decimal', 'return': 'int'}`, and `eval_str=True` is
refused for any format but `VALUE`). Revisit if the future-import form stops
appearing in registered code.

Rejected: `typing._eval_type` per annotation, which is what `get_type_hints`
does internally. Private, and its signature has moved across 3.12-3.14.

Decided: resolve each annotation on a PROBE FUNCTION carrying the callable's
own globals and type parameters, and hand that to the public
`typing.get_type_hints`. One annotation in, one resolution out, and everything
`get_type_hints` knows how to do it still does. Measured identically on 3.12.13,
3.13.13 and 3.14.4 over a signature mixing `Annotated[str, "unit"]`, a type
parameter `T`, a postponed `list[int]`, a module-level class, a `__wrapped__`
callable and two unresolvable names: five resolve, two fail, on all three.

Decided: the whole-signature `get_type_hints` still runs first and answers
unchanged whenever it succeeds, so the per-annotation pass only ever runs where
the previous code raised. No ordinary registration changes cost.

Decided: an unresolvable annotation stands in the map as `Unresolved` and
`type_atoms_for` raises when handed one, because that function is the single
funnel every consumer reaches to turn an annotation into a type. Value
conversion reads `Any` for one instead, through `for_conversion`, since "we
could not name this type" is what `Any` already means at that boundary.
