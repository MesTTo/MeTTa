;; Purpose: declare a native owned record and read it back as data.
;; Guarantees: an empty record reads (); a written value reads as its whole
;;   row with a stored expression left unevaluated; replacing the value inside
;;   a transaction reads the new row; a second value for one key is refused at
;;   the outer commit and the record is unchanged [tested:
;;   sh test.sh examples/ch15-writing-transactions-and-worlds/07-owned_records.metta;
;;   commit=WORKTREE].

!(bind! &ledger (new-space))

;; One balance per account: the account's owned-by marker owns its balance row.
!(add-atom &metta (@owned-record &ledger $account &ledger (balance $account)))
!(add-atom &ledger (owned-by (Account 1)))

!(test (owned-record-read (@owned-record &ledger (Account 1) &ledger (balance (Account 1)))) ())

!(add-atom &ledger (balance (Account 1) (+ 5 5)))
!(test (owned-record-read (@owned-record &ledger (Account 1) &ledger (balance (Account 1))))
       ((balance (Account 1) (noeval (+ 5 5)))))

!(transaction (progn
    (remove-atom &ledger (balance (Account 1) (+ 5 5)))
    (add-atom &ledger (balance (Account 1) 12))))
!(test (owned-record-read (@owned-record &ledger (Account 1) &ledger (balance (Account 1))))
       ((balance (Account 1) 12)))

;; A second value for the same key cannot commit, and the record keeps its row.
!(test (if-error (catch (transaction (add-atom &ledger (balance (Account 1) 13))))
                 refused committed)
       refused)
!(test (owned-record-read (@owned-record &ledger (Account 1) &ledger (balance (Account 1))))
       ((balance (Account 1) 12)))
