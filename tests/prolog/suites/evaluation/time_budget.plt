% Purpose: the wall-clock rule every bounded door here holds -- a bound that
%   was exceeded REFUSES, and never answers.
% Assumes: engine/metta.pl is loaded, so run_under_pragmas/1, metta_timeout/3
%   and metta_host_time_budget/3 are reachable, and library(time) is present.
% Guarantees:
%   - a door whose alarm never arrived still refuses, because the deadline is
%     checked where the answer is produced [tested:
%     time_budget:a_pragma_bound_the_alarm_missed_still_refuses,
%     time_budget:the_language_timeout_form_refuses_a_bound_it_exceeded;
%     commit=WORKTREE].
%   - a bound that was NOT exceeded still answers, so the rule refuses a
%     deadline rather than refusing work [tested:
%     time_budget:a_bound_that_was_not_exceeded_answers; commit=WORKTREE].
% Fails when: read as coverage of the ALARM. call_with_time_limit/2 is what
%   stops the work; this file covers what decides the outcome once the work
%   has stopped or finished.
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(time_budget).

%THE CONTROL, and the reason the rest of this file exists. sig_atomic/1 blocks
%signal delivery, so the alarm call_with_time_limit/2 installed is removed
%before it can be delivered and the caller reads an ANSWER for work that ran
%six times its bound. This is the shape a loaded box produced by itself: a
%0.3-second load answered [[(Error (spin) StackOverflow)]] after 66.170 seconds
%at loadavg 90 to 100
%[source: docs/journal/2026-09-07-every-intermittent-root-caused.md].
test(the_alarm_alone_answers_a_bound_it_lost) :-
    get_time(Start),
    catch(call_with_time_limit(0.05, sig_atomic(sleep(0.3))), Ball, true),
    get_time(End),
    Elapsed is End - Start,
    assertion(var(Ball)),
    assertion(Elapsed > 0.2).

test(a_pragma_bound_the_alarm_missed_still_refuses) :-
    setup_call_cleanup(
        'pragma!'('max-time', 0.05, _),
        catch(run_under_pragmas(sig_atomic(sleep(0.3))), Ball, true),
        'pragma!'('max-time', none, _)),
    assertion(nonvar(Ball)),
    assertion(Ball = error(metta_control_signal(time_limit, 0.05), _)).

%The form's own findall gives the blocked alarm a safe point to land on after
%the goal returns, so here the alarm is what stops it and the deadline check
%is the backstop underneath. Either spelling is a time-limit refusal: the raw
%ball is one of the engine's declared control exceptions and every seat
%classifies it as `time_limit`
%[source: engine/metta/registration.pl, metta_host_control_signal_info/3].
test(the_language_timeout_form_refuses_a_bound_it_exceeded) :-
    catch(metta_timeout(0.05, sig_atomic(sleep(0.3)), _Value), Ball, true),
    assertion(nonvar(Ball)),
    assertion(( Ball == time_limit_exceeded
              ; Ball = error(metta_control_signal(time_limit, _), _) )).

%The rule refuses a DEADLINE, not work: a form inside its bound answers, and
%answers every solution, which is timeout's own contract.
test(a_bound_that_was_not_exceeded_answers) :-
    findall(V, metta_timeout(30, member(V, [a, b, c]), V), Values),
    assertion(Values == [a, b, c]).

test(a_pragma_bound_that_was_not_exceeded_answers) :-
    setup_call_cleanup(
        'pragma!'('max-time', 30, _),
        catch(run_under_pragmas(true), Ball, true),
        'pragma!'('max-time', none, _)),
    assertion(var(Ball)).

:- end_tests(time_budget).
