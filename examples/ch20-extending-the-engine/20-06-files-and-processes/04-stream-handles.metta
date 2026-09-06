; Purpose: reach standard input, output and error through the handle surface.
; [tested: lib_file_surface:standard_streams_are_handles_zero_one_and_two; commit=b96e1a15260b7538a8e42be613bcc5dd0dddd136]
!(import! &self (library lib_file))

; The three streams a process always has are HANDLES, POSIX's own numbers, in
; the same table file-open! fills. So every handle operation reaches them and
; there is no second vocabulary to learn.
!(test (stdin) 0)
!(test (stdout) 1)
!(test (stderr) 2)

; A spelling, not a second mechanism: (stderr! $text) is this write, and
; (stdin-to-string!) is (file-read-to-string! (stdin)). Use the short names for
; the two common cases and the handles when you want the rest of the surface.
!(test (file-write! (stderr) "through the handle\n") True)
!(test (stderr! "through the short name\n") True)

; file-write! adds no newline, which is what makes it the one to use when the
; output is a fragment rather than a line.
!(test (file-write! (stdout) "a fragment") True)
!(test (file-write! (stdout) " and its end\n") True)

; Closing one is refused. The process owns them, the engine's own diagnostics
; go to standard error, and there is no way to put a closed one back; a cleanup
; loop over every handle it has seen would otherwise do it by accident.
!(test (if-error (catch (file-close! (stderr))) refused fine) refused)
!(test (file-write! (stderr) "still writable\n") True)

; A minted handle starts past them, so an ordinary file can never collide.
!(bind! &path (temp-path! "stream-handles"))
!(test (write-file! &path "x") True)
!(test (let $handle (file-open! &path "r")
         (let $ok (> $handle 2)
           (let $_ (file-close! $handle) $ok)))
       True)
!(test (delete-file! &path) True)
