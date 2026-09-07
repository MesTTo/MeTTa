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
the 46 examples this thread adds: **4**, all allowlisted, all present in the
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
| `FTree` | a Type, the sort lib_datastructures' constructors answer to; `ch09-types/21-a_librarys_declared_types.metta` reads all four declarations back through `get-type` |
| `FTEmpty` | a nullary constructor, so it is a VALUE written bare and `(FTEmpty)` would be a one-element expression; `ch08-03/15-fingertree_internals.metta` passes and matches it |
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

Found by regenerating the introduction table: three constructs moved to an
earlier coordinate, and one of them moved the wrong way. `add-reduct`
20-02-08 -> 04-01-12 and `type-cast` 20-02-09 -> 09-00-20 each move from an
incidental late use into the chapter that owns the concept, which is what the
reading order is for. `get-type` 09-00-01 -> 08-03-15 is the opposite: the
finger-tree internals file read three declarations back, and a derived table
turned that into "chapter 8 introduces `get-type`", one chapter before the
types chapter that teaches it. The lane stays green either way, which is the
point: the law it holds is "a file uses only what an earlier number
introduced", and regeneration can satisfy that by moving the introduction.

Decided: the type claims move to the types chapter,
`examples/ch09-types/21-a_librarys_declared_types.metta`, which reads all four
of lib_datastructures' declarations back and adds what the move made room for
(the metatype contrast, and the two applications whose arguments do not fit,
which have no type at all). The finger-tree file keeps its subject, which is
shape. `get-type` is back at 09-00-01, and `FTree`'s allowlist reason names the
new file.

Tried: showing in that new file what the allowlist reason claims, that
`(FTEmpty)` is a one-element expression rather than the atom the library means
-> the coverage lane reported both `FTEmpty` and `FTree` as "allowlisted, and
an example now calls it". It is right to: call position is read out of the
TEXT, and a one-element expression and a nullary call are the same characters.
The corpus cannot demonstrate that form without claiming to cover the head, so
the demonstration comes out and the sentence stays, in the file and in the
allowlist reason. The lane refusing its own author's example is the second
direction of the exactness working.

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
