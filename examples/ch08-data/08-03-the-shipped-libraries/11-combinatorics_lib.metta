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
