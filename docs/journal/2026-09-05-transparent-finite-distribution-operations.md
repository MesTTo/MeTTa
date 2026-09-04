# Transparent finite distribution operations

Goal: add unary and binary composition, comparison, threshold mass, joint
conditioning, average, and Bernoulli update to the existing finite weighted
value representation.
Constraint: keep weight-first rows transparent and pure, refuse invalid mass,
and make every dependence assumption and comparison meaning visible at the call
site.

## 2026-09-05

Tried: reading the PeTTaChainer formulas beside ProbLog, PRISM, Scallop, NumPy,
SciPy, and Apache Commons Math. The common transferable construction is a
push-forward over one support and a product measure over independent supports,
with multiplication across choices and addition when outcomes coincide.
[source: https://github.com/numpy/numpy/blob/2f7fe64b8b6d7591dd208942f1cc74473d5db4cb/numpy/_core/numeric.py#L793-L801; commit=WORKTREE]
ProbLog and Scallop expose that addition-and-multiplication split directly in
their probability semirings. PRISM states the semantic side condition: factors
multiply for independent switch instances and explanations add when mutually
exclusive.
[source: https://github.com/ML-KULeuven/problog/blob/168f0399543f32506253fd9f7774dd8aa1222be8/problog/evaluator.py#L184-L209 and https://github.com/scallop-lang/scallop/blob/668bfb6d45ce302fd4ffa7f29916baf3c7ce36ef/core/src/runtime/provenance/probabilistic/add_mult_prob.rs#L48-L62; commit=WORKTREE]
[source: https://rjida.meijo-u.ac.jp/prism/download/prism23.pdf, PDF page 20, sha256=7998dda53cdcfb713228dff497eaef59e7cc4608a712a42683aa83a9cb6b36e3; commit=WORKTREE]

Rejected: `NatDist` and `FloatDist`, because the swept repository contains the
names but no implementations. Rejected: a particle ID and global backing store,
because no ownership or approximation case requires an opaque representation.
Rejected: reconstructing correlated inputs from marginals, because the lost
joint law cannot be recovered downstream. The correlation-preserving route is
an explicit distribution of `(Pair input output)` values.

Decided: `ws-map2-independent`, `ws-average-independent`,
`ws-prob-gt-independent`, and `ws-add-bernoulli-independent` carry the product
assumption in their names. Binary rows are enumerated left-major and equal
outputs merge at their first occurrence. Each public operation normalizes its
inputs and every distribution result, so positive relative weights are valid
input while negative, nonfinite, empty, and all-zero inputs refuse with a
remedy.

Rejected: a function named `compare`, because it would silently choose among
incompatible questions. Decided: preserve PeTTaChainer's useful strict win
probability as `ws-prob-gt-independent`, exactly `P(X > Y)` with ties worth
zero. First-order stochastic dominance remains a relation over every threshold;
total variation remains a symmetric distance; expectation ordering remains a
scalar summary. None is an alias for another.
[source: https://github.com/rTreutlein/PeTTaChainer/blob/b0e24f9b9d7106ccabf51917f1703abf3ab8c570/pettachainer/metta/dist_formulas.metta#L296-L310; commit=WORKTREE]

Decided: `ws-mass-at-least` is inclusive. The name states the boundary and the
requested law then holds at the minimum support value. Rejected the upstream
strict-threshold spelling because it would make that law false.

Decided: joint conditioning is exact equality on the first field of an explicit
`Pair`, followed by normalization of the matching slice. Rejected the upstream
structural-distance kernel and bandwidth because they introduce a similarity
model that this finite exact layer neither owns nor needs. Zero overlap refuses
and tells the caller to choose an observation in the joint support.

Decided: Bernoulli update means additive convolution with an independent
Bernoulli trial. Its probability is explicit and checked in `[0, 1]`; deriving
it from a proposition's STV was rejected because value uncertainty and truth
answer different questions.

Tried: exact idempotence under binary64 normalization. It is not a truthful
machine-level law for arbitrary decimal weights: normalizing weights
`(1, 16, 1, 1)` totals `0.9999999999999998`, so another division changes low
bits. Decided: laws compare floating masses with tolerance, while an already
unit-mass distribution avoids division and exact dyadic fixtures pin ordering,
duplicate collapse, and convolution without numerical ambiguity.

Tried: the executable average witness expected `3.0`. The engine answered exact
integer `3` for `(/ 6 2)`, and the test correctly failed because integer and
float outcomes are distinct. Rejected: coercing an exactly divisible arithmetic
mean to a float merely to fit the fixture. Decided: preserve the engine's numeric
result and expect `3`; a separate `1` versus `1.0` fixture pins that outcome
identity is not silently collapsed.

Tried: normalize two finite weights of `1.0e308`. Their direct sum overflows.
Decided: only on that overflow path, divide every positive weight by the largest
one and retry normalization before duplicate collapse, which avoids a duplicate
bucket overflowing first. Distinct outcomes produce `((0.5 0) (0.5 1))` and
equal outcomes produce `((1.0 0))`; ordinary already-unit and finite-total paths
retain their exact spelling.

Tried: pass empty and negative distributions through the composition heads.
Binding `ws-normalize`'s refusal and then iterating over it treated the three
fields of `(Error culprit remedy)` as distribution rows, producing secondary
arithmetic errors. Rejected: relying on an error term to propagate through a
`let` binding, because `let` deliberately exposes the value as data. Decided:
guard every normalized binding and the average fold with `if-error`; all seven
heads now preserve the original normalization remedy, including invalid inputs
on either side of a product [tested:
test_operations_preserve_the_normalization_refusal; commit=WORKTREE].

Measured: eight Hypothesis properties generated 100 passing distributions or
distribution tuples each, 800 law cases total, with weights from 1 through 8,
integer outcomes from -8 through 8, one through four rows per support, duplicate
outcomes admitted, and Bernoulli probabilities from the five dyadic endpoints.
The module reported 18 passing tests in 4.74 seconds under
`HYPOTHESIS_PROFILE=ci`. The repository registers only `metta` and `ci`, so the
requested but nonexistent `petta` profile was not used [tested:
test_distribution.py under HYPOTHESIS_PROFILE=ci; commit=WORKTREE].

Measured: the numbered example passed all 16 runnable checks, and the
engine-versus-Python parity runner reported `1/1 examples agree across both
configurations`. `jscpd --reporters ai --min-lines 5 --min-tokens 40` over the
new library, example, and test reported zero clones and 0.0 percent duplication,
so dry-refactoring had no extraction to make [tested:
examples/ch22-a-reasoner-you-can-serve/22-02-weighted-answers/12-distribution.metta;
commit=WORKTREE].

Found: the earlier `17-verify-discharges.metta` introduced `pragma!` in chapter
9 while `syntax_introductions.txt` still named chapter 14. Git history assigns
both files to MesTTo. Decided: correct the introduction coordinate to
`09-00-17`; the cumulative-syntax check then reads 240 examples and zero
findings. The example and library rosters were regenerated or corrected to 253
total examples, 235 shell-runnable examples, and 35 libraries.

Found: the evidence checker named
`metta_metatype_guards:an_audited_discharge_raises_a_disagreement`, but the
existing test is declared inside `begin_tests(discharge_audit)`. Git history
assigns both the tag and test to MesTTo. Decided: correct the suite qualifier to
`discharge_audit` so the evidence lane resolves the test it already intended to
name.

Tried: `GATE_ONLY=1 sh check.sh` under the shared gate lock on the functional
snapshot. It ran for 989.13 seconds and passed the distribution example,
engine/Python example parity, `lib-surface`, `layering`, `plunit`, `llms`,
`evidence`, `libdoc`, and the other functional lanes, but exited 1 with eight
red lanes: `engine-bench`, `prolog-static`, `c-bench`, `mork-bench`, `pytest`,
`benchmarks`, `policy-inventory`, and `parity-perf`. The MORK lane included
`perf stat failed with exit 2: Events disabled` and a second-session PMU
ownership error, so that measurement cannot support a performance conclusion
[tested: GATE_ONLY=1 sh check.sh; commit=WORKTREE].

Tried: the same focused failure checks in a detached `e8356642` control. Its
Python suite already had three failures: the unpublished
`metta_host_time_budget/3` transport call, a Ruff `D` count of 2232 against a
2231 maximum, and absolute paths in two earlier journal files. Its
`prolog-static` lane had the same unpublished transport call, and its
`policy-inventory` lane had the same two missing closed-policy exemptions in
`engine/metta/types.pl` [tested: repository pytest, prolog-static, and
policy-inventory controls; commit=e8356642aca8366e21b9e0f4517601cc9b657a04].
Decided: remove this work's one avoidable `D103` suppression so the feature
leaves the Ruff count at the base's 2232, and do not fold unrelated engine and
earlier-journal repairs into this distribution change [tested:
test_the_ruff_configuration_enables_every_family_or_records_why_not;
commit=WORKTREE].

Tried: a locked A/B run of `python bench.py --counter-only --keep-going
alpha-unique annotated-relation eval-arith source-load typed-call add-single`
on the feature tree and detached `e8356642`. `add-single` passed on both. The
same other five cases failed on both, with equal minima for `alpha-unique`
(3752466), `eval-arith` (278811), `source-load` (234733), and `typed-call`
(12505948); `annotated-relation` differed by two inferences, 308330 versus
308332 [measured: five matching failures and one matching pass; command=python
bench.py --counter-only --keep-going alpha-unique annotated-relation eval-arith
source-load typed-call add-single; fixture=feature tree and detached e8356642
control under the shared gate lock; commit=WORKTREE].
Decided: the full lane's 16 stale counter pins predate the new library;
re-pinning them here would hide rather than repair the frozen-base condition.

Open: the frozen base's eight full-gate lanes remain red for the failures above
and its other pre-existing performance pins. The distribution surface itself
has no open obligation.
