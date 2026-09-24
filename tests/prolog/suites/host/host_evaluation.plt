% Purpose: PlUnit coverage for the host evaluation door, metta_host_evaluate/5,
%   and the questions a host asks about an evaluation without running it.
% Assumes: engine/metta.pl is loaded; every test defines its equations under
%   an `hev-` prefix in &self, and a test that sets a pragma or a dispatch
%   default restores it in its cleanup.
% Guarantees:
%   - the door answers what the same term translated outside the fuel scope
%     answers, over every term the grid below generates and under each
%     no-match policy [tested 2026-09-25T05:48:27+10:00: host_evaluation:the_door_answers_what_translation_answers,
%     host_evaluation:an_unmatched_call_answers_by_the_no_match_policy]
%   - the symbol Empty crosses as data, and a stack-depth pragma bounds the
%     door branch by branch, a stopped branch answering after the finished
%     ones [tested 2026-09-25T05:48:27+10:00: host_evaluation:the_symbol_empty_crosses_as_data,
%     host_evaluation:a_stack_depth_pragma_bounds_the_door_branch_by_branch]
%   - the term runs for each of a generator's solutions, and a generator that
%     fails runs nothing
%     [tested 2026-09-25T05:48:27+10:00: host_evaluation:a_generator_runs_the_term_for_each_solution,
%     host_evaluation:a_generator_solution_whose_term_answers_nothing_is_skipped]
%   - a definition batch open around the door is settled before the term runs
%     [tested 2026-09-25T05:48:27+10:00: host_evaluation:a_definition_batch_is_settled_before_a_term_evaluates]
%   - the planning questions read the goals the door would run and run none of
%     them, the repeatability question declines a term it cannot classify but
%     never swallows a control limit, and a declared algebra operation or
%     negation runs in the fuel scope
%     [tested 2026-09-25T05:48:27+10:00: host_evaluation:a_planned_term_names_the_operations_the_door_would_run,
%     host_evaluation:a_repeatable_term_is_told_apart_from_an_effectful_one,
%     host_evaluation:the_repeatability_question_never_catches_a_control_limit,
%     host_evaluation:a_prepared_term_is_not_run,
%     host_evaluation:an_unmatched_call_is_told_apart_from_an_empty_body,
%     host_evaluation:a_declared_algebra_operation_runs_in_the_fuel_scope]
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(time), [call_with_time_limit/2]).

:- begin_tests(host_evaluation, [setup(hev_program)]).

hev_program :-
    metta_host_set_silent(true),
    process_metta_string(
        "(= (hev-add $x $y) (+ $x $y))
         (= (hev-pick 1) one)
         (= (hev-pick 2) two)
         (= (hev-none 1) (empty))
         (= (hev-both $x) (superpose ($x (hev-add $x 1))))
         (= (hev-empty) Empty)
         (: hev-typed (-> Number Number))
         (= (hev-typed $x) (* $x 2))
         (= (hev-deep $n) (if (== $n 0) done (hev-deep (- $n 1))))
         (= (hev-spin-op $a $b) (hev-spin-op $a (+ $b 1)))
         (= (hev-spin-neg $a) (hev-spin-neg (+ $a 1)))", _).

% ------------------------------------------------------------ one answer set

% Every head crossed with every argument the pool holds, at the head's arity:
% a compiled function on plain data, a nested call, a declared head, a special
% form, a symbol no function claims, and the boundaries between them (a symbol
% that names a function, an argument no equation head accepts, a special form
% that is also a function).
hev_head('hev-add', 2).
hev_head('hev-pick', 1).
hev_head('hev-none', 1).
hev_head('hev-both', 1).
hev_head('hev-typed', 1).
hev_head('hev-unknown', 1).
hev_head(if, 3).
%Special forms that are also functions, whose predicate and translation can
%answer differently, so a door that called the predicate would show here:
%(test-no-answer 1)'s translation collects the answer bag before it compares
%and refuses with [1], where its predicate refuses with 1.
hev_head(noeval, 1).
hev_head(superpose, 1).
hev_head('get-metatype', 1).
hev_head('test-no-answer', 1).

hev_argument(1).
hev_argument(3).
hev_argument(foo).
hev_argument("s").
hev_argument(true).
hev_argument('hev-add').
hev_argument(['hev-add', 1, 2]).

hev_term([Head|Args]) :-
    hev_head(Head, Arity),
    length(Args, Arity),
    maplist([A]>>hev_argument(A), Args).

hev_door(Term, Answers) :-
    catch(findall(A, metta_host_evaluate('&self', true, Term, A, _), Answers),
          error(Formal, _), Answers = raised(Formal)).

hev_translated(Term, Answers) :-
    space_module('&self', Module),
    catch(findall(Out,
                  ( with_metta_module(Module,
                        ( translate_cached_expr(Term, Goals, Produced),
                          call_goals_in_(Module, Goals) )),
                    translator:metta_boundary_result(Term, Produced, Out) ),
                  Answers),
          error(Formal, _), Answers = raised(Formal)).

hev_disagreements(Disagreements) :-
    findall(Term-Door-Translated,
            ( hev_term(Term),
              hev_door(Term, Door),
              hev_translated(Term, Translated),
              Door \=@= Translated ),
            Disagreements).

hev_with_no_match_policy(Policy, Goal) :-
    findall(Old, metta_catalog_row(['dispatch-default', 'NoMatchEnum', Old]), Olds),
    setup_call_cleanup(
        hev_set_no_match_policy(Olds, Policy),
        Goal,
        ( findall(Now, metta_catalog_row(['dispatch-default', 'NoMatchEnum', Now]), Nows),
          hev_restore_no_match_policy(Nows, Olds) )).

hev_set_no_match_policy(Olds, Policy) :-
    forall(member(Old, Olds),
           'remove-atom'('&metta', ['dispatch-default', 'NoMatchEnum', Old], _)),
    'add-atom'('&metta', ['dispatch-default', 'NoMatchEnum', Policy], _).

hev_restore_no_match_policy(Nows, Olds) :-
    forall(member(Now, Nows),
           'remove-atom'('&metta', ['dispatch-default', 'NoMatchEnum', Now], _)),
    forall(member(Old, Olds),
           'add-atom'('&metta', ['dispatch-default', 'NoMatchEnum', Old], _)).

%The fuel scope, the settle and the boundary change no answer of a term the
%scope does not stop, so the door answers what the same term translated
%outside them answers. The grid includes a call no equation head accepts,
%which under the preset policy both answer with nothing.
test(the_door_answers_what_translation_answers) :-
    findall(T, hev_term(T), Terms),
    length(Terms, Count),
    assertion(Count > 50),
    hev_disagreements(Disagreements),
    assertion(Disagreements == []).

%A call no equation head accepts answers by its function's no-match policy, as
%the same call compiled into a program does.
test(an_unmatched_call_answers_by_the_no_match_policy) :-
    forall(member(Policy-Expected,
                  [ 'NoMatchOriginal'-[['hev-pick', 3]],
                    'NoMatchError'-[['Error', ['hev-pick', 3], 'NoMatchingClause']] ]),
           hev_with_no_match_policy(Policy,
               ( hev_door(['hev-pick', 3], Answers),
                 assertion(Answers == Expected),
                 hev_disagreements(Disagreements),
                 assertion(Disagreements == []) ))).

% ------------------------------------------------------------ what crosses

test(the_symbol_empty_crosses_as_data) :-
    hev_door(['hev-empty'], Answers),
    assertion(Answers == ['Empty']).

test(each_answer_carries_its_residue) :-
    findall(A-D, metta_host_evaluate('&self', true, ['hev-add', 1, 2], A, D), Answers),
    assertion(Answers == [3-true]).

%The fuel scope's law, through the door: under max-stack-depth 20 the finished
%branch answers first and the branch that ran out answers its error after it.
%Outside a scope nothing charged the balance and the same recursion ran until
%the host stack gave out.
test(a_stack_depth_pragma_bounds_the_door_branch_by_branch) :-
    setup_call_cleanup(
        'pragma!'('max-stack-depth', 20, _),
        ( hev_door(['hev-deep', 100], Deep),
          hev_door([superpose, [['hev-deep', 1], ['hev-deep', 100]]], Mixed) ),
        'pragma!'('max-stack-depth', none, _)),
    assertion(Deep = [['Error', _, 'StackOverflow']]),
    assertion(Mixed = [done, ['Error', _, 'StackOverflow']]).

test(a_generator_runs_the_term_for_each_solution) :-
    findall(X-A,
            metta_host_evaluate('&self', member(X, [1, 2, 3]),
                                ['hev-add', X, 10], A, _),
            Rows),
    assertion(Rows == [1-11, 2-12, 3-13]).

%A generator that fails runs nothing, and a term that answers nothing for one
%solution leaves the other solutions' answers standing.
test(a_generator_solution_whose_term_answers_nothing_is_skipped) :-
    findall(X-A,
            metta_host_evaluate('&self', member(X, [1, 3, 2]),
                                ['hev-pick', X], A, _),
            Rows),
    assertion(Rows == [1-one, 2-two]),
    findall(A, metta_host_evaluate('&self', fail, ['hev-add', 1, 2], A, _), None),
    assertion(None == []).

%Inside a definition batch a dependent's recompilation waits for the first
%door that reads definitions; the door is one, so hev-f sees hev-g.
test(a_definition_batch_is_settled_before_a_term_evaluates) :-
    with_definition_batch(
        ( metta_add_atoms('&self', [[=, ['hev-f'], ['hev-g']],
                                   [=, ['hev-g'], 42]]),
          hev_door(['hev-f'], Answers) )),
    assertion(Answers == [42]).

% ------------------------------------------------ questions without running

test(a_planned_term_names_the_operations_the_door_would_run) :-
    metta_host_evaluation_effect_plan('&self', ['hev-add', 1, 2], Pure, PureEffect),
    assertion(Pure == [[+, pureStructural]]),
    assertion(PureEffect == pureStructural),
    metta_host_evaluation_effect_plan('&self', ['add-atom', '&self', [hev-planned, 1]],
                                      Writes, WriteEffect),
    assertion(memberchk(['add-atom', _], Writes)),
    assertion(WriteEffect \== pureStructural),
    assertion(\+ metta_host_stored('&self', [hev-planned, 1])).

test(a_repeatable_term_is_told_apart_from_an_effectful_one) :-
    assertion(metta_host_evaluation_repeatable('&self', ['hev-add', 1, 2])),
    assertion(\+ metta_host_evaluation_repeatable('&self',
                                                  ['add-atom', '&self', [hev-counted, 1]])),
    assertion(\+ metta_host_stored('&self', [hev-counted, 1])).

%A term the question cannot classify is declined, but an inference limit that
%fires inside it is the caller's to see: catch_recover/2 re-throws a control
%exception, so the classifier's own recovery cannot turn a spent budget into
%a quiet "not repeatable". The term is a 5000-deep conjunction, far past a
%50-inference budget.
repeatability_term_conjoin(Goal, Tail, [and, Goal, Tail]).

test(the_repeatability_question_never_catches_a_control_limit) :-
    length(Goals, 5000),
    maplist(=(true), Goals),
    foldl(repeatability_term_conjoin, Goals, true, Term),
    call_with_inference_limit(
        (   metta_host_evaluation_repeatable('&metta', Term)
        ->  Outcome = repeatable
        ;   Outcome = declined
        ),
        50,
        Result),
    assertion(var(Outcome)),
    assertion(Result == inference_limit_exceeded).

test(a_prepared_term_is_not_run) :-
    metta_host_evaluation_prepare('&self', ['add-atom', '&self', [hev-prepared, 1]]),
    assertion(\+ metta_host_stored('&self', [hev-prepared, 1])).

%Unmatched is a head question: (hev-pick 3) has no head for its argument,
%(hev-none 1) has one whose body answers nothing, and (hev-unknown 1) names no
%function at all.
test(an_unmatched_call_is_told_apart_from_an_empty_body) :-
    assertion(metta_host_unmatched('&self', ['hev-pick', 3])),
    assertion(\+ metta_host_unmatched('&self', ['hev-pick', 1])),
    assertion(\+ metta_host_unmatched('&self', ['hev-none', 1])),
    assertion(\+ metta_host_unmatched('&self', ['hev-unknown', 1])).

%A declared operation is an equation a host names, a binary one or a
%carrier's negation, so it runs in the fuel scope: the stack-depth pragma stops
%a runaway one and its error is the result. Outside the scope the same
%operation recurses for ever, so the wall bound turns that regression into a
%failure rather than a hung suite.
test(a_declared_algebra_operation_runs_in_the_fuel_scope,
     [ forall(member(Door, [operation, negation])) ]) :-
    setup_call_cleanup(
        'pragma!'('max-stack-depth', 20, _),
        catch(call_with_time_limit(10, hev_algebra_door(Door, Result)),
              time_limit_exceeded, Result = unbounded),
        'pragma!'('max-stack-depth', none, _)),
    assertion(Result = ['Error', _, 'StackOverflow']).

hev_algebra_door(operation, Result) :-
    metta_apply_algebra_operation(observed, 'hev-spin-op', 1, 2, Result).
hev_algebra_door(negation, Result) :-
    metta_apply_algebra_negation(observed, 'hev-spin-neg', 1, Result).

:- end_tests(host_evaluation).
