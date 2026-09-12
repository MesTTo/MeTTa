; Purpose: compress complete byte streams and extract validated archive data.
; [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/41-compression_lib.metta; commit=7b42d5ee5cecb82709617b7ed08dfa2c1441f268].
; Owns resources: the temporary directory is removed below; each library call
; owns its streams and staging files until it succeeds or raises.
!(import! &self (library lib_file))
!(import! &self (library lib_compression))

!(test (compression-formats) (gzip zlib))
!(test (path-join "one" "two") "one/two")
!(bind! &bytes (0 128 255 10))
!(bind! &gzip (compress-bytes gzip 6 &bytes))
!(bind! &zlib (compress-bytes zlib 6 &bytes))
!(test (car-atom &gzip) 31)
!(test (car-atom (cdr-atom &gzip)) 139)
!(test (decompress-bytes gzip &gzip) &bytes)
!(test (decompress-bytes zlib &zlib) &bytes)
!(test (decompress-bytes gzip (compress-bytes gzip 0 ())) ())
!(test (decompress-bytes zlib (compress-bytes zlib 9 ())) ())
!(test (decompress-bytes gzip (compress-bytes gzip 9 (1 1 1 1 1))) (1 1 1 1 1))
!(test (decompress-bytes zlib (compress-bytes zlib 0 (1 2 3))) (1 2 3))

; Formats and bytes are validated before acquiring output resources. Decoding
; requires a complete member, including its checksum and size trailer.
!(test (if-error (catch (compress-bytes invented 6 &bytes)) refused fine) refused)
!(test (if-error (catch (compress-bytes gzip -1 &bytes)) refused fine) refused)
!(test (if-error (catch (compress-bytes gzip 10 &bytes)) refused fine) refused)
!(test (if-error (catch (compress-bytes gzip 6 (256))) refused fine) refused)
!(test (if-error (catch (compress-bytes gzip 6 (-1))) refused fine) refused)
!(test (if-error (catch (decompress-bytes gzip ())) refused fine) refused)
!(test (if-error (catch (decompress-bytes gzip (31 139))) refused fine) refused)
!(test (if-error (catch (decompress-bytes zlib &gzip)) refused fine) refused)
!(test (if-error (catch (decompress-bytes gzip &zlib)) refused fine) refused)

; File operations stream bytes and publish after close. Replacing the input
; itself works because the original remains open until staging is complete.
!(bind! &work (temp-dir! "compression-lib"))
!(bind! &source (path-join &work "source"))
!(bind! &packed (path-join &work "packed.gz"))
!(bind! &restored (path-join &work "restored"))
!(test (write-bytes! &source &bytes) True)
!(test (compress-file! gzip 6 &source &packed) True)
!(test (decompress-bytes gzip (read-bytes! &packed)) &bytes)
!(test (decompress-file! gzip &packed &restored) True)
!(test (read-bytes! &restored) &bytes)
!(test (compress-file! zlib 0 &source &source) True)
!(test (decompress-file! zlib &source &source) True)
!(test (read-bytes! &source) &bytes)
!(test (write-bytes! &packed (31 139)) True)
!(test (if-error (catch (decompress-file! gzip &packed &restored)) refused fine) refused)
!(test (read-bytes! &restored) &bytes)

; Entries retain native metadata and zero-based ordinals, which distinguish
; repeated names. An ordinal read selects a regular file, not a directory.
!(bind! &fixtures "examples/ch08-data/08-03-the-shipped-libraries/_fixtures")
!(bind! &fixture (path-join &fixtures "compression-data.zip"))
!(bind! &entries (archive-entries! &fixture))
!(test (size-atom &entries) 4)
!(test (let (archive-entry $index $name $properties) (car-atom &entries) ($index $name)) (0 "./"))
!(test (archive-read! &fixture 2) &bytes)
!(test (archive-read! &fixture 3) ())
!(test (if-error (catch (archive-read! &fixture 0)) refused fine) refused)
!(test (if-error (catch (archive-read! &fixture 4)) refused fine) refused)
!(bind! &extracted (path-join &work "extracted"))
!(test (archive-extract! &fixture &extracted) True)
!(test (read-bytes! (path-join &extracted "sub/bytes.bin")) &bytes)
!(test (read-bytes! (path-join &extracted "empty")) ())
!(test (if-error (catch (archive-extract! &fixture &extracted)) refused fine) refused)
!(test (read-bytes! (path-join &extracted "sub/bytes.bin")) &bytes)

; A gzip envelope around ZIP retains the same entries. Decoding supplies a
; seekable archive and validates every gzip layer before extraction publishes.
!(test (compress-file! gzip 6 &fixture &packed) True)
!(test (archive-entries! &packed) &entries)
!(test (archive-read! &packed 2) &bytes)
!(bind! &second (path-join &work "second"))
!(test (archive-extract! &packed &second) True)
!(test (read-bytes! (path-join &second "sub/bytes.bin")) &bytes)

; ZIP names use their declared Unicode form or the format's CP437 default.
!(test (let (archive-entry $index $name $properties) (car-atom (archive-entries! (path-join &fixtures "compression-unicode.zip"))) $name) "café/π🙂")
!(test (let (archive-entry $index $name $properties) (car-atom (archive-entries! (path-join &fixtures "compression-legacy.zip"))) $name) "café")
!(test (let (archive-entry $index $name $properties) (car-atom (archive-entries! (path-join &fixtures "compression-unicode-extra.zip"))) $name) "café/π🙂")

; An archive can be inspected even when its paths cannot be extracted safely.
!(bind! &unsafe (path-join &fixtures "compression-unsafe.zip"))
!(bind! &refused (path-join &work "refused"))
!(test (archive-read! &unsafe 0) (42))
!(test (if-error (catch (archive-extract! &unsafe &refused)) refused fine) refused)
!(test (dir-exists &refused) False)
!(test (file-exists (path-join &work "escape")) False)
!(test (delete-tree! &work) True)
