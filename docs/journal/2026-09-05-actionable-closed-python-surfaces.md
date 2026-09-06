# Actionable closed Python surfaces
Goal: make answer-view, algebra typing, and closed algebra-set failures state
their remedy, while giving every closed algebra roster one catalog authority
and a gate that compares members rather than counts.
Constraint: `Answers.index` remains the `Sequence` operation; the callable
module keeps its runtime identity; catalog data and existing generators remain
the derivation mechanism.

## 2026-09-05

Measured the answer-view collision before changing it:

    columns: ('fact',)
    column collision: ValueError ''
    present row index: 1
    ordinary absence: ValueError ''
    has group_by: False

Rejected: making `Answers.index('fact')` project the `fact` column. `Answers`
is a `Sequence`, so that would silently change the meaning of a standard
sequence method for every polymorphic caller. Decided: delegate to
`Sequence.index` first and replace only the failed `ValueError` when its string
argument is also a column name. `column(name)` and `group_by(column)` are
separate row-view operations.

Measured the same probe afterward:

    columns: ('fact',)
    column collision: ValueError "`index` is the Sequence method and answers a row position; 'fact' is a column, read it with `.column('fact')`"
    present row index: 1
    ordinary absence: ValueError ''
    has group_by: True

Tried: describe `_AlgebraModule.__call__` in `metta/algebra.pyi`. On the same
consumer file, mypy still reported:

    error: Module not callable  [operator]

Rejected: a module stub, because mypy models modules structurally and does not
consult the runtime reassignment of `sys.modules[__name__].__class__`.
`_fn.pyi` therefore does not transfer to this case. A minimal package
`__init__.pyi` made the call type-check but shadowed the complete package
implementation, degrading unrelated root exports to `Any`.

Decided: generate the complete package stub from `metta/__init__.py`, refine
only its `algebra` attribute with a callable Protocol, and generate that
Protocol's carrier attributes from the catalog's `semiring` vocabulary. The
normal package mypy lane checks 92 source files, a separate lane checks the
shadowed root implementation, and a consumer fixture checks both call forms,
all ten carrier attributes, representative existing exports, and a wrong
assignment. Afterward the original probe reported no error and revealed
`metta._AlgebraModule`, `metta.algebra.DeclaredAlgebra`, and
`metta.algebra.DeclaredAlgebra`. A 31-expression root-surface probe was
byte-identical before and after the stub.

Inspected the existing closed-set mechanism before adding data. The
`vocab-sync` lane already compares every generated Python enum with catalog
`(vocabulary ...)` rows. The policy inventory query named `algebra_laws`
already returned rows, but its query was exactly
`(claim semiring <name> ordered <direction>)`: three ordering claims, with no
reference to `metta_algebra_equational_law/1`, accepted declaration laws, or
alias expansions. `vocabgen.py` exited 0 while the law roster remained
unpublished. Renamed that policy seam to semiring claims so its scope is no
longer mistaken for declaration-law coverage.

Measured the carrier sibling at the base revision: ten catalog algebra rows,
ten Python `_PRESETS`, eight `Semiring` enum members, five Python carrier
objects, and five names in the consumer object roster. For declaration laws
there were ten equational facts, eleven canonical accepted names after adding
`contraction`, five alias claims, and fifteen unique accepted spellings because
`contraction` is also its own alias.

Decided: derive the `semiring` vocabulary from the catalog algebra rows and the
`algebra-law` vocabulary from the engine's law and alias facts. Publish each
alias as `(claim algebra-law <alias> expands-to ...)`. `vocabgen.py` then emits
the Python enums, the Node vocabulary test reads the same live catalog, Python
objects are checked against the generated carrier enum, and the ROSTERS lane
checks exact source, catalog, enum, object, and sheet members. It also checks
the five alias mappings. Counts are only diagnostic; a same-cardinality member
substitution is a planted failure.

Rejected: updating the Node consumer prose from "32 closed value sets" to
"33". Its vocabulary test already compares every set name and every member
with the live catalog, while the prose number had no reader. Removed the count
instead of replacing one unheld claim with another.

Planted one extra `metta_algebra_equational_law/1` fact without regenerating
the enum. After booting the engine, the existing generator lane exited 1:

    metta/vocabularies.py no longer matches the engine's (vocabulary ...) rows: run `python extensions/python/tools/vocabgen.py --write`

Removed the fact, booted again, and the same command exited 0. The sheet gate's
54 planted cases also include same-member-count substitutions and all passed
by detecting their intended fault. The shipped state has fifteen accepted law
spellings and ten carrier names, and an unknown `identity` refusal prints all
fifteen accepted alternatives.

The production policy inventory initially reported two pre-existing closed
lists in `metta_arrow_type_shape/5`, both mapping the same six accepted short
and long annotated-arrow cardinality spellings. These are parser-owned syntax,
not runtime policy choices. Added the inventory's adjacent
`arbiter-owned-language-law` exemption to each occurrence. The policy inventory
then reported 20 runtime rows and 0 findings, while all 7 arrow-projection tests
passed.

Open: none.
