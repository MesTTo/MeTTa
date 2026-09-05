% Purpose: exercise annotated effects, cardinality auditing and declaration lifetime.
% Guarantees: tests enter through declaration and evaluation doors, retaining
%   plain-arrow controls and checking rollback as well as successful calls
%   [tested: run_tests(metta_arrow_products); commit=WORKTREE].
% Owns resources: each case releases its named spaces; pragma writes restore
%   the disabled mode before the next case. Observer cases erase their clause
%   references and destroy their message queues even when an assertion fails.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(metta_arrow_products).

product_fixture(Source, Space, Module) :-
    'new-space'(Space),
    space_module(Space, Module),
    process_metta_string(Source, _, Space).

product_cleanup(Space) :-
    set_metta_pragma('verify-cardinality', none),
    metta_release_space(Space).

cardinality_goal_in(Body) :-
    sub_term(Sub, Body),
    nonvar(Sub),
    functor(Sub, metta_verify_annotated_call, 5).

product_answers(Module, Expr, Answers) :-
    findall(Value, eval_metta_in_module(Module, Expr, Value), Answers).

test(explicit_effect_reaches_catalog_and_plan,
     [ setup(product_fixture(
          "(: product-f (-[det,writesState]-> Number Number))
           (= (product-f $x) $x)", Space, Module)),
       cleanup(product_cleanup(Space)) ]) :-
    assertion(metta_catalog_row([effect, 'product-f', writesState])),
    metta_host_source_effect_plan(Module, ['product-f', 1], Ops, Effect),
    assertion(Ops == [['product-f', writesState]]),
    assertion(Effect == writesState),
    assertion(seam:kind(metta_annotated_operation_effect/2, service)),
    product_answers(Module, ['product-f', 1], [1]).

test(nondet_joins_every_concrete_class_with_its_floor,
     [ forall(member(Class-Expected,
                      [pureStructural-nondeterministicReadOnly,
                       readOnlyLookup-nondeterministicReadOnly,
                       nondeterministicReadOnly-nondeterministicReadOnly,
                       writesState-writesState, oracleIO-oracleIO])),
       setup('new-space'(Space)), cleanup(product_cleanup(Space)) ]) :-
    atomic_list_concat(['-[nondet,', Class, ']->'], Head),
    metta_add_atom(Space, [':', 'product-f', [Head, 'Number', 'Number']], true),
    metta_add_atom(Space, [=, ['product-f', X], X], true),
    space_module(Space, Module),
    metta_host_source_effect_plan(Module, ['product-f', 1], _, Effect),
    assertion(Effect == Expected),
    assertion(metta_catalog_row([effect, 'product-f', Expected])).

test(a_declared_pure_body_still_contributes_its_real_effect,
     [ setup(product_fixture(
          "(: product-f (-[det,pureStructural]-> Number Number))
           (= (product-f $x) (random-int 1 20))", Space, Module)),
       cleanup(product_cleanup(Space)) ]) :-
    metta_host_source_effect_plan(Module, ['product-f', 1], Ops, Effect),
    assertion(member(['product-f', pureStructural], Ops)),
    assertion(member(['random-int', oracleIO], Ops)),
    assertion(Effect == oracleIO).

test(an_annotated_callee_is_not_hidden_by_a_plain_caller,
     [ setup(product_fixture(
          "(: product-f (-[det,writesState]-> Number Number))
           (= (product-f $x) $x)
           (: product-caller (-> Number Number))
           (= (product-caller $x) (product-f $x))", Space, Module)),
       cleanup(product_cleanup(Space)) ]) :-
    metta_host_source_effect_plan(Module, ['product-caller', 1], Ops, Effect),
    assertion(member(['product-f', writesState], Ops)),
    assertion(Effect == writesState),
    catch(metta_effect_walk(Module, ['product-caller'/2], _), Error, true),
    assertion(nonvar(Error)),
    assertion(Error = error(metta_impure_goal('product-f'/2), _)).

test(removal_keeps_equal_handwritten_rows_and_other_space_owners,
     [ forall(member(ManualClass, [readOnlyLookup, writesState])),
       setup(('new-space'(Left), 'new-space'(Right),
              add_sexp('&metta', [effect, 'product-f', ManualClass], Manual))),
       cleanup((product_cleanup(Left), product_cleanup(Right), erase(Manual))) ]) :-
    Decl = [':', 'product-f', ['-[det,writesState]->', 'Number', 'Number']],
    metta_add_atom(Left, Decl, true),
    metta_add_atom(Right, Decl, true),
    metta_remove_atom(Left, Decl, true),
    assertion(metta_operation_effect('product-f', writesState)),
    metta_remove_atom(Right, Decl, true),
    assertion(metta_operation_effect('product-f', ManualClass)),
    findall(Class, metta_catalog_row([effect, 'product-f', Class]), Classes),
    assertion(Classes == [ManualClass]),
    assertion(clause_property(Manual, fact)).

test(an_owned_effect_is_removed_through_its_declaration,
     [ setup(product_fixture(
          "(: product-f (-[det,writesState]-> Number Number))", Space, _)),
       cleanup(product_cleanup(Space)),
       throws(error(permission_error(remove, annotated_arrow_effect, _), _)) ]) :-
    metta_remove_atom('&metta', [effect, 'product-f', writesState], _).

test(a_counted_catalog_keeps_the_owned_effect_removal_guard,
     [ setup(product_fixture(
          "(: product-f (-[det,writesState]-> Number Number))", Space, _)),
       cleanup((metta_undeclare_hook(pre_add, '&metta'),
                metta_remove_atom('&metta', [capacity, '&metta', 100000], _),
                metta_remove_atom('&self',
                    [=, ['space-admission-guard-&metta', _], _], _),
                product_cleanup(Space))) ]) :-
    metta_add_atom('&metta', [capacity, '&metta', 100000], true),
    metta_admission_claim('&metta', '&self'),
    metta_capacity_count('&metta', Before),
    catch(metta_remove_atom('&metta', [effect, 'product-f', writesState], _),
          Error, true),
    assertion(nonvar(Error)),
    assertion(Error = error(permission_error(remove, annotated_arrow_effect, _), _)),
    assertion(metta_catalog_row([effect, 'product-f', writesState])),
    metta_capacity_count('&metta', After),
    assertion(After == Before).

test(clearing_the_catalog_cannot_orphan_another_spaces_product,
     [ setup(product_fixture(
          "(: product-f (-[det,writesState]-> Number Number))
           (= (product-f $x) $x)", Space, Module)),
       cleanup(product_cleanup(Space)) ]) :-
    catch(clear_native_atoms('&metta'), Error, true),
    assertion(nonvar(Error)),
    assertion(Error = error(permission_error(clear, annotated_arrow_catalog,
                                             '&metta'), _)),
    assertion(metta_host_stored(Space,
        [':', 'product-f', ['-[det,writesState]->', 'Number', 'Number']])),
    assertion(metta_catalog_row([effect, 'product-f', writesState])),
    metta_host_source_effect_plan(Module, ['product-f', 1], _, Effect),
    assertion(Effect == writesState).

test(clearing_an_undefined_declaration_withdraws_its_effect,
     [ setup(product_fixture(
          "(: product-f (-[det,writesState]-> Number Number))", Space, _)),
       cleanup(product_cleanup(Space)) ]) :-
    clear_native_atoms(Space),
    assertion(\+ metta_operation_effect('product-f', _)).

test(a_clear_observer_still_sees_atoms_outside_the_compiled_half,
     [ forall(member(Pattern-Term,
          [[=, ['product-f'|_]|_]-[=, ['product-f', 1]],
           [_, ['product-f'|_], _]-[data, ['product-f', 1], kept]])),
       setup(('new-space'(Space), message_queue_create(Queue))),
       cleanup(((nonvar(Ref) -> erase(Ref) ; true),
                product_cleanup(Space), message_queue_destroy(Queue))) ]) :-
    metta_add_atom(Space, Term, true),
    assertz(seam:(atom_removed(Space, Pattern) :-
                     thread_send_message(Queue, observed)), Ref),
    metta_host_clear_space(Space),
    assertion(thread_get_message(Queue, observed, [timeout(0)])).

test(a_batch_cannot_store_an_annotation_as_inert_data,
     [ setup('new-space'(Space)), cleanup(product_cleanup(Space)) ]) :-
    metta_add_atoms(Space,
        [[data, 1], [':', 'product-f', ['-[det,writesState]->', 'Number', 'Number']]]),
    assertion(metta_operation_effect('product-f', writesState)).

test(unsupported_products_are_refused_before_storage,
     [ forall(member(Type,
          [['-[$e]->', 'Number', 'Number'],
           ['-[$d,pureStructural]->', 'Number', 'Number'],
           ['-[det,$e]->', 'Number', 'Number'],
           ['-[det,bogus]->', 'Number', 'Number'],
           ['-[det,pureStructural]->', ['-[det]->', 'Number', 'Number'], 'Number'],
           ['->', ['-[det,pureStructural]->', 'Number', 'Number'], 'Number']])),
       setup('new-space'(Space)), cleanup(product_cleanup(Space)) ]) :-
    catch(metta_add_atom(Space, [':', 'product-f', Type], _), Error, true),
    assertion(nonvar(Error)),
    assertion(Error = error(metta_unhonoured_arrow_product('product-f', Type), _)),
    assertion(\+ metta_host_stored(Space, [':', 'product-f', _])),
    assertion(\+ metta_operation_effect('product-f', _)).

test(transaction_rollback_restores_the_declaration_and_its_effect,
     [ setup(product_fixture(
          "(: product-f (-[det,writesState]-> Number Number))", Space, _)),
       cleanup(product_cleanup(Space)) ]) :-
    Decl = [':', 'product-f', ['-[det,writesState]->', 'Number', 'Number']],
    assertion(\+ transaction((metta_remove_atom(Space, Decl, true), fail))),
    assertion(metta_host_stored(Space, Decl)),
    assertion(metta_operation_effect('product-f', writesState)),
    metta_remove_atom(Space, Decl, true),
    assertion(\+ transaction((metta_add_atom(Space, Decl, true), fail))),
    assertion(\+ metta_operation_effect('product-f', _)).

test(cardinality_is_trusted_when_verification_is_disabled,
     [ setup(product_fixture(
          "(: product-f (-[det]-> Number Number))
           (= (product-f $x) $x) (= (product-f $x) (+ $x 1))", Space, Module)),
       cleanup(product_cleanup(Space)) ]) :-
    product_answers(Module, ['product-f', 1], Answers),
    assertion(Answers == [1, 2]).

test(verification_rejects_a_second_equation_before_returning_its_first_answer,
     [ setup(product_fixture(
          "(: product-f (-[det]-> Number Number))
           (= (product-f $x) $x) (= (product-f $x) (+ $x 1))", Space, Module)),
       cleanup(product_cleanup(Space)),
       throws(error(metta_cardinality_violation(_, 'product-f', det, nondet), _)) ]) :-
    set_metta_pragma('verify-cardinality', true),
    eval_metta_in_module(Module, ['product-f', 1], _).

test(verification_preserves_the_selected_dispatch_result,
     [ setup(product_fixture(
          "(: product-f (-[det,pureStructural]-> Number Number))
           (= (product-f $x) $x) (= (product-f $x) (+ $x 1))", Space, Module)),
       cleanup((metta_remove_atom('&metta',
                    ['dispatch-policy', 'product-f', 'FunctionResultEnum',
                     'Deterministic'], _), product_cleanup(Space))) ]) :-
    metta_add_atom('&metta',
        ['dispatch-policy', 'product-f', 'FunctionResultEnum', 'Deterministic'], true),
    set_metta_pragma('verify-cardinality', true),
    product_answers(Module, ['product-f', 1], [1]).

test(verification_rejects_duplicate_answers_too,
     [ setup(product_fixture(
          "(: product-f (-[semidet,pureStructural]-> Number Number))
           (= (product-f $x) $x) (= (product-f $x) $x)", Space, Module)),
       cleanup(product_cleanup(Space)),
       throws(error(metta_cardinality_violation(_, 'product-f', semidet, nondet), _)) ]) :-
    set_metta_pragma('verify-cardinality', true),
    eval_metta_in_module(Module, ['product-f', 1], _).

test(det_requires_an_answer_for_applicable_input,
     [ setup(product_fixture(
          "(: product-f (-[det,pureStructural]-> Number Number))
           (= (product-f 0) 0)", Space, Module)),
       cleanup(product_cleanup(Space)),
       throws(error(metta_cardinality_violation(_, 'product-f', det, failure), _)) ]) :-
    set_metta_pragma('verify-cardinality', true),
    eval_metta_in_module(Module, ['product-f', 1], _).

test(empty_does_not_discharge_det,
     [ setup(product_fixture(
          "(: product-f (-[det,pureStructural]-> Number Atom))
           (= (product-f $x) Empty)", Space, Module)),
       cleanup(product_cleanup(Space)),
       throws(error(metta_cardinality_violation(_, 'product-f', det, failure), _)) ]) :-
    set_metta_pragma('verify-cardinality', true),
    eval_metta_in_module(Module, ['product-f', 1], _).

test(semidet_permits_failure_and_nondet_permits_multiple_answers,
     [ setup(product_fixture(
          "(: product-f (-[semidet,pureStructural]-> Number Number))
           (= (product-f 0) 0)
           (: product-many (-[nondet,pureStructural]-> Number Number))
           (= (product-many $x) $x) (= (product-many $x) $x)", Space, Module)),
       cleanup(product_cleanup(Space)) ]) :-
    set_metta_pragma('verify-cardinality', true),
    product_answers(Module, ['product-f', 1], []),
    product_answers(Module, ['product-f', 0], [0]),
    product_answers(Module, ['product-many', 1], [1, 1]).

test(the_mode_can_change_after_a_caller_has_compiled,
     [ setup(product_fixture(
          "(: product-f (-[det]-> Number Number))
           (= (product-f $x) $x) (= (product-f $x) $x)
           (= (product-caller $x) (product-f $x))", Space, Module)),
       cleanup(product_cleanup(Space)) ]) :-
    product_answers(Module, ['product-caller', 1], [1, 1]),
    set_metta_pragma('verify-cardinality', true),
    catch(product_answers(Module, ['product-caller', 1], _), Error, true),
    assertion(nonvar(Error)),
    assertion(Error = error(metta_cardinality_violation(_, 'product-f', det, nondet), _)),
    set_metta_pragma('verify-cardinality', none),
    product_answers(Module, ['product-caller', 1], [1, 1]).

test(a_late_annotation_and_its_removal_recompile_existing_callers,
     [ setup(product_fixture(
          "(: product-f (-> Number Number))
           (= (product-f $x) $x) (= (product-f $x) $x)
           (= (product-caller $x) (product-f $x))", Space, Module)),
       cleanup(product_cleanup(Space)) ]) :-
    product_answers(Module, ['product-caller', 1], [1, 1]),
    Decl = [':', 'product-f', ['-[det]->', 'Number', 'Number']],
    metta_add_atom(Space, Decl, true),
    set_metta_pragma('verify-cardinality', true),
    catch(product_answers(Module, ['product-caller', 1], _), Error, true),
    assertion(nonvar(Error)),
    assertion(Error = error(metta_cardinality_violation(_, 'product-f', det, nondet), _)),
    metta_remove_atom(Space, Decl, true),
    product_answers(Module, ['product-caller', 1], [1, 1]),
    clause(Module:'product-caller'(_, _), Body),
    assertion(\+ cardinality_goal_in(Body)).

test(plain_arrows_emit_no_cardinality_work_even_with_the_mode_on,
     [ setup(product_fixture(
          "(: product-f (-> Number Number))
           (= (product-f $x) $x) (= (product-f $x) $x)
           (= (product-caller $x) (product-f $x))", Space, Module)),
       cleanup(product_cleanup(Space)) ]) :-
    set_metta_pragma('verify-cardinality', true),
    product_answers(Module, ['product-caller', 1], [1, 1]),
    clause(Module:'product-caller'(_, _), Body),
    assertion(\+ cardinality_goal_in(Body)),
    product_answers(Module, ['product-f', "s"],
                    [['Error', ['product-f', "s"],
                      ['BadArgType', 1, 'Number', 'String']]]),
    assertion(\+ metta_catalog_row([effect, 'product-f', _])).

test(a_bound_output_may_filter_a_det_answer,
     [ setup(product_fixture(
          "(: product-f (-[det,pureStructural]-> Number Number))
           (= (product-f $x) $x)", Space, Module)),
       cleanup(product_cleanup(Space)) ]) :-
    set_metta_pragma('verify-cardinality', true),
    assertion(\+ eval_metta_in_module(Module, ['product-f', 1], 2)),
    product_answers(Module, ['product-f', 1], [1]).

test(a_shadowing_plain_function_keeps_its_own_cardinality,
     [ setup(('new-space'(Space), space_module(Space, Module))),
       cleanup((product_cleanup(Space),
                metta_remove_atom('&self', [':', 'product-shared', _], _))) ]) :-
    metta_add_atom('&self',
        [':', 'product-shared', ['-[det]->', 'Number', 'Number']], true),
    process_metta_string(
        "(: product-shared (-> Number Number))
         (= (product-shared $x) $x) (= (product-shared $x) $x)", _, Space),
    set_metta_pragma('verify-cardinality', true),
    product_answers(Module, ['product-shared', 1], [1, 1]).

test(a_special_form_annotation_is_refused_at_load,
     [ setup('new-space'(Space)), cleanup(product_cleanup(Space)),
       throws(error(metta_unhonoured_arrow_product(superpose, _), _)) ]) :-
    process_metta_string(
        "(: superpose (-[det,pureStructural]-> Atom %Undefined%))", _, Space).

test(a_translator_rule_cannot_discard_an_existing_product,
     [ setup(product_fixture(
          "(: product-f (-[det]-> Number Number)) (= (product-f $x) $x)",
          Space, Module)), cleanup(product_cleanup(Space)) ]) :-
    catch(eval_metta_in_module(Module, ['add-translator-rule!', 'product-f'], _),
          Error, true),
    assertion(nonvar(Error)),
    assertion(Error = error(metta_unhonoured_arrow_product('product-f', _), _)),
    assertion(\+ translator_rule('product-f', _, _)).

test(a_translator_rule_annotation_is_refused_at_load,
     [ setup(product_fixture(
          "(= (product-f $x) (noeval $x)) !(add-translator-rule! product-f)",
          Space, _)), cleanup(product_cleanup(Space)),
       throws(error(metta_unhonoured_arrow_product('product-f', _), _)) ]) :-
    metta_add_atom(Space,
        [':', 'product-f', ['-[det]->', 'Number', 'Number']], _).

test(a_concrete_product_accepts_polymorphic_parameter_types,
     [ setup(product_fixture(
          "(: product-f (-[det,pureStructural]-> $a $a))
           (= (product-f $x) $x)", Space, Module)),
       cleanup(product_cleanup(Space)) ]) :-
    set_metta_pragma('verify-cardinality', true),
    product_answers(Module, ['product-f', 1], [1]),
    product_answers(Module, ['product-f', "text"], ["text"]).

:- end_tests(metta_arrow_products).

:- begin_tests(metta_arrow_control).

test(cardinality_disagreements_survive_recovery_catches,
     [throws(error(metta_cardinality_violation(module, function, det, nondet), c))]) :-
    catch_recover(
        throw(error(metta_cardinality_violation(module, function, det, nondet), c)),
        true).

:- end_tests(metta_arrow_control).
