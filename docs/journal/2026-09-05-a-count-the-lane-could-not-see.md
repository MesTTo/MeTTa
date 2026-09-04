# The operator-word count the llms lane could not see
Goal: every claim in `llms.txt` is derived from the tree or the live engine,
including the ones that are not in the sources table.
Constraint: the sheet is read by things that cannot notice a stale claim, so a
wrong number there is worse than no number.

## 2026-09-05
A downstream report said fifteen attribute names on `S` alias to arithmetic
operators. `llms.txt` said thirteen. The table under that sentence listed
fourteen. Three numbers, no agreement.

Measured, against the live package rather than the tables that produce it:

    OPERATOR_WORDS                                       13
    _COMPOSITE_OPERATOR_IMAGES (floordiv, refuses)        1
    attributes where S.<word> differs from its spelling  22

Tried: counting the attributes whose image differs from the written word -> 22,
which is too many. Eight of them are `and_`, `or_`, `not_`, `is_`, `is_none`,
`is_not`, `is_not_none` and `length_hint`, already explained by PEP 8's keyword
escape and the underscore-to-hyphen map. They are spellings, not operator words.

Decided: an operator word is one the mechanical map does NOT explain, that is,
`S.<word>` is not the symbol `attribute_name(word)` names. That is the sheet's
own sentence, and it yields 14, agreeing with `13 + 1` from the two constants.
The sheet's thirteen was short by one because `floordiv` has a table row and no
map entry.

Rejected: deriving the count from `len(OPERATOR_WORDS)` plus
`len(_COMPOSITE_OPERATOR_IMAGES)`. It gets the same 14 today, but it reads the
tables the sentence is a claim ABOUT, so a word reaching the wrong head would
still count correctly. The behavioural form also needs no hand-kept exclusion
list for the eight keyword and underscore words. Revisit if reading live
attributes ever costs an engine boot; today it costs one import.

Tried: relying on the existing COUNTS check. It only reads the sources table,
and this claim is prose, so nothing anchored it. `_NUMBER_WORDS` also stopped
at ten, so a count spelled as a word above ten could not be parsed even if a
pattern had matched it. Both are now fixed; the vocabulary reaches twenty.

Decided: check the ROSTER as well as the count. A word swapped for another
keeps the count right and the table wrong, and the count alone cannot see it.
Planted separately and each caught: a count one short, a dropped word while the
count still agreed, a plain spelling given a row, and deletion of the claim
itself.

    llms selftest: 42 planted case(s), 0 failure(s)
    llms: 5 cheat sheet(s) read ..., 0 finding(s)

Open: the same prose-claim blindness covers the algebra presets, the vocabulary
members, the effect classes and the provider capability words, which are closed
value sets with no source-table row. `ai-llms-and-algebra-audit.md` carries that
list.
