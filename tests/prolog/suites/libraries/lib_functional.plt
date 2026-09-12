% Purpose: check each collection operation against a second way of computing the
% same answer, and the three control forms against the number of times they run.
% Guarantees: every operation agrees with an oracle built from the host's own
% predicates over generated inputs, the two flattens agree with append/2 and with
% library(lists)' flatten/2 respectively, and the cost of one pass stays linear
% [tested: lib_functional; commit=a2a80061cd8264d8f714b14c76b94d00f44a0755].
% Owns resources: none; every answer is a term, and the one space the control
% forms count in is created inside its own test.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(lists), [append/2, append/3, flatten/2, last/2, member/2,
                               nth1/3, numlist/3, sum_list/2]).
:- use_module(library(apply), [exclude/3, maplist/2, maplist/3]).
:- use_module(library(pairs), [pairs_values/2]).
:- use_module(library(random), [random_between/3, random_permutation/2]).
:- initialization(consult('../../lib/lib_functional/lib_functional.pl')).

:- begin_tests(lib_functional).
:- meta_predicate must_throw(0, ?).

must_throw(Goal, Expected) :-
    catch(Goal, Error, true), assertion(nonvar(Error)), assertion(Error = Expected).

% numlist/3 fails for an empty range rather than answering the empty list, so
% every generator that starts at zero needs its own sequence.
items(0, []) :- !.
items(Size, Items) :- numlist(1, Size, Items).

single(Item, [Item]).

% The library's own face, and the one key function the head-taking operations
% apply: the three control forms are equations in lib_functional.metta, the
% held-parameter declarations that make them work live there, and a key function
% is whatever the evaluator can apply, so it is written as an equation here.
face_imported :-
    (   nb_current('$lib_functional_face', true)
    ->  true
    ;   process_metta_string("!(import! &self (library lib_functional))", _),
        process_metta_string("(= (remainder $x) (% $x 5))", _),
        nb_setval('$lib_functional_face', true)
    ).

answer_of(Program, Value) :-
    face_imported,
    process_metta_string(Program, Answers),
    last(Answers, Answer),
    metta_answer_term(Answer, Value).

% --------------------------------------------------------- pairing and slicing

% zip stops at the shorter side, so its length is the smaller of the two and
% every pair holds the elements at that position. nth1/3 is the oracle.
test(zip_and_unzip_round_trip,
     [forall(member(Left-Right, [0-0, 0-3, 3-0, 1-1, 4-7, 7-4, 40-40]))]) :-
    items(Left, Lefts), items(Right, Rights),
    zip(Lefts, Rights, Pairs),
    length(Pairs, Paired),
    Expected is min(Left, Right),
    assertion(Paired == Expected),
    forall(nth1(Index, Pairs, Pair),
           ( nth1(Index, Lefts, L), nth1(Index, Rights, R),
             assertion(Pair == [L, R]) )),
    % unzip inverts a zip exactly when nothing was truncated.
    (   Left == Right
    ->  unzip(Pairs, Sides), assertion(Sides == [Lefts, Rights])
    ;   true
    ),
    must_throw(unzip([[1, 2], 3], _), error(type_error(pair, 3), _)),
    must_throw(unzip([[1, 2, 3]], _), error(type_error(pair, [1, 2, 3]), _)),
    must_throw(zip(notalist, [], _), error(type_error(list, notalist), _)).

% A suffix and its prefix are one append, which is the oracle: whatever drop
% leaves, the elements before it are exactly the count that was dropped.
test(drop_is_the_suffix_append_names, [forall(between(0, 12, Size))]) :-
    items(Size, Items),
    forall(between(0, 15, Count),
           ( drop(Items, Count, Rest),
             (   Count =< Size
             ->  length(Prefix, Count), append(Prefix, Rest, Items)
             ;   assertion(Rest == [])
             ) )),
    must_throw(drop([1, 2], -1, _), error(type_error(nonneg, -1), _)).

% Cutting loses nothing and overlaps nothing: the chunks concatenate back to the
% collection, every one but the last is full, and the count is the ceiling of
% the division.
test(chunks_partition_the_collection, [forall(between(0, 17, Size))]) :-
    items(Size, Items),
    forall(between(1, 6, Cut),
           ( chunk(Items, Cut, Chunks),
             append(Chunks, Rejoined), assertion(Rejoined == Items),
             length(Chunks, Count),
             Ceiling is (Size + Cut - 1) // Cut, assertion(Count == Ceiling),
             forall(( nth1(Index, Chunks, Chunk), Index < Count ),
                    ( length(Chunk, Full), assertion(Full == Cut) )),
             (   Chunks == []
             ->  assertion(Size == 0)
             ;   last(Chunks, Last), length(Last, Tail),
                 assertion(Tail =< Cut), assertion(Tail > 0)
             ) )),
    must_throw(chunk([1, 2], 0, _), error(domain_error(positive_integer, 0), _)),
    must_throw(chunk([1, 2], -3, _), error(domain_error(positive_integer, -3), _)).

% A sliding window is the run of Size elements at each offset, which append/3
% names directly, and there is one per offset that still fits.
test(windows_are_every_run_of_the_size, [forall(between(0, 17, Size))]) :-
    items(Size, Items),
    forall(between(1, 6, Width),
           ( window(Items, Width, Windows),
             length(Windows, Count),
             Expected is max(0, Size - Width + 1), assertion(Count == Expected),
             forall(nth1(Index, Windows, Window),
                    ( Offset is Index - 1,
                      length(Before, Offset), append(Before, Rest, Items),
                      length(Run, Width), append(Run, _, Rest),
                      assertion(Window == Run) )) )),
    window(Items, 1, Singles), maplist(single, Items, Singly),
    assertion(Singles == Singly),
    must_throw(window([1, 2], 0, _), error(domain_error(positive_integer, 0), _)).

% ------------------------------------------------------------ the two flattens

% One level of nesting removed from a collection of collections IS their
% concatenation, and append/2 is the host's name for that.
test(one_level_flatten_is_the_concatenation, [forall(between(0, 8, Size))]) :-
    items(Size, Sizes),
    maplist(items, Sizes, Nested),
    'flatten-once'(Nested, Flat),
    append(Nested, Concatenated),
    assertion(Flat == Concatenated),
    % An element that is not a collection survives as itself, which is what
    % makes the operation total rather than a concatenation with a precondition.
    'flatten-once'([[1, 2], three, [], [[4]]], Mixed),
    assertion(Mixed == [1, 2, three, [4]]),
    must_throw('flatten-once'(notalist, _), error(type_error(list, notalist), _)).

% Every level removed is library(lists)' own flatten/2, so that predicate is the
% oracle. It is also the reason this library publishes flatten-once and
% flatten-deep rather than the bare name: a registered head is reached by NAME
% through the module chain the calling space resolves in, the engine module
% imports the whole of library(lists), and a head spelled flatten/2 here
% answered the host's every-level flatten instead of its own clauses, silently.
test(the_deep_flatten_agrees_with_library_lists) :-
    set_random(seed(20260912)),
    forall(between(1, 200, _),
           ( nested(3, Nested),
             'flatten-deep'(Nested, Mine),
             flatten(Nested, Host),
             assertion(Mine == Host) )),
    'flatten-deep'([[[[]]], []], Empties), assertion(Empties == []),
    'flatten-deep'([1, [2, [3, [4]]]], Deep), assertion(Deep == [1, 2, 3, 4]),
    % The bare name stays the host's: the engine module answers library(lists)'
    % flatten/2, and this library publishes neither that name nor that arity.
    predicate_property(metta_engine:flatten(_, _), imported_from(Source)),
    assertion(Source == lists),
    module_property(lib_functional, exports(Exports)),
    assertion(\+ member(flatten/2, Exports)).

% A random proper list, nested to at most that depth, with atoms, numbers and
% empty collections as leaves.
nested(0, Leaf) :- !, leaf(Leaf).
nested(Depth, Items) :-
    random_between(0, 4, Length),
    Deeper is Depth - 1,
    length(Items, Length),
    maplist(nested_element(Deeper), Items).

nested_element(Depth, Item) :-
    random_between(0, 2, Choice),
    ( Choice == 0 -> leaf(Item) ; nested(Depth, Item) ).

leaf(Leaf) :-
    random_between(1, 3, Which),
    nth1(Which, [a, 1, []], Leaf).

% ----------------------------------------------------- keys, folds and unfolds

% keysort/2 is stable and documented to be, so it is the oracle for sort-by; the
% grouping has to keep its keys in first-appearance order, which a sort cannot
% produce and a walk over the keyed pairs can.
test(grouping_and_sorting_are_stable) :-
    face_imported,
    set_random(seed(20260912)),
    numlist(1, 40, Ordered),
    random_permutation(Ordered, Items),
    'sort-by'(remainder, Items, Sorted),
    findall(Key-Item, ( member(Item, Items), Key is Item mod 5 ), Keyed),
    keysort(Keyed, Stable), pairs_values(Stable, Expected),
    assertion(Sorted == Expected),
    'group-by'(remainder, Items, Groups),
    findall(Key2, member([Key2, _], Groups), Keys),
    findall(Answer, ( member(Item2, Items), Answer is Item2 mod 5 ), Answers),
    first_appearances(Answers, FirstAppearance),
    assertion(Keys == FirstAppearance),
    forall(member([Key3, Members], Groups),
           ( findall(Item3, ( member(Item3, Items), Key3 =:= Item3 mod 5 ), InOrder),
             assertion(Members == InOrder) )),
    'group-by'(remainder, [], None), assertion(None == []),
    % Every element lands in exactly one group, so a grouping loses nothing.
    findall(Member, ( member([_, Members2], Groups), member(Member, Members2) ), Gathered),
    msort(Gathered, SortedGathered), msort(Items, SortedItems),
    assertion(SortedGathered == SortedItems).

first_appearances([], []).
first_appearances([Key|Keys], [Key|First]) :-
    exclude(==(Key), Keys, Rest),
    first_appearances(Rest, First).

% The running results of a fold ARE the folds of the prefixes, one per prefix,
% which is the oracle: the sum of the first N elements is the Nth answer.
test(scan_is_every_prefix_fold, [forall(between(0, 12, Size))]) :-
    face_imported,
    items(Size, Items),
    scan('+', 0, Items, Running),
    length(Running, Count), Expected is Size + 1,
    assertion(Count == Expected),
    forall(nth1(Index, Running, Value),
           ( Taken is Index - 1,
             length(Prefix, Taken), append(Prefix, _, Items),
             sum_list(Prefix, Sum),
             assertion(Value == Sum) )),
    % The start is the first answer even when there is nothing to fold.
    scan('+', 7, [], Start), assertion(Start == [7]).

% An unfold and a fold are inverses over the same step: a seed grown into 1..N
% has to be the range itself.
test(unfold_is_the_inverse_of_a_fold, [forall(member(Size, [0, 1, 5, 20]))]) :-
    Limit is Size + 1,
    format(atom(Program),
           "!(unfold (|-> ($n) (if (< $n ~d) ($n (+ $n 1)) (empty))) 1)",
           [Limit]),
    answer_of(Program, Grown),
    items(Size, Items),
    assertion(Grown == Items).

% ------------------------------------------------ application and the controls

% pipe composes left to right through the evaluator, and apply-to is what turns
% a collection of arguments into a call.
test(pipe_and_apply_to_compose_through_the_evaluator) :-
    face_imported,
    'apply-to'('+', [1, 2], Three), assertion(Three == 3),
    'apply-to'('-', [10, 4], Six), assertion(Six == 6),
    pipe([], seed, Seed), assertion(Seed == seed),
    pipe([remainder, remainder], 12, Twice), assertion(Twice == 2),
    partition(remainder, [5, 6, 10, 11], Sides),
    assertion(Sides == [[], [5, 6, 10, 11]]),
    must_throw('apply-to'('+', notalist, _), error(type_error(list, notalist), _)),
    must_throw(pipe(notalist, 1, _), error(type_error(list, notalist), _)).

% The three control forms hold their body, so the number of times it runs is the
% number of answers, and a counter in a space is how that number is checked.
test(the_control_forms_run_their_body_the_counted_number_of_times) :-
    answer_of("!(collapse (repeat 4 (+ 1 1)))", Repeated),
    assertion(Repeated == [2, 2, 2, 2]),
    answer_of("!(collapse (repeat 0 (+ 1 1)))", NoneRepeated),
    assertion(NoneRepeated == []),
    answer_of("!(collapse (unless False ran))", Unless),
    assertion(Unless == [ran]),
    answer_of("!(collapse (unless True ran))", NoneUnless),
    assertion(NoneUnless == []),
    answer_of("!(collapse (while False ran))", NoneWhile),
    assertion(NoneWhile == []),
    % A loop whose condition reads a space and whose body advances it stops when
    % the space says so, which is what holding both of them is for.
    answer_of("!(bind! &counted (new-space))\n\c
                !(add-atom &counted (count 0))\n\c
                (= (counted) (car-atom (collapse (match &counted (count $n) $n))))\n\c
                (= (step) (let $now (counted)\n\c
                            (let $gone (remove-atom &counted (count $now))\n\c
                              (let $next (+ $now 1)\n\c
                                (let $added (add-atom &counted (count $next)) $next)))))\n\c
                !(collapse (while (< (counted) 5) (step)))",
              Counted),
    assertion(Counted == [1, 2, 3, 4, 5]).

% ----------------------------------------------------------- refusals and cost

% Each refusal names the operation that raised it, so a caller learns which of
% several collection arguments was wrong.
test(every_refusal_names_its_operation) :-
    must_throw(chunk([1], 0, _), error(domain_error(positive_integer, 0), _)),
    must_throw(window([1], 0, _), error(domain_error(positive_integer, 0), _)),
    must_throw(drop([1], -2, _), error(type_error(nonneg, -2), _)),
    must_throw(unzip([nopair], _), error(type_error(pair, nopair), _)),
    forall(member(Goal, [zip(nolist, [], _), zip([], nolist, _), drop(nolist, 0, _),
                         chunk(nolist, 1, _), window(nolist, 1, _),
                         'flatten-once'(nolist, _), 'flatten-deep'(nolist, _),
                         partition(remainder, nolist, _),
                         'group-by'(remainder, nolist, _),
                         'sort-by'(remainder, nolist, _), scan('+', 0, nolist, _),
                         unzip(nolist, _)]),
           must_throw(Goal, error(type_error(list, nolist), _))).

% One pass means the cost grows with the length and not with its square. The
% engine's own counter is the measurement, because wall clock on a loaded box is
% not one.
test(one_pass_costs_scale_linearly) :-
    forall(member(Operation, [zip, chunk, window, 'flatten-once', 'flatten-deep', drop]),
           ( pass_cost(Operation, 200, Small),
             pass_cost(Operation, 2000, Large),
             % Ten times the input, so a linear pass costs about ten times as
             % much and a quadratic one a hundred times. Three times the linear
             % expectation is the line between them.
             Bound is Small * 30,
             assertion(Large < Bound) )).

pass_cost(Operation, Size, Cost) :-
    numlist(1, Size, Items),
    maplist(single, Items, Nested),
    pass_goal(Operation, Items, Nested, Size, Goal),
    statistics(inferences, Before),
    call(Goal),
    statistics(inferences, After),
    Cost is After - Before.

pass_goal(zip, Items, _, _, zip(Items, Items, _)).
pass_goal(chunk, Items, _, _, chunk(Items, 7, _)).
pass_goal(window, Items, _, _, window(Items, 3, _)).
pass_goal('flatten-once', _, Nested, _, 'flatten-once'(Nested, _)).
pass_goal('flatten-deep', _, Nested, _, 'flatten-deep'(Nested, _)).
pass_goal(drop, Items, _, Size, drop(Items, Half, _)) :- Half is Size // 2.

:- end_tests(lib_functional).
