# Derive Python protocols from their source contracts

Goal: derive Python's operation inventory and project shared protocol shapes
into native equations, compiler bindings and differential tests.

## 2026-09-15

Source: at `15059fadefb33295bd30d927be5e25559528c2df`,
`extensions/python/metta/_declare/prelude.py:install` registers `py-operator`
at two flat arities. `_compile/call_syntax.py:application`
already separates operand computation from held argument frames. CPython's
`operator.call` has a variadic call signature, while syntax operands and Atom
builders have their own contracts. The existing compiler's min/max paths fold
binary applications, so they do not expose the service's arity limit directly.

Decided: use the existing operation service with a selector and one expression
of completed operands. Its signature derives one native arity. Compile each
expression operand into a fresh native let, in source order, then hold the
assembled frame. Variables and literal atoms are already completed values.
This uses the existing expression representation and operation registration;
the selector inventory is unchanged in this unit.

Rejected: enumerate additional service arities or add a second variadic
operator service. Either would repeat the call protocol for a cardinality that
the native operand expression already represents. The required frame has
linear construction cost in its operand count; no sublinear representation
can expose all supplied operands. This unit claims structural cardinality,
evaluation order and native rewriting, not a performance improvement.

Tried: after deleting engine and library QLF files, the following command
against unchanged providers passes the evaluation-order control and fails the
frame call with `TypeError: 'tuple' object is not callable`. The temporary
operator.call selector receives the entire frame as one tuple under the old
flat convention. Log: `ai-tmp/ai-classes-c59-frames-before.log`.

```sh
python -m pytest -q -n 0 --benchmark-disable --randomly-seed=1125382488 \
  extensions/python/tests/ch11_python_as_a_notation/test_operator_frames.py
```

The frame witnesses cover empty call operands, several operands, falsey
values, a scalar symbol with an active native rule, grounded Atom identity,
ordered computed effects, and native equation matching and replacement.
Existing compiler and fold assertions now inspect the same frame contract.

Verified: the focused command above, also selecting
`extensions/python/tests/ch08_data/test_reduce_lowering.py`, passes five tests
after the ABI migration. Log: `ai-tmp/ai-classes-c59-frames-after.log`.
`sh check.sh layering ruff mypy ty evidence policy-inventory` passes all
selected checks, with 7,851 evidence claims and zero unbacked references.
Log: `ai-tmp/ai-classes-c59-checks.log`. The five-file clone scan in
`ai-tmp/ai-classes-c59-verify.sh` reports 4,652 lines, 40,351 tokens and zero
clones. Log: `ai-tmp/ai-classes-c59-clones.log`.

Verified: `GATE_ONLY=1 sh check.sh door-sync reference` passes the 227-contract
projection checks, 69 door controls, 58 refusal controls and four reference
controls. After deleting engine and library QLF files, `sh engine/test.sh`
with `libraries/lib_reflect.plt`, `host/python_surface.plt` and
`evaluation/grounded_effects.plt` under `tests/prolog/suites/` passes 68 tests
and 15 subtests in three processes. The Python command in
`ai-tmp/ai-classes-c59-verify.sh` passes 1,071 tests with `-n 0`, covering data,
notation, class methods, construction, grains, costs and operator projections.
The complete commands and outputs are in `ai-tmp/ai-classes-c59-verify.sh`,
`ai-tmp/ai-classes-c59-projections.log`, `ai-tmp/ai-classes-c59-native.log` and
`ai-tmp/ai-classes-c59-python.log`. `/usr/bin/time -v` reports peak resident
memory of 40,788 KiB for the native runner and 1,628,776 KiB for Python.

Open: derive the operation inventory and connect its protocol shapes to native
class dispatch. This operand-frame unit does not establish Python protocol
fallback semantics.
