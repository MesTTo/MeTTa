;; A vocabulary row and the rows that USE its values are two halves of one
;; statement, and they have to agree. The previous file showed the SHAPE of
;; a (claim ...) row; this one is about the set those claims are drawn from,
;; and about what goes wrong when the two halves drift.

;; Ten algebras ship and the semiring vocabulary is exactly their names.
;; This row is the authority rather than a copy of one:
;; extensions/python/metta/vocabularies.py is GENERATED from it, so
;; `Semiring.budget` exists in a Python annotation because this row says
;; budget does.
!(test (match &metta (vocabulary semiring $a $b $c $d $e $f $g $h $i $j)
                     ($a $b $c $d $e $f $g $h $i $j))
       (bool bag counting set ranked tropical prob prov budget amplitude))

;; Each of those names also has an (algebra ...) row saying what it
;; computes. budget is a cost carrier: it combines with min, extends with
;; +, and starts from infinity, so an unreachable path costs infinity and
;; every real one improves on it. The last field is the row's OWNER: a
;; shipped preset says global, a declared one names the space that declared
;; it, and the lookup reads its own context first and global second.
!(test (match &metta (algebra budget $combine $extend $zero $one
                              $laws $carrier $requires $owner)
                     ($zero $owner))
       (infinity global))

;; Orderedness is a separate claim, because combining with min does not by
;; itself say which end a (top k ...) slice should take. budget reads
;; ASCENDING, cheapest first, the same direction tropical reads.
!(test (match &metta (claim semiring budget $property $direction)
                     ($property $direction))
       (ordered ascending))
!(test (match &metta (claim semiring tropical $property $direction)
                     ($property $direction))
       (ordered ascending))

;; The invariant is that those halves agree in BOTH directions. A carrier
;; defined but not named could be used and never spelled in a type; a
;; carrier named but not defined would answer nothing. budget was the first
;; kind for five days: shipped, usable through `metta.under`, and absent
;; from the vocabulary the enum is generated from, so `Semiring.budget`
;; raised AttributeError while `(algebra budget ...)` sat right here.
!(test (match &metta (algebra amplitude $c $e $z $o $l $ca $r $w) $z)
       (complex 0 0))
