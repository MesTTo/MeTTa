% Purpose: compare the compiled source envelope with the original goal executor.
% Guarantees: ordered answers, variable sharing, source effects and error
%   locations agree with direct execution of translate_runnable_expr/4's goals
%   [tested: source_runnable_envelope; commit=e246959279271d22f166a1c8fb1840896295a020].
% Owns resources: cases release their spaces and oracle wrapper, and restore
%   the loader output and host backtrace settings.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').
:- use_module(library(prolog_wrap)).
:- use_module('../../source_observation_helper.pl').

:- begin_tests(source_runnable_envelope).
:- metta_ensure_source_observation.

kernel([+, 1, 2], []).
kernel([superpose, [1, 1, 2]], []).
kernel([superpose, ['Empty', 7]], []).
kernel([empty], []).
kernel('Empty', []).
kernel([], []).
kernel([unknown, X, X], ['x'-X]).
kernel([/, 1, 0], []).
kernel([let, X, [+, 1, 2], [*, X, 3]], ['x'-X]).
kernel([collapse, [superpose, [X, X, Y]]], ['x'-X, 'y'-Y]).

test(translated_answers_and_sharing_agree,
     [forall(kernel(Term, Names))]) :-
    metta_self_module(Module),
    with_metta_module(Module,
        translator:translate_runnable_expr(Term, Names, Goals, Result)),
    copy_term(Goals-Result, Original-Expected),
    metta_engine:call_goals_in(Module, Original),
    copy_term(Goals-Result, Compiled-Actual),
    metta_engine:call_goals_in(Module,
        [filereader:run_source_runnable(Module, Compiled)]),
    assertion(Actual =@= Expected).

source("!(late 1) (= (late $x) (+ $x 2)) !(late 1)\n\c
        !(println! before) !(add-atom &self (held 7))\n\c
        !(match &self (held $x) $x) !(println! after)\n\c
        !(remove-atom &self (held 7)) !(match &self (held $x) $x)").
source("(= (divide $x) (+ 1 (/ 1 $x)))\n\c
        (= (caller $x) (+ 2 (divide $x)))\n!(caller 0)").
source("(= (collect $x) (collapse (+ 1 (/ 1 $x))))\n!(collect 0)").
source("!(superpose (1 1 2)) !(empty) !Empty !() !(unknown $x $x)").
source("!(+ 1 2) (= (check $x) (assertEqual $x 3)) !(check 0) !(println! unreachable)").

test(source_prefix_effects_answers_and_error_frames_agree,
     [forall(source(Source))]) :-
    % The oracle invokes the cut's executor inside the same outer observation
    % boundary. It consumes the original translated term, not this executor's
    % extracted pieces, and therefore detects a lost boundary or reordered goal.
    setup_call_cleanup(
        wrap_predicate(filereader:run_source_runnable(Module, Goals), envelope_oracle, _,
                       metta_engine:call_goals_in_(Module, Goals)),
        source_run_observation("envelope.metta", Source, Expected, ExpectedOutput),
        unwrap_predicate(filereader:run_source_runnable/2, envelope_oracle)),
    source_run_observation("envelope.metta", Source, Actual, ActualOutput),
    assertion(Actual =@= Expected),
    assertion(ActualOutput == ExpectedOutput).

:- end_tests(source_runnable_envelope).
