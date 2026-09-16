% Purpose: answer whether this SWI-Prolog still has the cleanup-registration
%   window: one call port between setup_call_cleanup/3's Setup returning and
%   its cleanup being registered, at which an inference limit unwinds with
%   Setup's effects in place and no cleanup owed. Prints `present` while the
%   host has the window and `absent` once it does not.
% Assumes:
%   - run as `swipl -q -f none -s FILE -g main -t halt` by the host-workarounds
%     lane, which reads the last line printed
% Guarantees:
%   - `present` iff some budget in 1..64 leaves the asserted guard behind
%     [measured 2026-09-10: budget 4 leaks and every other budget is clean;
%     command=sh check.sh host-workarounds; fixture=SWI-Prolog 10.1.13;
%     commit=2bd6b250a22d9898ced449595c168a8dc3a78768]
%     [measured 2026-09-17: present on SWI-Prolog 10.1.14 as shipped, absent on
%     10.1.14 built with tests/checks/host_workarounds/swi-cleanup-window.patch;
%     command=sh check.sh host-workarounds;
%     fixture=SWI-Prolog 10.1.14 with swi-cleanup-window.patch; commit=ca783ee2ae42f40bdc3cff1ce17590df02ccbd60]
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- dynamic guard/0.

main :-
    (   between(1, 64, Budget),
        leaks(Budget)
    ->  Verdict = present
    ;   Verdict = absent
    ),
    format("~w~n", [Verdict]).

% A budget that trips at the call port after Setup returns leaves `guard`
% asserted: the cleanup that would erase it was never registered.
leaks(Budget) :-
    retractall(guard),
    call_with_inference_limit(
        setup_call_cleanup(asserta(guard, Ref), true, erase(Ref)),
        Budget, _),
    guard.
