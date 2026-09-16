% Purpose: verify captured foreign outcomes and deferred native reconciliation.
% Assumes: participant capture, completion and the native transaction wrapper
%   are loaded through engine/metta.pl [source:
%   engine/metta/space_hooks.pl:metta_run_coordinator/4; commit=37d417bd059b4636f3fe603863a2e738e1f9aeda].
% Owns resources: fixture cleanup removes provider/native rows and restores the
%   observation wrapper. Callback logs are engine-local and survive rollback.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(prolog_wrap), [wrap_predicate/4, unwrap_predicate/2]).

:- dynamic fco_provider/4, fco_native/1.
:- multifile seam:foreign_participant/3, metta_engine:control_exception/1.

seam:foreign_participant(Space, Identity, Capture) :-
    clause(fco_provider(Space, Owner, Commit, Rollback), true, Identity),
    Capture = user:fco_capture(Owner, Commit, Rollback).

metta_engine:control_exception(fco_control).

fco_capture(Owner, Commit, Rollback,
            transaction(user:fco_note(Owner-begin),
                        user:fco_step(Owner-commit, Commit),
                        user:fco_step(Owner-rollback, Rollback))).

fco_step(Label, Goal) :- fco_note(Label), call(Goal).
fco_note(Label) :-
    nb_getval('$fco_calls', Calls), nb_linkval('$fco_calls', [Label|Calls]).
fco_calls(Calls) :- nb_getval('$fco_calls', Reversed), reverse(Reversed, Calls).

fco_setup :-
    fco_cleanup,
    assertz(fco_provider('&fco-original', original, user:true, user:true)).
fco_cleanup :-
    retractall(fco_provider(_, _, _, _)), retractall(fco_native(_)),
    nb_setval('$fco_calls', []),
    nb_setval('$metta_tx_foreign_outcome', foreign_completion(discard, [])),
    ( nb_current('$fco_participants', _) -> nb_delete('$fco_participants') ; true ).

fco_failure(fail, user:fail).
fco_failure(throw, user:throw(error(fco_refused, none))).

fco_mutate(keep).
fco_mutate(unregister) :- retractall(fco_provider('&fco-original', _, _, _)).
fco_mutate(replace) :-
    fco_mutate(unregister),
    assertz(fco_provider('&fco-original', replacement, user:true, user:true)).

% Registration and native-row edits go through these, defined here in user: a
% test body's own assertz runs in the unit's module and creates a local
% fco_provider/4 or fco_native/1 there, invisible to the seam clause and to
% fco_cleanup [measured 2026-09-16: 18 rollback cases saw no broken provider
% and the commit case of the native-outcome read answered absent].
fco_register(Space, Owner, Commit, Rollback) :-
    assertz(fco_provider(Space, Owner, Commit, Rollback)).
fco_mark(Value) :- assertz(fco_native(Value)).

fco_body(commit).
fco_body(fail) :- fail.
fco_body(throw) :- throw(error(fco_body, none)).

:- meta_predicate fco_run(+, 0, -), fco_host(+, 0).
fco_run(speculate, Goal, Result) :- !,
    catch((metta_speculate(Goal) -> Result = returned ; Result = failed),
          Error, Result = threw(Error)).
fco_run(_, Goal, Result) :-
    catch((metta_transaction(Goal) -> Result = returned ; Result = failed),
          Error, Result = threw(Error)).

fco_host(commit, Goal) :- transaction(Goal).
fco_host(fail, Goal) :- \+ transaction((call(Goal), fail)).
fco_host(throw, Goal) :-
    catch(transaction((call(Goal), throw(fco_native_abort))), fco_native_abort, true).
fco_host(snapshot, Goal) :- snapshot(Goal).

:- begin_tests(foreign_completion_results).

test(rollback_failure_attempts_every_original_and_retains_the_body_error,
     [forall((member(How, [fail,throw]), member(Mutation, [keep,unregister,replace]),
              member(Body, [fail,throw,speculate]))),
      setup(fco_setup), cleanup(fco_cleanup)]) :-
    fco_failure(How, Failure),
    fco_register('&fco-broken', broken, user:true, Failure),
    fco_run(Body,
        ( metta_enlist_foreign('&fco-original'), metta_enlist_foreign('&fco-broken'),
          fco_mutate(Mutation),
          ( Body == speculate -> true ; fco_body(Body) ) ), Result),
    assertion(Result = threw(_)),
    ( Body == throw -> assertion(Result = threw(error(fco_body, none))) ; true ),
    fco_calls(Calls),
    assertion(Calls == [original-begin, broken-begin, broken-rollback, original-rollback]),
    metta_foreign_completion(discard, Attempts),
    assertion(Attempts = [completed('&fco-broken', rollback, threw(_)),
                          completed('&fco-original', rollback, ok)]).

test(refusing_commit_and_failed_rollback_do_not_skip_later_participants,
     [forall((member(CommitHow, [fail,throw]), member(RollbackHow, [fail,throw]))),
      setup(fco_setup), cleanup(fco_cleanup)]) :-
    fco_failure(CommitHow, CommitFailure), fco_failure(RollbackHow, RollbackFailure),
    fco_register('&fco-rollback', rollback, user:true, RollbackFailure),
    fco_register('&fco-refuser', refuser, CommitFailure, user:true),
    fco_register('&fco-durable', durable, user:true, user:true),
    fco_run(commit,
        ( metta_enlist_foreign('&fco-original'), metta_enlist_foreign('&fco-rollback'),
          metta_enlist_foreign('&fco-refuser'), metta_enlist_foreign('&fco-durable'),
          fco_mutate(replace) ), Result),
    assertion(Result = threw(_)),
    fco_calls(Calls),
    assertion(Calls == [original-begin, rollback-begin, refuser-begin, durable-begin,
                        durable-commit, refuser-commit, rollback-rollback, original-rollback]),
    metta_foreign_completion(commit, Attempts),
    assertion(Attempts = [completed('&fco-durable', commit, ok),
                          completed('&fco-refuser', commit, threw(_)),
                          completed('&fco-rollback', rollback, threw(_)),
                          completed('&fco-original', rollback, ok)]),
    metta_foreign_writes_lost('&fco-durable', Lost),
    assertion(Lost == ['&fco-refuser','&fco-rollback','&fco-original']).

test(a_control_failure_is_not_masked_by_an_ordinary_body_error,
     [setup(fco_setup), cleanup(fco_cleanup)]) :-
    fco_register('&fco-control', control, user:true, user:throw(fco_control)),
    fco_run(throw,
        ( metta_enlist_foreign('&fco-original'), metta_enlist_foreign('&fco-control'),
          fco_body(throw) ), Result),
    assertion(Result == threw(fco_control)),
    fco_calls(Calls), assertion(member(original-rollback, Calls)).

test(a_provider_completion_can_start_a_transaction_without_replacing_its_parent,
     [setup(fco_setup), cleanup(fco_cleanup)]) :-
    fco_register('&fco-inner', inner, user:true, user:true),
    fco_register('&fco-outer', outer,
        user:metta_transaction((metta_enlist_foreign('&fco-inner'),
                                metta_after_foreign(inner, user:fco_note(inner-reconcile)))),
        user:true),
    metta_transaction((metta_enlist_foreign('&fco-original'),
                       metta_enlist_foreign('&fco-outer'),
                       metta_after_foreign(outer, user:fco_note(outer-reconcile)))),
    fco_calls(Calls),
    assertion(Calls == [original-begin, outer-begin, outer-commit,
                        inner-begin, inner-commit, inner-reconcile,
                        original-commit, outer-reconcile]),
    metta_foreign_completion(commit, Attempts),
    assertion(Attempts == [completed('&fco-outer', commit, ok),
                           completed('&fco-original', commit, ok)]).

test(a_speculative_rollback_callback_gets_its_own_user_transaction,
     [setup(fco_setup), cleanup(fco_cleanup)]) :-
    fco_register('&fco-inner', inner, user:true, user:true),
    fco_register('&fco-speculative', speculative, user:true,
        user:metta_transaction(metta_enlist_foreign('&fco-inner'))),
    metta_transaction((metta_enlist_foreign('&fco-original'),
                       metta_speculate(metta_enlist_foreign('&fco-speculative')),
                       fco_note(parent-resumed))),
    fco_calls(Calls),
    assertion(Calls == [original-begin, speculative-begin, speculative-rollback,
                        inner-begin, inner-commit, parent-resumed, original-commit]),
    metta_foreign_completion(commit, [completed('&fco-original', commit, ok)]).

test(a_successful_abort_keeps_ordinary_goal_failure,
     [setup(fco_setup), cleanup(fco_cleanup)]) :-
    fco_run(fail, (metta_enlist_foreign('&fco-original'), fail), Result),
    assertion(Result == failed),
    metta_foreign_completion(discard, [completed('&fco-original', rollback, ok)]).

test(a_completed_participant_is_not_called_again_by_completion_retry,
     [setup(fco_setup), cleanup(fco_cleanup)]) :-
    metta_transaction((metta_enlist_foreign('&fco-original'),
                       nb_getval('$metta_completion_context', Context),
                       arg(2, Context, enlisted(Participants)),
                       nb_linkval('$fco_participants', Participants))),
    nb_getval('$fco_participants', Retained),
    metta_finish_foreign(committed, Retained, Result),
    assertion(Result == ok),
    fco_calls(Calls), assertion(Calls == [original-begin,original-commit]).

:- end_tests(foreign_completion_results).

:- begin_tests(transaction_completion).

test(native_completion_transfers_to_its_outermost_transaction,
     [forall(member(Outcome, [commit,fail,throw,snapshot])),
      setup(fco_setup), cleanup(fco_cleanup)]) :-
    fco_host(Outcome,
        ( transaction(metta_after_foreign(native, user:fco_note(completed))),
          fco_calls(During), assertion(During == []) )),
    fco_calls(After), assertion(After == [completed]).

test(reconciliation_reads_the_standing_native_outcome,
     [forall(member(Outcome, [commit,fail,throw,snapshot])),
      setup(fco_setup), cleanup(fco_cleanup)]) :-
    fco_host(Outcome,
        ( fco_mark(changed),
          metta_after_foreign(native,
              (user:fco_native(changed) -> user:fco_note(present)
              ; user:fco_note(absent))) )),
    fco_calls(After),
    ( Outcome == commit -> assertion(After == [present])
    ; assertion(After == [absent]) ).

test(foreign_then_reconciliation_then_observation,
     [setup(fco_setup), cleanup(fco_cleanup)]) :-
    setup_call_cleanup(
        wrap_predicate(seam:observation_commit, fco_order, Original,
                       (user:fco_note(observation), call(Original))),
        metta_transaction((metta_enlist_foreign('&fco-original'),
                           metta_after_foreign(field, user:fco_note(reconciliation)),
                           fco_calls(During), assertion(During == [original-begin]))),
        unwrap_predicate(seam:observation_commit, fco_order)),
    fco_calls(Calls),
    assertion(Calls == [original-begin, original-commit, reconciliation, observation]).

test(a_failed_callback_does_not_skip_another_or_replay_on_native_cleanup_retry,
     [forall(member(How, [fail,throw])), setup(fco_setup), cleanup(fco_cleanup)]) :-
    fco_failure(How, Failure),
    catch(transaction((
        metta_after_foreign(last, user:fco_note(last)),
        metta_after_foreign(broken, user:fco_step(broken, Failure)))), Error, true),
    assertion(nonvar(Error)),
    fco_calls(Calls), assertion(Calls == [broken,last]).

test(an_explicit_retry_is_a_new_attempt,
     [setup(fco_setup), cleanup(fco_cleanup)]) :-
    catch(metta_after_foreign(retry, user:fco_step(first, user:fail)), Error, true),
    assertion(nonvar(Error)),
    metta_after_foreign(retry, user:fco_note(second)),
    fco_calls(Calls), assertion(Calls == [first,second]).

test(reconciliation_failure_keeps_native_commit_and_observation,
     [setup(fco_setup), cleanup(fco_cleanup)]) :-
    setup_call_cleanup(
        wrap_predicate(seam:observation_commit, fco_order, Original,
                       (user:fco_note(observation), call(Original))),
        fco_run(commit,
            ( fco_mark(committed),
              metta_after_foreign(broken, user:fco_step(reconciliation, user:fail)) ), Result),
        unwrap_predicate(seam:observation_commit, fco_order)),
    assertion(Result = threw(error(metta_completion_failed(broken), _))),
    assertion(fco_native(committed)),
    fco_calls(Calls), assertion(Calls == [reconciliation,observation]).

test(notification_failure_finishes_participants_and_queued_work,
     [setup(fco_setup), cleanup(fco_cleanup)]) :-
    catch(metta_transaction_notified(
        (metta_enlist_foreign('&fco-original'),
         metta_after_foreign(queued, user:fco_note(reconciliation))),
        throw(error(fco_notification, none)), true), Error, true),
    assertion(Error == error(fco_notification, none)),
    fco_calls(Calls),
    assertion(Calls == [original-begin, original-commit, reconciliation]).

test(native_repair_failure_keeps_the_durable_decision_and_original_participant,
     [forall(member(How, [fail,throw])), setup(fco_setup), cleanup(fco_cleanup)]) :-
    fco_failure(How, Repair),
    catch(metta_transaction_notified(
        (fco_mark(committed), metta_enlist_foreign('&fco-original'),
         fco_mutate(replace), host_transactions:host_transaction_on_exit(Repair),
         metta_after_foreign(queued, user:fco_note(reconciliation))),
        fco_note(notified-commit), fco_note(notified-rollback)), Error, true),
    assertion(nonvar(Error)), assertion(fco_native(committed)),
    fco_calls(Calls),
    assertion(Calls == [original-begin, notified-commit, original-commit, reconciliation]),
    metta_foreign_completion(commit, [completed('&fco-original', commit, ok)]).

test(a_native_repair_error_cannot_replace_the_original_body_exception,
     [setup(fco_setup), cleanup(fco_cleanup)]) :-
    catch(metta_transaction_notified(
        (fco_mark(aborted), metta_enlist_foreign('&fco-original'),
         host_transactions:host_transaction_on_exit(fail), fco_body(throw)),
        fco_note(notified-commit), fco_note(notified-rollback)), Error, true),
    assertion(Error == error(fco_body, none)), assertion(\+ fco_native(aborted)),
    fco_calls(Calls),
    assertion(Calls == [original-begin, notified-rollback, original-rollback]),
    metta_foreign_completion(discard, [completed('&fco-original', rollback, ok)]).

test(scheduling_during_completion_is_consumed_before_the_context_leaves,
     [setup(fco_setup), cleanup(fco_cleanup)]) :-
    metta_transaction(metta_after_foreign(first,
        (user:fco_note(first), metta_after_foreign(second, user:fco_note(second))))),
    fco_calls(Calls), assertion(Calls == [first,second]),
    assertion(\+ (nb_current('$metta_completion_context', Context), Context \== [])).

completion_cut_body :-
    metta_enlist_foreign('&fco-original'), fco_note(enlisted),
    metta_after_foreign(cut, user:fco_note(reconcile)).

completion_cut_goal(plain) :- metta_transaction(completion_cut_body).
completion_cut_goal(nested) :- metta_transaction(metta_transaction(completion_cut_body)).

test(inference_cuts_retain_attempts_without_replaying_callbacks,
     [forall(member(Form, [plain,nested])), setup(fco_setup), cleanup(fco_cleanup)]) :-
    seam:observation_frames(FramesBefore),
    statistics(inferences, Before), completion_cut_goal(Form),
    statistics(inferences, After), Last is After-Before+1,
    forall(between(1, Last, Budget),
        ( fco_setup,
          catch(ignore(call_with_inference_limit(completion_cut_goal(Form), Budget, _)),
                Error, assertion(control_exception(Error))),
          fco_calls(Calls),
          findall(Verb, (member(original-Verb, Calls), memberchk(Verb, [commit,rollback])), Verbs),
          length(Verbs, Count), assertion(Count =< 1),
          findall(reconcile, member(reconcile, Calls), Reconciliations),
          length(Reconciliations, Reconciled), assertion(Reconciled =< 1),
          ( memberchk(enlisted, Calls)
          -> metta_foreign_completion(_, Attempts),
             assertion(Attempts = [completed('&fco-original', _, _)])
          ; true ),
          assertion(\+ (nb_current('$metta_completion_context', Context), Context \== [])),
          seam:observation_frames(FramesAfter), assertion(FramesAfter == FramesBefore) )).

:- end_tests(transaction_completion).
