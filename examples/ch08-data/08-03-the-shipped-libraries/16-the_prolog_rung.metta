; Purpose: compare retained Prolog spellings with their MeTTa library names.
; Guarantees: the paired calls below agree on their results.
; [tested: examples/ch08-data/08-03-the-shipped-libraries/16-the_prolog_rung.metta; commit=WORKTREE].
; The libraries retain underscore spellings beside their MeTTa names. Both
; are callable; the assertions show when they share an operation. Their
; source declarations publish both spellings.
;
;A library does that with `import_prolog_functions_from_file`, which names
;the file and the predicates, so the names a library publishes are written
;down in the library rather than discovered by loading it.
!(import! &self (library lib_string))
!(import! &self (library lib_regex))
!(import! &self (library lib_crypto))
!(import! &self (library lib_datetime))
!(import! &self (library lib_conformance))

;The regex aliases retain the native operation's results.
!(test (regex_match "(?i)^needle" "Needle in a haystack") True)
!(test (== (regex_match "^x" "abc") (re-match "^x" "abc")) True)
!(test (collapse (regex_find "\\d+" "a1 b22 c333")) ("1" "22" "333"))
!(test (regex_captures "(?<y_I>\\d+)" "n 42") ((0 "42") (y 42)))
!(test (regex_split ":\\s*" "Age: 33") ("Age" ": " "33"))
!(test (regex_replace "a" "X" "banana") "bXnana")
!(test (regex_replace_all "a" "X" "banana") "bXnXnX")

;lib_crypto's two. A digest is a content key: the same text always answers
;the same hex, which is what lets a fact carry the digest of its payload as
;an identity.
!(test (crypto_hash sha256 "text")
       "982d9e3eb996f559e633f4d194def3761d909f5a3b647d1a851fead67c32c9d1")
!(test (== (crypto_hash sha256 "text") (crypto-hash sha256 "text")) True)
!(test (== (crypto_hash sha256 "text") (crypto_hash sha256 "other")) False)

;`crypto-random-hex` answers two hex characters per byte. The fixture checks
;the output lengths and compares two independent sixteen-byte draws.
!(test (string-length (crypto-random-hex 8)) 16)
!(test (string-length (crypto_random_hex 16)) 32)
!(test (== (crypto-random-hex 16) (crypto-random-hex 16)) False)

;lib_datetime's two, over Unix time. The epoch is a Thursday, which is the
;one date this can assert without asking what day it is.
!(test (day_of_week 0) Thursday)
!(test (format_date 0 "%Y-%m-%d") 1970-01-01)
!(test (== (day_of_week 0) (day-of-week 0)) True)
!(test (== (format_date 0 "%H:%M:%S") (format-date 0 "%H:%M:%S")) True)

;lib_conformance's one, which is the whole library: the kit that proves a
;foreign space provider before its users find out. `check-space-provider` is
;`metta_check_space_provider` and nothing else, so the Prolog-facing name
;runs the same three checks.
!(import_prolog_functions_from_file "./examples/ch08-data/08-03-the-shipped-libraries/_fixtures/demo_provider.pl" ())
!(test (metta_check_space_provider &demo_provider)
       ("match: declared, seam:foreign_match/3 has clauses"
        "enumerate: declared, seam:foreign_atoms/2 has clauses"
        "match: over-approximation holds over 2 atoms and their pattern families"
        "source: repeated, two enumerations agree"
        "round trip: not asked, the provider does not declare add, remove and enumerate together"
        "pushdown: 0 of 2 patterns claimed exact, and are"
        "plan: not declared, so a conjunction takes the engine's split"))
!(test (== (metta_check_space_provider &demo_provider)
           (check-space-provider &demo_provider))
       True)
