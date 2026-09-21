% Purpose: own the catalog effects and runtime cardinality checks of annotated arrows.
% Assumes: spaces.pl consults this file; metta_arrow_type_shape/5 owns syntax,
%   canonical classes and the nondet effect floor.
% Guarantees: an accepted annotation publishes its effect; removing its last
%   stored declaration withdraws only its owned catalog row. Unsupported
%   products raise before storage [tested: run_tests(metta_arrow_products);
%   commit=bbb512316280110a747e31c26adfc31e8c5104be].
% Owns resources: metta_arrow_product/5 and metta_arrow_dispatch/2 retain exact
%   catalog and compiler clause references; declaration removal, space clear
%   and source rollback release them.
% Guarded by: '$metta_arrow_products' serializes annotated declaration mutation;
%   SWI transactions own rollback of the metadata and catalog clauses.
% Decides: cardinality assertions are trusted unless verify-cardinality is on;
%   enabled det and semidet checks reject a surviving choicepoint and never
%   replay the body [tested: run_tests(metta_arrow_products); commit=bbb512316280110a747e31c26adfc31e8c5104be].

%Each declaration owns both references; equal declarations in other spaces
%remain independent when one source is withdrawn.
:- dynamic metta_arrow_product/5.
:- dynamic metta_arrow_dispatch/2.
:- dynamic metta_cardinality_verified/0.
:- meta_predicate metta_with_arrow_product_update(0).
:- meta_predicate metta_verify_annotated_call(+, +, +, ?, 0).
%control_exception/1 is the ONE seam whose home is the engine core rather than
%`seam`, because the translator emits it into compiled bodies and
%protect_engine_emitted/1 imports it into every space's module FROM the engine
%module [source: engine/ext_points.pl:kind/2; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720].
%A clause of it is therefore written metta_engine: wherever it is added, and
%this file is one of the four places that add one. Left unqualified it would
%have created spaces:control_exception/1, a second predicate the engine's
%recovery sites never read; written user: -- which is what it said while the
%engine core WAS `user` -- it creates user:control_exception/1 and SWI reports
%`Local definition of user:control_exception/1 overrides weak import from
%metta_engine`, after which the host tier's own clauses shadow the engine's
%whole list [tested: extensions/python/tests/ch07_control_flow/test_control_signals.py; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720].
:- multifile metta_engine:control_exception/1.
metta_engine:control_exception(error(metta_cardinality_violation(_, _, _, _), _)).
:- multifile seam:engine_emitted/1.
seam:engine_emitted(metta_verify_annotated_call/5).

%Only type expressions containing an annotation enter the product write path.
metta_annotated_type(Type) :-
    nonvar(Type), Type = [Head|Types],
    (   atom(Head), sub_atom(Head, 0, 2, _, '-[')
    ->  true
    ;   member(Nested, Types), compound(Nested), metta_annotated_type(Nested)
    ),
    !.

metta_require_arrow_product(Name, Type, Product) :-
    (   atom(Name),
        metta_arrow_type_shape(Type, Inputs, Output, Product0, explicit),
        Product0 = effect(Cardinality, Class),
        atom(Cardinality), atom(Class),
        \+ ( member(Nested, [Output|Inputs]), nonvar(Nested),
             metta_annotated_type(Nested) )
    ->  Product = Product0
    ;   throw(error(metta_unhonoured_arrow_product(Name, Type),
                    context(metta_add_atom/3,
                            'annotated arrows require a named function and a \c
                             concrete top-level cardinality and effect; product \c
                             variables and nested products are not enforced')))
    ).

metta_with_arrow_product_update(Goal) :-
    with_typing_policy_stable(with_mutex('$metta_arrow_products', Goal)).

metta_add_annotated_declaration(Space, Name, Type, Product, Token) :-
    metta_with_arrow_product_update(
        once(metta_transaction(
            store_annotated_declaration(Space, Name, Type, Product, Token)))).

store_annotated_declaration(_, Name, Type, _, _) :-
    (   metta_translated_head(Name)
    ;   translator:prolog_function_importer(Name)
    ),
    !,
    throw(error(metta_unhonoured_arrow_product(Name, Type),
                context(metta_add_atom/3,
                        'translated forms have no ordinary cardinality checkpoint; \c
                         annotate an ordinary wrapper function instead'))).
store_annotated_declaration(Space, Name, Type, _, _) :-
    seam:foreign_space(Space),
    \+ metta_writes(Space, transactional),
    !,
    throw(error(metta_unhonoured_arrow_product(Name, Type),
                context(metta_add_atom/3,
                        'annotated arrows require transactional storage to keep \c
                         the written type and its catalog effect together'))).
store_annotated_declaration(Space, Name, Type, Product, Token) :-
    result_finality(Name, Before),
    ( Space == '&self', fun(Name) -> retract_prelude_declarations(Name) ; true ),
    Product = effect(_, Class),
    add_sexp('&metta', [effect, Name, Class], EffectRef),
    record_source_assertion(EffectRef),
    assertz(metta_arrow_product(Name, Space, Type, Product, EffectRef), OwnerRef),
    record_source_assertion(OwnerRef),
    translator:install_annotated_dispatch(Name, DispatchRef),
    record_source_assertion(DispatchRef),
    assertz(metta_arrow_dispatch(EffectRef, DispatchRef), DispatchOwnerRef),
    record_source_assertion(DispatchOwnerRef),
    forall(seam:cache_policy_changed(Name), true),
    store_atom(Space, [':', Name, Type], Token),
    (   fun(Name)
    ->  space_module(Space, Module),
        announce_declaration_changed(Module, Name, Before)
    ;   true
    ).

metta_refuse_annotated_translator_rule(Name) :-
    (   metta_arrow_product(Name, _, Type, _, _)
    ->  throw(error(metta_unhonoured_arrow_product(Name, Type),
                    context('add-translator-rule!',
                            'a translator rule would bypass annotated cardinality; \c
                             keep the annotation on an ordinary wrapper function')))
    ;   true
    ).

%Read the written tier selected by governing_type_declaration_in/3, before
%that reader projects the arrow. A local definition also hides &self's rows.
metta_arrow_product_in(Module, Name, Type, Product) :-
    once(metta_arrow_product(Name, _, _, _, _)),
    metta_module_space(Module, Space),
    (   ( Space == '&self' ; once(match_stored(Space, [':', Name, _], _, _)) )
    ->  metta_arrow_product(Name, Space, Type, Product, _)
    ;   \+ fun_in(Module, Name),
        metta_arrow_product(Name, '&self', Type, Product, _)
    ).

%The retained reference distinguishes this derived row from an equal row
%written by another source. Source withdrawal visits the owning type first.
metta_refuse_owned_effect_removal(Module, Term) :-
    copy_term(Term, Probe),
    (   once(clause(Module:Probe, true, Ref)),
        metta_arrow_product(Name, Space, Type, _, Ref)
    ->  throw(error(permission_error(remove, annotated_arrow_effect, Probe),
                    context(metta_remove_atom/3,
                            remove_declaration(Space, [':', Name, Type]))))
    ;   true
    ).

metta_prune_arrow_products(Space) :-
    with_mutex('$metta_arrow_products',
        transaction(
            forall(( metta_arrow_product(Name, Space, Type, _, Ref),
                     \+ ( metta_host_stored(Space, [':', Name, Stored]),
                          Stored =@= Type ) ),
                   metta_erase_arrow_product(Ref)))).

%try_erase/1 rather than a clause_property(_, erased) test first: that is
%check-then-act over the shared clause store, and the mutex above does not
%close the window because the other eraser is source withdrawal, which does
%not take it. The named operation tolerates the lost race and still lets a
%non-clause blob's type_error through, so nothing the test bought is lost.
metta_erase_arrow_product(Ref) :-
    retractall(metta_arrow_product(_, _, _, _, Ref)),
    forall(retract(metta_arrow_dispatch(Ref, DispatchRef)),
           host_transactions:try_erase(DispatchRef)),
    host_transactions:try_erase(Ref).

metta_set_cardinality_verification(Value) :-
    retractall(metta_cardinality_verified),
    ( Value == false -> true
    ; Value == none -> true
    ; assertz(metta_cardinality_verified) ).

%The pragma is a materialised marker, as in metta_refresh_discharge_verification/0.
%Only an annotated call emits this goal. Its disabled path reads no types.
metta_verify_annotated_call(Module, Name, Args, Out, Goal) :-
    (   metta_cardinality_verified,
        metta_applicable_cardinality(Module, Name, Args, Cardinality)
    ->  ( Cardinality == det, var(Out) -> Required = det ; Required = semidet ),
        metta_check_cardinality(Module, Name, Required, Out, Goal)
    ;   call(Goal)
    ).

metta_applicable_cardinality(Module, Name, Args, Cardinality) :-
    findall(Card,
            ( metta_arrow_product_in(Module, Name, Raw, effect(Card, _)),
              Card \== nondet,
              \+ \+ ( length(Args, Arity),
                       metta_presented_arrow_chain(Raw, Arity, Types),
                       append(Parameters, [_], Types),
                       metta_argument_type_origins(Parameters, Origins),
                       metta_arguments_match_in(Module, Parameters, Origins, Args) ) ),
            Cards),
    ( memberchk(det, Cards) -> Cardinality = det
    ; memberchk(semidet, Cards) -> Cardinality = semidet ).

%SWI det/1 rejects both failure and a surviving choicepoint. call_cleanup/2
%observes that choicepoint without asking for a second answer or replaying an
%effect. Empty is not an observable MeTTa answer. A constrained output checks
%only the upper bound, since unification can legitimately remove its answer.
%[source: https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/man/builtin.plx,
%det/1 and call_cleanup/2; commit=bbb512316280110a747e31c26adfc31e8c5104be].
metta_check_cardinality(Module, Name, Required, Out, Goal) :-
    (   call_cleanup((call(Goal), Out \== 'Empty'), Finished = true)
    *-> (   Finished == true
        ->  true
        ;   throw(error(metta_cardinality_violation(Module, Name, Required, nondet),
                        context(metta_verify_annotated_call/5,
                                'annotated call succeeded with a choicepoint')))
        )
    ;   Required == det
    ->  throw(error(metta_cardinality_violation(Module, Name, det, failure),
                    context(metta_verify_annotated_call/5,
                            'annotated det call produced no answer')))
    ;   fail
    ).

:- multifile prolog:error_message//1.
prolog:error_message(metta_unhonoured_arrow_product(Name, Type)) -->
    [ 'cannot honour the annotated arrow for ~w: ~q'-[Name, Type] ].
prolog:error_message(metta_cardinality_violation(Module, Name, Expected, Found)) -->
    [ '~w in ~w declares ~w cardinality but its call was ~w'-
      [Name, Module, Expected, Found] ].
