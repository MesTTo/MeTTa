;PLN's formulas, one call each, and the small helpers they are built from.
;`03-plntest.metta` and the files after it run the inference rules; this one
;asks the arithmetic directly, because a rule that answers the right term
;with the wrong strength is a silent error.
;
;PLN and NARS share several names -- `Truth_Revision`, `Truth_Negation`,
;`Truth_Abduction` -- and they are DIFFERENT functions with different
;arities, so a program imports one library or the other and never both.
!(import! &self (library lib_pln))

;`/safe` is the division every formula below goes through: a zero
;denominator answers NOTHING rather than raising, so a formula whose
;preconditions fail contributes no answer instead of an error term.
!(test (/safe 1.0 2.0) 0.5)
!(test (collapse (/safe 1.0 0.0)) ())
!(test (negate 0.25) 0.75)
!(test (invert 4.0) 0.25)
!(test (collapse (invert 0.0)) ())

;`and5` and `min5` are the five-argument spellings the consistency checks
;need, written out because MeTTa's `and` and `min` are binary.
!(test (and5 True True True True True) True)
!(test (and5 True True False True True) False)
!(test (min5 5 3 9 1 7) 1)

;The tuple helpers. `TupleCount` is `length`, `Without` is `exclude-item`,
;`ElementOf` is `is-member` and `Unique` is `list_to_set`: each names what
;the reasoner means by the engine operation it stands on.
!(test (TupleCount (a b c)) 3)
!(test (TupleCount ()) 0)
!(test (Without (1 2 3 2) 2) (1 3))
!(test (ElementOf 2 (1 2 3)) True)
!(test (ElementOf 9 (1 2 3)) False)
!(test (Unique (1 2 1 3) ()) (1 2 3))

;`InsertSorted` puts one element into a sorted tuple, and `InsertionSort`
;sorts a whole one. The second takes an accumulator it no longer uses, which
;is the shape the recursive version had.
!(test (InsertSorted 3 ()) (3))
!(test (InsertSorted 3 (1 5)) (1 3 5))
!(test (InsertSorted 0 (1 5)) (0 1 5))
!(test (InsertionSort (3 1 2) ()) (1 2 3))

;`Test2` is the library's own comparison form, reporting both sides and the
;verdict as data rather than raising, which is what makes a table of cases
;readable when several of them fail.
!(test (Test2 1 1) ((Is: 1) (Should: 1) (Passed: True)))
!(test (Test2 1 2) ((Is: 1) (Should: 2) (Passed: False)))

;`Consistency_ImplicationImplicantConjunction` is the guard on the
;conjunction rule: three positive base probabilities and two conditional
;probabilities that do not exceed what the base rates allow.
!(test (Consistency_ImplicationImplicantConjunction 0.5 0.5 0.5 0.5 0.5) True)
!(test (Consistency_ImplicationImplicantConjunction 0.0 0.5 0.5 0.5 0.5) False)
!(test (Consistency_ImplicationImplicantConjunction 0.5 0.5 0.1 0.5 0.5) False)

;The evidence map, PLN's version: the same c = w / (w + 1) NARS uses, through
;`/safe`, so a confidence of exactly one answers nothing rather than dividing
;by zero.
!(test (Truth_w2c 9.0) 0.9)
!(test (< (abs-math (- (Truth_c2w 0.9) 9.0)) 1.0e-9) True)
!(test (collapse (Truth_c2w 1.0)) ())

;`Truth_Negation` flips the strength and keeps the confidence.
!(test (Truth_Negation (stv 0.8 0.9)) (stv 0.19999999999999996 0.9))

;`Truth_Revision` merges two beliefs about one statement by adding their
;evidence, exactly as in NARS except that PLN's ceiling is 1.0 rather than
;0.99.
!(test (Truth_Revision (stv 1.0 0.9) (stv 0.0 0.9)) (stv 0.5 0.9473684210526316))

;`Truth_SymmetricModusPonens` is modus ponens over a SYMMETRIC link, where
;the rule cannot assume a direction, so it carries a fixed 0.2 for the
;negative branch rather than a node probability.
!(test (Truth_SymmetricModusPonens (stv 1.0 0.9) (stv 1.0 0.8)) (stv 1.0 0.8))

;`SymmetricModusPonensRuleGuard` is what decides which links that rule may
;fire on, and it is three equations rather than a list: a link type it does
;not name answers nothing at all, which is what prunes the branch.
!(test (SymmetricModusPonensRuleGuard Similarity) True)
!(test (SymmetricModusPonensRuleGuard IntentionalSimilarity) True)
!(test (SymmetricModusPonensRuleGuard ExtensionalSimilarity) True)
!(test (collapse (SymmetricModusPonensRuleGuard Inheritance)) ())

;`Truth_inversion` keeps the strength and penalises the confidence by a fixed
;0.6, which the library records as weaker than classic OpenCog PLN.
!(test (Truth_inversion (stv 0.5 0.9) (stv 0.8 0.9)) (stv 0.8 0.48600000000000004))

;`Truth_equivalenceToImplication` turns a symmetric link into a directed one
;through the PLN book's sim2inh formula, with a documented shortcut when the
;product of strength and confidence is already above 0.99.
!(test (Truth_equivalenceToImplication (stv 0.5 0.9) (stv 0.5 0.9) (stv 0.8 0.9))
       (stv 0.888888888888889 0.9))

;`TransitiveSimilarityStrength` is the strength half of the transitive
;similarity rule, and `Truth_transitiveSimilarity` is that strength with the
;weaker of the two confidences.
!(test (TransitiveSimilarityStrength 0.5 0.5 0.5 0.5 0.5) 0.3846153846153847)
!(test (Truth_transitiveSimilarity (stv 0.5 0.9) (stv 0.5 0.9) (stv 0.5 0.9)
                                   (stv 0.5 0.8) (stv 0.5 0.7))
       (stv 0.3846153846153847 0.7))

;`simpleDeductionStrength` is the deduction formula's strength, and it is
;where the consistency guard bites: preconditions that do not hold answer
;NOTHING, so the rule that calls it derives nothing rather than deriving
;something unjustified.
!(test (simpleDeductionStrength 0.5 0.5 0.5 0.5 0.5) 0.5)
!(test (collapse (simpleDeductionStrength 0.0 0.5 0.5 0.5 0.5)) ())

;`Truth_evaluationImplication` is that strength with a confidence discounted
;twice by 0.9, the rule's own two-step penalty.
!(test (Truth_evaluationImplication (stv 0.5 0.9) (stv 0.5 0.9) (stv 0.5 0.9)
                                    (stv 0.5 0.9) (stv 0.5 0.9))
       (stv 0.5 0.6561000000000001))

;PLN's `Truth_Induction` and `Truth_Abduction` take FIVE truth values where
;NARS's take two, because these formulas need the three node probabilities as
;well as the two links.
!(test (Truth_Induction (stv 0.5 0.9) (stv 0.5 0.9) (stv 0.5 0.9)
                        (stv 0.5 0.9) (stv 0.5 0.9))
       (stv 0.5 0.4736842105263158))
!(test (Truth_Abduction (stv 0.5 0.9) (stv 0.5 0.9) (stv 0.5 0.9)
                        (stv 0.5 0.9) (stv 0.5 0.9))
       (stv 0.5 0.4736842105263158))
