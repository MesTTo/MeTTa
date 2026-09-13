% Purpose: compare public MeTTa enumerations with independent counts and models.
% Guarantees: order, multiplicity, exact arithmetic, literal values and streaming
% first answers survive the derived operations.
% [tested: lib_combinatorics_surface; commit=WORKTREE].
:- use_module(collection_test_support).
:- use_module(library(lists), [append/3,member/2,numlist/3]).
:- use_module(library(apply), [foldl/4]).
:- use_module(library(yall), [(>>)/4]).
:- initialization(load_collection_library(lib_combinatorics)).

:- begin_tests(lib_combinatorics_surface).

test(permutations_are_counted_by_factorial, [forall(between(0,6,Size))]) :-
    collection_items(Size,Items),
    findall(P,collection_answers(permutations(Items,P)),Permutations),
    length(Permutations,Counted),invoke(factorial(Size,Expected)),
    assertion(Counted==Expected),
    sort(Permutations,Distinct),length(Distinct,DistinctCount),
    assertion(DistinctCount==Expected),
    forall(member(P,Permutations),msort(P,Items)).

test(subsets_are_counted_by_two_to_the_n, [forall(between(0,8,Size))]) :-
    collection_items(Size,Items),findall(S,collection_answers(subsets(Items,S)),Subsets),
    length(Subsets,Counted),Expected is 2**Size,assertion(Counted=:=Expected),
    sort(Subsets,Distinct),length(Distinct,DistinctCount),
    assertion(DistinctCount=:=Expected),
    forall(member(Subset,Subsets),ordered_sublist(Subset,Items)).
ordered_sublist([],_).
ordered_sublist([Item|More],Items) :-
    append(_,[Item|Rest],Items),ordered_sublist(More,Rest).

test(subsets_of_a_size_are_counted_by_binomial, [forall(between(0,7,Size))]) :-
    collection_items(Size,Items),findall(S,collection_answers(subsets(Items,S)),Subsets),
    forall(between(0,Size,Chosen),
        (findall(S,(member(S,Subsets),length(S,Chosen)),OfSize),
         length(OfSize,Counted),invoke(binomial(Size,Chosen,Expected)),
         assertion(Counted==Expected))).

test(tuples_are_counted_by_the_product_of_the_sizes) :-
    findall(T,collection_answers(tuples([[a,b,c],[1,2],[x]],T)),Tuples),
    assertion(Tuples==[[a,1,x],[a,2,x],[b,1,x],[b,2,x],[c,1,x],[c,2,x]]),
    findall(T,collection_answers(tuples([],T)),Empty),assertion(Empty==[[]]),
    findall(T,collection_answers(tuples([[a],[]],T)),None),assertion(None==[]),
    refused(tuples(notalist,_)),refused(tuples([notalist],_)),
    refused(tuples([[],notalist],_)).

test(a_power_is_counted_by_the_size_to_the_length, [forall(between(0,5,Length))]) :-
    findall(T,collection_answers('cartesian-power'([0,1,2],Length,T)),Tuples),
    length(Tuples,Counted),Expected is 3**Length,assertion(Counted=:=Expected),
    forall(member(Tuple,Tuples),length(Tuple,Length)).

test(a_stepped_range_stops_before_its_end) :-
    forall(member(Low-High-Step-Expected,
                  [0-10-3-[0,3,6,9],0-9-3-[0,3,6],5-0-(-2)-[5,3,1],
                   0-0-1-[],0-5-(-1)-[],0-1-1-[0],0.5-2.0-1-[0.5,1.5]]),
        (findall(V,collection_answers('range-step'(Low,High,Step,V)),Actual),
         assertion(Actual==Expected))),
    refused('range-step'(0,5,0,_)),refused('range-step'(0,5,half,_)),
    refused('range-step'(0,5,1.0,_)),
    once(invoke('range-step'(1.0e20,1.0e21,1,1.0e20))),
    catch(findall(V,collection_answers('range-step'(1.0e20,1.0e21,1,V)),_),Error,true),
    assertion(nonvar(Error)).

test(factorial_is_the_product_of_its_range, [forall(between(0,12,Number))]) :-
    invoke(factorial(Number,Answer)),collection_items(Number,Items),
    foldl([X,A0,A]>>(A is A0*X),Items,1,Expected),
    assertion(Answer==Expected).

test(binomial_is_pascals_triangle, [forall(between(0,20,Count))]) :-
    forall(between(0,Count,Chosen),
        (invoke(binomial(Count,Chosen,Answer)),
         ( (Count=:=0;Chosen=:=0;Chosen=:=Count)
         -> assertion(Answer==1)
         ; Above is Count-1,Left is Chosen-1,
           invoke(binomial(Above,Left,One)),invoke(binomial(Above,Chosen,Two)),
           Sum is One+Two,assertion(Answer==Sum)))),
    invoke(binomial(0,0,1)),invoke(binomial(5,6,0)),invoke(binomial(5,-1,0)).

test(permutation_count_is_binomial_times_factorial, [forall(between(0,15,Count))]) :-
    forall(between(0,Count,Chosen),
        (invoke('permutation-count'(Count,Chosen,Answer)),
         invoke(binomial(Count,Chosen,Choices)),invoke(factorial(Chosen,Orders)),
         Expected is Choices*Orders,assertion(Answer==Expected))),
    invoke('permutation-count'(5,6,0)),invoke('permutation-count'(5,-1,0)).

test(the_counts_stay_exact) :-
    invoke(factorial(30,F)),assertion(F==265252859812191058636308480000000),
    invoke(binomial(100,50,C)),assertion(C==100891344545564193334812497256),
    invoke('permutation-count'(100,5,P)),assertion(P==9034502400),
    assertion(integer(F)),assertion(integer(C)),assertion(integer(P)).

test(count_domains_are_checked_before_enumerating) :-
    forall(member(Goal,[factorial(-1,_),factorial(1.0,_),binomial(-1,0,_),
                        binomial(1,0.0,_),'permutation-count'(-1,0,_),
                        'cartesian-power'([a],-1,_),'cartesian-power'([a],1.0,_),
                        chooseK([a],-1,_),chooseK([a],1.0,_)]),refused(Goal)),
    findall(T,collection_answers('cartesian-power'([],100000000000000000000,T)),None),
    assertion(None==[]).

test(segment_choice_preserves_order_literals_and_variable_identity) :-
    Data=[['+',1,2],['Error',a,b]],
    findall(P,collection_answers(permutations(Data,P)),Ps),
    assertion(Ps==[Data,[['Error',a,b],['+',1,2]]]),
    findall(S,collection_answers(subsets(Data,S)),Ss),
    assertion(Ss==[Data,[['Error',a,b]],[['+',1,2]],[]]),
    invoke(chooseKl(Data,2,[Data])),
    invoke(choose2l([a,b,c],[[a,b],[a,c],[b,c]])),
    invoke(takeK(2,[X,Y,z],Prefix)),assertion(Prefix==[X,Y]),
    invoke(chooseK([X,Y],2,Chosen)),assertion(Chosen==[X,Y]),
    assertion(var(X)),assertion(var(Y)),
    numlist(1,100,Large),once(invoke(chooseK(Large,50,First))),
    numlist(1,50,Expected),assertion(First==Expected).

test(the_weighted_subset_heads_keep_their_contracts) :-
    Candidates=[[candidate,a,1,[ratio,1,2]],[candidate,b,1,[ratio,1,2]]],
    invoke('weighted-subset-mass-independent'(Candidates,1,[ratio,1,2])),
    invoke('weighted-subset-posterior-independent'(Candidates,1,Posterior)),
    assertion(Posterior==['subset-posterior',[ratio,1,2],
                          [['candidate-posterior',a,[ratio,1,2]],
                           ['candidate-posterior',b,[ratio,1,2]]]]),
    invoke('weighted-subset-mass-independent'(Candidates,9,[ratio,0,1])).

:- end_tests(lib_combinatorics_surface).
