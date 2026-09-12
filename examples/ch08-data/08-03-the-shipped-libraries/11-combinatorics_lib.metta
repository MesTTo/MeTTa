;lib_combinatorics: choosing from a finite collection, in both of the two
;shapes MeTTa offers for a set of answers. Each operation comes as a
;nondeterministic version answering one choice per solution and an `l`
;version answering the whole tuple, so a caller picks whether the choices
;stream or land.
!(import! &self (library lib_combinatorics))

;`choose2` answers every unordered pair, one per solution: (a b) but never
;(b a), and never (a a).
!(test (sort-atom (collapse (choose2 (a b c)))) ((a b) (a c) (b c)))
!(test (collapse (choose2 (a))) ())
!(test (collapse (choose2 ())) ())

;`choose2l` is that answer set collapsed, which is the same information as
;one value rather than as multiplicity.
!(test (choose2l (a b c)) ((a b) (a c) (b c)))
!(test (choose2l (a)) ())

;`chooseKl` generalises it to k of them, still unordered, still without
;repetition, and it counts down through the list rather than indexing into
;it, so the answers come out in the list's own order.
!(test (chooseKl (a b c) 2) ((a b) (a c) (b c)))
!(test (chooseKl (a b c d) 3) ((a b c) (a b d) (a c d) (b c d)))
!(test (== (chooseKl (a b c) 2) (choose2l (a b c))) True)

;The two base cases are what make the recursion total: choosing none of
;anything is one choice, the empty one, and choosing some of nothing is no
;choice at all.
!(test (chooseKl (a b c) 0) (()))
!(test (chooseKl () 2) ())
!(test (chooseKl () 0) (()))

;`chooseK` streams the same tuples, one per solution, which is what a search
;wants: the consumer can stop without the rest being built.
!(test (sort-atom (collapse (chooseK (a b c) 2))) ((a b) (a c) (b c)))
!(test (collapse (chooseK (a b c) 0)) (()))

;`takeK` is the prefix rather than a choice: the first k in order, and the
;whole list when there are fewer than k.
!(test (takeK 2 (a b c)) (a b))
!(test (takeK 0 (a b c)) ())
!(test (takeK 5 (a b c)) (a b c))
!(test (takeK 2 ()) ())

;`range` counts up from k to n, one number per answer, n excluded. `range-step`
;is the same walk with a stride, and a negative stride counts down; a stride of
;zero would never arrive, so it is refused.
!(test (collapse (range 0 4)) (0 1 2 3))
!(test (collapse (range-step 0 10 3)) (0 3 6 9))
!(test (collapse (range-step 5 0 -2)) (5 3 1))
!(test (collapse (range-step 0 0 1)) ())
!(test (collapse (range-step 0 5 -1)) ())
!(test (if-error (catch (collapse (range-step 0 5 0))) refused fine) refused)

;`permutations` answers every ordering, one per answer. A permutation counts
;POSITIONS, so a repeated item makes repeated answers.
!(test (collapse (permutations (a b c)))
       ((a b c) (a c b) (b a c) (b c a) (c a b) (c b a)))
!(test (collapse (permutations ())) (()))
!(test (size-atom (collapse (permutations (a a)))) 2)

;`subsets` answers the powerset, one subset per answer, each in the items' own
;order: 2^n of them, the whole set first and the empty one last.
!(test (collapse (subsets (a b))) ((a b) (b) (a) ()))
!(test (collapse (subsets ())) (()))
!(test (size-atom (collapse (subsets (a b c d)))) 16)

;`tuples` chooses one element from each set, which is the Cartesian product; the
;last set varies fastest. An empty set anywhere means no answers at all, and no
;sets at all mean one answer, the empty tuple.
!(test (collapse (tuples ((1 2) (x y)))) ((1 x) (1 y) (2 x) (2 y)))
!(test (collapse (tuples ((1 2) ()))) ())
!(test (collapse (tuples ())) (()))

;`cartesian-power` is the product of one set with itself k times, so repetition
;is allowed: every binary string of length three is the power of (0 1).
!(test (collapse (cartesian-power (0 1) 2)) ((0 0) (0 1) (1 0) (1 1)))
!(test (size-atom (collapse (cartesian-power (0 1) 3))) 8)
!(test (collapse (cartesian-power (a b) 0)) (()))

;The counts are exact and never build the choices they count, so a card deal is
;an ordinary number rather than a search.
!(test (factorial 5) 120)
!(test (factorial 0) 1)
!(test (binomial 5 2) 10)
!(test (binomial 52 5) 2598960)
!(test (binomial 5 0) 1)
!(test (binomial 5 9) 0)
!(test (permutation-count 5 2) 20)
!(test (permutation-count 5 5) (factorial 5))
!(test (permutation-count 5 0) 1)
!(test (if-error (catch (factorial -1)) refused fine) refused)

;And the counts agree with the enumerations, which is what makes them the same
;question asked two ways.
!(test (== (size-atom (collapse (permutations (a b c)))) (factorial 3)) True)
!(test (== (size-atom (collapse (chooseK (a b c d) 2))) (binomial 4 2)) True)
!(test (== (size-atom (collapse (subsets (a b c)))) (pow-math 2 3)) True)
!(test (== (size-atom (collapse (cartesian-power (a b) 3))) (pow-math 2 3)) True)
