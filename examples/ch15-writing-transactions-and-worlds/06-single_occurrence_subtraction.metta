; Purpose: demonstrate single-occurrence subtraction inside transactions.
; Guarantees: a native miss returns False and failure restores a consumed copy
;   [tested: sh test.sh examples/ch15-writing-transactions-and-worlds/06-single_occurrence_subtraction.metta;
;   commit=WORKTREE].

;Subtraction observes the transaction's current store. A miss returns False
;without waiting for another writer, so the transaction can continue.
!(test (transaction (progn
         (add-atom &self (available 3))
         (add-atom &self (available 3))
         (subtract-atom &self (available 3)))) True)
!(test (collapse (match &self (available $n) $n)) (3))
!(test (transaction (subtract-atom &self (missing 4))) False)

;Failure restores the occurrence consumed inside the transaction.
!(test (collapse (transaction (progn
         (subtract-atom &self (available 3))
         (empty)))) ())
!(test (collapse (match &self (available $n) $n)) (3))
!(test (subtract-atom &self (available 3)) True)
