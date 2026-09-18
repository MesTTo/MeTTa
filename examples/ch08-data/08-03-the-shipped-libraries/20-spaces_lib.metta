; Purpose: every lib_spaces operation over whole spaces: counting, finding,
; copying, moving, draining, snapshotting, subtracting and clearing.
; [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/20-spaces_lib.metta; commit=a8b4bab6eb0bf1b42eb441e9145144cf91befa7d].
; Each bulk operation answers once per atom it touched, so the count of
; answers is the count of work it did.
!(import! &self (library lib_spaces))

!(add-atom &ledger (entry rent 1200))
!(add-atom &ledger (entry food 300))
!(add-atom &ledger (note "checked"))

; `match-count` folds over a match that answers 1 per solution, so nothing is
; materialised: a pattern nothing matches counts 0 rather than answering nothing.
!(test (match-count &ledger (entry $what $amount)) 2)
!(test (match-count &ledger (invoice $n)) 0)

; `find` is a match reduced to True or False, and `succeedsPredicate` asks the
; same of a Prolog-shaped call.
!(test (find &ledger (entry rent $amount)) True)
!(test (find &ledger (entry car $amount)) False)
!(test (succeedsPredicate (&ledger entry rent $amount)) True)

; `space-copy` leaves the source alone. A bare variable pattern copies
; everything, which is what merging one space into another is.
!(test (sort-atom (collapse (space-copy &ledger &audit (entry $what $amount)))) (true true))
!(test (match-count &audit (entry $what $amount)) 2)
!(test (match-count &ledger (entry $what $amount)) 2)
!(test (sort-atom (collapse (space-copy &ledger &everything $any))) (true true true))
!(test (space-atom-count &everything) 3)

; `space-snapshot` mints the destination itself, so what a space holds now
; survives later writes to it.
!(bind! &before (space-snapshot &ledger))
!(test (space-atom-count &before) 3)
!(add-atom &ledger (entry travel 90))
!(test (space-atom-count &before) 3)
!(test (space-atom-count &ledger) 4)

; `move-atoms` is what migrateAtoms' NAME promises: the atoms arrive in the
; destination and leave the source.
!(test (collapse (move-atoms &ledger &archive (entry travel $amount))) (true))
!(test (collapse (match &archive (entry $what $amount) ($what $amount))) ((travel 90)))
!(test (match-count &ledger (entry travel $amount)) 0)

; `migrateAtoms` keeps upstream's own equation, which names the source on both
; sides: it is a filtered drain, and the destination is not written. That is
; the arbiter's text, so the behaviour rather than the name is what a program
; relies on; `move-atoms` above is the one that moves.
!(test (collapse (migrateAtoms &ledger &nowhere (entry food $amount))) ((true true)))
!(test (collapse (get-atoms &nowhere)) ())
!(test (match-count &ledger (entry food $amount)) 0)

; `space-drain` answers the atoms it removed, so a caller sees what left.
!(test (collapse (space-drain &ledger (note $text))) ((note "checked")))
!(test (collapse (get-atoms &ledger)) ((entry rent 1200)))

; `space-subtract` removes every atom another space holds. An atom the space
; does not hold answers the removal's ordinary verdict.
!(test (sort-atom (collapse (space-subtract &everything &audit))) (true true))
!(test (collapse (get-atoms &everything)) ((note "checked")))
!(test (collapse (space-subtract &everything &audit)) (true true))

; `remove-all-atoms` clears a space. Its own body is a collapse over every
; atom's removal, so one call answers one expression of verdicts and a second
; call over the emptied space answers the empty one.
!(test (collapse (remove-all-atoms &everything)) ((true)))
!(test (collapse (get-atoms &everything)) ())
!(test (collapse (remove-all-atoms &everything)) (()))
