<!-- Purpose: record why the corpus showed no segment matching, what upstream answers to the same programs, and which fragment a written ask actually reaches. -->
# Sequence variables in the executable corpus
Goal: a reader who asks "does this engine do segment matching" finds the answer
in `examples/`, and a consumer of `llms.txt` learns the spellings, the fence and
the cost without reading Prolog.
Constraint: the corpus is executable, so every sentence it makes has to be an
assertion that runs; and PeTTa is the arbiter, so a claim about the semantics is
measured against upstream at the parity pin rather than asserted.

## 2026-09-07

Tried: `grep -rli segment examples/` -> no file, which is what prompted the
work. The section EXISTS: `examples/ch08-data/08-02-sequence-variables/`, one
file, `01-segments.metta`, eleven assertions, added in the corpus
reorganisation. It says "gap", "sequence variable" and `(:seg $x)` and never
the word "segment", so a content grep misses it and a path grep finds it.
Decided: the section stays where it is. `ch04-spaces-and-matching` was the
alternative and is ruled out by the corpus's own cumulative-syntax law: the
richer gap files need `case` (07-01-06), `unify` (04-02-07), `index-atom`
(08-01-07) and `sort-atom` (08-01-07), all of which are introduced after
chapter 4, and `examples/README.md`'s chapter table already lists "sequence
variables" under chapter 8.

Tried: measuring what a WRITTEN gap ask reaches, before writing an example per
fragment -> only one of the three fragments is reachable. `metta_seq_plan/3`
parses its LEFT argument alone (`engine/spaces/segment_matching.pl:440`), and
`metta_unify_decision/3` hands it the right operand as written
(`engine/translator/special_forms.pl`), so the classifier walks an unparsed
right side, finds no gap there, and answers `one_sided(left)` for every pair a
program can write. Every door that is not `unify` faces a value, so those were
one-sided by construction already. Measured on `petta` at fd188ef0, one form
per file through `sh run.sh`:

    !(collapse (unify (f a b) (f a b (:seg $v)) $v none))          -> (none)
    !(collapse (unify (f (g (:seg $x)) (h (:seg $x)))
                      (f (g (:seg $y)) (h b)) $x none))            -> (none)
    !(collapse (unify (f (:seg $u) b) (f a (:seg $v)) ($u $v) no)) -> (no)
    !(collapse (unify (f (:seg $u) (g a))
                      (f (g b) (:seg $v)) ($u $v) no))             -> (no)
    !(collapse (unify (f (:seg $u)) (f (:seg $u)) yes no))         -> refuses, mixed_roles

The first four are exactly the shapes `tests/prolog/suites/reader/segments.plt`
proves the `last_position` and `linear_shallow` solvers answer, and it proves
them by calling `metta_seq_unify/3` with two PARSED sides, which no surface
produces. The fifth is worse than unreachable: the trivial identity `X = X`,
which Kutsia Section 6.3 keeps, refuses here, and the reason it gives is
`mixed_roles` although `$u` plays one role on both sides. The cause is the same
unparsed right side: `metta_seq_ordinary/3` walks it, sees `(:seg $u)` as an
ordinary two-child expression, and collects `$u` as an ordinary variable.

Decided: do not fix it in this package. The brief rules the engine's behaviour
out of scope here, and the fix changes answers (four `none`/`no` rows become
solutions and one refusal becomes `yes`), so it needs its own differential.
Recorded instead in three places that a reader meets: the `Known issue` block
on `metta_unify_decision/3`, the `Fails when` and `To Do` lines of
`segments.plt`, and
`examples/ch08-data/08-02-sequence-variables/04-the-two-sided-fragments.metta`,
which pins each answer so the day the door parses both sides the corpus goes
red and says which shapes moved. The fix is one change: parse B in
`metta_unify_decision/3` and pass the parsed side to `metta_match_atoms/2`.

Tried: the arbiter measurement the unit's header carried as an assumption.
Thirteen programs through this engine and through upstream PeTTa at
`ae66fa8e41dcd5539d614706bd4e5cfb34f9608d`
(the `PeTTa-upstream` checkout beside the repository that
`tests/checks/check_upstream_parity.py` pins), each `sh run.sh <file>` in its
own checkout, upstream's `unify` reached by importing `lib_he` because it is a
library equation there:

| program | this engine | upstream PeTTa |
|---|---|---|
| `(match &self (Order ...) matched)` over three Orders | `(matched matched matched)` | `()` |
| `(match &self (Note ...) matched)` | `(matched)` | `()` |
| `(match &self (Order 7 (:seg $rest)) $rest)` | `((x y))` | `()` |
| `(match &self (Order 8 (:seg $rest)) $rest)` | `(())` | `()` |
| `(let ($pre ... SEP ... $post) (a b SEP c SEP d) ($pre $post))` | `((a d) (a d))` | `()` |
| `(let (row (:seg $r)) (row a b c) $r)` | `((a b c))` | `()` |
| `case` arm `((Order $id (:seg $rest)) ($id $rest))` | `((7 (x y)))` | `(nope)` |
| stored `(Marked ... tail)`, ask `(Marked $slot tail)` | `(...)` | `(...)` |
| stored `(Marked ... tail)`, ask `(Marked ... tail)` | `(found)` | `(found)` |
| `(let (:seg $r) (:seg foo) $r)` | `(foo)` | `(foo)` |
| `(= (allof (:seg $xs)) (quote $xs))` then `!(allof a b)` | `((quote (a b)))` | `Domain error: function_input_arities(allof,[1]) expected, found 2` |
| `(= (split (row (:seg $b) SEP (:seg $a))) ...)` then `!(split (row a SEP b SEP c))` | two answers, splits shortest first | `()` |
| `(= (splice (head (:seg $xs) tail)) (rebuilt before (:seg $xs) after))` | `((rebuilt before a b after))` | `()` |
| `(match &self (Order (:seg $m) $m) hit)` | refuses, `mixed_roles` | `()` |
| `(unify (f (:seg $x) a) (f a (:seg $x)) yes no)` | refuses, `mixed_roles` | `(no)` |
| `(unify (f (:seg $u)) (f (:seg $u)) yes no)` | refuses, `mixed_roles` | `(yes)` |
| `(unify (f a (:seg $u)) (f a b (:seg $v)) $u none)` | `((b (:seg $_0)))` | `(none)` |
| `(unify (f a b) (f a b (:seg $v)) $v none)` | `(none)` | `(none)` |

Decided: the header's `[assumed: adopted from an earlier reference semantics,
not re-measured]` becomes a measured statement, because the measurement is
unambiguous: UPSTREAM HAS NO READING OF SEQUENCE VARIABLES AT ALL. `...` is an
ordinary symbol there and `(:seg $x)` an ordinary two-child expression, on the
pattern side, on the stored side and in an equation head; a gap ask answers
nothing rather than refusing. Wherever the two agree in the table above it is
because the marker was DATA on both sides, which is the one thing both engines
read the same way. So every decision the header lists is an extension over a
region upstream leaves undefined, with three rows where the extension CHANGES an
upstream answer rather than filling a silence: the commuting equation (`no` ->
refusal), the trivial identity (`yes` -> refusal) and the mixed-role pattern
(`()` -> refusal). The first is deliberate and is the fence doing its job; the
second is the surface-reachability defect above, and it is the sharpest evidence
that the defect is real, because it makes this engine refuse where the arbiter
answers.

Rejected: a lane that replays our gap programs through upstream. Upstream is
pinned and `check_upstream_parity.py` already refuses a checkout at any other
commit, so such a lane would re-measure a frozen answer on every run, and it
would need an upstream checkout that most trees do not have. Revisit if the pin
moves, or if a gap program's upstream answer ever becomes load-bearing for a
behaviour rather than for provenance.

Tried: stating the cost claim in the corpus. `(inferences N $expr)` is the only
inference vocabulary a program has, it is a BOUND rather than a report, and its
expiry is a control signal no `catch` can eat, so a corpus file can assert "this
fits under N" and cannot assert "that one does not". It is also introduced at
`14-00-01`, so a chapter-8 file cannot use it at all. The cost example is
therefore `examples/ch18-performance/18-01-larger-workloads/06-a-gap-query-and-its-index.metta`.
Measured there by lowering each bound until the ask stopped fitting, over a
space holding three `edge` atoms and 200 then 2,000 `node` atoms:

| ask | 200 nodes | 2,000 nodes |
|---|---|---|
| `(length (collapse (match &self (edge a $y) $y)))` | 57 | 57 |
| `(length (collapse (match &self (edge ... $y) $y)))` | 144 | 144 |
| `(length (collapse (match &self (node ... $y) $y)))` | 4,670 | 46,070 |

Decided: assert both edge queries under one bound of 1,000 at both store sizes,
and assert separately that the node gap query answers 2,200 rows. That pair is a
proof rather than a pin: no ask can answer 2,200 rows for fewer than 2,200
inferences, so an edge query fitting under 1,000 cannot have read them, and the
bound keeps 6.9x of headroom for ordinary engine drift while still failing by
46x if the candidate head ever stopped being written from the pattern's leading
child. The same measurement through the Python door reads 36 gap-free and 41
with a gap, flat at 100, 1,000 and 4,000 node atoms.

Tried: pricing the six new twins. Deterministic to the inference across three
independent fresh processes at loadavg 41: 10,663 / 19,513 / 7,851 / 7,417 /
6,797 for the five chapter-8 twins and 52,858 for the chapter-18 one. Five of
the six report `equal` stored content; the sixth differs by one word, `&self`
against `&pyspace_1` inside the bulk-loader equation, because the twin harness
mints its home space and `S.add_atom(m, ...)` encodes the handle by name.
`18-01-larger-workloads/01-scale.metta` carries the same difference on trunk, so
it is the harness's and not this package's; it is now a residue entry.

Open: the five residue entries this package added are the Python surface's own
list -- a star PARAMETER that lowers to a segment head, a `solve` that answers a
wholly ground pair, a `case` arm binding one name in two roles (which Python's
grammar rules out outright), the refusal's structured payload on
`EngineError.atom`, and the `&self` encoding above.

## 2026-09-07 (later the same day)

Superseded, one decision only: "Decided: do not fix it in this package" above.
The door was repaired the same day in its own thread,
`docs/journal/2026-09-07-unify-reaches-the-two-sided-fragments.md`, which
carries the design, the eight-row arbiter measurement of the shapes that moved,
and the cost. Two facts recorded above are no longer current and are corrected
there rather than edited here: `metta_unify_decision/3` now parses BOTH
operands, so the four `none`/`no` rows answer their calculus and the trivial
identity answers `yes` as the arbiter does; and the one-line fix this entry
proposed was measured to regress two shapes on its own, an open operand and a
space operand, so the repair also gave `metta_seq_atoms/2` the subject case
analysis it was missing. Everything else above, including the thirteen-program
arbiter table and the cost example's numbers, still holds.
