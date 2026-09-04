; Purpose: executable semantics for transparent finite value distributions.
; Guarantees: every lib_distribution head has a checked example, including
;   invalid mass and the distinction between independent marginals and a joint
;   law [tested: this file's !(test ...) forms; commit=WORKTREE].
; Fails when: a library operation changes its boundary, ordering, dependence,
;   or normalization contract without updating this consumer-facing example.

!(import! &self (library lib_distribution))

;Normalization collapses equal outcomes at their first position, removes zero
;support, and retains exact dyadic weights when the mass is already one.
!(test (ws-normalize ((0.25 x) (0.0 gone) (0.5 y) (0.25 x)))
       ((0.5 x) (0.5 y)))
!(test (ws-normalize ((0.25 1) (0.75 1.0)))
       ((0.25 1) (0.75 1.0)))

;Unary map is a push-forward; equal mapped values collapse.
!(test (ws-map abs-math ((0.25 -1) (0.25 1) (0.5 2)))
       ((0.5 1) (0.5 2)))

;Binary map visits the left distribution first, then the right. Addition is
;convolution, and the name says that the two inputs are assumed independent.
!(test (ws-map2-independent + ((0.25 0) (0.75 1)) ((0.5 0) (0.5 1)))
       ((0.125 0) (0.5 1) (0.375 2)))

;Threshold is inclusive. Comparison is the strict independent probability
;P(X > Y), where a tie contributes zero.
!(test (ws-mass-at-least ((0.25 1) (0.75 3)) 1) 1.0)
!(test (ws-mass-at-least ((0.25 1) (0.75 3)) 4) 0.0)
!(test (ws-prob-gt-independent ((0.5 0) (0.5 1)) ((1.0 0))) 0.5)

;Conditioning reads dependence from one explicit joint distribution.
!(test (ws-condition-joint
         ((0.25 (Pair rain late))
          (0.25 (Pair rain early))
          (0.5 (Pair dry early)))
         rain)
       ((0.5 late) (0.5 early)))

;Average and Bernoulli addition also say their independence assumption.
!(test (ws-average-independent (((1.0 2)) ((1.0 4)))) ((1.0 3)))
!(test (ws-add-bernoulli-independent ((1.0 2)) 0.25)
       ((0.75 2) (0.25 3)))

;The same uniform marginal used twice independently can sum to one. A perfectly
;correlated joint law cannot: only zero and two occur. Use ws-map over the joint
;when correlation is part of the model.
!(test (ws-map2-independent + ((0.5 0) (0.5 1)) ((0.5 0) (0.5 1)))
       ((0.25 0) (0.5 1) (0.25 2)))
!(test (ws-map
         (|-> ($pair) (+ (index-atom $pair 1) (index-atom $pair 2)))
         ((0.5 (Pair 0 0)) (0.5 (Pair 1 1))))
       ((0.5 0) (0.5 2)))

;Invalid mass refuses with a remedy instead of yielding an empty or silently
;renormalized answer.
!(test (ws-normalize ())
       (Error () "ws-normalize requires a nonempty finite distribution; provide at least one positive-weight outcome"))
!(test (ws-normalize ((0.0 nowhere)))
       (Error ((0.0 nowhere)) "ws-normalize requires positive total mass; provide at least one positive-weight outcome"))
!(test (ws-normalize ((-1.0 wrong)))
       (Error ((-1.0 wrong)) "ws-normalize requires nonnegative weights; remove negative weights and provide at least one positive-weight outcome"))
