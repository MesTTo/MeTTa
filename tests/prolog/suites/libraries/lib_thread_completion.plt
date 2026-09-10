% Purpose: prove that a recorded future result does not bypass worker cleanup.
% Guarantees: ordinary and scheduled await join a worker whose result is already
%   published; concurrent awaiters wait through a competing or interrupted
%   native join; pool statistics describe one manager snapshot [tested:
%   lib_thread_completion; commit=WORKTREE].
% Owns resources: each fixture releases its worker barrier, joins both threads,
%   removes its predicate wrapper, closes its queues and destroys its pool.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- initialization(consult('../../lib/lib_thread/lib_thread.pl')).
:- use_module(library(prolog_wrap)).
:- use_module(library(thread_pool)).

:- begin_tests(lib_thread_completion).

record_join(Thread, Worker, Events, Wrapped) :-
    ( Thread == Worker -> thread_send_message(Events, joining) ; true ),
    call(Wrapped).

await_result(ordinary, Space, Answer) :- once(thread_await(Space, Answer)).
await_result(scheduled, Space, Answer) :-
    lib_thread:scheduler_future_settle_(completion_probe, Space, done),
    once('get-atoms'(Space, Answer)).

% The worker has published its result but cannot leave its cleanup handler.
% Observing entry to the real join distinguishes waiting from early return
% without a sleep or a negative timed assertion.
cached_result_joins(Mode) :-
    setup_call_cleanup(
        pool_create('$completion_pool', 1, true),
        setup_call_cleanup(
            ( message_queue_create(Done), message_queue_create(Ready),
              message_queue_create(Release), message_queue_create(Events),
              'new-space'(Space) ),
            completion_worker(Mode, Space, Done, Ready, Release, Events),
            ( metta_release_space(Space),
              maplist(message_queue_destroy, [Done,Ready,Release,Events]) )),
        pool_destroy('$completion_pool', true)).

completion_worker(Mode, Space, Done, Ready, Release, Events) :-
    setup_call_cleanup(
        ( thread_create_in_pool('$completion_pool',
              lib_thread:future_worker_(Space, Done,
                  (lib_thread:future_add_atom(Space, 10), Outcome = done),
                  Outcome,
                  (thread_send_message(Ready, published),
                   thread_get_message(Release, go))), Worker, []),
          assertz(lib_thread:metta_future(Space, Worker, Done)) ),
        ( thread_get_message(Ready, published, [timeout(10)]),
          setup_call_cleanup(
              wrap_predicate(lib_thread:metta_thread_join_settled(Thread, _),
                  '$completion_join', Wrapped,
                  plunit_lib_thread_completion:record_join(
                      Thread, Worker, Events, Wrapped)),
              completion_awaiter(Mode, Space, Release, Events),
              unwrap_predicate(lib_thread:metta_thread_join_settled/2,
                               '$completion_join')) ),
        ( thread_send_message(Release, go),
          catch(lib_thread:metta_thread_join_settled(Worker, _), _, true),
          retractall(lib_thread:metta_future(Space, _, _)),
          retractall(lib_thread:metta_future_result(Space, _)) )).

completion_awaiter(Mode, Space, Release, Events) :-
    setup_call_cleanup(
        thread_create(
            ( catch(await_result(Mode, Space, Answer), Error,
                    Answer = error(Error)),
              thread_send_message(Events, awaited(Answer)) ), Awaiter, []),
        ( thread_get_message(Events, First, [timeout(10)]),
          assertion(First == joining), First == joining,
          thread_send_message(Release, go),
          thread_get_message(Events, awaited(10), [timeout(10)]),
          pool_stats('$completion_pool', Stats),
          assertion(Stats == [[size,1],[running,0],[backlog,0],[free,1]]) ),
        ( thread_send_message(Release, go), thread_join(Awaiter, true) )).

test(cached_result_await_joins_before_answering) :- cached_result_joins(ordinary).
test(cached_result_scheduled_await_joins_before_answering) :- cached_result_joins(scheduled).

% Each manager request gets a different valid snapshot. Reading properties
% independently would combine running=0 with free=0 from different snapshots.
changing_pool_snapshot(Property) :-
    flag('$completion_snapshots', N, N+1),
    Running is (N // 2) mod 2, Free is 1-Running,
    member(Property, [size(1), running(Running), backlog(0), free(Free)]).

test(pool_statistics_are_one_snapshot,
     [ cleanup((unwrap_predicate(thread_pool:thread_pool_property/2,
                                 '$completion_snapshot'),
                pool_destroy('$completion_snapshot_pool', true))) ]) :-
    pool_create('$completion_snapshot_pool', 1, true),
    flag('$completion_snapshots', _, 0),
    wrap_predicate(thread_pool:thread_pool_property(Name, Property),
        '$completion_snapshot', Wrapped,
        ( Name == '$completion_snapshot_pool'
        -> plunit_lib_thread_completion:changing_pool_snapshot(Property)
        ; call(Wrapped) )),
    pool_stats('$completion_snapshot_pool', Stats),
    memberchk([running,Running], Stats), memberchk([free,Free], Stats),
    assertion(Running + Free =:= 1).

% Pause before worker_exitted sends the manager its completion message. One
% native joiner then blocks and the other receives the real permission error.
% The next event distinguishes retry from an early answer, without a timed
% absence assertion. Cleanup releases both barriers even when the test fails.
pause_pool_exit(Name, Ready, Release, Wrapped) :-
    ( Name == '$completion_pair_pool'
    -> thread_send_message(Ready, exiting), thread_get_message(Release, go)
    ; true ),
    call(Wrapped).

observe_contended_join(Thread, Worker, Events, Recovery, Wrapped) :-
    ( Thread == Worker
    -> thread_self(Self),
       ( nb_current('$completion_join_retry', failed)
       -> nb_setval('$completion_join_retry', retrying),
          thread_send_message(Events, retrying(Self))
       ; true ),
       catch(call(Wrapped), Error,
           ( Error = error(permission_error(join, thread, Thread), _),
             \+ nb_current('$completion_join_retry', _)
           -> nb_setval('$completion_join_retry', failed),
              thread_send_message(Events, contended(Self)),
              thread_get_message(Recovery, go),
              throw(Error)
           ; throw(Error) ))
    ; call(Wrapped) ).

pair_awaiter(Mode, Space, Events) :-
    thread_self(Self),
    catch(await_result(Mode, Space, Answer), Error, Answer = error(Error)),
    thread_send_message(Events, answered(Self, Answer)).

release_pair(Release, Recovery) :-
    thread_send_message(Release, go),
    thread_send_message(Recovery, go).

pair_events(One, Two, Interrupt, Space, Events, Release, Recovery) :-
    thread_get_message(Events, contended(Loser)),
    ( Loser == One -> Winner = Two ; Winner = One ),
    ( Interrupt = interrupt(Ball)
    -> thread_signal(Winner, throw(Ball)),
       thread_get_message(Events, answered(Winner, Answer)),
       assertion(Answer == error(Ball)), Answer == error(Ball)
    ; true ),
    thread_send_message(Recovery, go),
    thread_get_message(Events, Next),
    assertion(Next == retrying(Loser)), Next == retrying(Loser),
    ( Interrupt = interrupt_retry(RetryBall)
    -> thread_signal(Loser, throw(RetryBall)),
       thread_get_message(Events, answered(Loser, RetryAnswer)),
       assertion(RetryAnswer == error(RetryBall)), RetryAnswer == error(RetryBall)
    ; true ),
    thread_send_message(Release, go),
    ( Interrupt = interrupt_retry(_)
    -> true
    ; thread_get_message(Events, answered(Loser, 10)) ),
    ( Interrupt = interrupt(_)
    -> true
    ; thread_get_message(Events, answered(Winner, 10)) ),
    pool_stats('$completion_pair_pool', Stats),
    assertion(Stats == [[size,2],[running,0],[backlog,0],[free,2]]),
    % The future remains reusable after the one native join has been consumed.
    await_result(ordinary, Space, 10),
    await_result(scheduled, Space, 10).

pair_waiters(ModeOne, ModeTwo, Interrupt, Space, Events, Release, Recovery) :-
    setup_call_cleanup(
        thread_create(pair_awaiter(ModeOne, Space, Events), One, []),
        setup_call_cleanup(
            thread_create(pair_awaiter(ModeTwo, Space, Events), Two, []),
            pair_events(One, Two, Interrupt, Space, Events, Release, Recovery),
            ( release_pair(Release, Recovery), thread_join(Two, true) )),
        ( release_pair(Release, Recovery), thread_join(One, true) )).

pair_worker(ModeOne, ModeTwo, Interrupt, Space, Done, Ready, Release,
            Events, Recovery) :-
    setup_call_cleanup(
        ( thread_create_in_pool('$completion_pair_pool',
              lib_thread:future_worker_(Space, Done,
                  (lib_thread:future_add_atom(Space, 10), Outcome = done),
                  Outcome, true), Worker, []),
          assertz(lib_thread:metta_future(Space, Worker, Done)) ),
        ( assertion(blob(Worker, thread)),
          thread_get_message(Ready, exiting),
          setup_call_cleanup(
              wrap_predicate(lib_thread:metta_thread_join_settled(Thread, _),
                  '$completion_pair_join', Wrapped,
                  plunit_lib_thread_completion:observe_contended_join(
                      Thread, Worker, Events, Recovery, Wrapped)),
              pair_waiters(ModeOne, ModeTwo, Interrupt, Space, Events,
                           Release, Recovery),
              unwrap_predicate(lib_thread:metta_thread_join_settled/2,
                               '$completion_pair_join')) ),
        ( release_pair(Release, Recovery),
          catch(lib_thread:metta_thread_join_settled(Worker, _), _, true),
          retractall(lib_thread:metta_future(Space, _, _)),
          retractall(lib_thread:metta_future_result(Space, _)) )).

concurrent_awaiters(ModeOne, ModeTwo, Interrupt) :-
    setup_call_cleanup(
        pool_create('$completion_pair_pool', 2, true),
        setup_call_cleanup(
            ( message_queue_create(Done), message_queue_create(Ready),
              message_queue_create(Release), message_queue_create(Events),
              message_queue_create(Recovery), 'new-space'(Space) ),
            setup_call_cleanup(
                wrap_predicate(thread_pool:worker_exitted(Name, _, _),
                    '$completion_pair_exit', Wrapped,
                    plunit_lib_thread_completion:pause_pool_exit(
                        Name, Ready, Release, Wrapped)),
                pair_worker(ModeOne, ModeTwo, Interrupt, Space, Done, Ready,
                            Release, Events, Recovery),
                unwrap_predicate(thread_pool:worker_exitted/3,
                                 '$completion_pair_exit')),
            ( metta_release_space(Space),
              maplist(message_queue_destroy,
                      [Done,Ready,Release,Events,Recovery]) )),
        pool_destroy('$completion_pair_pool', true)).

test(concurrent_awaiters_join_before_both_answer,
     [forall((member(One, [ordinary,scheduled]),
              member(Two, [ordinary,scheduled])))]) :-
    concurrent_awaiters(One, Two, none).

test(an_interrupted_joiner_leaves_the_join_for_the_other_awaiter,
     [forall((member(Phase, [interrupt,interrupt_retry]), member(Ball,
         [ completion_join_interrupted,
           time_limit_exceeded,
           error(metta_control_signal(interrupted, future(completion_probe)),
                 context(metta, future(completion_probe))) ])))]) :-
    Interrupt =.. [Phase, Ball],
    concurrent_awaiters(ordinary, scheduled, Interrupt).

test(an_interruption_during_the_status_read_is_not_settlement,
     [forall(member(Ball, [time_limit_exceeded, completion_join_interrupted]))]) :-
    setup_call_cleanup(
        wrap_predicate(system:thread_property(Thread, _),
            '$completion_status_error', Wrapped,
            ( Thread == '$completion_status_probe' -> throw(Ball)
            ; call(Wrapped) )),
        ( catch(lib_thread:future_join_('$completion_status_probe'),
                Caught, true),
          assertion(Caught == Ball) ),
        unwrap_predicate(system:thread_property/2, '$completion_status_error')).

:- end_tests(lib_thread_completion).
