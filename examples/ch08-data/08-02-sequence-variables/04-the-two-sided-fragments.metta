; The other two proved-finite fragments, and how far a MeTTa program reaches
; into them.
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
; The last two need BOTH sides to carry gaps, and only one form in the
; language hands the matcher two operands that are both syntax: `unify`, whose
; arguments are typed Atom and cross unevaluated. What `unify` actually does
; with a gap on its right is measured below.

;;; A MARKER ON THE RIGHT OF unify IS DATA. The left operand is the pattern;
;;; the right operand is read the way stored atoms are read, so `(:seg $v)`
;;; there is an ordinary two-child expression and a gap on the left consumes
;;; it as one child.
!(test (unify (f ...) (f (:seg $v)) taken none) taken)
!(test (unify (f (:seg $u)) (f (:seg $v)) $u none) ((:seg $v)))

;;; So a gap written on the right ALONE is matched literally, and an ordinary
;;; child does not match it.
!(test (unify (f a b) (f a (:seg $v)) $v none) none)

;;; Limitation, measured 2026-09-07: those two answers are the whole story.
;;; `metta_seq_plan/3` parses the LEFT operand only, so the classifier sees no
;;; gap on the right and answers `one_sided(left)` for every ask a program can
;;; write. The four shapes below are the ones the last-position and
;;; linear-shallow calculi are for, and each answers here as a one-sided match
;;; that fails. The solvers themselves decide them, and
;;; tests/prolog/suites/reader/segments.plt calls them directly to prove it;
;;; nothing in the language reaches them.
;;;
;;; last-position shapes: a trailing gap facing a longer side, and a repeated
;;; name in trailing position on both sides. Given two parsed sides the
;;; calculus answers `()` for the first, the empty run, and `(b)` for the
;;; second
;;; [tested: tests/prolog/suites/reader/segments.plt:a_trailing_gap_takes_the_empty_run,
;;; tests/prolog/suites/reader/segments.plt:a_repeated_gap_solves_its_stored_run_against_the_second_face;
;;; commit=a403e56b4f33828834823338eb1fc316e3fea2a4].
!(test (unify (f a b) (f a b (:seg $v)) $v none) none)
!(test (unify (f (g (:seg $x)) (h (:seg $x))) (f (g (:seg $y)) (h b)) $x none)
       none)
;;; linear-shallow shapes: two root gaps that would absorb each other's fixed
;;; children. Given two parsed sides the calculus answers `((a) (b))` for the
;;; first and `(((g b)) ((g a)))` for the second
;;; [tested: tests/prolog/suites/reader/segments.plt:two_root_gaps_solve_to_their_runs,
;;; tests/prolog/suites/reader/segments.plt:gaps_absorb_each_others_settled_children;
;;; commit=a403e56b4f33828834823338eb1fc316e3fea2a4].
!(test (unify (f (:seg $u) b) (f a (:seg $v)) ($u $v) no) no)
!(test (unify (f (:seg $u) (g a)) (f (g b) (:seg $v)) ($u $v) no) no)

;;; And the same cause turns the calculus's own trivial identity into a
;;; refusal. `(f (:seg $u))` against itself has no mixed role at all, and given
;;; two parsed sides the calculus answers `yes`, keeping `X = X` as trivial
;;; [tested: tests/prolog/suites/reader/segments.plt:the_trivial_identity_holds;
;;; commit=a403e56b4f33828834823338eb1fc316e3fea2a4]. The unparsed right side
;;; puts `$u` in the classifier's ORDINARY list instead, so the mixed-role rule
;;; fires. 05-the-fence.metta is the rule this misreads.
!(test (let $refusal (catch (unify (f (:seg $u)) (f (:seg $u)) yes no))
            (index-atom (index-atom $refusal 1) 4))
       mixed_roles)
