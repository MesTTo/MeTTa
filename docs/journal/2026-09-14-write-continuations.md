# Storage write continuations

Goal: stop compiled continuations when a native storage write refuses, while
preserving ordinary value bindings and storage already written.

## 2026-09-14

Tried: invalid entity and prototype field assignments through plain, augmented,
generator and finally blocks. Storage remains unchanged, but the next effect
runs, generators produce the next answer, and finally retains the old error.
Replacing a native writer with Error values of four widths also runs the tail.
`python -m pytest -q --benchmark-disable --randomly-seed=1125382488
extensions/python/tests/ch09_types/test_class_write_continuations.py` reports
12 failed and 1 passed before the repair, then 13 passed. Logs:
`ai-classes-c42-write-continuations-before.log` and
`ai-classes-c42-write-continuations-after.log`.

Decided: a binding has either a local target and value, or no target and a
storage-write status. Statement, generator and finally lowering share one
emitter. It uses native `case` to select the continuation after inspecting the
status. A local binding keeps value semantics outside a try body; protected
bindings select before structural matching. Dictionary, State, global and
deletion writes use the same emitter. No write invents a local `_` binding.

Rejected: discarding the writer result loses its refusal. Changing native
`let` would change all value bindings. The existing `if-error` call evaluates
both branch operands before selecting, so it cannot guard an effectful tail.
The signature experiments and rejection conditions are recorded in
[Compiled error selection](2026-09-05-compiled-error-selection.md).

The completed negative control reads an Error from a compiled raising function,
then carries it through an ordinary local binding and a writer returning false.
It returns that same Error. A captured Python Expression was a grounded host
object and did not test native Error binding. All thirteen cases pass with
this native source in `ai-classes-c43-write-negative-controls.log`. Layering,
Ruff, mypy and evidence pass in `ai-classes-c43-write-checks-final.log`.
The three changed production files have zero clones across 2,920 lines:
`jscpd --format python --min-lines 8 --min-tokens 80 --max-lines 10000
--max-size 1mb --no-gitignore --noTips --reporters console,json
--output ai-tmp/ai-classes-c43-write-clones
extensions/python/metta/_compile/context.py
extensions/python/metta/_compile/records.py
extensions/python/metta/_compile/statements.py`.
