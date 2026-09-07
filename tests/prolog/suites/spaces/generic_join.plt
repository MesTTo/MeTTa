% Purpose: compare planned native conjunctions with the original bag join.
% Guarantees: the oracle executes each conjunct separately and retains every
% duplicate; the growth test distinguishes quadratic intermediate enumeration
% from variable-domain intersection [tested: native_generic_join; commit=3c64e2e24787362a5a5081513bc24b880711a1d7].
% Assumes: planning is off unless a program asks for it, so the unit declares
% the plan-cyclic-joins pragma for its own scope and restores the previous
% value; a differential run without it would compare the nested loop with
% itself [tested: native_generic_join:planning_is_declared_rather_than_the_default;
% commit=3c64e2e24787362a5a5081513bc24b880711a1d7].

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(native_generic_join,
               [setup(enable_join_planning(Previous)),
                cleanup(set_metta_pragma('plan-cyclic-joins', Previous))]).

enable_join_planning(Previous) :-
    ( metta_pragma('plan-cyclic-joins', Previous) -> true ; Previous = none ),
    set_metta_pragma('plan-cyclic-joins', true).

with_join_atoms(Atoms, Goal) :-
    setup_call_cleanup(
        maplist(add_sexp('&plunit_generic_join'), Atoms),
        Goal,
        clear_native_atoms('&plunit_generic_join')).

reference_conjunction(_, []).
reference_conjunction(Space, [Pattern|Patterns]) :-
    match(Space, Pattern, hit, hit),
    reference_conjunction(Space, Patterns).

answer_bag(Goal, Template, Bag) :-
    catch(( findall(Template, Goal, Answers),
            maplist(canonical_answer, Answers, Canonical),
            msort(Canonical, Bag) ),
          error(Formal, _), Bag = error(Formal)).

canonical_answer(Answer, Canonical) :-
    copy_term_nat(Answer, Canonical),
    numbervars(Canonical, 0, _).

same_bag(Patterns, Template) :-
    answer_bag(( reference_conjunction('&plunit_generic_join', Patterns),
                 acyclic_term(Template) ), Template, Expected),
    answer_bag(match('&plunit_generic_join', [','|Patterns], Template, _),
               Template, Actual),
    assertion(Actual == Expected).

triangle_differential :-
    forall(permutation([[edge,X,Y],[edge,Y,Z],[edge,Z,X]], Patterns),
           same_bag(Patterns, [X,Y,Z])),
    same_bag([[edge,X,Y],[edge,Y,Z],[edge,Z,X]], hit),
    same_bag([[edge,a,Y],[edge,Y,Z],[edge,Z,a]], [Y,Z]),
    same_bag([[edge,X,X],[edge,X,Y],[edge,Y,X]], [X,Y]),
    same_bag([[edge,X,Y],[edge,Y,Z],[edge,Z,X],[edge,X,Y]], [X,Y,Z]),
    same_bag([[edge,X,Y],[edge,Y,Z],[absent,Z,X]], [X,Y,Z]).

test(ground_and_duplicate_bags_match_the_nested_reference) :-
    with_join_atoms([[edge,a,b],[edge,a,b],[edge,b,c],[edge,c,a],
                     [edge,a,a],[edge,c,c]], triangle_differential).

test(a_four_relation_cycle_retains_duplicate_bags) :-
    with_join_atoms([[r,a,b],[r,a,b],[r,a,other],[s,b,c],
                     [t,c,d],[u,d,a],[u,d,other]],
        same_bag([[r,X,Y],[s,Y,Z],[t,Z,W],[u,W,X]], [X,Y,Z,W])).

test(ternary_relations_intersect_every_shared_column) :-
    with_join_atoms([[r,a,b,c],[r,a,b,c],[s,b,c,d],[s,b,other,d],
                     [t,c,d,a],[t,c,d,other],[u,d,a,b]],
        same_bag([[r,X,Y,Z],[s,Y,Z,W],[t,Z,W,X],[u,W,X,Y]], [X,Y,Z,W])).

test(disconnected_cycles_retain_the_product_of_their_bags) :-
    with_join_atoms([[r,a,b],[r,a,b],[s,b,c],[t,c,a],
                     [u,d,e],[v,e,f],[w,f,d],[w,f,d]],
        same_bag([[r,X,Y],[u,A,B],[s,Y,Z],[v,B,C],[t,Z,X],[w,C,A]],
                 [X,Y,Z,A,B,C])).

test(repeated_ground_factors_retain_each_occurrence) :-
    with_join_atoms([[r,a,b],[s,b,c],[t,c,a],[guard],[guard]],
        same_bag([[r,X,Y],[s,Y,Z],[t,Z,X],[guard],[guard]], hit)).

test(a_projection_retains_each_duplicate_derivation) :-
    with_join_atoms([[edge,a,b],[edge,a,b],[edge,b,c],[edge,c,a]],
        ( answer_bag(match('&plunit_generic_join',
                           [',',[edge,X,Y],[edge,Y,Z],[edge,Z,X]], hit, _),
                     hit, Bag),
          assertion(Bag == [hit,hit,hit,hit,hit,hit]) )).

test(compound_and_numeric_keys_retain_unification_identity) :-
    with_join_atoms([[edge,[node,a],1],[edge,1,1.0],[edge,1.0,[node,a]],
                     [edge,"a",1],[edge,1,"a"],[edge,"a","a"],
                     [edge,0.0,-0.0],[edge,-0.0,1.5NaN],
                     [edge,1.5NaN,0.0],[edge,1.5NaN,1.5NaN],
                     [edge,[],[]]], triangle_differential).

test(attributed_query_variables_keep_the_reference_constraints) :-
    with_join_atoms([[edge,a,b],[edge,b,c],[edge,c,a],[edge,a,b]],
        ( dif(X, a),
          same_bag([[edge,X,Y],[edge,Y,Z],[edge,Z,X]], [X,Y,Z]) )).

test(nonground_rows_keep_the_reference_bag) :-
    with_join_atoms([[edge,_,b],[edge,b,c],[edge,c,a],[edge,a,b]],
                    triangle_differential).

test(nested_pattern_variables_keep_the_reference_bag) :-
    with_join_atoms([[edge,[node,a],[node,b]],
                     [edge,[node,b],[node,c]],
                     [edge,[node,c],[node,a]]],
        same_bag([[edge,[node,X],Y],[edge,Y,Z],[edge,Z,[node,X]]], [X,Y,Z])).

test(an_open_conjunct_keeps_the_existing_instantiation_error,
     [throws(error(instantiation_error, _))]) :-
    with_join_atoms([[edge,a,b]],
        match('&plunit_generic_join',
              [',',[edge,X|_Tail],[edge,Y,Z],[edge,Z,X]], [X,Y,Z], _)).

test(a_cyclic_binding_is_rejected_only_if_the_output_carries_it) :-
    with_join_atoms([[edge,[f,A],A],[edge,b,b]],
        ( same_bag([[edge,X,X],[edge,X,X],[edge,X,X]], hit),
          same_bag([[edge,X,X],[edge,X,X],[edge,X,X]], X) )).

test(edits_are_visible_to_the_next_conjunction) :-
    with_join_atoms([[edge,a,b],[edge,b,c],[edge,c,a]],
        ( triangle_differential,
          add_sexp('&plunit_generic_join', [edge,a,b]),
          triangle_differential,
          remove_sexp('&plunit_generic_join', [edge,b,c]),
          triangle_differential,
          clear_native_atoms('&plunit_generic_join'),
          triangle_differential )).

test(generated_ground_bags_match_the_reference) :-
    set_random(seed(892025)),
    forall(between(1, 80, _),
        ( findall([edge,A,B],
                  ( between(1, 9, _), random_between(0, 3, A),
                    random_between(0, 3, B) ), Atoms),
          with_join_atoms(Atoms, triangle_differential) )).

hub_join_cost(N, Cost) :-
    findall([edge,A,B],
            ( between(1, N, I), member(H, [-1,-2]),
              member(A-B, [I-H,H-I]) ), Atoms),
    with_join_atoms(Atoms,
        ( statistics(inferences, Before),
          findall([X,Y,Z],
                  match('&plunit_generic_join',
                        [',',[edge,X,Y],[edge,Y,Z],[edge,Z,X]], [X,Y,Z], _),
                  Answers),
          statistics(inferences, After),
          Cost is After - Before,
          assertion(Answers == []) )).

test(the_empty_two_hub_triangle_avoids_quadratic_growth) :-
    hub_join_cost(64, _),
    hub_join_cost(128, Small),
    hub_join_cost(256, Medium),
    hub_join_cost(512, Large),
    assertion(Medium < 2.8 * Small),
    assertion(Large < 2.8 * Medium).

prefix_join_cost(N, Cost) :-
    findall([edge,I,J], (between(1, N, I), J is I+1), Chain),
    append([[edge,a,b],[edge,b,c],[edge,c,a]], Chain, Atoms),
    with_join_atoms(Atoms,
        ( Goal = spaces:match_bounded(1, '&plunit_generic_join',
                                      [',',[edge,X,Y],[edge,Y,Z],[edge,Z,X]],
                                      [triple,X,Y,Z], Answer),
          findall(Answer, Goal, _),
          statistics(inferences, Before),
          findall(Answer, Goal, Answers),
          statistics(inferences, After),
          Cost is After - Before,
          assertion(Answers == [[triple,a,b,c]]) )).

test(a_bounded_triangle_retains_streaming_first_answer_cost) :-
    prefix_join_cost(16, _),
    prefix_join_cost(64, Small),
    prefix_join_cost(256, Medium),
    prefix_join_cost(1024, Large),
    assertion(Medium =< Small + 4),
    assertion(Large =< Small + 4).

empty_factor_cost(N, Cost) :-
    findall([edge,A,B], (between(1, N, A), between(1, N, B)), Atoms),
    with_join_atoms(Atoms,
        ( Patterns = [[edge,X,Y],[edge,Y,Z],[edge,Z,X],[absent]],
          statistics(inferences, Before),
          findall([X,Y,Z],
                  match('&plunit_generic_join', [','|Patterns], [X,Y,Z], _),
                  Answers),
          statistics(inferences, After),
          Cost is After - Before,
          assertion(Answers == []),
          same_bag(Patterns, [X,Y,Z]) )).

test(an_empty_factor_prevents_dense_triangle_enumeration) :-
    empty_factor_cost(8, _),
    empty_factor_cost(16, Small),
    empty_factor_cost(32, Medium),
    empty_factor_cost(64, Large),
    assertion(Medium =< Small + 4),
    assertion(Large =< Small + 4).

% The pragma is the whole gate: without it a cyclic conjunction keeps the
% nested loop, which is what every unskewed instance measures faster.
test(planning_is_declared_rather_than_the_default) :-
    assertion(spaces:cyclic_join_planning_enabled),
    setup_call_cleanup(
        set_metta_pragma('plan-cyclic-joins', none),
        ( assertion(\+ spaces:cyclic_join_planning_enabled),
          with_join_atoms([[edge,a,b],[edge,b,c],[edge,c,a],[edge,a,b]],
              same_bag([[edge,X,Y],[edge,Y,Z],[edge,Z,X]], [X,Y,Z])) ),
        set_metta_pragma('plan-cyclic-joins', true)).

% The self-honesty law. What (explain (match ...)) says about the plan has to
% be what the matcher then does, and the only way to know what it did is to
% COUNT the planned answer predicate's calls: a flag the engine sets would be
% the engine agreeing with itself. wrap_predicate/4 counts them from outside.
%
% Stated exactly: a planned mode -- generic-join or empty-factor -- appears
% exactly when native_conjunction_answer/1 runs, and nested-loop exactly when
% it does not. An empty factor IS a plan; it answers the empty bag through the
% same predicate, from a single zero-count leaf.
:- dynamic plunit_join_answer_count/1.

planned_join_runs(Space, Pattern, Ran) :-
    retractall(plunit_join_answer_count(_)),
    assertz(plunit_join_answer_count(0)),
    setup_call_cleanup(
        wrap_predicate(spaces:native_conjunction_answer(_),
                       plunit_join_counter, Wrapped,
                       ( retract(plunit_join_answer_count(N0)),
                         N1 is N0 + 1,
                         assertz(plunit_join_answer_count(N1)),
                         Wrapped )),
        forall(match(Space, Pattern, hit, _), true),
        unwrap_predicate(spaces:native_conjunction_answer/1,
                         plunit_join_counter)),
    plunit_join_answer_count(Count),
    ( Count > 0 -> Ran = true ; Ran = false ).

explained_plan_mode(Space, Pattern, Mode) :-
    metta_explain([match, Space, Pattern, hit], Items),
    memberchk([plan, Mode|_], Items).

plan_agrees_with_the_route(Pattern) :-
    explained_plan_mode('&plunit_generic_join', Pattern, Mode),
    planned_join_runs('&plunit_generic_join', Pattern, Ran),
    ( memberchk(Mode, ['generic-join', 'empty-factor']) -> Planned = true
    ; Mode == 'nested-loop' -> Planned = false
    ; Planned = unknown(Mode) ),
    assertion(Planned == Ran).

test(the_plan_says_generic_join_exactly_when_the_planned_join_runs) :-
    Triangle = [',', [edge,_X,_Y], [edge,_Y,_Z], [edge,_Z,_X]],
    Chain = [',', [edge,_A,_B], [edge,_B,_C]],
    Missing = [',', [edge,_D,_E], [edge,_E,_F], [absent,_F,_D]],
    with_join_atoms([[edge,a,b],[edge,b,c],[edge,c,a]],
        ( assertion(explained_plan_mode('&plunit_generic_join', Triangle,
                                        'generic-join')),
          plan_agrees_with_the_route(Triangle),
          assertion(explained_plan_mode('&plunit_generic_join', Chain,
                                        'nested-loop')),
          plan_agrees_with_the_route(Chain),
          assertion(explained_plan_mode('&plunit_generic_join', Missing,
                                        'empty-factor')),
          plan_agrees_with_the_route(Missing),
          plan_agrees_with_the_route([edge,_G,_H]) )),
    % A stored row with a variable in it declines the trie plan at the ground
    % admission, which the shape alone cannot see; the item has to follow the
    % route rather than the query, and this is the case that says so.
    with_join_atoms([[edge,a,b],[edge,b,c],[edge,c,a],[edge,_P,_Q]],
        ( assertion(explained_plan_mode('&plunit_generic_join', Triangle,
                                        'nested-loop')),
          plan_agrees_with_the_route(Triangle) )),
    setup_call_cleanup(
        set_metta_pragma('plan-cyclic-joins', none),
        with_join_atoms([[edge,a,b],[edge,b,c],[edge,c,a]],
            ( assertion(explained_plan_mode('&plunit_generic_join', Triangle,
                                            'nested-loop')),
              plan_agrees_with_the_route(Triangle) )),
        set_metta_pragma('plan-cyclic-joins', true)).

% The order item for the retained loop is the matcher's own choice at its first
% level, not source order: cheapest_conjunct/6 hoists a conjunct that matches at
% most one row, and native_match_order/3 asks it the same question.
test(the_nested_loop_order_names_the_conjunct_the_matcher_leads_with) :-
    with_join_atoms([[edge,a,b],[edge,b,c],[edge,c,a],[only,z]],
        ( Pattern = [',', [edge,X,Y], [only,W]],
          spaces:native_match_order('&plunit_generic_join', Pattern, Order),
          assertion(Order = [[only,W], [edge,X,Y]]),
          explained_plan_mode('&plunit_generic_join', Pattern, Mode),
          assertion(Mode == 'nested-loop'),
          metta_explain([match, '&plunit_generic_join', Pattern, hit], Items),
          assertion(memberchk([plan, 'nested-loop',
                               [order, [only,W], [edge,X,Y]]], Items)) )).

% The relations item names each conjunct's columns in the order's own
% numbering, which is what rel(Columns, Trie) holds, and the order is the query
% variables in first occurrence. findall/3 copies the items out of the
% explanation, so the order's variables are fresh: what is checkable is that
% they are three distinct variables and that the columns index them.
test(the_relations_item_carries_each_conjunct_columns) :-
    with_join_atoms([[edge,a,b],[edge,b,c],[edge,c,a]],
        ( metta_explain([match, '&plunit_generic_join',
                         [',', [edge,_X,_Y], [edge,_Y,_Z], [edge,_Z,_X]], hit],
                        Items),
          memberchk([plan, 'generic-join', [order|Vars], [relations|Relations]],
                    Items),
          Vars = [V1,V2,V3],
          assertion(( var(V1), var(V2), var(V3),
                      V1 \== V2, V2 \== V3, V1 \== V3 )),
          assertion(Relations == [[edge,1,2],[edge,2,3],[edge,1,3]]) )),
    % A four-cycle, where the columns are not symmetric and a wrong numbering
    % could not pass by coincidence.
    with_join_atoms([[edge,a,b],[edge,b,c],[edge,c,d],[edge,d,a]],
        ( metta_explain([match, '&plunit_generic_join',
                         [',', [edge,_A,_B], [edge,_B,_C], [edge,_C,_D],
                          [edge,_D,_A]], hit],
                        Square),
          memberchk([plan, 'generic-join', [order|Corners],
                     [relations|Sides]], Square),
          assertion(length(Corners, 4)),
          assertion(Sides == [[edge,1,2],[edge,2,3],[edge,3,4],[edge,1,4]]) )).

% The empty-factor item names the conjunct that has no candidate, which is the
% one thing a reader needs to know about a query that answers nothing.
test(the_empty_factor_item_names_the_conjunct_with_no_candidate) :-
    with_join_atoms([[edge,a,b],[edge,b,c],[edge,c,a]],
        ( metta_explain([match, '&plunit_generic_join',
                         [',', [edge,_X,_Y], [edge,_Y,_Z], [absent,_Z,_X]], hit],
                        Items),
          memberchk([plan, 'empty-factor', Conjunct], Items),
          assertion(Conjunct = [absent,_,_]) )).

:- end_tests(native_generic_join).
