% Purpose: verify source ownership, re-entry, wakeup and independent progress.
% Owns resources: each fixture joins its workers and destroys its queues.
% Guarantees: the tests coordinate through messages, with no timing assumption
%   [tested: loader_singleflight; commit=90ba93eb8f6e98ebfefc55416859bf13de6a8427].

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(loader_singleflight, [condition(current_prolog_flag(threads, true))]).

test(same_owner_reentry_does_not_wait) :-
    metta_engine:metta_source_singleflight(reentry,
        metta_engine:metta_source_singleflight(reentry, true)),
    assertion(\+ metta_engine:metta_source_flight(reentry, _, _)).

test(a_failed_owner_releases_the_key) :-
    catch(metta_engine:metta_source_singleflight(failure, throw(expected)),
          expected, true),
    metta_engine:metta_source_singleflight(failure, true),
    assertion(\+ metta_engine:metta_source_flight(failure, _, _)).

test(queues_and_ownership_are_not_rolled_back) :-
    \+ transaction(metta_engine:metta_source_singleflight(rollback, fail)),
    assertion(\+ metta_engine:metta_source_flight(rollback, _, _)),
    metta_engine:metta_source_singleflight(rollback, true).

test(one_source_owner_and_every_waiter_wakes) :-
    setup_call_cleanup(
        ( message_queue_create(Started), message_queue_create(Release),
          message_queue_create(Waiting), message_queue_create(Done) ),
        ( thread_create(flight_owner(shared, Started, Release, Done), Owner, []),
          thread_get_message(Started, started),
          metta_engine:metta_source_flight_enter(shared, Claim),
          assertion(Claim = waiting(_)),
          findall(Waiter,
                  ( between(1, 4, _),
                    thread_create(flight_waiter(shared, Waiting, Done), Waiter, []) ), Waiters),
          forall(between(1, 4, _), thread_get_message(Waiting, waiting)),
          thread_send_message(Release, release),
          maplist(thread_join_true, Waiters),
          thread_join(Owner, true),
          findall(done, between(1, 5, _), Expected),
          maplist(thread_get_message(Done), Expected),
          assertion(\+ metta_engine:metta_source_flight(shared, _, _)) ),
        ( message_queue_destroy(Started), message_queue_destroy(Release),
          message_queue_destroy(Waiting),
          message_queue_destroy(Done) )).

test(a_distinct_source_completes_while_the_first_is_held) :-
    setup_call_cleanup(
        ( message_queue_create(Started), message_queue_create(Release),
          message_queue_create(Done) ),
        ( thread_create(flight_owner(first, Started, Release, Done), Owner, []),
          thread_get_message(Started, started),
          metta_engine:metta_source_singleflight(second,
              thread_send_message(Release, release)),
          thread_join(Owner, true),
          thread_get_message(Done, done) ),
        ( message_queue_destroy(Started), message_queue_destroy(Release),
          message_queue_destroy(Done) )).

flight_owner(Key, Started, Release, Done) :-
    metta_engine:metta_source_singleflight(Key,
        ( thread_send_message(Started, started),
          thread_get_message(Release, release),
          thread_send_message(Done, done) )).

flight_waiter(Key, Waiting, Done) :-
    with_mutex(metta_loader, metta_engine:metta_source_flight_enter(Key, Claim)),
    Claim = waiting(_), thread_send_message(Waiting, waiting),
    metta_engine:metta_source_flight_run(Claim, Key, thread_send_message(Done, done)).

thread_join_true(Thread) :- thread_join(Thread, true).

test(an_interrupted_owner_wakes_all_already_waiting_callers) :-
    setup_call_cleanup(
        ( message_queue_create(Started), message_queue_create(Release),
          message_queue_create(Waiting), message_queue_create(Done) ),
        ( thread_create(catch(flight_owner(interrupted, Started, Release, Done),
                              interrupted, true), Owner, []),
          thread_get_message(Started, started),
          findall(Waiter,
                  ( between(1,4,_),
                    thread_create(flight_waiter(interrupted,Waiting,Done),Waiter,[]) ), Waiters),
          forall(between(1,4,_), thread_get_message(Waiting,waiting)),
          thread_signal(Owner,throw(interrupted)), thread_join_true(Owner),
          maplist(thread_join_true,Waiters),
          forall(between(1,4,_),thread_get_message(Done,done)),
          assertion(\+ metta_engine:metta_source_flight(interrupted,_,_)) ),
        ( message_queue_destroy(Started), message_queue_destroy(Release),
          message_queue_destroy(Waiting), message_queue_destroy(Done) )).

:- end_tests(loader_singleflight).
