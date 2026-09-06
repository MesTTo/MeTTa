# A cost is a claim the gate can fail
Goal: let a head declare the class its cost grows in, and make that
declaration something a lane can refute rather than a comment.
Constraint: the checker is dynamic. Static inference of the class is the
research half of this thread and is not claimed here. The counter has to be
deterministic, because this box runs at loadavg 45 to 77.

## 2026-09-07

Decided: the row is `(cost <witness> <class>)` with an optional fourth measure
field, a catalog kind preset beside `cache`, and the class a new `cost-class`
vocabulary. That is Ciao's assertion language adopted rather than reinvented:
`:- check comp nrev(A,B) + steps_o(length(A))` states the same thing and
CiaoPP discharges it against statically inferred bounds, and its size measures
are list-length, term-size, term-depth and integer-value
[source: https://ciao-lang.org/ciao/build/doc/ciaopp_tutorials.html/tut_advanced.html].
What changes is the checker: measured here, proved there.

Decided: the hole is "exactly one distinct VARIABLE in the witness", not a
variable named `$n`. Tried the name first and it cannot work: `sread` answers
`[cost,[nrev,_442348],quadratic]`, so a MeTTa variable is an anonymous Prolog
variable by the time the row is stored and the spelling is gone. Repeated
occurrences of one variable stay one hole, which is what makes
`(intersection-atom $n $n)` a legal witness that sizes both operands together.
A witness needing free binders, `(foldl-atom $n 0 $a $b (+ $a $b))`, is
therefore refused, and that is the design's own refusal rather than an
oversight.

Decided: the engine owns the measure derivation, not the lane. The arrow at
the hole's position decides it, `Number` giving Ciao's integer-value measure
and everything else its list-length measure, and `metta_cost_declaration/4`
answers the resolved pair. One derivation then serves `(explain ...)`, the
Python docstring and the benchmark lane instead of three.

Defect found and fixed in that derivation: the parameter type was UNIFIED with
`'Number'`. `(: min-atom (-> $a Number))` carries a type variable at the hole's
position, that variable unifies, and the whole polymorphic family read as
integer-sized. Measured: `(cost (min-atom $n) linear)` then handed min-atom the
number 2048 where it wants 2048 children and read a flat 409 inferences,
exponent -0.005, against 0.978 with `==`. The lane's own red is what found it.

Tried: putting the shipped rows in `engine/prelude.metta` as
`!(add-atom &metta (cost ...))`. Rejected: `load_prelude_form/3` takes exactly
one runnable shape, `add-translator-rule!`, so that the prelude cannot smuggle
execution into boot, and anything else throws `domain_error(prelude_form, ...)`.
Decided instead: a bare `(cost ...)` form is the prelude's THIRD declaration
about its own vocabulary beside `(: ...)` and `(@doc ...)`, handled by a new
declarative clause that writes the row through `add_sexp/3`, the ordinary
catalog door, so the same checker validates the engine's rows as a program's.
Eviction withdraws it: `evict_prelude_definition/1` already drops the type and
the doc atom when a program takes a prelude name over, and a cost claim
measured on the prelude's equations must go with them.

Tried: leaving `lib_builtin_types.metta`'s rows to reach `&metta` only through
an explicit `!(import! &self (library lib_builtin_types))`. Verified that path
works, and rejected it anyway: `explain` and every docstring answer from
`&metta`, so a row nobody imports is a claim nobody sees. Decided: the boot
pass that already parses that file for its `(: ...)` rows reads its `(cost ...)`
rows too, one `forall` beside the other, since a claim about a builtin belongs
where the builtin's surface is declared and has to be loaded to be worth
anything.

### The ladder, measured rather than taken from the design

The design specified a length ladder of "a flat expression of n symbols, under
MAX_FLAT_CHILDREN 1024" and an exponential value ladder of `4 6 8 10 12`.
Neither survived measurement.

Tried: 512 to 4096. The six linear rows read 0.81 to 0.96 and the linearithmic
ones 1.06 to 1.09, a gap of 0.15 with the linear fits still climbing, because a
per-call floor of about 2,300 inferences dominates the low end.
Tried: 2048 to 16384. Linear reads 0.962 to 0.990 and linearithmic 1.056 to
1.090, pair slopes settled. Decided that ladder. `MAX_FLAT_CHILDREN` does not
bound it: that ceiling is SWI's `max_procedure_arity`, which a flat expression
meets only when STORED as a space fact, and a fixture here is an argument the
reader never asserts. A 16,384-child argument crosses and evaluates with no
arity error.

Tried: the exponential ladder `4 6 8 10 12` on the fib control. Its semi-log
slope reads 0.088 there, because the ~7,500-inference floor is most of the
measurement; the counts are 7537, 7656, 8097, 9252, 12276.
Decided: 16, 18, 20, 22, where the counts are 36846, 91065, 233134, 605081 and
the slope reads 0.6734.

Decided: the length fixture is a deterministic pseudorandom permutation of n
distinct integers, from an LCG transcribed into the lane rather than from
`random.sample`, whose algorithm the standard library reserves the right to
change under a ledger that pins exact counts. Distinct, so a dedup does work;
unsorted, because `0..n-1` in order is the best case of every comparison sort
and a row measured on it would claim a class the head has only for input
somebody else already sorted.

### The exponential class needs a different estimator

Measured: the same fib control reads log-log exponent 6.887 over sizes 14 to 20
and 8.466 over 16 to 22. The exponent of a curve no power law describes is a
property of the LADDER, so a band on it cannot decide the class.
Decided: `curves.exponential_fit`, a semi-log regression reporting doublings per
unit of size. Measured on one ladder: fib 0.650, a synthetic cubic 0.230, the
quadratic control 0.0121, a linear row 0.0002. The floor sits at 0.30, with the
log-log exponent above 3.5 as a second condition.

### The bands, and the gap that is deliberate

Rejected: an upper bound alone, which is Ciao's `check comp` reading. It would
let every head declare `quadratic` and never be wrong. Decided: a band per
class, checked in both directions, with the floor half armed by its own
control. Measured on the ladders above: constant -0.003, linear 0.962 to 0.990,
linearithmic 1.056 to 1.090, the quadratic control 1.932.

Neighbouring bands below quadratic overlap so the gate stays quiet at a
boundary. `linearithmic` at 1.30 and `quadratic` at 1.60 do NOT meet, and that
gap is kept: a curve at n^1.45 is neither, this vocabulary has no word for it,
and stretching the bands together would let such a head declare the cheaper
one. Ciao has no gap here because `steps_o` takes an arbitrary cost function
where this takes one of six names.

### What the second counter changed about which rows ship

The lane gates on inferences, which are deterministic: two full runs at loadavg
53 and 77 returned identical counts for every row at every size, zero spread.
It is therefore blind to work that crosses into C, which is LAW 2 in this tree,
and `--paired` is the second reading.

Measured, inferences against retired instructions:

| head | inferences | instructions | verdict |
| --- | --- | --- | --- |
| `+` | -0.003 | 0.003 | agree, constant |
| `car-atom` | 0.972 | 0.965 | agree, linear |
| `cdr-atom` | 0.976 | 0.999 | agree, linear |
| `size-atom` | 0.970 | 0.967 | agree, linear |
| `union-atom` | 0.985 | 0.992 | agree, linear |
| `union` | 0.994 | 1.000 | agree, linear |
| `index-atom` | 0.963 | 0.963 | agree, linear |
| `reverse` | 0.978 | 1.035 | agree, linear |
| `alpha-unique-atom` | 1.076 | 1.079 | agree, linearithmic |
| `intersection-atom` | 1.090 | 1.086 | agree, linearithmic |
| `subtraction-atom` | 1.092 | 1.108 | agree, linearithmic |
| `alpha-unique` | 1.057 | 1.064 | agree, linearithmic |
| `intersection` | 1.073 | 1.082 | agree, linearithmic |
| `subtraction` | 1.077 | 1.107 | agree, linearithmic |
| `unique-atom` | 0.978 | **1.057** | DISAGREE |
| `unique` | 0.990 | **1.053** | DISAGREE |
| `msort` | 0.976 | **1.055** | DISAGREE |

The disagreement is mechanical, not statistical.
`'unique-atom'(A, B) :- list_to_set(A, B)` is one foreign call, and SWI's
`list_to_set/2` sorts; the engine retires one inference for work that is n log
n, so the inference curve is the ARGUMENT arriving. `intersection-atom` and
`subtraction-atom` build a `count_assoc` of one operand and look the other up
in it, which is Prolog's own n log n and which both counters see;
`union-atom` is `append/3`; `alpha-unique-atom` walks an AVL through
`put_assoc`.

Decided: a row ships only for a head whose two counters agree. `unique` and
`unique-atom` therefore carry none, with the reason written beside each of
them, and the lane prints `PAIRED DISAGREES` under `--paired` for any shipped
row that starts to drift that way. The alternative, shipping
`(cost (unique-atom $n) linear)` because it is true of the counter the gate
reads, was rejected: the docstring line cannot carry the counter caveat and a
reader would take it for the cost.

Revisit if the row grows a counter field, or if the gate acquires a
load-immune instruction counter.

### The ten rows

Each was measured before it was written; the ledger
`extensions/python/benchmarks/cost-baseline.json` carries the counts.

| row | file | exponent | class |
| --- | --- | --- | --- |
| `(cost (+ $n 1) constant)` | `lib_builtin_types.metta` | -0.003 | constant, `int` measure |
| `(cost (car-atom $n) linear)` | `lib_builtin_types.metta` | 0.972 | linear |
| `(cost (cdr-atom $n) linear)` | `lib_builtin_types.metta` | 0.976 | linear |
| `(cost (size-atom $n) linear)` | `lib_builtin_types.metta` | 0.970 | linear |
| `(cost (union-atom $n $n) linear)` | `lib_builtin_types.metta` | 0.985 | linear |
| `(cost (intersection-atom $n $n) linearithmic)` | `lib_builtin_types.metta` | 1.090 | linearithmic |
| `(cost (union (superpose $n) (superpose $n)) linear)` | `prelude.metta` | 0.994 | linear |
| `(cost (intersection (superpose $n) (superpose $n)) linearithmic)` | `prelude.metta` | 1.073 | linearithmic |
| `(cost (subtraction (superpose $n) (superpose $n)) linearithmic)` | `prelude.metta` | 1.077 | linearithmic |
| `(cost (alpha-unique (superpose $n)) linearithmic)` | `prelude.metta` | 1.057 | linearithmic |

The headline fact for a reader is the `union-atom` / `intersection-atom` pair:
an append against an association tree, one linear and one linearithmic, and the
same difference again at the stream level between `union` and `intersection`.

### A memoised head under its shipped policy

The design asks for `fib` measured both ways. `lib_memo` ships no such head, so
this is the lane's own exponential control rather than a shipped row, measured
on sizes 16 to 22 with a fresh space per size:

- under `(cache <head> refuse)`: 36846, 91065, 233134, 605081 inferences,
  doubling slope 0.6734, log-log exponent 8.777. Exponential.
- under the automatic memo, on sizes 40 to 320: 34542, 47373, 175588, 671438,
  log-log exponent 1.473. NOT linear, which the design predicted: the answer is
  a bignum, `fib(320)` has 67 digits, and adding k-digit numbers is O(k) with k
  growing linearly in n, so the memoised recursion is quadratic in bit cost.
  At sizes 4 to 12 the same head reads CONSTANT, because the ~20,000-inference
  per-call floor is the whole measurement there.

A fresh space per size is what keeps the refused reading exponential: compiled
clauses and their memo live in the space's module, so measuring size 22 after
size 16 in one space reads a warm memo. Each row also gets a fresh PROCESS.

### What the lane costs

Measured 2026-09-07, four runs at loadavg 45 to 72: 16.2, 22.6, 29.6 and 31.0
seconds wall for all fifteen rows, ten shipped and five controls. The two
quadratic controls are most of it, and they run on 64 to 512 rather than the
length ladder because 16,384 squared is 2.7e8 answers; the sibling `scaling`
lane makes the same choice for its own planted quadratic. Cross-run inference
spread is zero.

Open: `size` and `depth`, two of Ciao's four measures, have no ladder here and
a row naming one is refused by name. Adding them is a builder each; nothing
shipped needs them yet.
Open: no shipped row uses the optional measure field, because no shipped head's
arrow decides the wrong measure. The field is exercised by the tests.
Open: the lane carries no constant-factor guard, unlike `scaling`. Absolute
counts are already pinned by `baseline.json` and by `scaling`'s growth gate, and
a second tripwire here would turn every unrelated constant change into a red.

### What the vocabulary row costs, measured and attributed

Adding the `cost-class` vocabulary is not free, and the mechanism is the one
`2026-09-05-catalog-arity-enumeration.md` already priced.

Measured: the row `(vocabulary cost-class constant log linear linearithmic
quadratic exponential)` is eight elements wide, so it is stored as
`'&metta'/8`, an arity this engine did not have. The `&metta` storage goes from
twelve distinct arities to thirteen: `[2,3,4,5,6,7,10,11,12,13,15,21]` becomes
`[2,3,4,5,6,7,8,10,11,12,13,15,21]`.

An OPEN-TAIL catalog query enumerates every storage arity, by the design that
thread settled after rejecting both a membership walk and an index build on
measurements. Measured directly, a miss on `[annotations, &x|_]` costs 68
inferences at twelve arities and 73 at thirteen: **+5 per open-tail query per
added arity**. A fixed-width query costs 8 either way and is unaffected.

Attributed: `annotated-relation` performs 15 open-tail `[claim|_]` queries per
evaluation (counted by instrumenting the open-tail branch and running ten
evaluations: 150 queries, all of them `claim`), so it pays +75 per evaluation
and +37,500 over its 500. That is the whole of this branch's movement on the
Python counter suite: every other row in `benchmarks` measures IDENTICALLY to a
pristine control at the branch base, to the inference
[measured 2026-09-07; command=sh check.sh benchmarks on this tree and on a
detached worktree at 5621c456; fixture=matching C and MORK artifacts on both;
commit=WORKTREE].

The identity twin moves the OTHER way and is not attributed to a mechanism.
Measured under the same provisioned configuration by lowering its own `BUDGET`
so the harness prints the count: 3,462 on the pristine control, failing its
3,422 pin by 40, and 3,422 on this branch, exactly the pin. That is the
boot-content clause-indexing class `baseline.json`'s own repin comments
describe, where inert boot content moves a count through indexing shape; no
mechanism is claimed for it here either, and the branch is not credited with an
improvement it cannot explain. An earlier reading of 3,462 against 3,472 was
taken before this worktree had the C reader, writer, JSON and extension
artifacts and compared two unprovisioned trees; it is superseded by the pair
above.

Isolated to the vocabulary row alone, not to the rest of the branch: reverting
`engine/spaces/catalog.pl` to its base returns 820,627, and applying ONLY the
`cost-class` preset clause to the base file returns 858,127, the same reading
as the whole branch. Reverting each of the other six changed engine files
changes nothing. Removing the ten shipped rows changes nothing: 858,127 either
way, so the cost is the vocabulary's WIDTH and not the rows.

Not re-pinned here, on purpose. `annotated-relation` is pinned at 315,385 and
the pristine control at this branch's base already measures 820,627, so 505,242
inferences of that row's gap arrived before this branch and are not this
branch's to absorb; re-pinning would hide them inside this commit. The same
holds for the identity twin's pre-existing 3422 to 3462. Both numbers are here
so the next re-pin can subtract this branch's share exactly.

Found and NOT fixed here, with its measurement, because it is a pre-existing
cost this branch only makes 7% larger rather than one it causes:
`metta_vocabulary_claim/3` (engine/metta/effects.pl) reads
`metta_catalog_row([claim, Vocab, Value|Properties])` with an open tail and no
cache, and `metta_annotations_order/2` calls it on every `(top k ...)`
evaluation. At 15 calls and 73 inferences each that is about 1,095 of the
workload's 1,756 inferences per evaluation, 62% of it, spent re-reading one
catalog row. A cache with the invalidation `metta_vocab_cache` already has
would take it to single digits. That is its own change, in the annotations
path rather than in this one, and it is written down here rather than bundled
into a branch about declaring costs.
