/* Purpose: compare compiled shipped typing decisions with the registry
   interpreter, including directed matching, variable sharing and cuts.
   Guarantees: the comparison includes accepted and refused outcome queries
   and constrained rule names [tested: sh engine/test.sh
   suites/typecheck/compiled_typing_rules.plt; commit=e246959279271d22f166a1c8fb1840896295a020].
   Expected-family classification agrees with the original interpreter for
   shipped and user tiers, including aliases, free values and rule order
   [tested: sh engine/test.sh suites/typecheck/compiled_typing_rules.plt;
   commit=e246959279271d22f166a1c8fb1840896295a020].
   Runtime get_type_rule/2 callbacks retain their order and source error
   frames, including a throwing tuple retry [tested: compiled_typing_rules;
   commit=e246959279271d22f166a1c8fb1840896295a020].
   Owns resources: cases release their spaces and oracle wrapper.
*/
:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(prolog_wrap)).
:- use_module('../../source_observation_helper.pl').

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

registry_expected(Module, Family, Expected) :-
    (   type_rules:typing_rule_entry(user, Module, _, Family, _, RawPattern, _),
        normalize_callable_type_in(Module, RawPattern, Pattern)
    ;   type_rules:typing_rule_entry(shipped, '*', _, Family, _, Pattern, _)
    ),
    type_rules:typing_pattern_openness(Pattern, Openness),
    type_rules:typing_rule_pattern_matches(Expected, Pattern, Openness),
    !.

expected_agrees(Module, Family, Expected) :-
    findall(Module-Family-Expected, registry_expected(Module, Family, Expected),
            Reference),
    findall(Module-Family-Expected,
            type_rules:typing_rule_expected_resolved(Module, Family, Expected),
            Compiled),
    assertion(Compiled =@= Reference).

test(expected_families_preserve_answers_and_bindings) :-
    metta_self_module(Module),
    forall((type_rules:typing_rule_family(Family), query_type(Expected)),
           expected_agrees(Module, Family, Expected)),
    forall(query_type(Expected), expected_agrees(Module, _, Expected)),
    expected_agrees(Module, missing_family, _),
    expected_agrees(Module, FamilyAndExpected, FamilyAndExpected).

test(expected_user_patterns_keep_normalization_and_first_match,
     [setup(('new-space'(Space), space_module(Space, Module))),
      cleanup(metta_release_space(Space))]) :-
    metta_add_atom(Space, [':', 'ExpectedAlias', ['Alias', 'TagA']], _),
    with_metta_module(Module,
        ( 'add-typing-rule!'('expected-alias', metatype, _, 'ExpectedAlias',
                             [refuse, named_reason], _),
          'add-typing-rule!'('expected-shared', metatype, _, [pair, X, X],
                             defer, _),
          'add-typing-rule!'('expected-open', widening, _, _, accept, _) )),
    forall((type_rules:typing_rule_family(Family), query_type(Expected)),
           expected_agrees(Module, Family, Expected)),
    forall(query_type(Expected), expected_agrees(Module, _, Expected)),
    expected_agrees(Module, metatype, [pair, Shared, Shared]),
    expected_agrees(Module, metatype, [pair, _, _]),
    assertion(type_rules:typing_rule_expected_resolved(Module, metatype, 'TagA')),
    assertion(\+ type_rules:typing_rule_expected_resolved(Module, metatype, 'TagB')),
    assertion(type_rules:typing_rule_expected_resolved(Module, widening, _)),
    metta_remove_atom(Space, [':', 'ExpectedAlias', ['Alias', 'TagA']], _),
    metta_add_atom(Space, [':', 'ExpectedAlias', ['Alias', 'TagB']], _),
    expected_agrees(Module, metatype, 'TagA'),
    expected_agrees(Module, metatype, 'TagB'),
    assertion(\+ type_rules:typing_rule_expected_resolved(Module, metatype, 'TagA')),
    assertion(type_rules:typing_rule_expected_resolved(Module, metatype, 'TagB')).

callback_source(accepted,
"(= (get-type observed) (progn (println! callback-first) Number))
(: take (-> Number Atom))
(= (take $x) (accepted $x))
!(take observed)
!(get-type (unknown observed))
!(println! finished)").
callback_source(refused,
"(= (get-type observed) (progn (println! callback-first) String))
(: take (-> Number Atom))
(= (take $x) (accepted $x))
!(take observed)
!(take \"literal\")
!(println! finished)").
callback_source(throwing,
"(= (get-type observed) (progn (println! callback-first) Number))
(= (get-type observed) (progn (println! callback-second) (assertEqual 0 1)))
!(get-type (unknown observed))
!(println! unreachable)").

test(runtime_callbacks_and_source_error_frames_agree,
     [forall(callback_source(Kind, Source))]) :-
    setup_call_cleanup(
        wrap_predicate(type_rules:typing_rule_expected_resolved(Module, Family, Type),
                       typing_expected_oracle, _,
                       registry_expected(Module, Family, Type)),
        source_run_observation("typing.metta", Source, Expected, ExpectedOutput),
        unwrap_predicate(type_rules:typing_rule_expected_resolved/3,
                         typing_expected_oracle)),
    source_run_observation("typing.metta", Source, Actual, ActualOutput),
    assertion(Actual =@= Expected),
    assertion(ActualOutput == ExpectedOutput),
    assertion(sub_string(ActualOutput, _, _, _, "callback-first")),
    callback_outcome(Kind, Actual, ActualOutput).

callback_outcome(accepted, Rows, Output) :-
    assertion(memberchk(['observation-answer', 0, [accepted, observed]], Rows)),
    assertion(sub_string(Output, _, _, _, "finished")).
callback_outcome(refused, Rows, Output) :-
    assertion(\+ member(['observation-answer', 0, _], Rows)),
    assertion(memberchk(['observation-answer', 1,
                         ['Error', [take, "literal"],
                          ['BadArgType', 1, 'Number', 'String']]], Rows)),
    assertion(sub_string(Output, _, _, _, "finished")).
callback_outcome(throwing, Rows, Output) :-
    assertion(memberchk(['observation-status', exception], Rows)),
    assertion(member(['source-frame', _, _, get_type_rule, "typing.metta",
                      2, _, 2, _, exact], Rows)),
    assertion(sub_string(Output, _, _, _, "callback-second")),
    assertion(\+ sub_string(Output, _, _, _, "unreachable")).

:- end_tests(compiled_typing_rules).
