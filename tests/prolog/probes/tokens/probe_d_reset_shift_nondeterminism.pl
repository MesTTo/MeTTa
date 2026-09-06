% Purpose: probe (d) for the handlers design: the exact shapes in which
%   reset/3 and shift/1 work under nondeterminism on SWI-Prolog 10.1.13:
%   d1 a resumed continuation that later fails backtracks INTO the goal before
%      the shift, which shifts again (reset/3 is re-entered per alternative);
%   d2 a shift from inside findall/3;
%   d3 calling one continuation twice (re-activation, variable sharing);
%   d4 a cut inside a saved continuation (the manual's t1);
%   d5 choice points created by the continuation itself live normally;
%   d6 two composed handlers (state + emit) over a nondeterministic body;
%   d7 shift through catch/3, setup_call_cleanup/3, \+ and -> called at once;
%   d8 cost of reset/shift/call and of copy_term on a continuation;
%   d9 a continuation captured in one engine and called inside another engine;
%   d10 the tabling shape: capture in a failure-driven loop, resume later once
%       per answer through a fresh reset.
% Run: cd <worktree> && timeout -s KILL 120 swipl -q -g main -t halt ai-tmp/probes/probe_d_reset_shift_nondeterminism.pl
:- dynamic cont/1.

show(Label, Goal) :-
    (   catch(Goal, E, (format("~w: EXCEPTION ~q~n", [Label, E]), fail))
    ->  true
    ;   format("~w: (failed)~n", [Label])
    ).

% d1
g1(X) :- member(X, [1,2,3]), shift(got(X)), X > 1.
run1(Goal, Out) :-
    reset(Goal, Ball, Cont),
    (   Cont == 0
    ->  Out = done
    ;   Ball = got(X),
        format("   handler saw got(~w), resuming~n", [X]),
        call(Cont),
        Out = X
    ).

% d3
g3(X) :- shift(ask), X is random(1000000).

% d4 (manual's t1)
t1(R) :- reset(gbad, ball, Cont), ( Cont == 0 -> R = completed_without_shift ; format("   t1: resuming a continuation holding `!, fail`~n"), call(Cont), R = resumed_and_succeeded ).
gbad :- n, !, fail.
gbad.
n :- shift(ball), format("   n: after the shift~n").
gok :- \+ n.
gassert :- ( n -> fail ; true ).

% d6: two handlers composed by propagation; the body is nondeterministic
get(S) :- shift(get(S)).
put(S) :- shift(put(S)).
emit(E) :- shift(emit(E)).
run_state(Goal, Sin, Sout) :-
    reset(Goal, Cmd, Cont),
    (   Cont == 0 -> Sout = Sin
    ;   Cmd = get(S) -> S = Sin, run_state(Cont, Sin, Sout)
    ;   Cmd = put(S) -> run_state(Cont, S, Sout)
    ;   shift(Cmd), run_state(Cont, Sin, Sout)      % propagate an unknown effect outward
    ).
run_emit(Goal, Es) :-
    reset(Goal, Cmd, Cont),
    (   Cont == 0 -> Es = []
    ;   Cmd = emit(E) -> Es = [E|Es1], run_emit(Cont, Es1)
    ;   shift(Cmd), run_emit(Cont, Es)
    ).
body6(X) :- member(X, [a, b, c]), get(S), S1 is S + 1, put(S1), emit(X).

% d10: the tabling shape
:- dynamic saved/1, answer/1.
worker10(X) :- member(X, [1,2,3]), shift(need(X)).
capture10 :-
    retractall(saved(_)), retractall(answer(_)),
    (   reset(worker10(X), need(X), Cont),
        ( Cont == 0 -> assertz(answer(done(X))) ; copy_term(X-Cont, Saved), assertz(saved(Saved)) ),
        fail
    ;   true
    ).
resume10 :-
    forall(saved(X-Cont),
           (   reset(Cont, Ball, Cont2),
               ( Cont2 == 0 -> assertz(answer(resumed(X))) ; assertz(answer(shifted_again(Ball))) )
           )).

main :-
    % d1
    show("d1 findall over a handler whose resumed continuation fails and backtracks into the pre-shift goal",
         ( findall(O, run1(g1(_), O), Os), format("d1: outs = ~q (expected [2,3]: reset/3 re-entered per member alternative)~n", [Os]) )),
    show("d1b reset/3 itself is re-entered on backtracking: count solutions of reset(member+shift)",
         ( findall(B, reset((member(X, [1,2,3]), shift(s(X))), B, _), Bs), format("d1b: balls = ~q~n", [Bs]) )),
    % d2
    show("d2 shift from inside findall/3",
         ( reset(findall(X, (member(X, [1,2]), shift(inner(X))), L), Ball2, Cont2),
           format("d2: ball=~q cont_is_zero=~w L=~q~n", [Ball2, Cont2 == 0, L]),
           ( Cont2 \== 0 -> ( call(Cont2) -> format("d2: continuation resumed and completed, L=~q~n", [L]) ; format("d2: continuation resumed and FAILED~n") ) ; true ) )),
    show("d2b findall around the handler (the shape the engine's findall-then-member doors use)",
         ( findall(X, ( reset(g1(X), got(X), C), ( C == 0 -> true ; call(C) ) ), Xs2), format("d2b: ~q~n", [Xs2]) )),
    % d3
    show("d3 calling one continuation twice",
         ( reset(g3(V), ask, C3),
           call(C3), format("d3: first call bound V=~w~n", [V]),
           ( call(C3) -> format("d3: second call succeeded, V=~w (variable shared: unification, not re-evaluation)~n", [V])
           ; format("d3: second call FAILED (V already bound; `is` compared a new draw against it)~n") ) )),
    show("d3b calling a COPY of the continuation twice",
         ( reset(g3(W), ask, C3b), copy_term(W-C3b, W1-K1), copy_term(W-C3b, W2-K2),
           call(K1), call(K2), format("d3b: copies bound W1=~w W2=~w (fresh variables per copy)~n", [W1, W2]) )),
    % d4
    show("d4 cut inside a resumed continuation (manual t1)", ( t1(R4), format("d4: first answer ~w (the resumed `!, fail` failed without pruning gbad's second clause, which then answered)~n", [R4]) )),
    show("d4b the same cut, continuation called IMMEDIATELY inside the handler, solutions counted",
         ( findall(x, t1(_), L4), length(L4, N4), format("d4b: t1 has ~w solutions~n", [N4]) )),
    % d5
    show("d5 choice points created by the continuation live normally",
         ( G5 = (shift(a), member(Y5, [1,2,3])), reset(G5, a, C5), findall(Y5, call(C5), Ys5), format("d5: ~q~n", [Ys5]) )),
    % d6
    show("d6 composed handlers over a nondeterministic body, all answers",
         ( findall(X6-S6-Es6, run_emit(run_state(body6(X6), 0, S6), Es6), R6), format("d6: ~q~n", [R6]) )),
    % d7
    show("d7a shift through catch/3", ( reset(catch((shift(a), true), _, true), a, C7a), (C7a == 0 -> format("d7a: no shift seen~n") ; call(C7a), format("d7a: ok, resumed through catch/3~n")) )),
    show("d7b shift through setup_call_cleanup/3", ( reset(setup_call_cleanup(true, (shift(a), true), true), a, C7b), (C7b == 0 -> format("d7b: no shift seen~n") ; call(C7b), format("d7b: ok, resumed through setup_call_cleanup/3~n")) )),
    show("d7c shift inside \\+ resumed at once keeps \\+ semantics (manual t2)",
         ( ( reset(gok, ball, C7c) -> ( C7c == 0 -> R7c = no_shift ; ( call(C7c) -> R7c = succeeded ; R7c = failed ) ) ; R7c = reset_failed ), format("d7c: ~w (expected failed: \\+ keeps its semantics when resumed at once)~n", [R7c]) )),
    show("d7d shift inside if-then-else resumed LATER loses the commit (manual t3)",
         ( retractall(cont(_)), findall(x, ( reset(gassert, ball, C7d), ( C7d == 0 -> true ; assertz(cont(C7d)) ) ), L7dt), length(L7dt, N7dt),
           findall(x, ( cont(K), call(K) ), L7d), length(L7d, N7d), format("d7d: t3-shaped goal solutions = ~w (manual: 2); later call of the saved continuation solutions = ~w (manual: 0)~n", [N7dt, N7d]) )),
    % d8
    statistics(inferences, I0), statistics(cputime, T0),
    forall(between(1, 100000, _), ( reset(shift(x), x, K8), call(K8) )),
    statistics(inferences, I1), statistics(cputime, T1),
    D8 is I1 - I0, C8 is T1 - T0,
    format("d8: 100000 x (reset + shift + call cont) = ~D inferences, ~3f s cpu~n", [D8, C8]),
    statistics(inferences, J0), statistics(cputime, U0),
    forall(between(1, 100000, _), true),
    statistics(inferences, J1), statistics(cputime, U1),
    D8b is J1 - J0, C8b is U1 - U0,
    format("d8: 100000 x (plain true) loop floor = ~D inferences, ~3f s cpu~n", [D8b, C8b]),
    show("d8c copy_term cost of a small continuation",
         ( reset((shift(y), member(_, [1,2,3]), length(_, 5)), y, K8c),
           statistics(inferences, M0), statistics(cputime, WA),
           forall(between(1, 100000, _), copy_term(K8c, _)),
           statistics(inferences, M1), statistics(cputime, WB),
           D8c is M1 - M0, C8c is WB - WA,
           format("d8: 100000 x copy_term of a small continuation = ~D inferences, ~3f s cpu~n", [D8c, C8c]) )),
    % d9
    show("d9 a continuation captured here, called inside a fresh engine",
         ( G9 = (shift(a), member(Z9, [1,2,3])), reset(G9, a, C9),
           engine_create(Z9, call(C9), E9), findall(Z, engine_next_reified_loop(E9, Z), Zs9), engine_destroy(E9),
           format("d9: engine answers ~q~n", [Zs9]) )),
    % d10
    show("d10 the tabling shape: capture in a failure-driven loop, resume each saved continuation once",
         ( capture10, findall(S, saved(S), Saved), length(Saved, NS), resume10, findall(A, answer(A), As),
           format("d10: saved ~w continuations; answers ~q~n", [NS, As]) )),
    halt(0).

engine_next_reified_loop(E, Z) :-
    engine_next_reified(E, T),
    (   T = the(Z)
    ;   T == no, !, fail
    ;   T = throw(Err), throw(Err)
    ;   engine_next_reified_loop(E, Z)
    ).
