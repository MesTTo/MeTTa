% Purpose: publish changed reference faces and repair native links on rollback.
% Assumes: references.pl owns reference rows, faces, bindings and visibility.
% Guarantees: adding an importer publishes no existing sibling; changing a
%   provider publishes its affected importers
%   [tested: reference_publication; commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Guarantees: patterned references participate in demand, publication and
%   rollback through their original defining home
%   [tested: reference_patterns; commit=a95e6c90c910db30c72311abadd58dee5349978c].
% Guarantees: nested completion transfers mutation roots to the live parent,
%   then reconciles bindings against rows surviving the transaction
%   [tested: references:rollback_restores_native_links_and_nested_rollback_restores_its_parent,
%   references:inner_failure_transfers_one_watch_and_outer_completion_retires_it;
%   commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Guarantees: inference cuts cannot abandon a registered reference frame or
%   its reconciliation [tested:
%   references:an_inference_cut_cannot_abandon_reference_completion;
%   commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Owns resources: pending faces and frame roots are engine-local SWI global
%   variables. Publication consumes its pending set; completion retires its
%   frame. host_transaction_on_exit/1 invokes completion after SWI releases its
%   global event mutex [tested: host_transaction_completion; commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].
% Guarded by: with_typing_policy_stable/1 serializes native publication. Maps
%   run outside that mutex and the support graph mutex; an epoch change retries
%   their publication against the current rows
%   [source: engine/metta/reference_refresh.pl:metta_reference_refresh_now/0;
%   commit=9b0a084e534ddf7dd67980ad84c27c8279b877f1].

:- use_module(library(nb_set), [empty_nb_set/1, add_nb_set/2, nb_set_to_list/2]).
:- use_module(library(ordsets), [ord_subtract/3]).
:- multifile support_graph:support_invalidation_action/1.

% The graph already fixes the affected forward closure before notifying its
% owners. Keep a publication queue, as filereader's compiled-function owner
% does, rather than traversing all known spaces or maintaining a second graph.
support_graph:support_invalidation_action(derived(Module, reference_face)) :-
    metta_reference_seen_space(Space, Module),
    metta_reference_queue(Space).

metta_reference_queue(Space) :-
    ( nb_current('$metta_reference_pending', Pending) -> true
    ; empty_nb_set(Pending), nb_linkval('$metta_reference_pending', Pending) ),
    add_nb_set(Space, Pending),
    metta_reference_source_queued(Space).

metta_reference_pending(Spaces) :-
    ( nb_current('$metta_reference_pending', Pending)
    -> nb_set_to_list(Pending, Spaces)
    ; Spaces = [] ).

metta_reference_consumed(Spaces) :-
    metta_reference_pending(Queued),
    ord_subtract(Queued, Spaces, Remaining),
    ( Remaining == [] -> nb_delete('$metta_reference_pending')
    ; empty_nb_set(Pending),
      forall(member(Space, Remaining), add_nb_set(Space, Pending)),
      nb_linkval('$metta_reference_pending', Pending) ).

metta_reference_changed(Space) :-
    (   metta_reference_refreshing
    ->  true
    ;   metta_reference_definition_changed(Space),
        ( filereader:active_source_program(_)
        -> true
        ; metta_reference_refresh )
    ).

% A binding the drain installs announces a function change in the importer;
% that is the refresh's own work and must not re-queue the face it publishes.
metta_reference_definition_changed(Space) :-
    (   metta_reference_refreshing
    ->  true
    ;   metta_reference_face_changed(Space)
    ).

% A change the refresh did not make, such as a deferred function a repair
% forced into its physical arity, is queued even while a drain runs; the
% drain's loop reads the queue again after each publication.
metta_reference_face_changed(Space) :-
    metta_reference_track_transaction([Space]),
    metta_reference_invalidate([Space]),
    filereader:source_definition_arrived('$metta_reference_face').

metta_reference_invalidate(Spaces) :-
    flag('$metta_reference_epoch', Epoch, Epoch+1),
    findall(derived(Module, reference_face),
            ( member(Space, Spaces), metta_reference_seen_space(Space, Module) ),
            Roots),
    support_graph:support_invalidate_many(Roots).

metta_reference_refresh :-
    (   metta_reference_refreshing
    ->  true
    ;   % Workaround: swi-cleanup-window - an interrupted drain restores its trailed marker.
        metta_with_trailed_enumeration('$metta_reference_refreshing', true,
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
                  metta_reference_local_face(Space, [], Face) ), Faces),
        metta_reference_binding_context(Faces, Context),
        findall(Space-Plan,
                ( member(Space-_-Face, Faces),
                  metta_reference_source_plan(Space, Face, Plan) ), Sources),
        % Publish all bindings and metadata before repairing a shared caller.
        % A defining home's face may be needed to select its own closure;
        % reading that context does not publish the unmodified home.
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
              metta_reference_local_face(Home, [], Face) ), Extra),
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

% Workaround: swi-query-frame-discarded-on-engine-destroy - watch the nearest live transaction and exclude finishing frames when transferring its roots.
% Inspecting a frame marks it FR_NOTIFY. SWI's discard_query can notify an
% inspected outer query after closing its foreign frame. Stop at the nearest
% transaction and exclude a finishing frame when transferring its roots.
% https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-wam.c#L3052-L3064
metta_reference_track_frames(Frame, Spaces) :-
    prolog_frame_attribute(Frame, predicate_indicator, Predicate),
    % policy-inventory-exempt: mechanism-internal; reason=the three native transaction and snapshot frames in the pinned SWI source; evidence=engine/metta/reference_refresh.pl:metta_reference_track_frames/2
    (   memberchk(Predicate, [system:'$transaction'/2, system:'$transaction'/3,
                             system:'$snapshot'/1]),
        \+ metta_reference_finishing(Frame)
    ->  metta_reference_frame_entries(Frames),
        ( memberchk(frame(Frame, Roots), Frames) -> true
        ; empty_nb_set(Roots),
          % Register retirement before publishing an untrailed frame.
          host_transactions:host_transaction_on_exit(
              metta_engine:metta_reference_finish_frame(Frame)),
          nb_linkval('$metta_reference_frames', [frame(Frame, Roots)|Frames]) ),
        forall(member(Space, Spaces), add_nb_set(Space, Roots))
    ; prolog_frame_attribute(Frame, parent, Parent),
      metta_reference_track_frames(Parent, Spaces) ).

metta_reference_finish_frame(Frame) :-
    metta_reference_frame_entries(Frames),
    (   memberchk(frame(Frame, Roots), Frames)
    ->  nb_set_to_list(Roots, Spaces),
        ( nb_current('$metta_reference_finishing', Before) -> true ; Before = [] ),
        % Workaround: swi-cleanup-window - exclusion of finishing frames follows the trail.
        metta_with_trailed_enumeration('$metta_reference_finishing', [Frame|Before],
            ( metta_reference_track_transaction(Spaces),
              metta_reference_invalidate(Spaces),
              metta_reference_refresh,
              with_typing_policy_stable(metta_reference_demand_wrapper) )),
        % Keep the roots until reconciliation succeeds so a cleanup retry
        % can repeat it. Transferring roots may have registered a new parent.
        metta_reference_frame_entries(Current),
        selectchk(frame(Frame, _), Current, Remaining),
        ( Remaining == [] -> nb_delete('$metta_reference_frames')
        ; nb_linkval('$metta_reference_frames', Remaining) )
    ;   true
    ).

metta_reference_frame_entries(Frames) :-
    ( nb_current('$metta_reference_frames', Frames) -> true ; Frames = [] ).

metta_reference_pending_frames(Frames) :-
    metta_reference_frame_entries(Entries),
    findall(Frame, member(frame(Frame, _), Entries), Frames).

metta_reference_pending_frame(Frame) :-
    metta_reference_frame_entries(Entries), member(frame(Frame, _), Entries).
