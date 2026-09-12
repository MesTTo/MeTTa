; Purpose: YAML documents as values, in the shape lib_json already uses.
; [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/28-yaml_lib.metta; commit=WORKTREE].
!(import! &self (library lib_yaml))

; A mapping becomes a SPACE of (Key Value) atoms, which is lib_json's own shape,
; so the queries over a YAML document are the queries over a JSON one: `get-keys`
; lists the keys, `get-value` follows one and `json-at` walks a path.
!(bind! &conf (yaml-decode "name: petta
version: 1.5
tags:
  - prolog
  - metta
limits:
  depth: 3
  strict: true
  note:
  nothing: ~
"))
!(test (collapse (get-keys &conf)) (limits name tags version))
!(test (get-value &conf name) "petta")
!(test (get-value &conf version) 1.5)
!(test (get-value &conf tags) ("prolog" "metta"))
!(test (json-at &conf (tags 0)) "prolog")
!(test (json-at &conf (limits depth)) 3)
!(test (json-at &conf (limits strict)) True)
; A key written with NO value decodes as the empty string rather than null: the
; host's reader does not distinguish `note:` from `note: ""`, so a document that
; means null writes `~` or `null`. An absent key has no answer at all.
!(test (json-at &conf (limits note)) "")
!(test (json-at &conf (limits nothing)) Null)
!(test (collapse (get-value &conf missing)) ())

; A sequence becomes an expression and a scalar document stays a scalar, so a
; document that is not a mapping needs no unwrapping.
!(test (yaml-decode "- 1\n- 2\n") (1 2))
!(test (yaml-decode "just text\n") "just text")
!(test (yaml-decode "42\n") 42)
!(test (yaml-decode "true\n") True)
!(test (yaml-decode "null\n") Null)
; An empty document is Null, which is what YAML says it holds.
!(test (yaml-decode "") Null)
; A quoted scalar keeps its type: this is the string "no", not a boolean, because
; YAML 1.2's core schema has only true and false.
!(test (json-at (yaml-decode "k: no\n") (k)) "no")

; Encoding inverts decoding, and the text it writes is one document ending in a
; newline.
!(test (yaml-encode (yaml-decode "a: 1\nb:\n  - x\n")) "a: 1\nb:\n- x\n")
!(test (yaml-encode (1 2 Null True)) "- 1\n- 2\n- null\n- true\n")
!(test (yaml-encode "text") "text\n")
!(test (yaml-encode 7) "7\n")
!(test (yaml-encode Null) "null\n")
; A mapping to encode is a space of pairs, which `dict-space` builds without any
; text in between.
!(test (yaml-encode (dict-space ((a 1) (b "two")))) "a: 1\nb: two\n")
!(test (json-at (yaml-decode (yaml-encode (dict-space ((k 1))))) (k)) 1)

; The file doors are one line each over lib_file: the read is the decode of a
; whole file and the write is an atomic replacement, so a reader never sees half
; a document.
; The scope is lib_file's: `with-temp-dir` applies a function to a directory it
; creates and removes, so the example leaves nothing behind.
(= (write-and-read $dir)
   (let $path (path-join $dir "conf.yaml")
     (let $written (yaml-write! $path (dict-space ((host "localhost") (port 8080))))
       (let $text (read-file! $path)
         ($text (json-at (yaml-read! $path) (port)))))))
!(test (with-temp-dir "yaml-lib" write-and-read)
       ("host: localhost\nport: 8080\n" 8080))

; The four refusals. A stream with more than one document is refused naming the
; marker, because the host's reader takes one and answering the first would answer
; less than the text says.
!(test (if-error (catch (yaml-decode "a: 1\n---\nb: 2\n")) refused fine) refused)
; A tag the host has no value for is refused naming the tag, where it would
; otherwise answer an opaque term no MeTTa form can read.
!(test (if-error (catch (yaml-decode "k: !foo 1\n")) refused fine) refused)
; Malformed text is refused with the line the host stopped on, and a duplicate
; key is refused rather than silently keeping one of the two.
!(test (if-error (catch (yaml-decode "a: [1,\n")) refused fine) refused)
!(test (if-error (catch (yaml-decode "dup: 1\ndup: 2\n")) refused fine) refused)
!(test (if-error (catch (yaml-decode 7)) refused fine) refused)
; A space that is not a mapping is refused naming the atom that is not a pair,
; because encoding it would lose the atom.
!(bind! &notamap (new-space))
!(add-atom &notamap (a 1 2))
!(test (if-error (catch (yaml-encode &notamap)) refused fine) refused)
; A symbol encodes as the string it spells, so an expression of symbols is a
; sequence of strings rather than a refusal.
!(test (yaml-encode (one two)) "- one\n- two\n")
