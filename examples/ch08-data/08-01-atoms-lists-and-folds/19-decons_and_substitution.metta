;Taking an expression apart in one step, and putting a value into a named
;hole.
;
;`decons-atom` answers the head and the tail together, as a two-element
;expression, so one call does what `car-atom` and `cdr-atom` do in two and
;the pair destructures straight into a `let`.
!(test (decons-atom (a b c)) (a (b c)))
!(test (decons-atom (a)) (a ()))
!(test (let ($head $tail) (decons-atom (1 2 3)) (+ $head (car-atom $tail))) 3)

;`decons` is the same operation under its un-suffixed name, the spelling the
;reference corelib ships beside `cons`, and `cons` puts back what it took
;apart.
!(test (decons (a b c)) (a (b c)))
!(test (== (decons (a b c)) (decons-atom (a b c))) True)
!(test (let ($head $tail) (decons (a b c)) (cons $head $tail)) (a b c))

;The head comes back AS WRITTEN. Taking a list apart is not evaluating it,
;so a call sitting in head position stays a call.
!(test (decons ((f 1) b)) ((f 1) (b)))

;`atom-subst` puts a value where a named variable stands: value first, the
;variable second, the term third. Every occurrence goes, which is what makes
;it substitution rather than a single rewrite.
!(test (atom-subst 1 $x (foo $x $x)) (foo 1 1))
!(test (atom-subst (g 2) $x (foo $x (bar $x))) (foo (g 2) (bar (g 2))))

;Only the variable named is touched; the others stay free.
!(test (=alpha (atom-subst 1 $y (foo $x $y)) (foo $a 1)) True)

;The second operand is a BINDER position: it is held as written, so a call
;that would reduce to a variable is refused as the non-binder it is rather
;than being quietly evaluated into one.
!(test (atom-subst 1 (car-atom ($x)) (foo $x))
       (Error (atom-subst 1 (car-atom ($x)) (foo $x)) NoReturn))

;A term with nothing to substitute comes back unchanged, so the operation is
;total over ground data.
!(test (atom-subst 1 $x (foo bar)) (foo bar))
