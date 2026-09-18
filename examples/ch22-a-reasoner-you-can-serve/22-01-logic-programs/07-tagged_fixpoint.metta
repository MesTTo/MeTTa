; Purpose: a tagged program evaluated to its fixpoint by the engine, under
;   several carriers, over a graph with a cycle.
; Guarantees: bool and tropical converge on the two-cycle, formula then prob
;   reads the exact probability where a sum over proofs would count a shared
;   path twice, and counting counts the derivations of an acyclic program.
; [tested: examples/ch22-a-reasoner-you-can-serve/22-01-logic-programs/07-tagged_fixpoint.metta; commit=12609a929638e7a2b08d3ff8f517abc1a399e7a9]

;A tagged program is ordinary atoms: (fact tag proposition) and
;(rule tag head (premises ...)). This graph has a cycle, a -> b -> a, and two
;ways from a to c: the direct edge and the way through b.
(fact 0.6 (edge a b))
(fact 0.5 (edge b a))
(fact 0.2 (edge a c))
(fact 0.3 (edge b c))
(rule 1 (path $x $y) (premises (edge $x $y)))
(rule 1 (path $x $z) (premises (edge $x $y) (path $y $z)))

;(match-under &space carrier pattern) is the fixpoint under a carrier: one
;answer (proposition tag) per derived proposition matching the pattern. Under
;bool the tag is the strongest path, max of products, and the cycle adds
;nothing: the direct 0.2 beats 0.6 * 0.3.
!(test (match-under &self bool (path a c)) ((path a c) 0.2))

;tropical is min of sums, the cheapest path, each rule adding its own tag 1.
!(test (match-under &self tropical (path a c)) ((path a c) 1.2))

;Every pair the cycle reaches, once each, whatever the carrier.
!(test (let $rows (collapse (match-under &self set (path a $y))) (size-atom $rows)) 3)

;The exact probability is the formula carrier read back under prob: a
;decision diagram over the facts, so the shared edges are counted once and
;the cycle contributes nothing, 1 - (1 - 0.2)(1 - 0.6 * 0.3) = 0.344.
!(test (let ($p $t) (match-under &self (formula prob) (path a c))
         (< (abs-math (- $t 0.344)) 0.000001))
       True)

;On an acyclic graph every carrier is exact. counting reads every source as
;one, so it counts derivations; prob sums their products, 0.2 + 0.6 * 0.5.
!(bind! &dag (new-space))
!(add-atom &dag (fact 0.6 (edge a b)))
!(add-atom &dag (fact 0.5 (edge b c)))
!(add-atom &dag (fact 0.2 (edge a c)))
!(add-atom &dag (rule 1 (path $x $y) (premises (edge $x $y))))
!(add-atom &dag (rule 1 (path $x $z) (premises (edge $x $y) (path $y $z))))
!(test (match-under &dag counting (path a c)) ((path a c) 2))
!(test (match-under &dag prob (path a c)) ((path a c) 0.5))
