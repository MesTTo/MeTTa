% Purpose: verify the repository workaround for nested host rollback.
% Guarantees: later transactions cannot observe aborted assertions, older
%   rows survive rollback, and journals remain local to their executing thread
%   [tested: host_transactions; commit=WORKTREE].
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

