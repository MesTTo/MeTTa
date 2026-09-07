;Two handle operations the file chapter has not used yet: moving the cursor,
;and asking how big the file is rather than how much of it is left.
!(import! &self (library lib_file))

;`file-get-size!` answers the size of the FILE, in characters, and it does
;not move or consult the cursor: asking twice, once at the start and once
;after everything has been read, answers the same number.
!(test (let* (($path (temp-path! "seek"))
              ($written (write-file! $path "hello world"))
              ($handle (file-open! $path "r"))
              ($before (file-get-size! $handle))
              ($all (file-read-to-string! $handle))
              ($after (file-get-size! $handle))
              ($closed (file-close! $handle))
              ($gone (delete-file! $path)))
         ($before $all $after))
       (11 "hello world" 11))

;`file-seek!` moves the cursor to a character offset, so the next read starts
;there. Reading to the end, seeking back, and reading again is how a file is
;read twice without being opened twice.
!(test (let* (($path (temp-path! "seek"))
              ($written (write-file! $path "hello world"))
              ($handle (file-open! $path "r"))
              ($first (file-read-to-string! $handle))
              ($rewound (file-seek! $handle 0))
              ($second (file-read-to-string! $handle))
              ($closed (file-close! $handle))
              ($gone (delete-file! $path)))
         ($first $second))
       ("hello world" "hello world"))

;Seeking to an offset in the middle answers the tail from there, which is
;what makes the pair a random-access read rather than a stream.
!(test (let* (($path (temp-path! "seek"))
              ($written (write-file! $path "hello world"))
              ($handle (file-open! $path "r"))
              ($moved (file-seek! $handle 6))
              ($tail (file-read-to-string! $handle))
              ($closed (file-close! $handle))
              ($gone (delete-file! $path)))
         $tail)
       "world")

;Which is the difference the header names: after seeking to the end there is
;nothing left to read, and the SIZE is unchanged.
!(test (let* (($path (temp-path! "seek"))
              ($written (write-file! $path "hello world"))
              ($handle (file-open! $path "r"))
              ($size (file-get-size! $handle))
              ($moved (file-seek! $handle $size))
              ($rest (file-read-to-string! $handle))
              ($again (file-get-size! $handle))
              ($closed (file-close! $handle))
              ($gone (delete-file! $path)))
         ($size $rest $again))
       (11 "" 11))

;`file-read-exact!` takes at most n characters from the cursor, so seek and
;exact read together walk a file in fixed-size pieces.
!(test (let* (($path (temp-path! "seek"))
              ($written (write-file! $path "hello world"))
              ($handle (file-open! $path "r"))
              ($first (file-read-exact! $handle 5))
              ($moved (file-seek! $handle 6))
              ($second (file-read-exact! $handle 5))
              ($closed (file-close! $handle))
              ($gone (delete-file! $path)))
         ($first $second))
       ("hello" "world"))
