% Purpose: answer whether this SWI-Prolog still installs the undefined
%   supervisor on a predicate whose resolution an inference limit cut: a fresh
%   module's clause calls sum_list/2 before another goal, its first call is
%   bounded at a budget that lands inside the resolution, and the same clause
%   is called again unbounded. Prints `present` while some budget leaves that
%   second call raising existence_error and `absent` once every budget leaves
%   it callable.
% Assumes:
%   - run as `swipl -q -f none -s FILE -g main -t halt` by the host-workarounds
%     lane, which reads the last line printed
%   - the `autoload` flag is true and library(lists) is in the library index,
%     which is how a fresh module resolves sum_list/2 at all
%   - the call to sum_list/2 is not the last call of its clause: a last call,
%     a meta-call, an explicit import and a defining assert all resolve the
%     predicate again, and only a compiled call that is not the last runs the
%     installed supervisor
% Guarantees:
%   - `present` iff some budget in 1..64 leaves the predicate undefined after
%     the cut [measured 2026-09-11: every budget from 1 to 64 does;
%     command=sh tools/check.sh host-workarounds; fixture=SWI-Prolog 10.1.13;
%     commit=23ed2559a7c9b5712e1f6f4710ed02f8d5c6a23d]
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

main :-
    (   between(1, 64, Budget),
        poisons(Budget)
    ->  Verdict = present
    ;   Verdict = absent
    ),
    format("~w~n", [Verdict]).

% One fresh module per budget, because a resolution that completed once has
% nothing left to cut. The bounded call is the module's first call to
% sum_list/2, so the limit lands inside the resolution; the unbounded call
% after it is the question.
poisons(Budget) :-
    format(atom(Module), 'autoload_cut_~w', [Budget]),
    Module:assertz((go(List, Sum) :- sum_list(List, Sum0), Sum is Sum0 + 0)),
    catch(call_with_inference_limit(Module:go([1, 2], _), Budget, _), _, true),
    catch(( Module:go([1, 2], Sum), Sum == 3, Outcome = callable ),
          error(existence_error(procedure, _), _),
          Outcome = undefined),
    Outcome == undefined.
