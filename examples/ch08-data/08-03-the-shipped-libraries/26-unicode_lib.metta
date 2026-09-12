; Purpose: the Unicode database and the standard transformations over text.
; [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/26-unicode_lib.metta; commit=a30e0a59e8e16d15705dc0258d7e0a004ae63e4b].
!(import! &self (library lib_unicode))
; lib_string is beside it here because the two answer different questions about
; the same text: `string-codes` and `string-chars` count code points, this
; library's `unicode-graphemes` counts what a person calls a character, and
; `string-lower` is a lowercasing where `unicode-casefold` is not.
!(import! &self (library lib_string))

; Every answer here comes from the host's own database, and its version is a head
; because a normalization is reproducible only beside the version that made it.
!(test (unicode-version) "16.0.0")

; The five normalization forms. "é" can be one code point or two, and nfc and nfd
; are what move between them; `string-codes` shows which one a string holds.
!(test (string-codes (unicode-normalize nfd "é")) (101 769))
!(test (string-codes (unicode-normalize nfc "é")) (233))
!(test (== (unicode-normalize nfc (unicode-normalize nfd "é")) "é") True)
; The compatibility forms also replace presentation characters: the ffi ligature
; becomes three letters and the superscript two becomes a two.
!(test (unicode-normalize nfkc "ﬃ") "ffi")
!(test (unicode-normalize nfkd "2²") "22")
!(test (unicode-normalize nfc "2²") "2²")
; nfkc-casefold is the caseless identifier form of UAX#31: compatibility, then
; composition, then case folding, in one pass.
!(test (unicode-normalize nfkc-casefold "Straße") "strasse")
!(test (if-error (catch (unicode-normalize nfx "a")) refused fine) refused)

; Case folding is NOT lowercasing: it answers what compares equal regardless of
; case, so sharp s becomes two letters and the answer is longer than the input.
!(test (unicode-casefold "Straße") "strasse")
!(test (string-lower "Straße") "straße")
!(test (== (unicode-casefold "HELLO") (unicode-casefold "hello")) True)

; `unicode-map` is the general operation the forms above are compositions of, and
; it does the transformations that have no standard name: stripping the accents
; off text is composing it and stripping the marks.
!(test (unicode-map "café" (compose stripmark)) "cafe")
; Two combinations are refused rather than passed to the host, which answers a
; bare domain error for both: composing and decomposing at once, and stripping
; marks with neither beside it.
!(test (if-error (catch (unicode-map "a" (compose decompose))) refused fine) refused)
!(test (if-error (catch (unicode-map "a" (stripmark))) refused fine) refused)
; `lump` folds typographic variants onto their ASCII equivalents, which is what a
; search index wants: a curly apostrophe and an en dash become the straight ones.
; The table is the host's own and covers single quotes, dashes, slashes, brackets
; and connectors; DOUBLE quotes are not in it, which is why this claim uses the
; apostrophe.
!(test (unicode-map "it’s a–b" (lump)) "it's a-b")
!(test (unicode-map "Hello" (casefold)) "hello")
!(test (if-error (catch (unicode-map "a" (nosuchflag))) refused fine) refused)

; The database, one character at a time. A character is a one-character string or
; the number of a code point, whichever the program has in hand.
!(test (unicode-property "A" category) Lu)
!(test (unicode-property 65 category) Lu)
!(test (unicode-property "1" category) Nd)
!(test (unicode-property " " category) Zs)
!(test (unicode-property "A" lowercase) 97)
!(test (unicode-property "a" uppercase) 65)
!(test (unicode-property "A" width) 1)
!(test (unicode-property "漢" width) 2)
; A property the character has no value for has NO answer, which is data about
; the character; an unknown property NAME is refused, which is a mistake.
!(test (collapse (unicode-property "A" uppercase)) ())
!(test (collapse (unicode-property "a" decomp-type)) ())
!(test (if-error (catch (unicode-property "a" colour)) refused fine) refused)
!(test (if-error (catch (unicode-property "ab" category)) refused fine) refused)

; The classification a lexer asks per character, as a Bool so it composes with
; if. Every class is a general category of the database or a group of them, so
; the answers do not move with the process locale: "é" is a letter under
; LC_ALL=C as well, where the host's own code_type says it is not.
!(test (unicode-is "a" letter) True)
!(test (unicode-is "1" letter) False)
!(test (unicode-is "1" digit) True)
!(test (unicode-is "Ⅲ" number) True)
!(test (unicode-is " " white-space) True)
!(test (unicode-is "é" letter) True)
!(test (unicode-is "é" ascii) False)
!(test (unicode-is "漢" letter) True)
!(test (unicode-is 65 upper) True)
!(test (unicode-is "," punctuation) True)
!(test (unicode-is 1114111 assigned) False)
!(test (if-error (catch (unicode-is "a" vowel)) refused fine) refused)

; Graphemes are the characters a PERSON counts: a base character with its
; combining marks is one, where `string-chars` answers each code point.
!(test (size-atom (string-chars (unicode-normalize nfd "éx"))) 3)
!(test (size-atom (unicode-graphemes (unicode-normalize nfd "éx"))) 2)
; The first grapheme holds BOTH code points, which is what grouping means, and
; the codes are what makes it visible: the two strings print the same.
!(test (string-codes (car-atom (unicode-graphemes (unicode-normalize nfd "éx"))))
       (101 769))
!(test (unicode-graphemes "abc") ("a" "b" "c"))
!(test (unicode-graphemes "") ())

; A code point is valid when the database ASSIGNS it a character, which is
; stricter than being in range: a surrogate half, an unassigned number and a
; noncharacter all answer False, and a private-use code point answers True
; because it is assigned. The same question through the database is whether
; `unicode-property` answers a category at all.
!(test (unicode-codepoint-valid 97) True)
!(test (unicode-codepoint-valid 55296) False)
!(test (unicode-codepoint-valid 1114112) False)
!(test (unicode-codepoint-valid 1114111) False)
!(test (unicode-codepoint-valid 57344) True)
!(test (unicode-property 57344 category) Co)
!(test (collapse (unicode-property 1114111 category)) ())
