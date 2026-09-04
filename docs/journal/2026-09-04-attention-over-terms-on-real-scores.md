# Attention over terms, on scores a network produced

Goal: `lib_measure`'s softmax and `lib_soft`'s scorer work on the inputs their
own headers point at, network scores and a space's equations, rather than only
on small hand-written tables.
Constraint: no answer inside the safe range moves, and `soft-match` over a
space stays affordable.

## 2026-09-04

Reported downstream, both open on 0.7.3.

### ws-softmax overflowed

Tried: reproducing. `(ws-softmax ((1000.0 a) (1001.0 b)) 1.0)` answers
`((NaN a) (NaN b))` where the same one-unit gap at `((1.0 a) (2.0 b))` answers
`(0.2689 0.7311)`. Found a second failure the report did not name: the other
tail refuses rather than NaNs, `((-1000.0 a) (-1001.0 b))` giving
`(Error ... "ws-normalize requires nonzero total mass")`, because every term
underflows to zero.

Decided: subtract the peak before exponentiating, the standard remedy, which
`scipy.special.softmax` and every array library apply. Softmax is invariant to
a constant shift so nothing in the safe range moves, and after the shift the
largest term is `exp(0)` exactly, so the mass is neither zero nor infinite.
The shift is taken AFTER the division by the temperature, on the scaled
scores, which is what makes it hold for a negative temperature too.

### soft-score ran the program it was scoring

Tried: reproducing.
`(soft-score (= (tepid $x) $b) (= (warm $y) (* $y 2)))` refused with "* ran
backwards with more than one unknown", correct arithmetic met in the wrong
place. Both parameters were undeclared, so both operands were evaluated on the
way in.

Decided: `(: soft-score (-> Atom Atom Number))` and the same for `sym-sim`.
The call now answers a degree, and `(soft-score (likes cat (+ 1 2)) ...)` no
longer adds. Scoring a bare head worked either way, which is why the library's
own examples never met this.

### The aggregation is now a choice, and it cost three tries to make it free

The same report notes that `min`, the fuzzy t-norm, takes an otherwise strong
match to zero on one unrelated symbol, which flattens a ranking. The default
stays `min`; the choice is a declaration, `(soft-aggregate mean)`, which is
Bousi~Prolog's own shape for the same decision.

Measured first, because the shape depended on it: the existing walk stops at
0.0, and that early stop is worth 1.93x on a `soft-match` over 400
six-position candidates, 98,135 inferences against 189,341
[ai-tmp/probe_soft_cost.py]. So an aggregation had to keep it.

Tried: an aggregation as four accessors, a unit, a combine, a finish and a
halting degree. Rejected: they are called PER POSITION, and the scorer cost
322,179 inferences against 98,135 on the mismatch case and 1,001,407 against
189,341 on the match case, three to five times.

Tried: dispatching the fold and the walk on the aggregation's name, two
clauses each, so a clause head is selected once where an accessor was called
per position. Better, 218,975 and 600,591, and still 2.2x.

Found the rest by removing one thing at a time: the `Symbol` declaration on
the aggregation parameter. `Symbol` is a METATYPE, and a metatype parameter is
checked through the typing-rule registry on every call; two such checks per
position were more than doubling the fold. Declared `%Undefined%` the same
code costs 99,369 and 195,375, so the whole aggregation seam is +1.3% and
+3.2% over the scorer that had no seam at all.

Decided: `%Undefined%` for now, with the reason and the numbers beside it, and
the `Symbol` declaration restored when the metatype check stops costing more
than the work it guards. That check is the same cost class as the parity
corpus's worst row, `04-nilbc.metta` at 12.66x, whose own waiver measures
argument type checking at 99.4% of the file; this is an independent workload
saying the same thing, and it is the entry point for that work.

Open: the report's other half, a declared algebra deciding carrier closure by
its own equality, which would let a fused semiring hold tensors. Not started.
