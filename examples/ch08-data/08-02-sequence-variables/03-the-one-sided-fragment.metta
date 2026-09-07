; ONE SIDE CARRIES NO GAP AT ALL. That is the first of the three restrictions
; of sequence unification that are proved finite, and it is the one every gap
; ask in a MeTTa program lands in, because every door faces a VALUE on the
; other side: a `match` faces stored atoms, a `let` and a `case` face the
; expression they were handed, an equation head faces a call. Data carries no
; gap, so the pattern is the only side with one, and matching is enough.
;
; Matching one is the enumeration of its splits and nothing more. A gap
; consumes a run of the other side's children, SHORTEST FIRST, and every other
; position decides the way it always did.

;;; Shortest first, one answer per split, so a two-gap pattern parses a
;;; sequence with no recursion written.
!(test (collapse (let ((:seg $pre) SEP (:seg $post)) (a b SEP c SEP d)
                      (pair $pre $post)))
       ((pair (a b) (c SEP d)) (pair (a b SEP c) (d))))

;;; Zero children is a run, so the empty case needs no separate arm.
!(test (let (row (:seg $r)) (row) $r) ())
!(test (let (row (:seg $r)) (row a b c) $r) (a b c))

;;; The run a named gap took is the EXPRESSION those children make, which is
;;; an ordinary value: read it with the atom operations like any other.
!(test (get-metatype (let (row (:seg $r)) (row a b) $r)) Expression)
!(test (size-atom (let (row (:seg $r)) (row a b) $r)) 2)
!(test (car-atom (let (row (:seg $r)) (row a b) $r)) a)

;;; A REPEATED named gap has to take the same run twice, and "the same" is the
;;; engine's own comparison rather than sameness of spelling, so 1 and 1.0
;;; agree here as they do at every other position.
!(test (let (f (:seg $x) g (:seg $x)) (f a b g a b) $x) (a b))
!(test (collapse (let (f (:seg $x) g (:seg $x)) (f a b g c) $x)) ())
!(test (let (f (:seg $x) g (:seg $x)) (f 1 g 1.0) took) took)

;;; Distinct `...` occurrences are distinct variables, so neither constrains
;;; the other; what pins this pattern down is the literal `g` between them.
!(test (collapse (let (f ... g ...) (f a g b c) done)) (done))

;;; A gap below the root matches inside a child, and a settled child that
;;; disagrees refutes every split rather than some of them.
!(test (let (f (g ...) b) (f (g 1 2) b) nested) nested)
!(test (collapse (let (A ... D) (A b c E) never)) ())

;;; Against a SPACE the stored side is the value, so a gap pattern reads every
;;; arity the gap can span, and it joins with an ordinary conjunct the way any
;;; other pattern does.
!(add-atom &self (edge a b))
!(add-atom &self (edge b c d))
!(add-atom &self (tag b hot))
!(test (collapse (match &self (edge a ... $last) $last)) (b))
!(test (collapse (match &self (, (edge ... $mid) (tag $mid $heat)) ($mid $heat)))
       ((b hot)))
