; Purpose: run four divisor searches under one explicit branch budget.
(= (find-divisor $n $test-divisor)
   (if (> (* $test-divisor $test-divisor) $n)
       $n
       (if (== 0 (% $n $test-divisor)) 
           $test-divisor
           (find-divisor $n (+ $test-divisor 1)))))

(= (prime? $n)
   (== $n (find-divisor $n 2)))

;The four divisor searches share this finite branch budget.
!(test (with-pragma! ((max-stack-depth 1000000))
         ((prime? 53537257)
          (prime? 53781811)
          (prime? 54218443)
          (prime? 54734431)))
       (True True True True))
