; Purpose: compare imported assertions per answer and retained prelude bag heads.
; [tested: sh test.sh examples/ch12-testing/01-he_assert.metta; commit=90ba93eb8f6e98ebfefc55416859bf13de6a8427].
!(import! &self (library lib_he))

!(test (assertEqual (+ 1 2) (- 6 3)) True)
!(test (assertAlphaEqual (h $x $y) (h $a $b)) True)
!(test (assertAlphaEqual (quote (+ $x $y)) (quote (+ $a $b))) True)

; Upstream lib_he makes ToResult an alias of the individual-answer assertion.
; Its expected value is scalar; two equal alternatives produce two successes.
!(test (assertEqualToResult (+ 1 2) 3) True)
!(test (collapse (assertEqualToResult (superpose (1 1)) 1)) (true true))
(= (adder) ($x))
!(test (assertAlphaEqualToResult (adder) ($y)) True)

; lib_he does not define Includes or Msg heads. Those keep the engine's bag
; contract: every expected result must appear among those produced.
!(test (assertIncludes (superpose (1 2 3)) (2)) True)
!(test (assertIncludes (superpose (1 2 3)) (2 3)) True)

; The engine's Msg variants retain their bag contract and failure message.
!(test (assertEqualMsg (+ 1 2) (- 6 3) "sums differ") True)
!(test (assertAlphaEqualMsg (h $x $y) (h $a $b) "not alpha equal") True)
!(test (assertEqualToResultMsg (+ 1 2) (3) "not the expected result") True)
!(test (assertAlphaEqualToResultMsg (adder) (($y)) "not alpha equal") True)
