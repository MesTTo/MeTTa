; Purpose: query a trace collected for one named function.
!(import! &self (library lib_observe))
(= (trace-increment $x) (+ $x 1))
(= (trace-outer $x) (trace-increment $x))
!(bind! &trace (trace-source &self "!(trace-outer 4)" (trace-increment) 10))
; An event carries its sequence number and the wall nanoseconds since the run
; began before its depth, so a program reading this space can order and time
; what it reads: a space is a bag and the events arrive in no order at all.
!(test (match &trace (trace-event $seq $time $depth call (trace-increment 4) $answer) $depth) 1)
!(test (match &trace (trace-event $seq $time $depth exit (trace-increment 4) $answer) $answer) 5)
!(test (match &trace (trace-event 0 $time $depth call (trace-increment 4) $answer) $depth) 1)
!(test (match &trace (trace-stopped $reason) $reason) False)
!(test (space-atom-count &trace) 3)
