% Guarantees: source imports are queryable and undo preserves occurrence ownership
%   [tested: lib_import_lifecycle; commit=4f2d6c0f8eb293b73f8dde30a1c84e24834f7393].
% Purpose: verify queryable import records, exact source undo, and static-import!.
%   The fast path for a large data file converts a
%   .metta file to an inert occurrence image, qcompiles it, and restores its
%   rows on each load. Every one of those steps could silently produce or serve
%   the wrong data, and three of them did.
% Guarantees:
%   - the conversion goes through the engine's own reader, so a blank line, a
%     comment, a form spanning lines, an escaped quote and a run of spaces all
%     survive [tested: import_converts_through_the_reader]
%   - the facts land where the space actually reads them
%     [tested: import_facts_land_where_the_space_reads_them]
%   - a conversion that does not finish leaves NO output, so the next run
%     re-converts rather than serving half a file
%     [tested: import_removes_a_partial_conversion]
%   - a cache older than its source is not used
%     [tested: import_reconverts_a_stale_cache]
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- initialization(consult('../../lib/lib_import/lib_import.pl')).

% One form per line, no comments, no escapes and no runs of spaces were the
% four assumptions the line-by-line converter made and the format does not
% carry. A blank line failed sub_string/5, which failed the whole conversion
% and left the partly written output CLOSED rather than removed: the next run
% qcompiled the truncated file and reported success with half the data, in
% binary, for good.
awkward_source("; a comment line, which is not a form\n\c
                (fact a 1)\n\c
                (fact b 2)\n\c
                \n\c
                (fact c 3)\n\c
                (fact\n\c
                   d 4)\n\c
                (text e \"a \\\"quoted\\\" value\")\n\c
                (spaced f \"two  spaces\")\n").

import_space('&plunit_import').

% A directory of its own per test, so a leftover cache cannot make the next
% test pass for the wrong reason. meta_predicate because the checks below are
% compiled into their unit's module, not into this file's. The working
% directory is the reader's own scope door: `working_dir/1` is a declared
% context reader over a trailed stack, not a dynamic fact a fixture can assert.
:- meta_predicate with_import_dir(+, +, 2).
with_import_dir(Stem, Source, Goal) :-
    tmp_file(import, Dir),
    make_directory(Dir),
    atomic_list_concat([Dir, '/', Stem, '.metta'], MettaFile),
    setup_call_cleanup(
        setup_call_cleanup(open(MettaFile, write, Out),
                           write(Out, Source),
                           close(Out)),
        filereader:with_working_directory(Dir, call(Goal, Dir, Stem)),
        delete_directory_and_contents(Dir)).

clear_import_space :-
    import_space(Space),
    clear_native_atoms(Space).

:- begin_tests(lib_import_conversion, [cleanup(clear_import_space)]).

test(import_converts_through_the_reader) :-
    awkward_source(Source),
    with_import_dir(data, Source, check_awkward_conversion).

check_awkward_conversion(_, Stem) :-
    import_space(Space),
    'static-import!'(Space, Stem, true),
    findall(Atom, 'get-atoms'(Space, Atom), Atoms),
    % Six forms, one comment and one blank line, and the two-line form is one
    % atom rather than two.
    assertion(length(Atoms, 6)),
    assertion(memberchk([fact, c, 3], Atoms)),
    assertion(memberchk([fact, d, 4], Atoms)),
    assertion(memberchk([text, e, "a \"quoted\" value"], Atoms)),
    assertion(memberchk([spaced, f, "two  spaces"], Atoms)),
    clear_import_space.

% The converter wrote '&self'(fact,a,1) into USER, while native atoms live in
% the storage module '$metta_atoms:&self'. Every clause loaded, nothing could
% read them, and the import reported success.
test(import_facts_land_where_the_space_reads_them) :-
    with_import_dir(where, "(fact a 1)\n", check_facts_are_readable).

check_facts_are_readable(Dir, Stem) :-
    import_space(Space),
    'static-import!'(Space, Stem, true),
    findall(V, match(Space, [fact, a, V], V, _), Values),
    assertion(Values == [1]),
    % And in the storage module, not in user.
    native_storage_module(Space, Module),
    functor(Head, Space, 4),
    assertion(( clause(Module:Head, true) )),
    assertion(\+ clause(user:Head, true)),
    atomic_list_concat([Dir, '/', Stem, '.tokens-v1.pl'], PlFile),
    assertion(exists_file(PlFile)),
    clear_import_space.

:- end_tests(lib_import_conversion).

:- begin_tests(lib_import_cache, [cleanup(clear_import_space)]).

% A runnable cannot become an atom. The conversion refuses it, and what it has
% written so far must not survive, because "a .pl exists" is the branch the
% next run takes.
test(import_removes_a_partial_conversion) :-
    with_import_dir(bad, "(fact a 1)\n!(println! oops)\n", check_partial_removed).

check_partial_removed(Dir, Stem) :-
    import_space(Space),
    catch('static-import!'(Space, Stem, true), Error, true),
    assertion(Error = error(metta_static_import_form(_, _), _)),
    atomic_list_concat([Dir, '/', Stem, '.tokens-v1.pl'], PlFile),
    assertion(\+ exists_file(PlFile)),
    findall(A, 'get-atoms'(Space, A), Atoms),
    assertion(Atoms == []).

% A cache older than the source answers from data the file no longer holds.
% The old branches asked only whether the cache EXISTED.
test(import_reconverts_a_stale_cache) :-
    with_import_dir(stale, "(fact a 1)\n", check_stale_cache).

check_stale_cache(Dir, Stem) :-
    import_space(Space),
    'static-import!'(Space, Stem, true),
    clear_import_space,
    atomic_list_concat([Dir, '/', Stem, '.metta'], MettaFile),
    atomic_list_concat([Dir, '/', Stem, '.tokens-v1.pl'], PlFile),
    atomic_list_concat([Dir, '/', Stem, '.tokens-v1.qlf'], QlfFile),
    % Rewrite the source and date it after both caches.
    setup_call_cleanup(open(MettaFile, write, Out),
                       write(Out, "(fact a 1)\n(fact b 2)\n"),
                       close(Out)),
    time_file(MettaFile, SourceTime),
    Older is SourceTime - 10,
    set_time_file(PlFile, [], [modified(Older)]),
    set_time_file(QlfFile, [], [modified(Older)]),
    assertion(\+ lib_import:static_import_cache_fresh(MettaFile, QlfFile)),
    'static-import!'(Space, Stem, true),
    findall(A, 'get-atoms'(Space, A), Atoms),
    assertion(length(Atoms, 2)),
    clear_import_space.

:- end_tests(lib_import_cache).

:- begin_tests(lib_import_tokens).

test(cache_preserves_tokens_in_another_space_and_after_source_deletion) :-
    with_import_dir(tokens, "(row 1)\n(row 1)\n", check_token_cache).

check_token_cache(Dir, Stem) :-
    setup_call_cleanup(
        ('new-space'(First), 'new-space'(Second)),
        ( 'static-import!'(First, Stem, true),
          metta_host_blame(First, [row,1], Tokens), assertion(length(Tokens, 2)),
          'static-import!'(First, Stem, true),
          metta_host_blame(First, [row,1], Repeated), assertion(Repeated == Tokens),
          atomic_list_concat([Dir, '/', Stem, '.metta'], Source),
          atomic_list_concat([Dir, '/', Stem, '.tokens-v1.pl'], TextCache),
          delete_file(Source), delete_file(TextCache),
          'static-import!'(Second, Stem, true),
          metta_host_blame(Second, [row,1], Restored), assertion(Restored == Tokens),
          assertion(\+ lib_import:static_import_image(_)),
          flag('$metta_generation', Next, Next),
          forall(member([t,_,Gen], Tokens), assertion(Next > Gen)) ),
        (metta_release_space(First), metta_release_space(Second))).

test(empty_static_cache_is_loadable) :-
    with_import_dir(empty, "; no atoms\n", check_empty_cache).

check_empty_cache(_, Stem) :-
    setup_call_cleanup('new-space'(Space),
        ( 'static-import!'(Space, Stem, true),
          'static-import!'(Space, Stem, true),
          findall(A, 'get-atoms'(Space, A), Atoms), assertion(Atoms == []) ),
        metta_release_space(Space)).

test(static_equations_and_variable_data_remain_inert) :-
    with_import_dir(inert, "(= (t0-static-equation $x) $x)\n($head a)\n$scalar\n",
                    check_inert_cache).

check_inert_cache(_, Stem) :-
    setup_call_cleanup('new-space'(Space),
        ( 'static-import!'(Space, Stem, true),
          findall(A, 'get-atoms'(Space, A), Atoms),
          msort(Atoms, Sorted),
          assertion(Sorted =@= [_, [_,a], [=,['t0-static-equation',X],X]]),
          space_module(Space, Module),
          assertion(\+ filereader:'$metta_equation_token'(Module,_,_,_)),
          assertion(\+ spaces:deferred_metta_function(_,_,Space,_,_,_)) ),
        metta_release_space(Space)).

test(static_load_rollback_discards_its_occurrences_and_source_rows) :-
    with_import_dir(rollback, "(row 1)\n", check_static_rollback).

check_static_rollback(Dir, Stem) :-
    setup_call_cleanup('new-space'(Space),
        ( assertion(\+ transaction(('static-import!'(Space, Stem, true), fail))),
          findall(A, 'get-atoms'(Space, A), Atoms), assertion(Atoms == []),
          assertion(\+ filereader:metta_source_load(_,Space,_,_)),
          assertion(\+ lib_import:static_import_image(_)),
          atomic_list_concat([Dir, '/', Stem, '.tokens-v1.qlf'], Cache),
          assertion(exists_file(Cache)),
          'static-import!'(Space, Stem, true),
          metta_host_blame(Space, [row,1], Tokens), assertion(length(Tokens, 1)) ),
        metta_release_space(Space)).

:- end_tests(lib_import_tokens).

% Source ownership is occurrence identity, including equal caller-owned rows.
:- begin_tests(lib_import_lifecycle).

:- meta_predicate with_owned_import(+, 2).
with_owned_import(Source, Goal) :-
    with_import_dir(owned, Source, owned_import_in_dir(Goal)).

:- meta_predicate owned_import_in_dir(2, +, +).
owned_import_in_dir(Goal, Dir, Stem) :-
    directory_file_path(Dir, Stem, Base),
    file_name_extension(Base, metta, Path),
    setup_call_cleanup('new-space'(Space), call(Goal, Space, Path),
                       spaces:metta_release_space(Space)).

import_paths(Space, Paths) :-
    imports(Space, View),
    findall(Path, match(View, [import, Path], Path, Path), Paths).

test(markers_are_queryable_and_reimport_is_idempotent) :-
    with_owned_import("(payload 1)\n(payload 2)\n", check_import_rows).

check_import_rows(Space, Path) :-
    import_paths(Space, Empty), assertion(Empty == []),
    'import!'(Space, Path, true),
    'import!'(Space, Path, true),
    import_paths(Space, Paths), assertion(Paths == [Path]),
    findall(A, 'get-atoms'(Space, A), Atoms),
    assertion(Atoms == [[payload, 1], [payload, 2]]).

test(undo_preserves_equal_atoms_before_and_after_import) :-
    with_owned_import("(shared x)\n(shared x)\n", check_exact_undo).

check_exact_undo(Space, Path) :-
    'add-atom'(Space, [shared, x], _),
    'import!'(Space, Path, true),
    'add-atom'(Space, [shared, x], _),
    'unimport!'(Space, Path, true),
    findall(A, 'get-atoms'(Space, A), Atoms),
    assertion(Atoms == [[shared, x], [shared, x]]),
    import_paths(Space, Paths), assertion(Paths == []),
    'unimport!'(Space, Path, true),
    findall(A, 'get-atoms'(Space, A), Again), assertion(Again == Atoms),
    'import!'(Space, Path, true),
    findall(A, 'get-atoms'(Space, A), Reloaded), assertion(length(Reloaded, 4)).

test(undo_preserves_equal_equations_and_their_execution) :-
    with_owned_import("(= (owned-answer $x) $x)\n", check_equation_undo).

check_equation_undo(Space, Path) :-
    'add-atom'(Space, [=, ['owned-answer', X], X], _),
    'import!'(Space, Path, true),
    'add-atom'(Space, [=, ['owned-answer', Y], Y], _),
    'unimport!'(Space, Path, true),
    findall(A, 'get-atoms'(Space, A), Atoms), assertion(length(Atoms, 2)),
    space_module(Space, Module),
    findall(R, with_metta_module(Module, eval(['owned-answer', 42], R)), Results),
    assertion(Results == [42, 42]).

test(undo_skips_removed_occurrences_and_preserves_replacements) :-
    with_owned_import("(payload x)\n", check_removed_occurrence).

check_removed_occurrence(Space, Path) :-
    'import!'(Space, Path, true),
    'remove-atom'(Space, [payload, x], _),
    'add-atom'(Space, [payload, x], _),
    'unimport!'(Space, Path, true),
    findall(A, 'get-atoms'(Space, A), Atoms),
    assertion(Atoms == [[payload, x]]).

test(undo_survives_a_deleted_source) :-
    with_owned_import("(payload x)\n", check_deleted_source).

check_deleted_source(Space, Path) :-
    'import!'(Space, Path, true), delete_file(Path),
    'unimport!'(Space, Path, true), 'unimport!'(Space, Path, true),
    findall(A, 'get-atoms'(Space, A), Atoms), assertion(Atoms == []).

test(undo_keeps_another_spaces_import) :-
    with_owned_import("(= (owned-answer) kept)\n", check_other_space).

check_other_space(Space, Path) :-
    setup_call_cleanup('new-space'(Other),
        ( 'import!'(Space, Path, true), 'import!'(Other, Path, true),
          'unimport!'(Space, Path, true),
          space_module(Other, Module),
          findall(R, with_metta_module(Module, eval(['owned-answer'], R)), Results),
          assertion(Results == [kept]),
          import_paths(Other, Paths), assertion(Paths == [Path]) ),
        spaces:metta_release_space(Other)).

test(nested_imports_have_independent_ownership) :-
    with_owned_import("(parent payload)\n!(import! &self child)\n", check_nested).

check_nested(Space, Path) :-
    file_directory_name(Path, Dir), directory_file_path(Dir, 'child.metta', Child),
    setup_call_cleanup(open(Child, write, Out), write(Out, "(child payload)\n"), close(Out)),
    'import!'(Space, Path, true),
    'unimport!'(Space, Path, true),
    findall(A, 'get-atoms'(Space, A), Atoms), assertion(Atoms == [[child, payload]]),
    import_paths(Space, Paths), assertion(Paths == [Child]),
    'unimport!'(Space, Child, true),
    findall(A, 'get-atoms'(Space, A), Empty), assertion(Empty == []).

test(failed_import_has_no_row) :-
    with_owned_import("(payload x)\n!(import! &self definitely-missing-import)\n", check_failed_row).

check_failed_row(Space, Path) :-
    catch('import!'(Space, Path, true), Error, true), assertion(nonvar(Error)),
    import_paths(Space, Paths), assertion(Paths == []),
    findall(A, 'get-atoms'(Space, A), Atoms), assertion(Atoms == []).

test(clear_removes_rows_from_a_retained_view) :-
    with_owned_import("(payload x)\n", check_clear_rows).

check_clear_rows(Space, Path) :-
    'import!'(Space, Path, true), imports(Space, View),
    clear_native_atoms(Space),
    findall(A, match(View, A, A, A), Rows), assertion(Rows == []).

test(import_view_refuses_writes,
     [throws(error(permission_error(add, import_records, _), _))]) :-
    imports('&self', View), 'add-atom'(View, [import, fake], _).


test(overlapping_sources_keep_independent_occurrences) :-
    with_owned_import("(shared x)\n(= (overlap-answer) kept)\n", check_overlap).

check_overlap(Space, Path) :-
    file_directory_name(Path, Dir), directory_file_path(Dir, 'second.metta', Other),
    copy_file(Path, Other),
    'import!'(Space, Path, true), 'import!'(Space, Other, true),
    'unimport!'(Space, Path, true),
    findall(A, match(Space, [shared, A], A, A), Rows), assertion(Rows == [x]),
    space_module(Space, Module),
    findall(R, with_metta_module(Module, eval(['overlap-answer'], R)), Results),
    assertion(Results == [kept]),
    import_paths(Space, Paths), assertion(Paths == [Other]),
    'unimport!'(Space, Other, true),
    findall(A, 'get-atoms'(Space, A), Empty), assertion(Empty == []).

test(refused_withdrawal_restores_atoms_and_marker) :-
    with_owned_import("(first x)\n(blocked x)\n(last x)\n", check_refused_undo).

check_refused_undo(Space, Path) :-
    'import!'(Space, Path, true),
    setup_call_cleanup(
        asserta((spaces:metta_remove_atom(Space, [blocked, x], false) :- !), Ref),
        catch('unimport!'(Space, Path, true), Error, true),
        erase(Ref)),
    assertion(Error = error(permission_error(remove, source_atom, [blocked,x]), _)),
    findall(A, 'get-atoms'(Space, A), Atoms),
    assertion(Atoms == [[first,x], [blocked,x], [last,x]]),
    import_paths(Space, Paths), assertion(Paths == [Path]),
    'unimport!'(Space, Path, true),
    findall(A, 'get-atoms'(Space, A), Empty), assertion(Empty == []).


test(a_removal_callback_does_not_inherit_source_ownership) :-
    with_owned_import("(trigger)\n", check_removal_callback).

check_removal_callback(Space, Path) :-
    'add-atom'(Space, [=, ['callback-answer', X], X], _),
    'import!'(Space, Path, true),
    setup_call_cleanup(
        asserta((spaces:metta_remove_atom(Space, [trigger], Result) :- !,
                    spaces:metta_remove_atom_raw(Space, [trigger], Result),
                    spaces:metta_remove_atom(Space,
                                            [=, ['callback-answer', Y], Y], _)), Ref),
        'unimport!'(Space, Path, true),
        erase(Ref)),
    findall(A, 'get-atoms'(Space, A), Atoms), assertion(Atoms == []),
    space_module(Space, Module),
    findall(R, with_metta_module(Module, eval(['callback-answer', 42], R)), Results),
    assertion(Results == [['callback-answer', 42]]).


test(deferred_overlapping_sources_keep_the_surviving_function) :-
    setup_call_cleanup(asserta(filereader:silent(true), Silent),
        with_owned_import("(shared x)\n(= (overlap-answer) kept)\n", check_overlap),
        erase(Silent)).

test(deferred_import_keeps_another_spaces_function) :-
    setup_call_cleanup(asserta(filereader:silent(true), Silent),
        with_owned_import("(= (owned-answer) kept)\n", check_other_space),
        erase(Silent)).


test(typed_overlapping_sources_keep_the_surviving_function) :-
    with_owned_import("(shared x)\n(: overlap-answer (-> Symbol))\n(= (overlap-answer) kept)\n",
                      check_overlap).


test(a_replaced_equation_is_not_withdrawn_with_its_former_source) :-
    with_owned_import("(= (replacement-answer $x) $x)\n", check_replaced_equation).

check_replaced_equation(Space, Path) :-
    'import!'(Space, Path, true),
    'remove-atom'(Space, [=, ['replacement-answer', X], X], _),
    'add-atom'(Space, [=, ['replacement-answer', Y], Y], _),
    'unimport!'(Space, Path, true),
    findall(A, 'get-atoms'(Space, A), Atoms), assertion(length(Atoms, 1)),
    space_module(Space, Module),
    findall(R, with_metta_module(Module, eval(['replacement-answer', 42], R)), Results),
    assertion(Results == [42]).


test(undo_does_not_force_deferred_compilation) :-
    setup_call_cleanup(asserta(filereader:silent(true), Silent),
        with_owned_import("(= (uncompiled-answer x) x)\n(= (uncompiled-answer y) y)\n",
                          check_uncompiled_undo),
        erase(Silent)).

check_uncompiled_undo(Space, Path) :-
    setup_call_cleanup('new-space'(Other),
        ( 'import!'(Space, Path, true), 'import!'(Other, Path, true),
          setup_call_cleanup(
              wrap_predicate(spaces:metta_ensure_compiled(F), import_no_compile, Wrapped,
                  ( F == 'uncompiled-answer'
                  -> throw(error(unexpected_import_compilation(F), none))
                  ; call(Wrapped) )),
              'unimport!'(Space, Path, true),
              unwrap_predicate(spaces:metta_ensure_compiled/1, import_no_compile)),
          findall(A, 'get-atoms'(Space, A), Atoms), assertion(Atoms == []),
          findall(A, 'get-atoms'(Other, A), Others), assertion(length(Others, 2)),
          assertion(spaces:deferred_metta_function('uncompiled-answer', _, Other, _, _, _)) ),
        spaces:metta_release_space(Other)).


test(deferred_nested_equations_keep_their_exact_source_owner) :-
    setup_call_cleanup(asserta(filereader:silent(true), Silent),
        with_owned_import("(= (nested-answer) first)\n!(import! &self child)\n(= (nested-answer) second)\n",
                          check_nested_equations),
        erase(Silent)).

check_nested_equations(Space, Path) :-
    file_directory_name(Path, Dir), directory_file_path(Dir, 'child.metta', Child),
    setup_call_cleanup(open(Child, write, Out),
                       write(Out, "(= (nested-answer) third)\n"), close(Out)),
    'import!'(Space, Path, true), space_module(Space, Module),
    findall(R, with_metta_module(Module, eval(['nested-answer'], R)), Before),
    assertion(Before == [first, third, second]),
    'unimport!'(Space, Path, true),
    findall(R, with_metta_module(Module, eval(['nested-answer'], R)), After),
    assertion(After == [third]),
    findall(A, 'get-atoms'(Space, A), Atoms),
    assertion(Atoms == [[=, ['nested-answer'], third]]).

test(a_callback_can_force_remaining_equations_during_source_withdrawal) :-
    setup_call_cleanup(asserta(filereader:silent(true), Silent),
        with_owned_import("(= (callback-deferred) first)\n(= (callback-deferred) second)\n",
                          check_deferred_callback),
        erase(Silent)).

check_deferred_callback(Space, Path) :-
    file_directory_name(Path, Dir), directory_file_path(Dir, 'second.metta', Other),
    setup_call_cleanup(open(Other, write, Out),
                       write(Out, "(= (callback-deferred) third)\n"), close(Out)),
    'import!'(Space, Path, true), 'import!'(Space, Other, true),
    space_module(Space, Module),
    setup_call_cleanup(
        asserta((spaces:metta_remove_atom(Space, [=, ['callback-deferred'], Body], Result) :- !,
                    spaces:metta_remove_atom_raw(Space,
                                                [=, ['callback-deferred'], Body], Result),
                    findall(R, with_metta_module(Module, eval(['callback-deferred'], R)), _)), Ref),
        'unimport!'(Space, Path, true),
        erase(Ref)),
    findall(R, with_metta_module(Module, eval(['callback-deferred'], R)), Results),
    assertion(Results == [third]),
    findall(A, 'get-atoms'(Space, A), Atoms),
    assertion(Atoms == [[=, ['callback-deferred'], third]]).

test(a_callback_keeps_the_surviving_equations_own_type_group) :-
    setup_call_cleanup(asserta(filereader:silent(true), Silent),
        with_owned_import("(: callback-typed (-> Number))\n(= (callback-typed) 1)\n(: callback-typed (-> Bool))\n(= (callback-typed) True)\n",
                          check_deferred_type_callback),
        erase(Silent)).

check_deferred_type_callback(Space, Path) :-
    file_directory_name(Path, Dir), directory_file_path(Dir, 'second.metta', Other),
    setup_call_cleanup(open(Other, write, Out),
                       write(Out, "(: callback-typed (-> String))\n(= (callback-typed) \"third\")\n"), close(Out)),
    'import!'(Space, Path, true), 'import!'(Space, Other, true),
    space_module(Space, Module),
    setup_call_cleanup(
        asserta((spaces:metta_remove_atom(Space, [=, ['callback-typed'], 'True'], Result) :- !,
                    spaces:metta_remove_atom_raw(Space,
                                                [=, ['callback-typed'], 'True'], Result),
                    findall(R, with_metta_module(Module, eval(['callback-typed'], R)), _)), Ref),
        'unimport!'(Space, Path, true),
        erase(Ref)),
    findall(R, with_metta_module(Module, eval(['callback-typed'], R)), Results),
    assertion(Results == ["third"]),
    findall(Body-Types, translator:fun_meta_clause_types(Module, 'callback-typed', _, Body, Types),
            Metadata),
    assertion(Metadata == ["third"-[[->, 'String']]]).


test(undo_invalidates_a_specialization_after_a_failed_reload) :-
    with_owned_import("(= (import-bump $n) (+ $n 1))\n(= (import-twice $f $x) ($f ($f $x)))\n",
                      check_specialized_undo).

check_specialized_undo(Space, Path) :-
    read_file_to_string(Path, Source, []),
    'import!'(Space, Path, true),
    setup_call_cleanup(open(Path, write, Broken),
                       write(Broken, "(= (import-bump $n) (+ $n 2))\n!(import! &self definitely-missing-import)\n"),
                       close(Broken)),
    catch('import!'(Space, Path, true), Error, true), assertion(nonvar(Error)),
    setup_call_cleanup(open(Path, write, Restored), write(Restored, Source), close(Restored)),
    'import!'(Space, Path, true),
    space_module(Space, Module),
    findall(R, with_metta_module(Module, eval(['import-twice', 'import-bump', 1], R)), Before),
    assertion(Before == [3]),
    assertion(specializer:ho_specialization(Module, 'import-twice', _)),
    'unimport!'(Space, Path, true),
    assertion(\+ specializer:ho_specialization(Module, 'import-twice', _)),
    findall(A, 'get-atoms'(Space, A), Atoms), assertion(Atoms == []),
    findall(R, with_metta_module(Module, eval(['import-twice', 'import-bump', 1], R)), After),
    assertion(After == [['import-twice', 'import-bump', 1]]).

:- end_tests(lib_import_lifecycle).

% The library-import door preserves the process-wide host tier.
% [tested: lib_import:use_module_imports_into_the_shared_host_tier; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]
:- begin_tests(lib_import).

test(use_module_imports_into_the_shared_host_tier) :-
    assertion(\+ current_predicate(user:write_to_codes/2)),
    'use-module!'(codesio, true),
    assertion(predicate_property(user:write_to_codes(_, _), imported_from(codesio))),
    space_module('&self', Self),
    call(Self:write_to_codes, kept, Codes),
    assertion(Codes == [107, 101, 112, 116]).

:- end_tests(lib_import).
