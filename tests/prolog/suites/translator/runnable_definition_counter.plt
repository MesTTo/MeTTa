% Purpose: verify source-prefix decisions and their first-call counter cost.
% Guarantees: pending and arrived definitions answer the same on the first
%   and repeated guard call, with equal inference counts whether retired
%   clauses remain or have been collected [tested:
%   run_tests(runnable_definition_counter); commit=8ca8a387fc61d0918484b19a1a3baf85b6523043].
% Owns resources: each fresh child owns its reader rows and collection policy;
%   the parent closes its output stream and joins the child on every exit.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(process)).

:- begin_tests(runnable_definition_counter).

:- dynamic generation_marker/0.

test(first_source_prefix_read_matches_the_warm_read,
     [forall((member(State, [pending,arrived]),
              member(Collection, [retained,collected])))]) :-
    source_file(counter_child(_, _), File),
    current_prolog_flag(executable, Swipl),
    format(atom(Goal),
           'plunit_runnable_definition_counter:counter_child(~q,~q)',
           [State, Collection]),
    setup_call_cleanup(
        process_create(Swipl,
            ['-f', none, '-q', '-s', File, '-g', Goal, '-t', halt],
            [stdout(pipe(Output)), process(Pid)]),
        read_term(Output, Sample, []),
        (close(Output), process_wait(Pid, Status))),
    assertion(Status == exit(0)),
    Sample = sample(First, Warm, Answer, Again),
    assertion(First == Warm),
    assertion(Answer == Again),
    ( State == pending -> assertion(Answer == true)
    ; assertion(Answer == false) ).

% Fresh processes keep the consumer's first inherited call unresolved. Warm
% the unrelated context reads before measuring the real guard, then use the
% reader's ordinary arrival transition to leave its pending row retired.
counter_child(State, Collection) :-
    set_prolog_gc_thread(false),
    '$cgc_params'(_, _, _, 0, 1.0e20, 1.0e20),
    b_setval('$metta_translating_runnable', true),
    b_setval('$metta_source_programs', [counter_source]),
    assertz(filereader:source_pending_definition(counter_source,
                                                counter_function)),
    translator:active_source_program(counter_source),
    translator:current_metta_module(_),
    ( State == arrived
    -> filereader:source_definition_arrived(counter_function)
    ; true ),
    assertz(generation_marker),
    ( Collection == collected -> garbage_collect_clauses ; true ),
    measure(First, Answer), measure(Warm, Again),
    write_canonical(sample(First, Warm, Answer, Again)), writeln('.').

measure(Count, Answer) :-
    statistics(inferences, Before),
    ( translator:runnable_head_awaits_its_definition(counter_function)
    -> Answer = true ; Answer = false ),
    statistics(inferences, After),
    Count is After-Before.

:- end_tests(runnable_definition_counter).
