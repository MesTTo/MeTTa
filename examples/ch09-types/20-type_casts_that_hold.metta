;`type-cast-holds` is the question `type-cast` asks before it decides: does
;any declared type of this atom, in this space, unify with the one asked
;about? It answers a Bool, so it composes with `if` where `type-cast`
;answers the atom or an error.

(: five Number)
(: greeting String)
(: twice (-> Number Number))
(= (twice $x) (* 2 $x))

;A declared symbol holds its own type and nothing else.
!(test (type-cast-holds five Number &self) True)
!(test (type-cast-holds five Bool &self) False)
!(test (type-cast-holds greeting String &self) True)

;A literal carries its type without a declaration, so the question is the
;same one for data and for names.
!(test (type-cast-holds 1 Number &self) True)
!(test (type-cast-holds "text" String &self) True)
!(test (type-cast-holds 1 String &self) False)

;An arrow is a type like any other, so a function is asked about the same
;way, with the whole arrow as the second argument.
!(test (type-cast-holds twice (-> Number Number) &self) True)
!(test (type-cast-holds twice (-> String String) &self) False)

;`%Undefined%` unifies with everything, which is what makes it the gradual
;default rather than a type: an atom nothing declares answers True for any
;question, because it has no declared type to contradict one.
!(test (type-cast-holds five %Undefined% &self) True)
!(test (type-cast-holds undeclared-name Number &self) True)
!(test (type-cast-holds undeclared-name String &self) True)

;The space is the third argument and it is the context the declarations are
;read from, so the same atom answers differently in two spaces.
!(add-atom &other (: five String))
!(test (type-cast-holds five String &other) True)
!(test (type-cast-holds five String &self) False)

;`type-cast` is this question with the atom or an error as its answer, so the
;pair is a predicate and its enforcing twin.
!(test (type-cast 1 Number &self) 1)
!(test (type-cast five Bool &self) (Error five BadType))
!(test (if (type-cast-holds five Bool &self) yes no) no)
