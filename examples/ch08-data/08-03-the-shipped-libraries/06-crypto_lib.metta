; Purpose: content keys, authenticated bytes, secure values and password records.
; Guarantees: the example calls every crypto head and both password arities
; [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/06-crypto_lib.metta; commit=WORKTREE].

!(import! &self (library lib_crypto))

!(test (crypto-hash sha256 "hello")
       "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
!(test (crypto-hash sha512 "hello")
       "9b71d224bd62f3785d96d46ad3ea3d73319bfbc2890caadae2dff72519673ca72323c3d99ba5c11d7c7acc6e14b8c5da0c4663475c2e5c3adef46f73bcdec043")

;A content key: the fact carries the digest of its own payload.
(= (content-key $text) (crypto-hash sha256 $text))
!(test (content-key "hello")
       "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")

;;; Text uses UTF-8. The byte door preserves each octet, including zero.
!(test (crypto_hash sha256 "hello")
       "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
!(test (crypto-hash-bytes sha256 (104 101 108 108 111))
       "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
!(test (crypto-hash-bytes sha256 ())
       "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
!(test (crypto-hmac sha256 "Jefe" "what do ya want for nothing?")
       "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843")
!(test (crypto-hmac-bytes sha256 (195 169) (0 255))
       "6a96aac37f1ab07208ddcd8a71292bd9fc92722a85ca984fa3adcd07fede237d")

;;; A zero-sized token is empty; real requests draw secure random bytes.
!(import! &self (library lib_string))
!(test (crypto_random_hex 0) "")
!(test (string-length (crypto-random-hex 4)) 8)
!(test (crypto-random-bytes 0) ())
!(test (size-atom (crypto-random-bytes 8)) 8)
!(test (crypto-random-integer -9 -8) -9)
!(test (let $n (crypto-random-integer -20 7) (and (>= $n -20) (< $n 7))) True)

;;; The record carries its parameters and random salt. A valid wrong password
;;; returns False; malformed records raise. Cost 2 is a fast fixture only.
!(test (let $record (crypto-password-hash "fixture")
         (crypto-password-verify "fixture" $record)) True)
!(test (let $record (crypto-password-hash "fixture" 2)
         (crypto-password-verify "fixture" $record)) True)
!(test (let $record (crypto-password-hash "fixture" 2)
         (crypto-password-verify "different" $record)) False)

;;; A file digest reads bytes through a bounded buffer and closes the stream.
!(import! &self (library lib_file))
!(test (let* (($path (temp-path! "crypto-content"))
              ($_ (write-file! $path "hello"))
              ($digest (crypto-hash-file! sha256 $path)))
         (chain (delete-file! $path) $_ $digest))
       "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
