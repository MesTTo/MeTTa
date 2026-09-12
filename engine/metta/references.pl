% Purpose: derive live definition references and occurrence visibility from rows.
% Assumes: spaces:metta_space_pair/4 retains each stored occurrence's token;
%   foreign receivers declare tokens, add-token and remove-token.
% Guarantees: reference paths identify defining predicates, while their clauses
%   retain their original multiplicity and execution module
%   [tested: references; commit=90ba93eb8f6e98ebfefc55416859bf13de6a8427].
%   Suspended reference queries can be destroyed: transaction discovery leaves
%   their outer query frame unwatched [tested:
%   reference_loading:a_suspended_background_qualified_query_survives_release;
%   commit=90ba93eb8f6e98ebfefc55416859bf13de6a8427].
% Owns resources: observed spaces own mutation observers, projected metadata and
%   native bindings; space release withdraws all three. Transaction completion
%   reconciles native bindings with the rows surviving commit or rollback.
%   A completion callback excludes its finishing frame only until its cleanup;
%   inner rollback retains one outer watch and outer completion retires it
%   [tested: references:inner_failure_transfers_one_watch_and_outer_completion_retires_it;
%   commit=90ba93eb8f6e98ebfefc55416859bf13de6a8427].
% Guarded by: with_typing_policy_stable/1 serializes binding publication. Maps
%   run before publication, outside the typing and support-graph mutexes.
% Decides: INTERNAL is visibility's zero and PUBLIC its one. A visited-space
%   traversal bounds cycles, including cycles whose maps change names.

:- dynamic metta_reference_row/4, metta_reference_map/3.
:- dynamic metta_occurrence_grade/4, metta_reference_projection/4.
:- dynamic metta_reference_roots/4, metta_reference_seen_space/2.
:- dynamic metta_reference_slot/4, metta_reference_observed/1.
:- volatile metta_reference_seen_space/2, metta_reference_slot/4.
:- '$notransact'(metta_reference_seen_space/2).
:- '$notransact'(metta_reference_slot/4).
:- thread_local metta_reference_refreshing/0, metta_reference_finishing/1.
:- dynamic metta_reference_hooks/0.
:- dynamic metta_reference_demand/1.
:- volatile metta_reference_demand/1.
:- thread_local metta_reference_forcing/1.

metta_reference_declare(Space, Term, Token) :-
    spaces:metta_require_token_mutation(Space, from),
    metta_reference_watch(Space),
    (   Term = [from, Source|Maps],
        metta_reference_row_map(Space, Maps, Term, Map)
    ->  metta_reference_source(Space, Source, Home),
        metta_reference_watch(Home),
        metta_reference_validate_selection(Home, Map),
        transaction(( spaces:metta_store_occurrence(Space, Term, Token, _),
                      assertz(metta_reference_row(Space, Token, Home, Map)),
                      metta_reference_refresh )),
        metta_reference_changed(Space)
    ;   Term = [internal|Names]
    ->  maplist(must_be(atom), Names),
        transaction(( spaces:metta_store_occurrence(Space, Term, Token, _),
                      metta_reference_refresh )),
        metta_reference_changed(Space)
    ;   domain_error(reference_declaration, Term)
    ).

metta_reference_row_map(_, [Map], _, Map) :- !.
metta_reference_row_map(Space, [], _, Map) :- !,
    metta_reference_option(Space, 'from-map', Map).
metta_reference_row_map(_, _, Original, _) :- domain_error(from_row, Original).

metta_reference_watch(Space) :-
    spaces:metta_require_token_read(Space, from),
    metta_reference_install_hooks,
    space_module(Space, Module),
    ( metta_reference_seen_space(Space, Module) -> true
    ; assertz(metta_reference_seen_space(Space, Module)) ),
    ( metta_reference_observed(Space) -> true
    ; spaces:metta_reference_mutation_scope(Space, enabled),
      assertz(metta_reference_observed(Space)) ),
    metta_reference_track_transaction.

% A map's explicit domain can name an absent or private head. Arbitrary maps
% are filtered imports: they receive each public head the source actually has.
% https://github.com/racket/racket/blob/v8.18/racket/collects/racket/require.rkt
metta_reference_validate_selection(Home, Map) :-
    findall(Name, metta_reference_selected(Map, Name), Names0),
    sort(Names0, Names),
    ( Names == [] -> Face = [] ; metta_reference_face(Home, [], Face) ),
    forall(member(Name, Names),
           ( must_be(atom, Name),
             ( metta_reference_internal(Home, Name)
             -> throw(error(metta_internal_reference(Home, Name), none))
             ; memberchk(Name/_-_, Face) -> true
             ; space_module(Home, Module),
               metta_reference_note(Module, Name, reference_missing(Home))
             ) )).

metta_reference_selected(partial(Head, Args), Name) :- !,
    metta_reference_selected([Head|Args], Name).
metta_reference_selected([only, Names], Name) :- member(Name, Names).
metta_reference_selected([rename, Pairs], Name) :- member([Name, _], Pairs).

metta_reference_internal(Space, Name) :-
    spaces:metta_space_pair(Space, [internal|Names], _, _), memberchk(Name, Names), !.
metta_reference_internal(Space, Name) :-
    metta_reference_manifest_row(Space, [internal|Names]),
    memberchk(Name, Names), !.

metta_reference_row_head([=, [Name|_], _], Name) :- atom(Name), !.
metta_reference_row_head([=, Name, _], Name) :- atom(Name), !.
metta_reference_row_head([':', Name, _], Name) :- atom(Name), !.
metta_reference_row_head(['@doc', Name|_], Name) :- atom(Name), !.
metta_reference_row_head([Name|_], Name) :- atom(Name), !.
metta_reference_row_head(Name, Name) :- atom(Name).

metta_reference_refresh_grades(Space) :-
    retractall(metta_occurrence_grade(Space, _, visibility, _)),
    forall(( spaces:metta_space_pair(Space, Row, Token, _),
             metta_reference_row_head(Row, Name),
             metta_reference_internal(Space, Name) ),
           assertz(metta_occurrence_grade(Space, Token, visibility, 'INTERNAL'))).

% The same dynamically scoped algebra used by under determines a row's grade.
% Absence of an annotation is the selected algebra's one, not a stored row.
metta_graded_pair(Space, Row, Token, Ref, Grade) :-
    spaces:metta_space_pair(Space, Row, Token, Ref),
    metta_effective_algebra(Space, Algebra),
    ( metta_occurrence_grade(Space, Token, Algebra, Held) -> Grade = Held
    ; metta_algebra_one(Space, Grade) ),
    b_setval('$metta_answer_k', Grade).

metta_reference_own_head(Space, Name, Arity) :-
    metta_with_under(visibility,
        ( metta_graded_pair(Space, [=, [Name|Args], _], Token, _, 'PUBLIC'),
          atom(Name), metta_reference_equation_arity(Space, Name, Token, Args, Arity) )).
metta_reference_own_head(Space, Name, Arity) :-
    metta_reference_prolog_head(Space, Name, Arity),
    \+ metta_reference_internal(Space, Name).
metta_reference_own_head(Space, Name, Arity) :-
    metta_reference_manifest_head(Space, Name, Arity),
    \+ metta_reference_internal(Space, Name).
metta_reference_own_head(Space, Name, declaration) :-
    metta_reference_declared_head(Space, Name),
    \+ metta_reference_internal(Space, Name).

metta_reference_face(Space, Visited, Face) :-
    metta_with_under(visibility,
        ( metta_reference_local_face(Space, Visited, Local),
          include(metta_reference_public_entry(Space), Local, Face) )).

metta_host_reference_names(Space, Names) :-
    metta_with_under(visibility, metta_reference_local_face(Space, [], Face)),
    findall(Name, member(Name/_-_, Face), Heads),
    sort(Heads, Names).

metta_reference_public_entry(Space, Name/Arity-root(Home, Original, _)) :-
    ( Space == Home, Name == Original
    -> once(metta_reference_own_head(Space, Name, Arity))
    ; \+ metta_reference_internal(Space, Name) ).

metta_reference_local_face(Space, Visited, Face) :-
    (   memberchk(Space, Visited)
    ->  Face = []
    ;   findall(Name/Arity-root(Space, Name, Arity),
                metta_reference_local_head(Space, Name, Arity), Own),
        findall(Name/Arity-Root,
                ( metta_reference_row(Space, Token, Home, Map),
                  metta_reference_face(Home, [Space|Visited], Source),
                  member(Original/Arity-Root, Source),
                  metta_reference_names(Space, Token, Map, Original, Names),
                  member(Name, Names) ), Imported),
        append(Own, Imported, All), sort(All, Face)
    ).

metta_reference_local_head(Space, Name, Arity) :-
    spaces:metta_space_pair(Space, [=, [Name|Args], _], Token, _),
    atom(Name), metta_reference_equation_arity(Space, Name, Token, Args, Arity).
metta_reference_local_head(Space, Name, Arity) :-
    metta_reference_prolog_head(Space, Name, Arity).
metta_reference_local_head(Space, Name, Arity) :-
    metta_reference_manifest_head(Space, Name, Arity).
metta_reference_local_head(Space, Name, declaration) :-
    metta_reference_declared_head(Space, Name).

% A projected declaration retains its original source. Treating that copy as
% a new local root would make diamonds duplicate it and cycles retain it.
metta_reference_declared_head(Space, Name) :-
    metta_reference_type_subject(Row, Name),
    spaces:metta_space_pair(Space, Row, Token, _),
    atom(Name),
    \+ metta_reference_projection(Space, _, Token, _).

metta_reference_type_subject([':', Name, _], Name).
metta_reference_type_subject([':<', Name, _], Name).

% Eta expansion can add inputs. The occurrence-to-clause registry gives the
% actual arity after translation; before it, the source head is a manifest.
metta_reference_equation_arity(Space, Name, Token, Args, Arity) :-
    space_module(Space, Module),
    ( filereader:'$metta_equation_token'(Module, Name, Ref, Token),
      clause_property(Ref, predicate(Module:_/CompiledArity))
    -> Arity = CompiledArity
    ; length(Args, Inputs), Arity is Inputs+1 ).

metta_reference_names(_, Token, _, Head, Names) :-
    metta_reference_map(Token, Head, Names), !.
metta_reference_names(Space, Token, Map, Head, Names) :-
    metta_source_singleflight(reference_map(Token, Head),
        metta_reference_map_once(Space, Token, Map, Head, Names)).

metta_reference_map_once(_, Token, _, Head, Names) :-
    metta_reference_map(Token, Head, Names), !.
metta_reference_map_once(Space, Token, Map, Head, Names) :-
    space_module(Space, Module),
    findall(Name,
            with_metta_module(Module,
                eval([let, Mapper, Map, [Mapper, Head]], Name)), Results),
    forall(member(Result, Results),
           ( atom(Result) -> true
           ; throw(error(metta_reference_map_result(Map, Head, Result), none)) )),
    sort(Results, Names),
    assertz(metta_reference_map(Token, Head, Names)).

metta_reference_changed(Space) :-
    (   metta_reference_refreshing
    ->  true
    ;   metta_reference_track_transaction,
        metta_reference_definition_changed(Space),
        ( filereader:active_source_program(_)
        -> filereader:source_definition_arrived('$metta_reference_face')
        ; metta_reference_refresh )
    ).

metta_reference_definition_changed(Space) :-
    (   metta_reference_refreshing
    ->  true
    ;   flag('$metta_reference_epoch', Epoch, Epoch+1),
        space_module(Space, Module),
        support_graph:support_invalidate(derived(Module, reference_face)),
        filereader:source_definition_arrived('$metta_reference_face')
    ).

metta_reference_refresh :-
    (   metta_reference_refreshing
    ->  true
    ;   setup_call_cleanup(
            asserta(metta_reference_refreshing, Guard),
            metta_reference_refresh_now,
            erase(Guard))
    ).

metta_reference_refresh_now :-
    flag('$metta_reference_epoch', Version, Version),
    findall(Space-Module, metta_reference_seen_space(Space, Module), Spaces),
    forall(member(Space-_, Spaces),
           ( metta_reference_watch(Space),
             metta_reference_retire_rows(Space),
             metta_reference_refresh_grades(Space) )),
    findall(Space-Module-Face,
            ( member(Space-Module, Spaces),
              metta_reference_local_face(Space, [], Face) ), Faces),
    % One face can change several dependencies of the same compiled caller.
    % Reuse the graph's batch so callers rebuild after every binding and type
    % projection is installed. This is the same observer boundary as
    % https://github.com/solidjs/solid/releases/tag/v1.5.0
    % [tested: references:one_face_publication_recompiles_a_shared_caller_once;
    % commit=90ba93eb8f6e98ebfefc55416859bf13de6a8427].
    with_typing_policy_stable(support_graph:with_support_repairs_deferred(
        ( flag('$metta_reference_epoch', Current, Current),
          ( Current =:= Version
          -> forall(member(Space-Module-Face, Faces),
                    metta_reference_publish_face(Space, Module, Face, Faces)),
             metta_reference_publish_demand(Faces),
             forall(member(Space-_-Face, Faces),
                    metta_reference_publish_metadata(Space, Face)),
             Result = published
          ; Result = changed ) ))),
    ( Result == changed -> metta_reference_refresh_now
    ; forall(support_graph:support_repair_invalidations, true) ).

% Static imports protect compiler goals from a program's equations. Wrap that
% static entry while demands exist; turning it dynamic would allow assertion
% through its imports. prolog_wrap retains the static definition and its guard:
% https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/library/prolog_wrap.pl
% [tested: reference_loading:demand_keeps_the_compiler_goal_static_and_retires;
% commit=90ba93eb8f6e98ebfefc55416859bf13de6a8427].
metta_reference_publish_demand(Faces) :-
    findall(Name,
            ( member(Space-_-Face, Faces), member(Name/_-root(Home, Original, _), Face),
              Home \== Space,
              metta_reference_unsettled(Home, Original) ), Names0),
    sort(Names0, Names),
    forall(( metta_reference_demand(Name), \+ memberchk(Name, Names) ),
           retractall(metta_reference_demand(Name))),
    forall(member(Name, Names),
           ( metta_reference_demand(Name) -> true
           ; assertz(metta_reference_demand(Name)) )),
    ( Names == []
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

metta_reference_unsettled(Home, _) :- metta_reference_loading(Home), !.
metta_reference_unsettled(Home, Name) :-
    spaces:deferred_metta_function(Name, _, Home, _, _, _).

metta_reference_force(Name) :-
    (   metta_reference_forcing(Name)
    ->  true
    ;   setup_call_cleanup(
            asserta(metta_reference_forcing(Name), Guard),
            forall(( metta_reference_roots(_, Name, _, Roots),
                     member(root(Home, Original, _), Roots) ),
                   ( metta_reference_wait(Home),
                     ( Original == Name -> true
                     ; spaces:metta_ensure_compiled(Original) ) )),
            erase(Guard))
    ).

:- multifile user:exception/3.
user:exception(undefined_predicate, Module:Predicate/Arity, retry) :-
    metta_reference_demand(Name), compiled_function_name(Name, Predicate),
    metta_reference_roots(Module, Name, _, _),
    spaces:metta_ensure_compiled(Name),
    current_predicate(Module:Predicate/Arity), !.

metta_reference_retire_rows(Space) :-
    space_module(Space, Module),
    forall(( metta_reference_row(Space, Token, _, _),
             \+ spaces:metta_space_pair(Space, [from|_], Token, _) ),
           ( retractall(metta_reference_row(Space, Token, _, _)),
             retractall(metta_reference_map(Token, _, _)),
             support_graph:support_forget(derived(Module, reference_row(Token))) )).

metta_reference_publish_face(Space, Module, Face, Faces) :-
    findall(derived(Module, reference_row(Token)),
            ( metta_reference_row(Space, Token, Home, _),
              space_module(Home, HomeModule),
              support_graph:support_publish(derived(Module, reference_row(Token)),
                  [derived(HomeModule, reference_face)], []) ), Supports0),
    sort(Supports0, Supports),
    support_graph:support_publish(derived(Module, reference_face), Supports, []),
    support_graph:support_stabilize(derived(Module, reference_face),
                                   =(Face), _),
    findall(Name/Arity,
            ( member(Name/Arity-_, Face), integer(Arity)
            ; metta_reference_slot(Module, Name, Arity, _) ), Keys0),
    sort(Keys0, Keys),
    forall(member(Name/Arity, Keys),
           ( findall(Root, member(Name/Arity-Root, Face), Roots),
             metta_reference_bind(Space, Module, Name, Arity, Roots, Faces),
             ( Roots == []
             -> support_graph:support_forget(derived(Module, reference(Name, Arity)))
             ; support_graph:support_publish(derived(Module, reference(Name, Arity)),
                   [derived(Module, reference_face)],
                   [edge(derived(Module, reference(Name, Arity)), function(Module, Name))]) ),
             retractall(metta_reference_roots(Module, Name, Arity, _)),
             ( Roots == [] -> true
             ; assertz(metta_reference_roots(Module, Name, Arity, Roots)) ) )).

metta_reference_bind(Space, Module, Name, Arity, Roots, Faces) :-
    (   Roots = [root(Space, Name, Arity)],
        \+ metta_reference_slot(Module, Name, Arity, _)
    ->  true
    ;   Roots == [], \+ metta_reference_slot(Module, Name, Arity, _)
    ->  true
    ;   metta_reference_binding(Space, Module, Name, Arity, Roots, Faces),
        (   Roots == []
        ->  ( metta_reference_roots(Module, Name, OtherArity, Other),
              OtherArity =\= Arity, Other \== []
            -> true ; unregister_fun_in(Module, Name) )
        ;   ( member(root(Home, Original, _), Roots),
              \+ metta_reference_unsettled(Home, Original)
            -> register_arity(Name, Arity) ; true ),
            register_fun_in(Module, Name),
            metta_reference_announce_union(Module, Name, Roots)
        ),
        spaces:announce_function_changed(Module, Name)
    ).

% Native imports share SWI's definition, with no forwarding clause. A source
% with a wider public union must instead contribute its retained own closure.
% https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-modul.c
metta_reference_binding(_, Module, Name, Arity, [], _) :-
    \+ current_transaction(_), !,
    metta_reference_drop_binding(Module, Name, Arity).
metta_reference_binding(Space, Module, Name, Arity,
                        [root(Space, Name, Arity)], _) :-
    metta_reference_slot(Module, Name, Arity, wrapped(_, _)), !,
    compiled_function_name(Name, Predicate), functor(Head, Predicate, Arity),
    unwrap_predicate(Module:Head, metta_reference_union),
    retractall(metta_reference_slot(Module, Name, Arity, _)).
metta_reference_binding(Space, Module, Name, Arity,
                        [root(Home, Name, Arity)], Faces) :-
    Home \== Space,
    memberchk(Home-HomeModule-Face, Faces),
    findall(R, member(Name/Arity-R, Face), [root(Home, Name, Arity)]),
    \+ ( metta_reference_slot(Module, Name, Arity, wrapped(_, _)),
         current_transaction(_) ),
    !,
    metta_reference_drop_binding(Module, Name, Arity),
    compiled_function_name(Name, Predicate),
    HomeModule:export(Predicate/Arity), Module:import(HomeModule:Predicate/Arity),
    assertz(metta_reference_slot(Module, Name, Arity, imported(HomeModule))).
metta_reference_binding(Space, Module, Name, Arity, Roots, Faces) :-
    metta_reference_detach_import(Module, Name, Arity),
    compiled_function_name(Name, Predicate),
    Module:dynamic(Predicate/Arity),
    functor(Head, Predicate, Arity),
    Head =.. [_|Args],
    metta_reference_goal_list(Roots, Space, Name, Args, Original, Faces, Goals),
    metta_reference_disjunction(Goals, Body),
    wrap_predicate(Module:Head, metta_reference_union, Original, Body),
    retractall(metta_reference_slot(Module, Name, Arity, _)),
    assertz(metta_reference_slot(Module, Name, Arity, wrapped(Head, Original))).

metta_reference_goal_list([], _, _, _, _, _, []).
metta_reference_goal_list([root(Home, OriginalName, Arity)|Roots],
                          Space, Name, Args, Own, Faces, [Goal|Goals]) :-
    (   Home == Space, OriginalName == Name
    ->  Call = call(Own)
    ;   memberchk(Home-HomeModule-Face, Faces),
        Root = root(Home, OriginalName, Arity),
        findall(R, member(OriginalName/Arity-R, Face), HomeRoots),
        compiled_function_name(OriginalName, HomePredicate),
        HomeHead =.. [HomePredicate|Args],
        (   HomeRoots == [Root]
        ->  Call = HomeModule:HomeHead
        ;   metta_reference_own_closure(HomeModule, HomeHead, Closure),
            Call = call(Closure)
        )
    ),
    ( metta_reference_loading(Home)
    -> Goal = (metta_reference_wait(Home), Call)
    ; Goal = Call ),
    metta_reference_goal_list(Roots, Space, Name, Args, Own, Faces, Goals).

% Reinstalling the unchanged native body returns its original definition,
% including when the body never called that definition.
% https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/library/prolog_wrap.pl#L113-L145
metta_reference_own_closure(Module, Head, Closure) :-
    % Workaround: swi-wrapper-roundtrip-merges-closures - copy the native clause body without conflating its original with other retained closures.
    (   '$wrapped_predicate'(Module:Head, Wrappers),
        memberchk(metta_reference_union-Ref, Wrappers)
    ->  clause(Module:WrappedHead, Body, Ref),
        Head =.. [_|Args], WrappedHead =.. [_|Args],
        wrap_predicate(Module:Head, metta_reference_union, Closure, Body)
    ;   setup_call_cleanup(
            true,
            wrap_predicate(Module:Head, metta_reference_capture, Closure,
                           call(Closure)),
            % Workaround: swi-cleanup-window - register capture cleanup before mutation and retry retirement if cleanup is cut.
            catch(ignore(unwrap_predicate(Module:Head, metta_reference_capture)),
                  Ball,
                  ( ignore(unwrap_predicate(Module:Head, metta_reference_capture)),
                    throw(Ball) )))
    ).

metta_reference_disjunction([], fail).
metta_reference_disjunction([Goal], Goal) :- !.
metta_reference_disjunction([Goal|Goals], (Goal;Rest)) :-
    metta_reference_disjunction(Goals, Rest).

metta_reference_detach_import(Module, Name, Arity) :-
    (   retract(metta_reference_slot(Module, Name, Arity, imported(_)))
    ->  compiled_function_name(Name, Predicate), abolish(Module:Predicate/Arity)
    ;   true
    ).

metta_reference_drop_binding(Module, Name, Arity) :-
    (   retract(metta_reference_slot(Module, Name, Arity, Binding))
    ->  compiled_function_name(Name, Predicate),
        ( Binding = imported(_) -> abolish(Module:Predicate/Arity)
        ; functor(Head, Predicate, Arity),
          unwrap_predicate(Module:Head, metta_reference_union),
          abolish(Module:Predicate/Arity) )
    ;   true
    ).

metta_reference_prepare(Module, Name, Arity) :-
    metta_reference_detach_import(Module, Name, Arity).

metta_reference_announce_union(Module, Name, Roots) :-
    ( Roots = [_,_|_] -> metta_reference_note(Module, Name, reference_union(Roots))
    ; true ).

metta_reference_note(Module, Name, Reason) :-
    ( head_pattern_note(Module, Name, [], Name, Reason) -> true
    ; assertz(translator:head_pattern_note(Module, Name, [], Name, Reason), Ref),
      record_source_assertion(Ref),
      print_message(informational, metta_head_pattern_note(Name, [], Name, Reason)) ).

% The declaration pattern is fixed before the store is asked, so the query is
% the indexed lookup of that head and subject rather than a walk over the
% provider's whole population (a class space holds its instances' facts).
metta_reference_metadata(Space, Face, Key, Row) :-
    member(Name/_-root(Home, Original, _), Face), Home \== Space,
    metta_reference_metadata_row(OriginalRow, Original, Name, Row),
    spaces:metta_space_pair(Home, OriginalRow, Token, _),
    \+ metta_reference_projection(Home, _, Token, _),
    Key = origin(Home, Token, Name).
metta_reference_metadata(Space, Face, Key, Row) :-
    member(Name/_-root(Home, Original, _), Face), Home \== Space,
    metta_reference_manifest_row(Home, OriginalRow),
    metta_reference_metadata_row(OriginalRow, Original, Name, Row),
    \+ spaces:metta_space_pair(Home, OriginalRow, _, _),
    copy_term(Row, KeyRow), numbervars(KeyRow, 0, _),
    Key = manifest(Home, Name, KeyRow).

metta_reference_metadata_row([':', Original, Type], Original, Name,
                             [':', Name, Type]).
metta_reference_metadata_row([':<', Original, Type], Original, Name,
                             [':<', Name, Type]).
metta_reference_metadata_row(['@doc', Original|Fields], Original, Name,
                             ['@doc', Name|Fields]).

metta_reference_publish_metadata(Space, Face) :-
    findall(Key-Row, metta_reference_metadata(Space, Face, Key, Row), Rows0),
    sort(Rows0, Rows),
    forall(( metta_reference_projection(Space, Key, Token, Ref),
             \+ memberchk(Key-_, Rows) ),
           ( spaces:metta_remove_occurrence(Space, Token, _),
             retractall(metta_reference_projection(Space, Key, _, Ref)) )),
    forall(member(Key-Row, Rows),
           ( metta_reference_projection(Space, Key, _, _) -> true
           ; metta_add_atom(Space, Row, Token, _),
             ( nonvar(Token), spaces:metta_space_pair(Space, Row, Token, Ref)
             -> assertz(metta_reference_projection(Space, Key, Token, Ref))
             ; true ) )).

metta_reference_track_transaction :-
    (   current_transaction(_)
    ->  ( nb_current('$metta_reference_listening', true) -> true
        ; nb_setval('$metta_reference_listening', true),
          thread_self(Owner),
          prolog_listen(frame_finished,
                        metta_engine:metta_reference_frame_finished(Owner)) ),
        prolog_current_frame(Frame), metta_reference_track_frames(Frame)
    ;   true
    ).

% Workaround: swi-query-frame-discarded-on-engine-destroy - watch the nearest live transaction and exclude finishing frames when transferring its watch.
% prolog_frame_attribute/3 marks its input frame FR_NOTIFY. Stop at the
% nearest transaction: SWI's discard_query notifies an inspected outer query
% after closing its foreign frame, so destroying a suspended engine asserts.
% Its completion refresh registers the next enclosing transaction, if any.
% https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-wam.c#L3052-L3064
% frameFailed leaves the finishing frame in the callback's ancestry. Exclude
% every active completion callback's frame so rollback transfers to a live one.
% https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-wam.c#L903-L915
metta_reference_track_frames(Frame) :-
    prolog_frame_attribute(Frame, predicate_indicator, Predicate),
    % policy-inventory-exempt: mechanism-internal; reason=the three native transaction and snapshot frames from the pinned SWI source above; evidence=engine/metta/references.pl:metta_reference_track_frames/1
    (   memberchk(Predicate, [system:'$transaction'/2, system:'$transaction'/3,
                             system:'$snapshot'/1]),
        \+ metta_reference_finishing(Frame)
    ->  ( metta_reference_pending_frame(Frame) -> true
        ; metta_reference_pending_frames(Frames),
          nb_setval('$metta_reference_frames', [Frame|Frames]) )
    ; prolog_frame_attribute(Frame, parent, Parent),
      metta_reference_track_frames(Parent) ).

% Workaround: swi-named-listener-replacement-lock - register distinct unnamed owner closures and unregister each once.
% frame_finished is global; the frame identifiers and pending set are local.
% Distinct closures also avoid SWI's named-hook replacement path, which leaves
% its list mutex locked at this revision:
% https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-event.c#L145-L160
% [tested: reference_loading:concurrent_transactions_keep_each_others_rollback_listener;
% commit=90ba93eb8f6e98ebfefc55416859bf13de6a8427].
metta_reference_frame_finished(Owner, Frame) :-
    thread_self(Thread),
    ( Owner == Thread -> metta_reference_finish_frame(Owner, Frame) ; true ).

metta_reference_finish_frame(Owner, Frame) :-
    metta_reference_pending_frames(Frames),
    (   selectchk(Frame, Frames, Remaining)
    ->  nb_setval('$metta_reference_frames', Remaining),
        setup_call_cleanup(
            asserta(metta_reference_finishing(Frame), Guard),
            metta_reference_refresh,
            erase(Guard)),
        ( metta_reference_pending_frame(_) -> true
        ; nb_delete('$metta_reference_listening'),
          prolog_unlisten(frame_finished,
                          metta_engine:metta_reference_frame_finished(Owner)) )
    ;   true
    ).

metta_reference_pending_frames(Frames) :-
    ( nb_current('$metta_reference_frames', Frames) -> true ; Frames = [] ).

metta_reference_pending_frame(Frame) :-
    metta_reference_pending_frames(Frames), member(Frame, Frames).

metta_reference_release(Space) :-
    retractall(metta_reference_space_option(Space, _, _)),
    (   retract(metta_reference_seen_space(Space, Module))
    ->  metta_reference_release_loader(Space),
        spaces:metta_reference_mutation_scope(Space, disabled),
        retractall(metta_reference_observed(Space)),
        forall(retract(metta_reference_row(Space, Token, _, _)),
               retractall(metta_reference_map(Token, _, _))),
        retractall(metta_occurrence_grade(Space, _, _, _)),
        retractall(metta_reference_projection(Space, _, _, _)),
        forall(retract(metta_reference_row(Receiver, Token, Space, _)),
               ( retractall(metta_reference_map(Token, _, _)),
                 space_module(Receiver, ReceiverModule),
                 support_graph:support_forget(derived(ReceiverModule, reference_row(Token))) )),
        forall(retract(metta_reference_slot(Module, Name, Arity, Binding)),
               ( compiled_function_name(Name, Predicate),
                 ( Binding = imported(_) -> abolish(Module:Predicate/Arity)
                 ; functor(Head, Predicate, Arity),
                   unwrap_predicate(Module:Head, metta_reference_union) ) )),
        retractall(metta_reference_roots(Module, _, _, _)),
        metta_reference_refresh
    ;   true
    ).

:- dynamic seam:space_releasing/1, seam:deferred_translation_settled/0.
metta_reference_install_hooks :-
    ( metta_reference_hooks -> true
    ; assertz(metta_reference_hooks),
      assertz((seam:source_program_compiled :- metta_reference_refresh)),
      assertz((seam:deferred_translation_settled :- metta_reference_refresh)),
      assertz((seam:space_releasing(Space) :- metta_reference_release(Space))) ).

:- multifile prolog:message//1, prolog:error_message//1.
prolog:message(metta_head_pattern_note(Name, [], _, reference_union(Origins))) -->
    [ '~w is the union of definitions from ~q; use except to select a source'-
      [Name, Origins] ].
prolog:message(metta_head_pattern_note(Name, [], _, reference_missing(Home))) -->
    [ '~w does not currently define ~w; the standing from row will follow it'-
      [Home, Name] ].
prolog:error_message(metta_internal_reference(Home, Name)) -->
    [ '~w is internal in ~w; call (evalc (~w ...) ~w) to use its defining space'-
      [Name, Home, Name, Home] ].
prolog:error_message(metta_reference_map_result(Map, Head, Result)) -->
    [ 'from map ~q returned ~q for ~w; each answer must be a symbol'-
      [Map, Result, Head] ].
