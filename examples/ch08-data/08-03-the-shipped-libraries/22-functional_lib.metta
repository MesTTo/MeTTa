; Purpose: the functional and iteration utilities, beside lib_patrick's four
; idioms that this library grew out of.
; [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/22-functional_lib.metta; commit=a2a80061cd8264d8f714b14c76b94d00f44a0755].
; The two libraries are separate imports, so a program pays for the half it
; asks for; this file asks for both, the general half here and the idioms below.
!(import! &self (library lib_functional))
; lib_unicode is imported for one claim below, whose test is a head the library
; declares deterministic: that is the case a verdict has to be read rather than
; asked for.
!(import! &self (library lib_unicode))

(= (double $x) (* 2 $x))
(= (odd? $x) (== 1 (% $x 2)))
(= (grade $score) (if (> $score 50) pass fail))

; `zip` pairs corresponding elements and stops at the shorter collection, so a
; long one zipped with a short one is the short one's length. `unzip` inverts it.
!(test (zip (1 2 3) (a b c)) ((1 a) (2 b) (3 c)))
!(test (zip (1 2 3) (a b)) ((1 a) (2 b)))
!(test (zip () (a)) ())
!(test (unzip ((1 a) (2 b))) ((1 2) (a b)))
!(test (unzip (zip (1 2) (a b))) ((1 2) (a b)))
!(test (if-error (catch (unzip (1))) refused fine) refused)

; `drop` is the suffix. The PREFIX is lib_combinatorics' `takeK`, so this
; library adds no second spelling of it.
!(test (drop (1 2 3 4) 2) (3 4))
!(test (drop (1 2) 5) ())
!(test (drop (1 2) 0) (1 2))

; `chunk` cuts a collection into pieces, the last one short when the size does
; not divide the length. `window` slides instead of cutting, so consecutive
; windows overlap by all but one element.
!(test (chunk (1 2 3 4 5) 2) ((1 2) (3 4) (5)))
!(test (chunk (1 2 3 4) 2) ((1 2) (3 4)))
!(test (chunk () 2) ())
!(test (window (1 2 3 4) 2) ((1 2) (2 3) (3 4)))
!(test (window (1 2 3) 3) ((1 2 3)))
!(test (window (1 2) 3) ())
!(test (if-error (catch (chunk (1 2) 0)) refused fine) refused)
!(test (if-error (catch (window (1 2) 0)) refused fine) refused)

; `flatten-once` removes ONE level of nesting and `flatten-deep` removes every
; one, which is the difference between concatenating and collecting the leaves.
; Both say the depth in the name, because the bare name `flatten` is the host
; Prolog's own every-level flatten and the library leaves it alone.
!(test (flatten-once ((1 2) (3) () 4)) (1 2 3 4))
; An inner collection's own nesting is data one level does not touch; the
; expression (1 (2)) flattens to its two elements, one of which is (2).
!(test (flatten-once (((1 (2))) 3)) ((1 (2)) 3))
!(test (flatten-deep ((1 (2 (3))) 4)) (1 2 3 4))
!(test (flatten-deep (((())))) ())

; `partition` splits on a test and loses nothing: whatever the test does not
; answer True for lands in the second side.
!(test (partition odd? (1 2 3 4)) ((1 3) (2 4)))
!(test (partition odd? ()) (() ()))
!(test (partition (|-> ($x) (> $x 10)) (1 2)) (() (1 2)))
; The test's verdict is READ and compared, never threaded into the call as an
; expected answer, so a test whose own head is declared deterministic answers
; False rather than failing: this one is lib_unicode's, over one-character
; strings.
!(test (partition (|-> ($c) (unicode-is $c letter)) ("a" "1")) (("a") ("1")))

; `group-by` gathers by what a key function answers, keys in first-appearance
; order and members in the collection's order, so grouping needs no sort.
!(test (group-by odd? (1 2 3 4)) ((True (1 3)) (False (2 4))))
!(test (group-by grade (80 20 90)) ((pass (80 90)) (fail (20))))
!(test (group-by odd? ()) ())

; `sort-by` orders by the key and is STABLE, so equal keys keep their order.
!(test (sort-by double (3 1 2)) (1 2 3))
!(test (sort-by (|-> ($p) (index-atom $p 1)) ((b 1) (a 1) (c 0))) ((c 0) (b 1) (a 1)))

; `scan` is a fold that answers its running results, so a prefix sum is scan
; with +. The answer is one longer than the input, because the start is first.
!(test (scan + 0 (1 2 3)) (0 1 3 6))
!(test (scan + 0 ()) (0))
!(test (scan (|-> ($acc $x) (cons-atom $x $acc)) () (1 2)) (() (1) (2 1)))

; `unfold` is the opposite of a fold: a seed grows into a collection while the
; step answers (Value NextSeed), and stops when it answers nothing.
!(test (unfold (|-> ($n) (if (< $n 4) ($n (+ $n 1)) (empty))) 1) (1 2 3))
!(test (unfold (|-> ($n) (empty)) 1) ())

; `pipe` applies functions left to right, which is the reading order;
; lib_patrick's `compose` applies them right to left, the mathematical order.
; The collection of functions is HELD, so it is not read as a call.
!(test (pipe (double double) 3) 12)
!(test (pipe () 3) 3)
!(test (pipe (double odd?) 3) False)

; `apply-to` turns a collection of arguments into a call, which is what a fold
; over a variable number of arguments needs.
!(test (apply-to + (1 2)) 3)
!(test (apply-to double (5)) 10)

; The three control forms hold their body: `repeat` runs it a fixed number of
; times, `while` runs it until its condition stops answering True, and `unless`
; runs it when the condition answers False.
!(test (collapse (repeat 3 (+ 3 4))) (7 7 7))
!(test (collapse (repeat 0 (+ 3 4))) ())
!(test (collapse (unless False (+ 1 1))) (2))
!(test (collapse (unless True (+ 1 1))) ())
!(test (collapse (while False never)) ())

; A while loop with state: the counter lives in a space, the condition reads it
; and the body advances it, so the loop ends when the space says so. Held
; parameters are what make this work: an evaluated body would run once.
!(add-atom &ticks (count 0))
(= (ticks) (car-atom (collapse (match &ticks (count $n) $n))))
(= (tick)
   (let $now (ticks)
     (let $gone (remove-atom &ticks (count $now))
       (let $next (+ $now 1)
         (let $added (add-atom &ticks (count $next)) $next)))))
!(test (collapse (while (< (ticks) 3) (tick))) (1 2 3))
!(test (ticks) 3)

; And lib_patrick's own four, unchanged, from their own library.
!(import! &self (library lib_patrick))
!(test (compose (double double) (3)) 12)
; The same composition written both ways: double then odd? left to right is
; odd? after double right to left, and 6 is even either way.
!(test (compose (odd? double) (3)) False)
!(test (@ $x (+ 1 2)) 3)
!(test (collapse (for $x (1 2 3) (* $x 10))) (10 20 30))
!(test (iterate 0 3 0 (|-> ($i $s) (+ $s $i))) 3)
