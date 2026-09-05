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
