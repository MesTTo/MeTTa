; Purpose: read a CSV file once into a numbered space, beside the live view.
; [tested: lib_csv:snapshot_rows_carry_their_record_number; commit=b96e1a15260b7538a8e42be613bcc5dd0dddd136]
!(import! &self (library lib_csv))
!(import! &self (library lib_file))

!(bind! &csv-path (temp-path! "metta-csv-snapshot"))
!(write-file! &csv-path "id,amount\n001,12.50\n002,9\n002,9\n")

; Two doors over one file. csv-space is a live VIEW: it holds no rows and every
; query reparses. csv-snapshot! reads once into an ordinary space, so repeated
; queries pay one parse between them.
!(bind! &live (csv-space &csv-path))
!(bind! &shot (csv-snapshot! &csv-path))

; The snapshot carries the record NUMBER, which is what a space of rows cannot
; otherwise have: a space is unordered, so without it nothing says which record
; came first. Duplicates and leading zeroes stay as they are either way.
!(test (collapse (match &shot (row $n $id $amount) ($n $id $amount)))
       ((1 "id" "amount") (2 "001" "12.50") (3 "002" "9") (4 "002" "9")))

; Which is what lets a query skip the header rather than matching it by content.
!(test (collapse (match &shot (row $n $id $amount)
                   (if (> $n 1) ($id $amount) (empty))))
       (("001" "12.50") ("002" "9") ("002" "9")))

; Drop the number and the two doors answer the same records, so a program can
; move between them without its queries changing meaning.
!(test (== (collapse (match &live (row $id $amount) ($id $amount)))
           (collapse (match &shot (row $_ $id $amount) ($id $amount))))
       True)

; They differ on what happens when the file changes. The view follows it; the
; snapshot is what was read, which is what makes its number an identity rather
; than a position in whatever the file currently says.
!(write-file! &csv-path "003,42\n")
!(test (collapse (match &live (row $id $amount) ($id $amount))) (("003" "42")))
!(test (collapse (match &shot (row $n $_ $_) $n)) (1 2 3 4))

; And the snapshot is an ordinary space, so it takes the writes the view
; refuses: a derived row sits beside the ones the file supplied.
!(test (add-atom &shot (row 99 "total" "34.50")) True)
!(test (collapse (match &shot (row 99 $id $amount) ($id $amount))) (("total" "34.50")))
!(test (if-error (catch (add-atom &live (row "004" "1"))) refused fine) refused)

; Every refusal is the view's, named for the door the program used: a missing
; file raises where the mistake was made rather than at the first query.
!(test (if-error (catch (csv-snapshot! (path-join (path-parent &csv-path) "absent.csv")))
                 refused fine)
       refused)

!(delete-file! &csv-path)
