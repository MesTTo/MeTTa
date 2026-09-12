; Purpose: executable semantics for transparent finite value distributions.
; Guarantees: every lib_distribution head has a checked example, including
;   invalid mass and the distinction between independent marginals and a joint
;   law [tested: this file's !(test ...) forms; commit=f99382c5b4127b49de6e0a6e355d50eda39c5df6].
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

;The moments are folds over the finite support, so they are what the law says
;rather than what a sample of it suggests. Two coin-flip values, one and three:
!(bind! &two-sided ((0.5 1) (0.5 3)))
!(test (ws-expect &two-sided) 2.0)
!(test (ws-variance &two-sided) 1.0)
!(test (ws-deviation &two-sided) 1.0)

;The first central moment is 0 by definition, and this answers exactly that;
;the second IS the variance, which is what makes the general form worth having.
!(test (ws-central-moment &two-sided 1) 0.0)
!(test (== (ws-central-moment &two-sided 2) (ws-variance &two-sided)) True)
!(test (ws-central-moment &two-sided 3) 0.0)

;The variance is computed about the mean in two passes. The one-pass form
;E[X^2] - E[X]^2 is algebraically the same and numerically not: at a mean of a
;billion it subtracts two nearly equal numbers and keeps none of the answer.
!(bind! &shifted ((0.5 999999999.0) (0.5 1000000001.0)))
!(test (ws-variance &shifted) 1.0)
!(test (let* (($mean (ws-expect &shifted))
              ($squares (ws-expect (ws-map (|-> ($x) (* $x $x)) &shifted))))
         (== (- $squares (* $mean $mean)) 1.0))
       False)

;`ws-mass-at-most` is the cumulative distribution function and
;`ws-mass-at-least` its inclusive upper tail, so the two account for every
;outcome between them.
!(test (ws-mass-at-most &two-sided 1) 0.5)
!(test (ws-mass-at-most &two-sided 3) 1.0)
!(test (ws-mass-at-most &two-sided 0) 0.0)
!(test (+ (ws-mass-at-most &two-sided 1) (ws-mass-at-least &two-sided 3)) 1.0)

;`ws-quantile` answers the smallest value whose cumulative mass reaches the
;level, and the median is the quantile at one half. A level outside (0, 1] has
;no value to answer, so it refuses.
!(test (ws-quantile &two-sided 0.5) 1)
!(test (ws-quantile &two-sided 0.6) 3)
!(test (ws-quantile &two-sided 1.0) 3)
!(test (ws-median &two-sided) 1)
!(test (if-error (ws-quantile &two-sided 0.0) refused fine) refused)
!(test (if-error (ws-quantile &two-sided 1.5) refused fine) refused)

;`ws-quantile-walk` is the recursion the quantile is defined by: values in
;increasing order, mass added until the level is reached, so the last value
;answers whatever rounding leaves. Calling it directly is how the definition
;reads, and the quantile is that call over the sorted support.
!(test (ws-quantile-walk ((1 0.5) (3 0.5)) 0.5 0.0) 1)
!(test (ws-quantile-walk ((1 0.5) (3 0.5)) 0.75 0.0) 3)
!(test (ws-quantile-walk ((1 0.5) (3 0.5)) 1.0 0.0) 3)

;`ws-support` is what the distribution can answer, once each, smallest first.
!(test (ws-support &two-sided) (1 3))
!(test (ws-support ((0.5 b) (0.25 a) (0.25 b))) (a b))

;`ws-sum-independent` convolves the distribution with itself, so it is the law
;of a total rather than a simulation of one: two draws of one-or-three are two,
;four or six, and the mean is n times the mean of one draw.
!(test (ws-sum-independent &two-sided 0) ((1.0 0)))
!(test (ws-sum-independent &two-sided 1) ((0.5 1) (0.5 3)))
!(test (ws-sum-independent &two-sided 2) ((0.25 2) (0.5 4) (0.25 6)))
!(test (ws-expect (ws-sum-independent &two-sided 3)) 6.0)
!(test (ws-variance (ws-sum-independent &two-sided 3)) 3.0)
!(test (if-error (ws-sum-independent &two-sided -1) refused fine) refused)

;And every one of them preserves the normalization refusal, because each starts
;by normalizing what it was given.
!(test (if-error (ws-variance ()) refused fine) refused)
!(test (if-error (ws-quantile ((0.0 nowhere)) 0.5) refused fine) refused)
