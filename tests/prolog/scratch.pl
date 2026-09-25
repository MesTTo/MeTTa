% Purpose: resolve one scratch parent for every suite fixture, and make a
%   uniquely named directory under it, owned by a goal or by its caller.
% Assumes: the process may run with TMPDIR set or unset. Both are ordinary; a
%   plain interactive shell on this box exports neither.
% Guarantees:
%   - scratch_parent/1 is det and cannot fail, so a fixture built on it cannot
%     produce the vacuous "failed" a bare getenv/2 gives when TMPDIR is unset
%     [tested: tests/prolog/suites/seams/scratch.plt; commit=2e54536e7b10e2e396a45e846c757258de0cd4b9]
%   - the parent is TMPDIR when the environment sets it, keeping fixtures off
%     a RAM-backed /tmp, and SWI's tmp_dir flag otherwise
%     [measured 2026-09-21: with TMPDIR pointed at a checkout directory,
%      current_prolog_flag(tmp_dir, D) still answered /tmp, so tmp_dir does
%      NOT track TMPDIR on this build and cannot stand in for it; commit=2e54536e7b10e2e396a45e846c757258de0cd4b9]
% Owns resources: with_scratch_directory/2 creates the directory and deletes it
%   with its contents on success, failure or exception. make_scratch_directory/2
%   hands the directory to its caller, which deletes it: a plunit unit makes one
%   in its setup for all its tests and deletes it in its cleanup.

:- module(scratch, [scratch_parent/1, make_scratch_directory/2, with_scratch_directory/2]).
:- use_module(library(filesex), [directory_file_path/3, delete_directory_and_contents/1]).
:- meta_predicate with_scratch_directory(+, 1).

%! scratch_parent(-Parent) is det.
%
%  Where fixtures go. Three suites spelled this as a bare `getenv('TMPDIR', P)`
%  as the first goal of their fixture. getenv/2 FAILS rather than raising when
%  the variable is unset, so the whole test failed before reaching its subject
%  and plunit printed "failed" with no error and no clue which goal died
%  [measured 2026-09-21: lib_csv_surface 45 failures and lib_json_surface 15
%  with TMPDIR unset, 0 and 0 with it set, same tree and same runner].
scratch_parent(Parent) :-
    (   getenv('TMPDIR', Parent)
    ->  true
    ;   current_prolog_flag(tmp_dir, Parent)
    ).

%! make_scratch_directory(+Base, -Directory) is det.
%
%  Create a fresh empty directory named from Base under the scratch parent and
%  leave it to the caller. tmp_file/2 contributes only the unique basename,
%  because the directory it would pick is the tmp_dir flag and that ignores
%  TMPDIR here.
make_scratch_directory(Base, Directory) :-
    scratch_parent(Parent),
    tmp_file(Base, Temporary), file_base_name(Temporary, Name),
    directory_file_path(Parent, Name, Directory),
    make_directory(Directory).

%! with_scratch_directory(+Base, :Goal) is semidet.
%
%  Call Goal(Directory) on a fresh empty directory, removing it and anything
%  left in it afterwards.
with_scratch_directory(Base, Goal) :-
    setup_call_cleanup(make_scratch_directory(Base, Directory),
                       call(Goal, Directory),
                       delete_directory_and_contents(Directory)).
