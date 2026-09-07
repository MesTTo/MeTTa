; THE FENCE. General sequence unification is INFINITARY: `(f (:seg $x) a)`
; against `(f a (:seg $x))` is solved by `$x = a`, by `$x = (a a)`, and so on
; without end, so no complete finite answer set exists (Kutsia, Journal of
; Symbolic Computation 42(3), 2007, Theorem 62). An ask outside the three
; fragments 03 and 04 name therefore REFUSES rather than searching, and the
; refusal names the rule it refused under.
;
; This is what it says, in full:
;
;   gap unification of (Order (:seg $m) $m) against any atom is outside the
;   proved finitary fragment (mixed_roles, mixed-roles: ($m)). General
;   sequence unification is INFINITARY (Kutsia, Journal of Symbolic
;   Computation 42(3), 2007, Theorem 62), so the engine refuses rather than
;   searching forever. Three fragments are proved finite and are the ones it
;   decides: one side with no gap at all; every gap linear and a direct child
;   of the root (Kutsia Section 6.2); every gap the last child of its own
;   expression (Kutsia Section 6.3). One name may not be both a gap and an
;   ordinary variable. The classifier is metta_seq_classify/3 in
;   engine/spaces/segment_matching.pl
;
; "against any atom" is what a space match prints for its other side, because
; a pattern is classified before any candidate has been read.

!(add-atom &self (Order 7 x y))

;;; THE RULE THAT FIRES: one name may not be both a gap and an ordinary
;;; variable. `(Order (:seg $m) $m)` asks for a run and for one term under the
;;; same name, and outside an equation head that mix has no finite reading.
!(test (if-error (catch (match &self (Order (:seg $m) $m) hit)) refused answered)
       refused)

;;; A caught refusal is DATA, and its payload is an expression a program can
;;; read: the rule it broke, the two sides, and the names caught in both roles.
!(test (let $refusal (catch (match &self (Order (:seg $m) $m) hit))
            (car-atom (index-atom $refusal 1)))
       metta_seq_outside_fragment)
!(test (let $refusal (catch (match &self (Order (:seg $m) $m) hit))
            (index-atom (index-atom $refusal 1) 4))
       mixed_roles)
!(test (let $refusal (catch (match &self (Order (:seg $m) $m) hit))
            (index-atom (index-atom $refusal 1) 1))
       (Order (:seg $m) $m))
!(test (let $refusal (catch (match &self (Order (:seg $m) $m) hit))
            (index-atom (index-atom $refusal 1) 3))
       ($m))

;;; THE REFUSAL IS CARRIED, NOT RAISED WHILE THE FILE LOADS. It travels with
;;; the compiled pattern and throws at the ask, so an arm nothing reaches
;;; cannot stop a program from running.
!(test (case (Order 8)
             (((Order 8) plain)
              ((Order (:seg $m) $m) never)
              ($_ other)))
       plain)

;;; The remedy is to rewrite the pattern: ask for the run and for the term
;;; under DIFFERENT names, and compare them where comparison belongs.
!(test (collapse (match &self (Order (:seg $run) $last) (pair $run $last)))
       ((pair (7 x) y)))
!(test (collapse (let (Order (:seg $run) $last) (Order (x y) (x y))
                      (if (== $run ($last)) same different)))
       (same))

;;; An EQUATION HEAD is the one place the mix is admitted, because a head is
;;; always the pattern side of a one-sided match: 02-in-an-equation-head.metta.
(= (echoes ((:seg $xs) tag $xs)) yes)
!(test (echoes (a b tag (a b))) yes)

;;; Limitation, measured 2026-09-07: the classifier has a second refusal,
;;; `no_certificate`, for a pair whose gaps are neither all final nor all
;;; shallow, and no MeTTa program can reach it. It needs gaps on BOTH sides,
;;; and 04 measures why a written ask never has them. The shape below is the
;;; one the plunit suite refuses when it hands the classifier two parsed
;;; sides; written here it is an ordinary one-sided match that finds nothing.
!(test (collapse (unify (f (g (:seg $u) b)) (f (g a (:seg $v))) yes no)) (no))
