; Purpose: create, copy and inspect files using queryable metadata.
; [tested: sh test.sh examples/ch20-extending-the-engine/20-06-files-and-processes/01-files-and-paths.metta; commit=WORKTREE]
!(import! &self (library lib_file))

!(test (path-join "reports" "sales.csv") "reports/sales.csv")
!(test (path-parent "reports/sales.csv") "reports")
!(test (path-name "reports/sales.csv") "sales.csv")
!(test (path-extension "reports/sales.csv") "csv")
!(test (path-extension "README") "")

; A unique temporary filename also gives this example a unique directory.
!(bind! &seed (temp-path! "file-surface"))
!(bind! &directory (string-join "" (&seed "-directory")))
!(test (make-dir! &directory) True)
!(bind! &source (path-join &directory "source.txt"))
!(bind! &copy (path-join &directory "copy.txt"))
!(test (write-file! &source "hello") True)
!(test (copy-file! &source &copy) True)
!(test (read-file! &copy) "hello")

; The result is a space. Read fields with ordinary match.
!(bind! &metadata (file-metadata! &copy))
!(test (match &metadata (kind $kind) $kind) file)
!(test (match &metadata (size $bytes) $bytes) 5)
!(test (> (match &metadata (modified $time) $time) 0) True)
!(test (match (file-metadata! &directory) (kind $kind) $kind) directory)

!(test (delete-file! &source) True)
!(test (delete-file! &copy) True)
!(test (delete-dir! &directory) True)
!(test (delete-file! &seed) True)
