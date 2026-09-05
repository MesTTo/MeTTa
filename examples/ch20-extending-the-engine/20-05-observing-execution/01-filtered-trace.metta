; Purpose: query a trace collected for one named function.
!(import! &self (library lib_observe))
(= (trace-increment $x) (+ $x 1))
(= (trace-outer $x) (trace-increment $x))
!(bind! &trace (trace-source &self "!(trace-outer 4)" (trace-increment) 10))
!(test (match &trace (trace-event $depth call (trace-increment 4) $answer) $depth) 1)
!(test (match &trace (trace-event $depth exit (trace-increment 4) $answer) $answer) 5)
!(test (match &trace (trace-stopped $reason) $reason) False)
!(test (space-atom-count &trace) 3)
