;`#//` is the last member of the relational family, and it is not `#div`
;repeated under another name: the two disagree on every negative operand.
;`#//` truncates toward zero, the way SWI's own // does, and `#div` floors.
;Both are CLP(FD) constraints, so both still run in either direction.
;
;Forwards, on non-negative operands, they agree.
!(test (#// 7 2) 3)
!(test (#div 7 2) 3)

;A negative operand is where they part, and the difference is the rounding
;rule rather than a sign convention: -3.5 truncates to -3 and floors to -4.
!(test (#// -7 2) -3)
!(test (#div -7 2) -4)
!(test (#// 7 -2) -3)
!(test (#div 7 -2) -4)

;`#div` and `#mod` are the pair that reconstructs the dividend, because both
;round the same way: quotient times divisor plus remainder is the dividend.
!(test (+ (* (#div -7 2) 2) (#mod -7 2)) -7)
;`#//` has no matching remainder in this surface -- there is no `#rem` -- so
;the same sum built on it is off by the divisor, which is exactly the gap
;between truncating and flooring.
!(test (+ (* (#// -7 2) 2) (#mod -7 2)) -5)

;Backwards, like every other # operator: give the quotient and the dividend
;and the constraint solves for the divisor.
!(test (let 3 (#// 7 $d) $d) 2)

;The other direction is a genuine relation rather than a function, because
;truncation loses information: 6 and 7 both divide to 3, so the constraint
;narrows the dividend without deciding it and leaves the variable carrying
;its domain. Post a second constraint and it is decided again, which is
;propagation rather than search doing the work.
!(test (let True (#< $n 7) (let 3 (#// $n 2) $n)) 6)
!(test (let True (#> $n 6) (let 3 (#// $n 2) $n)) 7)
