;`nop` takes any number of arguments, evaluates every one of them, and
;answers the unit `()`. It is the sequencing form for a step whose answer you
;do not want: `progn` above keeps the last answer and `prog1` keeps the
;first, and this one keeps none.
!(test (nop) ())
!(test (nop 1) ())
!(test (nop 1 2 3) ())

;What it discards is the ANSWERS, not the work. The arguments evaluate, so a
;write inside one still lands.
!(test (nop (add-atom &log (seen 1)) (add-atom &log (seen 2))) ())
!(test (collapse (match &log (seen $n) $n)) (1 2))

;Which is the difference from `empty`: `empty` answers nothing at all and a
;collapse around it is the empty tuple, while `nop` answers exactly one thing
;and that thing is the unit.
!(test (collapse (nop 1)) (()))
!(test (collapse (empty)) ())

;It is not a collapse. An argument with three answers is three calls of
;`nop`, so three units come back and all three writes land; a form that
;wanted one answer would have to say `collapse` itself.
!(test (collapse (nop (let $x (superpose (1 2 3)) (add-atom &drained (x $x)))))
       (() () ()))
!(test (space-atom-count &drained) 3)

;The unit is the same value every runnable that exists for its effect
;answers, which is why a `nop` composes with them without a special case.
!(test (== (nop 1) (add-atom &log (seen 3))) False)
!(test (== (nop 1) (nop 2)) True)
