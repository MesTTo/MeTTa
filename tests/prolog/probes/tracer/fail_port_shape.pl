% Purpose: which control construct gives a trace wrapper the `fail` port it
%   wants. SWI's own port wrapper (library(prolog_trace), wrapper/4) reports
%   the BYRD box with call_cleanup/2 and a local cut, so `fail` fires on
%   EXHAUSTION after however many exits; a tracer recording a reduction's
%   OUTCOME wants the else branch only when the goal answered nothing, which
%   is the soft cut. This prints, for each shape, whether a deterministic
%   success stays deterministic, whether failure reaches the port, whether a
%   nondeterministic goal keeps every answer, and whether an exception passes
%   through without reaching the port.
% Run: cd <worktree> && swipl -q tests/prolog/probes/tracer/fail_port_shape.pl
% Measured 2026-09-07: both shapes leave deterministic(true) after a
%   deterministic goal and rethrow without entering the else branch; the soft
%   cut fires its port only on the no-answer case, which is why
%   engine/tracer.pl's metta_trace_ports/4 uses it.
:- initialization(main, main).

soft(G) :- ( call(G) *-> true ; format("SOFT PORT~n"), fail ).

byrd(G) :-
    call((   call_cleanup(call(G), Det = true),
             (   Det == true
             ->  !
             ;   true
             )
         ;   format("BYRD PORT~n"),
             fail
         )).

det_of(G, D) :- call(G), deterministic(D).

main :-
    det_of(soft(true), D1), format("softcut det success  det=~w~n", [D1]),
    det_of(byrd(true), D2), format("byrd    det success  det=~w~n", [D2]),
    ( soft(fail) -> true ; format("softcut failure reached its port~n") ),
    ( byrd(fail) -> true ; format("byrd    failure reached its port~n") ),
    findall(X, soft(member(X, [a, b])), Xs),
    format("softcut nondet answers ~w~n", [Xs]),
    findall(Y, byrd(member(Y, [a, b])), Ys),
    format("byrd    nondet answers ~w (its port fires on exhaustion)~n", [Ys]),
    ( catch(soft(throw(boom)), B1, format("softcut rethrows ~w~n", [B1])) -> true ; true ),
    ( catch(byrd(throw(boom)), B2, format("byrd    rethrows ~w~n", [B2])) -> true ; true ).
