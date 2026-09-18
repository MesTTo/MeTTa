% Purpose: compare scoped publication with the source journal's original policy.
% Guarantees: ownership, callback order and transaction visibility agree through
%   nested pins and recompiles, failure, exceptions, threads and engines
%   [tested: source_publication; commit=e246959279271d22f166a1c8fb1840896295a020].
% Owns resources: fixtures erase their journal rows and listeners and release
%   the temporary empty source and its space.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(prolog_wrap)).

:- begin_tests(source_publication).
:- dynamic publication_event/1.
:- meta_predicate owning(+, 0), recompiling(+, 0), real_source(0).

owning(Load, Goal) :- filereader:with_owning_source_load(Load, Goal).
recompiling(Owners, Goal) :- filereader:with_source_recompile_owners(Owners, Goal).

real_source(Goal) :-
    setup_call_cleanup(
        ('new-space'(Space), tmp_file_stream(text, Path, Out), close(Out)),
        filereader:with_source_load(Path, Space,
            (filereader:read_metta_source(Path, _), Goal)),
        (metta_release_space(Space), delete_file(Path))).

clean_publication :-
    retractall(filereader:source_load_assertion(_, _, publication(_))),
    retractall(filereader:source_load_support_assertions(_, [publication(_)])),
    retractall(publication_event(_)).

% The cut's owner interpreter is the independent oracle, including its cut
% before matching the current load against the nearest recompile context.
expected_artifact_owners(Owners) :-
    filereader:source_recompile_context(Context, Owners), !,
    ( filereader:active_source_load(Load) -> Context = load(Load) ; Context = none ).
expected_artifact_owners(Owners) :- expected_stored_owners(Owners).

expected_stored_owners(Owners) :-
    ( filereader:active_source_load(Load0)
    -> ( Load0 = '$metta_owner_pin'(Load) -> true ; Load = Load0 ),
       ( Load == none -> Owners = [] ; Owners = [Load] )
    ; Owners = [] ).

check_publication(Tag) :-
    ( expected_artifact_owners(ArtifactOwners) -> true
    ; expected_stored_owners(ArtifactOwners) ),
    expected_stored_owners(StoredOwners),
    filereader:record_source_assertion(publication(Tag)),
    filereader:record_source_atom_assertion(publication(Tag)),
    support_graph:support_assertion_records([publication(Tag)]),
    findall(O, filereader:source_load_assertion(O, artifact, publication(Tag)), A),
    findall(O, filereader:source_load_assertion(O, stored, publication(Tag)), S),
    findall(O, filereader:source_load_support_assertions(O, [publication(Tag)]), G),
    assertion(A == ArtifactOwners), assertion(S == StoredOwners),
    assertion(G == ArtifactOwners).

publication_context(Context) :- b_getval('$metta_source_publication', Context).

nested_publication :-
    check_publication(unowned),
    owning(publication_outer,
      ( check_publication(outer),
        recompiling([publication_a, publication_b, publication_a],
          ( check_publication(recompile),
            owning(publication_inner, check_publication(inner)),
            owning(publication_outer, check_publication(same_pin)),
            owning(none, check_publication(no_owner)),
            check_publication(restored_recompile) )),
        check_publication(restored_outer) )).

test(nested_owners_equal_the_interpreter,
     [setup(clean_publication), cleanup(clean_publication)]) :-
    publication_context(Before), nested_publication, publication_context(After),
    assertion(After == Before).

test(recompile_without_a_source_does_not_own_stored_atoms,
     [setup(clean_publication), cleanup(clean_publication)]) :-
    recompiling([publication_a], check_publication(recompile_only)),
    recompiling([], check_publication(empty_recompile)).

test(a_pin_preserves_the_older_real_load_and_context_enumeration,
     [setup(clean_publication), cleanup(clean_publication)]) :-
    real_source(
      ( once(filereader:active_source_load(Outer)),
        owning(publication_pin,
          ( findall(L, filereader:active_source_load(L), Loads),
            assertion(Loads == ['$metta_owner_pin'(publication_pin), Outer]),
            filereader:current_owning_source_load(Owner), assertion(Owner == Outer),
            recompiling([publication_a],
              recompiling([publication_b],
                ( findall(O, filereader:source_recompile_context(_, O), Owners),
                  assertion(Owners == [[publication_b],[publication_a]]),
                  assertion(filereader:source_recompile_owners([publication_a])) ))) )) )).

test(nested_rollback_restores_the_enclosing_owner,
     [setup(clean_publication), cleanup(clean_publication)]) :-
    owning(publication_outer,
      ( \+ transaction((owning(publication_inner, check_publication(rolled_back)), fail)),
        check_publication(after_rollback) )).

test(outer_rollback_never_resurrects_an_unwound_scope,
     [setup(clean_publication), cleanup(clean_publication)]) :-
    publication_context(Before),
    \+ transaction((nested_publication, fail)),
    publication_context(After), assertion(After == Before),
    assertion(\+ filereader:source_load_assertion(_, _, publication(_))),
    assertion(\+ filereader:source_load_support_assertions(_, [publication(_)])).

test(failure_exception_and_cut_restore_the_context,
     [setup(clean_publication), cleanup(clean_publication)]) :-
    publication_context(Before),
    \+ owning(publication_failure, fail),
    catch(owning(publication_throw, throw(publication_error)),
          publication_error, true),
    once(owning(publication_cut, member(_, [a,b]))),
    publication_context(After), assertion(After == Before).

test(new_thread_and_engine_start_without_an_owner,
     [setup(clean_publication), cleanup(clean_publication)]) :-
    thread_create(nested_publication, Thread, []), thread_join(Thread, true),
    clean_publication,
    setup_call_cleanup(engine_create(done, nested_publication, Engine),
                       engine_next(Engine, done), engine_destroy(Engine)).

publication_listener(assertz, Ref) :-
    clause(filereader:source_load_assertion(Owner, Kind, publication(Tag)), true, Ref), !,
    assertz(publication_event(Owner-Kind-Tag)).
publication_listener(_, _).

test(journal_callbacks_see_each_row_in_original_order,
     [setup(clean_publication), cleanup(clean_publication)]) :-
    setup_call_cleanup(
        prolog_listen(filereader:source_load_assertion/3, publication_listener),
        owning(publication_outer,
          recompiling([publication_a,publication_b],
            check_publication(observed))),
        prolog_unlisten(filereader:source_load_assertion/3, publication_listener)),
    findall(E, publication_event(E), Events),
    assertion(Events == [publication_a-artifact-observed,
                         publication_b-artifact-observed,
                         publication_outer-stored-observed]).

test(recording_remains_visible_to_source_observer_wrappers,
     [setup(clean_publication), cleanup(clean_publication)]) :-
    setup_call_cleanup(
        wrap_predicate(filereader:record_source_atom_assertion(Ref), publication_test,
                       Wrapped, (Wrapped, assertz(publication_event(Ref)))),
        owning(publication_wrapped, check_publication(wrapped)),
        unwrap_predicate(filereader:record_source_atom_assertion/1, publication_test)),
    assertion(publication_event(publication(wrapped))).

nested_listener(assertz, Ref) :-
    clause(filereader:source_load_assertion(Owner, artifact, publication(Tag)), true, Ref), !,
    assertz(publication_event(Owner-Tag)),
    ( Owner == publication_a, Tag == reentrant
    -> owning(publication_nested,
              filereader:record_source_assertion(publication(callback)))
    ; true ).
nested_listener(_, _).

test(a_nested_callback_keeps_the_publishing_owners_and_order,
     [setup(clean_publication), cleanup(clean_publication)]) :-
    setup_call_cleanup(
        prolog_listen(filereader:source_load_assertion/3, nested_listener),
        recompiling([publication_a,publication_b],
                    filereader:record_source_assertion(publication(reentrant))),
        prolog_unlisten(filereader:source_load_assertion/3, nested_listener)),
    findall(E, publication_event(E), Events),
    assertion(Events == [publication_a-reentrant, publication_nested-callback,
                         publication_b-reentrant]).

throwing_listener(assertz, Ref) :-
    clause(filereader:source_load_assertion(_, artifact, publication(throwing)), true, Ref), !,
    throw(publication_callback_error).
throwing_listener(_, _).

test(a_callback_exception_stops_publication_and_restores_the_scope,
     [setup(clean_publication), cleanup(clean_publication)]) :-
    publication_context(Before),
    setup_call_cleanup(
        prolog_listen(filereader:source_load_assertion/3, throwing_listener),
        catch(recompiling([publication_a,publication_b],
                          filereader:record_source_assertion(publication(throwing))),
              Error, true),
        prolog_unlisten(filereader:source_load_assertion/3, throwing_listener)),
    assertion(Error == publication_callback_error),
    publication_context(After), assertion(After == Before),
    assertion(\+ filereader:source_load_assertion(publication_b, _, publication(throwing))).

publication_work(0) :- !.
publication_work(N) :- M is N-1, publication_work(M).

test(inference_limits_cannot_strand_a_publication_context,
     [setup(clean_publication), cleanup(clean_publication)]) :-
    publication_context(Before),
    forall(between(1, 1500, Budget),
      ( b_setval('$metta_source_publication', Before),
        catch(call_with_inference_limit(
          owning(publication_limited,
            recompiling([publication_a, publication_b],
              publication_work(100))), Budget, _), _, true),
        publication_context(After), assertion(Budget-After == Budget-Before) )).

:- end_tests(source_publication).
