/* Purpose: verify the host listener door registers once for every caller,
   completes before any caller returns, refuses an unbound closure and raises a
   failed registration from every waiter, without an engine boot.
   Guarantees: each test listens on a dynamic predicate of its own, joins every
   thread it creates, and registers nothing a later test can hear.
*/
:- use_module('../../../../engine/host_listeners').
:- use_module(library(lists), [numlist/3]).
:- use_module(library(apply), [maplist/3, maplist/2]).

:- begin_tests(host_listeners).

:- dynamic once_fact/1, once_seen/1.
once_event(Action, _Context) :- assertz(once_seen(Action)).

test(the_same_listener_registers_once) :-
    metta_listen(once_fact/1, once_event),
    metta_listen(once_fact/1, once_event),
    retractall(once_seen(_)),
    assertz(once_fact(1)),
    aggregate_all(count, once_seen(assertz), Fired),
    assertion(Fired == 1).

:- dynamic race_fact/1, race_seen/1.
race_event(_Action, Context) :- assertz(race_seen(Context)).

% Each thread registers, then adds a row. A caller that returned before the
% registration was live would add a row nothing hears, and a second
% registration would hear every row twice; eight rows heard once each is
% both claims at once.
test(concurrent_callers_register_once_and_none_returns_before_it_is_live,
     [condition(current_prolog_flag(threads, true))]) :-
    retractall(race_seen(_)),
    numlist(1, 8, Rows),
    maplist(race_thread, Rows, Threads),
    maplist(join_true, Threads),
    aggregate_all(count, race_seen(_), Heard),
    assertion(Heard == 8).

race_thread(Row, Thread) :-
    thread_create(( metta_listen(race_fact/1, race_event),
                    assertz(race_fact(Row)) ),
                  Thread, []).

join_true(Thread) :-
    thread_join(Thread, Status),
    assertion(Status == true).

test(an_unbound_closure_is_refused_before_anything_registers,
     [throws(error(instantiation_error, _))]) :-
    metta_listen(once_fact/1, once_event(_)).

test(an_unbound_channel_is_refused_before_anything_registers,
     [throws(error(instantiation_error, _))]) :-
    metta_listen(_, once_event).

:- dynamic tx_fact/1, tx_seen/1.
tx_event(Action, _Context) :- assertz(tx_seen(Action)).

% Both the registrar's path and the already-registered path run inside a
% transaction, which refuses thread_wait/2 and hides ordinary assertions.
test(registration_inside_a_transaction_completes_and_is_heard_after_it) :-
    transaction(( metta_listen(tx_fact/1, tx_event),
                  metta_listen(tx_fact/1, tx_event) )),
    retractall(tx_seen(_)),
    assertz(tx_fact(1)),
    aggregate_all(count, tx_seen(assertz), Fired),
    assertion(Fired == 1).

:- dynamic rb_fact/1, rb_seen/1.
rb_event(Action, _Context) :- assertz(rb_seen(Action)).

% The claim and the completion row are outside the transaction, so a rolled
% back registrar leaves a live listener rather than a claimed key nobody
% completes.
test(a_registration_survives_the_rollback_of_the_transaction_that_made_it) :-
    assertion(\+ transaction(( metta_listen(rb_fact/1, rb_event), fail ))),
    metta_listen(rb_fact/1, rb_event),
    retractall(rb_seen(_)),
    assertz(rb_fact(1)),
    aggregate_all(count, rb_seen(assertz), Fired),
    assertion(Fired == 1).

test(a_failed_registration_raises_from_the_registrar_and_from_a_later_caller) :-
    catch(metta_listen(no_such_channel, once_event), First, true),
    catch(metta_listen(no_such_channel, once_event), Second, true),
    assertion(First = error(domain_error(event, no_such_channel), _)),
    assertion(Second = error(domain_error(event, no_such_channel), _)).

:- end_tests(host_listeners).
