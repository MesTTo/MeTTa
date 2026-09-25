% Purpose: verify native transaction and snapshot outcomes on the host this
%   tree runs on, through every assertion door, and the completion registry
%   the engine wraps around each transaction.
% Guarantees: later transactions cannot observe aborted assertions, including
%   one a nested transaction erased (host ledger,
%   swi-nested-retract-loses-outer-assert, patched), older rows survive
%   rollback, and completion registries remain local to their executing thread
%   [tested: host_transactions; commit=7ead07e090b85ad2b541fc271dd59b4d8faaf636].
% Guarantees: a clause reference held in a transactional table outlives its
%   clause whenever another thread commits the erase first, and try_erase/1 is
%   what releases it without failing the cleanup around it
%   [tested: host_transactions; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f].
% Guarantees: a mutex taken inside an open transaction or snapshot leaves that
%   view in place, so its holder still reads a row another thread erased under
%   the same mutex [tested 2026-09-25T19:33:07+10:00: host_transactions:a_mutex_taken_inside_a_transaction_keeps_its_view].
% Owns resources: each test removes its private rows; worker threads are joined.
:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- use_module('../../../../engine/host_transactions', []).
:- use_module(library(prolog_wrap), [unwrap_predicate/2]).

:- begin_tests(host_transactions).
:- dynamic row/1, clock/1, permanent/1, reference_row/1, guarded/1.
:- '$notransact'(permanent/1).

later_rows(Rows) :-
    transaction(( forall(between(1, 100, N), assertz(clock(N))),
                  findall(X, row(X), Rows) )),
    retractall(clock(_)).

test(an_outer_rollback_retires_every_assertion_door,
     [forall((member(Name, [assert, asserta, assertz]), member(Arity, [1,2]))),
      cleanup(retractall(row(_)))]) :-
    ( Arity == 1 -> Args = [row(aborted)] ; Args = [row(aborted), _] ),
    compound_name_arguments(Assert, Name, Args),
    \+ transaction(( call(Assert),
                     transaction(retract(row(aborted))), fail )),
    later_rows(Rows), assertion(Rows == []).

test(a_failed_child_stays_absent_when_its_parent_commits,
     [cleanup(retractall(row(_)))]) :-
    transaction(( assertz(row(parent)),
                  \+ transaction(( assertz(row(child), Child),
                                   transaction(erase(Child)), fail )),
                  later_rows(During), assertion(During == [parent]) )),
    later_rows(After), assertion(After == [parent]).

test(a_failed_child_stays_absent_when_its_parent_rolls_back,
     [cleanup(retractall(row(_)))]) :-
    \+ transaction(( assertz(row(parent)),
                     \+ transaction(( assertz(row(child), Child),
                                      transaction(erase(Child)), fail )), fail )),
    later_rows(Rows), assertion(Rows == []).

test(an_older_clause_keeps_its_identity,
     [setup(assertz(row(old), Ref)), cleanup(retractall(row(_)))]) :-
    \+ transaction((transaction(erase(Ref)), fail)),
    later_rows(Rows), assertion(Rows == [old]),
    findall(Actual, clause(row(old), true, Actual), Refs),
    assertion(Refs == [Ref]).

test(a_child_rollback_restores_an_outer_clause,
     [cleanup(retractall(row(_)))]) :-
    transaction(( assertz(row(parent), Ref),
                  \+ transaction((erase(Ref), fail)), row(parent) )),
    later_rows(Rows), assertion(Rows == [parent]).

test(a_snapshot_retires_nested_erased_assertions,
     [cleanup(retractall(row(_)))]) :-
    snapshot((assertz(row(speculated), Ref), transaction(erase(Ref)))),
    later_rows(Rows), assertion(Rows == []).

test(a_failed_commit_constraint_retires_its_assertions,
     [cleanup(retractall(row(_)))]) :-
    \+ transaction(assertz(row(constrained), Ref),
                   (transaction(erase(Ref)), fail), host_transaction_test),
    later_rows(Rows), assertion(Rows == []).

test(a_bound_reference_is_the_hosts_own_refusal,
     [setup(assertz(row(old), Ref)), cleanup(retractall(row(_)))]) :-
    catch(transaction(assertz(row(new), Ref)), error(Formal, _), true),
    assertion(Formal = uninstantiation_error(_)),
    later_rows(Rows), assertion(Rows == [old]).

test(an_attributed_reference_can_reject_the_assertion,
     [cleanup(retractall(row(_)))]) :-
    freeze(Ref, (transaction(erase(Ref)), throw(rejected_reference))),
    catch(transaction(assertz(row(rejected), Ref)), Error, true),
    assertion(Error == rejected_reference),
    later_rows(Rows), assertion(Rows == []).

test(a_nontransactional_predicate_keeps_its_host_semantics,
     [cleanup(retractall(permanent(_)))]) :-
    \+ transaction((assertz(permanent(kept)), fail)),
    assertion(permanent(kept)).

test(empty_savepoints_register_nothing) :-
    transaction(( forall(between(1, 1000, _), transaction(true)),
                  nb_getval('$metta_host_completions', Registry),
                  arg(1, Registry, Goals), assertion(Goals == []) )),
    nb_getval('$metta_host_completions', Owner), assertion(Owner == none).

rollback_goal :-
    transaction(( assertz(row(bounded), Ref), transaction(erase(Ref)), fail )).

test(an_inference_cut_at_each_port_leaves_no_clause_behind,
     [cleanup(retractall(row(_)))]) :-
    statistics(inferences, Before),
    ignore(rollback_goal),
    statistics(inferences, After),
    Last is After - Before + 1,
    forall(between(1, Last, Budget),
           ( ignore(call_with_inference_limit(rollback_goal, Budget, _)),
             later_rows(Rows), assertion(Rows == []),
             nb_getval('$metta_host_completions', Owner),
             assertion(Owner == none) )).

test(a_nested_engine_keeps_its_own_registry,
     [cleanup(retractall(row(_)))]) :-
    transaction(( assertz(row(parent)),
                  setup_call_cleanup(
                      engine_create(Inside,
                                    ( \+ rollback_goal, later_rows(Inside) ), Engine),
                      ( engine_next(Engine, ChildRows),
                        assertion(ChildRows == []) ),
                      engine_destroy(Engine)),
                  assertion(row(parent)) )),
    later_rows(Rows), assertion(Rows == [parent]).

test(concurrent_registries_keep_their_owners,
     [cleanup(retractall(row(_)))]) :-
    thread_create(transaction(assertz(row(committed))), Committer, []),
    thread_create(( \+ transaction(( assertz(row(aborted), Ref),
                                     transaction(erase(Ref)), fail )),
                    later_rows(_) ), Aborter, []),
    thread_join(Committer, CommitStatus),
    thread_join(Aborter, AbortStatus),
    assertion(CommitStatus == true), assertion(AbortStatus == true),
    later_rows(Rows), assertion(Rows == [committed]).

test(reinstalling_one_door_keeps_the_existing_primitive,
     [setup(nb_setval(host_completion_pending, false)),
      cleanup(nb_delete(host_completion_pending))]) :-
    setup_call_cleanup(
        unwrap_predicate(system:'$transaction'(_, _), metta_host_transaction_completion),
        ( host_transactions:install_host_transaction_completion,
          transaction(host_transactions:host_transaction_on_exit(nb_setval(host_completion_pending, true))),
          nb_getval(host_completion_pending, Pending), assertion(Pending == true) ),
        host_transactions:install_host_transaction_completion).

%A dynamic row is snapshot-isolated per thread and erase/1 is not isolated at
%all, so a thread whose transaction opened before another thread committed
%still SEES a row naming a clause that is already physically gone. That is the
%whole of host_transactions:try_erase/1's reason for existing, and the test
%pins both halves: the bare erase FAILS there, and try_erase/1 does not.
%The observer reports rather than asserts, so a failed expectation names which
%of the three observations moved instead of only failing the thread.
release_observer(In, Out) :-
    transaction(( thread_send_message(Out, opened),
                  thread_get_message(In, committed),
                  (   reference_row(Ref)
                  ->  ( erase(Ref) -> Bare = succeeded ; Bare = failed ),
                      ( host_transactions:try_erase(Ref)
                      -> Tolerant = succeeded ; Tolerant = failed ),
                      Report = report(visible, Bare, Tolerant)
                  ;   Report = report(gone, not_reached, not_reached) ) )),
    thread_send_message(Out, Report).

test(a_row_naming_a_clause_another_thread_erased_is_released_only_by_try_erase,
     [cleanup(( retractall(reference_row(_)), retractall(guarded(_)) ))]) :-
    assertz(guarded(installed), Ref),
    assertz(reference_row(Ref)),
    message_queue_create(ToObserver), message_queue_create(FromObserver),
    thread_create(release_observer(ToObserver, FromObserver), Observer, []),
    thread_get_message(FromObserver, opened),
    transaction(( retract(reference_row(_)), erase(Ref) )),
    thread_send_message(ToObserver, committed),
    thread_get_message(FromObserver, Report),
    thread_join(Observer, Status),
    message_queue_destroy(ToObserver), message_queue_destroy(FromObserver),
    assertion(Status == true),
    assertion(Report == report(visible, failed, succeeded)).

%A mutex does not refresh a view an open transaction already holds: a nested
%transaction/1 keeps the outermost one's start, so a reader that takes the
%mutex after the writer committed under it still sees the row, and its bare
%erase fails. With nothing open the same reader finds the row gone, which is
%the only case the mutex serializes. Holding a mutex is therefore no license
%for a bare erase over a table another path writes.
mutex_reader(Outer, In, Out) :-
    Read = ( thread_send_message(Out, opened),
             thread_get_message(In, committed),
             with_mutex(host_transactions_probe,
                 transaction(( reference_row(Ref)
                             -> ( erase(Ref) -> Bare = succeeded ; Bare = failed ),
                                ( host_transactions:try_erase(Ref)
                                -> Tolerant = succeeded ; Tolerant = failed ),
                                Report = report(visible, Bare, Tolerant)
                             ;  Report = report(gone, not_reached, not_reached) ))) ),
    ( Outer == none -> call(Read) ; call(Outer, Read) ),
    thread_send_message(Out, Report).

test(a_mutex_taken_inside_a_transaction_keeps_its_view,
     [forall(member(Outer-Expected,
                    [ none-report(gone, not_reached, not_reached),
                      transaction-report(visible, failed, succeeded),
                      snapshot-report(visible, failed, succeeded) ])),
      cleanup(( retractall(reference_row(_)), retractall(guarded(_)) ))]) :-
    assertz(guarded(installed), Ref),
    assertz(reference_row(Ref)),
    message_queue_create(ToReader), message_queue_create(FromReader),
    thread_create(mutex_reader(Outer, ToReader, FromReader), Reader, []),
    thread_get_message(FromReader, opened),
    with_mutex(host_transactions_probe,
               transaction(( retract(reference_row(_)), erase(Ref) ))),
    thread_send_message(ToReader, committed),
    thread_get_message(FromReader, Report),
    thread_join(Reader, Status),
    message_queue_destroy(ToReader), message_queue_destroy(FromReader),
    assertion(Status == true),
    assertion(Report == Expected).

%The other direction. try_erase/1 tolerates a lost race and nothing else, so a
%caller defect still reaches the caller; ignore/1 is what draws that line and
%catch(erase(R), _, true), which three sites used to spell, does not.
bad_reference(not_a_reference, type_error(db_reference, not_a_reference)).
bad_reference(7,               type_error(db_reference, 7)).
bad_reference(_,               instantiation_error).

test(try_erase_still_raises_on_an_argument_that_is_not_a_clause_reference,
     [forall(bad_reference(Bad, Expected))]) :-
    catch(host_transactions:try_erase(Bad), error(Raised, _), true),
    assertion(Raised == Expected).

:- end_tests(host_transactions).

:- begin_tests(host_transaction_completion).

completion_outcome(commit, Goal) :- transaction(Goal).
completion_outcome(rollback, Goal) :- \+ transaction((call(Goal), fail)).
completion_outcome(snapshot, Goal) :- snapshot(Goal).
completion_outcome(exception, Goal) :-
    catch(transaction((call(Goal), throw(completion_test))), completion_test, true).
completion_outcome(constraint, Goal) :-
    \+ transaction(Goal, fail, host_completion_test).

completion_note :-
    ( current_transaction(_) -> State = parent ; State = outside ),
    nb_getval(host_completion_results, Before),
    nb_setval(host_completion_results, [State|Before]).

test(completion_runs_after_every_native_outcome,
     [forall(member(Outcome, [commit,rollback,snapshot,exception,constraint])),
      setup(nb_setval(host_completion_results, [])),
      cleanup(nb_delete(host_completion_results))]) :-
    completion_outcome(Outcome,
        host_transactions:host_transaction_on_exit(
            plunit_host_transaction_completion:completion_note)),
    nb_getval(host_completion_results, Results),
    assertion(Results == [outside]).

test(completion_observes_the_surviving_parent,
     [forall(member(Outcome, [commit,rollback,snapshot,exception,constraint])),
      setup(nb_setval(host_completion_results, [])),
      cleanup(nb_delete(host_completion_results))]) :-
    transaction((
        completion_outcome(Outcome,
            host_transactions:host_transaction_on_exit(
                ( plunit_host_transaction_completion:completion_note,
                  host_transactions:host_transaction_on_exit(
                      plunit_host_transaction_completion:completion_note) ))),
        nb_getval(host_completion_results, During),
        assertion(During == [parent]))),
    nb_getval(host_completion_results, Results),
    assertion(Results == [outside,parent]).

test(registration_outside_a_transaction_is_refused,
     [throws(error(context_error(transaction), _))]) :-
    host_transactions:host_transaction_on_exit(true).

test(failed_reconciliation_is_loud,
     [throws(error(goal_failed(_), _))]) :-
    transaction(host_transactions:host_transaction_on_exit(fail)).

test(a_failed_reconciliation_does_not_skip_other_registered_goals,
     [setup(nb_setval(host_completion_results, [])),
      cleanup(nb_delete(host_completion_results))]) :-
    catch(transaction((
        host_transactions:host_transaction_on_exit(
            plunit_host_transaction_completion:completion_note),
        host_transactions:host_transaction_on_exit(fail))), Error, true),
    assertion(Error = error(goal_failed(_), _)),
    nb_getval(host_completion_results, Results), assertion(Results == [outside]).

test(reconciliation_keeps_the_hosts_exception_urgency) :-
    Urgent = error(resource_error(completion_witness), context(test, cleanup)),
    catch(transaction((
        host_transactions:host_transaction_on_exit(throw(Urgent)),
        host_transactions:host_transaction_on_exit(throw(ordinary_repair)))), Error, true),
    assertion(Error == Urgent).

test(the_original_native_outcome_survives_a_later_repair_error,
     [forall(member(Kind-Expected,
                    [commit-committed, rollback-failed, snapshot-discarded,
                     exception-threw(completion_test), constraint-failed])),
      setup(nb_setval(host_completion_results, [])),
      cleanup(nb_delete(host_completion_results))]) :-
    catch(completion_outcome(Kind,
        (host_transactions:host_transaction_on_exit(
             nb_setval(host_completion_results, [Original]), Original),
         host_transactions:host_transaction_on_exit(fail))), Error, true),
    % A body exception stays primary, so the exception row's helper consumes
    % it and the repair failure is not a second outward error.
    ( Kind == exception -> assertion(var(Error)) ; assertion(nonvar(Error)) ),
    nb_getval(host_completion_results, Results), assertion(Results == [Expected]).

completion_armed :-
    host_transactions:host_transaction_on_exit(
        nb_setval(host_completion_pending, false)),
    nb_setval(host_completion_pending, true).

test(an_inference_cut_cannot_skip_registered_completion,
     [cleanup(nb_delete(host_completion_pending))]) :-
    statistics(inferences, Before), transaction(completion_armed),
    statistics(inferences, After), Last is After-Before+1,
    forall(between(1, Last, Budget),
           ( nb_setval(host_completion_pending, false),
             ignore(call_with_inference_limit(transaction(completion_armed), Budget, _)),
             nb_getval(host_completion_pending, Pending), assertion(Pending == false) )).

:- end_tests(host_transaction_completion).
