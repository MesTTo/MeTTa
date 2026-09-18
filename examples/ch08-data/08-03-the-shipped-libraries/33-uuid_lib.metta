; Purpose: UUID generations, namespaces, complete names and byte round trips.
; [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/33-uuid_lib.metta; commit=8fe20f1bdcde1af8b3e1753c545924f978246dba].
!(import! &self (library lib_crypto))
!(import! &self (library lib_uuid))
!(import! &self (library lib_encoding))
!(import! &self (library lib_string))

; Choose random identifiers explicitly. Version 1 contains a timestamp and may
; contain the host's MAC address; identifiers are not secrets.
!(test (size-atom (crypto-random-bytes 16)) 16)
!(test (uuid-version (uuid-random!)) 4)
!(test (uuid-variant (uuid-random!)) rfc)
!(test (uuid-is (uuid-random!)) True)
!(test (!= (uuid-random!) (uuid-random!)) True)
!(test (uuid-version (uuid-time!)) 1)
!(test (uuid-variant (uuid-time!)) rfc)
!(test (> (uuid-timestamp (uuid-time!)) 0) True)

; Names are deterministic and namespaces are values, including an application's
; own UUID String. These DNS vectors agree with Python's uuid3 and uuid5.
!(test (uuid-namespaces) (dns url oid x500))
!(test (uuid-name 3 dns "example.com") "9073926b-929f-31c2-abc9-fad77ae3e8eb")
!(test (uuid-name 5 dns "example.com") "cfbff0d1-9375-5685-968c-48ce8b15ae17")
!(test (uuid-name 5 "6ba7b810-9dad-11d1-80b4-00c04fd430c8" "example.com")
       (uuid-name 5 dns "example.com"))
!(test (uuid-name 3 url "http://example.com") "d632b50c-7913-3137-ae9a-2d93f56e70d5")
!(test (uuid-name 5 oid "1.3.6.1.4.1") "106dd502-8b3e-50db-80ed-1134f5c18eae")
!(test (uuid-name 5 x500 "cn=Test") "1a09ab7e-5f76-53b6-b866-3b565a53dc51")
!(test (uuid-name 5 dns "") "4ebd0208-8328-5d69-8c44-ec50939c0967")
!(test (uuid-name 5 dns "é") "ebfe0af8-3997-5ade-b634-ba92cf69f557")
!(test (uuid-name 3 dns "漢") "1f9d873c-79c5-37f3-a181-6bab16c1f1c9")
!(test (uuid-name 5 dns (string-from-codes (97 0 98))) "0a63f66b-e02f-5d2d-9fd4-aad819cf5352")

; The nil value is present. Other versions have no version-1 timestamp answer.
!(test (uuid-nil) "00000000-0000-0000-0000-000000000000")
!(test (uuid-is (uuid-nil)) True)
!(test (uuid-version (uuid-nil)) 0)
!(test (uuid-variant (uuid-nil)) ncs)
!(test (uuid-variant "00000000-0000-0000-c000-000000000000") microsoft)
!(test (uuid-variant "ffffffff-ffff-ffff-ffff-ffffffffffff") future)
!(test (uuid-timestamp "13814000-1dd2-11b2-8000-000000000000") 0.0)
!(test (collapse (uuid-timestamp (uuid-random!))) ())
!(test (collapse (uuid-timestamp (uuid-nil))) ())

; Text is canonical lower case on output, and bytes keep all 128 bits.
!(test (uuid-is "CFBFF0D1-9375-5685-968C-48CE8B15AE17") True)
!(test (hex-encode (uuid-bytes "cfbff0d1-9375-5685-968c-48ce8b15ae17"))
       "cfbff0d193755685968c48ce8b15ae17")
!(test (uuid-of-bytes (uuid-bytes "CFBFF0D1-9375-5685-968C-48CE8B15AE17"))
       "cfbff0d1-9375-5685-968c-48ce8b15ae17")
!(test (uuid-bytes (uuid-nil)) (0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0))
!(test (uuid-of-bytes (hex-decode "ffffffffffffffffffffffffffffffff"))
       "ffffffff-ffff-ffff-ffff-ffffffffffff")

; Shape validation answers False; consumers of malformed values name the repair.
!(test (uuid-is "------------------------------------") False)
!(test (uuid-is (string-replace (uuid-nil) "-" (string-from-codes (0)))) False)
!(test (uuid-is "cfbff0d193755685968c48ce8b15ae17") False)
!(test (uuid-is "zfbff0d1-9375-5685-968c-48ce8b15ae17") False)
!(test (uuid-is 3) False)
!(test (if-error (catch (uuid-version "broken")) refused fine) refused)
!(test (if-error (catch (uuid-timestamp "broken")) refused fine) refused)
!(test (if-error (catch (uuid-of-bytes (1 2))) refused fine) refused)
!(test (if-error (catch (uuid-of-bytes (0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 256))) refused fine) refused)
!(test (if-error (catch (uuid-name 2 dns "name")) refused fine) refused)
!(test (if-error (catch (uuid-name 5 missing "name")) refused fine) refused)
!(test (if-error (catch (uuid-name 5 "broken" "name")) refused fine) refused)

; Fields and name derivation can be reconstructed from their stored equations.
!(test (let $recipe
         (match &self (= (uuid-version $id) $body) (quote (|-> ($id) $body)))
         (let $inspect (eval $recipe) ($inspect (uuid-nil)))) 0)
!(test (let $recipe
         (match &self (= (uuid-name $v $ns $name) $body)
           (quote (|-> ($v $ns $name) $body)))
         (let $derive (eval $recipe) ($derive 5 dns "example.com")))
       "cfbff0d1-9375-5685-968c-48ce8b15ae17")
!(test (collapse (uuid-version (superpose
         ("00000000-0000-0000-0000-000000000000" "ffffffff-ffff-ffff-ffff-ffffffffffff"))))
       (0 15))
!(test (uuid-name 3 dns (string-from-codes (97 0 98)))
       "002a0ada-f547-375a-bab5-896a11d1927e")
