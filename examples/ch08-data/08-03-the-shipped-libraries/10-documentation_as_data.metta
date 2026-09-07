;Documentation here is atoms, so reading it is matching rather than a tool.
;`@doc` writes it, `get-doc` reads it, and the six operations below are the
;rest of that surface: what a space has documented, what it has not, and the
;three shapes the same document comes back in.
;
;This file imports nothing, because every operation here reports on the
;space it is asked about and an import would put another library's names in
;the answers.

(@doc twice
      (@desc "Doubles a number")
      (@params ((@param "the number")))
      (@return "twice it"))
(: twice (-> Number Number))
(= (twice $x) (* 2 $x))

(= (undocumented-here $x) $x)

;`defined-name` answers every head this space holds an equation for, once
;each. Builtins are not in it: they are not equations, and nothing filters
;them out because nothing puts them in. The answers are compared through
;`repr`, because a tuple of function NAMES written in the expected position
;would be read as a call to the first of them, and the collapsed set is
;NAMED by a `let` first, because `repr` and `sort-atom` take their operand as
;written and would otherwise be handed the call rather than its answers.
!(test (let $names (collapse (defined-name)) (repr (sort-atom $names)))
       "(twice undocumented-here)")

;`documented` and `undocumented` split that list on whether a `@doc` atom
;names the head.
!(test (let $names (collapse (documented)) (repr $names)) "(twice)")
!(test (let $names (collapse (undocumented-space &self)) (repr $names))
       "(undocumented-here)")

;Each has a spelling that takes the space explicitly, for asking about a
;space that is not the one you are running in.
!(test (let $names (collapse (documented-space &self)) (repr $names)) "(twice)")
!(add-atom &empty (= (f $x) $x))
!(test (let $names (collapse (documented-space &empty)) (repr $names)) "()")
!(test (let $names (collapse (undocumented-space &empty)) (repr $names)) "(f)")

;`get-doc-space` answers the `@doc` atom AS WRITTEN, which is what a program
;editing documentation wants: the same shape it would add.
!(test (get-doc-space &self twice)
       (@doc twice
             (@desc "Doubles a number")
             (@params ((@param "the number")))
             (@return "twice it")))

;`get-doc-atom` answers the FORMAL shape instead, one `@type` beside every
;description, and it fills those types from the atom alone: nothing is
;looked up, so every slot is the gradual default.
!(test (get-doc-atom &self twice)
       (@doc-formal (@item twice)
                    (@kind function)
                    (@type %Undefined%)
                    (@desc "Doubles a number")
                    (@params ((@param (@type %Undefined%) (@desc "the number"))))
                    (@return (@type %Undefined%) (@desc "twice it"))))

;`get-doc-single-atom` is the same formal shape with the DECLARED type read
;out of the space and spread across the parameters, so the arrow above
;decides what each `@type` says.
!(test (get-doc-single-atom &self twice)
       (@doc-formal (@item twice)
                    (@kind function)
                    (@type (-> Number Number))
                    (@desc "Doubles a number")
                    (@params ((@param (@type Number) (@desc "the number"))))
                    (@return (@type Number) (@desc "twice it"))))

;`get-doc-function` takes the arrow as an argument rather than looking it up,
;which is the door a caller uses when the type is computed or when the same
;name is documented at two arities.
!(test (== (get-doc-function &self twice (-> Number Number))
           (get-doc-single-atom &self twice))
       True)
!(test (get-doc-function &self twice (-> String String))
       (@doc-formal (@item twice)
                    (@kind function)
                    (@type (-> String String))
                    (@desc "Doubles a number")
                    (@params ((@param (@type String) (@desc "the number"))))
                    (@return (@type String) (@desc "twice it"))))

;`get-doc-params` is the step those three share, and it is callable on its
;own: parameter descriptions, a return description and a list of types in,
;the formal parameter list and the formal return out.
!(test (get-doc-params ((@param "the number")) (@return "twice it") (Number Number))
       (((@param (@type Number) (@desc "the number")))
        (@return (@type Number) (@desc "twice it"))))
!(test (get-doc-params () (@return "nothing to say") (Bool))
       (() (@return (@type Bool) (@desc "nothing to say"))))

;`help!` prints the document rather than answering it, which is what a person
;at a console wants and what a program never does. It answers the unit, and
;this file's own output carries the two documents it prints.
!(test (help! twice) ())
!(test (help! undocumented-here) ())
