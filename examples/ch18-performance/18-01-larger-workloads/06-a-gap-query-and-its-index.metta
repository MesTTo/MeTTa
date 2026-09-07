; What a gap query costs, and why it is not the size of the space.
;
; A pattern with a gap cannot use the store's arity-keyed read: `(edge ... $y)`
; has three children and matches stored atoms of every arity from two upwards,
; so the arity is what the gap decides rather than what the pattern fixes. The
; candidate set is enumerated per admissible arity instead, with the pattern's
; own leading child written into the candidate head first, so the store's
; first-argument index still selects the RELATION. Sequence variables are
; examples/ch08-data/08-02-sequence-variables/.
;
; Measured on this file 2026-09-07, by lowering each bound below until the ask
; stopped fitting under it:
;
;   ask                                        200 nodes    2000 nodes
;   (match &self (edge a $y) $y)   gap-free           57            57
;   (match &self (edge ... $y) $y) one gap           144           144
;   (match &self (node ... $y) $y) one gap         4,670        46,070

(= (nodes $n)
   (if (== $n 0)
       done
       (let $t (add-atom &self (node $n tag)) (nodes (- $n 1)))))

!(add-atom &self (edge a b))
!(add-atom &self (edge a c))
!(add-atom &self (edge a d e))

;;; Two hundred atoms in a relation the edge queries never touch.
!(test (nodes 200) done)
!(test (inferences 1000 (length (collapse (match &self (edge a $y) $y)))) 2)
!(test (inferences 1000 (length (collapse (match &self (edge ... $y) $y)))) 3)

;;; Two thousand more of them, and the same bound holds: the gap query reads
;;; the edge clauses and nothing else, so the node relation's size is not in
;;; its cost at all.
!(test (nodes 2000) done)
!(test (inferences 1000 (length (collapse (match &self (edge a $y) $y)))) 2)
!(test (inferences 1000 (length (collapse (match &self (edge ... $y) $y)))) 3)

;;; That bound is a proof and not a pin. The gap query over the node relation
;;; itself answers 2,200 rows, and no ask can answer 2,200 rows for fewer than
;;; 2,200 inferences, so an edge query fitting under 1,000 cannot have read
;;; them. What the gap costs is the enumeration it asked for: every arity the
;;; fixed part admits, over the one relation the head selects.
!(test (length (collapse (match &self (node ... $y) $y))) 2200)

;;; The gap decides the arity, so one pattern spans all three edge rows while
;;; the fixed pattern reads only the two of its own length. Sorted, because
;;; the gap query walks the arities the store holds and their order is the
;;; store's business rather than the program's.
!(test (sort-atom (collapse (match &self (edge a $y) $y))) (b c))
!(test (sort-atom (collapse (match &self (edge a (:seg $rest)) $rest)))
       ((b) (c) (d e)))
