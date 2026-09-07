;PLN's derivation loop, and the priority queue under it. The same five ideas
;NARS uses -- a stamp, a ranking, a bounded queue, a step budget and a fold
;over beliefs -- written a second time inside lib_pln, over its own tuple
;helpers rather than over the engine's list operations.
!(import! &self (library lib_pln))

;The three configuration numbers, nullary equations so a program can define
;its own budget.
!(test (PLN.Config.MaxSteps) 100)
!(test (PLN.Config.TaskQueueSize) 10)
!(test (PLN.Config.BeliefQueueSize) 100)

;`StampDisjoint` is the rule that stops evidence being counted twice: two
;sentences combine only when no evidence ID appears in both.
!(test (StampDisjoint (1 2) (3 4)) True)
!(test (StampDisjoint (1 2) (2 3)) False)
!(test (StampDisjoint () (1)) True)

;`StampConcat` merges two stamps through `InsertionSort`, so the result is
;sorted and order-independent. An empty addition is the identity and leaves
;the stamp exactly as it was, unsorted included.
!(test (StampConcat (3 1) (2)) (1 2 3))
!(test (StampConcat (3 1) ()) (3 1))
!(test (== (StampConcat (1) (2)) (StampConcat (2) (1))) True)

;The three ranking functions, each two equations: a value and a sentinel for
;the empty tuple that lets the fold start with no candidate.
!(test (PriorityRank (Sentence (a (stv 1.0 0.9)) (1))) 0.9)
!(test (PriorityRank ()) -99999.0)
!(test (PriorityRankNeg (Sentence (a (stv 1.0 0.9)) (1))) -0.9)
!(test (PriorityRankNeg ()) -99999.0)
!(test (ConfidenceRank ((stv 1.0 0.9) (1))) 0.9)
!(test (ConfidenceRank ()) 0)

;`BestCandidate` takes the ranking as an argument, which is what makes one
;fold serve both "most confident" and "least confident".
!(test (BestCandidate PriorityRank ()
                      ((Sentence (a (stv 1.0 0.5)) (1))
                       (Sentence (b (stv 1.0 0.9)) (2))))
       (Sentence (b (stv 1.0 0.9)) (2)))
!(test (BestCandidate PriorityRankNeg ()
                      ((Sentence (a (stv 1.0 0.5)) (1))
                       (Sentence (b (stv 1.0 0.9)) (2))))
       (Sentence (a (stv 1.0 0.5)) (1)))
!(test (BestCandidate PriorityRank () ()) ())

;`LimitSize` drops the lowest-ranked item until the tuple fits, and its test
;is `(< (TupleCount $L) $size)`, so it leaves size MINUS ONE items. What
;survives is the highest-ranked, because it drops by the negated rank.
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

;`PLN.Derive` is the loop: take the highest-priority task, combine it with
;every belief whose stamp is disjoint, add the derivations to both queues,
;bound them, repeat. It answers the two queues it ends with.
;
;One implication and one fact are enough: modus ponens gives b at 1.0 with
;the two confidences multiplied, and the derived sentence carries both
;evidence IDs.
!(test (index-atom (PLN.Derive ((Sentence ((Implication a b) (stv 1.0 0.9)) (1)))
                               ((Sentence (a (stv 1.0 0.9)) (2)))
                               2)
                   1)
       ((Sentence (a (stv 1.0 0.9)) (2))
        (Sentence (b (stv 1.0 0.81)) (1 2))))

;A step budget of zero derives nothing, so both queues come back as they went
;in: the loop is bounded by a NUMBER rather than by a fixed point.
!(test (PLN.Derive ((Sentence ((Implication a b) (stv 1.0 0.9)) (1)))
                   ((Sentence (a (stv 1.0 0.9)) (2)))
                   0)
       (((Sentence ((Implication a b) (stv 1.0 0.9)) (1)))
        ((Sentence (a (stv 1.0 0.9)) (2)))))

;And an empty task queue stops it whatever the budget is, because there is
;nothing left to select.
!(test (PLN.Derive () ((Sentence (a (stv 1.0 0.9)) (2))) 100)
       (() ((Sentence (a (stv 1.0 0.9)) (2)))))

;`PLN.Query` is that loop with the answers filtered to one term and ranked by
;confidence, which is why `ConfidenceRank` is here rather than in the ranking
;pair above.
!(test (PLN.Query ((Sentence ((Implication a b) (stv 1.0 0.9)) (1))
                   (Sentence (a (stv 1.0 0.9)) (2)))
                  b
                  2)
       ((stv 1.0 0.81) (1 2)))
