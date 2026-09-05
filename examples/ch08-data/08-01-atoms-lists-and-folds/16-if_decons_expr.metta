; Purpose: demonstrate held expression deconstruction and its safe fallback.

!(test (if-decons-expr (a b c) $h $t (pair $h $t) fallback)
       (pair a (b c)))
!(test (if-decons-expr () $h $t (pair $h $t) fallback) fallback)
!(test (if-decons-expr $unknown $h $t (pair $h $t) fallback) fallback)
; Inspect the written call, so its tail is (1 2), not the result of addition.
!(test (if-decons-expr (+ 1 2) $h $t $t fallback) (1 2))
!(test (if-decons-expr (1 2) $h $t (+ $h 10) (/ 1 0)) 11)
; Already-bound binders constrain the shape; a mismatch selects fallback.
!(test (if-decons-expr (a b) a (b) matched fallback) matched)
!(test (if-decons-expr (a b) wrong (b) matched fallback) fallback)
!(test (if-decons-expr (a b) a () matched fallback) fallback)
!(test (collapse (if-decons-expr (a b) $h $t (superpose (1 2 2)) fallback))
       (1 2 2))
; Wrong known types keep the engine's Error result instead of raising in Prolog.
!(test (if-error (if-decons-expr 42 $h $t yes fallback) refused answered)
       refused)
