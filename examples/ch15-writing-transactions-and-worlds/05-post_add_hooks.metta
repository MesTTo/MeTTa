;A post-add hook is the pre-add hook of the file before this one, read
;against a LANDED atom instead of an offered one. It claims the same write
;door of one space for one function of one argument, and the same four
;verdicts mean the same four things -- except that each of them now has to
;undo a write that already happened.
;
;This is a database AFTER trigger where the file before is a BEFORE trigger,
;and the reason to have both is that only the post phase can see what the
;write actually did.

(= (audit (raw $x)) (accept (cooked $x)))
(= (audit (secret $x)) (refuse "no secrets survive the audit"))
(= (audit (dup $x)) (drop))
(= (audit (plain $x)) (accept))

!(declare-post-add! &pool audit)

;(accept) leaves the landed atom where it is.
!(add-atom &pool (plain 1))
!(test (match &pool (plain $x) $x) 1)

;(accept <atom>) REPLACES it: the atom that landed is removed and the
;handler's is written through the same door, granted so the hook does not
;fire on its own output.
!(add-atom &pool (raw 7))
!(test (match &pool (cooked $x) $x) 7)
!(test (collapse (match &pool (raw $x) $x)) ())

;(drop) removes what landed, so the caller still sees the success of a write
;that leaves nothing behind.
!(add-atom &pool (dup 3))
!(test (collapse (match &pool (dup $x) $x)) ())

;(refuse <words>) throws with the handler's own sentence, and the write is
;undone first: an audited-and-rejected atom is not left in the space for the
;next reader to find.
!(test (repr (catch (add-atom &pool (secret 1))))
       "(Error (metta_add_refused &pool (secret 1) \"no secrets survive the audit\") none)")
!(test (collapse (match &pool (secret $x) $x)) ())

;A handler with no equation for the atom is a stuck state that names the
;space, the slot, the handler and the atom -- and the write is undone on that
;path too, which is the difference from the pre phase, where there was
;nothing to undo.
!(test (repr (catch (add-atom &pool (uncovered 9))))
       "(Error (metta_hook_stuck &pool post-add audit (uncovered 9)) none)")
!(test (collapse (match &pool (uncovered $x) $x)) ())

;One claimant per name here as well, checked when the claim is made.
(= (other-audit $a) (accept))
!(test (repr (catch (declare-post-add! &pool other-audit)))
       "(Error (metta_hook_conflict &pool post-add audit other-audit) none)")

;The two slots are independent, so a space can carry both: the pre hook
;decides what is allowed in and the post hook decides what to do about what
;got in. The post phase runs only when the pre phase wrote the atom AS
;OFFERED, so a pre transform is not audited twice.
(= (gate (raw $x)) (accept))
(= (gate (banned $x)) (drop))
(= (gate (plain $x)) (accept))
!(declare-pre-add! &pool gate)
!(add-atom &pool (raw 8))
!(test (match &pool (cooked 8) found) found)
!(add-atom &pool (banned 1))
!(test (collapse (match &pool (banned $x) $x)) ())

;Undeclaring is explicit and idempotent, and it frees the claim: the space is
;a direct write again.
!(undeclare-post-add! &pool)
!(undeclare-pre-add! &pool)
!(add-atom &pool (uncovered 10))
!(test (match &pool (uncovered $x) $x) 10)
!(undeclare-post-add! &pool)
