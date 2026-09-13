; Purpose: use every String head and each optional typed arity.
; Guarantees: codepoints, literal matching, layout and metrics retain their
; documented empty-input and overlap cases.
; [tested: examples/ch08-data/08-03-the-shipped-libraries/18-string_lib.metta;
; commit=118b805aedbee6de22be4f6131d97c3d6b9156de].

!(import! &self (library lib_string))

!(test (string-length "a🦊é") 3)
!(test (string-slice "a🦊é" 1 99) "🦊é")
!(test (string-split ",;" "a,b;;c") ("a" "b" "" "c"))
!(test (string-split-exact "::" "::a::::") ("" "a" "" ""))
!(test (string-join " / " ("a" "b")) "a / b")
!(test (string-trim " \ta\r\n") "a")
!(test (string-upper hello) "HELLO")
!(test (string-lower "HELLO") "hello")
!(test (string-starts-with "a🦊é" "a🦊") True)
!(test (string-ends-with "a🦊é" "é") True)
!(test (string-contains "a🦊é" "🦊") True)
!(test (string-index-of "banana" "ana") 1)
!(test (string-last-index-of "banana" "ana") 3)
!(test (string-count "aaaaa" "aa") 2)
!(test (string-count "aaaaa" "aa" True) 4)
!(test (string-replace "aaaaa" "aa" "X") "XXa")
!(test (string-replace "abc" "" "X") "abc")
!(test (string-last-index-of "a🦊" "") 2)
!(test (string-count "a🦊" "") 3)

!(test (string-chars "a🦊") ("a" "🦊"))
!(test (string-from-chars ("ab" c 42)) "abc42")
!(test (string-codes "a🦊") (97 129418))
!(test (string-from-codes (97 129418)) "a🦊")
; Construct an actual NUL through scalar codes; the reader has no JSON escapes.
!(test (string-codes (string-from-codes (97 0 129418))) (97 0 129418))
!(test (string-repeat "ab" 3) "ababab")
!(test (string-pad-left "x" 4 "ab") "abax")
!(test (string-pad-right "x" 4 "ab") "xaba")
!(test (string-center "x" 6 "ab") "abxaba")

!(test (string-lines "a\n\nb\n") ("a" "" "b"))
!(test (string-unlines ("a" "" "b")) "a\n\nb\n")
!(test (string-dedent "  a\n  b\n") "a\nb\n")
!(test (string-indent "> " "a\n \nb\n") "> a\n \n> b\n")
!(test (string-wrap "one two three" 7) "one two\nthree")
!(test (string-wrap "a b c d" 4 justify) "a  b\nc d")
!(test (string-template "Dear {Name}: {Value}. {Missing,none}"
                       (quote ((Name "Ada") (Value (age 3)))))
       "Dear Ada: (age 3). none")

!(test (string-edit-distance "kitten" "sitting") 3)
!(test (string-similarity "ab" "ac") 0.5)
!(test (string-isub "language" "language") 1.0)
!(test (string-isub "A.B" "ab" ((normalize True) (zero-to-one True) (substring-threshold 0))) 1.0)
!(test (parse-number "0x10") 16)
!(test (number-to-string 42) "42")
!(test (collapse (parse-number "not a number")) ())

; Text recipes are ordinary equations over literal text and answer streams.
!(test (string-repeat 42 2) "4242")
!(test (string-repeat "" 1000000000000000000000000) "")
!(test (string-center 12 7 3) "3312333")
!(test (string-center "x" 1000000000000000000000000 "") "x")
!(test (string-ends-with "ab" "abc") False)
!(test (if-error (catch (string-repeat "" 1.5)) True False) True)
!(test (collapse (string-repeat "x" (superpose (0 2)))) ("" "xx"))
!(test (let $recipe (match &self (= (string-repeat $value $n) $body)
                           (quote (|-> ($value $n) $body)))
         (let $function (eval $recipe) ($function "ab" 2))) "abab")
