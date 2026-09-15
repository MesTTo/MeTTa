% Purpose: test held native cleanup application on actual SWI unwind outcomes.
% Owns resources: every test erases its recorded event references, temporary
%   clauses, engines and named-space rows, including after assertion failure
%   [tested: sh engine/test.sh suites/evaluation/on_unwind.plt;
%   commit=WORKTREE].

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(when)).

:- multifile seam:extension_builtin/2.
seam:extension_builtin('plunit-on-unwind-probe', writesState).
seam:extension_builtin('plunit-on-unwind-handler', writesState).
:- dynamic on_unwind_cell/2.

'plunit-on-unwind-probe'(Token, Mode, Out) :-
    on_unwind_probe(Mode, Token, Out).
'plunit-on-unwind-handler'(Token, Mode, Outcome, Out) :-
    on_unwind_handler(Mode, Token, Outcome, Out).
:- register_builtin_fun('plunit-on-unwind-probe').
:- register_builtin_fun('plunit-on-unwind-handler').

on_unwind_event(Token, Event) :- recordz(Token, event(Event), _).
on_unwind_events(Token, Events) :-
    findall(Event, recorded(Token, event(Event), _), Events).
clear_on_unwind(Token) :-
    forall(recorded(Token, _, Reference), erase(Reference)),
    retractall(on_unwind_cell(Token, _)).
new_on_unwind(Token) :- gensym('$plunit_on_unwind_', Token).

on_unwind_probe(failure, _, _) :- fail.
on_unwind_probe(choices, Token, Out) :-
    member(Out, [first, second, third]),
    on_unwind_event(Token, source(Out)).
on_unwind_probe(raise(Ball), _, _) :- throw(Ball).
on_unwind_probe(mutate_fail(Cell), Token, _) :-
    retractall(on_unwind_cell(Cell, _)), assertz(on_unwind_cell(Cell, after)),
    on_unwind_event(Token, mutated),
    fail.
on_unwind_probe(yield_fail, Token, _) :-
    on_unwind_event(Token, before_yield),
    engine_yield(paused),
    on_unwind_event(Token, after_yield),
    fail.
on_unwind_probe(yield_signal, Token, _) :-
    on_unwind_event(Token, before_yield),
    engine_yield(paused),
    engine_fetch(Ball),
    throw(Ball).

on_unwind_handler(note, Token, Outcome, true) :-
    on_unwind_event(Token, handled(Outcome)).
on_unwind_handler(failure, Token, Outcome, _) :-
    on_unwind_event(Token, handled(Outcome)), fail.
on_unwind_handler(raise(Ball), Token, Outcome, _) :-
    on_unwind_event(Token, handled(Outcome)), throw(Ball).
on_unwind_handler(multiple, Token, Outcome, Out) :-
    member(Out, [first, second, third]),
    on_unwind_event(Token, handler(Out, Outcome)),
    ( Out == third -> throw(unwind_third_handler_executed) ; true ).
on_unwind_handler(value(Value), Token, Outcome, Value) :-
    on_unwind_event(Token, handled(Outcome)).
on_unwind_handler(capture(Cell), Token, Outcome, true) :-
    on_unwind_cell(Cell, Value), on_unwind_event(Token, captured(Value, Outcome)).
on_unwind_handler(label(Label), Token, Outcome, true) :-
    on_unwind_event(Token, Label-Outcome).
on_unwind_handler(module, Token, Outcome, true) :-
    current_metta_module(Module), on_unwind_event(Token, module(Module, Outcome)).
on_unwind_handler(construct, Token, _, Handler) :-
    on_unwind_event(Token, constructed), unwind_handler(Token, note, Handler).

% Fixture modes contain native exception terms and cell refs, held as data.
unwind_handler(Token, Mode,
               ['|->', [Outcome], ['plunit-on-unwind-handler', Token, [noeval, Mode], Outcome]]).
unwind_source(Token, Mode, ['plunit-on-unwind-probe', Token, [noeval, Mode]]).

:- begin_tests(on_unwind).

test(the_provider_is_exported_declared_and_classified) :-
    assertion(predicate_property(metta_engine:'on-unwind'(_, _, _), exported)),
    assertion(builtin_fun('on-unwind')),
    assertion(builtin_implementation('on-unwind'/2, prolog(engine))),
    assertion(seam:builtin_type_declaration('on-unwind', [->, 'Atom', 'Atom', 'Atom'])),
    findall(Effect, metta_operation_effect('on-unwind', Effect), Effects),
    assertion(Effects == [writesState]).

test(deterministic_completion_does_not_evaluate_the_handler,
     [setup(new_on_unwind(Token)), cleanup(clear_on_unwind(Token))]) :-
    Handler = ['plunit-on-unwind-handler', Token, construct, unused],
    'on-unwind'([noeval, done], Handler, Out),
    assertion(Out == done), on_unwind_events(Token, Events), assertion(Events == []).

test(an_unused_unbound_handler_stays_unevaluated) :-
    'on-unwind'([noeval, done], Handler, Out),
    assertion(var(Handler)), assertion(Out == done).

test(failure_applies_the_handler_to_the_native_catcher,
     [setup(new_on_unwind(Token)), cleanup(clear_on_unwind(Token))]) :-
    unwind_source(Token, failure, Source), unwind_handler(Token, note, Handler),
    assertion(\+ 'on-unwind'(Source, Handler, _)),
    on_unwind_events(Token, Events), assertion(Events == [handled([fail])]).

test(handler_construction_occurs_only_at_unwind,
     [setup(new_on_unwind(Token)), cleanup(clear_on_unwind(Token))]) :-
    Handler = ['plunit-on-unwind-handler', Token, construct, unused],
    assertion(\+ 'on-unwind'([superpose, []], Handler, _)),
    on_unwind_events(Token, Events), assertion(Events == [constructed, handled([fail])]).

test(a_caller_cut_runs_the_handler_once_before_return,
     [setup(new_on_unwind(Token)), cleanup(clear_on_unwind(Token))]) :-
    unwind_source(Token, choices, Source), unwind_handler(Token, note, Handler),
    once('on-unwind'(Source, Handler, Out)), assertion(Out == first),
    on_unwind_events(Token, Events), assertion(Events == [source(first), handled(['!'])]).

test(a_source_cut_does_not_cut_the_callers_other_branch,
     [setup(new_on_unwind(Token)), cleanup(clear_on_unwind(Token))]) :-
    unwind_handler(Token, note, Handler),
    findall(Value,
            ( 'on-unwind'([once, [superpose, [first, second]]], Handler, Value)
            ; Value = caller ), Values),
    assertion(Values == [first, caller]),
    on_unwind_events(Token, Events), assertion(Events == []).

test(an_exception_reaches_the_handler_and_keeps_its_original_ball,
     [setup(new_on_unwind(Token)), cleanup(clear_on_unwind(Token))]) :-
    Ball = error(unwind_source_witness, context(test, preserved)),
    unwind_source(Token, raise(Ball), Source), unwind_handler(Token, note, Handler),
    catch('on-unwind'(Source, Handler, _), Caught, true), assertion(Caught == Ball),
    on_unwind_events(Token, Events), assertion(Events == [handled([exception, Ball])]).

test(an_external_exception_is_distinct_from_a_source_exception,
     [setup(new_on_unwind(Token)), cleanup(clear_on_unwind(Token))]) :-
    unwind_source(Token, choices, Source), unwind_handler(Token, note, Handler),
    catch(( 'on-unwind'(Source, Handler, first), throw(unwind_external) ), Ball, true),
    assertion(Ball == unwind_external),
    on_unwind_events(Token, Events),
    assertion(Events == [source(first), handled([external_exception, unwind_external])]).

test(a_terminal_engine_control_signal_is_not_reified_as_a_value,
     [setup(new_on_unwind(Token)), cleanup(clear_on_unwind(Token))]) :-
    Ball = error(metta_control_signal(inference_limit, witness), context(test, control)),
    assertion(control_exception(Ball)),
    unwind_source(Token, raise(Ball), Source), unwind_handler(Token, note, Handler),
    catch(eval([catch, ['on-unwind', Source, Handler]], _), Caught, true),
    assertion(Caught == Ball),
    on_unwind_events(Token, Events), assertion(Events == [handled([exception, Ball])]).

test(handler_failure_preserves_source_failure,
     [setup(new_on_unwind(Token)), cleanup(clear_on_unwind(Token))]) :-
    unwind_handler(Token, failure, Handler),
    assertion(\+ 'on-unwind'([superpose, []], Handler, _)),
    on_unwind_events(Token, Events), assertion(Events == [handled([fail])]).

test(handler_failure_preserves_the_pending_exception,
     [setup(new_on_unwind(Token)), cleanup(clear_on_unwind(Token))]) :-
    unwind_source(Token, raise(unwind_primary), Source), unwind_handler(Token, failure, Handler),
    catch('on-unwind'(Source, Handler, _), Ball, true), assertion(Ball == unwind_primary),
    on_unwind_events(Token, Events), assertion(Events == [handled([exception, unwind_primary])]).

test(a_handler_exception_replaces_source_failure,
     [setup(new_on_unwind(Token)), cleanup(clear_on_unwind(Token))]) :-
    unwind_handler(Token, raise(unwind_cleanup), Handler),
    catch('on-unwind'([superpose, []], Handler, _), Ball, true),
    assertion(Ball == unwind_cleanup).

test(a_more_urgent_source_exception_outweighs_a_cleanup_exception,
     [setup(new_on_unwind(Token)), cleanup(clear_on_unwind(Token))]) :-
    Primary = error(resource_error(unwind_witness), context(test, primary)),
    unwind_source(Token, raise(Primary), Source), unwind_handler(Token, raise(unwind_cleanup), Handler),
    catch('on-unwind'(Source, Handler, _), Ball, true), assertion(Ball == Primary),
    on_unwind_events(Token, Events), assertion(Events == [handled([exception, Primary])]).

test(a_more_urgent_handler_exception_outweighs_the_source_exception,
     [setup(new_on_unwind(Token)), cleanup(clear_on_unwind(Token))]) :-
    Secondary = error(resource_error(unwind_witness), context(test, cleanup)),
    unwind_source(Token, raise(unwind_primary), Source), unwind_handler(Token, raise(Secondary), Handler),
    catch('on-unwind'(Source, Handler, _), Ball, true), assertion(Ball == Secondary).

test(handler_alternatives_are_cut_after_the_first_answer,
     [setup(new_on_unwind(Token)), cleanup(clear_on_unwind(Token))]) :-
    unwind_handler(Token, multiple, Handler),
    assertion(\+ 'on-unwind'([superpose, []], Handler, _)),
    on_unwind_events(Token, Events), assertion(Events == [handler(first, [fail])]).

test(error_shaped_handler_results_remain_data,
     [setup(new_on_unwind(Token)), cleanup(clear_on_unwind(Token))]) :-
    unwind_handler(Token, value(['Error', held, data]), Handler),
    assertion(\+ 'on-unwind'([superpose, []], Handler, _)),
    on_unwind_events(Token, Events), assertion(Events == [handled([fail])]).

test(a_source_value_keeps_its_native_identity_and_shape,
     [forall(member(Value, ['@'(none), false, [], ['Error', held, data], ['+', 1, 2]]))]) :-
    'on-unwind'([noeval, Value], unused, Out), assertion(Out == Value),
    eval(['on-unwind', [noeval, Value], unused], Evaluated), assertion(Evaluated == Value),
    compiled_unwind([noeval, Value], unused, Compiled), assertion(Compiled == Value).

test(a_successful_source_variable_is_not_copied) :-
    'on-unwind'([noeval, Value], unused, Out),
    assertion(var(Value)), assertion(Out == Value), Out = bound, assertion(Value == bound).

test(a_source_constraint_keeps_one_original_delayed_hook,
     [forall(member(Door, [direct, evaluated])),
      setup(new_on_unwind(Token)), cleanup(clear_on_unwind(Token))]) :-
    when(nonvar(Variable), on_unwind_event(Token, bound)),
    Source = [noeval, Variable],
    ( Door == direct -> 'on-unwind'(Source, unused, Out)
    ; eval(['on-unwind', Source, unused], Out) ),
    assertion(Out == Variable),
    on_unwind_events(Token, Before), assertion(Before == []),
    Out = bound,
    on_unwind_events(Token, After), assertion(After == [bound]).

test(captured_variables_belong_to_the_failing_leafs_current_environment,
     [setup(new_on_unwind(Token)), cleanup(clear_on_unwind(Token))]) :-
    Cell = Token,
    assertz(user:on_unwind_cell(Cell, before)),
    unwind_handler(Token, capture(Cell), Handler),
    retractall(user:on_unwind_cell(Cell, _)), assertz(user:on_unwind_cell(Cell, current_leaf)),
    assertion(\+ 'on-unwind'([superpose, []], Handler, _)),
    on_unwind_events(Token, Events), assertion(Events == [captured(current_leaf, [fail])]).

test(a_cell_changed_inside_source_is_the_handlers_exact_cell,
     [setup(new_on_unwind(Token)), cleanup(clear_on_unwind(Token))]) :-
    Cell = Token, assertz(user:on_unwind_cell(Cell, before)),
    unwind_source(Token, mutate_fail(Cell), Source), unwind_handler(Token, capture(Cell), Handler),
    assertion(\+ 'on-unwind'(Source, Handler, _)),
    assertion(user:on_unwind_cell(Cell, after)), on_unwind_events(Token, Events),
    assertion(Events == [mutated, captured(after, [fail])]).

test(nested_unwind_handlers_run_from_inner_to_outer,
     [setup(new_on_unwind(Token)), cleanup(clear_on_unwind(Token))]) :-
    unwind_handler(Token, label(outer), OuterHandler), unwind_handler(Token, label(inner), InnerHandler),
    assertion(\+ 'on-unwind'(['on-unwind', [superpose, []], InnerHandler], OuterHandler, _)),
    on_unwind_events(Token, Events), assertion(Events == [inner-[fail], outer-[fail]]).

test(an_engine_yield_is_not_unwind_and_resume_keeps_its_handler,
     [setup(new_on_unwind(Token)), cleanup(clear_on_unwind(Token))]) :-
    unwind_source(Token, yield_fail, Source), unwind_handler(Token, note, Handler),
    setup_call_cleanup(
        engine_create(done, ( \+ 'on-unwind'(Source, Handler, _) ), Engine),
        ( engine_next(Engine, paused),
          on_unwind_events(Token, Before), assertion(Before == [before_yield]),
          engine_next(Engine, done),
          on_unwind_events(Token, After),
          assertion(After == [before_yield, after_yield, handled([fail])]) ),
        engine_destroy(Engine)).

test(a_resumed_engine_control_signal_runs_cleanup_before_it_escapes,
     [setup(new_on_unwind(Token)), cleanup(clear_on_unwind(Token))]) :-
    Ball = error(metta_control_signal(inference_limit, yielded), context(test, control)),
    unwind_source(Token, yield_signal, Source), unwind_handler(Token, note, Handler),
    setup_call_cleanup(
        engine_create(unreachable, 'on-unwind'(Source, Handler, _), Engine),
        ( engine_next(Engine, paused), engine_post(Engine, Ball),
          catch(engine_next(Engine, _), Caught, true), assertion(Caught == Ball),
          on_unwind_events(Token, Events),
          assertion(Events == [before_yield, handled([exception, Ball])]) ),
        engine_destroy(Engine)).

test(abandoning_a_suspended_engine_runs_its_handler_once,
     [setup(new_on_unwind(Token)), cleanup(clear_on_unwind(Token))]) :-
    unwind_source(Token, yield_fail, Source), unwind_handler(Token, note, Handler),
    setup_call_cleanup(
        engine_create(unreachable, 'on-unwind'(Source, Handler, _), Engine),
        engine_next(Engine, paused),
        engine_destroy(Engine)),
    on_unwind_events(Token, Events),
    assertion(Events = [before_yield, handled(_)]),
    Events = [before_yield, handled(Outcome)],
    assertion(Outcome \== [exit]).

test(source_and_handler_use_the_same_named_module,
     [setup(new_on_unwind(Token)),
      cleanup((clear_on_unwind(Token), clear_native_atoms('&plunit_unwind_home')))]) :-
    current_metta_module(Before),
    unwind_source(Token, failure, Source), unwind_handler(Token, module, Handler),
    assertion(\+ evalc(['on-unwind', Source, Handler], '&plunit_unwind_home', _)),
    space_module('&plunit_unwind_home', Home),
    on_unwind_events(Token, Events), assertion(Events == [module(Home, [fail])]),
    current_metta_module(After), assertion(After == Before).

test(outer_transaction_writes_are_visible_to_cleanup_and_rollback_together,
     [cleanup(clear_native_atoms('&plunit_unwind_transaction'))]) :-
    Home = '&plunit_unwind_transaction',
    Handler = ['|->', [Outcome],
               [match, Home, [cell, Value], ['add-atom', Home, [observed, Value, Outcome]]]],
    catch(transaction((
        'add-atom'(Home, [cell, current], _),
        \+ 'on-unwind'([superpose, []], Handler, _),
        assertion('get-atoms'(Home, [observed, current, [fail]])),
        throw(unwind_transaction_rollback)
    )), unwind_transaction_rollback, true),
    assertion(\+ 'get-atoms'(Home, _)).

test(both_effect_planners_visit_the_source_and_applied_handler) :-
    metta_self_module(Module),
    Read = ['get-atoms', '&plunit_unwind_read'],
    Write = ['add-atom', '&plunit_unwind_write', held],
    forall(member(ReadRuns-WriteRuns, [true-true, true-false, false-true]),
           ( ( ReadRuns == true -> Source = Read ; Source = [noeval, Read] ),
             ( WriteRuns == true -> Body = Write ; Body = [noeval, Write] ),
             Handler = ['|->', [_], Body], Form = ['on-unwind', Source, Handler],
             metta_host_source_runtime_effect_plan(Module, Form, SourceOperations, _),
             translate_expr(Form, Goals, _), translator:goals_list_to_conj(Goals, Goal),
             metta_host_goal_effect_plan(Module, Goal, GoalOperations, _),
             forall(member(Operations, [SourceOperations, GoalOperations]),
                    ( ( memberchk(['get-atoms', _], Operations) -> assertion(ReadRuns == true)
                      ; assertion(ReadRuns == false) ),
                      ( memberchk(['add-atom', _], Operations) -> assertion(WriteRuns == true)
                      ; assertion(WriteRuns == false) ) )) )).

test(a_dynamic_handler_is_an_unresolved_operation) :-
    metta_self_module(Module),
    metta_host_source_runtime_effect_plan(Module, ['on-unwind', [noeval, done], _], Operations, _),
    assertion(memberchk(['<dynamic-operation>', oracleIO], Operations)).

test(a_local_override_keeps_its_own_source_effects,
     [cleanup(clear_native_atoms('&plunit_unwind_override'))]) :-
    Home = '&plunit_unwind_override',
    'add-atom'(Home, [=, ['on-unwind', _, _], ['println!', overridden]], _),
    space_module(Home, Module), Form = ['on-unwind', [noeval, held], unused],
    metta_host_source_runtime_effect_plan(Module, Form, SourceOperations, _),
    with_metta_module(Module,
        ( translate_expr(Form, Goals, _), translator:goals_list_to_conj(Goals, Goal) )),
    metta_host_goal_effect_plan(Module, Goal, GoalOperations, _),
    forall(member(Operations, [SourceOperations, GoalOperations]),
           assertion(memberchk(['println!', writesState], Operations))).

compiled_unwind(Source, Handler, Answer) :-
    gensym('$plunit_compiled_unwind_', Name),
    translate_clause([=, [Name], ['on-unwind', Source, Handler]], Clause),
    current_metta_module(Module), compiled_function_name(Name, Predicate),
    Goal =.. [Predicate, Answer],
    setup_call_cleanup(assertz(Module:Clause, Reference), Module:Goal, erase(Reference)).

:- end_tests(on_unwind).
