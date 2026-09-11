% Purpose: an inference limit that cuts the host's own machinery leaves the
%   process consistent: a first-use resolution it cut still resolves, a
%   nested findall it cut does not shorten the enclosing findall, and the
%   bounded call reports the bound's own ball in both cases. These are the
%   two host workarounds of engine/metta/limits.pl, tested from the calls
%   that reach them.
% Assumes:
%   - the engine's wrappers are installed by loading engine/metta.pl, which is
%     why the suite boots the engine rather than SWI alone: on the bare host
%     every test here fails, which is what the two reproductions under
%     tests/checks/host_workarounds/ measure
%   - fresh modules are built with assertz rather than files, because a
%     module's first compiled call is what traps, and a clause asserted into a
%     module compiles the same call site a loaded file would
% Guarantees:
%   - every budget of a 200-budget sweep leaves the predicate callable from
%     the compiled call site that trapped, and reports the limit or a
%     completed goal, never an existence error
%     [tested: a_bound_landing_anywhere_inside_a_first_use_resolution_leaves_the_predicate_callable]
%   - a findall enclosing a bounded nested findall, a bounded findnsols, or the
%     engine's own inference-budget door collects every answer
%     [tested: a_bound_landing_inside_a_nested_findall_keeps_the_enclosing_answers]
%   - a predicate nothing defines still refuses with an existence error under
%     a bound and after it [tested: an_undefined_predicate_under_a_bound_still_refuses]
%   - the wrapped collectors answer exactly as the host's own, including a
%     findnsols cut by its caller [tested: the_wrapped_collectors_answer_as_the_host_does]
% Open Obligations:
%   To Do: None
%   Hacks: None
%   Future Enhancements: None

:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- begin_tests(limits).

limits_spin(0) :- !.
limits_spin(N) :-
    N1 is N - 1,
    limits_spin(N1).

nested_findall_work :-
    findall(X, ( between(1, 30, X), limits_spin(3) ), _).

%One fresh module per budget, because a resolution that completed once has
%nothing left to cut, and the call to sum_list/2 is not the clause's last
%call, because a last call resolves again on its own (limits.pl says why).
test(a_bound_landing_anywhere_inside_a_first_use_resolution_leaves_the_predicate_callable) :-
    forall(between(1, 200, Budget),
           ( format(atom(Module), 'limits_resolution_~w', [Budget]),
             Module:assertz((go(List, Sum) :- sum_list(List, Sum0), Sum is Sum0 + 0)),
             \+ current_predicate(Module:sum_list/2),
             call_with_inference_limit(Module:go([1, 2], _), Budget, Result),
             assertion(memberchk(Result, [inference_limit_exceeded, !, true])),
             Module:go([1, 2], Sum),
             assertion(Sum == 3) )).

test(a_bound_landing_inside_a_nested_findall_keeps_the_enclosing_answers) :-
    findall(Budget,
            ( between(1, 200, Budget),
              call_with_inference_limit(nested_findall_work, Budget, _) ),
            Plain),
    assertion(length(Plain, 200)),
    findall(Budget,
            ( between(1, 200, Budget),
              metta_host_inference_budget(nested_findall_work, Budget, Bounded),
              catch(Bounded, error(metta_control_signal(inference_limit, _), _), true) ),
            Doors),
    assertion(length(Doors, 200)),
    findall(Budget,
            ( between(1, 200, Budget),
              call_with_inference_limit(
                  once(findnsols(2, X, ( member(X, [a, b, c]), limits_spin(3) ), _)),
                  Budget, _) ),
            Chunked),
    assertion(length(Chunked, 200)).

test(an_undefined_predicate_under_a_bound_still_refuses) :-
    catch(call_with_inference_limit(limits_missing:nothing_defines_this(1), 50, Result),
          Ball,
          true),
    assertion(( Result == inference_limit_exceeded
              ; Ball = error(existence_error(procedure, _), _) )),
    catch(limits_missing:nothing_defines_this(1),
          error(existence_error(procedure, Indicator), _),
          true),
    assertion(Indicator == limits_missing:nothing_defines_this/1).

%The wrapped findall keeps its answers and its determinism, and a findnsols
%cut by its caller pops its bag: a stale bag would make the findall after
%it collect the wrong answers.
test(the_wrapped_collectors_answer_as_the_host_does) :-
    findall(X, member(X, [a, b, c]), Xs),
    assertion(Xs == [a, b, c]),
    findall(X, fail, None),
    assertion(None == []),
    once(findnsols(2, Y, member(Y, [p, q, r]), Chunk)),
    assertion(Chunk == [p, q]),
    findall(Z, member(Z, [u, v]), Zs),
    assertion(Zs == [u, v]),
    findall(All, findnsols(2, W, member(W, [1, 2, 3]), All), Chunks),
    assertion(Chunks == [[1, 2], [3]]),
    bagof(K-V, member(K-V, [b-2, a-1]), Pairs),
    assertion(Pairs == [b-2, a-1]),
    aggregate_all(count, member(_, [x, y, z]), Count),
    assertion(Count == 3).

:- end_tests(limits).
