% Purpose: pin the weighted-subset exact-number contract and sparse row bound.
% Guarantees:
%   - equivalent exact input ratios canonicalize to the same answer and
%     integer and float identities remain distinct [tested:
%     weighted_subset:equivalent_input_ratios_are_canonical,
%     weighted_subset:numeric_lookalikes_are_distinct_ids; commit=afc4024cef7d4b7bcdd194bb030a112187b676d0]
%   - twenty-four unit-loss choices truncated at target twelve retain thirteen
%     cells, rather than one cell per configuration [tested:
%     weighted_subset:repeated_unit_losses_have_target_bounded_rows;
%     commit=afc4024cef7d4b7bcdd194bb030a112187b676d0]

:- initialization(consult('../../lib/lib_combinatorics/lib_combinatorics.pl')).

:- begin_tests(weighted_subset).

test(equivalent_input_ratios_are_canonical) :-
    'weighted-subset-mass-independent'(
        [[candidate, a, 1, [ratio, 2, 4]]], 1, Ratio),
    assertion(Ratio == [ratio, 1, 2]).

test(numeric_lookalikes_are_distinct_ids) :-
    'weighted-subset-posterior-independent'(
        [[candidate, 1, 0, [ratio, 1, 2]],
         [candidate, 1.0, 0, [ratio, 1, 2]]],
        0,
        [ 'subset-posterior', [ratio, 1, 1],
          [['candidate-posterior', First, [ratio, 1, 2]],
           ['candidate-posterior', Second, [ratio, 1, 2]]] ]),
    assertion(First == 1),
    assertion(Second == 1.0),
    assertion(First \== Second).

test(empty_zero_target_is_certain) :-
    'weighted-subset-posterior-independent'(
        [], 0, ['subset-posterior', [ratio, 1, 1], []]).

test(zero_mass_refuses_with_reachability_remedy) :-
    catch(
        'weighted-subset-posterior-independent'(
            [[candidate, absent, 2, [ratio, 0, 1]]], 2, _),
        error(weighted_subset_zero_mass(2),
              context('weighted-subset-posterior-independent'/2, Remedy)),
        true),
    assertion(nonvar(Remedy)),
    %once/1, because sub_string/5 with unbound positions can match at
    %several offsets and leaves a choicepoint the gate fails on.
    once(sub_string(Remedy, _, _, _, "weighted-subset-mass-independent")).

test(repeated_unit_losses_have_target_bounded_rows) :-
    numlist(1, 24, Ids),
    maplist(unit_candidate, Ids, Candidates),
    lib_combinatorics:weighted_subset_prefix_rows(Candidates, 12, Rows),
    maplist(length, Rows, Lengths),
    max_list(Lengths, Maximum),
    last(Rows, Final),
    assertion(Maximum == 13),
    assertion(length(Final, 13)).

unit_candidate(Id, ws_candidate(Id, 1, 1, 2)).

:- end_tests(weighted_subset).
