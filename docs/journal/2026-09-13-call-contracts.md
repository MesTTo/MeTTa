# Native Python call contracts

Goal: make Python argument contracts inspectable and rewritable as native
program data, including parameter kinds, defaults and exact annotations.

## 2026-09-13

Tried: storing an `inspect.Signature` as a Grounded object made ordinary class
program digests refuse live host identity. Reconstructing typing aliases from
their bare origins also changed their Python species. The nineteen-shape probe
`PYTHONPATH=extensions/python $CHECK_PY ai-tmp/ai-classes-c27-annotation-contracts.py`
passed twelve cases and failed seven; its matching log records the digest
refusals and annotation mismatches.

Decided: use `(signature ((parameter name kind annotation default) ...) return)`
records. Defaults are `()` or `(default value)`. The existing host-type and
host-apply vocabulary carries named annotations; the conversion catalog carries
declared class identity. Unnamed host annotations keep their Grounded identity
and its existing persistence boundary. Qualified lookup reads loaded namespaces
with `inspect.getattr_static`, so decoding does not run a descriptor or import
another module. `inspect.Signature` remains Python's argument binder.

Rejected: opaque signatures and a second argument-binding implementation.
Native `match`, `remove-atom` and `add-atom` already express a contract edit.
The fresh `builtins()` inventory reports 307 names; the inventory and fourteen
head contracts are in `ai-classes-c27-builtins.log` and
`ai-classes-c27-builtin-contracts.log`. `id` is the identity function, not a
Python object identity operation.

Verified before partition: the nineteen annotation storage/digest cases pass
in `ai-classes-c27-signature-species.log`. The generated argument-binding
witness is included in the 111 passing class consumers recorded in
`ai-classes-c27-class-consumers.log`. Both use `PYTHONPATH=extensions/python
$CHECK_PY -m pytest -q -n 3 --benchmark-disable --randomly-seed=1125382488`;
the standalone input is
`extensions/python/tests/ch09_types/test_class_call_contracts.py`.

Verified on the isolated prerequisite tree: that file plus
`test_convert.py` and `test_p5_annotations.py` in
`extensions/python/tests/ch03_atoms_and_expressions/` pass all 76 cases with
the same pytest command. `sh engine/test.sh
tests/prolog/suites/host/python_surface.plt
tests/prolog/suites/libraries/lib_reflect.plt` passes 44 tests plus ten
subtests, then twenty tests. `sh tools/check.sh ruff mypy evidence` passes. Logs:
`ai-classes-c28-contract-A-python.log`,
`ai-classes-c28-contract-A-native-harness.log` and
`ai-classes-c28-contract-A-checks.log`.

The initial raw SWI command omitted the runner's extension loading and
reported `Unknown procedure: plunit_python_surface:'py-atom'/2`. Running the
repository's `engine/test.sh` with the same suite supplies that environment;
no source change was needed. New test fixtures also initially called the
symbol namespace, used its underscore translation for an exact enum name,
and expected a space in `positional-only`. The corrected fixtures preserve
the binding/refusal assertions; their earlier failures are in
`ai-classes-c28-call-contracts-before.log` and
`ai-classes-c28-call-contracts-after.log`.
