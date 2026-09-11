% Purpose: detect compile-time binding of the host ISub option variables.
% Guarantees: exact runtime controls distinguish the defect from a host repair.
% [tested: sh check.sh host-workarounds host-workarounds-selftest; commit=WORKTREE].

:- use_module(library(isub), [isub/4]).

compiled_option(Normalize,Score) :-
    isub("A","a",Score,
         [normalize(Normalize),zero_to_one(false),substring_threshold(0)]).

main :-
    findall(Normalize-Score,
            ( member(Normalize,[false,true]),
              call(isub:isub,"A","a",Score,
                   [normalize(Normalize),zero_to_one(false),substring_threshold(0)]) ),
            Control),
    ( Control == [false-(-1.0),true-1.0] -> true
    ; throw(error(isub_runtime_control_failed(Control),_)) ),
    findall(Normalize-Score,
            (member(Normalize,[false,true]),compiled_option(Normalize,Score)),
            Actual),
    ( Actual == Control -> writeln(absent)
    ; Actual == [true-1.0] -> writeln(present)
    ; throw(error(unexpected_isub_compilation_result(Actual),_)) ).
