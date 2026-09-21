% Purpose: assert that a library goal refuses, pinning the term it throws
%     rather than only that something was thrown.
% Assumes:
%     - the goal is a Prolog call into a shipped library. The MeTTa-layer form
%       is collection_test_support:refused/1, which asks the weaker question of
%       whether evaluation reported any error at all.
%     - every suite runs in its own swipl process, so this module replaces
%       twenty identical top-level definitions that never collided
%       [source: engine/check.sh:366 loops `for suite in suites/*/*.plt`
%        and runs one swipl per suite; commit=WORKTREE]
% Guarantees:
%     - must_throw/2 fails its test when the goal succeeds, when it fails
%       without throwing, and when the thrown term does not unify with the
%       expectation [tested: library_refusals.plt:the_assertion_sees_a_planted
%       _success, _a_planted_failure and _a_planted_mismatch; commit=WORKTREE]
%     - the goal is called in its CALLER's module, so a suite naming a library
%       predicate unqualified reaches the same predicate it reached when the
%       definition was local to the suite [source: meta_predicate 0 below]
% Fails when: the goal leaves the catcher's reach, halt/1 being the shape, in
%     which case the process exits and no assertion runs.

:- module(library_assertions, [must_throw/2, throws_matching/2]).
:- use_module(library(debug), [assertion/1]).

%A plain module predicate would call Goal in THIS module and every library
%head would be undefined. The 0 qualifies it with the caller's module, which
%is what the twenty local copies got for free by living in `user`.
:- meta_predicate must_throw(0, ?), throws_matching(0, ?).

% The decision, carrying no reporting: true when Goal throws a term unifying
% with Expected. Split out because assertion/1 cannot be planted from inside a
% plunit test: plunit hooks a failed assertion to MARK the test failed and
% carry on, so it neither throws nor fails and `\+ catch(must_throw(...))`
% reports the plant as a real failure
% [measured 2026-09-21: the three plants below each failed that way first].
% Unification, not subsumption: a caller writes the expectation with variables
% where it does not care, and binding them is how the twenty copies read.
throws_matching(Goal, Expected) :-
    catch(Goal, Error, true),
    nonvar(Error),
    Error = Expected.

must_throw(Goal, Expected) :-
    assertion(throws_matching(Goal, Expected)).
