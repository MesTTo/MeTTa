% Purpose: verify checked parameter contracts across native variable bindings.
% Guarantees: aliases retain the direct call's inference cost while declaration
%   edits, policy changes and independent branches keep their runtime checks
%   [tested: run_tests(translator_parameter_aliases); commit=59a1783102aa6d8d6a9b7766761b094c891fc417].
% Owns resources: each test releases its native space through plunit cleanup.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(translator_parameter_aliases).

run_in(Space, Text, Answers) :-
    setup_call_cleanup(asserta(filereader:silent(true), Ref),
                       process_metta_string(Text, Answers, Space), erase(Ref)).

setup_aliases(Space) :-
    'new-space'(Space),
    run_in(Space, "
        (: Parcel (-> Number Parcel))
        (: accept-parcel (-> Parcel Number))
        (= (accept-parcel (Parcel $n)) $n)
        (: direct-parcel (-> Parcel Number))
        (= (direct-parcel $x) (accept-parcel $x))
        (: let-parcel (-> Parcel Number))
        (= (let-parcel $x) (let $a $x (accept-parcel $a)))
        (: chain-parcel (-> Parcel Number))
        (= (chain-parcel $x) (chain $x $a (chain $a $b (accept-parcel $b))))
        (: reverse-parcel (-> Parcel Atom Number))
        (= (reverse-parcel $x $y) (let $x $y (accept-parcel $y)))
        (: branch-parcel (-> Bool Parcel Atom Number))
        (= (branch-parcel $choose $x $y)
           (if $choose (let $y $x (accept-parcel $y)) (accept-parcel $y)))
        (: different-parcel (-> Parcel Number))
        (= (different-parcel $x) (let $y ""bad"" (accept-parcel $y)))", []).

evaluate_in(Space, Term, Answers) :-
    space_module(Space, Module),
    with_metta_module(Module, findall(Value, eval(Term, Value), Answers)).

call_cost(Module, Name, Count, Cost) :-
    Goal =.. [Name, ['Parcel', 3], Value],
    statistics(inferences, Before),
    forall(between(1, Count, _), (call(Module:Goal), Value = 3)),
    statistics(inferences, After),
    Cost is After - Before.

test(let_and_chain_aliases_cost_the_same_as_the_checked_parameter,
     [setup(setup_aliases(S)), cleanup(metta_release_space(S))]) :-
    space_module(S, Module),
    forall(member(Name, ['direct-parcel', 'let-parcel', 'chain-parcel']),
           evaluate_in(S, [Name, ['Parcel', 3]], [3])),
    with_metta_module(Module,
        forall(member(Count, [100, 1000, 10000]),
            ( plunit_translator_parameter_aliases:call_cost(Module, 'direct-parcel', Count, Direct),
              forall(member(Name, ['let-parcel', 'chain-parcel']),
                  ( plunit_translator_parameter_aliases:call_cost(Module, Name, Count, Aliased),
                    format('~w ~w direct=~w alias=~w~n', [Name, Count, Direct, Aliased]),
                    assertion(Aliased =:= Direct) ))))).

test(bindings_keep_answers_and_wrong_argument_errors,
     [setup(setup_aliases(S)), cleanup(metta_release_space(S))]) :-
    forall(member(Name, ['let-parcel', 'chain-parcel']),
        ( evaluate_in(S, [Name, ['superpose', [['Parcel', 3], ['Parcel', 4]]]], Answers),
          assertion(Answers == [3, 4]),
          evaluate_in(S, [Name, "bad"], Bad),
          assertion(Bad == [['Error', [Name, "bad"],
                            ['BadArgType', 1, 'Parcel', 'String']]]) )),
    evaluate_in(S, ['reverse-parcel', ['Parcel', 3], ['Parcel', 3]], [3]).

test(a_binding_does_not_prove_another_value_or_another_branch,
     [setup(setup_aliases(S)), cleanup(metta_release_space(S))]) :-
    Refusal = [['Error', ['accept-parcel', "bad"],
                ['BadArgType', 1, 'Parcel', 'String']]],
    evaluate_in(S, ['different-parcel', ['Parcel', 3]], Different),
    assertion(Different == Refusal),
    evaluate_in(S, ['branch-parcel', false, ['Parcel', 3], "bad"], OtherBranch),
    assertion(OtherBranch == Refusal).

test(removing_the_enclosing_contract_retires_the_alias_proof,
     [setup(setup_aliases(S)), cleanup(metta_release_space(S))]) :-
    evaluate_in(S, ['chain-parcel', ['Parcel', 3]], [3]),
    metta_remove_atom(S, [':', 'chain-parcel', [->, 'Parcel', 'Number']], true),
    evaluate_in(S, ['chain-parcel', "bad"], Answers),
    assertion(Answers == [['Error', ['accept-parcel', "bad"],
                          ['BadArgType', 1, 'Parcel', 'String']]]).

test(changing_the_callee_contract_retains_its_new_refusal,
     [setup(setup_aliases(S)), cleanup(metta_release_space(S))]) :-
    evaluate_in(S, ['chain-parcel', ['Parcel', 3]], [3]),
    metta_remove_atom(S, [':', 'accept-parcel', [->, 'Parcel', 'Number']], true),
    run_in(S, "(: accept-parcel (-> String Number))", []),
    evaluate_in(S, ['chain-parcel', ['Parcel', 3]], Answers),
    assertion(Answers == [['Error', ['accept-parcel', ['Parcel', 3]],
                          ['BadArgType', 1, 'String', 'Parcel']]]).

test(changing_the_typing_policy_retires_alias_shortcuts,
     [setup(setup_aliases(S)), cleanup(metta_release_space(S))]) :-
    evaluate_in(S, ['chain-parcel', ['Parcel', 3]], [3]),
    run_in(S, "!(add-typing-rule! deny-parcel ordinary Parcel Parcel (refuse denied))", [true]),
    evaluate_in(S, ['chain-parcel', ['Parcel', 3]], Changed),
    evaluate_in(S, ['direct-parcel', ['Parcel', 3]], Direct),
    assertion(Changed = [['Error', _, _]]),
    assertion(Direct = [['Error', _, _]]),
    run_in(S, "!(remove-typing-rule! deny-parcel)", [true]),
    evaluate_in(S, ['chain-parcel', ['Parcel', 3]], [3]).

:- end_tests(translator_parameter_aliases).
