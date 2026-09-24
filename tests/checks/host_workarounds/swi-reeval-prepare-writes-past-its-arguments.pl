% Purpose: test whether '$tbl_reeval_prepare'/2 still succeeds with its
% variant unbound after waiting for a thread that re-evaluated the table.
% Its threaded branch in src/pl-tabling.c claims the table asking for a
% clause reference, and when the table comes back complete it unifies that
% reference with A3, a term reference past the predicate's two arguments,
% and succeeds. Its contract is to fail there, since the other thread
% re-evaluated the table. Prints present while the call succeeds leaving
% the variant unbound and absent once it fails.
% Guarantees: present iff the call succeeds leaving its argument unbound and
% the table then answers [1,2]; absent iff it fails and the table answers
% [1,2]; broken otherwise, a host without threads included
% [measured 2026-09-24: present on /home/user/Dev/.venv-pypetta/bin/swipl
% (10.1.14 patched, threaded); absent on a threaded build of V10.1.14 with
% every patch of the ledger and
% tests/checks/host_workarounds/swi-reeval-prepare-writes-past-its-arguments.patch;
% commit=622e425d40c126681c04c7f7f81d92618ab83d0d].
% Owns resources: the message queue and the re-evaluating thread, joined
% before main reports.

:- table sr/1 as (incremental,shared).
:- dynamic([sr_d/1], [incremental(true)]).

sr_d(1).

% A re-evaluation in the thread main starts tells main it has begun, then
% holds the table long enough for main to wait for it.
sr(X) :-
    (   nb_current(sr_signal, Queue)
    ->  thread_send_message(Queue, reevaluating),
        sleep(1)
    ;   true
    ),
    sr_d(X).

main :-
    (   current_prolog_flag(threads, true)
    ->  findall(X, sr(X), _),
        once(( current_table(_:Variant, ATrie), Variant = sr(_) )),
        assertz(sr_d(2)),
        message_queue_create(Queue),
        thread_create(( b_setval(sr_signal, Queue), findall(X, sr(X), _) ),
                      Reevaluator),
        thread_get_message(Queue, reevaluating),
        (   '$tbl_reeval_prepare'(ATrie, Prepared)
        ->  Result = succeeded(Prepared)
        ;   Result = failed
        ),
        thread_join(Reevaluator),
        message_queue_destroy(Queue),
        findall(X, sr(X), Xs0),
        msort(Xs0, Xs),
        verdict(Result, Xs, Verdict)
    ;   Verdict = broken
    ),
    writeln(Verdict).

verdict(succeeded(Prepared), [1,2], present) :-
    var(Prepared),
    !.
verdict(failed, [1,2], absent) :-
    !.
verdict(_, _, broken).
