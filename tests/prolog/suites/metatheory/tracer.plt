% Purpose: verify tracing follows functions created by traced source and
%   records calls made by hyperpose worker threads.
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(tracer).

cleanup_trace_function(F) :-
    findall(Ref,
            ( filereader:translated_from(Ref, [=, [F|_], _]),
              \+ clause_property(Ref, erased) ),
            Refs),
    forall(member(Ref, Refs),
           ( erase(Ref), retractall(filereader:translated_from(Ref, _)) )),
    remove_sexp('&self', [=, [F|_], _]),
    user:clear_fun_meta(_, F),
    retractall(user:arity(F, _)),
    retractall(user:fun(F)),
    user:unregister_fun_everywhere(F).

setup_trace_test :-
    retractall(user:silent(_)),
    assertz(user:silent(true)),
    cleanup_trace_function(plunit_trace_new),
    cleanup_trace_function(plunit_trace_named),
    retractall(user:'&plunit_trace_named'(=,
                                          [plunit_trace_named|_], _)),
    cleanup_trace_function(plunit_trace_inner),
    cleanup_trace_function(plunit_trace_outer),
    cleanup_trace_function(plunit_trace_hyperpose),
    cleanup_trace_function(plunit_trace_walk),
    catch(tracer:metta_debug_end, _, true).

cleanup_trace_test :-
    cleanup_trace_function(plunit_trace_new),
    cleanup_trace_function(plunit_trace_named),
    cleanup_trace_function(plunit_trace_hyperpose),
    cleanup_trace_function(plunit_trace_walk),
    retractall(user:'&plunit_trace_named'(=,
                                          [plunit_trace_named|_], _)),
    catch(tracer:metta_debug_end, _, true),
    retractall(user:silent(_)),
    assertz(user:silent(false)).

%The fields a test pins by hand. The other two are checked by their own tests:
%a sequence number is the event's position in this very list, and a time is a
%clock reading no expectation can spell.
trace_shape(event(_, _, Depth, Kind, Term, Answer, Names),
            event(Depth, Kind, Term, Answer, Names)).

trace_shapes(Events, Shapes) :- maplist(trace_shape, Events, Shapes).

test(function_defined_in_source_is_traced,
     [setup(setup_trace_test), cleanup(cleanup_trace_test)]) :-
    Source = "(= (plunit_trace_new $x) (+ $x 1))\n\
!(plunit_trace_new 1)",
    tracer:metta_trace_source(Source, '&self', Events),
    trace_shapes(Events, Shapes),
    Shapes == [event(0, call, [plunit_trace_new, 1], '', []),
               event(0, exit, [plunit_trace_new, 1], 2, [])].

test(function_defined_in_named_trace_stays_in_that_space,
     [setup(setup_trace_test), cleanup(cleanup_trace_test)]) :-
    Space = '&plunit_trace_named',
    Source = "(= (plunit_trace_named $x) (+ $x 1))\n\
!(plunit_trace_named 1)",
    tracer:metta_trace_source(Source, Space, Events),
    space_module(Space, Module),
    functor(Head, plunit_trace_named, 2),
    clause(Module:Head, _, Ref),
    clause_property(Ref, module(Module)),
    \+ clause(user:Head, _, _),
    trace_shapes(Events, Shapes),
    Shapes == [event(0, call, [plunit_trace_named, 1], '', []),
               event(0, exit, [plunit_trace_named, 1], 2, [])].

test(hyperpose_workers_share_the_trace_event_store,
     [setup(setup_trace_test), cleanup(cleanup_trace_test)]) :-
    process_metta_string("(= (plunit_trace_hyperpose $x) (+ $x 1))", _),
    tracer:metta_trace_source(
        "!(hyperpose ((plunit_trace_hyperpose 1) (plunit_trace_hyperpose 2)))",
        '&self', Events),
    trace_shapes(Events, Shapes),
    msort(Shapes, Sorted),
    msort([event(0, call, [plunit_trace_hyperpose, 1], '', []),
           event(0, call, [plunit_trace_hyperpose, 2], '', []),
           event(0, exit, [plunit_trace_hyperpose, 1], 2, []),
           event(0, exit, [plunit_trace_hyperpose, 2], 3, [])],
          Expected),
    Sorted == Expected.

cleanup_trace_type_extension :-
    findall(Ref,
            ( filereader:translated_from(
                  Ref,
                  [=, ['get-type', plunit_trace_type], _]),
              \+ clause_property(Ref, erased) ),
            Refs),
    forall(member(Ref, Refs),
           ( erase(Ref), retractall(filereader:translated_from(Ref, _)) )),
    remove_sexp('&self', [=, ['get-type', plunit_trace_type], _]),
    retractall(user:get_type_rule(plunit_trace_type, _)),
    drop_fun_meta(_, 'get-type', [plunit_trace_type], plunit_traced_type),
    unregister_fun_in(user, 'get-type').

test(type_extensions_keep_the_public_name,
     [ setup(cleanup_trace_type_extension),
       cleanup(cleanup_trace_type_extension) ]) :-
    Source = "(= (get-type plunit_trace_type) plunit_traced_type)\n\
!(get-type plunit_trace_type)",
    tracer:metta_trace_source(Source, '&self', Events),
    trace_shapes(Events, Shapes),
    Shapes == [event(0, call, ['get-type', plunit_trace_type], '', []),
               event(0, exit, ['get-type', plunit_trace_type],
                     plunit_traced_type, [])].

%The events carried the term's text and the reader parsed it back, so a
%symbol whose spelling reads as something else arrived as something else.
%A stored (holds $notvar) traced as a variable, a semicolon truncated the
%rest of the term at the comment it starts, and a tab inside a symbol
%split the record into the wrong fields.
%In source $notvar is a variable, so the symbol of that spelling can only
%arrive from a store or from a host, which is where it used to be lost.
test(a_symbol_that_looks_like_a_variable_stays_a_symbol,
     [ setup(setup_trace_test),
       cleanup(( remove_sexp('&self', [plunit_trace_holds, _]),
                 cleanup_trace_test )) ]) :-
    process_metta_string("(= (plunit_trace_new $x) $x)", _),
    'add-atom'('&self', [plunit_trace_holds, '$notvar'], _),
    tracer:metta_trace_source(
        "!(match &self (plunit_trace_holds $v) (plunit_trace_new $v))",
        '&self', Events),
    trace_shapes(Events, Shapes),
    Shapes == [event(0, call, [plunit_trace_new, '$notvar'], '', []),
               event(0, exit, [plunit_trace_new, '$notvar'],
                     '$notvar', [])].

%A semicolon cannot be written in source, where it starts a comment, so
%the symbol is stored and reached through a match.
test(a_symbol_holding_a_comment_character_stays_whole,
     [ setup(setup_trace_test),
       cleanup(( remove_sexp('&self', [plunit_trace_holds, _]),
                 cleanup_trace_test )) ]) :-
    process_metta_string("(= (plunit_trace_new $x) $x)", _),
    'add-atom'('&self', [plunit_trace_holds, 'semi;colon'], _),
    tracer:metta_trace_source(
        "!(match &self (plunit_trace_holds $v) (plunit_trace_new $v))",
        '&self', Events),
    trace_shapes(Events, Shapes),
    Shapes == [event(0, call, [plunit_trace_new, 'semi;colon'], '', []),
               event(0, exit, [plunit_trace_new, 'semi;colon'],
                     'semi;colon', [])].

%The bound TRUNCATES rather than raising, and this test's own subject is
%what happens afterwards: the session ends and every wrapper comes off,
%which used to be reachable only through the exception path. Reaching the
%bound answers the events recorded so far, so the prefix is asserted here
%too -- a bound that discarded them charged their memory for nothing, which
%is what it did until 2026-09-03.
test(event_limit_truncates_and_removes_every_wrapper,
     [setup(setup_trace_test), cleanup(cleanup_trace_test)]) :-
    process_metta_string("(= (plunit_trace_hyperpose $x) (+ $x 1))", _),
    tracer:metta_trace_source("!(plunit_trace_hyperpose 1)", '&self', 1,
                              Bounded, Stopped),
    Stopped == events,
    trace_shapes(Bounded, BoundedShapes),
    BoundedShapes == [event(0, call, [plunit_trace_hyperpose, 1], '', [])],
    \+ tracer:metta_trace_session,
    \+ current_predicate_wrapper(user:plunit_trace_hyperpose(_, _),
                                  metta_tracer, _, _),
    tracer:metta_trace_source("!(plunit_trace_hyperpose 2)", '&self', Events),
    trace_shapes(Events, Shapes),
    Shapes == [event(0, call, [plunit_trace_hyperpose, 2], '', []),
               event(0, exit, [plunit_trace_hyperpose, 2], 3, [])].

%A trace that fits its bound says so, which is the other half: `Stopped`
%is what a caller reads to know whether the events are all of them.
test(a_trace_inside_its_bound_is_not_truncated,
     [setup(setup_trace_test), cleanup(cleanup_trace_test)]) :-
    process_metta_string("(= (plunit_trace_hyperpose $x) (+ $x 1))", _),
    tracer:metta_trace_source("!(plunit_trace_hyperpose 3)", '&self', 1000,
                              Events, Stopped),
    Stopped == false,
    trace_shapes(Events, Shapes),
    Shapes == [event(0, call, [plunit_trace_hyperpose, 3], '', []),
               event(0, exit, [plunit_trace_hyperpose, 3], 4, [])].

%A RUN bound stops the recording too, and answers the prefix rather than
%letting the exception carry the events off with it. The guard is left
%reporting success, which is what tells the seat above to read the answer
%instead of classifying an exception, and the events kept are a genuine
%prefix of the unbounded run.
%
%The budget is half what the unbounded trace cost rather than a number
%written here, so the test follows the engine instead of going stale.
test(a_run_bound_answers_the_prefix_it_recorded,
     [setup(setup_trace_test), cleanup(cleanup_trace_test)]) :-
    process_metta_string(
        "(= (plunit_trace_walk $n) \c
             (if (> $n 0) (plunit_trace_walk (- $n 1)) done))", _),
    statistics(inferences, Before),
    tracer:metta_trace_source("!(plunit_trace_walk 300)", '&self', 100000,
                              Whole, false),
    statistics(inferences, After),
    Budget is (After - Before) // 2,
    length(Whole, Full),
    Full > 20,
    call_with_inference_limit(
        tracer:metta_trace_source("!(plunit_trace_walk 300)", '&self', 100000,
                                  Prefix, Stopped),
        Budget, Result),
    Result == (!),
    Stopped == inferences,
    length(Prefix, Cut),
    Cut > 0,
    Cut < Full,
    %By SHAPE, because the two runs happened at different times and an event
    %carries when it happened.
    trace_shapes(Prefix, PrefixShapes),
    trace_shapes(Whole, WholeShapes),
    append(PrefixShapes, _, WholeShapes).

%A bound sent INSIDE the request bounds the program, not the door. Arming the
%tracer walks every name in arity/2 and the teardown unwraps them again, and
%while a caller's guard around the whole door paid for both, the same budget
%answered fewer and fewer events as the process registered more names --
%twelve inferences per name, and none at all under a whole test suite in one
%process [measured 2026-09-07]. Here the budget is a fraction of what the
%PROGRAM costs and the door's own cost is measured, warm, and left out of it.
test(a_bounded_request_bounds_the_program_and_not_the_arming,
     [setup(setup_trace_test), cleanup(cleanup_trace_test)]) :-
    process_metta_string(
        "(= (plunit_trace_bounded $n) \c
             (if (> $n 0) (plunit_trace_bounded (- $n 1)) done))", _),
    tracer:metta_trace_source("!(plunit_trace_bounded 0)", '&self', 100000,
                              _, false),
    statistics(inferences, DoorBefore),
    tracer:metta_trace_source("!(plunit_trace_bounded 0)", '&self', 100000,
                              _, false),
    statistics(inferences, DoorAfter),
    Door is DoorAfter - DoorBefore,
    statistics(inferences, WholeBefore),
    tracer:metta_trace_source("!(plunit_trace_bounded 300)", '&self', 100000,
                              Whole, false),
    statistics(inferences, WholeAfter),
    Budget is (WholeAfter - WholeBefore - Door) // 2,
    length(Whole, Full),
    Full > 20,
    tracer:metta_trace_source(
        "!(plunit_trace_bounded 300)", '&self',
        bounded(100000, run_bounds(-1, Budget, -1, -1)), Prefix, Stopped),
    Stopped == inferences,
    length(Prefix, Cut),
    Cut > 0,
    Cut < Full,
    %By SHAPE, because the two runs happened at different times and an event
    %carries when it happened.
    trace_shapes(Prefix, PrefixShapes),
    trace_shapes(Whole, WholeShapes),
    append(PrefixShapes, _, WholeShapes).

test(filter_precedes_the_bound_and_keeps_depth,
     [setup(setup_trace_test), cleanup(cleanup_trace_test)]) :-
    Source = "(= (plunit_trace_new $x) (plunit_trace_walk $x)) \c
              (= (plunit_trace_walk $x) (+ $x 1)) !(plunit_trace_new 2)",
    tracer:metta_trace_source(Source, '&self', 2, [plunit_trace_walk],
                              Events, false),
    trace_shapes(Events, Shapes),
    Shapes == [event(1, call, [plunit_trace_walk, 2], '', []),
               event(1, exit, [plunit_trace_walk, 2], 3, [])],
    tracer:metta_trace_source("!(plunit_trace_new 2)", '&self', 100, Whole, false),
    include(selected_walk_event, Whole, Selected),
    trace_shapes(Selected, Expected),
    Shapes == Expected.

selected_walk_event(event(_, _, _, _, [plunit_trace_walk|_], _, _)).

test(empty_filter_runs_source_and_does_not_leak,
     [setup(setup_trace_test), cleanup(cleanup_trace_test)]) :-
    Source = "(= (plunit_trace_new $x) (+ $x 1)) !(plunit_trace_new 2)",
    tracer:metta_trace_source(Source, '&self', 1, [], [], false),
    tracer:metta_trace_source("!(plunit_trace_new 4)", '&self', Events),
    trace_shapes(Events, Shapes),
    Shapes == [event(0, call, [plunit_trace_new, 4], '', []),
               event(0, exit, [plunit_trace_new, 4], 5, [])].

test(filter_request_crosses_the_existing_host_door,
     [setup(setup_trace_test), cleanup(cleanup_trace_test)]) :-
    Source = "(= (plunit_trace_new $x) (+ $x 1)) !(plunit_trace_new 2)",
    tracer:metta_trace_source(Source, '&self', [2, ["plunit_trace_new"]],
                              Events, false),
    trace_shapes(Events, Shapes),
    Shapes == [event(0, call, [plunit_trace_new, 2], '', []),
               event(0, exit, [plunit_trace_new, 2], 3, [])].

test(invalid_filter_refuses_with_remedy,
     [throws(error(domain_error(trace_function_filter, [42]),
                   context(metta_trace_source/6, _)))]) :-
    tracer:metta_trace_source("", '&self', 100, [42], _, _).

test(variable_filter_does_not_unify_to_all,
     [throws(error(domain_error(trace_function_filter, _), _))]) :-
    tracer:metta_trace_source("", '&self', 100, _, _, _).

%The same two equations in &self and in a second space, so both modules compile
%their own predicates and both are wrapped when a trace arms.
setup_trace_leak(Box) :-
    setup_trace_test,
    cleanup_trace_function(plunit_trace_leak),
    cleanup_trace_function(plunit_trace_clear),
    'new-space'(Box),
    trace_leak_program(Program),
    process_metta_string(Program, _),
    process_metta_string(Program, _, Box).

trace_leak_program("(= (plunit_trace_leak $x) 42)\n\
(= (plunit_trace_clear $s) (collapse (match $s $x (remove-atom $s $x))))\n\
!(plunit_trace_leak 1)").

%The tracer is disarmed FIRST, so a failure here costs this test rather than
%every trace test after it. Through ignore/1 because the teardown is the thing
%under test: on a tree where it still fails, a cleanup that failed with it would
%report the cleanup rather than the assertions that name the defect.
cleanup_trace_leak(Box) :-
    ignore(catch(tracer:metta_trace_end, _, true)),
    catch(metta_release_space(Box), _, true),
    cleanup_trace_function(plunit_trace_leak),
    cleanup_trace_function(plunit_trace_clear),
    cleanup_trace_test.

%A traced program that clears the second space abolishes that space's copies,
%and the shadow repair imports &self's in their place, so the recorded child
%targets start denoting the PARENT's procedures and unwrapping them removes the
%parents' wrappers. The parents' own recorded targets then find nothing to
%remove, and unwrap_predicate/2 FAILS rather than raising there. The failure
%used to stop maplist/2 before metta_trace_end_unlocked/0 retracted anything,
%leaving session=yes and four wrapped targets standing, after which every trace
%on the engine refused [measured 2026-09-05 on the same fixture: two targets at
%arm, four recorded at teardown, and the second trace below raised
%permission_error(trace, evaluation, nested)].
test(a_trace_that_abolishes_a_wrapped_predicate_leaves_the_tracer_disarmed,
     [setup(setup_trace_leak(Box)), cleanup(cleanup_trace_leak(Box))]) :-
    format(atom(Source), "!(plunit_trace_clear ~w)", [Box]),
    tracer:metta_trace_source(Source, '&self', 1000, _Cleared),
    assertion(\+ tracer:metta_trace_session),
    assertion(\+ tracer:metta_trace_wrapped(_)),
    tracer:metta_trace_source("!(plunit_trace_leak 1)", '&self', 1000, Again),
    trace_shapes(Again, AgainShapes),
    assertion(AgainShapes == [event(0, call, [plunit_trace_leak, 1], '', []),
                              event(0, exit, [plunit_trace_leak, 1], 42, [])]).

%The debug twin of the leak above, because a breakpoint session takes the same
%wrappers and would leave them the same way. metta_debug_end_unlocked/0 calls
%the trace's teardown rather than listing the state again, so this is that
%totality asserted through the other door: on a tracer whose unwrap sweep still
%stopped at the first already-removed target, the session flag would stand and
%every later session on the engine would refuse.
test(a_debug_session_that_abolishes_a_wrapped_predicate_leaves_the_tracer_disarmed,
     [setup(setup_trace_leak(Box)), cleanup(cleanup_trace_leak(Box))]) :-
    format(atom(Source), "!(plunit_trace_clear ~w)", [Box]),
    tracer:metta_debug_begin([], -1),
    engine_create(done(Groups),
                  tracer:metta_debug_run(Source, '&self', Groups),
                  Engine),
    engine_next_reified(Engine, Event),
    assertion(Event = the(done(_))),
    engine_destroy(Engine),
    tracer:metta_debug_end,
    assertion(\+ tracer:metta_trace_session),
    assertion(\+ tracer:metta_trace_wrapped(_)),
    assertion(\+ tracer:metta_debug_mode(_)),
    %The engine still arms, which is what the leak took away.
    tracer:metta_trace_source("!(plunit_trace_leak 1)", '&self', 1000, Again),
    trace_shapes(Again, AgainShapes),
    assertion(AgainShapes == [event(0, call, [plunit_trace_leak, 1], '', []),
                              event(0, exit, [plunit_trace_leak, 1], 42, [])]).

%The debug session's own contract, on the transport's side of the seam: the
%engine holds a suspended program, a yield answers the host and a post
%carries the command back, and the wrappers stay on until the session ends.
%The transport that creates the engine is the shim's, so this drives the
%three published services directly.
debug_engine(Source, Armed, Engine) :-
    debug_engine(Source, Armed, -1, Engine).

debug_engine(Source, Armed, Count, Engine) :-
    tracer:metta_debug_begin(Armed, Count),
    engine_create(done(Groups), tracer:metta_debug_run(Source, '&self', Groups),
                  Engine).

test(a_breakpoint_suspends_the_program_and_a_post_resumes_it,
     [setup(setup_trace_test), cleanup(cleanup_trace_test)]) :-
    process_metta_string("(= (plunit_trace_inner $x) (+ $x 1))", _),
    process_metta_string(
        "(= (plunit_trace_outer $x) (plunit_trace_inner (plunit_trace_inner $x)))",
        _),
    debug_engine("!(plunit_trace_outer 1)", [plunit_trace_inner], Engine),
    engine_next_reified(Engine, First),
    First = the(stop(_, _, 1, call, [plunit_trace_inner, 1], '', [])),
    engine_post(Engine, resume(run, [plunit_trace_inner])),
    engine_next_reified(Engine, Second),
    Second = the(stop(_, _, 1, exit, [plunit_trace_inner, 1], 2, [])),
    %Stepping stops at the very next reduction, which no breakpoint names.
    engine_post(Engine, resume(step, [])),
    engine_next_reified(Engine, Third),
    Third = the(stop(_, _, 1, call, [plunit_trace_inner, 2], '', [])),
    %And with nothing armed and no step, the program runs to its answer.
    engine_post(Engine, resume(run, [])),
    engine_next_reified(Engine, Fourth),
    Fourth = the(done(_)),
    engine_destroy(Engine),
    tracer:metta_debug_end,
    \+ current_predicate_wrapper(user:plunit_trace_inner(_, _),
                                 metta_tracer, _, _).

%A session and a trace take the same wrappers, so the second to ask is
%refused rather than quietly sharing them.
test(a_session_refuses_a_second_one,
     [setup(setup_trace_test), cleanup(cleanup_trace_test)]) :-
    process_metta_string("(= (plunit_trace_inner $x) (+ $x 1))", _),
    tracer:metta_debug_begin([plunit_trace_inner], -1),
    catch(tracer:metta_debug_begin([], -1), Error, true),
    Error = error(permission_error(debug, evaluation, nested), _),
    catch(tracer:metta_trace_source("!(plunit_trace_inner 1)", '&self', _),
          TraceError, true),
    TraceError = error(permission_error(trace, evaluation, nested), _),
    tracer:metta_debug_end.

%%%%%%%%%% The three ports, the two new fields, and the seed %%%%%%%%%%

%A reduction that answers nothing reaches the fail port. It used to leave a
%call with no exit, which a consumer had to infer from the NEXT event's depth
%and could not infer at all for the last call of a run.
test(a_reduction_that_answers_nothing_records_a_fail_port,
     [setup(setup_trace_test), cleanup(cleanup_trace_test)]) :-
    Source = "(= (plunit_trace_new 1) yes)\n!(plunit_trace_new 2)",
    tracer:metta_trace_source(Source, '&self', Events),
    trace_shapes(Events, Shapes),
    Shapes == [event(0, call, [plunit_trace_new, 2], '', []),
               event(0, fail, [plunit_trace_new, 2], '', [])].

%And a reduction that answered is NOT also reported as failing when its
%answers run out, which is where SWI's own port wrapper differs: it fires
%`fail` on exhaustion, after however many exits, because it reports the Byrd
%box rather than the outcome.
test(an_answered_reduction_records_no_fail_port,
     [setup(setup_trace_test), cleanup(cleanup_trace_test)]) :-
    Source = "(= (plunit_trace_new $x) a)\n(= (plunit_trace_new $x) b)\n\
!(plunit_trace_new 1)",
    tracer:metta_trace_source(Source, '&self', Events),
    trace_shapes(Events, Shapes),
    Shapes == [event(0, call, [plunit_trace_new, 1], '', []),
               event(0, exit, [plunit_trace_new, 1], a, []),
               event(0, exit, [plunit_trace_new, 1], b, [])].

%Every event numbers itself and dates itself, and both run forward.
test(events_carry_a_monotone_sequence_and_time,
     [setup(setup_trace_test), cleanup(cleanup_trace_test)]) :-
    Source = "(= (plunit_trace_new $x) (plunit_trace_walk $x))\n\
(= (plunit_trace_walk $x) (+ $x 1))\n!(plunit_trace_new 2)",
    tracer:metta_trace_source(Source, '&self', Events),
    findall(Seq, member(event(Seq, _, _, _, _, _, _), Events), Seqs),
    length(Events, Count),
    Last is Count - 1,
    numlist(0, Last, Seqs),
    findall(Time, member(event(_, Time, _, _, _, _, _), Events), Times),
    forall(member(Time, Times), integer(Time)),
    msort(Times, Times).

%A seeded run draws the same numbers twice and leaves the generator where it
%found it, which is what makes a recorded run replayable.
test(a_seeded_run_repeats_its_draws_and_leaves_the_outside_alone,
     [setup(setup_trace_test), cleanup(cleanup_trace_test)]) :-
    process_metta_string(
        "(= (plunit_trace_new $x) (random-int 1 1000000))", _),
    random_property(state(Before)),
    tracer:metta_trace_source(
        "!(plunit_trace_new 1)", '&self',
        bounded(100, run_bounds(-1, -1, -1, 7)), First, false),
    tracer:metta_trace_source(
        "!(plunit_trace_new 1)", '&self',
        bounded(100, run_bounds(-1, -1, -1, 7)), Second, false),
    trace_shapes(First, FirstShapes),
    trace_shapes(Second, SecondShapes),
    FirstShapes == SecondShapes,
    memberchk(event(0, exit, _, Drawn, []), FirstShapes),
    integer(Drawn),
    random_property(state(After)),
    Before == After.

%%%%%%%%%% A library's dispatcher, made visible %%%%%%%%%%

%The memo binds a call site to a lookup of its own, so the wrapper on the
%FUNCTION never runs for a call the cache answers: `!(fib 8)` under the
%automatic memo recorded 0 events over 23,050 inferences [measured 2026-09-07].
%The dispatcher declares itself through seam:interposed_dispatch/4 and the
%reduction is recorded once, by whichever layer the call entered first, so a
%hit is a call with its answer and no children and a miss is the whole
%reduction underneath.
test(a_memoised_head_records_its_calls_once,
     [setup(setup_trace_memo), cleanup(cleanup_trace_memo)]) :-
    Source = "!(plunit_trace_memo 4)",
    tracer:metta_trace_source(Source, '&self', 1000, Cold),
    trace_shapes(Cold, ColdShapes),
    %Every distinct argument reduces once and every repeat is answered from
    %the cache, so each call has exactly one exit and no call is recorded
    %twice at the same depth for the same term.
    findall(Term,
            member(event(_, call, Term, _, _), ColdShapes), Calls),
    findall(Term,
            member(event(_, exit, Term, _, _), ColdShapes), Exits),
    length(Calls, Same),
    length(Exits, Same),
    Same > 4,
    memberchk([plunit_trace_memo, 4], Calls),
    memberchk([plunit_trace_memo, 0], Calls),
    %A second trace over a WARM cache records the one call it makes.
    tracer:metta_trace_source(Source, '&self', 1000, Warm),
    trace_shapes(Warm, WarmShapes),
    WarmShapes == [event(0, call, [plunit_trace_memo, 4], '', []),
                   event(0, exit, [plunit_trace_memo, 4], 3, [])],
    %And forgetting what the libraries derived puts the run back where the
    %first one started, which is what a replay of a recording needs.
    metta_forget_derived,
    tracer:metta_trace_source(Source, '&self', 1000, Again),
    trace_shapes(Again, AgainShapes),
    AgainShapes == ColdShapes.

setup_trace_memo :-
    setup_trace_test,
    cleanup_trace_function(plunit_trace_memo),
    process_metta_string(
        "(= (plunit_trace_memo $n) (if (< $n 2) $n \c
(+ (plunit_trace_memo (- $n 1)) (plunit_trace_memo (- $n 2)))))", _).

cleanup_trace_memo :-
    catch(metta_forget_derived, _, true),
    cleanup_trace_function(plunit_trace_memo),
    cleanup_trace_test.

%%%%%%%%%% The count breakpoint %%%%%%%%%%

%A COUNT is the third kind of breakpoint, and the one a recording needs: it
%stops at the event with that sequence number, which is how replaying a
%recorded run to one of its events becomes a live session.
test(a_count_breakpoint_stops_at_that_event,
     [setup(setup_trace_test), cleanup(cleanup_trace_test)]) :-
    process_metta_string("(= (plunit_trace_inner $x) (+ $x 1))", _),
    process_metta_string(
        "(= (plunit_trace_outer $x) (plunit_trace_inner (plunit_trace_inner $x)))",
        _),
    Source = "!(plunit_trace_outer 1)",
    tracer:metta_trace_source(Source, '&self', 1000, Events),
    nth0(2, Events, event(Seq, _, Depth, Kind, Term, _, _)),
    debug_engine(Source, [], Seq, Engine),
    engine_next_reified(Engine, Stopped),
    Stopped = the(stop(Seq, _, Depth, Kind, Term, _, _)),
    engine_destroy(Engine),
    tracer:metta_debug_end.

%%%%%%%%%% A held OBSERVE session %%%%%%%%%%

%The session a host holds across its OWN calls, which is what instrumentation
%over a block of work needs: one arming, several evaluations, one harvest.
test(a_held_session_records_across_separate_evaluations,
     [setup(setup_trace_test), cleanup(cleanup_trace_test)]) :-
    process_metta_string("(= (plunit_trace_inner $x) (+ $x 1))", _),
    tracer:metta_trace_begin(1000, all, observe),
    tracer:metta_trace_start_clock,
    process_metta_string("!(plunit_trace_inner 1)", _),
    process_metta_string("!(plunit_trace_inner 2)", _),
    tracer:metta_trace_harvest(Stopped, Events),
    tracer:metta_trace_end,
    Stopped == false,
    findall(Kind-Term,
            member(event(_, _, _, Kind, Term, _, _), Events),
            Ports),
    Ports == [call-[plunit_trace_inner, 1], exit-[plunit_trace_inner, 1],
              call-[plunit_trace_inner, 2], exit-[plunit_trace_inner, 2]].

%The whole difference between the two modes. A trace's recording bound stops
%the program with the recording, which is what bounds a traced run's time; an
%observed block's work is the host's, so the bound stops the RECORDING and the
%work finishes.
test(an_observed_blocks_bound_stops_the_recording_and_not_the_work,
     [setup(setup_trace_test), cleanup(cleanup_trace_test)]) :-
    process_metta_string("(= (plunit_trace_inner $x) (+ $x 1))", _),
    process_metta_string(
        "(= (plunit_trace_outer $x) (plunit_trace_inner (plunit_trace_inner $x)))",
        _),
    tracer:metta_trace_begin(2, all, observe),
    tracer:metta_trace_start_clock,
    process_metta_string("!(plunit_trace_outer 1)", Answers),
    tracer:metta_trace_harvest(Stopped, Events),
    tracer:metta_trace_end,
    flatten(Answers, Flat),
    memberchk(3, Flat),
    Stopped == events,
    length(Events, 2).

%And the same bound in the other mode still aborts, which is the property the
%mode exists to keep apart from the one above.
test(a_traced_runs_bound_still_stops_the_run,
     [setup(setup_trace_test), cleanup(cleanup_trace_test)]) :-
    process_metta_string("(= (plunit_trace_inner $x) (+ $x 1))", _),
    process_metta_string(
        "(= (plunit_trace_outer $x) (plunit_trace_inner (plunit_trace_inner $x)))",
        _),
    tracer:metta_trace_source("!(plunit_trace_outer 1)", '&self', 2, Events,
                              Stopped),
    Stopped == events,
    length(Events, 2).

%A held session takes the wrappers, so a trace inside one refuses by the same
%rule a second debug session meets.
test(a_held_session_refuses_a_trace_inside_it,
     [setup(setup_trace_test), cleanup(cleanup_trace_test)]) :-
    process_metta_string("(= (plunit_trace_inner $x) (+ $x 1))", _),
    tracer:metta_trace_begin(1000, all, observe),
    catch(tracer:metta_trace_source("!(plunit_trace_inner 1)", '&self', _),
          Error, true),
    tracer:metta_trace_end,
    Error = error(permission_error(trace, evaluation, nested), _).

%The door validates its own bound and filter before anything is wrapped, so a
%host that holds a session across its own calls cannot arm one it then has to
%tear down.
test(a_held_session_refuses_a_malformed_bound,
     [setup(setup_trace_test), cleanup(cleanup_trace_test)]) :-
    catch(tracer:metta_trace_begin(0, all, observe), Error, true),
    Error = error(domain_error(positive_integer, 0), _),
    catch(tracer:metta_trace_begin(1000, "not a list", observe), Filter, true),
    Filter = error(domain_error(trace_function_filter, _), _),
    \+ tracer:metta_trace_session.

:- end_tests(tracer).
