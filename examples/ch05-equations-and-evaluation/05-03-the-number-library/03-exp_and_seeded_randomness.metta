;Two names the number library carries that the -math family does not cover on
;its own: `exp` beside `exp-math`, and `with-seed`, which makes a random draw
;repeatable.
;
;`exp` is e to the power of its argument. It is the same operation `exp-math`
;names one file up; the library declares both because the reference corelib
;ships the un-suffixed spelling and this engine answers to it.
!(test (exp 0) 1.0)
!(test (exp 1) 2.718281828459045)
!(test (== (exp 2) (exp-math 2)) True)

;`with-seed` holds its body rather than evaluating it first, and runs it with
;the random generator seeded to the number given. Two runs of the same seed
;draw the same numbers, which is what makes a randomised program testable at
;all: the draw stays random and the RUN stops being.
!(test (== (with-seed 42 (random-int 0 100))
           (with-seed 42 (random-int 0 100)))
       True)

;The scope is the body's whole dynamic extent, so several draws inside one
;`with-seed` are one repeatable sequence rather than one repeated number.
!(test (== (with-seed 7 (collapse (superpose ((random-int 0 100)
                                              (random-int 0 100)))))
           (with-seed 7 (collapse (superpose ((random-int 0 100)
                                              (random-int 0 100))))))
       True)

;A different seed is a different sequence, so the seed is doing work rather
;than switching randomness off.
!(test (== (with-seed 42 (random-int 0 100))
           (with-seed 43 (random-int 0 100)))
       False)

;It seeds `random-float` too, since one generator serves both.
!(test (== (with-seed 5 (random-float 0.0 1.0))
           (with-seed 5 (random-float 0.0 1.0)))
       True)
