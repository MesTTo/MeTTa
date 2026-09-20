% Purpose: answer whether this SWI-Prolog still leaves a findall bag on the
%   thread's bag stack when an inference limit trips between the bag's push
%   and its cleanup's registration: a findall over two hundred budgets each
%   bounds a goal that runs a nested findall, and collects fewer than two
%   hundred answers once one budget has landed on that port. Prints `present`
%   while the enclosing findall is short and `absent` once it collects every
%   answer.
% Assumes:
%   - run as `swipl -q -f none -s FILE -g main -t halt` by the host-workarounds
%     lane, which reads the last line printed
%   - the nested findall's goal costs enough inferences that some budget in
%     1..200 lands on the push's registration port; thirty answers of three
%     inferences each do
% Guarantees:
%   - `present` iff the enclosing findall collects fewer than 200 answers
%     [measured 2026-09-11: 13 of 200 are collected, while a thrown ball
%     through the same nesting collects 200 and a depth limit collects 200;
%     command=sh tools/check.sh host-workarounds; fixture=SWI-Prolog 10.1.13;
%     commit=23ed2559a7c9b5712e1f6f4710ed02f8d5c6a23d]
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

main :-
    findall(Budget,
            ( between(1, 200, Budget),
              call_with_inference_limit(nested, Budget, _) ),
            Collected),
    length(Collected, Count),
    (   Count < 200
    ->  Verdict = present
    ;   Verdict = absent
    ),
    format("~w~n", [Verdict]).

nested :-
    findall(X, ( between(1, 30, X), spin(3) ), _).

spin(0) :- !.
spin(N) :-
    N1 is N - 1,
    spin(N1).
