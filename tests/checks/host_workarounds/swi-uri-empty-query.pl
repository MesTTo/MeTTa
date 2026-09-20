% Purpose: detect loss of a defined-empty URI query during native composition.
% [tested: sh tools/check.sh host-workarounds; commit=24b96f8ec8468bc97cec35e1d71ce689ede7fdcf].
:- use_module(library(uri), [uri_components/2]).
main :-
    uri_components('http://host?q',Control), uri_components(ControlText,Control),
    ( ControlText == 'http://host?q' -> true ; throw(control_failed(ControlText)) ),
    uri_components('http://host?',Parts), uri_components(Actual,Parts),
    ( Actual == 'http://host?' -> writeln(absent)
    ; Actual == 'http://host' -> writeln(present)
    ; throw(unexpected_empty_query(Actual)) ).
