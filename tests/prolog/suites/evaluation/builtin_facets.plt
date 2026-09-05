% Purpose: prove builtin names, exact implementation facets, project-owned
%   surface predicates, and reason-bearing exemptions remain mutually complete.
% Assumes: engine/metta.pl completes its ordered boot before this suite mutates
%   the dynamic registries, and each mutation is erased by its cleanup goal.
% Guarantees: both coverage directions reject omissions at the exact name,
%   MeTTa arity, and Prolog hook; exemptions are local, reasoned, unique, and
%   live [tested: tests/prolog/suites/evaluation/builtin_facets.plt;
%   commit=WORKTREE].

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

'plunit-builtin-facet-one'(Input, Input).
'plunit-builtin-facet-reverse'(Input, Input).

with_assertions([], Goal) :- call(Goal).
with_assertions([Fact|Facts], Goal) :-
    setup_call_cleanup(assertz(Fact, Reference),
                       with_assertions(Facts, Goal),
                       erase(Reference)).

:- begin_tests(builtin_facets).

test(the_live_registry_is_complete_in_both_directions) :-
    builtin_registration_coverage_inventory(Registration),
    assertion(Registration == []),
    validate_builtin_registration_coverage,
    validate_builtin_implementation_coverage,
    validate_builtin_registry.

test(the_core_declaration_keeps_the_name_registry_authoritative) :-
    assertion(builtin_fun('+')),
    assertion(builtin_implementation('+'/2, prolog(engine))),
    assertion(builtin_implementation(let/3,
                                     compiler(translator,
                                              metta_special_form_head, 1))),
    assertion(builtin_implementation('let*'/2,
                                     compiler(translator,
                                              metta_special_form_head, 1))),
    findall(Name,
            ( builtin_implementation(Name/_, _), \+ builtin_fun(Name) ),
            Unregistered),
    assertion(Unregistered == []).

test(prelude_facets_are_derived_from_prelude_ownership) :-
    forall(( prelude_owned(Name),
             prelude_equation(Name, ['=', [Name|Arguments], _]),
             length(Arguments, Arity) ),
           assertion(builtin_implementation(Name/Arity, prelude(_)))),
    assertion(builtin_implementation(union/2, prelude(equation))),
    assertion(builtin_implementation(intersection/2, prelude(equation))).

test(extension_facets_are_derived_from_extension_ownership) :-
    forall(( seam:extension_builtin(Name, _),
             arity(Name, PrologArity),
             PrologArity > 0,
             Arity is PrologArity - 1 ),
           assertion(builtin_implementation(Name/Arity, extension(_)))).

% Asking about ONE predicate must not synthesise the whole surface union to
% answer. Synthesising it made each of the five exemption liveness questions
% cost 1,842 inferences of setof and member/2 walk before its own 81 of work,
% which was 9,214 of a boot's 35,275 inferences of registry validation.
% A RATIO rather than a pin, because both sides move with the size of the
% union and the number of loaded predicates: the bound ask reads 81 and the
% scan 12,237, a factor of 151, where synthesising put the same factor at 6.6
% [measured 2026-09-06: 81 and 12,237 inferences].
surface_question_cost(Question, Cost) :-
    statistics(inferences, Before),
    ( call(Question) -> true ; true ),
    statistics(inferences, After),
    Cost is After - Before - 3.

test(a_bound_surface_question_does_not_synthesise_the_whole_union) :-
    surface_question_cost(
        builtin_surface_predicate(spaces:metta_prune_empty/2, _), Bound),
    surface_question_cost(
        findall(_, builtin_surface_predicate(_, _), _), Scan),
    assertion(Bound > 0),
    assertion(Scan > 20 * Bound).

% The reverse scan does not read translator:embedded_operation_head/1: the
% engine may only reach what the translator's module exports, and that table
% is not on the export list. Nothing is lost while every head it names is
% already named by one of the seven sources the scan does read, so the claim
% is asked of the engine here instead of being asserted in a comment there. A
% head that stops being covered fails this and the decision is then a real
% one: name it on another surface, or put it on the translator's export list.
test(the_translators_embedded_operations_add_no_surface_name) :-
    findall(Name,
            ( translator:embedded_operation_head(Name),
              atom(Name),
              \+ builtin_surface_name(Name) ),
            Uncovered),
    assertion(Uncovered == []),
    aggregate_all(count, translator:embedded_operation_head(_), Heads),
    assertion(Heads > 40).

test(the_current_reverse_inventory_names_every_independent_surface_orphan) :-
    builtin_implementation_coverage_inventory(Inventory),
    assertion(Inventory ==
              [ predicate(spaces:metta_prune_empty/2),
                predicate(spaces:metta_require_current_capability/2),
                predicate(spaces:metta_require_safe_goal/1),
                predicate(spaces:metta_require_space_update_capability/2),
                predicate(user:'=@='/3)
              ]).

test(the_legacy_variant_predicate_is_exempt_in_place) :-
    Reason = legacy_alpha_equivalence_spelling_is_not_language_visible,
    clause(seam:builtin_implementation_exemption('=@='/3, Reason), true,
           Reference),
    clause_property(Reference, file(File)),
    sub_atom(File, _, _, 0, '/engine/metta/operators.pl').

% Each subject is PARENTHESISED and each row is destructured in the ACTION
% rather than in the condition. SWI gives `:` priority 600 and `-` priority
% 500, so `spaces:metta_prune_empty/2-Reason-Suffix` reads as
% `spaces:((metta_prune_empty/2-Reason)-Suffix)`, the whole row inside the
% module qualifier: `member(Subject-Reason-Suffix, Expected)` then matched
% nothing, the forall/2 was vacuously true, and this test passed unchanged
% against a tree with no exemption seam at all. Destructuring in the action
% makes a row that does not match FAIL rather than disappear, and the length
% is pinned so an empty list cannot pass either.
test(the_effect_planner_helpers_are_exempt_in_place) :-
    Expected =
        [ (spaces:metta_prune_empty/2)-
              compiled_collapse_helper_is_not_a_language_operation-
              '/engine/spaces/bounded_matching.pl',
          (spaces:metta_require_current_capability/2)-
              compiled_capability_guard_is_not_a_language_operation-
              '/engine/spaces/lifecycle.pl',
          (spaces:metta_require_safe_goal/1)-
              compiled_safe_goal_guard_is_not_a_language_operation-
              '/engine/spaces/lifecycle.pl',
          (spaces:metta_require_space_update_capability/2)-
              compiled_space_update_guard_is_not_a_language_operation-
              '/engine/spaces/lifecycle.pl'
        ],
    length(Expected, 4),
    forall(member(Row, Expected),
           ( Row = Subject-Reason-Suffix,
             clause(seam:builtin_implementation_exemption(Subject, Reason), true,
                    Reference),
             clause_property(Reference, file(File)),
             sub_atom(File, _, _, 0, Suffix) )).

test(a_registered_name_without_a_description_is_rejected,
     [ throws(error(unregistered_builtin_spec('plunit-undescribed'),
                    builtin_registry)) ]) :-
    with_assertions(
        [ builtin_fun('plunit-undescribed') ],
        validate_builtin_registration_coverage).

test(a_missing_overload_description_is_rejected_at_its_metta_arity,
     [ throws(error(unregistered_builtin_spec('plunit-builtin-facet-one'/2),
                    builtin_registry)) ]) :-
    with_assertions(
        [ builtin_fun('plunit-builtin-facet-one'),
          arity('plunit-builtin-facet-one', 2),
          arity('plunit-builtin-facet-one', 3),
          builtin_implementation('plunit-builtin-facet-one'/1,
                                 prolog(engine))
        ],
        validate_builtin_registration_coverage).

test(a_reasoned_registration_exemption_admits_one_exact_name) :-
    with_assertions(
        [ builtin_fun('plunit-registration-exempt'),
          builtin_registration_exemption(
              'plunit-registration-exempt',
              fixture_has_no_callable_implementation)
        ],
        ( validate_builtin_exemptions,
          validate_builtin_registration_coverage )).

test(a_described_implementation_without_a_registered_name_is_rejected,
     [ throws(error(unregistered_builtin_implementation(
                        'plunit-builtin-facet-reverse'/1),
                    builtin_registry)) ]) :-
    with_assertions(
        [ builtin_implementation('plunit-builtin-facet-reverse'/1,
                                 prolog(engine)) ],
        validate_builtin_implementation_coverage).

test(an_unexempted_surface_predicate_is_rejected,
     [ throws(error(unregistered_builtin_implementation(user:'=@='/3),
                    builtin_registry)) ]) :-
    Reason = legacy_alpha_equivalence_spelling_is_not_language_visible,
    setup_call_cleanup(
        seam:retract(builtin_implementation_exemption('=@='/3, Reason)),
        validate_builtin_implementation_coverage,
        seam:assertz(builtin_implementation_exemption('=@='/3, Reason))).

test(a_missing_callable_hook_is_rejected,
     [ throws(error(undefined_builtin_implementation_hook(
                        'plunit-missing-hook'/1, prolog(engine)),
                    builtin_registry)) ]) :-
    with_assertions(
        [ builtin_implementation('plunit-missing-hook'/1, prolog(engine)) ],
        validate_builtin_implementation_hooks).

test(a_missing_compiler_hook_is_rejected,
     [ throws(error(undefined_builtin_implementation_hook(
                        'plunit-compiler-form'/1,
                        compiler(translator, plunit_missing_hook, 1)),
                    builtin_registry)) ]) :-
    with_assertions(
        [ builtin_implementation(
              'plunit-compiler-form'/1,
              compiler(translator, plunit_missing_hook, 1)) ],
        validate_builtin_implementation_hooks).

test(a_malformed_implementation_facet_is_rejected,
     [ throws(error(invalid_builtin_implementation(
                        'plunit-malformed'/ -1, prolog(engine)),
                    builtin_registry)) ]) :-
    with_assertions(
        [ builtin_implementation('plunit-malformed'/ -1, prolog(engine)) ],
        validate_builtin_implementation_schema).

test(a_duplicate_key_is_rejected,
     [ throws(error(duplicate_builtin_implementation_key('+'/2),
                    builtin_registry)) ]) :-
    with_assertions(
        [ builtin_implementation('+'/2, prolog(engine)) ],
        validate_builtin_implementation_unique).

test(an_empty_exemption_reason_is_rejected,
     [ throws(error(invalid_builtin_registration_exemption(
                        'plunit-empty-reason', ''),
                    builtin_registry)) ]) :-
    with_assertions(
        [ builtin_registration_exemption('plunit-empty-reason', '') ],
        validate_builtin_exemption_schema).

test(a_stale_implementation_exemption_is_rejected,
     [ throws(error(stale_builtin_implementation_exemption('+'/3),
                    builtin_registry)) ]) :-
    with_assertions(
        [ seam:builtin_implementation_exemption(
              '+'/3, a_registered_hook_needs_no_exemption) ],
        validate_builtin_exemption_liveness).

:- end_tests(builtin_facets).
