% Purpose: check the relation operations against the host's own pairs library,
% the stability of both orderings, the grouping and ungrouping inverse, and the
% refusal that names the element which is not a pair.
% Guarantees: for generated relations the projections, the converse, the sorts
% and the grouping answer exactly what library(pairs) answers over the same rows
% as Key-Value terms, duplicates survive every operation, and a lookup compares
% keys as terms [tested: lib_pairs; commit=40b3353b9ae721bf42b832fb953e93a5dc230e6c].
% Owns resources: none; every value is a term.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(lists), [member/2, memberchk/2, nth1/3, numlist/3]).
:- use_module(library(apply), [maplist/2, maplist/3]).
:- use_module(library(yall), [(>>)/3]).
:- use_module(library(pairs), [pairs_keys/2, pairs_keys_values/3, pairs_values/2,
                              group_pairs_by_key/2, transpose_pairs/2]).
:- use_module(library(random), [random_between/3]).
:- initialization(consult('../../lib/lib_pairs/lib_pairs.pl')).

:- begin_tests(lib_pairs).
:- meta_predicate must_throw(0, ?).

must_throw(Goal, Expected) :-
    catch(Goal, Error, true), assertion(nonvar(Error)), assertion(Error = Expected).

% A random relation over three keys and small values, so a key holds several
% values often enough for the grouping and the lookup to have work to do. The
% same rows are produced twice: as this library's (Key Value) expressions and as
% the host's Key-Value terms.
random_relation(Pairs, Keyed) :-
    random_between(0, 8, Size),
    length(Rows, Size),
    maplist(random_row, Rows),
    findall([Key, Value], member(Key-Value, Rows), Pairs),
    Keyed = Rows.

random_row(Key-Value) :-
    random_between(1, 3, Which),
    nth1(Which, [a, b, c], Key),
    random_between(0, 4, Value).

% Every projection and both orderings against library(pairs) over the same rows.
% keysort/2 is the host's stable sort and pairs_keys_values/3 its projections, so
% the differential is against the library this one is a face over rather than
% against a table.
test(the_relation_operations_agree_with_library_pairs) :-
    set_random(seed(20260912)),
    forall(between(1, 300, _),
           ( random_relation(Pairs, Keyed),
             'pairs-keys'(Pairs, Keys),
             pairs_keys(Keyed, ExpectedKeys), assertion(Keys == ExpectedKeys),
             'pairs-values'(Pairs, Values),
             pairs_values(Keyed, ExpectedValues), assertion(Values == ExpectedValues),
             pairs_keys_values(Keyed, ExpectedKeys, ExpectedValues),
             'pairs-sort-by-key'(Pairs, Sorted),
             keysort(Keyed, ExpectedSorted), as_pairs(ExpectedSorted, ExpectedSortedPairs),
             assertion(Sorted == ExpectedSortedPairs),
             'pairs-group'(Pairs, Groups),
             group_pairs_by_key(ExpectedSorted, ExpectedGroups),
             as_groups(ExpectedGroups, ExpectedGroupPairs),
             assertion(Groups == ExpectedGroupPairs),
             'pairs-swap'(Pairs, Swapped),
             findall([Value, Key], member(Key-Value, Keyed), ExpectedSwapped),
             assertion(Swapped == ExpectedSwapped) )).

as_pairs(Keyed, Pairs) :- findall([Key, Value], member(Key-Value, Keyed), Pairs).
as_groups(Keyed, Groups) :- findall([Key, Values], member(Key-Values, Keyed), Groups).

% The host's transpose_pairs/2 is the converse SORTED by the old value, which is
% this library's swap followed by its sort: the two heads compose into it rather
% than a third head existing for it.
test(the_sorted_converse_is_the_swap_and_the_sort) :-
    set_random(seed(20260912)),
    forall(between(1, 200, _),
           ( random_relation(Pairs, Keyed),
             'pairs-swap'(Pairs, Swapped), 'pairs-sort-by-key'(Swapped, Sorted),
             transpose_pairs(Keyed, Transposed), as_pairs(Transposed, Expected),
             assertion(Sorted == Expected) )).

% Both orderings keep the relative order of equal keys, which is what makes them
% usable for a stable multi-pass sort, and neither drops a row.
test(the_orderings_are_stable) :-
    Pairs = [[b, 1], [a, 2], [b, 0], [a, 1], [b, 1]],
    'pairs-sort-by-key'(Pairs, ByKey),
    assertion(ByKey == [[a, 2], [a, 1], [b, 1], [b, 0], [b, 1]]),
    'pairs-sort-by-value'(Pairs, ByValue),
    assertion(ByValue == [[b, 0], [b, 1], [a, 1], [b, 1], [a, 2]]),
    length(Pairs, Rows), length(ByKey, Rows), length(ByValue, Rows),
    % Sorting by value then by key is the stable two-pass sort: the second pass
    % keeps the first's order within each key.
    'pairs-sort-by-key'(ByValue, Both),
    assertion(Both == [[a, 1], [a, 2], [b, 0], [b, 1], [b, 1]]).

% The relation may hold one key many times, and nothing here drops a row: the
% projections, the sorts and the ungrouped grouping all have the relation's own
% length, and the grouping gathers every value.
test(duplicates_survive_every_operation) :-
    set_random(seed(20260912)),
    forall(between(1, 200, _),
           ( random_relation(Pairs, _), length(Pairs, Rows),
             'pairs-keys'(Pairs, Keys), length(Keys, Rows),
             'pairs-values'(Pairs, Values), length(Values, Rows),
             'pairs-swap'(Pairs, Swapped), length(Swapped, Rows),
             'pairs-sort-by-key'(Pairs, ByKey), length(ByKey, Rows),
             'pairs-sort-by-value'(Pairs, ByValue), length(ByValue, Rows),
             'pairs-group'(Pairs, Groups),
             findall(V, ( member([_, Vs], Groups), member(V, Vs) ), Gathered),
             length(Gathered, Rows),
             msort(Gathered, SortedGathered), msort(Values, SortedValues),
             assertion(SortedGathered == SortedValues) )),
    % A key with the same value twice keeps both, because a relation is not a set.
    'pairs-group'([[a, 1], [a, 1]], Doubled),
    assertion(Doubled == [[a, [1, 1]]]).

% Ungrouping a grouping answers the relation sorted by key, which is the only
% thing the round trip can promise: the grouping sorts.
test(grouping_and_ungrouping_are_inverses) :-
    set_random(seed(20260912)),
    forall(between(1, 200, _),
           ( random_relation(Pairs, _),
             'pairs-group'(Pairs, Groups), 'pairs-ungroup'(Groups, Back),
             'pairs-sort-by-key'(Pairs, Sorted),
             assertion(Back == Sorted),
             % Every key appears once in the grouping, whatever the relation did.
             'pairs-keys'(Groups, GroupKeys), sort(GroupKeys, Distinct),
             assertion(GroupKeys == Distinct) )),
    'pairs-group'([], Empty), assertion(Empty == []),
    'pairs-ungroup'([], NoPairs), assertion(NoPairs == []),
    % A group with no values contributes no pair, so ungrouping is not a bijection
    % on multimaps and the round trip the other way round can lose an empty group.
    'pairs-ungroup'([[a, []], [b, [1]]], OnlyB), assertion(OnlyB == [[b, 1]]).

% The lookup answers once per value, in the relation's own order, and compares
% keys as terms: a variable key matches nothing, where member/2 would have bound
% it to the first row.
test(a_lookup_compares_keys_as_terms) :-
    Pairs = [[sydney, 120], [perth, 90], [sydney, 30]],
    findall(V, 'pairs-lookup'(Pairs, sydney, V), Sydney),
    assertion(Sydney == [120, 30]),
    findall(V, 'pairs-lookup'(Pairs, perth, V), Perth), assertion(Perth == [90]),
    findall(V, 'pairs-lookup'(Pairs, darwin, V), None), assertion(None == []),
    findall(V, 'pairs-lookup'(Pairs, _, V), NoneForVariable),
    assertion(NoneForVariable == []),
    % A compound key is compared whole, so a pattern that would unify does not
    % match either.
    Keyed = [[[point, 1, 2], here]],
    findall(V, 'pairs-lookup'(Keyed, [point, 1, 2], V), Exact), assertion(Exact == [here]),
    findall(V, 'pairs-lookup'(Keyed, [point, 1, _], V), Pattern), assertion(Pattern == []).

% The refusal names the element that is not a pair rather than the collection,
% and every head that walks a relation makes it.
test(a_collection_that_is_not_pairs_is_refused_by_name) :-
    Bad = [[a, 1], b],
    forall(member(Goal, ['pairs-keys'(Bad, _), 'pairs-values'(Bad, _),
                         'pairs-swap'(Bad, _), 'pairs-sort-by-key'(Bad, _),
                         'pairs-sort-by-value'(Bad, _), 'pairs-group'(Bad, _),
                         'pairs-lookup'(Bad, a, _)]),
           must_throw(Goal, error(type_error(pair, b), _))),
    must_throw('pairs-keys'([[a, 1, 2]], _), error(type_error(pair, [a, 1, 2]), _)),
    forall(member(Goal, ['pairs-keys'(notalist, _), 'pairs-group'(notalist, _)]),
           must_throw(Goal, error(type_error(list, notalist), _))),
    must_throw('pairs-ungroup'([[a, 1]], _), error(type_error(group, [a, 1]), _)),
    must_throw('pairs-ungroup'(notalist, _), error(type_error(list, notalist), _)),
    'pairs-is'(Bad, false), 'pairs-is'([[a, 1]], true), 'pairs-is'([], true),
    'pairs-is'(notalist, false), 'pairs-is'([[a, 1, 2]], false).

:- end_tests(lib_pairs).
