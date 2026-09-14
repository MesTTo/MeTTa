% Purpose: verify release preparation before either native clearing phase.
% Guarantees: preparation retires references before row deletion, remains
%   retryable, and refuses external heirs or callback errors before storage
%   changes [tested: release_preparation; commit=0891c522503ca9856fb654f306364f4ae9736b22].
% Owns resources: fixtures release their spaces and erase callback tracing.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(prolog_wrap)).

:- begin_tests(release_preparation).

release_setup :-
    metta_host_set_silent(true),
    nb_setval(release_preparation_spaces, []).

release_space(Space) :-
    gensym('&release-preparation-', Space), space_module(Space, _),
    nb_getval(release_preparation_spaces, Before),
    nb_setval(release_preparation_spaces, [Space|Before]).

release_cleanup :-
    nb_getval(release_preparation_spaces, Spaces),
    maplist(metta_release_space, Spaces),
    nb_delete(release_preparation_spaces),
    metta_host_set_silent(false).

release_note(Space) :-
    nb_getval(release_preparation_published, Before),
    nb_setval(release_preparation_published, [Space|Before]).

release_trace(Goal, Published) :-
    setup_call_cleanup(
        ( nb_setval(release_preparation_published, []),
          wrap_predicate(metta_engine:metta_reference_publish_face(Space, _, _, _),
                         release_preparation_trace, Original,
                         ( plunit_release_preparation:release_note(Space),
                           call(Original) )) ),
        ( call(Goal), nb_getval(release_preparation_published, Published) ),
        ( unwrap_predicate(metta_engine:metta_reference_publish_face(_, _, _, _),
                           release_preparation_trace),
          nb_delete(release_preparation_published) )).

test(preliminary_clear_retires_the_provider_once_before_removing_rows,
     [forall(member(Count, [1, 8, 32])),
      setup(release_setup), cleanup(release_cleanup)]) :-
    release_space(Home), release_space(Receiver),
    forall(between(1, Count, N),
           metta_add_atom(Home, [=, ['release-value', N], N], _)),
    metta_add_atom(Receiver, [from, Home], _),
    release_trace(metta_clear_space_for_release(Home), Published),
    assertion(Published == [Receiver]),
    assertion(\+ 'get-atoms'(Home, _)),
    findall(Value, evalc(['release-value', 1], Receiver, Value), Values),
    assertion(Values == [['release-value', 1]]),
    release_trace((metta_clear_space_for_release(Home), metta_release_space(Home)),
                  Repeated),
    assertion(Repeated == []).

test(preliminary_clear_refuses_an_external_heir_before_mutation,
     [setup(release_setup), cleanup(release_cleanup)]) :-
    release_space(Home), release_space(Child),
    metta_declare_space_parent(Child, Home),
    metta_add_atom(Home, [kept, value], _),
    catch((metta_clear_space_for_release(Home), Result = accepted),
          Error, Result = raised(Error)),
    assertion(Result == raised(error(metta_space_parent_live_child(Home, Child), none))),
    assertion('get-atoms'(Home, [kept, value])).

test(preparation_errors_leave_storage_for_a_retry,
     [setup(release_setup), cleanup(release_cleanup)]) :-
    release_space(Home),
    metta_add_atom(Home, [kept, value], _),
    setup_call_cleanup(
        assertz((seam:space_releasing(Home) :- throw(release_preparation_refusal)), Ref),
        catch((metta_clear_space_for_release(Home), Result = accepted),
              Error, Result = raised(Error)),
        erase(Ref)),
    assertion(Result == raised(release_preparation_refusal)),
    assertion('get-atoms'(Home, [kept, value])),
    metta_clear_space_for_release(Home),
    assertion(\+ 'get-atoms'(Home, _)).

:- end_tests(release_preparation).
