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
