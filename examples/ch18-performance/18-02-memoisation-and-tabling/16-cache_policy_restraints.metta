;A restraint is a bound a table declares for itself: (max-answers N) caps the
;answers one table may hold, (subgoal-abstract N) and (answer-abstract N) cap
;the size of a subgoal and of an answer. Reaching one stops the evaluation
;with a control signal, the way an inference limit does, and the host seats
;classify it beside the other limits (the Python surface raises
;RestraintError with the word, the bound and the call). It is not catchable
;from MeTTa, deliberately: a program cannot disarm its own bound, so this file
;shows the declared table under its bound and the policy in force.

!(import! &self (library lib_tabling))

(= (upto $n) (superpose (1 2 3 4 5)))

;Restraints stack with any other word; the default watch stays incremental.
!(add-atom &metta (cache upto ((max-answers 10) (subgoal-abstract 4))))
!(test (table-stats (upto $n))
       ((tables 0) (answers 0) (complete-call 0) (invalidated 0) (reevaluated 0)
        (policy (incremental shared (max-answers 10) (subgoal-abstract 4)))))

;Five answers under a bound of ten: nothing is different.
!(test (sort-atom (collapse (upto 5))) (1 2 3 4 5))
!(test (table-stats (upto $n))
       ((tables 1) (answers 5) (complete-call 1) (invalidated 0) (reevaluated 0)
        (policy (incremental shared (max-answers 10) (subgoal-abstract 4)))))

;A restraint's argument is checked at the door: a bound that is not an
;integer is refused, and the row never lands.
!(test (if-error (catch (add-atom &metta (cache upto (max-answers many))))
                 refused admitted)
       refused)
!(test (collapse (match &metta (cache upto $policy) $policy))
       (((max-answers 10) (subgoal-abstract 4))))
