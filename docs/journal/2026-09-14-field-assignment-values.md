# Field assignment values and evaluation order

Goal: preserve computed field values and Python assignment order through the
native field writers.

## 2026-09-14

Tried: pass Python values and compiled right-side expressions directly to
typed writers. Atom inputs retain the right-side source instead of computing
it; Expression and refined Atom inputs execute supplied syntax data. Plain
assignment evaluates its receiver before its value. Augmented assignment
evaluates the receiver twice. The sixteen-case fixture fails fourteen cases
and passes two at 6f21f3546975d9077c9cee202b372d1ecf502b2c. Command:
`python -m pytest -q -n 3 --benchmark-disable --randomly-seed=1125382488
--tb=short extensions/python/tests/ch09_types/test_class_field_assignments.py`.
Log: `ai-classes-c37-field-write-scratch-before.log`.

Decided: Python setters submit quoted value computations to the existing
application builder. Compiled assignment binds the right-side value before
the writer evaluates its target. Augmented assignment binds the receiver
once and uses it for both the read and write. The existing native let form
expresses these dependencies; typed writer contracts remain authoritative.

Rejected: quote every writer operand, because compiled right-side expressions
must execute. Changing field annotations would weaken admission and alter
native callers. Duplicating the receiver source violates augmented assignment
when construction, lookup or a factory has effects.

The value witness rewrites its native source equation between writes and
checks the changed result. It crosses both mutable grains, three syntax
annotations and Python/compiled entries. The order witness crosses both
mutable grains and plain/augmented assignment. Value-grain initialization
and replacement refusals retain their existing paths.

The first source fixture used a captured function-namespace wrapper. Calling
that wrapper returns Answers, so six cases also tested an incorrect scalar
expectation. Its replacement captured a NativeCallable whose nested host
call failed with `one() expected exactly one answer, got 0`. Those receipts
do not isolate the writer. Passing the native callable as a typed function
parameter yields a native call directly. The final sixteen-case baseline
fails ten cases and passes six; the repair passes all sixteen. Same command
as above. Logs: `ai-classes-c38-field-native-before.log` and
`ai-classes-c38-field-native-after.log`. The source is asserted independently
before and after its native equation is rewritten. The order matrix also
includes annotated assignment in the final eighteen-case fixture.

The broader Python cohort passes 1609 tests, including all eighteen field
cases. Ten native suites pass 245 tests and 52 subtests. Layering, mypy and
evidence checks pass; Ruff rejects the fixture's typing.Callable import with
UP035. Importing Callable from collections.abc satisfies the repository
convention. The two production files contain 1042 lines and no jscpd clones.
Commands are recorded beside the logs in `ai-classes-c38-field-A-*.command`;
the amended state is checked through the same commands in
`ai-classes-c38-field-final-A-*.command`.
