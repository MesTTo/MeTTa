;Two space operations that finish the write and read family: `add-reducts`,
;which is `add-atoms` with each element EVALUATED on the way in, and
;`space-contains`, which asks about one atom without opening a query.
;
;`add-atoms` stores what you wrote. The space then holds calls, and a match
;against them matches the call rather than its answer.
!(add-atoms &written ((+ 1 1) (* 2 3)))
!(test (repr (collapse (get-atoms &written))) "((+ 1 1) (* 2 3))")

;`add-reducts` is the same door with the elements reduced first, so the space
;holds answers. It is `add-reduct` over a list, the way `add-atoms` is
;`add-atom` over one.
!(add-reducts &reduced ((+ 1 1) (* 2 3)))
!(test (repr (collapse (get-atoms &reduced))) "(2 6)")
!(add-reduct &single (+ 1 1))
!(test (repr (collapse (get-atoms &single))) "(2)")

;Which of the two you want is the difference between a space of FACTS and a
;space of PROGRAM: the reduced one answers a query about 2, and the written
;one answers a query about the expression that computes it.
!(test (collapse (match &reduced 2 found)) (found))
!(test (collapse (match &written 2 found)) ())
!(test (collapse (match &written (+ 1 1) found)) (found))

;`space-contains` answers True or False for one atom, and its atom argument
;is held: (+ 1 1) is the question "is this expression in the space", not "is
;2 in the space".
!(test (space-contains &reduced 2) True)
!(test (space-contains &reduced 99) False)
!(test (space-contains &written (+ 1 1)) True)
!(test (space-contains &written 2) False)

;It asks about UNIFICATION rather than identity, so a stored atom with a
;variable in it answers True for every atom that variable could stand for.
!(add-atom &written (edge $a $b))
!(test (space-contains &written (edge a b)) True)
!(test (space-contains &written (edge $x $y)) True)
!(test (space-contains &written (node a)) False)

;The difference from a match is what comes back rather than what is asked: a
;match binds and enumerates, this answers one Bool and binds nothing, which
;is one indexed probe against the store however many atoms it holds.
!(test (collapse (match &written (edge $x $y) ($x $y))) (($x $y)))
!(test (space-contains &written (edge a b)) True)
