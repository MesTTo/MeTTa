% Purpose: compare scalar constant folding with the retained runtime evaluator.
% Guarantees: every differential compares complete answer bags and variable
%   bindings, including failed and duplicate-producing contexts
%   [tested: run_tests(translator_constant_folding); commit=3c64e2e24787362a5a5081513bc24b880711a1d7].
% Assumes: the existing tracked/untracked translation doors select the two
%   plans; reaching the compiler here is necessary to compare their code.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(translator_constant_folding).

translation(Mode, Term, Goals, Value) :-
    type_rules:with_typing_policy_stable(
        translator:with_static_contract_shortcuts(
            Mode, translator:translate_expr(Term, Goals, Value))).

answer_bag(Mode, Term0, Outcome) :-
    copy_term(Term0, Term),
    term_variables(Term, Variables),
    translation(Mode, Term, Goals, Value),
    current_metta_module(Module),
    catch(( findall(Variables-Value,
                    call_goals_in(Module, Goals), Rows),
            maplist(canonical_answer, Rows, Canonical),
            msort(Canonical, Sorted),
            Outcome = answers(Sorted) ),
          Error,
          ( canonical_answer(Error, CanonicalError),
            Outcome = thrown(CanonicalError) )).

canonical_answer(Value, Canonical) :-
    copy_term(Value, Canonical),
    numbervars(Canonical, 0, _).

differential(Term) :-
    answer_bag(disabled, Term, Slow),
    answer_bag(enabled, Term, Fast),
    assertion(Fast == Slow).

adversarial("(+ 1 (+ 2 3))").
adversarial("(max-atom (9 9 -5 3))").
adversarial("(min-atom (-8 2 -8 9))").
adversarial("(size-atom (1 1 1 2))").
adversarial("(size-atom ())").
adversarial("(max-atom ())").
adversarial("(+ 1 \"bad\")").
adversarial("(+ 1.0 2.0)").
adversarial("(floor-div 1 0)").
adversarial("(+ 1 (floor-div 1 0))").
adversarial("(if True (+ 1 2) (floor-div 1 0))").
adversarial("(if False (floor-div 1 0) (+ 1 2))").
adversarial("(quote (+ 1 2))").
adversarial("(let $x (max-atom ()) (+ 1 2))").
adversarial("(let 7 (+ $x 2) $x)").
adversarial("(let 7 (* $x 2) $x)").
adversarial("(let $x (superpose (1 1 2)) (+ 3 4))").
adversarial("(collapse (let $x (superpose (1 1 2)) (+ 3 4)))").
adversarial("(superpose ((+ 1 2) (+ 1 2) (+ 2 2)))").
adversarial("(let $x (superpose (1 1 2)) (+ $x (+ 3 4)))").
adversarial("(let $x (+ 2 3) ($x $x))").
adversarial("(if (superpose (True False True)) (+ 1 1) (+ 2 2))").
adversarial("(max-atom (1 (quote (+ 1 2)) 3))").

test(ground_and_adversarial_answer_bags_agree,
     [forall(adversarial(Text))]) :-
    sread(Text, Term),
    differential(Term).

integer_probe(-17).
integer_probe(-1).
integer_probe(0).
integer_probe(1).
integer_probe(19).
integer_probe(1208925819614629174706176).

binary_operation('+').
binary_operation('-').
binary_operation('*').
binary_operation('%').
binary_operation(min).
binary_operation(max).
binary_operation('floor-div').
binary_operation('bit-and').
binary_operation('bit-or').
binary_operation('bit-xor').

test(the_closed_integer_fragment_agrees_in_every_probed_mode,
     [forall(( binary_operation(Operation),
               integer_probe(Left), integer_probe(Right) ))]) :-
    differential([Operation, Left, Right]).

test(unary_integer_results_agree,
     [forall(( member(Operation, ['abs-math', 'bit-not']),
               integer_probe(Value) ))]) :-
    differential([Operation, Value]).

test(nested_constants_are_reduced_during_tracked_translation) :-
    translation(enabled, ['+', 1, ['*', 2, 3]], Goals, Value),
    assertion(Value == 7),
    assertion(\+ ( sub_term(Goal, Goals), compound(Goal),
                    member(Name, ['+', '*']), functor(Goal, Name, 3) )).

test(an_untracked_translation_keeps_its_runtime_call) :-
    translation(disabled, ['+', 1, 2], Goals, Value),
    assertion(var(Value)),
    assertion(( sub_term(Goal, Goals), nonvar(Goal), Goal = '+'(1, 2, _) )).

test(a_runnable_translation_keeps_its_runtime_call) :-
    translate_runnable_expr(['+', 1, 2], Goals, Value),
    assertion(var(Value)),
    assertion(( sub_term(Goal, Goals), nonvar(Goal), Goal = '+'(1, 2, _) )).

test(a_fixed_list_scan_becomes_one_integer) :-
    numlist(1, 2000, Values),
    translation(enabled, ['max-atom', Values], Goals, Value),
    assertion(Value == 2000),
    assertion(\+ ( sub_term(Goal, Goals), compound(Goal),
                    functor(Goal, 'max-atom', 2) )).

test(an_empty_scan_keeps_its_failure) :-
    answer_bag(enabled, ['max-atom', []], Outcome),
    assertion(Outcome == answers([])).

test(a_duplicate_context_still_answers_three_times) :-
    sread("(let $x (superpose (1 1 2)) (+ 3 4))", Term),
    answer_bag(enabled, Term, answers(Rows)),
    assertion(Rows == [[1]-7, [1]-7, [2]-7]).

test(a_stricter_effect_declaration_disables_planning,
     [ setup('add-atom'('&metta', [effect, '+', oracleIO], _)),
       cleanup('remove-atom'('&metta', [effect, '+', oracleIO], _)) ]) :-
    translation(enabled, ['+', 1, 2], _, Value),
    assertion(var(Value)).

test(a_variable_input_is_not_bound_by_planning) :-
    translation(enabled, ['+', Input, 2], _, _),
    assertion(var(Input)).

test(a_float_call_retains_its_runtime_numeric_policy) :-
    translation(enabled, ['+', 1.0, 2.0], _, Value),
    assertion(var(Value)).

test(a_resource_amplifying_shift_is_not_executed_during_planning) :-
    translation(enabled, ['bit-shift-left', 1, 100000000000], _, Value),
    assertion(var(Value)).

squaring_chain(0, Value, Value) :- !.
squaring_chain(Depth, Value, [let, Next, ['*', Value, Value], Tail]) :-
    Rest is Depth - 1,
    squaring_chain(Rest, Next, Tail).

test(let_bound_repeated_squaring_retains_runtime_bindings,
     [forall(member(Depth, [2, 4, 6, 8, 10, 12]))]) :-
    squaring_chain(Depth, Seed, Tail),
    Term = [if, 'False', [let, Seed, 2, Tail], 0],
    translation(enabled, Term, Goals, _),
    findall(1, ( sub_term(Goal, Goals), compound(Goal),
                 functor(Goal, '*', 3) ), Multiplications),
    length(Multiplications, Count),
    assertion(Count == Depth),
    forall((sub_term(Integer, Goals), integer(Integer)),
           assertion(between(-2, 2, Integer))),
    differential(Term).

:- end_tests(translator_constant_folding).
