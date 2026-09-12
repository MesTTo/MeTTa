% Guarantees: metta_with_occurrence_load/1 restores its root through
%   metta_with_trailed/3 before catch-protected receipt retirement
%   [source: engine/spaces/receipts.pl:metta_with_occurrence_load/1; commit=cdcb23421809ec3a493059a381e0245cf08a1984].
% Guarantees: interrupted native completion retires every finished scope's
%   rows and standing-engine reservations; nested rollback preserves the live
%   outer owner [tested: spaces_receipt_limits; commit=3ff7688a605c1f0de0e021f66f3075353476a992].
% Guarantees: the exception hook that finishes a cut listener is clausal only
%   from the process's first bound on, so a process that never bounds pays
%   nothing per ball [tested: spaces_receipt_limits:the_limit_hook_is_armed_by_the_first_bound;
%   commit=WORKTREE].
% Guarantees: a process that does bound pays three inferences per bounded call
%   for the test that arms it, and nothing else after the first
%   [measured 2026-09-12: 38,107 against 37,807 with the wrapper absent;
%   command=extensions/python/bench.py --counter-only query-limit-guarded;
%   fixture=one hundred guarded Python queries, min of three fresh processes;
%   commit=WORKTREE].
%
% Purpose: reserve incoming occurrence identities across transaction views.
% Assumes: native erasures use metta_erase_storage_ref/1 or metta_retract_storage/1.
% Guarantees: overlapping image receipts retain distinct tokens, while a load
%   into an empty destination preserves its tokens [tested: spaces_token_images;
%   commit=cdcb23421809ec3a493059a381e0245cf08a1984].
%   A completed inner transaction transfers its scope to the live outer one;
%   destroying its suspended engine does not notify a discarded query frame
%   [tested: spaces_receipt_frames; commit=cdcb23421809ec3a493059a381e0245cf08a1984].
% Owns resources: one standing engine; reservations and erased references last
%   only until their enclosing load or transaction finishes. Nested rollback
%   releases its reservations [tested: spaces_token_images; commit=cdcb23421809ec3a493059a381e0245cf08a1984].
% Guarded by: '$metta_occurrence_receipts' serializes requests to the engine.

:- use_module(library(ordsets), [ord_memberchk/2]).
:- dynamic metta_receipt_pending/4, metta_receipt_marker/2,
           metta_receipt_erased/2, metta_receipt_reserved/1.
:- meta_predicate metta_with_occurrence_load(0), metta_retract_storage(:).

% A standalone load publishes ordinary clauses as it goes. Its reservation
% lives through the restore; a transactional load keeps it through outer commit.
metta_with_occurrence_load(Goal) :-
    flag('$metta_occurrence_scope', Load, Load+1),
    ( current_transaction(_) -> metta_receipt_transaction_scope(Scope), Held = transaction
    ; Scope = Load, Held = load ),
    % Workaround: swi-cleanup-window - register receipt cleanup before trailing the load.
    setup_call_catcher_cleanup(
        true,
        metta_with_trailed('$metta_occurrence_load', Scope-Load, Goal), Catcher,
        catch(metta_finish_occurrence_load(Held, Scope, Load, Catcher), Ball,
              (metta_finish_occurrence_load(Held, Scope, Load, Catcher), throw(Ball)))).

metta_finish_occurrence_load(Held, Scope, Load, Catcher) :-
    ( Held == load -> metta_receipt_forget_scope(Scope)
    % policy-inventory-exempt: mechanism-internal; reason=exit and ! are SWI's completed cleanup outcomes; evidence=engine/spaces/receipts.pl:metta_finish_occurrence_load/4
    ; memberchk(Catcher, [exit, !]) -> true
    ; metta_receipt_request(forget_load(Load), done),
      retractall(metta_receipt_marker(Scope, Load)) ).

metta_receive_occurrences(_, [], []) :- !.
metta_receive_occurrences(Space, Incoming, Stored) :-
    nb_getval('$metta_occurrence_load', Scope-Load),
    findall(Portable,
            ( metta_native_pair(Space, _, Token, _),
              metta_token_portable(Token, Portable) ), Local),
    findall(Ref, metta_receipt_erased(Scope, Ref), Erased0), sort(Erased0, Erased),
    ( metta_receipt_reserved(Scope) -> true
    ; % Workaround: swi-cleanup-window - retain the engine obligation across native rollback.
      ( nb_current('$metta_occurrence_transaction', _-Owner),
        Owner = scope(Scope, _)
      -> nb_setarg(2, Owner, true)
      ; true ),
      assertz(metta_receipt_reserved(Scope)) ),
    % One marker owns this batch before any reservation can escape to the
    % standing engine. Rolling it back releases exactly these incoming rows.
    assertz(metta_receipt_marker(Scope, Load), Ref),
    metta_receipt_request(
        reserve(owner(Scope,Load), Ref, Space, Local, Erased, Incoming), Stored).

% The journal is itself transactional, so a nested rollback restores the
% parent's deletion set. No native clause reference survives outer completion.
metta_erase_storage_ref(Ref) :-
    (   current_transaction(_)
    ->  metta_receipt_transaction_scope(Scope),
        % Workaround: swi-cleanup-window - make the journal follow erasure even if its call port trips.
        sig_atomic((erase(Ref),
                    catch(assertz(metta_receipt_erased(Scope, Ref)), Ball,
                          (assertz(metta_receipt_erased(Scope, Ref)), throw(Ball)))))
    ;   erase(Ref)
    ).

metta_retract_storage(Head) :-
    (   current_transaction(_)
    ->  forall(clause(Head, true, Ref), metta_erase_storage_ref(Ref))
    ;   retractall(Head)
    ).

metta_receipt_transaction_scope(Scope) :-
    (   nb_current('$metta_occurrence_transaction', _-scope(Scope, _))
    ->  true
    ;   flag('$metta_occurrence_scope', Scope, Scope+1),
        metta_receipt_watch_transaction(none, Scope)
    ).

% Workaround: swi-query-frame-discarded-on-engine-destroy - transfer the owner to the nearest live transaction.
metta_receipt_watch_transaction(Finished, Scope) :-
    prolog_current_frame(Current),
    metta_receipt_nearest_frame(Current, Finished, Frame),
    ( Frame == none -> existence_error(transaction_frame, Current) ; true ),
    % This completion record outlives forall/2 and inner rollback. The native
    % transaction owns it; a local trail would end before that owner finishes.
    ( nb_current('$metta_occurrence_transaction', Owner),
      Owner = _-scope(Scope, _)
    -> nb_setarg(1, Owner, Frame)
    ; nb_setval('$metta_occurrence_transaction', Frame-scope(Scope, false)) ).

% Inspection marks its input FR_NOTIFY. Stop at a live transaction rather than
% marking the outer query, which discard_query notifies after its foreign frame
% has closed. On failure frameFailed leaves the completed frame in the live
% ancestry, so exclude it when transferring the watch [source:
% https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-wam.c#L902-L916
% and https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-trace.c#L2484-L2503;
% commit=8ca8a387fc61d0918484b19a1a3baf85b6523043].
% Workaround: swi-query-frame-discarded-on-engine-destroy - stop before the engine's outer query frame.
metta_receipt_nearest_frame(Current, Finished, Nearest) :-
    prolog_frame_attribute(Current, predicate_indicator, Predicate),
    ( Current \== Finished, metta_receipt_transaction_predicate(Predicate)
    -> Nearest = Current
    ; prolog_frame_attribute(Current, parent, Parent)
    -> metta_receipt_nearest_frame(Parent, Finished, Nearest)
    ; Nearest = none ).

metta_receipt_transaction_predicate(system:'$transaction'/2).
metta_receipt_transaction_predicate(system:'$transaction'/3).
metta_receipt_transaction_predicate(system:'$snapshot'/1).

metta_receipt_frame_finished(Frame) :-
    % Workaround: swi-cleanup-window - resume interrupted completion at a clean call port.
    catch(metta_receipt_finish_frame(Frame), Ball,
          ( thread_self(Me),
            thread_signal(Me, (spaces:metta_receipt_finish_frame(Frame), throw(Ball))) )).

metta_receipt_finish_frame(Frame) :-
    (   nb_current('$metta_occurrence_transaction', Frame-scope(Scope, _))
    ->  ( current_transaction(_)
        -> metta_receipt_watch_transaction(Frame, Scope)
        ; metta_receipt_forget_scope(Scope),
          nb_delete('$metta_occurrence_transaction') )
    ;   true
    ).

% The host can cut the listener before its catch starts. At that point the
% hook may report the enclosing native frame. Only schedule here: calling
% retirement from an exception hook would run it with an outstanding ball.
%
% The hook is DECLARED at load and CLAUSED by the first bound of the process:
% SWI consults prolog:prolog_exception_hook/5 on every ball the process
% throws once it holds a clause, one inference each, which
% engine/source_observation.pl measured at 119 on the engine's translate case
% and 2 per compiled host request, and only a bound can cut the listener. A
% process that never bounds keeps no clause and pays nothing per ball; a
% bounded one pays the inference on every ball it throws from its first bound
% on [tested: spaces_receipt_limits:the_limit_hook_is_armed_by_the_first_bound;
% commit=3ff7688a605c1f0de0e021f66f3075353476a992]. The clause is its own armed record: a trip on assertz/1's
% call port inside the mutex leaves nothing behind and the next bound arms it.
% The wrapper below is the arming point; the host's own limit predicate keeps
% its definition under the wrapper, so the deferral on its call port survives.
% Workaround: swi-cleanup-window - schedule reconciliation when a bound cuts an owned transaction.
:- multifile prolog:prolog_exception_hook/5.
:- dynamic prolog:prolog_exception_hook/5.
:- dynamic metta_receipt_bound_seen/0.
:- use_module(library(prolog_wrap), []).

% Every bounded call in the process runs the test in the wrapper's body, so
% the test is a dynamic fact and not a search for the clause it records:
% clause/2 over the hook costs four inferences against the fact's one, and the
% Python seat's hundred guarded queries read 38,407 with the search against
% 38,107 with the fact. The wrapper itself is the remaining 300, three
% inferences a bounded query: with this unit at its pre-wrapper state the same
% tree reads 37,807 [measured 2026-09-12: extensions/python/bench.py
% --counter-only query-limit-guarded, min of three fresh processes per arm,
% each after a boot that rebuilds the .qlf set; commit=WORKTREE].
metta_receipt_arm_limit_hook :-
    with_mutex('$metta_receipt_limit_hook', metta_receipt_arm_limit_hook_once).

% Under the mutex. The outer test is for the thread that was waiting on it and
% the inner one for a bound that was cut between the two assertions: the hook
% clause is the armed record and the fact is the memo of it, so a trip on
% either call port leaves a state the next bound completes and neither
% assertion can happen twice.
metta_receipt_arm_limit_hook_once :-
    (   metta_receipt_bound_seen
    ->  true
    ;   (   metta_receipt_limit_hook_armed
        ->  true
        ;   assertz((prolog:prolog_exception_hook(inference_limit_exceeded, _, _, _, _) :-
                         spaces:metta_receipt_schedule_reconciliation))
        ),
        assertz(metta_receipt_bound_seen)
    ).

metta_receipt_limit_hook_armed :-
    clause(prolog:prolog_exception_hook(inference_limit_exceeded, _, _, _, _),
           spaces:metta_receipt_schedule_reconciliation).

metta_receipt_schedule_reconciliation :-
    nb_current('$metta_occurrence_transaction', _-scope(Scope, _)),
    thread_self(Me),
    thread_signal(Me, spaces:metta_receipt_reconcile_scope(Scope)),
    fail.

% Installed once per process; a second consult finds the wrapper in place. The
% library is named on the call rather than imported, so a reader of this
% directive resolves both goals of the body it installs.
:- (   prolog_wrap:current_predicate_wrapper('$syspreds':call_with_inference_limit(_, _, _),
                                             metta_receipt_first_bound, _, _)
   ->  true
   ;   prolog_wrap:wrap_predicate('$syspreds':call_with_inference_limit(_, _, _),
                                  metta_receipt_first_bound, Bounded,
                                  ( (   spaces:metta_receipt_bound_seen
                                    ->  true
                                    ;   spaces:metta_receipt_arm_limit_hook
                                    ),
                                    Bounded ))
   ).

metta_receipt_reconcile_scope(Scope) :-
    ( nb_current('$metta_occurrence_transaction', _-scope(Scope, Reserved))
    -> ( current_transaction(_)
       -> metta_receipt_watch_transaction(none, Scope),
          ( Reserved == true
          -> metta_receipt_request(claims(Scope), Claims),
             forall(member(Claim, Claims),
                    ( clause(metta_receipt_marker(Scope, _), true, Claim)
                    -> true
                    ; metta_receipt_request(forget_claim(Claim), done) ))
          ; true )
       ; metta_receipt_forget_scope(Scope),
         nb_delete('$metta_occurrence_transaction') )
    ; true ).

metta_receipt_forget_scope(Scope) :-
    % Workaround: swi-cleanup-window - release the reservation before removing its retry record.
    ( ( metta_receipt_reserved(Scope)
      ; nb_current('$metta_occurrence_transaction', _-scope(Scope, true)) )
    -> metta_receipt_request(forget_scope(Scope), done),
       retractall(metta_receipt_reserved(Scope))
    ; true ),
    retractall(metta_receipt_marker(Scope, _)),
    retractall(metta_receipt_erased(Scope, _)).

% A rolled-back marker no longer decodes. Its reference was attached while
% live, so rollback only compares identity and never inspects the dead clause.
metta_receipt_marker_changed(Action, Ref) :-
    % Workaround: swi-cleanup-window - finish a cut marker notification outside its native query.
    catch(metta_receipt_marker_change(Action, Ref), Ball,
          ( thread_self(Me),
            thread_signal(Me, (spaces:metta_receipt_marker_change(Action, Ref), throw(Ball))) )).

metta_receipt_marker_change(rollback(assertz), Ref) :-
    !, metta_receipt_request(forget_claim(Ref), done).
metta_receipt_marker_change(retract, Ref) :-
    !, metta_receipt_request(forget_claim(Ref), done).
metta_receipt_marker_change(_, _).

metta_receipt_request(Request, Reply) :-
    with_mutex('$metta_occurrence_receipts',
        engine_post('$metta_occurrence_receipts', Request, Outcome)),
    ( Outcome = replied(Reply) -> true
    ; Outcome = raised(Error) -> throw(Error)
    ; throw(error(metta_occurrence_reservation_failed(Request), none)) ).

% The standing engine has no transaction and sees committed rows that the
% caller's old snapshot cannot see. It never takes its caller's mutex.
metta_receipt_loop :-
    repeat,
      engine_fetch(Request),
      ( catch(metta_receipt_apply(Request, Reply), Error, true)
      -> ( var(Error) -> Outcome = replied(Reply) ; Outcome = raised(Error) )
      ; Outcome = failed ),
      engine_yield(Outcome),
    fail.

metta_receipt_apply(reserve(owner(Scope,Load), Claim, Space, Local, Erased, Incoming), Stored) :-
    findall(Portable,
            ( metta_native_pair(Space, _, Token, Ref),
              \+ ord_memberchk(Ref, Erased), metta_token_portable(Token, Portable)
            ; metta_receipt_pending(Space, Portable, owner(Owner,_), _), Owner \== Scope ),
            Other),
    append(Local, Other, Existing), sort(Existing, Keys),
    maplist(metta_receipt_key, Keys, Pairs), ord_list_to_assoc(Pairs, Index),
    maplist(metta_receipt_reserve(owner(Scope,Load), Claim, Space, Index), Incoming, Stored).
metta_receipt_apply(forget_scope(Scope), done) :-
    retractall(metta_receipt_pending(_, _, owner(Scope,_), _)).
metta_receipt_apply(claims(Scope), Claims) :-
    findall(Claim, metta_receipt_pending(_, _, owner(Scope,_), Claim), All),
    sort(All, Claims).
metta_receipt_apply(forget_load(Load), done) :-
    retractall(metta_receipt_pending(_, _, owner(_,Load), _)).
metta_receipt_apply(forget_claim(Claim), done) :-
    retractall(metta_receipt_pending(_, _, _, Claim)).

metta_receipt_key(Token, Token-true).
metta_receipt_reserve(Owner, Ref, Space, Index, Token, Stored) :-
    ( get_assoc(Token, Index, _) -> true
    ; assertz(metta_receipt_pending(Space, Token, Owner, Ref)),
      Stored = Token ).

metta_boot_receipts :-
    flag('$metta_occurrence_receipts_ready', Ready, Ready),
    ( Ready == 1 -> true
    ; engine_create(_, spaces:metta_receipt_loop, _,
                    [alias('$metta_occurrence_receipts')]),
      prolog_listen(frame_finished, spaces:metta_receipt_frame_finished,
                    [name(metta_occurrence_transaction)]),
      prolog_listen(metta_receipt_marker/2, spaces:metta_receipt_marker_changed,
                    [name(metta_occurrence_rollback)]),
      flag('$metta_occurrence_receipts_ready', _, 1) ).

:- metta_boot_receipts.
