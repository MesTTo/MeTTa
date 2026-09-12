% Purpose: compare grouped retirement with the original per-reference loops.
% Guarantees: exact references, callback order, logical-update visibility,
%   failure prefixes and nested transaction receipts agree
%   [tested: source_retirement; commit=e246959279271d22f166a1c8fb1840896295a020].
% Owns resources: fixtures retire their clauses, listeners, queues and spaces.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(prolog_wrap)).

:- begin_tests(source_retirement).
:- dynamic artifact/1.

original_cleanup(Refs) :-
    forall(member(Ref, Refs), (catch(erase(Ref), _, true) -> true ; true)).
original_executable(Module, Refs) :-
    forall(member(Ref, Refs),
      ( filereader:translated_from(Ref, Term)
      -> filereader:forget_translated_from(Module, Ref, Term), erase(Ref)
      ; erase(Ref) )).
original_storage :-
    forall(clause(artifact(_), true, Ref), spaces:metta_erase_storage_ref(Ref)).

retirement(cleanup, original, Refs) :- original_cleanup(Refs).
retirement(cleanup, grouped, Refs) :- filereader:retire_source_artifacts(Refs).
retirement(executable, original, Refs) :- original_executable(user, Refs).
retirement(executable, grouped, Refs) :- filereader:retire_translated_clauses(user, Refs).
retirement(storage, original, _) :- original_storage.
retirement(storage, grouped, _) :-
    spaces:metta_retract_storage(plunit_source_retirement:artifact(_)).

fixture(Refs) :-
    findall(Ref, (member(Value, [a,b,b,c]), assertz(artifact(Value), Ref)), Refs).

receipt_indices(Refs, Indices) :-
    findall(Index,
            ( spaces:metta_receipt_erased(_, Ref), nth1(Index, Refs, Known),
              Known == Ref ), Indices).

callback(Scenario, Refs, Queue, Action, Ref) :-
    ( nth1(Index, Refs, Known), Known == Ref
    -> ( Action = rollback(_)
       -> Event = event(Action, Index)
       ; findall(Value, artifact(Value), Visible),
         receipt_indices(Refs, Receipts),
         Event = event(Action, Index, Visible, Receipts) ),
       thread_send_message(Queue, Event),
       callback_action(Scenario, Action, Index, Refs)
    ; true ).

% SWI discards a transaction's clause hash table in hash order. A rollback
% callback can therefore precede or follow disposal of its receipt row even
% across two unchanged runs. Retain every rollback event and check the final
% database; compare exact visible prefixes for forward callbacks.
% https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-transaction.c#L363-L415
callback_action(insert, retract, 1, _) :- !, assertz(artifact(later)).
callback_action(remove_later, retract, 1, [_,_,Ref|_]) :- !, erase(Ref).
callback_action(nested_rollback, retract, 1, [_,_,Ref|_]) :- !,
    \+ transaction((spaces:metta_erase_storage_ref(Ref), fail)).
callback_action(throwing, retract, 2, _) :- !, throw(retirement_callback_error).
callback_action(failing, retract, 2, _) :- !, fail.
callback_action(_, _, _, _).

drain(Queue, Events) :-
    ( thread_get_message(Queue, Event, [timeout(0)])
    -> Events = [Event|Rest], drain(Queue, Rest)
    ; Events = [] ).

case(Kind, Implementation, Scenario, Outcome-Visible-Receipts-Events) :-
    setup_call_cleanup(
        (fixture(Refs), message_queue_create(Queue)),
        setup_call_cleanup(
            prolog_listen(artifact/1, callback(Scenario, Refs, Queue)),
            ( catch(transaction(
                    ( ( retirement(Kind, Implementation, Refs)
                      -> Outcome = success ; Outcome = failure ),
                      receipt_indices(Refs, Receipts) )),
                    Error, (Outcome = raised(Error), Receipts = rolled_back)),
              findall(Value, artifact(Value), Visible), drain(Queue, Events),
              assertion(\+ nb_current('$metta_occurrence_transaction', _)),
              assertion(\+ spaces:metta_receipt_erased(_, _)) ),
            prolog_unlisten(artifact/1, callback(Scenario, Refs, Queue))),
        (retractall(artifact(_)), message_queue_destroy(Queue))).

test(callbacks_and_failure_prefixes_match,
     [forall((member(Kind, [cleanup, executable, storage]),
              member(Scenario, [plain, insert, remove_later, nested_rollback,
                                throwing, failing])))]) :-
    case(Kind, original, Scenario, Expected),
    case(Kind, grouped, Scenario, Actual),
    assertion(Actual == Expected).

test(cleanup_attempts_stale_and_duplicate_references) :-
    setup_call_cleanup(fixture([First,Second,Third,Fourth]),
      ( erase(Second),
        filereader:retire_source_artifacts([First,Second,First,Third,Fourth]),
        assertion(\+ artifact(_)) ),
      retractall(artifact(_))).

test(storage_keeps_pattern_variables_unbound_and_new_rows_outside_the_snapshot) :-
    case(storage, grouped, insert, success-[later]-[1,2,3,4]-_),
    setup_call_cleanup(fixture(_),
      (transaction(spaces:metta_retract_storage(plunit_source_retirement:artifact(Value))),
       assertion(var(Value)), assertion(\+ artifact(_))),
      retractall(artifact(_))).

test(empty_storage_does_not_open_a_receipt_scope) :-
    transaction(( spaces:metta_retract_storage(plunit_source_retirement:artifact(_)),
                  assertion(\+ nb_current('$metta_occurrence_transaction', _)) )).

test(outer_rollback_restores_the_whole_set) :-
    setup_call_cleanup(fixture(_),
      ( \+ transaction((spaces:metta_retract_storage(
                           plunit_source_retirement:artifact(_)), fail)),
        findall(Value, artifact(Value), Values),
        assertion(Values == [a,b,b,c]),
        assertion(\+ spaces:metta_receipt_erased(_, _)),
        assertion(\+ nb_current('$metta_occurrence_transaction', _)) ),
      retractall(artifact(_))).

scope_probe(Queue, Goal) :- thread_send_message(Queue, scope), call(Goal).

scope_reads(Implementation, Count) :-
    setup_call_cleanup((fixture(Refs), message_queue_create(Queue)),
      setup_call_cleanup(
        wrap_predicate(spaces:metta_receipt_transaction_scope(_), retirement_scope,
                       Call, scope_probe(Queue, Call)),
        ( transaction(retirement(storage, Implementation, Refs)),
          message_queue_property(Queue, size(Count)) ),
        unwrap_predicate(spaces:metta_receipt_transaction_scope/1, retirement_scope)),
      (retractall(artifact(_)), message_queue_destroy(Queue))).

test(the_owner_probe_runs_once_for_the_selected_set) :-
    scope_reads(original, Original), scope_reads(grouped, Grouped),
    assertion(Original == 4), assertion(Grouped == 1).

executable_source(Implementation, Remaining) :-
    setup_call_cleanup('new-space'(Space),
      ( filereader:metta_host_run_source(
          "(= (retirement-function $x) (+ $x 1))\n\c
           (= (retirement-function $x) (+ $x 2))\n!(retirement-function 1)",
          Space, [], _),
        space_module(Space, Module),
        findall(Ref, (filereader:translated_from(Ref,[=,['retirement-function'|_],_]),
                      clause_property(Ref,module(Module))), Refs),
        assertion(Refs = [_,_]),
        ( Implementation == original -> original_executable(Module, Refs)
        ; filereader:retire_translated_clauses(Module, Refs) ),
        findall(Term, (filereader:translated_from(Ref,Term),
                      memberchk(Ref,Refs)), Remaining),
        forall(member(Ref,Refs), assertion(\+ clause(Module:_,_,Ref))) ),
      metta_release_space(Space)).

test(executable_groups_retire_their_provenance) :-
    executable_source(original, Expected), executable_source(grouped, Actual),
    assertion(Actual == Expected), assertion(Actual == []).

:- end_tests(source_retirement).
