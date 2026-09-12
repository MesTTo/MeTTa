% Purpose: verify occurrence sampling, distribution domains and generator ownership.
% Guarantees: seeded finite domains test multiplicities, supports and moments;
% scale and shape extremes retain representable results and every scope restores.
% [tested: lib_random; commit=505b45e1d9184608c818a8a4fdba5cf6406bf3e7].
% Owns resources: each test borrows and restores its host generator state;
% concurrent/3 joins its workers and the inference-limit test closes its scope.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module('../../../../lib/lib_random/lib_random').
:- use_module(library(random), [getrand/1, setrand/1, random/1]).
:- use_module(library(lists), [member/2, numlist/3]).
:- use_module(library(apply), [include/3, foldl/4]).
:- use_module(library(thread), [concurrent/3]).

:- begin_tests(lib_random).
:- meta_predicate with_seed(+, 0), must_throw(0, ?).

with_seed(Seed, Goal) :-
    setup_call_cleanup(getrand(State),(set_random(seed(Seed)),Goal),setrand(State)).

must_throw(Goal, Expected) :-
    catch(Goal,Error,true),assertion(nonvar(Error)),assertion(Error = Expected).

test(choice_preserves_held_terms_and_occurrence_weights) :-
    with_seed(1977,
        ('random-choice!'([['+',1,2]],Term),assertion(Term == ['+',1,2]),
         findall(X,(between(1,6000,_),'random-choice!'([a,a,b],X)),Draws),
         include(=(a),Draws,As),length(As,Count),assertion(abs(Count-4000) < 240))).

test(shuffle_and_sampling_preserve_occurrences) :-
    forall(between(1,32,Seed),
        with_seed(Seed,
            (Items=[a,a,b,c,d],
             'random-shuffle!'(Items,Shuffled),msort(Shuffled,Sorted),
             assertion(Sorted == Items),
             'random-sample!'(Items,5,false,All),msort(All,AllSorted),
             assertion(AllSorted == Items),
             'random-sample!'([x],17,true,Repeated),
             assertion(length(Repeated,17)),assertion(\+ (member(X,Repeated),X \== x)),
             numlist(1,12,Population),
             forall(between(0,12,Count),
                    ('random-sample!'(Population,Count,false,Sample),
                     assertion(length(Sample,Count)),sort(Sample,Unique),
                     assertion(length(Unique,Count)),
                     forall(member(Value,Sample),assertion(between(1,12,Value)))))))).

test(empty_and_degenerate_cases_consume_no_state) :-
    with_seed(42,
        (getrand(Before),
         'random-choice!'([only],One),assertion(One == only),
         'random-shuffle!'([],Empty),assertion(Empty == []),
         'random-sample!'([],0,true,A),'random-sample!'([],0,false,B),
         assertion(A == []),assertion(B == []),
         findall(X,'random-draw!'([normal,0,1],0,X),None),assertion(None == []),
         forall(member(Spec-Expected,[[uniform,4,4]-4.0,[normal,7,0]-7.0,
                                     [lognormal,0,0]-1.0,[triangular,3,3,3]-3.0,
                                     [bernoulli,0]-false,[bernoulli,1]-true]),
                (findall(X,'random-draw!'(Spec,3,X),Values),
                 assertion(Values == [Expected,Expected,Expected]))),
         getrand(After),assertion(After == Before))).

test(cut_consumes_only_the_demanded_prefix) :-
    with_seed(42,
        (getrand(Start),once('random-draw!'([normal,0,1],100,First)),getrand(AfterCut),
         setrand(Start),'random-draw!'([normal,0,1],1,Only),getrand(AfterOne),
         assertion(First == Only),assertion(AfterCut == AfterOne))).

test(normal_uses_only_the_host_generator) :-
    with_seed(314159,
        (getrand(Start),random(U),random(V),getrand(ExpectedState),
         Expected is cos(2*pi*U)*sqrt(-2*log(V)),setrand(Start),
         'random-draw!'([normal,0,1],1,Actual),getrand(ActualState),
         assertion(Actual == Expected),assertion(ActualState == ExpectedState))).

test(discovery_describes_every_constructor) :-
    'random-distributions'(Forms),assertion(length(Forms,10)),
    findall(Name,member(['random-distribution',Name,_],Forms),Names),
    assertion(Names == [uniform,normal,lognormal,exponential,triangular,gamma,beta,
                        bernoulli,pareto,weibull]),
    forall(member(['random-distribution',_,Parameters],Forms),
           forall(member(Parameter,Parameters),assertion(string(Parameter)))).

numeric(Value, Number) :-
    (Value == true -> Number=1 ; Value == false -> Number=0 ; Number=Value).

moment(Value, Sum-SquareSum, Next-NextSquare) :-
    numeric(Value,X),Next is Sum+X,NextSquare is SquareSum+X*X.

test(distributions_have_their_expected_moments) :-
    Cases=[[uniform,-2,4]-1-3,[normal,2,3]-2-9,
           [lognormal,0,0.5]-exp(0.125)-((exp(0.25)-1)*exp(0.25)),
           [exponential,2]-0.5-0.25,[triangular,0,4,1]-(5/3)-(13/18),
           [gamma,2,3]-6-18,[beta,2,5]-(2/7)-(10/392),
           [bernoulli,0.3]-0.3-0.21,[pareto,5]-1.25-(5/48),
           [weibull,3,2]-(1.5*sqrt(pi))-(9*(1-pi/4))],
    forall(member(Spec-MeanExpr-VarianceExpr,Cases),
        with_seed(1729,
            (findall(X,'random-draw!'(Spec,10000,X),Values),
             assertion(length(Values,10000)),
             foldl(moment,Values,0.0-0.0,Sum-Squares),
             Mean is Sum/10000,Variance is Squares/10000-Mean*Mean,
             ExpectedMean is MeanExpr,ExpectedVariance is VarianceExpr,
             assertion(abs(Mean-ExpectedMean) < 8*sqrt(ExpectedVariance/10000)),
             assertion(abs(Variance-ExpectedVariance) < 0.65*ExpectedVariance)))).

test(bounded_support_including_extreme_interpolation) :-
    forall(member(Spec-Low-High,[[uniform,-1.0e308,1.0e308]-(-1.0e308)-1.0e308,
                                [triangular,-1.0e308,1.0e308,0]-(-1.0e308)-1.0e308,
                                [triangular,0,1,0]-0-1,[triangular,0,1,1]-0-1,
                                [beta,0.001,0.001]-0-1,[beta,5.0e-324,5.0e-324]-0-1]),
        with_seed(23,
            forall('random-draw!'(Spec,256,X),
                   (assertion(X >= Low),assertion(X =< High))))).

test(gamma_scale_and_beta_ratio_preserve_range) :-
    with_seed(2,('random-draw!'([gamma,0.001,1],1,Small),assertion(Small == 0.0))),
    with_seed(2,('random-draw!'([gamma,0.001,1.0e300],1,Rescued),
                 assertion(Rescued > 2.64e-34),assertion(Rescued < 2.66e-34))),
    with_seed(42,
        ('random-draw!'([gamma,1.0e308,1],1,Huge),assertion(Huge == 1.0e308),
         'random-draw!'([beta,1.0e308,1.0e308],1,Half),assertion(Half == 0.5),
         'random-draw!'([weibull,1.0e308,1.0e308],1,Scale),assertion(Scale == 1.0e308),
         'random-draw!'([gamma,1.0e308,5.0e-324],1,Finite),
         assertion(Finite > 4.94e-16),assertion(Finite < 4.95e-16))).

test(saturation_and_signed_degenerate_values) :-
    'random-draw!'([normal,-0.0,0],1,Zero),assertion(copysign(1.0,Zero) =:= -1.0),
    'random-draw!'([lognormal,1000,0],1,Inf),assertion(Inf == 1.0Inf),
    'random-draw!'([lognormal,-1000,0],1,Tiny),assertion(Tiny == 0.0).

test(parameter_refusals_leave_state_unchanged) :-
    with_seed(123,
        (getrand(Before),
         must_throw('random-choice!'([],_),error(domain_error(nonempty_population,[]),_)),
         must_throw('random-shuffle!'([a|bad],_),error(type_error(list,_),_)),
         Cycle=[a|Cycle],must_throw('random-shuffle!'(Cycle,_),error(type_error(list,_),_)),
         must_throw('random-sample!'([],1,true,_),error(domain_error(nonempty_population,[]),_)),
         must_throw('random-sample!'([a],2,false,_),error(domain_error(sample_size,2-1),_)),
         must_throw('random-sample!'([a],0,7,_),error(type_error(boolean,7),_)),
         must_throw('random-sample!'([a],-1,true,_),error(type_error(nonneg,-1),_)),
         must_throw('random-draw!'([missing,1],0,_),error(domain_error(random_distribution,_),_)),
         must_throw('random-draw!'([normal,0],1,_),error(domain_error(random_distribution,_),_)),
         forall(member(Spec,[[uniform,2,1],[normal,0,-1],[lognormal,0,-1],
                             [exponential,0],[triangular,0,1,2],[gamma,-1,2],
                             [beta,2,0],[bernoulli,1.1],[pareto,0],[weibull,0,1]]),
                must_throw('random-draw!'(Spec,0,_),
                           error(domain_error(random_distribution_parameters,Spec),_))),
         forall(member(Value,[1.0Inf,-1.0Inf,1.5NaN]),
                must_throw('random-draw!'([normal,Value,1],1,_),
                           error(domain_error(finite_random_parameter,_),_))),
         must_throw('random-draw!'([normal,bad,1],1,_),error(type_error(number,bad),_)),
         getrand(After),assertion(After == Before))).

test(engine_seed_scope_restores_completion_cut_exception_and_cancellation) :-
    with_seed(123,
        (getrand(Before),
         findall(X,metta_engine:metta_with_seed(99,[],
                     lib_random:'random-draw!'([gamma,0.5,2],8,X),_),Values),
         assertion(length(Values,8)),getrand(AfterAll),assertion(AfterAll == Before),
         once(metta_engine:metta_with_seed(99,[],
                  lib_random:'random-draw!'([normal,0,1],100,_),_)),
         getrand(AfterCut),assertion(AfterCut == Before),
         must_throw(metta_engine:metta_with_seed(99,[],
                        (lib_random:'random-draw!'([normal,0,1],1,_),throw(error(probe,scope))),_),
                    error(probe,scope)),
         getrand(AfterError),assertion(AfterError == Before),
         call_with_inference_limit(
             metta_engine:metta_with_seed(99,[],
                 findall(X,lib_random:'random-draw!'([normal,0,1],100000,X),_),_),
             5000,Outcome),assertion(Outcome == inference_limit_exceeded),
         getrand(AfterCancel),assertion(AfterCancel == Before))).

seeded_values(Seed, Values) :-
    with_seed(Seed,findall(X,'random-draw!'([normal,0,1],32,X),Values)).

test(concurrent_generators_replay_independently) :-
    getrand(Before),seeded_values(1,A),seeded_values(2,B),assertion(A \== B),
    concurrent(2,[plunit_lib_random:seeded_values(1,ActualA),
                  plunit_lib_random:seeded_values(2,ActualB)],[]),
    assertion(ActualA == A),assertion(ActualB == B),
    getrand(After),assertion(After == Before).

test(draws_declare_seed_dependence) :-
    forall(member(Name,['random-choice!','random-shuffle!','random-sample!','random-draw!']),
           assertion(seam:seeded_operation(Name))).

:- end_tests(lib_random).
