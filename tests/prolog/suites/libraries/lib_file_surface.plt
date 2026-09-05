% Purpose: verify file operations against SWI and query metadata as atoms.
% Owns resources: each fixture directory is removed through setup_call_cleanup.
% [tested: lib_file_surface; commit=504f8dddfa890ced97e795a13ab10e239b1de2ce]
:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(prolog_wrap)).
:- initialization(consult('../../lib/lib_string/lib_string.pl')).
:- initialization(consult('../../lib/lib_file/lib_file.pl')).

:- begin_tests(lib_file_surface).

fixture(Dir) :-
    tmp_file_stream(text, Dir, Stream), close(Stream), delete_file(Dir),
    make_directory(Dir).

with_fixture(Goal) :-
    setup_call_cleanup(fixture(Dir), call(Goal, Dir),
                       delete_directory_and_contents(Dir)).

test(lexical_paths) :-
    'path-join'("a", "b.txt", "a/b.txt"),
    'path-parent'("a/b.txt", "a"),
    'path-name'("a/b.txt", "b.txt"),
    'path-extension'("a/b.txt", "txt"),
    'path-extension'("README", ""),
    'path-extension'(".env", "env"),
    'path-parent'("README", "."),
    'path-join'("", "name", "name"),
    'path-name'("a/", "a"),
    'path-extension'("a.b/c", "").

test(paths_follow_swi,
     [forall(member(Path, ["a/b.txt", "a/../b", "name", ".env", ""]))]) :-
    file_directory_name(Path, Parent), 'path-parent'(Path, P),
    atom_string(Parent, P),
    file_base_name(Path, Base), 'path-name'(Path, B), atom_string(Base, B),
    file_name_extension(_, Ext, Base), 'path-extension'(Path, E),
    atom_string(Ext, E).

test(recursive_creation_and_empty_deletion) :- with_fixture(directory_case).
directory_case(Dir) :-
    directory_file_path(Dir, 'a/b', Nested),
    'make-dir!'(Nested, true), 'make-dir!'(Nested, true),
    assertion(exists_directory(Nested)),
    'delete-dir!'(Nested, true), assertion(\+ exists_directory(Nested)).

test(copy_is_binary_and_replaces_only_after_success) :- with_fixture(copy_case).
copy_case(Dir) :-
    directory_file_path(Dir, source, From),
    directory_file_path(Dir, target, To),
    setup_call_cleanup(open(From, write, Out, [type(binary)]),
                       maplist(put_byte(Out), [0, 255, 13, 10, 128]), close(Out)),
    'write-file!'(To, "old content", true),
    'copy-file!'(From, To, true),
    setup_call_cleanup(open(To, read, In, [type(binary)]),
                       read_stream_to_codes(In, Bytes), close(In)),
    assertion(Bytes == [0, 255, 13, 10, 128]),
    directory_files(Dir, Files), msort(Files, Sorted),
    assertion(Sorted == ['.', '..', source, target]).

test(failed_copy_preserves_destination) :- with_fixture(failed_copy_case).
failed_copy_case(Dir) :-
    directory_file_path(Dir, missing, Missing),
    directory_file_path(Dir, target, To),
    'write-file!'(To, "keep me", true),
    catch('copy-file!'(Missing, To, _), Error, true),
    assertion(nonvar(Error)),
    assertion(Error = error('file-not-found'('copy-file!', _, _), context(_, _))),
    'read-file!'(To, "keep me"),
    catch('copy-file!'(To, To, _), SameError, true),
    assertion(nonvar(SameError)),
    assertion(SameError = error('file-permission-denied'(_, copy, same_file, _), _)),
    'read-file!'(To, "keep me").

test(failed_publication_removes_staging) :- with_fixture(publication_case).
publication_case(Dir) :-
    directory_file_path(Dir, source, From),
    directory_file_path(Dir, target, To),
    'write-file!'(From, "bytes", true), make_directory(To),
    catch('copy-file!'(From, To, _), Error, true),
    assertion(nonvar(Error)),
    assertion(exists_directory(To)),
    directory_files(Dir, Files), msort(Files, Sorted),
    assertion(Sorted == ['.', '..', source, target]).

% Inject the OS close failure that a temporary-file fixture cannot produce.
% The wrapper is process-local and removed before checking destination data.
test(source_close_failure_preserves_destination) :- with_fixture(close_failure_case).
close_failure_case(Dir) :-
    directory_file_path(Dir, source, From),
    directory_file_path(Dir, target, To),
    'write-file!'(From, "new bytes", true),
    'write-file!'(To, "old bytes", true),
    setup_call_cleanup(
        wrap_predicate(system:close(Stream), file_surface_close, Wrapped,
            ( (stream_property(Stream, mode(read)),
               stream_property(Stream, file_name(From)))
              -> call(Wrapped), throw(error(io_error(close, Stream), injected))
              ; call(Wrapped) )),
        catch('copy-file!'(From, To, _), Error, true),
        unwrap_predicate(system:close(_), file_surface_close)),
    assertion(nonvar(Error)),
    assertion(Error = error('file-operation-failed'('copy-file!', _), _)),
    'read-file!'(To, "old bytes"),
    directory_files(Dir, Files), msort(Files, Sorted),
    assertion(Sorted == ['.', '..', source, target]).

test(metadata_is_queryable) :- with_fixture(metadata_case).
metadata_case(Dir) :-
    directory_file_path(Dir, data, Path),
    'write-file!'(Path, "hello", true),
    'file-metadata!'(Path, Space),
    setup_call_cleanup(true,
        ( findall(Value, 'get-atoms'(Space, [size, Value]), Sizes),
          assertion(Sizes == [5]),
          findall(Kind, 'get-atoms'(Space, [kind, Kind]), Kinds),
          assertion(Kinds == [file]),
          time_file(Path, Modified),
          findall(T, 'get-atoms'(Space, [modified, T]), Times),
          assertion(Times == [Modified]) ),
        spaces:metta_release_space(Space)).

test(missing_metadata_is_a_named_error,
     [throws(error('file-not-found'('file-metadata!', _, _), context(_, _)))]) :-
    'file-metadata!'('missing-file-surface-fixture', _).

test(invalid_exit_status_has_a_remedy,
     [forall(member(Status, [-1, 256, 1.5, nope])),
      throws(error(domain_error(exit_status, Status), context('exit!', _)))]) :-
    'exit!'(Status, _).

effect_row('path-join', pureStructural).
effect_row('path-parent', pureStructural).
effect_row('path-name', pureStructural).
effect_row('path-extension', pureStructural).
effect_row('list-dir!', readOnlyLookup).
effect_row('make-dir!', writesState).
effect_row('delete-dir!', writesState).
effect_row('copy-file!', writesState).
effect_row('file-metadata!', writesState).
effect_row('stderr!', oracleIO).
effect_row('stdin-to-string!', oracleIO).
effect_row('exit!', oracleIO).
test(effect_rows, [forall(effect_row(Name, Expected))]) :-
    metta_operation_effect(Name, Actual), assertion(Actual == Expected).

:- end_tests(lib_file_surface).
