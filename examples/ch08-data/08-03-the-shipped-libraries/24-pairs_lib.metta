; Purpose: a collection of (Key Value) pairs read as a relation.
; [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/24-pairs_lib.metta; commit=40b3353b9ae721bf42b832fb953e93a5dc230e6c].
!(import! &self (library lib_pairs))

; A relation is a collection of two-element expressions, so nothing has to be
; built: this one holds three sales, one city twice.
!(bind! &sales ((sydney 120) (perth 90) (sydney 30)))

; `pairs-is` asks whether a collection is a relation; every other head asks the
; same question and names the element that is not a pair.
!(test (pairs-is &sales) True)
!(test (pairs-is ((a 1) (b))) False)
!(test (pairs-is ()) True)
!(test (pairs-is 7) False)

; The two projections keep order and keep duplicates, so their length is the
; relation's own. lib_functional's `unzip` answers both sides at once.
!(test (pairs-keys &sales) (sydney perth sydney))
!(test (pairs-values &sales) (120 90 30))
!(test (pairs-keys ()) ())

; `pairs-swap` is the converse relation with the order kept, which is how a
; lookup by value is written: swap, then look up.
!(test (pairs-swap &sales) ((120 sydney) (90 perth) (30 sydney)))
!(test (pairs-swap (pairs-swap &sales)) ((sydney 120) (perth 90) (sydney 30)))

; Both orderings are STABLE, so the two sydney rows keep their relative order
; under a sort by key, and nothing is dropped.
!(test (pairs-sort-by-key &sales) ((perth 90) (sydney 120) (sydney 30)))
!(test (pairs-sort-by-value &sales) ((sydney 30) (perth 90) (sydney 120)))
!(test (pairs-sort-by-key ((b 1) (a 2) (b 0) (a 1)))
       ((a 2) (a 1) (b 1) (b 0)))

; `pairs-group` reads the relation as a multimap: every key once, in the standard
; order of terms, with every value it has. It sorts by key ITSELF, because the
; host's grouping gathers only adjacent pairs and would answer sydney twice here.
!(test (pairs-group &sales) ((perth (90)) (sydney (120 30))))
!(test (pairs-group ()) ())
!(test (pairs-group ((a 1))) ((a (1))))

; `pairs-ungroup` inverts it, so a round trip is the relation sorted by key.
!(test (pairs-ungroup (pairs-group &sales)) ((perth 90) (sydney 120) (sydney 30)))
!(test (pairs-ungroup ((a (1 2)) (b ()))) ((a 1) (a 2)))
!(test (pairs-ungroup ()) ())

; `pairs-lookup` answers once per value the key has, in the relation's order, so
; a key with two values is a superposition of two answers and an absent key is
; no answer at all.
!(test (collapse (pairs-lookup &sales sydney)) (120 30))
!(test (collapse (pairs-lookup &sales perth)) (90))
!(test (collapse (pairs-lookup &sales darwin)) ())
; An absent key really is NO answer rather than an empty one, which is the
; difference a collapse makes visible and what an `if` over it reads.
!(test (if (== () (collapse (pairs-lookup &sales darwin))) none found) none)
!(test (if (== () (collapse (pairs-lookup &sales perth))) none found) found)
; A key is compared as a TERM, so a variable matches nothing, where a match
; against the same collection would have bound it to the first key.
!(test (collapse (pairs-lookup &sales $city)) ())

; The refusals name the element that is not a pair, which is the whole of the
; repair when a relation is built by hand.
!(test (if-error (catch (pairs-keys ((a 1) b))) refused fine) refused)
!(test (if-error (catch (pairs-group ((a 1) (b 2 3)))) refused fine) refused)
!(test (if-error (catch (pairs-lookup 7 a)) refused fine) refused)
!(test (if-error (catch (pairs-ungroup ((a 1)))) refused fine) refused)
