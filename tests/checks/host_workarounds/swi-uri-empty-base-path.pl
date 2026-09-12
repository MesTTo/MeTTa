% Purpose: detect a lost merged path when the native URI base has no path.
% [tested: sh check.sh host-workarounds; commit=WORKTREE].
:- use_module(library(uri), [uri_resolve/3]).
main :-
    uri_resolve(g,'http://a/',Control),
    ( Control == 'http://a/g' -> true ; throw(control_failed(Control)) ),
    uri_resolve(g,'http://a',Actual),
    ( Actual == 'http://a/g' -> writeln(absent)
    ; Actual == 'http://a' -> writeln(present)
    ; throw(unexpected_empty_base_path(Actual)) ).
