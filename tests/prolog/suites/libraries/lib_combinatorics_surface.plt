% Purpose: check the enumerations against their exact counts and the counts
% against the host's own arithmetic.
% Guarantees: every enumeration answers each choice exactly once and as many
% times as its count says, and each count agrees with a second way of computing
% it [tested: lib_combinatorics_surface; commit=WORKTREE].
% Owns resources: none; every answer is a term.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(apply), [foldl/4]).
:- use_module(library(yall), [(>>)/4]).
:- initialization(consult('../../lib/lib_combinatorics/lib_combinatorics.pl')).

:- begin_tests(lib_combinatorics_surface).
:- meta_predicate must_throw(0, ?).

must_throw(Goal, Expected) :-
    catch(Goal, Error, true), assertion(nonvar(Error)), assertion(Error = Expected).

% numlist/3 FAILS for an empty range rather than answering the empty list, so
% the size-zero case of every generator needs its own sequence.
items(0, []) :- !.
items(Size, Items) :- numlist(1, Size, Items).

% An enumeration and its count are the same question asked two ways, so each
% enumeration is counted and compared with the closed form.
test(permutations_are_counted_by_factorial, [forall(between(0, 6, Size))]) :-
    items(Size, Items),
    findall(P, permutations(Items, P), Permutations),
    length(Permutations, Counted),
    factorial(Size, Expected),
    assertion(Counted == Expected),
    sort(Permutations, Distinct),
    length(Distinct, DistinctCount),
    assertion(DistinctCount == Expected),
    forall(member(Permutation, Permutations), msort(Permutation, Items)).

test(subsets_are_counted_by_two_to_the_n, [forall(between(0, 8, Size))]) :-
    items(Size, Items),
    findall(S, subsets(Items, S), Subsets),
    length(Subsets, Counted),
    Expected is 2 ** Size,
    assertion(Counted =:= Expected),
    sort(Subsets, Distinct), length(Distinct, DistinctCount),
    assertion(DistinctCount =:= Expected),
    % Each subset keeps the items' own order, so it is a sublist rather than a
    % permutation of one.
    forall(member(Subset, Subsets), ordered_sublist(Subset, Items)).

ordered_sublist([], _).
ordered_sublist([Item|More], Items) :-
    append(_, [Item|Rest], Items),
    ordered_sublist(More, Rest).

test(subsets_of_a_size_are_counted_by_binomial, [forall(between(0, 7, Size))]) :-
    items(Size, Items),
    findall(S, subsets(Items, S), Subsets),
    forall(between(0, Size, Chosen),
           ( findall(S, (member(S, Subsets), length(S, Chosen)), OfSize),
             length(OfSize, Counted),
             binomial(Size, Chosen, Expected),
             assertion(Counted == Expected) )).

test(tuples_are_counted_by_the_product_of_the_sizes) :-
    Sets = [[a, b, c], [1, 2], [x]],
    findall(T, tuples(Sets, T), Tuples),
    length(Tuples, Counted),
    assertion(Counted == 6),
    assertion(Tuples == [[a,1,x], [a,2,x], [b,1,x], [b,2,x], [c,1,x], [c,2,x]]),
    findall(T, tuples([], T), Empty), assertion(Empty == [[]]),
    findall(T, tuples([[a], []], T), None), assertion(None == []),
    must_throw(tuples(notalist, _), error(type_error(list, notalist), _)),
    must_throw(( tuples([notalist], _) ), error(type_error(list, notalist), _)).

test(a_power_is_counted_by_the_size_to_the_length, [forall(between(0, 5, Length))]) :-
    findall(T, 'cartesian-power'([0, 1, 2], Length, T), Tuples),
    length(Tuples, Counted),
    Expected is 3 ** Length,
    assertion(Counted =:= Expected),
    forall(member(Tuple, Tuples), length(Tuple, Length)),
    must_throw('cartesian-power'([a], -1, _), error(type_error(nonneg, -1), _)).

% A stride walk covers exactly the numbers between the ends, and never the end.
test(a_stepped_range_stops_before_its_end) :-
    findall(V, 'range-step'(0, 10, 3, V), Up), assertion(Up == [0, 3, 6, 9]),
    findall(V, 'range-step'(0, 9, 3, V), Exact), assertion(Exact == [0, 3, 6]),
    findall(V, 'range-step'(5, 0, -2, V), Down), assertion(Down == [5, 3, 1]),
    findall(V, 'range-step'(0, 0, 1, V), Same), assertion(Same == []),
    findall(V, 'range-step'(0, 5, -1, V), Away), assertion(Away == []),
    findall(V, 'range-step'(0, 1, 1, V), One), assertion(One == [0]),
    findall(V, 'range-step'(0.5, 2.0, 1, V), Floats), assertion(Floats == [0.5, 1.5]),
    must_throw('range-step'(0, 5, 0, _), error(domain_error(nonzero_step, 0), _)),
    must_throw('range-step'(0, 5, half, _), error(type_error(integer, half), _)).

% The counts against a second way of computing the same number.
test(factorial_is_the_product_of_its_range, [forall(between(0, 12, Number))]) :-
    factorial(Number, Answer),
    numlist_product(Number, Expected),
    assertion(Answer == Expected).

numlist_product(0, 1) :- !.
numlist_product(Number, Product) :-
    numlist(1, Number, Items),
    foldl([X, A0, A]>>(A is A0 * X), Items, 1, Product).

test(binomial_is_pascals_triangle, [forall(between(0, 20, Count))]) :-
    forall(between(0, Count, Chosen),
           ( binomial(Count, Chosen, Answer),
             (   ( Count =:= 0 ; Chosen =:= 0 ; Chosen =:= Count )
             ->  assertion(Answer == 1)
             ;   Above is Count - 1, Left is Chosen - 1,
                 binomial(Above, Left, One), binomial(Above, Chosen, Two),
                 Sum is One + Two,
                 assertion(Answer == Sum)
             ) )),
    binomial(0, 0, 1),
    binomial(5, 6, 0), binomial(5, -1, 0),
    must_throw(binomial(-1, 0, _), error(type_error(nonneg, -1), _)).

test(permutation_count_is_binomial_times_factorial, [forall(between(0, 15, Count))]) :-
    forall(between(0, Count, Chosen),
           ( 'permutation-count'(Count, Chosen, Answer),
             binomial(Count, Chosen, Choices), factorial(Chosen, Orders),
             Expected is Choices * Orders,
             assertion(Answer == Expected) )),
    'permutation-count'(5, 6, 0),
    'permutation-count'(5, -1, 0),
    must_throw('permutation-count'(-1, 0, _), error(type_error(nonneg, -1), _)).

% Exact rather than floating: the counts are whole numbers however large.
test(the_counts_stay_exact) :-
    factorial(30, Factorial),
    assertion(Factorial == 265252859812191058636308480000000),
    binomial(100, 50, Central),
    assertion(Central == 100891344545564193334812497256),
    'permutation-count'(100, 5, Falling),
    assertion(Falling == 9034502400),
    assertion(integer(Factorial)), assertion(integer(Central)), assertion(integer(Falling)).

% The weighted-subset heads keep their contracts; the modes they now declare are
% what the generated face reads.
test(the_weighted_subset_heads_keep_their_contracts) :-
    Candidates = [[candidate, a, 1, [ratio, 1, 2]], [candidate, b, 1, [ratio, 1, 2]]],
    'weighted-subset-mass-independent'(Candidates, 1, Mass),
    assertion(Mass == [ratio, 1, 2]),
    'weighted-subset-posterior-independent'(Candidates, 1, Posterior),
    Posterior = ['subset-posterior', Mass2, Marginals],
    assertion(Mass2 == [ratio, 1, 2]),
    assertion(Marginals == [['candidate-posterior', a, [ratio, 1, 2]],
                            ['candidate-posterior', b, [ratio, 1, 2]]]),
    'weighted-subset-mass-independent'(Candidates, 9, None),
    assertion(None == [ratio, 0, 1]).

:- end_tests(lib_combinatorics_surface).
