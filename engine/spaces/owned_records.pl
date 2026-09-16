% Purpose: validate native owned records at outer commit and read their rows.
% Assumes: spaces.pl consults this unit; public declarations enter add_sexp/4.
% Owns resources: prepared checks retain source references until their outer
%   transaction completes; no pending registry or listener is installed.
% Guarded by: metta_validate_owned_records/1 runs under the existing
%   '$metta_materialization' outer commit mutex and calls native readers only
%   [source: engine/materialize.pl:materialization_transaction/2; commit=c5bdd73e06840e1d0fd0991523983c75def074f6].
% Decides: declared records have at most one value and require one live owner;
%   undeclared native relations retain ordinary snapshot semantics
%   [source: engine/spaces/owned_records.pl:metta_owned_validate_key/2; commit=c5bdd73e06840e1d0fd0991523983c75def074f6].
% Guarantees: owned-record-read validates original keys and occurrence counts
%   in one database snapshot; stored values remain inside complete row envelopes
%   [source: engine/spaces/owned_records.pl:'owned-record-read'/2; commit=dbb95d0bff10a93f2fef0453195b2331918f92dc].
%   A read refusal names 'owned-record-read'/2 and its repair; only the outer
%   commit validator asks for a retry
%   [tested: owned_record_reads:read_refusals_name_the_reader_and_the_repair; commit=e4fdf699f9dedb73f1fe0de7446334b60bd8dc36].
%   metta_owned_record_occurrences/3 exposes those same checked references to
%   native allocation producers, including the zero-owner/zero-value state,
%   and refuses under its own name
%   [source: engine/spaces/owned_records.pl:metta_owned_read_references/5; commit=05fae56ad5b23baa140cb4e6454cb7b304c06f4f].

:- multifile seam:transaction_constraint/1.

seam:transaction_constraint(spaces:metta_validate_owned_records(Prepared)) :-
    spaces:metta_prepare_owned_records(Prepared).

% Validate syntax before publication, including after a catalog kind is
% withdrawn. These are native storage patterns, never executable selectors.
metta_check_owned_record(Row) :-
    copy_term_nat(Row, Plain),
    (   acyclic_term(Plain),
        Plain = ['@owned-record', Home, Owner, Storage, Prefix],
        ground(Home), metta_owned_space_pattern(Home),
        metta_owned_space_pattern(Storage),
        is_list(Prefix), Prefix = [Head|_], atom(Head),
        term_variables([Home, Owner], OwnerVars),
        term_variables([Storage, Prefix], RecordVars),
        metta_owned_same_variables(OwnerVars, RecordVars)
    ->  metta_owned_require_native(Home, Row),
        ( ground(Storage) -> metta_owned_require_native(Storage, Row) ; true )
    ;   throw(error(domain_error(native_owned_record_declaration, Row),
                    context(metta_check_owned_record/1,
                            'use a fixed native owner home and a finite prefix; owner and record must determine each other')))
    ).

metta_owned_space_pattern(Space) :- var(Space), !.
metta_owned_space_pattern(Space) :- atom(Space), !.
metta_owned_space_pattern(Space) :-
    is_list(Space), Space = [Head|_], atom(Head).

metta_owned_same_variables(Left, Right) :-
    sort(Left, LeftSet), sort(Right, RightSet), LeftSet == RightSet.

metta_owned_require_native(Space, Row) :-
    (   seam:foreign_space(Space)
    ->  throw(error(permission_error(declare, native_owned_record, Row),
                    context(metta_check_owned_record/1,
                            'owned records require native storage')))
    ;   true
    ).

% The host supplies the net delta once. Erased cache entries recover the
% native identity of a space retired inside this same transaction.
metta_prepare_owned_records(owned(Changes, Sources, Keys, Removed, Views)) :-
    transaction_updates(Updates),
    findall(cache(Space, Module),
            ( member(Update, Updates), metta_owned_update(Update, _, Ref),
              metta_owned_cache_reference(Ref, Space, Module) ), Caches),
    findall(change(Action, Space, Row, Ref),
            ( member(Update, Updates), metta_owned_update(Update, Action, Ref),
              metta_owned_reference(Ref, Caches, Space, Row, _) ), Delta),
    Delta \== [],
    findall(Change, (member(Row, Delta), metta_owned_change(Row, Change)), Raw),
    metta_owned_unique(Raw, Changes),
    findall(Ref,
            ( member(change(removed, '&metta', Row, Ref), Delta),
              metta_owned_declaration_row(Row) ), Removed),
    findall(Space-View,
            ( ( member(change(_, Space, _, _), Delta)
              ; member(cache(Space, _), Caches) ),
              metta_owned_view(Space, Caches, View) ), DeltaViews),
    sort(DeltaViews, Views),
    metta_owned_used_sources(Changes, Views, CurrentUses),
    findall(used(Row, Ref, Use),
            ( member(change(removed, '&metta', Row, Ref), Delta),
              metta_owned_declaration_row(Row),
              ( Use = none
              ; member(Change, Changes),
                metta_owned_change_key(Row, Change, Changes, Views, Key),
                Use = some(Key) ) ), RemovedUses),
    append(CurrentUses, RemovedUses, Uses),
    findall(source(Row, Ref), member(used(Row, Ref, _), Uses), Snapshot),
    metta_owned_sources(Snapshot, Sources),
    maplist(metta_owned_check_source, Sources),
    findall(Key,
            ( member(used(_, _, some(Key)), Uses)
            ; member(declaration(Template), Changes),
              metta_owned_declared_key(Template, Views, Key) ), Keys0),
    sort(Keys0, Keys),
    forall(member(key(Home, _, Storage, _), Keys),
           ( metta_owned_require_native(Home, Home),
             metta_owned_require_native(Storage, Storage) )).

metta_owned_update(Update, Action, Ref) :-
    compound(Update), compound_name_arguments(Update, Kind, [Ref]),
    ( Kind == erased -> Action = removed
    ; (Kind == asserta ; Kind == assertz), Action = added ).

% Workaround: swi-bound-clause-reference-ignores-snapshot - decompile an admitted occurrence even after another transaction erases it.
% The caller already selected Ref through its snapshot or native write delta.
% This retrieves syntax, never liveness. SWI's bound-reference clause/3 rejects
% CL_ERASED globally, while '$clause'/4 retains the reference's original term.
% [source: https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-comp.c#L6838-L6849; commit=c5bdd73e06840e1d0fd0991523983c75def074f6].
metta_owned_clause(Ref, Head) :- '$clause'(Head, true, Ref, _).

metta_owned_cache_reference(Ref, Space, Module) :-
    catch(clause_property(Ref, predicate(spaces:native_storage_module_cache/2)), _, fail),
    catch(metta_owned_clause(Ref, spaces:native_storage_module_cache(Space, Module)), _, fail).

metta_owned_reference(Ref, Caches, Space, Row, view(Module, Functor)) :-
    catch(clause_property(Ref, predicate(Module:Name/_)), _, fail),
    ( native_storage_module_cache(Space, Module)
    -> true
    ; member(cache(Space, Module), Caches) ),
    catch(metta_owned_clause(Ref, Module:Head), _, fail),
    metta_owned_functor(Space, Functor),
    ( Name == '$metta_native_scalar'
    -> Head = '$metta_native_scalar'(Atom, _)
    ; Name == Functor, metta_storage_term(Functor, Atom, _, Head) ),
    copy_term_nat(Atom, Row).

% A cache reference establishes the space's native representation even when
% its parametric registration has just been erased by drop-space.
metta_owned_functor(Space, Functor) :-
    ( atom(Space) -> Functor = Space ; Functor = '$metta_parametric_atom' ).

metta_owned_view(Space, Caches, view(Module, Functor)) :-
    ( native_storage_module_cache(Space, Module)
    -> true
    ; member(cache(Space, Module), Caches) ),
    !, metta_owned_functor(Space, Functor).
metta_owned_view(_, _, absent).

metta_owned_key_view(Space, Views, View) :-
    ( memberchk(Space-Prepared, Views), Prepared \== absent
    -> View = Prepared
    ; metta_owned_view(Space, [], View) ).

metta_owned_change(change(Action, Space, Row, _), row(Space, Prefix)) :-
    is_list(Row), append(Prefix, [_], Row), Prefix \== [],
    metta_owned_change_admits(Action, Prefix).
metta_owned_change(change(Action, Space, Row, _), owner(Space, Owner)) :-
    nonvar(Row), Row = [Head, Owner], Head == 'owned-by',
    metta_owned_change_admits(Action, Owner).
metta_owned_change(change(_, '&metta', Row, _), declaration(Row)) :-
    metta_owned_declaration_row(Row).

% An occurrence whose key is not ground never came through a commit, and it
% has to be able to leave through one: its removal derives no key, so it
% contributes no check. Adding one still refuses in metta_owned_ground/1.
metta_owned_change_admits(added, _).
metta_owned_change_admits(removed, Key) :- ground(Key).

metta_owned_declaration_row(Row) :-
    nonvar(Row), Row = [Head|_], Head == '@owned-record'.

metta_owned_source_for_change(Change, Row, Ref) :-
    copy_term_nat(Change, QueryChange),
    metta_owned_source_query(QueryChange, Query),
    metta_native_pair('&metta', Query, _, Ref),
    metta_owned_view('&metta', [], View),
    metta_owned_original(View, Ref, Row), metta_owned_declaration_row(Row),
    ( Change = declaration(Template) -> Row =@= Template ; true ).

metta_owned_source_query(row(Space, Prefix), ['@owned-record', _, _, Space, Prefix]).
metta_owned_source_query(owner(Home, Owner), ['@owned-record', Home, Owner, _, _]).
metta_owned_source_query(declaration(Template), Template).

% Lookup follows the storage prefix or owner using the native catalog index.
% An ordinary transaction does not scan every class declaration or record.
metta_owned_used_sources(Changes, Views, Uses) :-
    findall(used(Row, Ref, Use),
            ( member(Change, Changes), metta_owned_source_for_change(Change, Row, Ref),
              ( Change = declaration(_) -> Use = none
              ; metta_owned_change_key(Row, Change, Changes, Views, Key), Use = some(Key) ) ),
            Uses).

metta_owned_check_source(schema(Row, _)) :- metta_check_owned_record(Row).

metta_owned_variant_key(Term, Key) :-
    copy_term_nat(Term, Copy),
    metta_owned_canonical(Copy, Key), numbervars(Key, 0, _).

% Tag syntax before numbering variables: a literal '$VAR'(0) must not alias
% a declaration variable in the sort key.
metta_owned_canonical(Term, variable(Term)) :- var(Term), !.
metta_owned_canonical(Term, atomic(Term)) :- atomic(Term), !.
metta_owned_canonical(Term, compound(Name, Fields)) :-
    compound_name_arguments(Term, Name, Arguments),
    maplist(metta_owned_canonical, Arguments, Fields).

metta_owned_unique(Terms, Unique) :-
    findall(Key-Term,
            ( member(Term, Terms), metta_owned_variant_key(Term, Key) ), Pairs),
    keysort(Pairs, Sorted), group_pairs_by_key(Sorted, Groups),
    findall(Term, member(_-[Term|_], Groups), Unique).

metta_owned_sources(Rows, Sources) :-
    findall(Key-source(Row, Ref),
            ( member(source(Row, Ref), Rows), metta_owned_variant_key(Row, Key) ), Pairs),
    keysort(Pairs, Sorted), group_pairs_by_key(Sorted, Groups),
    maplist(metta_owned_source_group, Groups, Sources).

metta_owned_source_group(_-Rows, schema(Template, Refs)) :-
    Rows = [source(Template, _)|_],
    findall(Ref, member(source(_, Ref), Rows), Unsorted), sort(Unsorted, Refs).

metta_owned_change_key(Template, Change, Changes, Views, Key) :-
    copy_term_nat(Template, ['@owned-record', Home, Owner, Storage, Prefix]),
    (   Change = row(Space, Actual),
        unifiable(Storage-Prefix, Space-Actual, _)
    ->  metta_owned_ground(Space-Actual),
        ( ground(Storage) -> Anchored = true ; Anchored = false ),
        Storage = Space, Prefix = Actual,
        ( Anchored == true -> true
        ; metta_owned_owner_observed(Home, Owner, Changes, Views) )
    ;   Change = owner(Space, Actual),
        unifiable(Home-Owner, Space-Actual, _),
        metta_owned_ground(Space-Actual), Home = Space, Owner = Actual
    ),
    metta_owned_declared_storage(Template, Storage, Views),
    metta_owned_key(Home, Owner, Storage, Prefix, Key).

metta_owned_owner_observed(Home, Owner, Changes, Views) :-
    ( member(owner(ActualHome, ActualOwner), Changes),
      unifiable(Home-Owner, ActualHome-ActualOwner, _),
      metta_owned_ground(ActualHome-ActualOwner),
      Home = ActualHome, Owner = ActualOwner
    -> true
    ; metta_owned_key_view(Home, Views, View),
      once(metta_owned_owner(View, Owner, _)) ).

metta_owned_key(Home, Owner, Storage, Prefix, key(Home, Owner, Storage, Prefix)) :-
    metta_owned_ground([Home, Owner, Storage, Prefix]).

% Preparation, validation and the reader all reach this; the context names no
% phase, so a refusal never blames a predicate that did not run.
metta_owned_ground(Key) :-
    ( ground(Key), acyclic_term(Key) -> true
    ; throw(error(domain_error(ground_owned_record_key, Key),
                  context(_, 'owned record keys must be ground; stored values may contain variables'))) ).

% This phase sees the current committed store combined with this transaction.
% New declarations are already syntax-checked by their publication door.
metta_validate_owned_records(owned(Changes, Sources, Prepared, Removed, Views)) :-
    maplist(metta_owned_source_survives(Removed), Sources),
    metta_owned_used_sources(Changes, Views, Current),
    findall(Key, member(used(_, _, some(Key)), Current), Added),
    findall(Key,
            ( member(declaration(Template), Changes),
              metta_owned_declared_key(Template, Views, Key) ), Declared),
    append([Prepared, Added, Declared], AllKeys), sort(AllKeys, Keys),
    maplist(metta_owned_validate_key(Views), Keys).

metta_owned_source_survives(Removed, schema(Template, Refs)) :-
    copy_term_nat(Template, Query),
    (   member(Ref, Refs),
        ( memberchk(Ref, Removed)
        ; metta_native_pair('&metta', Query, _, Live), Live == Ref )
    ->  true
    ;   throw(error(metta_owned_record_conflict(declaration(Template), withdrawn),
                    context(metta_validate_owned_records/1,
                            'an observed owned-record declaration was withdrawn; retry the outer transaction')))
    ).

% Declaration changes inspect their currently covered population once. Owner
% rows cover absent fields; fixed storage also exposes orphaned value rows.
metta_owned_declared_key(Template, Views, Key) :-
    copy_term_nat(Template, ['@owned-record', Home, Owner, Storage, Prefix]),
    metta_owned_key_view(Home, Views, View),
    metta_owned_owner(View, Owner, _),
    metta_owned_declared_storage(Template, Storage, Views),
    metta_owned_key(Home, Owner, Storage, Prefix, Key).
metta_owned_declared_key(Template, Views, Key) :-
    copy_term_nat(Template, ['@owned-record', Home, Owner, Storage, Prefix]),
    ground(Storage),
    metta_owned_key_view(Storage, Views, View),
    metta_owned_value(View, Prefix, _),
    metta_owned_key(Home, Owner, Storage, Prefix, Key).

% A variable storage pattern is selected by an existing native identity. This
% also handles owners committed after preparation, without a provider call.
metta_owned_declared_storage(['@owned-record', _, _, Pattern, _], Storage, Views) :-
    ( ground(Pattern) -> true
    ; metta_owned_key_view(Storage, Views, View), View \== absent -> true
    ; throw(error(domain_error(native_owned_record_storage, Storage),
                  context(metta_validate_owned_records/1,
                          'an owned prototype needs an allocated native storage identity'))) ).

metta_owned_pair(view(Module, Functor), Row, Ref) :-
    metta_storage_term(Functor, Row, _, Head),
    compound_name_arity(Head, Functor, Arity),
    current_predicate(Module:Functor/Arity),
    clause(Module:Head, true, Ref).

% Retrieve the unbound occurrence again after indexed matching. Unification
% with a ground query must not conceal a variable in the stored key itself.
metta_owned_original(view(Module, Functor), Ref, Row) :-
    metta_owned_clause(Ref, Module:Head),
    metta_storage_term(Functor, Atom, _, Head), copy_term_nat(Atom, Row).

metta_owned_owner(View, Owner, Ref) :-
    metta_owned_pair(View, ['owned-by', Owner], Ref),
    metta_owned_original(View, Ref, Stored),
    metta_owned_ground(Stored).

metta_owned_value(View, Prefix, Ref) :-
    append(Prefix, [_], Pattern), metta_owned_pair(View, Pattern, Ref),
    metta_owned_original(View, Ref, Row), append(Stored, [_], Row),
    metta_owned_ground(Stored).

% The public reader holds one database snapshot across validation and row
% extraction. A concurrently erased clause cannot disappear between them.
'owned-record-read'(Declaration, Rows) :-
    metta_check_owned_record(Declaration),
    Declaration = ['@owned-record', Home, Owner, Storage, Prefix],
    metta_owned_key(Home, Owner, Storage, Prefix, Key),
    snapshot(metta_owned_read_rows(Key, Rows)).

metta_owned_read_rows(Key, Rows) :-
    metta_owned_read_references(Key, Owners, Values, RecordView, Problem),
    (   Problem \== none
    ->  metta_owned_read_refusal('owned-record-read'/2, Key, Problem)
    ;   Owners == []
    ->  metta_owned_read_refusal('owned-record-read'/2, Key, retired_owner)
    ;   maplist(metta_owned_original(RecordView), Values, Rows)
    ).

% Host lifetimes retain the original occurrences, not a reconstructed key.
% Empty owner/value lists expose absence for an explicit allocation producer;
% a value without its owner is still the shared check's retired-owner problem.
metta_owned_record_occurrences(Declaration, Owners, Rows) :-
    metta_check_owned_record(Declaration),
    Declaration = ['@owned-record', Home, Owner, Storage, Prefix],
    metta_owned_key(Home, Owner, Storage, Prefix, Key),
    snapshot(metta_owned_occurrence_rows(Key, Owners, Rows)).

metta_owned_occurrence_rows(Key, Owners, Rows) :-
    metta_owned_read_references(Key, Owners, Values, RecordView, Problem),
    (   Problem \== none
    ->  metta_owned_read_refusal(metta_owned_record_occurrences/3, Key, Problem)
    ;   maplist(metta_owned_occurrence(RecordView), Values, Rows)
    ).

metta_owned_occurrence(View, Ref, Ref-Row) :- metta_owned_original(View, Ref, Row).

metta_owned_read_references(Key, Owners, Values, RecordView, Problem) :-
    Key = key(Home, _, Storage, _),
    metta_owned_reader_view(Home, OwnerView),
    metta_owned_reader_view(Storage, RecordView),
    metta_owned_key_problem([Home-OwnerView, Storage-RecordView], Key, Owners, Values, Problem).

% A read meets the store as it is. Nothing is retried; a surplus occurrence is
% removed by the caller, so the remedy is the reading door's, not the validator's.
metta_owned_read_refusal(Door, key(Home, Owner, Storage, Prefix), Problem) :-
    metta_owned_read_remedy(Problem, Remedy),
    throw(error(metta_owned_record_conflict(record(Home, Owner, Storage, Prefix), Problem),
                context(Door, Remedy))).

metta_owned_read_remedy(retired_owner, 'the native owner has retired').
metta_owned_read_remedy(multiple_values, 'remove the surplus value rows').
metta_owned_read_remedy(multiple_owners, 'remove the surplus owner rows').

metta_owned_reader_view(Space, View) :-
    metta_owned_view(Space, [], View),
    (   View == absent
    ->  throw(error(domain_error(native_owned_record_storage, Space),
                    context('owned-record-read'/2, 'owned records require an allocated native storage identity')))
    ;   true
    ).

metta_owned_validate_key(Views, Key) :-
    metta_owned_key_problem(Views, Key, _, _, Problem),
    (   Problem == none
    ->  true
    ;   Key = key(Home, Owner, Storage, Prefix),
        throw(error(metta_owned_record_conflict(record(Home, Owner, Storage, Prefix), Problem),
                    context(metta_validate_owned_records/1, 'retry the outer transaction')))
    ).

% Commit checks and explicit reads share the same original-occurrence checks;
% each names its own remedy.
metta_owned_key_problem(Views, Key, Owners, Values, Problem) :-
    Key = key(Home, Owner, Storage, Prefix),
    metta_owned_key_view(Home, Views, OwnerView),
    metta_owned_key_view(Storage, Views, RecordView),
    findall(Ref, limit(2, metta_owned_value(RecordView, Prefix, Ref)), Values),
    findall(Ref, limit(2, metta_owned_owner(OwnerView, Owner, Ref)), Owners),
    (   Values = [_,_]
    ->  Problem = multiple_values
    ;   Owners = [_,_]
    ->  Problem = multiple_owners
    ;   Values = [_], Owners == []
    ->  Problem = retired_owner
    ;   Problem = none
    ).

:- multifile prolog:error_message//1.
prolog:error_message(metta_owned_record_conflict(Key, Problem)) -->
    ['native owned-record conflict ~q for ~q'-[Problem, Key]].
