% Purpose: reserve incoming occurrence identities across transaction views.
% Assumes: native erasures use metta_erase_storage_ref/1 or metta_retract_storage/1.
% Guarantees: overlapping image receipts retain distinct tokens, while a load
%   into an empty destination preserves its tokens [tested: spaces_token_images;
%   commit=8ca8a387fc61d0918484b19a1a3baf85b6523043].
%   A completed inner transaction transfers its scope to the live outer one;
%   destroying its suspended engine does not notify a discarded query frame
%   [tested: spaces_receipt_frames; commit=8ca8a387fc61d0918484b19a1a3baf85b6523043].
% Owns resources: one standing engine; reservations and erased references last
%   only until their enclosing load or transaction finishes. Nested rollback
%   releases its reservations [tested: spaces_token_images; commit=8ca8a387fc61d0918484b19a1a3baf85b6523043].
% Guarded by: '$metta_occurrence_receipts' serializes requests to the engine.
% Guarantees: metta_retract_storage/1 resolves the receipt owner after its first
%   successful erase and reuses it for that logical-update snapshot, preserving
%   each erase, callback and transactional receipt in order
%   [tested: source_retirement, spaces_receipt_frames; commit=e246959279271d22f166a1c8fb1840896295a020].

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
    ( nb_current('$metta_occurrence_load', Previous) -> Prior = some(Previous)
    ; Prior = none ),
    setup_call_catcher_cleanup(
        nb_setval('$metta_occurrence_load', Scope-Load),
        call(Goal), Catcher,
        ( ( Held == load -> metta_receipt_forget_scope(Scope)
          % policy-inventory-exempt: mechanism-internal; reason=exit and ! are the two catcher values setup_call_catcher_cleanup/4 hands a goal that completed, beside exception, fail and external; evidence=engine/spaces/receipts.pl:metta_with_occurrence_load/1
          ; memberchk(Catcher, [exit, !]) -> true
          ; metta_receipt_request(forget_load(Load), done),
            retractall(metta_receipt_marker(Scope, Load)) ),
          ( Prior = some(Saved) -> nb_setval('$metta_occurrence_load', Saved)
          ; nb_delete('$metta_occurrence_load') ) )).

metta_receive_occurrences(_, [], []) :- !.
metta_receive_occurrences(Space, Incoming, Stored) :-
    nb_getval('$metta_occurrence_load', Scope-Load),
    findall(Portable,
            ( metta_native_pair(Space, _, Token, _),
              metta_token_portable(Token, Portable) ), Local),
    findall(Ref, metta_receipt_erased(Scope, Ref), Erased0), sort(Erased0, Erased),
    ( metta_receipt_reserved(Scope) -> true
    ; assertz(metta_receipt_reserved(Scope)) ),
    % One marker owns this batch before any reservation can escape to the
    % standing engine. Rolling it back releases exactly these incoming rows.
    assertz(metta_receipt_marker(Scope, Load), Ref),
    metta_receipt_request(
        reserve(owner(Scope,Load), Ref, Space, Local, Erased, Incoming), Stored).

% The journal is itself transactional, so a nested rollback restores the
% parent's deletion set. No native clause reference survives outer completion.
metta_erase_storage_ref(Ref) :-
    erase(Ref),
    (   current_transaction(_)
    ->  metta_receipt_transaction_scope(Scope),
        assertz(metta_receipt_erased(Scope, Ref))
    ;   true
    ).

% The local cell survives forall's backtracking, but cannot outlive this
% retirement call. Resolve only after erase succeeds, as the single-reference
% door does: a throwing or failing callback has not published a receipt yet.
% The surrounding transaction cannot finish while its traversal is running;
% nested callback transactions keep the same owner and transactional journal.
metta_retract_storage(Head) :-
    (   current_transaction(_)
    ->  Context = receipt_scope(_),
        forall(clause(Head, true, Ref),
               ( erase(Ref),
                 arg(1, Context, Scope),
                 ( nonvar(Scope) -> true
                 ; metta_receipt_transaction_scope(Owner),
                   nb_setarg(1, Context, Owner), Scope = Owner ),
                 assertz(metta_receipt_erased(Scope, Ref)) ))
    ;   retractall(Head)
    ).

metta_receipt_transaction_scope(Scope) :-
    (   nb_current('$metta_occurrence_transaction', _-Scope)
    ->  true
    ;   flag('$metta_occurrence_scope', Scope, Scope+1),
        metta_receipt_watch_transaction(none, Scope)
    ).

% Workaround: swi-query-frame-discarded-on-engine-destroy - transfer the owner to the nearest live transaction.
metta_receipt_watch_transaction(Finished, Scope) :-
    prolog_current_frame(Current),
    metta_receipt_nearest_frame(Current, Finished, Frame),
    ( Frame == none -> existence_error(transaction_frame, Current) ; true ),
    nb_setval('$metta_occurrence_transaction', Frame-Scope).

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
    (   nb_current('$metta_occurrence_transaction', Frame-Scope)
    ->  ( current_transaction(_)
        -> metta_receipt_watch_transaction(Frame, Scope)
        ; nb_delete('$metta_occurrence_transaction'),
          metta_receipt_forget_scope(Scope) )
    ;   true
    ).

metta_receipt_forget_scope(Scope) :-
    ( retract(metta_receipt_reserved(Scope))
    -> metta_receipt_request(forget_scope(Scope), done)
    ; true ),
    retractall(metta_receipt_marker(Scope, _)),
    retractall(metta_receipt_erased(Scope, _)).

% A rolled-back marker no longer decodes. Its reference was attached while
% live, so rollback only compares identity and never inspects the dead clause.
metta_receipt_marker_changed(rollback(assertz), Ref) :-
    !, metta_receipt_request(forget_claim(Ref), done).
metta_receipt_marker_changed(retract, Ref) :-
    !, metta_receipt_request(forget_claim(Ref), done).
metta_receipt_marker_changed(_, _).

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
