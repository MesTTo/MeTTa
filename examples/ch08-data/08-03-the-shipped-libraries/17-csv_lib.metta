; Purpose: exchange lossless CSV text and files through every library head.
; [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/17-csv_lib.metta; commit=WORKTREE].
; Owns resources: the example deletes its files, writer lock and temporary
; directory. Snapshots follow the engine's ordinary space lifetime.
!(import! &self (library lib_csv))

!(test (csv-parse "001,\"a,b\"\r\n002,9\r\n") (("001" "a,b") ("002" "9")))
!(test (csv-encode (("001" "a,b") ("002" "9"))) "001,\"a,b\"\r\n002,9\r\n")
; Quote option data so a name such as quote is not called as a function.
!(test (csv-parse "id;value\n001;a\n001;a\n" (quote ((separator ";") (skip 1))))
       (("001" "a") ("001" "a")))
!(test (csv-encode (("001" "a;b")) (quote ((separator ";") (newline "\n")))) "001;\"a;b\"\n")
!(test (csv-parse "") ())
!(test (csv-encode ()) "")
!(test (csv-parse "\n\"\"\n,\n" (quote ((width any)))) (() ("") ("" "")))
!(test (csv-parse "a\"b,c\n" (quote ((quote "")))) (("a\"b" "c")))
!(test (csv-parse (csv-encode (("é🦊" "λ\r\n")) (quote ((separator "🦊") (quote "λ"))))
                 (quote ((separator "🦊") (quote "λ"))))
       (("é🦊" "λ\r\n")))

!(import! &self (library lib_file))
!(bind! &csv-dir (temp-dir! "metta-csv"))
!(bind! &csv-path (path-join &csv-dir "records.csv"))
!(test (csv-write! &csv-path (("001" "a,b") ("002" "9"))) True)
!(test (collapse (csv-read! &csv-path)) (("001" "a,b") ("002" "9")))
!(test (csv-append! &csv-path (("002" "9"))) True)
!(test (collapse (csv-read! &csv-path)) (("001" "a,b") ("002" "9") ("002" "9")))

!(bind! &csv-live (csv-space &csv-path))
!(test (collapse (match &csv-live (row $id $value) ($id $value)))
       (("001" "a,b") ("002" "9") ("002" "9")))
!(bind! &csv-shot (csv-snapshot! &csv-path))
!(test (collapse (match &csv-shot (row $n $id $value) ($n $id $value)))
       ((1 "001" "a,b") (2 "002" "9") (3 "002" "9")))

!(test (csv-write! &csv-path (("id" "value") ("003" "a;b")) (quote ((separator ";")))) True)
!(test (csv-append! &csv-path (("004" "7")) (quote ((separator ";")))) True)
!(test (collapse (csv-read! &csv-path (quote ((separator ";") (skip 1))))) (("003" "a;b") ("004" "7")))
!(bind! &csv-configured (csv-space &csv-path (quote ((separator ";") (skip 1)))))
!(test (collapse (match &csv-configured (row $id $value) ($id $value))) (("003" "a;b") ("004" "7")))
!(bind! &csv-numbered (csv-snapshot! &csv-path (quote ((separator ";") (skip 1)))))
!(test (collapse (match &csv-numbered (row $n $id $value) ($n $id $value)))
       ((2 "003" "a;b") (3 "004" "7")))

; A snapshot remains the records it read while the live descriptor follows
; the file. A header is skipped by position, never by its label or contents.
!(test (collapse (match &csv-shot (row $n $id $value) ($n $id $value)))
       ((1 "001" "a,b") (2 "002" "9") (3 "002" "9")))
!(csv-write! &csv-path (("id" "value") ("005" "later")) (quote ((separator ";"))))
!(test (collapse (match &csv-configured (row $id $value) ($id $value))) (("005" "later")))

!(delete-file! &csv-path)
!(delete-file! (path-join &csv-dir "records.csv.metta-csv.lock"))
!(delete-dir! &csv-dir)
