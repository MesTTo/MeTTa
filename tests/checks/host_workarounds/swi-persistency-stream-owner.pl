% Purpose: detect journal streams left open before their native registration.
% Guarantees: the probe throws after native open, detaches, and observes only
% that journal's streams. [tested: sh check.sh host-workarounds; commit=060bea3199e9f504c6d425f60841f229fc96e861].
% Owns resources: restore the wrapped predicate, close orphan streams, detach
% the probe schema and remove its journal on every exit.

:- use_module(library(persistency)).
:- use_module(library(prolog_wrap), [wrap_predicate/4,unwrap_predicate/2]).
:- use_module(library(apply), [maplist/2]).
:- persistent database_stream_probe:row(value:any).

main :-
    tmp_file(database_stream_probe,Path),
    setup_call_cleanup(true,database_stream_check(Path,Result),
        (database_stream_probe:db_detach,
         findall(Stream,stream_property(Stream,file_name(Path)),Streams),maplist(close,Streams),
         (exists_file(Path)->delete_file(Path);true))),
    writeln(Result).
database_stream_check(Path,Result) :-
    database_stream_probe:db_attach(Path,[sync(close)]),
    database_stream_probe:assert_row(control),database_stream_probe:db_detach,
    \+ stream_property(_,file_name(Path)),
    database_stream_probe:db_attach(Path,[sync(none)]),
    setup_call_cleanup(
        wrap_predicate(persistency:db_open_file(File,_,_),database_stream_boundary,Wrapped,
                       (call(Wrapped),(File==Path->throw(database_stream_interrupted);true))),
        catch(database_stream_probe:assert_row(lost),Error,true),
        unwrap_predicate(persistency:db_open_file(_,_,_),database_stream_boundary)),
    ( Error==database_stream_interrupted -> true
    ; throw(error(database_stream_probe_error(Error),_)) ),
    database_stream_probe:db_detach,
    findall(Stream,stream_property(Stream,file_name(Path)),Streams),
    ( Streams=[_] -> Result=present
    ; Streams==[] -> Result=absent
    ; throw(error(database_stream_probe_streams(Streams),_)) ).
