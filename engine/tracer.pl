% Purpose: the reduction trace. metta_trace_source/3 runs MeTTa source
%   with every compiled MeTTa function wrapped by SWI's own
%   wrap_predicate, recording a call event with the input term and an
%   exit event with the answer per reduction, depth-nested through the
%   call tree, then unwraps whole, so tracing costs nothing when off.
%   Events answer as event/7 terms carrying a sequence number, the time,
%   depth, kind, term, answer, and the names of the term's variables.
% Guarantees:
%   - A reduction's outcome is one of three ports: an `exit` per answer, one
%     `fail` when it produced none, or nothing at all when a bound cut the run
%     [tested: tracer:a_reduction_that_answers_nothing_records_a_fail_port,
%     tracer:an_answered_reduction_records_no_fail_port; commit=e54c3654b9e0d3d040560d12c105a54303f63af7].
%   - Every event carries its own sequence number and the wall nanoseconds
%     since the run began, both monotone within one session
%     [tested: tracer:events_carry_a_monotone_sequence_and_time; commit=e54c3654b9e0d3d040560d12c105a54303f63af7].
%   - A library that interposes a predicate between a call site and the
%     function it stands for declares it through seam:interposed_dispatch/4,
%     and the reduction is then recorded ONCE, by whichever layer the call
%     entered first [tested: tracer:a_memoised_head_records_its_calls_once;
%     commit=e54c3654b9e0d3d040560d12c105a54303f63af7].
%   - A run under a seed pins the generator and restores the state in force
%     when it finishes, so a recorded run's draws replay
%     [tested: tracer:a_seeded_run_repeats_its_draws_and_leaves_the_outside_alone;
%     commit=e54c3654b9e0d3d040560d12c105a54303f63af7].
%   - Exact function filters retain execution depth and charge only selected
%     events [tested: tracer:filter_precedes_the_bound_and_keeps_depth;
%     commit=504f8dddfa890ced97e795a13ab10e239b1de2ce].
%   - A DEBUG session suspends the program at a breakpoint through
%     engine_yield/1 and resumes the same execution on the command the host
%     posts back, and only one session, trace or debug, holds the wrappers
%     [tested: tracer:a_breakpoint_suspends_the_program_and_a_post_resumes_it,
%     tracer:a_session_refuses_a_second_one; commit=39dd4c9014bf8c38d78df8c8fdc9c114b372dc1f].
%   - Functions defined by the traced source and calls from hyperpose workers
%     produce events [tested 2026-08-14: tracer].
%   - A symbol whose spelling reads back as something else survives the
%     trip: the trace and run answer the same atom
%     [tested 2026-08-15: tracer:a_symbol_that_looks_like_a_variable_stays_a_symbol].
%   - Traced get-type extensions report their public function name
%     [tested 2026-08-15: tracer:type_extensions_keep_the_public_name].
%   - A registered predicate whose clauses clause/3 refuses, a foreign one or
%     a builtin, is skipped rather than raising out of the whole trace
%     [tested 2026-08-16: test_a_foreign_predicate_does_not_break_tracing].
%   - Every bound that can stop a traced run answers the prefix it recorded
%     and names itself, the recording pair from the recorder and the run
%     triple by catching their balls
%     [tested 2026-09-04: tracer:a_run_bound_answers_the_prefix_it_recorded].
%   - A run bound sent as a `bounded/2` request bounds the PROGRAM: arming the
%     tracer over every name in arity/2 and unwrapping them again costs twelve
%     inferences per name and is not charged to it, so the same budget answers
%     the same prefix whatever else the process has registered
%     [tested: tracer:a_bounded_request_bounds_the_program_and_not_the_arming,
%     test_arming_the_tracer_is_not_charged_to_the_run_bound;
%     commit=59c3cbf1bc269dfa7194f78da34497f1757a9604].
% Owns:
%   - metta_trace_source/4 removes every metta_tracer wrapper and state fact,
%     including after an event-limit error [tested 2026-08-14:
%     tracer:event_limit_truncates_and_removes_every_wrapper].
%   - the teardown is TOTAL. A recorded target whose wrapper is already gone,
%     which is what a traced program that abolishes a wrapped predicate leaves
%     behind, stops neither the rest of the sweep nor the state retractions, so
%     a later trace on the same engine still arms
%     [tested: tracer:a_trace_that_abolishes_a_wrapped_predicate_leaves_the_tracer_disarmed;
%     commit=f5eb8775b78519c080da4ea7c6dff81f7be21ef9].
%   - a DEBUG session's teardown is the trace's, so it is total for the same
%     reason and stays total when the trace's grows: metta_debug_end_unlocked/0
%     calls metta_trace_end_unlocked/0 rather than listing the state again
%     [tested: tracer:a_debug_session_that_abolishes_a_wrapped_predicate_leaves_the_tracer_disarmed;
%     commit=39dd4c9014bf8c38d78df8c8fdc9c114b372dc1f].
% Guarded by:
%   - '$metta_trace_state' serializes trace sessions and wrapper changes
%     [tested 2026-08-14: tracer:event_limit_truncates_and_removes_every_wrapper].
%   - '$metta_trace_events' assigns event sequence numbers and enforces the
%     event bound across hyperpose worker threads [tested 2026-08-14: tracer].
% Decides:
%   - `time` is WALL nanoseconds since the run began, not CPU. SWI's cputime is
%     thread-local, so a hyperpose worker's events would carry times near zero
%     beside the main thread's, and this tracer records worker events by design
%     [tested: tracer:hyperpose_workers_share_the_trace_event_store]. The
%     process-wide clock is the other one monotone across threads, and it costs
%     2.7 to 3.6 times a get_time/1 read, more per event than an event
%     [measured 2026-09-07: swipl -q tests/prolog/probes/tracer/clock_cost.pl,
%     200,000 reads each; 1,713ns against 477 at loadavg 60 and 2,247 against
%     822 at loadavg 88, this box being shared].
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

%Three predicates: what a trace records for a host, and the three questions
%engine/ext_points.pl asks before it wraps a compiled function -- which
%compiled functions to wrap, which interposed dispatchers to wrap beside them,
%and the wrap itself, all three reached from seam:function_clauses_changed/1,
%whose clause is this file's and whose module is the seam's. The event buffer,
%the sequence counter and the wrapper bodies are this subsystem's own
%[tested: engine_layering:test_the_engine_layering_contract_holds_and_a_violation_is_named].
:- module(tracer,
          [ metta_trace_source/4,
            metta_trace_source/5,
            metta_trace_source/6,
            metta_trace_default_events/1,
            metta_trace_target/1,
            metta_trace_interposed_target/1,
            metta_trace_wrap_once/1,
            metta_debug_begin/2,
            metta_debug_run/3,
            metta_debug_end/0
          ]).

%metta_trace_source/4 reads the values off a pairs list. Imported here rather
%than into the engine module, because this is the only file that wants it and a
%module of one's own is what makes that distinction possible to state.
:- use_module(library(pairs), [pairs_values/2]).
%call_with_time_limit/2 arrives through engine/metta.pl's platform census,
%which loads library(time) as the `deadlines` capability and records its
%absence rather than failing to load. Importing it here instead broke the
%WebAssembly seat at boot -- `source_sink library(time) does not exist`, which
%extensions/node refuses to absorb, and every ch21 test with it
%[measured 2026-09-07].

:- meta_predicate
       metta_trace_stack_bound(+, 0),
       metta_trace_time_bound(+, 0),
       metta_trace_inference_bound(+, 0),
       metta_trace_seeded(+, 0),
       metta_trace_ports(+, +, ?, 0),
       metta_trace_interposition(+, 0).

:- dynamic metta_trace_event/2.
:- dynamic metta_trace_limit/1.
:- dynamic metta_trace_next_seq/1.
:- dynamic metta_trace_session/0.
:- dynamic metta_trace_stopped/1.
:- dynamic metta_trace_cells/1.
:- dynamic metta_trace_wrapped/1.
:- dynamic metta_trace_filter/1.
:- dynamic metta_trace_selected/1.
:- dynamic metta_trace_origin/1.

%Every name the translator compiled from equations, in &self's module and in
%each other space module that registered it: exactly the predicates owning at
%least one translated_from-tracked clause. Builtins and imports never do,
%which keeps a trace about the program, not the engine, and keeps the
%wrap away from library predicates a weak import makes visible.
metta_trace_target(Module:F/A) :-
    arity(LogicalF, A),
    ( fun_in(Module, LogicalF) ; metta_self_module(Module) ),
    compiled_function_name(LogicalF, F),
    current_predicate(Module:F/A),
    functor(Head, F, A),
    \+ predicate_property(Module:Head, imported_from(_)),
    %clause/3 REFUSES a predicate it cannot show, raising
    %permission_error(access, private_procedure, _) rather than failing, and a
    %foreign predicate is one of those. Registering a single C extension
    %anywhere in the process therefore made EVERY trace raise
    %`clause/3: No permission to access private_procedure 'c-bump'/2', because
    %this walks every registered arity looking for tracked clauses and reaches
    %the foreign one on the way
    %[tested: test_a_foreign_predicate_does_not_break_tracing].
    %
    %number_of_clauses is the guard rather than a list of kinds to skip: it is
    %true for exactly the predicates clause/3 accepts and false for every one
    %it refuses, foreign and builtin alike [measured 2026-08-16: false for
    %is/2, atom_length/2 and format/2, all three of which raise; true for
    %append/3, which does not].
    predicate_property(Module:Head, number_of_clauses(_)),
    once(( clause(Module:Head, _, Ref),
           clause_property(Ref, module(Module)),
           translated_from(Ref, _) )).

%A predicate a LIBRARY put in front of a function, declared through
%seam:interposed_dispatch/4 and enumerated here with everything unbound. The
%engine knows no library by name, so the set is whatever the loaded ones
%declare; with none loaded this finds nothing and costs one failed call per
%session.
metta_trace_interposed_target(interposed(Module:Head, Fun, InArgs, Out)) :-
    seam:interposed_dispatch(Module:Head, Fun, InArgs, Out),
    functor(Head, Name, Arity),
    current_predicate(Module:Name/Arity).

%The decomposition happens HERE, once per session per target, rather than in
%the wrapper: wrap_predicate/4 builds a clause whose head is this term, so the
%call's own arguments arrive already bound to InArgs and Out, the way any
%clause head binds them. The wrapper it replaced re-derived them with =.. ,
%length/2 and append/3 on every traced call
%[source: /usr/lib/swi-prolog/library/prolog_trace.pl, wrapper/4, which shares
%one head between the wrapped goal and its port calls for the same reason].
metta_trace_wrap(Module:F/A) :-
    functor(Head, F, A),
    compiled_function_name(LogicalF, F),
    In is A - 1,
    length(InArgs, In),
    Head =.. [_|Args],
    append(InArgs, [Out], Args),
    wrap_predicate(Module:Head, metta_tracer, Closure,
                   metta_trace_call(LogicalF, InArgs, Out, Closure)).
metta_trace_wrap(interposed(Module:Head, Fun, InArgs, Out)) :-
    wrap_predicate(Module:Head, metta_tracer, Closure,
                   metta_trace_interposed_call(Fun, InArgs, Out, Closure)).

%Tolerant of BOTH outcomes, and the FAILURE is the one that bites.
%unwrap_predicate/2 is semidet and fails when the indicator names no
%metta_tracer wrapper, which is what a traced program that abolishes a wrapped
%predicate produces: clear_generated_predicate/3 abolishes the child module's
%copy and metta_restore_inherited_predicate/3 imports the parent's, so the
%child's recorded indicator starts denoting the PARENT's procedure and removes
%ITS wrapper, and the parent's own recorded target then finds nothing left to
%remove. The catch alone let that failure through maplist/2 in
%metta_trace_end_unlocked/0, which never reached its nine retractalls, so the
%session flag stayed asserted; metta_trace_source/6 runs the teardown as a
%cleanup, whose failure is not reported, so the trace answered normally and
%every later trace on that engine refused with
%permission_error(trace, evaluation, nested)
%[tested: tracer:a_trace_that_abolishes_a_wrapped_predicate_leaves_the_tracer_disarmed;
%commit=f5eb8775b78519c080da4ea7c6dff81f7be21ef9].
metta_trace_unwrap(Module:F/A) :-
    ignore(catch(unwrap_predicate(Module:F/A, metta_tracer), _, true)).
metta_trace_unwrap(interposed(Module:Head, _, _, _)) :-
    functor(Head, Name, Arity),
    metta_trace_unwrap(Module:Name/Arity).

metta_trace_wrap_once(Target) :-
    ( metta_trace_wrapped(Target) -> true
    ; metta_trace_wrap(Target),
      assertz(metta_trace_wrapped(Target)) ).

%A function compiled while a trace is active must be wrapped before the next
%form runs. The compiled-clause event, not the definition event: wrapping
%needs the predicate, and under deferred translation function_changed fires
%when the equation ARRIVES, which can be before any clause exists to wrap;
%this one fires once per compiled equation, arrival-translated and
%materialised alike.
:- multifile seam:function_clauses_changed/1.
seam:function_clauses_changed(F) :-
    with_mutex('$metta_trace_state',
               ( metta_trace_session
                 -> compiled_function_name(F, Predicate),
                    findall(Target,
                            ( metta_trace_target(Target),
                              Target = _Module:Predicate/_Arity
                            ; metta_trace_interposed_target(Target) ),
                            Targets0),
                    sort(Targets0, Targets),
                    maplist(metta_trace_wrap_once, Targets)
                 ; true )).

%The interposed sweep rides on the same event and is not narrowed to this
%function, because a library's dispatcher does not carry the function's name in
%its predicate: `(memoize-exact f)` DURING a trace generates a replay predicate
%of its own, and only a full sweep of what the seam declares finds it. It costs
%one solution per declared interposition against a hook that already walks
%every registered arity looking for this function's own targets, and
%metta_trace_wrap_once/1 makes the repeat free.

%The compiled function's own wrapper. It records the reduction unless a
%library's dispatcher recorded it a moment ago and is now running the function
%to answer it: that is ONE reduction seen at two layers, and recording both
%showed `(fib 8)` reducing inside itself. The mark is cleared before the body
%runs, so a call the body makes under the same name is an ordinary reduction
%again.
metta_trace_call(F, InArgs, Out, Closure) :-
    (   nb_current('$metta_trace_interposed', F)
    ->  b_setval('$metta_trace_interposed', []),
        call(Closure)
    ;   metta_trace_ports(F, InArgs, Out, Closure)
    ).

%The library dispatcher's wrapper. The reduction is recorded HERE, because
%this is where the call arrives and the layer below may never run: a cache hit
%answers from its table without entering the function, which is why a memoised
%head's trace was empty [measured 2026-09-07: `!(fib 8)` with the automatic
%memo recorded 0 events over 23,050 inferences, and 18 on a cold cache, one
%pair per miss and nothing for the 9 hits].
metta_trace_interposed_call(F, InArgs, Out, Closure) :-
    metta_trace_ports(F, InArgs, Out, metta_trace_interposition(F, Closure)).

%The mark that stops the layer below recording the same reduction, set for the
%dispatcher's own body and cleared again on the way out, so a cache HIT -- which
%never reaches the function and never consumes the mark -- does not leave it
%standing for the next direct call. Backtracking restores it, which is what a
%dispatcher re-entered for a second answer wants.
metta_trace_interposition(F, Closure) :-
    b_setval('$metta_trace_interposed', F),
    call(Closure),
    b_setval('$metta_trace_interposed', []).

%The three ports of one reduction. `*->` is the operator the trichotomy needs:
%the else branch runs only when the goal produced NO answer, so a reduction
%that answered is not also reported as failing, and the soft cut leaves no
%choicepoint behind a deterministic success [measured 2026-09-07: swipl -q
%tests/prolog/probes/tracer/fail_port_shape.pl, deterministic(true) after a
%det goal, the same answer SWI's own port wrapper reaches with call_cleanup/2
%and a local cut (source: /usr/lib/swi-prolog/library/prolog_trace.pl,
%wrapper/4)]. SWI's
%wrapper fires `fail` on EXHAUSTION, after however many exits, which is the
%Byrd box; this records the OUTCOME of a reduction, so the port that says
%"this one answered nothing" is worth an event and a second port saying "and
%now there are no more" is not, on a stream every consumer pairs by depth.
%
%An exception does not reach the else branch at all, so a bound that cut the
%run leaves the call unmatched rather than claiming it failed.
metta_trace_ports(F, InArgs, Out, Closure) :-
    ( nb_current('$metta_trace_depth', D) -> true ; D = 0 ),
    Term = [F|InArgs],
    metta_trace_observe(D, call, Term, ''),
    D1 is D + 1,
    b_setval('$metta_trace_depth', D1),
    (   call(Closure)
    *-> b_setval('$metta_trace_depth', D),
        metta_trace_observe(D, exit, Term, Out)
    ;   metta_trace_observe(D, fail, Term, ''),
        fail
    ).

%What the wrapper does with one event, which is the session's business and
%not the wrapper's. A debug session SUSPENDS on it and a trace session
%RECORDS it.
%
%The third arm is not a fallback, it is the correctness of the second. A
%debug session holds its wrappers on across the host's thinking time, so an
%unrelated evaluation on another thread reaches this while a debug session
%owns the wrap; sending it to metta_trace_record/4 would fail, because that
%predicate's conjunction needs a limit no debug session sets, and a failing
%wrapper FAILS THE PREDICATE IT WRAPS. The debug flag is engine-local
%(b_setval inside the engine, invisible outside it, measured), which is what
%keeps the suspend to the one execution the host is driving.
metta_trace_observe(Depth, Kind, Term, Answer) :-
    (   nb_current('$metta_debug_active', true)
    ->  metta_debug_event(Depth, Kind, Term, Answer)
    ;   metta_trace_limit(_)
    ->  metta_trace_record(Depth, Kind, Term, Answer)
    ;   true
    ).

%An event carries the term, not the term's text. Written with swrite and
%read back by the receiver, every symbol whose spelling reads as something
%else changed on the way: a stored (holds $notvar) traced as a variable
%while run answered the symbol, a semicolon truncated the rest of the term
%at the comment it starts, and a tab inside a symbol split the record into
%the wrong fields altogether. Variables are named by first occurrence,
%which is the one thing the text form did that a reader wants kept.
% Filter before copying terms or charging either recording budget. Wrappers
% still run for excluded functions, so selected descendants keep their depth.
% CPython 3.13 trace.py globaltrace_lt likewise decides before recording:
% https://github.com/python/cpython/blob/v3.13.0/Lib/trace.py
metta_trace_accepts(_) :- metta_trace_filter(all), !.
metta_trace_accepts(F) :- metta_trace_selected(F).

metta_trace_record(_, _, [F|_], _) :-
    \+ metta_trace_accepts(F), !.
metta_trace_record(Depth, Kind, Term, Answer) :-
    copy_term(Term-Answer, TermCopy-AnswerCopy),
    term_variables(TermCopy-AnswerCopy, Variables),
    metta_trace_variable_names(Variables, 0, Names),
    metta_trace_time(Time),
    with_mutex('$metta_trace_events',
               ( metta_trace_next_seq(N),
                 %Built inside the lock because the sequence number is part of
                 %it and the cell budget must charge what is stored. It costs
                 %one term_size walk over a term the assertz below walks again.
                 Event = event(N, Time, Depth, Kind, TermCopy, AnswerCopy,
                               Names),
                 term_size(Event, EventCells),
                 metta_trace_limit(Max),
                 metta_trace_cells(Cells),
                 Cells1 is Cells + EventCells,
                 metta_trace_cell_budget(Budget),
                 N1 is N + 1,
                 ( metta_trace_recording_bound(N1, Max, Cells1, Budget,
                                               Why)
                   -> metta_trace_note_stop(Why),
                      throw('$metta_trace_bound_reached')
                 ; retractall(metta_trace_next_seq(_)),
                   assertz(metta_trace_next_seq(N1)),
                   retractall(metta_trace_cells(_)),
                   assertz(metta_trace_cells(Cells1)),
                   assertz(metta_trace_event(N, Event)) ) )).

%Which recording bound this event would cross. The count is asked first
%because it is the one the caller set and the one a caller can act on; the
%cell budget is the engine's own and stops a trace whose events are large
%rather than numerous.
metta_trace_recording_bound(Seq, Max, _, _, events) :- Seq > Max, !.
metta_trace_recording_bound(_, _, Cells, Budget, memory) :- Cells > Budget.

%The first bound to stop the recording is the one reported. Worker threads
%record through this same mutex, so a second one crossing a different bound
%a moment later does not rewrite what stopped the run.
metta_trace_note_stop(Why) :-
    ( metta_trace_stopped(_) -> true ; assertz(metta_trace_stopped(Why)) ).

%One row per RUN bound that can stop a traced run, pairing the ball it
%arrives as with the name the caller set it under. The two RECORDING bounds
%are not here: they arrive as this module's own control atom and have
%already named themselves through metta_trace_stopped/1.
%
%Catching these inside the traced goal is what keeps the events, and it is
%sound rather than a trick played on the guard. SWI disarms the inference
%limit BEFORE it throws (pl-prims.c raiseInferenceLimitException sets
%INFERENCE_NO_LIMIT, then raises the bare atom), so the harvest below runs
%unbounded and call_with_inference_limit/3 restores the caller's outer limit
%and reports success rather than inference_limit_exceeded; the time limit is
%a one-shot alarm with remove(true) and behaves the same [measured
%2026-09-04: 200,000 further inferences after the catch, outer Result=!, and
%the NEXT bounded call still bounded;
%docs/journal/2026-09-04-bounded-trace-keeps-its-events.md].
metta_trace_stop_ball(inference_limit_exceeded, inferences).
metta_trace_stop_ball(time_limit_exceeded, timeout).
metta_trace_stop_ball(error(resource_error(stack), _), stack).

%What stopped the run, as one of the limit vocabulary's words, or false when
%nothing did. Anything that is not a bound is rethrown: a trace must not
%turn a program's own error into a short answer.
metta_trace_stop(Ball, Stopped) :-
    (   var(Ball)
    ->  Stopped = false
    ;   Ball == '$metta_trace_bound_reached'
    ->  metta_trace_stopped(Stopped)
    ;   metta_trace_stop_ball(Ball, Stopped)
    ->  true
    ;   throw(Ball)
    ).

%The throw still ABORTS the run, and metta_trace_source/5 catches it and
%answers the events recorded so far. Both halves matter and the earlier
%design had only one of each.
%
%Aborting is what bounds the TIME. The bound is a count, so a trace that
%merely stopped recording still ran the whole program: 02-tilepuzzle.metta
%at max_events 5000 did not finish in 240 seconds that way, where the
%abort ends it in seconds. A caller asking to be bounded is asking not to
%pay for the rest.
%
%Answering the prefix is what stops the memory being spent for nothing.
%The bound is a count and the memory an event costs is the size of its
%term, which nothing bounds, so a throw that also discarded the events
%charged the full memory of the bound and returned no trace: measured
%2026-09-03 on 02-tilepuzzle.metta, max_events 5000 peaks 0.08GB and
%10000 peaks 0.26GB, and a downstream renderer measured 50000 at 5.77GB,
%100000 above 14GB, and six concurrent renders taking a 60GB machine to
%2GB free -- every one of them raising and answering nothing.
%
%'$metta_trace_bound_reached' is a bare atom rather than an error term
%because it is this module's own control flow and must not be mistaken
%for, or caught by, anything that handles error/2. It never escapes
%metta_trace_source/5.

%The clock an event carries: whole nanoseconds since the session's run began,
%so a recording's first event is near zero and two recordings of the same
%program are comparable whatever else the machine was doing. An absolute epoch
%stamp would spend nineteen digits a row saying when the process started.
%
%Outside a session there is no origin and the answer is 0, which is the only
%time this is reached: metta_trace_observe/4 has already decided a session is
%recording, and both sessions set an origin before the program runs.
metta_trace_time(Time) :-
    (   metta_trace_origin(Origin)
    ->  get_time(Now),
        Time is round((Now - Origin) * 1 000 000 000)
    ;   Time = 0
    ).

metta_trace_start_clock :-
    get_time(Now),
    retractall(metta_trace_origin(_)),
    assertz(metta_trace_origin(Now)).

%_0, _1 and so on, by first occurrence, which is the naming swrite applied
%when an event crossed as text. The pairs travel with the term, so a
%receiver that encodes variables by name reads the same spelling; the
%leading $ belongs to the spelling of a variable, not to its name.
metta_trace_variable_names([], _, []).
metta_trace_variable_names([Variable|Rest], Index, [Name-Variable|Names]) :-
    atom_concat('_', Index, Name),
    Next is Index + 1,
    metta_trace_variable_names(Rest, Next, Names).

%%%%%%%%%%% The debugger %%%%%%%%%%
%
% Same wrappers, different action: where a trace RECORDS an event and runs
% on, a debug session SUSPENDS on one and hands the host the term, then
% resumes with whatever the host posts back.
%
% Suspension is engine_yield/1 from inside the wrapper, which is the one
% mechanism SWI documents for returning control from deep inside a running
% goal, and the only one that leaves the goal resumable: a yield from five
% frames down answers the host's engine_next/2 and the next engine_post/3
% delivers a command through engine_fetch/1 and carries on
% [source: https://www.swi-prolog.org/pldoc/man?predicate=engine_yield/1;
% measured 2026-09-05 against this engine]. The alternative shape, a
% callback that blocks until the host answers, is what CPython's bdb and
% SWI's own debug_adapter do; it cannot be used across janus, whose query
% iterator is not opened for yielding, so the host would have to hold a
% thread inside the callback.
%
% ALL targets are wrapped, not just the armed ones, which is the one place
% this differs from the trace filter above. Stepping has to be able to enter
% a function nobody set a breakpoint on, which is exactly why bdb traces
% every frame and decides in stop_here/break_here rather than instrumenting
% only the breakpoints.
%
% The armed set arrives WHOLE on every resume rather than as edits. The host
% owns it, so there is no second copy here to drift, and arming a function
% mid-session is the same operation as resuming.
% A COUNT joins the names as a third kind of breakpoint, because the question
% "stop where the recording's event 200 is" has no name to arm: replaying a
% recorded run to one of its events is how a recording becomes a live session,
% and the event is identified by its position. It is the same numbering a trace
% records, because both sessions count through metta_trace_observe/4 over the
% same wrappers, and a recording is made with no filter, so nothing is skipped
% on one side and counted on the other.
:- dynamic metta_debug_armed/1.
:- dynamic metta_debug_mode/1.
:- dynamic metta_debug_count/1.

metta_debug_event(Depth, Kind, Term, Answer) :-
    metta_debug_next_seq(Seq),
    (   metta_debug_stops(Seq, Term)
        %Read only when it is about to be reported. A session spends the
        %host's thinking time between stops, so a clock read per candidate
        %event would price every reduction for a number nobody sees.
    ->  metta_trace_time(Time),
        metta_debug_suspend(Seq, Time, Depth, Kind, Term, Answer)
    ;   true
    ).

metta_debug_next_seq(Seq) :-
    with_mutex('$metta_trace_events',
               ( metta_trace_next_seq(Seq),
                 Next is Seq + 1,
                 retractall(metta_trace_next_seq(_)),
                 assertz(metta_trace_next_seq(Next)) )).

metta_debug_stops(Seq, _) :-
    metta_debug_count(Seq).
metta_debug_stops(_, [F|_]) :-
    (   metta_debug_mode(step)
    ->  true
    ;   metta_debug_armed(F)
    ).

%The names travel with the term for the same reason a trace event's do: a
%receiver that encodes variables by name reads the same spelling the writer
%would have produced.
metta_debug_suspend(Seq, Time, Depth, Kind, Term, Answer) :-
    copy_term(Term-Answer, TermCopy-AnswerCopy),
    term_variables(TermCopy-AnswerCopy, Variables),
    metta_trace_variable_names(Variables, 0, Names),
    metta_debug_yield(stop(Seq, Time, Depth, Kind, TermCopy, AnswerCopy,
                           Names)),
    engine_fetch(Command),
    metta_debug_command(Command).

%A breakpoint reached from inside a host callback cannot suspend, and says
%so rather than being skipped. SWI refuses engine_yield/1 when the engine is
%inside a foreign predicate that called back into Prolog, and a Python
%operation that evaluates MeTTa is exactly that path; the refusal it raises
%names the VM instruction and nothing else, so it is translated here into
%the one sentence that says what to do about it.
metta_debug_yield(Stop) :-
    catch(engine_yield(Stop),
          error(permission_error(execute, vmi, 'I_YIELD'), _),
          throw(error(permission_error(suspend, metta_breakpoint, Stop),
                      context(metta_debug_run/3,
                              'a breakpoint inside a host operation cannot \c
suspend; set it on a function the program reaches outside one')))).

metta_debug_command(resume(Mode, Armed)) :-
    retractall(metta_debug_mode(_)),
    assertz(metta_debug_mode(Mode)),
    retractall(metta_debug_armed(_)),
    metta_debug_arm(Armed).

metta_debug_arm([]).
metta_debug_arm([Name0|Rest]) :-
    ( atom(Name0) -> Name = Name0 ; atom_string(Name, Name0) ),
    assertz(metta_debug_armed(Name)),
    metta_debug_arm(Rest).

%The debugged run itself, the goal a transport puts inside an engine and
%steps. The flag is set INSIDE the engine, so it travels with this execution
%and no other; a concurrent evaluation on another thread meets the same
%wrappers and falls straight through them.
%
%A transport creates the engine rather than this file, for the reason the
%cursor's own comment gives: a policy wrapping engine_next/2 on the caller
%cannot roll back work the engine performs, so the transaction has to be
%part of the suspended goal, and the policy constructor lives with the
%transport that knows which scope is open. Sessions begin and end here
%because the WRAPPERS are this file's.
metta_debug_run(Source, Space, Groups) :-
    b_setval('$metta_debug_active', true),
    b_setval('$metta_trace_depth', 0),
    metta_trace_start_clock,
    once(metta_host_run_source(Source, Space, [], Groups)).

%Count is the event to stop at, or a negative number for no count breakpoint,
%which is the no-bound sentinel every other door here uses.
metta_debug_begin(Armed, Count) :-
    with_mutex('$metta_trace_state', metta_debug_begin_unlocked(Armed, Count)).

%One session at a time, trace or debug, because they take the same wrappers.
%
%The clean slate comes from metta_trace_end_unlocked/0 rather than a second
%list of retractalls. A debug session must not inherit a fact a trace session
%left, and the set of those facts is the trace's to know: it has grown twice
%already, by the truncation flag and again by the filter pair, and each time a
%copy here would have gone stale silently. No metta_trace_limit/1 is asserted,
%which is what metta_trace_observe/4 reads to tell the two sessions apart.
metta_debug_begin_unlocked(Armed, Count) :-
    (   metta_trace_session
    ->  throw(error(permission_error(debug, evaluation, nested),
                    context(metta_debug_begin/2,
                            'a trace or debug session is already running')))
    ;   metta_trace_end_unlocked,
        retractall(metta_debug_mode(_)),
        assertz(metta_debug_mode(run)),
        retractall(metta_debug_armed(_)),
        metta_debug_arm(Armed),
        %The counter the stops are numbered by. metta_trace_end_unlocked/0 has
        %just retracted it and asserts none of its own, because a trace
        %session's begin is the only other place that sets it.
        assertz(metta_trace_next_seq(0)),
        ( Count < 0 -> true ; assertz(metta_debug_count(Count)) ),
        assertz(metta_trace_session),
        catch(( metta_trace_all_targets(Targets),
                maplist(metta_trace_wrap_once, Targets) ),
              Error,
              ( metta_debug_end_unlocked, throw(Error) ))
    ).

metta_debug_end :-
    with_mutex('$metta_trace_state', metta_debug_end_unlocked).

%The trace's own teardown, so a debug session inherits its TOTALITY: a
%recorded target whose wrapper a traced program abolished stops neither the
%rest of the sweep nor the state retractions, and a session that could not
%disarm itself would refuse every later trace and debug on the engine.
metta_debug_end_unlocked :-
    metta_trace_end_unlocked,
    retractall(metta_debug_armed(_)),
    retractall(metta_debug_count(_)),
    retractall(metta_debug_mode(_)).

%%%%%%%%%%% Trace sessions %%%%%%%%%%

metta_trace_begin(Max, Filter) :-
    with_mutex('$metta_trace_state', metta_trace_begin_unlocked(Max, Filter)).

metta_trace_begin_unlocked(Max, Filter) :-
    ( metta_trace_session
      -> throw(error(permission_error(trace, evaluation, nested),
                     context(metta_trace_source/3,
                             'a trace is already running')))
    ; retractall(metta_trace_filter(_)),
      retractall(metta_trace_selected(_)),
      retractall(metta_trace_event(_, _)),
      retractall(metta_trace_limit(_)),
      retractall(metta_trace_next_seq(_)),
      retractall(metta_trace_stopped(_)),
      retractall(metta_trace_cells(_)),
      assertz(metta_trace_cells(0)),
      retractall(metta_trace_wrapped(_)),
      assertz(metta_trace_limit(Max)),
      assertz(metta_trace_next_seq(0)),
      assertz(metta_trace_session),
      catch(( metta_trace_install_filter(Filter),
              metta_trace_all_targets(Targets),
              maplist(metta_trace_wrap_once, Targets) ),
            Error,
            ( metta_trace_end_unlocked, throw(Error) )) ).

%Every compiled MeTTa function, and every predicate a loaded library declared
%it interposes in front of one. Sorted together so the wrap order is stable
%and a duplicate declaration wraps once.
metta_trace_all_targets(Targets) :-
    findall(Target,
            ( metta_trace_target(Target)
            ; metta_trace_interposed_target(Target) ),
            Targets0),
    sort(Targets0, Targets).

metta_trace_end :-
    with_mutex('$metta_trace_state', metta_trace_end_unlocked).

metta_trace_end_unlocked :-
    findall(Target, metta_trace_wrapped(Target), Targets),
    maplist(metta_trace_unwrap, Targets),
    retractall(metta_trace_wrapped(_)),
    retractall(metta_trace_session),
    retractall(metta_trace_filter(_)),
    retractall(metta_trace_selected(_)),
    retractall(metta_trace_limit(_)),
    retractall(metta_trace_next_seq(_)),
    retractall(metta_trace_stopped(_)),
    retractall(metta_trace_cells(_)),
    retractall(metta_trace_origin(_)),
    retractall(metta_trace_event(_, _)).

%Run Source in Space with the trace armed; Events come back oldest
%first, at most Max of them. Past any bound the recording STOPS and
%Stopped names the bound, so the caller keeps the prefix it asked to be
%bounded to: an event costs the size of its term and nothing bounds that, so
%a throw at the bound discarded everything already recorded and charged the
%full memory of the bound for no answer. The five-argument form reports the
%bound, false when the run finished; the four- and three-argument forms drop
%that and carry the default bound. Each event is
%event(Seq, Time, Depth, Kind, Term, Answer, VariableNames), Answer being ''
%on a call and on a fail, Seq numbering the recorded events from 0, Time being
%the wall nanoseconds since the run began, and VariableNames pairing $_0, $_1
%with the term's variables.
%
%DEFAULT_TRACE_EVENTS is 10000 rather than the 1000000 it was through
%2026-09-03. An unqualified trace has to be survivable on an ordinary
%machine, and the old default was not: measured on
%examples/ch22-a-reasoner-you-can-serve/22-03-search/02-tilepuzzle.metta,
%10000 events peak 0.26GB and a downstream renderer measured 50000 at
%5.77GB and 100000 above 14GB, six concurrent renders taking a 60GB
%machine to 2GB free. Truncation is what makes a low default safe rather
%than lossy: a caller who needs more asks for more and can SEE that the
%first answer was cut.
%A COUNT cannot bound the memory, because an event costs the size of its
%term and nothing bounds that. Measured 2026-09-03 on
%examples/ch22-a-reasoner-you-can-serve/22-03-search/02-tilepuzzle.metta,
%whose terms are search states: 1000 events peak 0.13GB, 5000 peak 1.38GB,
%and 10000 exceeded a 4GB cap and died. The same 10000 on an ordinary
%program costs nothing at all. So the bound a caller can set is a count
%because that is what a caller can reason about, and the bound that keeps
%the process alive is this, in cells of the Prolog store.
%
%The two stop the recording identically and answer different words,
%because their remedies differ and a caller told only "cut" acts on the
%wrong one: raising max_events after the CELL budget stopped a trace
%returns the same prefix again, at the same cost, for the same reason.
%Charged on the term ALREADY copied, so it costs a term_size walk over a
%term copy_term has just walked anyway.
%
%4 million cells is 32MB at 8 bytes a cell, and it is chosen from the
%measurement rather than the arithmetic: answering a trace collects,
%encodes, crosses and rebuilds it, each step holding its own copy, and
%that pipeline costs about twenty times the recorded size. On
%02-tilepuzzle.metta, which peaks at 0.19GB untraced, a whole traced run
%peaks at 0.39GB for 2M cells, 0.73GB for 4M and 2.76GB for 16M. 4M keeps
%the worst program measured under a gigabyte while leaving 4,035 events of
%it, and an ordinary program never reaches the budget at all: the 42-event
%trace of a recursive count is unchanged.
%
%The twenty-fold pipeline is where a streaming door would pay, since it
%is the materialising and not the recording that dominates. Nothing here
%streams yet.
metta_trace_cell_budget(4000000).

metta_trace_default_events(10000).

metta_trace_source(Source, Space, Events) :-
    metta_trace_default_events(Max),
    metta_trace_source(Source, Space, Max, Events).

metta_trace_source(Source, Space, Max, Events) :-
    metta_trace_source(Source, Space, Max, Events, _Stopped).

% The existing host door transports its bound unchanged. A two-item request
% adds a filter without changing that door or bypassing its execution guards,
% and a `bounded/2` request carries the RUN bounds the same way, for the reason
% metta_trace_run/3 records. A caller that sends neither is unbounded here and
% may still wrap the whole door itself, which is what lib_observe, the Node
% bridge and tracer.plt do.
metta_trace_source(Source, Space, Request, Events, Stopped) :-
    (   nonvar(Request), Request = bounded(Inner, Bounds)
    ->  true
    ;   Inner = Request, Bounds = run_bounds(-1, -1, -1, -1)
    ),
    (   nonvar(Inner), Inner = [Max, Filter]
    ->  true
    ;   Max = Inner, Filter = all
    ),
    metta_trace_bounded_source(Source, Space, Max, Filter, Bounds,
                               Events, Stopped).

% all selects every compiled logical name; [] selects none. Names need not
% exist yet because Source itself can define them. Invalid filters refuse
% before source executes or a session is armed.
metta_trace_filter_names(Filter, Names) :-
    ( Filter == all
    -> Names = all
    ; is_list(Filter), maplist(metta_trace_filter_name, Filter, Atoms)
    -> sort(Atoms, Names)
    ; throw(error(domain_error(trace_function_filter, Filter),
                  context(metta_trace_source/6,
                          'use all or a list of nonempty function names'))) ).

metta_trace_filter_name(Name, Atom) :-
    ( atom(Name) -> Atom = Name
    ; string(Name) -> atom_string(Atom, Name) ),
    Atom \== ''.

metta_trace_install_filter(all) :- !,
    assertz(metta_trace_filter(all)).
metta_trace_install_filter(Names) :-
    assertz(metta_trace_filter(selected)),
    forall(member(Name, Names), assertz(metta_trace_selected(Name))).

metta_trace_source(Source, Space, Max, Filter, Events, Stopped) :-
    metta_trace_bounded_source(Source, Space, Max, Filter,
                               run_bounds(-1, -1, -1, -1), Events, Stopped).

metta_trace_bounded_source(Source, Space, Max, Filter, Bounds, Events, Stopped) :-
    metta_trace_filter_names(Filter, Names),
    ( integer(Max), Max > 0 -> true
    ; throw(error(domain_error(positive_integer, Max),
                  context(metta_trace_source/5, 'max_events bound')))),
    catch(metta_trace_session(Source, Space, Max, Names, Bounds,
                              Events0, Stopped0),
          Ball, true),
    (   var(Ball)
    ->  Events = Events0, Stopped = Stopped0
        %Arming the tracer wraps every compiled function, which is itself
        %work, so a bound tight enough to run out before the first event is
        %recorded exists. It names itself over an empty prefix rather than
        %raising: where inside the setup a counter runs out is not something
        %a caller can reason about, and a bound that sometimes raises and
        %sometimes answers, on nothing the caller can see, is worse than
        %either. metta_trace_begin/2 has already torn the session down by
        %here, so there is nothing left to harvest. A bound sent as
        %run_bounds/4 cannot reach that branch at all, since it is installed
        %around the program rather than around the arming; a caller wrapping
        %the whole door still can.
    ;   metta_trace_stop_ball(Ball, Stopped)
    ->  Events = []
    ;   throw(Ball)
    ).

metta_trace_session(Source, Space, Max, Filter, Bounds, Events, Stopped) :-
    setup_call_cleanup(
        metta_trace_begin(Max, Filter),
        ( b_setval('$metta_trace_depth', 0),
          %After the arming, so an event's time measures the PROGRAM, the same
          %division the run bounds already make.
          metta_trace_start_clock,
          %Every ball, so a RUN bound stopped by the guard around this
          %call keeps its events too; metta_trace_stop/2 rethrows anything
          %that is not a bound before a single event is harvested.
          catch(metta_trace_run(Bounds, Source, Space), Ball, true),
          with_mutex('$metta_trace_events',
                     ( metta_trace_stop(Ball, Stopped),
                       findall(N-E, metta_trace_event(N, E), Pairs) )),
          keysort(Pairs, Sorted),
          pairs_values(Sorted, Events) ),
        metta_trace_end).

%What the RUN bounds bound, and what they do not. Arming the tracer walks
%every name in arity/2 and wraps the ones a module still defines, and
%metta_trace_end_unlocked/0 unwraps them again: measured 2026-09-07 that pair
%costs twelve inferences per registered name -- 12,016 in a fresh process,
%35,941 with two thousand more names defined and 47,943 with three thousand --
%against 3,192 for the program those numbers were taken on. Charged to the
%caller's budget, as they were while the Python transport wrapped the whole
%door in metta_py_guarded/4, a bound the caller set for the PROGRAM was spent
%on the wrap before the first event was recorded: `inferences=40_000` answered
%an empty prefix naming a bound the program never reached, and what the door
%did depended on how much else the process had loaded rather than on the
%program. The door's own contract is that max_events bounds the RECORDING and
%timeout, inferences and stack bound the RUN, and the ENCODING left this
%budget for the same reason on 2026-09-04
%[docs/journal/2026-09-04-bounded-trace-keeps-its-events.md]; the arming and
%the teardown leave it here.
metta_trace_run(run_bounds(Seconds, Inferences, StackBytes, Seed),
                Source, Space) :-
    metta_trace_stack_bound(
        StackBytes,
        metta_trace_time_bound(
            Seconds,
            metta_trace_inference_bound(
                Inferences,
                metta_trace_seeded(
                    Seed,
                    process_metta_string(Source, _Results, Space))))).

%A run under a pinned generator, which is what makes a recorded run's draws
%replay: rr records the nondeterministic inputs once and replays deterministically
%[source: O'Callahan et al., "Engineering Record and Replay for Deployability",
%USENIX ATC 2017, arXiv:1705.05937], and the only such input this engine has
%without a host call is the random state. The save-and-restore pair is
%metta_with_seed/4's, and for its reason: a seed is a SCOPE, so the generator
%is left exactly where the caller had it
%[source: engine/metta/control.pl, metta_with_seed/4]. Innermost of the four,
%so the seeding is inside every bound rather than beside them.
metta_trace_seeded(Seed, Goal) :-
    (   Seed < 0
    ->  call(Goal)
    ;   random_property(state(Saved)),
        setup_call_cleanup(set_random(seed(Seed)),
                           call(Goal),
                           set_random(state(Saved)))
    ).

%A negative bound is the no-bound sentinel every other door here uses.
metta_trace_stack_bound(Bytes, Goal) :-
    (   Bytes < 0
    ->  call(Goal)
    ;   metta_host_with_stack_limit(Bytes, Goal)
    ).

%A build without the deadlines capability refuses BY NAME, the way
%(timeout N Expr) and (pragma! max-time N) do, rather than raising an
%existence error for a predicate the census already knows is absent.
metta_trace_time_bound(Seconds, Goal) :-
    (   Seconds < 0
    ->  call(Goal)
    ;   metta_require_platform('a trace with a timeout', deadlines),
        call_with_time_limit(Seconds, Goal)
    ).

%call_with_inference_limit/3 REPORTS the overrun through its Result rather
%than letting the ball out, so it is thrown again here: metta_trace_stop/2
%names a bound from the ball, and this one has to name itself the same way
%whether it was installed here or by a caller wrapping the whole door. The
%throw is sound rather than a trick played on the guard, for the reason
%metta_trace_stop_ball/2 records: SWI disarms the limit before it raises, so
%the harvest below the catch runs unbounded either way.
metta_trace_inference_bound(Limit, Goal) :-
    (   Limit < 0
    ->  call(Goal)
    ;   call_with_inference_limit(Goal, Limit, Result),
        (   Result == inference_limit_exceeded
        ->  throw(inference_limit_exceeded)
        ;   true
        )
    ).
