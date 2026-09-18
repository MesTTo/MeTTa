; Purpose: compose finite domains, traversal, assertions and first witnesses.
; [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/43-testing_lib.metta; commit=7fad61bab72098722b27091a94282ff69989920e].
!(import! &self (library lib_combinatorics))
!(import! &self (library lib_testing))

; A domain is an ordinary generator. range excludes its upper bound.
!(test (collapse (range -2 3)) (-2 -1 0 1 2))
!(test (collapse (range 3 4)) (3))
!(test (collapse (range 3 3)) ())
!(test (collapse (range 100000000000000000000 100000000000000000003))
       (100000000000000000000 100000000000000000001 100000000000000000002))
!(test (collapse (superpose (a a "π"))) (a a "π"))
!(test (collapse (superpose ())) ())
; superpose evaluates alternatives; indexing selects a value as data.
!(test (size-atom (index-atom (quote ((+ 1 2))) 0)) 3)
!(test (collapse (index-atom (()) 0)) (()))
!(test (let $items (collapse (range 1 4))
         (collapse (index-atom $items (range 0 (size-atom $items))))) (1 2 3))

; List lengths and element choices vary independently.
!(test (collapse (cartesian-power (0 1) 0)) (()))
!(test (collapse (cartesian-power (0 1) 2)) ((0 0) (0 1) (1 0) (1 1)))
!(test (collapse (cartesian-power (a a) 2)) ((a a) (a a) (a a) (a a)))
!(test (collapse (cartesian-power () 0)) (()))
!(test (collapse (cartesian-power () 2)) ())
!(test (collapse (let* (($population (collapse (range 0 2)))
                       ($length (range 0 3)))
                  (cartesian-power $population $length)))
       (() (0) (1) (0 0) (0 1) (1 0) (1 1)))
!(test (collapse (cartesian-power (0 1) (range 2 2))) ())
; Freshness is explicit; sharing inside each copied term survives.
!(test (let $choice (index-atom ((row $x $x)) 0)
         (let $pair (map-atom (1 2) $ignored (copy_term (quote $choice)))
           (=alpha $pair ((row $a $a) (row $b $b))))) True)
!(test (collapse (cartesian-power (() (a)) 1)) ((()) ((a))))

; forall traverses and test judges. The assertion is the callback.
!(forall (range -3 4) (|-> ($x) (test (>= (* $x $x) 0) True)))
!(forall (cartesian-power (0 1) (range 0 4))
   (|-> ($xs) (test (reverse (reverse $xs)) $xs)))
!(test (forall (range 0 5) (<= 0)) True)
!(test (foldall (|-> ($value $count) (+ $count 1)) (superpose (a a b)) 0) 3)
!(test (forall (superpose ()) (|-> ($x) False)) True)
!(test (foldall (|-> ($value $count) (+ $count 1)) (superpose ()) 0) 0)

; A bag assertion checks all answers and their multiplicities.
!(forall (range 1 3)
   (|-> ($x) (assertEqualToResult (superpose (2 1 1)) (1 2 1))))
!(forall (range 1 3) (|-> ($x) (assertEqualToResult (empty) ())))
!(forall (index-atom (quote ((+ 1 2))) 0)
   (|-> ($value) (assertEqualToResult (quote $value) ((+ 1 2)))))
!(forall (index-atom ((row $x $x)) 0)
   (|-> ($value) (test (=alpha $value (row $y $y)) True)))

; once commits to the first answer satisfying a condition.
!(test (once (let $x (range 0 6) (if (>= $x 3) $x (empty)))) 3)
!(test (collapse (once (let $x (range 0 6) (if (>= $x 3) $x (empty))))) (3))
!(test (collapse (once (let $x (range 0 3) (if (>= $x 3) $x (empty))))) ())
!(test (collapse (once (superpose ()))) ())
!(test (once (let $x (range 0 6)
               (if (== (sort-atom (collapse (superpose (2 1 1)))) (1 1 2))
                   $x (empty)))) 0)
!(test (size-atom (once (index-atom (quote ((+ 1 2))) 0))) 3)
!(test (collapse (once (let $x (index-atom (() (a)) (range 0 2))
                        (if (== (size-atom $x) 0) $x (empty))))) (()))
!(forall (range 0 3)
   (|-> ($x) (test (once (let $y (range 0 3) (if (== $x $y) $y (empty)))) $x)))

; Counting the checked cases is a fold over the same generator.
!(test (foldall (|-> ($x $count)
                 (let $checked (test (>= $x 0) True) (+ $count 1)))
               (range 0 3) 0) 3)
; Predicate existence and an exact answer bag are different questions.
!(test (forall (range 0 2) (|-> ($x) (superpose (False True)))) True)
!(test (forall (range 0 2) (|-> ($x) (empty))) False)
!(test (forall (range 0 2) (|-> ($x) 7)) False)

; A caught failure retains the core missing/excess answer bags.
!(test (let $error (catch (assertEqualToResult (superpose (1 1)) (1 2)))
         (unify $error (Error $ball $context) (repr $ball) no-error))
       "(metta_assertion_failed (assertEqualToResult (superpose (1 1)) (1 2)) (2) (1))")
!(test (if-error (catch (cartesian-power (a) -1)) refused fine) refused)
!(test (if-error (catch (cartesian-power (a) 1.5)) refused fine) refused)
; Commitment keeps the selected binding, as in any ordinary once expression.
!(test (let $value (once (unify $x 3 $x (empty))) $x) 3)
