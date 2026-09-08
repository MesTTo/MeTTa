% Purpose: measure source attribution for a defined and an absent host goal.
% Assumes: the engine's native artifacts are provisioned in this checkout
% [source: engine/source_observation.pl:goal_attribution/3; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720].
:- ensure_loaded('../../../engine/qlf_boot').
:- metta_qlf_boot:qlf_load_engine.
:- initialization(module_attribution_main, main).
module_attribution_main :-
    metta_ensure_source_observation,
    metta_engine_module(Engine),
    module_attribution_cost(Engine:maplist(a,b,c), P),
    module_attribution_cost(Engine:'plunit-not-a-host-goal'(a,b,c), M),
    format("present=~w missing=~w~n", [P, M]).
module_attribution_cost(Goal, Per) :-
    Rounds = 1000,
    statistics(inferences, Before),
    forall(between(1, Rounds, _),
           ( source_observation:goal_attribution(Goal, plunit_construct, _) -> true ; true )),
    statistics(inferences, After),
    Per is (After - Before - 3 * Rounds) // Rounds.
