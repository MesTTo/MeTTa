% Purpose: check the sorted map and the priority queue against the upstream
% libraries whose algorithms they adapt, and against their own contracts.
% Guarantees: for generated key sequences the list-shaped map answers exactly
% what library(assoc) answers and the queue exactly what library(heaps) answers,
% so the adaptation is checked against its source rather than against a table
% [tested: lib_datastructures; commit=WORKTREE].
% Owns resources: none; every value is an immutable term.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(assoc)).
:- use_module(library(heaps)).
:- use_module(library(random), [random_permutation/2]).
:- initialization(consult('../../lib/lib_datastructures/lib_datastructures.pl')).

:- begin_tests(lib_datastructures).
:- meta_predicate must_throw(0, ?).

must_throw(Goal, Expected) :-
    catch(Goal, Error, true), assertion(nonvar(Error)), assertion(Error = Expected).

% ------------------------------------------------------- the map differential

% Every insertion order of the same keys, against library(assoc) over the same
% sequence: the pairs, the keys, the values, every lookup and both extremes.
test(maps_agree_with_library_assoc, [forall(member(Size, [0, 1, 2, 3, 7, 64, 257]))]) :-
    set_random(seed(20260912)),
    ( Size == 0 -> Keys = [] ; numlist(1, Size, Keys0), random_permutation(Keys0, Keys) ),
    findall([Key, Value], (member(Key, Keys), Value is Key * 10), Pairs),
    foldl(insert_both, Pairs, t-'MapEmpty', Assoc-Map),
    assoc_to_list(Assoc, Native),
    findall([K, V], member(K-V, Native), Expected),
    'map-pairs'(Map, Answered), assertion(Answered == Expected),
    assoc_to_keys(Assoc, NativeKeys), 'map-keys'(Map, AnsweredKeys),
    assertion(AnsweredKeys == NativeKeys),
    assoc_to_values(Assoc, NativeValues), 'map-values'(Map, AnsweredValues),
    assertion(AnsweredValues == NativeValues),
    'map-size'(Map, Counted), length(Native, Counted),
    forall(between(0, Size, Probe),
           (   get_assoc(Probe, Assoc, NativeValue)
           ->  'map-get'(Map, Probe, AnsweredValue),
               assertion(AnsweredValue == NativeValue),
               'map-has'(Map, Probe, true)
           ;   assertion(\+ 'map-get'(Map, Probe, _)),
               'map-has'(Map, Probe, false)
           )),
    (   Size > 0
    ->  min_assoc(Assoc, MinKey, MinValue), 'map-min'(Map, MinPair),
        assertion(MinPair == [MinKey, MinValue]),
        max_assoc(Assoc, MaxKey, MaxValue), 'map-max'(Map, MaxPair),
        assertion(MaxPair == [MaxKey, MaxValue])
    ;   assertion(\+ 'map-min'(Map, _)),
        assertion(\+ 'map-max'(Map, _))
    ).

insert_both([Key, Value], Assoc0-Map0, Assoc-Map) :-
    put_assoc(Key, Assoc0, Value, Assoc),
    'map-put'(Map0, Key, Value, Map).

% Deleting every key in turn, in a different order from the insertions: the
% adapted rebalancing has to answer what the upstream rebalancing answers at
% every step, which is what catches a mistranscribed rotation.
test(map_deletion_agrees_with_library_assoc, [forall(member(Size, [1, 2, 3, 8, 65]))]) :-
    set_random(seed(20260913)),
    numlist(1, Size, Keys),
    findall([Key, Value], (member(Key, Keys), Value is Key * 10), Pairs),
    foldl(insert_both, Pairs, t-'MapEmpty', Assoc0-Map0),
    random_permutation(Keys, Order),
    foldl(delete_both, Order, Assoc0-Map0, Assoc-Map),
    assoc_to_list(Assoc, Native), assertion(Native == []),
    'map-pairs'(Map, Answered), assertion(Answered == []),
    'map-size'(Map, 0).

delete_both(Key, Assoc0-Map0, Assoc-Map) :-
    del_assoc(Key, Assoc0, _, Assoc),
    'map-remove'(Map0, Key, Map),
    assoc_to_list(Assoc, Native),
    findall([K, V], member(K-V, Native), Expected),
    'map-pairs'(Map, Answered),
    assertion(Answered == Expected).

% ----------------------------------------------------- the queue differential

test(queues_agree_with_library_heaps, [forall(member(Size, [0, 1, 2, 3, 9, 128]))]) :-
    set_random(seed(20260914)),
    ( Size == 0
    -> Priorities = []
    ;  numlist(1, Size, Priorities0), random_permutation(Priorities0, Priorities) ),
    findall([Priority, Value], (member(Priority, Priorities), atom_concat(v, Priority, Value)),
            Entries),
    empty_heap(Heap0), 'pq-empty'(Queue0),
    foldl(add_both, Entries, Heap0-Queue0, Heap-Queue),
    heap_to_list(Heap, Native),
    findall([P, V], member(P-V, Native), Expected),
    'pq-pairs'(Queue, Answered), assertion(Answered == Expected),
    heap_size(Heap, Counted), 'pq-size'(Queue, Counted),
    (   Size > 0
    ->  min_of_heap(Heap, MinPriority, MinValue),
        'pq-min'(Queue, MinPair), assertion(MinPair == [MinPriority, MinValue]),
        get_from_heap(Heap, MinPriority, MinValue, NativeRest),
        'pq-pop'(Queue, [MinPriority, MinValue, Rest]),
        heap_to_list(NativeRest, NativeRestList),
        findall([P, V], member(P-V, NativeRestList), RestExpected),
        'pq-pairs'(Rest, RestAnswered), assertion(RestAnswered == RestExpected)
    ;   assertion(\+ 'pq-min'(Queue, _)),
        assertion(\+ 'pq-pop'(Queue, _))
    ).

add_both([Priority, Value], Heap0-Queue0, Heap-Queue) :-
    add_to_heap(Heap0, Priority, Value, Heap),
    'pq-insert'(Queue0, Priority, Value, Queue).

test(queue_merge_and_removal_agree_with_library_heaps) :-
    Left = [[3, c], [1, a]], Right = [[2, b], [1, z]],
    'pq-from-pairs'(Left, LeftQueue), 'pq-from-pairs'(Right, RightQueue),
    findall(P-V, member([P, V], Left), LeftNative),
    findall(P-V, member([P, V], Right), RightNative),
    list_to_heap(LeftNative, LeftHeap), list_to_heap(RightNative, RightHeap),
    merge_heaps(LeftHeap, RightHeap, MergedHeap), 'pq-merge'(LeftQueue, RightQueue, Merged),
    heap_to_list(MergedHeap, MergedNative),
    findall([P, V], member(P-V, MergedNative), MergedExpected),
    'pq-pairs'(Merged, MergedAnswered), assertion(MergedAnswered == MergedExpected),
    delete_from_heap(MergedHeap, 1, z, WithoutHeap), 'pq-remove'(Merged, 1, z, Without),
    heap_to_list(WithoutHeap, WithoutNative),
    findall([P, V], member(P-V, WithoutNative), WithoutExpected),
    'pq-pairs'(Without, WithoutAnswered), assertion(WithoutAnswered == WithoutExpected),
    assertion(\+ 'pq-remove'(Merged, 1, absent, _)).

% ------------------------------------------------------------- the contracts

% A value a written form can carry: that is why the nodes are expressions and
% not the host's compounds.
test(a_map_survives_bind) :-
    'map-from-pairs'([[b, 2], [a, 1]], Map),
    process_metta_string("!(import! &self (library lib_datastructures))", _),
    swrite(Map, Text),
    format(atom(Program), "!(bind! &probe-map ~w)\n!(map-size &probe-map)", [Text]),
    process_metta_string(Program, Answers),
    last(Answers, Answer),
    metta_answer_term(Answer, Size),
    assertion(Size == 2).

test(a_put_leaves_its_input_alone) :-
    'map-from-pairs'([[a, 1]], Map),
    'map-put'(Map, b, 2, Bigger),
    'map-pairs'(Map, [[a, 1]]),
    'map-pairs'(Bigger, [[a, 1], [b, 2]]),
    'pq-from-pairs'([[1, a]], Queue),
    'pq-insert'(Queue, 0, z, Longer),
    'pq-pairs'(Queue, [[1, a]]),
    'pq-pairs'(Longer, [[0, z], [1, a]]).

test(absence_has_no_answer) :-
    'map-empty'(Empty),
    assertion(\+ 'map-get'(Empty, k, _)),
    assertion(\+ 'map-min'(Empty, _)),
    assertion(\+ 'map-max'(Empty, _)),
    'map-get-or'(Empty, k, fallback, fallback),
    'map-remove'(Empty, k, Empty),
    'map-has'(Empty, k, false),
    'pq-empty'(EmptyQueue),
    assertion(\+ 'pq-min'(EmptyQueue, _)),
    assertion(\+ 'pq-pop'(EmptyQueue, _)),
    assertion(\+ 'pq-remove'(EmptyQueue, 1, a, _)),
    'pq-size'(EmptyQueue, 0),
    'pq-pairs'(EmptyQueue, []).

% The standard order of terms, which is the two upstream libraries' own
% comparison: a Number orders before a Symbol, and 1 and 1.0 are different keys.
test(keys_use_the_standard_order) :-
    'map-from-pairs'([[b, 2], [1, one], [1.0, float], [a, 1], ["s", string]], Map),
    'map-keys'(Map, Keys),
    msort([b, 1, 1.0, a, "s"], Expected),
    assertion(Keys == Expected),
    'map-get'(Map, 1, one), 'map-get'(Map, 1.0, float),
    'map-size'(Map, 5).

test(order_is_the_standard_order) :-
    'map-from-pairs'([[3, c], [1, a], [2, b]], Map),
    'map-pairs'(Map, [[1, a], [2, b], [3, c]]),
    'map-keys'(Map, [1, 2, 3]),
    'map-values'(Map, [a, b, c]),
    'pq-from-pairs'([[3, c], [1, a], [2, b]], Queue),
    'pq-pairs'(Queue, [[1, a], [2, b], [3, c]]).

test(a_repeated_priority_is_kept_and_a_repeated_key_is_refused) :-
    'pq-from-pairs'([[1, a], [1, b], [1, c]], Queue),
    'pq-size'(Queue, 3),
    'pq-pairs'(Queue, Pairs), length(Pairs, 3),
    forall(member(Pair, Pairs), Pair = [1, _]),
    must_throw('map-from-pairs'([[k, 1], [k, 2]], _),
               error(duplicate_map_key(_), context('map-from-pairs', _))),
    'map-from-pairs'([[k, 1]], Map), 'map-put'(Map, k, 2, Replaced),
    'map-pairs'(Replaced, [[k, 2]]).

test(a_wrong_shape_names_the_operation) :-
    must_throw('map-get'(42, k, _), error(type_error(sorted_map, 42), context('map-get', _))),
    must_throw('map-put'(nonsense, k, v, _),
               error(type_error(sorted_map, nonsense), context('map-put', _))),
    must_throw('pq-size'(42, _), error(type_error(priority_queue, 42), context('pq-size', _))),
    'map-empty'(Map), 'pq-empty'(Queue),
    must_throw('pq-min'(Map, _), error(type_error(priority_queue, Map), context('pq-min', _))),
    must_throw('map-size'(Queue, _), error(type_error(sorted_map, Queue), context('map-size', _))),
    must_throw('map-from-pairs'(notalist, _),
               error(type_error(key_value_pairs, notalist), context('map-from-pairs', _))),
    must_throw('map-from-pairs'([[a]], _),
               error(type_error(key_value_pairs, _), context('map-from-pairs', _))),
    must_throw('pq-from-pairs'([[1, a, b]], _),
               error(type_error(key_value_pairs, _), context('pq-from-pairs', _))).

% A round trip through the pair form is the identity, which is what makes the
% pairs the shape to store and send.
test(a_map_and_a_queue_round_trip_through_their_pairs) :-
    Pairs = [[a, 1], [b, 2], [c, 3]],
    'map-from-pairs'(Pairs, Map), 'map-pairs'(Map, Pairs),
    'pq-from-pairs'(Pairs, Queue), 'pq-pairs'(Queue, Pairs),
    'map-empty'(Empty), 'map-pairs'(Empty, []), 'map-from-pairs'([], Empty),
    'pq-empty'(EmptyQueue), 'pq-pairs'(EmptyQueue, []), 'pq-from-pairs'([], EmptyQueue).

:- end_tests(lib_datastructures).
