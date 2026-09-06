% Purpose: test structural symbol scoring independently of function registration.
% Guarantees: defining a head preserves its similarity and grounded leaves stay
%   crisp [tested: sh engine/test.sh suites/libraries/lib_soft.plt; commit=WORKTREE].

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

soft_answers(Term, Answers) :-
    findall(Answer, eval(Term, Answer), Answers).

:- initialization('import!'('&self', [library, lib_soft], _)).

:- multifile seam:host_object/1.
seam:host_object('$soft-test-grounded').

:- begin_tests(lib_soft).

test(defining_a_head_preserves_similarity) :-
    'add-atom'('&self', [similar, 'soft-tepid', 'soft-warm', 0.9], _),
    soft_answers(['soft-score-by', mean, ['soft-tepid', 5], ['soft-warm', 5]], Before),
    assertion(Before == [0.95]),
    'add-atom'('&self', [=, ['soft-warm', X], [*, X, 2]], _),
    soft_answers(['get-metatype', 'soft-warm'], Kind),
    assertion(Kind == ['Grounded']),
    soft_answers(['sym-sim', 'soft-tepid', 'soft-warm'], Similarity),
    assertion(Similarity == [0.9]),
    soft_answers(['soft-score-by', mean, ['soft-tepid', 5], ['soft-warm', 5]], After),
    assertion(After == Before),
    soft_answers(['soft-score', [=, ['soft-tepid', P], B],
                               [=, ['soft-warm', Y], [*, Y, 2]]], Equation),
    assertion(Equation == [0.9]),
    assertion(var(P)), assertion(var(B)).

test(grounded_values_ignore_similarity_rows) :-
    forall(member(A-B, [3-4, "warm"-"tepid", true-false,
                        3-'soft-warm', '$soft-test-grounded'-'soft-warm']),
           ( 'add-atom'('&self', [similar, A, B, 0.9], _),
             soft_answers(['soft-score', A, B], Answers),
             assertion(Answers == [0.0]) )),
    forall(member(Value, [3, "warm", true, false, []]),
           ( soft_answers(['soft-score', Value, Value], Answers),
             assertion(Answers == [1.0]) )).

test(symbol_discriminator_observes_representation) :-
    forall(member(Value, ['soft-tepid', 'soft-warm', min]),
           ( soft_answers(['soft-symbol?', Value], Answers),
             assertion(Answers == [true]) )),
    forall(member(Value, [_, 3, "warm", true, false, [], [warm, 5],
                          '$soft-test-grounded']),
           ( soft_answers(['soft-symbol?', Value], Answers),
             assertion(Answers == [false]) )).

test(expression_shape_remains_crisp) :-
    soft_answers(['soft-score', [likes, cat], [likes, cat, fish]], Answers),
    assertion(Answers == [0.0]).

:- end_tests(lib_soft).
