;lib_roman's three set operations, and the three helpers around them.
;
;`15-roman.metta` used the nine spellings that fix an equality: `/=\` for
;intersection under `=`, `/==\` under `==`, `/=a\` under `=alpha`, and the
;same three for subtraction and union. Each of those nine is one call to the
;general operator with the comparison passed in, and this file uses the
;general one directly with a comparison of its own, so the family is three
;operations rather than nine.
!(import! &self (library lib_roman))

;"Within one of each other" is a perfectly good sameness for a set operation,
;and nothing about the operators cares that it is not an equality.
(: close-enough (-> Number Number Bool))
(= (close-enough $a $b) (< (abs-math (- $a $b)) 2))

;`/?\` keeps the elements of the left that the comparison relates to
;something on the right: 1 is within one of 2, and 5 and 9 are not near 100.
!(test (/?\ close-enough (1 5 9) (2 100)) (1))
!(test (/?\ close-enough (1 5 9) ()) ())

;`\?` is the other half: the elements of the left with no relative on the
;right.
!(test (\? close-enough (1 5 9) (2 100)) (5 9))
!(test (\? close-enough (1 5 9) ()) (1 5 9))

;`\?/` is the union built out of that subtraction: what the left contributes
;that the right does not already cover, then the whole right.
!(test (\?/ close-enough (1 5 9) (2 100)) (5 9 2 100))
!(test (\?/ close-enough () (2 100)) (2 100))

;Passing `==` back in reproduces the fixed spelling exactly, which is what
;makes the nine sugar rather than nine implementations.
!(test (== (/?\ == (1 2 3) (2 3 4)) (/==\ (1 2 3) (2 3 4))) True)
!(test (== (\? == (1 2 3) (2 3 4)) (\== (1 2 3) (2 3 4))) True)
!(test (== (\?/ == (1 2 3) (2 3 4)) (\==/ (1 2 3) (2 3 4))) True)

;`fst` and `snd` read a two-element expression, and `cns` is the pair reading
;of `cons`: one argument holding the head and the tail together.
!(test (fst (a b)) a)
!(test (snd (a b)) b)
!(test (cns (1 (2 3))) (1 2 3))
!(test (cns ((f 1) ())) ((f 1)))

;The two tracing helpers print and answer their subject unchanged, so they
;drop into an expression without changing what it computes. `traceid` prints
;the value; `tracem` prints a label beside it.
!(test (traceid 42) 42)
!(test (tracem "the answer" 42) 42)
!(test (+ 1 (traceid 41)) 42)
