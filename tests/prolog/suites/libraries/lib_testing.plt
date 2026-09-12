% Purpose: verify finite generators, quantified bags and generator cleanup.
% Guarantees: independent products and bag models preserve occurrence counts;
% fixtures exercise bounds, variable copying, module context and failure exits.
% [tested: lib_testing; commit=WORKTREE].
% Owns resources: fixtures destroy message queues and release execution spaces.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module('../../../../lib/lib_testing/lib_testing').
:- use_module(library(lists), [member/2,numlist/3]).
:- use_module(library(aggregate), [aggregate_all/3]).
:- initialization(testing_suite_setup).

testing_suite_setup :-
    import_prolog_functions(['test-integers','test-choices','test-lists',
                            'test-forall','test-witness','testing-suite-owned',
                            'testing-suite-raise','testing-suite-bag',
                            'testing-suite-binding'],_),
    filereader:metta_host_run_source("!(import! &self (library lib_testing))",'&self',[],_).

'testing-suite-owned'(Queue,Value) :-
    setup_call_cleanup(true,
        (thread_send_message(Queue,opened),between(1,3,Value),
         thread_send_message(Queue,visited(Value))),
        thread_send_message(Queue,closed)).
'testing-suite-raise'(Value,_) :- throw(testing_function_error(Value)).
'testing-suite-bag'(Bag,_,Value) :- member(Value,Bag).
'testing-suite-binding'(Original,[row,Original]) :- Original=bound.

:- begin_tests(lib_testing).
:- meta_predicate must_throw(0,?), with_queue(1).

must_throw(Goal,Expected) :-
    catch(Goal,Error,true),assertion(nonvar(Error)),assertion(Error=Expected).
with_queue(Goal) :-
    setup_call_cleanup(message_queue_create(Queue),call(Goal,Queue),
                       message_queue_destroy(Queue)).
messages(Queue,Values) :-
    ( thread_get_message(Queue,Value,[timeout(0)])
    -> Values=[Value|Rest],messages(Queue,Rest)
    ; Values=[] ).

test(integer_intervals_match_the_native_finite_range) :-
    forall((between(-5,5,Low),between(-5,5,High)),
        (findall(V,'test-integers'(Low,High,V),Values),
         (Low=<High->numlist(Low,High,Expected);Expected=[]),assertion(Values==Expected))),
    Big is 1<<500,High is Big+2,Middle is Big+1,
    findall(V,'test-integers'(Big,High,V),Values),assertion(Values==[Big,Middle,High]).

test(integer_bounds_reject_nonintegers_and_unbounded_values) :-
    forall(member(Low-High,[_-1,0-_,1.5-2,0-1.5,a-2,0-inf,0-1.0Inf]),
           must_throw('test-integers'(Low,High,_),error(_,_))).

test(choices_keep_occurrences_and_literal_values) :-
    string_codes(Nul,[97,0,98]),Items=[[],a,a,Nul,['+',1,2],1,1.0],
    findall(V,'test-choices'(Items,V),Values),assertion(Values==Items),
    findall(V,'test-choices'([],V),Empty),assertion(Empty==[]).

test(choice_variables_are_fresh_but_internal_sharing_survives) :-
    once('test-choices'([[row,X,X]],[row,A,B])),
    assertion(A==B),assertion(A\==X),A=bound,assertion(var(X)).

test(choices_reject_variables_improper_lists_and_cycles) :-
    Cycle=[x|Cycle],
    forall(member(Items,[_Variable,[x|tail],Cycle,[[x,Cycle]]]),
           must_throw('test-choices'(Items,_),error(_,_))).

test(list_families_match_an_independent_product_model) :-
    forall((member(Pool,[[],[a],[a,a],[a,b],[a,b,c]]),
            between(0,3,Minimum),between(0,3,Maximum)),
        (findall(L,'test-lists'(['test-choices',Pool],Minimum,Maximum,L),Actual),
         findall(L,(between(Minimum,Maximum,N),model_list(N,Pool,L)),Expected),
         assertion(Actual==Expected))).
model_list(0,_,[]) :- !.
model_list(N,Pool,[Value|Rest]) :-
    member(Value,Pool),Next is N-1,model_list(Next,Pool,Rest).

test(list_variables_are_independent_between_positions) :-
    once('test-lists'(['test-choices',[[row,X,X]]],2,2,[[row,A,B],[row,C,D]])),
    assertion(A==B),assertion(C==D),assertion(A\==C),
    A=left,assertion(var(C)),assertion(var(X)).

test(zero_length_does_not_evaluate_the_element_generator) :-
    findall(L,'test-lists'(['testing-suite-raise',unused],0,0,L),Lists),
    assertion(Lists==[[]]),
    findall(L,'test-lists'(['testing-suite-raise',unused],2,1,L),Reversed),
    assertion(Reversed==[]).

test(empty_populations_do_not_walk_the_requested_length_interval) :-
    Huge is 1<<500,statistics(inferences,Before),
    findall(L,'test-lists'(['test-choices',[]],0,Huge,L),Lists),
    findall(L,'test-lists'(['test-choices',[]],1,Huge,L),None),
    statistics(inferences,After),Cost is After-Before,
    assertion(Lists==[[]]),assertion(None==[]),assertion(Cost<10000).

test(list_bounds_validate_before_running_the_generator) :-
    forall(member(Min-Max,[-1-2,0-(-1),0-1.5,a-2,_-2,0-_]),
        must_throw('test-lists'(['testing-suite-raise',unused],Min,Max,_),error(_,_))).

test(element_generator_is_snapshotted_once) :- with_queue(snapshot_case).
snapshot_case(Queue) :-
    aggregate_all(count,'test-lists'(['testing-suite-owned',Queue],1,2,_),Count),
    assertion(Count==12),messages(Queue,Events),
    assertion(Events==[opened,visited(1),visited(2),visited(3),closed]).

test(bag_properties_match_ground_multiset_equality) :-
    Bags=[[],[a],[b],[a,a],[a,b],[b,a],[b,a,a],["π"],[[],['+',1,2]]],
    forall((member(Actual,Bags),member(Expected,Bags)),
        (msort(Actual,SortedActual),msort(Expected,SortedExpected),
         ( 'test-witness'(['test-choices',[case]],
                         ['testing-suite-bag',[quote,Actual]],Expected,Found)
         -> assertion(SortedActual==SortedExpected),assertion(Found==case)
         ; assertion(SortedActual\==SortedExpected) ))).

test(universal_checks_count_every_occurrence_including_zero) :-
    'test-forall'(['test-choices',[a,a,b]],['|->',[_],true],[true],Count),
    assertion(Count==3),
    'test-forall'(['test-choices',[]],['testing-suite-raise'],[true],Zero),
    assertion(Zero==0),
    'test-forall'(['test-integers',1,3],['|->',[_],[empty]],[],Three),
    assertion(Three==3).

test(boolean_properties_require_exactly_one_true_answer) :-
    forall(member(Actual,[[],[false],[true,true],[7],[true,false]]),
        must_throw('test-forall'(['test-choices',[case]],
                                ['testing-suite-bag',[quote,Actual]],[true],_),
                   error(metta_assertion_failed(_,_,_),_))).

test(counterexample_reports_the_input_and_missing_and_excess_bags) :-
    must_throw('test-forall'(['test-integers',0,3],['|->',[X],['<',X,2]],[true],_),
        error(metta_assertion_failed(
            ['test-forall',['test-integers',0,3],[_,[quote,2]],[true]],[true],[false]),
            context('test-forall',_))).

test(witness_commits_to_the_first_input_and_closes_the_generator) :- with_queue(witness_case).
witness_case(Queue) :-
    findall(V,'test-witness'(['testing-suite-owned',Queue],['|->',[X],['>=',X,2]],[true],V),Values),
    assertion(Values==[2]),messages(Queue,Events),
    assertion(Events==[opened,visited(1),visited(2),closed]).

test(generator_cleanup_survives_property_failure_and_exception) :-
    with_queue(assertion_cleanup),with_queue(exception_cleanup).
assertion_cleanup(Queue) :-
    must_throw('test-forall'(['testing-suite-owned',Queue],['|->',[X],['<',X,2]],[true],_),
               error(metta_assertion_failed(_,_,_),_)),
    messages(Queue,Events),assertion(Events==[opened,visited(1),visited(2),closed]).
exception_cleanup(Queue) :-
    must_throw('test-witness'(['testing-suite-owned',Queue],'testing-suite-raise',[true],_),
               testing_function_error(1)),
    messages(Queue,Events),assertion(Events==[opened,visited(1),closed]).

test(quantification_does_not_bind_the_callers_generator_template) :-
    'test-witness'(['testing-suite-binding',Original],['|->',[_],true],[true],Found),
    assertion(Found==[row,bound]),assertion(var(Original)).

test(expected_bags_and_cyclic_calls_refuse_before_generation) :-
    Cycle=[Cycle],
    forall(member(Expected,[_Variable,a,[a|tail],Cycle]),
        (must_throw('test-forall'(['testing-suite-raise',unused],f,Expected,_),error(_,_)),
         must_throw('test-witness'(['testing-suite-raise',unused],f,Expected,_),error(_,_)))),
    must_throw('test-forall'(Cycle,f,[],_),error(domain_error(acyclic_term,_),_)),
    must_throw('test-witness'(['test-choices',[]],Cycle,[],_),error(domain_error(acyclic_term,_),_)).

test(generator_and_function_names_resolve_in_each_calling_module) :-
    setup_call_cleanup('new-space'(Left),
        setup_call_cleanup('new-space'(Right),context_case(Left,Right),
                           spaces:metta_release_space(Right)),
        spaces:metta_release_space(Left)).
context_case(Left,Right) :-
    filereader:metta_host_run_source("!(import! &self (library lib_testing))\n(= (testing-local) 11)\n(= (testing-map $x) 12)",Left,[],_),
    filereader:metta_host_run_source("!(import! &self (library lib_testing))\n(= (testing-local) 21)\n(= (testing-map $x) 22)",Right,[],_),
    spaces:space_module(Left,LM),spaces:space_module(Right,RM),
    with_metta_module(LM,'test-forall'(['testing-local'],'testing-map',[12],LC)),
    with_metta_module(RM,'test-forall'(['testing-local'],'testing-map',[22],RC)),
    assertion(LC==1),assertion(RC==1),
    with_metta_module(LM,'test-witness'(['testing-local'],'testing-map',[12],LV)),
    with_metta_module(RM,'test-witness'(['testing-local'],'testing-map',[22],RV)),
    assertion(LV==11),assertion(RV==21).

:- end_tests(lib_testing).
