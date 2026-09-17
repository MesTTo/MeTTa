; Purpose: a frozen Python dataclass is a constructor term. Its fields are
;   positions, a method is an equation over the term, an operator is the method
;   Python routes it to, and a keyword case pattern is the positional term.
;   These are the rows the Python twin's `@m.define class Point` derives; here
;   they are written by hand into the class's own space, &Point, which a
;   program references with (from &Point).

!(add-atom &Point (: Point (-> Number Number Point)))
!(add-atom &Point (= (Point-x (Point $x $y)) $x))
!(add-atom &Point (= (Point-y (Point $x $y)) $y))

;A method compiles with self as its first parameter: norm reads the fields.
!(add-atom &Point
  (= (Point-norm (Point $x $y)) (sqrt-math (+ (* $x $x) (* $y $y)))))

;__add__ is the word add: a + b lowers to this head when a is a Point.
!(add-atom &Point
  (= (Point-add (Point $x1 $y1) (Point $x2 $y2)) (Point (+ $x1 $x2) (+ $y1 $y2))))

;case Point(x=0, y=y) places its keyword patterns through __match_args__.
!(add-atom &Point
  (= (Point-quadrant $p)
     (case $p (((Point 0 0) origin) ((Point 0 $y) axis) ((Point $x $y) plane)))))

!(add-atom &self (from &Point))

!(test (Point-norm (Point 3 4)) 5.0)
!(test (Point-add (Point 1 2) (Point 3 4)) (Point 4 6))
!(test (Point-quadrant (Point 0 0)) origin)
!(test (Point-quadrant (Point 0 4)) axis)
!(test (Point-quadrant (Point 3 4)) plane)
;Equality is the term's own: two points with the same fields are one value.
!(test (== (Point-add (Point 1 2) (Point 3 4)) (Point 4 6)) True)
