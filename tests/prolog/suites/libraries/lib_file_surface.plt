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

% A fresh directory, so a caller who needs somewhere to put files does not
% derive one from a temporary FILE name the way this suite's own fixture/1 and
% the shipped example both had to.
test(temp_dir_mints_a_fresh_empty_directory) :-
    'temp-dir!'("file-surface-a", Path),
    setup_call_cleanup(true,
        ( assertion(exists_directory(Path)),
          directory_files(Path, Files), msort(Files, Sorted),
          assertion(Sorted == ['.', '..']) ),
        delete_directory(Path)).

% Two mints in one process must not answer the same path, which is the whole
% reason this exists rather than a fixed name under the temporary directory.
test(two_temp_dirs_are_different_directories) :-
    'temp-dir!'("file-surface-b", First),
    'temp-dir!'("file-surface-b", Second),
    setup_call_cleanup(true, assertion(First \== Second),
        ( delete_directory(First), delete_directory(Second) )).

% A prefix NAMES the directory. tmp_file/2 pastes it into the path without
% sanitising, so a separator would place the result outside the temporary
% directory entirely.
test(a_temp_prefix_carrying_a_separator_is_refused,
     [throws(error('file-name-not-a-path'('temp-dir!', _), context('temp-dir!', _)))]) :-
    'temp-dir!'("logs/run", _).

% POSIX's numbering, so the handle surface reaches the three streams a process
% always has without a further operation each.
test(standard_streams_are_handles_zero_one_and_two) :-
    'stdin'(In), assertion(In == 0),
    'stdout'(Out), assertion(Out == 1),
    'stderr'(Err), assertion(Err == 2).

% Every handle operation takes them: this reads standard input through the same
% predicate that reads a file, which is what makes the handles a spelling
% rather than a second mechanism.
test(the_stdin_handle_reads_through_the_file_surface) :- with_fixture(stdin_handle_case).
stdin_handle_case(Dir) :-
    directory_file_path(Dir, input, Path),
    'write-file!'(Path, "alpha\nbeta\n", true),
    with_stdin_from(Path, 'file-read-to-string!'(0, Whole)),
    assertion(Whole == "alpha\nbeta\n"),
    with_stdin_from(Path, 'stdin-to-string!'(Short)),
    assertion(Short == "alpha\nbeta\n").

% The written text is the same either way, so stderr! is the short spelling of
% a handle write rather than a different operation.
test(the_stderr_handle_writes_what_stderr_writes) :- with_fixture(stderr_handle_case).
stderr_handle_case(Dir) :-
    directory_file_path(Dir, through_handle, ViaHandle),
    directory_file_path(Dir, through_stderr, ViaShort),
    with_error_to(ViaHandle, 'file-write!'(2, "exact text", true)),
    with_error_to(ViaShort, 'stderr!'("exact text", true)),
    read_file_to_string(ViaHandle, Handled, [encoding(utf8)]),
    read_file_to_string(ViaShort, Shorted, [encoding(utf8)]),
    assertion(Handled == "exact text"),
    assertion(Handled == Shorted).

% Minting starts past them, so an ordinary handle can never collide with one.
test(a_minted_handle_never_collides_with_a_standard_stream) :- with_fixture(mint_case).
mint_case(Dir) :-
    directory_file_path(Dir, data, Path),
    'write-file!'(Path, "x", true),
    'file-open!'(Path, "r", Handle),
    setup_call_cleanup(true, assertion(Handle >= 3), 'file-close!'(Handle, true)).

% Closing 1 or 2 takes stdout or stderr from everything else in the process,
% the engine's own diagnostics included, and there is no way to put it back.
test(closing_a_standard_stream_is_refused,
     [forall(member(Handle, [0, 1, 2])),
      throws(error('standard-stream-not-closable'('file-close!', _),
                   context('file-close!', _)))]) :-
    'file-close!'(Handle, _).

% Re-aliasing rather than a child process, so these run here: set_stream/2
% moves the alias every reader resolves, and the restore sits in the CLEANUP
% arm because a goal that throws while user_error points at a stream about to
% be closed would leave the process without one.
with_stdin_from(Path, Goal) :-
    once(stream_property(Original, alias(user_input))),
    setup_call_cleanup(open(Path, read, Reader, [encoding(utf8)]),
        setup_call_cleanup(set_stream(Reader, alias(user_input)), Goal,
                           set_stream(Original, alias(user_input))),
        close(Reader)).

with_error_to(Path, Goal) :-
    once(stream_property(Original, alias(user_error))),
    setup_call_cleanup(open(Path, write, Writer, [encoding(utf8)]),
        setup_call_cleanup(set_stream(Writer, alias(user_error)), Goal,
                           set_stream(Original, alias(user_error))),
        close(Writer)).

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
effect_row('temp-dir!', writesState).
effect_row(stdin, pureStructural).
effect_row(stdout, pureStructural).
effect_row(stderr, pureStructural).
test(effect_rows, [forall(effect_row(Name, Expected))]) :-
    metta_operation_effect(Name, Actual), assertion(Actual == Expected).

:- end_tests(lib_file_surface).
