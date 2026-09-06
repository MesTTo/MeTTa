# A one-sided assertion, and the name a failure blames
Goal: close the three things the bag-difference thread left open --
`assertIncludes` reporting `false` while its siblings name their call and their
bags, the culprit prefix naming the Prolog predicate that raised, and the
example having no Python twin -- without moving any verdict.
Constraint: `2026-09-06-the-bag-diff-an-assertion-already-computes.md` recorded
what was rejected on the way to `assert-answers`, and none of those conditions
have changed; the verdicts of every assert form stay exactly the comparisons
they were.

## 2026-09-07

### The one-sided report

Tried: measure what the arbiter prints for a failing `assertIncludes` first ->
`git grep -in assertincludes tests/conformance/ ai-tmp/PeTTa-upstream/` exits 1.
Upstream PeTTa at `ae66fa8` does not define the head at all, so there is no
conformance case and no upstream sentence to match. The report's shape is
this engine's own; the verdict is what does not move.

Decided: a second door, `(assert-includes-answers $Verdict $Form $Actual
$Expected)`, Prolog `'assert-includes-answers'/5`. It is `assert-answers`'
four arguments in the same order with the same meanings, and differs in one
respect: it computes `Expected` minus `Actual` and leaves the excess side
UNBOUND. That is the shape the earlier thread already named as the way in --
"the same `report_failed_assertion/4` takes it with Excess left unbound" -- and
the two alternatives it rejected are still rejected for the reasons it gave: a
mode argument naming the comparison is a closed value set no lane can check,
and deciding the comparison from the reported form's head would make that form
load-bearing for semantics.

Decided: reading the head of the reported form for the CULPRIT, below, is not
that rejected option. The rejection is about deciding a comparison; a culprit
is a diagnostic, decides nothing, and the form the two answer-bag doors carry
is documented as the call the program wrote.

Decided: a one-sided verdict gets a one-sided report because an answer in
excess of a containment's expectation is LEGAL, so naming one invites the
reader to fix something that is not broken. The same split exists in a standard
library and was measured rather than recalled
[measured 2026-09-07, CPython 3.11.15: `assertCountEqual([1,2],[2,3])` prints
`First has 1, Second has 0:  1` AND `First has 0, Second has 1:  3`, while
`assertIn(3, [1,2])` prints `3 not found in [1, 2]` and says nothing about the
members of the list it was not asked about].

Tried: keeping the message renderer's pair test and giving it a third case ->
rejected before writing. `assertion_bag_difference//2` asked `var(Missing),
var(Excess)` as one question, so it could print both bags or neither; the ball
has carried per-bag absence since it was designed. The renderer now asks each
bag for itself, `assertion_bag_line//2`, and the pair question is gone.

Tried: the suites after that change -> `metta_assertions:a_non_list_operand_
leaves_the_bags_absent` failed with `the two answer bags agree, so the answers
differ only in order` printed under a failure that compared nothing.
`assertion_permutation_note([], [])` matched its two bags in the HEAD, so two
absent bags were BOUND to `[]` and then reported as agreeing. It had been
unreachable only because the pair test cut every absent case out before it.
Decided: the note compares with `==`. An absent bag is never taken for an empty
one anywhere in the renderer now.

Tried: the report end to end ->
`!(assertIncludes (superpose (1 2)) (7))` prints `MeTTa assertion failed:
(assertIncludes (superpose (1 2)) (7))` and `  missing: (7)`, with no `excess:`
line and no permutation note; through the Python door the same failure gives
`.missing == (7,)` and `.excess is None`. 1 and 2 are produced by that call and
neither is expected, and neither is named.

Open: nothing about `assertIncludes`' verdict moved. `subtraction-atom` on the
written expectation minus the collapsed answers, compared with `()`, is what it
always was; only where the difference goes changed.
