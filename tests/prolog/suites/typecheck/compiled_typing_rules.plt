/* Purpose: compare compiled shipped typing decisions with the registry
   interpreter, including directed matching, variable sharing and cuts.
   Guarantees: the comparison includes accepted and refused outcome queries
   and constrained rule names [tested: sh engine/test.sh
   suites/typecheck/compiled_typing_rules.plt; commit=32650f9ff4d1c4aa0749d8eb8b153e5bb448ee5c].
*/
:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(compiled_typing_rules).

%Keep the original interpreter as the independent oracle. Determine both
%patterns' openness before unification can bind a variable shared by them.
registry_decision(Family, Actual, Expected, Outcome, Name) :-
    type_rules:typing_rule_entry(shipped, '*', Name, Family, Left, Right, Candidate),
    type_rules:typing_pattern_openness(Left, LeftOpen),
    type_rules:typing_pattern_openness(Right, RightOpen),
    type_rules:typing_rule_pattern_matches(Actual, Left, LeftOpen),
    type_rules:typing_rule_pattern_matches(Expected, Right, RightOpen),
    Candidate \== defer,
    !,
    Outcome = Candidate.

query_type('%Undefined%').
query_type('Atom').
query_type('Number').
query_type('BigInt').
query_type('Symbol').
query_type('Variable').
query_type('Grounded').
query_type('Expression').
query_type('_').
query_type('Other').
query_type([->, 'Number', 'Number']).
query_type(['|', 'Number', 'String']).
query_type([pair, X, X]).
query_type(_).

query_pair(Actual, Expected) :- query_type(Actual), query_type(Expected).
query_pair(Same, Same).
query_pair([pair, X, X], [pair, X, _]).
query_pair([pair, X, Y], [pair, Y, X]).

agrees(Family, Actual, Expected, Outcome, Name) :-
    findall(Actual-Expected-Outcome-Name,
            registry_decision(Family, Actual, Expected, Outcome, Name), Reference),
    findall(Actual-Expected-Outcome-Name,
            type_rules:decisive_typing_rule(shipped, '*', Family, Actual,
                                            Expected, Outcome, Name), Compiled),
    assertion(Compiled =@= Reference).

test(every_family_preserves_answers_and_bindings) :-
    forall((type_rules:typing_rule_family(Family), query_pair(Actual, Expected)),
           agrees(Family, Actual, Expected, _, _)).

test(a_constrained_outcome_does_not_select_a_later_rule) :-
    forall((type_rules:typing_rule_family(Family), query_pair(Actual, Expected),
            member(Outcome, [accept, defer, [refuse, reason]])),
           agrees(Family, Actual, Expected, Outcome, _)).

test(a_rule_name_filters_before_the_decision) :-
    forall((type_rules:typing_rule_entry(shipped, '*', Name, Family, _, _, _),
            query_pair(Actual, Expected)),
           agrees(Family, Actual, Expected, _, Name)),
    agrees(ordinary, 'Number', 'Number', _, missing_rule).

test(a_relational_family_retains_its_first_decision) :-
    forall(query_pair(Actual, Expected), agrees(_, Actual, Expected, _, _)).

test(a_closed_pattern_does_not_instantiate_an_unknown_input) :-
    findall(Actual-Expected,
            type_rules:decisive_typing_rule(shipped, '*', widening,
                                            Actual, Expected, _, _), Answers),
    assertion(Answers == []).

test(an_exact_pattern_can_share_a_free_variable_between_inputs) :-
    findall(Actual-Expected,
            type_rules:decisive_typing_rule(shipped, '*', 'arrow-arity',
                                            Actual, Expected, _, _), Answers),
    assertion(Answers =@= [Same-Same]).

:- end_tests(compiled_typing_rules).
