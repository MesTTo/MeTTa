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

### The name a failure blames

Tried: read the whole report a false claim writes, rather than the message the
engine's own `print_message/2` prints ->

    ERROR: MeTTa assertion failed: (assertEqual (+ 1 1) 3)
    ERROR:   missing: (3)
    ERROR:   excess: (2)
    ERROR: engine/main.pl:93: user:main 'assert-answers'/5: MeTTa assertion
           failed: (assertEqual (+ 1 1) 3) ...

The first block is `report_failed_assertion/4`'s own print, whose context is
unbound and which therefore blames nobody. The `'assert-answers'/5` in the
second is SWI printing the ball's context culprit
[source: SWI-Prolog 10.1.13 boot/messages.pl, swi_location//1 over
context(ContextPI, _)], and `'assert-answers'/5` is a predicate with no head of
that name anywhere a reader could search. `assert/2` and `test/3` read the same
way.

Decided: the culprit is the MeTTa head the program wrote, as an ATOM. Naming
the written MeTTa operation in that position is the convention the engine
already holds every other user-facing refusal to
[source: engine/metta/registration.pl, metta_host_operation_error/5, whose
first condition is `atom(Operation)` over that same position, and the two
`prolog:message//1` clauses that render from it]. So `assert`, `test`, and
for the two answer-bag doors the head of the call they were handed --
`assertEqual`, `assertEqualToResult`, `assertEqualMsg`, `assertIncludes`.
Measured after: each of those five forms blames its own head, and no `/5` or
`/2` appears in any of them.

Decided: reading the reported form's head is legitimate HERE and was rejected
elsewhere for a reason that does not reach it. `2026-09-06-the-bag-diff-an-
assertion-already-computes.md` rejected "dispatch on the reported form's head"
because it would make that form load-bearing for SEMANTICS; a culprit changes
no verdict, no bag and no ball, and the same doors document that argument as
the call the program wrote. A form that is not an application has no head, and
the door's own MeTTa name is then what the program wrote, since it called the
door directly.

Rejected: deriving the culprit inside `report_failed_assertion/4` from its Form.
`assert/2`'s Form is the EVALUATED operand -- `(: assert (-> %Undefined% (->)))`
is upstream's declaration -- so `!(assert (foo bar))` would have blamed `foo`,
a head the program wrote nowhere near an assertion. The derivation belongs to
the doors whose form IS a written call.

Tested: `a_failure_blames_the_metta_head_the_program_wrote` walks all five
forms in `prelude.plt`; four cases in `metta.plt` cover the doors directly, the
formless fallback and the rendered sentence; the shell failure-surface lane
asserts the prefix and the absence of the predicate indicator for each of the
three shapes that have a culprit. Planted proof: with the old culprits restored,
`sh tests/shell/test_example_runner_surfaces_failures.sh` exits 1 with `the
FAILURE block for test_mismatch does not name test: MeTTa test failed`.

Tried: the Node seat's fixture for the classifier, which carried
`assert/2: MeTTa assertion failed: false (MeTTa assertion failed)` as the
engine's wording -> it classifies on `/MeTTa assertion failed/` and is
unaffected, but the string was teaching a spelling the engine no longer
writes. It carries the new one, and the seat's live one-sided case asserts the
head as well. `node --test build/test/errors.test.js` -> 14 pass, 0 fail.
