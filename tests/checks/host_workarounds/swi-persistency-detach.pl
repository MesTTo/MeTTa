% Purpose: detect attachment bookkeeping left behind by a failed stream close.
% Guarantees: normal detach removes registration; a second detach must finish
% the failed case. [tested: sh check.sh host-workarounds; commit=060bea3199e9f504c6d425f60841f229fc96e861].
% Owns resources: detach the probe schema and remove its journal on every exit.

:- use_module(library(persistency)).
:- persistent database_detach_probe:row(value:any).

main :-
    tmp_file(database_detach_probe,Path),
    setup_call_cleanup(true,database_detach_check(Path,Result),
        (database_detach_probe:db_detach,(exists_file(Path)->delete_file(Path);true))),
    writeln(Result).
database_detach_check(Path,Result) :-
    database_detach_probe:db_attach(Path,[sync(flush)]),
    database_detach_probe:assert_row(control),database_detach_probe:db_detach,
    \+ persistency:db_file(database_detach_probe,_,_,_,_),
    database_detach_probe:db_attach(Path,[sync(flush)]),
    database_detach_probe:assert_row(value),
    persistency:db_stream(database_detach_probe,Stream),close(Stream),
    catch(database_detach_probe:db_detach,Error,true),
    ( Error=error(existence_error(stream,_),_) -> true
    ; throw(error(database_detach_probe_error(Error),_)) ),
    ( persistency:db_file(database_detach_probe,Path,_,_,_) -> Result=present
    ; Result=absent ),
    database_detach_probe:db_detach,
    \+ persistency:db_file(database_detach_probe,_,_,_,_),
    \+ persistency:db_option(database_detach_probe,_).
