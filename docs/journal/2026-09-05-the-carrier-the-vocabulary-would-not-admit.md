# The carriers the semiring vocabulary would not admit
Goal: the algebras this catalog DEFINES and the ones its vocabulary lets a
caller NAME are the same set.
Constraint: engine/spaces/catalog.pl is the single source; vocabularies.py is
generated from it and must never be edited directly.

## 2026-09-05
Found while auditing llms.txt before a release, in the blind spot that document
already names: a closed value set that is neither a library roster nor a call
head, which the llms lane cannot check.

Measured, four ways of asking what carriers ship:

    algebra._PRESETS                       10
    the runtime's own refusal message      10  ("shipped presets are bool, bag,
                                                counting, set, ranked, tropical,
                                                prob, prov, budget, amplitude")
    llms.txt's carrier table               10
    catalog (vocabulary semiring ...)       8  <- no budget, no amplitude
    generated vocabularies.Semiring         8  <- because it mirrors the row above

The catalog contradicts ITSELF, which is what settles it: its own
`[algebra, X, ...]` rows define all ten, amplitude and budget included, while
its `(vocabulary semiring ...)` row admits eight. No design defines an algebra
it then refuses to name.

Not a ruling: nothing pins eight, `catalog.plt` reads the row generically and
widens it, and the history is plain drift. The vocabulary row was last touched
2026-08-23 and `budget` reached `_PRESETS` on 2026-08-28.

The consequence was narrow but real. Both carriers already WORKED --
`metta.under('budget')` and `metta.under('amplitude')` each answered before this
change -- so the defect was that neither could be SPELLED in a typed annotation,
`Semiring.budget` and `Semiring.amplitude` raising AttributeError.

Tried: reading `_carrier_input` for whether admitting them exposes an unhandled
path -> no. It special-cases bool, bag, set, counting and prov and falls through
to `trace.raw` for the rest, which is the path budget and amplitude were already
taking.

Decided: widen the vocabulary row to ten and regenerate. `budget` also gains the
`(claim semiring budget ordered ascending)` row it was missing: four presets
declare an `order` and only three published it, so a program asking
`(match &metta (claim semiring $s ordered $d) ...)` was told about ranked,
tropical and prob and nothing about budget, which declares `order=ascending`
exactly as tropical does.

Two parity tests close the gap that let this sit. Nothing had ever compared the
shipped presets against the generated enum, or an ordered preset against its
claim row. Both are written against the catalog rather than a list, so a carrier
added tomorrow is covered without editing them, and both were proven to
discriminate by reverting the fix and watching them go red.

`check_policy_inventory.py` gains budget in REQUIRED_ALGEBRA_LAWS and its
selftest fixture gains the matching row, because that lane requires every
semiring carrying law claims to be listed there.

## 2026-09-05, later: the count the example moved

The example added for this carrier is the 255th `examples/**/*.metta`, and
`examples/README.md` still said "143 of the 254 programs". The next sentence in
the same paragraph says "the other 112", and 143 + 112 = 255, so the paragraph
contradicted itself.

`test_the_examples_readme_states_the_split` was green throughout. It recomputes
`derived` and `total - derived` and requires both in the section, but never
`total` itself -- the one number in that sentence nothing derived is the one
that went stale. Same shape as the `llms.txt` lane, which derives the counts in
the source table and cannot see a count written anywhere else.

Decided: correct the number and add `str(total)` to the required tuple, so all
three are recomputed. Proven to discriminate: planting 254 back fails with
`assert '255' in ...`, restoring it passes.
