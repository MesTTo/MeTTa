# PeTTaChainer adaptations stay on PeTTa library seams

Goal: settle findings 5, 6, 7, 9, 10, 11, 13, and 14 against the live
`petta` source, implement the justified library adaptations, and preserve the
sweep's refusal boundary.

Constraint: PeTTaChainer commit
`b0e24f9b9d7106ccabf51917f1703abf3ab8c570` has no license file. Its source
may be studied but not copied. Kernel type and translator files are owned by
other work, and finding 5 is assigned to another slice.

## 2026-09-05

Tried: checked the 186 selected `.metta`, `.py`, `.pl`, and `.md` files in the
PeTTaChainer snapshot against a sorted, target-relative `sha256sum` manifest.
The four aggregate digests reproduced the sweep exactly, including
`0d4760125b2bbb98ca138a1aef463032ef15b0852b1a75cd209a537c35d4aea3`
for the 148 MeTTa rows.

Decided: ship only
`docs/provenance/pettachainer-b0e24f9b-manifest.json`. It records the pinned
upstream commit and 186 content digests without redistributing any upstream
source or fixture bytes.

### Finding 5: distribution operations

Verified: `lib/lib_measure/lib_measure.metta` still exposes normalization,
stable softmax, ranking, top-k, sample, collapse, expectation, choose, filter,
and flip. At the starting commit it has no binary map/convolution,
distribution comparison, threshold-mass operation, joint conditioning, or
normal constructor. `lib_soft` consumes the measure representation and is not
a second distribution representation.

Decided: **BLOCKED BY OWNERSHIP**. This finding is assigned to the distribution
slice, so this branch does not touch `lib_measure` or create a competing
`lib_distribution`.

### Finding 6: dependence-aware proof factoring

Verified: the sweep's line anchors moved. `DeclaredAlgebra` combines values at
`extensions/python/metta/algebra.py:169-226`, while `_Trace` retains neutral
derivation structure at `:238-269`. Source tokens are query-local ordinals
created by `_program` at `:868-897`, not caller-stable signed identities.
`_derive_rule` rejects overlap only for a carrier declaring `linear` at
`:929-963`; `_fuse` at `:998-1020` combines overlapping alternatives without
factoring. `lib_pln` has stamp utilities but no common-support factorization.

Tried: mapped the requirement to database lineage and polynomial provenance.
Green, Karvounarakis, and Tannen distinguish alternative derivations from
joint use through semiring addition and multiplication
([DOI 10.1145/1265530.1265535](https://doi.org/10.1145/1265530.1265535)).

Rejected: copying PeTTaChainer's proof store, quadratic list intersections, or
calling query-local ordinals stable evidence IDs. Revisit actual common-factor
pooling only when a reasoner owns stable signed source identities, a proof DAG,
hypothesis/evidence separation, cycle policy, invalidation, and explicit
materialization.

Decided: **ADAPTED** the safe opt-in boundary in `lib_pln2`. Every independent
formula takes `(supported (moments MEAN VARIANCE) (ID ...))`, preserves exact
term IDs, and rejects duplicate or overlapping support. The rejection names
the supported remedy: factor shared support in an owned reasoner, then pass
only disjoint residual supports.

### Finding 7: selected CTV and Beta formulas

Verified: `lib/lib_pln/lib_pln.metta:145-171` still marks induction and
abduction confidence as TODO-level and gives modus ponens a fixed fallback.
Its equivalence formula at `:200-207` still documents a workaround for absent
distributional truth values. No CTV, Beta, or variance-valued truth module was
present at the starting commit.

Tried: fixed the representation against the standard Beta mean and variance
([NIST Beta distribution](https://www.itl.nist.gov/div898/handbook/eda/section3/eda366h.htm))
and the conjugate update against `alpha + successes, beta + failures`
([Stan User's Guide 2.22](https://mc-stan.org/docs/2_22/stan-users-guide/exploiting-conjugacy.html)).
For mutually independent `X`, `Y`, and `Z`, direct second-moment expansion
gives:

```text
Var(XY) = Var(X)Var(Y) + Var(X)E[Y]^2 + Var(Y)E[X]^2
Var(ZX + (1-Z)Y)
  = E[Z]^2 Var(X) + (1-E[Z])^2 Var(Y)
    + (E[X]-E[Y])^2 Var(Z) + Var(Z)(Var(X)+Var(Y))
```

Rejected: wholesale replacement of `lib_pln`; a hidden `k=800`; endpoint or
zero-variance inversion to an invented finite confidence; clipping; ratio
variance without its missing validation fixture; and the `0.25`
negative-branch confidence discount. Revisit each omitted formula only with an
independent derivation, limiting-case checks, and a named caller.

Decided: **ADAPTED** a separate `lib_pln2` with explicit evidence scale,
confidence/count conversion, Beta moments and update, STV/moment conversion,
independent products, conditional total probability, and explicit support
checking. Generated tests check the algebraic laws rather than selected
examples.

### Finding 9: weighted-subset posterior

Verified: no reusable all-marginal subset posterior exists in PeTTa.
`lib_measure` can represent weighted rows and
`extensions/python/examples/reasoning/neurosymbolic_addition.py` exhaustively
enumerates a small product, but neither provides conditioned mass and every
candidate marginal.

Tried: mapped the problem to a generalized Poisson-binomial sum and
forward/backward inference. Zhang, Hong, and Balakrishnan define the generalized
case where Bernoulli variables take arbitrary paired values
([arXiv:1702.01326v1](https://arxiv.org/abs/1702.01326v1)). Serang's
probabilistic convolution tree merges paths with the same sum and uses
forward/backward messages to recover marginals
([DOI 10.1371/journal.pone.0091507](https://doi.org/10.1371/journal.pone.0091507)).
Open-source Poisson-binomial implementations also form the probability
generating-function coefficients incrementally, but their dense floating rows
do not satisfy this surface's exact-key contract.

Rejected: PeTTaChainer's unlicensed 404-line implementation, floating sum
identity, positional candidate identity, implicit scale selection, and a
posterior value for a zero-mass observation. Revisit rational losses only with
a caller-supplied common-denominator contract and a measured need that
outweighs the larger integer lattice.

Decided: **ADAPTED** two `lib_combinatorics` operations. A candidate is exactly
`(candidate ID LOSS (ratio NUMERATOR DENOMINATOR))`; IDs are unique ground
acyclic terms under Prolog `==`; losses and targets are nonnegative integers;
and priors and outputs are reduced exact ratios. Sparse sorted prefix and
suffix rows are truncated at the target. Their two-pointer joins recover all
marginals in `O(NR)` arithmetic operations and `O(NR)` retained row cells,
where `R` is the maximum target-bounded reachable-row width. Integer bit cost
still grows with the product of prior denominators. The mass operation returns
exact zero; the posterior operation rejects zero mass and points callers to
the mass operation. Candidate order is preserved, and exhaustive `chooseK`
remains separate for callers that need every subset.

### Finding 10: premise vocabulary

Verified: relational arithmetic and CLP constraints, scalar comparisons,
`foldall`, ordinary maps/spaces, and constructive `not-provable` already cover
the generic execution mechanisms. `lib/lib_pln/lib_pln.metta:190-193` already
contains `Truth_Negation`, so the sweep's suggestion that STV complement still
needed adding is out of date. There is no reasoner compiler IR that assigns
proof children and truth contribution to `Compute`, `FoldAll`, `Not`, or the
distribution forms.

Rejected: adding Chainer premise names as kernel special forms, duplicating
relational arithmetic, or giving core `foldall` one deduplication policy.

Decided: **REFUSED WITH CONDITION**. Revisit premise syntax only inside a
reasoner compiler whose typed IR fixes input/output modes, scope, cardinality,
proof children, truth contribution, and failure for every form. The generic
operations and finding 5's distribution library remain ordinary library calls.

### Finding 11: shared sessions and materialization

Verified: Python evaluation can batch targets through one crossing, prepared
calls wire once, and `assuming`, `given=`, transactions, retained derivations,
events, and `engine/support_graph.pl` provide the generic ownership and
dependency seams. There is no `lib_chainer`, shared proof arena, fair
multi-root reasoner budget, or explicit run-then-publish-proofs API.

Rejected: a second generic batch API, global proof scratch spaces, query-local
rows that survive exceptions, and publication without support edges.

Decided: **REFUSED WITH CONDITION**. Revisit after a named reasoner caller
demonstrates overlapping roots that materially benefit from one bounded proof
arena and requires proof publication. The reasoner must own alpha-isolated root
IDs, fairness, cancellation, exception-scoped assumptions, and atomic
support-tracked materialization.

### Finding 13: probabilistic existential propositions

Verified: exact search found no `ExistentialClaim`, `KnownExistential`,
`ExistentialResidual`, or `exists-slot`. Logical variables and constructive
negation answer exact symbolic existence questions, but no current caller asks
for uncertain existential support without a witness.

Rejected: treating this as core quantifier semantics or assuming noisy-OR over
an unspecified witness population.

Decided: **REFUSED WITH CONDITION**. Revisit inside an uncertainty-aware
reasoner only when a caller states witness-set completeness, dependence and
residual-confidence rules, hygienic binder scope, and stable alpha/Skolem
identity, including nested and escaping-form refusals.

### Finding 14: empirical Member/base-rate views

Verified: `lib_pln` derives Member through Inheritance but exposes no
universe-size or empirical base-rate API. `TabledMap`, `LiveView`, events, the
support graph, and independent bag/set/counting carriers remain the generic
incremental substrate. No current caller supplies the missing population
policy.

Rejected: automatic empirical inheritance in the engine and deduplication in
core `foldall`.

Decided: **REFUSED WITH CONDITION**. Revisit as a library materialized view
when a caller fixes population identity and snapshot, open- versus closed-world
semantics, negative observations, proof/provenance deduplication, confidence,
removal, partial-budget refinement, and concurrency.

### Verification record

Tried: `HYPOTHESIS_PROFILE=petta pytest` initially failed because only `metta`
and `ci` profiles were registered. The test harness now registers `petta` as
an exact parent-copy of `metta`, preserving exploratory behavior under the
requested public spelling.

Tried: the focused generated Python law suites completed with 25 passing tests;
the two PLUnit suites completed with 9 passing tests; both executable examples
ran with every check green; and the repository example integration checks
completed with 12 passing tests. Full-gate evidence is appended after the
functional tree is frozen.
