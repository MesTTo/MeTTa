% Purpose: supply algebra primitives during catalog validation and evaluation.
% Assumes: metta_engine loads this unit before spaces seeds finite algebras,
%   and metta/algebra_formula.pl beside it for the formula carrier.
% Guarantees: visibility operations accept only INTERNAL and PUBLIC; numeric
%   operations keep their native arithmetic calls
%   [tested: references:visibility_is_a_checked_two_element_lattice; commit=90ba93eb8f6e98ebfefc55416859bf13de6a8427];
%   the formula carrier's or, and, not and var are the decision diagram's,
%   and a carrier's negation is native where the engine knows it, complement
%   over a number and not over a formula, and its declared operation
%   otherwise [tested: test_the_formula_carrier_counts_each_proof_once; commit=55368cb4eeb641d2325194eff9d0925048814b76].
% Decides: a custom operation runs under the requested algebra after boot.

metta_apply_algebra_operation(formula, 'formula-or', A, B, R) :-
    !,
    metta_formula_apply(or, A, B, R).
metta_apply_algebra_operation(formula, 'formula-and', A, B, R) :-
    !,
    metta_formula_apply(and, A, B, R).
metta_apply_algebra_operation(formula, 'formula-var', Key, Weight, R) :-
    !,
    metta_formula_variable(Key, Weight, R).
metta_apply_algebra_operation(counting, 'counting-one', _, _, 1) :-
    !.
metta_apply_algebra_operation(visibility, min, A, B, R) :-
    !,
    must_be(oneof(['INTERNAL', 'PUBLIC']), A),
    must_be(oneof(['INTERNAL', 'PUBLIC']), B),
    ( A == 'INTERNAL' -> R = A ; R = B ).
metta_apply_algebra_operation(visibility, max, A, B, R) :-
    !,
    must_be(oneof(['INTERNAL', 'PUBLIC']), A),
    must_be(oneof(['INTERNAL', 'PUBLIC']), B),
    ( A == 'PUBLIC' -> R = A ; R = B ).
metta_apply_algebra_operation(_, '*', A, B, R) :-
    number(A), number(B), !,
    R is A * B.
metta_apply_algebra_operation(_, '+', A, B, R) :-
    number(A), number(B), !,
    R is A + B.
metta_apply_algebra_operation(_, min, A, B, R) :-
    number(A), number(B), !,
    R is min(A, B).
metta_apply_algebra_operation(_, max, A, B, R) :-
    number(A), number(B), !,
    R is max(A, B).
metta_apply_algebra_operation(Algebra, Operation, A, B, R) :-
    (   once(metta_with_under(Algebra, eval([Operation, A, B], R0)))
    ->  R = R0
    ;   throw(error(metta_algebra_operation_failed(Algebra, Operation, A, B),
                    none))
    ).

%metta_apply_algebra_negation(+Algebra, +Operation, +Value, -Negated): the
%carrier's declared negation, (claim semiring <name> negation <op>), which
%is what lets a formula's model count weigh the branch a variable is false on.
metta_apply_algebra_negation(_, complement, Value, Negated) :-
    number(Value), !,
    Negated is 1 - Value.
metta_apply_algebra_negation(formula, 'formula-not', Value, Negated) :-
    !,
    metta_formula_not(Value, Negated).
metta_apply_algebra_negation(Algebra, Operation, Value, Negated) :-
    (   once(metta_with_under(Algebra, eval([Operation, Value], R0)))
    ->  Negated = R0
    ;   throw(error(metta_algebra_operation_failed(Algebra, Operation, Value),
                    none))
    ).
