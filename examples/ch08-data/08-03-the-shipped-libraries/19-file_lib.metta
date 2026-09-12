; Purpose: exercise the File library: bytes, publication, renames, trees,
; traversal, globbing, paths, kinds, links, scopes and the handle surface.
; [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/19-file_lib.metta; commit=WORKTREE].
; Owns resources: everything the example creates lives under one temporary
; directory that delete-tree! removes at the end; every handle is closed.
!(import! &self (library lib_file))

; A fresh directory, minted exclusively, is where the whole example works.
!(bind! &dir (temp-dir! "file-lib"))
!(test (dir-exists &dir) True)
!(test (file-kind &dir) directory)

; Text files: the whole-file trio and the lines as data.
!(bind! &notes (path-join &dir "notes.txt"))
!(test (write-file! &notes "alpha\nbeta\n") True)
!(test (append-file! &notes "gamma\n") True)
!(test (read-file! &notes) "alpha\nbeta\ngamma\n")
!(test (file-lines! &notes) ("alpha" "beta" "gamma"))
!(test (let $lines (file-space! &notes) (match $lines (line 2 $text) $text)) "beta")
!(test (file-exists &notes) True)
!(test (file-kind &notes) file)

; Bytes are an expression of integers 0 to 255, whole-file and by handle.
!(bind! &blob (path-join &dir "blob.bin"))
!(test (write-bytes! &blob (0 1 255 10)) True)
!(test (append-bytes! &blob (7)) True)
!(test (read-bytes! &blob) (0 1 255 10 7))
!(test (let* (($h (file-open! &blob "rb"))
              ($head (file-read-bytes! $h 2))
              ($rest (file-read-bytes! $h))
              ($closed (file-close! $h)))
         ($head $rest))
       ((0 1) (255 10 7)))
!(test (let* (($h (file-open! &blob "wb"))
              ($written (file-write-bytes! $h (65 66)))
              ($closed (file-close! $h)))
         (read-file! &blob))
       "AB")
; A byte operation on a text handle, or a text operation on a binary one,
; refuses by name rather than decoding octets as text.
!(test (if-error (catch (let $h (file-open! &blob "r") (file-read-bytes! $h))) refused fine) refused)
!(test (if-error (catch (write-bytes! &blob (1 300))) refused fine) refused)

; The handle surface: size, seek, exact reads, and the three standard streams.
!(test (let* (($h (file-open! &notes "r"))
              ($size (file-get-size! $h))
              ($first (file-read-exact! $h 5))
              ($moved (file-seek! $h 6))
              ($second (file-read-exact! $h 4))
              ($tail (file-read-to-string! $h))
              ($closed (file-close! $h)))
         ($size $first $second $tail))
       (17 "alpha" "beta" "\ngamma\n"))
!(test (let* (($h (file-open! &notes "a"))
              ($written (file-write! $h "delta\n"))
              ($closed (file-close! $h)))
         (file-lines! &notes))
       ("alpha" "beta" "gamma" "delta"))
!(test (stdin) 0)
!(test (stdout) 1)
!(test (stderr) 2)
!(test (stderr! "") True)

; replace-file! publishes by rename: a reader holding the old file keeps
; reading it while the path already names the new one.
!(test (let* (($h (file-open! &notes "r"))
              ($replaced (replace-file! &notes "fresh"))
              ($old (file-read-exact! $h 5))
              ($closed (file-close! $h)))
         ($old (read-file! &notes)))
       ("alpha" "fresh"))
!(test (replace-file! &blob (104 105)) True)
!(test (read-file! &blob) "hi")
; copy-file! publishes the same way, byte for byte, replacing only on success.
!(test (copy-file! &blob (path-join &dir "blob-copy.bin")) True)
!(test (read-bytes! (path-join &dir "blob-copy.bin")) (104 105))
!(test (if-error (catch (copy-file! (path-join &dir "absent.bin") (path-join &dir "blob-copy.bin"))) refused fine) refused)
!(test (read-bytes! (path-join &dir "blob-copy.bin")) (104 105))

; Directories, trees and links.
!(bind! &tree (path-join &dir "tree"))
!(test (make-dir! (path-join &tree "deep/deeper")) True)
!(test (write-file! (path-join &tree "deep/deeper/leaf.txt") "leaf") True)
!(test (write-file! (path-join &tree "deep/note.md") "note") True)
!(test (write-file! (path-join &tree ".hidden") "h") True)
!(test (make-link! "deep" (path-join &tree "shortcut")) True)
!(test (make-link! ".." (path-join &tree "deep/up")) True)
!(test (file-kind (path-join &tree "shortcut")) link)
!(test (read-link (path-join &tree "shortcut")) "deep")
!(test (same-file (path-join &tree "shortcut") (path-join &tree "deep")) True)
!(test (same-file (path-join &tree "deep") (path-join &tree "deep/note.md")) False)
!(test (list-dir! &tree) (".hidden" "deep" "shortcut"))

; A walk answers every descendant, depth first, names in codepoint order;
; links are reported and not entered unless asked.
!(test (collapse (dir-walk &tree))
       ((path-join &tree ".hidden") (path-join &tree "deep") (path-join &tree "deep/deeper")
        (path-join &tree "deep/deeper/leaf.txt") (path-join &tree "deep/note.md")
        (path-join &tree "deep/up") (path-join &tree "shortcut")))
; Following links enters shortcut; the link back to an ancestor is reported
; and not entered, so a cycle cannot loop.
!(test (size-atom (collapse (dir-walk &tree (quote ((follow-links True)))))) 11)

; A glob selects by pattern: literal components join without listing, * ? [] {}
; filter one directory, ** matches zero or more levels, dotfiles need asking.
!(test (collapse (dir-glob &tree "deep/*.md")) ((path-join &tree "deep/note.md")))
!(test (collapse (dir-glob &tree "**/*.txt")) ((path-join &tree "deep/deeper/leaf.txt")))
!(test (collapse (dir-glob &tree "*")) ((path-join &tree "deep") (path-join &tree "shortcut")))
!(test (collapse (dir-glob &tree "*" (quote ((hidden True)))))
       ((path-join &tree ".hidden") (path-join &tree "deep") (path-join &tree "shortcut")))
!(test (collapse (dir-glob &tree "{deep,other}/note.m?")) ((path-join &tree "deep/note.md")))
!(test (collapse (dir-glob &tree "**/*.md" (quote ((follow-links True)))))
       ((path-join &tree "deep/note.md") (path-join &tree "shortcut/note.md")))
!(test (collapse (dir-glob &tree "nowhere/*")) ())
!(test (if-error (catch (collapse (dir-glob &tree "[unclosed"))) refused fine) refused)

; copy-dir! builds the copy beside its destination and publishes it with one
; rename; links are recreated with the text they hold.
!(bind! &copy (path-join &dir "copies/tree"))
!(test (copy-dir! &tree &copy) True)
!(test (read-file! (path-join &copy "deep/deeper/leaf.txt")) "leaf")
!(test (read-link (path-join &copy "shortcut")) "deep")
!(test (if-error (catch (copy-dir! &tree &copy)) refused fine) refused)
!(test (if-error (catch (copy-dir! &tree (path-join &tree "inside"))) refused fine) refused)

; rename-file! is the host's rename: a file replaces a file, a directory
; replaces an empty directory, and nothing is ever copied.
!(test (rename-file! (path-join &copy "deep/note.md") (path-join &copy "deep/renamed.md")) True)
!(test (file-kind (path-join &copy "deep/note.md")) missing)
!(test (read-file! (path-join &copy "deep/renamed.md")) "note")
!(test (if-error (catch (rename-file! (path-join &copy "deep") (path-join &copy "deep/deeper"))) refused fine) refused)

; delete-tree! unlinks a link root and leaves its target alone, then removes
; a whole tree.
!(test (delete-tree! (path-join &copy "shortcut")) True)
!(test (dir-exists (path-join &copy "deep")) True)
!(test (delete-tree! &copy) True)
!(test (dir-exists &copy) False)
!(test (delete-dir! (path-join &dir "copies")) True)

; Lexical paths never touch the filesystem; path-resolve does.
!(test (path-join "reports" "sales.csv") "reports/sales.csv")
!(test (path-parent "reports/sales.csv") "reports")
!(test (path-name "reports/sales.csv") "sales.csv")
!(test (path-extension "reports/sales.tar.gz") "gz")
!(test (path-stem "reports/sales.tar.gz") "sales.tar")
!(test (path-parts "/reports/2026/sales.csv") ("/" "reports" "2026" "sales.csv"))
!(test (path-normalize "reports/./2026/../sales.csv") "reports/sales.csv")
!(test (path-normalize "/x/../../y") "/y")
!(test (path-relative "/a/b/c" "/a/d") "../b/c")
!(test (path-absolute "/x/./y") "/x/y")
!(test (path-parent (path-absolute "rel")) (path-absolute "."))
!(test (path-resolve (path-join &tree "shortcut/deeper/leaf.txt")) (path-join &tree "deep/deeper/leaf.txt"))
!(test (path-resolve (path-join &tree "deep/up/.hidden")) (path-join &tree ".hidden"))

; Metadata is a queryable snapshot; file-kind names what is missing.
!(test (match (file-metadata! &notes) (size $bytes) $bytes) 5)
!(test (file-kind (path-join &dir "nothing")) missing)
!(test (if-error (catch (read-link &notes)) refused fine) refused)

; Scopes apply a function to a resource and release it on every exit. The
; function is a name, a lambda or a partial application: these three are named
; so the claims below read as what they are, and a two-answer body shows that
; every answer streams while the handle is still open.
(= (size-then-two $h) (file-get-size! $h))
(= (size-then-two $h) (file-read-exact! $h 2))
(= (fill-and-list $name $work)
   (let* (($written (write-file! (path-join $work $name) $name)))
     (list-dir! $work)))
(= (close-then-read $h)
   (let* (($closed (file-close! $h)))
     (file-read-to-string! $h)))

!(test (with-file &notes "r" file-read-to-string!) "fresh")
!(test (collapse (with-file &notes "r" size-then-two)) (5 "fr"))
!(test (with-file &notes "r" (|-> ($h) (file-get-size! $h))) 5)
!(test (with-temp-dir "file-lib-scope" (fill-and-list "scratch")) ("scratch"))
; A closed handle refuses by name, and a scope body that raises still closes.
!(test (if-error (catch (with-file &notes "r" close-then-read)) refused fine) refused)

; temp-path! mints a fresh file the caller owns; a prefix names, never places.
!(bind! &scratch (temp-path! "file-lib"))
!(test (file-exists &scratch) True)
!(test (delete-file! &scratch) True)
!(test (if-error (catch (temp-path! "logs/run")) refused fine) refused)

; Everything the example made goes with the one directory.
!(test (delete-tree! &dir) True)
!(test (dir-exists &dir) False)
