# A tracer is an array of its own library

Goal: a JAX tracer crosses `metta.arrays` operations untouched, so a gradient
reaches through a MeTTa computation.
Constraint: recognition stays DLPack and semantics stay the array API
standard; nothing here may special-case a library by name.

## 2026-09-04

Reported: `metta.arrays` recognises a JAX tracer as an array, because it has
`__dlpack__`, and then fails converting it, because it has no
`__dlpack_device__` -- while `namespace_of(tracer) is namespace_of(concrete)`,
so no conversion was needed at all.

Tried: reproducing it [ai-tmp/probe_jax_tracer.py, jax 0.11.0]. Inside
`jax.jit`, `is_array(tracer)` is True, `hasattr(tracer, "__dlpack_device__")`
is False, `namespace_of` answers the same object for the tracer and for the
concrete array, and `type` reads `DynamicJaxprTracer` against `ArrayImpl`.
The gate is `type(b) is not type(a)`, so the conversion fires and
`from_dlpack` refuses with "The array passed to from_dlpack must have
__dlpack__ and __dlpack_device__ methods".

Decided: the gate asks which LIBRARY an operand belongs to, and Python type
identity is not that question. `_into(namespace, like, value)` converts only
when `namespace_of(value)` is not the target, with the type test kept in
front as a fast path because two values of one Python type are always of one
library. Three sites shared the defect, the binary-operand alignment and both
of the embedding store's, so the helper is where the question is answered
once.

Measured, both directions, through a real MeTTa operation
[ai-tmp/probe_jax_e2e2.py]: with the tracer on the RIGHT, which is the pair
that reaches `from_dlpack` because the left operand names the namespace,
`(t+ <concrete> <tracer>)` under `jax.jit` raised
`Python TypeError in (t+ Array([1., 2., 3.]) JitTracer(float32[3]))` before
and answers 12.0 after, and `jax.grad` returns `[1. 1. 1.]`. With the tracer
on the LEFT the old gate already passed, which is why the report named a
direction.

Tried, while writing the end-to-end probe: `arrays.install(m)` on a CONTEXT.
It raised `MeTTa has no 'is_function': it is a Space door, and a context is
not its space`. That refusal is deliberate and its message names the fix, but
an installer is exactly the place where the home space is what was meant: the
whole array operation set was left unregistered by the natural spelling, and
`integrate(m, target)` has the same hole one door earlier, on `m.name`.

Decided: `integrate.space_of(m)` resolves a context to its home space and
answers a space for itself, and both installers call it, so an installer is
handed a SPACE whichever of the two the caller holds. It is duck-typed rather
than an isinstance because `metta.integrate` deliberately does not import the
facade; a context is exactly the object with a home space to give.

Open: the array suite's own fixture passes a Space, which is why neither hole
was caught here. A suite that drives only the door the library's examples do
not write is the shape to watch for.
