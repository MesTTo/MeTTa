;The five operations the measure algebra is built from. `01-measure.metta`
;uses the surface -- `ws-top`, `ws-best`, `ws-collapse`, `ws-sample!` -- and
;each of those is one of these with the plumbing around it.
!(import! &self (library lib_measure))

;`ws-ranked` is the ordering: pairs best-first. It sorts by the standard
;order of terms and reverses, so the WEIGHT decides because it is written
;first, and equal weights fall back on the value.
!(test (ws-ranked ((0.2 low) (0.7 high) (0.1 mid)))
       ((0.7 high) (0.2 low) (0.1 mid)))
!(test (ws-ranked ()) ())

;`ws-take` is beam search's keep rule: the first k, whatever order they are
;in. It is total in both directions, so a k past the end is the whole tuple
;and a k of zero is nothing.
!(test (ws-take ((0.7 high) (0.2 low) (0.1 mid)) 2) ((0.7 high) (0.2 low)))
!(test (ws-take ((0.7 high)) 5) ((0.7 high)))
!(test (ws-take ((0.7 high) (0.2 low)) 0) ())
!(test (ws-take () 2) ())

;`ws-top` is those two composed, which is why it is one call in the surface
;and two operations here.
!(test (== (ws-top ((0.2 low) (0.7 high) (0.1 mid)) 2)
           (ws-take (ws-ranked ((0.2 low) (0.7 high) (0.1 mid))) 2))
       True)

;`ws-pickmax` is the step `ws-best` folds with: the heavier of two pairs, and
;the FIRST of two equal ones, which is what makes the fold left-biased and so
;deterministic on ties.
!(test (ws-pickmax (0.2 a) (0.7 b)) (0.7 b))
!(test (ws-pickmax (0.7 b) (0.2 a)) (0.7 b))
!(test (ws-pickmax (0.5 a) (0.5 b)) (0.5 a))

;`ws-sample-walk` is the inverse-transform step under `ws-sample!`: it walks
;the pairs subtracting weights until the budget runs out, so it is the random
;draw with the randomness taken OUT. Passing the budget explicitly is what
;makes sampling testable.
!(test (ws-sample-walk ((0.5 a) (0.3 b) (0.2 c)) 0.1) a)
!(test (ws-sample-walk ((0.5 a) (0.3 b) (0.2 c)) 0.6) b)
!(test (ws-sample-walk ((0.5 a) (0.3 b) (0.2 c)) 0.9) c)

;The last pair absorbs everything left over, so a budget at or past the total
;mass still lands on a value rather than falling off the end.
!(test (ws-sample-walk ((0.5 a) (0.5 b)) 1.5) b)

;`ws-merge-into` is the step `ws-collapse` folds with: add one pair to an
;accumulator, summing weights where the VALUE already appears and appending
;where it does not. That is the summing of explanations for one conclusion.
!(test (ws-merge-into () (0.3 x)) ((0.3 x)))
!(test (ws-merge-into ((0.3 x) (0.4 y)) (0.2 x)) ((0.5 x) (0.4 y)))
!(test (ws-merge-into ((0.3 x)) (0.2 z)) ((0.3 x) (0.2 z)))

;And the fold over it is `ws-collapse`, so the surface operation is this step
;and nothing else.
!(test (== (ws-collapse ((0.3 x) (0.4 y) (0.2 x)))
           (ws-merge-into (ws-merge-into (ws-merge-into () (0.3 x)) (0.4 y))
                          (0.2 x)))
       True)
