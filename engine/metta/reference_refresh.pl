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
%   commit=WORKTREE].
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
    (   metta_reference_refreshing
    ->  true
    ;   metta_reference_face_event(metta_reference_mark, Space),
        ( filereader:active_source_program(_)
        -> true
        ; metta_reference_refresh )
    ).

% A binding the drain installs announces a function change in the importer;
% that is the refresh's own work and must not re-queue the face it publishes.
metta_reference_definition_changed(Space) :-
    (   metta_reference_refreshing
    ->  true
    ;   metta_reference_face_event(metta_reference_mark, Space)
    ).

% A change the refresh did not make, such as a deferred function a repair
% forced into its physical arity, is queued even while a drain runs; the
% drain's loop reads the queue again after each publication.
metta_reference_face_changed(Space) :-
    metta_reference_face_event(metta_reference_invalidate, Space).

metta_reference_face_event(Invalidate, Space) :-
    metta_reference_track_transaction([Space]),
    call(Invalidate, [Space]),
    filereader:source_definition_arrived('$metta_reference_face').

metta_reference_mark(Spaces) :-
    metta_reference_face_roots(Spaces, Roots),
    forall(member(Root, Roots), support_graph:support_invalidate_node(Root)).

metta_reference_invalidate(Spaces) :-
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

metta_reference_refresh_now :-
    metta_reference_pending(Pending),
    (   Pending == []
    ->  true
    ;   flag('$metta_reference_epoch', Version, Version),
        findall(Space-Module,
                ( member(Space, Pending), metta_reference_seen_space(Space, Module) ),
                Spaces),
        forall(member(Space-_, Spaces),
               ( metta_reference_watch(Space),
                 metta_reference_retire_rows(Space),
                 metta_reference_refresh_grades(Space) )),
        findall(Space-Module-Face,
                ( member(Space-Module, Spaces),
                  metta_reference_provider_face(Space, [], Face) ), Faces),
        metta_reference_binding_context(Faces, Context),
        findall(Space-Plan,
                ( member(Space-_-Face, Faces),
                  metta_reference_source_plan(Space, Face, Plan) ), Sources),
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
              -> metta_reference_demand_names(Spaces, PreviousDemand),
                 forall(member(Space-Module-Face, Faces),
                        metta_reference_publish_face(Space, Module, Face, Context)),
                 metta_reference_publish_demand(Faces, PreviousDemand),
                 forall(member(Space-_-Face, Faces),
                        ( memberchk(Space-Plan, Sources),
                          metta_reference_source_metadata_face(Face, Plan, Metadata),
                          metta_reference_publish_metadata(Space, Metadata),
                          metta_reference_publish_source(Space, Plan) )),
                 % Stabilization can notify another member of this batch.
                 % Every batch face already describes the same row epoch.
                 % Consume those notifications and retain newly affected homes.
                 metta_reference_consumed(Pending),
                 Result = published
              ; Result = changed ) ))),
        b_setval('$metta_reference_draining', []),
        ( Result == published
        -> forall(support_graph:support_repair_invalidations, true)
        ; true ),
        metta_reference_refresh_now
    ).

metta_reference_binding_context(Faces, Context) :-
    findall(Home,
            ( member(_-_-Face, Faces), member(_-root(Home, _, _, _), Face),
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
    ( \+ metta_reference_demand(_)
    -> ( unwrap_predicate(spaces:metta_ensure_compiled/1, metta_reference_demand)
       -> true ; true )
    ; current_predicate_wrapper(spaces:metta_ensure_compiled(_),
                                metta_reference_demand, _, _)
    -> true
    ; wrap_predicate(spaces:metta_ensure_compiled(Name), metta_reference_demand,
                     Wrapped,
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
        metta_with_trailed_push('$metta_reference_finishing', Frame,
            ( metta_reference_track_transaction(Spaces),
              metta_reference_invalidate(Spaces),
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

metta_reference_frame_entries(Frames) :-
    ( nb_current('$metta_reference_frames', Frames) -> true ; Frames = [] ).

metta_reference_pending_frames(Frames) :-
    metta_reference_frame_entries(Entries),
    findall(Frame, member(frame(Frame, _), Entries), Frames).

metta_reference_pending_frame(Frame) :-
    metta_reference_frame_entries(Entries), member(frame(Frame, _), Entries).
