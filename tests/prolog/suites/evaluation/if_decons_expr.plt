% Purpose: exercise safe expression deconstruction through the engine evaluator.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(if_decons_expr).

test(nonempty_expression_binds_head_and_tail) :-
    findall(Result, eval(['if-decons-expr', [a,b,c], H,T,
                         [pair,H,T], fallback], Result), Results),
    assertion(Results == [[pair,a,[b,c]]]).

test(empty_expression_selects_the_fallback) :-
    findall(Result, eval(['if-decons-expr', [], H,T,
                         [pair,H,T], fallback], Result), Results),
    assertion(Results == [fallback]).

test(unbound_input_selects_fallback_without_inventing_a_list) :-
    findall(Result-X, eval(['if-decons-expr', X, H,T,
                           [pair,H,T], fallback], Result), Results),
    Results = [fallback-Variable],
    assertion(var(Variable)).

test(only_the_selected_branch_evaluates) :-
    findall(Result, eval(['if-decons-expr', [1,2], H,_T,
                         ['+',H,10], ['/',1,0]], Result), Results),
    assertion(Results == [11]).

test(the_operand_is_inspected_without_evaluation) :-
    findall(Result, eval(['if-decons-expr', ['+',1,2], _H,T,
                         T, fallback], Result), Results),
    assertion(Results == [[1,2]]).

test(failed_bindings_are_undone_before_fallback) :-
    findall(Result-H, eval(['if-decons-expr', [a,b], H,H,
                           matched, fallback], Result), Results),
    Results = [fallback-Variable],
    assertion(var(Variable)).

test(already_bound_head_and_tail_match_or_select_fallback) :-
    findall(Result, eval(['if-decons-expr', [a,b], a,[b],
                         matched, fallback], Result), Matches),
    assertion(Matches == [matched]),
    findall(Result, eval(['if-decons-expr', [a,b], wrong,[b],
                         matched, fallback], Result), WrongHead),
    assertion(WrongHead == [fallback]),
    findall(Result, eval(['if-decons-expr', [a,b], a,[],
                         matched, fallback], Result), WrongTail),
    assertion(WrongTail == [fallback]).

test(selected_branch_preserves_all_answers) :-
    findall(Result, eval(['if-decons-expr', [a,b], _H,_T,
                         [superpose,[1,2,2]], fallback], Result), Results),
    assertion(Results == [1,2,2]).

test(known_wrong_operand_type_retains_the_type_error) :-
    findall(Result, eval(['if-decons-expr', 42, H,T,
                         [pair,H,T], fallback], Result), Results),
    assertion(Results = [['Error', _, ['BadArgType',1,'Expression','Number']]]).

test(a_held_error_branch_cannot_replace_an_input_type_refusal) :-
    findall(Result, eval(['if-decons-expr', 42, _H,_T,
                         ['Error',bad,held], fallback], Result), Results),
    assertion(Results = [['Error', _, ['BadArgType',1,'Expression','Number']]]).

test(an_undecided_symbol_keeps_the_call_unreduced) :-
    Call = ['if-decons-expr', undecided_symbol, H,T, [pair,H,T], fallback],
    findall(Result, eval(Call, Result), Results),
    assertion(Results =@= [Call]).

test(the_selector_has_an_explicit_structural_effect) :-
    findall(Effect, metta_operation_effect('if-decons-expr', Effect), Effects),
    assertion(Effects == [pureStructural]).

test(the_planner_checks_both_selected_branch_candidates) :-
    metta_self_module(Module),
    forall(member(Then-Else, [['println!',held_then]-pure_else,
                             pure_then-['println!',held_else]]),
           ( metta_host_source_runtime_effect_plan(
                 Module, ['if-decons-expr', [], _H,_T, Then, Else],
                 Operations, Effect),
             assertion(Effect == writesState),
             assertion(memberchk(['println!',writesState], Operations))
           )).

:- end_tests(if_decons_expr).
