;The previous file read a metatype off the SHAPE of a term: an expression is
;an Expression, a number is Grounded, a variable is a Variable. A bare NAME is
;the one case shape cannot answer, and this is the rule that does.
;
;    sh run.sh examples/ch09-types/07-metatype_of_a_name.metta
;
;A name is Grounded when the engine holds a FUNCTION for it, and a Symbol when
;it does not. That is the whole rule and there is no list of special names
;behind it.

;`+` is Grounded because the engine adds. `car-atom` is Grounded for the same
;reason, though it reads like ordinary list vocabulary rather than machinery.
!(test (get-metatype +) Grounded)
!(test (get-metatype car-atom) Grounded)

;A special form is compiled by the translator rather than defined as a
;function, so there is no function to hold and it is a Symbol. `if` and
;`chain` are as central to the language as `car-atom` and answer the other
;way, which is the clearest sign that the question is about the REGISTER and
;not about how important the name is.
!(test (get-metatype if) Symbol)
!(test (get-metatype chain) Symbol)

;A name nothing has given meaning to is a Symbol.
!(test (get-metatype no-such-operation) Symbol)

;And it is a fact about YOUR PROGRAM rather than about the language. `double`
;has an equation, so the engine holds a function for it and its name is
;Grounded. `colour` is only ever written as data, so nothing holds it and it
;stays a Symbol.
(= (double $x) (* 2 $x))
(colour sky blue)

!(test (double 21) 42)
!(test (get-metatype double) Grounded)
!(test (get-metatype colour) Symbol)

;To watch a name CROSS, write the equation at run time rather than as a form
;of the file: a file's equations are all compiled before any of its ! forms
;run, so a check written above one of them already sees the function.
!(test (get-metatype triple) Symbol)
!(add-atom &self (= (triple $x) (* 3 $x)))
!(test (get-metatype triple) Grounded)
!(test (triple 5) 15)

;A space handle is a name too, so it follows the same rule and answers Symbol.
;What says a handle is a space is its TYPE, which is the question to ask when
;you want the species of a value rather than the state of its name.
!(test (get-metatype &self) Symbol)
!(test (get-type &self) SpaceType)
