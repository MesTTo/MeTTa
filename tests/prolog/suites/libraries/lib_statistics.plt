% Purpose: verify exact statistical identities, domains and numerical range.
% Guarantees: finite exhaustive domains use centered reference calculations;
% edge fixtures exercise ties, binary64 range and complete refusals.
% [tested: lib_statistics; commit=WORKTREE].
% Owns resources: the arithmetic-policy test restores both host flags;
% concurrent/3 joins all workers, and cancellation leaves only query-local terms.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module('../../../../lib/lib_statistics/lib_statistics').
:- use_module('../../../../lib/lib_vector/lib_vector', [fraction_sqrt/2]).
:- use_module(library(lists), [member/2, numlist/3, sum_list/2, nth0/3]).
:- use_module(library(apply), [maplist/2, maplist/3]).
:- use_module(library(thread), [concurrent/3]).
:- use_module(library(random), [getrand/1]).

:- begin_tests(lib_statistics).
:- meta_predicate must_throw(0, ?).

must_throw(Goal, Expected) :-
    catch(Goal,Error,true),assertion(nonvar(Error)),assertion(Error = Expected).

center_square(Mean, Value, Square) :- Square is (Value-Mean)**2.
affine(Value, Image) :- Image is 3*Value+7.

test(exact_reductions_against_centered_finite_reference) :-
    forall((between(-3,3,A),between(-3,3,B),between(-3,3,C)),
        (Data=[A,B,C],Mean is (A+B+C) rdiv 3,
         maplist(center_square(Mean),Data,Squares),sum_list(Squares,SS),
         'stats-mean'(Data,ActualMean),assertion(ActualMean == Mean),
         forall(between(0,2,D),
                ('stats-variance'(Data,D,Actual),Expected is SS rdiv (3-D),
                 assertion(Actual == Expected))),
         maplist(affine,Data,Other),
         'stats-covariance'(Data,Other,1,Cov),assertion(Cov =:= 3*SS rdiv 2),
         (SS > 0
         -> 'stats-correlation'(Data,Other,Correlation),assertion(Correlation == 1.0),
            'stats-regression'(Data,Other,false,Fit),assertion(Fit == ['linear-fit',3,7])
         ; true))).

test(sum_and_mean_round_after_cancellation_or_division) :-
    'stats-sum'([],Zero),assertion(Zero == 0),
    'stats-sum'([1.0e308,1,-1.0e308],One),assertion(One == 1.0),
    'stats-mean'([1.0e308,1.0e308],Mean),assertion(Mean == 1.0e308),
    Third is 1 rdiv 3,'stats-sum'([Third,Third,Third],Whole),assertion(Whole == 1).

test(root_precedes_floating_overflow_and_underflow) :-
    'stats-variance'([-1.0e308,1.0e308],0,Overflow),assertion(Overflow == 1.0Inf),
    'stats-stdev'([-1.0e308,1.0e308],0,Large),assertion(Large == 1.0e308),
    'stats-variance'([-1.0e-300,1.0e-300],0,Underflow),assertion(Underflow == 0.0),
    'stats-stdev'([-1.0e-300,1.0e-300],0,Small),assertion(Small == 1.0e-300),
    Big is 1<<2000,Tiny is 1 rdiv Big,
    fraction_sqrt(Big,Root),assertion(Root =:= float(1<<1000)),
    fraction_sqrt(Tiny,TinyRoot),assertion(TinyRoot =:= float(1 rdiv (1<<1000))).

test(shared_root_is_an_explicit_native_import) :-
    assertion(predicate_property(lib_statistics:fraction_sqrt(_,_),imported_from(lib_vector))).

test(geometric_exponent_cancellation_and_equal_input_bounds) :-
    Big is 1<<2000,Tiny is 1 rdiv Big,
    'stats-geometric-mean'([Big,Tiny],One),assertion(One == 1.0),
    'stats-geometric-mean'([Big,Big,Tiny,Tiny],Again),assertion(Again == 1.0),
    forall(member(Value,[1.0e308,5.0e-324,1.0,1.7976931348623157e308]),
           ('stats-geometric-mean'([Value,Value,Value],Mean),assertion(Mean == Value))),
    'stats-geometric-mean'([54,24,36],ThirtySix),assertion(ThirtySix == 36.0),
    'stats-geometric-mean'([0,Big],Zero),assertion(Zero == 0.0).

test(harmonic_mean_preserves_exact_reciprocals) :-
    'stats-harmonic-mean'([40,60],Value),assertion(Value == 48),
    'stats-harmonic-mean'([40.0,60],Float),assertion(Float == 48.0),
    Tiny is 1 rdiv (1<<2000),
    'stats-harmonic-mean'([Tiny,Tiny],Same),assertion(Same == Tiny),
    'stats-harmonic-mean'([0,1],Zero),assertion(Zero == 0).

test(quantile_endpoints_and_partition_consistency) :-
    forall((between(2,20,N),between(1,20,Partitions)),
        (numlist(1,N,Data),
         'stats-quantile'(Data,0,inclusive,Low),assertion(Low == 1),
         'stats-quantile'(Data,1,inclusive,High),assertion(High == N),
         forall(member(Method,[inclusive,exclusive]),
             ('stats-quantiles'(Data,Partitions,Method,Cuts),
              ExpectedLength is Partitions-1,assertion(length(Cuts,ExpectedLength)),
              msort(Cuts,Sorted),assertion(Sorted == Cuts),
              forall(nth0(I,Cuts,Value),
                  (P is (I+1) rdiv Partitions,
                   'stats-quantile'(Data,P,Method,Individual),assertion(Individual == Value))))))),
    'stats-quantile'([0,10],0,exclusive,Before),assertion(Before == -10),
    'stats-quantile'([0,10],1,exclusive,After),assertion(After == 20).

test(singleton_quantiles_validate_all_arguments) :-
    'stats-quantiles'([7],1,inclusive,Empty),assertion(Empty == []),
    'stats-quantiles'([7],4,exclusive,Repeated),assertion(Repeated == [7,7,7]),
    must_throw('stats-quantiles'([7],1,missing,_),error(domain_error(quantile_method,missing),_)),
    must_throw('stats-quantile'([7],2,inclusive,_),error(domain_error(probability,2),_)),
    must_throw('stats-quantiles'([],1,inclusive,_),error(domain_error(statistical_sample_size,0-0),_)).

test(median_and_numeric_promotion) :-
    'stats-median'([9,1,4],Middle),assertion(Middle == 4),
    'stats-median'([1,2],Half),assertion(Half =:= 3 rdiv 2),
    'stats-median'([9.0,1,4],Float),assertion(Float == 4.0),
    'stats-quantile'([0,10],0.25,inclusive,Q),assertion(Q =:= 5 rdiv 2).

test(mode_ties_keep_terms_and_first_occurrence_order) :-
    findall(X,'stats-mode'([b,a,b,a,c],X),Modes),assertion(Modes == [b,a]),
    findall(X,'stats-mode'([1,1.0],X),Numbers),assertion(Numbers == [1,1.0]),
    once('stats-mode'([['+',1,2],['+',1,2],9],Held)),assertion(Held == ['+',1,2]),
    once('stats-mode'([b,a,b,a],First)),assertion(First == b),
    once('stats-mode'([X,X,Y],Variable)),assertion(Variable == X),assertion(var(Y)).

test(rank_ties_match_less_and_equal_counts) :-
    forall((between(-2,2,A),between(-2,2,B),between(-2,2,C)),
        (Data=[A,B,C],'stats-ranks'(Data,Ranks),
         forall(nth0(I,Data,X),
             (findall(1,(member(Y,Data),Y < X),Less),length(Less,L),
              findall(1,(member(Y,Data),Y =:= X),Equal),length(Equal,E),
              Expected is L+(E+1) rdiv 2,nth0(I,Ranks,Actual),
              assertion(Actual == Expected))))),
    'stats-ranks'([1,1.0,2],Mixed),Half is 3 rdiv 2,assertion(Mixed == [Half,Half,3]),
    'stats-ranks'([],Empty),assertion(Empty == []).

test(regression_models_have_their_identifiable_domains) :-
    'stats-regression'([2],[6],true,Origin),assertion(Origin == ['linear-fit',3,0]),
    'stats-regression'([0,1,2],[7,7,7],false,Constant),
    assertion(Constant == ['linear-fit',0,7]),
    'stats-regression'([0.0,1,2],[1,5,9],false,Float),
    assertion(Float == ['linear-fit',4.0,1.0]),
    must_throw('stats-regression'([1],[2],false,_),error(domain_error(statistical_sample_size,1-1),_)),
    must_throw('stats-regression'([0],[2],true,_),error(domain_error(identifiable_regression,[0]),_)),
    must_throw('stats-regression'([1,1],[2,3],false,_),error(domain_error(identifiable_regression,[1,1]),_)).

test(numeric_refusals_cover_complete_inputs) :-
    must_throw('stats-mean'([1|bad],_),error(type_error(list(number),_),_)),
    Cycle=[1|Cycle],must_throw('stats-sum'(Cycle,_),error(type_error(list(number),_),_)),
    must_throw('stats-sum'([_],_),error(instantiation_error,_)),
    forall(member(Goal,['stats-geometric-mean'([0,-1],_),
                        'stats-harmonic-mean'([0,-1],_)]),
           must_throw(Goal,error(domain_error(nonnegative_observation,-1),_))),
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
                            'stats-regression'([1],[Value],true,_)]),
               must_throw(Goal,error(domain_error(finite_observation,_),_)))),
    Term=[x|Term],must_throw('stats-mode'([Term],_),
                            error(representation_error(cyclic_statistical_data),_)).

test(sample_size_and_pair_refusals) :-
    forall(member(Goal,['stats-mean'([],_),'stats-median'([],_),
                        'stats-geometric-mean'([],_),'stats-harmonic-mean'([],_),
                        'stats-mode'([],_),'stats-variance'([],0,_),
                        'stats-stdev'([],0,_)]),
           must_throw(Goal,error(domain_error(statistical_sample_size,0-0),_))),
    must_throw('stats-variance'([1],1,_),error(domain_error(statistical_sample_size,1-1),_)),
    must_throw('stats-variance'([1,2],-1,_),error(type_error(nonneg,-1),_)),
    must_throw('stats-covariance'([1,2],[1],0,_),
               error(domain_error(paired_observation_lengths,2-1),_)),
    must_throw('stats-correlation'([1,1],[2,3],_),
               error(domain_error(nonconstant_observations,_),_)).

test(configured_approximation_refuses_exact_results) :-
    (current_prolog_flag(max_rational_size,Size) -> true ; Size=infinite),
    current_prolog_flag(max_rational_size_action,Action),
    setup_call_cleanup(true,
        (set_prolog_flag(max_rational_size,1),set_prolog_flag(max_rational_size_action,float),
         forall(member(Goal,['stats-mean'([1,2,2],_),
                             'stats-harmonic-mean'([2,3],_),
                             'stats-quantile'([1,2],0.25,inclusive,_),
                             'stats-quantiles'([1,2],4,inclusive,_),
                             'stats-ranks'([1,1,2],_)]),
                must_throw(Goal,error(representation_error(exact_statistics_arithmetic),_)))),
        (set_prolog_flag(max_rational_size,Size),set_prolog_flag(max_rational_size_action,Action))).

test(cancellation_and_concurrent_reads_leave_no_state) :-
    getrand(Before),length(Data,100000),maplist(=(1),Data),
    call_with_inference_limit('stats-mean'(Data,_),10000,Status),
    assertion(Status == inference_limit_exceeded),
    concurrent(2,[lib_statistics:'stats-mean'([1,2,3],Mean),
                  lib_statistics:'stats-variance'([1,2,3],1,Variance)],[]),
    assertion(Mean == 2),assertion(Variance == 1),
    getrand(After),assertion(After == Before).

:- end_tests(lib_statistics).
