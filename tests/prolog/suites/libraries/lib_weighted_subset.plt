% Purpose: verify Statistics' exact additive conditioning and sparse row bound.
% Guarantees:
%   - equivalent exact input ratios canonicalize to the same answer and
%     integer and float identities remain distinct [tested:
%     weighted_subset:equivalent_input_ratios_are_canonical,
%     weighted_subset:numeric_lookalikes_are_distinct_ids; commit=WORKTREE]
%   - twenty-four unit-loss choices truncated at target twelve retain thirteen
%     cells, rather than one cell per configuration [tested:
%     weighted_subset:repeated_unit_losses_have_target_bounded_rows;
%     commit=WORKTREE]
%   - literal identities, caller alternatives and reconstructed equations retain
%     their ordinary MeTTa semantics [tested: weighted_subset; commit=WORKTREE].

:- use_module(collection_test_support).
:- use_module(library(lists), [last/2,max_list/2,member/2,numlist/3]).
:- use_module(library(apply), [maplist/3]).
:- initialization(load_collection_library(lib_statistics)).

:- begin_tests(weighted_subset).

test(equivalent_input_ratios_are_canonical) :-
    invoke('weighted-subset-mass-independent'(
        [[candidate, a, 1, [ratio, 2, 4]]], 1, Ratio)),
    assertion(Ratio == [ratio, 1, 2]).

test(numeric_lookalikes_are_distinct_ids) :-
    invoke('weighted-subset-posterior-independent'(
        [[candidate, 1, 0, [ratio, 1, 2]],
         [candidate, 1.0, 0, [ratio, 1, 2]]],
        0,
        [ 'subset-posterior', [ratio, 1, 1],
          [['candidate-posterior', First, [ratio, 1, 2]],
           ['candidate-posterior', Second, [ratio, 1, 2]]] ])),
    assertion(First == 1),
    assertion(Second == 1.0),
    assertion(First \== Second).

test(empty_zero_target_is_certain) :-
    invoke('weighted-subset-posterior-independent'(
        [], 0, ['subset-posterior', [ratio, 1, 1], []])),
    invoke('weighted-subset-mass-independent'([],1,[ratio,0,1])).

test(zero_mass_refuses_with_reachability_remedy) :-
    catch(
        invoke('weighted-subset-posterior-independent'(
            [[candidate, absent, 2, [ratio, 0, 1]]], 2, _)),
        Error,
        true),
    assertion(nonvar(Error)),
    term_string(Error,Remedy),
    once(sub_string(Remedy, _, _, _, "weighted-subset-mass-independent")).

test(repeated_unit_losses_have_target_bounded_rows) :-
    numlist(1, 24, Ids),
    maplist(unit_candidate, Ids, Candidates),
    invoke('statistics-subset-rows'(Candidates, 12, Rows)),
    maplist(length, Rows, Lengths),
    max_list(Lengths, Maximum),
    last(Rows, Final),
    assertion(Maximum == 13),
    assertion(length(Final, 13)),
    assertion(length(Rows,25)),
    forall(member(Row,Rows),
           (findall(Sum,member([Sum,_],Row),Sums),sort(Sums,Sorted),
            assertion(Sums==Sorted),
            forall(member([Sum,Weight],Row),
                   (assertion(between(0,12,Sum)),assertion(Weight>0))))).

unit_candidate(Id, [candidate, Id, 1, [ratio, 1, 2]]).

test(the_weighted_subset_heads_keep_their_contracts) :-
    Candidates=[[candidate,a,1,[ratio,1,2]],[candidate,b,1,[ratio,1,2]]],
    invoke('weighted-subset-mass-independent'(Candidates,1,[ratio,1,2])),
    invoke('weighted-subset-posterior-independent'(Candidates,1,Posterior)),
    assertion(Posterior==['subset-posterior',[ratio,1,2],
                          [['candidate-posterior',a,[ratio,1,2]],
                           ['candidate-posterior',b,[ratio,1,2]]]]),
    invoke('weighted-subset-mass-independent'(Candidates,9,[ratio,0,1])).

test(literal_ids_do_not_execute) :-
    Ids=[['+',1,2],['Error',a,b],[], 'Empty',opaque(value)],
    Candidates=[[candidate,Id,0,[ratio,1,2]]],
    forall(member(Id,Ids),
           (invoke('weighted-subset-posterior-independent'(Candidates,0,Result)),
            assertion(Result==['subset-posterior',[ratio,1,1],
                               [['candidate-posterior',Id,[ratio,1,2]]]]))).

test(zero_and_certain_priors_and_zero_losses) :-
    Candidates=[[candidate,absent,5,[ratio,0,7]],
                [candidate,certain,2,[ratio,5,5]],
                [candidate,metadata,0,[ratio,2,6]]],
    invoke('weighted-subset-posterior-independent'(Candidates,2,Result)),
    assertion(Result==['subset-posterior',[ratio,1,1],
                       [['candidate-posterior',absent,[ratio,0,1]],
                        ['candidate-posterior',certain,[ratio,1,1]],
                        ['candidate-posterior',metadata,[ratio,1,3]]]]),
    invoke('weighted-subset-mass-independent'(Candidates,1,[ratio,0,1])).

test(ratios_keep_arbitrary_integer_precision) :-
    Denominator is (1<<2048)+1, Twice is 2*Denominator,
    invoke('weighted-subset-mass-independent'(
        [[candidate,large,1,[ratio,2,Twice]]],1,[ratio,1,Denominator])).

test(malformed_rows_and_priors_refuse) :-
    forall(member(Rows,[invalid,[invalid],[[candidate]],
                        [[other,a,1,[ratio,1,2]]],
                        [[candidate,a,1,invalid]],
                        [[candidate,a,1,[ratio,1]]],
                        [[candidate,a,1,[other,1,2]]],
                        [[candidate,a,1,[ratio,1,0]]],
                        [[candidate,a,1,[ratio,1,-2]]],
                        [[candidate,a,1,[ratio,-1,2]]],
                        [[candidate,a,1,[ratio,3,2]]],
                        [[candidate,a,1,[ratio,1.0,2]]],
                        [[candidate,a,1,[ratio,1,2.0]]],
                        [[candidate,a,1,[ratio,one,2]]]]),
           refused('weighted-subset-mass-independent'(Rows,1,_))).

test(noninteger_lattices_refuse) :-
    forall(member(Loss,[-1,1.0,one]),
           refused('weighted-subset-mass-independent'(
               [[candidate,a,Loss,[ratio,1,2]]],1,_))),
    forall(member(Target,[-1,1.0,one]),
           refused('weighted-subset-mass-independent'([],Target,_))).

test(unbound_and_duplicate_identities_refuse_without_binding) :-
    refused('weighted-subset-mass-independent'([[candidate,Id,1,[ratio,1,2]]],1,_)),
    assertion(var(Id)),
    refused('weighted-subset-mass-independent'(
        [[candidate,[f,a],1,[ratio,1,2]],[candidate,[f,a],2,[ratio,1,3]]],1,_)).

test(open_and_cyclic_host_values_refuse) :-
    refused('weighted-subset-mass-independent'(Unbound,0,_)),assertion(var(Unbound)),
    Open=[[candidate,a,1,[ratio,1,2]]|Tail],
    refused('weighted-subset-mass-independent'(Open,1,_)),assertion(var(Tail)),
    Cycle=[cycle,Cycle],
    refused('weighted-subset-mass-independent'([[candidate,Cycle,1,[ratio,1,2]]],1,_)).

test(caller_alternatives_keep_their_multiplicity) :-
    A=[[candidate,a,1,[ratio,1,2]]],B=[[candidate,b,1,[ratio,1,3]]],
    Query=[let,Rows,[superpose,[[quote,A],[quote,A],[quote,B]]],
           ['weighted-subset-mass-independent',Rows,1]],
    findall(Answer,eval_expr(Query,Answer),Answers),
    assertion(Answers==[[ratio,1,2],[ratio,1,2],[ratio,1,3]]).

test(reflection_reconstructs_the_mass_recipe) :-
    once(eval_expr([match,'&self',
                    [=,['weighted-subset-mass-independent',Rows,Target],Body],
                    [quote,Body]],Recipe)),
    once(eval_expr([let,Rows,[quote,[[candidate,a,1,[ratio,1,3]]]],
                    [let,Target,1,Recipe]],[ratio,1,3])).

:- end_tests(weighted_subset).
