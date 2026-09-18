% Purpose: the engine's tabled fixpoint of a tagged program and the formula
%   carrier's diagrams, checked against hand-computed values.
% Guarantees: a cyclic program converges under an idempotent combine, an
%   acyclic one is exact under every shipped carrier, the formula carrier's
%   model count is the exact probability, and a relation the program never
%   names answers nothing [tested: run_tests(algebra_fixpoint); commit=55368cb4eeb641d2325194eff9d0925048814b76].
% Owns resources: each test releases its space; the formula tables are
%   cleared after the suite.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(algebra_fixpoint).

cycle_space(Space) :-
    'new-space'(Space),
    'add-atom'(Space, [fact, 0.6, [edge, a, b]], _),
    'add-atom'(Space, [fact, 0.5, [edge, b, a]], _),
    'add-atom'(Space, [fact, 0.2, [edge, a, c]], _),
    'add-atom'(Space, [fact, 0.3, [edge, b, c]], _),
    'add-atom'(Space, [rule, 1, [path, X, Y], [premises, [edge, X, Y]]], _),
    'add-atom'(Space, [rule, 1, [path, X2, Z2],
                       [premises, [edge, X2, Y2], [path, Y2, Z2]]], _).

dag_space(Space) :-
    'new-space'(Space),
    'add-atom'(Space, [fact, 0.6, [edge, a, b]], _),
    'add-atom'(Space, [fact, 0.5, [edge, b, c]], _),
    'add-atom'(Space, [fact, 0.2, [edge, a, c]], _),
    'add-atom'(Space, [rule, 1, [path, X, Y], [premises, [edge, X, Y]]], _),
    'add-atom'(Space, [rule, 1, [path, X2, Z2],
                       [premises, [edge, X2, Y2], [path, Y2, Z2]]], _).

near(Expected, Actual) :- abs(Expected - Actual) < 1.0e-9.

test(a_cycle_converges_under_an_idempotent_combine,
     [ setup(cycle_space(Space)), cleanup(metta_release_space(Space)) ]) :-
    metta_algebra_fixpoint(Space, bool, [path, a, c], Bool),
    Bool = [[[path, a, c], B]],
    assertion(near(0.2, B)),
    metta_algebra_fixpoint(Space, tropical, [path, a, c], Tropical),
    Tropical = [[[path, a, c], T]],
    assertion(near(1.2, T)),
    metta_algebra_fixpoint(Space, set, [path, _, _], Every),
    length(Every, Reached),
    assertion(Reached == 6).

test(an_acyclic_program_is_exact_under_a_sum,
     [ setup(dag_space(Space)), cleanup(metta_release_space(Space)) ]) :-
    metta_algebra_fixpoint(Space, prob, [path, a, c], Prob),
    Prob = [[[path, a, c], P]],
    assertion(near(0.5, P)),
    metta_algebra_fixpoint(Space, counting, [path, a, c], Counting),
    assertion(Counting == [[[path, a, c], 2]]),
    metta_algebra_fixpoint(Space, prov, [path, a, c], Prov),
    assertion(Prov == [[[path, a, c],
                        [plus, [times, 1, 0.2],
                               [times, [times, 1, 0.6], [times, 1, 0.5]]]]]).

test(the_formula_carrier_reads_the_exact_probability_back,
     [ setup(cycle_space(Space)), cleanup(metta_release_space(Space)) ]) :-
    metta_algebra_fixpoint(Space, formula, [path, a, c], [[_, Formula]]),
    assertion(Formula = [formula, _]),
    metta_formula_model_count(Formula, prob, Exact),
    Expected is 1 - (1 - 0.2) * (1 - 0.6 * 0.3),
    assertion(near(Expected, Exact)),
    % The variables are the three edges on the paths that survive: a->c,
    % a->b, b->c; the cycle's b->a is absorbed by the direct edge.
    metta_formula_variables(Formula, Variables),
    findall(W, member([[src, Space, _], W], Variables), Weights),
    msort(Weights, Sorted),
    assertion(Sorted == [0.2, 0.3, 0.6]).

%A non-idempotent join over cyclic data re-adds a premise's earlier answer
%inside the strongly connected component, so the value grows without a
%fixpoint: the caller's budget stops it, as it stops any other unbounded
%program, or the carrier's own arithmetic overflows first, which the host
%reports as an evaluation error. Either is visible; neither is a plausible
%wrong number.
test(a_sum_over_a_cycle_has_no_fixpoint_and_the_budget_stops_it,
     [ setup(cycle_space(Space)), cleanup(metta_release_space(Space)) ]) :-
    catch(call_with_inference_limit(
              metta_algebra_fixpoint(Space, prob, [path, a, c], _), 200000, Result),
          error(evaluation_error(float_overflow), _),
          Result = float_overflow),
    assertion(memberchk(Result, [inference_limit_exceeded, float_overflow])).

test(a_relation_the_program_never_names_answers_nothing,
     [ setup(dag_space(Space)), cleanup(metta_release_space(Space)) ]) :-
    metta_algebra_fixpoint(Space, bool, [nothing, a], Answers),
    assertion(Answers == []).

test(a_carrier_without_a_negation_cannot_count_a_formula,
     [ setup(dag_space(Space)), cleanup(metta_release_space(Space)),
       throws(error(metta_algebra_negation_required(tropical), _)) ]) :-
    metta_algebra_fixpoint(Space, formula, [path, a, c], [[_, Formula]]),
    metta_formula_model_count(Formula, tropical, _).

%A rule whose tag is (function F) labels its instances with F over the
%premise tags: here the weaker of two premises, a NARS-shaped deduction,
%where the extend fold would have multiplied them.
test(a_rule_may_label_its_instances_by_a_function_of_its_premise_tags,
     [ setup(( 'new-space'(Space),
               'add-atom'(Space, ['=', ['plunit-weaker', A, B], [min, A, B]], _),
               'add-atom'(Space, [fact, 0.6, [p, a]], _),
               'add-atom'(Space, [fact, 0.3, [q, a]], _),
               'add-atom'(Space, [rule, [function, 'plunit-weaker'], [h, X],
                                  [premises, [p, X], [q, X]]], _) )),
       cleanup(metta_release_space(Space)) ]) :-
    space_module(Space, Module),
    with_metta_module(Module,
        metta_algebra_fixpoint(Space, prob, [h, a], Answers)),
    Answers = [[[h, a], Label]],
    assertion(near(0.3, Label)).

test(the_fixpoint_module_is_gone_after_the_call,
     [ setup(dag_space(Space)), cleanup(metta_release_space(Space)) ]) :-
    flag('$metta_algebra_fixpoint', Before, Before),
    metta_algebra_fixpoint(Space, bool, [path, a, c], _),
    atom_concat(metta_algebra_fixpoint_, Before, Module),
    assertion(\+ current_module(Module)).

:- end_tests(algebra_fixpoint).
