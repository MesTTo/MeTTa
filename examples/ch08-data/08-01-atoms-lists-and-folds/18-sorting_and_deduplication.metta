;Four operations over an expression that all look like "tidy this up" and are
;each a different question: `sort`, `list_to_set`, `exclude-item`, and
;`alpha-unique` over an answer stream.
;
;`sort` is SWI's sort/2: the standard order of terms, with duplicates
;REMOVED. `sort-atom` orders and keeps them, and `msort` keeps them too, so
;the three differ only in what they do with equals.
!(test (sort (3 1 2 1)) (1 2 3))
!(test (sort-atom (3 1 2 1)) (1 1 2 3))
!(test (msort (3 1 2 1)) (1 1 2 3))
!(test (sort ()) ())

;The order is the standard order of terms rather than a numeric one, so
;mixed content still has one total order: numbers, then strings, then names.
!(test (sort (b a 10 2 "s")) (2 10 "s" a b))

;`list_to_set` removes duplicates and keeps the ORIGINAL order, which is what
;you want when the sequence means something and only the repeats do not.
!(test (list_to_set (b a b c a)) (b a c))
!(test (list_to_set (3 1 2 1)) (3 1 2))
!(test (list_to_set ()) ())

;`exclude-item` drops one named item wherever it appears, item first and list
;second. An item that is not there is not an error; the list comes back whole.
!(test (exclude-item 2 (1 2 3 2)) (1 3))
!(test (exclude-item x (1 2 3)) (1 2 3))
!(test (exclude-item 1 (1 1 1)) ())

;`alpha-unique` is the same idea over an answer STREAM rather than an
;expression, and it deduplicates up to a consistent renaming of variables.
;`unique` beside it compares atoms exactly, so two answers that differ only
;in a variable's name both survive there and only one survives here.
!(test (collapse (unique (superpose ((f $x) (f $y) (g $z)))))
       ((f $a) (f $b) (g $c)))
!(test (collapse (alpha-unique (superpose ((f $x) (f $y) (g $z)))))
       ((f $a) (g $b)))

;A ground answer is only alpha-equivalent to itself, so on ground data the
;two agree.
!(test (collapse (alpha-unique (superpose (1 2 1 3)))) (1 2 3))
!(test (collapse (unique (superpose (1 2 1 3)))) (1 2 3))

;And a variable answer is not the same as the ground one it would unify
;with: (f $x) and (f 1) are two answers, not one.
!(test (collapse (alpha-unique (superpose ((f $x) (f $y) (f 1)))))
       ((f $a) (f 1)))
