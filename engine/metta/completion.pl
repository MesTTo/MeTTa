% Purpose: retain completion attempts across native and foreign outcomes.
% Assumes: engine/metta.pl consults this source in its implementation module.
% Guarantees: metta_after_foreign/2 transfers through native transactions,
%   finishes after captured foreign participants and before observations, and
%   never repeats a completed callback [tested: transaction_completion,
%   foreign_completion_results; commit=WORKTREE].
% Owns resources: native journals and the current coordinator retain scheduled
%   goals. A completed attempt drops its captured goal; scope exit drops its
%   queue. Explicit retry creates a new attempt, never a retired-name entry.
% Guarded by: queues and attempt cells belong to one executing engine. This
%   unit acquires no mutex; immediate callers must release their own locks.
%   Native completion runs after the host's event-list lock has been released.

:- meta_predicate metta_after_foreign(+, 0).

metta_after_foreign(Label, Goal) :-
    must_be(ground, Label),
    metta_participant_goal(Goal),
    % A host callback schedules from its own query, which closes before the
    % goal runs and undoes the bindings its inputs made; the copy carries them
    % [measured 2026-09-16: py_call(F:'__call__'(), _) reached completion with
    % F unbound when the scheduling query had returned to Python].
    duplicate_term(Goal, Kept),
    Task = completion(Label, pending(Kept), unqueued),
    metta_schedule_completion(Task).

% The native wrapper restores its parent before invoking this goal. Reusing
% that boundary keeps physical callbacks outside SWI's event-list mutex.
% [source: engine/host_transactions.pl:host_transaction_leave/4; commit=WORKTREE].
metta_schedule_completion(Task) :-
    (   arg(2, Task, done(_))
    ->  true
    ;   current_transaction(_)
    ->  context_module(Module),
        host_transactions:host_transaction_on_exit(
            Module:metta_schedule_completion(Task))
    ;   nb_current('$metta_completion_context', Context), Context \== []
    ->  arg(3, Context, Queue),
        catch(metta_queue_completion(Queue, Task), Ball,
              (metta_queue_completion(Queue, Task), throw(Ball)))
    ;   metta_attempt_completion(Task, Result),
        metta_completion_result(Result)
    ).

% A task can be transferred twice when the host retries interrupted native
% bookkeeping. The task's own queue membership makes that an O(1) no-op.
metta_queue_completion(Queue, Task) :-
    (   arg(3, Task, queued)
    ->  true
    ;   arg(1, Queue, Pending),
        ( Pending = [First|_], First == Task
        -> true
        ; nb_linkarg(1, Queue, [Task|Pending]) ),
        nb_linkarg(3, Task, queued)
    ).

% Save the active task before removing its pending link. Completion can be
% interrupted between those writes without losing the one callback owed.
metta_completion_take(Queue, Task) :-
    arg(2, Queue, Active),
    (   Active == none
    ->  arg(1, Queue, [Task|_]), nb_linkarg(2, Queue, Task)
    ;   Task = Active
    ),
    arg(1, Queue, Pending),
    ( Pending = [First|Rest], First == Task
    -> nb_linkarg(1, Queue, Rest)
    ; true ).

metta_completion_retire(Queue, Task) :-
    arg(3, Queue, Done),
    ( Done = [Last|_], Last == Task
    -> true
    ; nb_linkarg(3, Queue, [Task|Done]) ),
    nb_linkarg(2, Queue, none).

metta_drain_completions(Queue) :-
    (   arg(1, Queue, []), arg(2, Queue, none)
    ->  true
    ;   catch(metta_completion_take(Queue, Task), Ball,
              (metta_completion_take(Queue, Task), throw(Ball))),
        metta_attempt_completion(Task, _),
        catch(metta_completion_retire(Queue, Task), Ball,
              (metta_completion_retire(Queue, Task), throw(Ball))),
        metta_drain_completions(Queue)
    ).

metta_queued_completion_results(Queue, Results) :-
    arg(3, Queue, Done), reverse(Done, Ordered),
    findall(completed(Label, Result),
            member(completion(Label, done(Result), _), Ordered), Results).

% Cleanup records the attempt before an exception can escape. Catch retries
% only that idempotent state write, never Goal. This is the existing native
% cleanup-window workaround applied to a retained callback result.
% [source: engine/host_transactions.pl:host_transaction/2; commit=WORKTREE].
metta_attempt_completion(Task, Result) :-
    arg(2, Task, State),
    (   State = done(Result)
    ->  true
    ;   State == running
    ->  arg(1, Task, Label),
        Result = threw(error(metta_completion_reentrant(Label), none))
    ;   State = pending(Goal),
        catch(
            setup_call_catcher_cleanup(
                true,
                ( nb_linkarg(2, Task, running),
                  ( once(call(Goal)) -> Answer = ok
                  ; metta_completion_failure(Task, Answer) ) ),
                Catcher,
                catch(metta_attempt_finished(Task, Catcher, Answer), Ball,
                      (metta_attempt_finished(Task, Catcher, Answer), throw(Ball)))),
            Error,
            catch(metta_attempt_threw(Task, Error), Ball,
                  (metta_attempt_threw(Task, Error), throw(Ball)))),
        arg(2, Task, done(Result))
    ).

metta_attempt_finished(Task, Catcher, Answer) :-
    (   Catcher == exit
    ->  Result = Answer
    ;   Catcher = exception(Error)
    ->  Result = threw(Error)
    ;   Catcher = external_exception(Error)
    ->  Result = threw(Error)
    ;   metta_completion_failure(Task, Result)
    ),
    nb_linkarg(2, Task, done(Result)).

metta_attempt_threw(Task, Error) :-
    nb_linkarg(2, Task, done(threw(Error))).

metta_completion_failure(Task, threw(error(metta_completion_failed(Label), none))) :-
    arg(1, Task, Label).

metta_completion_result(ok).
metta_completion_result(threw(Error)) :- throw(Error).

% Phase order chooses the first ordinary failure. A registered engine control
% signal still stops the caller when another phase already failed ordinarily.
% The seam owns that classification; completion has no exception-name list.
metta_completion_error([], ok).
metta_completion_error([ok|Results], Result) :- !,
    metta_completion_error(Results, Result).
metta_completion_error([threw(Error)|Results], Result) :-
    metta_completion_error_after(Results, Error, Chosen),
    Result = threw(Chosen).

metta_completion_error_after([], Error, Error).
metta_completion_error_after([ok|Results], Error, Chosen) :- !,
    metta_completion_error_after(Results, Error, Chosen).
metta_completion_error_after([threw(Later)|Results], Error, Chosen) :-
    ( \+ control_exception(Error), control_exception(Later)
    -> Next = Later
    ; Next = Error ),
    metta_completion_error_after(Results, Next, Chosen).

:- multifile prolog:error_message//1.
prolog:error_message(metta_completion_failed(Label)) -->
    ['completion ~q failed without an exception'-[Label]].
prolog:error_message(metta_completion_reentrant(Label)) -->
    ['completion ~q cannot enter its own unfinished attempt'-[Label]].
