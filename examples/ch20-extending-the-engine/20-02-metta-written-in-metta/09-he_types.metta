; Purpose: observe exact type comparison and the resulting cast refusals.
; [tested: sh test.sh examples/ch20-extending-the-engine/20-02-metta-written-in-metta/09-he_types.metta; commit=WORKTREE].
; lib_he shadows the prelude locally with upstream's equations. Its
; match-types uses exact equality; type-cast remains an engine prelude head.
!(import! &self (library lib_he))

!(test (is-function (-> Atom Atom)) True)
!(test (is-function Atom) False)
;type-cast answers the atom when it has the type and (Error $atom BadType) when
;it does not. A matching metatype or declared type admits the atom;
;%Undefined% does not equal a requested type.
(: type1 Type)
(: A type1)

!(test (type-cast A type1 &self) A)
!(test (type-cast 1 type1 &self) (Error 1 BadType))

;A metatype counts, so any symbol casts to Symbol and any number to Grounded.
!(test (type-cast A Symbol &self) A)
!(test (type-cast 1 Number &self) 1)

; With exact match-types, an undeclared atom cannot satisfy this type claim.
!(test (type-cast B type1 &self) (Error B BadType))
; Upstream's == comparison neither admits Atom as a wildcard nor binds a
; variable-bearing type to a concrete instance.
!(test (match-types Atom Atom "Matched!" "Didn't match") "Matched!")
!(test (match-types Atom Number "Matched!" "Didn't match") "Didn't match")
!(test (match-types Bool Number "Matched!" "Didn't match") "Didn't match")
!(test (match-types (List $x) (List Number) "Matched!" "Didn't match") "Didn't match")
!(test (first-from-pair (A B)) A)
!(test (second-from-pair (A B)) B)
!(test (match-type-or True Number Bool) True)
