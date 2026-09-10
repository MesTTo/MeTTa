% Purpose: pin what the engine answers a host that asks where a written form
%   leaves a variable unevaluated, read off the effect planner's table and the
%   declaration masks.
% Assumes: each case owns a fresh space and releases it.
% Guarantees:
%   - a special form's patterns and binders answer their paths and its
%     evaluated positions answer none, a match pattern and let*'s pair
%     patterns included [tested:
%     form_unevaluated_paths:let_answers_its_pattern_and_not_its_value_or_body,
%     form_unevaluated_paths:a_match_pattern_is_unevaluated_and_its_space_and_body_are_not,
%     form_unevaluated_paths:let_star_answers_each_pairs_pattern_and_not_its_values,
%     form_unevaluated_paths:a_variable_both_bound_by_the_pattern_and_evaluated_in_the_body_answers_its_pattern_occurrence,
%     form_unevaluated_paths:a_quoted_atom_is_unevaluated; commit=WORKTREE]
%   - a declared Atom parameter is unevaluated and a Number parameter is not,
%     and an undeclared head evaluates every position [tested:
%     form_unevaluated_paths:a_declared_atom_parameter_is_unevaluated,
%     form_unevaluated_paths:an_undeclared_head_evaluates_every_position;
%     commit=WORKTREE]
%   - a form whose head is not a symbol answers no paths [tested:
%     form_unevaluated_paths:a_non_symbol_head_answers_nothing; commit=WORKTREE]
% Owns resources: setup/cleanup releases each space; no file is written.
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(form_unevaluated_paths).

context(Space) :- 'new-space'(Space).

release_quietly(Space) :- catch(metta_release_space(Space), _, true).

run_in(Space, Source, Answers) :-
    setup_call_cleanup(asserta(filereader:silent(true), Ref),
                       process_metta_string(Source, Answers, Space),
                       erase(Ref)).

paths_in(Space, Text, Paths) :-
    sread(Text, Form),
    metta_form_unevaluated_variable_paths(Space, Form, Paths).

test(let_answers_its_pattern_and_not_its_value_or_body,
     [setup(context(S)), cleanup(release_quietly(S))]) :-
    paths_in(S, "(let (cons $h $t) (g $x) (f $h $t))", Paths),
    assertion(Paths == [[1,1],[1,2]]).

test(a_match_pattern_is_unevaluated_and_its_space_and_body_are_not,
     [setup(context(S)), cleanup(release_quietly(S))]) :-
    paths_in(S, "(match &self (parent $x $y) (child $y $z))", Paths),
    assertion(Paths == [[2,1],[2,2]]).

test(a_variable_both_bound_by_the_pattern_and_evaluated_in_the_body_answers_its_pattern_occurrence,
     [setup(context(S)), cleanup(release_quietly(S))]) :-
    paths_in(S, "(match &self (parent $p $k) $k)", Match),
    assertion(Match == [[2,1],[2,2]]),
    paths_in(S, "(let $x (g $x) (h $x))", Let),
    assertion(Let == [[1]]),
    paths_in(S, "(let* (($x 1) ($y $x)) (k $x $y))", LetStar),
    assertion(LetStar == [[1,0,0],[1,1,0]]).

test(let_star_answers_each_pairs_pattern_and_not_its_values,
     [setup(context(S)), cleanup(release_quietly(S))]) :-
    paths_in(S, "(let* (($a (g $q)) ((pair $b $c) (h $a))) (k $a $b $c))", Paths),
    assertion(Paths == [[1,0,0],[1,1,0,1],[1,1,0,2]]).

test(a_quoted_atom_is_unevaluated,
     [setup(context(S)), cleanup(release_quietly(S))]) :-
    paths_in(S, "(quote (f $x))", Paths),
    assertion(Paths == [[1,1]]).

test(a_declared_atom_parameter_is_unevaluated,
     [setup(context(S)), cleanup(release_quietly(S))]) :-
    run_in(S, "(: my-let (-> Atom Number Atom Number)) (= (my-let $p $v $b) $v)", _),
    paths_in(S, "(my-let $x 1 (+ $x $y))", Paths),
    assertion(Paths == [[1],[3,1],[3,2]]).

test(an_undeclared_head_evaluates_every_position,
     [setup(context(S)), cleanup(release_quietly(S))]) :-
    paths_in(S, "(nothing-known $x (f $y))", Paths),
    assertion(Paths == []).

test(a_non_symbol_head_answers_nothing,
     [setup(context(S)), cleanup(release_quietly(S))]) :-
    paths_in(S, "((f $x) $y)", Compound),
    assertion(Compound == []),
    paths_in(S, "($f $y)", Variable),
    assertion(Variable == []).

:- end_tests(form_unevaluated_paths).
