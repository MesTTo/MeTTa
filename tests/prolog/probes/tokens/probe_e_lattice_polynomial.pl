% Purpose: probe (e) for the provenance carrier: whether a mode-directed
%   lattice(PI) table can carry a provenance polynomial as its aggregated value
%   (join = polynomial sum), whether that join is CORRECT under SWI's
%   completion (re-evaluation of dependent continuations when an aggregate
%   changes), and what it costs on 1,000-answer tables against a plain table
%   and an integer `sum` table.
%   A polynomial is a sorted list Monomial-Coefficient; a monomial is a sorted
%   list of tokens (msort keeps duplicates, so x*x is [x,x]).
% Run: cd <worktree> && timeout -s KILL 300 swipl -q -g main -t halt ai-tmp/probes/probe_e_lattice_polynomial.pl

% ---- polynomial arithmetic over N[X] as canonical terms
psum(P, Q, R) :- append(P, Q, PQ), keysort(PQ, S), merge_coeffs(S, R).
merge_coeffs([], []).
merge_coeffs([M-C], [M-C]) :- !.
merge_coeffs([M-C1, M-C2|T], R) :- !, C is C1 + C2, merge_coeffs([M-C|T], R).
merge_coeffs([MC|T], [MC|R]) :- merge_coeffs(T, R).
ptimes(P, Q, R) :-
    findall(M-C, ( member(M1-C1, P), member(M2-C2, Q), append(M1, M2, M0), msort(M0, M), C is C1 * C2 ), Raw),
    keysort(Raw, S), merge_coeffs(S, R).
% B[X]: the idempotent image (coefficients collapse to 1)
bsum(P, Q, R) :- append(P, Q, PQ), keysort(PQ, S), merge_coeffs(S, R0), maplist([M-_, M-1]>>true, R0, R).

% ---- e1/e2: the double-count question on an acyclic graph with two parallel edges
:- dynamic e/3.
:- table reach_n(_, _, lattice(psum/3)).
reach_n(X, Y, [[T]-1]) :- e(X, Y, T).
reach_n(X, Y, P) :- reach_n(X, Z, P1), e(Z, Y, T), ptimes(P1, [[T]-1], P).

:- table reach_b(_, _, lattice(bsum/3)).
reach_b(X, Y, [[T]-1]) :- e(X, Y, T).
reach_b(X, Y, P) :- reach_b(X, Z, P1), e(Z, Y, T), ptimes(P1, [[T]-1], P0), bsum(P0, [], P).

% the same provenance computed by enumerating proof trees, one monomial per tree, summed outside any table
path(X, Y, [T]) :- e(X, Y, T).
path(X, Y, [T|P]) :- e(X, Z, T), path(Z, Y, P).
enumerated(X, Y, Poly) :- findall(M-1, ( path(X, Y, M0), msort(M0, M) ), Raw), keysort(Raw, S), merge_coeffs(S, Poly).

% Why(X): a monomial is a SET of tokens (sort/2), coefficients collapse; finitely many values over a finite token set
wsum(P, Q, R) :- append(P, Q, PQ), keysort(PQ, S), merge_coeffs(S, R0), maplist([M-_, M-1]>>true, R0, R).
wtimes(P, Q, R) :-
    findall(M-1, ( member(M1-_, P), member(M2-_, Q), append(M1, M2, M0), sort(M0, M) ), Raw), keysort(Raw, S), merge_coeffs(S, R0), maplist([M-_, M-1]>>true, R0, R).
:- table reach_w(_, _, lattice(wsum/3)).
reach_w(X, Y, [[T]-1]) :- e(X, Y, T).
reach_w(X, Y, P) :- reach_w(X, Z, P1), e(Z, Y, T), wtimes(P1, [[T]-1], P).

bounded(Label, Goal) :-
    call_with_inference_limit(Goal, 2000000, R),
    (   R == inference_limit_exceeded
    ->  format("~w: DID NOT CONVERGE within 2,000,000 inferences~n", [Label])
    ;   format("~w: converged (~w)~n", [Label, R])
    ).

% ---- e3: does the `sum` mode double count on a recursive dependency?
:- table cnt(_, sum).
cnt(a, 1).
cnt(a, 1).
cnt(b, C) :- cnt(a, C0), C is C0 * 10.

% ---- e4: cost on 1,000-answer tables (star graph: root -> leaf_i by two parallel edges p_i, q_i)
:- dynamic se/3.
:- table star_plain(_, _).
star_plain(X, Y) :- se(X, Y, _).
star_plain(X, Y) :- star_plain(X, Z), se(Z, Y, _).
:- table star_count(_, _, sum).
star_count(X, Y, 1) :- se(X, Y, _).
star_count(X, Y, C) :- star_count(X, Z, C), se(Z, Y, _).
:- table star_poly(_, _, lattice(psum/3)).
star_poly(X, Y, [[T]-1]) :- se(X, Y, T).
star_poly(X, Y, P) :- star_poly(X, Z, P1), se(Z, Y, T), ptimes(P1, [[T]-1], P).
:- table star_rows(_, _, _).          % provenance as part of the variant: one row per derivation
star_rows(X, Y, [[T]-1]) :- se(X, Y, T).
star_rows(X, Y, P) :- star_rows(X, Z, P1), se(Z, Y, T), ptimes(P1, [[T]-1], P).

% ---- e5: a chain of 1,000 single edges (monomials grow with depth)
:- dynamic ce/3.
:- table chain_plain(_, _).
chain_plain(X, Y) :- ce(X, Y, _).
chain_plain(X, Y) :- chain_plain(X, Z), ce(Z, Y, _).
:- table chain_poly(_, _, lattice(psum/3)).
chain_poly(X, Y, [[T]-1]) :- ce(X, Y, T).
chain_poly(X, Y, P) :- chain_poly(X, Z, P1), ce(Z, Y, T), ptimes(P1, [[T]-1], P).

measure(Label, Goal) :-
    garbage_collect,
    statistics(inferences, I0), statistics(cputime, C0),
    ( call(Goal) -> true ; format("~w: GOAL FAILED~n", [Label]) ),
    statistics(inferences, I1), statistics(cputime, C1),
    Inf is I1 - I0, Cpu is C1 - C0,
    format("~w: ~D inferences, ~3f s cpu~n", [Label, Inf, Cpu]).

table_bytes(Label) :-
    statistics(table_space_used, B), format("   ~w table_space_used = ~D bytes~n", [Label, B]).

main :-
    % e1: a -> b by p and q, b -> c by r; N[X] provenance of reach(a,c) is p*r + q*r
    assertz(e(a, b, p)), assertz(e(a, b, q)), assertz(e(b, c, r)),
    enumerated(a, c, Expected), format("e1 expected N[X] provenance of reach(a,c) by proof-tree enumeration: ~q~n", [Expected]),
    reach_n(a, c, Pn), format("e1 lattice(psum) table answers: ~q~n", [Pn]),
    ( Pn == Expected -> format("e1 VERDICT: lattice(psum) agrees with the enumeration~n") ; format("e1 VERDICT: lattice(psum) DISAGREES (double counting under completion)~n") ),
    reach_b(a, c, Pb), format("e2 lattice(bsum) (B[X], idempotent) table answers: ~q~n", [Pb]),
    % e1b: a diamond with a longer left arm, so the first aggregate seen by the dependent is not the final one
    retractall(e(_, _, _)),
    assertz(e(s, m, x1)), assertz(e(s, n, y1)), assertz(e(n, m, y2)), assertz(e(m, t, z)),
    abolish_all_tables,
    enumerated(s, t, Exp2), format("e1b expected: ~q~n", [Exp2]),
    reach_n(s, t, Pn2), format("e1b lattice(psum): ~q~n", [Pn2]),
    ( Pn2 == Exp2 -> format("e1b VERDICT: agrees~n") ; format("e1b VERDICT: DISAGREES~n") ),
    reach_b(s, t, Pb2), format("e1b lattice(bsum): ~q~n", [Pb2]),
    % e1c: the SAME question asked of the in-SCC table: the open call reach_n(s, Y, P) computes (s,t) inside the
    % variant (s,_,_) whose own aggregate for (s,m) changes while (s,t) is being derived from it
    abolish_all_tables,
    findall(Y-P, reach_n(s, Y, P), Open), msort(Open, OpenS), format("e1c open call reach_n(s, Y, P) answers: ~q~n", [OpenS]),
    ( memberchk(t-Pt, OpenS), Pt == Exp2 -> format("e1c VERDICT: in-SCC aggregate agrees~n") ; format("e1c VERDICT: in-SCC aggregate DISAGREES with ~q (double counting inside one SCC)~n", [Exp2]) ),
    abolish_all_tables,
    findall(Y-P, reach_b(s, Y, P), OpenB), msort(OpenB, OpenBS), format("e1c open call lattice(bsum): ~q~n", [OpenBS]),
    abolish_all_tables,
    findall(Y-P, reach_w(s, Y, P), OpenW), msort(OpenW, OpenWS), format("e1c open call lattice(wsum) Why(X): ~q~n", [OpenWS]),
    % e6: a cyclic graph a <-> b, b -> c: infinitely many derivations
    retractall(e(_, _, _)), assertz(e(a, b, ab)), assertz(e(b, a, ba)), assertz(e(b, c, bc)),
    abolish_all_tables, bounded("e6 cyclic graph, lattice(psum) N[X]", reach_n(a, c, _)),
    abolish_all_tables, bounded("e6 cyclic graph, lattice(bsum) B[X]", reach_b(a, c, _)),
    abolish_all_tables, bounded("e6 cyclic graph, lattice(wsum) Why(X)", ( reach_w(a, c, Pw), format("   Why(X) provenance of reach(a,c): ~q~n", [Pw]) )),
    % e3: sum mode on a dependent aggregate
    cnt(b, Cb), format("e3 `sum` table cnt(b): ~w (10 if the dependent contributes once per aggregate update after re-evaluation, 20 if it sums both the partial and the final aggregate)~n", [Cb]),
    % e4: star graph, 1000 leaves, two parallel edges each
    forall(between(1, 1000, I), ( atom_concat(leaf_, I, L), atom_concat(p_, I, P), atom_concat(q_, I, Q), assertz(se(root, L, P)), assertz(se(root, L, Q)) )),
    abolish_all_tables,
    measure("e4 plain table, 1000 answers", ( findall(Y, star_plain(root, Y), Ys), length(Ys, N1), format("   answers ~w~n", [N1]) )), table_bytes("plain"),
    abolish_all_tables,
    measure("e4 sum-count table, 1000 answers", ( findall(Y-C, star_count(root, Y, C), Ycs), length(Ycs, N2), msort(Ycs, [_-C1|_]), format("   answers ~w, first count ~w~n", [N2, C1]) )), table_bytes("sum"),
    abolish_all_tables,
    measure("e4 lattice(psum) polynomial table, 1000 answers", ( findall(Y-P, star_poly(root, Y, P), Yps), length(Yps, N3), msort(Yps, [_-P1|_]), format("   answers ~w, first polynomial ~q~n", [N3, P1]) )), table_bytes("psum"),
    abolish_all_tables,
    measure("e4 provenance-in-variant table (one row per derivation), 2000 rows", ( findall(Y-P, star_rows(root, Y, P), Yrs), length(Yrs, N4), format("   rows ~w~n", [N4]) )), table_bytes("rows"),
    % e5: chain of 1000
    forall(between(1, 1000, I), ( J is I + 1, atom_concat(n_, I, A), atom_concat(n_, J, B), atom_concat(t_, I, T), assertz(ce(A, B, T)) )),
    abolish_all_tables,
    measure("e5 chain plain table, 1000 answers", ( findall(Y, chain_plain(n_1, Y), Cs), length(Cs, N5), format("   answers ~w~n", [N5]) )), table_bytes("chain plain"),
    abolish_all_tables,
    measure("e5 chain lattice(psum) table, 1000 answers (monomial of length i at depth i)", ( findall(Y-P, chain_poly(n_1, Y, P), Cps), length(Cps, N6), format("   answers ~w~n", [N6]) )), table_bytes("chain psum"),
    halt(0).
