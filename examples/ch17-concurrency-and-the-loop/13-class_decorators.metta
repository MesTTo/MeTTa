; Purpose: the decorators and special methods of a Python class are rows the
;   engine already has. A property is an accessor equation; a class method
;   takes the class symbol; a static method has no receiver; total_ordering
;   derives the missing comparisons from the root and equality; __add__,
;   __len__, __iter__ and __call__ are the words add, len, iter and call;
;   an abstract method is an arrow with no equation. The Python twin declares
;   these classes with `@m.define`; here their rows are written by hand.

;@property area on a frozen Circle: a derived accessor.
!(add-atom &Circle (: Circle (-> Number Circle)))
!(add-atom &Circle (= (Circle-area (Circle $r)) (* 3 (* $r $r))))
;@classmethod unit: the class symbol is the first argument. @staticmethod
;grow: no receiver at all.
!(add-atom &Circle (= (Circle-unit Circle) (Circle 1)))
!(add-atom &Circle (= (Circle-grow $r $by) (+ $r $by)))

;@functools.total_ordering with __eq__ and __lt__ written: le derives from
;the two, and gt is lt with its operands swapped, the reflection Python uses.
!(add-atom &Money (: Money (-> Number Money)))
!(add-atom &Money (= (Money-eq (Money $a) (Money $b)) (== $a $b)))
!(add-atom &Money (= (Money-lt (Money $a) (Money $b)) (< $a $b)))
!(add-atom &Money
  (= (Money-le $a $b) (or (Money-lt $a $b) (Money-eq $a $b))))
!(add-atom &Money (= (Money-gt $a $b) (Money-lt $b $a)))

;__add__ on a vector, __len__ and __iter__ on a stack, __call__ on an adder.
!(add-atom &Vector (: Vector (-> Number Number Vector)))
!(add-atom &Vector
  (= (Vector-add (Vector $x1 $y1) (Vector $x2 $y2)) (Vector (+ $x1 $x2) (+ $y1 $y2))))
!(add-atom &Stack (: Stack (-> Expression Stack)))
!(add-atom &Stack (= (Stack-len (Stack $items)) (size-atom $items)))
!(add-atom &Stack (= (Stack-iter (Stack $items)) (superpose $items)))
!(add-atom &Adder (: Adder (-> Number Adder)))
!(add-atom &Adder (= (Adder-call (Adder $n) $x) (+ $n $x)))

;An abstract Shape publishes the arrow alone; the concrete Square writes the
;equation.
!(add-atom &Shape (: Shape Type))
!(add-atom &Shape (: Shape-area (-> Shape Number)))
!(add-atom &Square (: Square (-> Number Square)))
!(add-atom &Square (:< Square Shape))
!(add-atom &Square (= (Square-area (Square $s)) (* $s $s)))

!(add-atom &self (from &Circle))
!(add-atom &self (from &Money))
!(add-atom &self (from &Vector))
!(add-atom &self (from &Stack))
!(add-atom &self (from &Adder))
!(add-atom &self (from &Shape))
!(add-atom &self (from &Square))

!(test (Circle-area (Circle 2)) 12)
!(test (Circle-unit Circle) (Circle 1))
!(test (Circle-grow 2 3) 5)
!(test (Money-le (Money 5) (Money 5)) True)
!(test (Money-gt (Money 7) (Money 5)) True)
!(test (Money-gt (Money 5) (Money 5)) False)
!(test (Vector-add (Vector 1 2) (Vector 3 4)) (Vector 4 6))
!(test (Stack-len (Stack (1 2 3))) 3)
!(test (collapse (Stack-iter (Stack (1 2 3)))) (1 2 3))
!(test (Adder-call (Adder 10) 4) 14)
!(test (Square-area (Square 3)) 9)
!(test (collapse (match &Shape (: Shape-area $arrow) $arrow)) ((-> Shape Number)))
