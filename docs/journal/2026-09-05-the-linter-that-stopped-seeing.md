# Teaching the linter the annotated arrow before the engine admits it
Goal: the arity, declared-function and type diagnostics see an annotated arrow
declaration exactly as they see its plain twin.
Constraint: the engine owns which annotations are legal; the linter must not
carry a second copy of that vocabulary.

## 2026-09-05
The PeTTaChainer sweep warned that `_arrow_inputs` and `_declared_arrows`
accept only `->`, so the diagnostics would silently miss annotated
declarations once the reader learned them. Checked rather than assumed, and it
is worse than "once": the declaration is stored TODAY.

    (: fann (-[det]-> Number Number))    added
    (: fpln (-> Number Number))          added

`lint.py` passes raw `space.atoms()`, so the linter already sees the annotated
head. The annotated spelling is a DIFFERENT HEAD ATOM, `-[det]->`, not a
modifier on `->`, which is why an `== "->"` test drops it.

Measured, with the old predicate restored in process so nothing else changed:

    with the fix          unannotated FINDING    annotated FINDING
    with name == "->"     unannotated FINDING    annotated NO FINDING

The silent half is the defect. The lane keeps reporting, its output looks
healthy, and a whole class of declaration has stopped being read.

Decided: match the FRAME only, `->` or `-[` ... `]->` with a non-empty inside.
Which cardinalities and effect classes are legal stays with
`metta_arrow_type_shape/5`, because `effect-class` is a catalog
`(vocabulary ...)` row and copying it into Python would be a second closed
value set to keep in step. That is the same defect class this repository has
been closing all week.

The two directions of error are not symmetric, which is what settles the
choice. Asked of the engine directly:

    ->                     yes, implicit
    -[det]->               yes, explicit
    -[$e]->                yes, explicit
    -[nondet,oracleIO]->   yes, explicit
    -[semidet,pure]->      NO      <- `pure` is not in the effect-class vocabulary
    -[]->  -  foo  -[det]  [det]->  NO

So the frame test accepts `-[semidet,pure]->` and the engine refuses it.
Deliberate: a declaration naming a bad effect class is itself a problem, and
lint reporting on it beats lint skipping it. Too restrictive would silently
drop a valid declaration, which is the failure being fixed.

Rejected: validating the slots in Python. It gets the exact answer today and
goes stale the first time the vocabulary gains a member. Revisit if a false
positive on a malformed annotation ever costs more than the duplication.

Open: the diagnostics now see the declaration; whether the ANNOTATION itself
should be diagnosed, so `pure` is named as not an effect class, is not done
here.
