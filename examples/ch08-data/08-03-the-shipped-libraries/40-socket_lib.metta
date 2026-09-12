; Purpose: exchange TCP bytes and IPv6 datagrams through owned File handles.
; [tested: sh test.sh examples/ch08-data/08-03-the-shipped-libraries/40-socket_lib.metta; commit=WORKTREE].
; Owns resources: the loopback listener, connections and datagram handle close
; below; with-socket closes every scoped acquisition with its answer stream.
!(import! &self (library lib_file))
!(import! &self (library lib_socket))

(: socket-answers (-> Number Number))
(= (socket-answers $handle) (superpose (1 2)))

!(test (path-join "one" "two") "one/two")
!(test (socket-wait! () infinite) ())
!(bind! &listener (tcp-listen! (endpoint ipv4 "127.0.0.1" 0) 8))
!(bind! &address (socket-endpoint &listener local))
!(test (socket-kind &listener) listener)
!(test (let (endpoint $family $host $port) &address $family) ipv4)
!(test (let (endpoint $family $host $port) &address $host) "127.0.0.1")
!(test (let (endpoint $family $host $port) &address (> $port 0)) True)
!(test (socket-wait! (&listener) 0) ())
!(bind! &client (tcp-connect! &address))
!(test (socket-wait! (&listener) infinite) (&listener))
!(bind! &accepted (tcp-accept! &listener))
!(test (socket-kind &client) tcp)
!(test (socket-kind &accepted) tcp)
!(test (socket-endpoint &accepted local) &address)
!(test (socket-endpoint &client peer) &address)
!(test (socket-endpoint &accepted peer) (socket-endpoint &client local))

; File's byte doors carry TCP data. Readiness retains duplicate handles, and
; shutting down output sends EOF while the other direction remains usable.
!(test (file-write-bytes! &client (0 128 255 10)) True)
!(test (socket-wait! (&accepted &accepted) infinite) (&accepted &accepted))
!(test (file-read-bytes! &accepted 2) (0 128))
!(test (file-read-bytes! &accepted 2) (255 10))
!(test (socket-shutdown! &client write) True)
!(test (file-read-bytes! &accepted) ())
!(test (file-write-bytes! &accepted (42)) True)
!(test (file-read-bytes! &client 1) (42))
!(test (socket-shutdown! &accepted both) True)
!(test (file-close! &listener) True)
!(test (file-close! &client) True)
!(test (file-close! &accepted) True)
!(test (file-close! &accepted) True)

; Each UDP send is one packet. The sender's actual IPv6 endpoint accompanies
; its bytes, including a packet with no bytes at all.
!(bind! &udp (udp-bind! (endpoint ipv6 "::1" 0)))
!(bind! &udp-address (socket-endpoint &udp local))
!(test (socket-kind &udp) udp)
!(test (let (endpoint $family $host $port) &udp-address $family) ipv6)
!(test (let (endpoint $family $host $port) &udp-address $host) "::1")
!(test (socket-wait! (&udp) 0) ())
!(test (udp-send! &udp &udp-address (0 255 1)) True)
!(test (udp-send! &udp &udp-address ()) True)
!(test (socket-wait! (&udp) infinite) (&udp))
!(test (udp-receive! &udp) (datagram &udp-address (0 255 1)))
!(test (udp-receive! &udp) (datagram &udp-address ()))

; Refusals happen before an invalid send or acquisition changes the network.
!(test (if-error (catch (udp-send! &udp &udp-address (256))) refused fine) refused)
!(test (socket-wait! (&udp) 0) ())
!(test (if-error (catch (udp-send! &udp (endpoint ipv4 "127.0.0.1" 1) ())) refused fine) refused)
!(test (if-error (catch (socket-endpoint &udp peer)) refused fine) refused)
!(test (if-error (catch (tcp-accept! &udp)) refused fine) refused)
!(test (if-error (catch (socket-shutdown! &udp write)) refused fine) refused)
!(test (file-close! &udp) True)
!(test (if-error (catch (socket-kind &udp)) refused fine) refused)
!(test (if-error (catch (udp-bind! (endpoint unknown "127.0.0.1" 0))) refused fine) refused)
!(test (if-error (catch (udp-bind! (endpoint ipv4 "" 0))) refused fine) refused)
!(test (if-error (catch (udp-bind! (endpoint ipv4 "127.0.0.1" 65536))) refused fine) refused)
!(test (if-error (catch (tcp-connect! (endpoint ipv4 "127.0.0.1" 0))) refused fine) refused)
!(test (if-error (catch (tcp-listen! (endpoint ipv4 "127.0.0.1" 0) -1)) refused fine) refused)
!(test (if-error (catch (socket-wait! () -1)) refused fine) refused)
!(test (if-error (catch (transaction (udp-bind! (endpoint ipv4 "127.0.0.1" 0)))) refused fine) refused)

; The scope keeps a resource until all callback answers end, then closes it.
!(test (collapse (with-socket (udp-bind! (endpoint ipv4 "127.0.0.1" 0)) socket-answers)) (1 2))
!(test (with-socket (udp-bind! (endpoint ipv4 "127.0.0.1" 0)) socket-kind) udp)
!(bind! &closed (with-socket (udp-bind! (endpoint ipv4 "127.0.0.1" 0)) (lambda $handle $handle)))
!(test (if-error (catch (socket-kind &closed)) refused fine) refused)
