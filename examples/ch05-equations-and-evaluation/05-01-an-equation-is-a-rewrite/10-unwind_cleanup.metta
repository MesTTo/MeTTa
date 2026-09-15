;; Purpose: expose native cleanup as an editable handler equation.
;; Guarantees: deterministic success skips cleanup; failure and caller cut
;;   apply it once to their native outcome [tested:
;;   sh test.sh examples/ch05-equations-and-evaluation/05-01-an-equation-is-a-rewrite/10-unwind_cleanup.metta;
;;   commit=2d09b82e3ea1565d10fd8206e3b3cc9808ce6cb1].

(= (unwind-note $home $outcome) (add-atom $home (unwound $outcome)))

!(test (on-unwind 7 (unwind-note &self)) 7)
!(test (collapse (match &self (unwound $outcome) $outcome)) ())

!(test (collapse (on-unwind (superpose ()) (unwind-note &self))) ())
!(test (collapse (match &self (unwound $outcome) $outcome)) ((fail)))
!(remove-atom &self (unwound (fail)))

!(test (once (on-unwind (superpose (1 2)) (unwind-note &self))) 1)
!(test (collapse (match &self (unwound $outcome) $outcome)) ((!)))
