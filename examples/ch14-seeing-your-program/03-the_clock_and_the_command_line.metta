;Three doors onto the world outside the program: the wall clock, its written
;form, and the arguments the process was started with. They are here rather
;than in the file chapter because what they answer is about the RUN rather
;than about any data the program holds.
!(import! &self (library lib_string))

;`current-time` answers Unix time as a float, seconds since 1970. It is the
;raw number, so arithmetic on it is ordinary arithmetic.
!(test (> (current-time) 1700000000.0) True)

;It moves forward and never backward, which is the one property a program
;timing itself depends on. Two reads in one expression evaluate left to
;right, so the first is never the later one.
!(test (<= (current-time) (current-time)) True)

;`format-time` writes the CURRENT time through an strftime format string, so
;it is `current-time` and a rendering in one call rather than two. Everything
;that is not a directive is copied through. The answer is a NAME rather than
;a String, which is what the format string is measured against below.
!(test (format-time "abc") abc)
!(test (== (format-time "abc") "abc") False)
!(test (string-length (format-time "a literal")) 9)
!(test (string-length (format-time "")) 0)
;A doubled per cent is the one escape, and it writes one character.
!(test (string-length (format-time "%%")) 1)

;The directives are strftime's own, so a year is four characters and an ISO
;date is ten, whatever day this file runs on.
!(test (string-length (format-time "%Y")) 4)
!(test (string-length (format-time "%Y-%m-%d")) 10)
!(test (string-length (format-time "%H:%M:%S")) 8)

;`argv` reads the process's own argument list by index, zero-based, and it is
;the arguments the engine was given rather than the whole command line.
;Reading past the end answers NOTHING, which is one answer fewer than an
;error and exactly what a caller checking for an optional argument wants.
!(test (collapse (argv 999)) ())
!(test (collapse (argv -1)) ())

;An argument that reads as a number arrives as one, so a numeric option needs
;no parsing step of its own.
!(test (== (argv 0) (argv 0)) True)

;Which makes "is there an argument here" a collapse rather than a length: the
;empty tuple is the absent argument, and a present one is a one-element bag.
(= (argument-or $index $default)
   (let $found (collapse (argv $index))
        (if (== $found ()) $default (car-atom $found))))
!(test (argument-or 999 no-such-argument) no-such-argument)
!(test (== (argument-or 0 no-such-argument) no-such-argument) False)
