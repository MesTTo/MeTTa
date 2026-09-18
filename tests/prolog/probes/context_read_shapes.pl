% Purpose: the inferences one read of a context costs per shape, above an
%   empty loop, in the three states a reader meets: key unset, inactive []
%   and one element. Bare SWI, no engine: the shapes are what
%   engine/ext_points.pl's context_reader/4 chooses between, and a dynamic
%   fact is the guard they replaced.
% Assumes: run as `swipl tests/prolog/probes/context_read_shapes.pl`.
% Guarantees: one line per shape with the three per-read costs, the
%   negative read (\+) for unset and inactive and the positive first read
%   for one element; the counts are exact, so two runs agree to the digit.
:- initialization(main, main).
:- dynamic f/1.

wrap_stack(X) :- nb_current(k, L), member(X, L).
wrap_flag :- nb_current(kf, true).
head_read(X) :- nb_current(k, [X0|More]), ( More == [] -> X = X0 ; ( X = X0 ; member(X, More) ) ).

shape('dynamic fact', \+ f(_), f(_)).
shape('nb_current flag, inline', \+ nb_current(kf, true), nb_current(kf, true)).
shape('flag wrapper predicate', \+ wrap_flag, wrap_flag).
shape('stack wrapper predicate, nb_current then member', \+ wrap_stack(_), wrap_stack(_)).
shape('stack, inline nb_current then member', \+ ( nb_current(k, L), member(_, L) ), ( nb_current(k, L), member(_, L) )).
shape('stack, inline head pattern (context_reader stack)',
      \+ ( nb_current(k, [X0|More]), ( More == [] -> _ = X0 ; ( _ = X0 ; member(_, More) ) ) ),
      ( nb_current(k, [X1|More1]), ( More1 == [] -> _ = X1 ; ( _ = X1 ; member(_, More1) ) ) )).
shape('stack, head pattern wrapper predicate', \+ head_read(_), head_read(_)).

:- dynamic runner/1.
runner_for(Goal, Head) :-
    gensym(run_, Name), Head =.. [Name],
    assertz((Head :- ( between(1, 10000, _), Goal, fail ; true ))).

cost(Head, Cost) :-
    call(Head), call(Head),
    statistics(inferences, I0), call(Head), statistics(inferences, I1),
    Cost is I1 - I0.

per(Goal, Base, Per) :- runner_for(Goal, Head), cost(Head, C), Per is (C - Base) / 10000.

state(unset) :- nb_delete(k), nb_delete(kf), retractall(f(_)).
state(inactive) :- nb_setval(k, []), nb_setval(kf, []), retractall(f(_)).
state(one) :- nb_setval(k, [a]), nb_setval(kf, true), retractall(f(_)), assertz(f(a)).

main(_) :-
    runner_for(true, BaseHead), cost(BaseHead, Base),
    format("~w~t~56|~w~t~66|~w~t~76|~w~n", [shape, unset, inactive, one]),
    forall(shape(Name, Negative, Positive),
           ( state(unset), per(Negative, Base, U),
             state(inactive), per(Negative, Base, I),
             state(one), per(Positive, Base, O),
             format("~w~t~56|~3f~t~66|~3f~t~76|~3f~n", [Name, U, I, O]) )).
