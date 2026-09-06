; Purpose: mint a temporary DIRECTORY, the twin of temp-path!'s temporary file.
; [tested: lib_file_surface:temp_dir_mints_a_fresh_empty_directory; commit=b96e1a15260b7538a8e42be613bcc5dd0dddd136]
!(import! &self (library lib_file))

; temp-dir! creates the directory exclusively, so two checkouts running the
; corpus at once cannot collide on a name. Without it a caller who wants
; somewhere to put files derives a directory name from a temporary FILE name.
!(bind! &work (temp-dir! "fresh-directory"))
!(test (dir-exists &work) True)
!(test (list-dir! &work) ())

; It is an ordinary directory, so everything else in the library reaches it.
!(bind! &report (path-join &work "report.txt"))
!(test (write-file! &report "one line\n") True)
!(test (list-dir! &work) ("report.txt"))
!(test (match (file-metadata! &report) (kind $kind) $kind) file)

; A prefix NAMES the directory and does not place it, so a separator is
; refused rather than acted on: it would put the result outside the temporary
; directory entirely.
!(test (if-error (catch (temp-dir! "logs/run")) refused fine) refused)

; delete-dir! takes an empty directory, so the entries go first.
!(test (delete-file! &report) True)
!(test (delete-dir! &work) True)
!(test (dir-exists &work) False)
