% Purpose: the formula carrier, whose values are reduced ordered binary
%   decision diagrams over the facts and rule instances a program derived
%   from, so alternative derivations that share a fact are counted once, a
%   cyclic program converges (or is idempotent and absorptive), and a carrier
%   with a negation reads the exact weighted model count back from it.
% Assumes: metta_engine loads this unit beside metta/algebra_operations.pl,
%   which routes the formula operations here; a formula value is the MeTTa
%   term [formula, Id] with [formula, 0] false and [formula, 1] true.
% Guarantees:
%   - one variable per key, minted on first sight, its weight the tag last
%     minted for it; a key is [src, Space, N] for a fact or [rule, Space, N,
%     Head] for a ground rule instance, so the derived and the tabled routes
%     over one space mint the same variable for the same fact, and a space
%     name reused after a drop reads its current program [tested:
%     test_the_formula_carrier_counts_each_proof_once,
%     test_a_cyclic_program_is_exact_under_formula; commit=55368cb4eeb641d2325194eff9d0925048814b76].
%   - or, and and not are the reduced ordered diagram's apply, memoised on
%     (operation, left, right), so two structurally equal formulas are one
%     node id and a repeated combination costs one table lookup (Bryant 1986,
%     Graph-based algorithms for Boolean function manipulation, IEEE TC 35(8),
%     10.1109/TC.1986.1676819) [tested:
%     test_the_formula_carrier_counts_each_proof_once; commit=55368cb4eeb641d2325194eff9d0925048814b76].
%   - the model count under a carrier with a negation is exact:
%     wmc(node) = w ⊗ wmc(hi) ⊕ negate(w) ⊗ wmc(lo), memoised per node, so it
%     is linear in the diagram's size (aProbLog, Kimmig, Van den Broeck and
%     De Raedt, AAAI 2011, 10.1609/aaai.v25i1.7852) [tested:
%     test_the_formula_carrier_counts_each_proof_once,
%     test_a_cyclic_program_converges_under_every_shipped_carrier; commit=55368cb4eeb641d2325194eff9d0925048814b76].
%   - the witnesses of a positive formula are its prime implicants, the
%     minimal variable sets whose truth alone makes it true, read off the
%     diagram with one memo per node: an implicant of the high branch
%     that no implicant of the low branch absorbs takes the node's
%     variable (Coudert and Madre, DAC 1992, 10.1109/DAC.1992.227866),
%     which for the fixpoint's positive formulas is every minimal
%     derivation [tested: algebra_fixpoint:a_formula_answers_its_minimal_derivations_as_witnesses;
%     commit=WORKTREE].
% Owns resources: the four dynamic tables below are process-global memory
%   released only by metta_formula_clear/0; a program that mints variables
%   forever grows them, as a program that asserts forever grows the database.
% Guarded by: with_mutex(metta_formula) around every table write, so two
%   threads cannot mint two ids for one node or one key; reads are unguarded
%   under the logical update view.
% Decides: the variable order is first-seen order, which is derivation order
%   for one evaluation; a subsequent evaluation over the same space sees the
%   same variables, since the key names the fact and not the evaluation.

:- dynamic '$metta_formula_node'/4.       % node(Id, Var, Lo, Hi)
:- dynamic '$metta_formula_unique'/4.     % unique(Var, Lo, Hi, Id)
:- dynamic '$metta_formula_cache'/4.      % cache(Op, A, B, R)
:- dynamic '$metta_formula_variable'/3.   % variable(Key, Var, Weight)

%metta_formula_variable(+Key, +Weight, -Formula): the formula that is the
%variable named by Key, minted on first sight; a key minted again with
%another weight keeps its variable and takes the new weight, so a space name
%reused after a drop, or a program edited in place, counts under the program
%that is there now.
metta_formula_variable(Key, Weight, Out) :-
    with_mutex(metta_formula,
        (   '$metta_formula_variable'(Key, Var, Recorded)
        ->  (   Recorded == Weight
            ->  true
            ;   retract('$metta_formula_variable'(Key, Var, Recorded)),
                assertz('$metta_formula_variable'(Key, Var, Weight))
            )
        ;   flag('$metta_formula_variables', Var, Var + 1),
            assertz('$metta_formula_variable'(Key, Var, Weight))
        )),
    metta_formula_node(Var, [formula, 0], [formula, 1], Out).

%The unique table: one id per (Var, Lo, Hi), and a node whose branches agree
%is that branch, which is the reduction.
metta_formula_node(_, Same, Same, Same) :- !.
metta_formula_node(Var, [formula, Lo], [formula, Hi], [formula, Id]) :-
    with_mutex(metta_formula,
        (   '$metta_formula_unique'(Var, Lo, Hi, Id)
        ->  true
        ;   flag('$metta_formula_nodes', Id0, Id0 + 1),
            Id is Id0 + 2,
            assertz('$metta_formula_node'(Id, Var, Lo, Hi)),
            assertz('$metta_formula_unique'(Var, Lo, Hi, Id))
        )).

%metta_formula_apply(+Op, +A, +B, -Out): or or and over two formulas, the
%Shannon expansion on the smaller top variable.
%Time: one cache probe per reachable (Op, A, B) pair, so |A|·|B| node visits
%in the worst case, |A| and |B| the two diagrams' sizes. Space: the nodes
%minted, at most |A|·|B|.
metta_formula_apply(Op, [formula, A], [formula, B], Out) :-
    (   metta_formula_terminal(Op, A, B, Terminal)
    ->  Out = [formula, Terminal]
    ;   '$metta_formula_cache'(Op, A, B, Cached)
    ->  Out = [formula, Cached]
    ;   metta_formula_top(A, B, Var, ALo, AHi, BLo, BHi),
        metta_formula_apply(Op, [formula, ALo], [formula, BLo], Lo),
        metta_formula_apply(Op, [formula, AHi], [formula, BHi], Hi),
        metta_formula_node(Var, Lo, Hi, Out),
        Out = [formula, Id],
        with_mutex(metta_formula, assertz('$metta_formula_cache'(Op, A, B, Id)))
    ).

metta_formula_terminal(_, A, A, A) :- !.
metta_formula_terminal(and, 0, _, 0) :- !.
metta_formula_terminal(and, _, 0, 0) :- !.
metta_formula_terminal(and, 1, B, B) :- !.
metta_formula_terminal(and, A, 1, A) :- !.
metta_formula_terminal(or, 1, _, 1) :- !.
metta_formula_terminal(or, _, 1, 1) :- !.
metta_formula_terminal(or, 0, B, B) :- !.
metta_formula_terminal(or, A, 0, A) :- !.

%The smaller variable is the earlier seen one; a terminal, or a node below
%that variable, keeps both cofactors as itself.
metta_formula_top(A, B, Var, ALo, AHi, BLo, BHi) :-
    metta_formula_variable_of(A, VarA),
    metta_formula_variable_of(B, VarB),
    Var is min(VarA, VarB),
    metta_formula_cofactors(A, Var, ALo, AHi),
    metta_formula_cofactors(B, Var, BLo, BHi).

metta_formula_variable_of(Id, Var) :-
    (   '$metta_formula_node'(Id, Var0, _, _)
    ->  Var = Var0
    ;   Var = inf
    ).

metta_formula_cofactors(Id, Var, Lo, Hi) :-
    (   '$metta_formula_node'(Id, Var, Lo, Hi)
    ->  true
    ;   Lo = Id, Hi = Id
    ).

%metta_formula_not(+Formula, -Negated): the complement, memoised under the
%operation name not with a zero right operand.
metta_formula_not([formula, 0], [formula, 1]) :- !.
metta_formula_not([formula, 1], [formula, 0]) :- !.
metta_formula_not([formula, Id], Out) :-
    (   '$metta_formula_cache'(not, Id, 0, Cached)
    ->  Out = [formula, Cached]
    ;   '$metta_formula_node'(Id, Var, Lo, Hi),
        metta_formula_not([formula, Lo], NotLo),
        metta_formula_not([formula, Hi], NotHi),
        metta_formula_node(Var, NotLo, NotHi, Out),
        Out = [formula, NotId],
        with_mutex(metta_formula, assertz('$metta_formula_cache'(not, Id, 0, NotId)))
    ).

%metta_formula_model_count(+Formula, +Algebra, -Count): the weighted model
%count of Formula under a carrier that declares a negation, each variable
%weighing the tag recorded when it was minted.
%Time: one visit per node, memoised. Space: the memo, one entry per node.
metta_formula_model_count([formula, Id], Algebra, Count) :-
    metta_algebra_descriptor(Algebra, Combine, Extend, Zero, One, _, _, _),
    metta_algebra_negation_claim(Algebra, Negation),
    empty_assoc(Memo0),
    metta_formula_model_count_(Id, count(Algebra, Combine, Extend, Negation, Zero, One),
                               Count, Memo0, _).

%The carrier's declared negation, or the refusal that names the carrier.
metta_algebra_negation_claim(Algebra, Negation) :-
    (   metta_algebra_claim(Algebra, negation, Negation0)
    ->  Negation = Negation0
    ;   throw(error(metta_algebra_negation_required(Algebra), none))
    ).

metta_formula_model_count_(0, count(_, _, _, _, Zero, _), Zero, Memo, Memo) :- !.
metta_formula_model_count_(1, count(_, _, _, _, _, One), One, Memo, Memo) :- !.
metta_formula_model_count_(Id, Ops, Count, Memo0, Memo) :-
    (   get_assoc(Id, Memo0, Cached)
    ->  Count = Cached, Memo = Memo0
    ;   Ops = count(Algebra, Combine, Extend, Negation, _, _),
        '$metta_formula_node'(Id, Var, Lo, Hi),
        '$metta_formula_variable'(_, Var, Weight),
        metta_formula_model_count_(Hi, Ops, HiCount, Memo0, Memo1),
        metta_formula_model_count_(Lo, Ops, LoCount, Memo1, Memo2),
        metta_apply_algebra_operation(Algebra, Extend, Weight, HiCount, HiTerm),
        metta_apply_algebra_negation(Algebra, Negation, Weight, Complement),
        metta_apply_algebra_operation(Algebra, Extend, Complement, LoCount, LoTerm),
        metta_apply_algebra_operation(Algebra, Combine, HiTerm, LoTerm, Count),
        put_assoc(Id, Memo2, Count, Memo)
    ).

%metta_formula_witnesses(+Formula, -Witnesses): the prime implicants of a
%positive formula, each the [Key, Weight] pairs of its variables in
%variable order, the witnesses in standard order. The fixpoint builds its
%formulas from or, and and var alone, so every implicant is a set of
%sources sufficient for the answer and minimal among such sets.
%Time: one visit per node, each joining its branches' implicant lists
%with an absorption check, so the product of their sizes at a node;
%the output can be as large as the number of minimal derivations.
metta_formula_witnesses([formula, Id], Witnesses) :-
    empty_assoc(Memo0),
    metta_formula_implicants_(Id, Sets, Memo0, _),
    findall(Rows,
            ( member(Set, Sets),
              findall([Key, Weight],
                      ( member(Var, Set), '$metta_formula_variable'(Key, Var, Weight) ),
                      Rows) ),
            Witnesses).

metta_formula_implicants_(0, [], Memo, Memo) :- !.
metta_formula_implicants_(1, [[]], Memo, Memo) :- !.
metta_formula_implicants_(Id, Sets, Memo0, Memo) :-
    (   get_assoc(Id, Memo0, Cached)
    ->  Sets = Cached, Memo = Memo0
    ;   '$metta_formula_node'(Id, Var, Lo, Hi),
        metta_formula_implicants_(Lo, LoSets, Memo0, Memo1),
        metta_formula_implicants_(Hi, HiSets, Memo1, Memo2),
        findall([Var|Set],
                ( member(Set, HiSets),
                  \+ ( member(Absorbing, LoSets), subset(Absorbing, Set) ) ),
                WithVar),
        append(LoSets, WithVar, Sets0),
        sort(Sets0, Sets),
        put_assoc(Id, Memo2, Sets, Memo)
    ).

%metta_formula_variables(+Formula, -Variables): the [Key, Weight] pairs of the
%variables a formula mentions, in variable order, for a reader that wants the
%explanation rather than the count.
metta_formula_variables([formula, Id], Variables) :-
    metta_formula_nodes_(Id, [], Nodes),
    findall(Var, ( member(Node, Nodes), '$metta_formula_node'(Node, Var, _, _) ), Vars0),
    sort(Vars0, Vars),
    findall([Key, Weight],
            ( member(Var, Vars), '$metta_formula_variable'(Key, Var, Weight) ),
            Variables).

metta_formula_nodes_(Id, Seen, Seen) :- ( Id < 2 ; memberchk(Id, Seen) ), !.
metta_formula_nodes_(Id, Seen0, Seen) :-
    '$metta_formula_node'(Id, _, Lo, Hi),
    metta_formula_nodes_(Lo, [Id|Seen0], Seen1),
    metta_formula_nodes_(Hi, Seen1, Seen).

%metta_formula_clear: forget every node, cache entry and variable, and start
%the ids again; every formula value held anywhere is invalid afterwards.
metta_formula_clear :-
    with_mutex(metta_formula,
        ( retractall('$metta_formula_node'(_, _, _, _)),
          retractall('$metta_formula_unique'(_, _, _, _)),
          retractall('$metta_formula_cache'(_, _, _, _)),
          retractall('$metta_formula_variable'(_, _, _)),
          flag('$metta_formula_variables', _, 0),
          flag('$metta_formula_nodes', _, 0) )).
