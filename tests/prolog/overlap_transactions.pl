% Purpose: run two engine transactions with a controlled overlap and commit order for plunit suites.
% Assumes: the engine is loaded before this module, so metta_transaction/1 resolves through user.
% Guarantees: both snapshots open before either body writes, the caller names who commits first,
%   the loser's own commit carries its refusal, and every worker is joined or signalled before the
%   harness returns [source: tests/prolog/suites/spaces/owned_records.plt:overlap/4; commit=c5bdd73e06840e1d0fd0991523983c75def074f6].
% Decides: queues, never timing, select snapshots and commit order.
% The queue and worker helpers are exported too: the owned-record reads and
% occurrences suites drive their own snapshot writer through them.
:- module(overlap_transactions,
          [overlap/4, outcome/2, with_queues/2, worker_cleanup/2, stage/3]).
:- meta_predicate overlap(0, 0, +, -), outcome(0, -), with_queues(+, 0).

outcome(Goal, Outcome) :-
    catch(( call(Goal) -> Outcome = committed ; Outcome = failed ),
          Error, Outcome = threw(Error)).

% Both workers open their snapshots before either body writes. The parent
% receives an early failure instead of waiting for a stage that cannot occur.
worker(Tag, Goal, Commands, Events) :-
    outcome(metta_transaction(
                ( thread_send_message(Events, event(Tag, opened)),
                  thread_get_message(Commands, begin), call(Goal),
                  thread_send_message(Events, event(Tag, written)),
                  thread_get_message(Commands, commit) )), Result),
    thread_send_message(Events, event(Tag, done(Result))).

stage(Events, Tag, Expected) :-
    thread_get_message(Events, event(Tag, Actual)),
    ( Actual == Expected -> true
    ; throw(error(overlap_worker_stage(Tag, Expected, Actual), none)) ).

worker_cleanup(Finished, Thread) :-
    ( var(Thread) -> true
    ; Finished == true
    -> thread_join(Thread, Status), assertion(Status == true)
    ; catch(( thread_property(Thread, status(running))
            -> thread_signal(Thread, throw(overlap_abandoned))
            ; true ), error(existence_error(thread, _), _), true),
      catch(thread_join(Thread, _), error(existence_error(thread, _), _), true) ).

with_queues([], Goal) :- call(Goal).
with_queues([Queue|Queues], Goal) :-
    setup_call_cleanup(message_queue_create(Queue), with_queues(Queues, Goal),
                       message_queue_destroy(Queue)).

overlap(FirstGoal, SecondGoal, FirstCommit, Results) :-
    with_queues([Events, First, Second],
        setup_call_cleanup(
            true,
            ( thread_create(worker(first, FirstGoal, First, Events), A, []),
              thread_create(worker(second, SecondGoal, Second, Events), B, []),
              stage(Events, first, opened), stage(Events, second, opened),
              thread_send_message(First, begin), stage(Events, first, written),
              thread_send_message(Second, begin), stage(Events, second, written),
              ( FirstCommit == first
              -> Ahead = first-First, Behind = second-Second
              ; Ahead = second-Second, Behind = first-First ),
              Ahead = AheadTag-AheadQueue, Behind = BehindTag-BehindQueue,
              thread_send_message(AheadQueue, commit),
              thread_get_message(Events, event(AheadTag, done(AheadResult))),
              thread_send_message(BehindQueue, commit),
              thread_get_message(Events, event(BehindTag, done(BehindResult))),
              keysort([AheadTag-AheadResult, BehindTag-BehindResult], Results),
              Finished = true ),
            ( worker_cleanup(Finished, A), worker_cleanup(Finished, B) ))).
