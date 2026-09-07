# Every atom has an example

Goal: every name the engine can call and every head a shipped library carries
is CALLED by a file in `examples/`, and a lane keeps it that way, so a change
to any of them breaks something visible.

Constraint: the corpus is cumulative. A file may use only constructs a lower
coordinate introduced (`tests/data/syntax_introductions.txt`), so a new
example goes where its constructs are already legal rather than where its
subject is most convenient. Upstream PeTTa is the semantics arbiter: where an
example disagrees with it, the example changes.

## 2026-09-07

Measured the gap first, with the functions the lane now ships, over the corpus
at 31d54e19 (`git archive 31d54e19 examples | tar -x -C <dir>`): of 721 heads,
245 engine callables and 641 distinct heads that 38 libraries carry across 659
rows, **287 were called by no example**. 61 of those were the engine's own and
226 were carried only by a library, spread over 28 of the 38 libraries. After
the 45 examples this thread adds: **4**, all allowlisted, all present in the
corpus in declaration or argument position.

Decided: CALL POSITION, not mention. `(name `, `(name)` and `(name` at a line
end are the three shapes, full-line comments are stripped first and
`_fixtures/` is skipped, matching what `check_llms_names.corpus_head_uses`
already reads the corpus under. Stripping comments is not pedantry: it moved
the engine count from 60 to 61 and caught two heads a mention-based audit had
counted as covered, `every` (named only in a comment in the concurrency
chapter) and `sread` (named four times in `ch03/06-reading_forms.metta`'s prose
and called nowhere). Both have real calls now, and `sread` is the one new row
in the introduction table.

Decided: the allowlist is exact in BOTH directions, which is the property that
keeps it from becoming the place uncovered heads go to be forgotten. A row
whose head an example now calls is a finding; a row whose head appears nowhere
in the corpus is a finding, so a stated reason like "a Type, so it appears in
declaration position" has to stay true; a row for a head neither the engine nor
a library carries is a finding. Four rows today:

| head | why a call is meaningless |
|---|---|
| `DontEvalType` | a Type, written in a declaration; `ch09-types/06-dont_eval_type.metta` declares `(: OpaquePayload DontEvalType)` |
| `FTree` | a Type, the sort lib_datastructures' constructors answer to; `ch08-03/15-fingertree_internals.metta` reads it back through `get-type` |
| `FTEmpty` | a nullary constructor, so it is a VALUE written bare and `(FTEmpty)` would be a one-element expression; the same file passes and matches it |
| `TP` | a Type, lib_strategy's type-preserving scheme, written in the second argument of the typed application operator; `ch20-02/11-strategy.metta` applies it there |

Tried: reusing `tests/data/example_skips.txt` for the three examples that need
a capability the tree does not always have (MORK's `.so`, a Redis server,
torch). Rejected, because a skip file takes the file out of the run entirely
and the point of these three is that they RUN where the capability exists. Each
guards itself the way the corpus already guards optional work, `(if (file-exists
...) (progn ...) (println! "SKIPPED ..."))`, and each was verified BOTH ways:
the MORK one with the `.so` moved aside and back, the Redis one against a
`redis:7.2.3-alpine` container started and stopped for the measurement, the
torch one with and without the virtualenv on the path. `example_skips.txt`
stays at five entries.

Tried: writing the torch guard as Python's `find_spec("torch")`. Rejected in
the twin, because the module NAME it takes is host text a twin may not write;
the engine's own `(if-error (catch (py-call (torch.zeros 1))) no yes)` is the
question the example asks and the one that stays.

Three claims the arbiter settled against the intuitive reading, each documented
in the example rather than "fixed":

- `migrateAtoms` does not write its destination. Upstream's own equation names
  the source space on both sides
  (`tests/conformance/petta/lib/lib_spaces.metta`), so the example states the
  removal and what the destination does NOT gain.
- `Truth_Union` and the `Truth_DecomposeNNN` family answer bare pairs rather
  than `(stv ...)`, unlike their neighbours in the same library.
- `LimitSize` leaves size MINUS ONE items, because its guard is
  `(< (length $L) $size)`. The example asserts the arithmetic the engine has.

Decided: the lane's selftest plants findings rather than asserting a clean run.
It builds a corpus and an allowlist in a scratch directory and plants all four
refusals plus two negatives (a head spelled only in a comment, a head called
only under `_fixtures/`). Mutation-tested by breaking each rule in turn:
disabling comment stripping, including `_fixtures/`, dropping the
absent-allowlist check and dropping the stale-row check each take the selftest
to a finding it names.

Open: the twin corpus keeps two accepted band overruns and two digest
differences, each with the reason in the file; and the Redis twin is the one
file in the corpus whose inference count is not deterministic. Three
single-round measurements gave 113484, 113469 and 113484, because every read
and write crosses a socket and the subscription thread's work lands in the same
counter, so it carries `ALLOWANCE = 200` rather than the tree's default 4.
