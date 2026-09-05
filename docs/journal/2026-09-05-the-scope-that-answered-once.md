# The scope that answered once
Goal: `speculate` must answer every answer of its body, the way `transaction`
already does.
Constraint: the writes still belong to one discarded execution.

## 2026-09-05

Reported by the graph port as `speculate` rolling back but running its goal as
`once`, so a nondeterministic command answers once inside it and a `collapse` is
needed to see the rest.

Measured through the Node binding's speculate scope, over a space holding three
rows: 3 answers unscoped, 1 scoped, nothing said about the other two.
`snapshot/1` is once-like exactly as `transaction/1` is, and
`metta_transaction/1` was repaired for that on 2026-08-19 by collecting inside
and replaying after. Dropping answers is the same opacity violation there and
here, and a DISCARDED scope has less excuse for it: the answers are copied out
of the snapshot before its writes go, so nothing about them depends on the
rolled-back state.

Rejected: repairing it in the callers. The Python shim's LAZY cursor already
carried a hand-written `metta_speculate(fence(findall(...))), member(...)`,
which is why a held speculative cursor kept every answer while the eager door
beside it and the Node binding's own scope did not. One caller's workaround is
what a seam-level defect looks like from inside.

Decided: `metta_speculate/1` collects and replays, reusing
`metta_transaction_answers/3` so the two scopes are one mechanism, and the
shim's special case goes with it, taking `metta_py_execution_cursor_goal/4` (a
one-clause pass-through afterwards) with it.

Control: reverting the collect leaves
`transaction_answers:speculation_answers_every_answer_and_still_discards_its_writes`
as the only failing test in a 249-test suite.
