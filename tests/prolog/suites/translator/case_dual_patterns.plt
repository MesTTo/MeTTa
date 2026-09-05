% Purpose: keep wildcard case patterns distinct from the Empty default in duals.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(case_dual_patterns).

test(an_empty_body_and_an_unmatched_case_have_true_duals) :-
    with_output_to(string(_), filereader:process_metta_string(
        "(= (unmatched-case $key)\n\c
            (case $key ((90 True)\n\c
                        ($other (case $key ((40 False) ($rest (empty))))))))\n\c
         !(not-provable (empty))\n\c
         !(not-provable (unmatched-case 55))", Results)),
    assertion(Results == [true, true]).

test(a_nested_integer_case_keeps_its_wildcard_pattern) :-
    with_output_to(string(_), filereader:process_metta_string(
        "(= (nested-integer-case $key)\n\c
            (case $key ((1 True)\n\c
                        ($other (case $key ((2 False) ($rest False)))))))\n\c
         !(not-provable (nested-integer-case 1))\n\c
         !(not-provable (nested-integer-case 2))\n\c
         !(not-provable (nested-integer-case 3))", Results)),
    assertion(Results == [false, true, true]).

test(a_wildcard_before_empty_is_not_the_empty_default) :-
    with_output_to(string(_), filereader:process_metta_string(
        "(= (wildcard-before-empty)\n\c
            (case (empty) (($ordinary False) (Empty True))))\n\c
         !(not-provable (wildcard-before-empty))", Results)),
    assertion(Results == [false]).

test(a_symbolic_wildcard_can_reach_a_true_nested_arm) :-
    with_output_to(string(_), filereader:process_metta_string(
        "(= (nested-symbol-case $key)\n\c
            (case $key ((first False)\n\c
                        ($other (case $key ((second True) ($rest False)))))))\n\c
         !(not-provable (nested-symbol-case first))\n\c
         !(not-provable (nested-symbol-case second))\n\c
         !(not-provable (nested-symbol-case third))", Results)),
    assertion(Results == [true, false, true]).

:- end_tests(case_dual_patterns).
