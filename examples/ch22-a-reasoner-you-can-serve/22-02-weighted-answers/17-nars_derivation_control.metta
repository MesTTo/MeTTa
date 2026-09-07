;What NARS does BETWEEN inferences. `09-nars_tuffy.metta` asks `NARS.Query` a
;question and reads the answer; the machinery under it is a priority queue,
;an evidence-tracking rule, three configuration numbers and a bounded loop,
;and each of those is an ordinary function here.
!(import! &self (library lib_nars))

;The three configuration numbers are nullary EQUATIONS rather than constants
;in the loop, so a program that wants a different budget defines its own.
!(test (NARS.Config.MaxSteps) 100)
!(test (NARS.Config.TaskQueueSize) 10)
!(test (NARS.Config.BeliefQueueSize) 100)

;`StampDisjoint` is what stops the same evidence being counted twice: two
;sentences may only combine when no evidence ID appears in both stamps. It is
;the rule that keeps a reasoner from talking itself into confidence.
!(test (StampDisjoint (1 2) (3 4)) True)
!(test (StampDisjoint (1 2) (2 3)) False)
!(test (StampDisjoint () ()) True)
!(test (StampDisjoint (1) ()) True)

;`StampConcat` merges two stamps, sorted, so a derived sentence carries every
;ID its premises did and the merge is order-independent. An empty addition is
;the identity, and it does NOT sort what it was given.
!(test (StampConcat (3 1) (2)) (1 2 3))
!(test (StampConcat (3 1) ()) (3 1))
!(test (== (StampConcat (1) (2)) (StampConcat (2) (1))) True)

;The two ranking functions are the priority queue's comparison, and they are
;defined at TWO clauses each: a sentence answers its confidence, and the
;empty tuple answers a sentinel far below anything real, which is what makes
;the fold's seed work without a special case.
!(test (PriorityRank (Sentence ((--> a b) (stv 1.0 0.9)) (1))) 0.9)
!(test (PriorityRank ()) -99999.0)
!(test (PriorityRankNeg (Sentence ((--> a b) (stv 1.0 0.9)) (1))) -0.9)
!(test (PriorityRankNeg ()) -99999.0)

;`ConfidenceRank` is the same shape for a bare (truth stamp) pair, which is
;what a query's answers are rather than sentences.
!(test (ConfidenceRank ((stv 1.0 0.9) (1))) 0.9)
!(test (ConfidenceRank ()) 0)

;`BestCandidate` is the queue itself: a ranking function, a running best, and
;the tuple to walk. Passing the ranking in is what makes one fold serve both
;"most confident" and "least confident".
!(test (BestCandidate PriorityRank ()
                      ((Sentence (a (stv 1.0 0.5)) (1))
                       (Sentence (b (stv 1.0 0.9)) (2))))
       (Sentence (b (stv 1.0 0.9)) (2)))
!(test (BestCandidate PriorityRankNeg ()
                      ((Sentence (a (stv 1.0 0.5)) (1))
                       (Sentence (b (stv 1.0 0.9)) (2))))
       (Sentence (a (stv 1.0 0.5)) (1)))
!(test (BestCandidate PriorityRank () ()) ())

;`LimitSize` is the bound on that queue: drop the lowest-priority item until
;the tuple fits. Its test is `(< (length $L) $size)`, so what it leaves is
;size MINUS ONE items rather than size, which is the arbiter's own arithmetic
;and worth knowing before a budget is chosen.
!(test (LimitSize ((Sentence (a (stv 1.0 0.5)) (1))) 5)
       ((Sentence (a (stv 1.0 0.5)) (1))))
!(test (LimitSize ((Sentence (a (stv 1.0 0.5)) (1))
                   (Sentence (b (stv 1.0 0.9)) (2)))
                  2)
       ((Sentence (b (stv 1.0 0.9)) (2))))
!(test (LimitSize ((Sentence (a (stv 1.0 0.5)) (1))
                   (Sentence (b (stv 1.0 0.9)) (2)))
                  1)
       ())

;And what it keeps is the HIGHEST priority, because it drops by the negated
;rank: bounding the queue is forgetting the least confident.
!(test (LimitSize ((Sentence (a (stv 1.0 0.1)) (1))
                   (Sentence (b (stv 1.0 0.9)) (2))
                   (Sentence (c (stv 1.0 0.5)) (3)))
                  3)
       ((Sentence (b (stv 1.0 0.9)) (2)) (Sentence (c (stv 1.0 0.5)) (3))))

;`NARS.Derive` is the loop those five build: take the highest-priority task,
;combine it with every belief whose stamp is disjoint, add what came out to
;both queues, bound them, and repeat until the step budget runs out. It
;answers the two queues it ends with, and it traces each selection.
;
;Two premises and two steps are enough to see it work: a --> b and b --> c
;deduce a --> c, whose stamp carries both IDs.
!(test (is-member (Sentence ((--> a c) (stv 1.0 0.81)) (1 2))
                  (index-atom (NARS.Derive ((Sentence ((--> a b) (stv 1.0 0.9)) (1)))
                                           ((Sentence ((--> b c) (stv 1.0 0.9)) (2)))
                                           2)
                              1))
       True)

;A step budget of zero derives nothing, so the belief queue comes back as it
;went in: the loop is bounded by a NUMBER rather than by a fixed point.
!(test (index-atom (NARS.Derive ((Sentence ((--> a b) (stv 1.0 0.9)) (1)))
                                ((Sentence ((--> b c) (stv 1.0 0.9)) (2)))
                                0)
                   1)
       ((Sentence ((--> b c) (stv 1.0 0.9)) (2))))

;And an empty task queue stops it whatever the budget is, because there is
;nothing left to select.
!(test (NARS.Derive () ((Sentence ((--> b c) (stv 1.0 0.9)) (2))) 100)
       (() ((Sentence ((--> b c) (stv 1.0 0.9)) (2)))))
