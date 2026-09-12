% Purpose: verify the cost and choicepoint scope of compiled type checks.
% Guarantees: intrinsic argument checks add no native calls to their untyped
%   equivalent, while joint type witnesses commit independently of caller
%   alternatives [tested: run_tests(translator_check_commits); commit=6c70946993db4811ebc46c618e8c68a18474694c].
% Owns resources: each measured fixture releases its native space in cleanup.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(translator_check_commits).

setup_checks(Space) :-
    'new-space'(Space),
    setup_call_cleanup(
        asserta(filereader:silent(true), Ref),
        process_metta_string("
            (: checked-body (-> Atom Number Number Number))
            (= (checked-body $receiver $x $y) (+ (* $x $x) (* $y $y)))
            (= (plain-body $receiver $x $y) (+ (* $x $x) (* $y $y)))
            (= (checked $receiver $x $y) (checked-body $receiver $x $y))
            (= (plain $receiver $x $y) (plain-body $receiver $x $y))",
            [], Space),
        erase(Ref)).

inferences(Goal, Count) :-
    statistics(inferences, Before),
    forall(between(1, 10000, _), call(Goal)),
    statistics(inferences, After),
    Count is After - Before.

test(intrinsic_argument_checks_cost_no_more_than_plain_arguments,
     [setup(setup_checks(Space)), cleanup(metta_release_space(Space))]) :-
    space_module(Space, Module),
    Checked = Module:checked(receiver, 3, 4, 25),
    Plain = Module:plain(receiver, 3, 4, 25),
    with_metta_module(Module,
        ( forall(between(1, 100, _), (call(Checked), call(Plain))),
          plunit_translator_check_commits:inferences(Plain, _),
          plunit_translator_check_commits:inferences(Checked, _),
          plunit_translator_check_commits:inferences(Plain, PlainCount),
          plunit_translator_check_commits:inferences(Checked, CheckedCount),
          assertion(CheckedCount =:= PlainCount) )).

test(a_committed_witness_keeps_the_surrounding_disjunction) :-
    translator:commit_checks([member(X, [first, second]), X = second], [Goal], []),
    findall(X, (Goal; X = fallback), Answers),
    assertion(Answers == [second, fallback]).

test(a_failed_group_leaves_its_bindings_and_the_other_branch_free) :-
    translator:commit_checks([X = rejected, fail], [Goal], []),
    findall(X, (Goal; X = fallback), Answers),
    assertion(Answers == [fallback]),
    assertion(var(X)).

test(argument_choices_survive_checks_and_wrong_inputs_keep_their_error,
     [setup(setup_checks(Space)), cleanup(metta_release_space(Space))]) :-
    space_module(Space, Module),
    with_metta_module(Module,
        findall(Value, eval([checked, receiver, [superpose, [3, 4]], 4], Value), Answers)),
    assertion(Answers == [25, 32]),
    with_metta_module(Module,
        findall(Value, eval([checked, receiver, "bad", 4], Value), Bad)),
    assertion(Bad = [['Error', ['checked-body', receiver, "bad", 4],
                      ['BadArgType', 2, 'Number', 'String']]]).

:- end_tests(translator_check_commits).
