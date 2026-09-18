% Purpose: test cancellation acknowledgement at running-engine safe points.
% Guarantees: a cancelled loop publishes no answer and releases its guard;
%   an outstanding await does not prevent cancellation [tested:
%   run_tests(lib_thread_cancellation); commit=c6e1198c490a824b96f6fc6e1c0622a542917024].
% Guarantees: preliminary release waits for cancellation cleanup before
%   clearing and tolerates repetition [tested:
%   lib_thread_cancellation:a_preliminary_release_cancels_before_clear_and_can_repeat;
%   commit=0891c522503ca9856fb654f306364f4ae9736b22].
% Owns resources: each test joins its workers and drops its future and queues.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- initialization(sc_cancel_setup).

sc_cancel_setup :-
    consult('../../lib/lib_thread/lib_thread.pl'),
    import_prolog_functions(['sc-cancel-loop', 'sc-cancel-sleep'], _).

'sc-cancel-loop'(Ready, done) :-
    setup_call_cleanup(
        true,
        ( thread_send_message(Ready, ready), sc_cancel_spin ),
        thread_send_message(Ready, cleaned)).

sc_cancel_spin :- sc_cancel_spin.

'sc-cancel-sleep'(Ready, done) :-
    thread_send_message(Ready, ready),
    sleep(0.1).

sc_cancel_release(Space, Ready) :-
    ( nonvar(Space)
    -> thread_cancel(Space, _), metta_release_space(Space)
    ; true ),
    message_queue_destroy(Ready).

:- begin_tests(lib_thread_cancellation).

test(an_unknown_future_refuses_instead_of_claiming_completion,
     [ throws(error(existence_error(metta_future, '&sc-unknown-future'), _)) ]) :-
    thread_cancel('&sc-unknown-future', _).

test(a_running_loop_stops_and_its_guard_cleans_up,
     [ setup(message_queue_create(Ready)),
       cleanup(sc_cancel_release(Space, Ready)) ]) :-
    thread_spawn(['sc-cancel-loop', Ready], Space),
    thread_get_message(Ready, ready),
    thread_cancel(Space, Stopped),
    assertion(Stopped == true),
    thread_get_message(Ready, cleaned),
    assertion(lib_thread:metta_future_result(Space, cancelled)),
    findall(Answer, thread_await(Space, Answer), Answers),
    assertion(Answers == []),
    thread_cancel(Space, Again),
    assertion(Again == false).

test(a_foreign_sleep_returns_before_cancellation_is_acknowledged,
     [ setup(message_queue_create(Ready)),
       cleanup(sc_cancel_release(Space, Ready)) ]) :-
    thread_spawn(['sc-cancel-sleep', Ready], Space),
    thread_get_message(Ready, ready),
    thread_cancel(Space, Stopped),
    assertion(Stopped == true),
    assertion(lib_thread:metta_future_result(Space, cancelled)),
    findall(Answer, thread_await(Space, Answer), Answers),
    assertion(Answers == []).

test(a_preliminary_release_cancels_before_clear_and_can_repeat,
     [ setup(message_queue_create(Ready)),
       cleanup(sc_cancel_release(Space, Ready)) ]) :-
    thread_spawn(['sc-cancel-loop', Ready], Space),
    thread_get_message(Ready, ready),
    metta_clear_space_for_release(Space),
    assertion(thread_get_message(Ready, cleaned, [timeout(0)])),
    assertion(lib_thread:metta_future_result(Space, cancelled)),
    metta_clear_space_for_release(Space),
    findall(Answer, thread_await(Space, Answer), Answers),
    assertion(Answers == []).

test(an_awaiting_consumer_does_not_lock_cancellation_out,
     [ setup(message_queue_create(Ready)),
       cleanup(sc_cancel_release(Space, Ready)) ]) :-
    thread_spawn(['sc-cancel-loop', Ready], Space),
    thread_get_message(Ready, ready),
    thread_create(findall(A, thread_await(Space, A), []), Waiter, []),
    thread_cancel(Space, Stopped),
    lib_thread:metta_thread_join(Waiter, Status),
    assertion(Stopped == true),
    assertion(Status == true).

:- end_tests(lib_thread_cancellation).
