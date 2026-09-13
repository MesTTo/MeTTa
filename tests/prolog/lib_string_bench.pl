:- encoding(utf8).

% Purpose: compare String traversal with the previous copying and host-search controls.
% Guarantees: each timed result is checked against its complete expected value.
% [tested: swipl --on-error=status -q -s tests/prolog/lib_string_bench.pl -g true -t halt; commit=WORKTREE].
% Decides: CPU measurements are descriptive; the controls retain their actual
% algorithms and do not use inference counts to estimate native comparisons.
% [source: tests/prolog/lib_string_bench.pl:measure/5; commit=WORKTREE].

:- ensure_loaded('../../engine/qlf_boot.pl').
:- ensure_loaded('../../engine/metta.pl').
:- use_module('../../lib/lib_string/lib_string').
:- initialization(main, main).

main :-
    writeln('operation,mode,first_codepoint,characters,pattern_characters,inferences,cpu_seconds'),
    forall(member(N,[1000,4000,16000,64000]),
           (repeat_fixture("a",N,Text), repeat_fixture("bb",N,Expected),
            measure(replace,control,Text,"a",Expected),
            measure(replace,native,Text,"a",Expected))),
    forall((member(Char,["a","🦊"]),member(N,[4000,16000,64000,256000])),
           (repeat_fixture(Char,N,Text), M is N//4,
            repeat_fixture(Char,M,Prefix), string_concat(Prefix,"b",Pattern),
            measure(search,control,Text,Pattern,-1),
            measure(search,native,Text,Pattern,-1))).

% Construct fixtures outside the measured search and replacement operations.
repeat_fixture(Text,Count,Out) :-
    length(Copies,Count), maplist(=(Text),Copies), atomics_to_string(Copies,Out).

measure(Operation,Mode,Text,Pattern,Expected) :-
    garbage_collect, statistics(inferences,I0), statistics(cputime,T0),
    measured(Operation,Mode,Text,Pattern,Actual),
    statistics(cputime,T1), statistics(inferences,I1),
    ( Actual == Expected -> true
    ; throw(error(string_benchmark_mismatch(Operation,Mode,Actual),_)) ),
    I is I1-I0, T is T1-T0,
    string_code(1,Text,Code), string_length(Text,N), string_length(Pattern,M),
    format('~w,~w,~d,~d,~d,~d,~6f~n',[Operation,Mode,Code,N,M,I,T]).

measured(replace,native,Text,Pattern,Out) :- 'string-replace'(Text,Pattern,"bb",Out).
measured(replace,control,Text,Pattern,Out) :- old_replace(Text,Pattern,"bb",Out).
measured(search,native,Text,Pattern,Out) :- 'string-index-of'(Text,Pattern,Out).
measured(search,control,Text,Pattern,Out) :-
    (sub_string(Text,Before,_,_,Pattern) -> Out=Before ; Out = -1).

% The prior implementation at 02d05add8a092c5d83c853192fe442ea6e2b6a06,
% lib/lib_string/lib_string.pl:'string-replace'/4 and replacement_pieces/4.
old_replace(Value,From,To,Out) :-
    metta_text(Value,Text), metta_text(From,FromText), metta_text(To,ToText),
    ( FromText == "" -> Out = Text
    ; old_pieces(Text,FromText,ToText,Pieces), atomics_to_string(Pieces,Out) ).

old_pieces(Text,From,To,Pieces) :-
    ( sub_string(Text,Before,Length,After,From)
    -> sub_string(Text,0,Before,_,Head), Rest is Before+Length,
       sub_string(Text,Rest,After,_,Tail), Pieces=[Head,To|More],
       old_pieces(Tail,From,To,More)
    ; Pieces=[Text] ).
