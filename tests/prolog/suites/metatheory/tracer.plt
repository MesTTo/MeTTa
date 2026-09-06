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

test(function_defined_in_source_is_traced,
     [setup(setup_trace_test), cleanup(cleanup_trace_test)]) :-
    Source = "(= (plunit_trace_new $x) (+ $x 1))\n\
!(plunit_trace_new 1)",
    tracer:metta_trace_source(Source, '&self', Events),
    Events == [event(0, call, [plunit_trace_new, 1], '', []),
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
    Events == [event(0, call, [plunit_trace_named, 1], '', []),
               event(0, exit, [plunit_trace_named, 1], 2, [])].

test(hyperpose_workers_share_the_trace_event_store,
     [setup(setup_trace_test), cleanup(cleanup_trace_test)]) :-
    process_metta_string("(= (plunit_trace_hyperpose $x) (+ $x 1))", _),
    tracer:metta_trace_source(
        "!(hyperpose ((plunit_trace_hyperpose 1) (plunit_trace_hyperpose 2)))",
        '&self', Events),
    msort(Events, Sorted),
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
    Events == [event(0, call, ['get-type', plunit_trace_type], '', []),
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
    Events == [event(0, call, [plunit_trace_new, '$notvar'], '', []),
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
    Events == [event(0, call, [plunit_trace_new, 'semi;colon'], '', []),
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
    Bounded == [event(0, call, [plunit_trace_hyperpose, 1], '', [])],
    \+ tracer:metta_trace_session,
    \+ current_predicate_wrapper(user:plunit_trace_hyperpose(_, _),
                                  metta_tracer, _, _),
    tracer:metta_trace_source("!(plunit_trace_hyperpose 2)", '&self', Events),
    Events == [event(0, call, [plunit_trace_hyperpose, 2], '', []),
               event(0, exit, [plunit_trace_hyperpose, 2], 3, [])].

%A trace that fits its bound says so, which is the other half: `Stopped`
%is what a caller reads to know whether the events are all of them.
test(a_trace_inside_its_bound_is_not_truncated,
     [setup(setup_trace_test), cleanup(cleanup_trace_test)]) :-
    process_metta_string("(= (plunit_trace_hyperpose $x) (+ $x 1))", _),
    tracer:metta_trace_source("!(plunit_trace_hyperpose 3)", '&self', 1000,
                              Events, Stopped),
    Stopped == false,
    Events == [event(0, call, [plunit_trace_hyperpose, 3], '', []),
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
    append(Prefix, _, Whole).

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
        bounded(100000, run_bounds(-1, Budget, -1)), Prefix, Stopped),
    Stopped == inferences,
    length(Prefix, Cut),
    Cut > 0,
    Cut < Full,
    append(Prefix, _, Whole).

test(filter_precedes_the_bound_and_keeps_depth,
     [setup(setup_trace_test), cleanup(cleanup_trace_test)]) :-
    Source = "(= (plunit_trace_new $x) (plunit_trace_walk $x)) \c
              (= (plunit_trace_walk $x) (+ $x 1)) !(plunit_trace_new 2)",
    tracer:metta_trace_source(Source, '&self', 2, [plunit_trace_walk],
                              Events, false),
    Events == [event(1, call, [plunit_trace_walk, 2], '', []),
               event(1, exit, [plunit_trace_walk, 2], 3, [])],
    tracer:metta_trace_source("!(plunit_trace_new 2)", '&self', 100, Whole, false),
    include(selected_walk_event, Whole, Expected),
    Events == Expected.

selected_walk_event(event(_, _, [plunit_trace_walk|_], _, _)).

test(empty_filter_runs_source_and_does_not_leak,
     [setup(setup_trace_test), cleanup(cleanup_trace_test)]) :-
    Source = "(= (plunit_trace_new $x) (+ $x 1)) !(plunit_trace_new 2)",
    tracer:metta_trace_source(Source, '&self', 1, [], [], false),
    tracer:metta_trace_source("!(plunit_trace_new 4)", '&self', Events),
    Events == [event(0, call, [plunit_trace_new, 4], '', []),
               event(0, exit, [plunit_trace_new, 4], 5, [])].

test(filter_request_crosses_the_existing_host_door,
     [setup(setup_trace_test), cleanup(cleanup_trace_test)]) :-
    Source = "(= (plunit_trace_new $x) (+ $x 1)) !(plunit_trace_new 2)",
    tracer:metta_trace_source(Source, '&self', [2, ["plunit_trace_new"]],
                              Events, false),
    Events == [event(0, call, [plunit_trace_new, 2], '', []),
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
    assertion(Again == [event(0, call, [plunit_trace_leak, 1], '', []),
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
    tracer:metta_debug_begin([]),
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
    assertion(Again == [event(0, call, [plunit_trace_leak, 1], '', []),
                        event(0, exit, [plunit_trace_leak, 1], 42, [])]).

%The debug session's own contract, on the transport's side of the seam: the
%engine holds a suspended program, a yield answers the host and a post
%carries the command back, and the wrappers stay on until the session ends.
%The transport that creates the engine is the shim's, so this drives the
%three published services directly.
debug_engine(Source, Armed, Engine) :-
    tracer:metta_debug_begin(Armed),
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
    First = the(stop(1, call, [plunit_trace_inner, 1], '', [])),
    engine_post(Engine, resume(run, [plunit_trace_inner])),
    engine_next_reified(Engine, Second),
    Second = the(stop(1, exit, [plunit_trace_inner, 1], 2, [])),
    %Stepping stops at the very next reduction, which no breakpoint names.
    engine_post(Engine, resume(step, [])),
    engine_next_reified(Engine, Third),
    Third = the(stop(1, call, [plunit_trace_inner, 2], '', [])),
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
    tracer:metta_debug_begin([plunit_trace_inner]),
    catch(tracer:metta_debug_begin([]), Error, true),
    Error = error(permission_error(debug, evaluation, nested), _),
    catch(tracer:metta_trace_source("!(plunit_trace_inner 1)", '&self', _),
          TraceError, true),
    TraceError = error(permission_error(trace, evaluation, nested), _),
    tracer:metta_debug_end.

:- end_tests(tracer).
