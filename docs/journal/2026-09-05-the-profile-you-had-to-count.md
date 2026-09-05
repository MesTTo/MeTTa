# The profile you had to count
Goal: settle the backlog row asking for `EngineProfile` to render through `Rows`.
Constraint: whatever already reads the profile positionally must keep working.

## 2026-09-05

`EngineProfile.nodes` held `[tuple(node) for node in nodes]` and `top()` handed
those tuples back, so self-ticks were `node[3]`, counted out against a docstring.
Every other public table door here answers `Rows`, which carries the column
names, projects a column by name and renders in a notebook.

Decided: `Rows(COLUMNS, nodes)` with
`(predicate, calls, redos, ticks_self, ticks_siblings)`. `top()` returns a slice,
and `Rows` retains its own type and columns across sequence operations, so it
needed no separate wrapping.

Compatibility came free rather than by care: `Row` subclasses `tuple`, so
`_profiled_rows` reading `node[0]` through `node[3]` is unchanged, and the
existing `test_profile_counts_samples_on_real_work` unpacks five positional
fields and still passes. The new test asserts both readings agree on the same
row, which is the property that makes the change safe rather than merely green.

Proven to discriminate by reverting `nodes` to tuples: `assert isinstance(
prof.nodes, Rows)` fails and every other profile test stays green.

Evidence: 3,012 Python tests pass, against 3,011 before.
