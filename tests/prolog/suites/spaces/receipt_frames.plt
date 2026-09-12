% Purpose: prove receipt ownership and safe suspended-engine destruction.
% Guarantees: nested completion retains the outer owner and retires each scope
%   once, including failure and exception rollback [tested: spaces_receipt_frames;
%   commit=cdcb23421809ec3a493059a381e0245cf08a1984].
% Owns resources: fixtures destroy their engines and spaces, remove the scope
%   retirement wrapper, and close their event queues.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(prolog_wrap)).

:- begin_tests(spaces_receipt_frames).

:- meta_predicate with_events(1), nested_transactions(+, 0, +), rollback(+, 0),
                  outer_transaction(+, 0).

with_events(Goal) :-
    setup_call_cleanup(message_queue_create(Events),
        setup_call_cleanup(
            wrap_predicate(spaces:metta_receipt_forget_scope(Scope),
                           receipt_frames, Wrapped,
                           ( thread_send_message(Events, retired(Scope)),
                             call(Wrapped) )),
            call(Goal, Events),
            unwrap_predicate(spaces:metta_receipt_forget_scope/1,
                             receipt_frames)),
        message_queue_destroy(Events)).

reserve(Space, Scope) :-
    spaces:metta_with_occurrence_load((
        spaces:metta_receive_occurrences(Space, [[t,receipt_frames,1]], Stored),
        assertion(Stored == [[t,receipt_frames,1]]),
        nb_current('$metta_occurrence_transaction', _-scope(Scope, _)) )).

nested_transactions(0, Goal, _) :- !, call(Goal).
nested_transactions(Depth, Goal, Events) :-
    Next is Depth-1,
    transaction((nested_transactions(Next, Goal, Events),
                 assertion(message_queue_property(Events, size(0))))).

empty_receipts :-
    assertion(\+ spaces:metta_receipt_pending(_,_,_,_)),
    assertion(\+ spaces:metta_receipt_marker(_,_)),
    assertion(\+ spaces:metta_receipt_reserved(_)),
    assertion(\+ nb_current('$metta_occurrence_transaction', _)).

one_retirement(Events, Scope) :-
    assertion(message_queue_property(Events, size(1))),
    thread_get_message(Events, retired(Retired)),
    assertion(Retired == Scope),
    empty_receipts.

destroy_receipted_engine(Depth, Space, Events) :-
    setup_call_cleanup(
        engine_create(ready(Scope),
            ( nested_transactions(Depth, reserve(Space, Scope), Events),
              assertion(\+ nb_current('$metta_occurrence_transaction', _)),
              engine_yield(ready(Scope)) ), Engine),
        ( engine_next(Engine, ready(Owner)),
          assertion(message_queue_property(Events, size(1))) ),
        engine_destroy(Engine)),
    one_retirement(Events, Owner).

test(suspended_engine_with_completed_receipts,
     [forall(between(1, 4, Depth)), setup('new-space'(Space)),
      cleanup(metta_release_space(Space))]) :-
    with_events(destroy_receipted_engine(Depth, Space)).

rollback(fail, Goal) :- assertion(\+ transaction((call(Goal), fail))).
rollback(throw, Goal) :-
    catch(transaction((call(Goal), throw(receipt_frames))), receipt_frames, true).

inner_rollback(Mode, Space, Events) :-
    transaction((
        rollback(Mode, reserve(Space, _)),
        assertion(message_queue_property(Events, size(0))),
        nb_current('$metta_occurrence_transaction', _-scope(Scope, _)),
        reserve(Space, Again), assertion(Again == Scope),
        assertion(message_queue_property(Events, size(0))) )),
    one_retirement(Events, Scope).

test(inner_rollback_transfers_the_existing_owner,
     [forall(member(Mode, [fail,throw])), setup('new-space'(Space)),
      cleanup(metta_release_space(Space))]) :-
    with_events(destroy_rolled_back_engine(Mode, Space)).

destroy_rolled_back_engine(Mode, Space, Events) :-
    setup_call_cleanup(
        engine_create(ready,
            ( inner_rollback(Mode, Space, Events), engine_yield(ready) ), Engine),
        engine_next(Engine, ready),
        engine_destroy(Engine)),
    assertion(message_queue_property(Events, size(0))),
    empty_receipts.

test(original_query_shape) :-
    setup_call_cleanup(
        engine_create(ready,
            (transaction(spaces:metta_receipt_transaction_scope(_)),
             engine_yield(ready)), Engine),
        engine_next(Engine, ready),
        engine_destroy(Engine)).

outer_transaction(plain, Goal) :- transaction(Goal).
outer_transaction(options, Goal) :- transaction(Goal, []).
outer_transaction(constraint, Goal) :- transaction(Goal, true, receipt_frames).
outer_transaction(snapshot, Goal) :- snapshot(Goal).

native_owner(Mode, Space, Events) :-
    outer_transaction(Mode,
        ( transaction(reserve(Space, Scope)),
          nb_current('$metta_occurrence_transaction', _-scope(Owner, _)),
          assertion(Owner == Scope),
          assertion(message_queue_property(Events, size(0))) )),
    one_retirement(Events, Scope).

test(all_native_transaction_frames_keep_the_outer_owner,
     [forall(member(Mode, [plain,options,constraint,snapshot])),
      setup('new-space'(Space)), cleanup(metta_release_space(Space))]) :-
    with_events(native_owner(Mode, Space)).

:- end_tests(spaces_receipt_frames).
