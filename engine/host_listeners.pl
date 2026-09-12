/* Purpose: register a host event listener once for the life of the process,
   through the one door the tree allows, so that no registration holds a mutex
   a callback could take and no listener is named, replaced or removed.
   Assumes:
   - prolog_listen/2 takes the channel's event-list lock to register and holds
     that lock across every callback it delivers, so a mutex held during a
     registration is ordered before the lock and a mutex taken inside a
     callback is ordered after it
     [source: https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-event.c#L99-L110
     and https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-event.c#L415-L470;
     commit=WORKTREE]
   - flag/3 updates atomically, so its compare-and-set is the once-only claim
     [source: `swipl -g "help(flag/3)"`, SWI-Prolog 10.1.13; commit=WORKTREE]
   - a registration is reached from inside a caller's transaction, where
     thread_wait/2 is refused and an ordinary assertion is invisible to other
     threads and undone by rollback, so the completion row is a
     non-transactional predicate and a waiter polls it
     [measured 2026-09-13: `thread_wait/2: No permission to thread wait ...
     (in transaction)` from function_free_materialization:overlapping_owned_publications_leave_one_image
     with a thread_wait/2 door; command=sh engine/test.sh suites/spaces/materialization.plt;
     commit=WORKTREE]
   Guarantees:
   - two calls with the same channel and closure register once, and neither
     returns before the registration is live; a registration that raises
     raises the same error from every call that waited on it; an unbound
     channel or closure is refused before anything is registered; a
     registration made inside a transaction survives that transaction's
     rollback [tested: host_listeners; commit=WORKTREE]
   - a bare predicate indicator names the closure's own module, so the same
     spelling from two modules is two channels and two keys
     [tested: host_listeners:the_same_listener_registers_once; commit=WORKTREE]
   - no prolog_listen/2,3 or prolog_unlisten/2 exists outside this file under
     engine/, lib/ or a seat's binding half
     [tested: tests/prolog/static_checks.pl, every_host_listener_registers_through_the_door;
     commit=WORKTREE]
   Owns resources: the listeners it registers, which live until the process
     ends. There is no removal door: SWI frees a removed callback while another
     thread may still be walking the list that held it.
   Guarded by: nothing. The once-only claim is flag/3's atomic compare-and-set
     and completion is the listener/2 row, both outside every transaction, so
     no mutex is held across prolog_listen/2 and a registration orders no mutex
     before the event-list lock. tests/prolog/lock_order.pl records that lock
     as one more mutex and the plunit lane fails on any cycle through it.
   Decides: a listener is process-wide and permanent, and its closure is ground,
     so the same registration is the same key from every thread.
*/
:- module(metta_host_listeners, [metta_listen/2]).

:- use_module(library(error), [instantiation_error/1]).

:- meta_predicate metta_listen(+, :).

% listener(Key, live) or listener(Key, failed(Error)), one row per claim,
% written outside any transaction the registrar is inside.
:- dynamic listener/2.
:- '$notransact'(listener/2).

% Four hangs in this tree were one lock cycle: a thread registered a listener
% while holding an engine mutex, and a callback on another thread waited for
% that mutex with the channel's event-list lock held. The record is
% docs/journal/2026-09-13-one-door-for-host-listeners.md. A registration that
% holds no mutex cannot open that cycle, whatever a callback later locks.
%
% Workaround: swi-event-list-lock-spans-listener-callbacks - a registration holds no mutex, so no mutex is ever ordered before a channel's event-list lock.
% Workaround: swi-named-listener-replacement-lock - the door takes no name, so a listener is registered once and never replaced.
metta_listen(Channel, Closure) :-
    ( ground(Channel) -> true ; instantiation_error(Channel) ),
    ( ground(Closure) -> true ; instantiation_error(Closure) ),
    strip_module(Closure, Module, _),
    qualified_channel(Channel, Module, Qualified),
    format(atom(Key), '~q', [listener(Qualified, Closure)]),
    (   listener(Key, Outcome)
    ->  true
    ;   flag(Key, 0, 1)
    ->  catch(prolog_listen(Qualified, Closure), Raised, true),
        ( var(Raised) -> Outcome = live ; Outcome = failed(Raised) ),
        assertz(listener(Key, Outcome))
    ;   registration_completed(Key, Outcome)
    ),
    (   Outcome == live
    ->  true
    ;   Outcome = failed(Error),
        throw(Error)
    ).

% A caller that lands between the registrar's claim and its row waits for the
% row. The window is one prolog_listen/2 call, and the wait is a sleep loop
% because thread_wait/2 is refused inside a transaction, which is where a
% registration is reached from.
registration_completed(Key, Outcome) :-
    (   listener(Key, Outcome)
    ->  true
    ;   sleep(0.0005),
        registration_completed(Key, Outcome)
    ).

% A predicate channel is resolved in the calling context by prolog_listen/2,
% which is transparent; naming the module here makes the key say which
% predicate is watched and keeps the resolution independent of who calls.
qualified_channel(Name/Arity, Module, Module:Name/Arity) :- !.
qualified_channel(Channel, _, Channel).
