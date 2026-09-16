% Purpose: show whether a call and an unbound clause/3 in an old transaction
%   still see a dynamic predicate's rows after another thread erased every
%   current clause, which is what the zero-count shortcut skips.
% Guarantees: the last line is present only when the old transaction's call
%   and clause/3 both answer nothing while nth_clause/3 still admits every
%   original reference, for one and for sixteen facts; mixed readings throw
%   [tested: sh check.sh host-workarounds; commit=c5bdd73e06840e1d0fd0991523983c75def074f6]
%   [measured 2026-09-17: present on SWI-Prolog 10.1.13 and 10.1.14 as shipped,
%   absent on 10.1.14 built with
%   tests/checks/host_workarounds/swi-empty-indexed-snapshot.patch;
%   command=sh check.sh host-workarounds;
%   fixture=SWI-Prolog 10.1.14 with the patch; commit=c6337b74018252516e43107789ceb7d47d044546].
% Owns resources: each erasing thread is joined; fixture facts are withdrawn.

:- dynamic snapshot_row/1.
:- use_module(library(lists), [member/2, numlist/3]).

main :-
    findall(Result, (member(Size, [1, 16]), check(Size, Result)), Results),
    sort(Results, Unique),
    ( Unique = [Result] -> writeln(Result)
    ; throw(error(inconsistent_empty_snapshot_results(Results), none)) ).

check(Size, Result) :-
    numlist(1, Size, Expected),
    setup_call_cleanup(
        forall(member(Value, Expected), assertz(snapshot_row(Value))),
        transaction(observe(Expected, Result)),
        retractall(snapshot_row(_))).

observe(Expected, Result) :-
    thread_create(transaction(retractall(snapshot_row(_))), Eraser, []),
    thread_join(Eraser, Status),
    ( Status == true -> true ; throw(error(eraser_failed(Status), none)) ),
    findall(Value, snapshot_row(Value), Calls),
    findall(Value, clause(snapshot_row(Value), true, _), Clauses),
    findall(Value,
            ( nth_clause(snapshot_row(_), _, Ref),
              '$clause'(snapshot_row(Value), true, Ref, _) ), Retained),
    ( Retained == Expected -> true
    ; throw(error(snapshot_retention_changed(Retained, Expected), none)) ),
    ( Calls == Expected, Clauses == Expected -> Result = absent
    ; Calls == [], Clauses == [] -> Result = present
    ; throw(error(snapshot_readers_disagree(Calls, Clauses, Expected), none)) ).
