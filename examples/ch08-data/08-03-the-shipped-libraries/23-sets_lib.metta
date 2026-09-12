; Purpose: sets as ordered expressions, and the merge operations over them.
; [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/23-sets_lib.metta; commit=WORKTREE].
!(import! &self (library lib_sets))

; A set is an expression in the standard order of terms with no duplicates, so
; `set-of` sorts and deduplicates once and the answer is an ordinary expression:
; `size-atom` counts it, `==` compares it and `()` is the empty set.
!(test (set-of (3 1 2 1)) (1 2 3))
!(test (set-of ()) ())
!(test (size-atom (set-of (b a b))) 2)
!(test (== (set-of (2 1)) (set-of (1 2 2))) True)
; Numbers sort before symbols in the standard order, and a symbol before an
; expression, so a mixed set has a fixed shape whatever order it was written in.
!(test (set-of (b (x) 2 a 1)) (1 2 a b (x)))

; `set-is` asks whether an expression already is one: ordered and without
; duplicates. Every other head asks the same question before it merges.
!(test (set-is (1 2 3)) True)
!(test (set-is (2 1)) False)
!(test (set-is (1 1)) False)
!(test (set-is 3) False)

; Membership compares TERMS rather than unifying, so a variable is not a member
; of a set of numbers, where a match would have bound it to the first one.
!(test (set-member (1 2 3) 2) True)
!(test (set-member (1 2 3) 4) False)
!(test (set-member (1 2 3) $x) False)

; Insertion and removal answer a new set and leave the input alone; adding what
; is there and removing what is not both answer the set unchanged.
!(test (set-insert (1 3) 2) (1 2 3))
!(test (set-insert (1 3) 3) (1 3))
!(test (set-remove (1 2 3) 2) (1 3))
!(test (set-remove (1 2 3) 9) (1 2 3))
!(bind! &primes (set-of (2 3 5)))
!(test (set-insert &primes 7) (2 3 5 7))
!(test &primes (2 3 5))

; The four merges, each one pass down both sets.
!(test (set-union (1 3) (2 3)) (1 2 3))
!(test (set-intersection (1 2 3) (2 3 4)) (2 3))
!(test (set-difference (1 2 3) (2 3 4)) (1))
!(test (set-difference (2 3 4) (1 2 3)) (4))
!(test (set-symmetric-difference (1 2 3) (2 3 4)) (1 4))
!(test (set-union () ()) ())
!(test (set-intersection (1 2) (3 4)) ())

; The merges over a whole collection of sets: the union of none is empty, and
; the intersection of none is refused, because it would be every term there is.
!(test (set-union-all ((1 2) (2 3) (5))) (1 2 3 5))
!(test (set-union-all ()) ())
!(test (set-intersection-all ((1 2 3) (2 3 4) (3 4 5))) (3))
!(test (if-error (catch (set-intersection-all ())) refused fine) refused)

; The two questions between sets. A set is a subset of itself, the empty set is
; a subset of everything and disjoint from everything, itself included.
!(test (set-subset (1 2) (1 2 3)) True)
!(test (set-subset (1 2 3) (1 2)) False)
!(test (set-subset () (1)) True)
!(test (set-subset (1 2) (1 2)) True)
!(test (set-disjoint (1 2) (3 4)) True)
!(test (set-disjoint (1 2) (2 3)) False)
!(test (set-disjoint () ()) True)

; The laws hold because the representation is canonical: a union is the same
; set whichever way round, and De Morgan's law is an `==` over expressions.
!(test (== (set-union (1 2) (3)) (set-union (3) (1 2))) True)
!(test (== (set-difference (1 2 3 4) (set-union (1) (2)))
           (set-intersection (set-difference (1 2 3 4) (1)) (set-difference (1 2 3 4) (2))))
       True)

; An argument that is not a set is refused rather than merged into nonsense:
; the host's own merge over an unordered list answers (2 1 1) with nothing said,
; which is the wrong answer with no symptom this library exists to remove.
!(test (if-error (catch (set-union (2 1) (1))) refused fine) refused)
!(test (if-error (catch (set-member (1 1) 1)) refused fine) refused)
!(test (if-error (catch (set-union-all ((1) (2 1)))) refused fine) refused)
