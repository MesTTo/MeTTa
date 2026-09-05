% Purpose: compare planned native conjunctions with the original bag join.
% Guarantees: the oracle executes each conjunct separately and retains every
% duplicate; the growth test distinguishes quadratic intermediate enumeration
% from variable-domain intersection [tested: native_generic_join; commit=WORKTREE].

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(native_generic_join).

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

:- end_tests(native_generic_join).
