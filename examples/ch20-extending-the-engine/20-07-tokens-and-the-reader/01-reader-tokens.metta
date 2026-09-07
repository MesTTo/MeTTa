;The reader is an extension seam too. `register-token!` binds a regular
;expression to a constructor, and from then on any TOKEN the reader meets
;that matches the pattern is read as `(<constructor> "<the text>")` instead
;of as a symbol. That is how `12px` becomes data without `12px` being
;anything the grammar knows.
;
;The shipped classes are exactly this mechanism: numbers and strings are four
;registered patterns, and a custom one is looked up before them.

;Before registering, a token that is not a number and not a string is a
;SYMBOL, whatever it looks like.
!(test (repr (parse "12px")) "12px")

;Registering is one call, and it answers True.
!(test (register-token! "[0-9]+px" Pixels) True)

;Now the same text reads as an application of the constructor to the token's
;own text. The text arrives as a String, so the constructor sees exactly what
;was written rather than a parsed value.
!(test (repr (parse "12px")) "(Pixels \"12px\")")

;It is a TOKEN rule rather than a form rule, so it fires wherever a token can
;appear and the rest of the form reads normally.
!(test (repr (parse "(width 12px)")) "(width (Pixels \"12px\"))")
!(test (repr (parse "(box 12px 4px)")) "(box (Pixels \"12px\") (Pixels \"4px\"))")

;The pattern is anchored at both ends, so it classifies a whole token or none
;of it: `12pxy` is not `12px` followed by `y`.
!(test (repr (parse "12pxy")) "12pxy")
!(test (repr (parse "px")) "px")

;A second pattern is a second class, and the two do not interfere.
!(test (register-token! "[0-9]+%" Percent) True)
!(test (repr (parse "(size 50% 12px)"))
       "(size (Percent \"50%\") (Pixels \"12px\"))")

;Registering the same pattern again REPLACES its constructor rather than
;adding a second class, because a token has one reading.
!(test (register-token! "[0-9]+px" Device) True)
!(test (repr (parse "12px")) "(Device \"12px\")")

;`unregister-token!` takes the pattern back out, and the text is an ordinary
;symbol again. Unregistering a pattern that is not there answers True rather
;than raising, so a cleanup path does not have to check first.
!(test (unregister-token! "[0-9]+px") True)
!(test (repr (parse "12px")) "12px")
!(test (unregister-token! "[0-9]+px") True)
!(test (repr (parse "50%")) "(Percent \"50%\")")
!(test (unregister-token! "[0-9]+%") True)
!(test (repr (parse "50%")) "50%")

;A pattern that is not text is refused by the operation's own name, because a
;token pattern is a regular expression and there is nothing else it could be.
!(test (repr (catch (register-token! 12 Pixels)))
       "(Error (type_error text 12) (context register-token! a token pattern is text))")

;And a constructor that could not be written back is refused too: the reader
;has to be able to spell what it builds.
!(test (repr (catch (register-token! "[0-9]+em" "not a symbol")))
       "(Error (domain_error metta_reader_constructor \"not a symbol\") (context (/ register-token! 3) the constructor must be a readable symbol))")
