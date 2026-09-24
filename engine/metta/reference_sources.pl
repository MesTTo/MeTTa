% Purpose: project declaration-only FROM origins into home-indexed source readers.
% Assumes: reference_refresh.pl supplies one checked face epoch and the reader
%   supplies parallel source origins [source:
%   engine/metta/reference_refresh.pl:metta_reference_refresh_now/0;
%   commit=1a8c00f93ae6c63ccabd41d39fed3f967dadd3a9].
% Guarantees: local source roots and current callable roots precede imported
%   data names; ambiguous origins refuse on use [tested:
%   reference_source_origins:declarations_introduce_names_but_nested_declarations_and_equations_are_uses,
%   reference_source_origins:callable_union_and_withdrawal_use_standing_roots,
%   reference_source_origins:distinct_origins_refuse_only_the_ambiguous_use; commit=1a8c00f93ae6c63ccabd41d39fed3f967dadd3a9].
% Guarantees: the plan a space's readers were published from is kept beside
%   them, and rows alone extend its origins monotonically or refuse, leaving
%   the space to be planned whole, when they would withdraw one [tested:
%   reference_deltas:every_step_of_a_row_sequence_publishes_what_a_whole_republication_does;
%   commit=WORKTREE].
% Owns resources: metta_reference_source_reader/3 owns exact derived clause
%   references. Refresh replaces them and home release erases them. Their
%   transaction state follows the source rows and existing frame reconciliation.
% Guarded by: metta_reference_sources is a leaf mutex used only for native
%   clause publication. Face and mapper evaluation occur before publication.
% Decides: bind! remains global; FROM elaborates source uses, never supplied values.

:- use_module(library(assoc), [empty_assoc/1, list_to_assoc/2, get_assoc/3,
                                put_assoc/4, gen_assoc/3]).
:- use_module(library(pairs), [group_pairs_by_key/2]).
:- use_module(library(ordsets), [ord_memberchk/2]).
:- dynamic metta_reference_resolve_source/5, metta_reference_source_reader/3.
%The plan a space's readers were last published from: its source map and its
%origins, each name's roots. A publication that owes only new rows extends it
%(metta_reference_source_plan_rows/6); a whole one replaces it.
:- dynamic metta_reference_plan/2.
:- seam:context_reader(metta_reference_source_mapping(Space),
                       '$metta_reference_source_mapping', stack(Space)).

%A plan is source_plan(Map, Origins): Map, each source name's meaning, is what
%the readers resolve by; Origins, each name's roots, what the meanings and the
%canonical declarations are derived from.
metta_reference_source_plan(Space, Face, source_plan(Map, Origins)) :-
    findall(Name,
            ( member(Name/Arity-root(Home, Original, _, _), Face),
              ( integer(Arity) ; Home == Space, Original == Name ) ), Blocked0),
    sort(Blocked0, Blocked),
    findall(Name-Root,
            ( member(Name/declaration-Root, Face),
              Root = root(Home, Original, declaration, []),
              \+ ord_memberchk(Name, Blocked),
              once(metta_reference_source_constructor(Home, Original)) ), Roots0),
    sort(Roots0, Roots),
    group_pairs_by_key(Roots, Groups),
    list_to_assoc(Groups, Origins),
    findall(Name-Meaning,
            ( member(Name-NameRoots, Groups),
              metta_reference_source_meaning(Name, NameRoots, Meaning) ), Pairs),
    list_to_assoc(Pairs, Map).

%The plan a face gains from Entries, the entries new rows alone added to it:
%each declaration-only name among them that nothing in the face blocks gains
%an origin, and every origin the plan had stands. Blocked is a negation over
%the whole face, so an entry that blocks a name holding origins withdraws them;
%this fails then, and the caller plans the face whole. That is the one change
%here that is not monotone, an antijoin whose delta needs the other side's
%whole state [source: Budiu, Chajed, McSherry, Ryzhyk, Tannen, "DBSP:
%Automatic Incremental View Maintenance for Rich Query Languages", PVLDB
%16(7) 2023, doi 10.14778/3587136.3587137, section 7.5]. A name is blocked by
%an integer entry among Entries, by one the face already held, which the
%space's recorded roots name, or by one of the space's own heads; the own
%heads stand, since a change to them is a face event that plans whole.
metta_reference_source_plan_rows(Space, Module, source_plan(Map0, Origins0),
                                 Entries, source_plan(Map, Origins), Added) :-
    findall(Name, ( member(Name/Arity-_, Entries), integer(Arity) ), Blocking0),
    sort(Blocking0, Blocking),
    \+ ( member(Name, Blocking), get_assoc(Name, Origins0, _) ),
    findall(Name-Root,
            ( member(Name/declaration-Root, Entries),
              Root = root(Home, Original, declaration, []),
              \+ ord_memberchk(Name, Blocking),
              \+ metta_reference_roots(Module, Name, _, _),
              \+ metta_reference_local_head(Space, Name, _),
              once(metta_reference_source_constructor(Home, Original)) ), Added0),
    sort(Added0, Added),
    group_pairs_by_key(Added, Groups),
    foldl(metta_reference_source_origin, Groups, Map0-Origins0, Map-Origins).

metta_reference_source_origin(Name-Roots, Map0-Origins0, Map-Origins) :-
    ( get_assoc(Name, Origins0, Known) -> true ; Known = [] ),
    append(Roots, Known, All0), sort(All0, All),
    put_assoc(Name, Origins0, All, Origins),
    (   metta_reference_source_meaning(Name, All, Meaning)
    ->  put_assoc(Name, Map0, Meaning, Map)
    ;   Map = Map0
    ).

metta_reference_source_constructor(Home, Original) :-
    metta_reference_type_subject(Row, Original),
    metta_reference_metadata_origin(Home, Original, Original, _, Row),
    Row = [_, _, Type],
    \+ type_alias_declaration_type(Type).

metta_reference_source_meaning(Name, Roots, Meaning) :-
    findall(Original, member(root(_, Original, _, _), Roots), Originals0),
    sort(Originals0, Originals),
    ( Originals = [Original]
    -> Name \== Original, Meaning = value(Original)
    ; Meaning = ambiguous(Roots) ).

metta_reference_source_metadata_face(Face, source_plan(_, Origins), Metadata) :-
    findall(Entry,
            ( gen_assoc(_, Origins, Roots),
              metta_reference_source_canonical(Roots, Entry) ), Canonical),
    append(Face, Canonical, All),
    sort(All, Metadata).

%The declarations an origin's roots project under their own names.
metta_reference_source_canonical(Roots, Original/declaration-Root) :-
    member(Root, Roots), Root = root(_, Original, _, _).

% Resolve after extension callbacks. A callback may publish a new FROM row.
metta_reference_resolve_source(_, _, tokens, Term, Rewritten) :-
    ( metta_token_claim(_, _, _, _)
    -> substitute_bound_tokens_(Term, Rewritten)
    ; Rewritten = Term ).
metta_reference_resolve_source(_, _, literal, Term, Term).

metta_reference_source_pending(Space, Origin, Policy, Term, Rewritten) :-
    ( metta_reference_refreshing
    -> metta_reference_source_current(Space, Map),
       filereader:source_bound_names(Map, Origin, Policy, Term, Rewritten)
    ; metta_reference_refresh,
      metta_reference_resolve_source(Space, Origin, Policy, Term, Rewritten) ).

% A mapper can read another settled home, but cannot obtain a complete source
% map that depends on its own unfinished result. Held evalc values need no map.
metta_reference_source_current(Space, Map) :-
    ( metta_reference_source_mapping(Space)
    -> throw(error(metta_source_mapping_cycle(Space), none))
    ; metta_with_trailed_push('$metta_reference_source_mapping', Space,
                              metta_reference_source_current_face(Space, Map)) ).

metta_reference_source_current_face(Space, Map) :-
    flag('$metta_reference_epoch', Version, Version),
    metta_reference_local_face(Space, [], Face),
    metta_reference_source_plan(Space, Face, source_plan(Current, _)),
    flag('$metta_reference_epoch', After, After),
    ( After =:= Version -> Map = Current
    ; metta_reference_source_current_face(Space, Map) ).

% Invalidation can call this under the support mutex. No evaluator, mapper,
% typing lock or user callback may enter the leaf publication transaction.
metta_reference_source_queued(Space) :-
    with_mutex(metta_reference_sources,
        ( metta_reference_source_reader(Space, pending, _)
        -> true
        ; metta_reference_source_clauses(Space, Readers),
          Resolver = (metta_reference_resolve_source(Space, Origin, Policy, Term, Out) :-
                          !, metta_reference_source_pending(Space, Origin, Policy, Term, Out)),
          transaction(metta_reference_source_replace(Space,
              [reader(pending, metta_engine, Resolver)|Readers])) )).

metta_reference_publish_source(Space, Plan) :-
    Plan = source_plan(Map, _),
    with_mutex(metta_reference_sources,
        ( empty_assoc(Map)
        -> transaction(( metta_reference_source_replace(Space, []),
                         metta_reference_source_keep(Space, Plan) ))
        ; metta_reference_source_clauses(Space, Readers),
          Resolver = (metta_reference_resolve_source(Space, Origin, Policy, Term, Out) :-
                          !, filereader:source_bound_names(Map, Origin, Policy, Term, Out)),
          transaction(( metta_reference_source_replace(Space,
                            [reader(ready, metta_engine, Resolver)|Readers]),
                        metta_reference_source_keep(Space, Plan) )) )).

metta_reference_source_keep(Space, Plan) :-
    retractall(metta_reference_plan(Space, _)),
    assertz(metta_reference_plan(Space, Plan)).

metta_reference_source_clear(Space) :-
    with_mutex(metta_reference_sources,
               transaction(( metta_reference_source_replace(Space, []),
                             retractall(metta_reference_plan(Space, _)) ))).

metta_reference_source_replace(Space, Clauses) :-
    forall(retract(metta_reference_source_reader(Space, _, Ref)), host_transactions:try_erase(Ref)),
    reverse(Clauses, Reversed),
    forall(member(reader(Kind, Module, Clause), Reversed),
           ( asserta(Module:Clause, Ref),
             assertz(metta_reference_source_reader(Space, Kind, Ref)) )).

% Read the ordinary bodies while holding the source-publication mutex, so the
% list this computes is the list that gets installed: both callers hold that
% mutex across this call AND metta_reference_source_replace/2, so no other
% publication interleaves between the read and the asserts.
% SWI wrappers change a predicate's supervisor, leaving its clauses here:
% https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-wrap.c#L315-L377
%A reader this file installs is ASSERTED, and an asserted clause carries no
%file: clause_property(Ref, file(_)) is therefore the clause store's own record
%of which clauses are the engine's, and it needs no second table agreeing with
%it. The subtraction it replaces, \+ metta_reference_source_reader(_, _, Ref),
%read a dynamic fact, so inside transaction/1 it answered from the CALLING
%THREAD'S SNAPSHOT: a thread whose transaction opened before another thread
%installed a reader never saw that reader's row, took its clause for a generic
%one and projected an already projected body. That arrives as
%metta_source_reader_template(process_loader_form/3, FourReaders), two of them
%carrying a doubled resolve, and it is the same isolation mismatch
%host_transactions:try_erase/1 exists for, met in the filter instead of in the
%erase. This is not the liveness question the waiver journal bars asking of a
%clause reference: `file` is immutable metadata fixed when the clause was
%created, not a fact about whether it still exists
%[measured 2026-09-20: eight runs of a 6,000-iteration suspended-background load
%raised the template error in eight, and in none with this filter; the property
%separates them under both a source consult and the shipped .qlf boot;
%commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f].
metta_reference_source_clauses(Space, Clauses) :-
    findall(reader(rewrite, metta_engine, (Head :- !, Projected)),
            ( Head = rewrite_parsed_form(Space, Origin, _, _, Out),
              clause(Head, Body, Ref),
              clause_property(Ref, file(_)),
              metta_reference_source_rewrite_body(Body, Space, Origin, Out, Projected, 1) ), Rewrite),
    ( Rewrite = [_] -> true
    ; throw(error(metta_source_reader_template(rewrite_parsed_form/5, Rewrite), none)) ),
    findall(reader(loader, filereader, (Head :- !, Resolve, Body)),
            ( clause(filereader:process_loader_form(Space, Parsed, Result), Body, Ref),
              clause_property(Ref, file(_)), nonvar(Parsed),
              metta_reference_source_expression(Parsed, BoundParsed, Origins, Term, Bound),
              Head = process_loader_form(Space, BoundParsed, Result),
              Resolve = metta_engine:metta_reference_resolve_source(
                            Space, origin(expression, Origins), literal, Term, Bound) ), Loaders),
    ( Loaders = [_, _] -> true
    ; throw(error(metta_source_reader_template(process_loader_form/3, Loaders), none)) ),
    append([Rewrite, Loaders,
            [reader(data, filereader,
                    (rewrite_source_data(Space, Origin, Term, Out) :-
                         !, metta_engine:metta_reference_resolve_source(
                                Space, Origin, tokens, Term, Out))),
             reader(bulk, filereader, (data_run(_, Space, _, _) :- !, fail)),
             reader(bulk, filereader, (definition_run(_, Space, _, _) :- !, fail))]], Clauses).

metta_reference_source_expression(parsed(expression, Text, Bound),
                                  parsed(expression, Text, Term), source, Term, Bound).
metta_reference_source_expression(bound_source(Origins, parsed(expression, Text, Bound)),
                                  bound_source(Origins, parsed(expression, Text, Term)),
                                  Origins, Term, Bound).

% Project just the late name-resolution step from the ordinary reader body.
% A changed body shape must update this producer and its controls together.
metta_reference_source_rewrite_body(Goal, Space, Origin, Out, Rewritten, 1) :-
    nonvar(Goal),
    Goal = (metta_token_claim(_, _, _, _) -> substitute_bound_tokens_(Bound, Result)
            ; Identity),
    Result == Out,
    ( Identity == (Out = Bound) ; Identity == (Bound = Out) ), !,
    Rewritten = metta_reference_resolve_source(Space, Origin, tokens, Bound, Out).
%COMPOUND, not merely nonvar. compound_name_arguments/3 THROWS
%type_error(compound, X) when its first argument is an atom, and a body reaches
%here holding the bare cut: this producer asserts a projected reader as
%(Head :- !, Resolve, Body), so rewriting one walks into its `!` and the walk
%dies where it should have stopped. The third clause below is already the right
%answer for a goal with no sub-goals, handing it back unchanged; this guard is
%what kept it from being reached
%[measured 2026-09-20 over eight runs of a 6,000-iteration loop on the
%suspended-background reference load: two ended in compound_name_arguments/3:
%Type error: `compound' expected, found `!', and none did with this guard].
metta_reference_source_rewrite_body(Goal, Space, Origin, Out, Rewritten, Count) :-
    compound(Goal), compound_name_arguments(Goal, Operator, [Left, Right]),
    metta_reference_source_control(Operator), !,
    metta_reference_source_rewrite_body(Left, Space, Origin, Out, BoundLeft, LCount),
    metta_reference_source_rewrite_body(Right, Space, Origin, Out, BoundRight, RCount),
    compound_name_arguments(Rewritten, Operator, [BoundLeft, BoundRight]),
    Count is LCount+RCount.
metta_reference_source_rewrite_body(Goal, _, _, _, Goal, 0).

metta_reference_source_control(',').
metta_reference_source_control(';').
metta_reference_source_control('->').

:- multifile prolog:error_message//1.
prolog:error_message(metta_source_name_ambiguity(Name, Origins)) -->
    [ 'source name ~w has distinct FROM origins ~q; use rename to select distinct names'-
      [Name, Origins] ].
prolog:error_message(metta_source_origins(Term, Origins)) -->
    [ 'form rewriter returned an invalid source-origin tree ~q for ~q'-[Origins, Term] ].
prolog:error_message(metta_source_reader_template(Predicate, Clauses)) -->
    [ 'source reader ~q has an unrecognized projection template ~q'-[Predicate, Clauses] ].
prolog:error_message(metta_source_mapping_cycle(Space)) -->
    [ 'source names for ~w depend on their unfinished FROM map; use held values with evalc while constructing that map'-
      [Space] ].
