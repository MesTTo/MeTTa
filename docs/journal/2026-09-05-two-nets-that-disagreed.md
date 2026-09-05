# The two nets that disagreed about an arrow
Goal: a declaration the engine will not honour as a call type is reported by
something, whichever door it arrived through.
Constraint: the engine owns which annotations are legal; the linter must not
carry a second copy of that vocabulary.

## 2026-09-05
Tried: writing an annotated declaration the way a user would ->
`(: z (-[det]-> Number Number))` loaded from a FILE is refused as "not an
arrow", while the same line through `m.run` is stored. Two doors, one
declaration, opposite answers.

Tried: separating the declaration from its definition, which is what a real
file does ->

    (: z (-[det]-> Number Number))     accepted
    (= (z $x) $x)                      accepted
    !(z 1)  ->  (Error (z 1) IncorrectNumberOfArguments)

So the notation is not merely unsupported. Using it silently breaks the
function, in two ordinary statements, today.

Tried: attributing that to the annotation -> wrong. `(: z Number)`, a plain
non-arrow declaration, does exactly the same when separated. The gap is
general and DELIBERATE: `refuse_untypable_declaration/3` judges a definition's
own forms, because a build writing `(: f Number)` and `(: f (-> Number Number))`
as two atoms passes through a state where only the first is stored, and
refusing there would refuse a program about to be correct. Its own comment
names the net for everything else: "Declarations that reach a space by any
other route are named by space.lint()".

Measured that net:

    (: z Number)                    lint: declaration-types-the-symbol
    (: z (-[det]-> Number Number))  lint: NOTHING
    (: z (-> Number Number))        lint: nothing, correctly

The hole sits exactly where the two halves disagree. The linter had been
taught on 2026-09-05 that `-[det]->` is an arrow, so the arity and
declared-function diagnostics would stop skipping annotated declarations;
`untypable_declarations/2` still decides with a literal `[->|_]`. Each change
was right on its own and the pair left the one rule whose whole job is the
case the loader never judges reporting nothing.

Rejected: teaching the engine the annotated spelling. Measured the partial
form first, and it is worse than the refusal: with only
`untypable_declarations/2` fixed, the declaration lands and `!(fann 1)` answers
IncorrectNumberOfArguments while `(get-type (fann 1))` types ELEMENT-WISE,
because 49 further sites across 12 files match the literal `[->|` and most are
clause heads in the typing and lowering path. A loud refusal became silent
misbehaviour. Revisit when a declaration's chain is normalised at the READ
boundary, so those sites keep seeing `[->|Types]` and the annotation rides
beside it, and when a full gate can run to prove it.

Rejected: deciding in Python which spellings the engine honours. It is exactly
the second closed value set the linter's own frame test refuses to become, and
it would go stale the day the engine learns the annotation.

Decided: ASK the engine. `EngineRegistry.types_a_call/1` puts
`untypable_declarations/2` the question directly, cached per head for the pass.
`_is_arrow_head` keeps matching the FRAME, which is what an author's intent
looks like and what the arity diagnostics want; the new question is the
narrower one of what the engine will honour, and only
`declaration-types-the-symbol` asks it.

Both findings are reported when both hold, rather than the spelling
short-circuiting the arity check: an arrow the engine will not honour still
STATES an arity, and reporting one at a time would surface the second only
after the author had fixed the first.

    annotated, arity mismatch -> arrow-arity-mismatch + declaration-types-the-symbol
    plain,     arity mismatch -> arrow-arity-mismatch
    annotated, arity OK       -> declaration-types-the-symbol
    plain,     arity OK       -> nothing

Open: the engine still stores a declaration it will not honour. The linter now
says so, which is the net working as designed, but the 49-site normalisation is
the real repair.

## 2026-09-05, after the gate: one predicate, two ownership rules

Ran `GATE_ONLY=1 sh check.sh` once the box quietened. 8 of 100 lanes red, five
of them benchmark lanes at loadavg 7 to 10. Of the three that are not timing,
two were already recorded elsewhere; `policy-inventory` was not, and it named
`engine/metta/types.pl:65` and `:79`:

    closed policy list [det-det, deterministic-det, semidet-semidet, ...]
    has no adjacent exemption

Both are inside `metta_arrow_type_shape/5`, which resolves its EFFECT CLASS
through `spaces:metta_effect_class_canonical/2`, catalog-owned, and decided its
CARDINALITY from a literal list repeated in both of its branches. One
predicate keeping two ownership rules, and the catalog already ships
`[vocabulary, determinism, det, semidet, nondet]`.

Decided: derive, not exempt. `metta_determinism_canonical/2` mirrors its
effect-class sibling exactly, including the two-part rule that a long spelling
maps IN without becoming a fourth public member: `-[deterministic]->` reads as
`det` and `-[bogus]->` is still refused. The lane goes from 2 findings to 0
because the closed list is GONE, not because it acquired a note.

Tried: shipping it with only the `kind/2` declaration -> `ext_points.plt` and
`layering.plt` went red, two suites that had been green. A declared seam must
also be EXPORTED and reachable under its module, which is the declaration doing
its job: `metta_determinism_canonical/2` joins the export list in
engine/spaces.pl and both suites return to green. The whole plunit set then
matches its pre-change baseline suite for suite.

Re-pinned the identity twin 3553 -> 3558, and this one is attributed in FULL,
which the -12 recorded in that file earlier today was not. A/B in the main
checkout with the QLF cleared: HEAD reads 3553 and the lane passes; with the
four changed files restored it reads 3558. Four facts added to a file the boot
consults, the same first-argument-index shape the file already documents twice.

## 2026-09-05, the seam declaration that cost 1.2%

The gate's `instructions` lane went from ok to FAIL on the commit above, on two
LOAD benchmarks: `source-load` +1.7% over its baseline and `save-load-fast`
+1.3%, both outside the 1% band.

Isolated it a file at a time, with the QLF warmed before each measurement
because a cold first sample charges the recompile and inverts the reading:

    HEAD (all four files changed)   225,364,670
    spaces.pl reverted alone        225,397,903   no change
    ext_points.pl reverted alone    222,694,800   <- the whole cost
    catalog.pl reverted alone       226,123,375   no change
    types.pl reverted alone         225,415,270   no change

One line. `kind(metta_determinism_canonical/2, service).`, the 198th clause of
`kind/2`.

Tried: attributing it to work. INFERENCES are identical either way, 239,281
over the thousand-definition source load, so the engine executes exactly the
same goals. Moving the same declaration to a different position in the file
changes nothing either (225,633,460 against 225,607,063). What costs is the
clause EXISTING, at a count where SWI's clause indexing spends instructions
that retire no inferences.

Decided: the declaration was wrong on its own terms, and removing it is not a
concession to the benchmark. `metta_effect_class_canonical/2` is a declared
seam because EXTENSIONS resolve an effect class they themselves declared; it
is reached from five files. `metta_determinism_canonical/2` resolves a slot
inside an arrow the engine reads, and it has exactly one caller,
`engine/metta/types.pl`, through an explicit `spaces:` qualification. Mirroring
the sibling's `kind/2` row was mirroring one attribute too many.

The EXPORT stays: `layering.plt` requires it, naming the exact remedy ("add it
to the module's export list or change the caller"), and the isolation above
shows the export is free. So the fix is one removed line, and both benchmarks
return inside the band, `source-load` at 222,614,639 and `save-load-fast` at
4,127,710,479, the latter now under its baseline.

`llms.txt`'s service count follows the tree in both directions: 56 to 57 when
the declaration landed, and back to 56 when it left. The lane caught both.
