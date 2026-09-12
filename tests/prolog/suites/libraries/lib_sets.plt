% Purpose: check the set operations against their definitions over lists, the
% laws of the algebra over generated sets, and the refusal every head makes.
% Guarantees: for generated sets each merge answers exactly what its definition
% over member/2 answers, every answer is itself a set, membership compares terms
% rather than unifying, and an unordered argument is refused by every head that
% takes a set [tested: lib_sets; commit=e3e8c891065765765ee8fe567c5eb6864e79b652].
% Owns resources: none; every value is a term.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(lists), [member/2, memberchk/2, numlist/3]).
:- use_module(library(apply), [maplist/2]).
:- use_module(library(yall), [(>>)/3]).
:- use_module(library(ordsets), [is_ordset/1]).
:- use_module(library(random), [random_between/3]).
:- initialization(consult('../../lib/lib_sets/lib_sets.pl')).

:- begin_tests(lib_sets).
:- meta_predicate must_throw(0, ?).

must_throw(Goal, Expected) :-
    catch(Goal, Error, true), assertion(nonvar(Error)), assertion(Error = Expected).

% A random set over a small universe, so two of them overlap often enough for
% the merges to have something to merge.
random_set(Set) :-
    random_between(0, 6, Size),
    length(Draws, Size),
    maplist([Draw]>>random_between(0, 9, Draw), Draws),
    'set-of'(Draws, Set).

% The definitions over lists, which the merges must agree with: an element is in
% the union when it is in either, in the intersection when in both, in the
% difference when in the first and not the second, and in the symmetric
% difference when in exactly one. Each is a filter over the universe of the two.
by_definition(Left, Right, union, Answer) :-
    findall(X, ( member(X, Left) ; member(X, Right) ), Xs0), sort(Xs0, Answer).
by_definition(Left, Right, intersection, Answer) :-
    findall(X, ( member(X, Left), memberchk(X, Right) ), Xs0), sort(Xs0, Answer).
by_definition(Left, Right, difference, Answer) :-
    findall(X, ( member(X, Left), \+ memberchk(X, Right) ), Xs0), sort(Xs0, Answer).
by_definition(Left, Right, symmetric, Answer) :-
    findall(X, ( member(X, Left), \+ memberchk(X, Right)
               ; member(X, Right), \+ memberchk(X, Left) ), Xs0),
    sort(Xs0, Answer).

merge(union, Left, Right, Answer) :- 'set-union'(Left, Right, Answer).
merge(intersection, Left, Right, Answer) :- 'set-intersection'(Left, Right, Answer).
merge(difference, Left, Right, Answer) :- 'set-difference'(Left, Right, Answer).
merge(symmetric, Left, Right, Answer) :- 'set-symmetric-difference'(Left, Right, Answer).

test(the_merges_agree_with_their_list_definitions) :-
    set_random(seed(20260912)),
    forall(between(1, 300, _),
           ( random_set(Left), random_set(Right),
             forall(member(Operation, [union, intersection, difference, symmetric]),
                    ( merge(Operation, Left, Right, Answer),
                      by_definition(Left, Right, Operation, Expected),
                      assertion(Answer == Expected) )) )).

% set-of is sort/2, which is the standard order with duplicates removed; the
% differential says so against sort/4's own dedup, and against a hand count.
test(set_of_sorts_and_removes_duplicates, [forall(between(1, 100, _))]) :-
    random_between(0, 12, Size),
    length(Draws, Size),
    maplist([Draw]>>random_between(0, 5, Draw), Draws),
    'set-of'(Draws, Set),
    sort(0, @<, Draws, Expected),
    assertion(Set == Expected),
    assertion(is_ordset(Set)),
    forall(member(Draw, Draws), 'set-member'(Set, Draw, true)),
    length(Set, Distinct),
    findall(D, ( member(D, [0, 1, 2, 3, 4, 5]), memberchk(D, Draws) ), Present),
    length(Present, Counted),
    assertion(Distinct == Counted).

% Every answer of every head that answers a set is itself a set, which is what
% lets the operations compose with no normalisation between them.
test(every_answer_is_a_set) :-
    set_random(seed(20260912)),
    forall(between(1, 200, _),
           ( random_set(Left), random_set(Right), random_between(0, 9, Element),
             forall(member(Operation, [union, intersection, difference, symmetric]),
                    ( merge(Operation, Left, Right, Answer), assertion(is_ordset(Answer)) )),
             'set-insert'(Left, Element, Bigger), assertion(is_ordset(Bigger)),
             'set-remove'(Left, Element, Smaller), assertion(is_ordset(Smaller)),
             'set-union-all'([Left, Right, Bigger], All), assertion(is_ordset(All)),
             'set-intersection-all'([Left, Right, Bigger], Common), assertion(is_ordset(Common)) )).

% The laws over generated sets and a universe: commutativity, associativity,
% distribution of intersection over union, De Morgan, and the two differences.
test(the_laws_of_the_algebra_hold) :-
    set_random(seed(20260912)),
    numlist(0, 9, Universe),
    forall(between(1, 200, _),
           ( random_set(A), random_set(B), random_set(C),
             'set-union'(A, B, AB), 'set-union'(B, A, BA), assertion(AB == BA),
             'set-intersection'(A, B, AiB), 'set-intersection'(B, A, BiA), assertion(AiB == BiA),
             'set-union'(AB, C, AB_C), 'set-union'(B, C, BC), 'set-union'(A, BC, A_BC),
             assertion(AB_C == A_BC),
             'set-intersection'(A, BC, AiBC), 'set-intersection'(A, C, AiC),
             'set-union'(AiB, AiC, AiB_AiC), assertion(AiBC == AiB_AiC),
             % De Morgan: U \ (A u B) == (U \ A) n (U \ B)
             'set-difference'(Universe, AB, NotAB),
             'set-difference'(Universe, A, NotA), 'set-difference'(Universe, B, NotB),
             'set-intersection'(NotA, NotB, NotA_NotB), assertion(NotAB == NotA_NotB),
             % The symmetric difference is the union of the two differences.
             'set-difference'(A, B, AmB), 'set-difference'(B, A, BmA),
             'set-union'(AmB, BmA, Either), 'set-symmetric-difference'(A, B, Symmetric),
             assertion(Either == Symmetric),
             % Subset and disjointness against their definitions.
             'set-subset'(A, B, Sub),
             ( forall(member(X, A), memberchk(X, B)) -> assertion(Sub == true) ; assertion(Sub == false) ),
             'set-disjoint'(A, B, Dis),
             ( AiB == [] -> assertion(Dis == true) ; assertion(Dis == false) ),
             'set-subset'(A, A, true), 'set-subset'([], A, true), 'set-disjoint'([], A, true) )).

% Insertion and removal are the two-set merges with a one-element set, and
% adding what is there or removing what is not leaves the set as it was.
test(insertion_and_removal_agree_with_the_merges, [forall(between(1, 100, _))]) :-
    random_set(Set), random_between(0, 12, Element),
    'set-insert'(Set, Element, Bigger), 'set-union'(Set, [Element], ExpectedBigger),
    assertion(Bigger == ExpectedBigger),
    'set-remove'(Set, Element, Smaller), 'set-difference'(Set, [Element], ExpectedSmaller),
    assertion(Smaller == ExpectedSmaller),
    (   memberchk(Element, Set)
    ->  assertion(Bigger == Set)
    ;   assertion(Smaller == Set)
    ).

% The collection forms are the folds of the two-set merges, and the intersection
% of no sets is refused rather than answered.
test(the_collection_forms_are_the_folds) :-
    set_random(seed(20260912)),
    forall(between(1, 100, _),
           ( random_set(A), random_set(B), random_set(C),
             'set-union-all'([A, B, C], Union),
             'set-union'(A, B, AB), 'set-union'(AB, C, ExpectedUnion),
             assertion(Union == ExpectedUnion),
             'set-intersection-all'([A, B, C], Common),
             'set-intersection'(A, B, AiB), 'set-intersection'(AiB, C, ExpectedCommon),
             assertion(Common == ExpectedCommon) )),
    'set-union-all'([], None), assertion(None == []),
    'set-union-all'([[1, 2]], One), assertion(One == [1, 2]),
    must_throw('set-intersection-all'([], _), error(domain_error(non_empty_list, []), _)),
    must_throw('set-union-all'(notalist, _), error(type_error(list, notalist), _)).

% Membership is the standard order of terms and never unifies: an unbound
% variable is not in a set of numbers, and member/2 would have bound it.
test(membership_compares_terms_rather_than_unifying) :-
    'set-member'([1, 2, 3], 2, true),
    'set-member'([1, 2, 3], 4, false),
    'set-member'([1, 2, 3], Var, Answer), assertion(Answer == false), assertion(var(Var)),
    'set-member'([a, b], b, true),
    'set-member'([[1, 2], [3]], [1, 2], true),
    'set-member'([[1, 2], [3]], [1, _], PatternAnswer), assertion(PatternAnswer == false),
    'set-member'([], anything, false).

% The refusal every head that takes a set makes, and the one set-of makes.
test(an_unordered_argument_is_refused_by_every_head) :-
    Unordered = [2, 1],
    Duplicated = [1, 1],
    forall(member(Bad, [Unordered, Duplicated, notalist]),
           forall(member(Goal, ['set-member'(Bad, 1, _), 'set-insert'(Bad, 1, _),
                                'set-remove'(Bad, 1, _), 'set-union'(Bad, [1], _),
                                'set-union'([1], Bad, _), 'set-intersection'(Bad, [1], _),
                                'set-difference'([1], Bad, _),
                                'set-symmetric-difference'(Bad, [1], _),
                                'set-subset'(Bad, [1], _), 'set-disjoint'([1], Bad, _),
                                'set-union-all'([[1], Bad], _),
                                'set-intersection-all'([Bad], _)]),
                  must_throw(Goal, error(type_error(set, Bad), _)))),
    must_throw('set-of'(notalist, _), error(type_error(list, notalist), _)),
    'set-is'(Unordered, false), 'set-is'(Duplicated, false), 'set-is'(notalist, false),
    'set-is'([], true), 'set-is'([1, 2], true).

:- end_tests(lib_sets).
