; Purpose: call every lib_regex head through guards, scans and substitutions.
; A MeTTa string reads \\ as one backslash, so "\\d" spells the regex \d,
; the same convention as Python's non-raw strings.
; Cost: 103,904 MeTTa inferences and 103,258 Python inferences, ratio 0.9938.
; [measured 2026-09-11: minimum of three runs; command=python extensions/python/tools/twin_coverage.py --measure --rounds 3 examples/ch08-data/08-03-the-shipped-libraries/04-regex_lib.metta; fixture=26 assertions, warm native objects and QLFs; commit=7dcfe83fcf74742a1e944db240aa918596c8d4b0]
!(import! &self (library lib_regex))

!(test (re-match "(?i)^needle" "Needle in a haystack") True)
!(test (re-match "^x" "abc") False)
!(test (collapse (re-find "\\d+" "a1 b22 c333")) ("1" "22" "333"))
!(test (re-captures "(?<year_I>\\d\\d\\d\\d)-(?<month_I>\\d\\d)" "2017-04-20")
       ((0 "2017-04") (month 4) (year 2017)))
!(test (re-split ":\\s*" "Age: 33") ("Age" ": " "33"))
!(test (re-replace-all "a+" "X" "banana") "bXnXnX")
!(test (re-replace "(?<y>\\d+)" "[$y]" "n 42 n") "n [42] n")

; The native spellings remain public and retain the same results.
!(test (regex_match "^x" "xyz") True)
!(test (collapse (regex_find "x" "x-x")) ("x" "x"))
!(test (regex_captures "(x)" "x") ((0 "x") (1 "x")))
!(test (regex_split "," "a,b") ("a" "," "b"))
!(test (regex_replace "x" "y" "xx") "yx")
!(test (regex_replace_all "x" "y" "xx") "yy")

; A compiled pattern is a value that you can bind and pass to any matcher.
!(test (let $pattern (re-compile "\\d+")
         (collapse (re-find $pattern "n7 n8"))) ("7" "8"))
!(test (re-fullmatch "a|ab" "ab") True)
!(test (re-fullmatch "a|ab" "abc") False)
!(test (collapse (re-scan "(?<n_I>\\d+)" "a1 b22"))
       (((0 "1") (n 1)) ((0 "22") (n 22))))
!(test (collapse (re-ranges "." "é🦊")) ((0 1) (1 1)))
!(test (re-count "" "é🦊") 3)
!(test (re-fullmatch (re-escape "a.*\\E #") "a.*\\E #") True)

; Empty matches keep their nonempty alternatives. Optional groups stay absent.
!(test (collapse (re-find "a*?" "aa")) ("" "a" "" "a" ""))
!(test (re-split "" "a") ("" "" "a" "" ""))
!(test (re-replace-all "a*?" "X" "aa") "XXXXX")
!(test (re-captures "((a)?b)" "b") ((0 "b") (1 "b")))
!(test (re-replace "(?<term_T>1-2)" "$term" "before 1-2 after") "before 1-2 after")
!(test (re-captures "(?<span_R>é)(?<term_T>1-2)" "é1-2")
       (quote ((0 "é1-2") (span (- 0 1)) (term (- 1 2)))))
