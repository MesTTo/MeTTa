% Purpose: verify statistical equations against exact independent references.
% Guarantees: finite exhaustive models cover moments, ties and interpolation;
% range and domain fixtures exercise public MeTTa calls and host input guards.
% [tested: lib_statistics; commit=6fa571d1b7059b610f73e9feed657711414251e5].
% Owns resources: arithmetic-policy flags are restored; concurrent/3 joins its
% workers, and cancellation leaves only query-local terms.

:- use_module(collection_test_support).
:- use_module('../../../../lib/_support/collections_data', []).
:- use_module('../../../../lib/lib_vector/lib_vector', [fraction_sqrt/2]).
:- use_module(library(lists), [member/2, numlist/3, sum_list/2, nth0/3]).
:- use_module(library(apply), [maplist/2, maplist/3]).
:- use_module(library(thread), [concurrent/3]).
:- use_module(library(random), [getrand/1]).
:- load_collection_library(lib_statistics).

:- begin_tests(lib_statistics).

center_square(Mean, Value, Square) :- Square is (Value-Mean)**2.
affine(Value, Image) :- Image is 3*Value+7.

test(exact_reductions_against_centered_finite_reference) :-
    forall((between(-3,3,A),between(-3,3,B),between(-3,3,C)),
        (Data=[A,B,C],Mean is (A+B+C) rdiv 3,
         maplist(center_square(Mean),Data,Squares),sum_list(Squares,SS),
         invoke('stats-mean'(Data,ActualMean)),assertion(ActualMean == Mean),
         forall(between(0,2,D),
                (invoke('stats-variance'(Data,D,Actual)),Expected is SS rdiv (3-D),
                 assertion(Actual == Expected))),
         maplist(affine,Data,Other),
         invoke('stats-covariance'(Data,Other,1,Cov)),assertion(Cov =:= 3*SS rdiv 2),
         (SS > 0
         -> invoke('stats-correlation'(Data,Other,Correlation)),assertion(Correlation == 1.0),
            invoke('stats-regression'(Data,Other,false,Fit)),assertion(Fit == ['linear-fit',3,7])
         ; true))).

test(sum_and_mean_round_after_cancellation_or_division) :-
    invoke('stats-sum'([],Zero)),assertion(Zero == 0),
    invoke('stats-sum'([1.0e308,1,-1.0e308],One)),assertion(One == 1.0),
    invoke('stats-mean'([1.0e308,1.0e308],Mean)),assertion(Mean == 1.0e308),
    Third is 1 rdiv 3,invoke('stats-sum'([Third,Third,Third],Whole)),assertion(Whole == 1).

test(root_precedes_floating_overflow_and_underflow) :-
    invoke('stats-variance'([-1.0e308,1.0e308],0,Overflow)),assertion(Overflow == 1.0Inf),
    invoke('stats-stdev'([-1.0e308,1.0e308],0,Large)),assertion(Large == 1.0e308),
    invoke('stats-variance'([-1.0e-300,1.0e-300],0,Underflow)),assertion(Underflow == 0.0),
    invoke('stats-stdev'([-1.0e-300,1.0e-300],0,Small)),assertion(Small == 1.0e-300),
    Big is 1<<2000,Tiny is 1 rdiv Big,
    fraction_sqrt(Big,Root),assertion(Root =:= float(1<<1000)),
    fraction_sqrt(Tiny,TinyRoot),assertion(TinyRoot =:= float(1 rdiv (1<<1000))).

test(variance_is_a_matchable_covariance_recipe) :-
    once(eval_expr([match,'&self',
                    ['=',['stats-variance',Data,Degrees],
                         ['stats-covariance',Data,Data,Degrees]],true],Answer)),
    assertion(Answer == true).

test(geometric_exponent_cancellation_and_equal_input_bounds) :-
    Big is 1<<2000,Tiny is 1 rdiv Big,
    invoke('stats-geometric-mean'([Big,Tiny],One)),assertion(One == 1.0),
    invoke('stats-geometric-mean'([Big,Big,Tiny,Tiny],Again)),assertion(Again == 1.0),
    forall(member(Value,[1.0e308,5.0e-324,1.0,1.7976931348623157e308]),
           (invoke('stats-geometric-mean'([Value,Value,Value],Mean)),assertion(Mean == Value))),
    invoke('stats-geometric-mean'([54,24,36],ThirtySix)),assertion(ThirtySix == 36.0),
    invoke('stats-geometric-mean'([0,Big],Zero)),assertion(Zero == 0.0).

test(harmonic_mean_preserves_exact_reciprocals) :-
    invoke('stats-harmonic-mean'([40,60],Value)),assertion(Value == 48),
    invoke('stats-harmonic-mean'([40.0,60],Float)),assertion(Float == 48.0),
    Tiny is 1 rdiv (1<<2000),
    invoke('stats-harmonic-mean'([Tiny,Tiny],Same)),assertion(Same == Tiny),
    invoke('stats-harmonic-mean'([0,1],Zero)),assertion(Zero == 0).

test(quantile_endpoints_and_partition_consistency) :-
    forall((between(2,20,N),between(1,20,Partitions)),
        (numlist(1,N,Data),
         invoke('stats-quantile'(Data,0,inclusive,Low)),assertion(Low == 1),
         invoke('stats-quantile'(Data,1,inclusive,High)),assertion(High == N),
         forall(member(Method,[inclusive,exclusive]),
             (invoke('stats-quantiles'(Data,Partitions,Method,Cuts)),
              ExpectedLength is Partitions-1,assertion(length(Cuts,ExpectedLength)),
              msort(Cuts,Sorted),assertion(Sorted == Cuts),
              forall(nth0(I,Cuts,Value),
                  (P is (I+1) rdiv Partitions,
                   invoke('stats-quantile'(Data,P,Method,Individual)),
                   assertion(Individual == Value))))))),
    invoke('stats-quantile'([0,10],0,exclusive,Before)),assertion(Before == -10),
    invoke('stats-quantile'([0,10],1,exclusive,After)),assertion(After == 20).

test(singleton_quantiles_validate_all_arguments) :-
    invoke('stats-quantiles'([7],1,inclusive,Empty)),assertion(Empty == []),
    invoke('stats-quantiles'([7],4,exclusive,Repeated)),assertion(Repeated == [7,7,7]),
    refused('stats-quantiles'([7],1,missing,_)),
    refused('stats-quantile'([7],2,inclusive,_)),
    refused('stats-quantiles'([],1,inclusive,_)).

test(median_and_numeric_promotion) :-
    invoke('stats-median'([9,1,4],Middle)),assertion(Middle == 4),
    invoke('stats-median'([1,2],Half)),assertion(Half =:= 3 rdiv 2),
    invoke('stats-median'([9.0,1,4],Float)),assertion(Float == 4.0),
    invoke('stats-quantile'([0,10],0.25,inclusive,Q)),assertion(Q =:= 5 rdiv 2).

test(mode_ties_keep_terms_and_first_occurrence_order) :-
    findall(X,collection_answers('stats-mode'([b,a,b,a,c],X)),Modes),assertion(Modes == [b,a]),
    findall(X,collection_answers('stats-mode'([1,1.0],X)),Numbers),assertion(Numbers == [1,1.0]),
    invoke('stats-mode'([['+',1,2],['+',1,2],9],Held)),assertion(Held == ['+',1,2]),
    invoke('stats-mode'([b,a,b,a],First)),assertion(First == b),
    invoke('stats-mode'([X,X,Y],Variable)),assertion(Variable == X),assertion(var(Y)).

test(rank_ties_match_less_and_equal_counts) :-
    forall((between(-2,2,A),between(-2,2,B),between(-2,2,C)),
        (Data=[A,B,C],invoke('stats-ranks'(Data,Ranks)),
         forall(nth0(I,Data,X),
             (findall(1,(member(Y,Data),Y < X),Less),length(Less,L),
              findall(1,(member(Y,Data),Y =:= X),Equal),length(Equal,E),
              Expected is L+(E+1) rdiv 2,nth0(I,Ranks,Actual),
              assertion(Actual == Expected))))),
    invoke('stats-ranks'([1,1.0,2],Mixed)),Half is 3 rdiv 2,assertion(Mixed == [Half,Half,3]),
    invoke('stats-ranks'([],Empty)),assertion(Empty == []).

test(regression_models_have_their_identifiable_domains) :-
    invoke('stats-regression'([2],[6],true,Origin)),assertion(Origin == ['linear-fit',3,0]),
    invoke('stats-regression'([0,1,2],[7,7,7],false,Constant)),
    assertion(Constant == ['linear-fit',0,7]),
    invoke('stats-regression'([0.0,1,2],[1,5,9],false,Float)),
    assertion(Float == ['linear-fit',4.0,1.0]),
    refused('stats-regression'([1],[2],false,_)),
    refused('stats-regression'([0],[2],true,_)),
    refused('stats-regression'([1,1],[2,3],false,_)).

% Cyclic and improper host lists cannot be written as finite MeTTa source.
% Exercise the same native representation guard before quoting such a value.
test(host_expression_guard_refuses_cycles_and_improper_lists) :-
    Cycle=[1|Cycle],Nested=[x|Nested],
    forall(member(Data,[[1|bad],Cycle,[Nested]]),
           (catch(collections_data:'collections-expression'(Data,_),Error,true),
            assertion(nonvar(Error)))).

test(numeric_refusals_cover_complete_inputs) :-
    refused('stats-sum'([_],_)),
    forall(member(Goal,['stats-geometric-mean'([0,-1],_),
                        'stats-harmonic-mean'([0,-1],_),
                        'stats-sum'([1,"bad"],_)]),refused(Goal)),
    forall(member(Value,[1.0Inf,-1.0Inf,1.5NaN]),
        forall(member(Goal,['stats-sum'([Value],_),
                            'stats-mean'([Value],_),
                            'stats-harmonic-mean'([0,Value],_),
                            'stats-geometric-mean'([0,Value],_),
                            'stats-median'([Value],_),
                            'stats-quantile'([1],Value,inclusive,_),
                            'stats-quantiles'([Value],1,inclusive,_),
                            'stats-variance'([Value],0,_),
                            'stats-stdev'([Value],0,_),
                            'stats-covariance'([Value],[1],0,_),
                            'stats-correlation'([1,Value],[1,2],_),
                            'stats-ranks'([Value],_),
                            'stats-regression'([1],[Value],true,_)]),refused(Goal))).

test(sample_size_and_pair_refusals) :-
    forall(member(Goal,['stats-mean'([],_),'stats-median'([],_),
                        'stats-geometric-mean'([],_),'stats-harmonic-mean'([],_),
                        'stats-mode'([],_),'stats-variance'([],0,_),
                        'stats-stdev'([],0,_),'stats-variance'([1],1,_),
                        'stats-variance'([1,2],-1,_),
                        'stats-covariance'([1,2],[1],0,_),
                        'stats-correlation'([1,1],[2,3],_)]),refused(Goal)).

test(configured_approximation_refuses_exact_results) :-
    (current_prolog_flag(max_rational_size,Size) -> true ; Size=infinite),
    current_prolog_flag(max_rational_size_action,Action),
    setup_call_cleanup(true,
        (set_prolog_flag(max_rational_size,1),set_prolog_flag(max_rational_size_action,float),
         forall(member(Goal,['stats-mean'([1,2,2],_),
                             'stats-harmonic-mean'([2,3],_),
                             'stats-quantile'([1,2],0.25,inclusive,_),
                             'stats-quantiles'([1,2],4,inclusive,_),
                             'stats-ranks'([1,1,2],_)]),refused(Goal))),
        (set_prolog_flag(max_rational_size,Size),set_prolog_flag(max_rational_size_action,Action))).

test(cancellation_and_concurrent_reads_leave_no_state) :-
    getrand(Before),length(Data,100000),maplist(=(1),Data),
    call_with_inference_limit(invoke('stats-mean'(Data,_)),10000,Status),
    assertion(Status == inference_limit_exceeded),
    concurrent(2,[collection_test_support:invoke('stats-mean'([1,2,3],Mean)),
                  collection_test_support:invoke('stats-variance'([1,2,3],1,Variance))],[]),
    assertion(Mean == 2),assertion(Variance == 1),
    getrand(After),assertion(After == Before).

:- end_tests(lib_statistics).
