;lib_patrick's `compose`: a list of functions applied right to left, to a
;list of arguments. The innermost function takes all the arguments and each
;one outside it takes the single answer of the one inside, which is what lets
;the same operator compose over an operation of any arity.
!(import! &self (library lib_patrick))

(: inc (-> Number Number))
(= (inc $x) (+ $x 1))
(: double (-> Number Number))
(= (double $x) (* $x 2))

;A one-function list is just application, and it is the case the definition
;special-cases: a single argument is handed over directly rather than being
;rebuilt into a call and reduced.
!(test (compose (inc) (5)) 6)
!(test (compose (double) (5)) 10)

;Two functions, innermost last: (inc (double 5)) and (double (inc 5)) are
;different numbers, and the order in the list is the order they read in.
!(test (compose (inc double) (5)) 11)
!(test (compose (double inc) (5)) 12)

;The innermost function is the one that meets the argument list, so it can
;take more than one. Everything outside it is unary by construction.
!(test (compose (+) (2 3)) 5)
!(test (compose (inc +) (2 3)) 6)
!(test (compose (double inc +) (2 3)) 12)

;Composition with nothing to compose is the argument itself, which keeps the
;operator associative: composing a longer list is composing the shorter ones.
!(test (compose (inc) ((compose (double) (5)))) 11)
!(test (== (compose (inc double) (5)) (compose (inc) ((compose (double) (5)))))
       True)
