;lib_spaces' two remaining operations over a whole space: `match-count`,
;which counts matches without building the list of them, and `migrateAtoms`,
;which moves matching atoms out of a space.
!(import! &self (library lib_spaces))

!(add-atom &ledger (n 1))
!(add-atom &ledger (n 2))
!(add-atom &ledger (m 9))

;`match-count` folds + over a match that answers 1 per solution, so the
;answer set is never materialised: counting ten thousand matches costs no
;list. A pattern nothing matches counts 0 rather than answering nothing.
!(test (match-count &ledger (n $x)) 2)
!(test (match-count &ledger (m $x)) 1)
!(test (match-count &ledger (zzz $x)) 0)
!(assertEqual (match-count &ledger ($head $tail)) (space-atom-count &ledger))

;`migrateAtoms` answers one pair per matched atom, the answers of the two
;writes it performs, so the count of answers is the count of atoms it moved.
!(test (collapse (migrateAtoms &ledger &archive (n $x)))
       ((true true) (true true)))

;The matched atoms leave the source, and everything else stays.
!(test (collapse (get-atoms &ledger)) ((m 9)))
!(test (match-count &ledger (n $x)) 0)

;THE DESTINATION IS NOT WRITTEN. The shipped equation names the SOURCE on
;both sides,
;
;    (= (migrateAtoms $FromSpace $ToSpace $Pattern)
;       (match $FromSpace $Pattern ((add-atom $FromSpace $Pattern)
;                                   (remove-atom $FromSpace $Pattern))))
;
;so `$ToSpace` is accepted and never read, and what the operation does is add
;the atom back to the source and then remove every copy of it. That is the
;arbiter's own text, byte for byte, so this engine answers what upstream
;answers; the name promises more than the equation delivers, and the
;behaviour rather than the name is what a program can rely on.
!(test (collapse (get-atoms &archive)) ())

;Which makes it a filtered drain today: everything matching the pattern goes,
;and a second run over the same pattern moves nothing because nothing is
;left.
!(test (collapse (migrateAtoms &ledger &archive (n $x))) ())
!(test (collapse (get-atoms &ledger)) ((m 9)))
