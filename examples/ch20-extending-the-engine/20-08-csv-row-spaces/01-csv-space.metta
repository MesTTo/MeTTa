; Purpose: query a CSV file through the ordinary foreign-space match seam.
; The binding names the space, and each query streams the current file.
!(import! &self (library lib_csv))
!(import! &self (library lib_file))

!(bind! &csv-path (temp-path! "metta-csv-example"))
!(write-file! &csv-path "id,amount\n001,12.50\n002,9\n002,9\n")
!(bind! &sales (csv-space &csv-path))

; Header records and duplicates remain data; leading zeroes remain text.
!(test (collapse (match &sales (row $id $amount) ($id $amount)))
       (("id" "amount") ("001" "12.50") ("002" "9") ("002" "9")))
!(test (match &sales (row "001" $amount) (parse-number $amount)) 12.5)

; The descriptor remains the same, and a new query observes the new content.
!(write-file! &csv-path "003,42\n")
!(test (collapse (match &sales (row $id $amount) ($id $amount)))
       (("003" "42")))
!(delete-file! &csv-path)
