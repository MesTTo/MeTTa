;A type does not have to be written in the file that uses it. `import!` brings
;a library's declarations in along with its equations, and `get-type` reads
;them back exactly as it reads the ones written above in this chapter: a
;declaration is an atom in the space, and an imported one is no different from
;a local one.
;
;lib_datastructures' finger tree is the example because its four declarations
;cover every shape a declaration takes: the type itself, a constructor that
;takes nothing, and two that take arguments.
!(import! &self (library lib_datastructures))

;`FTree` is declared `Type`, which is what makes the other three mean anything.
!(test (get-type FTree) Type)

;`FTEmpty` takes nothing, so its type is the type itself: it IS a tree rather
;than a way of making one. The other two are arrows, and their argument types
;say what each field holds: one atom for the single, and for the deep node a
;prefix digit, a middle tree and a suffix digit.
!(test (get-type FTEmpty) FTree)
!(test (get-type FTSingle) (-> Atom FTree))
!(test (get-type FTDeep) (-> Expression FTree Expression FTree))

;Applying one answers the type its arrow ends in, which is how trees built out
;of different constructors are all one type.
!(test (get-type (FTSingle 1)) FTree)
!(test (get-type (FTDeep (1 2) FTEmpty (3 4))) FTree)

;A nullary constructor is a SYMBOL, and that is the difference between writing
;it and calling it: `FTEmpty` is the value, and wrapping it in brackets would
;be a one-element expression rather than the atom the library means. Which is
;why the corpus never writes that form: the coverage lane reads call position
;out of the text, and a one-element expression and a nullary call are the same
;characters, so `FTEmpty` and `FTree` are allowlisted rather than covered.
!(test (get-metatype FTEmpty) Symbol)
!(test (get-metatype (FTSingle 1)) Expression)

;The argument types are checked, and an application that does not fit has no
;type at all rather than a wrong one: a third argument the arrow has no room
;for, and a number where the prefix digit has to be an expression.
!(test (collapse (get-type (FTSingle 1 2))) ())
!(test (collapse (get-type (FTDeep 1 FTEmpty (3 4)))) ())
