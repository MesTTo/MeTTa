% Purpose: supply algebra primitives during catalog validation and evaluation.
% Assumes: metta_engine loads this unit before spaces seeds finite algebras.
% Guarantees: visibility operations accept only INTERNAL and PUBLIC; numeric
%   operations keep their native arithmetic calls
%   [tested: references:visibility_is_a_checked_two_element_lattice; commit=WORKTREE].
% Decides: a custom operation runs under the requested algebra after boot.

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
