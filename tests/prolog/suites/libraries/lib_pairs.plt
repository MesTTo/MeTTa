% Purpose: compare MeTTa relation compositions with the host pairs library.
% Guarantees: generated relations preserve stable ordering and duplicates;
% literal keys and values retain identity, and malformed shapes are refused.
% [tested: lib_pairs; commit=6471fbad35eced5ed6440ebf2c25a053b20221f3].
:- use_module(collection_test_support).
:- use_module(library(lists), [member/2,nth1/3]).
:- use_module(library(apply), [maplist/2]).
:- use_module(library(pairs), [pairs_keys/2,pairs_values/2,
                              group_pairs_by_key/2,transpose_pairs/2]).
:- use_module(library(random), [random_between/3]).
:- initialization(load_collection_library(lib_pairs)).

:- begin_tests(lib_pairs).

random_relation(Pairs,Keyed) :-
    random_between(0,8,Size),length(Keyed,Size),maplist(random_row,Keyed),
    as_pairs(Keyed,Pairs).
random_row(Key-Value) :-
    random_between(1,3,Which),nth1(Which,[a,b,c],Key),random_between(0,4,Value).
as_pairs(Keyed,Pairs) :- findall([Key,Value],member(Key-Value,Keyed),Pairs).

test(the_relation_operations_agree_with_library_pairs) :-
    set_random(seed(20260912)),
    forall(between(1,300,_),
        (random_relation(Pairs,Keyed),
         invoke('pairs-keys'(Pairs,Keys)),pairs_keys(Keyed,ExpectedKeys),
         assertion(Keys==ExpectedKeys),
         invoke('pairs-values'(Pairs,Values)),pairs_values(Keyed,ExpectedValues),
         assertion(Values==ExpectedValues),
         invoke('pairs-sort-by-key'(Pairs,Sorted)),
         keysort(Keyed,ExpectedSorted),as_pairs(ExpectedSorted,ExpectedSortedPairs),
         assertion(Sorted==ExpectedSortedPairs),
         invoke('pairs-group'(Pairs,Groups)),
         group_pairs_by_key(ExpectedSorted,ExpectedGroups),
         as_pairs(ExpectedGroups,ExpectedGroupPairs),assertion(Groups==ExpectedGroupPairs),
         invoke('pairs-swap'(Pairs,Swapped)),
         findall([V,K],member(K-V,Keyed),ExpectedSwapped),
         assertion(Swapped==ExpectedSwapped))).

test(the_sorted_converse_is_the_swap_and_the_sort) :-
    set_random(seed(20260912)),
    forall(between(1,200,_),
        (random_relation(Pairs,Keyed),invoke('pairs-swap'(Pairs,Swapped)),
         invoke('pairs-sort-by-key'(Swapped,Sorted)),
         transpose_pairs(Keyed,Transposed),as_pairs(Transposed,Expected),
         assertion(Sorted==Expected))).

test(the_orderings_are_stable) :-
    Pairs=[[b,1],[a,2],[b,0],[a,1],[b,1]],
    invoke('pairs-sort-by-key'(Pairs,ByKey)),
    assertion(ByKey==[[a,2],[a,1],[b,1],[b,0],[b,1]]),
    invoke('pairs-sort-by-value'(Pairs,ByValue)),
    assertion(ByValue==[[b,0],[b,1],[a,1],[b,1],[a,2]]),
    invoke('pairs-sort-by-key'(ByValue,Both)),
    assertion(Both==[[a,1],[a,2],[b,0],[b,1],[b,1]]).

test(duplicates_survive_every_operation) :-
    set_random(seed(20260912)),
    forall(between(1,200,_),
        (random_relation(Pairs,_),length(Pairs,Rows),
         forall(member(Head,['pairs-keys','pairs-values','pairs-swap',
                            'pairs-sort-by-key','pairs-sort-by-value']),
                (Goal=..[Head,Pairs,Answer],invoke(Goal),length(Answer,Rows))),
         invoke('pairs-values'(Pairs,Values)),invoke('pairs-group'(Pairs,Groups)),
         findall(V,(member([_,Vs],Groups),member(V,Vs)),Gathered),
         length(Gathered,Rows),msort(Gathered,SG),msort(Values,SV),assertion(SG==SV))),
    invoke('pairs-group'([[a,1],[a,1]],[[a,[1,1]]])).

test(grouping_and_ungrouping_are_inverses) :-
    set_random(seed(20260912)),
    forall(between(1,200,_),
        (random_relation(Pairs,_),invoke('pairs-group'(Pairs,Groups)),
         invoke('pairs-ungroup'(Groups,Back)),invoke('pairs-sort-by-key'(Pairs,Sorted)),
         assertion(Back==Sorted),invoke('pairs-keys'(Groups,Keys)),
         sort(Keys,Distinct),assertion(Keys==Distinct))),
    invoke('pairs-group'([],[])),invoke('pairs-ungroup'([],[])),
    invoke('pairs-ungroup'([[a,[]],[b,[1]]],[[b,1]])).

test(a_lookup_compares_keys_as_terms) :-
    Pairs=[[sydney,120],[perth,90],[sydney,30]],
    findall(V,collection_answers('pairs-lookup'(Pairs,sydney,V)),[120,30]),
    findall(V,collection_answers('pairs-lookup'(Pairs,perth,V)),[90]),
    findall(V,collection_answers('pairs-lookup'(Pairs,darwin,V)),[]),
    findall(V,collection_answers('pairs-lookup'(Pairs,_,V)),[]),
    Keyed=[[[point,1,2],here]],
    findall(V,collection_answers('pairs-lookup'(Keyed,[point,1,2],V)),[here]),
    findall(V,collection_answers('pairs-lookup'(Keyed,[point,1,_],V)),[]),
    invoke('pairs-lookup'([[Key,Value]],Key,Found)),
    assertion(Found==Value),assertion(var(Key)).

test(malformed_pairs_and_groups_are_refused) :-
    Bad=[[a,1],b],
    forall(member(Goal,['pairs-keys'(Bad,_),'pairs-values'(Bad,_),'pairs-swap'(Bad,_),
                        'pairs-sort-by-key'(Bad,_),'pairs-sort-by-value'(Bad,_),
                        'pairs-group'(Bad,_),'pairs-lookup'(Bad,a,_),
                        'pairs-keys'([[a,1,2]],_),'pairs-keys'(notalist,_),
                        'pairs-group'(notalist,_),'pairs-ungroup'([[a,1]],_),
                        'pairs-ungroup'(notalist,_)]),refused(Goal)),
    forall(member(Value,[Bad,notalist,[[a,1,2]]]),invoke('pairs-is'(Value,false))),
    invoke('pairs-is'([[a,1]],true)),invoke('pairs-is'([],true)).

test(quoted_runnable_rows_and_error_values_are_data) :-
    invoke('pairs-keys'([['+',1],['Error',2]],['+','Error'])),
    invoke('pairs-values'([[a,['+',1,2]],[b,['Error',a,b]]],
                         [['+',1,2],['Error',a,b]])),
    invoke('pairs-keys'([["id",1],[b,2]],["id",b])),
    invoke('pairs-ungroup'([[Key,[X,Y]]],Rows)),
    assertion(Rows==[[Key,X],[Key,Y]]),
    assertion(var(Key)),assertion(var(X)),assertion(var(Y)),
    eval_expr(['if-error',[catch,['pairs-keys',[[id,1],[b,2]]]],refused,accepted],refused).

:- end_tests(lib_pairs).
