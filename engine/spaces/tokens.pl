% Purpose: compose occurrence reads and ordering with the native storage shape.
% Guarantees: raw occurrence storage returns its identity; reference scopes
%   remove selected occurrences through the ordinary semantic write doors
%   [tested: reference_providers; commit=90ba93eb8f6e98ebfefc55416859bf13de6a8427].
% Assumes: spaces.pl consults this unit before catalog initialization.
% Guarantees: received generations advance the same flag used by fresh writes;
%   rollback may leave gaps but cannot reuse an allocated generation
%   [tested: spaces_tokens; commit=7f00ac7932fefa6f380fc8d14ec583ea0c58eff4].
%   A forced source reload preserves the native constructor registration
%   [tested: test_reloading_storage_preserves_occurrences; commit=7f00ac7932fefa6f380fc8d14ec583ea0c58eff4].
% Assumes: metta_identity owns the actor and generation flags for the runtime.
% Owns resources: the native constructor registration lasts until SWI cleanup;
%   exact foreign removal restores its thread-local selector at call exit.
% Guarded by: flag/3 atomically reads and replaces the generation counter
%   [tested: spaces_tokens:concurrent_minting_is_unique; commit=7f00ac7932fefa6f380fc8d14ec583ea0c58eff4].
% Decides: actor defaults to a UUID; generation defaults to zero. SWI's flag/3
%   representation limit raises before an exhausted counter can publish a write.

:- use_module('../identity').
:- if(current_predicate(open_shared_object/3)).
:- use_module(library(shlib), [load_foreign_library/1]).
:- use_module(library(pairs), [pairs_values/2]).
:- endif.

% Enumerate each stored occurrence once while retaining its identity. A fixed
% expression uses clause indexing; open arity enumerates only held predicates.
metta_native_pair(Space, Pattern, Token, Ref) :-
    must_be(nonvar, Space),
    native_storage_module_ready(Space, Storage),
    native_storage_functor(Space, Functor),
    (   is_list(Pattern), Pattern = [_|_]
    ->  metta_storage_term(Functor, Pattern, Token, Head),
        clause(Storage:Head, true, Ref)
    ;   (   \+ atomic(Pattern),
            current_predicate(Storage:Functor/Arity), Arity >= 2,
            functor(Head, Functor, Arity),
            metta_storage_term(Functor, Pattern, Token, Head),
            clause(Storage:Head, true, Ref)
        ;   clause(Storage:'$metta_native_scalar'(Pattern, Token), true, Ref)
        )
    ).

metta_require_token_read(Space, Operation) :-
    must_be(nonvar, Space),
    (   seam:foreign_space(Space), \+ foreign_provides(Space, tokens)
    ->  throw(error(metta_foreign_tokens_required(Space, Operation), none))
    ;   true
    ),
    metta_source_guard(Space).

metta_space_pair(Space, Pattern, Token, Ref) :-
    (   seam:foreign_space(Space)
    ->  seam:foreign_token(Space, Pattern, Provided),
        metta_token_receive(Provided, Token), Ref = none
    ;   metta_native_pair(Space, Pattern, Token, Ref)
    ).

% Read identities and mutate identities are separate provider promises. The
% native store implements both; a foreign owner must declare each operation.
metta_require_token_mutation(Space, Operation) :-
    metta_require_token_read(Space, Operation),
    ( seam:foreign_space(Space)
    -> forall(member(Capability, ['add-token', 'remove-token']),
              ( foreign_provides(Space, Capability) -> true
              ; throw(error(metta_foreign_token_mutation_required(
                                Space, Operation, Capability), none)) ))
    ; true ).

metta_store_occurrence(Space, Atom, Token, Ref) :-
    ( seam:foreign_space(Space)
    -> foreign_write(Space, 'add-token',
                     seam:foreign_add_token(Space, Atom, Provided)),
       metta_token_receive(Provided, Token), Ref = none
    ; add_sexp(Space, Atom, Token, Ref), record_source_atom_assertion(Ref) ).

metta_remove_occurrence(Space, Token, Removed) :-
    ( once(metta_space_pair(Space, Atom, Token, Ref))
    -> ( Ref == none
       -> ( nb_current('$metta_foreign_removal_token', Previous)
          -> Prior = some(Previous) ; Prior = none ),
          setup_call_cleanup(
              nb_setval('$metta_foreign_removal_token', Space-Token),
              metta_remove_atom(Space, Atom, Removed),
              metta_restore_removal_token(Prior))
       ; metta_remove_atom_reference(Ref), Removed = true )
    ; Removed = false ).

metta_restore_removal_token(some(Previous)) :-
    nb_setval('$metta_foreign_removal_token', Previous).
metta_restore_removal_token(none) :- nb_delete('$metta_foreign_removal_token').

% Consume the selector before calling the provider, so a callback's removal
% cannot inherit the selected identity. The exact door also implements value
% removal for receivers that do not register the older remove capability.
metta_remove_provider_occurrence(Space, Atom, Removed) :-
    ( nb_current('$metta_foreign_removal_token', Space-Token)
    -> nb_delete('$metta_foreign_removal_token'),
       metta_token_portable(Token, Portable),
       foreign_write(Space, 'remove-token',
                     seam:foreign_remove_token(Space, Portable, Removed))
    ; foreign_provides(Space, remove)
    -> foreign_write(Space, remove, seam:foreign_remove(Space, Atom, Removed))
    ; once(metta_space_pair(Space, Atom, Token, _))
    -> metta_token_portable(Token, Portable),
       foreign_write(Space, 'remove-token',
                     seam:foreign_remove_token(Space, Portable, Removed))
    ; Removed = false ).

metta_host_blame(Space, Pattern, Tokens) :-
    metta_require_token_read(Space, blame),
    findall((Generation-Actor)-[t, Actor, Generation],
            ( metta_space_pair(Space, Pattern, Token, _),
              metta_token_parts(Token, Actor, Generation) ), Pairs),
    keysort(Pairs, Ordered),
    metta_distinct_token_rows(Ordered, Space),
    pairs_values(Ordered, Tokens).

metta_distinct_token_rows([], _).
metta_distinct_token_rows([_], _).
metta_distinct_token_rows([Key-Token, Next-Value|Rest], Space) :-
    (   Key == Next
    ->  throw(error(domain_error(distinct_occurrence_tokens, Space-Token), none))
    ;   metta_distinct_token_rows([Next-Value|Rest], Space)
    ).

:- multifile prolog:error_message//1.
prolog:error_message(metta_foreign_tokens_required(Space, Operation)) -->
    [ '~w cannot run ~w because its provider has no tokens capability; copy its \c
       atoms into a native overlay, or implement stable provider identities'-
      [Space, Operation] ].
prolog:error_message(metta_foreign_token_mutation_required(Space, Operation, Capability)) -->
    [ '~w cannot run ~w because its provider has no ~w capability; copy its \c
       atoms into a native overlay, or register exact-token mutation'-
      [Space, Operation, Capability] ].

% The native constructor implements this specification in one foreign call.
% This path also runs in WASM, whose bundle has no native shared object.
metta_storage_term_prolog(Name, Fields, Token, Head) :-
    (   var(Head)
    ->  must_be(atom, Name), must_be(list, Fields),
        append(Fields, [Token], Arguments),
        compound_name_arguments(Head, Name, Arguments)
    ;   must_be(compound, Head),
        compound_name_arguments(Head, Found, Arguments),
        ( Arguments == [] -> type_error(compound, Head) ; true ),
        append(Decoded, [Last], Arguments),
        Name = Found, Fields = Decoded, Token = Last
    ).

% Do not declare the foreign predicate dynamic: repeating that directive on
% reload disables its C implementation, while load_foreign_library/1 retains
% the existing library registration. The fallback assertz/1 creates its own
% dynamic predicate when no native library is present.
metta_load_storage_constructor :-
    (   predicate_property(metta_storage_term(_, _, _, _), foreign)
    ->  true
    ;   current_predicate(open_shared_object/3),
        metta_engine:metta_engine_src_dir(Directory),
        current_prolog_flag(shared_object_extension, Extension),
        file_name_extension(storage, Extension, Filename),
        directory_file_path(Directory, Filename, Library),
        exists_file(Library)
    ->  load_foreign_library(Library)
    ;   retractall(metta_storage_term(_, _, _, _)),
        assertz((metta_storage_term(Name, Fields, Token, Head) :-
                    metta_storage_term_prolog(Name, Fields, Token, Head)))
    ).

:- metta_boot_identity.
:- metta_load_storage_constructor.
