% Purpose: prove lib_strategy's reified plans cross the Prolog engine's normal
%   library, storage, translator, traversal, and typed-scheme seams.
% Assumes: run from tests/prolog so ../../engine/metta.pl and the repository's
%   lib/ directory resolve from this worktree.
% Guarantees:
%   - strategy-apply is admitted as a translator rule while a stored plan stays
%     queryable data [tested: lib_strategy:stored_plans_lower_through_the_translator;
%     commit=505ce25b9384e782afa26f621527d4b1fd695924]
%   - left-biased choice, strict traversal, and TP/TU filtering retain their
%     observable laws at the engine door [tested:
%     lib_strategy:choice_uses_the_complete_left_result_bag,
%     lib_strategy:traversals_keep_their_strict_order,
%     lib_strategy:typed_schemes_filter_by_the_declared_arrow; commit=505ce25b9384e782afa26f621527d4b1fd695924]
%   - a named space's own choice definition hides lib_strategy's inherited
%     arrow for dispatch while get-type keeps reporting the arrow [tested:
%     lib_strategy:an_inherited_arrow_does_not_veto_a_local_definition,
%     lib_strategy:settled_nested_arguments_use_the_governing_outer_arrow,
%     lib_strategy:removing_a_local_shadow_recompiles_its_callers;
%     commit=505ce25b9384e782afa26f621527d4b1fd695924]

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

strategy_eval_string(Text, Results) :-
    sread(Text, Term),
    findall(Result, eval(Term, Result), Results).

strategy_add_form(Text) :-
    sread(Text, Form),
    'add-atom'('&self', Form, _).

strategy_space_answers(Space, Term, Answers) :-
    space_module(Space, Module),
    findall(Answer, with_metta_module(Module, eval(Term, Answer)), Answers).

clear_strategy_shadow_spaces :-
    maplist(clear_native_atoms,
            ['&plunit-strategy-inherited',
             '&plunit-strategy-local',
             '&plunit-strategy-declared',
             '&plunit-strategy-scalar',
             '&plunit-strategy-nested',
             '&plunit-strategy-removal']).

load_strategy_fixture :-
    strategy_eval_string("(import! &self (library lib_strategy))", _),
    maplist(strategy_add_form,
            [ "(= (plunit-strategy-step plunit-a) plunit-b)",
              "(= (plunit-strategy-step plunit-b) plunit-c)",
              "(= (plunit-strategy-step $x) (empty))",
              "(= (plunit-strategy-many plunit-a) plunit-left-1)",
              "(= (plunit-strategy-many plunit-a) plunit-left-2)",
              "(= (plunit-strategy-right plunit-a) plunit-wrong)",
              "(= (plunit-strategy-cap plunit-a) plunit-A)",
              "(= (plunit-strategy-cap $x) (empty))",
              "(: plunit-strategy-type Type)",
              "(: plunit-strategy-other Type)",
              "(: plunit-typed-a plunit-strategy-type)",
              "(: plunit-typed-b plunit-strategy-other)",
              "(: plunit-strategy-preserve (-> plunit-strategy-type plunit-strategy-type))",
              "(= (plunit-strategy-preserve $x) (plunit-marked $x))",
              "(: plunit-shadow-outer (-> Number Result))",
              "(: plunit-shadow-inner (-> Number Number))",
              "(= (plunit-shadow-inner $x) $x)",
              "(plunit-strategy-policy fast (seq plunit-strategy-step plunit-strategy-step))"
            ]).

:- initialization(load_strategy_fixture).

:- begin_tests(lib_strategy).

test(an_inherited_arrow_does_not_veto_a_local_definition,
     [cleanup(clear_strategy_shadow_spaces)]) :-
    'add-atom'('&plunit-strategy-inherited', [shadow_probe], _),
    strategy_space_answers('&plunit-strategy-inherited',
                           ['get-type', choice], InheritedTypes),
    assertion(InheritedTypes == [[->, 'Atom', [':seg', 'Atom'],
                                  '%Undefined%']]),
    strategy_space_answers('&plunit-strategy-inherited', [choice], Inherited),
    assertion(Inherited == [['Error', [choice],
                             'IncorrectNumberOfArguments']]),

    'add-atom'('&plunit-strategy-local', [=, [choice], base], _),
    strategy_space_answers('&plunit-strategy-local', ['get-type', choice],
                           LocalTypes),
    assertion(LocalTypes == InheritedTypes),
    strategy_space_answers('&plunit-strategy-local', [choice], Local),
    assertion(Local == [base]),

    'add-atom'('&plunit-strategy-declared',
               [':', choice, [->, 'Result']], _),
    'add-atom'('&plunit-strategy-declared', [=, [choice], local], _),
    strategy_space_answers('&plunit-strategy-declared', [choice], Declared),
    assertion(Declared == [local]),

    'add-atom'('&plunit-strategy-scalar', [':', choice, 'Result'], _),
    space_module('&plunit-strategy-scalar', ScalarModule),
    findall(Type,
            with_metta_module(
                ScalarModule,
                governing_type_declaration(choice, Type)),
            ScalarTypes),
    assertion(ScalarTypes == ['Result']),
    assertion(\+ with_metta_module(
                     ScalarModule,
                     governing_type_declaration(choice, [->|_]))).

test(settled_nested_arguments_use_the_governing_outer_arrow,
     [cleanup(clear_strategy_shadow_spaces)]) :-
    'add-atom'('&plunit-strategy-nested',
               [':', 'plunit-shadow-outer', [->, 'String', 'Result']], _),
    strategy_space_answers('&plunit-strategy-nested',
                           ['plunit-shadow-outer', 1], Literal),
    strategy_space_answers('&plunit-strategy-nested',
                           ['plunit-shadow-outer',
                            ['plunit-shadow-inner', 1]], Nested),
    LiteralExpected = [['Error', ['plunit-shadow-outer', 1],
                        ['BadArgType', 1, 'String', 'Number']]],
    NestedExpected = [['Error',
                       ['plunit-shadow-outer',
                        ['plunit-shadow-inner', 1]],
                       ['BadArgType', 1, 'String', 'Number']]],
    assertion(Literal == LiteralExpected),
    assertion(Nested == NestedExpected).

test(removing_a_local_shadow_recompiles_its_callers,
     [cleanup(clear_strategy_shadow_spaces)]) :-
    Choice = [=, [choice], base],
    'add-atom'('&plunit-strategy-removal', Choice, _),
    'add-atom'('&plunit-strategy-removal',
               [=, ['plunit-run-choice'], [choice]], _),
    strategy_space_answers('&plunit-strategy-removal',
                           ['plunit-run-choice'], Before),
    assertion(Before == [base]),
    metta_remove_atom('&plunit-strategy-removal', Choice, Removed),
    assertion(Removed == true),
    Expected = [['Error', [choice], 'IncorrectNumberOfArguments']],
    strategy_space_answers('&plunit-strategy-removal', [choice], Direct),
    strategy_space_answers('&plunit-strategy-removal',
                           ['plunit-run-choice'], After),
    assertion(Direct == Expected),
    assertion(After == Expected).

test(stored_plans_lower_through_the_translator) :-
    assertion(translator_rule('strategy-apply')),
    strategy_eval_string(
        "(match &self (plunit-strategy-policy fast $strategy) $strategy)",
        Stored),
    assertion(Stored == [[seq, 'plunit-strategy-step',
                          'plunit-strategy-step']]),
    strategy_eval_string(
        "(match &self (plunit-strategy-policy fast $strategy) (strategy-apply $strategy plunit-a))",
        Applied),
    assertion(Applied == ['plunit-c']).

test(choice_uses_the_complete_left_result_bag) :-
    strategy_eval_string(
        "(choice plunit-strategy-many plunit-strategy-right plunit-a)",
        Results),
    assertion(Results == ['plunit-left-1', 'plunit-left-2']).

test(traversals_keep_their_strict_order) :-
    strategy_eval_string(
        "(topdown (try plunit-strategy-cap) (plunit-h plunit-a))",
        Forgiving),
    assertion(Forgiving == [['plunit-h', 'plunit-A']]),
    strategy_eval_string(
        "(topdown plunit-strategy-cap (plunit-h plunit-a))",
        Strict),
    assertion(Strict == []).

test(typed_schemes_filter_by_the_declared_arrow) :-
    strategy_eval_string(
        "(◁ plunit-strategy-preserve TP plunit-typed-a)", Good),
    assertion(Good == [['plunit-marked', 'plunit-typed-a']]),
    strategy_eval_string(
        "(◁ plunit-strategy-preserve TP plunit-typed-b)", WrongType),
    assertion(WrongType == []).

test(zero_one_and_many_steps_are_ordinary_variadic_plans) :-
    forall(between(0,24,Count),
           ( length(Steps,Count), maplist(=(id),Steps),
             Plan=[seq|Steps],
             findall(Value,eval(['strategy-apply',Plan,literal],Value),[literal]),
             append([seq|Steps],[literal],Direct),
             findall(Value,eval(Direct,Value),[literal]) )),
    strategy_eval_string("(collapse (strategy-apply (choice) literal))",[[]]),
    strategy_eval_string("(collapse (choice literal))",[[]]),
    strategy_eval_string(
        "(choice fail fail plunit-strategy-many plunit-strategy-right plunit-a)",
        ['plunit-left-1','plunit-left-2']).

test(callable_values_keep_eager_and_held_operands_literal) :-
    strategy_add_form("(= (plunit-strategy-literal $x) (noeval (marked $x)))"),
    strategy_add_form("(: plunit-strategy-held (-> Atom %Undefined%))"),
    strategy_add_form("(= (plunit-strategy-held $x) (noeval (marked $x)))"),
    strategy_add_form("(= (plunit-strategy-prefix $p $x) (noeval ($p $x)))"),
    forall(member(Strategy,["plunit-strategy-literal","plunit-strategy-held",
                            "(|-> ($x) (noeval (marked $x)))",
                            "(plunit-strategy-prefix marked)"]),
           ( format(string(Call),"(strategy-apply ~s (+ 1 2))",[Strategy]),
             strategy_eval_string(Call,Answers),
             assertion(Answers==[[marked,['+',1,2]]]) )),
    strategy_eval_string(
        "(all plunit-strategy-literal ((+ 1 2) (Error data code)))",All),
    assertion(All==[[[marked,['+',1,2]],[marked,['Error',data,code]]]]).

test(topmost_rewrites_stop_at_success_and_keep_the_complete_bag) :-
    strategy_add_form("(= (plunit-strategy-top (h a)) root)"),
    strategy_add_form("(= (plunit-strategy-top a) changed)"),
    strategy_add_form("(= (plunit-strategy-top a) changed)"),
    strategy_add_form("(= (plunit-strategy-top $x) (empty))"),
    strategy_eval_string("(alltd plunit-strategy-top (h a))",[root]),
    strategy_eval_string("(alltd plunit-strategy-top (g a a))",Answers),
    assertion(Answers==[[g,changed,changed],[g,changed,changed],
                        [g,changed,changed],[g,changed,changed]]),
    strategy_eval_string("(alltd fail ())",[[]]),
    strategy_eval_string("(alltd fail untouched)",[untouched]).

test(choice_restores_each_answer_binding) :-
    strategy_add_form("(= (plunit-strategy-binding a) first)"),
    strategy_add_form("(= (plunit-strategy-binding b) second)"),
    findall(Result-Subject,
            eval([choice,'plunit-strategy-binding',id,Subject],Result),Answers),
    assertion(Answers==[first-a,second-b]).

test(unbound_strategy_declines) :-
    \+ eval(['strategy-eval',_Strategy,literal],_).

test(numeric_repeat_and_rewrite_repeat_coexist) :-
    strategy_eval_string("(import! &self (library lib_functional))",_),
    strategy_eval_string("(collapse (repeat 0 (noeval token)))",[[]]),
    strategy_eval_string("(collapse (repeat 3 (noeval token)))",[[token,token,token]]),
    strategy_eval_string("(strategy-repeat plunit-strategy-step plunit-a)",['plunit-c']),
    strategy_eval_string("(strategy-apply (repeat plunit-strategy-step) plunit-a)",['plunit-c']).

:- end_tests(lib_strategy).
