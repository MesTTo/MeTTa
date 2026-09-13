; Purpose: the sorted map and the priority queue lib_datastructures publishes,
; beside the functional queue and the finger tree it already had.
; [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/21-datastructures_lib.metta; commit=WORKTREE].
; Both are VALUES: an operation answers a new one and leaves its input alone,
; so a program can hold both the before and the after.
!(import! &self (library lib_datastructures))

; A map is built from pairs or grown from the empty one. Keys are compared in
; the standard order of terms, so the pairs come back sorted however they went in.
!(bind! &prices (map-from-pairs ((pear 5) (apple 3) (plum 7))))
!(test (map-size &prices) 3)
!(test (map-keys &prices) (apple pear plum))
!(test (map-values &prices) (3 5 7))
!(test (map-pairs &prices) ((apple 3) (pear 5) (plum 7)))

; A lookup that finds nothing has NO answer, which is what tells absence from a
; stored value; map-get-or takes the answer to give instead.
!(test (map-get &prices pear) 5)
!(test (collapse (map-get &prices durian)) ())
!(test (map-get-or &prices durian 0) 0)
!(test (map-has &prices apple) True)
!(test (map-has &prices durian) False)
!(test (map-min &prices) (apple 3))
!(test (map-max &prices) (plum 7))

; A put answers a NEW map and leaves the old one alone, which is what makes a
; map a value rather than a place.
!(bind! &raised (map-put &prices pear 6))
!(test (map-pairs &raised) ((apple 3) (pear 6) (plum 7)))
!(test (map-pairs &prices) ((apple 3) (pear 5) (plum 7)))
!(test (map-pairs (map-remove &prices pear)) ((apple 3) (plum 7)))
!(test (map-pairs (map-remove &prices durian)) ((apple 3) (pear 5) (plum 7)))
!(test (map-size (map-empty)) 0)
!(test (map-pairs (map-put (map-empty) k v)) ((k v)))

; A key holds one value, so two values for one key is refused where it is
; written rather than silently keeping the last.
!(test (if-error (catch (map-from-pairs ((k 1) (k 2)))) refused fine) refused)
!(test (if-error (catch (map-get 42 k)) refused fine) refused)

; A priority queue stores its entries in priority order, keeping every occurrence.
!(bind! &work (pq-from-pairs ((3 sweep) (1 wake) (2 boil))))
!(test (pq-size &work) 3)
!(test (pq-min &work) (1 wake))
!(test (pq-pairs &work) ((1 wake) (2 boil) (3 sweep)))

; pq-pop decomposes the first entry and the remaining queue together.
!(test (let ($priority $value $rest) (pq-pop &work) ($priority $value (pq-size $rest)))
       (1 wake 2))
!(test (let ($priority $value $rest) (pq-pop &work) (pq-pairs $rest)) ((2 boil) (3 sweep)))
!(test (pq-size &work) 3)

; Repeated priorities are kept, so a queue holds what was inserted; merging is
; one operation over both queues, and removing a named entry cancels it.
!(test (pq-size (pq-from-pairs ((1 a) (1 b)))) 2)
!(test (pq-pairs (pq-insert &work 0 rise)) ((0 rise) (1 wake) (2 boil) (3 sweep)))
!(test (pq-pairs (pq-merge &work (pq-from-pairs ((0 rise))))) ((0 rise) (1 wake) (2 boil) (3 sweep)))
!(test (pq-pairs (pq-remove &work 2 boil)) ((1 wake) (3 sweep)))
!(test (collapse (pq-remove &work 2 absent)) ())
!(test (pq-size (pq-empty)) 0)
!(test (collapse (pq-min (pq-empty))) ())
!(test (collapse (pq-pop (pq-empty))) ())
!(test (if-error (catch (pq-size 42)) refused fine) refused)

; The functional queue that was here before: enqueue and dequeue in amortized
; constant time over two lists.
!(test (enqueue 2 (enqueue 1 (empty-queue))) (queue (cons 2 (cons 1 ())) () 2))
!(test (dequeue 1 (enqueue 2 (enqueue 1 (empty-queue)))) (queue () (cons 2 ()) 1))

; And the finger tree, which is the deque: both ends in amortized constant time
; and concatenation in O(log n).
!(test (ft-to-list (ft-from-list (1 2 3))) (1 2 3))
!(test (ft-front (ft-from-list (1 2 3))) 1)
!(test (ft-back (ft-from-list (1 2 3))) 3)
!(test (ft-to-list (ft-concat (ft-from-list (1 2)) (ft-from-list (3 4)))) (1 2 3 4))
!(test (ft-is-empty (ft-empty)) True)

; A map's relation is available to ordinary patterns and Pairs operations.
!(test (== &prices (SortedMap ((apple 3) (pear 5) (plum 7)))) True)
!(test (let (SortedMap $rows) &prices (pairs-lookup $rows pear)) 5)

; Merge accepts zero, one or any number of queues, including a runtime sequence.
!(test (pq-merge) (pq-empty))
!(test (pq-merge &work) &work)
!(test (pq-size (pq-merge &work &work &work)) 9)
!(test (pq-size (apply-to pq-merge (quote (&work &work)))) 6)
!(test (pq-pairs (pq-from-pairs ((1 a) (1 b) (1 c)))) ((1 a) (1 b) (1 c)))
!(test (pq-pairs (pq-insert (pq-from-pairs ((1 a) (1 b))) 1 c)) ((1 a) (1 b) (1 c)))
!(test (pq-pairs (pq-remove (pq-from-pairs ((1 a) (1 a) (2 b))) 1 a)) ((1 a) (2 b)))

; Variables retain identity, and malformed or cross-kind values are refused.
!(test (if-error (catch (map-from-pairs (($x a) ($x b)))) refused fine) refused)
!(test (if-error (catch (map-from-pairs ($pair))) refused fine) refused)
!(test (let $map (map-from-pairs (($x a) ($y b)))
         (map-get $map $x)) a)
!(test (map-get (map-from-pairs (quote (((+ 1 2) (Error data code)))))
               (quote (+ 1 2))) (quote (Error data code)))
!(test (if-error (catch (map-size (pq-empty))) refused fine) refused)
!(test (if-error (catch (pq-size (map-empty))) refused fine) refused)
!(test (collapse (map-get (map-from-pairs (superpose (((a 1)) ((a 2))))) a)) (1 2))

; Reconstruct an equation, or specialize its collection before applying it.
!(test (let $source
         (match &self (= (map-remove $map $key) $body)
           (quote (|-> ($map $key) $body)))
         (let $remove (eval $source) (map-pairs ($remove &prices pear))))
       ((apple 3) (plum 7)))
!(test (let $map &prices
         (let $source
           (match &self (= (map-remove $map $key) $body)
             (quote (|-> ($key) $body)))
           (let $remove (eval $source) (map-pairs ($remove plum)))))
       ((apple 3) (pear 5)))
