% Purpose: a MeTTa function value handed to a Prolog meta-predicate is applied
%   the way the meta-predicate asks, whatever the value captured, through a
%   compiled call, a head known only at run time, reduce/3 and a restricted
%   space alike: partial/3 to partial/11 in engine/metta/control.pl are the
%   apply of the closure value partial(F, Bound), and the effect walk follows
%   F through one.

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(closure_values).

% The probe that found it: the lambda captures $k, so it evaluates to
% partial(lambda_<hex>, [K]), and maplist/3 applies that with two more
% arguments. It raised `apply:maplist/3: Unknown procedure: partial/4`.
test(a_lambda_capturing_a_variable_is_a_maplist_closure) :-
    process_metta_string("!(let $k 1 (maplist (|-> ($a) (+ $k $a)) (1 2 3)))",
                         Answers),
    assertion(Answers == [[2, 3, 4]]).

% A non-text blob in a lambda body is lifted into the closure, so a lambda
% holding one is a partial value even with nothing captured; this is the shape
% a C function value takes in CMeTTa-Examples' 05-lambda twin. A stream is the
% blob here because it needs no seat.
test(a_lambda_holding_a_blob_is_a_maplist_closure) :-
    current_output(Stream),
    findall(Closure, eval(['|->', [A], [pair, A, Stream]], Closure), [Closure]),
    assertion(Closure = partial(_, [Stream])),
    findall(Out, eval([maplist, ['|->', [B], [pair, B, Stream]], [1, 2]], Out),
            Answers),
    assertion(Answers == [[[pair, 1, Stream], [pair, 2, Stream]]]).

% foldl/4 appends three arguments: the element and the two accumulators.
test(a_lambda_capturing_a_variable_is_a_foldl_closure) :-
    process_metta_string(
        "!(let $k 10 (foldl (|-> ($x $acc) (+ $k (+ $x $acc))) (1 2 3) 0))",
        Answers),
    assertion(Answers == [36]).

% A head known only at run time is translated there rather than when the
% source compiles, and the value reaches maplist/3 the same way.
test(a_closure_reaches_maplist_through_a_computed_head) :-
    process_metta_string(
        "!(let $m maplist (let $k 1 ($m (|-> ($a) (+ $k $a)) (1 2 3))))",
        Answers),
    assertion(Answers == [[2, 3, 4]]).

% reduce/3 calls a builtin with the values it was handed, through its own
% door rather than a compiled call.
test(a_closure_reaches_maplist_through_reduce) :-
    process_metta_string(
        "!(let $k 1 (reduce (maplist (|-> ($a) (+ $k $a)) (1 2 3))))",
        Answers),
    assertion(Answers == [[2, 3, 4]]).

% A restricted space's module does not inherit the engine's; its core is
% given what the engine module defines, these clauses among them.
test(a_restricted_space_applies_a_capturing_lambda) :-
    process_metta_string(
        "!(new-space &plunit-cv-locked (restricted))
         !(add-atom &plunit-cv-locked
             (= (bump-all $k $xs) (maplist (|-> ($a) (+ $k $a)) $xs)))
         !(evalc (bump-all 1 (1 2 3)) &plunit-cv-locked)",
        Answers),
    assertion(last(Answers, [2, 3, 4])).

% A partial application of a named function is the same value and goes the
% same way.
test(a_partial_application_is_a_maplist_closure,
     [ setup(process_metta_string("(= (plunit-cv-add $a $b) (+ $a $b))", _)) ]) :-
    process_metta_string("!(maplist (plunit-cv-add 10) (1 2 3))", Answers),
    assertion(Answers == [[11, 12, 13]]).

% Every count of appended arguments a meta_predicate declaration can ask for,
% 1 to 9, reaches F with Bound first and then the appended arguments in order,
% in the module the closure was called from; 0 is a goal, and nothing answers
% for it or for 10. The call goes through &self's module, which reaches the
% engine's clauses the way every space's module does.
test(every_appended_argument_count_reaches_the_function) :-
    metta_self_module(Self),
    forall(between(1, 9, Count),
           (   numlist(1, Count, Appended),
               Arity is Count + 1,
               functor(Head, plunit_cv_record, Arity),
               Head =.. [_|Received],
               setup_call_cleanup(
                   assertz(Self:(Head :- nb_setval(plunit_cv_seen, Received))),
                   ( Goal =.. [call, Self:partial(plunit_cv_record, [bound])|Appended],
                     call(Goal),
                     nb_getval(plunit_cv_seen, Seen) ),
                   abolish(Self:plunit_cv_record/Arity)),
               assertion(Seen == [bound|Appended])
           )),
    metta_engine_module(Engine),
    assertion(\+ current_predicate(Engine:partial/2)),
    assertion(\+ current_predicate(Engine:partial/12)).

% The effect walk reads the closure as the function it names, so it reaches
% the lambda's own body rather than classifying partial/4.
test(the_effect_walk_follows_the_function_a_partial_value_names) :-
    metta_effect_construct(maplist(partial(plunit_cv_lambda, [k]), [1], _),
                           Goals),
    assertion(Goals = [plunit_cv_lambda(k, _, _)]).

:- end_tests(closure_values).
