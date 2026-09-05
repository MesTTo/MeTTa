% Purpose: keep singleton superpositions transparent to evaluation and tail calls.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(singleton_superpose).

test(the_only_branch_has_the_same_goal_and_output_as_its_expression) :-
    translator:translate_expr_to_conj([superpose, [['+', 1, 2]]], Wrapped, WrappedOut),
    translator:translate_expr_to_conj(['+', 1, 2], Direct, DirectOut),
    assertion((Wrapped, WrappedOut) =@= (Direct, DirectOut)).

test(the_only_branch_keeps_every_answer_and_duplicate) :-
    with_output_to(string(_), filereader:process_metta_string(
        "!(collapse (superpose ((superpose (1 2 2)))))", Results)),
    assertion(Results == [[1, 2, 2]]).

test(an_empty_only_branch_keeps_no_answers) :-
    with_output_to(string(_), filereader:process_metta_string(
        "!(collapse (superpose ((empty))))\n\c
         !(collapse (superpose (Empty)))", Results)),
    assertion(Results == [[], []]).

test(a_variable_branch_stays_unbound_until_its_enclosing_binding) :-
    with_output_to(string(_), filereader:process_metta_string(
        "!(let $value 3 (superpose ($value)))\n\c
         !(let $values (1 2) (collapse (superpose ($values))))", Results)),
    assertion(Results == [3, [[1, 2]]]).

:- end_tests(singleton_superpose).
