% Purpose: differential and fallback coverage for engine/empty_prune.c, the C
%   twin of the four identity walks in engine/spaces/bounded_matching.pl. The
%   Prolog walks remain the specification; the C scan answers what they answer
%   or refuses, and never approximates.
%
%   Two levels, because agreement at one of them alone would not be enough.
%   The DOOR level drives metta_prune_empty/2 and metta_prune_empty_answers/2
%   and takes its Prolog reference by retracting
%   spaces:metta_c_empty_prune_active/0 for the length of one call, which is
%   the in-process form of METTA_C_EMPTY_PRUNE=off and is the dispatch's only
%   gate; that gives every door its own reference without a second
%   implementation in this file that could drift. Each door case also names
%   the answer it expects, so a pair of arms that agreed on the WRONG answer
%   is caught. The PREDICATE level compares metta_c_has_empty/1 and
%   metta_c_drop_empty/2 against metta_member_empty_/1 and
%   metta_drop_empty_/2 directly, and the '$metta_answer' pair likewise,
%   because a door that stopped calling into C would still agree with itself.
%
%   Three properties this file keeps beyond agreement:
%
%   - A C scan the door never reached would agree on every case, because the
%     fallback answers identically. So the lane measures COST: the C scan
%     retires the same number of inferences on a 1,000-element list and a
%     10,000-element one, where the walk retires one per cell
%     (the_c_scan_is_constant_where_the_prolog_walk_is_linear). That is also
%     the regression this whole unit exists for.
%   - The comparator must be able to say no. A planted divergence goes through
%     the same predicate every case uses and the lane fails if that stops
%     being caught (a_planted_divergence_is_caught).
%   - The surviving cells must be the CALLER's own terms, not copies, which is
%     what lets a residual constraint pass through the prune intact
%     (the_surviving_cells_are_the_callers_own_terms).
%
%   The one place the C scan is deliberately STRONGER than the walk it ports:
%   a partial list and a cyclic list have no terminating walk to match. The
%   walk unifies an open tail with [X|Xs] and recurses forever. Both doors
%   classify with '$skip_list'/3 on the Prolog branch and PL_skip_list on the
%   C branch, so the two DOORS refuse identically and both shapes are ordinary
%   cases below; only metta_member_empty_/1 called raw still spins, which is
%   why the predicate-level forall runs over the terminating shapes alone.
%
%   The differential unit is conditioned on spaces:metta_c_empty_prune_active,
%   following suites/reader/writer_c.plt. The fallback unit is deliberately
%   unconditioned, so a box without engine/empty_prune.so and
%   METTA_C_EMPTY_PRUNE=off both retain coverage and report why only the C
%   comparisons were skipped.
%
%   Run: cd tests/prolog && swipl -g "set_test_options([format(log)]), run_tests" -t halt suites/spaces/empty_prune_c.plt -- extensions
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

% Load the engine through metta.pl, not main.pl: main.pl's
% `:- initialization(main, main).` fires on consult and prints its demo
% into the test output. The suite imports its own CLP(FD) operators and hooks
% [tested: empty_prune_c_differential:a_residual_constraint_answers_through_both_arms;
% commit=WORKTREE].
:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(clpfd)).

%PlUnit omits a unit whose condition fails but does not print that condition's
%output in the log format. Report the same gate once while loading the suite,
%then let the condition itself stay a side-effect-free artifact predicate.
empty_prune_c_available :-
    spaces:metta_c_empty_prune_active.

empty_prune_c_report_unavailable :-
    (   empty_prune_c_available
    ->  true
    ;   empty_prune_c_skip_reason(Reason),
        format(user_error, "Empty-prune C differential tests skipped: ~w.~n",
               [Reason])
    ).

empty_prune_c_skip_reason('METTA_C_EMPTY_PRUNE=off') :-
    getenv('METTA_C_EMPTY_PRUNE', off),
    !.
empty_prune_c_skip_reason('engine/empty_prune.so is absent or could not be loaded').

:- empty_prune_c_report_unavailable.

%Success value, error term, or failure, so a differential case compares all
%three the same way.
prune_outcome(Goal, Value, Outcome) :-
    (   catch(Goal, E, true)
    ->  ( var(E) -> Outcome = ok(Value) ; Outcome = err(E) )
    ;   Outcome = fail
    ).

%The Prolog answer, from the same door with the C scan switched off. Tolerant
%of the flag being absent already, which is what lets the fallback unit below
%run on a box that never built the artifact.
without_c_scan(Goal) :-
    (   spaces:metta_c_empty_prune_active
    ->  setup_call_cleanup(retract(spaces:metta_c_empty_prune_active),
                           Goal,
                           assertz(spaces:metta_c_empty_prune_active))
    ;   call(Goal)
    ).

%A disagreement prints what both sides said. The planted self-test runs the
%same comparator on purpose, so it silences the report rather than bypassing
%the check.
prune_report(Format, Args) :-
    (   nb_current(empty_prune_c_quiet, true)
    ->  true
    ;   format(user_error, Format, Args)
    ).

prune_agree(Label, Left, Right) :-
    (   Left =@= Right
    ->  true
    ;   prune_report("empty-prune disagreement on ~w:~n  ~q~n  ~q~n",
                     [Label, Left, Right]),
        fail
    ).

%%%% the shapes %%%%
%
%Label, the list, and what metta_prune_empty/2 must answer for it. The
%expected term SHARES the input's variables, so =@=/2 also checks that a
%surviving cell is the caller's own and not a copy.

bare_case(empty_list,              [],                    ok([])).
bare_case(no_empty,                [a,b,c],               ok([a,b,c])).
bare_case(empty_first,             ['Empty',b,c],         ok([b,c])).
bare_case(empty_middle,            [a,'Empty',c],         ok([a,c])).
bare_case(empty_last,              [a,b,'Empty'],         ok([a,b])).
bare_case(all_empty,               ['Empty','Empty'],     ok([])).
bare_case(single_empty,            ['Empty'],             ok([])).
%An unbound answer is not Empty and is never pruned. A unifying scan bound one
%and dropped it, which is the defect translated_success_leaves_the_query_
%variable_unbound pins.
bare_case(unbound_element,         [X],                   ok([X])).
bare_case(unbound_beside_empty,    [X,'Empty'],           ok([X])).
%The ATOM Empty, not a term that merely contains it.
bare_case(empty_inside_a_term,     [[a,'Empty'],b],       ok([[a,'Empty'],b])).
bare_case(improper_without_empty,  [a,b|foo],             ok([a,b|foo])).
bare_case(improper_with_empty,     [a,'Empty'|foo],       fail).
bare_case(not_a_list,              foo,                   ok(foo)).
bare_case(attributed_alone,        [X],                   ok([X])) :- X #> 0.
bare_case(attributed_beside_empty, [X,'Empty'],           ok([X])) :- X #> 0.
bare_case(empty_beside_attributed, ['Empty',X],           ok([X])) :- X #> 0.
bare_case(attributed_among_ground, [1,X,'Empty',b],       ok([1,X,b])) :- X #> 0.
bare_case(ten_thousand_ground,     L,                     ok(L)) :-
    numlist(1, 10000, L).
bare_case(partial_list,            [a|_],
          err(error(instantiation_error, _))).
bare_case(wholly_unbound,          _,
          err(error(instantiation_error, _))).

%A cyclic list belongs beside the partial one and is tested the same way, but
%not from a forall generator: plunit records each generated binding with
%assert/1, and SWI answers `Cannot represent due to cyclic_term` for that. It
%has its own test in each unit below instead.

answer_case(empty_list, [], ok([])).
answer_case(no_empty,
            ['$metta_answer'(a,n1),'$metta_answer'(b,n2)],
            ok(['$metta_answer'(a,n1),'$metta_answer'(b,n2)])).
answer_case(empty_first,
            ['$metta_answer'('Empty',n1),'$metta_answer'(b,n2)],
            ok(['$metta_answer'(b,n2)])).
answer_case(empty_middle,
            ['$metta_answer'(a,n1),'$metta_answer'('Empty',n2),
             '$metta_answer'(c,n3)],
            ok(['$metta_answer'(a,n1),'$metta_answer'(c,n3)])).
answer_case(empty_last,
            ['$metta_answer'(a,n1),'$metta_answer'('Empty',n2)],
            ok(['$metta_answer'(a,n1)])).
answer_case(all_empty,
            ['$metta_answer'('Empty',n1),'$metta_answer'('Empty',n2)],
            ok([])).
answer_case(unbound_answer,
            ['$metta_answer'(X,n1)],
            ok(['$metta_answer'(X,n1)])).
answer_case(unbound_beside_empty,
            ['$metta_answer'(X,n1),'$metta_answer'('Empty',n2)],
            ok(['$metta_answer'(X,n1)])).
%The walk's clause head takes '$metta_answer'/2 and nothing else, so a cell of
%another shape does not unify and the goal fails, leaving the list whole.
answer_case(a_cell_that_is_not_an_answer,
            [foo,'$metta_answer'('Empty',n)],
            ok([foo,'$metta_answer'('Empty',n)])).
answer_case(a_bare_empty_among_answers,
            ['$metta_answer'(a,n),'Empty'],
            ok(['$metta_answer'(a,n),'Empty'])).
answer_case(improper_without_empty,
            ['$metta_answer'(a,n)|foo],
            ok(['$metta_answer'(a,n)|foo])).
answer_case(improper_with_empty, ['$metta_answer'('Empty',n)|foo], fail).
answer_case(attributed_answer,
            ['$metta_answer'(X,n),'$metta_answer'('Empty',m)],
            ok(['$metta_answer'(X,n)])) :- X #> 0.
answer_case(ten_thousand_ground, L, ok(L)) :-
    numlist(1, 10000, Ns),
    findall('$metta_answer'(X, names), member(X, Ns), L).
answer_case(partial_list, ['$metta_answer'(a,n)|_],
            err(error(instantiation_error, _))).

%The shapes whose Prolog WALK terminates when called raw, which is every one
%except those with no end. The doors classify those before the walk runs;
%metta_member_empty_/1 on its own does not, and would spin.
terminating_bare_case(Label, Input) :-
    bare_case(Label, Input, _),
    \+ memberchk(Label, [partial_list, wholly_unbound]).

terminating_answer_case(Label, Input) :-
    answer_case(Label, Input, _),
    Label \== partial_list.

%One call's inference cost, which is what says whether the door reached C.
%Only ever called on a list of ground answers, which the door always answers,
%so there is no wrapper here to price.
prune_cost(Input, Cost) :-
    statistics(inferences, Before),
    spaces:metta_prune_empty(Input, _),
    statistics(inferences, After),
    Cost is After - Before.

:- begin_tests(empty_prune_c_fallback).

%THE ARTIFACT AND THE FLAG HAVE TO AGREE, and the differential unit below is
%CONDITIONED on the flag: plunit SKIPS a unit whose condition fails, so an
%activation step that stopped running would read as a suite with fewer tests
%rather than as a failure. This is the unconditioned half.
%METTA_C_EMPTY_PRUNE=off and an artifact that will not load are the only two
%reasons the scan may be off, and when it is on the four names must be the
%FOREIGN predicates rather than the failing stubs
%engine/spaces/bounded_matching.pl installs in their place.
test(the_c_scan_is_active_exactly_when_its_artifact_loads) :-
    assertion(spaces:metta_empty_prune_artifact(_)),
    spaces:metta_empty_prune_artifact(Artifact),
    (   getenv('METTA_C_EMPTY_PRUNE', off)
    ->  assertion(\+ spaces:metta_c_empty_prune_active)
    ;   exists_file(Artifact)
    ->  assertion(spaces:metta_c_empty_prune_active),
        forall(member(Name/Arity, [metta_c_has_empty/1,
                                   metta_c_drop_empty/2,
                                   metta_c_has_empty_answer/1,
                                   metta_c_drop_empty_answer/2]),
               ( functor(Goal, Name, Arity),
                 assertion(predicate_property(spaces:Goal, foreign)) ))
    ;   assertion(\+ spaces:metta_c_empty_prune_active)
    ).

test(the_prolog_walk_answers_every_bare_shape_with_the_c_scan_off,
     [forall(bare_case(Label, Input, Expected))]) :-
    without_c_scan(prune_outcome(spaces:metta_prune_empty(Input, Kept),
                                 Kept, Outcome)),
    prune_agree(Label-prolog_door, Outcome, Expected).

test(the_prolog_walk_answers_every_answer_shape_with_the_c_scan_off,
     [forall(answer_case(Label, Input, Expected))]) :-
    without_c_scan(prune_outcome(spaces:metta_prune_empty_answers(Input, Kept),
                                 Kept, Outcome)),
    prune_agree(Label-prolog_answer_door, Outcome, Expected).

%The walk itself does not terminate on a list with no end, so the door
%classifies before it runs. Without that, this call would grow the global
%stack until it hit the limit.
test(a_list_with_no_end_refuses_rather_than_spinning_with_the_c_scan_off) :-
    without_c_scan(
        prune_outcome(spaces:metta_prune_empty([a|_], _), unused, Partial)),
    assertion(Partial = err(error(instantiation_error, _))),
    Cyclic = [a|Cyclic],
    without_c_scan(
        prune_outcome(spaces:metta_prune_empty(Cyclic, _), unused, Cycle)),
    assertion(Cycle = err(error(type_error(list, _), _))),
    Cycle = err(error(type_error(list, Culprit), _)),
    assertion(Culprit == Cyclic).

:- end_tests(empty_prune_c_fallback).

:- begin_tests(empty_prune_c_differential,
               [condition(user:empty_prune_c_available)]).

test(the_two_prune_doors_agree_shape_for_shape,
     [forall(bare_case(Label, Input, Expected))]) :-
    prune_outcome(spaces:metta_prune_empty(Input, KeptC), KeptC, WithC),
    without_c_scan(prune_outcome(spaces:metta_prune_empty(Input, KeptP),
                                 KeptP, WithProlog)),
    prune_agree(Label-arms, WithC, WithProlog),
    prune_agree(Label-expected, WithC, Expected).

test(the_two_answer_prune_doors_agree_shape_for_shape,
     [forall(answer_case(Label, Input, Expected))]) :-
    prune_outcome(spaces:metta_prune_empty_answers(Input, KeptC),
                  KeptC, WithC),
    without_c_scan(
        prune_outcome(spaces:metta_prune_empty_answers(Input, KeptP),
                      KeptP, WithProlog)),
    prune_agree(Label-arms, WithC, WithProlog),
    prune_agree(Label-expected, WithC, Expected).

test(the_c_scan_and_the_prolog_walk_agree_shape_for_shape,
     [forall(terminating_bare_case(Label, Input))]) :-
    prune_outcome(spaces:metta_c_has_empty(Input), found, HasC),
    prune_outcome(spaces:metta_member_empty_(Input), found, HasP),
    prune_agree(Label-has, HasC, HasP),
    prune_outcome(spaces:metta_c_drop_empty(Input, DC), DC, DropC),
    prune_outcome(spaces:metta_drop_empty_(Input, DP), DP, DropP),
    prune_agree(Label-drop, DropC, DropP).

test(the_c_answer_scan_and_the_prolog_walk_agree_shape_for_shape,
     [forall(terminating_answer_case(Label, Input))]) :-
    prune_outcome(spaces:metta_c_has_empty_answer(Input), found, HasC),
    prune_outcome(spaces:metta_member_empty_answer_(Input), found, HasP),
    prune_agree(Label-has, HasC, HasP),
    prune_outcome(spaces:metta_c_drop_empty_answer(Input, DC), DC, DropC),
    prune_outcome(spaces:metta_drop_empty_answers_(Input, DP), DP, DropP),
    prune_agree(Label-drop, DropC, DropP).

%The defect the whole unit exists for. A unifying scan RAISES here, because
%unifying 'Empty' against a clpfd variable runs attribute_unify_hook, which
%throws type_error(integer, 'Empty') out of a path that catches nothing. The
%identity scan reads the cell and answers, through both arms.
test(a_residual_constraint_answers_through_both_arms) :-
    X #> 0,
    assertion(get_attr(X, clpfd, _)),
    Input = [X, 'Empty', b],
    prune_outcome(spaces:metta_prune_empty(Input, KeptC), KeptC, WithC),
    without_c_scan(prune_outcome(spaces:metta_prune_empty(Input, KeptP),
                                 KeptP, WithProlog)),
    assertion(WithC = ok(_)),
    assertion(WithProlog = ok(_)),
    prune_agree(residual_constraint, WithC, WithProlog),
    WithC = ok(Kept),
    assertion(Kept == [X, b]),
    assertion(get_attr(X, clpfd, _)),
    Wrapped = ['$metta_answer'(X, names), '$metta_answer'('Empty', other)],
    prune_outcome(spaces:metta_prune_empty_answers(Wrapped, WrappedC),
                  WrappedC, AnswerC),
    assertion(AnswerC == ok(['$metta_answer'(X, names)])).

%What a unifying scan does on the same cell, so the hazard this file removes
%is reproduced rather than described. memberchk/2 is the exact predicate the
%prune used to open with.
test(the_unifying_scan_still_raises_on_the_cell_the_identity_scan_reads) :-
    X #> 0,
    prune_outcome(memberchk('Empty', [X]), matched, Unifying),
    assertion(Unifying = err(error(type_error(integer, 'Empty'), _))),
    prune_outcome(spaces:metta_c_has_empty([X]), found, Identity),
    assertion(Identity == fail).

%A surviving cell must be the caller's own term. If PL_cons_list copied
%instead of linking, every == below would fail and a residual constraint would
%arrive at the printer detached from the variable the program asked about.
test(the_surviving_cells_are_the_callers_own_terms) :-
    X #> 0,
    Y = fresh(_),
    Input = [X, 'Empty', Y],
    spaces:metta_c_drop_empty(Input, Kept),
    Kept = [KeptX, KeptY],
    assertion(KeptX == X),
    assertion(KeptY == Y),
    Wrapped = ['$metta_answer'('Empty', a), '$metta_answer'(X, b)],
    spaces:metta_c_drop_empty_answer(Wrapped, KeptWrapped),
    KeptWrapped = [Cell],
    assertion(Cell == '$metta_answer'(X, b)),
    arg(1, Cell, Inner),
    assertion(Inner == X).

%THE REGRESSION THIS UNIT EXISTS FOR. A C scan the door never reached would
%agree on every case above, because the fallback answers identically. Cost is
%what distinguishes them: the scan is one foreign call whatever the length,
%while the walk retires one inference per cell. Asserting the two C readings
%are EQUAL rather than merely close is the O(1) claim stated exactly, and it
%is what fails the moment the door stops taking the C branch.
test(the_c_scan_is_constant_where_the_prolog_walk_is_linear) :-
    numlist(1, 1000, Short),
    numlist(1, 10000, Long),
    %A predicate's FIRST call in a process reads one inference higher than
    %every later one, so both arms are warmed before either is compared. That
    %alone made the first reading 7 against the 6 the same call answered five
    %more times, at both lengths
    %[measured 2026-09-05: [7,6,6,6,6,6] at n=1000 then [6,6,6,6,6,6] at
    %n=10000 in one process; commit=d6ae0469e495f47b8483b7d6f185ecd9d5472046].
    prune_cost(Short, _),
    without_c_scan(prune_cost(Short, _)),
    prune_cost(Short, CShort),
    prune_cost(Long, CLong),
    without_c_scan(prune_cost(Short, PShort)),
    without_c_scan(prune_cost(Long, PLong)),
    assertion(CShort =:= CLong),
    assertion(PLong - PShort >= 9000),
    assertion(CLong < PLong).

%The other shape with no end. PL_skip_list walks the spine with Brent's
%algorithm and '$skip_list'/3 is the same C, so both arms classify and refuse
%where the walk each of them wraps would spin. The culprit must be the
%caller's own list, which is what makes the error nameable.
test(a_cyclic_list_refuses_identically_through_both_arms) :-
    Cyclic = [a|Cyclic],
    prune_outcome(spaces:metta_prune_empty(Cyclic, _), unused, WithC),
    without_c_scan(prune_outcome(spaces:metta_prune_empty(Cyclic, _),
                                 unused, WithProlog)),
    prune_agree(cyclic_bare, WithC, WithProlog),
    assertion(WithC = err(error(type_error(list, _), _))),
    WithC = err(error(type_error(list, Culprit), _)),
    assertion(Culprit == Cyclic),
    CyclicAnswers = ['$metta_answer'(a, n)|CyclicAnswers],
    prune_outcome(spaces:metta_prune_empty_answers(CyclicAnswers, _),
                  unused, AnswersC),
    without_c_scan(
        prune_outcome(spaces:metta_prune_empty_answers(CyclicAnswers, _),
                      unused, AnswersProlog)),
    prune_agree(cyclic_answers, AnswersC, AnswersProlog),
    assertion(AnswersC = err(error(type_error(list, _), _))).

%The comparator must be able to say no, or every agreement above is vacuous.
%This plants a divergence and asserts the same predicate every case uses
%catches it, with the report silenced because the failure is the point.
test(a_planted_divergence_is_caught) :-
    setup_call_cleanup(nb_setval(empty_prune_c_quiet, true),
                       ( \+ prune_agree(planted, ok([a]), ok([a,b])),
                         \+ prune_agree(planted, ok([a]), fail),
                         \+ prune_agree(planted,
                                        err(error(instantiation_error, _)),
                                        err(error(type_error(list, x), _))),
                         prune_agree(planted, ok([a]), ok([a])) ),
                       nb_setval(empty_prune_c_quiet, false)).

:- end_tests(empty_prune_c_differential).
