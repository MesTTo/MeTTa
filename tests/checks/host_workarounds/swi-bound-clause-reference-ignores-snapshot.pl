% Purpose: compare clause enumeration with bound-reference reads in an old snapshot.
% Guarantees: the last line is present only when enumeration retains the fact
%   but clause/3 with its reference loses it after another thread erases it
%   [tested: sh check.sh host-workarounds; commit=c5bdd73e06840e1d0fd0991523983c75def074f6].
% Owns resources: the erasing thread is joined before inspection; the fixture
%   is removed after the outer transaction finishes.

:- dynamic snapshot_fact/1.

main :-
    setup_call_cleanup(
        ( assertz(snapshot_fact(original)), assertz(snapshot_fact(sentinel)) ),
        transaction(probe(Result)),
        retractall(snapshot_fact(_))),
    writeln(Result).

probe(Result) :-
    once(clause(snapshot_fact(original), true, Ref)),
    thread_create(transaction(retractall(snapshot_fact(original))), Eraser, []),
    thread_join(Eraser, Status),
    ( Status == true -> true ; throw(error(eraser_failed(Status), none)) ),
    findall(Value-Visible,
            ( clause(snapshot_fact(Value), true, Visible), Value == original ), Seen),
    ( Seen == [original-Ref] -> true
    ; throw(error(snapshot_enumeration_changed(Seen), none)) ),
    '$clause'(snapshot_fact(Original), true, Ref, _),
    ( Original == original -> true
    ; throw(error(reference_decompilation_changed(Original), none)) ),
    ( clause(snapshot_fact(Read), true, Ref)
    -> ( Read == original -> Result = absent
       ; throw(error(bound_reference_changed(Read), none)) )
    ; Result = present ).
