; Purpose: show lib_pln2's explicit evidence scale, Beta moments, and
; support-checked independent uncertainty propagation.
; Assumes: support IDs name stable source evidence, not query-local positions.
; Guarantees: every asserted formula runs through the public lib_pln2 surface
; [tested: examples/ch22-a-reasoner-you-can-serve/22-02-weighted-answers/10-pln2-ctv.metta; commit=afc4024cef7d4b7bcdd194bb030a112187b676d0].
; Fails when: two independent operands name the same support; factor that
; support inside an owned reasoner before combining their residuals.

!(import! &self (library lib_pln2))

;The scale that maps confidence to evidence count belongs to the caller.
;At confidence one half, the count equals the chosen scale.
!(test (pln2-confidence-count 0.5 20.0) 20.0)
!(test (pln2-count-confidence 20.0 20.0) 0.5)

;A Beta(2,3) has mean 2/5 and variance 2*3/(5^2*6).
!(test (pln2-beta-moments (beta 2.0 3.0)) (moments 0.4 0.04))
!(test (pln2-beta-update (beta 2.0 3.0) 4 1) (beta 6.0 4.0))

;Moment propagation consumes explicit supports and returns their ordered union.
!(test
  (pln2-product-independent
    (supported (moments 0.5 0.1) (sensor-a))
    (supported (moments 0.4 0.05) (sensor-b)))
  (supported (moments 0.2 0.0335) (sensor-a sensor-b)))

;For B, the three inputs are B|A, B|not-A, and A. Their source evidence must
;be mutually independent. The variance includes uncertainty in all three.
(= (supported-mean (supported (moments $mean $_variance) $_support)) $mean)
(= (supported-variance (supported (moments $_mean $variance) $_support)) $variance)
(= (conditional-result)
   (pln2-total-probability-independent
     (supported (moments 0.8 0.02) (positive-conditional))
     (supported (moments 0.2 0.03) (negative-conditional))
     (supported (moments 0.6 0.04) (condition))))
!(test (< (abs-math (- (supported-mean (conditional-result)) 0.56)) 1.0e-12) true)
!(test (< (abs-math (- (supported-variance (conditional-result)) 0.0284)) 1.0e-12) true)

;An STV can round-trip only while its finite concentration is identifiable.
(= (restored-stv)
   (pln2-moments-stv (pln2-stv-moments (stv 0.4 0.75) 20.0) 20.0))
(= (stv-strength (stv $strength $_confidence)) $strength)
(= (stv-confidence (stv $_strength $confidence)) $confidence)
!(test (< (abs-math (- (stv-strength (restored-stv)) 0.4)) 1.0e-12) true)
!(test (< (abs-math (- (stv-confidence (restored-stv)) 0.75)) 1.0e-12) true)

