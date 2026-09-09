% Purpose: expand transparent, nullary type aliases in their declaration scope.
% Guarantees: normalize_source_type_declarations/3 and
%   validate_type_alias_syntax/2 validate splice syntax before publication
%   [tested: variadic_arrows; commit=6031c83ab3002b5703cb6fcb10e70a60a89f4ad7].
% Assumes: this plain source unit is consulted by engine/metta/types.pl.
% Guarantees: normalize_type_in/4 preserves raw variables, freshens each alias
%   occurrence, reports successful and missing lookup dependencies, and rejects
%   cycles with their owner-qualified path [tested:
%   tests/prolog/suites/typecheck/structural_aliases.plt; commit=acad923476d21110870f235192757281a737ee71].
% Owns resources: type_alias_gate_ref/2 owns installed reader clauses and
%   retires them transactionally on last-alias removal or scope release. The
%   raw store owns declarations and support_graph owns type_alias(Name) roots;
%   no expansion cache is retained [tested: structural_aliases; commit=acad923476d21110870f235192757281a737ee71].
% Guarded by: mutation callers hold with_typing_policy_stable/1 while validating,
%   storing and repairing declarations [tested:
%   tests/prolog/suites/typecheck/structural_aliases.plt; commit=acad923476d21110870f235192757281a737ee71].
%   Two overlapping ENGINE transactions cannot both commit a different alias for
%   one name: metta_validate_pending_type_aliases/0 re-runs the requirement at
%   the outer commit, where the snapshot has refreshed, and the second commit is
%   refused by name [tested:
%   structural_aliases:overlapping_transactions_leave_one_alias_and_name_the_loser;
%   commit=f5eb8775b78519c080da4ea7c6dff81f7be21ef9].
% Fails when: callers expect serializability from overlapping RAW outer
%   transactions a caller opened with transaction/1 itself; the engine has no
%   commit hook inside one of those and the limitation is reproduced by
%   tests/prolog/probes/type_declaration_snapshot.pl [source:
%   docs/journal/2026-09-05-type-declarations-in-overlapping-transactions.md;
%   commit=acad923476d21110870f235192757281a737ee71].
% Decides: aliases substitute syntax, never evaluate terms; their declaration
%   tier fixes the meaning of names inside the RHS [tested:
%   tests/prolog/suites/typecheck/structural_aliases.plt; commit=acad923476d21110870f235192757281a737ee71].

% Keep the native miss first. Untyped data heads need no alias lookup.
normalized_self_type_declaration(X, Type) :-
    '$metta_atoms:&self':'&self'(':', X, Raw, _),
    metta_self_module(Self),
    normalize_type_in(Self, Raw, Type).

scoped_type_declaration(Space, Module, X, Type) :-
    match_stored(Space, [':', X, Raw], Raw, _),
    normalize_type_in(Module, Raw, Type).

% The identity reader owns no expansion state. Alias-bearing scopes install
% indexed clauses ahead of it in the same transaction as their declarations.
:- dynamic normalize_type_in/3, normalize_callable_type_in/3.
:- dynamic type_alias_lookup_changed/2, type_alias_gate_ref/2, type_edge_view/2.

normalize_type_in(_, Raw, Raw).

% This is metta_runtime_type/2's projection with a scope slot. Keeping the
% projection in the existing read avoids an extra call for plain arrows.
normalize_callable_type_in(_, Raw, Type) :-
    (   nonvar(Raw), Raw = [Head|_], Head \== '->',
        metta_arrow_type_chain(Raw, Types)
    ->  Type = [->|Types]
    ;   Type = Raw
    ).

normalize_type_in(Module, Raw, Canonical, Dependencies) :-
    normalize_type_view(Module, live, Raw, Canonical, Found, []),
    sort(Found, Dependencies).

normalize_type_view(Module, View, Raw, Canonical, Dependencies, Tail) :-
    (   acyclic_term(Raw)
    ->  expand_type_syntax(Module, View, Raw, [], Canonical, Dependencies, Tail)
    ;   throw(error(domain_error(acyclic_type_syntax, Raw), none))
    ).

expand_type_syntax(_, _, Raw, _, Raw, Tail, Tail) :- var(Raw), !.
expand_type_syntax(Module, View, Raw, Stack, Canonical, Deps, Tail) :-
    atom(Raw),
    !,
    type_alias_lookup(Module, View, Raw, Owner, Found, Deps, More),
    (   Found = alias(RHS)
    ->  Key = Owner:Raw,
        % Haskell 2010 section 4.2.2 forbids cyclic synonyms. The stack names
        % the closed expansion path, rather than assigning an order-dependent
        % meaning to recursion: https://www.haskell.org/onlinereport/haskell2010/haskellch4.html#x10-730004.2.2
        (   memberchk(Key, Stack)
        ->  reverse([Key|Stack], Expansion),
            append(_, [Key|CycleTail], Expansion),
            !,
            throw(error(metta_type_alias_cycle([Key|CycleTail]), none))
        ;   expand_type_syntax(Owner, View, RHS, [Key|Stack], Canonical,
                               More, Tail)
        )
    ;   Canonical = Raw,
        More = Tail
    ).
expand_type_syntax(Module, View, [Head|Rest], Stack, [Head|Types], Deps, Tail) :-
    nonvar(Head),
    type_alias_form_head(Head),
    !,
    expand_type_items(Module, View, Rest, Stack, Types, Deps, Tail).
expand_type_syntax(Module, View, [Head|Rest], Stack, [Type|Types], Deps, Tail) :-
    !,
    expand_type_syntax(Module, View, Head, Stack, Type, Deps, More),
    expand_type_items(Module, View, Rest, Stack, Types, More, Tail).
expand_type_syntax(_, _, Raw, _, Raw, Tail, Tail).

expand_type_items(_, _, Raw, _, Raw, Tail, Tail) :- var(Raw), !.
expand_type_items(_, _, [], _, [], Tail, Tail) :- !.
expand_type_items(Module, View, [Raw|Rest], Stack, [Type|Types], Deps, Tail) :-
    !,
    expand_type_syntax(Module, View, Raw, Stack, Type, Deps, More),
    expand_type_items(Module, View, Rest, Stack, Types, More, Tail).
expand_type_items(Module, View, Raw, Stack, Type, Deps, Tail) :-
    expand_type_syntax(Module, View, Raw, Stack, Type, Deps, Tail).

% These are syntax delimiters, including an annotated arrow's complete head.
% Reserved type syntax cannot be redefined by an alias. Written as clause facts
% rather than a closed list so each head is one indexed lookup and the policy
% inventory reads them as mechanism, which they are.
type_alias_form_head('Alias').
type_alias_form_head('->').
type_alias_form_head(':Atom').
type_alias_form_head(':Expression').
type_alias_form_head(':seg').
type_alias_form_head(Head) :-
    atom(Head),
    atom_concat('-[', Rest, Head),
    atom_concat(_, ']->', Rest).

% A declaration in a child tier hides a shared alias of the same name. An
% inherited alias expands only in its owner's tier, including its misses.
type_alias_lookup(Module, View, Name, Owner, Found,
                  [derived(Module, type_alias(Name))|Deps], Tail) :-
    type_alias_local(Module, View, Name, Local),
    (   Local \== missing
    ->  Owner = Module,
        Found = Local,
        Deps = Tail
    ;   metta_self_module(Module)
    ->  Owner = Module,
        Found = missing,
        Deps = Tail
    ;   metta_self_module(Self),
        Owner = Self,
        Deps = [derived(Self, type_alias(Name))|Tail],
        type_alias_local(Self, View, Name, Found)
    ).

type_alias_local(Module, source(Source, Entries), Name, Found) :-
    Module == Source,
    get_assoc(Name, Entries, Rows),
    !,
    copy_term(Rows, Fresh),
    type_alias_from_rows(Fresh, Found).
type_alias_local(Module, _, Name, Found) :-
    metta_module_space(Module, Space),
    (   once(( match_stored(Space, [':', Name, Raw], Raw, _),
               type_alias_declaration_type(Raw), Raw = ['Alias', RHS] ))
    ->  Found = alias(RHS)
    ;   once(match_stored(Space, [':', Name, _], true, _))
    ->  Found = declared
    ;   Found = missing
    ).

type_alias_from_rows(Rows, alias(RHS)) :-
    member(Raw, Rows),
    type_alias_declaration_type(Raw),
    Raw = ['Alias', RHS],
    !.
type_alias_from_rows(_, declared).

% Each prefix map holds raw declarations. It is private to preparation and
% never changes the live store, so refusal precedes source effects.
normalize_source_type_declarations(Module, Declarations, Normalized) :-
    empty_assoc(Empty),
    normalize_source_type_declarations(Declarations, Module, Empty, Normalized).

normalize_source_type_declarations([], _, _, []).
normalize_source_type_declarations([Name-Raw|Rest], Module, Prefix,
                                   [Name-type_syntax(Raw, Type)|Types]) :-
    translator:validate_type_splices(Raw),
    type_alias_source_step(Module, Name, Raw, Prefix, Next),
    normalize_type_view(Module, source(Module, Next), Raw, Type, _, []),
    normalize_source_type_declarations(Rest, Module, Next, Types).

type_alias_source_step(Module, Name, Raw, Prefix, Next) :-
    (   get_assoc(Name, Prefix, Rows)
    ->  true
    ;   metta_module_space(Module, Space),
        findall(T, match_stored(Space, [':', Name, T], T, _), Rows)
    ),
    (   type_alias_declaration_type(Raw)
    ->  validate_type_alias_syntax(Name, Raw),
        Raw = ['Alias', RHS],
        forall(( member(Old, Rows), type_alias_declaration_type(Old),
                 Old = ['Alias', Standing] ),
               require_same_type_alias(Module, Name, Standing, RHS)),
        note_pending_type_alias(Module, Name, RHS)
    ;   true
    ),
    put_assoc(Name, Prefix, [Raw|Rows], Next),
    (   type_alias_declaration_type(Raw)
    ->  normalize_type_view(Module, source(Module, Next), Name, _, _, [])
    ;   true
    ).

type_alias_declaration_type(Type) :-
    nonvar(Type), Type = [Head|_], Head == 'Alias'.

validate_type_alias_syntax(Name, Raw) :-
    (   atom(Name), nonvar(Raw), Raw = ['Alias', _], acyclic_term(Raw)
    ->  true
    ;   throw(error(domain_error(type_alias_declaration, [':', Name, Raw]), none))
    ),
    translator:validate_type_splices(Raw),
    (   type_alias_form_head(Name)
    ->  throw(error(permission_error(redefine, type_form, Name), none))
    ;   true
    ).

%The check above reads the rows this transaction can SEE, which under SWI's
%snapshot isolation is the state as of its start plus its own writes. Two
%overlapping transactions therefore each find no conflict and both commit, and
%the space ends holding `(: Count (Alias Number))` and `(: Count (Alias
%String))` together [measured 2026-09-05 on the clean base, reproduced without
%aliases with two typing rules, so it is the substrate rather than this
%feature].
%
%So the same check runs a SECOND time at commit, where it sees the merged
%state. `transaction/3` is built for this and SWI names the pattern: it calls
%Goal, locks the mutex, "changes the visibility to the current global state
%combined with the changes made by Goal", calls the constraint, and only then
%commits, discarding everything on failure or exception
%[source: SWI-Prolog transaction/3, and the outer branch of pl-transaction.c
%is the one that refreshes gen_start under the constraint mutex and holds it
%through commit].
%
%Recorded per thread and only inside a transaction, so an ordinary declaration
%pays one metta_in_user_transaction/0 check and nothing else.
note_pending_type_alias(Module, Name, RHS) :-
    (   metta_in_user_transaction
    ->  (   nb_current('$metta_tx_aliases', Pending)
        ->  true
        ;   Pending = []
        ),
        nb_setval('$metta_tx_aliases', [pending(Module, Name, RHS)|Pending])
    ;   true
    ).

%The commit constraint. Re-reads each name's standing rows in the refreshed
%state and re-runs the same requirement, so a conflict another transaction
%committed while this one ran is refused HERE rather than silently accepted.
%Throwing rather than failing, because a bare failure would discard the
%transaction without saying why, and the error already renders.
metta_validate_pending_type_aliases :-
    (   nb_current('$metta_tx_aliases', Pending)
    ->  nb_setval('$metta_tx_aliases', []),
        forall(member(pending(Module, Name, RHS), Pending),
               validate_committed_type_alias(Module, Name, RHS))
    ;   true
    ).

%The recorded list is nb_setval, which does not unwind on backtracking, so a
%NESTED transaction that declared an alias and then rolled back leaves its
%entry behind. Validating that entry would refuse the outer commit for a
%declaration that no longer exists, which is a worse failure than the one this
%repairs. So the presence of our own row in the refreshed state is the first
%question: if the declaration did not survive, there is nothing to conflict
%with and nothing to check.
validate_committed_type_alias(Module, Name, RHS) :-
    metta_module_space(Module, Space),
    findall(Standing,
            ( match_stored(Space, [':', Name, T], T, _),
              type_alias_declaration_type(T),
              T = ['Alias', Standing] ),
            Committed),
    (   member(Ours, Committed), Ours =@= RHS
    ->  forall(member(Standing, Committed),
               require_same_type_alias(Module, Name, Standing, RHS))
    ;   true
    ).

require_same_type_alias(Module, Name, Standing, Requested) :-
    (   Standing =@= Requested
    ->  true
    ;   metta_module_space(Module, Space),
        throw(error(metta_type_alias_conflict(Space, Name, Standing, Requested),
                    none))
    ).

validate_type_alias_declaration(Module, Name, Raw) :-
    validate_type_alias_syntax(Name, Raw),
    empty_assoc(Empty),
    type_alias_source_step(Module, Name, Raw, Empty, _).

% A raw declaration can change lookup even when it is not an Alias: adding a
% local type declaration hides a shared alias, and removing it reveals that
% alias. Runnable templates are untracked, so they are evicted as well.
type_alias_lookup_changed(_, _).

type_alias_scope(Module, shared) :- metta_self_module(Module), !.
type_alias_scope(Module, local(Module)).

type_alias_scope_module(shared, _).
type_alias_scope_module(local(Module), Module).

% First arrival pays for observing the retained annotations that predate it.
% Later compilations publish these dependencies directly. The same graph owns
% both paths, including unsuccessful lookups and source-owned support edges.
enable_type_alias_scope(Module) :-
    type_alias_scope(Module, Scope),
    (   type_alias_gate_ref(Scope, _)
    ->  true
    ;   type_alias_scope_module(Scope, Reader),
        asserta((normalize_type_in(Reader, Raw, Type) :- !,
                    normalize_type_view(Reader, live, Raw, Type, _, [])), R1),
        asserta((normalize_callable_type_in(Reader, Raw, Type) :- !,
                    normalize_type_view(Reader, live, Raw, Expanded, _, []),
                    metta_runtime_type(Expanded, Type)), R2),
        asserta((type_alias_lookup_changed(Reader, Name) :- !,
                    type_alias_lookups_changed(Reader, [Name])), R3),
        asserta((metta_types_match_in(Reader, Left, Right) :- !,
                    normalize_callable_type_in(Reader, Left, L),
                    normalize_callable_type_in(Reader, Right, R),
                    metta_resolved_types_match_in(Reader, L, R)), R4),
        asserta((has_type_in(Reader, Value, RawType) :- !,
                    normalize_callable_type_in(Reader, RawType, Type),
                    has_resolved_type_in(Reader, Value, Type)), R5),
        asserta((type_declaration_in(Reader, X, T) :- !,
                    raw_type_declaration_in(Reader, X, Raw, Owner),
                    normalize_type_in(Owner, Raw, T)), R6),
        asserta((governing_type_declaration_in(Reader, X, T) :- !,
                    raw_governing_type_declaration_in(Reader, X, Raw, Owner),
                    normalize_callable_type_in(Owner, Raw, T)), R7),
        asserta((definition_type_declaration_in(Reader, X, T) :- !,
                    raw_definition_type_declaration_in(Reader, X, Raw),
                    normalize_callable_type_in(Reader, Raw, T)), R8),
        once(( clause(type_witness_in(Reader, Value, Type), Witness, Original),
               \+ type_alias_gate_ref(_, Original) )),
        asserta((type_witness_in(Reader, Value, RawType) :- !,
                    normalize_callable_type_in(Reader, RawType, Type),
                    Witness), R9),
        asserta((type_edge_view(visible(Reader), View) :- !,
                    expanded_type_edge_view(visible(Reader), View)), R10),
        type_alias_scope_space(Scope, Space),
        asserta((type_edge_view(space(Space), View) :- !,
                    expanded_type_edge_view(space(Space), View)), R11),
        maplist(assert_type_alias_gate_ref(Scope),
                [R1,R2,R3,R4,R5,R6,R7,R8,R9,R10,R11]),
        spaces:set_type_alias_mutation_scope(Scope, enabled),
        filereader:set_type_alias_support_scope(Scope, enabled)
    ).

assert_type_alias_gate_ref(Scope, Ref) :- assertz(type_alias_gate_ref(Scope, Ref)).

type_alias_scope_space(shared, _).
type_alias_scope_space(local(Module), Space) :- metta_module_space(Module, Space).

retire_type_alias_scope(Module) :-
    type_alias_scope(Module, Scope),
    forall(retract(type_alias_gate_ref(Scope, Ref)), erase(Ref)),
    filereader:set_type_alias_support_scope(Scope, disabled),
    spaces:set_type_alias_mutation_scope(Scope, disabled).

refresh_type_alias_scope(Module) :-
    type_alias_scope(Module, Scope),
    (   type_alias_gate_ref(Scope, _),
        metta_module_space(Module, Space),
        \+ stored_type_alias(Space)
    ->  retire_type_alias_scope(Module)
    ;   true
    ).

type_alias_lookups_changed(Module, Names) :-
    findall(Root,
            ( member(Name, Names), Root = derived(Module, type_alias(Name)),
              once(supports(Root, _)) ),
            Roots),
    support_invalidate_many(Roots),
    filereader:repair_typing_policy_invalidations,
    clear_translation_cache,
    refresh_type_alias_scope(Module).

% Include the declared function itself: its annotation controls static
% parameter proofs and output finality even if its body never names it.
type_annotation_support(Module, Symbol, Support) :-
    raw_governing_type_declaration_in(Module, Symbol, Raw, Owner),
    normalize_type_in(Owner, Raw, _, Dependencies),
    member(Support, Dependencies).

:- multifile prolog:error_message//1.
prolog:error_message(metta_type_alias_cycle(Path)) -->
    [ 'cyclic type alias expansion: ~w'-[Path] ].
prolog:error_message(metta_type_alias_conflict(Space, Name, Standing, Requested)) -->
    [ 'conflicting type alias ~w in ~w: ~p versus ~p'-
      [Name, Space, Standing, Requested] ].

% A widening query owns this view. Ground left sides use the same AVL library
% as seen_types/2; polymorphic edges retain source order and fresh variables.
% No value survives the query, so declaration edits cannot leave stale edges.
type_edge_view(Scope, Scope).

expanded_type_edge_view(Scope, expanded(Ordered, Ground, Polymorphic)) :-
    findall(edge(Left, Right),
            ( raw_type_edge(Scope, Owner, RawLeft, RawRight),
              normalize_type_in(Owner, [RawLeft, RawRight], [Left, Right]) ),
            Edges),
    findall(N-Edge, nth1(N, Edges, Edge), Ordered),
    empty_assoc(Empty),
    index_type_edges(Ordered, Empty, Ground, Polymorphic).

stored_type_alias(Space) :-
    once(( match_stored(Space, [':', _, Raw], Raw, _),
           type_alias_declaration_type(Raw) )).

raw_type_edge(space(Space), Module, Left, Right) :-
    space_module(Space, Module),
    match_stored(Space, [':<', Left, Right], Right, _).
raw_type_edge(visible(Module), Owner, Left, Right) :-
    (   metta_module_space(Module, Space), Owner = Module,
        match_stored(Space, [':<', Left, Right], Right, _)
    ;   \+ metta_self_module(Module), metta_self_module(Owner),
        match_stored('&self', [':<', Left, Right], Right, _)
    ).

index_type_edges([], Index, Index, []).
index_type_edges([N-edge(Left,Right)|Rest], Empty, Index, Polymorphic) :-
    index_type_edges(Rest, Empty, Following, Tail),
    (   ground(Left)
    ->  ( get_assoc(Left, Following, More) -> true ; More = [] ),
        put_assoc(Left, Following, [N-edge(Left,Right)|More], Index),
        Polymorphic = Tail
    ;   Index = Following,
        Polymorphic = [N-edge(Left,Right)|Tail]
    ).

type_edge_from_view(visible(Module), Left, Right) :-
    metta_self_module(Module), !,
    match_stored('&self', [':<', Left, Right], Right, _).
type_edge_from_view(visible(Module), Left, Right) :-
    metta_module_space(Module, Space),
    ( match_stored(Space, [':<', Left, Right], Right, _)
    ; match_stored('&self', [':<', Left, Right], Right, _) ).
type_edge_from_view(space(Space), Left, Right) :-
    match_stored(Space, [':<', Left, Right], Right, _).
type_edge_from_view(expanded(All, Ground, Polymorphic), Left, Right) :-
    (   ground(Left)
    ->  ( get_assoc(Left, Ground, Exact) -> true ; Exact = [] ),
        % append/3, not merge/3: the two lists are enumerated by member/2
        % below so their interleaving is immaterial, and merge/3 is a
        % deprecated autoload from library(backward_compatibility) that a
        % NO_AUTOLOAD=1 boot reports undefined [tested: prolog-static and
        % no-autoload lanes; commit=4f2bd4835d3bae3eb68ccb668072d19558eeae1e].
        append(Exact, Polymorphic, Candidates)
    ;   Candidates = All
    ),
    member(_-Raw, Candidates),
    copy_term(Raw, edge(Left, Right)).

% Cast's metatype branch historically needs no space. Leave invalid space
% handling to its existing get-type-space branch when that branch is needed.
normalize_cast_type(Space, Raw, Canonical) :-
    (   nonvar(Space), metta_space_name(Space)
    ->  space_module(Space, Module),
        normalize_type_in(Module, Raw, Canonical)
    ;   Canonical = Raw
    ).

:- multifile seam:effect_operation_name/3.
seam:effect_operation_name(normalize_cast_type(_, _, _),
                           '__metta_type_syntax__', 2).
