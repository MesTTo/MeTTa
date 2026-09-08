% Purpose: verify transaction-owned host cursors and the seats that hold them.
% Guarantees: engine laziness, held-row ownership, commit and rollback lifetime,
%   occurrence order, capture and idempotent close are executable
%   contracts [tested: host_hold; commit=ea2c1bde39a7b002b1e5948cf6c53bc469dac084].
% Owns resources: each test closes its handles and joins every thread it starts.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- ensure_loaded('../../../../extensions/python/metta/shim.pl').
:- ensure_loaded('../../../../extensions/node/bridge.pl').

:- begin_tests(host_hold).
:- dynamic written/1.
:- meta_predicate in_other_thread(0, -).

in_other_thread(Goal, Result) :-
    thread_create(
        ( catch((call(Goal) -> Outcome = answered ; Outcome = failed),
                Error, Outcome = error(Error)),
          thread_exit(Outcome) ), Thread, []),
    thread_join(Thread, exited(Result)).

test(outside_is_a_lazy_engine, [cleanup(retractall(written(_)))]) :-
    setup_call_cleanup(
        metta_host_hold(X, (member(X, [a,a,b]), assertz(written(X))), H),
        ( assertion(is_engine(H)),
          assertion(\+ written(_)),
          metta_host_hold_chunk(H, 2, Rows),
          assertion(Rows == [a,a]),
          findall(X, written(X), Seen),
          assertion(Seen == [a,a]) ),
        metta_host_hold_close(H)).

test(inside_is_held_and_commit_keeps_unread_rows,
     [cleanup(retractall(written(_)))]) :-
    transaction(
        ( metta_host_hold(X, (member(X, [a,a,b]), assertz(written(X))), H),
          thread_self(Thread),
          assertion(H = held(_, Thread)),
          findall(X, written(X), Seen),
          assertion(Seen == [a,a,b]),
          metta_host_hold_next(H, a) )),
    setup_call_cleanup(true,
        ( metta_host_hold_chunk(H, 8, Rows),
          assertion(Rows == [a,b]),
          assertion(\+ metta_host_hold_next(H, _)) ),
        metta_host_hold_close(H)).

test(rollback_discards_writes_and_unread_rows) :-
    catch(transaction(
        ( metta_host_hold(X, (member(X, [a,b]), assertz(written(X))), H),
          throw(rollback(H)) )), rollback(Handle), true),
    assertion(\+ written(_)),
    assertion(\+ metta_host_hold_next(Handle, _)),
    metta_host_hold_close(Handle).

test(nested_commit_is_owned_by_the_outer_rollback) :-
    catch(transaction(
        ( transaction(metta_host_hold(X, member(X, [a,b]), H)),
          throw(rollback(H)) )), rollback(Handle), true),
    assertion(\+ metta_host_hold_next(Handle, _)),
    metta_host_hold_close(Handle).

test(close_is_idempotent_on_both_shapes) :-
    metta_host_hold(X, member(X, [a,b]), Engine),
    metta_host_hold_close(Engine),
    metta_host_hold_close(Engine),
    assertion(\+ is_engine(Engine)),
    transaction(
        ( metta_host_hold(X, member(X, [a,b]), Held),
          metta_host_hold_close(Held),
          metta_host_hold_close(Held),
          assertion(\+ metta_host_hold_next(Held, _)) )).

test(other_thread_refuses_before_reading) :-
    transaction(setup_call_cleanup(
        metta_host_hold(X, member(X, [a,b]), H),
        ( forall(member(Goal, [metta_host_hold_next(H, _),
                              metta_host_hold_chunk(H, 0, _)]),
                 ( in_other_thread(Goal, Result),
                   assertion(Result = error(error(
                       permission_error(access, transaction_cursor, H),
                       context(metta_host_hold/3,
                               'step it from the transaction\'s thread, or \c
                                open it outside the transaction')))) )),
          metta_host_hold_chunk(H, 3, Rows),
          assertion(Rows == [a,b]) ),
        metta_host_hold_close(H))).

test(other_thread_close_runs_on_the_owner) :-
    transaction(
        ( metta_host_hold(X, member(X, [a,b]), H),
          in_other_thread(metta_host_hold_close(H), Result),
          assertion(Result == answered),
          assertion(\+ metta_host_hold_next(H, _)),
          metta_host_hold_close(H) )).

test(close_after_owner_exit_is_idempotent) :-
    thread_create(
        ( transaction(metta_host_hold(X, member(X, [a,b]), H)),
          thread_exit(H) ), Thread, []),
    thread_join(Thread, exited(Handle)),
    metta_host_hold_close(Handle),
    metta_host_hold_close(Handle).

test(close_is_delivered_to_a_suspended_engine_owner) :-
    setup_call_cleanup(
        engine_create(Rows,
            ( transaction(metta_host_hold(X, member(X, [a,b]), H)),
              engine_yield(H),
              metta_host_hold_chunk(H, 3, Rows) ), Engine),
        ( engine_next(Engine, Handle),
          metta_host_hold_close(Handle),
          engine_next(Engine, Remaining),
          assertion(Remaining == []) ),
        engine_destroy(Engine)).

test(outside_engine_can_be_stepped_on_another_thread) :-
    setup_call_cleanup(metta_host_hold(a, true, H),
        ( in_other_thread(metta_host_hold_next(H, a), Result),
          assertion(Result == answered) ),
        metta_host_hold_close(H)).

test(post_resumes_an_engine) :-
    setup_call_cleanup(metta_host_hold(X, engine_fetch(X), H),
        ( metta_host_hold_post(H, reply, Row), assertion(Row == reply) ),
        metta_host_hold_close(H)).

test(post_to_held_rows_refuses,
     [throws(error(permission_error(post, held_cursor, _), _))]) :-
    transaction(setup_call_cleanup(metta_host_hold(a, true, H),
        metta_host_hold_post(H, reply, _), metta_host_hold_close(H))).

test(held_capture_emits_the_whole_text_once) :-
    transaction(setup_call_cleanup(
        metta_py_open_controlled_cursor([none, @(true)], X,
            (member(X, [a,b]), format('~w~n', [X])), H),
        ( metta_py_cursor_chunk_controlled(H, 1, First),
          assertion(First == [[a], "a\nb\n"]),
          metta_py_cursor_next_controlled(H, Second),
          assertion(Second == [[b], ""]),
          metta_py_cursor_next_controlled(H, End),
          assertion(End == [[], ""]) ),
        metta_py_cursor_close(H))).

test(empty_held_capture_keeps_its_text) :-
    transaction(setup_call_cleanup(
        metta_py_open_controlled_cursor([none, @(true)], _,
            (write('empty\n'), fail), H),
        ( metta_py_cursor_chunk_controlled(H, 4, First),
          assertion(First == [[], "empty\n"]),
          metta_py_cursor_next_controlled(H, End),
          assertion(End == [[], ""]) ),
        metta_py_cursor_close(H))).

test(outside_capture_still_emits_per_pull) :-
    setup_call_cleanup(
        metta_py_open_controlled_cursor([none, @(true)], X,
            (member(X, [a,b]), format('~w~n', [X])), H),
        ( metta_py_cursor_next_controlled(H, First),
          assertion(First == [[a], "a\n"]),
          metta_py_cursor_chunk_controlled(H, 3, Rest),
          assertion(Rest == [[b], "b\n"]) ),
        metta_py_cursor_close(H)).

test(plain_cursor_policy_uses_the_service) :-
    transaction(setup_call_cleanup(
        metta_py_open_controlled_cursor(none, a, true, H),
        ( assertion(H = held(_, _)), metta_py_cursor_next(H, [a]) ),
        metta_py_cursor_close(H))).

test(node_jobs_use_the_transaction_hold) :-
    transaction(setup_call_cleanup(
        metta_node_start([], ["source", "(+ 2 3)", "&self"], Id),
        ( metta_node_job(Id, H), assertion(H = held(_, _)),
          metta_node_step(Id, [Event]),
          assertion(Event == [answer, [n, "5"], "5"]),
          metta_node_step(Id, [[spent, Spent]]),
          number_string(_, Spent),
          metta_node_step(Id, []) ),
        metta_node_stop(Id))).

:- end_tests(host_hold).
