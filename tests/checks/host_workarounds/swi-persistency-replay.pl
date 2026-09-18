% Purpose: detect native replay continuing past an unsupported journal record.
% Guarantees: a valid control reopens; present requires the record after the
% invalid action to load. [tested: sh check.sh host-workarounds; commit=060bea3199e9f504c6d425f60841f229fc96e861].
% Owns resources: detach the probe schema and remove its journal on every exit.

:- use_module(library(persistency)).
:- persistent database_replay_probe:row(value:any).
:- multifile user:message_hook/3.
user:message_hook(illegal_term(invented(database_replay_corruption)),error,_) :- !.

main :-
    tmp_file(database_replay_probe,Path),
    setup_call_cleanup(true,database_replay_check(Path,Result),
        (database_replay_probe:db_detach,(exists_file(Path)->delete_file(Path);true))),
    writeln(Result).
database_replay_check(Path,Result) :-
    database_replay_probe:db_attach(Path,[sync(close)]),
    database_replay_probe:assert_row(before),database_replay_probe:db_detach,
    database_replay_probe:db_attach(Path,[sync(close)]),
    findall(X,database_replay_probe:row(X),[before]),database_replay_probe:db_detach,
    setup_call_cleanup(open(Path,append,Out),
        format(Out,'invented(database_replay_corruption).~nassert(row(after)).~n',[]),close(Out)),
    catch(database_replay_probe:db_attach(Path,[sync(close)]),Error,true),
    findall(X,database_replay_probe:row(X),Rows),
    ( var(Error),Rows==[before,after] -> Result=present
    ; nonvar(Error) -> Result=absent
    ; throw(error(database_replay_probe_rows(Rows),_)) ).
