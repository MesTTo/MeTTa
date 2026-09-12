; Purpose: grammars as values, and what running one over text answers.
; [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/27-parsing_lib.metta; commit=WORKTREE].
!(import! &self (library lib_parsing))
; lib_unicode is beside it for the one primitive that takes a FUNCTION: the
; classes here are ASCII, and a Unicode class is (char-if f) over unicode-is.
!(import! &self (library lib_unicode))

; A grammar is an expression, and `grammar-parse` runs it over the whole text.
; Every way it matches is an answer, so a grammar that does not match answers
; NOTHING rather than raising, which is what makes the combinators compose.
!(test (grammar-parse (lit "ab") "ab") "ab")
!(test (collapse (grammar-parse (lit "ab") "ax")) ())
!(test (collapse (grammar-parse (lit "ab") "abc")) ())

; The primitives. A leaf answers the text it matched, except the two numbers,
; which answer the number, and `eos`, which answers ().
!(test (grammar-parse (any) "x") "x")
!(test (grammar-parse (char-in "aeiou") "e") "e")
!(test (collapse (grammar-parse (char-in "aeiou") "z")) ())
!(test (grammar-parse (char-not-in "aeiou") "z") "z")
!(test (grammar-parse (digits) "1024") "1024")
!(test (grammar-parse (integer) "-42") -42)
!(test (grammar-parse (number) "3.5") 3.5)
!(test (grammar-parse (nonblanks) "word") "word")
!(test (grammar-parse (blanks) "  ") "  ")
!(test (grammar-parse (blanks) "") "")
!(test (grammar-parse (until ",") "ab") "ab")
!(test (grammar-parse (quoted) "\"a\\nb\"") "a\nb")
!(test (grammar-parse (rest) "whatever") "whatever")
!(test (grammar-parse (eos) "") ())

; `char-if` takes a FUNCTION, applied where the grammar was written, so a class
; the primitives do not have is one line: this is Unicode's own letter class,
; which holds for a letter no ASCII test would accept.
(= (letter? $c) (unicode-is $c letter))
!(test (grammar-parse (many1 (char-if letter?)) "héllo") ("h" "é" "l" "l" "o"))
!(test (collapse (grammar-parse (char-if letter?) "1")) ())

; `cat` runs its parts in turn and answers their values; `skip` drops one, so a
; separator contributes nothing to the answer.
!(test (grammar-parse (cat (digits) (lit "-") (digits)) "12-34") ("12" "-" "34"))
!(test (grammar-parse (cat (digits) (skip (lit "-")) (digits)) "12-34") ("12" "34"))
!(test (grammar-parse (cat (skip (lit "#")) (rest)) "#tag") ("tag"))

; `alt` answers once per branch that matches, which is a superposition and not a
; first-match choice: a grammar that is ambiguous says so.
; Both branches match "12" here, so the grammar answers twice and a collapse is
; what shows it: an ambiguous grammar says so rather than choosing.
!(test (collapse (grammar-parse (alt (digits) (nonblanks)) "12")) ("12" "12"))
!(test (collapse (grammar-parse (alt (lit "a") (lit "b")) "a")) ("a"))
!(test (collapse (grammar-parse (alt (any) (rest)) "x")) ("x" "x"))
!(test (collapse (grammar-parse (alt (lit "a") (lit "b")) "c")) ())

; `many` and `many1` repeat, longest match first; `optional` answers (V) or ().
!(test (grammar-parse (many (char-in "ab")) "aab") ("a" "a" "b"))
!(test (grammar-parse (many (char-in "ab")) "") ())
!(test (collapse (grammar-parse (many1 (char-in "ab")) "")) ())
!(test (grammar-parse (cat (optional (lit "-")) (digits)) "-7") (("-") "7"))
!(test (grammar-parse (cat (optional (lit "-")) (digits)) "7") (() "7"))

; `sep-by` is the list a separator holds, and its values are the parts only.
!(test (grammar-parse (sep-by (digits) (lit ",")) "1,2,3") ("1" "2" "3"))
!(test (grammar-parse (sep-by (digits) (lit ",")) "1") ("1"))
!(test (grammar-parse (sep-by (digits) (lit ",")) "") ())

; `between` drops both ends and `token` eats the blanks around a part, which is
; what a language with free whitespace needs.
!(test (grammar-parse (between (lit "(") (digits) (lit ")")) "(5)") "5")
!(test (grammar-parse (token (digits)) "  5 ") "5")
!(test (grammar-parse (sep-by (token (digits)) (lit ",")) " 1 , 2 ") ("1" "2"))

; `map` applies a function to a value and `as` tags one, so a grammar builds the
; parse TREE rather than a list of strings to read again.
(= (double $n) (* 2 $n))
!(test (grammar-parse (map double (integer)) "21") 42)
!(test (grammar-parse (as amount (integer)) "7") (amount 7))
!(test (grammar-parse (many (as digit (char-in "12"))) "12") ((digit "1") (digit "2")))

; A grammar refers to itself through `ref`, which evaluates a function of no
; arguments when the parse reaches it, so a nested language is expressible. This
; one is a parenthesised sum of numbers.
(= (sum) (alt (integer) (between (lit "(") (sep-by (ref sum) (lit "+")) (lit ")"))))
!(test (grammar-parse (ref sum) "7") 7)
!(test (grammar-parse (ref sum) "(1+2)") (1 2))
!(test (grammar-parse (ref sum) "(1+(2+3))") (1 (2 3)))
!(test (collapse (grammar-parse (ref sum) "(1+)")) ())

; A prefix parse answers the value with the unread rest, which is how a reader
; takes one construct at a time. The longest match comes first.
!(test (grammar-parse-prefix (digits) "12ab") ("12" "ab"))
!(test (car-atom (collapse (grammar-parse-prefix (many (char-in "ab")) "aab!"))) (("a" "a" "b") "!"))
!(test (grammar-parse-prefix (rest) "all") ("all" ""))
!(test (collapse (grammar-parse-prefix (lit "z") "ab")) ())

; A real format, in seven forms: a CSV row of quoted or bare fields. The bare
; field stops at a QUOTE as well as at a comma, which is what makes the grammar
; unambiguous: with (until ",") a quoted field would also parse as three bare
; ones and the row would answer twice.
(= (field) (alt (quoted) (until ",\"")))
(= (row) (cat (sep-by (ref field) (lit ",")) (skip (eos))))
!(test (grammar-parse (ref row) "a,b,c") (("a" "b" "c")))
!(test (grammar-parse (ref row) "\"x,y\",z") (("x,y" "z")))

; The vocabulary is data, and a value that is not a grammar is refused BEFORE any
; text is read, naming the form that is wrong rather than answering nothing.
!(test (size-atom (grammar-forms)) 26)
!(test (grammar-is (cat (digits) (eos))) True)
!(test (grammar-is (lit 7)) False)
!(test (grammar-is (many)) False)
!(test (grammar-is 7) False)
!(test (if-error (catch (grammar-parse (nosuch) "a")) refused fine) refused)
!(test (if-error (catch (grammar-parse (cat (digits) (nosuch)) "1")) refused fine) refused)
!(test (if-error (catch (grammar-parse (digits) 7)) refused fine) refused)
