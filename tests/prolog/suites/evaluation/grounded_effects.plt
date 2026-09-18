% Purpose: verify effect planning through a grounded provider's applicability.
% Guarantees: executable grounded heads have an opaque effect; data and quoted
%   calls retain structural effects, and planning never applies the provider.
% [tested: grounded_source_effects; commit=84c73d0d703be50c3520b2e08488581e77a7ce3f]

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

% A provider owns the applicability question independently of application.
:- multifile seam:grounded_applicable/1.
seam:grounded_applicable("plunit-opaque-callable").

:- multifile seam:grounded_apply/4.
seam:grounded_apply("plunit-opaque-callable", _, _, _) :-
    throw(error(plunit_effect_plan_applied_its_target, _)).

:- begin_tests(grounded_source_effects).

test(an_applicable_grounded_source_has_the_compiled_goals_opaque_effect,
     [forall(member(Goal,
         [grounded_apply("plunit-opaque-callable", [3], [], _),
          metta_dynamic_call("plunit-opaque-callable", [3], _),
          metta_dynamic_value_call("plunit-opaque-callable", [3], [3], _),
          reduce(["plunit-opaque-callable", 3], _, _)]))]) :-
    metta_self_module(Module),
    metta_host_goal_effect_plan(
        Module, Goal, CompiledOperations, CompiledEffect),
    assertion(CompiledEffect == oracleIO),
    metta_host_source_effect_plan(Module, ["plunit-opaque-callable", 3],
                                  Operations, Effect),
    assertion(Effect == oracleIO),
    assertion(Operations == CompiledOperations).

test(a_retained_equation_exposes_its_grounded_call,
     [ cleanup(metta_remove_atom('&self',
                   ['=', ['plunit-opaque-wrapper', _], _], _)) ]) :-
    metta_add_atom('&self', ['=', ['plunit-opaque-wrapper', Value],
                                  ["plunit-opaque-callable", Value]], true),
    metta_self_module(Module),
    metta_host_source_effect_plan(Module, ['plunit-opaque-wrapper', 3],
                                  Operations, Effect),
    assertion(memberchk(['<dynamic-operation>', oracleIO], Operations)),
    assertion(Effect == oracleIO).

test(quoted_grounded_calls_remain_data) :-
    metta_self_module(Module),
    metta_host_source_effect_plan(Module,
        [noeval, ["plunit-opaque-callable", 3]], _, Effect),
    assertion(Effect == pureStructural).

test(nonapplicable_grounded_heads_remain_data,
     [forall(member(Head, [1, 1.5, "plunit-inert-value"]))]) :-
    metta_self_module(Module),
    metta_host_source_effect_plan(Module, [Head, 3], Operations, Effect),
    assertion(Operations == []),
    assertion(Effect == pureStructural).

:- end_tests(grounded_source_effects).
