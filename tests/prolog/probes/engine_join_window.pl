% Purpose: show which SWI-Prolog engine operations make the thread running
%   them unsafe for another thread to thread_join/2, by parking a worker inside
%   each one and joining it from the main thread.
% Assumes: plain SWI-Prolog. Nothing from this repository is loaded, because
%   the window belongs to SWI and not to anything here.
% Guarantees: each mode parks the worker deterministically with a message
%   queue rather than racing it, so the join reads the worker's pthread_t while
%   the worker is provably inside the named operation. A detached sleeper
%   releases the worker, so a mode that is SAFE terminates and prints its
%   status instead of hanging [measured 2026-09-06: `destroy` dies with SIGSEGV
%   in __pthread_clockjoin_ex 10 runs out of 10 and `post`, `next` and
%   `create_idle` join cleanly 10 out of 10, at loadavg 65;
%   command=sh tests/prolog/probes/engine_join_window.sh 10;
%   fixture=swipl 10.1.13, this file;
%   commit=81d05b34f938ff97f835ca1c00205220690cb6f0].
% Fails when: run against an SWI-Prolog whose detach_engine keeps a real
%   thread's tid, which is the host this tree runs on since the
%   swi-thread-join-detach-window patch of docs/host-workarounds.md, where
%   every mode joins cleanly and the probe shows nothing; the ledger's
%   reproduction is this probe's destroy mode frozen in
%   tests/checks/host_workarounds/swi-thread-join-detach-window.sh.
% Owns resources: three message queues, one worker thread, one detached
%   releaser and one engine per run. The process is expected to die in
%   `destroy` mode, so cleanup is the process exit; every other mode joins its
%   worker and returns.
% Decides: `destroy` is the reproducing mode. It is the one this repository
%   stopped using, in engine/materialize.pl's erase callback.
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None
%
% The window. engine_create/3 and engine_destroy/1 both run their work between
% PL_set_engine(Other, &Caller) and PL_set_engine(Caller, NULL). The first of
% those calls detach_engine(Caller), which sets the CALLING thread's
% PL_thread_info_t.has_tid to false and memsets its .tid to zero; the second
% restores both [source: SWI-Prolog 10.1.13 src/pl-thread.c:7038
% detach_engine, called from PL_set_engine at :7056 by its line :7077;
% '$engine_create'/3 at :4083 makes the pair at :4134 and :4148, and
% destroy_interactor at :4164 the pair at :4168 and :4170;
% commit=81d05b34f938ff97f835ca1c00205220690cb6f0].
% thread_join/2 reads .tid once, with no has_tid test, and hands it to
% pthread_timedjoin_np [source: SWI-Prolog 10.1.13 src/pl-thread.c:2898
% thread_join, its call at :2927, pthread_join_interruptible at :2873;
% commit=81d05b34f938ff97f835ca1c00205220690cb6f0], so a join inside the
% window calls pthread_timedjoin_np(0, ...) and glibc dereferences a null
% struct pthread.
%
% engine_next/2 and engine_post/3 do NOT close on that path: they go through
% activate_interactor/suspend_interactor, which detach the ENGINE's
% PL_thread_info_t and leave the host's alone [source: SWI-Prolog 10.1.13
% src/pl-thread.c:4251 activate_interactor, :4266 suspend_interactor;
% commit=81d05b34f938ff97f835ca1c00205220690cb6f0]. That difference is the
% whole reason a standing engine driven by engine_post/3 is safe where a
% per-event engine is not.
%
%   swipl tests/prolog/probes/engine_join_window.pl destroy
%   swipl tests/prolog/probes/engine_join_window.pl post
%   swipl tests/prolog/probes/engine_join_window.pl next
%   swipl tests/prolog/probes/engine_join_window.pl create_idle
%   swipl tests/prolog/probes/engine_join_window.pl create_churn

:- initialization(main, main).

% Forty rounds of: start a worker that churns engine_create/3 and
% engine_destroy/1 for fifty milliseconds, wait two milliseconds into it, and
% join it with plain thread_join/2. This is the shape lib_thread's regressions
% use, with the safe join taken out, so it says what those regressions would do
% without it.
main([create_churn]) :-
    !,
    message_queue_create(_, [alias(churning)]),
    format("forty joins, each two milliseconds into a churning worker~n", []),
    flush_output,
    forall(between(1, 40, _),
           ( get_time(Now),
             Deadline is Now + 0.05,
             thread_create(churn_announced(Deadline), Worker, []),
             thread_get_message(churning, now),
             sleep(0.002),
             thread_join(Worker, _) )),
    format("joined: forty~n", []).
main([Mode]) :-
    !,
    message_queue_create(_, [alias(parked)]),
    message_queue_create(_, [alias(ready)]),
    message_queue_create(_, [alias(release)]),
    thread_create(worker(Mode), Worker, []),
    thread_get_message(ready, now),
    thread_get_message(parked, now),
    format("worker parked inside ~w; joining~n", [Mode]),
    flush_output,
    % The worker is held until this fires, so a join that does NOT crash still
    % terminates and says so. A detached sleeper rather than library(time):
    % SWI 10.1.13 halts only after an alarm that FIRED and was never removed
    % has been reaped, and about one run in three it never is -- 5 of 15 runs
    % of `alarm(2, true, _), sleep(3)` sat until a 30 second ceiling, against
    % 0 of 15 for a plain sleep, 0 of 15 for the same alarm with
    % remove_alarm/1, and 0 of 15 for call_with_time_limit/2, which removes
    % its own [measured 2026-09-06; command=sh bounded.sh --ceiling 30 swipl
    % -g GOAL -t halt; fixture=swipl 10.1.13;
    % commit=81d05b34f938ff97f835ca1c00205220690cb6f0].
    thread_create(( sleep(2), thread_send_message(release, go) ), _,
                  [detached(true)]),
    thread_join(Worker, Status),
    format("joined: ~q~n", [Status]).
main(_) :-
    format(user_error,
           "usage: engine_join_window.pl destroy|post|next|create_idle|create_churn~n", []),
    halt(2).

park :-
    thread_send_message(parked, now),
    thread_get_message(release, go).

% engine_destroy/1 closes the engine's query, which runs the pending
% setup_call_cleanup/3 cleanup. member/2 leaves a choice point behind the first
% answer, so the cleanup is still pending when the destroy arrives and parking
% in it parks the host thread inside destroy_interactor's PL_set_engine window.
worker(destroy) :-
    engine_create(x, setup_call_cleanup(true, member(_, [a,b]), park), E),
    engine_next(E, _),
    thread_send_message(ready, now),
    engine_destroy(E).
% The control: the same park, reached through an engine that already exists.
worker(post) :-
    engine_create(_, post_loop, E),
    engine_post(E, warmup, done),
    thread_send_message(ready, now),
    engine_post(E, park, _).
worker(next) :-
    engine_create(x, ( park, fail ; x = done ), E),
    thread_send_message(ready, now),
    engine_next(E, _).
% engine_create/3's own window is short and cannot be parked in, because
% nothing inside it runs Prolog. These two modes report how often a join lands
% in it by chance, which is how the crash was first met: rarely, and under
% load. They differ only in WHEN the join happens, and that is the whole
% difference between a probe that discriminates and one that does not:
% `create_idle` joins as soon as the worker announces itself and has never
% crashed here, while `create_churn` joins forty times, two milliseconds into
% each of forty short churns, and crashes readily. A join taken straight after
% thread_create/3 reads the pthread_t before the worker has run its first
% goal, which is also why an early form of
% lib_thread:a_joined_worker_survives_engine_churn_on_its_thread passed against
% the defect it exists for.
worker(create_idle) :-
    numlist(1, 300000, L),
    Goal = ( length(L, _), true ),
    thread_send_message(ready, now),
    thread_send_message(parked, now),
    get_time(T0),
    Deadline is T0+3.0,
    churn(Goal, Deadline).
% Driven by main/1 rather than by the shared park-and-join body, because the
% repeated join is the point.
worker(create_churn) :-
    thread_send_message(ready, now),
    thread_send_message(parked, now).

post_loop :-
    repeat,
      engine_fetch(Term),
      ( Term == park -> park ; true ),
      engine_yield(done),
    fail.

churn_announced(Deadline) :-
    thread_send_message(churning, now),
    churn(( X = x, X == x ), Deadline).

churn(Goal, Deadline) :-
    get_time(Now),
    (   Now >= Deadline
    ->  true
    ;   engine_create(x, Goal, E),
        engine_destroy(E),
        churn(Goal, Deadline)
    ).
