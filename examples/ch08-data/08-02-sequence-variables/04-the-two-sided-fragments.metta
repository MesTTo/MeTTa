; The other two proved-finite fragments, and the one door that reaches them.
;
; General sequence unification is INFINITARY (Kutsia, Journal of Symbolic
; Computation 42(3), 2007, Theorem 62), so an engine that decides gaps has to
; say which restriction of the theory it decides. This one decides three, and
; `metta_seq_classify/3` in engine/spaces/segment_matching.pl names them:
;
;   one_sided       one side carries no gap at all, which is 03.
;   last_position   every gap is the LAST child of its own expression, on both
;                   sides (Kutsia Section 6.3). Deterministic and unitary: one
;                   answer or none.
;   linear_shallow  every gap is a direct child of the ROOT, no nested
;                   expression carries one, and each named gap occurs once
;                   across the pair (Kutsia Section 6.2).
;
; The last two are the TWO-SIDED fragments: a gap on ONE side is a pattern to
; match, and it takes two of them to have anything to solve. So they need a
; door that hands the matcher two pieces of SYNTAX, and `unify` is that door
; and the only one. Its four arguments are typed Atom and cross unevaluated,
; while `match` faces stored atoms and `let`, `case` and an equation head face
; a value, and a value's marker-shaped children are data rather than gaps.
; Every ask in 01, 02 and 03 is therefore one-sided by construction; the asks
; here are not.
;
; Which shape reaches which solver is the classifier's own order, tried once
; while the ask compiles: a side with no gap at all first; then last position,
; which is deterministic and therefore the more specific answer; then linear
; shallow. Outside all three the ask refuses, naming the certificate it has
; none of, and 05-the-fence.metta reads that refusal apart.

;;; ONE SIDE WITH NO GAP is still the one-sided fragment, whichever side it is.
;;; A gap written on the right alone consumes the left's children the same way
;;; a gap on the left consumes the right's.
!(test (unify (f a b) (f a (:seg $v)) $v none) (b))

;;; LAST POSITION. Every gap is the last child of its own expression, so
;;; nothing is ever split: the two child lists are walked pointwise and a
;;; trailing gap takes the whole remainder of the other side. Here the right
;;; side is longer by exactly its gap, so the run is EMPTY.
!(test (unify (f a b) (f a b (:seg $v)) $v none) ())

;;; A remainder that still holds the OTHER side's gap keeps it, as the marker
;;; that would match it: an open run is an answer, not a refusal.
!(test (unify (f a (:seg $u)) (f a b (:seg $v)) $u none) (b (:seg $v)))
!(test (unify (f (:seg $u)) (f (:seg $v)) $u none) ((:seg $v)))

;;; An anonymous gap is a name like any other here, and it absorbs the other
;;; side's gap as one child of its run.
!(test (unify (f ...) (f (:seg $v)) taken none) taken)

;;; Linearity is NOT required in this fragment: Kutsia Section 6.3 asks only
;;; that every gap be last in its own expression. So a NAME may occur twice,
;;; and its second occurrence solves the run its first took against what that
;;; occurrence faces rather than demanding the two were written alike.
!(test (unify (f (g (:seg $x)) (h (:seg $x))) (f (g (:seg $y)) (h b)) $x none)
       (b))

;;; And the calculus keeps `X = X` as trivial rather than as a clash, so a name
;;; written as a gap on BOTH sides plays one role and the pair holds. Upstream
;;; PeTTa, which has no reading of a gap at all, unifies the two identical
;;; expressions and answers the same.
!(test (unify (f (:seg $u)) (f (:seg $u)) yes no) yes)

;;; The fragment is unitary: one answer or none, never a stream of them.
!(test (collapse (unify (f a b) (f a b (:seg $v)) $v none)) (()))

;;; LINEAR SHALLOW. Every gap is a direct child of the root and each named gap
;;; occurs once across the pair, so the two child lists are a linear word
;;; equation: project a gap to the empty run, or widen it by one item and carry
;;; a fresh remainder in its slot (Kutsia Section 6.2). Projection is tried
;;; first, which keeps the shortest-first order 03 already has.
!(test (unify (f (:seg $u) b) (f a (:seg $v)) ($u $v) no) ((a) (b)))

;;; What a gap absorbs is whole CHILDREN, expressions included, so two gaps
;;; can trade the settled children written between them.
!(test (unify (f (:seg $u) (g a)) (f (g b) (:seg $v)) ($u $v) no)
       (((g b)) ((g a))))

;;; Each of those answers once too, because each gap here is pinned by the
;;; other side's settled children.
!(test (collapse (unify (f (:seg $u) b) (f a (:seg $v)) ($u $v) no))
       (((a) (b))))

;;; A SPACE operand makes the ask a query, which is one-sided again: the stored
;;; side is data. Both doors then answer the same rows for the same pattern.
!(add-atom &self (friend Bob Alice))
!(add-atom &self (friend Carol Alice))
!(test (collapse (unify &self (friend (:seg $who)) $who none))
       ((Bob Alice) (Carol Alice)))
!(test (collapse (match &self (friend (:seg $who)) $who))
       ((Bob Alice) (Carol Alice)))

;;; OUTSIDE ALL THREE the ask refuses. Kutsia's own witness is a pair of root
;;; gaps sharing one name across a settled child, which is neither all-final
;;; nor linear, so it has no certificate: 05-the-fence.metta reads the refusal.
!(test (if-error (catch (unify (f (:seg $x) a) (f a (:seg $x)) yes no))
                 refused answered)
       refused)
