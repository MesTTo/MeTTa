# The count that ran before it asked
Goal: settle whether `m.stats()` is blind to a lazy cursor's engine work.
Constraint: the count route is a real optimisation for match views and must
keep working there.

## 2026-09-05

Tried: `m.run(...)` with 300 answers, pulling 1 against pulling all -> 6,193
inferences either way, zero spread. That looked like eagerness and was the
wrong door: `run` returns `list[list[Atom]]`, so it is eager by contract. The
lazy door is `Space.answers`.

Tried: `Space.answers` over 300 answers -> creating the view costs 5
inferences, pulling 1 costs 156, 64 costs 1,680, 65 costs 1,698, all 300 costs
6,456. Linear at ~21.5 per answer with no step at the chunk boundary, and
exhaustion costs 3 more. The match cursor scales the same way, 27 to 1,251
across 400 answers. So stats sees BOTH cursors and the question that started
this is answered: it is not blind.

Found while measuring: `list(view)` cost 90,399 inferences where
`[x for x in view]` cost 8,563 over the same 400 answers, for identical
results. 10.6x on the more idiomatic spelling.

Tried: isolating it. `len(view)` alone is 81,841 and iterating alone is 8,563,
while `len` AFTER iterating is free, so the cache works and `__len__` takes a
different route. `_materialize()` called directly costs 8,563, the same as
iterating, so the cost is not in materializing.

The route is `count_answers` in `_space_execution.py`. For an effect-safe goal
it counts on a SEPARATE engine, crossing one integer instead of encoding every
answer. Measured against draining: 9.6x on an evaluation view, and 0.74x on a
match view. So it is a genuine optimisation for match and a pessimisation for
evaluation, and the ratio is constant across 50 to 800 answers with both sides
linear -- a constant factor, not a class change.

Decided: leave that trade alone. A caller who asks only for a number is taken
at their word, and the separate count is O(1) host memory where draining is
O(n).

Decided: fix the ORDER instead. `count_answers` called
`evaluate_count_if_repeatable` and only then tested `values_wanted`, then
returned the number it had already paid for. So `list(view)`, which asks for an
iterator before its length hint precisely so a count source can tell it from a
bare `len`, bought the count AND drained the cursor. The match-backed count
source at `_space.py:2245` has always tested the hint first. Moving the test
before the call puts `list(view)` at 8,563, parity with the comprehension.

## 2026-09-05, and it was not only a cost

`test_a_lazy_drain_runs_an_effectful_island_once` was `xfail(strict)` and
started passing. Its recorded reason blamed the eval cursor's engine goal for
retaining a choicepoint and resuming into a second execution, and it ruled the
count door OUT explicitly, on the grounds that `metta_host_goal_repeatable`
already guards it. That is why nobody looked there.

Measured both ways on the probe in that test: without the reorder the effectful
body executes TWICE and the drain answers `Grounded(2)`; with it, once, and
`Grounded(1)`. Probing an effectful goal for repeatability runs it, and the
materializing pass then ran it again. So the double execution was the count
door all along, and the wrong value was being delivered.

Open: none for this thread. The xfail is retired with the true cause in its
docstring rather than deleted, because the wrong diagnosis is the reason it
survived.

Evidence: `list(view)` 90,399 -> 8,563 over 400 answers. Full Python suite
2,995 passed, 0 failed, against 2,993 before: one new cost test and one xfail
that now passes. The cost test was proven to discriminate by reverting the
reorder, which fails it at 90,350 against 8,546 while the other ten count-route
tests stay green.
