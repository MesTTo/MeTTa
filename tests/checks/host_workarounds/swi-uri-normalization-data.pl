% Purpose: detect identifying case and reserved octets changed by URI normalization.
% [tested: sh check.sh host-workarounds; commit=WORKTREE].
:- use_module(library(uri), [uri_normalized/2]).
:- use_module(library(lists), [member/2, memberchk/2]).
main :-
    uri_normalized('HTTP://HOST/%7e',Control),
    ( Control == 'http://host/~' -> true ; throw(control_failed(Control)) ),
    findall(Status,
        ( member(Input-Good-Bad,
                 ['http://User:Pass@HOST/'-'http://User:Pass@host/'-'http://user:pass@host/',
                  'urn:example:ABC'-'urn:example:ABC'-'urn:example:abc',
                  '%FF'-'%FF'-'%C3%BF']),
          uri_normalized(Input,Actual),
          ( Actual == Good -> Status=absent
          ; Actual == Bad -> Status=present
          ; throw(unexpected_uri_normalization(Input,Actual)) ) ),Statuses),
    ( memberchk(present,Statuses) -> writeln(present) ; writeln(absent) ).
