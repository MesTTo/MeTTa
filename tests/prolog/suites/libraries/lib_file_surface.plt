% Purpose: verify file operations against SWI and query metadata as atoms.
% Guarantees: bytes, staged publication, renames, tree copy and removal,
% traversal, globbing, path functions, entry kinds, links and scopes are each
% checked against the host and against CPython's posixpath goldens
% [tested: lib_file_surface; commit=b7866b4d874879ff0cb212eb1c6af60dddaa39c6].
% Owns resources: each fixture directory is removed through setup_call_cleanup;
% every space a test allocates is released by the suite's cleanup; a wrapped
% host predicate is unwrapped before the test's assertions run. The socket
% fixture's child closes its socket and process_create/3 waits and reaps it.
:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(prolog_wrap)).
:- use_module(library(ordsets), [ord_subtract/3]).
:- use_module(library(process), [process_create/3]).
:- use_module('../../scratch.pl').
:- initialization(consult('../../lib/lib_string/lib_string.pl')).
:- initialization(consult('../../lib/lib_file/lib_file.pl')).
:- initialization(file_surface_setup).

% The scope heads are applied by the evaluator, so they and the library heads
% a body calls are registered as MeTTa functions the way the face does it.
file_surface_setup :-
    import_prolog_functions(['file-read-to-string!', 'file-get-size!', 'file-read-bytes!',
                             'delete-tree!', 'write-file!', 'make-dir!',
                             'scope-answers', 'scope-boom', 'scope-fill', 'scope-remove'], _).

'scope-answers'(Handle, [Handle, Answer]) :-
    (   'file-read-to-string!'(Handle, Answer)
    ;   'file-get-size!'(Handle, Answer)
    ).
'scope-boom'(Resource, _) :- throw(error(scope_boom(Resource), scope)).
'scope-fill'(Dir, Dir) :-
    directory_file_path(Dir, 'nested/inner', Inner), make_directory_path(Inner),
    directory_file_path(Inner, 'file.txt', File), 'write-file!'(File, "x", true),
    assertion(exists_directory(Dir)).
'scope-remove'(Dir, Dir) :- 'delete-tree!'(Dir, true).

:- use_module('library_assertions.pl', [must_throw/2]).

:- begin_tests(lib_file_surface,
               [setup(metta_space_names(Before)), cleanup(release_added(Before))]).

release_added(Before) :-
    metta_space_names(After), ord_subtract(After, Before, Added),
    maplist(spaces:metta_release_space, Added).

with_fixture(Goal) :- with_scratch_directory(file_surface, Goal).

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

% ---------------------------------------------------------------- bytes

test(bytes_round_trip_every_value) :- with_fixture(bytes_case).
bytes_case(Dir) :-
    directory_file_path(Dir, 'all.bin', Path),
    numlist(0, 255, Every),
    'write-bytes!'(Path, Every, true),
    'read-bytes!'(Path, Back), assertion(Back == Every),
    size_file(Path, Size), assertion(Size == 256),
    'append-bytes!'(Path, [7, 0], true),
    'read-bytes!'(Path, Longer), append(Every, [7, 0], Expected), assertion(Longer == Expected),
    'write-bytes!'(Path, [], true), 'read-bytes!'(Path, None), assertion(None == []),
    'append-bytes!'(Path, [1, 2, 3, 4, 5], true),
    'file-open!'(Path, "rb", Handle),
    setup_call_cleanup(true,
        ( 'file-read-bytes!'(Handle, 2, Two), assertion(Two == [1, 2]),
          'file-read-bytes!'(Handle, Rest), assertion(Rest == [3, 4, 5]),
          'file-read-bytes!'(Handle, 9, Tail), assertion(Tail == []),
          'file-seek!'(Handle, 3, true),
          'file-read-bytes!'(Handle, 9, Short), assertion(Short == [4, 5]),
          'file-get-size!'(Handle, Measured), assertion(Measured == 5) ),
        'file-close!'(Handle, true)),
    'file-open!'(Path, "wb", Writer),
    setup_call_cleanup(true,
        'file-write-bytes!'(Writer, [255, 0, 128], true),
        'file-close!'(Writer, true)),
    'read-bytes!'(Path, Written), assertion(Written == [255, 0, 128]),
    'file-open!'(Path, "ab", Appender),
    setup_call_cleanup(true, 'file-write-bytes!'(Appender, [9], true), 'file-close!'(Appender, true)),
    'read-bytes!'(Path, Appended), assertion(Appended == [255, 0, 128, 9]).

test(handle_kinds_are_checked) :- with_fixture(handle_kind_case).
handle_kind_case(Dir) :-
    directory_file_path(Dir, 'data', Path),
    'write-file!'(Path, "text", true),
    'file-open!'(Path, "rb", Binary),
    setup_call_cleanup(true,
        ( must_throw('file-read-to-string!'(Binary, _),
                     error('file-handle-kind'('file-read-to-string!', Binary, binary), _)),
          must_throw('file-read-exact!'(Binary, 1, _),
                     error('file-handle-kind'('file-read-exact!', Binary, binary), _)) ),
        'file-close!'(Binary, true)),
    'file-open!'(Path, "wb", Sink),
    setup_call_cleanup(true,
        must_throw('file-write!'(Sink, "x", true),
                   error('file-handle-kind'('file-write!', Sink, binary), _)),
        'file-close!'(Sink, true)),
    'file-open!'(Path, "r", Text),
    setup_call_cleanup(true,
        ( must_throw('file-read-bytes!'(Text, _),
                     error('file-handle-kind'('file-read-bytes!', Text, text), _)),
          must_throw('file-read-bytes!'(Text, 1, _),
                     error('file-handle-kind'('file-read-bytes!', Text, text), _)) ),
        'file-close!'(Text, true)),
    'file-open!'(Path, "w", Out),
    setup_call_cleanup(true,
        must_throw('file-write-bytes!'(Out, [1], true),
                   error('file-handle-kind'('file-write-bytes!', Out, text), _)),
        'file-close!'(Out, true)),
    % The standard streams are text, so a byte read of stdin refuses by name too.
    must_throw('file-read-bytes!'(0, _), error('file-handle-kind'('file-read-bytes!', 0, text), _)).

test(bytes_are_validated_before_the_file_is_touched) :- with_fixture(byte_validation_case).
byte_validation_case(Dir) :-
    directory_file_path(Dir, 'keep', Path),
    'write-bytes!'(Path, [1, 2, 3], true),
    must_throw('write-bytes!'(Path, [1, 300], true), error(type_error(_, 300), _)),
    'read-bytes!'(Path, Kept1), assertion(Kept1 == [1, 2, 3]),
    must_throw('append-bytes!'(Path, [-1], true), error(type_error(_, -1), _)),
    must_throw('append-bytes!'(Path, [a], true), error(type_error(_, a), _)),
    must_throw('append-bytes!'(Path, [1.5], true), error(type_error(_, 1.5), _)),
    must_throw('write-bytes!'(Path, notalist, true), error(type_error(_, notalist), _)),
    'read-bytes!'(Path, Kept2), assertion(Kept2 == [1, 2, 3]),
    must_throw('replace-file!'(Path, [256], true), error(type_error(_, 256), _)),
    'read-bytes!'(Path, Kept3), assertion(Kept3 == [1, 2, 3]),
    directory_files(Dir, Files), msort(Files, Sorted),
    assertion(Sorted == ['.', '..', keep]),
    must_throw('read-bytes!'("/nonexistent/metta/bytes.bin", _),
               error('file-not-found'('read-bytes!', source_sink, _), context('read-bytes!', _))).

% ------------------------------------------------------ publication

test(replace_publishes_text_and_bytes_by_rename) :- with_fixture(replace_case).
replace_case(Dir) :-
    directory_file_path(Dir, 'target', Path),
    'replace-file!'(Path, "first", true),
    'read-file!'(Path, First), assertion(First == "first"),
    % An open handle keeps the OLD file: publication is a new entry, not a
    % truncation of the one the reader holds.
    'file-open!'(Path, "r", Reader),
    setup_call_cleanup(true,
        ( 'replace-file!'(Path, "second", true),
          'file-read-to-string!'(Reader, Held), assertion(Held == "first") ),
        'file-close!'(Reader, true)),
    'read-file!'(Path, Second), assertion(Second == "second"),
    'replace-file!'(Path, [104, 105, 0], true),
    'read-bytes!'(Path, Bytes), assertion(Bytes == [104, 105, 0]),
    'replace-file!'(Path, 42, true), 'read-file!'(Path, Number), assertion(Number == "42"),
    directory_files(Dir, Files), msort(Files, Sorted), assertion(Sorted == ['.', '..', target]).

test(replace_preserves_destination_on_failure) :- with_fixture(replace_failure_case).
replace_failure_case(Dir) :-
    directory_file_path(Dir, 'target', Path),
    'write-file!'(Path, "old", true),
    directory_file_path(Dir, 'occupied', Occupied), make_directory(Occupied),
    must_throw('replace-file!'(Occupied, "new", true), error('file-operation-failed'('replace-file!', _), _)),
    assertion(exists_directory(Occupied)),
    directory_file_path(Dir, 'missing/parent', Nowhere),
    must_throw('replace-file!'(Nowhere, "new", true), error('file-not-found'('replace-file!', _, _), _)),
    'read-file!'(Path, Old), assertion(Old == "old"),
    directory_files(Dir, Files), msort(Files, Sorted), assertion(Sorted == ['.', '..', occupied, target]).

% Inject a close failure on the staged write: the destination keeps its bytes
% and the staging directory is removed.
test(replace_keeps_the_old_file_when_the_stage_fails_to_close) :- with_fixture(replace_close_case).
replace_close_case(Dir) :-
    directory_file_path(Dir, 'target', Path),
    'write-file!'(Path, "old", true),
    setup_call_cleanup(
        wrap_predicate(system:close(Stream), file_surface_replace_close, Wrapped,
            ( (stream_property(Stream, mode(write)),
               stream_property(Stream, file_name(Name)),
               sub_atom(Name, _, _, 0, contents))
              -> call(Wrapped), throw(error(io_error(close, Stream), injected))
              ; call(Wrapped) )),
        catch('replace-file!'(Path, "new", true), Error, true),
        unwrap_predicate(system:close(_), file_surface_replace_close)),
    assertion(nonvar(Error)),
    assertion(Error = error('file-operation-failed'('replace-file!', _), _)),
    'read-file!'(Path, Old), assertion(Old == "old"),
    directory_files(Dir, Files), msort(Files, Sorted), assertion(Sorted == ['.', '..', target]).

test(close_failures_are_reported_and_release_the_handle) :- with_fixture(close_report_case).
close_report_case(Dir) :-
    directory_file_path(Dir, 'data', Path),
    'file-open!'(Path, "w", Handle),
    setup_call_cleanup(
        wrap_predicate(system:close(Stream), file_surface_report_close, Wrapped,
            ( stream_property(Stream, file_name(Path))
              -> call(Wrapped), throw(error(io_error(close, Stream), injected))
              ; call(Wrapped) )),
        catch('file-close!'(Handle, _), Error, true),
        unwrap_predicate(system:close(_), file_surface_report_close)),
    assertion(nonvar(Error)),
    assertion(Error = error('file-operation-failed'('file-close!', _), _)),
    % The handle is gone either way, so the second close is the silent one.
    'file-close!'(Handle, true),
    must_throw('file-read-to-string!'(Handle, _), error(existence_error(metta_file_handle, Handle), _)).

% -------------------------------------------------------------- rename

test(rename_follows_posix_replacement_rules) :- with_fixture(rename_case).
rename_case(Dir) :-
    directory_file_path(Dir, a, A), directory_file_path(Dir, b, B),
    directory_file_path(Dir, d, D), directory_file_path(Dir, e, E), directory_file_path(Dir, f, F),
    'write-file!'(A, "a", true), 'write-file!'(B, "b", true),
    make_directory(D), make_directory(E), make_directory(F),
    directory_file_path(F, inner, Inner), 'write-file!'(Inner, "x", true),
    'rename-file!'(A, B, true), 'read-file!'(B, Replaced),
    assertion(Replaced == "a"), assertion(\+ exists_file(A)),
    'rename-file!'(D, E, true), assertion(exists_directory(E)), assertion(\+ exists_directory(D)),
    must_throw('rename-file!'(E, F, true), error('file-operation-failed'('rename-file!', _), _)),
    assertion(exists_directory(E)), 'read-file!'(Inner, Still), assertion(Still == "x"),
    must_throw('rename-file!'(B, E, true), error('file-operation-failed'('rename-file!', _), _)),
    must_throw('rename-file!'(E, B, true), error('file-operation-failed'('rename-file!', _), _)),
    must_throw('rename-file!'(B, B, true), error('file-permission-denied'('rename-file!', rename, same_file, _), _)),
    must_throw('rename-file!'(A, B, true), error('file-not-found'('rename-file!', file, _), _)),
    'read-file!'(B, Kept), assertion(Kept == "a"),
    directory_file_path(Dir, link, Link), 'make-link!'("nowhere", Link, true),
    directory_file_path(Dir, moved, Moved),
    'rename-file!'(Link, Moved, true), 'read-link'(Moved, Target), assertion(Target == "nowhere").

test(rename_across_filesystems_refuses_and_never_copies,
     [condition(( exists_directory('/dev/shm'), access_file('/dev/shm', write) ))]) :-
    with_fixture(cross_device_case).
cross_device_case(Dir) :-
    directory_file_path(Dir, source, Source), 'write-file!'(Source, "stay", true),
    tmp_file(cross_device, Temporary), file_base_name(Temporary, Base),
    directory_file_path('/dev/shm', Base, Destination),
    catch('rename-file!'(Source, Destination, true), Error, true),
    (   var(Error)
    ->  % One filesystem after all: the rename was an ordinary rename.
        assertion(exists_file(Destination)), delete_file(Destination)
    ;   assertion(Error = error('file-operation-failed'('rename-file!', _), _)),
        'read-file!'(Source, Stay), assertion(Stay == "stay"),
        assertion(\+ exists_file(Destination))
    ).

% ---------------------------------------------------------------- trees

test(copy_dir_publishes_a_complete_tree) :- with_fixture(copy_dir_case).
copy_dir_case(Dir) :-
    directory_file_path(Dir, source, Source), make_directory(Source),
    directory_file_path(Source, 'deep/deeper', Deeper), make_directory_path(Deeper),
    directory_file_path(Deeper, 'leaf.bin', Leaf), 'write-bytes!'(Leaf, [0, 255, 10], true),
    directory_file_path(Source, '.hidden', Hidden), 'write-file!'(Hidden, "h", true),
    directory_file_path(Source, 'rel', Rel), 'make-link!'("deep/deeper/leaf.bin", Rel, true),
    directory_file_path(Source, 'dangling', Dangling), 'make-link!'("nowhere", Dangling, true),
    directory_file_path(Source, 'up', Up), 'make-link!'("..", Up, true),
    directory_file_path(Dir, 'copies/one', Destination),
    'copy-dir!'(Source, Destination, true),
    findall(P, 'dir-walk'(Destination, P), Walked),
    directory_file_path(Destination, '.hidden', H2), directory_file_path(Destination, dangling, D2),
    directory_file_path(Destination, deep, Deep2), directory_file_path(Destination, 'deep/deeper', Deeper2),
    directory_file_path(Destination, 'deep/deeper/leaf.bin', Leaf2), directory_file_path(Destination, rel, Rel2),
    directory_file_path(Destination, up, Up2),
    maplist(atom_string, [H2, D2, Deep2, Deeper2, Leaf2, Rel2, Up2], Expected),
    assertion(Walked == Expected),
    'read-bytes!'(Leaf2, Bytes), assertion(Bytes == [0, 255, 10]),
    'read-link'(Rel2, RelText), assertion(RelText == "deep/deeper/leaf.bin"),
    'read-link'(D2, DanglingText), assertion(DanglingText == "nowhere"),
    'read-link'(Up2, UpText), assertion(UpText == ".."),
    'read-bytes!'(Rel2, ThroughLink), assertion(ThroughLink == [0, 255, 10]),
    % A source that is a link to a directory copies the target's contents.
    directory_file_path(Dir, 'via-link', ViaLink), 'make-link!'("source", ViaLink, true),
    directory_file_path(Dir, 'copies/two', Second),
    'copy-dir!'(ViaLink, Second, true),
    directory_file_path(Second, 'deep/deeper/leaf.bin', Leaf3), assertion(exists_file(Leaf3)),
    % The staging directory is gone from beside the destinations.
    directory_file_path(Dir, copies, Copies), directory_files(Copies, Names), msort(Names, Sorted),
    assertion(Sorted == ['.', '..', one, two]).

test(copy_dir_refuses_before_writing) :- with_fixture(copy_dir_refusal_case).
copy_dir_refusal_case(Dir) :-
    directory_file_path(Dir, source, Source), make_directory(Source),
    directory_file_path(Source, 'a.txt', A), 'write-file!'(A, "a", true),
    directory_file_path(Dir, taken, Taken), 'write-file!'(Taken, "t", true),
    must_throw('copy-dir!'(Source, Taken, true), error('file-already-exists'('copy-dir!', _), _)),
    directory_file_path(Source, inner, Inner),
    must_throw('copy-dir!'(Source, Inner, true), error('file-overlap'('copy-dir!', _, _), _)),
    must_throw('copy-dir!'(Source, Source, true), error('file-already-exists'('copy-dir!', _), _)),
    directory_file_path(Source, 'deep/../inner', Sneaky),
    must_throw('copy-dir!'(Source, Sneaky, true), error('file-overlap'('copy-dir!', _, _), _)),
    directory_file_path(Dir, out, Out),
    must_throw('copy-dir!'(A, Out, true), error('file-kind-mismatch'('copy-dir!', _, directory, file), _)),
    directory_file_path(Dir, missing, Missing),
    must_throw('copy-dir!'(Missing, Out, true), error('file-not-found'('copy-dir!', directory, _), _)),
    directory_files(Source, SourceNames), msort(SourceNames, SortedSource),
    assertion(SortedSource == ['.', '..', 'a.txt']),
    directory_files(Dir, Names), msort(Names, Sorted), assertion(Sorted == ['.', '..', source, taken]).

% A socket entry is neither file, directory nor link: the copy refuses it and
% leaves no partial destination, and file-kind reads it as other.
test(copy_dir_refuses_special_entries_and_leaves_nothing) :- with_fixture(special_entry_case).
special_entry_case(Dir) :-
    directory_file_path(Dir, source, Source), make_directory(Source),
    directory_file_path(Source, 'a.txt', A), 'write-file!'(A, "a", true),
    directory_file_path(Source, 'z.sock', SocketPath),
    % Bind relative to the child's cwd: a gate's scratch prefix may exceed
    % the Unix socket address capacity. Closing leaves the filesystem entry.
    term_to_atom(( use_module(library(socket)),
                   setup_call_cleanup(unix_domain_socket(Socket),
                                      tcp_bind(Socket, 'z.sock'),
                                      tcp_close_socket(Socket)) ), Goal),
    process_create(prolog(self), ['-q', '-g', Goal, '-t', halt], [cwd(Source)]),
    'file-kind'(SocketPath, Kind), assertion(Kind == other),
    directory_file_path(Dir, target, Target),
    must_throw('copy-dir!'(Source, Target, true),
               error('file-kind-mismatch'('copy-dir!', _, file, other), _)),
    assertion(\+ exists_directory(Target)),
    directory_files(Dir, Names), msort(Names, Sorted),
    assertion(Sorted == ['.', '..', source]),
    'delete-tree!'(SocketPath, true), assertion(\+ access_file(SocketPath, exist)).

test(delete_tree_unlinks_a_link_root_and_removes_trees) :- with_fixture(delete_tree_case).
delete_tree_case(Dir) :-
    directory_file_path(Dir, real, Real), make_directory(Real),
    directory_file_path(Real, 'keep.txt', Keep), 'write-file!'(Keep, "k", true),
    directory_file_path(Dir, link, Link), 'make-link!'("real", Link, true),
    'delete-tree!'(Link, true),
    'file-kind'(Link, LinkKind), assertion(LinkKind == missing),
    'read-file!'(Keep, Kept), assertion(Kept == "k"),
    directory_file_path(Dir, dangling, Dangling), 'make-link!'("nowhere", Dangling, true),
    'delete-tree!'(Dangling, true), 'file-kind'(Dangling, DanglingKind), assertion(DanglingKind == missing),
    directory_file_path(Real, 'sub/deep', Deep), make_directory_path(Deep),
    directory_file_path(Deep, 'inner.txt', Inner), 'write-file!'(Inner, "i", true),
    directory_file_path(Real, 'sub/back', Back), 'make-link!'("..", Back, true),
    'delete-tree!'(Real, true), assertion(\+ exists_directory(Real)),
    directory_file_path(Dir, 'plain.txt', Plain), 'write-file!'(Plain, "p", true),
    'delete-tree!'(Plain, true), assertion(\+ exists_file(Plain)),
    must_throw('delete-tree!'(Plain, true), error('file-not-found'('delete-tree!', file, _), _)),
    directory_files(Dir, Names), msort(Names, Sorted), assertion(Sorted == ['.', '..']).

% ------------------------------------------------------------ traversal

tree(Dir) :-
    forall(member(Sub, ['sub/deep', '.dotdir', 'other']),
           ( directory_file_path(Dir, Sub, D), make_directory_path(D) )),
    forall(member(File, ['sub/deep/x.txt', 'sub/y.md', 't.txt', '.hidden.txt', 'other/z.txt',
                         '.dotdir/inside.txt', 'sub/[b].txt', 'sub/star*.txt']),
           ( directory_file_path(Dir, File, F), 'write-file!'(F, "", true) )),
    directory_file_path(Dir, lnk, Lnk), 'make-link!'("sub", Lnk, true),
    directory_file_path(Dir, 'sub/up', Up), 'make-link!'("..", Up, true),
    directory_file_path(Dir, dangling, Dangling), 'make-link!'("nowhere", Dangling, true).

paths(Dir, Relatives, Paths) :-
    findall(P, ( member(R, Relatives), directory_file_path(Dir, R, A), atom_string(A, P) ), Paths).

test(walk_reports_links_without_entering) :- with_fixture(walk_case).
walk_case(Dir) :-
    tree(Dir),
    findall(P, 'dir-walk'(Dir, P), Walked),
    paths(Dir, ['.dotdir', '.dotdir/inside.txt', '.hidden.txt', dangling, lnk, other, 'other/z.txt',
                sub, 'sub/[b].txt', 'sub/deep', 'sub/deep/x.txt', 'sub/star*.txt', 'sub/up', 'sub/y.md',
                't.txt'], Expected),
    assertion(Walked == Expected),
    'list-dir!'(Dir, Names),
    assertion(Names == [".dotdir", ".hidden.txt", "dangling", "lnk", "other", "sub", "t.txt"]),
    must_throw('dir-walk'("/nonexistent/metta/dir", _), error(existence_error(directory, _), _)),
    directory_file_path(Dir, 't.txt', T),
    must_throw('dir-walk'(T, _), error(existence_error(directory, _), _)).

test(walk_follows_links_without_looping) :- with_fixture(follow_case).
follow_case(Dir) :-
    tree(Dir),
    findall(P, 'dir-walk'(Dir, [['follow-links', true]], P), Walked),
    paths(Dir, ['.dotdir', '.dotdir/inside.txt', '.hidden.txt', dangling,
                lnk, 'lnk/[b].txt', 'lnk/deep', 'lnk/deep/x.txt', 'lnk/star*.txt', 'lnk/up', 'lnk/y.md',
                other, 'other/z.txt',
                sub, 'sub/[b].txt', 'sub/deep', 'sub/deep/x.txt', 'sub/star*.txt', 'sub/up', 'sub/y.md',
                't.txt'], Expected),
    assertion(Walked == Expected),
    % A cut after the first answer leaves no stream or state behind.
    once('dir-walk'(Dir, First)), assertion(string(First)),
    must_throw('dir-walk'(Dir, [[hidden, true]], _), error(domain_error(walk_option, _), _)),
    must_throw('dir-walk'(Dir, [['follow-links', yes]], _), error(domain_error(walk_option, _), _)),
    must_throw('dir-walk'(Dir, [['follow-links', true], ['follow-links', false]], _),
               error(domain_error(duplicate_walk_option, _), _)),
    must_throw('dir-walk'(Dir, notalist, _), error(type_error(list, notalist), _)).

test(walk_raises_on_an_unreadable_directory,
     [condition(\+ ( getenv('USER', root) ; getenv('LOGNAME', root) ))]) :-
    with_fixture(unreadable_case).
unreadable_case(Dir) :-
    directory_file_path(Dir, private, Private), make_directory(Private),
    directory_file_path(Private, 'secret.txt', Secret), 'write-file!'(Secret, "s", true),
    setup_call_cleanup(chmod(Private, 0o000),
        ( catch(findall(P, 'dir-walk'(Dir, P), _), Error, true),
          assertion(nonvar(Error)),
          assertion(Error = error('file-permission-denied'('dir-walk', _, _, _), _)) ),
        chmod(Private, 0o700)).

test(glob_selects_literal_wildcard_and_recursive_components) :- with_fixture(glob_case).
glob_case(Dir) :-
    tree(Dir),
    findall(P, 'dir-glob'(Dir, "*", P), Star),
    paths(Dir, [dangling, lnk, other, sub, 't.txt'], StarExpected), assertion(Star == StarExpected),
    findall(P, 'dir-glob'(Dir, "*", [[hidden, true]], P), All),
    paths(Dir, ['.dotdir', '.hidden.txt', dangling, lnk, other, sub, 't.txt'], AllExpected),
    assertion(All == AllExpected),
    findall(P, 'dir-glob'(Dir, ".*", P), Dots),
    paths(Dir, ['.dotdir', '.hidden.txt'], DotsExpected), assertion(Dots == DotsExpected),
    findall(P, 'dir-glob'(Dir, "**/*.txt", P), Texts),
    paths(Dir, ['t.txt', 'other/z.txt', 'sub/[b].txt', 'sub/star*.txt', 'sub/deep/x.txt'], TextsExpected),
    assertion(Texts == TextsExpected),
    findall(P, 'dir-glob'(Dir, "**/*.txt", [[hidden, true]], P), HiddenTexts),
    paths(Dir, ['.hidden.txt', 't.txt', '.dotdir/inside.txt', 'other/z.txt', 'sub/[b].txt',
                'sub/star*.txt', 'sub/deep/x.txt'], HiddenExpected),
    assertion(HiddenTexts == HiddenExpected),
    findall(P, 'dir-glob'(Dir, "**", P), Dirs),
    atom_string(Dir, DirText),
    paths(Dir, [other, sub, 'sub/deep'], DirsRest),
    assertion(Dirs == [DirText|DirsRest]),
    findall(P, 'dir-glob'(Dir, "**/*.md", [['follow-links', true]], P), Followed),
    paths(Dir, ['lnk/y.md', 'sub/y.md'], FollowedExpected), assertion(Followed == FollowedExpected),
    findall(P, 'dir-glob'(Dir, "lnk/*.md", P), ThroughLink),
    paths(Dir, ['lnk/y.md'], ThroughExpected), assertion(ThroughLink == ThroughExpected),
    findall(P, 'dir-glob'(Dir, "sub/deep/x.txt", P), Literal),
    paths(Dir, ['sub/deep/x.txt'], LiteralExpected), assertion(Literal == LiteralExpected),
    findall(P, 'dir-glob'(Dir, "sub/deep/missing.txt", P), Missing), assertion(Missing == []),
    findall(P, 'dir-glob'(Dir, "dangling", P), DanglingLiteral),
    paths(Dir, [dangling], DanglingExpected), assertion(DanglingLiteral == DanglingExpected),
    findall(P, 'dir-glob'(Dir, "sub/{y,z}.md", P), Braces),
    paths(Dir, ['sub/y.md'], BracesExpected), assertion(Braces == BracesExpected),
    findall(P, 'dir-glob'(Dir, "sub/\\[b\\].txt", P), Escaped),
    paths(Dir, ['sub/[b].txt'], EscapedExpected), assertion(Escaped == EscapedExpected),
    findall(P, 'dir-glob'(Dir, "sub/[xyz].md", P), Set),
    paths(Dir, ['sub/y.md'], SetExpected), assertion(Set == SetExpected),
    findall(P, 'dir-glob'(Dir, "sub/star\\*.txt", P), Literal2),
    paths(Dir, ['sub/star*.txt'], Literal2Expected), assertion(Literal2 == Literal2Expected),
    findall(P, 'dir-glob'(Dir, "./sub//y.md", P), Dotted),
    paths(Dir, ['sub/y.md'], DottedExpected), assertion(Dotted == DottedExpected),
    findall(P, 'dir-glob'(Dir, ".", P), Self), assertion(Self == [DirText]),
    findall(P, 'dir-glob'(Dir, "**/**/deep", P), Collapsed),
    paths(Dir, ['sub/deep'], CollapsedExpected), assertion(Collapsed == CollapsedExpected).

% Two ** components can consume the same directories two ways; each path is
% still answered once.
test(glob_answers_each_path_once) :- with_fixture(distinct_case).
distinct_case(Dir) :-
    directory_file_path(Dir, 'x/x/y', Deep), make_directory_path(Deep),
    directory_file_path(Dir, 'x/y', Shallow), make_directory_path(Shallow),
    findall(P, 'dir-glob'(Dir, "**/x/**/y", P), Found),
    paths(Dir, ['x/y', 'x/x/y'], Expected),
    msort(Found, SortedFound), msort(Expected, SortedExpected),
    assertion(SortedFound == SortedExpected),
    length(Found, Count), assertion(Count == 2).

test(glob_refuses_malformed_absolute_and_empty_patterns) :- with_fixture(glob_refusal_case).
glob_refusal_case(Dir) :-
    tree(Dir),
    must_throw('dir-glob'(Dir, "[x", _), error(domain_error(glob_pattern, "[x"), _)),
    must_throw('dir-glob'(Dir, "sub/{a", _), error(domain_error(glob_pattern, _), _)),
    must_throw('dir-glob'(Dir, "/etc/*", _), error(domain_error(glob_pattern, _), _)),
    must_throw('dir-glob'(Dir, "", _), error(domain_error(glob_pattern, ""), _)),
    must_throw('dir-glob'("/nonexistent/metta/dir", "*", _), error(existence_error(directory, _), _)),
    must_throw('dir-glob'(Dir, "*", [[colour, true]], _), error(domain_error(walk_option, _), _)).

% ---------------------------------------------------------------- paths

% Goldens from CPython 3.14.7's posixpath at 823f0323ee6ec1402088b73bce1a38473cac36dc.
normalize_golden("a/./b/../c", "a/c").
normalize_golden("//x/y", "//x/y").
normalize_golden("///x", "/x").
normalize_golden("/x/../../y", "/y").
normalize_golden("", ".").
normalize_golden(".", ".").
normalize_golden("a/..", ".").
normalize_golden("..", "..").
normalize_golden("a//b/", "a/b").
normalize_golden("/..", "/").
normalize_golden("a/b/../../..", "..").
normalize_golden("../a/../../b", "../../b").
normalize_golden("/", "/").
normalize_golden("//", "//").
normalize_golden("a/./././b", "a/b").
test(normalize_matches_posixpath, [forall(normalize_golden(In, Out))]) :-
    'path-normalize'(In, Got), assertion(Got == Out).

relative_golden("/a/b/c", "/a/d", "../b/c").
relative_golden("/a", "/a/b/c", "../..").
relative_golden("a", "a", ".").
relative_golden("/a/b", "/", "a/b").
relative_golden("/", "/a/b", "../..").
relative_golden("/a/b/./c", "/a//b", "c").
test(relative_matches_posixpath, [forall(relative_golden(Path, Start, Out))]) :-
    'path-relative'(Path, Start, Got), assertion(Got == Out).

parts_golden("/a/b", ["/", "a", "b"]).
parts_golden("a//b/", ["a", "b"]).
parts_golden("", []).
parts_golden(".", []).
parts_golden("//x", ["//", "x"]).
parts_golden("a/./../b", ["a", "..", "b"]).
test(parts_follow_the_library_conventions, [forall(parts_golden(In, Out))]) :-
    'path-parts'(In, Got), assertion(Got == Out).

test(stem_is_the_complement_of_extension) :-
    'path-stem'("a/b.tar.gz", S1), assertion(S1 == "b.tar"),
    'path-stem'(".env", S2), assertion(S2 == ""),
    'path-stem'("README", S3), assertion(S3 == "README"),
    'path-stem'("dir.d/file", S4), assertion(S4 == "file").

test(absolute_and_relative_use_the_working_directory) :-
    working_directory(W, W), atom_string(W, WText), 'path-normalize'(WText, Cwd),
    'path-absolute'("x/./y", Abs), atomics_to_string([Cwd, "/x/y"], Expected), assertion(Abs == Expected),
    'path-absolute'("/x/./y", AbsRoot), assertion(AbsRoot == "/x/y"),
    'path-absolute'("", Here), assertion(Here == Cwd),
    'path-relative'("x/y", ".", Rel), assertion(Rel == "x/y"),
    must_throw('path-relative'("", ".", _), error(domain_error(path, ""), _)).

test(resolve_follows_links_before_dotdot_and_keeps_loops) :- with_fixture(resolve_case).
resolve_case(Dir) :-
    tree(Dir),
    atom_string(Dir, DirText),
    directory_file_path(Dir, 'lnk/y.md', Via), 'path-resolve'(Via, R1),
    atomics_to_string([DirText, "/sub/y.md"], E1), assertion(R1 == E1),
    directory_file_path(Dir, 'lnk/../t.txt', DotDot), 'path-resolve'(DotDot, R2),
    atomics_to_string([DirText, "/t.txt"], E2), assertion(R2 == E2),
    directory_file_path(Dir, 'sub/up/other/z.txt', Up), 'path-resolve'(Up, R3),
    atomics_to_string([DirText, "/other/z.txt"], E3), assertion(R3 == E3),
    directory_file_path(Dir, 'missing/../t.txt', Missing), 'path-resolve'(Missing, R4), assertion(R4 == E2),
    directory_file_path(Dir, 'dangling/x', Dangling), 'path-resolve'(Dangling, R5),
    atomics_to_string([DirText, "/nowhere/x"], E5), assertion(R5 == E5),
    directory_file_path(Dir, abs, Abs), 'make-link!'("/", Abs, true),
    directory_file_path(Dir, 'abs/dev', AbsDev), 'path-resolve'(AbsDev, R6), assertion(R6 == "/dev"),
    directory_file_path(Dir, loop1, Loop1), directory_file_path(Dir, loop2, Loop2),
    'make-link!'("loop2", Loop1, true), 'make-link!'("loop1", Loop2, true),
    directory_file_path(Dir, 'loop1/tail', LoopTail), 'path-resolve'(LoopTail, R7),
    atomics_to_string([DirText, "/loop1/tail"], E7), assertion(R7 == E7),
    'path-resolve'("/", Root), assertion(Root == "/"),
    working_directory(W, W), atom_string(W, WText), 'path-normalize'(WText, Cwd),
    'path-resolve'(".", Here), 'path-resolve'(Cwd, HereToo), assertion(Here == HereToo).

% ----------------------------------------------------------- kinds and links

test(kinds_links_and_identity) :- with_fixture(kind_case).
kind_case(Dir) :-
    tree(Dir),
    directory_file_path(Dir, 't.txt', T), 'file-kind'(T, K1), assertion(K1 == file),
    directory_file_path(Dir, sub, Sub), 'file-kind'(Sub, K2), assertion(K2 == directory),
    directory_file_path(Dir, lnk, Lnk), 'file-kind'(Lnk, K3), assertion(K3 == link),
    directory_file_path(Dir, dangling, Dangling), 'file-kind'(Dangling, K4), assertion(K4 == link),
    directory_file_path(Dir, nothing, Nothing), 'file-kind'(Nothing, K5), assertion(K5 == missing),
    'file-exists'(Dangling, E1), assertion(E1 == false),
    'dir-exists'(Lnk, E2), assertion(E2 == true),
    'same-file'(Lnk, Sub, S1), assertion(S1 == true),
    directory_file_path(Dir, 'sub/../sub', Spelled), 'same-file'(Spelled, Sub, S2), assertion(S2 == true),
    'same-file'(T, Sub, S3), assertion(S3 == false),
    'same-file'(Nothing, Sub, S4), assertion(S4 == false),
    'read-link'(Lnk, L1), assertion(L1 == "sub"),
    'read-link'(Dangling, L2), assertion(L2 == "nowhere"),
    must_throw('read-link'(T, _), error('file-kind-mismatch'('read-link', _, link, file), _)),
    must_throw('read-link'(Nothing, _), error('file-kind-mismatch'('read-link', _, link, missing), _)),
    must_throw('make-link!'("sub", Lnk, true), error('file-already-exists'('make-link!', _), _)),
    must_throw('make-link!'("sub", Dangling, true), error('file-already-exists'('make-link!', _), _)),
    directory_file_path(Dir, 'missing/parent/link', Nowhere),
    must_throw('make-link!'("sub", Nowhere, true), error('file-not-found'('make-link!', _, _), _)).

% ---------------------------------------------------------------- scopes

test(with_file_closes_on_every_exit) :- with_fixture(scope_case).
scope_case(Dir) :-
    directory_file_path(Dir, 'data.txt', Path), 'write-file!'(Path, "abc", true),
    % Exhaustion: every answer of a nondeterministic body streams, then the
    % handle is gone.
    findall(Answer, 'with-file'(Path, "r", 'scope-answers', Answer), Answers),
    % assertion/1 keeps no bindings, so the handle is read with a plain unification.
    Answers = [[H|_]|_],
    assertion(Answers == [[H, "abc"], [H, 3]]),
    must_throw('file-read-to-string!'(H, _), error(existence_error(metta_file_handle, H), _)),
    % A cut after the first answer closes the handle too.
    once('with-file'(Path, "r", 'scope-answers', [H2, First])),
    assertion(First == "abc"),
    must_throw('file-read-to-string!'(H2, _), error(existence_error(metta_file_handle, H2), _)),
    % An exception in the body closes the handle and propagates.
    catch('with-file'(Path, "r", 'scope-boom', _), Error, true),
    assertion(nonvar(Error)), Error = error(scope_boom(H3), _),
    must_throw('file-read-to-string!'(H3, _), error(existence_error(metta_file_handle, H3), _)),
    % A binary scope and a bare function name both work.
    'with-file'(Path, "rb", 'file-read-bytes!', Bytes), assertion(Bytes == [97, 98, 99]),
    % A close failure inside the scope surfaces as the scope's error.
    setup_call_cleanup(
        wrap_predicate(system:close(Stream), file_surface_scope_close, Wrapped,
            ( stream_property(Stream, file_name(Path))
              -> call(Wrapped), throw(error(io_error(close, Stream), injected))
              ; call(Wrapped) )),
        catch(findall(A, 'with-file'(Path, "r", 'file-read-to-string!', A), _), CloseError, true),
        unwrap_predicate(system:close(_), file_surface_scope_close)),
    assertion(nonvar(CloseError)),
    assertion(CloseError = error('file-operation-failed'('file-close!', _), _)).

test(with_temp_dir_removes_its_directory_on_every_exit) :-
    findall(D, 'with-temp-dir'("file-surface-scope", 'scope-fill', D), Dirs),
    assertion(length(Dirs, 1)), Dirs = [Dir],
    atom_string(DirAtom, Dir),
    assertion(\+ exists_directory(DirAtom)),
    catch('with-temp-dir'("file-surface-scope", 'scope-boom', _), Error, true),
    assertion(nonvar(Error)), Error = error(scope_boom(Gone), _),
    atom_string(GoneAtom, Gone),
    assertion(\+ exists_directory(GoneAtom)),
    % A body that already removed the directory leaves nothing for the cleanup.
    'with-temp-dir'("file-surface-scope", 'scope-remove', Removed),
    atom_string(RemovedAtom, Removed),
    assertion(\+ exists_directory(RemovedAtom)).

% ---------------------------------------------------------- odds and ends

test(temp_path_refuses_a_separator_and_leaves_no_file,
     [throws(error('file-name-not-a-path'('temp-path!', _), context('temp-path!', _)))]) :-
    'temp-path!'("logs/run", _).

test(file_space_is_a_registered_space_even_when_empty) :- with_fixture(file_space_case).
file_space_case(Dir) :-
    directory_file_path(Dir, 'empty.txt', Empty), 'write-file!'(Empty, "", true),
    'file-space!'(Empty, Space),
    metta_space_names(Names), assertion(memberchk(Space, Names)),
    findall(A, 'get-atoms'(Space, A), Atoms), assertion(Atoms == []),
    directory_file_path(Dir, 'nul.txt', Nul), string_codes(Text, [0'a, 0, 0'b, 0'\n, 0'c, 0'\n]),
    'write-file!'(Nul, Text, true),
    'file-lines!'(Nul, Lines), string_codes(First, [0'a, 0, 0'b]),
    assertion(Lines == [First, "c"]),
    'file-space!'(Nul, Space2),
    findall(N-T, 'get-atoms'(Space2, [line, N, T]), Rows), msort(Rows, Sorted),
    assertion(Sorted == [1-First, 2-"c"]).

%Each of these contracts promises an error and none was witnessed. read-file!
%says a missing file "is an error rather than a failure, so it can never be
%mistaken for an empty file", list-dir! that "a missing directory raises", and
%delete-dir! that "missing or nonempty directories raise". Writing the
%witnesses showed the first two raising a bare existence_error while every
%other refusal in this library is one of library_refusal/1 carrying its caller
%and a remedy; they route through metta_file_refusal/2 now, and these assert it.
test(a_contract_that_promises_an_error_names_the_operation_that_refused)
     :- with_fixture(contract_refusals).
contract_refusals(Dir) :-
    directory_file_path(Dir, missing, Missing),
    directory_file_path(Dir, full, Full), make_directory(Full),
    directory_file_path(Full, 'a.txt', Inner), 'write-file!'(Inner, "a", true),
    must_throw('read-file!'(Missing, _),
               error('file-not-found'('read-file!', source_sink, _), context('read-file!', _))),
    must_throw('list-dir!'(Missing, _),
               error('file-not-found'('list-dir!', directory, _), context('list-dir!', _))),
    must_throw('delete-dir!'(Missing, _),
               error('file-not-found'('delete-dir!', directory, _), context('delete-dir!', _))),
    %A nonempty directory reaches SWI as a permission_error, which is why the
    %refusal reads permission-denied rather than naming emptiness.
    must_throw('delete-dir!'(Full, _),
               error('file-permission-denied'('delete-dir!', delete, directory, _),
                     context('delete-dir!', _))),
    assertion(exists_directory(Full)).

:- end_tests(lib_file_surface).
