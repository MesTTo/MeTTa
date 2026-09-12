% Purpose: verify constructor checking, sorted projections and their invalidation.
% Guarantees: public evaluation preserves complete answer bags while a warm
%   sorted accessor costs less than the same untyped accessor
%   [tested: run_tests(translator_constructors); commit=2398951d3272ad02b2c2d7b1e2b610c8e332c1f5].
% Guarantees: a typed callee reuses a ground argument's construction proof
%   while retaining changes to its own argument contract and live refinements
%   [tested: translator_constructors:a_typed_callee_reuses_the_constructed_argument_sort,
%   translator_constructors:a_callee_arrow_change_retires_its_argument_proof,
%   translator_constructors:a_constructed_argument_keeps_a_live_callee_refinement;
%   commit=WORKTREE].
% Owns resources: each test releases its native space through plunit cleanup.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(translator_constructors).

run_in(Space, Text, Answers) :-
    setup_call_cleanup(asserta(filereader:silent(true), Ref),
                       process_metta_string(Text, Answers, Space), erase(Ref)).

setup_points(Space) :-
    'new-space'(Space),
    run_in(Space, "
        (: Point (-> Number Number Point))
        (= (point-x (Point $x $y)) $x)
        (= (plain-x (Plain $x $y)) $x)
        (= (build-point $x $y) (Point $x $y))
        (= (read-point) (point-x (Point 3 4)))", []).

evaluate_in(Space, Term, Answers) :-
    space_module(Space, Module),
    with_metta_module(Module, findall(Value, eval(Term, Value), Answers)).

% The reference is the runtime checking route, retained beside the optimized
% translator. Explicit goldens below also pin values and error payloads.
differential(Space, Term) :-
    space_module(Space, Module),
    with_metta_module(Module,
        ( translator:with_static_contract_shortcuts(disabled,
              translator:translate_expr(Term, SlowGoals, SlowValue)),
          findall(SlowValue, call_goals_in(Module, SlowGoals), Expected),
          type_rules:with_typing_policy_stable(
              translator:with_static_contract_shortcuts(enabled,
                  translator:translate_expr(Term, FastGoals, FastValue))),
          findall(FastValue, call_goals_in(Module, FastGoals), Actual),
          assertion(Actual =@= Expected) )).

test(constructed_values_and_errors_keep_their_written_call,
     [setup(setup_points(S)), cleanup(metta_release_space(S))]) :-
    evaluate_in(S, ['build-point', 3, 4], Good),
    assertion(Good == [['Point', 3, 4]]),
    evaluate_in(S, ['build-point', "bad", 4], Bad),
    assertion(Bad == [['Error', ['Point', "bad", 4],
                      ['BadArgType', 1, 'Number', 'String']]]),
    evaluate_in(S, ['read-point'], Read), assertion(Read == [3]).

test(generated_constructor_arguments_preserve_answer_bags,
     [ setup(setup_points(S)), cleanup(metta_release_space(S)),
       forall((member(X, [0, 1, -1, 1.5, 1208925819614629174706176,
                         "bad", true, unknown]),
               member(Y, [0, 2, "bad", false]))) ]) :-
    differential(S, ['Point', X, Y]),
    differential(S, ['point-x', ['Point', X, Y]]).

test(arity_zero_partial_and_excess_keep_their_existing_meaning,
     [setup(setup_points(S)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: Unit (-> Unit))", []),
    forall(member(Term, [['Unit'], ['Point'], ['Point', 1],
                         ['Point', 1, 2, 3]]), differential(S, Term)).

test(nested_constructors_check_the_inner_boundary,
     [setup(setup_points(S)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: Box (-> Point Box))", []),
    forall(member(Term, [['Box', ['Point', 3, 4]],
                         ['Box', ['Point', "bad", 4]],
                         ['Box', ['Point', 1]],
                         ['Box', ['quote', ['Point', "bad", 4]]]]),
           differential(S, Term)).

test(shared_type_variables_and_overloads_keep_joint_bindings,
     [setup(setup_points(S)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: Pair (-> $t $t (Pair $t)))
               (: Choice (-> Number Number Choice))
               (: Choice (-> String String Choice))", []),
    forall((member(Head, ['Pair', 'Choice']),
            member(X, [1, "one", true]), member(Y, [2, "two", false])),
           differential(S, [Head, X, Y])).

test(variadic_constructor_checks_every_field_and_empty_run,
     [setup(setup_points(S)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: Numbers (-> (:seg Number) Numbers))", []),
    forall((between(0, 8, N), length(Args, N), maplist(=(1), Args)),
           differential(S, ['Numbers'|Args])),
    forall(between(1, 5, Position),
           (length(Args, 5), nth1(Position, Args, "bad", Rest),
            maplist(=(1), Rest), differential(S, ['Numbers'|Args]))).

test(a_variable_call_does_not_bind_the_source_during_compilation,
     [setup(setup_points(S)), cleanup(metta_release_space(S))]) :-
    space_module(S, Module),
    with_metta_module(Module,
        type_rules:with_typing_policy_stable(
            translator:with_static_contract_shortcuts(enabled,
                translator:translate_expr(['Point', X, Y], _, _)))),
    assertion(var(X)), assertion(var(Y)), assertion(X \== Y).

test(a_second_projection_equation_preserves_multiplicity,
     [setup(setup_points(S)), cleanup(metta_release_space(S))]) :-
    evaluate_in(S, ['read-point'], [3]),
    run_in(S, "(= (point-x (Point $x $y)) $x)", []),
    evaluate_in(S, ['read-point'], Answers), assertion(Answers == [3, 3]).

test(another_matching_equation_cannot_be_erased,
     [setup(setup_points(S)), cleanup(metta_release_space(S))]) :-
    evaluate_in(S, ['read-point'], [3]),
    run_in(S, "(= (point-x $anything) 17)", []),
    evaluate_in(S, ['read-point'], Answers), assertion(Answers == [3, 17]).

test(a_sorted_argument_need_not_be_the_first_argument,
     [setup(setup_points(S)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(= (pick $ignored (Point $x $y)) $y)
               (= (read-second) (pick unused (Point 3 4)))", []),
    evaluate_in(S, ['read-second'], Answers), assertion(Answers == [4]).

test(a_projection_cannot_resolve_a_result_that_still_needs_evaluation,
     [setup(setup_points(S)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: Held (-> Atom Held)) (= (unhold (Held $v)) $v)", []),
    differential(S, ['unhold', ['Held', ['quote', ['+', 1, 2]]]]).

test(a_changed_constructor_equation_recompiles_its_consumers,
     [setup(setup_points(S)), cleanup(metta_release_space(S))]) :-
    evaluate_in(S, ['read-point'], [3]),
    run_in(S, "(= (Point $x $y) (Plain $x $y))", []),
    evaluate_in(S, ['read-point'], Changed),
    evaluate_in(S, ['point-x', ['Point', 3, 4]], Direct),
    assertion(Changed == Direct), assertion(Changed == []),
    metta_remove_atom(S, [=, ['Point', X, Y], ['Plain', X, Y]], _),
    evaluate_in(S, ['read-point'], Restored), assertion(Restored == [3]).

test(a_changed_arrow_recompiles_constructor_checks,
     [setup(setup_points(S)), cleanup(metta_release_space(S))]) :-
    evaluate_in(S, ['read-point'], [3]),
    metta_remove_atom(S, [':', 'Point', [->, 'Number', 'Number', 'Point']], _),
    run_in(S, "(: Point (-> String Number Point))", []),
    evaluate_in(S, ['read-point'], Answers),
    assertion(Answers == [['Error', ['Point', 3, 4],
                          ['BadArgType', 1, 'String', 'Number']]]).

test(bulk_declarations_and_removal_patterns_recompile_checked_constructors,
     [ setup(setup_points(S)), cleanup(metta_release_space(S)),
       forall(member(Kind, [named, named_any_type, any_name, any_declaration])) ]) :-
    evaluate_in(S, ['read-point'], [3]),
    ( Kind == named -> Pattern = [':', 'Point', [->, 'Number', 'Number', 'Point']]
    ; Kind == named_any_type -> Pattern = [':', 'Point', _]
    ; Kind == any_name -> Pattern = [':', _, [->, 'Number', 'Number', 'Point']]
    ; Pattern = [':', _, _] ),
    metta_remove_atom(S, Pattern, true),
    metta_add_atoms(S, [[':', 'Point', [->, 'String', 'Number', 'Point']]]),
    evaluate_in(S, ['read-point'], Answers),
    assertion(Answers == [['Error', ['Point', 3, 4],
                          ['BadArgType', 1, 'String', 'Number']]]).

test(an_alias_change_recompiles_the_constructor_sort,
     [setup(setup_points(S)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: Coordinate (Alias Number))
               (: AliasPoint (-> Coordinate Coordinate AliasPoint))
               (= (alias-x (AliasPoint $x $y)) $x)
               (= (read-alias) (alias-x (AliasPoint 3 4)))", []),
    evaluate_in(S, ['read-alias'], [3]),
    metta_remove_atom(S, [':', 'Coordinate', ['Alias', 'Number']], true),
    run_in(S, "(: Coordinate (Alias String))", []),
    evaluate_in(S, ['read-alias'], Answers),
    assertion(Answers == [['Error', ['AliasPoint', 3, 4],
                          ['BadArgType', 1, 'Coordinate', 'Number',
                           ['TypeExpansion',
                            [->, 'Coordinate', 'Coordinate', 'AliasPoint'],
                            [->, 'String', 'String', 'AliasPoint']]]]]).

test(a_variable_subject_retires_every_affected_constructor_proof,
     [ setup(setup_points(S)), cleanup(metta_release_space(S)),
       forall((member(Door, [single, bulk]), member(Removal, [named, open]))) ]) :-
    run_in(S, "(= (constant-point) (Point 3 4))", []),
    evaluate_in(S, ['constant-point'], [['Point', 3, 4]]),
    metta_remove_atom(S, [':', 'Point', [->, 'Number', 'Number', 'Point']], true),
    Declaration = [':', _, [->, 'String', 'Number', 'Point']],
    ( Door == single -> metta_add_atom(S, Declaration, _)
    ; metta_add_atoms(S, [Declaration]) ),
    space_module(S, Module),
    findall(Answer, Module:'constant-point'(Answer), Answers),
    assertion(Answers == [['Error', ['Point', 3, 4],
                          ['BadArgType', 1, 'String', 'Number']]]),
    ( Removal == named -> Pattern = [':', 'Point', _]
    ; Pattern = [':', _, _] ),
    metta_remove_atom(S, Pattern, true),
    evaluate_in(S, ['constant-point'], Restored),
    assertion(Restored == [['Point', 3, 4]]).

test(a_referenced_constructor_keeps_its_home_sort_and_live_changes,
     [setup(setup_points(S)), cleanup(metta_release_space(S))]) :-
    'new-space'(Child),
    setup_call_cleanup(true,
        ( metta_add_atom(Child, [from, S], _),
          run_in(Child, "(= (read-child) (read-point))", []),
          evaluate_in(Child, ['read-child'], [3]),
          metta_remove_atom(S, [':', 'Point', [->, 'Number', 'Number', 'Point']], true),
          run_in(S, "(: Point (-> String Number Point))", []),
          evaluate_in(Child, ['read-child'], Answers),
          assertion(Answers == [['Error', ['Point', 3, 4],
                                ['BadArgType', 1, 'String', 'Number']]]) ),
        metta_release_space(Child)).

test(a_shared_variable_subject_retires_proofs_in_other_spaces,
     [setup('new-space'(S)), cleanup(metta_release_space(S))]) :-
    Arrow = [':', 'SharedPoint', [->, 'Number', 'Number', 'SharedPoint']],
    setup_call_cleanup(metta_add_atom('&self', Arrow, _),
        ( run_in(S, "(= (shared-point) (SharedPoint 3 4))", []),
          evaluate_in(S, ['shared-point'], [['SharedPoint', 3, 4]]),
          metta_remove_atom('&self', Arrow, true),
          Wildcard = [':', _, [->, 'String', 'Number', 'SharedPoint']],
          setup_call_cleanup(metta_add_atom('&self', Wildcard, _),
              ( space_module(S, Module),
                findall(Answer, Module:'shared-point'(Answer), Answers),
                assertion(Answers == [['Error', ['SharedPoint', 3, 4],
                                      ['BadArgType', 1, 'String', 'Number']]]) ),
              metta_remove_atom('&self', Wildcard, _)),
          evaluate_in(S, ['shared-point'], Restored),
          assertion(Restored == [['SharedPoint', 3, 4]]) ),
        metta_remove_atom('&self', Arrow, _)).

test(a_projection_keeps_its_method_argument_and_result_contracts,
     [setup(setup_points(S)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: wrong-input (-> String Number))
               (= (wrong-input (Point $x $y)) $x)
               (: wrong-result (-> Point String))
               (= (wrong-result (Point $x $y)) $x)", []),
    differential(S, ['wrong-input', ['Point', 3, 4]]),
    differential(S, ['wrong-result', ['Point', 3, 4]]).

test(a_conservative_constructor_check_keeps_its_home_through_from,
     [setup(setup_points(S)), cleanup(metta_release_space(S))]) :-
    transaction((run_in(S, "(= (slow-point) (Point 3 4))", []),
                 evaluate_in(S, ['slow-point'], [['Point', 3, 4]]))),
    'new-space'(Child),
    setup_call_cleanup(true,
        ( metta_add_atom(Child, [from, S], _),
          run_in(Child, "(: Point (-> String Number Point))", []),
          evaluate_in(Child, ['slow-point'], Answers),
          assertion(Answers == [['Point', 3, 4]]) ),
        metta_release_space(Child)).

test(a_typing_policy_change_reinstates_its_named_refusal,
     [setup(setup_points(S)), cleanup(metta_release_space(S))]) :-
    evaluate_in(S, ['read-point'], [3]),
    run_in(S, "!(add-typing-rule! reject-number ordinary Number Number
                 (refuse no-numbers))", _),
    evaluate_in(S, ['read-point'], Changed),
    assertion(Changed = [['Error', ['Point', 3, 4],
                         ['BadArgType', 1, 'Number', 'Number',
                          ['TypingRuleRefusal', 'reject-number', 'no-numbers']]]]),
    run_in(S, "!(remove-typing-rule! reject-number)", _),
    evaluate_in(S, ['read-point'], Restored), assertion(Restored == [3]).

test(an_untracked_plan_keeps_its_live_constructor_check,
     [setup(setup_points(S)), cleanup(metta_release_space(S))]) :-
    space_module(S, Module),
    with_metta_module(Module,
        translator:translate_clause([=, [outside], ['Point', 3, 4]],
                                    (_ :- Body))),
    assertion((sub_term(Goal, Body), nonvar(Goal),
               Goal = metta_bad_argument_error('Point', [3, 4], _))).

test(an_audit_observes_the_constructor_proof,
     [setup(setup_points(S)), cleanup(metta_release_space(S))]) :-
    space_module(S, Module),
    setup_call_cleanup(asserta(user:metta_discharges_verified, Ref),
        with_metta_module(Module,
            type_rules:with_typing_policy_stable(
                translator:with_static_contract_shortcuts(enabled,
                    translator:translate_expr(['Point', 3, 4], Goals, _)))),
        erase(Ref)),
    assertion((sub_term(Goal, Goals), nonvar(Goal),
               Goal = verified_discharge(_, _, discharge(constructor, 'Number', 3)))).

test(a_source_observation_keeps_the_projection_call,
     [setup(setup_points(S)), cleanup(metta_release_space(S))]) :-
    evaluate_in(S, ['read-point'], [3]),
    space_module(S, Module),
    setup_call_cleanup(nb_setval('$metta_observation', observing),
        with_metta_module(Module,
            type_rules:with_typing_policy_stable(
                translator:with_static_contract_shortcuts(enabled,
                    translator:translate_expr(['point-x', ['Point', 3, 4]],
                                              Goals, _)))),
        nb_delete('$metta_observation')),
    assertion((sub_term(Goal, Goals), nonvar(Goal), Goal = 'point-x'(_, _))).

test(a_rolled_back_arrow_change_restores_the_sorted_projection,
     [setup(setup_points(S)), cleanup(metta_release_space(S))]) :-
    evaluate_in(S, ['read-point'], [3]),
    \+ transaction((
        metta_remove_atom(S, [':', 'Point', [->, 'Number', 'Number', 'Point']], _),
        run_in(S, "(: Point (-> String Number Point))", []), fail)),
    evaluate_in(S, ['read-point'], Answers), assertion(Answers == [3]).

test(construction_proofs_retire_with_a_failed_compilation_context,
     [setup(setup_points(S)), cleanup(metta_release_space(S))]) :-
    space_module(S, Module),
    assertion(\+ nb_current('$metta_static_parameter_environment', _)),
    catch(with_metta_module(Module,
        type_rules:with_typing_policy_stable(
            translator:with_static_contract_shortcuts(enabled,
                translator:with_static_parameter_environment(
                    Module, probe, [], [],
                    ( translator:translate_expr(['Point', 3, 4], [], Value),
                      translator:constructor_sort_proved(Module, Value),
                      throw(construction_context_closed) ))))),
          construction_context_closed, true),
    assertion(\+ nb_current('$metta_static_parameter_environment', _)),
    metta_remove_atom(S, [':', 'Point', [->, 'Number', 'Number', 'Point']], _),
    run_in(S, "(: Point (-> String Number Point))", []),
    evaluate_in(S, ['read-point'], Answers),
    assertion(Answers == [['Error', ['Point', 3, 4],
                          ['BadArgType', 1, 'String', 'Number']]]).

call_cost(Space, Term, Cost) :-
    space_module(Space, Module),
    with_metta_module(Module,
        (statistics(inferences, Before), once(eval(Term, done)),
         statistics(inferences, After), Cost is After - Before)).

setup_loops(Space) :-
    setup_points(Space),
    run_in(Space, "
       (= (empty-loop $n) (if (== $n 0) done (let $_ 1 (empty-loop (- $n 1)))))
       (= (typed-loop $n) (if (== $n 0) done (let $_ (point-x (Point 3 4)) (typed-loop (- $n 1)))))
       (= (plain-loop $n) (if (== $n 0) done (let $_ (plain-x (Plain 3 4)) (plain-loop (- $n 1)))))", []).

test(a_cold_sorted_accessor_is_faster_than_its_untyped_twin,
     [setup(setup_loops(S)), cleanup(metta_release_space(S))]) :-
    call_cost(S, ['empty-loop', 100], Empty),
    call_cost(S, ['typed-loop', 100], Typed),
    call_cost(S, ['plain-loop', 100], Plain),
    assertion(Typed < Plain), assertion(Typed - Empty < 1500),
    evaluate_in(S, ['point-x', ['Point', 3, 4]], Direct),
    assertion(Direct == [3]).

test(a_deferred_projection_keeps_every_matching_occurrence,
     [setup(setup_points(S)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(= (point-x (Point $x $y)) $x)", []),
    evaluate_in(S, ['read-point'], Answers), assertion(Answers == [3, 3]).

test(a_warm_sorted_accessor_is_faster_than_its_untyped_twin,
     [setup(setup_loops(S)), cleanup(metta_release_space(S))]) :-
    forall(member(Head, ['empty-loop', 'typed-loop', 'plain-loop']),
           call_cost(S, [Head, 1], _)),
    forall(member(N, [100, 1000, 10000]),
        ( call_cost(S, ['empty-loop', N], Empty),
          call_cost(S, ['typed-loop', N], Typed),
          call_cost(S, ['plain-loop', N], Plain),
          assertion(Typed =:= Empty), assertion(Typed < Plain),
          assertion(Plain - Empty =:= N) )).

test(a_typed_callee_reuses_the_constructed_argument_sort,
     [setup(setup_points(S)), cleanup(metta_release_space(S))]) :-
    run_in(S, "
       (: sorted-norm (-> Point Number))
       (= (sorted-norm (Point $x $y)) (+ (* $x $x) (* $y $y)))
       (= (untyped-norm (Point $x $y)) (+ (* $x $x) (* $y $y)))
       (= (sorted-norm-loop $n) (if (== $n 0) done
          (let $_ (sorted-norm (Point 3 4)) (sorted-norm-loop (- $n 1)))))
       (= (untyped-norm-loop $n) (if (== $n 0) done
          (let $_ (untyped-norm (Point 3 4)) (untyped-norm-loop (- $n 1)))))", []),
    forall(member(Head, ['sorted-norm-loop', 'untyped-norm-loop']),
           call_cost(S, [Head, 1], _)),
    forall(member(N, [100, 1000, 10000]),
           ( call_cost(S, ['sorted-norm-loop', N], Typed),
             call_cost(S, ['untyped-norm-loop', N], Plain),
             assertion(Typed - Plain =< N) )),
    evaluate_in(S, ['sorted-norm', ['Point', 3, 4]], [25]).

test(a_callee_arrow_change_retires_its_argument_proof,
     [setup(setup_points(S)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: accepts-point (-> Point Number))
               (= (accepts-point $self) 7)
               (= (read-accepted-point) (accepts-point (Point 3 4)))", []),
    evaluate_in(S, ['read-accepted-point'], [7]),
    metta_remove_atom(S, [':', 'accepts-point', [->, 'Point', 'Number']], true),
    run_in(S, "(: accepts-point (-> String Number))", []),
    evaluate_in(S, ['read-accepted-point'], Answers),
    assertion(Answers == [['Error', ['accepts-point', ['Point', 3, 4]],
                          ['BadArgType', 1, 'String', 'Point']]]).

test(a_constructed_argument_keeps_a_live_callee_refinement,
     [setup(setup_points(S)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: admits-point (-> Point Bool))
               (= (admits-point $p) (match &self (admitted $p) True))
               (: refined-point (-> (Annotated Point (Predicate admits-point)) Number))
               (= (refined-point $self) 7)
               (= (read-refined-point) (refined-point (Point 3 4)))", []),
    evaluate_in(S, ['read-refined-point'], Before),
    assertion(Before = [['Error', _, ['BadArgValue', 1, ['Predicate', 'admits-point'], _]]]),
    metta_add_atom(S, [admitted, ['Point', 3, 4]], _),
    evaluate_in(S, ['read-refined-point'], [7]),
    metta_remove_atom(S, [admitted, ['Point', 3, 4]], true),
    evaluate_in(S, ['read-refined-point'], After),
    assertion(After == Before).

test(a_nullary_construction_proof_reaches_the_audit,
     [setup(setup_points(S)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: Unit (-> Unit)) (: unit-callee (-> Unit Number))
               (= (unit-callee $unit) 7)", []),
    space_module(S, Module),
    setup_call_cleanup(asserta(user:metta_discharges_verified, Ref),
        with_metta_module(Module,
            type_rules:with_typing_policy_stable(
                translator:with_static_contract_shortcuts(enabled,
                    translator:translate_expr(['unit-callee', ['Unit']], Goals, Value)))),
        erase(Ref)),
    assertion((sub_term(Goal, Goals), nonvar(Goal),
               Goal = verified_discharge(_, _,
                        discharge(constructed_argument, 'Unit', ['Unit'])))),
    findall(Value, with_metta_module(Module, call_goals_in(Module, Goals)), Answers),
    assertion(Answers == [7]).

:- end_tests(translator_constructors).
