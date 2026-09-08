% Purpose: reserve incoming occurrence identities across transaction views.
% Assumes: native erasures use metta_erase_storage_ref/1 or metta_retract_storage/1.
% Guarantees: overlapping image receipts retain distinct tokens, while a load
%   into an empty destination preserves its tokens [tested: spaces_token_images;
%   commit=7f00ac7932fefa6f380fc8d14ec583ea0c58eff4].
% Owns resources: one standing engine; reservations and erased references last
%   only until their enclosing load or transaction finishes. Nested rollback
%   releases its reservations [tested: spaces_token_images; commit=7f00ac7932fefa6f380fc8d14ec583ea0c58eff4].
% Guarded by: '$metta_occurrence_receipts' serializes requests to the engine.

:- dynamic metta_receipt_pending/4, metta_receipt_marker/2,
           metta_receipt_erased/2.
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
          ; memberchk(Catcher, [exit, !]) -> true
          ; metta_receipt_request(forget_load(Load), done),
            retractall(metta_receipt_marker(Scope, Load)) ),
          ( Prior = some(Saved) -> nb_setval('$metta_occurrence_load', Saved)
          ; nb_delete('$metta_occurrence_load') ) )).

metta_receive_occurrences(Space, Incoming, Stored) :-
    nb_getval('$metta_occurrence_load', Scope-Load),
    findall(Portable,
            ( metta_native_pair(Space, _, Token, _),
              metta_token_portable(Token, Portable) ), Local),
    findall(Ref, metta_receipt_erased(Scope, Ref), Erased0), sort(Erased0, Erased),
    metta_receipt_request(reserve(Scope, Load, Space, Local, Erased, Incoming), Decisions),
    maplist(metta_receipt_accept(Scope, Load), Decisions, Stored).

metta_receipt_accept(_, _, fresh, _).
metta_receipt_accept(Scope, Load, kept(Token, Claim), Stored) :-
    assertz(metta_receipt_marker(Scope, Load), Ref),
    metta_receipt_request(attach_claim(Claim, Ref), done),
    metta_token_receive(Token, Stored).

% The journal is itself transactional, so a nested rollback restores the
% parent's deletion set. No native clause reference survives outer completion.
metta_erase_storage_ref(Ref) :-
    erase(Ref),
    (   current_transaction(_)
    ->  metta_receipt_transaction_scope(Scope),
        assertz(metta_receipt_erased(Scope, Ref))
    ;   true
    ).

metta_retract_storage(Head) :-
    (   current_transaction(_)
    ->  forall(clause(Head, true, Ref), metta_erase_storage_ref(Ref))
    ;   retractall(Head)
    ).

metta_receipt_transaction_scope(Scope) :-
    (   nb_current('$metta_occurrence_transaction', _-Scope)
    ->  true
    ;   prolog_current_frame(Current),
        metta_receipt_outer_frame(Current, none, Frame),
        ( Frame == none -> existence_error(transaction_frame, Current) ; true ),
        flag('$metta_occurrence_scope', Scope, Scope+1),
        nb_setval('$metta_occurrence_transaction', Frame-Scope)
    ).

% These are the three native transaction frames in SWI's transaction/1,2,3
% and snapshot/1. Their frame_finished event follows commit or discard.
% https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-transaction.c
metta_receipt_outer_frame(Frame, Prior, Outer) :-
    prolog_frame_attribute(Frame, predicate_indicator, Predicate),
    ( memberchk(Predicate, [system:'$transaction'/2, system:'$transaction'/3,
                           system:'$snapshot'/1]) -> Found = Frame ; Found = Prior ),
    ( prolog_frame_attribute(Frame, parent, Parent)
    -> metta_receipt_outer_frame(Parent, Found, Outer)
    ; Outer = Found ).

metta_receipt_frame_finished(Frame) :-
    (   nb_current('$metta_occurrence_transaction', Frame-Scope)
    ->  nb_delete('$metta_occurrence_transaction'),
        metta_receipt_forget_scope(Scope)
    ;   true
    ).

metta_receipt_forget_scope(Scope) :-
    metta_receipt_request(forget_scope(Scope), done),
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

metta_receipt_apply(reserve(Scope, Load, Space, Local, Erased, Incoming), Decisions) :-
    findall(Portable,
            ( metta_native_pair(Space, _, Token, Ref),
              \+ ord_memberchk(Ref, Erased), metta_token_portable(Token, Portable)
            ; metta_receipt_pending(Space, Portable, owner(Owner,_), _), Owner \== Scope ),
            Other),
    append(Local, Other, Existing), sort(Existing, Keys),
    maplist(metta_receipt_key, Keys, Pairs), ord_list_to_assoc(Pairs, Index),
    maplist(metta_receipt_reserve(owner(Scope,Load), Space, Index), Incoming, Decisions).
metta_receipt_apply(forget_scope(Scope), done) :-
    retractall(metta_receipt_pending(_, _, owner(Scope,_), _)).
metta_receipt_apply(forget_load(Load), done) :-
    retractall(metta_receipt_pending(_, _, owner(_,Load), _)).
metta_receipt_apply(attach_claim(Claim, Ref), done) :-
    retract(metta_receipt_pending(Space, Token, Owner, Claim)),
    assertz(metta_receipt_pending(Space, Token, Owner, Ref)).
metta_receipt_apply(forget_claim(Claim), done) :-
    retractall(metta_receipt_pending(_, _, _, Claim)).

metta_receipt_key(Token, Token-true).
metta_receipt_reserve(Scope, Space, Index, Token, Decision) :-
    ( get_assoc(Token, Index, _) -> Decision = fresh
    ; flag('$metta_occurrence_claim', Claim, Claim+1),
      assertz(metta_receipt_pending(Space, Token, Scope, Claim)),
      Decision = kept(Token, Claim) ).

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
