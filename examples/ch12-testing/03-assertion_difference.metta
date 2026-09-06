; A failing assertion says WHICH answers differ. The comparison already knew:
; assertEqualToResult subtracts each answer bag from the other to decide its
; verdict, and assertEqual holds the same two collapsed tuples. Both carry that
; evidence into the failure now, where it used to be dropped along with the
; comparison.
;
; Reading the report is the point, so read one first. This is what the engine
; writes on stderr for the first assertion below, and the same three lines
; reach the Node seat, the C seat, and Python's AssertionFailure:
;
;     MeTTa assertion failed: (assertEqual (+ 1 1) 3)
;       missing: (3)
;       excess: (2)
;
; `missing` is what was expected and never produced; `excess` is what was
; produced and never expected. Both are BAGS, so a repeated answer counts every
; time it appears.
;
; catch turns the failure into DATA, which is the only reason a file about
; failing assertions can itself pass. It answers (Error <ball> <context>).
; unify reads the ball out: its operands are held rather than evaluated, so an
; error value can be taken apart there instead of travelling on past the call
; the way it does through an ordinary argument. repr then writes the ball as
; the text this file compares: the same three pieces of data the message lays
; out over its three lines, on one line.

; Both directions at once: 3 was wanted and never came, 2 came and was never
; wanted. The ball names the call AS WRITTEN rather than the False it reduced
; to, so the report points at something a reader can find in the source.
!(test (let $reported (catch (assertEqual (+ 1 1) 3))
         (unify $reported (Error $ball $context) (repr $ball) no-error))
       "(metta_assertion_failed (assertEqual (+ 1 1) 3) (3) (2))")

; One direction. The other bag is EMPTY rather than absent: the comparison ran
; and found nothing in excess.
!(test (let $reported (catch (assertEqualToResult (superpose (1 2)) (1 2 3)))
         (unify $reported (Error $ball $context) (repr $ball) no-error))
       "(metta_assertion_failed (assertEqualToResult (superpose (1 2)) (1 2 3)) (3) ())")

; A bag difference, not a set difference. One occurrence on one side consumes
; exactly one on the other, so (a a b) against (a b b) leaves one b wanted and
; one a produced rather than nothing at all.
!(test (let $reported (catch (assertEqual (superpose (a a b)) (superpose (a b b))))
         (unify $reported (Error $ball $context) (repr $ball) no-error))
       "(metta_assertion_failed (assertEqual (superpose (a a b)) (superpose (a b b))) (b) (a))")

; A ONE-SIDED question gets a one-sided answer. assertIncludes asks whether
; every expected answer appears, so an answer in excess of the expectation is
; LEGAL: 1 and 2 are both produced here and neither is expected, and the report
; names neither. Only the missing bag is a reason for the failure, and the
; excess side is ABSENT rather than empty, which repr writes as a variable:
;
;     MeTTa assertion failed: (assertIncludes (superpose (1 2)) (7))
;       missing: (7)
!(test (let $reported (catch (assertIncludes (superpose (1 2)) (7)))
         (unify $reported (Error $ball $context) (repr $ball) no-error))
       "(metta_assertion_failed (assertIncludes (superpose (1 2)) (7)) (7) $_0)")

; Two EMPTY bags beside a failure is the diagnosis rather than a puzzle.
; assertEqual compares the collapsed tuples by term equality, so a permutation
; fails while the answers themselves agree; the message adds a line saying
; "the two answer bags agree, so the answers differ only in order".
!(test (let $reported (catch (assertEqual (superpose (1 2)) (superpose (2 1))))
         (unify $reported (Error $ball $context) (repr $ball) no-error))
       "(metta_assertion_failed (assertEqual (superpose (1 2)) (superpose (2 1))) () ())")

; The Msg forms carry a message the engine used to accept and drop. Reporting
; the call as written carries it, with no separate channel for it.
!(test (let $reported (catch (assertEqualMsg (+ 1 2) 4 "sums differ"))
         (unify $reported (Error $ball $context) (repr $ball) no-error))
       "(metta_assertion_failed (assertEqualMsg (+ 1 2) 4 \"sums differ\") (4) (3))")

; assert takes a VERDICT, not two answer bags, so there is nothing to subtract
; and the ball carries neither. The two arguments stay UNBOUND, which repr
; writes as variables and the message prints as no bag line at all. Absence is
; a different answer from two empty bags: one says there was no bag comparison
; here, the other says the comparison ran and the bags agreed.
!(test (let $reported (catch (assert (== 1 2)))
         (unify $reported (Error $ball $context) (repr $ball) no-error))
       "(metta_assertion_failed false $_0 $_1)")

; The load-bearing half: the evidence travels, the verdicts do not move.
!(test (assertEqual (+ 1 2) (- 6 3)) True)
!(test (assertEqualToResult (superpose (1 2)) (2 1)) True)
!(test (assertEqualMsg (+ 1 2) (- 6 3) "sums differ") True)
