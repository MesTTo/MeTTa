% Purpose: enforce carrier membership through native annotation evaluation.
% Guarantees: public annotation reads and extension validate inputs and results
%   [tested: run_tests(algebra_types); commit=WORKTREE].
% Owns resources: tests release each declaring space after evaluation.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(algebra_types).

typed_space(Space, Module, Extend) :-
    'new-space'(Space),
    space_module(Space, Module),
    with_metta_module(Module,
        'add-atom'('&metta', [algebra, 'native-number', max, Extend, 0, 1,
                             [laws], [type, 'Number', [carrier]], [requires], Space], _)).

test(annotation_validates_the_current_value,
     [ setup(typed_space(Space, Module, '*')),
       cleanup(metta_release_space(Space)),
       throws(error(metta_algebra_value_outside_carrier('native-number', "bad", _), _)) ]) :-
    with_metta_module(Module,
        metta_with_under('native-number',
            ( b_setval('$metta_answer_k', "bad"), eval([annotation], _) ))).

test(extension_validates_even_an_identity_shortcut,
     [ setup(typed_space(Space, Module, '*')),
       cleanup(metta_release_space(Space)),
       throws(error(metta_algebra_value_outside_carrier('native-number', "bad", _), _)) ]) :-
    with_metta_module(Module,
        metta_with_under('native-number', metta_k_extend(Space, 1, "bad", _))).

test(extension_validates_the_result,
     [ setup(typed_space(Space, Module, 'bad-native-result')),
       cleanup(metta_release_space(Space)),
       throws(error(metta_algebra_value_outside_carrier('native-number', "bad", _), _)) ]) :-
    with_metta_module(Module,
        ( 'add-atom'(Space, ['=', ['bad-native-result', _A, _B], "bad"], _),
          metta_with_under('native-number', metta_k_extend(Space, 2, 3, _)) )).

test(extension_accepts_a_number,
     [ setup(typed_space(Space, Module, '*')),
       cleanup(metta_release_space(Space)) ]) :-
    with_metta_module(Module,
        metta_with_under('native-number', metta_k_extend(Space, 2, 3, Result))),
    assertion(Result == 6).

test(an_uncertified_one_does_not_skip_the_declared_operation,
     [ setup(typed_space(Space, Module, '+')),
       cleanup(metta_release_space(Space)) ]) :-
    with_metta_module(Module,
        metta_with_under('native-number', metta_k_extend(Space, 1, 3, Result))),
    assertion(Result == 4).

:- end_tests(algebra_types).
