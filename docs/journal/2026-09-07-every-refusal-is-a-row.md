# Every refusal is a row
Goal: one place says what a refusal MEANS, what authority it stands on and
what to do about it, and every seat reads that place rather than keeping its
own copy of any of the three.
Constraint: `engine/spaces/catalog.pl` is consulted into the `spaces` module
and may not reach an engine predicate, so a row here is CHECKED against the
engine's kind table rather than derived from it; the Python and Node wires
already carry the engine's kind word and nothing about them changes.

## 2026-09-07

The taxonomy was three hand-written lists: thirteen classes in `errors.py`,
thirteen in `errors.ts`, and prose in neither. `metta_host_error_kind_row/3`
had already made the KIND set one table (2026-09-07, the two-seats thread),
but what a caller should DO about a refusal existed only inside whichever
sentence the engine happened to compose, and the website had no error page at
all.

Decided: `(refusal <kind> <class> <ground> <remedy>)`, one row per kind, in
`&metta`. The kind word is the ENGINE's own, `time_limit` and not
`time-limit`: it is already the identifier five consumers share, the ball, the
wire, the fixture, `_EXCEPTION_TYPES` and the Node union, and a second
spelling for one identifier is what this catalog exists to stop. `op-kind`'s
`raw_det` carries an underscore in the shipped presets for the same reason.
Rejected: hyphenating it to match every other catalog symbol. The cost is a
map no consumer needs and a `(vocabulary refusal-kind ...)` row whose members
would no longer BE the wire strings, which is what makes `vocabgen` able to
generate both seats' kind sets from it.

Decided: `<class>` is the seat-independent class name, and a seat that spells
it differently records what it spells and why in
`tests/data/error-kinds.json`. Seven of the thirteen depart, and each
departure has a real reason rather than a habit: `ValueError` and `TypeError`
are Python's own words for the codec's two refusals; `InterruptedError` is
JavaScript's suffix convention where Python's builtin of that name already
means EINTR; `AssertionError` is `node:assert`'s own word; `CapabilityError`
and `OperationError` drop a prefix the package namespace already says. One
collision is now written down rather than latent: the row's `CastError` for
the `type` kind is a name `metta.casting.CastError` already holds on the
Python seat for a different meaning, a failed `cast()`.

Decided: the ground is the whole `(ground <authority> "<citation>")` row, not
the authority alone the plan asked for. A ground without its citation is half
a ground, `Ground.from_atom/1` reads exactly this shape, and the
`refusal-grounds` gate's own rule -- an `arbiter` claim must NAME
`tests/conformance/petta` -- then applies to the rows too. Twelve stand on
`HostLaws`, the law family the gate already admits for the host boundary, each
citing the predicate that states it; `operation` stands on the arbiter,
measured: `tests/conformance/petta/expected/he_error.metta.out` answers
`Error` to `(catch (+ 40 a))` at the parity pin, so a builtin refusing a value
is a VALUE inside MeTTa and becomes a host exception only at the crossing.
Rejected an `arbiter` ground for `assertion`: `he_assert.metta.out` measures
only assertions that HOLD, and a claim about what a failing one does would
have been unmeasured.

Tried: making the remedy template a MeTTa atom with holes, per the plan.
Result: the holes belong in two places with different rules. A TITLE's hole is
a field the ball carries and the engine fills it; an ACT's hole is the new
bound, which the engine has no opinion about. Decided: the row declares the
applicability its FILLED remedy has, and the renderer lowers it to `prose`
while any hole is left, which is exactly rustc's `HasPlaceholders`
[source: rustc_lint_defs::Applicability]. So `capability` arrives `maybe`
carrying `(edit (grants &restricted process))` while `time_limit` stays
`prose` carrying `(edit (pragma! max-time <seconds>))`.

Decided: a `prose` `Remedy` may name no act. Nine of the thirteen repairs are
decisions, not edits, and advice with no mechanical fix is a real category:
PostgreSQL's `errhint()`, clang's `note:`, rustc's `help:` without a
suggestion. The remedies package refused an act-less remedy on the ground that
"a remedy nobody classified is a defect"; the classifier is the APPLICABILITY,
and a `prose` remedy is classified. `machine` and `maybe` still refuse,
because those two levels promise something an editor can apply, and
`metta.lint.apply` writes only `machine`.

Tried: `maplist/3` with a yall lambda for the act filler. Result: every hole
filled with a fresh variable, so `(grants <space> <capability>)` rendered as
`(grants $_0 $_1)`. yall COPIES a lambda's free variables per call, and
`Fields` was one. Replaced with a written recursion.

Decided: one renderer, engine-side. The Python seat asks `metta_py_refusal/5`
once on a path that is already raising and reads the two rows back through the
atom wire; the Node bridge sends them flat beside the fields, as text, the
same shape and for the same reason the fields take; the C seat asks
`metta_c_error_advice/3` after the message is in place and answers them from
`mt_remedy()` and `mt_ground()`. Rejected composing the sentence per seat,
which is how the two seats' classifiers drifted in the first place.

Decided: the first ground kind is `host-reference`, not `python-reference`.
Bringing the vocabulary into the catalog put a host's name in the engine, and
`test_no_code_in_the_engine_names_a_host` said so at
`catalog.pl:1899` the moment it ran. The general form is what the specific one
always meant, "the host language's own specification says so", and the
CITATION is where a host may appear: this seat's stays `Python Language
Reference section 6.3.4, Calls`, and the gate still requires a section number
for that authority.

Decided: `refusal-kind`, `ground-kind`, `remedy-kind` and `applicability` are
catalog vocabularies. The first is DERIVED from the rows, so a kind reaches
the vocabulary by having a row; the other three are the closed sets
`Ground.__post_init__` and `Remedy.__post_init__` validate against, held equal
to `metta.errors`' three tuples by
`extensions/python/tests/repository/test_refusal_rows.py` rather than imported,
because `errors.py` sits BELOW `atoms.py` and `vocabularies.py` imports it.
`vocabgen` then generates all four for both seats, and the Node seat's
hand-written `RefusalKind` union became a re-export of the generated one: one
list checking another list in the same file was not a check.

Decided: `website/reference/refusals.md` is generated from the rows by
`extensions/python/tools/refusalsdoc.py`, the shape `ledger.py` already has
for `shrink-ledger.md`, gated by a `refusals` lane. rustc's error index and
PostgreSQL's `errcodes.txt` are the same move: one row list, and every
spelling of it generated [source: https://doc.rust-lang.org/error-index.html].
A `<field>` hole reaches the page inside backticks, because VitePress compiles
markdown through Vue and would read a bare `<line>` as a custom element.

Measured: `sh engine/test.sh` and the three seats agree. The plunit suite is
11 tests and 24 sub-tests; the Python lane is 48; the Node suite is 20 over
its three error groups, with the capability edit read back as
`(edit (grants &restricted process))`; the C suite is 486 checks with the
assertion remedy read out of `mt_remedy()`.

Open: `stack` and `source` still have no Python class, which the two-seats
thread already records; the rows now name `StackLimitError` and
`SourceNotFound` for them, so the day that seat closes the gap it has the
name to use.

Open: a row rewritten at runtime reaches the seats at once, which the Python
lane proves by planting one. Nothing revokes a row that a program removes and
never puts back: a kind with no row answers no refusal and every seat falls
back to the class it already chose, which is what it had before this existed.

## 2026-09-07, later: what the rows cost

The `benchmarks` lane is red on the base: 22 of 35 benchmarks fail, 20 of them
on an inference regression against a stale baseline, `annotated-relation`
reading 825,125 against a pinned 315,385. So "did this branch regress a
benchmark" could not be read off the lane's verdict and had to be read off the
numbers.

Measured, `bench.py --counter-only --keep-going` on this branch and on a
pristine worktree detached at the same base `d624792f`, provisioned
identically, each run twice, min-of-3 per benchmark inside the harness:
nineteen of the twenty are within ±2 inferences, which is this harness's own
cross-process noise, and one moved.

    source-load   control 235,270   branch 235,308   +38   +0.0162%

Deterministic on both sides: two runs of each gave the identical min-of-3.

Bisected by disabling presets and re-measuring:

- with the thirteen `(refusal ...)` preset rows disabled, the branch still
  reads 235,308, so the rows in `&metta` are not what costs;
- with the four `(vocabulary ...)` rows disabled as well, it reads 235,303.

So about 5 of the 38 are the seventeen catalog rows and about 33 are the
larger engine source this branch consults. Rejected the hypothesis that a
query for another head now walks the `refusal` rows: the catalog stores a row
as `'&metta'(Head, ...)` per arity and the HEAD is the indexed first argument
[source: engine/spaces/catalog.pl, metta_catalog_clause/2], and the arity set
is identical on both trees, `[2,3,4,5,6,7,8,10,11,12,13,15,21]`, so the rows
add no bucket for an open-tail query to walk either.

+0.0162% on one benchmark is inside the push gate's own reading, which calls a
bench regressed when it passes its noise floor plus 0.10pp. Recorded rather
than optimised: the cost is the source, not the data, and nothing in the
measurement points at a scan worth removing.
