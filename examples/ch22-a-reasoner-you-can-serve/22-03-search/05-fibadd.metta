; Purpose: evaluate an added Fibonacci equation with an explicit branch budget.
!(add-atom &self (= (fib $N)
                    (if (< $N 2)
                        $N
                        (+ (fib (- $N 1))
                           (fib (- $N 2))))))

;Set a finite branch budget for the equation added above.
!(test (with-pragma! ((max-stack-depth 100000000)) (fib 30)) 832040)
