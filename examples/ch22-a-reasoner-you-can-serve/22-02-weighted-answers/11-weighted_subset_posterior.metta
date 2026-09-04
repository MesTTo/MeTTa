; Purpose: show exact posterior marginals for independent Bernoulli candidates
; conditioned on one nonnegative integer additive observation.
; Assumes: each row is (candidate ID LOSS (ratio NUMERATOR DENOMINATOR)); IDs
; are unique ground terms and every loss uses one shared integer scale.
; Guarantees: all examples return exact reduced ratios in input order [tested:
; examples/ch22-a-reasoner-you-can-serve/22-02-weighted-answers/11-weighted_subset_posterior.metta;
; commit=afc4024cef7d4b7bcdd194bb030a112187b676d0].
; Fails when: the observation has zero mass; call
; weighted-subset-mass-independent to distinguish impossibility before asking
; for a conditional posterior.

!(import! &self (library lib_combinatorics))

;Only pump-a can explain loss 2. The observation mass is
;(1/2)*(1-1/4)=3/8, so its posterior is certain and pump-b's is zero.
!(test
  (weighted-subset-posterior-independent
    ((candidate pump-a 2 (ratio 1 2))
     (candidate pump-b 3 (ratio 1 4)))
    2)
  (subset-posterior
    (ratio 3 8)
    ((candidate-posterior pump-a (ratio 1 1))
     (candidate-posterior pump-b (ratio 0 1)))))

;Equal losses do not collapse distinct candidate identities. Conditioning on
;exactly one of two fair events leaves both marginals at one half.
!(test
  (weighted-subset-posterior-independent
    ((candidate left 1 (ratio 1 2))
     (candidate right 1 (ratio 1 2)))
    1)
  (subset-posterior
    (ratio 1 2)
    ((candidate-posterior left (ratio 1 2))
     (candidate-posterior right (ratio 1 2)))))

;A zero-loss event cannot affect the observed sum. Its posterior therefore
;stays at its prior while the event that explains loss 2 becomes certain.
!(test
  (weighted-subset-posterior-independent
    ((candidate metadata-flag 0 (ratio 1 3))
     (candidate failing-part 2 (ratio 1 2)))
    2)
  (subset-posterior
    (ratio 1 2)
    ((candidate-posterior metadata-flag (ratio 1 3))
     (candidate-posterior failing-part (ratio 1 1)))))

;Mass remains defined when conditioning would not be. A zero result is an
;exact reachability answer, not a fabricated posterior.
!(test
  (weighted-subset-mass-independent
    ((candidate absent 5 (ratio 0 1)))
    5)
  (ratio 0 1))

;Fixed-point callers scale every loss and the target together. No float is a
;sum key, so 1.25 is represented here on the shared hundredths lattice.
!(test
  (weighted-subset-mass-independent
    ((candidate scaled-loss 125 (ratio 2 5)))
    125)
  (ratio 2 5))

