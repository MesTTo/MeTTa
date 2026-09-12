% Purpose: verify opt-in source coverage and Error-frame observations.
% Guarantees: source coordinates distinguish repeated expressions; generated
%   closures disclose their origin and uncompiled functions disclose absent maps
%   [tested: source_observation; commit=6f634f6705fc1e40e0c2e3970d4156ee574ab70d].
% Owns resources: probe wrappers, hook clauses, thread flags and queue-backed
%   workers are released after each test, including exceptions.
:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module('../../../../engine/metta.pl', [metta_with_trailed/3]).
:- use_module(library(prolog_wrap)).

:- begin_tests(source_observation).

% The engine does not load the observer at boot, so this suite asks for it the
% same way lib_observe's observe-source does, and at load time because the
% tests below wrap and inspect the module's own predicates.
:- metta_ensure_source_observation.

observe(Source,Rows) :-
    setup_call_cleanup('new-space'(Space),
        source_observation:observe_source(Space,"unit.metta",Source,Rows),
        spaces:metta_release_space(Space)).

no_observation_buffer :-
    \+ (nb_current('$metta_observation',Buffer), Buffer \== []).

test(identical_branches_have_distinct_coverage) :-
    observe("(= (obs-pick $flag $x)\n  (if $flag\n    (+ $x 2)\n    (+ $x 2)))\n!(obs-pick True 1)",Rows),
    memberchk(['observation-answer',0,3],Rows),
    memberchk(['source-coverage',"unit.metta",3,5,3,13,1],Rows),
    memberchk(['source-coverage',"unit.metta",4,5,4,13,0],Rows).

test(error_atom_and_exact_caller_frames_survive, [nondet]) :-
    observe("(= (obs-divide $x)\n  (+ 1 (/ 1 $x)))\n(= (obs-caller $x)\n  (+ 2 (obs-divide $x)))\n!(obs-caller 0)",Rows),
    Error=['Error',['/',1,0],'DivisionByZero'],
    memberchk(['observation-answer',0,Error],Rows),
    member(['source-error',Id,Error],Rows),
    memberchk(['source-frame',Id,0,'obs-divide',"unit.metta",2,8,2,16,exact],Rows),
    memberchk(['source-frame',Id,1,'obs-caller',"unit.metta",4,8,4,23,exact],Rows).

test(generated_closure_reports_its_construct, [nondet]) :-
    observe("(= (obs-collect $x)\n  (collapse (+ 1 (/ 1 $x))))\n!(obs-collect 0)",Rows),
    member(['source-frame',_,_,'obs-collect',"unit.metta",2,3,2,28,
            ['generated-by',collapse]],Rows),
    memberchk(['source-coverage-unavailable',"unit.metta",2,13,2,27,
               ['generated-by',collapse]],Rows),
    \+ member(['source-coverage',"unit.metta",2,13,2,27,_],Rows).

test(identical_generated_siblings_keep_separate_origins, [nondet]) :-
    observe("(= (obs-twice $x)\n  (cons-atom (collapse (/ 1 $x)) (collapse (/ 1 $x))))\n!(obs-twice 0)",Rows),
    member(['source-frame',_,_,'obs-twice',"unit.metta",2,14,2,33,
            ['generated-by',collapse]],Rows),
    member(['source-frame',_,_,'obs-twice',"unit.metta",2,34,2,53,
            ['generated-by',collapse]],Rows).

test(unexecuted_definition_has_zero_entry_coverage) :-
    observe("(= (obs-unused $x) (+ $x 2))\n!(+ 1 2)",Rows),
    memberchk(['source-coverage',"unit.metta",1,1,1,29,0],Rows),
    ( memberchk(['source-coverage-unavailable',"unit.metta",1,20,1,28,'not-compiled'],Rows)
    ; memberchk(['source-coverage',"unit.metta",1,20,1,28,0],Rows) ).

test(previously_compiled_function_reports_absent_metadata, [nondet]) :-
    setup_call_cleanup('new-space'(Space),
        ( filereader:metta_host_run_source("(= (obs-old $x) (/ 1 $x)) !(obs-old 1)",Space,[],_),
          source_observation:observe_source(Space,"later.metta","!(obs-old 0)",Rows),
          memberchk(['source-function-unavailable','obs-old','source-not-observed'],Rows),
          member(['source-frame-unavailable',_,_,'obs-old','source-not-observed'],Rows) ),
        spaces:metta_release_space(Space)).

test(exception_keeps_source_frames_and_restores_debugger, [nondet]) :-
    current_prolog_flag(debug,Debug),
    current_prolog_flag(last_call_optimisation,LCO),
    '$visible'(Visible,Visible),
    observe("(= (obs-check $x) (assertEqual $x 3)) !(obs-check 0)",Rows),
    memberchk(['observation-status',exception],Rows),
    findall(Error, member(['source-error',_,Error], Rows), [_]),
    member(['source-frame',_,_,'obs-check',"unit.metta",1,_,1,_,_],Rows),
    current_prolog_flag(debug,Debug),
    current_prolog_flag(last_call_optimisation,LCO),
    '$visible'(Visible,Visible),
    no_observation_buffer,
    \+ source_observation:source_document(_,_,_),
    \+ source_observation:installed_hook(_).

test(repeated_observations_do_not_retain_errors_or_documents, [nondet]) :-
    observe("!(/ 1 0)",First), member(['source-error',_,_],First),
    observe("!(+ 1 2)",Second),
    \+ member(['source-error',_,_],Second),
    memberchk(['observation-answer',0,3],Second).

test(an_observed_error_does_not_mark_an_engines_outer_query_frame) :-
    setup_call_cleanup(
        engine_create(Rows, source_observation:observe_source(
            '&self', "engine.metta", "!(/ 1 0)", Rows), Engine),
        ( engine_next(Engine, Rows),
          memberchk(['source-error',_,['Error',['/',1,0],'DivisionByZero']], Rows) ),
        engine_destroy(Engine)).

test(decons_refusal_is_observed_as_unchanged_data, [nondet]) :-
    observe("!(decons-atom ())",Rows),
    member(['observation-answer',0,Error],Rows),
    Error=['Error',['decons-atom',[]],_],
    member(['source-error',_,Error],Rows).

test(error_hooks_keep_each_existing_refusal_shape) :-
    % These failure policies are internal dispatch branches, so exercising each
    % exact branch isolates recording from unrelated function-policy lookup.
    source_observation:new_observation_buffer(Buffer),
    metta_with_trailed('$metta_observation',Buffer,
      ( translator:dispatch_no_match('NoMatchError',missing,[1],A),
        translator:dispatch_out_of_clauses('FailureError',emptying,[2],B),
        translator:dispatch_mismatch('MismatchError',typed,[3],C),
        translator:declared_arity_refusal(declared,[4],D),
        A==['Error',[missing,1],'NoMatchingClause'],
        B==['Error',[emptying,2],'OutOfClauses'],
        C==['Error',[typed,3],'ArgumentTypeMismatch'],
        D==['Error',[declared,4],'IncorrectNumberOfArguments'],
        nb_getval('$metta_observation',Recorded), arg(2,Recorded,Errors),
        length(Errors,4) )).

% SWI consults prolog:prolog_exception_hook/5 whenever the predicate HOLDS A
% CLAUSE rather than whenever it exists, so one resident clause taxes every
% exception the process throws for as long as the module is loaded: it cost
% 119 inferences on the engine's translate case and 3 on a caught
% DivisionByZero [measured 2026-09-05]. The clauses therefore exist only while
% an observation runs. installed_hook/1 is the bookkeeping and this asks the
% database instead, because a receipt is not the payload. Both hooks are
% proved to WORK while installed by error_atom_and_exact_caller_frames_survive
% and identical_branches_have_distinct_coverage above, so a clean answer here
% is not a broken mechanism reading as a clean one.
observer_hook_clause(Head) :-
    clause(Head, Body),
    term_to_atom(Body, Text),
    sub_atom(Text, _, _, _, source_observation).

no_observer_hooks :-
    \+ observer_hook_clause(prolog:prolog_exception_hook(_,_,_,_,_)),
    \+ observer_hook_clause(user:prolog_trace_interception(_,_,_,_)),
    \+ source_observation:installed_hook(_).

test(the_observer_holds_no_hook_outside_an_observation) :-
    no_observation_buffer,
    no_observer_hooks.

test(an_observation_takes_its_process_wide_hooks_away_again) :-
    observe("!(/ 1 0)",Rows),
    memberchk(['source-error',_,_],Rows),
    no_observer_hooks.

test(ordinary_errors_keep_no_observation_buffer) :-
    metta_error_atom('/',[1,0],'DivisionByZero',Error),
    Error==['Error',['/',1,0],'DivisionByZero'],
    no_observation_buffer.

test(invalid_source_type_refuses,
     [throws(error(type_error(string,42),_))]) :-
    source_observation:observe_source('&self',"unit.metta",42,_).

test(nested_observation_refuses_without_destroying_outer_buffer) :-
    source_observation:new_observation_buffer(Buffer),
    metta_with_trailed('$metta_observation',Buffer,
        ( catch(source_observation:observe_source('&self',"nested","!(+ 1 2)",_),Error,true),
          nonvar(Error), Error=error(permission_error(observe,execution,nested),_),
          nb_current('$metta_observation',Still), same_term(Buffer,Still) )).


test(exception_preserves_completed_form_answers) :-
    observe("!(+ 1 2) !(assertEqual 0 1)",Rows),
    memberchk(['observation-status',exception],Rows),
    memberchk(['observation-answer',0,3],Rows).

test(invalid_label_has_remedy,
     [throws(error(type_error(string,label),
                   context('observe-source','pass the source label as a string')))]) :-
    source_observation:observe_source('&self',label,"!(+ 1 2)",_).

test(invalid_space_refuses_before_running_source,
     [throws(error(type_error('SpaceType',not_a_space),context('observe-source',_)))]) :-
    source_observation:observe_source(not_a_space,"unit.metta","!(assertEqual 0 1)",_).

test(compiled_goals_are_unchanged) :-
    Source="(= (obs-identical $x) (+ $x 1)) !(obs-identical 4)",
    setup_call_cleanup(('new-space'(A),'new-space'(B)),
      ( filereader:metta_host_run_source(Source,A,[],_),
        source_observation:observe_source(B,"unit.metta",Source,_),
        spaces:space_module(A,MA), spaces:space_module(B,MB),
        clause(MA:'obs-identical'(X,Y),BodyA),
        clause(MB:'obs-identical'(U,V),BodyB),
        (X,Y,BodyA) =@= (U,V,BodyB) ),
      (spaces:metta_release_space(A),spaces:metta_release_space(B))).

test(imported_function_uses_its_file_identity, [nondet]) :-
    tmp_file(obs_source,Stem), atom_concat(Stem,'.metta',File),
    setup_call_cleanup(
      ( setup_call_cleanup(open(File,write,Stream,[encoding(utf8)]),
                           write(Stream,'(= (obs-imported $x) (/ 1 $x))'),close(Stream)),
        'new-space'(Space) ),
      ( format(string(Source),'!(import! &self "~w") !(obs-imported 0)',[File]),
        source_observation:observe_source(Space,"driver.metta",Source,Rows),
        atom_string(File,Label),
        member(['source-frame',_,_,'obs-imported',Label,1,22,1,30,exact],Rows),
        \+ member(['source-frame',_,_,'obs-imported',"driver.metta",_,_,_,_,_],Rows) ),
      (spaces:metta_release_space(Space),delete_file(File))).

test(binary_coverage_records_nondeterministic_execution_once) :-
    observe("(= (obs-many $x) (+ $x 1)) !(obs-many (superpose (1 2 3)))",Rows),
    findall(Answer,member(['observation-answer',0,Answer],Rows),[2,3,4]),
    forall(member(['source-coverage',_,_,_,_,_,Covered],Rows),
           memberchk(Covered,[0,1])).

test(nested_controls_preserve_each_source_branch) :-
    observe("(= (obs-nested $a $b)\n  (if $a (if $b (+ 1 2) (+ 3 4)) (+ 5 6)))\n!(obs-nested True False)",Rows),
    memberchk(['observation-answer',0,7],Rows),
    memberchk(['source-coverage',"unit.metta",2,17,2,24,0],Rows),
    memberchk(['source-coverage',"unit.metta",2,25,2,32,1],Rows),
    memberchk(['source-coverage',"unit.metta",2,34,2,41,0],Rows).


test(observing_errors_does_not_reclassify_arithmetic) :-
    metta_operation_effect('observe-source',oracleIO),
    metta_operation_effect('/',Before),
    observe("!(/ 1 0)",_),
    metta_operation_effect('/',After), Before==After, Before==pureStructural.

test(generated_token_owns_only_its_lexical_span) :-
    % The scanner accepts an already-parsed constructor result. Its children
    % were synthesized by the reader and therefore have no written spans.
    Term=[token_constructor,"12x"], Tree=node(span(0,3,1,1,1,4),[]),
    source_observation:source_subterm(Term,Tree,Term,span(0,3,1,1,1,4),token),
    source_observation:goal_attribution(token_constructor("12x",_),
        token(token_constructor),['generated-by',['token-constructor',token_constructor]]).

test(partial_install_failure_releases_wrappers_and_state) :-
    setup_call_cleanup(
      wrap_predicate(source_observation:install_runtime_observers(_,_), setup_failure, _,
        ( wrap_predicate(filereader:metta_host_run_source(_,_,_,_),
                         source_observer,Call,Call),
          throw(error(observer_install_probe,context(test,partial_install))) )),
      ( catch(source_observation:observe_source('&self',"unit.metta","!(+ 1 2)",_),
              Error,true),
        nonvar(Error), Error=error(observer_install_probe,_),
        no_observation_buffer,
        \+ (predicate_property(translator:translate_expr_dl(_,_,_,_),wrapped(Names)),
             memberchk(source_map,Names)),
        \+ (predicate_property(filereader:metta_host_run_source(_,_,_,_),wrapped(Names)),
             memberchk(source_observer,Names)),
        \+ source_observation:installed_hook(_) ),
      unwrap_predicate(source_observation:install_runtime_observers/2,setup_failure)).

observation_worker(Queue) :-
    catch((observe("!(+ 5 6)",Rows),Outcome=success(Rows)),Error,Outcome=error(Error)),
    thread_send_message(Queue,finished(Outcome)).

test(ordinary_other_thread_execution_does_not_enter_observation) :-
    setup_call_cleanup(
      ( message_queue_create(Queue),
        wrap_predicate(source_observation:install_runtime_observers(_,_), concurrent_probe, Call,
          ( Call, thread_send_message(Queue,installed),
            thread_get_message(Queue,continue) )),
        thread_create(observation_worker(Queue),Worker,[]) ),
      ( thread_get_message(Queue,installed),
        filereader:metta_host_run_source("!(/ 1 0)",'&self',[],_),
        no_observation_buffer,
        thread_send_message(Queue,continue),
        thread_get_message(Queue,finished(success(Rows))),
        memberchk(['observation-answer',0,11],Rows),
        \+ member(['source-error',_,_],Rows) ),
      ( thread_send_message(Queue,continue), thread_join(Worker,_),
        unwrap_predicate(source_observation:install_runtime_observers/2,concurrent_probe),
        message_queue_destroy(Queue) )).

:- meta_predicate with_gc(+,0), throwing_exit_hook(+,0).

with_gc(Value, Goal) :-
    current_prolog_flag(gc, Previous),
    setup_call_cleanup(set_prolog_flag(gc,Value), Goal,
                       set_prolog_flag(gc,Previous)).

test(observation_restores_the_original_gc_flag,
     [forall(member(GC,[true,false]))]) :-
    with_gc(GC,
      ( observe("!(+ 1 2)",Rows),
        memberchk(['observation-answer',0,3],Rows),
        current_prolog_flag(gc,GC), no_observer_hooks )).

throwing_exit_hook(exit, _) :- !,
    current_prolog_flag(gc, GC), nb_setval('$observer_throw_gc',GC),
    throw(error(observer_gc_hook_probe,context(test,exit_hook))).
throwing_exit_hook(_, Goal) :- call(Goal).

test(a_throwing_exit_hook_restores_gc,
     [forall(member(GC,[true,false]))]) :-
    with_gc(GC,
      setup_call_cleanup(
        ( asserta((user:message_hook(error(observer_gc_hook_probe,_),error,_) :-
                       nb_setval('$observer_throw_reported',true)), Message),
          wrap_predicate(source_observation:observe_port(Port,_,_), gc_throw,
                         Call, throwing_exit_hook(Port,Call)) ),
        ( observe("!(+ 1 2)",Rows),
          memberchk(['observation-answer',0,3],Rows),
          nb_getval('$observer_throw_gc',false),
          nb_getval('$observer_throw_reported',true),
          current_prolog_flag(gc,GC), no_observer_hooks ),
        ( unwrap_predicate(source_observation:observe_port/3,gc_throw),
          erase(Message), nb_delete('$observer_throw_gc'),
          nb_delete('$observer_throw_reported') ))).

cancel_at_finished_frame(Owner, Queue, _) :-
    thread_self(Thread),
    ( Thread == Owner, nb_current('$observer_cancel_once',true),
      current_prolog_flag(gc,false)
    -> nb_delete('$observer_cancel_once'),
       thread_send_message(Queue,window_open),
       thread_get_message(Queue,release)
    ; true ).

cancelled_observation(GC, Queue) :-
    set_prolog_flag(gc,GC), thread_self(Owner),
    setup_call_cleanup(
      ( prolog_listen(frame_finished,cancel_at_finished_frame(Owner,Queue)),
        nb_setval('$observer_cancel_once',true) ),
      ( observe("!(+ 1 2)",Rows),
        memberchk(['observation-status',exception],Rows),
        memberchk(['observation-exception',Message],Rows),
        term_string(error(observer_cancel_probe,context(test,cancel)),Message),
        current_prolog_flag(gc,GC), no_observer_hooks ),
      ( prolog_unlisten(frame_finished,cancel_at_finished_frame(Owner,Queue)),
        nb_delete('$observer_cancel_once') )).

test(cancelling_an_open_window_restores_gc,
     [forall(member(GC,[true,false]))]) :-
    setup_call_cleanup(
      ( message_queue_create(Queue),
        thread_create(cancelled_observation(GC,Queue),Worker,[]) ),
      ( thread_get_message(Queue,window_open),
        thread_signal(Worker,throw(error(observer_cancel_probe,context(test,cancel)))),
        thread_join(Worker,Status) ),
      ( ( var(Status) -> thread_send_message(Queue,release), thread_join(Worker,_)
        ; true ),
        message_queue_destroy(Queue) )),
    Status == true.

child_collector(GC) :-
    current_prolog_flag(gc,GC),
    no_observation_buffer.

test(source_thread_creation_inherits_the_restored_flag,
     [forall(member(GC,[true,false]))]) :-
    with_gc(GC,
      setup_call_cleanup(
        wrap_predicate(filereader:metta_host_run_source(_,_,_,_), gc_child, Call,
          ( thread_create(child_collector(GC),Child,[]),
            thread_join(Child,true), Call )),
        ( observe("!(+ 1 2)",Rows),
          memberchk(['observation-answer',0,3],Rows),
          current_prolog_flag(gc,GC) ),
        unwrap_predicate(filereader:metta_host_run_source/4,gc_child))).

test(the_process_wide_trace_hook_leaves_other_threads_gc_alone,
     [forall(member(GC,[true,false]))]) :-
    with_gc(GC,
      setup_call_cleanup(
        ( message_queue_create(Queue),
          ( GC == true -> OwnerGC=false ; OwnerGC=true ),
          wrap_predicate(source_observation:install_runtime_observers(_,_), gc_owner,
            Call, ( Call, thread_send_message(Queue,installed),
                    thread_get_message(Queue,continue) )),
          thread_create((set_prolog_flag(gc,OwnerGC),observation_worker(Queue)),Worker,[]) ),
        ( thread_get_message(Queue,installed),
          setup_call_cleanup(
            assertz((user:prolog_trace_interception(_,_,_,continue) :-
                       current_prolog_flag(gc,Observed),
                       ( Observed == GC -> true
                       ; nb_setval('$other_gc_changed',true) )), Fallback),
            ( trace, thread_self(_), notrace, current_prolog_flag(gc,GC),
              \+ nb_current('$other_gc_changed',_) ),
            ( notrace, erase(Fallback), nb_delete('$other_gc_changed') )) ),
        ( thread_send_message(Queue,continue), thread_join(Worker,Status),
          unwrap_predicate(source_observation:install_runtime_observers/2,gc_owner),
          message_queue_destroy(Queue) ))),
    Status == true.

% Attribution asks whether a goal is a meta predicate, and the goals it walks
% are a compiled clause's own, so most of them are MeTTa functions living in
% their space's module rather than host predicates. meta_predicate/1 is one of
% the properties SWI answers by running its undefined-procedure trap, which
% searches the whole autoload library index before raising the existence error
% the caller discards: 1,029 inferences against 8 for maplist/3
% [measured 2026-09-06; commit=693b1bdb6ed06cd0ba01e901a8a6d774bc733d19]. A RATIO rather than a count, because
% the honest number moves a few inferences with clause layout.
test(attributing_a_goal_that_is_not_a_host_predicate_costs_what_one_that_is_costs) :-
    metta_engine_module(Engine),
    assertion(current_predicate(Engine:maplist/3)),
    assertion(\+ current_predicate(Engine:'plunit-not-a-host-goal'/3)),
    attribution_cost(Engine:maplist(a, b, c), Present),
    attribution_cost(Engine:'plunit-not-a-host-goal'(a, b, c), Missing),
    %Five, not four. A miss walks the module chain and the chain gained one
    %link when the engine core became a module of its own: the host tier
    %`user` now sits between it and `system`, which is what keeps a MeTTa
    %program's own consulted Prolog reachable from every space. The present
    %case is unmoved at 10 and the missing one reads 41 against 38
    %[measured: 2026-09-08 present=10 and missing=41, cut=10/38; command=swipl -q tests/prolog/probes/module_attribution.pl; fixture=provisioned module tree and cut 9006528e0; commit=ede2ac57e213a0d4502c6bbbca6227f97015b720]. The bound is here to
    %catch the 1,030-inference library-index search that
    %predicate_property(defined) used to trigger, which is two orders of
    %magnitude away either way. Ten rather than five because the plunit lane
    %runs under tests/prolog/lock_order.pl, which costs about twenty
    %inferences per mutex acquisition and the missing path takes mutexes the
    %present one does not [measured 2026-09-13: missing 78 against present 15
    %under the recorder; command=sh engine/test.sh suites/reader/source_observation.plt;
    %commit=WORKTREE].
    assertion(Missing =< 10 * Present).

attribution_cost(Goal, Per) :-
    Rounds = 1000,
    statistics(inferences, Before),
    forall(between(1, Rounds, _),
           ( source_observation:goal_attribution(Goal, plunit_construct, _)
           -> true ; true )),
    statistics(inferences, After),
    Per is (After - Before - 3 * Rounds) // Rounds.

:- end_tests(source_observation).
