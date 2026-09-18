; Purpose: a tagged rule with a side condition over its premise tags, the
;   rule form of a labelled deductive system, and the engine's witnesses for
;   a tabled answer.
; Guarantees: (where G) keeps only the instances G admits, on the derived
;   route and on the engine's fixpoint alike, and (product prob polynomial)
;   pairs each answer with every derivation the guard admitted.
; [tested: examples/ch22-a-reasoner-you-can-serve/22-01-logic-programs/08-guarded_rules.metta; commit=49478d67a10793a114d27d01a51f09a685d5136a]

;Two scored facts and a threshold written as an ordinary function.
(fact 0.6 (score a))
(fact 0.3 (score b))
(= (above-half $s) (> $s 0.5))

;A rule's fifth element, (where G), is its side condition: G applied to the
;premise tags in order must answer True for the instance to exist. Gabbay's
;labelled deductive systems give a rule exactly this shape, labelled
;premises, a label function and a condition on the labels.
(rule 1 (trusted $x) (premises (score $x)) (where above-half))

;Only a clears the bar; b's 0.3 leaves no instance at all, so it is not a
;low-weighted answer but no answer.
!(test (match-under &self prob (trusted $x)) ((trusted a) 0.6))
!(test (let $rows (collapse (match-under &self prob (trusted $x))) (size-atom $rows)) 1)

;On the fixpoint route a premise's tag is its table's value, the join of
;every derivation so far, so a guard reads an aggregate. Under bool the
;strongest score is what the threshold sees; under prob on acyclic data the
;same.
!(test (match-under &self bool (trusted a)) ((trusted a) 0.6))

;A guard reads the labels of the carrier the program is asked in, so the
;polynomial carrier, the free semiring whose labels are polynomials over
;the facts and rule instances, cannot answer a threshold written for
;probabilities on its own. A carrier may be a product, (product Left Right),
;whose tags are pairs: the left carrier reads the guards and the right
;follows the derivations it admits. (trusted a) has one derivation, one
;monomial through the fact and the rule instance, each a variable named
;by its key and carrying its written tag: 0.6 and 1.
!(test (let ((trusted a) (pair $p (poly (1 (var $k1 $w1) (var $k2 $w2)))))
            (match-under &self (product prob polynomial) (trusted a))
       (+ $w1 $w2)) 1.6)
