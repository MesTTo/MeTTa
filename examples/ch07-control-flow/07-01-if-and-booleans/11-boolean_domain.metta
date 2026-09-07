;`and`, `or` and `xor` are RELATIONS over the two booleans, not functions over
;anything. Inside the domain they decide; outside it they have no answer at
;all, so the whole call answers nothing rather than standing or refusing.
!(test (collapse (and a a)) ())
!(test (collapse (and True a)) ())
!(test (collapse (and (== 1 1) a)) ())
!(test (collapse (or a b)) ())
!(test (collapse (or True a)) ())
!(test (collapse (xor a b)) ())

;A number is outside it too, and outside it the same way: the call has no
;answer rather than a typed refusal, because a relation with no matching row
;is not a function given the wrong argument.
!(test (collapse (and True 5)) ())
!(test (collapse (or False 5)) ())
!(test (collapse (xor True 5)) ())

;Which is what a caller sees: a condition with no answer leaves the `if` with
;nothing to branch on, and the whole form answers nothing rather than taking
;the false branch.
!(test (collapse (if (and a a) yes no)) ())

;Being a relation is the other half of the same rule, and it is what an
;unbound operand reads: the operation enumerates its own truth table.
!(test (collapse (and $a $b)) (True False False False))
!(test (collapse (or $a $b)) (True True True False))
!(test (collapse (xor $a $b)) (False True True False))
