;The reporting door under the assert family. Every one of the eight forms in
;this chapter collapses its two sides into answer bags, computes a verdict,
;and hands the verdict plus both bags to one of two operations:
;`assert-answers` for a two-sided comparison and `assert-includes-answers`
;for a one-sided containment. They are callable directly, which is what a
;library writing its own assertion form uses.
;
;The verdict EVALUATES and the other three arguments are held. A true verdict
;answers `true` and prints nothing.
!(test (assert-answers True (my-check 1) (1 2) (1 2)) True)
!(test (assert-answers (== 1 1) (my-check 1) (1) (1)) True)

;A false verdict raises, carrying the call AS WRITTEN and the two directed
;bag differences: what was missing from the produced bag and what was in
;excess of the expected one. The call is whatever you passed, so a library's
;own form reports its own name rather than this one.
!(test (let $reported (catch (assert-answers False (my-check 1) (1 2) (1 3)))
         (unify $reported (Error $ball $context) (repr $ball) no-error))
       "(metta_assertion_failed (my-check 1) (3) (2))")

;The two bags arrive AS WRITTEN and the door computes their two directed
;differences, so a repeated answer counts every time it appears: (a a b)
;against (a b b) leaves one b wanted and one a produced.
!(test (let $reported (catch (assert-answers False (checked (f 1)) (a a b) (a b b)))
         (unify $reported (Error $ball $context) (repr $ball) no-error))
       "(metta_assertion_failed (checked (f 1)) (b) (a))")

;`assert-includes-answers` is the one-sided twin: an answer in excess of the
;expectation is legal, so the excess side is ABSENT rather than empty and the
;report leaves it as a variable.
!(test (assert-includes-answers True (my-check 2) (1 2 3) (1 2)) True)
!(test (let $reported (catch (assert-includes-answers False (my-check 2) (1 2) (7)))
         (unify $reported (Error $ball $context) (repr $ball) no-error))
       "(metta_assertion_failed (my-check 2) (7) $_0)")

;Which is exactly the difference between the two failures the shipped forms
;report: assertEqual goes through the two-sided door and assertIncludes
;through the one-sided one, and the reports differ in that one field.
!(test (let $reported (catch (assertEqual (+ 1 1) 3))
         (unify $reported (Error $ball $context) (repr $ball) no-error))
       "(metta_assertion_failed (assertEqual (+ 1 1) 3) (3) (2))")
!(test (let $reported (catch (assertIncludes (superpose (1 2)) (7)))
         (unify $reported (Error $ball $context) (repr $ball) no-error))
       "(metta_assertion_failed (assertIncludes (superpose (1 2)) (7)) (7) $_0)")

;Writing your own assertion form is those three steps and nothing else: a
;verdict, the call to report, and the two bags, each of them a VALUE by the
;time the door sees it. The declaration is the
;load-bearing line: an assertion form HOLDS the expression it is checking,
;the way every shipped one does, or the argument is evaluated at the call
;site and the form runs once per answer.
(: assert-sorted (-> Atom Bool))
(= (assert-sorted $expression)
   (let* (($answers (collapse $expression))
          ($sorted (sort-atom $answers)))
     (assert-answers (== $answers $sorted)
                     (assert-sorted $expression)
                     $answers
                     $sorted)))
!(test (assert-sorted (superpose (1 2 3))) True)
!(test (let $reported (catch (assert-sorted (superpose (3 1 2))))
         (unify $reported (Error $ball $context) (repr $ball) no-error))
       "(metta_assertion_failed (assert-sorted (superpose (3 1 2))) () ())")
