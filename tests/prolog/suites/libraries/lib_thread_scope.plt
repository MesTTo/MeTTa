% Purpose: verify lib_thread's lifetime tree through native entry points.
% Guarantees: native deferred cleanup follows scope transfer and rollback,
%   reports every failure and can retry a failed close
%   [tested: lib_thread_scope_deferred; commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Guarantees: native dependency queries follow explicit roots after joins,
%   preserve cycles and retry errors [tested: lib_thread_scope_deferred;
%   commit=WORKTREE].
% Guarantees: normal exit joins children, failure stops siblings, return
% transfers spaces and escaped names refuse [tested: lib_thread_scope;
% commit=c6e1198c490a824b96f6fc6e1c0622a542917024].
% Owns resources: each case closes its scope, drops returned spaces and
% destroys its queues, including exceptional exits.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- initialization(sc_scope_setup).

sc_scope_setup :-
    process_metta_string("!(import! &self (library lib_thread))", _),
    import_prolog_functions(['sc-scope-done', 'sc-scope-loop', 'sc-scope-error',
                             'sc-scope-unlocked'], _).

'sc-scope-done'(Queue, N, N) :- sleep(0.01), thread_send_message(Queue, done(N)).
'sc-scope-loop'(Queue, never) :-
    setup_call_cleanup(true,
        ( thread_send_message(Queue, ready), sc_scope_spin ),
        thread_send_message(Queue, cleaned)).
sc_scope_spin :- sc_scope_spin.
'sc-scope-error'(_) :- throw(error(scope_test_failure, context(test, child))).
'sc-scope-unlocked'(Value, Value) :- mutex_property('$metta_scopes', status(unlocked)).

sc_scope_spawn(Queue, N, Future) :- thread_spawn(['sc-scope-done', Queue, N], Future).
sc_scope_cleanup(Id, Owner, Queue) :-
    ( lib_thread:scope_state_(Id, _, _, _, _)
    -> scope_close(Id, Owner, failure, _) ; true ),
    message_queue_destroy(Queue).

:- begin_tests(lib_thread_scope).

test(exit_joins_three_children_and_retires_their_spaces,
     [ setup((message_queue_create(Q), thread_self(Owner),
              scope_open(none, Owner, infinite, Id))),
       cleanup(sc_scope_cleanup(Id, Owner, Q)) ]) :-
    scope_call(Id, maplist(sc_scope_spawn(Q), [1,2,3], Futures)),
    scope_close(Id, Owner, success, Report),
    assertion(Report == [none, [], true]),
    maplist(sc_scope_result(Q), [A,B,C]), Done = [A,B,C],
    msort(Done, Sorted), assertion(Sorted == [1,2,3]),
    forall(member(F, Futures),
           ( assertion(\+ lib_thread:metta_future(F, _, _)),
             assertion(scope_space_dead(F)) )).

test(a_child_failure_stops_running_siblings_and_runs_cleanup,
     [ setup((message_queue_create(Q), thread_self(Owner),
              scope_open(none, Owner, infinite, Id))),
       cleanup(sc_scope_cleanup(Id, Owner, Q)) ]) :-
    scope_call(Id, thread_spawn(['sc-scope-loop', Q], _)),
    scope_call(Id, thread_spawn(['sc-scope-loop', Q], _)),
    thread_get_message(Q, ready), thread_get_message(Q, ready),
    catch(scope_call(Id, thread_spawn(['sc-scope-error'], _)),
          error(metta_control_signal(interrupted, [scope, Id]), _), true),
    get_time(Start), scope_close(Id, Owner, success, Report), get_time(End),
    Report = [child_failure, [[prolog, Message]], true],
    once(sub_string(Message, _, _, _, "scope_test_failure")),
    thread_get_message(Q, cleaned), thread_get_message(Q, cleaned),
    Milliseconds is (End-Start)*1000,
    format(user_error, 'scope sibling cancellation: ~3f ms~n', [Milliseconds]).

test(the_public_scope_preserves_duplicate_alternatives) :-
    findall(Value, scope_body([superpose, [1,1,2]], Value), Values),
    assertion(Values == [1,1,2]).

test(a_child_error_retains_its_original_exception_term,
     [ cleanup((nonvar(Future) -> metta_release_space(Future) ; true)),
       throws(error(scope_test_failure, context(test, child))) ]) :-
    thread_spawn(['sc-scope-error'], Future),
    thread_await(Future, _).

test(a_returned_space_survives_and_can_be_released,
     [ cleanup((nonvar(Space) -> metta_release_space(Space) ; true)) ]) :-
    scope_body(['new-space'], Space),
    'add-atom'(Space, [retained, yes], _),
    findall(A, 'get-atoms'(Space, A), Atoms),
    assertion(Atoms == [[retained, yes]]).

test(a_raw_leaked_name_refuses_a_read,
     [ throws(error(permission_error(access, released_scope_space, _), _)) ]) :-
    thread_self(Owner), scope_open(none, Owner, infinite, Id),
    scope_call(Id, 'new-space'(Space)),
    scope_close(Id, Owner, success, _),
    'get-atoms'(Space, _).

test(a_scope_refuses_to_open_in_a_transaction,
     [ throws(error(permission_error(start, scope_in_transaction, _), _)) ]) :-
    transaction(scope_open(none, owner, infinite, _)).

test(cancellation_during_allocation_keeps_the_new_space_owned,
     [ cleanup((scope_space_dead('&sc-cancelled-allocation') -> true
                ; metta_release_space('&sc-cancelled-allocation'))) ]) :-
    thread_self(Owner), scope_open(none, Owner, infinite, Id),
    catch(scope_call(Id, sig_atomic((
              scope_cancel(Id, cancelled),
              ensure_native_storage_module('&sc-cancelled-allocation', _) ))),
          error(metta_control_signal(interrupted, [scope, Id]), _), true),
    scope_close(Id, Owner, success, [cancelled, [], true]),
    assertion(scope_space_dead('&sc-cancelled-allocation')).

test(a_returned_future_transfers_the_spaces_in_its_answers,
     [ cleanup(((nonvar(Child) -> metta_release_space(Child) ; true),
                (nonvar(Future) -> metta_release_space(Future) ; true))) ]) :-
    thread_self(Owner), scope_open(none, Owner, infinite, Id),
    scope_call(Id, thread_spawn(['new-space'], Future)),
    scope_keep(Id, Owner, Future),
    scope_close(Id, Owner, success, [none, [], true]),
    findall(S, thread_await(Future, S), [Child]),
    'add-atom'(Child, retained, _),
    findall(A, 'get-atoms'(Child, A), [retained]).

test(returning_an_heir_transfers_its_owned_parent,
     [ cleanup((metta_release_space('&sc-kept-child'),
                metta_release_space('&sc-kept-parent'))) ]) :-
    thread_self(Owner), scope_open(none, Owner, infinite, Id),
    scope_call(Id,
        ( ensure_native_storage_module('&sc-kept-parent', _),
          'new-space'('&sc-kept-child', [inherits, '&sc-kept-parent'], _) )),
    scope_keep(Id, Owner, '&sc-kept-child'),
    scope_close(Id, Owner, success, [none, [], true]),
    'add-atom'('&sc-kept-parent', retained, _),
    findall(A, 'get-atoms'('&sc-kept-child', A), [retained]).

test(capture_retains_the_evaluation_space,
     [ cleanup((metta_release_space('&sc-capture-left'),
                metta_release_space('&sc-capture-right'))) ]) :-
    Left = '&sc-capture-left', Right = '&sc-capture-right',
    'import!'(Left, [library, lib_thread], _),
    'import!'(Right, [library, lib_thread], _),
    'add-atom'(Left, ['=', ['sc-captured-value'], left], _),
    'add-atom'(Right, ['=', ['sc-captured-value'], right], _),
    space_module(Left, LM), space_module(Right, RM),
    findall(C, eval_metta_in_module(LM, [capture, ['sc-captured-value']], C), [Captured]),
    assertion(Captured == [evalc, ['sc-captured-value'], Left]),
    findall(Answer, eval_metta_in_module(RM, Captured, Answer), Answers),
    assertion(Answers == [left]).

:- end_tests(lib_thread_scope).

sc_scope_result(Q, N) :- thread_get_message(Q, done(N), [timeout(0)]).

:- begin_tests(lib_thread_scope_deferred).

deferred_setup(Space, Owner, Id) :-
    'new-space'(Space), thread_self(Owner), scope_open(none, Owner, infinite, Id).
deferred_cleanup(Space, Owner, Id) :-
    ( lib_thread:scope_state_(Id, _, _, _, _)
    -> scope_close(Id, Owner, failure, _) ; true ),
    metta_release_space(Space).

test(native_cleanups_run_in_reverse_acquisition_order,
     [setup(deferred_setup(Space, Owner, Id)),
      cleanup(deferred_cleanup(Space, Owner, Id))]) :-
    scope_call(Id,
        ( scope_defer([entity,1], ['add-atom',Space,[released,1]], true),
          scope_defer([entity,2], ['add-atom',Space,[released,2]], true) )),
    scope_close(Id, Owner, success, Report),
    assertion(Report == [none,[],true]),
    findall(Row, 'get-atoms'(Space, Row), Rows),
    assertion(Rows == [[released,2],[released,1]]).

test(a_kept_value_transfers_its_cleanup_to_the_parent,
     [setup(deferred_setup(Space, Owner, Outer)),
      cleanup(deferred_cleanup(Space, Owner, Outer))]) :-
    scope_open(Outer, Owner, infinite, Inner),
    scope_call(Inner, scope_defer([entity,1], ['add-atom',Space,[released,1]], true)),
    scope_keep(Inner, Owner, [answer,[entity,1]]),
    scope_close(Inner, Owner, success, [none,[],true]),
    assertion(\+ 'get-atoms'(Space, _)),
    scope_close(Outer, Owner, success, [none,[],true]),
    findall(Row, 'get-atoms'(Space, Row), Rows), assertion(Rows == [[released,1]]).

test(a_kept_root_value_releases_its_scope_descriptor,
     [setup(deferred_setup(Space, Owner, Id)),
      cleanup(deferred_cleanup(Space, Owner, Id))]) :-
    scope_call(Id, scope_defer([entity,1], ['add-atom',Space,[released,1]], true)),
    recorded(Id, child(deferred, Token), _),
    scope_keep(Id, Owner, [entity,1]),
    scope_close(Id, Owner, success, [none,[],true]),
    assertion(\+ lib_thread:scope_deferred_(Token, _, _, _, _, _)),
    assertion(\+ 'get-atoms'(Space, _)).

test(a_kept_cleanup_retains_its_captured_space_and_reference_provider,
     [setup(deferred_setup(Log, Owner, Outer)),
      cleanup(deferred_cleanup(Log, Owner, Outer))]) :-
    scope_open(Outer, Owner, infinite, Inner),
    scope_call(Inner,
        ( 'new-space'(Provider), 'new-space'(Consumer),
          'add-atom'(Provider, ['=', ['sc-deferred-mark'], done], _),
          'add-atom'(Consumer, [from,Provider], _),
          scope_defer([entity,1], [let,Mark,[evalc,['sc-deferred-mark'],Consumer],
                                  ['add-atom',Log,[released,Mark]]], true) )),
    scope_keep(Inner, Owner, [entity,1]),
    scope_close(Inner, Owner, success, [none,[],true]),
    assertion(\+ scope_space_dead(Provider)),
    assertion(\+ scope_space_dead(Consumer)),
    scope_close(Outer, Owner, success, Report),
    assertion(Report == [none,[],true]),
    findall(Row, 'get-atoms'(Log, Row), Rows), assertion(Rows == [[released,done]]),
    assertion(scope_space_dead(Provider)),
    assertion(scope_space_dead(Consumer)).

test(a_nested_transfer_preserves_cleanup_acquisition_order,
     [setup(deferred_setup(Log, Owner, Outer)),
      cleanup(deferred_cleanup(Log, Owner, Outer))]) :-
    scope_open(Outer, Owner, infinite, Inner),
    scope_call(Inner,
        ( scope_defer([entity,1], ['add-atom',Log,[released,1]], true),
          scope_defer([entity,2], ['add-atom',Log,[released,2]], true) )),
    scope_keep(Inner, Owner, [[entity,1],[entity,2]]),
    scope_close(Inner, Owner, success, [none,[],true]),
    scope_close(Outer, Owner, success, [none,[],true]),
    findall(Row, 'get-atoms'(Log, Row), Rows),
    assertion(Rows == [[released,2],[released,1]]).

test(a_rolled_back_descriptor_has_no_cleanup_left_to_run,
     [setup(deferred_setup(Space, Owner, Id)),
      cleanup(deferred_cleanup(Space, Owner, Id))]) :-
    scope_call(Id, snapshot(scope_defer([entity,1], ['add-atom',Space,[released,1]], true))),
    scope_close(Id, Owner, success, [none,[],true]),
    assertion(\+ 'get-atoms'(Space, _)).

test(failure_does_not_transfer_a_kept_value,
     [setup(deferred_setup(Space, Owner, Id)),
      cleanup(deferred_cleanup(Space, Owner, Id))]) :-
    scope_call(Id, scope_defer([entity,1], ['add-atom',Space,[released,1]], true)),
    scope_keep(Id, Owner, [entity,1]),
    scope_close(Id, Owner, failure, [body_failure,[],true]),
    findall(Row, 'get-atoms'(Space, Row), Rows), assertion(Rows == [[released,1]]).

test(explicit_space_retirement_is_safe_in_a_cleanup_snapshot,
     [setup(deferred_setup(Log, Owner, Id)),
      cleanup(deferred_cleanup(Log, Owner, Id))]) :-
    scope_call(Id,
        ( 'new-space'(Private),
          scope_defer([agent,Private], ['drop-space',Private], true) )),
    scope_close(Id, Owner, success, [none,[],true]),
    assertion(scope_space_dead(Private)).

test(a_failed_cleanup_is_retained_for_retry_and_siblings_still_run,
     [setup(deferred_setup(Space, Owner, Id)),
      cleanup(deferred_cleanup(Space, Owner, Id))]) :-
    scope_call(Id,
        ( scope_defer([entity,1], ['add-atom',Space,[released,1]], true),
          scope_defer([entity,2], [throw, ['Error',cleanup,retry]], true) )),
    scope_close(Id, Owner, success, [none, Errors, false]),
    assertion(Errors = [[prolog,_]]),
    findall(Row, 'get-atoms'(Space, Row), Rows), assertion(Rows == [[released,1]]),
    retract(lib_thread:scope_deferred_(Token, Id, [entity,2], Module, _, Dependencies)),
    assertz(lib_thread:scope_deferred_(Token, Id, [entity,2], Module, true, Dependencies)),
    scope_close(Id, Owner, success, [none,[],true]),
    findall(Row, 'get-atoms'(Space, Row), After), assertion(After == Rows).

test(equal_deferred_keys_in_unrelated_scopes_do_not_share_dependencies,
     [setup((deferred_setup(Log, Owner, Left),
             scope_open(none, Owner, infinite, Right))),
      cleanup((scope_close(Right, Owner, failure, _),
               deferred_cleanup(Log, Owner, Left)))]) :-
    scope_call(Left, scope_defer([shared,value], true, true)),
    scope_call(Right, lib_thread:scope_defer([shared,value], true,
        [throw,['Error',dependencies,unrelated_scope]], true)),
    scope_keep(Left, Owner, [shared,value]),
    scope_close(Left, Owner, success, [none,[],true]),
    assertion(lib_thread:scope_state_(Right, none, Owner, open, none)).

test(current_dependencies_follow_cycles_and_preserve_only_explicit_old_roots,
     [forall(member(KeepOld, [true, false])),
      setup(deferred_setup(Log, Owner, Outer)),
      cleanup(deferred_cleanup(Log, Owner, Outer))]) :-
    scope_open(Outer, Owner, infinite, Inner),
    scope_call(Inner,
        ( 'new-space'(Old), 'new-space'(New), 'new-space'(Other),
          'add-atom'(Log, [edge,[node,a],Old], _),
          'add-atom'(Log, [edge,[node,b],[node,a]], _),
          'add-atom'(Log, [edge,[node,b],New], _),
          'add-atom'(Log, [edge,[node,c],Other], _),
          forall(member(Node, [a,b,c]),
                 lib_thread:scope_defer([node,Node], ['add-atom',Log,[released,Node]],
                     [match,Log,[edge,[node,Node],Child],Child], true)) )),
    scope_keep(Inner, Owner, [node,a]),
    ( KeepOld == true -> scope_keep(Inner, Owner, Old) ; true ),
    'remove-atom'(Log, [edge,[node,a],Old], _),
    'add-atom'(Log, [edge,[node,a],[node,b]], _),
    scope_close(Inner, Owner, success, [none,[],true]),
    assertion(\+ scope_space_dead(New)),
    assertion(scope_space_dead(Other)),
    ( KeepOld == true -> assertion(\+ scope_space_dead(Old))
    ; assertion(scope_space_dead(Old)) ),
    findall(Node, 'get-atoms'(Log, [released,Node]), Released),
    assertion(Released == [c]),
    scope_close(Outer, Owner, success, [none,[],true]),
    assertion(scope_space_dead(New)),
    assertion(scope_space_dead(Old)).

test(dependency_queries_run_outside_the_scope_mutex,
     [setup(deferred_setup(Log, Owner, Outer)),
      cleanup(deferred_cleanup(Log, Owner, Outer))]) :-
    scope_open(Outer, Owner, infinite, Inner),
    scope_call(Inner,
        ( 'new-space'(Child),
          lib_thread:scope_defer([node,unlocked], true,
                                  ['sc-scope-unlocked',Child], true) )),
    scope_keep(Inner, Owner, [node,unlocked]),
    scope_close(Inner, Owner, success, [none,[],true]),
    assertion(\+ scope_space_dead(Child)),
    scope_close(Outer, Owner, success, [none,[],true]),
    assertion(scope_space_dead(Child)).

test(a_kept_future_follows_deferred_values_in_its_completed_answers,
     [setup(deferred_setup(Log, Owner, Outer)),
      cleanup(deferred_cleanup(Log, Owner, Outer))]) :-
    scope_open(Outer, Owner, infinite, Inner),
    scope_call(Inner,
        ( 'new-space'(Child),
          lib_thread:scope_defer([node,answer], true, [noeval,Child], true),
          thread_spawn([noeval,[node,answer]], Future) )),
    scope_keep(Inner, Owner, Future),
    scope_close(Inner, Owner, success, [none,[],true]),
    assertion(\+ scope_space_dead(Child)),
    findall(Value, thread_await(Future, Value), Values),
    assertion(Values == [[node,answer]]),
    scope_close(Outer, Owner, success, [none,[],true]),
    assertion(scope_space_dead(Child)).

test(rolled_back_dependency_descriptors_do_not_run,
     [setup(deferred_setup(Log, Owner, Id)),
      cleanup(deferred_cleanup(Log, Owner, Id))]) :-
    scope_call(Id, snapshot(lib_thread:scope_defer([node,rolled_back],
        ['add-atom',Log,[released,unexpected]], [throw,['Error',dependencies,rolled_back]], true))),
    scope_keep(Id, Owner, [node,rolled_back]),
    scope_close(Id, Owner, success, [none,[],true]),
    assertion(\+ 'get-atoms'(Log, _)).

test(a_dependency_error_preserves_resources_for_retry_or_failed_close,
     [forall(member(Next, [retry, failed_close])),
      setup(deferred_setup(Log, Owner, Id)),
      cleanup((deferred_cleanup(Log, Owner, Id),
               (nonvar(Child) -> metta_release_space(Child) ; true)))]) :-
    Bad = ['=', ['sc-current-dependency'], ['Error',dependencies,retry]],
    'add-atom'(Log, Bad, _),
    scope_call(Id,
        ( 'new-space'(Child),
          lib_thread:scope_defer([node,retry], ['add-atom',Log,[released,yes]],
              [evalc,['sc-current-dependency'],Log], true) )),
    scope_keep(Id, Owner, [node,retry]),
    scope_close(Id, Owner, success, [none,Errors,false]),
    assertion(Errors = [[prolog,_]]),
    assertion(\+ scope_space_dead(Child)),
    assertion(\+ 'get-atoms'(Log, [released,_])),
    ( Next == retry
    -> 'remove-atom'(Log, Bad, _),
       'add-atom'(Log, ['=', ['sc-current-dependency'], [noeval,Child]], _),
       scope_close(Id, Owner, success, [none,[],true]),
       assertion(\+ scope_space_dead(Child)),
       assertion(\+ 'get-atoms'(Log, [released,_]))
    ; scope_close(Id, Owner, failure, [body_failure,[],true]),
      assertion(scope_space_dead(Child)),
      assertion('get-atoms'(Log, [released,yes])) ).

:- end_tests(lib_thread_scope_deferred).
