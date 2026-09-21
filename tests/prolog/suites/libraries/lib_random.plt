% Purpose: verify MeTTa sample programs, numeric domains and generator ownership.
% Guarantees: all ten moment checks and the preceding occurrence/extreme cases
% exercise the public equations, including demand, cancellation and concurrency.
% [tested: lib_random; commit=1d0b78a359f58de49f2f98bed50a6480d56cd5f6].
% Owns resources: each test borrows and restores its host generator state;
% concurrent/3 joins its workers and the inference-limit test closes its scope.

:- use_module(collection_test_support).
:- use_module(library(random), [getrand/1, setrand/1, random/1]).
:- use_module(library(lists), [member/2, numlist/3, append/3]).
:- use_module(library(apply), [include/3, foldl/4]).
:- use_module(library(thread), [concurrent/3]).

:- use_module('library_assertions.pl', [must_throw/2]).

:- begin_tests(lib_random, [setup(load_collection_library(lib_random))]).
:- meta_predicate with_seed(+, 0).

with_seed(Seed, Goal) :-
    setup_call_cleanup(getrand(State),(set_random(seed(Seed)),Goal),setrand(State)).

% Prepare before repeat, including zero repetitions; eval preserves the stream.
draw(Constructor, Count, Value) :-
    eval_expr([let,Program,Constructor,[repeat,Count,Program]],Value).

constructor(Constructor, Program) :-
    Constructor=[Head|Arguments],append(Arguments,[Program],Outputs),
    Goal=..[Head|Outputs],invoke(Goal).

test(choice_preserves_held_terms_and_occurrence_weights) :-
    with_seed(1977,
        (constructor(['random-choice',[['+',1,2]]],Literal),
         once(eval_expr(Literal,Term)),assertion(Term == ['+',1,2]),
         constructor(['random-choice',[a,a,b]],Program),
         findall(X,eval_expr([repeat,6000,Program],X),Draws),
         include(=(a),Draws,As),length(As,Count),assertion(abs(Count-4000) < 240))).

test(shuffle_and_sampling_preserve_occurrences) :-
    forall(between(1,32,Seed),
        with_seed(Seed,
            (Items=[a,a,b,c,d],
             invoke('random-shuffle!'(Items,Shuffled)),msort(Shuffled,Sorted),
             assertion(Sorted == Items),
             invoke('random-sample!'(Items,5,All)),msort(All,AllSorted),
             assertion(AllSorted == Items),
             constructor(['random-choice',[x]],Choice),
             findall(X,eval_expr([repeat,17,Choice],X),Repeated),
             assertion(length(Repeated,17)),
             assertion(\+ (member(X,Repeated),X \== x)),
             numlist(1,12,Population),
             forall(between(0,12,Count),
                    (invoke('random-sample!'(Population,Count,Sample)),
                     assertion(length(Sample,Count)),sort(Sample,Unique),
                     assertion(length(Unique,Count)),
                     forall(member(Value,Sample),assertion(between(1,12,Value)))))))).

test(empty_and_degenerate_cases_consume_no_state) :-
    with_seed(42,
        (getrand(Before),
         constructor(['random-choice',[only]],Choice),
         once(eval_expr(Choice,One)),assertion(One == only),
         invoke('random-shuffle!'([],Empty)),assertion(Empty == []),
         invoke('random-shuffle!'([only],Singleton)),assertion(Singleton == [only]),
         invoke('random-sample!'([],0,A)),assertion(A == []),
         findall(X,draw(['random-normal',0,1],0,X),None),assertion(None == []),
         forall(member(Spec-Expected,
                       [['random-uniform',4,4]-4.0,['random-normal',7,0]-7.0,
                        ['random-lognormal',0,0]-1.0,['random-triangular',3,3,3]-3.0,
                        ['random-bernoulli',0]-false,['random-bernoulli',1]-true]),
                (findall(X,draw(Spec,3,X),Values),
                 assertion(Values == [Expected,Expected,Expected]))),
         getrand(After),assertion(After == Before))).

test(cut_consumes_only_the_demanded_prefix) :-
    with_seed(42,
        (getrand(Start),once(draw(['random-normal',0,1],100,First)),getrand(AfterCut),
         setrand(Start),once(draw(['random-normal',0,1],1,Only)),getrand(AfterOne),
         assertion(First == Only),assertion(AfterCut == AfterOne))).

test(normal_uses_only_the_host_generator) :-
    with_seed(314159,
        (getrand(Start),random(U),random(V),getrand(ExpectedState),
         Expected is cos(2*pi*U)*sqrt(-2*log(V)),setrand(Start),
         once(draw(['random-normal',0,1],1,Actual)),getrand(ActualState),
         assertion(Actual == Expected),assertion(ActualState == ExpectedState))).

distribution(['random-uniform',-2,4], 1, 3).
distribution(['random-normal',2,3], 2, 9).
distribution(['random-lognormal',0,0.5], exp(0.125), (exp(0.25)-1)*exp(0.25)).
distribution(['random-exponential',2], 0.5, 0.25).
distribution(['random-triangular',0,4,1], 5/3, 13/18).
distribution(['random-gamma',2,3], 6, 18).
distribution(['random-beta',2,5], 2/7, 10/392).
distribution(['random-bernoulli',0.3], 0.3, 0.21).
distribution(['random-pareto',5], 1.25, 5/48).
distribution(['random-weibull',3,2], 1.5*sqrt(pi), 9*(1-pi/4)).

test(constructors_are_typed_rewrites_and_construction_consumes_no_state) :-
    with_seed(42,
        (getrand(Before),
         forall(distribution(Spec,_,_),
             (Spec=[Head|Arguments],constructor(Spec,Program),
              assertion(is_list(Program)),
              once(eval_expr([match,'&self',[:,Head,Type],Type],Declared)),
              assertion(Declared = ['->'|_]),
              once(eval_expr([match,'&self',[=,[Head|Arguments],Body],Body],Recipe)),
              assertion(nonvar(Recipe)))),
         getrand(After),assertion(After == Before))).

numeric(Value, Number) :-
    (Value == true -> Number=1 ; Value == false -> Number=0 ; Number=Value).

moment(Value, Sum-SquareSum, Next-NextSquare) :-
    numeric(Value,X),Next is Sum+X,NextSquare is SquareSum+X*X.

test(distributions_have_their_expected_moments) :-
    forall(distribution(Spec,MeanExpr,VarianceExpr),
        with_seed(1729,
            (findall(X,draw(Spec,10000,X),Values),
             assertion(length(Values,10000)),
             foldl(moment,Values,0.0-0.0,Sum-Squares),
             Mean is Sum/10000,Variance is Squares/10000-Mean*Mean,
             ExpectedMean is MeanExpr,ExpectedVariance is VarianceExpr,
             assertion(abs(Mean-ExpectedMean) < 8*sqrt(ExpectedVariance/10000)),
             assertion(abs(Variance-ExpectedVariance) < 0.65*ExpectedVariance)))).

test(bounded_support_including_extreme_interpolation) :-
    forall(member(Spec-Low-High,
                  [['random-uniform',-1.0e308,1.0e308]-(-1.0e308)-1.0e308,
                   ['random-triangular',-1.0e308,1.0e308,0]-(-1.0e308)-1.0e308,
                   ['random-triangular',0,1,0]-0-1,['random-triangular',0,1,1]-0-1,
                   ['random-beta',0.001,0.001]-0-1,
                   ['random-beta',5.0e-324,5.0e-324]-0-1]),
        with_seed(23,
            forall(draw(Spec,256,X),(assertion(X >= Low),assertion(X =< High))))).

test(gamma_scale_and_beta_ratio_preserve_range) :-
    with_seed(2,(once(draw(['random-gamma',0.001,1],1,Small)),assertion(Small == 0.0))),
    with_seed(2,(once(draw(['random-gamma',0.001,1.0e300],1,Rescued)),
                 assertion(Rescued > 2.64e-34),assertion(Rescued < 2.66e-34))),
    with_seed(42,
        (once(draw(['random-gamma',1.0e308,1],1,Huge)),assertion(Huge == 1.0e308),
         once(draw(['random-beta',1.0e308,1.0e308],1,Half)),assertion(Half == 0.5),
         once(draw(['random-weibull',1.0e308,1.0e308],1,Scale)),assertion(Scale == 1.0e308),
         once(draw(['random-gamma',1.0e308,5.0e-324],1,Finite)),
         assertion(Finite > 4.94e-16),assertion(Finite < 4.95e-16))).

test(saturation_and_signed_degenerate_values) :-
    once(draw(['random-normal',-0.0,0],1,Zero)),assertion(copysign(1.0,Zero) =:= -1.0),
    once(draw(['random-lognormal',1000,0],1,Inf)),assertion(Inf == 1.0Inf),
    once(draw(['random-lognormal',-1000,0],1,Tiny)),assertion(Tiny == 0.0).

test(parameter_refusals_leave_state_unchanged) :-
    with_seed(123,
        (getrand(Before),
         refused('random-choice'([],_)),
         refused('random-shuffle!'([a|bad],_)),
         Cycle=[a|Cycle],refused('random-shuffle!'(Cycle,_)),
         refused('random-sample!'([],1,_)),
         refused('random-sample!'([a],2,_)),
         refused('random-sample!'([a],1.0,_)),
         refused('random-sample!'([a],-1,_)),
         forall(member(Spec,
                       [['random-uniform',2,1],['random-normal',0,-1],
                        ['random-lognormal',0,-1],['random-exponential',0],
                        ['random-triangular',0,1,2],['random-gamma',-1,2],
                        ['random-beta',2,0],['random-bernoulli',1.1],
                        ['random-pareto',0],['random-weibull',0,1]]),
                (Spec=[Head|Arguments],append(Arguments,[_],All),
                 Goal=..[Head|All],refused(Goal))),
         forall(member(Value,[1.0Inf,-1.0Inf,1.5NaN]),
                refused('random-normal'(Value,1,_))),
         refused('random-normal'(bad,1,_)),
         getrand(After),assertion(After == Before))).

test(engine_seed_scope_restores_completion_cut_exception_and_cancellation) :-
    with_seed(123,
        (getrand(Before),
         findall(X,metta_engine:metta_with_seed(99,[],
                     plunit_lib_random:draw(['random-gamma',0.5,2],8,X),_),Values),
         assertion(length(Values,8)),getrand(AfterAnswers),assertion(AfterAnswers == Before),
         once(metta_engine:metta_with_seed(99,[],
                  plunit_lib_random:draw(['random-normal',0,1],100,_),_)),
         getrand(AfterCut),assertion(AfterCut == Before),
         must_throw(metta_engine:metta_with_seed(99,[],
                        plunit_lib_random:(draw(['random-normal',0,1],1,_),
                                           throw(error(probe,scope))),_),
                    error(probe,scope)),
         getrand(AfterError),assertion(AfterError == Before),
         constructor(['random-normal',0,1],Program),Seen=seen(false),
         call_with_inference_limit(
             metta_engine:metta_with_seed(99,[],
                 plunit_lib_random:(once(eval_expr(Program,_)),nb_setarg(1,Seen,true),
                                    findall(X,eval_expr([repeat,100000,Program],X),_)),_),
             50000,Outcome),assertion(Outcome == inference_limit_exceeded),
         assertion(Seen == seen(true)),
         getrand(AfterCancel),assertion(AfterCancel == Before))).

seeded_values(Seed, Values) :-
    with_seed(Seed,findall(X,draw(['random-normal',0,1],32,X),Values)).

test(concurrent_generators_replay_independently) :-
    getrand(Before),seeded_values(1,A),seeded_values(2,B),assertion(A \== B),
    concurrent(2,[plunit_lib_random:seeded_values(1,ActualA),
                  plunit_lib_random:seeded_values(2,ActualB)],[]),
    assertion(ActualA == A),assertion(ActualB == B),
    getrand(After),assertion(After == Before).

test(derived_draws_reach_the_declared_core_generator) :-
    assertion(seam:seeded_operation('random-float')),
    assertion(seam:seeded_operation('random-int')),
    with_seed(42,
        (constructor(['random-normal',0,1],Program),getrand(Before),
         once(eval_expr(Program,_)),getrand(After),assertion(After \== Before))).

test(literal_values_and_shared_variables_survive_programs_and_removal) :-
    forall(between(1,24,Seed),
        with_seed(Seed,
            (Items=[X,X,Y,['Error',data,code],['+',1,2],1,1.0],
             constructor(['random-choice',[X]],Choice),
             once(eval_expr(Choice,Chosen)),assertion(Chosen == X),
             invoke('random-shuffle!'(Items,Shuffled)),
             msort(Items,Expected),msort(Shuffled,Actual),assertion(Actual == Expected),
             assertion(var(X)),assertion(var(Y)),assertion(X \== Y)))).

test(arbitrary_programs_compose_without_a_distribution_registry) :-
    findall(X,eval_expr([repeat,2,[superpose,[a,b]]],X),Alternatives),
    assertion(Alternatives == [a,b,a,b]),
    findall(X,draw(['random-normal',[superpose,[1,2]],0],1,X),Parameters),
    assertion(Parameters == [1.0,2.0]),
    constructor(['random-uniform',2,10],[Head,_Entropy,Low,High]),
    once(eval_expr([Head,0.25,Low,High],Rewritten)),assertion(Rewritten == 4.0).

:- end_tests(lib_random).
