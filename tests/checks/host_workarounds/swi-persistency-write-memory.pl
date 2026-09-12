% Purpose: detect an in-memory mutation surviving a failed journal append.
% Guarantees: a normal write/reopen control passes; only the retained failed
% value counts as present. [tested: sh check.sh host-workarounds; commit=WORKTREE].
% Owns resources: detach the probe schema and remove its directory on every exit.

:- use_module(library(persistency)).
:- use_module(library(filesex), [directory_file_path/3,delete_directory_and_contents/1]).
:- persistent database_memory_probe:row(value:any).

main :-
    tmp_file(database_memory_probe,Directory),
    setup_call_cleanup(make_directory(Directory),database_memory_check(Directory,Result),
        (database_memory_probe:db_detach,delete_directory_and_contents(Directory))),
    writeln(Result).
database_memory_check(Directory,Result) :-
    directory_file_path(Directory,'control.pl',Control),
    database_memory_probe:db_attach(Control,[sync(close)]),
    database_memory_probe:assert_row(control),database_memory_probe:db_detach,
    database_memory_probe:db_attach(Control,[sync(close)]),
    findall(X,database_memory_probe:row(X),[control]),database_memory_probe:db_detach,
    directory_file_path(Directory,'absent/journal.pl',Missing),
    database_memory_probe:db_attach(Missing,[sync(close)]),
    catch(database_memory_probe:assert_row(lost),Error,true),
    ( nonvar(Error),Error=error(existence_error(source_sink,Missing),_) -> true
    ; throw(error(database_memory_probe_error(Error),_)) ),
    findall(X,database_memory_probe:row(X),Rows),
    ( Rows==[lost] -> Result=present
    ; Rows==[] -> Result=absent
    ; throw(error(database_memory_probe_rows(Rows),_)) ).
