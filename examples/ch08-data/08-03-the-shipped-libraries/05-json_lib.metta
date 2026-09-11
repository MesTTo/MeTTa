; Purpose: query JSON objects as spaces, navigate paths, format and exchange files.
; [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/05-json_lib.metta; commit=WORKTREE]
; Objects retain duplicate fields; arrays are expressions. Each example file
; is removed after reading. Decoded object spaces remain caller-owned data.
!(import! &self (library lib_json))

;;; An object becomes a space. get-keys answers one key per solution, the way
;;; get-atoms does, so collapse it for a tuple.
!(test (let $d (json-decode "{\"a\":1,\"b\":2}") (collapse (get-keys $d)))
       (a b))
!(test (let $d (json-decode "{\"a\":1,\"b\":2}") (get-value $d a)) 1)
;An absent key answers nothing at all, so you test it with a match.
!(test (let $d (json-decode "{\"a\":1}") (collapse (get-value $d missing))) ())

;;; Arrays become expressions, scalars stay themselves.
!(test (json-decode "[1,2,3]") (1 2 3))
!(test (json-decode "\"plain\"") "plain")
!(test (json-decode "42") 42)
!(test (json-decode "true") True)
!(test (json-decode "null") Null)

;;; Nesting decodes all the way down, so an inner object is a space too.
!(test (let $outer (json-decode "{\"c\":{\"d\":2}}")
         (let $inner (get-value $outer c) (get-value $inner d)))
       2)

;;; Encoding inverts decoding.
!(test (json-decode (json-encode (1 2 3))) (1 2 3))
!(test (json-decode (json-encode "text")) "text")
!(test (let $d (json-decode (json-encode (dict-space ((k 1))))) (get-value $d k))
       1)

;;; dict-space builds one from pairs directly, without going through text.
!(test (let $d (dict-space ((name "ann") (age 3))) (get-value $d name)) "ann")

;;; Paths mix object keys with zero-based array indexes. Duplicate fields keep
;;; their alternatives; missing fields have none. An empty path returns the input.
!(test (json-at (json-decode "{\"rows\":[{\"name\":\"ann\"}]}") (rows 0 name)) "ann")
!(test (collapse (json-at (json-decode "{\"a\":[1],\"a\":[2]}") (a 0))) (1 2))
!(test (collapse (json-at (json-decode "{}") (missing))) ())
!(test (json-at 42 ()) 42)
!(test (json-encode (dict-space ())) "{}")
!(test (let $d (dict-space ((from 1) (internal 2))) (collapse (get-keys $d)))
       (quote (from internal)))

;;; Formatting uses the native writer's target width. Width zero keeps one
;;; line; width one expands nonempty containers. Short defaults stay on one line.
!(test (json-pretty (1 2)) "[1, 2 ]")
!(test (json-pretty (1 2) 1) "[\n  1,\n  2\n]")
!(test (json-decode (json-pretty (1 2) 0)) (1 2))

;;; Every physical JSON Lines line is a value. Blank lines are errors, while
;;; empty input has no records. A writer ends every record with LF.
!(test (collapse (json-lines-decode "1\r\ntrue\nnull\n")) (1 True Null))
!(test (json-lines-encode (1 True "é")) "1\ntrue\n\"é\"\n")
!(test (collapse (json-lines-decode "")) ())
!(test (json-lines-encode ()) "")

;;; Files are UTF-8. Writes stage beside the destination and publish after
;;; close succeeds; the reader closes on exhaustion, cut or error.
!(import! &self (library lib_file))
!(test (let* (($path (temp-path! "json-document"))
              ($written (json-write! $path (7 8)))
              ($value (json-read! $path)))
         (chain (delete-file! $path) $_ ($written $value)))
       (True (7 8)))
!(test (let* (($path (temp-path! "json-lines"))
              ($written (json-lines-write! $path (1 True "é")))
              ($values (collapse (json-lines-read! $path))))
         (chain (delete-file! $path) $_ ($written $values)))
       (True (1 True "é")))
