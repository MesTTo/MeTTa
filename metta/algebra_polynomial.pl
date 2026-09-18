% Purpose: the polynomial carrier, whose values are the polynomials of the
%   free commutative semiring over the program's facts and rule instances, so
%   a tabled answer's tag is every witness of its derivation, with
%   multiplicity, and any other carrier's value is that polynomial evaluated.
% Assumes: metta_engine loads this unit beside metta/algebra_operations.pl,
%   which routes the polynomial operations here; a value is [poly|Monomials]
%   with [poly] the zero and [poly, [1]] the one; a monomial is
%   [Coefficient|Variables], its variables [var, Key, Weight] in standard
%   order with repetition, and the monomials in standard order of their
%   variables, so two equal polynomials are one term.
% Guarantees:
%   - plus merges monomials and adds their coefficients, times multiplies
%     every pair and merges, the operations of N[X], the universal
%     commutative semiring (Green, Karvounarakis and Tannen, PODS 2007,
%     10.1145/1265530.1265535): every carrier's value of a derivation is
%     this polynomial under the one homomorphism sending each variable to
%     that carrier's tag for the source [tested:
%     algebra_fixpoint:the_polynomial_carrier_answers_every_witness_with_its_multiplicity;
%     commit=WORKTREE].
%   - a variable is minted per fact and per ground rule instance from the
%     fixpoint's keys, [src, Space, N] and [rule, Space, N, Head], so a
%     monomial names exactly the sources one derivation uses and how often
%     [tested: algebra_fixpoint:the_polynomial_carrier_answers_every_witness_with_its_multiplicity;
%     commit=WORKTREE].
% Decides: the polynomial is canonical, so the fixpoint's saturation test
%   is structural equality, and a program with infinitely many derivations
%   has no fixpoint here, as it has none under any non-idempotent carrier.

metta_polynomial_plus([poly|A], [poly|B], [poly|Sum]) :-
    append(A, B, Monomials),
    metta_polynomial_normal(Monomials, Sum).

%Time: |A|·|B| monomials built, then one keysort. Space: the product.
metta_polynomial_times([poly|A], [poly|B], [poly|Product]) :-
    findall([Coefficient|Variables],
            ( member([CA|VA], A),
              member([CB|VB], B),
              Coefficient is CA * CB,
              append(VA, VB, Unsorted),
              msort(Unsorted, Variables) ),
            Monomials),
    metta_polynomial_normal(Monomials, Product).

metta_polynomial_variable(Key, Weight, [poly, [1, [var, Key, Weight]]]).

%Canonical: monomials keyed by their variables in standard order, equal
%variable lists merged by adding coefficients, a zero coefficient dropped.
metta_polynomial_normal(Monomials, Normal) :-
    findall(Variables-Coefficient,
            member([Coefficient|Variables], Monomials), Pairs),
    keysort(Pairs, Sorted),
    metta_polynomial_merge(Sorted, Normal).

metta_polynomial_merge([], []).
metta_polynomial_merge([Variables-C1, Variables-C2|Rest], Normal) :-
    !,
    C is C1 + C2,
    metta_polynomial_merge([Variables-C|Rest], Normal).
metta_polynomial_merge([_-0|Rest], Normal) :-
    !,
    metta_polynomial_merge(Rest, Normal).
metta_polynomial_merge([Variables-C|Rest], [[C|Variables]|Normal]) :-
    metta_polynomial_merge(Rest, Normal).
