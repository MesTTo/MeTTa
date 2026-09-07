;Clojure's bitwise family over exact integers: `bit-and`, `bit-or`,
;`bit-xor`, `bit-not` and the two shifts. They are the operations SWI's own
;/\, \/, xor, \, << and >> perform, so an integer mask is arithmetic rather
;than a crossing into a host language; the compiled Python surface lowers &,
;|, ^ and ~ onto these same names.
;
;12 is 1100 and 10 is 1010, so the three binary operations read straight off
;the bits: 1000, 1110, 0110.
!(test (bit-and 12 10) 8)
!(test (bit-or 12 10) 14)
!(test (bit-xor 12 10) 6)

;`bit-not` is two's complement, not a boolean negation: it answers -(n+1) for
;every integer, so 0 goes to -1 and 12 goes to -13.
!(test (bit-not 0) -1)
!(test (bit-not 12) -13)
!(test (bit-not (bit-not 12)) 12)

;The shifts move bits left and right, which is multiplying and dividing by a
;power of two. Nothing is truncated at a word boundary, because MeTTa's
;integers are SWI's unbounded ones.
!(test (bit-shift-left 1 4) 16)
!(test (bit-shift-right 16 2) 4)
!(test (bit-shift-left 3 62) 13835058055282163712)

;Right shift on a negative number keeps the sign, the arithmetic shift rather
;than the logical one, which follows from the unbounded representation: there
;is no top bit to shift a zero into.
!(test (bit-shift-right -8 1) -4)
!(test (bit-shift-right -1 40) -1)

;The family is exact-integer only, and a float earns the operation's own
;words rather than being truncated into one. The shifts say more, because
;their second operand carries a second constraint of its own.
!(test (bit-and 1.5 2) (Error (bit-and 1.5 2) "bit-and expects two integers"))
!(test (bit-shift-left 1.5 2) (Error (bit-shift-left 1.5 2) "bit-shift-left expects two arguments: integer (value) and non-negative integer (count)"))

;A mask reads as a predicate: bit 2 of 12 is set, bit 1 is not.
!(test (== (bit-and 12 4) 4) True)
!(test (== (bit-and 12 2) 2) False)
