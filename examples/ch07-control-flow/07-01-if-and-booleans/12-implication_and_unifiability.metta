; Purpose: distinguish Boolean implication, unifiability and exact equality.
; Guarantees: if-equal2 follows upstream ==, preserving variable identity
;   [tested: examples/ch07-control-flow/07-01-if-and-booleans/12-implication_and_unifiability.metta;
;   commit=WORKTREE].
;Three engine forms that answer a question about two things rather than
;computing a value from them: `implies`, `=?` and `if-equal2`.
;
;`implies` is material implication over the Bools, the connective `and`, `or`
;and `not` leave out. False implies anything, and only a true antecedent with
;a false consequent is False.
!(test (implies False False) True)
!(test (implies False True) True)
!(test (implies True True) True)
!(test (implies True False) False)

;Which makes it the guard shape "if this holds then that must too", written
;once instead of as (or (not $p) $q).
(= (adult? $p) (> (age $p) 17))
(= (age ann) 30)
(= (age bo) 12)
(= (may-vote? $p) (implies (registered? $p) (adult? $p)))
(= (registered? ann) True)
(= (registered? bo) True)
!(test (may-vote? ann) True)
!(test (may-vote? bo) False)

;`=?` asks whether two atoms COULD be made equal, and answers without making
;them so: a variable on either side unifies with anything, and neither side
;is bound afterwards. This is the question a matcher asks before committing.
!(test (=? (f $x) (f 1)) True)
!(test (=? (f 2) (f 1)) False)
!(test (=? $a $b) True)
!(test (=? (f $x) (g $x)) False)

;Nothing is bound: $x is still free after the test, so the same variable
;answers True against two atoms that cannot both be true of it.
!(test (and (=? (f $x) (f 1)) (=? (f $x) (f 2))) True)

;`if-equal2` is `if-equal` under its second historical name, and it is
;upstream's == comparison preserves variable identity. Distinct variables
;select the fourth branch even when their expressions are alpha-equivalent.
!(test (if-equal2 (f $x) (f $x) same different) same)
!(test (if-equal2 (f $x) (f $y) renamed different) different)
!(test (if-equal2 (f $x) (f 1) renamed different) different)
!(test (if-equal2 (f $x $x) (f $y $z) renamed different) different)

;The pair (f $x) and (f 1) is unifiable but fails exact equality.
!(test (=? (f $x) (f 1)) True)
!(test (if-equal2 (f $x) (f 1) renamed different) different)
