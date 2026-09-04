# One roster for the algebra
Goal: make algebra names, scope, checking, answer shape, typing, and ranked-provider demand agree across the Python and engine surfaces.
Constraint: shared release and cheat-sheet files are integrator-owned; this track records their exact required edits without changing them.

## 2026-09-04 - D1 one shipped-semiring roster
Tried: compared `_PRESETS`, the catalog semiring vocabulary, generated `Semiring`, and root objects -> counts were 10, 8, 8, and 5 at `dca33c9f`.
Rejected: deleting `budget` and `amplitude`, because both have shipped algebra descriptor rows and executable behavior.
Decided: the catalog vocabulary remains the generated-enum authority, and one regression asserts that its ten values exactly equal `_PRESETS` and the root object surface. `python extensions/python/tools/vocabgen.py --write` carries the catalog change into the generated enum.
Open: the integrator-owned cheat sheets still carry stale rosters; the closed-value lane added later in this thread will report them.

## 2026-09-04 - D2 one law checker in one space
Tried: `METTA_PATH="$PWD" PYTHONPATH="$PWD/extensions/python" "$CHECK_PY" ai-tmp/probe_d2.py` -> local `(pmax ...)` evaluated to `1.0`, then declaration failed with `algebra_carrier_not_closed` because the engine retried it in `&self`.
Rejected: retaining Python's exhaustive checker as a preflight, because two executable certificates can diverge again and direct catalog declarations must still be checked by the engine.
Decided: remove Python's duplicate law walk. `metta_py_declare_algebra/2` adds the row through the ordinary catalog door while the declaring space's equation module is active, so the engine checker is the sole certificate and uses the same definitions later evaluation sees.

## 2026-09-06 - D1 landing: half of it was already on trunk
Tried: rebasing this thread onto `petta` -> the catalog half of D1 had landed
independently as `2026-09-05-the-carrier-the-vocabulary-would-not-admit.md`.
The `(vocabulary semiring ...)` row already names ten, `vocabularies.Semiring`
is already regenerated, `check_policy_inventory.REQUIRED_ALGEBRA_LAWS` already
carries `budget`, and `(claim semiring budget ordered ascending)` is already
there with a comment above it. Those hunks are dropped as already applied.
Decided: what remains is the third roster, which that thread did not touch:
`metta.<carrier>` as a root object. Trunk exported five of the ten, so
`metta.budget` raised AttributeError for a carrier `under="budget"` already
answered. The regression narrows to that claim plus the catalog ORDER, and
says in its docstring that the set equality is ch20's
`test_every_algebra_the_catalog_defines_is_one_its_vocabulary_admits`.
Tried: `ruff check metta/algebra.py metta/__init__.py` -> `bool` and `set` as
module-level names are A001, and `mypy metta/algebra.py` -> 14 errors, because
a module-level `bool` makes every `-> bool` in that module a variable
annotation and a TYPE_CHECKING import of the same name does it to the root too.
Rejected: qualifying the root's eight annotations as `_builtins.bool`. Three
are inside the block `aiogen.py` GENERATES from `Space`, which renders `bool`
from that signature, so the hand edit reverts on the next run.
Decided: `metta/algebra.py` qualifies its own six annotations and carries two
A001 suppressions naming the catalog spelling; `metta/__init__.py` does not
import either name, so both stay reachable through `__getattr__` typed `Any`
like any lazy attribute the block omits. The A-family ruff burn-down rises
17 -> 19 for the two that remain.
Tried: `ty check metta/algebra.py` and `pylint metta/algebra.py`, which read
what mypy did not -> two dataclass fields annotated `bool`, and every `budget`
identifier in the module, which the new `budget` carrier shadows. The fields
are qualified and the identifiers read `resources`, which is what they hold;
`_algebra_demand.evaluate_demand` keeps its own `budget=` keyword, the one call
that crosses the module. Three pylint findings remain and are trunk's: the same
E1101 pair and E1133 read on the unchanged tree.
