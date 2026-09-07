;What a space can be told to store, and which door tells it.
;
;Upstream PeTTa keeps an atom as a fact keyed on its HEAD, so an atom with no
;head -- a bare symbol, a number, a string, or the empty expression -- cannot
;become one there and `add-atom` has no answer at all for it. `add-atom` and
;`remove-atom` are upstream's spellings, so they answer here what they answer
;there.

(keep 1)

;An expression has a head. It is stored, and the write answers True.
!(test (collapse (add-atom &self (fact 2))) (True))
!(test (collapse (match &self (fact $n) $n)) (2))

;A headless atom is outside that door: no answer, and nothing written.
!(test (collapse (add-atom &self b)) ())
!(test (collapse (add-atom &self ())) ())
!(test (collapse (add-atom &self 1)) ())
!(test (collapse (match &self b found)) ())

;Removal has the same domain, for the same reason: it names the fact by the
;same head.
!(test (collapse (remove-atom &self b)) ())
!(test (collapse (remove-atom &self ())) ())
!(test (collapse (remove-atom &self (fact 2))) (True))
!(test (collapse (match &self (fact $n) $n)) ())

;An atom that arrives through a variable is decided when it arrives, not when
;the call compiles, so the same rule holds for a computed atom.
(= (store $atom) (add-atom &self $atom))
!(test (collapse (store (fact 3))) (True))
!(test (collapse (store b)) ())

;This engine's space is wider than upstream's, and the wider door is a
;spelling upstream does not define. `add-atoms` writes any atom, one per
;member, and what it wrote is matchable and removable like anything else.
!(test (add-atoms &self (b 1 ())) True)
!(test (collapse (match &self b found)) (found))
!(test (collapse (match &self 1 found)) (found))
!(test (subtract-atom &self b) True)
!(test (collapse (match &self b found)) ())
