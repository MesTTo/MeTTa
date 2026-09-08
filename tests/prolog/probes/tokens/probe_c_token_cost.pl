% Purpose: probe (c) for the tokens design: the cost in inferences, CPU
%   seconds and bytes of carrying one token per atom for a 100,000-atom space,
%   on add and on match, against the current storage, on five storage shapes:
%     v0  the engine's own doors (metta_add_atom/3 and match/4 on &self)
%     v1  raw current shape       M:'&x'(Rel, A, B)
%     v2  extra integer argument  M:'&x'(Rel, A, B, Gen)
%     v3  extra compound argument M:'&x'(Rel, A, B, t(Actor, Gen))
%     v4  side table keyed by clause reference: assertz/2 + M:tok(Ref, Gen)
%     v5  side table filled by a prolog_listen/2 hook on the storage predicate
%   plus the cost of three generation counters over 100,000 increments.
% Run: swipl -q -g main -t halt tests/prolog/probes/tokens/probe_c_token_cost.pl
:- ensure_loaded('../../../../engine/qlf_boot.pl').
:- ensure_loaded('../../../../engine/metta.pl').

:- dynamic v1:'&x'/3, v2:'&x'/4, v3:'&x'/4, v4:'&x'/3, v4:tok/2, v5:'&x'/3, v5:tok/2.
:- dynamic gencount/1.

n_atoms(100000).
n_rel(100).           % first argument values 0..99, 1000 rows each

measure(Label, Goal, Inf, Cpu) :-
    garbage_collect,
    statistics(inferences, I0), statistics(cputime, C0),
    ( call(Goal) -> true ; format("~w: GOAL FAILED~n", [Label]) ),
    statistics(inferences, I1), statistics(cputime, C1),
    Inf is I1 - I0, Cpu is C1 - C0,
    format("~w: ~D inferences, ~3f s cpu~n", [Label, Inf, Cpu]).

pred_bytes(Head, Bytes) :-
    ( predicate_property(Head, size(Bytes)) -> true ; Bytes = unknown ).

fill(Adder) :-
    n_atoms(N), n_rel(R),
    forall(between(1, N, K),
           ( I is K mod R, J is K // R, call(Adder, I, J) )).

% adders
add_v0(I, J) :- metta_add_atom('&self', [edge, I, J], _).
add_v1(I, J) :- assertz(v1:'&x'(edge, I, J)).
add_v2(I, J) :- flag(gen_v2, G, G + 1), assertz(v2:'&x'(edge, I, J, G)).
add_v3(I, J) :- flag(gen_v3, G, G + 1), assertz(v3:'&x'(edge, I, J, t(engine_a, G))).
add_v4(I, J) :- flag(gen_v4, G, G + 1), assertz(v4:'&x'(edge, I, J), Ref), assertz(v4:tok(Ref, G)).
add_v5(I, J) :- assertz(v5:'&x'(edge, I, J)).
v5_hook(assertz, Ref) :- !, flag(gen_v5, G, G + 1), assertz(v5:tok(Ref, G)).
v5_hook(_, _).

% matchers: bound first argument (1000 answers) and a full scan (100000 answers)
match_v0_bound(L) :- findall(X, match('&self', [edge, 5, X], X, X), L).
match_v0_scan(L)  :- findall(X-Y, match('&self', [edge, X, Y], [X, Y], _), L).
match_v1_bound(L) :- findall(X, v1:'&x'(edge, 5, X), L).
match_v1_scan(L)  :- findall(X-Y, v1:'&x'(edge, X, Y), L).
match_v2_bound(L) :- findall(X, v2:'&x'(edge, 5, X, _), L).
match_v2_scan(L)  :- findall(X-Y, v2:'&x'(edge, X, Y, _), L).
match_v2_bound_tok(L) :- findall(X-G, v2:'&x'(edge, 5, X, G), L).
match_v3_bound(L) :- findall(X, v3:'&x'(edge, 5, X, _), L).
match_v3_scan(L)  :- findall(X-Y, v3:'&x'(edge, X, Y, _), L).
match_v4_bound(L) :- findall(X, v4:'&x'(edge, 5, X), L).
match_v4_bound_tok(L) :- findall(X-G, ( clause(v4:'&x'(edge, 5, X), true, Ref), v4:tok(Ref, G) ), L).
match_v4_scan_tok(L)  :- findall(X-Y-G, ( clause(v4:'&x'(edge, X, Y), true, Ref), v4:tok(Ref, G) ), L).
% as-of read through the side table: every atom whose generation is below a bound
asof_v2(Bound, L) :- findall(X-Y, ( v2:'&x'(edge, X, Y, G), G < Bound ), L).
asof_v4(Bound, L) :- findall(X-Y, ( v4:tok(Ref, G), G < Bound, clause(v4:'&x'(edge, X, Y), true, Ref) ), L).
% blame: the token of one given atom
blame_v2(I, J, G) :- once(v2:'&x'(edge, I, J, G)).
blame_v4(I, J, G) :- once(( clause(v4:'&x'(edge, I, J), true, Ref), v4:tok(Ref, G) )).

counters :-
    n_atoms(N),
    measure("counter flag/3 x100k", forall(between(1, N, _), flag(gen_c, G, G + 1)), _, _),
    nb_setval(gen_nb, 0),
    measure("counter nb_getval/nb_setval x100k",
            forall(between(1, N, _), ( nb_getval(gen_nb, G), G1 is G + 1, nb_setval(gen_nb, G1) )), _, _),
    assertz(gencount(0)),
    measure("counter retract/assert dynamic fact x100k",
            forall(between(1, N, _), ( retract(gencount(G)), G1 is G + 1, assertz(gencount(G1)) )), _, _),
    measure("counter b_setval/b_getval x100k (backtrackable, for comparison)",
            ( b_setval(gen_b, 0),
              forall(between(1, N, _), ( b_getval(gen_b, G), G1 is G + 1, b_setval(gen_b, G1) )) ), _, _).

main :-
    n_atoms(N),
    format("atoms per variant: ~D~n", [N]),
    % v0: the engine's own doors
    measure("v0 add: metta_add_atom x100k", fill(add_v0), _, _),
    pred_bytes('$metta_atoms:&self':'&self'(_, _, _, _), B0),
    format("v0 bytes: '&self'/4 storage predicate = ~D~n", [B0]),
    measure("v0 match bound first arg (1000 answers)", match_v0_bound(L0), _, _), length(L0, N0), format("   answers ~D~n", [N0]),
    measure("v0 match full scan (100000 answers)", match_v0_scan(S0), _, _), length(S0, NS0), format("   answers ~D~n", [NS0]),
    % v1
    measure("v1 add: raw assertz current shape x100k", fill(add_v1), _, _),
    pred_bytes(v1:'&x'(_, _, _), B1), format("v1 bytes: ~D~n", [B1]),
    measure("v1 match bound (1000)", match_v1_bound(L1), _, _), length(L1, N1), format("   answers ~D~n", [N1]),
    measure("v1 match scan (100000)", match_v1_scan(S1), _, _), length(S1, NS1), format("   answers ~D~n", [NS1]),
    % v2
    measure("v2 add: extra integer argument + flag counter x100k", fill(add_v2), _, _),
    pred_bytes(v2:'&x'(_, _, _, _), B2), format("v2 bytes: ~D~n", [B2]),
    measure("v2 match bound, token ignored (1000)", match_v2_bound(L2), _, _), length(L2, N2), format("   answers ~D~n", [N2]),
    measure("v2 match bound, token read (1000)", match_v2_bound_tok(L2t), _, _), length(L2t, N2t), format("   answers ~D~n", [N2t]),
    measure("v2 match scan (100000)", match_v2_scan(S2), _, _), length(S2, NS2), format("   answers ~D~n", [NS2]),
    measure("v2 as-of read (generation < 50000) full scan", asof_v2(50000, A2), _, _), length(A2, NA2), format("   answers ~D~n", [NA2]),
    measure("v2 blame one atom", blame_v2(7, 300, G2), _, _), format("   token ~w~n", [G2]),
    % v3
    measure("v3 add: extra compound t(Actor,Gen) argument x100k", fill(add_v3), _, _),
    pred_bytes(v3:'&x'(_, _, _, _), B3), format("v3 bytes: ~D~n", [B3]),
    measure("v3 match bound (1000)", match_v3_bound(L3), _, _), length(L3, N3), format("   answers ~D~n", [N3]),
    measure("v3 match scan (100000)", match_v3_scan(S3), _, _), length(S3, NS3), format("   answers ~D~n", [NS3]),
    % v4
    measure("v4 add: current shape + side table tok(Ref,Gen) x100k", fill(add_v4), _, _),
    pred_bytes(v4:'&x'(_, _, _), B4a), pred_bytes(v4:tok(_, _), B4b), format("v4 bytes: storage ~D + tok ~D = ~D~n", [B4a, B4b, B4a + B4b]),
    measure("v4 match bound, token ignored (1000)", match_v4_bound(L4), _, _), length(L4, N4), format("   answers ~D~n", [N4]),
    measure("v4 match bound, token read via clause/3 + tok/2 (1000)", match_v4_bound_tok(L4t), _, _), length(L4t, N4t), format("   answers ~D~n", [N4t]),
    measure("v4 match scan with tokens (100000)", match_v4_scan_tok(S4), _, _), length(S4, NS4), format("   answers ~D~n", [NS4]),
    measure("v4 as-of read (generation < 50000) via tok/2 then clause/3", asof_v4(50000, A4), _, _), length(A4, NA4), format("   answers ~D~n", [NA4]),
    measure("v4 blame one atom", blame_v4(7, 300, G4), _, _), format("   token ~w~n", [G4]),
    % v5
    prolog_listen(v5:'&x'/3, v5_hook),
    measure("v5 add: current shape + prolog_listen hook filling tok(Ref,Gen) x100k", fill(add_v5), _, _),
    prolog_unlisten(v5:'&x'/3, v5_hook),
    pred_bytes(v5:tok(_, _), B5b), format("v5 bytes: tok ~D~n", [B5b]),
    aggregate_all(count, v5:tok(_, _), C5), format("v5 tok rows filled by the hook: ~D~n", [C5]),
    counters,
    halt(0).
