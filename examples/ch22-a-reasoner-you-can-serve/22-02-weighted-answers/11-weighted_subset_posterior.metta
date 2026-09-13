; Purpose: show exact posterior marginals for independent Bernoulli candidates
; conditioned on one nonnegative integer additive observation.
; Assumes: each row is (candidate ID LOSS (ratio NUMERATOR DENOMINATOR)); IDs
; are unique ground terms and every loss uses one shared integer scale.
; Guarantees: all examples return exact reduced ratios in input order [tested:
; examples/ch22-a-reasoner-you-can-serve/22-02-weighted-answers/11-weighted_subset_posterior.metta;
; commit=WORKTREE].
; Guarantees: literal identities, alternative input laws and reconstructed
; equations retain their ordinary MeTTa behavior [tested:
; examples/ch22-a-reasoner-you-can-serve/22-02-weighted-answers/11-weighted_subset_posterior.metta;
; commit=WORKTREE].
; Fails when: the observation has zero mass; call
; weighted-subset-mass-independent to distinguish impossibility before asking
; for a conditional posterior.

!(import! &self (library lib_statistics))

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

; The empty model has one configuration with zero loss.
!(test (weighted-subset-posterior-independent () 0)
       (subset-posterior (ratio 1 1) ()))

; Candidate identity is structural: integer1 and float1.0 are different events.
!(test (weighted-subset-posterior-independent
         ((candidate 1 0 (ratio 1 2)) (candidate 1.0 0 (ratio 1 3))) 0)
       (subset-posterior (ratio 1 1)
         ((candidate-posterior 1 (ratio 1 2))
          (candidate-posterior 1.0 (ratio 1 3)))))

; Runnable expressions and Error atoms can name events without executing.
!(test (weighted-subset-posterior-independent
         ((candidate (+ 1 2) 0 (ratio 1 2)) (candidate (Error a b) 0 (ratio 1 3))) 0)
       (quote (subset-posterior (ratio 1 1)
         ((candidate-posterior (+ 1 2) (ratio 1 2))
          (candidate-posterior (Error a b) (ratio 1 3))))))

; Alternative caller rows remain separate answers, including repeated laws.
!(test (collapse
         (let $rows (superpose
                      (((candidate a 1 (ratio 1 2)))
                       ((candidate a 1 (ratio 1 2)))
                       ((candidate b 1 (ratio 1 3)))))
           (weighted-subset-mass-independent $rows 1)))
       ((ratio 1 2) (ratio 1 2) (ratio 1 3)))

; Extract the library's equation as data, reconstruct its function and apply it.
!(test (let $source
         (match &self (= (weighted-subset-mass-independent $rows $target) $body)
           (quote (|-> ($rows $target) $body)))
         (let $mass (eval $source)
           ($mass (quote ((candidate a 1 (ratio 1 3)))) 1)))
       (ratio 1 3))

; Ordinary metagraph matching can supply the candidate relation.
(subset-event from-space 2 (ratio 1 3))
(subset-event other 3 (ratio 1 4))
!(test (let $rows (collapse
                   (match &self (subset-event $id $loss $prior)
                     (quote (candidate $id $loss $prior))))
         (weighted-subset-mass-independent $rows 2))
       (ratio 1 4))
