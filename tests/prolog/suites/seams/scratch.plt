% Purpose: prove that a suite fixture resolves its scratch directory whether or
%   not the environment names one, and owns it in every exit path.
% Guarantees: scratch_parent/1 is det under a set, unset and restored TMPDIR;
%   with_scratch_directory/2 hands over an empty directory and removes it after
%   success, failure and an exception, propagating each outcome unchanged.
% Owns resources: each case creates and removes its own directories; the TMPDIR
%   the process started with is restored whatever the case does.

:- use_module('../../scratch.pl').
:- use_module(library(filesex)).

:- begin_tests(scratch).

% The regression this file exists for. A bare getenv('TMPDIR', P) FAILS when the
% variable is unset, and because it was the first goal of four suite fixtures,
% 60 tests across lib_csv_surface and lib_json_surface reported a contentless
% "failed" in any shell that does not export TMPDIR -- which is the default one
% [measured 2026-09-21: 45 and 15 failures unset, 0 and 0 set, same tree].
with_tmpdir_unset(Goal) :-
    (   getenv('TMPDIR', Old)
    ->  setup_call_cleanup(unsetenv('TMPDIR'), Goal, setenv('TMPDIR', Old))
    ;   call(Goal)
    ).

with_tmpdir(Value, Goal) :-
    (   getenv('TMPDIR', Old)
    ->  setup_call_cleanup(setenv('TMPDIR', Value), Goal, setenv('TMPDIR', Old))
    ;   setup_call_cleanup(setenv('TMPDIR', Value), Goal, unsetenv('TMPDIR'))
    ).

test(parent_resolves_when_the_environment_names_no_tmpdir) :-
    with_tmpdir_unset(scratch_parent(Parent)),
    assertion(atomic(Parent)), assertion(exists_directory(Parent)).

test(parent_is_the_environment_tmpdir_when_it_is_set) :-
    with_scratch_directory(scratch_parent_case,
        [Directory]>>( with_tmpdir(Directory, scratch_parent(Parent)),
                       assertion(Parent == Directory) )).

test(a_scratch_directory_arrives_empty_and_is_removed_afterwards) :-
    with_scratch_directory(scratch_case,
        [Directory]>>( assertion(exists_directory(Directory)),
                       directory_files(Directory, Names), sort(Names, Sorted),
                       assertion(Sorted == ['.', '..']),
                       nb_setval(scratch_seen, Directory) )),
    nb_getval(scratch_seen, Seen), nb_delete(scratch_seen),
    assertion(\+ exists_directory(Seen)).

% A fixture must not convert its goal's outcome. These two are what let a real
% test failure stay a failure and a real error stay an error, instead of the
% fixture swallowing either into the other.
test(a_failing_goal_fails_the_fixture_and_still_removes_the_directory) :-
    \+ with_scratch_directory(scratch_fail_case,
           [Directory]>>( nb_setval(scratch_seen, Directory), fail )),
    nb_getval(scratch_seen, Seen), nb_delete(scratch_seen),
    assertion(\+ exists_directory(Seen)).

test(an_exception_propagates_and_still_removes_the_directory) :-
    catch(with_scratch_directory(scratch_throw_case,
              [Directory]>>( nb_setval(scratch_seen, Directory),
                             throw(error(scratch_probe, _)) )),
          error(Formal, _), true),
    assertion(Formal == scratch_probe),
    nb_getval(scratch_seen, Seen), nb_delete(scratch_seen),
    assertion(\+ exists_directory(Seen)).

% Contents, not just the directory, because a fixture that leaves files behind
% fails delete_directory/1 and would leak one directory per test.
test(a_directory_with_contents_is_still_removed) :-
    with_scratch_directory(scratch_contents_case,
        [Directory]>>( directory_file_path(Directory, records, File),
                       setup_call_cleanup(open(File, write, Stream),
                                          write(Stream, hello), close(Stream)),
                       nb_setval(scratch_seen, Directory) )),
    nb_getval(scratch_seen, Seen), nb_delete(scratch_seen),
    assertion(\+ exists_directory(Seen)).

test(the_whole_fixture_works_with_no_tmpdir_in_the_environment) :-
    with_tmpdir_unset(
        with_scratch_directory(scratch_unset_case,
            [Directory]>>assertion(exists_directory(Directory)))).

:- end_tests(scratch).
