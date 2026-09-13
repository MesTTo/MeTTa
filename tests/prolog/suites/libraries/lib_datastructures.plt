% Purpose: compare immutable collection equations with independent host models.
% Guarantees: insertion/deletion sequences, order, duplicates, absence and
% refusal are checked alongside literal values, variable identity and reflection.
% [tested: lib_datastructures; commit=WORKTREE].
% Owns resources: none; every collection and model is an immutable local term.

:- use_module(collection_test_support).
:- use_module(library(assoc), [assoc_to_list/2, assoc_to_keys/2, assoc_to_values/2,
                              put_assoc/4, get_assoc/3, del_assoc/4,
                              min_assoc/3, max_assoc/3]).
:- use_module(library(heaps), [empty_heap/1, add_to_heap/4, heap_to_list/2,
                              heap_size/2, min_of_heap/3, get_from_heap/4]).
:- use_module(library(random), [random_permutation/2]).
:- use_module(library(lists), [member/2, append/3, numlist/3, last/2]).
:- use_module(library(apply), [foldl/4, maplist/2]).
:- use_module('../../../../engine/metta.pl', [process_metta_string/2, swrite/2,
                                            metta_answer_term/2]).
:- load_collection_library(lib_datastructures).

:- begin_tests(lib_datastructures).

% The shared refusal retains the calling operation in its payload.
must_name(Goal, Operation) :-
    catch(invoke(Goal), Error, true),
    assertion(nonvar(Error)),
    assertion(Error = error(metta_assertion_failed(
        [assertEqualMsg,_,_,[quote,[Operation|_]]],_,_),_)).

test(maps_agree_with_library_assoc, [forall(member(Size,[0,1,2,3,7,64,257]))]) :-
    set_random(seed(20260912)),
    collection_items(Size, Ordered), random_permutation(Ordered, Keys),
    findall([Key,Value],(member(Key,Keys),Value is Key*10),Pairs),
    invoke('map-empty'(Empty)), foldl(insert_both,Pairs,t-Empty,Assoc-Map),
    assoc_to_list(Assoc, Native), native_pairs(Native,Expected),
    invoke('map-pairs'(Map,Answered)), assertion(Answered==Expected),
    assoc_to_keys(Assoc, NativeKeys), invoke('map-keys'(Map,AnsweredKeys)),
    assertion(AnsweredKeys==NativeKeys),
    assoc_to_values(Assoc, NativeValues), invoke('map-values'(Map,AnsweredValues)),
    assertion(AnsweredValues==NativeValues),
    invoke('map-size'(Map,Counted)), length(Native,Counted),
    forall(between(0,Size,Probe),
      ( get_assoc(Probe,Assoc,NativeValue)
      -> invoke('map-get'(Map,Probe,AnsweredValue)), assertion(AnsweredValue==NativeValue),
         invoke('map-has'(Map,Probe,true))
      ;  assertion(\+ invoke('map-get'(Map,Probe,_))), invoke('map-has'(Map,Probe,false)) )),
    ( Size>0
    -> min_assoc(Assoc,MinKey,MinValue), invoke('map-min'(Map,MinPair)),
       assertion(MinPair==[MinKey,MinValue]),
       max_assoc(Assoc,MaxKey,MaxValue), invoke('map-max'(Map,MaxPair)),
       assertion(MaxPair==[MaxKey,MaxValue])
    ;  assertion(\+ invoke('map-min'(Map,_))), assertion(\+ invoke('map-max'(Map,_))) ).

insert_both([Key,Value], Assoc0-Map0, Assoc-Map) :-
    put_assoc(Key,Assoc0,Value,Assoc), invoke('map-put'(Map0,Key,Value,Map)).

native_pairs(Native, Pairs) :- findall([K,V],member(K-V,Native),Pairs).

% Retain every original model size and check deletion after each edit.
test(map_deletion_agrees_with_library_assoc, [forall(member(Size,[1,2,3,8,65]))]) :-
    set_random(seed(20260913)), numlist(1,Size,Keys),
    findall([Key,Value],(member(Key,Keys),Value is Key*10),Pairs),
    invoke('map-empty'(Empty)), foldl(insert_both,Pairs,t-Empty,Assoc0-Map0),
    random_permutation(Keys,Order), foldl(delete_both,Order,Assoc0-Map0,Assoc-Map),
    assoc_to_list(Assoc,[]), invoke('map-pairs'(Map,[])), invoke('map-size'(Map,0)).

delete_both(Key, Assoc0-Map0, Assoc-Map) :-
    del_assoc(Key,Assoc0,_,Assoc), invoke('map-remove'(Map0,Key,Map)),
    assoc_to_list(Assoc,Native), native_pairs(Native,Expected),
    invoke('map-pairs'(Map,Answered)), assertion(Answered==Expected).

test(queues_agree_with_library_heaps, [forall(member(Size,[0,1,2,3,9,128]))]) :-
    set_random(seed(20260914)), collection_items(Size,Ordered),
    random_permutation(Ordered,Priorities),
    findall([P,V],(member(P,Priorities),atom_concat(v,P,V)),Entries),
    empty_heap(Heap0), invoke('pq-empty'(Queue0)),
    foldl(add_both,Entries,Heap0-Queue0,Heap-Queue),
    heap_to_list(Heap,Native), native_pairs(Native,Expected),
    invoke('pq-pairs'(Queue,Answered)), assertion(Answered==Expected),
    heap_size(Heap,Counted), invoke('pq-size'(Queue,Counted)),
    ( Size>0
    -> min_of_heap(Heap,MinPriority,MinValue), invoke('pq-min'(Queue,MinPair)),
       assertion(MinPair==[MinPriority,MinValue]),
       get_from_heap(Heap,MinPriority,MinValue,NativeRest),
       invoke('pq-pop'(Queue,[MinPriority,MinValue,Rest])),
       heap_to_list(NativeRest,NativeRestList), native_pairs(NativeRestList,RestExpected),
       invoke('pq-pairs'(Rest,RestAnswered)), assertion(RestAnswered==RestExpected)
    ;  assertion(\+ invoke('pq-min'(Queue,_))), assertion(\+ invoke('pq-pop'(Queue,_))) ).

add_both([Priority,Value], Heap0-Queue0, Heap-Queue) :-
    add_to_heap(Heap0,Priority,Value,Heap), invoke('pq-insert'(Queue0,Priority,Value,Queue)).

% The original tied merge/removal fixture now has an independent stable-order
% oracle. A heap's internal tie order is not the collection's public contract.
test(queue_merge_and_removal_have_stable_priority_order) :-
    Left=[[3,c],[1,a]], Right=[[2,b],[1,z]],
    invoke('pq-from-pairs'(Left,LeftQueue)), invoke('pq-from-pairs'(Right,RightQueue)),
    invoke('pq-merge'(LeftQueue,RightQueue,Merged)),
    append(Left,Right,Entries), stable_rows(Entries,Expected),
    invoke('pq-pairs'(Merged,Answered)), assertion(Answered==Expected),
    invoke('pq-remove'(Merged,1,z,Without)), invoke('pq-pairs'(Without,[[1,a],[2,b],[3,c]])),
    assertion(\+ invoke('pq-remove'(Merged,1,absent,_))),
    invoke('pq-pairs'(LeftQueue,[[1,a],[3,c]])), invoke('pq-pairs'(RightQueue,[[1,z],[2,b]])).

stable_rows(Rows, Sorted) :-
    findall(P-Row,(member(Row,Rows),Row=[P,_]),Keyed), keysort(Keyed,Ordered),
    findall(Row,member(_-Row,Ordered),Sorted).

test(a_map_survives_bind) :-
    invoke('map-from-pairs'([[b,2],[a,1]],Map)), swrite(Map,Text),
    format(atom(Program),"!(bind! &probe-map ~w)\n!(map-size &probe-map)",[Text]),
    process_metta_string(Program,Answers), last(Answers,Answer),
    metta_answer_term(Answer,Size), assertion(Size==2).

test(a_put_leaves_its_input_alone) :-
    invoke('map-from-pairs'([[a,1]],Map)), invoke('map-put'(Map,b,2,Bigger)),
    invoke('map-pairs'(Map,[[a,1]])), invoke('map-pairs'(Bigger,[[a,1],[b,2]])),
    invoke('pq-from-pairs'([[1,a]],Queue)), invoke('pq-insert'(Queue,0,z,Longer)),
    invoke('pq-pairs'(Queue,[[1,a]])), invoke('pq-pairs'(Longer,[[0,z],[1,a]])).

test(absence_has_no_answer) :-
    invoke('map-empty'(Empty)),
    forall(member(Goal,['map-get'(Empty,k,_),'map-min'(Empty,_),'map-max'(Empty,_)]),
           assertion(\+ invoke(Goal))),
    invoke('map-get-or'(Empty,k,fallback,fallback)), invoke('map-remove'(Empty,k,Empty)),
    invoke('map-has'(Empty,k,false)), invoke('pq-empty'(EmptyQueue)),
    forall(member(Goal,['pq-min'(EmptyQueue,_),'pq-pop'(EmptyQueue,_),
                        'pq-remove'(EmptyQueue,1,a,_)]), assertion(\+ invoke(Goal))),
    invoke('pq-size'(EmptyQueue,0)), invoke('pq-pairs'(EmptyQueue,[])).

test(keys_use_the_standard_order) :-
    invoke('map-from-pairs'([[b,2],[1,one],[1.0,float],[a,1],["s",string]],Map)),
    invoke('map-keys'(Map,Keys)), msort([b,1,1.0,a,"s"],Expected),
    assertion(Keys==Expected), invoke('map-get'(Map,1,one)),
    invoke('map-get'(Map,1.0,float)), invoke('map-size'(Map,5)).

test(order_is_the_standard_order) :-
    invoke('map-from-pairs'([[3,c],[1,a],[2,b]],Map)),
    invoke('map-pairs'(Map,[[1,a],[2,b],[3,c]])), invoke('map-keys'(Map,[1,2,3])),
    invoke('map-values'(Map,[a,b,c])),
    invoke('pq-from-pairs'([[3,c],[1,a],[2,b]],Queue)),
    invoke('pq-pairs'(Queue,[[1,a],[2,b],[3,c]])).

test(a_repeated_priority_is_kept_and_a_repeated_key_is_refused) :-
    invoke('pq-from-pairs'([[1,a],[1,b],[1,c]],Queue)), invoke('pq-size'(Queue,3)),
    invoke('pq-pairs'(Queue,[[1,a],[1,b],[1,c]])),
    must_name('map-from-pairs'([[k,1],[k,2]],_),'map-from-pairs'),
    invoke('map-from-pairs'([[k,1]],Map)), invoke('map-put'(Map,k,2,Replaced)),
    invoke('map-pairs'(Replaced,[[k,2]])).

test(a_wrong_shape_names_the_operation) :-
    invoke('map-empty'(Map)), invoke('pq-empty'(Queue)),
    forall(member(Goal,['map-get'(42,k,_),'map-put'(nonsense,k,v,_),
                       'pq-size'(42,_),'pq-min'(Map,_),'map-size'(Queue,_),
                       'map-from-pairs'(notalist,_),'map-from-pairs'([[a]],_),
                       'pq-from-pairs'([[1,a,b]],_)]),
           (functor(Goal,Operation,_),must_name(Goal,Operation))).

test(a_map_and_a_queue_round_trip_through_their_pairs) :-
    Pairs=[[a,1],[b,2],[c,3]],
    invoke('map-from-pairs'(Pairs,Map)), invoke('map-pairs'(Map,Pairs)),
    invoke('pq-from-pairs'(Pairs,Queue)), invoke('pq-pairs'(Queue,Pairs)),
    invoke('map-empty'(Empty)), invoke('map-pairs'(Empty,[])),
    invoke('map-from-pairs'([],Empty)), invoke('pq-empty'(EmptyQueue)),
    invoke('pq-pairs'(EmptyQueue,[])), invoke('pq-from-pairs'([],EmptyQueue)).

test(variable_keys_preserve_identity_and_never_become_wildcards) :-
    invoke('map-from-pairs'([[X,a],[Y,b]],Map)),
    invoke('map-keys'(Map,Keys)), assertion(Keys==[X,Y]),
    invoke('map-get'(Map,X,a)), invoke('map-get'(Map,Y,b)),
    invoke('map-has'(Map,Unknown,false)), assertion(var(Unknown)),
    invoke('map-put'(Map,X,c,Changed)), invoke('map-get'(Changed,X,c)),
    invoke('map-get'(Map,X,a)), invoke('map-remove'(Map,X,OnlyY)),
    invoke('map-pairs'(OnlyY,Rows)), assertion(Rows==[[Y,b]]),
    must_name('map-from-pairs'([[X,a],[X,b]],_),'map-from-pairs'),
    assertion(var(X)), assertion(var(Y)), assertion(X\==Y).

test(malformed_variables_open_lists_and_cycles_are_refused) :-
    forall(member(Goal,['map-from-pairs'([Pair],_),'pq-from-pairs'([Pair],_),
                       'map-size'(Unknown,_),'pq-size'(Unknown,_),
                       'map-size'(['SortedMap',[[a,1],[a,2]]],_),
                       'map-size'(['SortedMap',[[b,1],[a,2]]],_),
                       'pq-size'(['PriorityQueue',[[2,a],[1,b]]],_),
                       'pq-size'(['PriorityQueue',unknown],_)]),refused(Goal)),
    assertion(var(Pair)), assertion(var(Unknown)),
    Open=[[a,1]|Tail], Cyclic=[[a,1]|Cyclic],
    forall(member(Bad,[Open,Cyclic]),
      (refused('map-from-pairs'(Bad,_)),refused('pq-from-pairs'(Bad,_)))),
    assertion(var(Tail)).

test(literal_keys_values_and_defaults_remain_data) :-
    Literal=['+',1,2], Error=['Error',data,code],
    invoke('map-from-pairs'([[Literal,Error]],Map)),
    invoke('map-get'(Map,Literal,Found)), assertion(Found==Error),
    invoke('map-get-or'(Map,absent,Literal,Default)), assertion(Default==Literal),
    invoke('map-values'(Map,Values)), assertion(Values==[Error]),
    invoke('pq-from-pairs'([[Literal,Error]],Queue)),
    invoke('pq-pop'(Queue,[Priority,Value,Rest])),
    assertion(Priority==Literal), assertion(Value==Error), invoke('pq-size'(Rest,0)),
    invoke('ft-from-list'([Literal,Error],Tree)),
    invoke('ft-to-list'(Tree,List)), assertion(List==[Literal,Error]),
    invoke('ft-front'(Tree,First)), assertion(First==Literal),
    invoke('ft-back'(Tree,Last)), assertion(Last==Error).

test(removal_drops_one_identical_occurrence_and_retains_sharing) :-
    invoke('pq-from-pairs'([[X,a],[Y,a],[X,a]],Queue)),
    invoke('pq-remove'(Queue,X,a,Rest)), invoke('pq-pairs'(Rest,Rows)),
    assertion(Rows==[[X,a],[Y,a]]),
    assertion(\+ invoke('pq-remove'(Queue,Unknown,a,_))), assertion(var(Unknown)),
    invoke('pq-insert'(Queue,X,b,Longer)), invoke('pq-pairs'(Longer,LongRows)),
    assertion(LongRows==[[X,a],[X,a],[X,b],[Y,a]]),
    assertion(var(X)), assertion(var(Y)), assertion(X\==Y).

test(merge_accepts_zero_one_and_arbitrarily_many_queues) :-
    invoke('pq-merge'(Empty)), invoke('pq-empty'(Empty)),
    invoke('pq-from-pairs'([[1,a]],Queue)), invoke('pq-merge'(Queue,Queue)),
    forall(between(0,24,Count),
      (length(Queues,Count),maplist(=(Queue),Queues),
       append(Queues,[Answer],Arguments),Goal=..['pq-merge'|Arguments],invoke(Goal),
       invoke('pq-pairs'(Answer,Rows)),length(Expected,Count),maplist(=([1,a]),Expected),
       assertion(Rows==Expected))).

test(alternative_inputs_remain_alternative_answers) :-
    findall(Value,eval_expr(['map-get',['map-from-pairs',
        [superpose,[[[a,1]],[[a,2]]]]],a],Value),Values), assertion(Values==[1,2]).

test(equations_can_be_matched_reconstructed_and_specialized) :-
    invoke('map-from-pairs'([[a,1],[b,2]],Map)),
    once(eval_expr([let,Source,
      [match,'&self',['=',['map-remove',M,K],Body],[quote,['|->',[M,K],Body]]],
      [let,Remove,[eval,Source],[Remove,[quote,Map],a]]],Rest)),
    invoke('map-pairs'(Rest,[[b,2]])),
    once(eval_expr([let,Source2,
      [match,'&self',['=',['map-remove',Map,Key],Body2],[quote,['|->',[Key],Body2]]],
      [let,Remove2,[eval,Source2],[Remove2,b]]],Rest2)),
    invoke('map-pairs'(Rest2,[[a,1]])).

:- end_tests(lib_datastructures).
