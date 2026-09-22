% Purpose: compare recursive exact-memo coefficients with the uncached bag.
% Guarantees: the differential reaches populated sum tables, preserves each
%   answer's multiplicity on cold calls and replay through 6,561 occurrences
%   [tested: memo_coefficients:recursive_sum_matches_the_uncached_bag;
%   commit=WORKTREE].
% Owns resources: every case releases its space and its cache refusal row.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module('../../../../lib/lib_memo/lib_memo.pl').
:- use_module(library(apply), [maplist/2]).

:- begin_tests(memo_coefficients).

fixture(Space, Module) :-
    gensym('&memo-coefficients-', Space),
    'add-atom'('&metta', [cache, 'sum-coefficient', refuse], true),
    process_metta_string(
        "(= (coefficient-leaf) 1)\n\c
         (= (coefficient-leaf) 1)\n\c
         (= (coefficient-leaf) 2)\n\c
         (= (sum-coefficient $n)\n\c
            (if (== $n 0) (coefficient-leaf)\n\c
                (+ (sum-coefficient (- $n 1))\n\c
                   (sum-coefficient (- $n 1)))))",
        _, Space),
    space_module(Space, Module).

release(Space) :-
    metta_release_space(Space),
    'remove-atom'('&metta', [cache, 'sum-coefficient', refuse], true).

% Sorting time: O(A log A) comparisons. Space: O(A), A = 3^(2^Depth) occurrences.
% Sorting retains duplicates and compares bags independently of answer order.
bag(Module, Depth, Bag) :-
    findall(Answer,
            with_metta_module(Module, reduce(['sum-coefficient', Depth], Answer)),
            Answers),
    msort(Answers, Bag).

test(recursive_sum_matches_the_uncached_bag,
     [forall(between(0, 3, Depth)),
      setup(fixture(Space, Module)), cleanup(release(Space))]) :-
    bag(Module, Depth, Plain),
    with_metta_module(Module, 'is-memoized'('sum-coefficient', PlainEnabled)),
    assertion(PlainEnabled == false),
    % There are 2^Depth independent leaves, each with three occurrences.
    Expected is 3^(2^Depth),
    length(Plain, Expected),
    maplist(integer, Plain),
    with_metta_module(Module, 'memoize-exact'('sum-coefficient', true)),
    bag(Module, Depth, Cold),
    bag(Module, Depth, Replay),
    assertion(Cold == Plain),
    assertion(Replay == Plain),
    % is-memoized alone also accepts the ordinary list cache. Read the actual
    % trie so changing this fixture to cache force cannot silently skip sum.
    findall(Trie, lib_memo:current_exact_memo_table('sum-coefficient', Module, Trie),
            Tries),
    assertion(Tries \== []),
    with_metta_module(Module, 'get-memoize-stats'('sum-coefficient', Stats)),
    memberchk([answers, Stored], Stats),
    assertion(Stored >= Expected).

:- end_tests(memo_coefficients).
