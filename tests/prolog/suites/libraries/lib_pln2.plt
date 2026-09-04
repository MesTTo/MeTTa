% Purpose: pin lib_pln2's exact formula examples and loud dependence boundary.
% Guarantees:
%   - Beta moments, independent product, and conditional total probability
%     answer their independently calculated fixtures [tested: pln2;
%     commit=afc4024cef7d4b7bcdd194bb030a112187b676d0]
%   - repeated support refuses with the reasoner-owned factoring remedy
%     [tested: pln2:overlap_names_the_factoring_remedy; commit=afc4024cef7d4b7bcdd194bb030a112187b676d0]

:- initialization(consult('../../lib/lib_pln2/lib_pln2.pl')).

:- begin_tests(pln2).

test(beta_moments) :-
    'pln2-beta-moments'([beta, 2.0, 3.0], [moments, Mean, Variance]),
    assertion(abs(Mean - 0.4) < 1.0e-15),
    assertion(abs(Variance - 0.04) < 1.0e-15).

test(independent_product) :-
    'pln2-product-independent'(
        [supported, [moments, 0.5, 0.1], [left]],
        [supported, [moments, 0.4, 0.05], [right]],
        [supported, [moments, Mean, Variance], [left, right]]),
    assertion(abs(Mean - 0.2) < 1.0e-15),
    assertion(abs(Variance - 0.0335) < 1.0e-15).

test(conditional_total_probability) :-
    'pln2-total-probability-independent'(
        [supported, [moments, 0.8, 0.02], [if_true]],
        [supported, [moments, 0.2, 0.03], [if_false]],
        [supported, [moments, 0.6, 0.04], [condition]],
        [supported, [moments, Mean, Variance], [if_true, if_false, condition]]),
    assertion(abs(Mean - 0.56) < 1.0e-15),
    assertion(abs(Variance - 0.0284) < 1.0e-15).

test(overlap_names_the_factoring_remedy) :-
    catch(
        'pln2-product-independent'(
            [supported, [moments, 0.5, 0.1], [shared]],
            [supported, [moments, 0.4, 0.05], [shared]], _),
        error(pln2_dependent_supports(shared), context(_, Remedy)),
        true),
    assertion(nonvar(Remedy)),
    assertion(sub_string(Remedy, _, _, _, "factor shared support")),
    assertion(sub_string(Remedy, _, _, _, "owned reasoner")).

:- end_tests(pln2).
