; Purpose: UTF-8, hex and base64, each one head in and one head out.
; [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/30-encoding_lib.metta; commit=WORKTREE].
!(import! &self (library lib_encoding))
; lib_string is beside it for the one comparison that makes UTF-8 worth having:
; `string-length` counts characters where these bytes count bytes.
!(import! &self (library lib_string))

; Bytes are an expression of Numbers from 0 to 255, which is lib_file's byte shape,
; so what a file answers is what these heads take.
!(test (utf8-encode "hi") (104 105))
!(test (utf8-decode (104 105)) "hi")
!(test (utf8-encode "") ())
!(test (utf8-decode ()) "")

; UTF-8 is where a byte count and a character count part company: an accented
; letter is two bytes and an emoji four, and `string-length` counts one each.
!(test (utf8-encode "é") (195 169))
!(test (string-length "é") 1)
!(test (size-atom (utf8-encode "é")) 2)
!(test (size-atom (utf8-encode "🙂")) 4)
!(test (string-length "🙂") 1)
!(test (utf8-decode (utf8-encode "héllo 🙂")) "héllo 🙂")

; Hex answers lower case, two digits a byte and nothing between them, and reads
; either case back: that is how a hash, a key and a wire dump are all written.
!(test (hex-encode (255 16 0)) "ff1000")
!(test (hex-decode "ff1000") (255 16 0))
!(test (hex-decode "FF1000") (255 16 0))
!(test (hex-encode ()) "")
!(test (hex-decode "") ())
!(test (hex-encode (utf8-encode "hi")) "6869")

; Base64 takes its ALPHABET as an argument. `standard` is padded with `=`, as mail
; and JSON carry it; `url` uses `-` and `_` without padding, as a URL and a file
; name carry it, and the two differ exactly where a byte pair has high bits.
!(test (base64-encode standard (104 105)) "aGk=")
!(test (base64-decode standard "aGk=") (104 105))
!(test (base64-encode standard (255 254)) "//4=")
!(test (base64-encode url (255 254)) "__4")
!(test (base64-decode url (base64-encode url (255 254))) (255 254))
!(test (base64-encode standard ()) "")
!(test (base64-decode standard "") ())
; The two alphabets are the same encoding: the same three bytes come back from
; either spelling.
!(test (base64-decode standard "//79") (255 254 253))
!(test (base64-decode url "__79") (255 254 253))

; The encodings compose, which is the whole reason they are here: text to bytes to
; base64 and back is the way a document travels through a URL.
!(test (utf8-decode (base64-decode url (base64-encode url (utf8-encode "héllo")))) "héllo")
!(test (base64-encode standard (hex-decode "6869")) "aGk=")

; Malformed input is refused rather than repaired. Hex of odd length is a truncated
; dump and a character outside the alphabet is a typo; both name what was wrong.
!(test (if-error (catch (hex-decode "abc")) refused fine) refused)
!(test (if-error (catch (hex-decode "zz")) refused fine) refused)
; Bytes that are not UTF-8 are refused, because the alternative is a string holding
; whatever the bytes happened to mean.
!(test (if-error (catch (utf8-decode (255))) refused fine) refused)
!(test (if-error (catch (utf8-decode (195))) refused fine) refused)
; Base64 the decoder rejects, and an alphabet the library does not know.
!(test (if-error (catch (base64-decode standard "not base64!")) refused fine) refused)
!(test (if-error (catch (base64-encode nosuch (1))) refused fine) refused)
; A code point is not a byte: `string-codes` answers code points, and one above 255
; is refused naming the value.
!(test (if-error (catch (hex-encode (256))) refused fine) refused)
!(test (if-error (catch (base64-encode standard (string-codes "🙂"))) refused fine) refused)
; A code point that happens to fit in a byte is accepted as one, which is why the
; two are worth telling apart: this is the byte 233, not the letter é.
!(test (hex-encode (string-codes "é")) "e9")
!(test (hex-encode (utf8-encode "é")) "c3a9")
!(test (if-error (catch (utf8-decode (1 two))) refused fine) refused)
!(test (if-error (catch (hex-decode 7)) refused fine) refused)

; Hex equations are callable data and compose with alternative answer streams.
!(test (let $recipe
         (match &self (= (hex-encode $bytes) $body) (quote (|-> ($bytes) $body)))
         (let $format (eval $recipe) ($format (0 255)))) "00ff")
!(test (collapse (hex-encode (superpose (() (0 255))))) ("" "00ff"))
!(test (hex-encode (utf8-encode (string-from-codes (97 0 98)))) "610062")
!(test (if-error (catch (hex-decode "𝟢0")) refused fine) refused)
