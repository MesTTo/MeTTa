% Purpose: verify that a MeTTa program can query execution observations.
% Guarantees: selected trace records retain source execution results and depths
%   [tested: lib_observe; commit=504f8dddfa890ced97e795a13ab10e239b1de2ce].
% Guarantees: a trace-event atom carries the whole event, its sequence number
%   and time first, in the tracer's own field order
%   [tested: lib_observe:filtered_events_are_queryable; commit=e54c3654b9e0d3d040560d12c105a54303f63af7].
:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(lib_observe).

test(filtered_events_are_queryable) :-
    process_metta_string("!(import! &self (library lib_observe))\n(= (observe-inc $x) (+ $x 1))\n(= (observe-outer $x) (observe-inc $x))\n!(bind! &observe-report (trace-source &self \"!(observe-outer 4)\" (observe-inc) 10))\n!(match &observe-report (trace-event $seq $time $d exit (observe-inc 4) $answer) ($d $answer))", Results),
    last(Results, [1, 5]),
    process_metta_string("!(space-atom-count &observe-report)", [3]).

test(empty_filter_keeps_execution_and_reports_completion) :-
    process_metta_string("!(import! &self (library lib_observe))\n!(bind! &observe-empty (trace-source &self \"!(add-atom &self (observed-write 7))\" () 1))\n!(space-atom-count &observe-empty)\n!(match &self (observed-write $x) $x)", Results),
    reverse(Results, [7, 1|_]).

:- end_tests(lib_observe).
