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
;alpha-equivalence rather than unifiability: two atoms equal up to a
;consistent renaming of their variables take the third branch.
!(test (if-equal2 (f $x) (f $y) renamed different) renamed)
!(test (if-equal2 (f $x) (f 1) renamed different) different)
!(test (if-equal2 (f $x $x) (f $y $z) renamed different) different)

;So the two are genuinely different questions, and this is the pair that
;separates them: (f $x) and (f 1) unify, and are not alpha-equivalent.
!(test (=? (f $x) (f 1)) True)
!(test (if-equal2 (f $x) (f 1) renamed different) different)
