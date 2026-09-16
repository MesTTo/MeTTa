% Purpose: verify the repository workaround for nested host rollback.
% Guarantees: later transactions cannot observe aborted assertions, older
%   rows survive rollback, and journals remain local to their executing thread
%   [tested: host_transactions; commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Owns resources: each test removes its private rows; worker threads are joined.
:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- use_module('../../../../engine/host_transactions', []).
:- use_module(library(prolog_wrap), [unwrap_predicate/2]).

:- begin_tests(host_transactions).
:- dynamic row/1, clock/1, permanent/1.
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

test(a_bound_reference_failure_is_still_owned,
     [setup(assertz(row(old), Ref)), cleanup(retractall(row(_)))]) :-
    \+ transaction(( \+ assertz(row(new), Ref),
                     transaction(retract(row(new))), fail )),
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

test(empty_savepoints_do_not_accumulate) :-
    transaction(( forall(between(1, 1000, _), transaction(true)),
                  nb_getval('$metta_host_assertions', Journal),
                  arg(1, Journal, Entries), assertion(Entries == []) )),
    nb_getval('$metta_host_assertions', Owner), assertion(Owner == none).

rollback_goal :-
    transaction(( assertz(row(bounded), Ref), transaction(erase(Ref)), fail )).

test(an_inference_cut_at_each_journal_port_retires_owned_clauses,
     [cleanup(retractall(row(_)))]) :-
    statistics(inferences, Before),
    ignore(rollback_goal),
    statistics(inferences, After),
    Last is After - Before + 1,
    forall(between(1, Last, Budget),
           ( ignore(call_with_inference_limit(rollback_goal, Budget, _)),
             later_rows(Rows), assertion(Rows == []),
             nb_getval('$metta_host_assertions', Owner),
             assertion(Owner == none) )).

test(a_nested_engine_keeps_its_own_journal,
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

test(concurrent_journals_keep_their_owners,
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
     [cleanup(retractall(row(_)))]) :-
    setup_call_cleanup(
        unwrap_predicate(system:assertz(_), metta_host_assertion_ownership),
        ( host_transactions:install_host_transaction_workaround,
          \+ transaction((assertz(row(reinstalled)),
                           transaction(retract(row(reinstalled))), fail)),
          later_rows(Rows), assertion(Rows == []) ),
        host_transactions:install_host_transaction_workaround).

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
