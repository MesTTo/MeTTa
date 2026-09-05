# The promise a missing constructor breaks
Goal: extract what is decidable from the typechecker audit's item 20,
exhaustiveness for `det`, which the audit refused in general.
Constraint: do not warn about legal MeTTa.

## 2026-09-05

The audit refused general exhaustiveness and was right to: it needs totality and
is undecidable. Reproduced its ground first, and it holds:
`(: partial-bool (-> Bool Number))` with only a `True` equation is accepted, and
`(partial-bool False)` answers Empty, unflagged.

Tried: whether a type's members are enumerable at all. `Bool`'s are not stored
as `(: True Bool)` atoms, but a USER-declared type's are:
`(: Red Colour) (: Green Colour) (: Blue Colour)` makes
`!(match &self (: $c Colour) $c)` answer `[Red, Green, Blue]`. So the decidable
corner exists: members declared one by one are a set, and the missing ones are a
difference rather than an analysis.

Built it that way first, over a plain `->`, and it was WRONG. A plain arrow
promises nothing about how many answers come back, so a partial function is
ordinary MeTTa and warning about it warns about the language.

Corrected from upstream's own fixture, which is on disk at
`_fixtures/upstream/fail_nonexhaustive_ctor.metta` and states the case exactly:
"A -[det]-> function that cannot answer for a Point is not deterministic, it is
partial: -[semidet]->." The finding is the CONTRADICTION between the declaration
and the equations, and the remedy is a choice the message now names both halves
of: cover the member, or say `-[semidet]->` and mean it.

Decided: fire only on a `det` claim. Measured across the four arrows, with
`Blue` uncovered in each: `-[det]->` fires, plain `->` is silent, `-[semidet]->`
is silent because it is the remedy, and `-[det]->` with every member covered is
silent.

The rule reaches the Python surface for nothing, which was not designed for and
is the payoff of building on declarations rather than a bespoke registry:
`@m.define` on a `StrEnum` emits `(: red Colour)` beside `(: Colour Type)`, the
same shape a MeTTa program writes by hand, so an enum with an uncovered member
is found by the same set difference.

Corrected again, after the first version shipped: it counted a covered
argument only when it was a bare SYMBOL, so it saw enums and missed every
algebraic type, which is the more important half and the shape the upstream
fixture is actually written in. A constructor is a member of the type it
RETURNS, so `(: Circle (-> Number Shape))` makes Circle one of Shape's beside
the nullary `(: Point Shape)`, and `(area (Circle $r))` covers Circle by
pattern rather than by name. The fixture's own case now reports exactly
`area` missing `Point`.

Recorded limit, from the same upstream fixture: the verdict is a LOWER BOUND on
incompleteness. A constructor declared later, or in a file not yet loaded,
cannot be seen; `lint()` reports the space as it stands. Upstream's
`late_ctor_exhaustive_2_blue.metta` handles this by recording the verdict with
the constructor set it saw and re-running it when a later declaration arrives.
This does not, and says so rather than implying totality.

Evidence: 3,037 Python tests pass, against 3,035 before. One unrelated
intermittent, `test_serve_and_boot_expose_spaces_until_interrupted`, fails about
one run in three at loadavg 42 and migrates between its two parameters; it is
filed against the backlog's own intermittent row.

## 2026-09-05, the other half of the same promise

The same lens turned on PeTTaChainer's findings 3 and 8, which rest on a
measurement the adaptations journal records: `(: two (-[det]-> Number Number))`
with `(= (two $x) $x)` and `(= (two $x) (+ $x 1))` answers 1 AND 2, because the
arrow is read and its product dropped. Re-probed and it still does.

That is the mirror of the constructor case. `uncovered-constructor` catches too
FEW answers under a det claim; two equations sharing a head catch too MANY, and
the same guard decides both, so `_claims_det/1` is now one helper with two
callers rather than a condition written twice.

Neither existing overlap rule reaches it and both are right not to:
`duplicate-equation` needs equal bodies and these differ, `subsumed-equation`
needs one head to be a strict INSTANCE of the other and these are variants.
What makes it wrong is the declaration, not the overlap.

Measured across the arrows with the same two equations: `-[det]->` fires, plain
`->` is silent because a function is a relation, `-[nondet]->` is silent because
it is the remedy the message names. Distinct heads, a single equation, and an
undeclared function are all silent.

Deliberately conservative on PARTIAL overlap: `(= (f 1) 10)` beside
`(= (f $x) $x)` does answer twice for `(f 1)` and is not reported, because
deciding it needs unification against every stored head rather than an
alpha-key comparison. The certain case is the one that fires.

This is the STATIC half of findings 3 and 8. The runtime half, enforcing the
product rather than reporting the contradiction, is separate work and is not
claimed here.

Evidence: 3,041 Python tests pass, against 3,039 before.
