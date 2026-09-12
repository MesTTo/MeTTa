/* Purpose: verify the lock-order recorder sees each acquisition order once
   with the goal it was first taken for, a reversed order on another thread as a cycle, a
   recursive or tried acquisition as no order, and a listener callback as the
   holder of its channel's lock; and that its report names the counts or the
   cycle, without an engine boot.
   Guarantees: every test forgets the mutexes it names, so the process report
   at halt is the same with or without this suite; every thread is joined.
*/
:- use_module('../../lock_order').
:- use_module(library(lists), [member/2, append/3]).
:- use_module(library(apply), [maplist/2]).

:- begin_tests(lock_order).

forget(Mutexes) :- maplist(lock_order_forget, Mutexes).

inner_work.
acquire_a_then_b :- with_mutex(lo_a, with_mutex(lo_b, inner_work)).

test(holding_one_mutex_while_taking_another_records_the_order_once_with_the_goal_it_was_taken_for,
     [cleanup(forget([lo_a, lo_b]))]) :-
    acquire_a_then_b,
    acquire_a_then_b,
    findall(Site, lock_order_edge(lo_a, lo_b, Site), Sites),
    assertion(Sites = [_:inner_work/0]),
    assertion(\+ lock_order_edge(lo_b, lo_a, _)).

test(the_reversed_order_on_another_thread_is_a_cycle,
     [condition(current_prolog_flag(threads, true)),
      cleanup(forget([lo_c, lo_d]))]) :-
    with_mutex(lo_c, with_mutex(lo_d, true)),
    thread_create(with_mutex(lo_d, with_mutex(lo_c, true)), Thread, []),
    thread_join(Thread, Status),
    assertion(Status == true),
    lock_order_cycles(Cycles),
    assertion(memberchk([lo_c, lo_d], Cycles)).

% plunit holds its own mutex around every test, so an order INTO lo_e from it
% is real; the recursive take is what must leave nothing behind.
test(a_recursive_acquisition_records_no_order, [cleanup(forget([lo_e]))]) :-
    with_mutex(lo_e, with_mutex(lo_e, true)),
    assertion(\+ lock_order_edge(lo_e, _, _)).

test(a_trylock_records_no_order_but_is_held_afterwards,
     [setup(mutex_create(_, [alias(lo_j)])),
      cleanup((forget([lo_i, lo_j]), mutex_destroy(lo_j)))]) :-
    with_mutex(lo_i, ( mutex_trylock(lo_j), mutex_unlock(lo_j) )),
    assertion(\+ lock_order_edge(lo_i, lo_j, _)),
    mutex_trylock(lo_j),
    with_mutex(lo_i, true),
    mutex_unlock(lo_j),
    assertion(lock_order_edge(lo_j, lo_i, _)).

% An inference limit that trips inside the goal abandons it between any
% setup and its cleanup; the trailed stack unwinds with it.
test(an_abandoned_acquisition_unwinds_its_own_entry, [cleanup(forget([lo_z]))]) :-
    call_with_inference_limit(with_mutex(lo_z, ( repeat, fail )), 200, Result),
    assertion(Result == inference_limit_exceeded),
    lock_order:held(Held),
    assertion(\+ memberchk(lo_z, Held)).

:- dynamic lo_fact/1, lo_heard/1.
lo_listener(Action, _Context) :-
    assertz(lo_heard(Action)),
    with_mutex(lo_f, true).

% The registration is made while holding lo_h, the event fires while holding
% lo_g, and the callback takes lo_f: three orders, each through the channel's
% own lock, and the callback still fires on a bare indicator registered from
% this unit.
test(a_registration_carries_the_channel_lock_into_its_callback,
     [cleanup((forget([lo_f, lo_g, lo_h]),
               context_module(Unit),
               lock_order_forget(event_list(Unit:lo_fact/1))))]) :-
    context_module(Unit),
    Channel = event_list(Unit:lo_fact/1),
    with_mutex(lo_h, prolog_listen(lo_fact/1, lo_listener)),
    retractall(lo_heard(_)),
    with_mutex(lo_g, assertz(lo_fact(1))),
    assertion(lo_heard(assertz)),
    assertion(lock_order_edge(lo_h, Channel, _:lo_listener/0)),
    assertion(lock_order_edge(lo_g, Channel, _:lo_listener/0)),
    assertion(lock_order_edge(Channel, lo_f, _:true/0)),
    lock_order_cycles(Cycles),
    assertion(\+ ( member(Cycle, Cycles), memberchk(Channel, Cycle) )).

test(the_report_names_the_counts_when_acyclic_and_the_cycle_otherwise,
     [cleanup(forget([lo_k, lo_l]))]) :-
    with_output_to(string(Clean), lock_order_report),
    assertion(sub_string(Clean, _, _, _, "acquisition orders, 0 known cycles, no new cycle")),
    with_mutex(lo_k, with_mutex(lo_l, true)),
    with_mutex(lo_l, with_mutex(lo_k, true)),
    with_output_to(string(Cyclic), lock_order_report),
    split_string(Cyclic, "\n", "", Lines),
    assertion(memberchk("lock-order: new cycle of 2: [lo_k,lo_l]", Lines)),
    assertion(( member(Line, Lines),
                sub_string(Line, _, _, _, "lo_k -> lo_l, first taken for") )),
    assertion(append(_, ["lock-order: cycle", ""], Lines)).

% The inventory row is planted into the dynamic table and withdrawn again, so
% the process report at halt does not inherit it.
test(a_known_cycle_is_reported_as_known_and_the_same_cycle_unlisted_as_new,
     [cleanup((forget([lo_m, lo_n]),
               retractall(lock_order:known_cycle([lo_m, lo_n], _))))]) :-
    assertz(lock_order:known_cycle([lo_m, lo_n], planted)),
    with_mutex(lo_m, with_mutex(lo_n, true)),
    with_mutex(lo_n, with_mutex(lo_m, true)),
    with_output_to(string(Known), lock_order_report),
    split_string(Known, "\n", "", KnownLines),
    assertion(memberchk("lock-order: known cycle of 2: [lo_m,lo_n]", KnownLines)),
    assertion(( member(Summary, KnownLines),
                sub_string(Summary, _, _, _, "1 known cycles, no new cycle") )),
    retractall(lock_order:known_cycle([lo_m, lo_n], _)),
    with_output_to(string(New), lock_order_report),
    split_string(New, "\n", "", NewLines),
    assertion(memberchk("lock-order: new cycle of 2: [lo_m,lo_n]", NewLines)),
    assertion(append(_, ["lock-order: cycle", ""], NewLines)).

% The audit reads the whole inventory, which this process shows nothing of,
% so only the planted row's own verdict is read off its report.
test(the_audit_names_an_inventory_row_no_suite_showed_and_passes_one_that_was,
     [cleanup(retractall(lock_order:known_cycle([lo_p, lo_q], _)))]) :-
    assertz(lock_order:known_cycle([lo_p, lo_q], planted)),
    Shown = ["% Start unit: planted",
             "lock-order: known cycle of 2: [lo_p,lo_q]",
             "lock-order:   lo_p -> lo_q, first taken for planted:work/0",
             "lock-order: 2 mutexes, 2 acquisition orders, 1 known cycles, no new cycle"],
    with_output_to(string(Passed), ignore(lock_order_audit_lines(Shown))),
    assertion(\+ sub_string(Passed, _, _, _, "inventory row [lo_p,lo_q]")),
    with_output_to(string(Report),
                   ignore(lock_order_audit_lines(["lock-order: 0 mutexes"]))),
    assertion(sub_string(Report, _, _, _,
                         "inventory row [lo_p,lo_q], listed as shown by planted")).

:- end_tests(lock_order).
