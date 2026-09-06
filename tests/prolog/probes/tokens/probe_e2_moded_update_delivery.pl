% Purpose: probe (e2): how SWI's moded tabling feeds an UPDATED aggregate to a
%   consumer inside the same SCC. The source s(a,_) is `max` (idempotent, so
%   the SCC converges); the consumer t(b,_) is `sum`. If the consumer's earlier
%   contribution stays and the new aggregate is joined on top, t(b) = 10 + 20
%   = 30; if the re-fed aggregate replaces it, t(b) = 20.
%   The first attempt used two non-idempotent aggregates feeding each other
%   and never converged (a unit-rule cycle, PODS 2007 Theorem 6.5), which is
%   itself a result recorded in the design.
% Run: cd <worktree> && timeout -s KILL 120 swipl -q -g main -t halt ai-tmp/probes/probe_e2_moded_update_delivery.pl
:- table s(_, max), t(_, sum).
s(a, 1).
s(a, 2) :- t(b, _).
t(b, C) :- s(a, V), C is V * 10.

% polynomial version: source lattice is Why(X)-style (idempotent, finite), consumer is psum
wsum(P, Q, R) :- append(P, Q, PQ), keysort(PQ, S), merge_coeffs(S, R0), maplist([M-_, M-1]>>true, R0, R).
psum(P, Q, R) :- append(P, Q, PQ), keysort(PQ, S), merge_coeffs(S, R).
merge_coeffs([], []).
merge_coeffs([M-C], [M-C]) :- !.
merge_coeffs([M-C1, M-C2|T], R) :- !, C is C1 + C2, merge_coeffs([M-C|T], R).
merge_coeffs([MC|T], [MC|R]) :- merge_coeffs(T, R).
ptimes(P, Q, R) :-
    findall(M-C, ( member(M1-C1, P), member(M2-C2, Q), append(M1, M2, M0), msort(M0, M), C is C1 * C2 ), Raw),
    keysort(Raw, S), merge_coeffs(S, R).
:- table sw(_, lattice(wsum/3)), tp(_, lattice(psum/3)).
sw(a, [[x]-1]).
sw(a, [[y]-1]) :- tp(b, _).
tp(b, P) :- sw(a, P0), ptimes(P0, [[z]-1], P).

main :-
    call_with_inference_limit(( t(b, C), s(a, V) ), 2000000, R1),
    format("e2 sum consumer of a max source: t(b) = ~w with s(a) = ~w (~w)  [30 = joined on top of the earlier contribution; 20 = replaced]~n", [C, V, R1]),
    call_with_inference_limit(( tp(b, P), sw(a, PA) ), 2000000, R2),
    format("e2 psum consumer of a Why(X) source: tp(b) = ~q with sw(a) = ~q (~w)  [2xz + yz = joined on top; xz + yz = replaced]~n", [P, PA, R2]),
    halt(0).
