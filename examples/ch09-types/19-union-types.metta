;A union type, `(| A B ...)`, is a type whose values are the values of any one
;of its members. Write it wherever a type goes: an argument, a result, a field
;of a tuple, the right side of an alias.

(: union-id (-> (| Number String) %Undefined%))
(= (union-id $x) $x)

!(test (union-id 1) 1)
!(test (union-id "s") "s")

;A value of no member is refused at the same door every other type refuses at,
;and the refusal names the union as it was written.
!(test (union-id True)
       (Error (union-id True) (BadArgType 1 (| Number String) Bool)))

;`|` heads a union only where a TYPE is read. Everywhere else it is an ordinary
;symbol, which is what keeps `(|-> ($x) ...)` a lambda and `(| a b)` data.
!(test (| a b) (| a b))
!(test (let $f (|-> ($x) (+ $x 1)) ($f 2)) 3)

;The direction matters, and the two directions are different rules.
;
;A value against a required union needs SOME member to fit. A value whose own
;type is a union needs EVERY alternative to fit, because the value could be any
;of them: `v` is a Number or a String, so it goes where both are welcome and
;not where only one is.
(: v (| Number String))

(: wide (-> (| Number String Bool) %Undefined%))
(= (wide $x) accepted)
!(test (wide v) accepted)

(: narrow (-> (| Number Bool) %Undefined%))
(= (narrow $x) accepted)
!(test (narrow v)
       (Error (narrow v)
              (BadArgType 1 (| Number Bool) (| Number String))))

;A result type is checked the same way, and reported as it was written.
(: reading (-> Atom (| Number String)))
(= (reading $x) $x)
!(test (reading 1) 1)
!(test (reading "s") "s")
!(test (get-type (reading 1)) (| Number String))
!(test (collapse (reading True)) ())

;Nested inside a tuple, a union decides its own position and nothing else.
(: labelled (-> ((| Number String) Bool) %Undefined%))
(= (labelled $x) $x)
!(test (labelled (1 True)) (1 True))
!(test (labelled ("s" True)) ("s" True))
!(test (labelled (True True))
       (Error (labelled (True True))
              (BadArgType 1 ((| Number String) Bool) (Bool Bool))))

;An alias may name a union, and a union may name an alias. Nested unions are
;flattened and a member written twice is the same member, so a union is never a
;reason for an answer to arrive twice.
(: Count (Alias Number))
(: Scalar (Alias (| Count String)))

(: scalar-id (-> Scalar %Undefined%))
(= (scalar-id $x) $x)
!(test (scalar-id 1) 1)
!(test (scalar-id "s") "s")

(: twice (-> (| Number Number) %Undefined%))
(= (twice $x) seen)
!(test (collapse (twice 7)) (seen))

;A value that fits two members at once still answers once: `1` is a Number and
;every value is an Atom, and the call is made once either way.
(: either (-> (| Atom Number) %Undefined%))
(= (either $x) seen)
!(test (collapse (either 1)) (seen))

;A member may be a supertype, and the value reaches it the way it always has,
;through its widened type list rather than through a rule about subtyping.
(: Rex2 Dog2)
(:< Dog2 Animal2)
(: pet (-> (| Animal2 Number) %Undefined%))
(= (pet $x) accepted)
!(test (pet Rex2) accepted)
!(test (pet 1) accepted)

;A type VARIABLE inside a union is assigned once for the whole call. Here the
;first argument fits either alternative, and which one it takes is decided by
;what the second argument needs: taking `$t` would fix `$t` to Bool and leave
;`1` with nowhere to go, so the check comes back and takes `Bool` instead.
(: paired (-> (| $t Bool) $t %Undefined%))
(= (paired $a $b) accepted)
!(test (paired True 1) accepted)
!(test (paired 1 2) accepted)
!(test (paired "s" 1) (Error (paired "s" 1) (BadArgType 2 String Number)))

;What a union does NOT do is narrow. Testing a union-typed value tells the
;checker nothing about the branch it is in, so `get-type` still answers the
;union afterwards and a later argument still has to satisfy the whole of it.
;Typed Racket keeps the two apart the same way: unions are a type constructor,
;and occurrence typing is the separate mechanism that refines one.
!(assertEqual (get-type v) (| Number String))
!(test (if (== v v) (get-type v) nothing) (| Number String))
