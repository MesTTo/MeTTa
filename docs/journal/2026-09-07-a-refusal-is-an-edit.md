# A refusal is an edit
Goal: every refusal this library makes on purpose carries its repair as data,
so an editor can offer it and `metta lint` can write it, without anyone
parsing a sentence.
Constraint: the message text does not change anywhere; a refusal Python
already has a word for stays that class; the shapes have to be expressible as
atoms, because section 22 of the ecosystem journal makes refusal kinds catalog
rows later.

## 2026-09-07

Decided: `Remedy(title, kind, applicability, edit=, replace=, python=)` and
`Ground(kind, citation)`, both frozen and slotted, both projecting to atoms.
`kind` is LSP 3.17's CodeActionKind restricted to the three this library
issues [source: LSP 3.17 CodeActionKind,
https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#codeActionKind].
`applicability` is rustc's Applicability with its four levels collapsed to
three: `machine` is MachineApplicable, `maybe` is MaybeIncorrect, and `prose`
is HasPlaceholders, whose documentation is exactly what a remedy carrying
`<checkout>` or `<head>` is -- "the suggestion contains placeholders ... the
user will need to fill in the placeholders" [source:
rustc_lint_defs::Applicability,
https://doc.rust-lang.org/nightly/nightly-rustc/rustc_lint_defs/enum.Applicability.html].
Unspecified is not admitted: a remedy whose applicability nobody decided is a
remedy nobody classified, and the constructor's job is to make that impossible.

Tried: reading the design's three acts as sufficient for every finding ->
`duplicate-equation` has no shape. Its repair is a REMOVAL, and `edit` adds,
`replace` rewrites, `python` is text. Rejected: a fourth `remove` field,
because LSP already answers this: a deletion is a `TextEdit` whose `newText`
is `""`. Decided: `replace: tuple[Atom, Atom | None]`, with `None` in the
second position for a removal. One act covers rewrite and delete, the field
count is the design's, and the reading transfers straight from LSP.

Decided: the fields ride on the exception INSTANCE for a refusal whose class
is Python's own. `refusing(error, remedy=, ground=)` sets them and returns the
error, so `raise refusing(TypeError(msg), remedy=...)` is one line at 15
sites. Rejected: a `_GroundedX` subclass per builtin (there were three
candidate classes, TypeError, AttributeError and ValueError), because
`except TypeError` is the spelling a caller writes and a subclass per builtin
multiplies names for nothing. Every exception instance carries a `__dict__`,
so the parts fit where `AttributeError.name` fits. `_GroundedTypeError` is
deleted; `_grounded_type_error` stays as the one-line wrapper the ground gate
already scans for.

Measured the census before writing it. An AST walk over every `raise` in
`extensions/python/metta/*.py` found 1,115 sites; a remedy-cue vocabulary
(`Write`, `use`, `instead`, `declare`, ...) matched 773 of them, so prose
cues cannot be the gate's rule -- that is not a census, it is most of the
package. The rule that survives is narrower and is the author's own: a site
whose SOURCE calls the thing a remedy, either by interpolating a name spelled
that way or by writing the word into the message. That walk finds 15 sites in
9 modules, and every one of them now passes `remedy=`:

    _atom_namespace.py  2   the closed-catalog attribute and bracket doors
    _atoms_core.py      4   handle call, handle order, truth value, plain order
    _call_binding.py    2   the positional bind and the unknown-keyword builder
    _define_expression.py 1  the implicit host crossing
    _json.py            1   an uncrossable value
    _space_definitions.py 1  @typing.override over nothing
    _templates.py       1   program text with holes at a path door
    results.py          2   the (Error ...) answer and the index/column miss
    testing.py          1   programs() with no arbiter census

By applicability: 1 `machine` (none of the refusals; the machine remedies are
all lint findings), 5 `maybe`, 9 `prose`. The prose majority is honest rather
than lazy: a refusal about how a term was WRITTEN cannot name the exact edit
without the source position, which is precisely the difference between a
refusal and a lint finding.

Recorded the walk's limit rather than papering over it. Once a site carries
`remedy=`, the keyword itself puts the word in the site's footprint, so the
site stays in the walk forever: the static half is a ratchet against NEW
un-remedied sites, not a guard against someone deleting a remedy from a site
whose prose never used the word. The guard for that is the runtime half,
which names eleven refusals and drives each one.

Decided: `arbiter` as the third ground kind, and one site for it rather than
an empty vocabulary slot. `MettaResultError` is the refusal whose authority is
upstream PeTTa: an `(Error culprit reason)` is a VALUE there, which is why
every aggregating door keeps it as data and only the single-value accessors
raise. Measured, not assumed:
`tests/conformance/petta/expected/he_error.metta.out` answers
`(Error 5 BadType)` to `!(test (return-on-error (Error 5 BadType) 6) (Error 5 BadType))`
at pin `ae66fa8e41dcd5539d614706bd4e5cfb34f9608d`. The ground gate now admits
`arbiter` only when the citation names `tests/conformance/petta`, so a claim
about what upstream answers points at the file that measures it; the selftest
plants a citation that describes the pin instead of naming it.

Tried: `lint --fix` writing the finding's replacement atom straight into the
line -> it renamed every variable in the author's file.
`(= (fx-plain $value) (if True $value 0))` became `(= (fx-plain $_3) $_3)`,
because a finding stands on the atom the ENGINE stored and the engine has its
own variable names. Decided: recover the substitution from the alpha check
that already runs. `_alpha(a, b, ab, ba)` fills both maps as it walks, so
`ab` IS the engine-to-source renaming and applying it to the replacement is
one `_map_atoms`. Afterwards the same file reads
`(= (fx-plain $value) $value)`. This is the reason a compiler fix-it splices
source text rather than printing a tree.

Decided: the digest is the document version. `lint_file` records the sha256 of
the bytes it read into every finding's payload, and `fix_file(path, findings)`
refuses the whole file when the current bytes differ. That is LSP's
`OptionalVersionedTextDocumentIdentifier`, whose version is the one the edit
was computed against [source: LSP 3.17 TextDocumentEdit]. Passing held
findings back in is what makes the guard drivable at all: a `fix_file` that
lints and writes in one breath has no window a test can open, and no window a
real editor has either.

Decided: only `machine` is written. `cargo fix` applies rustc's
MachineApplicable suggestions and leaves the rest, and clang-tidy does the
same with its fix-its; a `maybe` rename that turns data into a call is exactly
the case where writing it would be wrong. Everything not applied comes back in
`Repair.skipped` with one of six reasons, and the exit code counts what
remains rather than what was repaired.

Open: `--fix` does not re-lint, so a repair that exposes a new finding needs a
second run. `cargo fix` loops to a fixpoint and this does not; the cost is one
more lint pass and the risk is a rule pair that rewrites each other's output
forever, which is why it is a decision to take with a measurement rather than
by default.
