% Purpose: detect first-argument lookup work from retired dynamic-clause keys.
% Assumes: the host exposes '$cgc_params'/6 to keep automatic collection from
%   erasing the state under inspection; the explicit collected arm controls it.
% Guarantees: reports the retained and collected bytes, CPU time and inference
%   counts; equal inference counts and a second collected sample check that
%   the comparison measures the hidden clause scan [tested: sh check.sh
%   host-workarounds; commit=WORKTREE].
% Owns resources: this fresh process's dynamic clauses and collection policy;
%   neither survives process exit.
% Decides: a fourfold CPU ratio distinguishes the scan from the collected
%   control; an unstable collected control is broken rather than absent.

:- dynamic cursor/2.

main :-
    set_prolog_gc_thread(false),
    system:'$cgc_params'(_, _, _, 0, 1.0e20, 1.0e20),
    scan_control(20000, Retained, Collected, Control),
    format('retained=~q collected=~q collected_control=~q~n',
           [Retained, Collected, Control]),
    Retained = sample(_, Before, I0),
    Collected = sample(_, After, I1),
    Control = sample(_, Again, I2),
    ( ( I0 =\= I1 ; I1 =\= I2 )
    -> throw(error(unequal_lookup_inferences(I0, I1, I2), _))
    ; ( After =< 0 ; Again =< 0 ; After > 4*Again ; Again > 4*After )
    -> throw(error(unstable_collected_control(After, Again), _))
    ; Before > 4*After -> writeln(present)
    ; writeln(absent) ).

% Retract marks the generation and leaves ClauseRef objects in the primary
% index until clause collection. The live tail forces lookup past dead keys;
% an empty predicate would return before scanning any of them.
% https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-proc.c#L2248-L2276
% https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-index.c#L293-L346
scan_control(Count, Before, After, Control) :-
    forall(between(1, Count, Id),
           ( assertz(cursor(Id, row)), retract(cursor(Id, _)) )),
    Last is Count+1,
    assertz(cursor(Last, row)),
    measure(Last, Before),
    garbage_collect_clauses,
    measure(Last, After), measure(Last, Control).

measure(Last, sample(Bytes, Seconds, Inferences)) :-
    predicate_property(cursor(_, _), size(Bytes)),
    statistics(cputime, BeforeTime), statistics(inferences, BeforeInferences),
    forall(between(1, 10000, _), cursor(Last, row)),
    statistics(inferences, AfterInferences), statistics(cputime, AfterTime),
    Seconds is AfterTime-BeforeTime,
    Inferences is AfterInferences-BeforeInferences.
