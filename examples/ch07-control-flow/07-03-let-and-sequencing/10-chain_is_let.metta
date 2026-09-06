;`chain` and `let` are the same instruction. Upstream compiles both with one
;clause, so the binder takes the value the operand produced, once, and the
;template is an ordinary expression around it.
!(test (chain (+ 2 4) $n (* 3 $n))
       (let $n (+ 2 4) (* 3 $n)))

;The bound VALUE is a value, not another thing to evaluate. `quote` hands back
;an atom that would reduce if anything asked it to, and neither door asks:
;`(= a b)` stays the atom instead of becoming the equality test's False.
!(test (chain (quote (= a b)) $v $v) (quote (= a b)))
!(test (let $v (quote (= a b)) $v) (quote (= a b)))
!(test (chain (quote (+ 1 2)) $v $v) (quote (+ 1 2)))

;Which is what makes a space readable. An equation is an atom like any other,
;so reading one out and binding it gives the atom back; evaluating it a second
;time would ask whether its two sides are equal instead.
(= (f0 a) (* a))
!(test (chain (get-atoms &self) $v $v) (quote (= (f0 a) (* a))))
!(test (collapse (chain (get-atoms &self) $v $v))
       (collapse (let $v (get-atoms &self) $v)))

;The template is still evaluated, and an operand held back inside it is still
;reduced by the call that held it: `car-atom` hands out `(+ 1 2)` unreduced
;and the result position is what turns it into 3.
!(test (chain 1 $x (car-atom ((+ 1 2) b))) 3)
!(test (chain (+ 1 2) $x (cons-atom $x (b))) (3 b))

;A binder used twice does not duplicate a nondeterministic operand, because
;the operand ran once and its value is what the binder holds.
!(test (collapse (chain (superpose (1 2)) $x ($x $x)))
       ((1 1) (2 2)))
