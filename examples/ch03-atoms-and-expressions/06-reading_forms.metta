;Telling "still typing" apart from "that is wrong".
;
;(sread $text) answers one way: it parses or it raises. Four different
;situations collapse into that one outcome, and a console needs them apart.
;CPython names this as THE hard part of a console, and answers it three ways:
;"The tricky part is to determine when the user has entered an incomplete
;command that can be completed by entering more text (as opposed to a
;complete command or a syntax error)."
;
;(parse-command $text) is that contract: (complete $term), incomplete, or a
;raise. It has no I/O in it, so a console, an editor and a notebook kernel
;share the answer without sharing a read loop.

!(test (parse-command "(f a)") (complete (f a)))

;Still typing. More text could finish any of these.
!(test (parse-command "(f a") incomplete)
!(test (parse-command "(a (b (c") incomplete)
!(test (parse-command "(= (f $x)") incomplete)

;An empty line re-prompts rather than erroring, which is the commonest input
;in any console.
!(test (parse-command "") incomplete)
!(test (parse-command "   ") incomplete)
!(test (parse-command "; only a comment") incomplete)

;A bare atom is a whole form.
!(test (parse-command "hello") (complete hello))

;Not "just count parens", which is why this is worth having rather than
;leaving every console to write it again: a bracket inside a string or a
;comment must not count.
!(test (parse-command "(f \"a)b\")") (complete (f "a)b")))
!(test (parse-command "(f a) ; )))") (complete (f a)))

;An unterminated string IS incomplete, because a MeTTa string may span lines.
!(test (parse-command "(f \"a") incomplete)

;One bracket too many is not incomplete: no amount of further typing repairs
;it, so the reader's own error is the answer.
!(import! &self (library lib_he))
!(test (if-error (catch (parse-command "(f a))")) Error NoError) Error)

;(sread $text) is the reader `parse-command` is written over, and it is the
;one that answers a term or raises. The two agree on everything that parses.
!(test (repr (sread "(f a)")) "(f a)")
!(test (repr (sread "hello")) "hello")
!(test (repr (sread "42")) "42")
!(test (repr (sread "(f \"a)b\")")) "(f \"a)b\")")

;Which is the whole reason `parse-command` exists: `sread` cannot tell a
;half-typed form from a wrong one, because both of them raise.
!(test (if-error (catch (sread "(f a")) Error NoError) Error)
!(test (if-error (catch (sread "(f a))")) Error NoError) Error)
!(test (parse-command "(f a") incomplete)

;(read-form!) is the buffering half, reading until the brackets balance. It
;needs a console, so examples/ch14-seeing-your-program/02-repl.metta is where it is shown.
