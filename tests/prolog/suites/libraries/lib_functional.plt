% Purpose: compare derived MeTTa transformations with independent list models.
% Guarantees: generated inputs cover slicing, flattening, stable keys, branching
% callbacks, held controls, literal values and variable identity.
% [tested: lib_functional; commit=6471fbad35eced5ed6440ebf2c25a053b20221f3].
% Owns resources: the loop fixture uses one garbage-collected state cell.
:- use_module(collection_test_support).
:- use_module(library(lists), [append/2,append/3,flatten/2,last/2,member/2,
                              nth1/3,numlist/3,sum_list/2]).
:- use_module(library(apply), [exclude/3,maplist/2,maplist/3]).
:- use_module(library(pairs), [pairs_values/2]).
:- use_module(library(random), [random_between/3,random_permutation/2]).
:- initialization(functional_suite_setup).
functional_suite_setup :-
    load_collection_library(lib_functional),
    filereader:metta_host_run_source("(= (remainder $x) (% $x 5))",'&self',[],_).

:- begin_tests(lib_functional).

test(zip_and_unzip_round_trip,
     [forall(member(Left-Right,[0-0,0-3,3-0,1-1,4-7,7-4,40-40]))]) :-
    collection_items(Left,Lefts),collection_items(Right,Rights),invoke(zip(Lefts,Rights,Pairs)),
    length(Pairs,Paired),Expected is min(Left,Right),assertion(Paired==Expected),
    forall(nth1(Index,Pairs,Pair),
        (nth1(Index,Lefts,L),nth1(Index,Rights,R),assertion(Pair==[L,R]))),
    (Left==Right->invoke(unzip(Pairs,Sides)),assertion(Sides==[Lefts,Rights]);true).

test(drop_is_the_suffix_append_names, [forall(between(0,12,Size))]) :-
    collection_items(Size,Items),
    forall(between(0,15,Count),
        (invoke(drop(Items,Count,Rest)),
         (Count=<Size->length(Prefix,Count),append(Prefix,Rest,Items)
         ; assertion(Rest==[])))).

test(chunks_partition_the_collection, [forall(between(0,17,Size))]) :-
    collection_items(Size,Items),
    forall(between(1,6,Cut),
        (invoke(chunk(Items,Cut,Chunks)),append(Chunks,Rejoined),
         assertion(Rejoined==Items),length(Chunks,Count),
         Ceiling is (Size+Cut-1)//Cut,assertion(Count==Ceiling),
         forall((nth1(Index,Chunks,Chunk),Index<Count),
                (length(Chunk,Full),assertion(Full==Cut))),
         (Chunks==[]->assertion(Size==0)
         ; last(Chunks,Last),length(Last,Tail),assertion(Tail=<Cut),assertion(Tail>0)))).

test(windows_are_every_run_of_the_size, [forall(between(0,17,Size))]) :-
    collection_items(Size,Items),
    forall(between(1,6,Width),
        (invoke(window(Items,Width,Windows)),length(Windows,Count),
         Expected is max(0,Size-Width+1),assertion(Count==Expected),
         forall(nth1(Index,Windows,Window),
            (Offset is Index-1,length(Before,Offset),append(Before,Rest,Items),
             length(Run,Width),append(Run,_,Rest),assertion(Window==Run))))),
    invoke(window(Items,1,Singles)),maplist(single,Items,Singly),
    assertion(Singles==Singly).
single(Item,[Item]).

test(one_level_flatten_is_the_concatenation, [forall(between(0,8,Size))]) :-
    collection_items(Size,Sizes),maplist(collection_items,Sizes,Nested),
    invoke('flatten-once'(Nested,Flat)),append(Nested,Concatenated),
    assertion(Flat==Concatenated),
    invoke('flatten-once'([[1,2],three,[],[[4]]],[1,2,three,[4]])).

test(the_deep_flatten_agrees_with_library_lists) :-
    set_random(seed(20260912)),
    forall(between(1,200,_),
        (nested(3,Nested),invoke('flatten-deep'(Nested,Mine)),
         flatten(Nested,Host),assertion(Mine==Host))),
    invoke('flatten-deep'([[[[]]],[]],[])),
    invoke('flatten-deep'([1,[2,[3,[4]]]],[1,2,3,4])).
nested(0,Leaf) :- !,leaf(Leaf).
nested(Depth,Items) :-
    random_between(0,4,Length),Deeper is Depth-1,length(Items,Length),
    maplist(nested_element(Deeper),Items).
nested_element(Depth,Item) :-
    random_between(0,2,Choice),(Choice==0->leaf(Item);nested(Depth,Item)).
leaf(Leaf) :-
    random_between(1,3,Which),nth1(Which,[a,1,[]],Leaf).

test(grouping_and_sorting_are_stable) :-
    set_random(seed(20260912)),numlist(1,40,Ordered),random_permutation(Ordered,Items),
    invoke('sort-by'(remainder,Items,Sorted)),
    findall(Key-Item,(member(Item,Items),Key is Item mod 5),Keyed),
    keysort(Keyed,Stable),pairs_values(Stable,Expected),assertion(Sorted==Expected),
    invoke('group-by'(remainder,Items,Groups)),
    findall(K,member([K,_],Groups),Keys),
    findall(K,(member(I,Items),K is I mod 5),Answers),
    first_appearances(Answers,First),assertion(Keys==First),
    forall(member([K,Members],Groups),
        (findall(I,(member(I,Items),K=:=I mod 5),InOrder),assertion(Members==InOrder))),
    invoke('group-by'(remainder,[],[])),
    findall(M,(member([_,Ms],Groups),member(M,Ms)),Gathered),
    msort(Gathered,SortedGathered),msort(Items,SortedItems),
    assertion(SortedGathered==SortedItems).
first_appearances([],[]).
first_appearances([Key|Keys],[Key|First]) :-
    exclude(==(Key),Keys,Rest),first_appearances(Rest,First).

test(scan_is_every_prefix_fold, [forall(between(0,12,Size))]) :-
    collection_items(Size,Items),invoke(scan('+',0,Items,Running)),
    length(Running,Count),Expected is Size+1,assertion(Count==Expected),
    forall(nth1(Index,Running,Value),
        (Taken is Index-1,length(Prefix,Taken),append(Prefix,_,Items),
         sum_list(Prefix,Sum),assertion(Value==Sum))),
    invoke(scan('+',7,[],[7])).

test(unfold_is_the_inverse_of_a_fold, [forall(member(Size,[0,1,5,20]))]) :-
    Limit is Size+1,
    Step=['|->',[N],[if,['<',N,Limit],[N,['+',N,1]],[empty]]],
    invoke(unfold(Step,1,Grown)),collection_items(Size,Items),assertion(Grown==Items).

test(pipe_and_apply_to_compose_through_the_evaluator) :-
    invoke('apply-to'('+',[1,2],3)),invoke('apply-to'('-',[10,4],6)),
    invoke(pipe([],seed,seed)),invoke(pipe([remainder,remainder],12,2)),
    invoke(partition(remainder,[5,6,10,11],[[],[5,6,10,11]])).

test(the_control_forms_run_their_body_the_counted_number_of_times) :-
    findall(V,collection_answers(repeat(4,['+',1,1],V)),Repeated),
    assertion(Repeated==[2,2,2,2]),
    findall(V,collection_answers(repeat(0,['+',1,1],V)),[]),
    findall(V,collection_answers(unless(false,ran,V)),[ran]),
    findall(V,collection_answers(unless(true,ran,V)),[]),
    findall(V,collection_answers(while(false,ran,V)),[]),
    invoke('new-state'(0,Cell)),
    Condition=['<',['get-state',Cell],5],
    Body=[let,Next,['+',['get-state',Cell],1],
          [let,_Changed,['change-state!',Cell,Next],Next]],
    findall(V,collection_answers(while(Condition,Body,V)),Counted),
    assertion(Counted==[1,2,3,4,5]),invoke('get-state'(Cell,5)).

test(invalid_collections_counts_and_steps_are_refused) :-
    forall(member(Goal,[chunk([1],0,_),chunk([1],-3,_),chunk([1],1.0,_),
                        window([1],0,_),drop([1],-2,_),
                        unzip([nopair],_),unzip([[1,2,3]],_),
                        zip(nolist,[],_),zip([],nolist,_),drop(nolist,0,_),
                        chunk(nolist,1,_),window(nolist,1,_),
                        'flatten-once'(nolist,_),'flatten-deep'(nolist,_),
                        partition(remainder,nolist,_),'group-by'(remainder,nolist,_),
                        'sort-by'(remainder,nolist,_),scan('+',0,nolist,_),
                        unzip(nolist,_),'apply-to'('+',nolist,_),pipe(nolist,1,_)]),
           refused(Goal)),
    Malformed=['|->',[N],[if,['==',N,0],[1,2,3],[empty]]],
    refused(unfold(Malformed,0,_)).

test(callback_alternatives_are_paths_and_predicates_ask_for_true) :-
    Add=['|->',[A,B],[superpose,[['+',A,B],['+',1,['+',A,B]]]]],
    findall(H,collection_answers(scan(Add,0,[1,2],H)),Histories),
    assertion(Histories==[[0,1,3],[0,1,4],[0,2,4],[0,2,5]]),
    Step=['|->',[N],[if,['<',N,2],
                    [superpose,[[N,['+',N,1]],[['+',N,10],['+',N,1]]]],[empty]]],
    findall(L,collection_answers(unfold(Step,0,L)),Lists),
    assertion(Lists==[[0,1],[0,11],[10,1],[10,11]]),
    Both=['|->',[_],[superpose,[false,true]]],
    None=['|->',[_],[empty]],
    invoke(partition(Both,[1,2],[[1,2],[]])),
    invoke(partition(None,[1,2],[[],[1,2]])),
    findall(H,collection_answers(scan(['|->',[_,_],[empty]],0,[1],H)),[]).

test(literal_values_and_caller_variables_survive_the_compositions) :-
    Data=[['+',1,2],['Error',a,b],X],
    invoke(zip(Data,[a,b,c],Pairs)),
    assertion(Pairs==[[['+',1,2],a],[['Error',a,b],b],[X,c]]),
    invoke(unzip(Pairs,Sides)),assertion(Sides==[Data,[a,b,c]]),
    invoke(chunk(Data,1,Chunks)),assertion(Chunks==[[['+',1,2]],[['Error',a,b]],[X]]),
    invoke(window(Data,3,Windows)),assertion(Windows==[Data]),
    invoke(drop(Data,2,Tail)),assertion(Tail==[X]),
    invoke('sort-by'(['|->',[_],0],Data,Sorted)),assertion(Sorted==Data),
    invoke('group-by'(['|->',[_],0],Data,Groups)),assertion(Groups==[[0,Data]]),
    invoke(scan(['|->',[_A,Item],[quote,Item]],seed,Data,History)),
    assertion(History==[seed,['+',1,2],['Error',a,b],X]),assertion(var(X)).

:- end_tests(lib_functional).
