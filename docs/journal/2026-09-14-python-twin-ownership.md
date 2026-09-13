# Python twins follow definition ownership

Goal: preserve independent reference implementations and live clause families.

## 2026-09-14

Tried: independent closures in two definition spaces answer native11/21 and
Python11/11. The pristine c75181adc witness ends `present` in
ai-classes-c34-twin-scope-control.log. The dispatcher registry keys on module
globals identity and Python name, while native clauses key on space and head.
The eight ownership cases all fail before the repair. The same eight fail
in pristine c75181adc; ai-classes-c40-twins-{before,control}.log. Command:
```sh
python -m pytest -q -n3 --benchmark-disable --randomly-seed=1125382488 \
  extensions/python/tests/ch11_python_as_a_notation/test_twin_ownership.py
```

The cases also expose captured Defined calls entering the engine from their
twin (`TypeError: unsupported operand type(s) for *: 'Answers' and 'int'`)
and pure compilation publishing an empty dispatcher into an existing twin
(`LookupError: _plain_helper: no clause's head matches (1,)`).

Decided: each definition space owns its twin namespace, and each native head
owns its dispatcher. Reuse the existing cloned Python globals and recursive
cells. Resolve source-function references by object identity and captured
Defined values by their own twin. Publish clause replacement and derived
reference updates together after successful native publication. Clear and
release retire the namespace through the existing definition cleanup.
Pure compilation only guards its source function; it publishes nothing.

Rejected: adding a space component to the old module/name key still merges
different explicit native heads. A ContextVar alone cannot redirect calls to
raw source functions that the compiler already resolved as native heads.
Rewriting Python call syntax adds a second compiler for an ownership error.

Tried: the repaired ownership, definition and reload suites pass95tests in
ai-classes-c40-twins-repaired.log. The command above adds test_define.py and
../ch05_equations_and_evaluation/test_reload.py. Recursion, stacked clauses,
later replacement, metadata and the existing name-collision refusal pass.

Tried: the completed ten ownership cases and the publication-failure suite
pass17tests in ai-classes-c40-twins-owned.log. Releasing the native space also
releases its source function, verified through a weak reference after GC.
Layering, mypy and evidence pass; Ruff names two overwritten loop variables,
an overlong positional signature and the new fixture's header spacing.
The corrected source keeps the publication inputs explicitly named.
