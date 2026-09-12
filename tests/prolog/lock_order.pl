/* Purpose: record the order in which each Prolog thread of a test process
   acquires SWI mutexes, with the event-list lock SWI holds across a listener
   callback modelled as one more lock per channel, and report every cycle at
   halt. A cycle is a deadlock some interleaving reaches. It is found the
   first time each of its edges is walked rather than the day the timing lines
   up, which is what a validator adds over a detector
   [source: https://github.com/torvalds/linux/blob/v6.10/Documentation/locking/lockdep-design.rst;
   commit=85d5c97fcc249810cb3dafea75506311796969d0].
   Assumes:
   - it is loaded before the suite it records (engine/test.sh passes it with
     -s), so the engine's boot-time registrations and every later acquisition
     pass through the wrappers; library(prolog_wrap) wraps a system predicate
     and a predicate that is defined later
     [tested: lock_order:a_registration_carries_the_channel_lock_into_its_callback;
     commit=85d5c97fcc249810cb3dafea75506311796969d0]
   - a callback runs on the thread whose event fired, with that channel's
     event-list lock held
     [source: https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-event.c#L415-L470;
     commit=85d5c97fcc249810cb3dafea75506311796969d0]
   - prolog_current_frame/1 and prolog_frame_attribute/3 mark the frame they
     inspect for frame_finished, so an instrument that inspected frames to
     name an acquirer would raise the events its own callback wrapper then
     records, without end
     [measured 2026-09-13: 105 of 118 suites died at a C-stack depth of 4476
     nested frame_finished callbacks under a frame-walking attribution;
     command=sh engine/test.sh; commit=85d5c97fcc249810cb3dafea75506311796969d0]
   Guarantees:
   - acquiring B while holding A records A -> B once, with the goal B was
     first taken for; registering while holding A records
     A -> event_list(Channel) with the closure; a callback holds
     event_list(Channel) while it runs; a mutex the thread already holds
     records nothing; a trylock records no order, because it cannot wait
     [tested: lock_order; commit=85d5c97fcc249810cb3dafea75506311796969d0]
   - lock_order_report/0 prints every cycle with the goal each edge was first
     taken for, then the line `lock-order: cycle` when one is not in the
     inventory, or one line with the counts when every cycle is inventoried
     or there is none, so a suite whose output has neither ran unrecorded;
     lock_order_audit/1 fails naming every inventoried cycle a whole run
     showed nowhere, so the inventory can only shrink
     [tested: lock_order; commit=85d5c97fcc249810cb3dafea75506311796969d0]
   - nothing here inspects a frame, so the recorder raises no event of its
     own [source: tests/prolog/lock_order.pl, every clause; commit=85d5c97fcc249810cb3dafea75506311796969d0]
   - the held stack is a trailed write, so a goal the host abandons, by an
     inference limit inside a callback or a thread signal that throws at the
     next call port, unwinds its own entry; nothing here runs in a
     setup_call_cleanup/3 Setup, which is the window the swi-cleanup-window
     entry names [measured 2026-09-13: with a non-backtrackable stack and
     setup_call_cleanup/3, spaces_receipt_limits leaked 130 entries per test
     and spent 96 of its 130 seconds copying the stack in nb_setval/2;
     command=sh engine/test.sh suites/spaces/receipt_limits.plt under a
     profile and a depth probe; commit=85d5c97fcc249810cb3dafea75506311796969d0]
     [tested: lock_order:an_abandoned_acquisition_unwinds_its_own_entry;
     commit=85d5c97fcc249810cb3dafea75506311796969d0]
   - a registration keeps its closure an atom: the generated predicate that
     stands in for it is registered by name, so the host resolves a procedure
     rather than building a closure term on the frame it is delivering for
     [measured 2026-09-13: with compound stand-ins, reference_loading died at
     signal 11 in the cell the swi-query-frame-discarded-on-engine-destroy
     entry names, printing the closure as garbage; command=sh engine/test.sh
     suites/reader/reference_loading.plt; commit=85d5c97fcc249810cb3dafea75506311796969d0]
   Owns resources: the seven wrappers and the edge table, for the life of the
     process.
   Guarded by: lock_order_edge/3 is a shared dynamic predicate written under
     SWI's own clause locking; each thread's held stack is a backtrackable
     global variable of that thread, which an engine has for itself. Two
     threads first seeing one edge at once can record it twice, which changes
     no verdict.
   Decides: this is a test instrument and costs inferences on every
     acquisition, so the plunit lane loads it and the engine never does. The
     report follows Abseil's Mutex, which keeps each edge with where it was
     first taken and prints the cycle's path
     [source: https://github.com/abseil/abseil-cpp/blob/20240722.0/absl/synchronization/internal/graphcycles.h;
     commit=85d5c97fcc249810cb3dafea75506311796969d0]; the site is the goal taken under the lock rather than
     the caller, because naming the caller needs the frame.
   Known issue: an engine that waits for a mutex held by the thread that
     resumes it deadlocks without a cycle, because the engine borrows that
     thread; this instrument does not see it. engine/materialize.pl states the
     rule those two follow above source_owner_erased/1.
*/
:- module(lock_order, [ lock_order_edge/3,
                        lock_order_cycles/1,
                        lock_order_report/0,
                        lock_order_forget/1,
                        lock_order_audit/1,
                        lock_order_audit_lines/1,
                        known_cycle/2 ]).

:- use_module(library(prolog_wrap), [wrap_predicate/4]).
:- use_module(library(lists), [member/2, selectchk/3, reverse/2, append/3,
                               nextto/3]).
:- use_module(library(gensym), [gensym/2]).
:- use_module(library(apply), [partition/4]).
:- use_module(library(readutil), [read_file_to_string/3]).

%!  lock_order_edge(?Held, ?Acquired, ?FirstFor) is nondet.
%
%   A thread holding Held asked for Acquired, first for the goal FirstFor.
%   event_list(Channel) stands for the lock SWI holds across Channel's
%   callbacks, and its goal is the closure.
:- dynamic lock_order_edge/3.

% Workaround: swi-event-list-lock-spans-listener-callbacks - a registration takes event_list(Channel) after every held mutex, and a callback holds it while it runs.
% Workaround: swi-cleanup-window - the held stack is a trailed write restored after the goal, never a Setup with a cleanup owed.

% registered(Channel, Closure, Name): the generated predicate Name stands in
% for Closure on Channel, so a removal can find it. generated(Name) marks the
% stand-ins so their own registration passes through untouched. Both, and
% every stand-in, are outside transactions: a registration is reached from
% inside one, and the host keeps the registration whether it commits or not.
:- dynamic registered/3, generated/1.
:- '$notransact'(registered/3).
:- '$notransact'(generated/1).

%%%% The wrappers %%%%

install :-
    wrap_predicate(system:with_mutex(Mutex, Goal), lock_order, Wrapped,
                   lock_order:holding(Mutex, Goal, Wrapped)),
    wrap_lock,
    wrap_trylock,
    wrap_unlock,
    wrap_listen,
    wrap_listen_with_options,
    wrap_unlisten,
    at_halt(lock_order:lock_order_report).

wrap_lock :-
    wrap_predicate(system:mutex_lock(Mutex), lock_order, Wrapped,
                   lock_order:locking(Mutex, Wrapped)).

% A trylock never waits, so it opens no dependency; it only becomes a held
% mutex that later acquisitions are ordered after.
wrap_trylock :-
    wrap_predicate(system:mutex_trylock(Mutex), lock_order, Wrapped,
                   ( Wrapped -> lock_order:pushed(Mutex) ; fail )).

wrap_unlock :-
    wrap_predicate(system:mutex_unlock(Mutex), lock_order, Wrapped,
                   ( Wrapped, lock_order:pop(Mutex) )).

wrap_listen :-
    wrap_predicate(system:prolog_listen(Channel, Closure), lock_order, Wrapped,
                   lock_order:registering(Channel, Closure, none, Wrapped)).

wrap_listen_with_options :-
    wrap_predicate(system:prolog_listen(Channel, Closure, Options), lock_order,
                   Wrapped,
                   lock_order:registering(Channel, Closure, Options, Wrapped)).

wrap_unlisten :-
    wrap_predicate(system:prolog_unlisten(Channel, Closure), lock_order, Wrapped,
                   lock_order:unregistering(Channel, Closure, Wrapped)).

:- initialization(install, now).

%%%% Each thread's held stack %%%%

held(Stack) :-
    ( nb_current('$lock_order_held', Stack) -> true ; Stack = [] ).

% The order a thread ASKS in is the dependency, whether or not this call
% waits, so the edges are recorded before the acquisition. A mutex the thread
% already holds is a recursive lock, which cannot wait and adds no order.
% The stack is written before the edges, so a callback that fires while the
% edges are being written sees the lock held and records nothing twice.
%
% The write is b_setval/2, after engine/metta/control.pl's metta_with_trailed/3:
% a goal that fails, throws, or is abandoned by an inference limit unwinds the
% trail and takes the entry with it, and a goal that exits restores the stack
% it started from. A setup_call_cleanup/3 would leave one call port between
% its Setup and its cleanup registration at which a limit strikes with the
% entry pushed and no pop owed, and a non-backtrackable write would copy the
% whole stack on every acquisition.
push(Mutex, For, Held) :-
    b_setval('$lock_order_held', [Mutex|Held]),
    (   Held == []
    ->  true
    ;   memberchk(Mutex, Held)
    ->  true
    ;   site(For, Site),
        forall(member(Above, Held), record(Above, Mutex, Site))
    ).

pop(Mutex) :-
    held(Held),
    (   selectchk(Mutex, Held, Rest)
    ->  b_setval('$lock_order_held', Rest)
    ;   true
    ).

holding(Mutex, Goal, Wrapped) :-
    held(Held),
    push(Mutex, Goal, Held),
    Wrapped,
    b_setval('$lock_order_held', Held).

% mutex_lock/1 has no scope of its own; its mutex_unlock/1 pops. A trylock
% that succeeds is held from then on but opened no dependency.
locking(Mutex, Wrapped) :-
    held(Held),
    push(Mutex, mutex_lock(Mutex), Held),
    Wrapped.

pushed(Mutex) :-
    held(Held),
    b_setval('$lock_order_held', [Mutex|Held]).

record(Above, Mutex, Site) :-
    (   lock_order_edge(Above, Mutex, _)
    ->  true
    ;   assertz(lock_order_edge(Above, Mutex, Site))
    ).

% The goal a lock is taken for, as its indicator.
site(Goal, Module:Name/Arity) :-
    strip_module(Goal, Module, Plain),
    (   compound(Plain)
    ->  compound_name_arity(Plain, Name, Arity)
    ;   Name = Plain,
        Arity = 0
    ).

%%%% Registration and callbacks %%%%

% The registration is made with a generated predicate standing in for the
% closure, so the callback SWI later delivers holds event_list(Channel) on its
% own thread for as long as it runs. The stand-in is registered by name, as
% an atom, because the host resolves an atom closure to a procedure before
% opening the callback's query and builds a compound closure on the frame it
% is delivering for. The wrapper sees the stand-in's own registration come
% back through the wrapped prolog_listen and passes it to the host.
%
% A bare predicate indicator is resolved by the host in the context module of
% the call, and inside a wrapper that context is the wrapper's own: passing
% the call through unchanged registers the wrong predicate. The closure
% arrives qualified with the caller's context, so a bare channel is qualified
% with the closure's module, which is what the door does and what the host
% would have done for a caller watching its own predicate
% [measured 2026-09-13: m1:go/0 registering f/1 through a wrapper that only
% called the original never heard m1:f/1, while its closure arrived as m1:cb;
% command=swipl -q -g main -t halt ai-tmp/ai-ctx-probe.pl; commit=85d5c97fcc249810cb3dafea75506311796969d0].
% Known issue: a caller that watches another module's predicate with a
% closure of its own is qualified with the closure's module here. A channel
% the host does not know is passed through, so the host raises its own error.
registering(Channel, Closure, Options, Wrapped) :-
    (   stand_in(Closure)
    ->  call(Wrapped)
    ;   strip_module(Closure, Context, _),
        qualified_channel(Channel, Context, Qualified),
        channel_arity(Qualified, Arity)
    ->  held(Held),
        site(Closure, Site),
        forall(member(Above, Held),
               record(Above, event_list(Qualified), Site)),
        generate(Qualified, Closure, Arity, Name),
        (   Options == none
        ->  prolog_listen(Qualified, lock_order:Name)
        ;   prolog_listen(Qualified, lock_order:Name, Options)
        )
    ;   call(Wrapped)
    ).

unregistering(Channel, Closure, Wrapped) :-
    (   stand_in(Closure)
    ->  call(Wrapped)
    ;   strip_module(Closure, Context, _),
        qualified_channel(Channel, Context, Qualified),
        forall(retract(registered(Qualified, Closure, Name)),
               prolog_unlisten(Qualified, lock_order:Name))
    ).

stand_in(lock_order:Name) :-
    atom(Name),
    generated(Name).

qualified_channel(Name/Arity, Module, Module:Name/Arity) :- !.
qualified_channel(Channel, _, Channel).

% What each channel adds to its closure [source: `swipl -g "help(prolog_listen/3)"`,
% SWI-Prolog 10.1.13; commit=85d5c97fcc249810cb3dafea75506311796969d0].
channel_arity(abort, 0).
channel_arity(erase, 1).
channel_arity(break, 3).
channel_arity(frame_finished, 1).
channel_arity(thread_exit, 1).
channel_arity(thread_start, 1).
channel_arity(this_thread_exit, 0).
channel_arity(_:_/_, 2).
channel_arity(_/_, 2).

% One stand-in per registration, as the host keeps one callback per
% registration; its clause carries the channel and the closure it delivers to.
generate(Qualified, Closure, Arity, Name) :-
    gensym('$lock_order_callback_', Name),
    length(Arguments, Arity),
    Head =.. [Name|Arguments],
    dynamic(Name/Arity),
    '$notransact'(Name/Arity),
    assertz((Head :- inside(Qualified, Closure, Arguments))),
    assertz(generated(Name)),
    assertz(registered(Qualified, Closure, Name)).

inside(Channel, Closure, Arguments) :-
    Goal =.. [call, Closure|Arguments],
    held(Held),
    push(event_list(Channel), Closure, Held),
    Goal,
    b_setval('$lock_order_held', Held).

%%%% The inventory %%%%

%!  known_cycle(?Mutexes, ?Suite) is nondet.
%
%   A cycle the tree carries today, in the canonical order
%   lock_order_cycles/1 reports, and one suite that shows it. INVENTORIED
%   rather than exempted, after tests/prolog/static_checks.pl's
%   scope_setup_backlog/5: the lane fails on a cycle not listed here and, when
%   every suite has run, on a listed cycle no suite shows any more, so the
%   list can only shrink. Each row is a lock-order inversion between the
%   engine's own mutexes, or between one of them and a channel's event-list
%   lock, that some interleaving turns into a hang; the burn-down and the
%   hierarchy that resolves it are in ai-code-organisation-and-fixes.md at
%   the workspace root. Four of the six are one shape: a watched transaction
%   frame finishing inside a critical section delivers frame_finished, whose
%   reference refresh needs that section's mutex; the other two put deferred
%   translation on both sides of the typing policy.
:- dynamic known_cycle/2.
known_cycle(['$metta_metta_exec',event_list(frame_finished)], reference_loading).
known_cycle(['$metta_typing_policy',event_list(frame_finished)], head_properties).
known_cycle(['$metta_typing_policy',metta_deferred_translation], translator_rule_extra_variables_exemption).
known_cycle(['$metta_metta_exec',event_list(frame_finished),'$metta_typing_policy'], reference_providers).
known_cycle(['$metta_specializer',event_list(frame_finished),'$metta_typing_policy'], head_properties).
known_cycle(['$metta_specializer',metta_deferred_translation,'$metta_typing_policy'], structural_aliases).

%%%% Cycles and the report %%%%

%!  lock_order_cycles(-Cycles) is det.
%
%   Every cycle in the recorded graph, each once, as the list of its mutexes
%   starting from the smallest in standard order.
lock_order_cycles(Cycles) :-
    findall(Cycle,
            ( lock_order_edge(From, To, _),
              cycle_through(From, To, Cycle) ),
            Found),
    sort(Found, Cycles).

cycle_through(From, To, Cycle) :-
    path(To, From, Path),
    append(Middle, [From], Path),
    canonical([From|Middle], Cycle).

% A path From -> ... -> To visiting no mutex twice, as its list of mutexes.
path(From, To, Path) :-
    walk(From, To, [From], Reversed),
    reverse(Reversed, Path).

walk(From, To, Seen, [To|Seen]) :-
    lock_order_edge(From, To, _).
walk(From, To, Seen, Path) :-
    lock_order_edge(From, Next, _),
    Next \== To,
    \+ memberchk(Next, Seen),
    walk(Next, To, [Next|Seen], Path).

canonical(Mutexes, Canonical) :-
    msort(Mutexes, [Smallest|_]),
    append(Before, [Smallest|After], Mutexes),
    !,
    append([Smallest|After], Before, Canonical).

%!  lock_order_forget(+Mutex) is det.
%
%   Drop every edge that names Mutex, for a suite that planted its own.
lock_order_forget(Mutex) :-
    retractall(lock_order_edge(Mutex, _, _)),
    retractall(lock_order_edge(_, Mutex, _)).

% The last line is the verdict engine/test.sh reads: the counts when every
% cycle is inventoried or there is none, `lock-order: cycle` when one is new.
% A known cycle prints its canonical form on one line so lock_order_audit/1
% can read which rows the run confirmed.
lock_order_report :-
    lock_order_cycles(Cycles),
    aggregate_all(count, lock_order_edge(_, _, _), Edges),
    (   setof(Mutex,
              A^B^S^( lock_order_edge(A, B, S), ( Mutex = A ; Mutex = B ) ),
              Mutexes)
    ->  length(Mutexes, Count)
    ;   Count = 0
    ),
    partition(known, Cycles, Known, New),
    forall(member(Cycle, Known), print_cycle(known, Cycle)),
    forall(member(Cycle, New), print_cycle(new, Cycle)),
    length(Known, KnownCount),
    (   New == []
    ->  format("lock-order: ~d mutexes, ~d acquisition orders, ~d known \c
                cycles, no new cycle~n", [Count, Edges, KnownCount])
    ;   format("lock-order: cycle~n")
    ).

known(Cycle) :- known_cycle(Cycle, _).

print_cycle(Status, Cycle) :-
    Cycle = [First|_],
    append(Cycle, [First], Closed),
    length(Cycle, Count),
    format("lock-order: ~w cycle of ~d: ~q~n", [Status, Count, Cycle]),
    forall(( nextto(Held, Acquired, Closed),
             lock_order_edge(Held, Acquired, Site) ),
           format("lock-order:   ~q -> ~q, first taken for ~q~n",
                  [Held, Acquired, Site])).

%!  lock_order_audit(+Log) is semidet.
%
%   Read a whole lane's log and fail, naming the row, for every inventoried
%   cycle no suite in it showed; that row is stale and must be deleted, which
%   is how the inventory only shrinks. Run by engine/test.sh after a run of
%   every suite.
lock_order_audit(Log) :-
    read_file_to_string(Log, Text, []),
    split_string(Text, "\n", "", Lines),
    lock_order_audit_lines(Lines).

%!  lock_order_audit_lines(+Lines) is semidet.
%
%   The audit over the log's lines, which is what the suite exercises.
lock_order_audit_lines(Lines) :-
    findall(Cycle,
            ( member(Line, Lines),
              string_concat("lock-order: known cycle of ", After, Line),
              sub_string(After, Position, 2, _, ": "),
              Skip is Position + 2,
              sub_string(After, Skip, _, 0, Text),
              catch(term_string(Cycle, Text), _, fail),
              is_list(Cycle) ),
            Shown0),
    sort(Shown0, Shown),
    findall(Cycle-Suite,
            ( known_cycle(Cycle, Suite), \+ memberchk(Cycle, Shown) ),
            Stale),
    (   Stale == []
    ->  true
    ;   forall(member(Cycle-Suite, Stale),
               format("lock-order: inventory row ~q, listed as shown by ~w, \c
                       was shown by no suite in this run; delete it~n",
                      [Cycle, Suite])),
        fail
    ).
