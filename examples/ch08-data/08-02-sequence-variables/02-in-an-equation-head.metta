; A gap in an EQUATION HEAD, which is the second place a program can write one.
;
; A head is the pattern side of a one-sided match, so everything 01 showed
; about `...` and `(:seg $x)` holds here, and one thing more: the gap decides
; the ARITY, so a head that carries one is a function of variable arity.

;;; The whole argument list as one run: a variadic function, with no list
;;; building and no fold.
(= (allof (:seg $xs)) (kept $xs))
!(test (allof) (kept ()))
!(test (allof a) (kept (a)))
!(test (allof a b c) (kept (a b c)))

;;; A gap between fixed children destructures instead. The run is the
;;; expression those children make, so it is an ordinary value the body reads.
(= (middle (row start (:seg $mid) end)) $mid)
!(test (middle (row start a b end)) (a b))
!(test (middle (row start end)) ())

;;; TWO gaps in one head make the CALL nondeterministic: matching enumerates
;;; the splits and the function answers once per split, shortest prefix first.
(= (split (row (:seg $before) SEP (:seg $after))) (pair $before $after))
!(test (collapse (split (row a SEP b SEP c)))
       ((pair (a) (b SEP c)) (pair (a SEP b) (c))))

;;; The body reads the run in whichever of two ways it writes. An ordinary
;;; `$xs` keeps the run as ONE expression; a written `(:seg $xs)` SPLICES it
;;; into the expression around it.
(= (project (head (:seg $xs) tail)) (rebuilt before $xs after))
(= (splice (head (:seg $xs) tail)) (rebuilt before (:seg $xs) after))
!(test (project (head a b tail)) (rebuilt before (a b) after))
!(test (splice (head a b tail)) (rebuilt before a b after))

;;; ONE NAME IN BOTH ROLES is admitted here and refused everywhere else. A
;;; head is always one-sided, so the run is finite and known before the
;;; ordinary occurrence is compared; the ordinary occurrence then stands for
;;; the expression that run makes. 05-the-fence.metta is the general rule.
(= (echoes ((:seg $xs) tag $xs)) yes)
!(test (echoes (a b tag (a b))) yes)
!(test (echoes (tag ())) yes)
!(test (collapse (echoes (a b tag (a c)))) ())

;;; A gap head and an ordinary head are ADDITIVE, like any two equations that
;;; overlap: both answer, in source order.
(= (kind (row ...)) row-shaped)
(= (kind $other) anything)
!(test (collapse (kind (row a b))) (row-shaped anything))
!(test (collapse (kind 7)) (anything))
