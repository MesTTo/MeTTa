% Purpose: supply algebra primitives during catalog validation and evaluation.
% Assumes: metta_engine loads this unit before spaces seeds finite algebras,
%   and metta/algebra_formula.pl beside it for the formula carrier.
% Guarantees: visibility operations accept only INTERNAL and PUBLIC; numeric
%   operations keep their native arithmetic calls
%   [tested: references:visibility_is_a_checked_two_element_lattice; commit=90ba93eb8f6e98ebfefc55416859bf13de6a8427];
%   the formula carrier's or, and, not and var are the decision diagram's,
%   and a carrier's negation is native where the engine knows it, complement
%   over a number and not over a formula, and its declared operation
%   otherwise [tested: test_the_formula_carrier_counts_each_proof_once; commit=55368cb4eeb641d2325194eff9d0925048814b76];
%   the polynomial carrier's plus, times and var are the free semiring's
%   [tested: algebra_fixpoint:the_polynomial_carrier_answers_every_witness_with_its_multiplicity;
%   commit=49478d67a10793a114d27d01a51f09a685d5136a].
%   A declared operation and a declared negation run in the fuel scope,
%   opened when the caller has none [tested 2026-09-25T05:48:27+10:00:
%   host_evaluation:a_declared_algebra_operation_runs_in_the_fuel_scope].
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
metta_apply_algebra_operation(polynomial, 'polynomial-plus', A, B, R) :-
    !,
    metta_polynomial_plus(A, B, R).
metta_apply_algebra_operation(polynomial, 'polynomial-times', A, B, R) :-
    !,
    metta_polynomial_times(A, B, R).
metta_apply_algebra_operation(polynomial, 'polynomial-var', Key, Weight, R) :-
    !,
    metta_polynomial_variable(Key, Weight, R).
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
%A declared operation is an equation, and evaluating it is evaluating MeTTa, so
%it runs in the fuel scope: inside a program the scope is already open and
%this is one read of it; asked by a host, which names the operation itself,
%it opens one, and a stack-depth pragma bounds the operation as it bounds the
%host evaluation door, an exhausted branch answering its
%(Error Culprit StackOverflow) as the result [tested 2026-09-25T05:48:27+10:00:
%host_evaluation:a_declared_algebra_operation_runs_in_the_fuel_scope].
metta_apply_algebra_operation(Algebra, Operation, A, B, R) :-
    (   once(metta_with_under(Algebra,
                              metta_run_with_fuel(Value, R0,
                                                  eval([Operation, A, B], Value))))
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
    (   once(metta_with_under(Algebra,
                              metta_run_with_fuel(Out, R0,
                                                  eval([Operation, Value], Out))))
    ->  Negated = R0
    ;   throw(error(metta_algebra_operation_failed(Algebra, Operation, Value),
                    none))
    ).
