; Purpose: compose URI components, resolve references and encode query relations.
; [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/39-uri_lib.metta; commit=24b96f8ec8468bc97cec35e1d71ce689ede7fdcf].
!(import! &self (library lib_uri))
!(import! &self (library lib_pairs))
!(import! &self (library lib_encoding))

; A missing row differs from a present empty String. Paths and authorities
; retain their encoded spelling, including opaque URNs and IPv6 brackets.
!(test (uri-parts "") (("path" "")))
!(test (uri-parts "?#") (("path" "") ("query" "") ("fragment" "")))
!(test (uri-parts "https://User:Pass@[::1]:0012/a%2Fb?q=1#F")
  (("scheme" "https") ("authority" "User:Pass@[::1]:0012") ("path" "/a%2Fb") ("query" "q=1") ("fragment" "F")))
!(test (uri-parts "urn:Example:ABC") (("scheme" "urn") ("path" "Example:ABC")))
!(test (uri-build ()) "")
!(test (uri-build (("query" "") ("fragment" ""))) "?#")
!(test (uri-build (("path" "/x") ("authority" "host:") ("scheme" "http"))) "http://host:/x")
!(test (uri-build (uri-parts "a:b?x#")) "a:b?x#")

; Generic normalization keeps identifying case and reserved percent bytes.
!(test (uri-normalize "HTTP://User:Pass@HOST/a/%2e%2e/b?x=%7e#F") "http://User:Pass@host/b?x=~#F")
!(test (uri-normalize "urn:Example:ABC") "urn:Example:ABC")
!(test (uri-normalize "http://HOST/%ff/%c0%af/%2f?#") "http://host/%FF/%C0%AF/%2F?#")
!(test (uri-normalize "../a/./b") "../a/./b")
!(test (uri-normalize "foo:/a/..//b") "foo:/.//b")

; Resolution supplies the path context. Empty query replaces an inherited one;
; a reference with its own scheme wins, even when the spelling is http:g.
!(test (uri-resolve "g" "http://a") "http://a/g")
!(test (uri-resolve "../g" "http://a/b/c/d;p?q") "http://a/b/g")
!(test (uri-resolve "?" "http://a/b?old#f") "http://a/b?")
!(test (uri-resolve "#" "http://a/b?old#f") "http://a/b?old#")
!(test (uri-resolve "" "http://a/b?old#f") "http://a/b?old")
!(test (uri-resolve "//other/x" "http://a/b") "http://other/x")
!(test (uri-resolve "http:g" "http://a/b") "http:g")
!(test (uri-resolve "urn:Example:ABC" "http://a/b") "urn:Example:ABC")
!(test (uri-resolve "g?y/../x" "http://a/b/c/d;p?q") "http://a/b/c/g?y/../x")
!(test (uri-resolve "%2e%2e/g" "http://a/b/") "http://a/b/%2e%2e/g")

; Encode raw data in the component where it will live. Decode after splitting.
!(test (uri-contexts) (path segment query-value fragment))
!(test (uri-encode path "a b/c?d") "a%20b/c%3Fd")
!(test (uri-encode segment "a b/c?d") "a%20b%2Fc%3Fd")
!(test (uri-encode query-value "a+b&c=d") "a%2Bb%26c%3Dd")
!(test (uri-encode fragment "a+b&c=d/x?y") "a+b&c=d/x?y")
!(test (uri-encode segment "π🙂") "%CF%80%F0%9F%99%82")
!(test (uri-encode segment (utf8-decode (97 0 98))) "a%00b")
!(test (uri-decode "%CF%80%F0%9F%99%82") "π🙂")
!(test (uri-decode "%252F+a") "%2F+a")
!(test (utf8-encode (uri-decode "%00x")) (0 120))

; Query pairs compose with the shared relation library. The style controls
; plus in both keys and values; repeated and empty-valued rows survive.
!(test (uri-query-parse uri "a+b=c+d&&a=2&bare&empty=&")
  (("a+b" "c+d") ("a" "2") ("bare" "") ("empty" "")))
!(test (uri-query-parse form "a+b=c+d&&a=2&bare&empty=&")
  (("a b" "c d") ("a" "2") ("bare" "") ("empty" "")))
!(test (uri-query-parse uri "a=1;b=2&=x") (("a" "1;b=2") ("" "x")))
!(test (uri-query-parse form "") ())
!(test (uri-query-build uri (("a b" "c+d") ("a b" "") ("" "π🙂")))
  "a%20b=c%2Bd&a%20b=&=%CF%80%F0%9F%99%82")
!(test (uri-query-build form (("a b" "c+d") ("a b" "") ("" "π🙂")))
  "a+b=c%2Bd&a+b=&=%CF%80%F0%9F%99%82")
!(test (uri-query-build form ()) "")
!(test (collapse (pairs-lookup (uri-query-parse uri "a=1&a=2&b=3") "a")) ("1" "2"))
!(test (uri-query-build form (uri-query-parse form "%2B=%00&x=a/b?c")) "%2B=%00&x=a/b?c")

; Invalid bytes and ambiguous component boundaries require a repair.
!(test (if-error (catch (uri-parts "a b")) refused fine) refused)
!(test (if-error (catch (uri-parts (utf8-decode (97 0 98)))) refused fine) refused)
!(test (if-error (catch (uri-parts "x%ZZ")) refused fine) refused)
!(test (if-error (catch (uri-build (("path" "a") ("authority" "host")))) refused fine) refused)
!(test (if-error (catch (uri-build (("path" "a") ("path" "b")))) refused fine) refused)
!(test (if-error (catch (uri-build (("missing" "x")))) refused fine) refused)
!(test (if-error (catch (uri-resolve "x" "relative")) refused fine) refused)
!(test (if-error (catch (uri-encode missing "x")) refused fine) refused)
!(test (if-error (catch (uri-decode "%")) refused fine) refused)
!(test (if-error (catch (uri-decode "%FF")) refused fine) refused)
!(test (if-error (catch (uri-decode "%C0%AF")) refused fine) refused)
!(test (if-error (catch (uri-query-parse form "x=%ED%A0%80")) refused fine) refused)
!(test (if-error (catch (uri-query-build missing ())) refused fine) refused)
