% Purpose: discriminate bounded one-answer evaluation from choicepoint checks.
% Owns resources: the suite releases its event log and transaction rows;
%   each control erases temporary compiled clauses and its named-space atoms.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- multifile seam:extension_builtin/2.
seam:extension_builtin('plunit-eval-one-probe', writesState).

:- dynamic eval_one_transaction_row/1.

'plunit-eval-one-probe'(Mode, Out) :-
    setup_call_cleanup(eval_one_event(open),
                       eval_one_probe(Mode, Out),
                       eval_one_event(close)).
:- register_builtin_fun('plunit-eval-one-probe').

eval_one_event(Event) :-
    nb_getval('$plunit_eval_one_events', Previous),
    append(Previous, [Event], Next),
    nb_setval('$plunit_eval_one_events', Next).

reset_eval_one :-
    nb_setval('$plunit_eval_one_events', []),
    retractall(eval_one_transaction_row(_)).

eval_one_probe(failing_tail, Out) :-
    ( eval_one_event(first), Out = one
    ; eval_one_event(failing), fail ).
eval_one_probe(none, _) :- fail.
eval_one_probe(bounded, Out) :-
    member(Out, [one, two, third]),
    eval_one_event(Out),
    ( Out == third -> throw(third_branch_executed) ; true ).
eval_one_probe(duplicates, same).
eval_one_probe(duplicates, same).
eval_one_probe(throws, _) :- throw(eval_one_witness).
eval_one_probe(late_throw, Out) :-
    ( Out = one ; throw(eval_one_late_witness) ).
eval_one_probe(cleanup_throw, Out) :-
    setup_call_cleanup(true, (Out = one ; fail), throw(eval_one_cleanup_witness)).
eval_one_probe(read_transaction, Value) :- eval_one_transaction_row(Value).
eval_one_probe(write_transaction, written) :-
    assertz(eval_one_transaction_row(written)).
eval_one_probe(context, Context) :- metta_evaluation_context(Context).
eval_one_probe(cut, Out) :- member(Out, [kept, discarded]), !.

:- begin_tests(eval_one,
               [ setup(nb_setval('$plunit_eval_one_events', [])),
                 cleanup(( nb_delete('$plunit_eval_one_events'),
                           retractall(user:eval_one_transaction_row(_)) )) ]).

test(the_provider_is_exported_declared_and_classified) :-
    assertion(predicate_property(metta_engine:'eval-one'(_, _), exported)),
    assertion(builtin_fun('eval-one')),
    assertion(builtin_implementation('eval-one'/1, prolog(engine))),
    assertion(seam:builtin_type_declaration('eval-one', [->, 'Atom', 'Atom'])),
    findall(Effect, metta_operation_effect('eval-one', Effect), Effects),
    assertion(Effects == [writesState]).

test(a_unique_answer_succeeds_after_its_failure_tail,
     [setup(reset_eval_one)]) :-
    'eval-one'(['plunit-eval-one-probe', failing_tail], Out),
    assertion(Out == one),
    nb_getval('$plunit_eval_one_events', Events),
    assertion(Events == [open, first, failing, close]).

test(no_answer_is_a_terminal_cardinality_error,
     [setup(reset_eval_one)]) :-
    Source = ['plunit-eval-one-probe', none],
    catch('eval-one'(Source, _), Ball, true),
    assertion(nonvar(Ball)),
    assertion(Ball = error(metta_cardinality_violation(_, Source, one, 0), _)),
    assertion(control_exception(Ball)),
    nb_getval('$plunit_eval_one_events', Events),
    assertion(Events == [open, close]).

test(two_answers_close_the_source_before_the_third_branch,
     [setup(reset_eval_one)]) :-
    Source = ['plunit-eval-one-probe', bounded],
    catch('eval-one'(Source, _), Ball, true),
    assertion(nonvar(Ball)),
    assertion(Ball = error(metta_cardinality_violation(_, Source, one, at_least(2)), _)),
    assertion(control_exception(Ball)),
    nb_getval('$plunit_eval_one_events', Events),
    assertion(Events == [open, one, two, close]).

test(equal_answers_still_count_twice,
     [throws(error(metta_cardinality_violation(_, _, one, at_least(2)), _))]) :-
    'eval-one'(['plunit-eval-one-probe', duplicates], _).

test(a_result_pattern_does_not_hide_a_second_answer,
     [throws(error(metta_cardinality_violation(_, _, one, at_least(2)), _))]) :-
    'eval-one'([superpose, [one, two]], one).

test(a_unique_answer_can_fail_its_result_pattern, [fail]) :-
    'eval-one'([noeval, actual], different).

test(a_successful_call_does_not_leave_an_alternative) :-
    call_cleanup('eval-one'([noeval, one], Out), Finished = true),
    assertion(Out == one),
    assertion(Finished == true).

test(a_source_cut_keeps_its_own_scope_and_runs_cleanup,
     [setup(reset_eval_one)]) :-
    findall(Out,
            ( 'eval-one'(['plunit-eval-one-probe', cut], Out)
            ; Out = caller_alternative ),
            Answers),
    assertion(Answers == [kept, caller_alternative]),
    nb_getval('$plunit_eval_one_events', Events),
    assertion(Events == [open, close]).

test(caller_cut_does_not_repeat_source_cleanup,
     [setup(reset_eval_one)]) :-
    once('eval-one'(['plunit-eval-one-probe', failing_tail], one)),
    nb_getval('$plunit_eval_one_events', Events),
    assertion(Events == [open, first, failing, close]).

test(an_exception_before_an_answer_keeps_its_term_and_cleanup,
     [setup(reset_eval_one)]) :-
    catch('eval-one'(['plunit-eval-one-probe', throws], _), Ball, true),
    assertion(Ball == eval_one_witness),
    nb_getval('$plunit_eval_one_events', Events),
    assertion(Events == [open, close]).

test(an_exception_after_the_first_answer_is_not_unique_success,
     [setup(reset_eval_one)]) :-
    catch('eval-one'(['plunit-eval-one-probe', late_throw], _), Ball, true),
    assertion(Ball == eval_one_late_witness),
    nb_getval('$plunit_eval_one_events', Events),
    assertion(Events == [open, close]).

test(a_cleanup_exception_replaces_the_unfinished_observation,
     [setup(reset_eval_one)]) :-
    catch('eval-one'(['plunit-eval-one-probe', cleanup_throw], _), Ball, true),
    assertion(Ball == eval_one_cleanup_witness),
    nb_getval('$plunit_eval_one_events', Events),
    assertion(Events == [open, close]).

test(held_values_are_returned_without_testing_or_reducing_them,
     [forall(member(Value, ['None', '@'(none), false, [],
                           ['Error', held, data], ['+', 1, 2]]))]) :-
    'eval-one'([noeval, Value], Direct),
    assertion(Direct == Value),
    eval(['eval-one', [noeval, Value]], Evaluated),
    assertion(Evaluated == Value),
    compiled_one([noeval, Value], Compiled),
    assertion(Compiled == Value).

test(a_held_variable_keeps_its_original_identity) :-
    'eval-one'([noeval, Variable], Direct),
    assertion(var(Variable)),
    assertion(Direct == Variable),
    eval(['eval-one', [noeval, Variable]], Evaluated),
    assertion(Evaluated == Variable).

test(sharing_inside_a_value_and_its_source_is_retained) :-
    Value = [pair, Variable, Variable],
    'eval-one'([noeval, Value], Result),
    assertion(Result == Value),
    Result = [pair, First, Second],
    First = bound,
    assertion(Second == bound),
    assertion(Variable == bound).

test(a_held_variable_retains_its_constraints) :-
    dif(Variable, excluded),
    'eval-one'([noeval, Variable], Result),
    assertion(Result == Variable),
    assertion(\+ Result = excluded),
    Result = admitted,
    assertion(Variable == admitted).

test(a_unique_source_binding_is_restored) :-
    'eval-one'([unify, Variable, bound, [noeval, Variable], 'Empty'], Result),
    assertion(Variable == bound),
    assertion(Result == bound).

test(the_empty_sentinel_retains_eval_semantics,
     [throws(error(metta_cardinality_violation(_, _, one, 0), _))]) :-
    'eval-one'([noeval, 'Empty'], _).

test(compiled_multiple_answers_raise_the_same_terminal_error,
     [throws(error(metta_cardinality_violation(_, _, one, at_least(2)), _))]) :-
    compiled_one([superpose, [one, two]], _).

test(outer_transactions_are_visible_and_own_all_native_writes,
     [setup(reset_eval_one)]) :-
    catch(transaction((
        assertz(user:eval_one_transaction_row(before)),
        'eval-one'(['plunit-eval-one-probe', read_transaction], before),
        'eval-one'(['plunit-eval-one-probe', write_transaction], written),
        assertion(user:eval_one_transaction_row(written)),
        throw(rollback_eval_one)
    )), rollback_eval_one, true),
    assertion(\+ user:eval_one_transaction_row(_)),
    nb_getval('$plunit_eval_one_events', Events),
    assertion(Events == [open, close, open, close]).

test(a_cardinality_exception_rolls_back_its_enclosing_transaction,
     [setup(reset_eval_one)]) :-
    catch(transaction((
        assertz(user:eval_one_transaction_row(before)),
        'eval-one'([superpose, [one, two]], _)
    )), Ball, true),
    assertion(nonvar(Ball)),
    assertion(Ball = error(metta_cardinality_violation(_, _, one, at_least(2)), _)),
    assertion(\+ user:eval_one_transaction_row(_)).

test(the_current_evaluation_context_is_visible_and_restored) :-
    Context = evaluation_context(ranked, 7, descending),
    metta_with_evaluation_context(Context,
        ( 'eval-one'(['plunit-eval-one-probe', context], Result),
          assertion(Result == Context),
          metta_evaluation_context(After),
          assertion(After == Context) )),
    assertion(\+ metta_evaluation_context(_)).

test(an_exception_restores_the_evaluation_context) :-
    catch(metta_with_evaluation_context(evaluation_context(ranked, 7, descending),
              'eval-one'(['plunit-eval-one-probe', throws], _)),
          eval_one_witness, true),
    assertion(\+ metta_evaluation_context(_)).

test(evalc_selects_the_source_home_and_restores_the_caller,
     [cleanup(clear_native_atoms('&plunit_eval_one_home'))]) :-
    current_metta_module(Before),
    'add-atom'('&plunit_eval_one_home', [=, ['plunit-eval-one-home'], there], _),
    evalc(['eval-one', ['plunit-eval-one-home']], '&plunit_eval_one_home', Out),
    assertion(Out == there),
    current_metta_module(After),
    assertion(After == Before).

test(an_exception_restores_the_named_module,
     [cleanup(clear_native_atoms('&plunit_eval_one_throw_home'))]) :-
    current_metta_module(Before),
    catch(evalc(['eval-one', ['plunit-eval-one-probe', throws]],
                '&plunit_eval_one_throw_home', _), Ball, true),
    assertion(Ball == eval_one_witness),
    current_metta_module(After),
    assertion(After == Before).

test(both_effect_plans_visit_the_source_and_preserve_held_data) :-
    metta_self_module(Module),
    Write = ['add-atom', '&plunit_eval_one_effect', [written, value]],
    forall(member(Source-Executes, [Write-true, [noeval, Write]-false]),
           ( metta_host_source_runtime_effect_plan(
                 Module, ['eval-one', Source], SourceOperations, _),
             translate_expr(['eval-one', Source], Goals, _),
             translator:goals_list_to_conj(Goals, Body),
             metta_host_goal_effect_plan(Module, Body, GoalOperations, _),
             forall(member(Operations, [SourceOperations, GoalOperations]),
                    ( memberchk(['add-atom', writesState], Operations)
                    -> assertion(Executes == true)
                    ;  assertion(Executes == false) )) )),
    assertion(\+ user:eval_one_transaction_row(_)).

test(a_local_override_keeps_its_own_body_effects,
     [cleanup(clear_native_atoms('&plunit_eval_one_override'))]) :-
    Space = '&plunit_eval_one_override',
    'add-atom'(Space, [=, ['eval-one', _], ['println!', overridden]], _),
    space_module(Space, Module),
    Source = ['eval-one', [noeval, held]],
    metta_host_source_runtime_effect_plan(Module, Source, SourceOperations, _),
    with_metta_module(Module,
                      ( translate_expr(Source, Goals, _),
                        translator:goals_list_to_conj(Goals, Body) )),
    metta_host_goal_effect_plan(Module, Body, GoalOperations, _),
    forall(member(Operations, [SourceOperations, GoalOperations]),
           assertion(memberchk(['println!', writesState], Operations))).

compiled_one(Source, Answer) :-
    gensym('$plunit_eval_one_', Name),
    translate_clause([=, [Name], ['eval-one', Source]], Clause),
    current_metta_module(Module),
    compiled_function_name(Name, Predicate),
    Goal =.. [Predicate, Answer],
    setup_call_cleanup(assertz(Module:Clause, Reference),
                       Module:Goal,
                       erase(Reference)).

:- end_tests(eval_one).
