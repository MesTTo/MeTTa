% Purpose: detect whether wrapper reconstruction merges distinct closures.
% Guarantees: the last line is present when current_predicate_wrapper/4 loses
%   the second closure's identity, absent when its documented round trip holds
%   [tested: sh check.sh host-workarounds;
%   commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Owns resources: fixture predicates and wrappers die with the probe process.

:- use_module(library(prolog_wrap)).
:- dynamic own/1, other/1.

main :-
    assertz(own(own)), assertz(other(other)),
    wrap_predicate(other(X), capture, Other, call(Other)),
    unwrap_predicate(other(_), capture),
    wrap_predicate(own(X), union, Own, (call(Own); call(Other))),
    findall(X, own(X), Before),
    current_predicate_wrapper(own(Y), union, Hole, Body),
    wrap_predicate(own(Y), union, Hole, Body),
    findall(Y, own(Y), After),
    ( Before == [own,other], After == [own,own]
    -> writeln(present)
    ; Before == [own,other], After == Before
    -> writeln(absent)
    ; throw(error(unexpected_wrapper_roundtrip(Before, After), none)) ).
