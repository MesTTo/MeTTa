<!-- Purpose: record how the two-sided door was threaded, what the five shapes answer now, and what the repair cost. -->
# unify reaches the two-sided fragments
Goal: a gap written on either operand of `unify` is a gap, so the
`last_position` and `linear_shallow` solvers the engine ships are reachable
from a written program rather than only from Prolog.
Constraint: every other door faces a value or stored data on one side and must
stay one-sided; upstream PeTTa is the arbiter, so where it answers, this engine
answers the same; and a gap-free ask must keep paying nothing.

## 2026-09-07

Tried: settling item 1's design by reading `metta_seq_classify/3`,
`metta_seq_unify/3` and the three solvers before touching anything, and
deriving each of the five rows by hand from Kutsia's rules -> every solver
already answers correctly when handed two PARSED sides, so nothing in the
calculus needed changing. `metta_seq_classify/3` is already symmetric
(`RightGaps == []` gives `one_sided(left)`, `LeftGaps == []` gives
`one_sided(right)`, and `metta_seq_unify(one_sided(right), L, R)` matches R
against L), and `metta_seq_store/3` already keeps Kutsia's trivial `X = X`
branch, which is why the identity row holds the moment both sides are parsed.
The whole defect was upstream of them, at the door.

Decided: parse B at the door and hand the emitted `metta_match_atoms/2` the
parsed right side; do NOT widen the plan term. `metta_seq_pair_plan/4` is two
lines over `metta_seq_plan/3`:

    metta_seq_pair_plan(Left, Right, Asked, ParsedRight) :-
        metta_seq_parse(Right, ParsedRight),
        metta_seq_plan(Left, ParsedRight, Asked).

The wrapper `'$metta_seq'(Plan, Parsed)` exists to make the LEFT operand
self-describing at a door that also takes unwrapped patterns, and
`metta_match_atoms/2` dispatches on it with a guard SWI compiles inline. The
right operand needs no self-description: the plan already names the solver, and
every solver reads its right side positionally.

Rejected: widening the wrapper to `'$metta_seq'(Plan, ParsedLeft, ParsedRight)`
or adding a second functor, which is the alternative the brief names. It would
change every producer (`metta_seq_head_plan/2`, `metta_seq_query_plan/2`,
`metta_seq_plan/3`) and both dispatchers (`match/4`,
`metta_match_atoms/2`), and would leave `metta_match_atoms/2`'s second argument
dead for a gap call, which is one more place for the two sides to disagree.
Revisit if a solver ever needs a per-side decision the plan cannot carry.

Tried: the narrow fix alone, parse B and pass it, which is what the earlier
journal entry proposed -> it REGRESSES two shapes that answer correctly today,
both measured on `petta` at 5a85f5602 before and after:

| written ask | before | narrow fix | with the repair |
|---|---|---|---|
| `!(collapse (unify $q (f a (:seg $v)) $q no))` | `((f a (:seg $_0)))` | `((f a ($metta_seg $_0 named)))` | `((f a (:seg $_0)))` |
| `!(collapse (unify &self (marker (:seg $l)) $l none))` | `($_0)` | `(none)` | `(((:seg $_0)))` |

The first is the one-sided solver publishing this engine's OWN parsed term into
an answer: `metta_seq_atoms/2` fell through to `metta_match_atoms/2`, which
binds an open subject to whatever it is handed. Parsing B newly routes a
variable-left ask through that fall-through, so the leak became reachable from
`unify`. It was already reachable from `let`:
`!(collapse (let (f (g (:seg $x)) b) $z ($z here)))` answered
`(f (g ($metta_seg $_0 named)) b)` on trunk and answers `(f (g (:seg $_0)) b)`
now. The second is the same fall-through handing a bare parsed pattern to a
SPACE, where `match` given the same written pattern answers rows.

Decided: `metta_seq_atoms/2` gets the complete subject case analysis it was
missing, in `metta_seq_faces/2`: an OPEN subject takes the pattern's surface
through `metta_seq_instantiate/2`, which splices every solved run and renders
every unsolved gap back to its marker; a SPACE subject takes the gap query
through `metta_seq_space/5`; anything else is the ordinary comparison. This is
the projection the two-sided solvers already make at `metta_seq_publish/1` and
that `attribute_goals//1` makes for an attributed variable: an internal store is
projected onto the query's own terms at the answer boundary, never published
raw. The one-sided solver was the one boundary that had no projection.

Tried: the arbiter, on the same eight programs, `sh run.sh <file>` in the
upstream PeTTa checkout at `ae66fa8e41dcd5539d614706bd4e5cfb34f9608d` with
`!(import! &self ../lib/lib_he)` first, because `unify` is a library equation
there. Ours are `sh run.sh` on this branch.

| program | before | after | upstream PeTTa |
|---|---|---|---|
| `(unify (f a b) (f a b (:seg $v)) $v none)` | `(none)` | `(())` | `(none)` |
| `(unify (f (g (:seg $x)) (h (:seg $x))) (f (g (:seg $y)) (h b)) $x none)` | `(none)` | `((b))` | `(none)` |
| `(unify (f (:seg $u) b) (f a (:seg $v)) ($u $v) no)` | `(no)` | `(((a) (b)))` | `(no)` |
| `(unify (f (:seg $u) (g a)) (f (g b) (:seg $v)) ($u $v) no)` | `(no)` | `((((g b)) ((g a))))` | `(no)` |
| `(unify (f (:seg $u)) (f (:seg $u)) yes no)` | refuses, `mixed_roles` | `(yes)` | `(yes)` |
| `(unify (f a b) (f a (:seg $v)) $v none)` | `(none)` | `((b))` | `(none)` |
| `(unify (f (g (:seg $u) b)) (f (g a (:seg $v))) yes no)` | `(no)` | refuses, `no_certificate` | `(no)` |
| `(unify (f (:seg $x) a) (f a (:seg $x)) yes no)` | refuses, `mixed_roles` | refuses, `no_certificate` | `(no)` |

Decided: the identity row is the one that governs. Upstream has no reading of a
gap at all, so it unifies two identical expressions and answers `yes`; this
engine refused, and the refusal's stated reason was false. Every other row is
an extension over ground upstream leaves undefined, because upstream reads the
marker as data and simply fails to unify. So the header block in
`engine/spaces/segment_matching.pl` loses one of its three "changes an upstream
answer" rows and keeps the other two as classes: a pair outside every fragment
(upstream `no`), and a genuine mixed-role pattern (upstream nothing through
`match`, `no` through `unify`).

Tried: whether `no_certificate` is reachable from a written program after the
fix -> yes, by two shapes, and one of them was already in the corpus.
`(unify (f (g (:seg $u) b)) (f (g a (:seg $v))) yes no)` fails the shallow
fragment on depth and the last-position fragment on position;
`(unify (f (:seg $x) a) (f a (:seg $x)) yes no)`, Kutsia's own infinitary
witness, has both gaps at the root but one name carrying both, so it is not
linear. The second is what `examples/.../01-segments.metta` and
`test_the_commuting_equation_refuses_naming_kutsia` already ask, and both stay
green: they assert the theorem and the fence, and only the reason word moved,
from the wrong `mixed_roles` to the right `no_certificate`. So the answer to
item 2 is reachability, measured, and `05-the-fence.metta` now asserts the
reason word for both shapes.

Tried: the cost, through `m.stats()` over one warmed ask each, engine reverted
to trunk for the before column and restored for the after
(`ai-tmp/seg/cost-probe.py`, loadavg 77, inferences rather than wall clock
because they are deterministic here):

| ask | before | after |
|---|---|---|
| `(unify (f a b) (f a b (:seg $v)) $v none)` | 402 | 390 |
| `(unify (f (g (:seg $x)) (h (:seg $x))) (f (g (:seg $y)) (h b)) $x none)` | 650 | 690 |
| `(unify (f (:seg $u) b) (f a (:seg $v)) ($u $v) no)` | 510 | 582 |
| `(unify (f (:seg $u) (g a)) (f (g b) (:seg $v)) ($u $v) no)` | 590 | 710 |
| `(unify (f (:seg $u)) (f (:seg $u)) yes no)` | 331 | 395 |
| control, `(unify (f a b) (f a b) yes no)` | 316 | 316 |
| control, one-sided `(unify (f (:seg $p) SEP (:seg $q)) (f a b SEP c) matched no)` | 522 | 522 |

Both controls are unchanged to the inference. The gap-free one is the
`metta_seq_written/1` guard doing its job: neither operand is a written gap, so
the door emits `metta_match_atoms([f,a,b],[f,a,b])` and no wrapper, which
`segments_written_pairs:a_gap_free_pair_emits_the_plain_matcher` now pins on the
emitted goal itself. The one-sided one says the walk `metta_seq_faces/2` was
added to costs nothing on the path that does not reach it.

Tried: attributing the six twin budget moves, because four of the six twins ask
no two-sided question at all. Each unchanged twin was measured min-of-3 on the
BRANCH BASE (5a85f5602) as a positive control and again on this branch:

| twin | pinned at a403e56b4 | on the base | on this branch | this change |
|---|---|---|---|---|
| `01-segments` | 9502 | 9664 | 9703 | +39 |
| `02-in-an-equation-head` | 16115 | 16176 | 16179 | +3 |
| `03-the-one-sided-fragment` | 7851 | 7868 | 7953 | +85 |
| `06-a-gap-query-and-its-index` | 51022 | 51301 | 51301 | 0 |

So most of each move is drift between the commit the numbers were taken at and
this branch's base, and none of it is dismissed. The +39 and +85 are the right
operand being parsed: those twins ask through `m.fn.unify`, which is translated
at the ask, so the parse is counted in the ask. The +3 is twin 02, which writes
no `unify` at all: it is what its equation heads pay at the three positions
where an expression pattern faces a non-expression subject and now reaches
`metta_seq_faces/2` before `metta_match_atoms/2`. Twin 06, the gap query over
2,000 stored atoms, is identical on both trees, which is the measurement that
matters: the one-sided hot path is untouched.

Decided: keep `metta_seq_faces/2` as a named predicate rather than inlining its
three branches into `metta_seq_atoms/2` to save one call. Inlining would halve
a cost measured at 3 inferences across the whole chapter-8 twin set and 0 on
the 2,000-atom gap query, and the named form is the module's own idiom.
Revisit if a profile ever names that position.

Open: `seam:custom_match/2` still receives a parsed side when a gap pattern
faces a foreign matchable value, which is the one subject kind
`metta_seq_faces/2` leaves to `metta_match_atoms/2`. Refuting is the right
answer there and refuting is what happens, so nothing observable is wrong; it
is listed because the same projection argument applies if a provider ever reads
the term it is offered rather than comparing it.
