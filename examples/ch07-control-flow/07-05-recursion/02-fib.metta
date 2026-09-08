; Purpose: compute Fibonacci with an explicit branch budget.
(= (fib $N)
   (if (< $N 2)
       $N
       (+ (fib (- $N 1))
          (fib (- $N 2)))))

;Set a finite branch budget for this worked recursive program.
!(test (with-pragma! ((max-stack-depth 100000000)) (fib 30)) 832040)
