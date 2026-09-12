% Purpose: detect lost namespace content during native absolute URN resolution.
% [tested: sh check.sh host-workarounds; commit=WORKTREE].
:- use_module(library(uri), [uri_resolve/3]).
main :-
    uri_resolve('g:h','http://a/',Control),
    ( Control == 'g:h' -> true ; throw(control_failed(Control)) ),
    uri_resolve('urn:example:ABC','http://a/',Actual),
    ( Actual == 'urn:example:ABC' -> writeln(absent)
    ; Actual == 'urn:' -> writeln(present)
    ; throw(unexpected_urn_resolution(Actual)) ).
