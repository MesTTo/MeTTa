% Purpose: the Prolog half of tests/prolog/probes/twin_profile.py: write the
%   profiler's per-predicate call counts, or the b_setval/2 writes per key,
%   as a TSV. Consulted by the probe; nothing else loads it.
% Assumes: the profiler has been stopped before the dump is asked for.
:- use_module(library(prolog_wrap)).
:- dynamic twin_profile_key/2.

twin_profile_dump(Out, Spent) :-
    profile_data(Data),
    get_dict(nodes, Data, Nodes),
    findall(Call-Pred, ( member(N, Nodes), get_dict(predicate, N, Pred),
                         get_dict(call, N, Call), Call > 0 ), Pairs),
    msort(Pairs, Sorted0), reverse(Sorted0, Sorted),
    setup_call_cleanup(open(Out, write, S),
        ( format(S, "inferences\t~d~n", [Spent]),
          forall(member(C-P, Sorted), format(S, "~d\t~q~n", [C, P])) ),
        close(S)).

twin_profile_watch_keys :-
    wrap_predicate(system:b_setval(K, V), twin_profile_keys, Wrapped,
                   ( twin_profile_record(K, V), Wrapped )).

% Counted per key and per whether the write changes anything: a write of the
% term the key already holds is a no-op by identity, which is what a scope
% re-entered per answer looks like from the outside.
twin_profile_record(Key, Value) :-
    (   nb_current(Key, Held), same_term(Held, Value)
    ->  Row = Key-same
    ;   Row = Key-changed
    ),
    ( retract(twin_profile_key(Row, N)) -> M is N + 1 ; M = 1 ),
    assertz(twin_profile_key(Row, M)).

twin_profile_key_report(Out) :-
    findall(N-Row, twin_profile_key(Row, N), Pairs),
    msort(Pairs, Sorted0), reverse(Sorted0, Sorted),
    setup_call_cleanup(open(Out, write, S),
        forall(member(N-Row, Sorted), format(S, "~d\t~q~n", [N, Row])),
        close(S)).
