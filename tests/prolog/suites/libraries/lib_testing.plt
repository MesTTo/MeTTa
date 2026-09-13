% Purpose: verify testing through ordinary generators, traversal and assertions.
% Guarantees: independent products and bag models cover multiplicity, literal
% values, binding, calling modules and generator cleanup on every exit.
% [tested: lib_testing; commit=WORKTREE].
% Owns resources: fixtures destroy message queues and release execution spaces.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(lists), [member/2,numlist/3]).
:- initialization(testing_suite_setup).

testing_suite_setup :-
    import_prolog_functions(['testing-suite-owned','testing-suite-raise',
                            'testing-suite-bag','testing-suite-binding'],_),
    filereader:metta_host_run_source("!(import! &self (library lib_testing))",'&self',[],_).

'testing-suite-owned'(Queue,Value) :-
    call_cleanup(
        (thread_send_message(Queue,opened),between(1,3,Value),
         thread_send_message(Queue,visited(Value))),
        thread_send_message(Queue,closed)).
'testing-suite-raise'(Value,_) :- throw(testing_function_error(Value)).
'testing-suite-bag'(Bag,_,Value) :- member(Value,Bag).
'testing-suite-binding'(Original,[row,Original]) :- Original=bound.

:- begin_tests(lib_testing).
:- meta_predicate must_throw(0,?), with_queue(1).

eval_expr(Expression,Answer) :-
    current_metta_module(Module),eval_metta_in_module(Module,Expression,Answer).
must_throw(Goal,Expected) :-
    catch(Goal,Error,true),assertion(nonvar(Error)),assertion(Error=Expected).
with_queue(Goal) :-
    setup_call_cleanup(message_queue_create(Queue),call(Goal,Queue),
                       message_queue_destroy(Queue)).
messages(Queue,Values) :-
    ( thread_get_message(Queue,Value,[timeout(0)])
    -> Values=[Value|Rest],messages(Queue,Rest)
    ; Values=[] ).

test(integer_domains_use_the_existing_exclusive_range) :-
    forall((between(-5,5,Low),between(-5,5,High)),
        (findall(V,eval_expr([range,Low,High],V),Values),Last is High-1,
         (Low<High->numlist(Low,Last,Expected);Expected=[]),
         assertion(Values==Expected))),
    Big is 1<<500,High is Big+3,Middle is Big+1,Last is Big+2,
    findall(V,eval_expr([range,Big,High],V),Values),
    assertion(Values==[Big,Middle,Last]).

test(indexing_keeps_occurrences_and_literal_values) :-
    string_codes(Nul,[97,0,98]),Items=[[],a,a,Nul,['+',1,2],1,1.0],
    length(Items,Size),
    findall(V,eval_expr(['index-atom',[quote,Items],[range,0,Size]],V),Values),
    assertion(Values==Items),
    findall(V,eval_expr(['index-atom',[],[range,0,0]],V),Empty),
    assertion(Empty==[]).

test(copying_runtime_values_is_explicit) :-
    eval_expr(['index-atom',[quote,[[row,X,X]]],0],Choice),
    eval_expr([copy_term,[quote,Choice]],[row,A,B]),
    eval_expr([copy_term,[quote,Choice]],[row,C,D]),
    assertion(A==B),assertion(C==D),assertion(A\==C),
    A=bound,assertion(var(C)),assertion(var(X)).

test(list_lengths_and_populations_compose_as_a_product) :-
    forall((member(Pool,[[],[a],[a,a],[a,b],[a,b,c]]),
            between(0,3,Minimum),between(0,3,Maximum)),
        (End is Maximum+1,
         findall(L,eval_expr(['cartesian-power',[quote,Pool],
                             [range,Minimum,End]],L),Actual),
         findall(L,(between(Minimum,Maximum,N),model_list(N,Pool,L)),Expected),
         assertion(Actual==Expected))).
model_list(0,_,[]) :- !.
model_list(N,Pool,[Value|Rest]) :-
    member(Value,Pool),Next is N-1,model_list(Next,Pool,Rest).

test(a_collected_population_runs_its_generator_once) :- with_queue(snapshot_case).
snapshot_case(Queue) :-
    Expression=[let,Pool,[collapse,['testing-suite-owned',Queue]],
                [collapse,['cartesian-power',Pool,[range,1,3]]]],
    eval_expr(Expression,Lists),length(Lists,Count),assertion(Count==12),
    messages(Queue,Events),
    assertion(Events==[opened,visited(1),visited(2),visited(3),closed]).

test(core_bag_assertions_match_an_independent_multiset_model) :-
    Bags=[[],[a],[b],[a,a],[a,b],[b,a],[b,a,a],["π"],[[],['+',1,2]]],
    forall((member(Actual,Bags),member(Expected,Bags)),
        (msort(Actual,SortedActual),msort(Expected,SortedExpected),
         Check=['assertEqualToResult',['testing-suite-bag',[quote,Actual],case],Expected],
         ( SortedActual==SortedExpected
         -> eval_expr(Check,true)
         ; must_throw(eval_expr(Check,_),error(metta_assertion_failed(_,_,_),_))
         ))).

test(forall_accepts_a_true_answer_and_foldall_counts_occurrences) :-
    eval_expr([forall,[superpose,[a,a,b]],['|->',[_],true]],true),
    eval_expr([forall,[superpose,[]],'testing-suite-raise'],true),
    eval_expr([foldall,['|->',[_Value,Count],['+',Count,1]],
               [superpose,[a,a,b]],0],3),
    eval_expr([foldall,['|->',[_Item,Initial],['+',Initial,1]],
               [superpose,[]],0],0),
    eval_expr([forall,[range,0,2],['|->',[_],[superpose,[false,true]]]],true),
    eval_expr([forall,[range,0,2],['|->',[_],[empty]]],false),
    eval_expr([forall,[range,0,2],['|->',[_],7]],false).

test(forall_and_an_assertion_preserve_exact_boolean_bags) :-
    forall(member(Actual,[[],[false],[true,true],[7],[true,false]]),
        must_throw(eval_expr([forall,[range,0,1],
            ['|->',[X],['assertEqualToResult',
                        ['testing-suite-bag',[quote,Actual],X],[true]]]],_),
                   error(metta_assertion_failed(_,_,_),_))).

test(a_failed_assertion_reports_its_actual_missing_and_excess_bags) :-
    must_throw(eval_expr(['assertEqualToResult',[superpose,[1,1]],[1,2]],_),
        error(metta_assertion_failed(
            ['assertEqualToResult',[superpose,[1,1]],[1,2]],[2],[1]),_)).

test(once_commits_to_the_first_filtered_input_and_closes_the_generator) :-
    with_queue(witness_case).
witness_case(Queue) :-
    findall(V,eval_expr([once,[let,X,['testing-suite-owned',Queue],
                              [if,['>=',X,2],X,[empty]]]],V),Values),
    assertion(Values==[2]),messages(Queue,Events),
    assertion(Events==[opened,visited(1),visited(2),closed]).

test(generator_cleanup_survives_success_failure_and_exceptions) :-
    with_queue(success_cleanup),with_queue(assertion_cleanup),
    with_queue(exception_cleanup).
success_cleanup(Queue) :-
    eval_expr([forall,['testing-suite-owned',Queue],
               ['|->',[X],[test,['<',X,4],true]]],true),
    messages(Queue,Events),
    assertion(Events==[opened,visited(1),visited(2),visited(3),closed]).
assertion_cleanup(Queue) :-
    must_throw(eval_expr([forall,['testing-suite-owned',Queue],
                          ['|->',[X],[test,['<',X,2],true]]],_),
               error(_,_)),
    messages(Queue,Events),
    assertion(Events==[opened,visited(1),visited(2),closed]).
exception_cleanup(Queue) :-
    must_throw(eval_expr([forall,['testing-suite-owned',Queue],
                          'testing-suite-raise'],_),testing_function_error(1)),
    messages(Queue,Events),assertion(Events==[opened,visited(1),closed]).

test(once_keeps_its_selected_binding_and_forall_quantifies_it) :-
    eval_expr([once,['testing-suite-binding',Original]],Found),
    assertion(Found==[row,bound]),assertion(Original==bound),
    eval_expr([forall,['testing-suite-binding',Quantified],
               ['|->',[_],true]],true),
    assertion(var(Quantified)).

test(empty_and_nested_witnesses_use_ordinary_answer_streams) :-
    findall(V,eval_expr([once,[empty]],V),None),assertion(None==[]),
    eval_expr([forall,[range,0,3],
        ['|->',[X],[test,[once,[let,Y,[range,0,3],
                               [if,['==',X,Y],Y,[empty]]]],X]]],true).

test(generators_and_callbacks_resolve_in_the_calling_module) :-
    setup_call_cleanup('new-space'(Left),
        setup_call_cleanup('new-space'(Right),context_case(Left,Right),
                           spaces:metta_release_space(Right)),
        spaces:metta_release_space(Left)).
context_case(Left,Right) :-
    filereader:metta_host_run_source("!(import! &self (library lib_testing))\n(= (testing-local) 11)\n(= (testing-map $x) 12)",Left,[],_),
    filereader:metta_host_run_source("!(import! &self (library lib_testing))\n(= (testing-local) 21)\n(= (testing-map $x) 22)",Right,[],_),
    spaces:space_module(Left,LM),spaces:space_module(Right,RM),
    eval_metta_in_module(LM,[forall,['testing-local'],
        ['|->',[X],[test,['testing-map',X],12]]],true),
    eval_metta_in_module(RM,[forall,['testing-local'],
        ['|->',[Y],[test,['testing-map',Y],22]]],true),
    eval_metta_in_module(LM,[once,['testing-local']],11),
    eval_metta_in_module(RM,[once,['testing-local']],21).

:- end_tests(lib_testing).
