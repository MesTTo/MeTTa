% Purpose: verify union type membership across the relation families, the value
%   doors and the compiled call boundary.
% Assumes: each fixture owns a fresh native space; `|` is union syntax only
%   where a type is read.
% Guarantees: a value fits a required union when some alternative fits it, an
%   actual union fits a requirement when every alternative does under one
%   assignment of the type variables they share, and the upstream relation's
%   shared-constraint loss cannot be reproduced here
%   [tested: run_tests(union_types); commit=7e2de138f59cd8137f55dce9e7f2f955906c76d1].
% Owns resources: setup/cleanup releases each space; no file is written.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(union_types).

context(Space, Module) :-
    'new-space'(Space),
    space_module(Space, Module).

run_in(Space, Source, Answers) :-
    setup_call_cleanup(asserta(filereader:silent(true), Ref),
                       process_metta_string(Source, Answers, Space),
                       erase(Ref)).

answers_in(Module, Term, Answers) :-
    with_metta_module(Module, findall(Answer, eval(Term, Answer), Answers)).

%%%%%%%%%% The syntax: what is a union and what is data %%%%%%%%%%

test(a_union_flattens_deduplicates_and_collapses_to_one_member) :-
    metta_runtime_type(['|', 'Number', ['|', 'String', 'Number'], 'String'],
                       Flat),
    assertion(Flat == ['|', 'Number', 'String']),
    metta_runtime_type(['|', 'Number', 'Number'], Collapsed),
    assertion(Collapsed == 'Number'),
    metta_runtime_type(['|', 'Number', 'String'], Unchanged),
    assertion(Unchanged == ['|', 'Number', 'String']).

test(a_union_member_that_is_an_annotated_arrow_is_projected) :-
    metta_runtime_type(['|', ['-[det]->', 'Number', 'Number'], 'String'],
                       Projected),
    assertion(Projected == ['|', [->, 'Number', 'Number'], 'String']).

test(distinct_type_variables_are_kept_because_they_are_only_variants) :-
    metta_runtime_type(['|', A, B], Kept),
    assertion(Kept == ['|', A, B]),
    assertion(A \== B),
    metta_runtime_type(['|', A, A], Same),
    assertion(Same == A).

test(an_empty_union_is_refused_as_type_syntax, [throws(error(metta_type_union_syntax(['|']), _))]) :-
    metta_runtime_type(['|'], _).

test(an_improper_union_is_refused_as_type_syntax,
     [throws(error(metta_type_union_syntax(_), _))]) :-
    Improper = ['|', 'Number'|_],
    metta_runtime_type(Improper, _).

test(a_declared_empty_union_names_its_own_syntax_error,
     [setup(context(S, _)), cleanup(metta_release_space(S))]) :-
    catch(run_in(S, "(: bad-empty (-> (|) %Undefined%)) (= (bad-empty $x) $x) !(bad-empty 1)", _),
          Ball, true),
    assertion(nonvar(Ball)),
    assertion(Ball = error(metta_type_union_syntax(['|']), _)).

test(a_pipe_expression_outside_a_type_stays_data,
     [setup(context(S, _)), cleanup(metta_release_space(S))]) :-
    run_in(S, "!(| a b) !(let $f (|-> ($x) (+ $x 1)) ($f 2)) !(get-metatype |)",
           Answers),
    assertion(Answers == [['|', a, b], 3, 'Symbol']).

%%%%%%%%%% Membership at the call boundary %%%%%%%%%%

test(a_required_union_admits_each_member_and_refuses_a_non_member,
     [setup(context(S, _)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: union-id (-> (| Number String) %Undefined%)) (= (union-id $x) $x) !(union-id 1) !(union-id \"s\") !(union-id True)", Answers),
    assertion(Answers == [1, "s",
                          ['Error', ['union-id', true],
                           ['BadArgType', 1, ['|', 'Number', 'String'],
                            'Bool']]]).

test(a_union_result_is_checked_and_reported_as_written,
     [setup(context(S, _)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: mk (-> Atom (| Number String))) (= (mk $x) $x) !(mk 1) !(mk \"s\") !(mk True) !(get-type (mk 1))", Answers),
    assertion(Answers == [1, "s", ['|', 'Number', 'String']]).

test(an_actual_union_fits_a_wider_union_and_not_a_narrower_one,
     [setup(context(S, _)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: v (| Number String)) (: wide (-> (| Number String Bool) %Undefined%)) (= (wide $x) got) (: narrow (-> (| Number Bool) %Undefined%)) (= (narrow $x) got) !(wide v) !(narrow v)", Answers),
    assertion(Answers == [got,
                          ['Error', [narrow, v],
                           ['BadArgType', 1, ['|', 'Number', 'Bool'],
                            ['|', 'Number', 'String']]]]).

test(a_union_at_a_tuple_position_is_decided_per_position,
     [setup(context(S, _)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: pair-in (-> ((| Number String) Bool) %Undefined%)) (= (pair-in $x) $x) !(pair-in (1 True)) !(pair-in (\"s\" True)) !(pair-in (True True))", Answers),
    assertion(Answers == [[1, true], ["s", true],
                          ['Error', ['pair-in', [true, true]],
                           ['BadArgType', 1,
                            [['|', 'Number', 'String'], 'Bool'],
                            ['Bool', 'Bool']]]]).

test(a_union_of_tuples_keeps_the_positional_walk,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: alt-in (-> (| (Number Bool) (String Bool)) %Undefined%)) (= (alt-in $x) got) !(alt-in (1 True)) !(alt-in (\"s\" True)) !(alt-in (True True))", Answers),
    assertion(Answers = [got, got, ['Error', _, ['BadArgType', 1, _, _]]]),
    assertion(tuple_positions_witness(M, [1, true],
                                      ['|', ['Number', 'Bool'],
                                       ['String', 'Bool']])),
    assertion(\+ tuple_positions_witness(M, [1, true],
                                         ['|', 'Number', 'String'])).

test(an_alias_naming_a_union_behaves_as_the_union_it_names,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: Scalar (Alias (| Number String))) (: scalar-id (-> Scalar %Undefined%)) (= (scalar-id $x) $x) !(scalar-id 1) !(scalar-id \"s\") !(scalar-id True)", Answers),
    assertion(Answers = [1, "s", ['Error', ['scalar-id', true],
                                  ['BadArgType', 1, 'Scalar', 'Bool'|_]]]),
    normalize_type_in(M, 'Scalar', Canonical, _),
    assertion(Canonical == ['|', 'Number', 'String']).

%Alias substitution and union canonicalisation are separate steps: the alias
%reader answers written syntax with names replaced, and metta_runtime_type/2
%flattens what that produced. normalize_callable_type_in/3 is the reader every
%checker uses, and it is the one that does both.
test(a_union_naming_an_alias_expands_before_it_is_flattened,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    metta_add_atom(S, [':', 'Count', ['Alias', 'Number']], true),
    metta_add_atom(S, [':', 'Text', ['Alias', ['|', 'String', 'Count']]], true),
    normalize_type_in(M, ['|', 'Count', 'Text'], Expanded, _),
    assertion(Expanded == ['|', 'Number', ['|', 'String', 'Number']]),
    normalize_callable_type_in(M, ['|', 'Count', 'Text'], Canonical),
    assertion(Canonical == ['|', 'Number', 'String']).

test(a_multi_typed_atom_still_finds_its_witness,
     [setup(context(S, _)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: at A) (: at T) (: takes-t (-> (| T Number) %Undefined%)) (= (takes-t $x) got) !(takes-t at)", Answers),
    assertion(Answers == [got]).

test(a_value_admitted_through_its_supertype_is_admitted_through_a_union,
     [setup(context(S, _)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: Rex Dog) (:< Dog Animal) (: pet-in (-> (| Animal Number) %Undefined%)) (= (pet-in $x) got) !(pet-in Rex) !(pet-in 1) !(pet-in \"s\")", Answers),
    assertion(Answers = [got, got, ['Error', _, ['BadArgType', 1, _, 'String']]]).

%%%%%%%%%% Duplicates and multiply-admitted values answer once %%%%%%%%%%

test(a_refined_union_member_checks_the_value_at_each_call_door,
     [setup(context(S, _)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: refined-in (-> (| (Annotated Number (Gt 0)) String) Number)) (= (refined-in $x) 1) (= (forward $x) (refined-in $x)) !(refined-in 2) !(forward 2) !(refined-in \"s\") !(forward -2)", Answers),
    assertion(Answers = [1, 1, 1, ['Error', _, ['BadArgType'|_]]]).

test(a_refined_union_result_admits_only_a_satisfied_alternative,
     [setup(context(S, _)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: refined-out (-> Atom (| (Annotated Number (Gt 0)) String))) (= (refined-out $x) $x) !(refined-out 2) !(refined-out \"s\") !(refined-out -2)", Answers),
    assertion(Answers == [2, "s"]).

test(an_outer_refinement_reports_its_constraint_after_a_refined_union_base,
     [setup(context(S, _)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: outer-refined (-> (Annotated (| (Annotated Number (Gt 0)) String) (Gt 2)) Number)) (= (outer-refined $x) 1) !(outer-refined 3) !(outer-refined 1)", Answers),
    assertion(Answers == [1, ['Error', ['outer-refined', 1],
                              ['BadArgValue', 1, ['Gt', 2], 1]]]).

test(a_gradual_unknown_does_not_discharge_refined_union_constraints,
     [setup(context(S, _)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: nonzero (-> (| (Annotated Number (Gt 0)) (Annotated Number (Lt 0))) Number)) (= (nonzero $x) 1) !(nonzero 2) !(nonzero -2) !(nonzero 0) !(nonzero mystery)", Answers),
    assertion(Answers = [1, 1, ['Error', _, _], ['Error', _, _]]).

test(a_refined_alternative_retains_the_assignment_a_later_parameter_needs,
     [setup(context(S, _)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: refined-shared (-> (| $t (Annotated Number (Gt 0))) $t Number)) (= (refined-shared $x $y) 1) !(refined-shared 2 \"s\") !(refined-shared -2 \"s\")", Answers),
    assertion(Answers = [1, ['Error', _, ['BadArgType'|_]]]).

test(a_declared_actual_union_still_proves_a_refined_union_requirement,
     [setup(context(S, _)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: known (| (Annotated Number (Gt 0)) String)) (: refined-known (-> (| (Annotated Number (Gt 0)) String Bool) Number)) (= (refined-known $x) 1) !(refined-known known)", Answers),
    assertion(Answers == [1]).

test(a_user_whole_union_refusal_precedes_its_value_refinements,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: guarded-refined (-> (| (Annotated Number (Gt 0)) String) Number)) (= (guarded-refined $x) 1) (= (forward $x) (guarded-refined $x))", []),
    with_metta_module(M,
        'add-typing-rule!'('deny-refined-whole', ordinary, 'Number',
                           ['|', ['Annotated', 'Number', ['Gt', 0]], 'String'],
                           [refuse, 'the whole union is denied'], true)),
    answers_in(M, ['guarded-refined', 2], Direct),
    answers_in(M, [forward, 2], Retained),
    assertion(Direct = [['Error', _, ['BadArgType'|_]]]),
    assertion(Retained = [['Error', _, ['BadArgType'|_]]]),
    with_metta_module(M, 'remove-typing-rule!'('deny-refined-whole', true)),
    answers_in(M, ['guarded-refined', 2], Restored),
    assertion(Restored == [1]).

test(a_refused_member_does_not_hide_a_satisfied_value_refinement,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: value-choice (-> (| (Annotated Number (Gt 0)) String) Number)) (= (value-choice $x) 1)", []),
    with_metta_module(M,
        'add-typing-rule!'('deny-text-member', ordinary, 'Number', 'String',
                           [refuse, 'a number is not text'], true)),
    answers_in(M, ['value-choice', 2], Answers),
    assertion(Answers == [1]).

test(refined_union_failures_do_not_evaluate_an_argument_twice,
     [setup(context(S, _)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: refined-effect (-> (| (Annotated Number (Gt 0)) String) Number)) (= (refined-effect $x) 1) (= (produce) (chain (add-atom &self (observed)) $ignored -2)) !(refined-effect (produce)) !(collapse (match &self (observed) seen))", Answers),
    assertion(Answers = [['Error', _, _], [seen]]).

test(a_repeated_member_neither_duplicates_an_answer_nor_a_side_effect,
     [setup(context(S, _)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: dup (-> (| Number Number) %Undefined%)) (= (dup $x) (let $ignored (add-atom &self (saw $x)) done)) !(dup 7) !(collapse (match &self (saw $n) $n))", Answers),
    assertion(Answers == [done, [7]]).

test(a_value_fitting_two_alternatives_answers_once,
     [setup(context(S, _)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: two (-> (| Atom Number) %Undefined%)) (= (two $x) seen) !(two 1) !(collapse (two 1))", Answers),
    assertion(Answers == [seen, [seen]]).

%%%%%%%%%% Shared type variables get ONE consistent assignment %%%%%%%%%%

test(a_shared_variable_across_an_input_and_a_union_is_assigned_once,
     [setup(context(S, _)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: same (-> (| $t Bool) $t %Undefined%)) (= (same $a $b) got) !(same 1 2) !(same 1 \"s\")", Answers),
    assertion(Answers = [got, ['Error', [same, 1, "s"],
                               ['BadArgType', 2, 'Number', 'String']]]).

%The first argument's `$t` alternative binds $t to Bool and the second argument
%then has no consistent type, so the check has to come back and take the
%literal `Bool` alternative instead, leaving $t for the second argument to fix.
%Committing to the first alternative that fits argument one answers nothing.
test(a_first_argument_does_not_commit_away_the_alternative_a_later_one_needs,
     [setup(context(S, _)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: bt (-> (| $t Bool) $t %Undefined%)) (= (bt $a $b) got) !(bt True 1) !(bt \"s\" 1)", Answers),
    assertion(Answers = [got, ['Error', [bt, "s", 1], ['BadArgType' | _]]]).

test(the_upstream_witness_cannot_discharge_a_shared_variable,
     [forall(member(Family, [ordinary, derived, reporting, witness]))]) :-
    metta_self_module(Self),
    Actual = ['|', 'Number', 'String'],
    Unsatisfiable = ['|', _T, 'Bool'],
    assertion(\+ type_rules:typing_rule_accepts_resolved(Self, Family, Actual,
                                                         Unsatisfiable)),
    Satisfiable = ['|', Bound, 'String'],
    (   Family == ordinary
    ->  type_rules:typing_rule_accepts_resolved(Self, Family, Actual,
                                                Satisfiable),
        assertion(Bound == 'Number')
    ;   true
    ).

%Each relation is asked on its own, because they overlap: a value door that
%reaches both the witness relation and the shipped fast path is still admitted
%when one of them stops deciding, and a test that only drives the public surface
%cannot tell which one answered.
test(the_shipped_fast_path_decides_union_membership_on_its_own) :-
    assertion(metta_shipped_types_match('Number', ['|', 'Number', 'String'])),
    assertion(\+ metta_shipped_types_match('Bool', ['|', 'Number', 'String'])),
    assertion(metta_shipped_types_match(['|', 'Number', 'String'],
                                        ['|', 'Number', 'String', 'Bool'])),
    assertion(\+ metta_shipped_types_match(['|', 'Number', 'Bool'],
                                           ['|', 'Number', 'String'])).

test(the_candidate_witness_decides_union_membership_on_its_own) :-
    metta_self_module(Self),
    assertion(type_witness_candidate_matches(Self, 'Number',
                                             ['|', 'Number', 'String'])),
    assertion(\+ type_witness_candidate_matches(Self, 'Bool',
                                                ['|', 'Number', 'String'])),
    assertion(type_witness_candidate_matches(Self, ['|', 'Number', 'String'],
                                             ['|', 'Number', 'String',
                                              'Bool'])),
    assertion(\+ type_witness_candidate_matches(Self,
                                                ['|', 'Number', 'String'],
                                                'Number')).

test(the_shipped_fast_path_refuses_the_upstream_witness_and_binds_the_twin) :-
    Actual = ['|', 'Number', 'String'],
    assertion(\+ metta_shipped_types_match(Actual, ['|', _, 'Bool'])),
    Satisfiable = ['|', Bound, 'String'],
    metta_shipped_types_match(Actual, Satisfiable),
    assertion(Bound == 'Number').

%%%%%%%%%% Each family keeps its own meaning of Atom and %Undefined% %%%%%%%%%%

test(the_gradual_unknown_and_atom_keep_each_familys_meaning) :-
    metta_self_module(Self),
    Union = ['|', 'Number', 'String'],
    WithAtom = ['|', 'Atom', 'Bool'],
    % ordinary: a gradual actual and an Atom alternative both admit.
    assertion(type_rules:typing_rule_accepts_resolved(Self, ordinary,
                                                      '%Undefined%', Union)),
    assertion(type_rules:typing_rule_accepts_resolved(Self, ordinary,
                                                      'Number', WithAtom)),
    % reporting: Atom is an ordinary type there, so it admits only itself.
    assertion(\+ type_rules:typing_rule_accepts_resolved(Self, reporting,
                                                         'Number', WithAtom)),
    assertion(type_rules:typing_rule_accepts_resolved(Self, reporting,
                                                      'Atom', WithAtom)),
    % witness: only the expected side is gradual, so an unknown proves nothing.
    assertion(\+ type_rules:typing_rule_accepts_resolved(Self, witness,
                                                         '%Undefined%', Union)),
    assertion(type_rules:typing_rule_accepts_resolved(Self, witness,
                                                      'Number', Union)).

test(a_union_containing_an_arrow_follows_the_arrow_relation,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: fn (-> Number Number)) (= (fn $x) $x) (: takes-fn (-> (| (-> Number Number) String) %Undefined%)) (= (takes-fn $f) got) !(takes-fn fn) !(takes-fn 1)", Answers),
    assertion(Answers = [got, ['Error', _, ['BadArgType', 1, _, 'Number']]]),
    assertion(type_witness_candidate_matches(
                  M, [->, 'Number', 'Number'],
                  ['|', ['-[det]->', 'Number', 'Number'], 'String'])).

%%%%%%%%%% User policy: the whole pair first, then the alternatives %%%%%%%%%%

test(a_user_refusal_of_the_whole_pair_is_decisive_in_retained_and_runnable_code,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: guard (-> (| Number String) %Undefined%)) (= (guard $x) ok) (= (caller $x) (guard $x)) !(guard 1) !(caller 1)", Before),
    assertion(Before == [ok, ok]),
    with_metta_module(M,
        'add-typing-rule!'('no-number-union', ordinary, 'Number',
                           ['|', 'Number', 'String'],
                           [refuse, 'a number is not this union'], true)),
    answers_in(M, [guard, 1], Runnable),
    answers_in(M, [caller, 1], Retained),
    assertion(Runnable = [['Error', _, ['BadArgType', 1, _, 'Number'|_]]]),
    assertion(Retained = [['Error', _, ['BadArgType', 1, _, 'Number'|_]]]),
    answers_in(M, [guard, "s"], Permitted),
    assertion(Permitted == [ok]),
    with_metta_module(M, 'remove-typing-rule!'('no-number-union', true)),
    answers_in(M, [guard, 1], After),
    answers_in(M, [caller, 1], AfterRetained),
    assertion(After == [ok]),
    assertion(AfterRetained == [ok]).

test(a_refused_alternative_does_not_refuse_a_permitted_one,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: guard (-> (| Number String) %Undefined%)) (= (guard $x) ok)", []),
    with_metta_module(M,
        'add-typing-rule!'('no-number-member', ordinary, 'Number', 'Number',
                           [refuse, 'not a number'], true)),
    answers_in(M, [guard, 1], Refused),
    answers_in(M, [guard, "s"], Permitted),
    assertion(Refused = [['Error', _, _]]),
    assertion(Permitted == [ok]),
    with_metta_module(M, 'remove-typing-rule!'('no-number-member', true)),
    answers_in(M, [guard, 1], Restored),
    assertion(Restored == [ok]).

test(a_union_refusal_carries_the_rule_that_refused_it,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: guard (-> (| Number Bool) %Undefined%)) (= (guard $x) ok)", []),
    with_metta_module(M,
        'add-typing-rule!'('deny-number', ordinary, 'Number', 'Number',
                           [refuse, 'denied'], true)),
    once(with_metta_module(M,
        type_rules:typing_rule_refusal_resolved(M, ordinary, 'Number',
                                                ['|', 'Number', 'Bool'],
                                                Name, Reason))),
    assertion(Name == 'deny-number'),
    assertion(Reason == denied),
    with_metta_module(M, 'remove-typing-rule!'('deny-number', true)).

%%%%%%%%%% Compile time: an uncertain union keeps its runtime obligation %%%%%%

test(an_uncertain_union_comparison_is_not_a_static_refusal,
     [setup(context(S, _)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: u (-> (| Number String) %Undefined%)) (= (u $x) got) (= (call-u) (u mystery)) !(call-u) !(u mystery)", Answers),
    assertion(Answers == [got, got]).

test(a_static_parameter_proof_still_needs_a_ground_union,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    with_metta_module(M,
        ( assertion(translator:static_checked_parameter_type(
                        [[->, ['|', 'Number', 'String'], '%Undefined%']], 1,
                        ['|', 'Number', 'String'])),
          assertion(\+ translator:static_checked_parameter_type(
                        [[->, ['|', _, 'String'], '%Undefined%']], 1, _)) )).

test(a_union_parameter_is_evaluated_and_checked_like_an_ordinary_one,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: held (-> (| Atom Number) %Undefined%)) (= (held $x) $x) !(held (+ 1 2))", Answers),
    assertion(Answers == [3]),
    with_metta_module(M, ( once(translator:metta_runtime_argument_mask(held, 1,
                                                                       Mask)),
                           assertion(Mask == [true]) )).

%%%%%%%%%% Where union membership deliberately stops %%%%%%%%%%

%`match-types` is the arbiter's relation, unification with the two wildcards,
%and `type-cast` is built on it. It compares WRITTEN types, so it relates a
%union to itself and to a variable and decomposes neither side. Union
%membership is the argument and result relation, reached by declaring a
%parameter; the engine's own witness family, which Python's cast asks, does
%decompose. This is a boundary rather than an omission: revisit it if a program
%needs a union cast target, which would take an internal comparison form beside
%__metta_type_syntax__ rather than a change to the arbiter's relation.
test(a_cast_target_is_compared_by_unification_and_is_not_decomposed,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    run_in(S, "(: v (| Number String)) !(type-cast 1 Number &self) !(type-cast 1 (| Number String) &self) !(type-cast v (| Number String) &self) !(match-types Number (| Number String) True False)", Answers),
    assertion(Answers == [1, ['Error', 1, 'BadType'], v, false]),
    assertion(type_rules:typing_rule_accepts_resolved(M, witness, 'Number',
                                                      ['|', 'Number',
                                                       'String'])).

%%%%%%%%%% Cost: a program with no union pays for none of this %%%%%%%%%%

%The union arms are guarded by inlined tests, which retire no inference. A MISS
%runs the whole chain including every guard where a HIT stops at the sixth
%comparison, so the two costing the same is the measurable statement that the
%guards are free. Pinning either number on its own would pin the chain's
%length instead.
test(the_union_guards_retire_no_inference_on_a_pair_with_no_union) :-
    union_check_cost(metta_shipped_types_match('Number', 'Number'), Hit),
    union_check_cost(metta_shipped_types_match('Number', 'String'), Miss),
    assertion(Hit =:= Miss).

%Unions are syntax, not declarations, so a checker that reads no `|` must have
%nothing to look through. This is the alias suite's unrelated-declaration scan
%question asked of this feature: the cost of a union-free check must not move
%when the space fills up with union declarations.
test(a_union_free_check_does_not_scan_declared_unions,
     [setup(context(S, M)), cleanup(metta_release_space(S))]) :-
    union_check_cost(metta_types_match_in(M, 'Number', 'Number'), Empty),
    forall(between(1, 200, N),
           ( atom_concat('union-name-', N, Name),
             metta_add_atom(S, [':', Name, ['|', 'Number', 'String']], true) )),
    union_check_cost(metta_types_match_in(M, 'Number', 'Number'), Loaded),
    assertion(Empty =:= Loaded).

union_check_cost(Goal, Per) :-
    Rounds = 1000,
    statistics(inferences, Before),
    forall(between(1, Rounds, _), ( call(Goal) -> true ; true )),
    statistics(inferences, After),
    Per is (After - Before - 3 * Rounds) // Rounds.

:- end_tests(union_types).
