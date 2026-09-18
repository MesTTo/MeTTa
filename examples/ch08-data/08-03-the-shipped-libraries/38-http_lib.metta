; Purpose: route local HTTP requests through MeTTa equations and owned byte streams.
; [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/38-http_lib.metta; commit=0f22b69cfca5c108e4126bdd56ab9bb2e493744d].
; Owns resources: the named server is stopped below; scoped servers and response
; handles close through their owners. Every request stays on loopback.
!(import! &self (library lib_http))
!(import! &self (library lib_encoding))

; Routes are equations over the request's method and decoded path. Target keeps
; its encoded query, and incoming fields preserve duplicate and parsed values.
(: library-http (-> Expression Expression))
(= (library-http (http-request $method "/" $target $fields $body))
   (http-response 200 (("X-Reply" "one") ("X-Reply" "two")) (0 128 255)))
(= (library-http (http-request $method "/echo" $target $fields $body))
   (http-response 201 (("Content-Type" "text/plain; charset=UTF-8")
                       ("X-Method" (repr $method)) ("X-Target" $target)) $body))
(= (library-http (http-request $method "/absent" $target $fields $body))
   (http-response 404 () ()))
(= (library-http (http-request $method "/redirect" $target $fields $body))
   (http-response 307 (("Location" "/")) ()))
(= (library-http (http-request $method "/empty" $target $fields $body)) (empty))
(= (library-http (http-request $method "/broken" $target $fields $body)) (broken-response 7))

(: read-http (-> Expression Expression))
(= (read-http (http-response $status $fields $handle)) (file-read-bytes! $handle))
(: ping-http (-> Expression Expression))
(= (ping-http $server)
   (http-request! get (http-server-url $server) ()))

!(test (http-methods) (delete get head post put patch options))
!(bind! &server (http-server-start! "127.0.0.1" 0 library-http ((workers 2))))
!(bind! &url (http-server-url &server))
!(bind! &echo (string-join "" (&url "echo?q=one%20two")))
!(bind! &response (http-request! get &url ((timeout 5))))
!(test (let (http-response $code $fields $bytes) &response $code) 200)
!(test (let (http-response $code $fields $bytes) &response $bytes) (0 128 255))
!(test (let (http-response $code $fields $bytes) &response
         (http-header $fields "Content-Type")) "application/octet-stream")
!(test (let (http-response $code $fields $bytes) &response
         (http-header $fields "CONTENT-LENGTH")) 3)
!(test (let (http-response $code $fields $bytes) &response
         (collapse (http-header $fields "x-reply"))) ("one" "two"))
!(test (let (http-response $code $fields $bytes) &response
         (collapse (http-header $fields "missing"))) ())

; HEAD preserves representation metadata and exposes an empty byte stream.
!(bind! &head (http-request! head &url ()))
!(test (let (http-response $code $fields $bytes) &head $code) 200)
!(test (let (http-response $code $fields $bytes) &head $bytes) ())
!(test (let (http-response $code $fields $bytes) &head
         (http-header $fields "content-length")) 3)

; Text is explicitly encoded to bytes, so its declared media type does not
; change the payload. Every method uses the same request shape.
!(bind! &posted (http-request! post &echo
                 ((body "text/plain; charset=UTF-8" (utf8-encode "aπ🙂"))
                  (header "X-Input" "one") (header "X-Input" "two"))))
!(test (let (http-response $code $fields $bytes) &posted $code) 201)
!(test (let (http-response $code $fields $bytes) &posted (utf8-decode $bytes)) "aπ🙂")
!(test (let (http-response $code $fields $bytes) &posted
         (http-header $fields "x-method")) "post")
!(test (let (http-response $code $fields $bytes) &posted
         (http-header $fields "x-target")) "/echo?q=one%20two")
!(test (let (http-response $code $fields $bytes) (http-request! put &echo ())
         (http-header $fields "x-method")) "put")
!(test (let (http-response $code $fields $bytes) (http-request! patch &echo ())
         (http-header $fields "x-method")) "patch")
!(test (let (http-response $code $fields $bytes) (http-request! delete &echo ())
         (http-header $fields "x-method")) "delete")
!(test (let (http-response $code $fields $bytes) (http-request! options &echo ())
         (http-header $fields "x-method")) "options")

; HTTP errors are responses. An empty handler gives404; a malformed one gives500.
!(test (let (http-response $code $fields $bytes)
            (http-request! get (string-join "" (&url "absent")) ()) $code) 404)
!(test (let (http-response $code $fields $bytes)
            (http-request! get (string-join "" (&url "empty")) ()) $code) 404)
!(test (let (http-response $code $fields $bytes)
            (http-request! get (string-join "" (&url "broken")) ()) $code) 500)
!(test (let (http-response $code $fields $bytes)
            (http-request! get (string-join "" (&url "redirect")) ()) $code) 307)
!(test (let (http-response $code $fields $bytes)
            (http-request! get (string-join "" (&url "redirect")) ((redirect True))) $bytes) (0 128 255))

; The streaming door shares File's byte reads and close. The scoped door
; retains the handle until its callback's answers end.
!(bind! &stream (http-open! get &url ()))
!(bind! &handle (let (http-response $code $fields $handle) &stream $handle))
!(test (file-read-bytes! &handle 2) (0 128))
!(test (file-read-bytes! &handle) (255))
!(test (file-close! &handle) True)
!(test (file-close! &handle) True)
!(test (with-http get &url () read-http) (0 128 255))
!(test (let (http-response $status $fields $body)
            (with-http-server "127.0.0.1" 0 library-http ((workers 1)) ping-http) $status) 200)

; Bad input is refused before opening a connection or listener.
!(test (if-error (catch (http-request! invented &url ())) refused fine) refused)
!(test (if-error (catch (http-request! get "file:///etc/passwd" ())) refused fine) refused)
!(test (if-error (catch (http-request! get &url ((header "bad:name" "x")))) refused fine) refused)
!(test (if-error (catch (http-request! get &url ((header "X-Input" "a\nb")))) refused fine) refused)
!(test (if-error (catch (http-request! post &url ((body "application/octet-stream" (256))))) refused fine) refused)
!(test (if-error (catch (http-request! get &url ((timeout 1) (timeout 2)))) refused fine) refused)
!(test (if-error (catch (http-request! get &url ((header "Content-Length" "3")))) refused fine) refused)
!(test (if-error (catch (http-server-start! "127.0.0.1" 0 library-http ((workers 0)))) refused fine) refused)
; A transaction cannot share its uncommitted lifecycle records with workers.
!(test (if-error (catch (transaction (http-server-start! "127.0.0.1" 0 library-http ()))) refused fine) refused)
!(test (if-error (catch (transaction (http-server-stop! &server))) refused fine) refused)
!(test (http-server-stop! &server) True)
!(test (http-server-stop! &server) True)
