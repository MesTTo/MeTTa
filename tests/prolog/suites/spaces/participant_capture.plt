% Purpose: verify foreign participant identity and retained completion calls.
% Assumes: the engine owns enlistment and completes foreign work after its
%   native transaction; fixture logs are engine-local and survive rollback.
% Owns resources: each test removes its provider rows and callback log.
% [source: engine/metta/space_hooks.pl:metta_enlist_foreign/1; commit=WORKTREE]

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- dynamic fpc_provider/3.
:- multifile seam:foreign_participant/3.

seam:foreign_participant(Space, Identity, Capture) :-
    fpc_provider(Space, _, _),
    clause(fpc_provider(Space, Owner, Policy), true, Identity),
    Capture = user:fpc_capture(Space, Owner, Policy).

fpc_capture(Space, Owner, Policy, Protocol) :-
    fpc_call(Owner, capture),
    fpc_policy(Policy, capture, Space),
    ( Policy == malformed -> Protocol = wrong
    ; Policy == unqualified -> Protocol = transaction(true, true, true)
    ; Protocol = transaction(user:fpc_step(Space, Owner, Policy, begin),
                             user:fpc_step(Space, Owner, Policy, commit),
                             user:fpc_step(Space, Owner, Policy, rollback)) ).

fpc_step(Space, Owner, Policy, Step) :-
    fpc_call(Owner, Step), fpc_policy(Policy, Step, Space).

fpc_policy(at(Step, throw), Step, Space) :- !,
    throw(error(fpc_refused(Space, Step), none)).
fpc_policy(at(Step, fail), Step, _) :- !, fail.
fpc_policy(at(Step, enlist(Other)), Step, _) :- !, metta_enlist_foreign(Other).
fpc_policy(_, _, _).

fpc_call(Owner, Step) :-
    nb_getval('$fpc_calls', Calls), nb_linkval('$fpc_calls', [Owner-Step|Calls]).

fpc_calls(Calls) :- nb_getval('$fpc_calls', Reversed), reverse(Reversed, Calls).

fpc_setup(Policy) :-
    fpc_cleanup, nb_setval('$fpc_calls', []),
    assertz(fpc_provider('&fpc', original, Policy)).

fpc_cleanup :-
    retractall(fpc_provider(_, _, _)), nb_setval('$fpc_calls', []).

fpc_replace(Owner, Policy) :-
    retractall(fpc_provider('&fpc', _, _)), assertz(fpc_provider('&fpc', Owner, Policy)).

% Registration edits go through these two, defined here in user: a retractall
% or assertz written inside a test runs in the unit's own module and creates
% a local fpc_provider/3 there, which then shadows this one for every later
% test [measured 2026-09-16: after unregister_keeps_original_completion,
% implementation_module answered plunit_foreign_participant_capture and the
% unit read no rows].
fpc_register(Space, Owner, Policy) :- assertz(fpc_provider(Space, Owner, Policy)).
fpc_unregister(Space) :- retractall(fpc_provider(Space, _, _)).

:- begin_tests(foreign_participant_capture).

test(unregister_keeps_original_completion,
     [setup(fpc_setup(none)), cleanup(fpc_cleanup)]) :-
    metta_transaction((metta_enlist_foreign('&fpc'), fpc_unregister('&fpc'))),
    fpc_calls(Calls),
    assertion(Calls == [original-capture, original-begin, original-commit]),
    assertion(\+ fpc_provider('&fpc', _, _)).

test(replacement_receives_no_previous_completion,
     [setup(fpc_setup(none)), cleanup(fpc_cleanup)]) :-
    metta_transaction((metta_enlist_foreign('&fpc'), fpc_replace(replacement, none))),
    fpc_calls(Calls),
    assertion(Calls == [original-capture, original-begin, original-commit]),
    assertion(fpc_provider('&fpc', replacement, none)).

test(abort_restores_registration_but_completes_original,
     [setup(fpc_setup(none)), cleanup(fpc_cleanup)]) :-
    catch(metta_transaction((metta_enlist_foreign('&fpc'),
                             fpc_replace(replacement, none),
                             throw(error(fpc_abort, none)))), Error, true),
    assertion(Error = error(fpc_abort, none)),
    assertion(fpc_provider('&fpc', original, none)),
    fpc_calls(Calls),
    assertion(Calls == [original-capture, original-begin, original-rollback]).

test(replacement_with_a_write_enlists_independently,
     [setup(fpc_setup(none)), cleanup(fpc_cleanup)]) :-
    metta_transaction((metta_enlist_foreign('&fpc'), fpc_replace(replacement, none),
                       metta_enlist_foreign('&fpc'))),
    fpc_calls(Calls),
    assertion(Calls == [original-capture, original-begin,
                        replacement-capture, replacement-begin,
                        replacement-commit, original-commit]).

test(equal_replacement_occurrence_is_a_new_registration,
     [setup(fpc_setup(none)), cleanup(fpc_cleanup)]) :-
    metta_transaction((metta_enlist_foreign('&fpc'), fpc_replace(original, none),
                       metta_enlist_foreign('&fpc'))),
    fpc_calls(Calls),
    assertion(Calls == [original-capture, original-begin,
                        original-capture, original-begin,
                        original-commit, original-commit]).

test(repeated_writes_capture_and_begin_once,
     [setup(fpc_setup(none)), cleanup(fpc_cleanup)]) :-
    metta_transaction(forall(between(1, 20, _), metta_enlist_foreign('&fpc'))),
    fpc_calls(Calls),
    assertion(Calls == [original-capture, original-begin, original-commit]).

test(nested_transaction_uses_the_same_capture,
     [setup(fpc_setup(none)), cleanup(fpc_cleanup)]) :-
    metta_transaction((metta_enlist_foreign('&fpc'),
                       metta_transaction(metta_enlist_foreign('&fpc')))),
    fpc_calls(Calls),
    assertion(Calls == [original-capture, original-begin, original-commit]).

test(speculation_keeps_the_outer_participant,
     [setup(fpc_setup(none)), cleanup(fpc_cleanup)]) :-
    metta_transaction((metta_enlist_foreign('&fpc'),
                       metta_speculate(metta_enlist_foreign('&fpc')),
                       metta_enlist_foreign('&fpc'))),
    fpc_calls(Calls),
    assertion(Calls == [original-capture, original-begin,
                        original-capture, original-begin, original-rollback,
                        original-commit]).

test(begin_can_enlist_another_provider_without_copying_its_own_state,
     [setup(fpc_setup(at(begin, enlist('&fpc-other')))), cleanup(fpc_cleanup)]) :-
    fpc_register('&fpc-other', other, none),
    metta_transaction(metta_enlist_foreign('&fpc')),
    fpc_calls(Calls),
    assertion(Calls == [original-capture, original-begin,
                        other-capture, other-begin, other-commit, original-commit]).

test(reentrant_begin_is_refused_before_recursive_capture,
     [setup(fpc_setup(at(begin, enlist('&fpc')))), cleanup(fpc_cleanup)]) :-
    catch(metta_transaction(metta_enlist_foreign('&fpc')), Error, true),
    assertion(Error = error(metta_foreign_reentrant_begin('&fpc'), _)),
    fpc_calls(Calls), assertion(Calls == [original-capture, original-begin]).

test(a_throw_after_begin_keeps_the_participant_for_rollback,
     [setup(fpc_setup(none)), cleanup(fpc_cleanup)]) :-
    metta_engine_module(Engine),
    setup_call_cleanup(
        wrap_predicate(Engine:metta_capture_participant(_, _), fpc_after_begin, Wrapped,
                       (call(Wrapped), throw(error(fpc_after_begin, none)))),
        catch(metta_transaction(metta_enlist_foreign('&fpc')), Error, true),
        unwrap_predicate(Engine:metta_capture_participant(_, _), fpc_after_begin)),
    assertion(Error = error(fpc_after_begin, none)),
    fpc_calls(Calls),
    assertion(Calls == [original-capture, original-begin, original-rollback]).

test(an_inference_cut_cannot_leave_an_unfinished_capture,
     [setup(fpc_setup(none)), cleanup(fpc_cleanup)]) :-
    metta_transaction((statistics(inferences, Before), metta_enlist_foreign('&fpc'),
                       statistics(inferences, After))),
    Last is After-Before+1,
    forall(between(1, Last, Budget),
        ( fpc_setup(none),
          metta_transaction((
              catch(ignore(call_with_inference_limit(metta_enlist_foreign('&fpc'), Budget, _)),
                    inference_limit_exceeded, true),
              nb_getval('$metta_tx_enlisted', Enlisted),
              assertion(\+ member(participant(_, _, opening), Enlisted)),
              length(Enlisted, Count) )),
          fpc_calls(Calls),
          findall(Step, (member(_-Step, Calls), memberchk(Step, [commit, rollback])), Completed),
          length(Completed, Count) )).

test(failed_capture_or_begin_has_no_completion,
     [forall(member(Step-How, [capture-throw, capture-fail, begin-throw, begin-fail])),
      setup(fpc_setup(at(Step, How))), cleanup(fpc_cleanup)]) :-
    catch((metta_transaction(metta_enlist_foreign('&fpc')) -> Result = true
          ; Result = false), Error, Result = threw(Error)),
    assertion(Result \== true),
    fpc_calls(Calls),
    ( Step == capture -> assertion(Calls == [original-capture])
    ; assertion(Calls == [original-capture, original-begin]) ).

test(failed_capture_can_be_attempted_again_in_the_same_transaction,
     [setup(fpc_setup(at(capture, throw))), cleanup(fpc_cleanup)]) :-
    metta_transaction(forall(between(1, 2, _),
        catch(metta_enlist_foreign('&fpc'), error(fpc_refused('&fpc', capture), _), true))),
    fpc_calls(Calls), assertion(Calls == [original-capture, original-capture]).

test(malformed_capture_is_refused_before_begin,
     [forall(member(Policy, [malformed, unqualified])),
      setup(fpc_setup(Policy)), cleanup(fpc_cleanup)]) :-
    catch(metta_transaction(metta_enlist_foreign('&fpc')), Error, true),
    ( Policy == malformed
    -> assertion(Error = error(domain_error(foreign_transaction_participant, wrong), _))
    ; assertion(Error = error(type_error(qualified_callable, true), _)) ),
    fpc_calls(Calls), assertion(Calls == [original-capture]).

test(failed_original_commit_never_calls_replacement,
     [forall(member(How, [throw, fail])),
      setup(fpc_setup(at(commit, How))), cleanup(fpc_cleanup)]) :-
    catch(metta_transaction((metta_enlist_foreign('&fpc'),
                             fpc_replace(replacement, none))), Error, true),
    assertion(nonvar(Error)),
    assertion(fpc_provider('&fpc', replacement, none)),
    fpc_calls(Calls),
    assertion(Calls == [original-capture, original-begin, original-commit]),
    metta_foreign_writes_lost('&another', Lost), assertion(Lost == ['&fpc']).

:- end_tests(foreign_participant_capture).
