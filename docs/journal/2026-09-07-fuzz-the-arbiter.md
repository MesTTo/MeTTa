# Fuzz the arbiter
Goal: find where this engine and upstream PeTTa disagree on programs the
vendored corpus never contained, and report each finding as the smallest
program that still shows it.
Constraint: upstream at ae66fa8e is the ARBITER. A program it leaves unreduced
says nothing about a divergence and everything about the surface it reduces at
that pin, so it is recorded and skipped. The lane never edits the pin or the
census; a census change is a commit.

## 2026-09-07

Decided: the census is DERIVED and then MEASURED, not written down. The corpus
census reads every call head out of `tests/conformance/petta/examples`, keeps
the ones no example defines with `=` and at least three files write, and then
runs each candidate on the arbiter with kind-directed arguments and records
what it did. Only the ones that reduced are drawable, so a generated program is
inside the arbiter's surface by construction rather than by hope.

Census counts, `python tests/conformance/petta_capture.py --upstream
../PeTTa-upstream --census`: 156 corpus files, 4,671 call sites, 495 distinct
symbol-headed call heads, 199 of them defined by the corpus itself. 70 heads
survive the two filters, giving 100 (head, arity) pairs to probe. The arbiter's
answers: 49 reduce, 43 it leaves standing, 4 raise, 4 reach outside the program.
The drawable surface is 41 heads over 49 pairs, and it is the language rather
than anybody's data: arithmetic and comparison, `if`, `let`, `chain`, `once`,
`superpose`, `collapse`, `match`, `add-atom`, `remove-atom`, `get-atoms`,
`cons`, `append`, `msort`, `foldl-atom`, `length`, `quote`, `eval`, `repr`,
`progn`, `test`.

Tried, each measured over the same 100 pairs by how many the arbiter reduced:

- kinds per position collapsed to one name, `any` where several were seen ->
  the probe handed `match`'s space position a number and the arbiter's most
  used three-argument head went in as answering nothing. Recording every kind
  the corpus wrote AND how often fixes it.
- kinds sorted by name -> 48 reduce. By descending use -> 49. The order decides
  because the probe walks the cross product and stops at the first tuple that
  reduces.
- probe values with no evaluating expression -> 47 reduce. With `(+ 1 1)` among
  them -> 49, `/`/2 and `<=`/2 being the two: an `expression` position in this
  corpus usually means a computation, and an inert `(a b)` there raises.
- 12 argument tuples per pair -> 47. 24 -> 49. 40 -> 49.
- deciding `unreduced` by comparing the printed answer with the query TEXT ->
  79 of 100 read as reducing, because any argument that evaluates changes the
  text: `!(a (+ 1 1))` answers `(a 2)` and `a` went in as language. Comparing
  the answer's HEAD and ARITY instead -> 49, and the 30 it moves back are data
  constructors the corpus writes and the arbiter leaves alone.
- probing variables last, on the reading that a probe is a closed query where
  `$x` is unbound -> no verdict changes at any cap. Rejected for buying
  nothing measurable; the order stays the corpus's own. Revisit if a corpus
  arrives whose positions are mostly variables.

Rejected: `import!`, `library`, `|->` and `add-translator-rule!` as drawable,
measured one query per file on both engines. `!(library a)` answers an absolute
path inside whichever engine ran it; `!(|-> (a b) (a b))` answers `lambda_1`
upstream and `lambda_2` here, a gensym counter; `!(import! &self 1)` answers
nothing upstream and raises here. Three are a declared table with each
measurement beside them, and the derived net beside it catches the class where
the answer says so itself (an answer naming the engine's own directory), which
is what catches `library` without naming it.

Tried, for the generator, over 120 programs at seed 0 with four rounds, counted
by wasted runs (the arbiter raising, where there is no oracle) and by distinct
divergences found:

| a leaf at a position | agree | arbiter errors | divergences |
|---|---|---|---|
| non-expression kinds only, `expression` nesting a call that answers one of them | 93 | 10 | 4 |
| every written kind, drawn evenly | 47 | 38 | 4 |
| every written kind, in corpus proportion | 66 | 43 | 0 |

Decided: the first. The third is the surprise and the reason the numbers are
recorded: weighting by how often the corpus writes each kind sounds like the
faithful choice and finds NOTHING, because an `expression` position drawn in
proportion still admits a call answering any kind at all, and those programs
land in the arbiter's error path rather than in its answers.

Tried, for grouping findings so the rounds look for a different disagreement
rather than another draw of the same one: masked text -> `(and a a)`,
`(and a b)` and `(and b a)` are three findings. Shapes (`head/arity`) ->
`(f 4)` against `(f 3)` and `(g true)` against `(g false)` become the same
thing. Decided: shapes ALIGN the two answer sets through
`difflib.SequenceMatcher` and masked text says what the difference was, with an
insertion or a deletion identified by shape and a replacement by text. Aligning
by line index at all splits one finding across every query that follows it: the
first run reported the same `and` three times because our extra answer moved
each of the arbiter's answers down one.

The run of record, `sh tools/check.sh parity-fuzz` at its defaults (200 programs,
seed 0, four rounds): 130 agree, 47 the arbiter raises on, 7 error-on-one, 16
answer-mismatch, no surface misses and nothing over the 20-second ceiling. Four
distinct divergences, each shrunk and written to
`ai-tmp/parity-fuzz/2026-09-07-033244/`:

- `!(add-atom &self ())` answers nothing upstream and `true` here.
- `!(and a a)` answers nothing upstream and `(and a a)` here: this engine
  leaves `and` standing where upstream reduces it away.
- `(= (f0 $x) (* $x))` in the space, then
  `!(chain (get-atoms &self) $v1 $v1)`: upstream enumerates the equation atom
  and this engine answers `false` for it.
- the same shape over `(= (f0 $x) (* $x (* $x $x)))` raises here, `*` run
  backwards with more than one unknown, where upstream prints the atom.

Each is a finding to file rather than to fix in this thread; the reports carry
the divergence issue template's fields verbatim and the hypothesis
reproduction blob.

Measured, on what a run can be held to: two runs at seed 0 into fresh report
directories wrote the same four findings under the same four names and shared
177 of their 200 programs, with the per-class counts moving by up to three
(135/44/6 against 132/43/7 for agree, arbiter-error, error-on-one). So the
FINDINGS are what a run is held to and the counts are indicative. Which
programs fill the budget after the findings are located is not fully determined
by the seed, and that is not root-caused: hypothesis bounds its shrink phase by
wall clock (`MAX_SHRINKING_SECONDS = 300` in its engine.py), which fits the
shape, but this run does not approach that bound, so the mechanism is unproven.

Open: whether the third and fourth findings are one. Both are `get-atoms`
handing an equation atom to a comparison, and they arrive as two because one
answers and the other raises, which is two CLASSES by construction. A signature
that looked through the class would join them and would also join things that
should not be joined.

Open: the design that settled this lane expected the planted self-test's
finding to shrink to one fact-free QUERY. It shrinks to a fact-free equation
and its query, two lines, and the self-test asserts what a reader of a report
actually needs instead: no facts, one query, and no line that can be dropped
with the disagreement surviving.

Open: the census records `test`/2 as reducing, so a generated program can carry
upstream's own assertion head. Nothing in this run drew it into a divergence.
