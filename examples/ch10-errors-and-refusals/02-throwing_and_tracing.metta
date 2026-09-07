;`throw` is the half of the error story a program writes for itself, and
;`trace!` is the one that prints without changing what the program answers.
;
;An error here is DATA, so `throw` does not unwind anything: it PRODUCES the
;value (Error (throw <reason>) <reason>), which travels the way every other
;error value travels.
!(test (throw (my-ball 1)) (Error (throw (my-ball 1)) (my-ball 1)))
!(test (throw "text") (Error (throw "text") "text"))

;Which means every form that reads an error reads this one, with no special
;case for a raised one against a computed one. `return-on-error` stops the
;computation by answering the error inside minimal MeTTa's own `return`
;marker, which is the shape that form always answers in.
!(test (if-error (throw oops) caught fine) caught)
!(test (if-error 42 caught fine) fine)
!(test (return-on-error (throw oops) carried-on) (return (Error (throw oops) oops)))
!(test (return-on-error 42 carried-on) carried-on)

;A reason that is ALREADY an error passes through unchanged rather than being
;wrapped twice, so rethrowing does not bury the original cause.
!(test (throw (Error (inner 1) because)) (Error (inner 1) because))
!(test (throw (throw first)) (Error (throw first) first))

;It travels out of a function the way any answer does, so a guard clause is
;an ordinary equation.
(= (half $n) (if (== (% $n 2) 0) (/ $n 2) (throw (odd $n))))
!(test (half 10) 5)
!(test (half 7) (Error (throw (odd 7)) (odd 7)))
!(test (if-error (half 7) refused (half 7)) refused)

;`trace!` prints its first argument and answers its SECOND, so it drops into
;the middle of an expression without changing the value that flows through.
;This file's own output carries the four lines it prints.
!(test (trace! "the answer" 42) 42)
!(test (+ 1 (trace! "adding one to" 41)) 42)
!(test (trace! (half 10) (half 10)) 5)

;Both arguments are held rather than reduced by the printing, so the label
;can be any atom and it is written as the program spelled it.
!(test (trace! (checking (odd 7)) ok) ok)
