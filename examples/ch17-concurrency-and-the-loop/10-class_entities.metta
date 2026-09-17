; Purpose: an ordinary Python dataclass is an entity: a handle around one of
;   the engine's own tokens, whose fields are facts in the class space. A
;   method that writes a field is a transaction, so a method that raises
;   leaves no half-written object, and the population is a query. The Python
;   twin's `@m.define class Account` derives these rows; here they are written
;   by hand into &Account.

!(add-atom &Account (: Account (-> Atom Account)))
!(add-atom &Account (internal owned-by _field-owner _field-balance))

;The accessor is an indexed match on the handle; the writer removes and adds
;inside the caller's transaction.
!(add-atom &Account
  (= (Account-balance (Account $id))
     (match &Account (_field-balance (Account $id) $n) $n)))
!(add-atom &Account
  (= (Account-balance! (Account $id) $n)
     (transaction
       (progn
         (remove-atom &Account (_field-balance (Account $id) $old))
         (add-atom &Account (_field-balance (Account $id) $n))
         True))))

;The constructor mints the identity as the owner row's own token.
!(add-atom &Account
  (= (make-Account $owner $balance)
     (transaction
       (progn
         (add-atom &Account (owned-by (Account $id)) $id)
         (add-atom &Account (_field-owner (Account $id) $owner))
         (add-atom &Account (_field-balance (Account $id) $balance))
         (Account $id)))))

;deposit and withdraw compile with self as a parameter; withdraw raises on an
;overdraft, which is an Error the transaction refuses.
!(add-atom &Account
  (= (Account-deposit (Account $id) $n)
     (Account-balance! (Account $id) (+ (Account-balance (Account $id)) $n))))
!(add-atom &Account
  (= (Account-withdraw (Account $id) $n)
     (if (< (Account-balance (Account $id)) $n)
       (Error (Account $id) overdraft)
       (Account-balance! (Account $id) (- (Account-balance (Account $id)) $n)))))

!(add-atom &self (from &Account))

!(bind! &alice (make-Account alice 40))
!(bind! &bob (make-Account bob 80))

!(test (Account-deposit &alice 25) True)
!(test (Account-balance &alice) 65)
;A failed withdrawal inside a transaction is refused and writes nothing.
!(test (if-error (transaction (Account-withdraw &alice 500)) refused unexpected) refused)
!(test (Account-balance &alice) 65)
!(test (Account-withdraw &bob 30) True)
;The population is one query over the class space.
!(test (msort (collapse (match &Account (_field-balance $account $n) $n))) (50 65))
