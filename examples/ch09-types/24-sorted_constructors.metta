; Purpose: compare declared constructors, untyped data and their field accessors.

; The arrow describes data. There is no equation with SortedPoint as its head.
; A method takes its receiver explicitly and destructures the constructor.
(: SortedPoint (-> Number Number SortedPoint))
(= (sorted-x (SortedPoint $x $y)) $x)
(= (plain-x (PlainPoint $x $y)) $x)
(= (make-sorted-point $x $y) (SortedPoint $x $y))
(= (sorted-norm (SortedPoint $x $y))
   (sqrt-math (+ (* $x $x) (* $y $y))))

!(test (get-type (SortedPoint 3 4)) SortedPoint)
!(test (sorted-x (SortedPoint 3 4)) 3)
!(test (sorted-norm (SortedPoint 3 4)) 5.0)
!(test (make-sorted-point "bad" 4)
       (Error (SortedPoint "bad" 4) (BadArgType 1 Number String)))

; The three loops do the same addition. The control supplies the field value
; directly. Compare their reduction costs with engine/bench.pl.
(= (constructor-control $n $sum)
   (if (== $n 0) $sum
       (let $x 3 (constructor-control (- $n 1) (+ $sum $x)))))
(= (constructor-sorted $n $sum)
   (if (== $n 0) $sum
       (let $x (sorted-x (SortedPoint 3 4))
            (constructor-sorted (- $n 1) (+ $sum $x)))))
(= (constructor-plain $n $sum)
   (if (== $n 0) $sum
       (let $x (plain-x (PlainPoint 3 4))
            (constructor-plain (- $n 1) (+ $sum $x)))))

!(test (constructor-control 20 0) 60)
!(test (constructor-sorted 20 0) 60)
!(test (constructor-plain 20 0) 60)
