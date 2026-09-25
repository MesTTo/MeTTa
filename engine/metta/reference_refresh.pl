% Purpose: publish changed reference faces and repair native links on rollback.
% Assumes: references.pl owns reference rows, faces, bindings and visibility.
% Guarantees: adding an importer publishes no existing sibling; changing a
%   provider publishes its affected importers
%   [tested: reference_publication; commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Guarantees: a face event whose effect the face value carries marks the face,
%   so an event that leaves it resolving the same recompiles no caller; an
%   event whose effect the value does not carry (settledness, release, a
%   completion after rollback) walks the face's dependents as before
%   [tested: references:a_face_that_resolves_the_same_recompiles_no_caller,
%   references:one_face_publication_recompiles_a_shared_caller_once,
%   reference_loading, release_preparation, specializer_invalidation;
%   commit=7472c49077c10a069876b88f1e154a5122820612].
% Guarantees: patterned references participate in demand, publication and
%   rollback through their original defining home
%   [tested: reference_patterns; commit=a95e6c90c910db30c72311abadd58dee5349978c].
% Guarantees: nested completion transfers mutation roots to the live parent,
%   then reconciles bindings against rows surviving the transaction
%   [tested: references:rollback_restores_native_links_and_nested_rollback_restores_its_parent,
%   references:inner_failure_transfers_one_watch_and_outer_completion_retires_it;
%   commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Guarantees: a completion inside a source program or definition batch queues
%   its spaces and leaves publication to the program's flush [tested:
%   test_class_method_costs:test_a_class_definition_publishes_its_references_once,
%   extensions/python/tests/ch15_writing_transactions_and_worlds/test_transaction.py;
%   commit=a8b3ad6e372c077945b36da93ed631f0a45d11fb].
% Guarantees: inference cuts cannot abandon a registered reference frame or
%   its reconciliation [tested:
%   references:an_inference_cut_cannot_abandon_reference_completion;
%   commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Guarantees: a space set's inference cost does not depend on the spaces'
%   names, it lists its members once each in standard order, and consuming a
%   published batch leaves pending the spaces queued since [tested:
%   references:a_space_set_costs_the_same_whatever_its_spaces_are_named,
%   references:consuming_published_spaces_keeps_the_ones_queued_since;
%   commit=d4a365c16bdf1801f9839597e56ecfcc8c2b7a0c].
% Guarantees: a space whose change since its last final publication is only
%   from rows declared into it is published by those rows alone, and whole
%   when any other event touched it, when a row it owes is gone, when its
%   internal names moved, when a space its standing rows reach is published
%   in the same drain, when a walk outside the drains that publish it reached
%   one of its rows, or when the rows would withdraw a source origin; a frame
%   that committed only such rows finishes its bindings and republishes its
%   importers without walking its face [tested:
%   reference_deltas:every_step_of_a_row_sequence_publishes_what_a_whole_republication_does,
%   reference_deltas:rows_after_the_first_are_published_alone,
%   reference_deltas:a_row_publishes_alone_whichever_way_its_space_and_home_sort,
%   reference_deltas:a_reached_home_in_the_same_drain_sends_the_rows_whole,
%   reference_deltas:a_row_walked_outside_its_drain_owes_its_space_whole;
%   commit=e4b7448d1f1bd98733f1b04c3906aaa42f35ef1a].
% Owns resources: the pending faces and each transaction frame's roots are
%   tries whose handles engine-local SWI global variables hold. Publication
%   destroys the pending trie it consumed and stores a fresh one holding the
%   spaces that stay, or none when none do; completion retires its frame and
%   destroys the frame's trie; a trie whose handle nothing holds any more is
%   reclaimed by atom garbage collection.
%   host_transaction_on_exit/1 invokes completion after SWI releases its
%   global event mutex [tested: host_transaction_completion; commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Guarded by: with_typing_policy_stable/1 serializes native publication. Maps
%   run outside that mutex and the support graph mutex; an epoch change retries
%   their publication against the current rows
%   [source: engine/metta/reference_refresh.pl:metta_reference_refresh_now/0;
%   commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].

:- use_module(library(ordsets), [ord_subtract/3]).
:- multifile support_graph:support_invalidation_action/1.

% The graph already fixes the affected forward closure before notifying its
% owners. Keep a publication queue, as filereader's compiled-function owner
% does, rather than traversing all known spaces or maintaining a second graph.
support_graph:support_invalidation_action(derived(Module, reference_face)) :-
    metta_reference_seen_space(Space, Module),
    metta_reference_queue(Space).
%A row's node is invalidated when its home's face moves, which moves what the
%row contributes, so the space the row belongs to owes a whole publication.
%It owes nothing when the walk is one a drain raises while it publishes and
%the space is one it publishes: every face and entry the drain publishes was
%read in one epoch, so a home stabilizing reaches only rows whose entries
%already hold what it moved to, the reason the drain consumes the queue
%entries the same walk makes (metta_reference_consumed/1). A standing row
%whose home the drain republishes sends its space whole before any walk
%(metta_reference_drain_unreached/3); a row published beside its home, whose
%first publication walks it, is the one this spares, and without it the rows
%of a space ordered before their homes went whole at the next publication.
support_graph:support_invalidation_action(derived(Module, reference_row(_))) :-
    metta_reference_seen_space(Space, Module),
    (   nb_current('$metta_reference_draining', Draining),
        memberchk(Space, Draining)
    ->  true
    ;   metta_reference_owe(Space, whole)
    ).

%What a space's next publication owes since its last final one, the one made
%outside every transaction. A face is the union of the space's own heads and
%of its from rows' entries, and bindings, metadata, source names, demand and
%grades are views over the face's entries, so a from row arriving changes all
%of them by its own entries, and a publication that knows the rows can apply
%exactly that. It cannot tell anything else from a mark, so every other event
%owes the space whole. SWI's monotonic tabling makes the same division for a
%table over dynamic facts: an assert propagates the new answers without
%recomputing the table, a retract invalidates it for re-evaluation, and the
%lazy form queues the answer with its dependency until the table is next
%asked [source: swipl-devel man/tabling.plx sections tabling-monotonic and
%tabling-monotonic-lazy, and boot/tabling.pl mon_propagate/3, at
%69775434c8226897626b226aefcc8266499f1e2e].
%
%The ledger is facts that an event only ever adds, so two threads declaring
%rows into one space cannot lose either row, and a publication retracts only
%what it published. metta_reference_owed_row/3 is a row, `new` until
%published and `applied` once a publication inside a still-open transaction
%published it with provisional bindings; metta_reference_owed_head/2 is a head
%such a publication bound, which the final publication binds again;
%metta_reference_owed_whole/1 is anything else. No fact means nothing
%changed since the last final publication. A space never published has no
%face to apply rows to, so its first publication is whole whatever it owes
%(metta_reference_owed_rows/4). Not journaled, as a binding is not: a
%transaction that rolls back takes its rows with it, and a publication that
%finds one of them gone publishes whole.
:- dynamic metta_reference_owed_whole/1, metta_reference_owed_row/3,
           metta_reference_owed_head/2.
:- volatile metta_reference_owed_whole/1, metta_reference_owed_row/3,
            metta_reference_owed_head/2.
:- '$notransact'(metta_reference_owed_whole/1).
:- '$notransact'(metta_reference_owed_row/3).
:- '$notransact'(metta_reference_owed_head/2).

metta_reference_owe(Space, row(Token)) :- !,
    (   metta_reference_owed_whole(Space)
    ->  true
    ;   assertz(metta_reference_owed_row(Space, Token, new))
    ).
metta_reference_owe(Space, whole) :-
    (   metta_reference_owed_whole(Space)
    ->  true
    ;   assertz(metta_reference_owed_whole(Space))
    ).

%The rows a space owes and the heads a provisional publication bound, when it
%owes nothing whole and some row.
metta_reference_owed_ledger(Space, New, Applied, Touched) :-
    \+ metta_reference_owed_whole(Space),
    findall(Token, metta_reference_owed_row(Space, Token, new), New),
    findall(Token, metta_reference_owed_row(Space, Token, applied), Applied),
    ( New \== [] ; Applied \== [] ), !,
    findall(Key, metta_reference_owed_head(Space, Key), Touched0),
    sort(Touched0, Touched).

%The pending queue and each transaction frame's roots are sets of spaces, and
%a set of spaces is a trie. Its handle is an atom, so a global variable holds
%the set itself rather than a copy of it, and no findall or failing branch can
%reclaim it, which a set stored as a term had to be copied into the variable
%to survive. Its membership check is one foreign call, where library(nb_set)
%probed in Prolog and cost more for a space whose name, the path of its file,
%hashed onto a taken slot (support_graph.pl's support_invalidate_closure/2
%measures what that cost).
metta_reference_set_add(Set, Space) :-
    (   trie_insert(Set, Space) -> true ; true ).

metta_reference_set_spaces(Set, Spaces) :-
    findall(Space, trie_gen(Set, Space), Members),
    sort(Members, Spaces).

metta_reference_queue(Space) :-
    (   nb_current('$metta_reference_pending', Pending)
    ->  true
    ;   trie_new(Pending), nb_setval('$metta_reference_pending', Pending)
    ),
    metta_reference_set_add(Pending, Space),
    metta_reference_source_queued(Space).

metta_reference_pending(Spaces) :-
    (   nb_current('$metta_reference_pending', Pending)
    ->  metta_reference_set_spaces(Pending, Spaces)
    ;   Spaces = []
    ).

% Spaces queued while the consumed ones were being published stay pending, in a
% set of their own.
% Workaround: swi-trie-gen-empty-hashed-root - build the spaces that stay into a fresh trie instead of deleting the consumed ones from this one.
% The next publication enumerates this set, and trie_gen/2 dies of SIGSEGV on
% a trie that trie_delete/3 emptied of two keys or more.
metta_reference_consumed(Spaces) :-
    metta_reference_pending(Queued),
    ord_subtract(Queued, Spaces, Remaining),
    (   nb_current('$metta_reference_pending', Pending)
    ->  nb_delete('$metta_reference_pending'),
        trie_destroy(Pending)
    ;   true
    ),
    (   Remaining == []
    ->  true
    ;   trie_new(Fresh),
        forall(member(Space, Remaining), metta_reference_set_add(Fresh, Space)),
        nb_setval('$metta_reference_pending', Fresh)
    ).

%A face event invalidates in one of two ways, and which one is decided by a
%single question: does the face's stored value carry everything this event
%changed for the nodes that resolved a name through the face?
%
%  MARK (metta_reference_mark/1) when it does. The face is dirtied without
%  walking, the next refresh recomputes it, and support_stabilize/3 in
%  metta_reference_stabilize_face/3 walks its dependents only if the value
%  moved. A row arriving or leaving, a Prolog head registering in a home, a
%  visibility grade, an equation or a declaration: each moves which name
%  resolves to which root or how visible it is, and the value is
%  face(Own, Public), which holds both.
%
%  WALK (metta_reference_invalidate/1) when it does not, which is three kinds
%  of event. SETTLEDNESS: a background load finishing or a deferred head
%  materialising changes whether a root is settled, which an importer reads
%  live when it binds (metta_reference_unsettled/2) and the value does not
%  hold. EXISTENCE: a released space is never republished, so there is no
%  comparison to make. HISTORY: a transaction's completion follows a rollback
%  that rewound the stored value, a transactional row, and left the imports
%  and wrappers its publication moved, which are not, so the rewound value
%  compares equal to the recomputed one while the bindings disagree with both.
%
%The deferred-materialisation walk is also a matter of TIME. It runs while a
%specialization's body is translating, and a specialization's invalidation
%action forgets it rather than rebuilding it
%[source: engine/specializer.pl, support_invalidation_action(specialization(_, _))].
%Marked, the wave would arrive at the next refresh, after the specialization
%was built against the settled head, and would delete the one the running call
%had already emitted, so the call answered nothing where it answers 2
%[tested: specializer_invalidation:a_specialization_invalidated_while_it_translates_is_rebuilt_once].
%
%What the mark saves is the walk's waste: N events that change nothing, with M
%compiled callers resolving through the face, recompiled every caller at every
%event. recompile_function_in_module/2 ran exactly M*N times -- 256 calls at
%M=16 N=16, 4 at M=4 N=1, with no spread anywhere in a sweep of M in 4, 8, 16
%and N in 1, 4, 8, 16 metta_reference_changed/1 calls on an unchanged home --
%and runs 0 times at every point of the same sweep once these events mark
%[measured 2026-09-23;
%tested: references:a_face_that_resolves_the_same_recompiles_no_caller].
metta_reference_changed(Space) :-
    metta_reference_changed(Space, whole).

%Change is row(Token) when the event is the from row Token arriving, which a
%publication can apply alone, and whole for every other event.
metta_reference_changed(Space, Change) :-
    (   metta_reference_refreshing
    ->  true
    ;   metta_reference_face_event(metta_reference_mark, Space, Change),
        ( filereader:active_source_program(_)
        -> true
        ; metta_reference_refresh )
    ).

% A binding the drain installs announces a function change in the importer;
% that is the refresh's own work and must not re-queue the face it publishes.
metta_reference_definition_changed(Space) :-
    (   metta_reference_refreshing
    ->  true
    ;   metta_reference_face_event(metta_reference_mark, Space, whole)
    ).

% A change the refresh did not make, such as a deferred function a repair
% forced into its physical arity, is queued even while a drain runs; the
% drain's loop reads the queue again after each publication.
metta_reference_face_changed(Space) :-
    metta_reference_face_event(metta_reference_invalidate, Space, whole).

metta_reference_face_event(Invalidate, Space, Change) :-
    metta_reference_track_transaction([Space]),
    metta_reference_owe(Space, Change),
    call(Invalidate, [Space]),
    filereader:source_definition_arrived('$metta_reference_face').

metta_reference_mark(Spaces) :-
    metta_reference_face_roots(Spaces, Roots),
    forall(member(Root, Roots), support_graph:support_invalidate_node(Root)).

metta_reference_invalidate(Spaces) :-
    forall(member(Space, Spaces), metta_reference_owe(Space, whole)),
    metta_reference_face_roots(Spaces, Roots),
    metta_with_trailed_enumeration('$metta_reference_face_wave', true,
                                   support_graph:support_invalidate_many(Roots)).

metta_reference_face_roots(Spaces, Roots) :-
    flag('$metta_reference_epoch', Epoch, Epoch+1),
    findall(derived(Module, reference_face),
            ( member(Space, Spaces), metta_reference_seen_space(Space, Module) ),
            Roots).

%The invalidation wave running now is a reference face's, raised either by a
%walking event or by the republication of a marked face whose value moved. It
%dirties every node that resolved a name through the face, so the repair
%recompiles them against whatever the face resolves to next, and says nothing
%about whether a definition moved: a head whose binding
%the refresh then changes announces itself, and that announcement's wave
%starts at the head. A cache keyed on behaviour rather than resolution,
%lib_tabling's table node, ignores this wave and follows that one, which is
%what keeps a table through the first compile of a deferred library function
%in a space holding a `from` row
%[tested: test_a_reference_refresh_that_changes_nothing_keeps_the_table;
%commit=0cb96b1823038ffb8084168a7103dfac9eef0daa].
metta_reference_face_wave :-
    nb_current('$metta_reference_face_wave', true).

metta_reference_refresh :-
    (   metta_reference_refreshing
    ->  true
    ;   metta_with_trailed_enumeration('$metta_reference_refreshing', true,
                                      metta_reference_refresh_now)
    ).

%A publication after a space's k-th from row used to republish all k: every
%row's node, every home's face filtered again, every head's standing check,
%every entry's metadata and the source plan over the whole face, and the
%space's grades over all its rows, so n rows cost Θ(n²) row republications.
%A space that owes only rows is published by them alone: their nodes, their
%homes' faces and the heads whose roots they change, so n rows cost Θ(n).
%A row costs its own publication, fixed but for a share per head it brings,
%and republishing whole cost the second row 3,899 inferences more than
%publishing it alone and the seventh 13,941 more, about 2,010 more a row,
%the part that grew [measured 2026-09-24: 13-class_decorators' seven from
%rows priced prefix by prefix through tests/fixtures/parity_driver.pl on the
%tree before this change and with it in one battery path cost 125,936
%inferences whole and 70,659 by rows, a row by rows 6,855 for a home bringing
%no head up to 16,429 for one bringing four, and the program reads 105.5M
%instructions net of its null where it read 153.5M; commit=e4b7448d1f1bd98733f1b04c3906aaa42f35ef1a].
metta_reference_refresh_now :-
    metta_reference_pending(Pending),
    (   Pending == []
    ->  true
    ;   flag('$metta_reference_epoch', Version, Version),
        findall(Space-Module,
                ( member(Space, Pending), metta_reference_seen_space(Space, Module) ),
                Spaces),
        forall(member(Space-_, Spaces), metta_reference_watch(Space)),
        % What each space owes is read before any is prepared, and the rows'
        % entries after every space's grades are, as a whole face is.
        findall(Space-Module-Owed,
                ( member(Space-Module, Spaces),
                  metta_reference_owed_rows(Space, Module, Pending, Owed) ), Owing),
        forall(member(Space-_-Owed, Owing), metta_reference_prepare(Owed, Space)),
        findall(Space-Module-Publication,
                ( member(Space-Module-Owed, Owing),
                  metta_reference_publication(Owed, Space, Module, Publication) ),
                Publications),
        findall(Space-Module-Face,
                member(Space-Module-publication(Face, _, _, _), Publications), Faces),
        metta_reference_binding_context(Faces, Publications, Context),
        % Publish all bindings and metadata before repairing a shared caller.
        % A defining home's face may be needed to select its own closure;
        % reading that context does not publish the unmodified home.
        % The spaces this drain refreshes, read by the publication loop: a
        % head imported from one of them is rebound and announced even when
        % its roots are unchanged, because the home's definitions may have.
        b_setval('$metta_reference_draining', Pending),
        with_typing_policy_stable(support_graph:with_support_repairs_deferred(
            ( flag('$metta_reference_epoch', Current, Current),
              ( Current =:= Version
              -> findall(Space-Module,
                         member(Space-Module-publication(_, _, _, whole(_)), Publications),
                         Wholes),
                 metta_reference_demand_names(Wholes, PreviousDemand),
                 forall(member(Space-Module-Publication, Publications),
                        metta_reference_publish(Publication, Space, Module, Context)),
                 findall(Space-Module-Demanding,
                         member(Space-Module-publication(_, Demanding, _, _), Publications),
                         Demands),
                 metta_reference_publish_demand(Demands, PreviousDemand),
                 forall(member(Space-_-Publication, Publications),
                        metta_reference_publish_views(Publication, Space)),
                 % Stabilization can notify another member of this batch.
                 % Every batch face already describes the same row epoch.
                 % Consume those notifications and retain newly affected homes.
                 metta_reference_consumed(Pending),
                 forall(member(Space-_-Publication, Publications),
                        metta_reference_settle(Publication, Space)),
                 Result = published
              ; Result = changed ) ))),
        b_setval('$metta_reference_draining', []),
        ( Result == published
        -> forall(support_graph:support_repair_invalidations, true)
        ; true ),
        metta_reference_refresh_now
    ).

%What a space owes, read before any space is prepared: the rows its ledger
%holds, when every one still stands, the space has a published face and
%source plan to apply them to, its internal names are the ones its last whole
%grading saw, and no space its standing rows reach is being published in the
%same drain; whole otherwise. A row a rollback took is a retraction, and a
%delta applies insertions only, as monotonic tabling propagates an assert and
%invalidates on a retract. A name turning internal changes the grades of the
%rows it heads and so the face's public half, which only a whole publication
%recomputes. A reached space the drain publishes may move its face under the
%entries the standing rows already contributed, and the drain consumes the
%notice its stabilization would send, so only a whole face reads it again; a
%space publishing for the first time cannot be reached by rows older than the
%drain, since a home is queued when its first row is declared.
metta_reference_owed_rows(Space, Module, Pending, Owed) :-
    (   metta_reference_owed_ledger(Space, New, Applied, Touched),
        metta_reference_rows_standing(Space, New, Applied),
        metta_reference_drain_unreached(Space, New, Pending),
        metta_reference_graded(Space, Internal),
        metta_reference_graded_names(Space, Internal),
        support_graph:support_stabilized(derived(Module, reference_face),
                                         face(Face0, Public0)),
        metta_reference_plan(Space, Plan0)
    ->  Owed = rows(New, Applied, Touched, Face0, Public0, Plan0)
    ;   Owed = whole
    ).

metta_reference_rows_standing(Space, New, Applied) :-
    forall(( member(Token, New) ; member(Token, Applied) ),
           metta_reference_row(Space, Token, _, _)).

%No space the drain publishes again, one with a face published before, is
%one Space's standing rows, the ones not in New, reach through their homes'
%rows in turn. The reach is walked only when the drain holds such a space,
%since a drain of the space and the homes its new rows first reach, the usual
%one, holds none.
metta_reference_drain_unreached(Space, New, Pending) :-
    findall(Other,
            ( member(Other, Pending), Other \== Space,
              metta_reference_seen_space(Other, OtherModule),
              support_graph:support_stabilized(derived(OtherModule, reference_face), _) ),
            Others),
    (   Others == []
    ->  true
    ;   findall(Home,
                ( metta_reference_row(Space, Token, Home, _),
                  \+ memberchk(Token, New) ), Homes0),
        sort(Homes0, Homes),
        metta_reference_reach_walk(Homes, Homes, Reach),
        \+ ( member(Other, Others), memberchk(Other, Reach) )
    ).

metta_reference_prepare(whole, Space) :-
    metta_reference_retire_rows(Space),
    metta_reference_refresh_grades(Space).
metta_reference_prepare(rows(New, _, _, _, _, _), Space) :-
    metta_reference_grade_rows(Space, New).

%A publication is publication(Face, Demands, Binds, Kind): the face its space
%publishes, the entries whose names demand is read for, the entries whose
%homes a binding may read, and what differs by kind. A whole publication reads
%the face and plans it, and all three are the face. A publication of rows reads
%their entries and adds them to the published face, plan and keys; demand is
%read for those entries, and bindings read the homes of the heads the rows
%reach. Touched, the heads a provisional publication of earlier rows bound,
%are bound again by the first publication made outside every transaction,
%which is the one whose bindings stand. A plan the rows would withdraw origins
%from sends the space whole (metta_reference_source_plan_rows/6).
metta_reference_publication(whole, Space, _, publication(Face, Face, Face, whole(Plan))) :-
    metta_reference_provider_face(Space, [], Face),
    metta_reference_source_plan(Space, Face, Plan).
metta_reference_publication(rows(New, Applied, Touched, Face0, Public0, Plan0),
                            Space, Module, Publication) :-
    findall(Token-Home,
            ( member(Token, New), metta_reference_row(Space, Token, Home, _) ),
            NewRows),
    findall(Entry,
            ( member(Token-Home, NewRows),
              metta_reference_row(Space, Token, Home, Map),
              metta_reference_row_entry(Space, [], Token, Home, Map, Entry) ),
            Entries0),
    sort(Entries0, Entries),
    (   metta_reference_source_plan_rows(Space, Module, Plan0, Entries, Plan, Added)
    ->  append(Entries, Face0, FaceAll), sort(FaceAll, Face),
        metta_with_under(visibility,
            include(metta_reference_public_entry(Space), Entries, PublicNew)),
        append(PublicNew, Public0, PublicAll), sort(PublicAll, Public),
        findall(Name/Arity, ( member(Name/Arity-_, Entries), integer(Arity) ),
                Reached0),
        sort(Reached0, Reached),
        (   current_transaction(_)
        ->  Bound = Reached
        ;   append(Reached, Touched, Bound0), sort(Bound0, Bound)
        ),
        findall(Key-Roots,
                ( member(Key, Bound),
                  metta_reference_key_roots(Module, Key, Entries, Roots) ), Keys),
        findall(Key-Root, ( member(Key-Roots, Keys), member(Root, Roots) ), Binds),
        metta_reference_importer_rows(Space, Moved),
        Publication = publication(Face, Entries, Binds,
                                  rows(NewRows, Public, Plan, Added, Keys, Moved,
                                       settled(New, Applied, Reached, Touched)))
    ;   metta_reference_owe(Space, whole),
        metta_reference_prepare(whole, Space),
        metta_reference_publication(whole, Space, Module, Publication)
    ).

%The rows importing Space, which read its face whole.
metta_reference_importer_rows(Space, Rows) :-
    findall(derived(ImporterModule, reference_row(Token)),
            ( metta_reference_row(Importer, Token, Space, _),
              metta_reference_seen_space(Importer, ImporterModule) ), Rows0),
    sort(Rows0, Rows).

%A head's roots once the rows' entries join the ones its last publication
%recorded, in the order a whole face lists them.
metta_reference_key_roots(Module, Name/Arity, Entries, Roots) :-
    findall(Root, member(Name/Arity-Root, Entries), Reached),
    ( metta_reference_roots(Module, Name, Arity, Known) -> true ; Known = [] ),
    append(Reached, Known, All), sort(All, Roots).

metta_reference_publish(publication(Face, _, _, whole(_)), Space, Module, Context) :-
    metta_reference_publish_face(Space, Module, Face, Context).
metta_reference_publish(publication(Face, _, _, rows(NewRows, Public, _, _, Keys, Moved, _)),
                        Space, Module, Context) :-
    metta_reference_publish_rows(Space, Module, NewRows, Face, Public, Keys,
                                 Moved, Context).

metta_reference_publish_views(publication(Face, _, _, whole(Plan)), Space) :-
    metta_reference_source_metadata_face(Face, Plan, Metadata),
    metta_reference_publish_metadata(Space, Metadata),
    metta_reference_publish_source(Space, Plan).
metta_reference_publish_views(publication(_, Entries, _, rows(_, _, Plan, Added, _, _, _)),
                              Space) :-
    pairs_values(Added, AddedRoots),
    findall(Entry, metta_reference_source_canonical(AddedRoots, Entry), Canonical),
    append(Entries, Canonical, Metadata0), sort(Metadata0, Metadata),
    metta_reference_metadata_rows(Space, Metadata, Rows),
    metta_reference_project_metadata(Space, Rows),
    metta_reference_publish_source(Space, Plan).

%A publication outside every transaction is final and retracts what it
%published; one inside keeps what its completion owes: the rows it published,
%now applied, and the heads it bound provisionally, or the whole space. A row
%declared while it ran is left owed.
metta_reference_settle(publication(_, _, _, whole(_)), Space) :-
    (   current_transaction(_)
    ->  metta_reference_owe(Space, whole)
    ;   retractall(metta_reference_owed_whole(Space)),
        retractall(metta_reference_owed_row(Space, _, _)),
        retractall(metta_reference_owed_head(Space, _))
    ).
metta_reference_settle(publication(_, _, _, rows(_, _, _, _, _, _,
                                               settled(New, Applied, Reached, Touched))),
                       Space) :-
    (   current_transaction(_)
    ->  forall(( member(Token, New),
                 retract(metta_reference_owed_row(Space, Token, new)) ),
               assertz(metta_reference_owed_row(Space, Token, applied))),
        forall(( member(Key, Reached), \+ metta_reference_owed_head(Space, Key) ),
               assertz(metta_reference_owed_head(Space, Key)))
    ;   forall(( member(Token, New) ; member(Token, Applied) ),
               retractall(metta_reference_owed_row(Space, Token, _))),
        forall(( member(Key, Reached) ; member(Key, Touched) ),
               retractall(metta_reference_owed_head(Space, Key)))
    ).

%The faces a binding reads beside the drain's own: each home a publication may
%bind to that the drain does not publish.
metta_reference_binding_context(Faces, Publications, Context) :-
    findall(Home,
            ( member(_-_-publication(_, _, Binds, _), Publications),
              member(_-root(Home, _, _, _), Binds),
              \+ memberchk(Home-_-_, Faces) ), Homes0),
    sort(Homes0, Homes),
    findall(Home-Module-Face,
            ( member(Home, Homes), metta_reference_seen_space(Home, Module),
              metta_reference_provider_face(Home, [], Face) ), Extra),
    append(Faces, Extra, Context).

metta_reference_demand_names(Spaces, Names) :-
    findall(Name,
            ( member(_-Module, Spaces), metta_reference_roots(Module, Name, _, _),
              metta_reference_demand(Name) ), Names0),
    sort(Names0, Names).

% Static imports protect compiler goals from user equations. Only names
% removed from changed roots need a remaining-user search; adding a settled
% importer must not inspect every other importer with the same head name.
% https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/library/prolog_wrap.pl
metta_reference_publish_demand(Faces, Previous) :-
    findall(Name,
            ( member(Space-_-Face, Faces), member(Name/Arity-root(Home, Original, _, _), Face),
              integer(Arity), \+ ( Home == Space, Name == Original ),
              metta_reference_unsettled(Home, Original) ), Names0),
    sort(Names0, Names),
    forall(( member(Name, Previous), \+ memberchk(Name, Names),
             \+ metta_reference_demanded_elsewhere(Name) ),
           retractall(metta_reference_demand(Name))),
    forall(member(Name, Names),
           ( metta_reference_demand(Name) -> true
           ; assertz(metta_reference_demand(Name)) )),
    metta_reference_demand_wrapper.

metta_reference_demanded_elsewhere(Name) :-
    metta_reference_roots(Module, Name, _, Roots),
    member(root(Home, Original, _, _), Roots),
    metta_reference_seen_space(Home, HomeModule),
    \+ ( HomeModule == Module, Name == Original ),
    metta_reference_unsettled(Home, Original), !.

metta_reference_demand_wrapper :-
    forall(metta_reference_force_door(Door, Name),
           metta_reference_demand_wrapper(Door, Name)).

%The two doors a resolving force enters by, from the module in force and from
%a module the caller names. Both are wrapped, so a demanded alias forces its
%original whichever door a call site, a hook or an inspection takes.
metta_reference_force_door(spaces:metta_ensure_compiled(Name), Name).
metta_reference_force_door(spaces:metta_ensure_compiled_from(_, Name), Name).

%Asked at every publication, so each state takes its cheapest test: a failing
%unwrap when nothing is demanded, and the wrapped/1 property while something
%is, which reads the wrapper's name where current_predicate_wrapper/4 rebuilds
%its body [measured 2026-09-25T01:13:28+10:00: 11 inferences against 63 on a
%wrapped predicate, and a failing unwrap 3; the class_decorators twin runs
%this 496 times].
metta_reference_demand_wrapper(Module:Head, Name) :-
    ( \+ metta_reference_demand(_)
    -> functor(Head, Door, Arity),
       ( unwrap_predicate(Module:Door/Arity, metta_reference_demand)
       -> true ; true )
    ; predicate_property(Module:Head, wrapped(Wrappers)),
      memberchk(metta_reference_demand, Wrappers)
    -> true
    ; wrap_predicate(Module:Head, metta_reference_demand, Wrapped,
                     ( ( metta_reference_demand(Name)
                       -> metta_reference_force(Name) ; true ), Wrapped ))
    ).

metta_reference_track_transaction :- metta_reference_track_transaction([]).

metta_reference_track_transaction(Spaces) :-
    (   current_transaction(_)
    ->  prolog_current_frame(Frame), metta_reference_track_frames(Frame, Spaces)
    ;   true
    ).

% Roots are tracked on the nearest live transaction frame; when that frame
% finishes inside an enclosing transaction its roots transfer to the next one,
% and the frame being finished is excluded from the walk because a failing
% frame is still in the live ancestry while its completion runs.
metta_reference_track_frames(Frame, Spaces) :-
    prolog_frame_attribute(Frame, predicate_indicator, Predicate),
    % policy-inventory-exempt: mechanism-internal; reason=the three native transaction and snapshot frames in the pinned SWI source; evidence=engine/metta/reference_refresh.pl:metta_reference_track_frames/2
    (   memberchk(Predicate, [system:'$transaction'/2, system:'$transaction'/3,
                             system:'$snapshot'/1]),
        \+ metta_reference_finishing(Frame)
    ->  metta_reference_frame_entries(Frames),
        (   memberchk(frame(Frame, Roots), Frames)
        ->  true
        ;   trie_new(Roots),
            % Register retirement before publishing an untrailed frame.
            host_transactions:host_transaction_on_exit(
                metta_engine:metta_reference_finish_frame(Frame)),
            nb_setval('$metta_reference_frames', [frame(Frame, Roots)|Frames])
        ),
        forall(member(Space, Spaces), metta_reference_set_add(Roots, Space))
    ; prolog_frame_attribute(Frame, parent, Parent),
      metta_reference_track_frames(Parent, Spaces) ).

metta_reference_finish_frame(Frame) :-
    metta_reference_frame_entries(Frames),
    (   memberchk(frame(Frame, Roots), Frames)
    ->  metta_reference_set_spaces(Roots, Spaces),
        % A completion inside a source program or definition batch queues
        % its spaces as a change does; the program's next flush publishes.
        partition(metta_reference_rows_committed, Spaces, Committed, Others),
        metta_with_trailed_push('$metta_reference_finishing', Frame,
            ( metta_reference_track_transaction(Spaces),
              metta_reference_invalidate(Others),
              forall(member(Space, Committed), metta_reference_rows_completed(Space)),
              ( filereader:active_source_program(_) -> true ; metta_reference_refresh ),
              with_typing_policy_stable(metta_reference_demand_wrapper) )),
        % Keep the roots until reconciliation succeeds so a cleanup retry
        % can repeat it. Transferring roots may have registered a new parent.
        metta_reference_frame_entries(Current),
        selectchk(frame(Frame, _), Current, Remaining),
        ( Remaining == [] -> nb_delete('$metta_reference_frames')
        ; nb_setval('$metta_reference_frames', Remaining) ),
        trie_destroy(Roots)
    ;   true
    ).

%A space the frame changed by from rows alone, every one still standing, so the
%frame committed them. Its face, its heads' roots and the views over them are
%what the frame's publications made, and they committed with it; it owes its
%bindings, which were provisional (metta_reference_owed_head/2), and its importers'
%publications, which read its face whole. So it walks its importers' rows,
%not its own face's closure, which would dirty every head it holds and every
%caller resolved through one, and queues itself for the publication that
%binds finally. A rolled-back frame took its rows with it, and a frame that
%changed anything else left the ledger whole: both walk the face as before,
%the rollback because the stored face rewound while the bindings did not.
metta_reference_rows_committed(Space) :-
    metta_reference_owed_ledger(Space, New, Applied, _),
    metta_reference_rows_standing(Space, New, Applied).

metta_reference_rows_completed(Space) :-
    metta_reference_importer_rows(Space, Rows),
    metta_with_trailed_enumeration('$metta_reference_face_wave', true,
                                   support_graph:support_invalidate_many(Rows)),
    metta_reference_queue(Space).

metta_reference_frame_entries(Frames) :-
    ( nb_current('$metta_reference_frames', Frames) -> true ; Frames = [] ).

metta_reference_pending_frames(Frames) :-
    metta_reference_frame_entries(Entries),
    findall(Frame, member(frame(Frame, _), Entries), Frames).

metta_reference_pending_frame(Frame) :-
    metta_reference_frame_entries(Entries), member(frame(Frame, _), Entries).
