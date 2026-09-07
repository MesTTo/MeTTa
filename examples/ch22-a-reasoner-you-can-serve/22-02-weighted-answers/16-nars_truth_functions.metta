;NARS's truth functions, one call each. A truth value is (stv <frequency>
;<confidence>): how often the statement held, and how much evidence stands
;behind that. `08-nars_direct.metta` and `09-nars_tuffy.metta` run the
;inference rules that call these; this file asks each function directly,
;because a rule that answers the right term with the wrong truth value is a
;silent error and the arithmetic is where it would live.
!(import! &self (library lib_nars))

;`Truth_c2w` and `Truth_w2c` are the two directions of the confidence-to-
;evidence map, c = w / (w + 1). Confidence approaches one as evidence grows
;and never reaches it, which is what makes the pair a bijection on [0,1).
!(test (Truth_w2c 9.0) 0.9)
!(test (Truth_w2c 0.0) 0.0)
!(test (Truth_w2c 1.0) 0.5)
!(test (< (abs-math (- (Truth_c2w 0.9) 9.0)) 1.0e-9) True)
!(test (Truth_c2w 0.0) 0.0)
!(test (< (abs-math (- (Truth_w2c (Truth_c2w 0.75)) 0.75)) 1.0e-9) True)

;`Truth_Deduction` multiplies frequencies and multiplies the product into the
;confidences: a chain is no stronger than its weakest link, and a chain of
;two 0.9-confidence beliefs is 0.81.
!(test (Truth_Deduction (stv 1.0 0.9) (stv 1.0 0.9)) (stv 1.0 0.81))
!(test (Truth_Deduction (stv 0.5 0.9) (stv 1.0 0.9)) (stv 0.5 0.405))

;`Truth_Abduction` keeps the second frequency and converts the evidence, so
;the answer is a WEAKER confidence rather than a scaled one: this is the
;guess that runs the implication backwards.
!(test (Truth_Abduction (stv 1.0 0.9) (stv 1.0 0.9))
       (stv 1.0 0.44751381215469616))
!(test (Truth_Induction (stv 1.0 0.9) (stv 1.0 0.9))
       (stv 1.0 0.44751381215469616))

;`Truth_Induction` is `Truth_Abduction` with the operands swapped, and that
;is its whole definition, so the two agree exactly where the operands agree
;and mirror each other where they do not.
!(test (== (Truth_Induction (stv 0.5 0.9) (stv 1.0 0.8))
           (Truth_Abduction (stv 1.0 0.8) (stv 0.5 0.9)))
       True)

;`Truth_Exemplification` answers frequency 1.0 whatever went in: it is the
;rule that turns a chain into an instance, and an instance either happened or
;is not derived at all.
!(test (Truth_Exemplification (stv 1.0 0.9) (stv 1.0 0.9))
       (stv 1.0 0.44751381215469616))
!(test (Truth_Exemplification (stv 0.2 0.9) (stv 0.2 0.9))
       (stv 1.0 0.03138318481208834))

;`Truth_Negation` flips the frequency and keeps the confidence, because
;evidence about a statement is evidence about its negation.
!(test (Truth_Negation (stv 1.0 0.9)) (stv 0.0 0.9))
!(test (Truth_Negation (stv 0.0 0.9)) (stv 1.0 0.9))

;The three structural rules are the binary ones against the default
;(stv 1.0 0.9), which is what "structural" means here: one premise and the
;language's own certainty about the shape.
!(test (Truth_StructuralDeduction (stv 1.0 0.9)) (stv 1.0 0.81))
!(test (== (Truth_StructuralDeduction (stv 0.5 0.9))
           (Truth_Deduction (stv 0.5 0.9) (stv 1.0 0.9)))
       True)
!(test (Truth_StructuralDeductionNegated (stv 1.0 0.9)) (stv 0.0 0.81))
!(test (Truth_StructuralIntersection (stv 0.8 0.9)) (stv 0.8 0.81))

;`Truth_Intersection` multiplies both components, which is the and of two
;independent beliefs.
!(test (Truth_Intersection (stv 0.8 0.9) (stv 0.5 0.9)) (stv 0.4 0.81))

;`Truth_or` is the probabilistic or on plain numbers rather than on truth
;values, and it is the one member of the family that takes and answers a
;NUMBER: the others are written over it.
!(test (Truth_or 0.5 0.5) 0.75)
!(test (Truth_or 0.0 0.0) 0.0)
!(test (Truth_or 1.0 0.0) 1.0)

;`Truth_Comparison` and `Truth_Resemblance` are the symmetric relations, both
;built on that or: comparison divides the product by it, resemblance
;multiplies the confidences by it.
!(test (Truth_Comparison (stv 1.0 0.9) (stv 1.0 0.9))
       (stv 1.0 0.44751381215469616))
!(test (Truth_Comparison (stv 0.0 0.9) (stv 0.0 0.9)) (stv 0.0 0.0))
!(test (Truth_Resemblance (stv 1.0 0.9) (stv 0.5 0.9)) (stv 0.5 0.81))
!(test (Truth_Analogy (stv 1.0 0.9) (stv 0.5 0.9)) (stv 0.5 0.405))

;`Truth_Difference` is the and-not: the first frequency times the second's
;complement.
!(test (Truth_Difference (stv 1.0 0.9) (stv 0.25 0.9)) (stv 0.75 0.81))

;The five decomposition rules take a compound's truth back to a component's.
;Each names the polarity of its three positions, so PNN is positive premise,
;negative compound, negative conclusion.
!(test (Truth_DecomposePNN (stv 1.0 0.9) (stv 0.0 0.9)) (stv 0.0 0.81))
!(test (Truth_DecomposeNPP (stv 0.0 0.9) (stv 1.0 0.9)) (stv 1.0 0.81))
!(test (Truth_DecomposePNP (stv 1.0 0.9) (stv 0.0 0.9)) (stv 1.0 0.81))
!(test (== (Truth_DecomposePPP (stv 1.0 0.9) (stv 1.0 0.9))
           (Truth_DecomposeNPP (Truth_Negation (stv 1.0 0.9)) (stv 1.0 0.9)))
       True)

;TWO of the family answer a BARE PAIR rather than an (stv ...), which is
;upstream PeTTa's own shape for them, byte for byte, so this engine answers
;what the arbiter answers. It matters to a caller: a bare pair does not match
;an (stv $f $c) pattern, so a rule that reads its own result has to know
;which two these are.
!(test (Truth_Union (stv 0.5 0.9) (stv 0.5 0.9)) (0.75 0.81))
!(test (Truth_DecomposeNNN (stv 0.0 0.9) (stv 0.0 0.9)) (0.0 0.81))

;`Truth_Eternalize` turns an event's confidence into an eternal one by
;treating it as evidence, so it always weakens.
!(test (Truth_Eternalize (stv 0.8 0.9)) (stv 0.8 0.4736842105263158))

;`Truth_Revision` is the one that ADDS evidence: two beliefs about the same
;statement become one whose confidence is above both, with the frequency a
;weighted average. It is the only rule here that can raise a confidence.
!(test (Truth_Revision (stv 1.0 0.9) (stv 0.0 0.9)) (stv 0.5 0.9473684210526316))
!(test (Truth_Revision (stv 1.0 0.5) (stv 1.0 0.5)) (stv 1.0 0.6666666666666666))

;And the ceiling in it is a NARS law rather than an accident: confidence is
;capped at 0.99, so no amount of evidence makes a belief certain.
!(test (Truth_Revision (stv 1.0 0.99) (stv 1.0 0.99)) (stv 1.0 0.99))

;`Truth_Expectation` is the decision-making projection: a single number that
;places a truth value on [0,1], half plus confidence times the frequency's
;distance from half.
!(test (Truth_Expectation (stv 1.0 0.9)) 0.95)
!(test (Truth_Expectation (stv 0.0 0.9)) 0.04999999999999999)
!(test (Truth_Expectation (stv 0.5 0.9)) 0.5)
!(test (Truth_Expectation (stv 1.0 0.0)) 0.5)
