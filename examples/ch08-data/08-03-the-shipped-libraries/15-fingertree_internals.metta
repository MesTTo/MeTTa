;The finger tree from the inside. `02-datastructures_fingertree.metta` uses
;the shipped surface, push and pop and concat; this file opens the structure
;those are written over, because a 2-3 finger tree's cost claims come from
;its shape rather than from its interface.
;
;A tree is one of three constructors. `FTEmpty` is the empty one, written as
;a bare symbol because it takes nothing. `FTSingle` holds one element.
;`FTDeep` holds a prefix digit, a middle tree of grouped nodes, and a suffix
;digit; the digits are plain expressions of one to four elements, and that
;bound is what every clause below is a case of.
;[source: Hinze & Paterson, "Finger trees: a simple general-purpose data
;structure", JFP 16(2), 2006]
!(import! &self (library lib_datastructures))

;The constructors are ordinary data, so a tree can be written out by hand and
;read back with the same operations that build one.
!(test (ft-to-list (FTSingle 1)) (1))
!(test (ft-to-list (FTDeep (1 2) FTEmpty (3 4))) (1 2 3 4))
!(test (ft-is-empty FTEmpty) True)
!(test (ft-is-empty (FTSingle 1)) False)

;`FTree` is the type all three answer to, and `FTEmpty` is the only one of
;the three that takes nothing, so it is written bare where the other two are
;applied. Neither is ever a call, which is why the corpus-coverage lane
;carries both by name.
!(test (get-type FTEmpty) FTree)
!(test (get-type FTSingle) (-> Atom FTree))
!(test (get-type FTDeep) (-> Expression FTree Expression FTree))

;`ft-node-digit` turns a middle-level node back into a digit. It is the step
;that lets a node drop one level when the level above it drains.
!(test (ft-node-digit (FTNode2 a b)) (a b))
!(test (ft-node-digit (FTNode3 a b c)) (a b c))

;`ft-borrow-l` is the pop that empties a prefix: with an empty middle it
;redistributes the suffix and the tree gets shallower, and with a nonempty
;middle it takes one node from the front of the middle and spreads it as the
;new prefix.
!(test (ft-borrow-l FTEmpty (a)) (FTSingle a))
!(test (ft-borrow-l FTEmpty (a b)) (FTDeep (a) FTEmpty (b)))
!(test (ft-borrow-l FTEmpty (a b c d)) (FTDeep (a b) FTEmpty (c d)))
!(test (ft-borrow-l (FTSingle (FTNode2 a b)) (c)) (FTDeep (a b) FTEmpty (c)))

;`ft-borrow-r` is its mirror on the suffix, and it takes its arguments in the
;mirrored order: the prefix first, then the middle.
!(test (ft-borrow-r (a) FTEmpty) (FTSingle a))
!(test (ft-borrow-r (a b) FTEmpty) (FTDeep (a) FTEmpty (b)))
!(test (ft-borrow-r (a) (FTSingle (FTNode2 b c))) (FTDeep (a) FTEmpty (b c)))

;Between them they are why a pop is amortized constant: the expensive case
;moves ONE node one level, and it can only happen after four cheap pops
;filled the digit it drains.
!(test (ft-to-list (ft-borrow-l (FTSingle (FTNode3 a b c)) (d))) (a b c d))

;`ft-nodes` is the regrouping concatenation needs: a list of loose elements
;becomes 2-3 nodes, peeling three at a time and leaving two, three or four
;for the base rows, so no node is ever a singleton.
!(test (ft-nodes (1 2)) ((FTNode2 1 2)))
!(test (ft-nodes (1 2 3)) ((FTNode3 1 2 3)))
!(test (ft-nodes (1 2 3 4)) ((FTNode2 1 2) (FTNode2 3 4)))
!(test (ft-nodes (1 2 3 4 5)) ((FTNode3 1 2 3) (FTNode2 4 5)))
!(test (ft-nodes (1 2 3 4 5 6)) ((FTNode3 1 2 3) (FTNode3 4 5 6)))

;`ft-push-list-front` and `ft-push-list-back` push a whole expression one
;element at a time, and the two differ in the order the elements end up in:
;pushing (1 2) onto the front of (3 4) keeps 1 first, pushing it onto the
;back puts 1 after everything already there.
!(test (ft-to-list (ft-push-list-front (1 2) (ft-from-list (3 4)))) (1 2 3 4))
!(test (ft-to-list (ft-push-list-back (1 2) (ft-from-list (3 4)))) (3 4 1 2))
!(test (ft-to-list (ft-push-list-front () (ft-from-list (3 4)))) (3 4))
!(test (ft-to-list (ft-push-list-back () (ft-from-list (3 4)))) (3 4))

;`ft-app3` is the operation finger trees exist for: two trees and a list of
;loose elements between them, joined in O(log n) rather than in O(n). It
;walks both spines together, regroups what falls between them with
;`ft-nodes`, and sinks the result one level.
!(test (ft-to-list (ft-app3 (ft-from-list (1 2)) (7 8) (ft-from-list (3 4))))
       (1 2 7 8 3 4))
!(test (ft-to-list (ft-app3 FTEmpty (7 8) (ft-from-list (3 4)))) (7 8 3 4))
!(test (ft-to-list (ft-app3 (ft-from-list (1 2)) () FTEmpty)) (1 2))
!(test (ft-to-list (ft-app3 FTEmpty () FTEmpty)) ())

;`ft-concat` is `ft-app3` with nothing in the middle, which is why the
;shipped surface has one operation where the recursion needs three arguments.
!(test (== (ft-to-list (ft-concat (ft-from-list (1 2)) (ft-from-list (3 4))))
           (ft-to-list (ft-app3 (ft-from-list (1 2)) () (ft-from-list (3 4)))))
       True)
