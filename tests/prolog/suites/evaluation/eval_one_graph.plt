% Purpose: verify observed binding graphs through every native eval-one door.
% Owns resources: each fixture deletes its temporary native goal reference;
%   cases release engines, compiled clauses, event counters and transaction rows.
% Assumes: the independent attributed-source cache admission repair is present.
% [tested: sh engine/test.sh suites/evaluation/eval_one_graph.plt;
% commit=WORKTREE].

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(when)).

:- multifile seam:extension_builtin/2.
seam:extension_builtin('plunit-eval-one-graph', writesState).

'plunit-eval-one-graph'(Key, _HeldSource, Out) :-
    nb_getval(Key, source(Goal, Produced)),
    call(Goal),
    Out = Produced.
:- register_builtin_fun('plunit-eval-one-graph').

:- begin_tests(eval_one_graph).
:- dynamic observed/1.
:- meta_predicate graph_one(+, ?, 0, ?, ?).
:- meta_predicate must(0).

test(the_successful_binding_graph_survives_observation,
     [ forall((member(Door, [direct, evaluated, compiled]), case_name(Name))),
       setup(nb_setval('$plunit_eval_one_graph_events', [])),
       cleanup((nb_delete('$plunit_eval_one_graph_events'), retractall(observed(_))))
     ]) :-
    eval_one_graph_case(Name, Door).

% The original goal stays outside Source so the hidden-variable cases cannot
% pass merely because a test closure exposes those variables as syntax.
graph_one(Door, Source, Goal, Produced, Out) :-
    gensym('$plunit_eval_one_graph_goal_', Key),
    setup_call_cleanup(
        nb_linkval(Key, source(Goal, Produced)),
        graph_invoke(Door, ['plunit-eval-one-graph', Key, [noeval, Source]], Out),
        nb_delete(Key)).

graph_invoke(direct, Source, Out) :- 'eval-one'(Source, Out).
graph_invoke(evaluated, Source, Out) :- eval(['eval-one', Source], Out).
graph_invoke(compiled, Source, Out) :-
    gensym('$plunit_eval_one_graph_call_', Name),
    translate_clause([=, [Name, Program], ['eval-one', Program]], Clause),
    current_metta_module(Module),
    compiled_function_name(Name, Predicate),
    Goal =.. [Predicate, Source, Out],
    setup_call_cleanup(assertz(Module:Clause, Reference),
                       Module:Goal,
                       erase(Reference)).

graph_cardinality(Ball, Found) :-
    must(nonvar(Ball)),
    must(Ball = error(metta_cardinality_violation(_, _, one, Found), _)),
    must(control_exception(Ball)).

case_name(plain_values).
case_name(ordinary_aliases).
case_name(held_when_failure_tail).
case_name(bound_when_failure_tail).
case_name(hidden_when_partner).
case_name(hidden_bound_partner).
case_name(when_conjunction).
case_name(when_alias_condition).
case_name(dif_constraint).
case_name(user_hook_binding).
case_name(user_hook_aliasing).
case_name(shared_raw_rows_and_result).
case_name(hidden_binding_in_raw_rows).
case_name(added_attribute_graph).
case_name(removed_attribute).
case_name(replaced_attribute).
case_name(cyclic_term).
case_name(cyclic_attributes).
case_name(garbage_collection_in_tail).
case_name(output_attribute_runs_after_count).
case_name(output_pattern_does_not_filter_count).
case_name(zero_answers).
case_name(two_answers_stop_before_third).
case_name(exception_after_first).
case_name(cleanup_after_failure_tail).
case_name(cleanup_on_second_answer).
case_name(cleanup_exception).
case_name(outer_transaction_visibility).
case_name(outer_transaction_rollback).
case_name(engine_yield_and_resume).

must(Goal) :- (call(Goal) -> true ; throw(check_failed(Goal))).

event(Name) :-
    nb_getval('$plunit_eval_one_graph_events', Before),
    nb_setval('$plunit_eval_one_graph_events', [Name|Before]).

events(Expected) :-
    nb_getval('$plunit_eval_one_graph_events', Reversed),
    reverse(Reversed, Actual),
    must(Actual == Expected).

attr_unify_hook(watch(Label, _References), _) :- event(Label).

% Raw snapshots must never ask the attribute module to regenerate its goals.
attribute_goals(_) --> { throw(residual_projection_called) }.

eval_one_graph_case(plain_values, Door) :-
    forall(member(Value, [none, false, [], '', _, error(example), ['+', 1, 2]]),
           ( graph_one(Door, Value, Produced=Value, Produced, Out),
             must(Out == Value) )).
eval_one_graph_case(ordinary_aliases, Door) :-
    graph_one(Door, pair(X,Y), (X=Y, Produced=pair(X,Y); fail), Produced, Out),
    must(X == Y),
    must(Out == pair(X,X)).
eval_one_graph_case(held_when_failure_tail, Door) :-
    when(nonvar(X), event(wake)),
    graph_one(Door, X, (Produced=X; event(tail), fail), Produced, Out),
    must(Out == X), events([tail]),
    Out=bound, events([tail,wake]).
eval_one_graph_case(bound_when_failure_tail, Door) :-
    when(nonvar(X), event(wake)),
    graph_one(Door, X, (X=bound, Produced=X; event(tail), fail), Produced, Out),
    must(Out == bound), must(X == bound), events([wake,tail]).
eval_one_graph_case(hidden_when_partner, Door) :-
    when((nonvar(X);nonvar(Hidden)), event(wake)),
    graph_one(Door, X, (Produced=X; fail), Produced, Out),
    must(Out == X), events([]),
    Hidden=first, events([wake]),
    Out=second, events([wake]).
eval_one_graph_case(hidden_bound_partner, Door) :-
    when((nonvar(X);nonvar(Hidden)), event(wake)),
    graph_one(Door, X, (Hidden=first, Produced=X; fail), Produced, Out),
    must(Hidden == first), must(Out == X), events([wake]),
    Out=second, events([wake]).
eval_one_graph_case(when_conjunction, Door) :-
    when((nonvar(X),nonvar(Hidden)), event(wake)),
    graph_one(Door, X, (X=first, Produced=X; fail), Produced, Out),
    must(Out == first), events([]),
    Hidden=second, events([wake]).
eval_one_graph_case(when_alias_condition, Door) :-
    when(?=(X,Y), event(wake)),
    graph_one(Door, pair(X,Y), (X=Y, Produced=X; fail), Produced, Out),
    must(X == Y), must(Out == X), events([wake]),
    Out=bound, events([wake]).
eval_one_graph_case(dif_constraint, Door) :-
    dif(X,Y),
    graph_one(Door, pair(X,Y), (Produced=pair(X,Y); fail), Produced, Out),
    must(Out == pair(X,Y)),
    must(\+ (X=Y)),
    X=left, Y=right.
eval_one_graph_case(user_hook_binding, Door) :-
    put_attr(X, plunit_eval_one_graph, watch(wake,hidden(Hidden))),
    graph_one(Door, X, (X=bound, Produced=Hidden; event(tail), fail), Produced, Out),
    must(X == bound), must(Out == Hidden), events([wake,tail]).
eval_one_graph_case(user_hook_aliasing, Door) :-
    put_attr(X, plunit_eval_one_graph, watch(left,refs(Hidden))),
    put_attr(Y, plunit_eval_one_graph, watch(right,refs(Hidden))),
    graph_one(Door, pair(X,Y), (X=Y, Produced=X; fail), Produced, Out),
    must(Out == X), must(X == Y),
    nb_getval('$plunit_eval_one_graph_events', Before), must(length(Before, 1)),
    Out=bound,
    nb_getval('$plunit_eval_one_graph_events', After), msort(After, Sorted),
    must(Sorted == [left,right]).
eval_one_graph_case(shared_raw_rows_and_result, Door) :-
    put_attr(X, plunit_eval_one_graph, watch(left,refs(Hidden,X))),
    put_attr(Y, plunit_eval_one_graph, watch(right,refs(Hidden,Y))),
    graph_one(Door, pair(X,Y), (Produced=answer(X,Y,Hidden,Hidden); fail), Produced, Out),
    must(Out == answer(X,Y,Hidden,Hidden)),
    get_attr(X, plunit_eval_one_graph, watch(left,refs(HX,SX))),
    get_attr(Y, plunit_eval_one_graph, watch(right,refs(HY,SY))),
    must(HX == Hidden), must(HY == Hidden), must(SX == X), must(SY == Y),
    events([]), X=one, Y=two, events([left,right]).
eval_one_graph_case(hidden_binding_in_raw_rows, Door) :-
    put_attr(X, plunit_eval_one_graph, watch(left,refs(Hidden))),
    put_attr(Y, plunit_eval_one_graph, watch(right,refs(Hidden))),
    graph_one(Door, pair(X,Y), (Hidden=bound, Produced=answer(X,Y,Hidden); fail),
              Produced, Out),
    must(Hidden == bound), must(Out == answer(X,Y,bound)),
    get_attr(X, plunit_eval_one_graph, watch(left,refs(HX))),
    get_attr(Y, plunit_eval_one_graph, watch(right,refs(HY))),
    must(HX == bound), must(HY == bound), events([]).
eval_one_graph_case(added_attribute_graph, Door) :-
    graph_one(Door, X,
              ( put_attr(X, plunit_eval_one_graph, watch(source,refs(New))),
                put_attr(New, plunit_eval_one_graph, watch(new,refs(X))),
                Produced=pair(X,New)
              ; fail ), Produced, pair(Out,NewOut)),
    must(Out == X),
    get_attr(Out, plunit_eval_one_graph, watch(source,refs(Hidden))),
    get_attr(NewOut, plunit_eval_one_graph, watch(new,refs(Back))),
    must(Hidden == NewOut), must(Back == X), events([]),
    NewOut=one, Out=two, events([new,source]).
eval_one_graph_case(removed_attribute, Door) :-
    put_attr(X, plunit_eval_one_graph, watch(old,refs(Hidden))),
    graph_one(Door, X, (del_attrs(X), Produced=pair(X,Hidden); fail), Produced, Out),
    must(Out == pair(X,Hidden)), must(\+ attvar(X)),
    X=bound, events([]).
eval_one_graph_case(replaced_attribute, Door) :-
    put_attr(X, plunit_eval_one_graph, watch(old,refs(Hidden))),
    graph_one(Door, X,
              (put_attr(X, plunit_eval_one_graph, watch(new,refs(Hidden))),
               Produced=X; fail), Produced, Out),
    must(Out == X), Out=bound, events([new]).
eval_one_graph_case(cyclic_term, Door) :-
    Cycle=ring(Cycle,X),
    graph_one(Door, Cycle, (X=bound, Produced=Cycle; fail), Produced, Out),
    must(Out == Cycle), must(Out == ring(Out,bound)).
eval_one_graph_case(cyclic_attributes, Door) :-
    Cycle=ring(X,Hidden,Cycle),
    put_attr(X, plunit_eval_one_graph, watch(source,refs(Cycle))),
    put_attr(Hidden, plunit_eval_one_graph, watch(hidden,refs(X))),
    graph_one(Door, X, (Produced=pair(X,Hidden); fail), Produced, Out),
    must(Out == pair(X,Hidden)),
    get_attr(X, plunit_eval_one_graph, watch(source,refs(SavedCycle))),
    must(SavedCycle == Cycle),
    Hidden=one, X=two, events([hidden,source]).
eval_one_graph_case(garbage_collection_in_tail, Door) :-
    when((nonvar(X);nonvar(Hidden)), event(wake)),
    graph_one(Door, X, (Produced=pair(X,Hidden); garbage_collect, event(tail), fail),
              Produced, Out),
    must(Out == pair(X,Hidden)), events([tail]),
    Hidden=one, X=two, events([tail,wake]).
eval_one_graph_case(output_attribute_runs_after_count, Door) :-
    when(nonvar(Out), event(output)),
    graph_one(Door, [], (Produced=done; event(tail), fail), Produced, Out),
    must(Out == done), events([tail,output]).
eval_one_graph_case(output_pattern_does_not_filter_count, Door) :-
    catch(graph_one(Door, [], (event(first), Produced=wrong; event(second), Produced=right),
                    Produced, right), Ball, true),
    graph_cardinality(Ball, at_least(2)), events([first,second]).
eval_one_graph_case(zero_answers, Door) :-
    catch(graph_one(Door, [], fail, _, _), Ball, true),
    graph_cardinality(Ball, 0).
eval_one_graph_case(two_answers_stop_before_third, Door) :-
    catch(graph_one(Door, [], (event(first), Produced=one;
                         event(second), Produced=two;
                         event(third), Produced=three), Produced, _), Ball, true),
    graph_cardinality(Ball, at_least(2)), events([first,second]).
eval_one_graph_case(exception_after_first, Door) :-
    when(nonvar(X), event(wake)),
    catch(graph_one(Door, X, (X=bound, Produced=X; event(tail), throw(source_error)),
                    Produced, _), Ball, true),
    must(Ball == source_error), must(var(X)), events([wake,tail]),
    X=later, events([wake,tail,wake]).
eval_one_graph_case(cleanup_after_failure_tail, Door) :-
    when(nonvar(X), event(wake)),
    graph_one(Door, X,
              setup_call_cleanup(event(setup),
                                 (X=bound, Produced=X; event(tail), fail),
                                 event(cleanup)), Produced, Out),
    must(X == bound), must(Out == bound), events([setup,wake,tail,cleanup]).
eval_one_graph_case(cleanup_on_second_answer, Door) :-
    catch(graph_one(Door, [], setup_call_cleanup(event(setup),
                        (event(first), Produced=one;
                         event(second), Produced=two;
                         event(third), Produced=three), event(cleanup)),
                    Produced, _), Ball, true),
    graph_cardinality(Ball, at_least(2)), events([setup,first,second,cleanup]).
eval_one_graph_case(cleanup_exception, Door) :-
    catch(graph_one(Door, [], setup_call_cleanup(event(setup),
                        (Produced=one; event(tail), fail),
                        (event(cleanup), throw(cleanup_error))), Produced, _),
          Ball, true),
    must(Ball == cleanup_error), events([setup,tail,cleanup]).
eval_one_graph_case(outer_transaction_visibility, Door) :-
    setup_call_cleanup(true,
        ( transaction((assertz(observed(entry)),
                       graph_one(Door, [], (observed(entry), assertz(observed(source)),
                                      Produced=done; fail), Produced, Out),
                       must(Out == done), must(observed(source)))),
          must(observed(entry)), must(observed(source)) ),
        retractall(observed(_))).
eval_one_graph_case(outer_transaction_rollback, Door) :-
    must(\+ transaction((assertz(observed(entry)),
                         graph_one(Door, [], (observed(entry), assertz(observed(source)),
                                        Produced=done; fail), Produced, _), fail))),
    must(\+ observed(_)).
eval_one_graph_case(engine_yield_and_resume, Door) :-
    setup_call_cleanup(
        engine_create(answer(Out),
                      graph_one(Door, [], (engine_yield(paused), Produced=done; fail),
                                Produced, Out), Engine),
        ( must(engine_next(Engine, paused)),
          must(engine_next(Engine, answer(done))),
          must(\+ engine_next(Engine, _)) ),
        engine_destroy(Engine)).

:- end_tests(eval_one_graph).
