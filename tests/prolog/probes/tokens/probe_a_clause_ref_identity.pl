% Purpose: probe (a) for the tokens design: whether a clause reference is a
%   stable identity across a transaction commit, after a snapshot discards it,
%   after retract, and after clause garbage collection, first on the raw SWI
%   database and then through the engine's own add_sexp/3 and
%   stored_atom_of_ref/3.
% Run: cd <worktree> && timeout -s KILL 120 swipl -q -g main -t halt ai-tmp/probes/probe_a_clause_ref_identity.pl
:- ensure_loaded('../../engine/qlf_boot.pl').
:- ensure_loaded('../../engine/metta.pl').

:- dynamic p/1.

report(Label, Goal) :-
    (   catch(Goal, E, (format("~w: EXCEPTION ~q~n", [Label, E]), fail))
    ->  format("~w: yes~n", [Label])
    ;   format("~w: no~n", [Label])
    ).

main :-
    % --- raw SWI: transaction commit keeps the reference identity
    transaction(( assertz(p(1), Ref1),
                  transaction_updates(U1),
                  format("inside tx: transaction_updates = ~q~n", [U1]) )),
    format("ref minted inside tx: ~q~n", [Ref1]),
    report("after commit: clause(p(1), true, Ref1) finds the clause by the minted ref",
           clause(p(1), true, Ref1)),
    clause(p(X), true, Ref1b), X == 1,
    report("after commit: the ref clause/3 hands back outside is == the minted ref",
           Ref1b == Ref1),
    report("after commit: clause_property(Ref1, predicate(PI)) answers",
           ( clause_property(Ref1, predicate(PI)), format("   PI = ~q~n", [PI]) )),
    % --- retract: the ref survives as an erased reference while referenced
    erase(Ref1),
    report("after erase: clause/3 by the ref fails", \+ clause(p(_), true, Ref1)),
    report("after erase: clause_property(Ref1, erased) holds", clause_property(Ref1, erased)),
    report("after erase: clause_property(Ref1, predicate(_)) still answers (erased-but-referenced)",
           clause_property(Ref1, predicate(_))),
    garbage_collect_clauses,
    report("after garbage_collect_clauses: clause_property(Ref1, predicate(_)) still answers",
           clause_property(Ref1, predicate(_))),
    report("after garbage_collect_clauses: clause_property(Ref1, erased) still answers",
           clause_property(Ref1, erased)),
    % --- snapshot: the reference is minted and then discarded
    snapshot(( assertz(p(2), Ref2),
               transaction_updates(U2),
               format("inside snapshot: transaction_updates = ~q~n", [U2]),
               nb_setval(probe_ref2, Ref2) )),
    nb_getval(probe_ref2, Ref2out),
    format("ref minted inside snapshot: ~q~n", [Ref2out]),
    report("after snapshot discard: clause(p(2), true, Ref2) fails", \+ clause(p(2), true, Ref2out)),
    report("after snapshot discard: clause_property(Ref2, erased) holds", clause_property(Ref2out, erased)),
    report("after snapshot discard: clause_property(Ref2, predicate(_)) answers",
           clause_property(Ref2out, predicate(_))),
    % --- nested transaction: a ref minted in an inner tx that commits into an outer tx that rolls back
    catch(transaction(( transaction(assertz(p(3), Ref3)),
                        nb_setval(probe_ref3, Ref3),
                        throw(abandon) )), abandon, true),
    nb_getval(probe_ref3, Ref3out),
    report("inner-committed ref after outer rollback: clause/3 fails", \+ clause(p(3), true, Ref3out)),
    report("inner-committed ref after outer rollback: clause_property erased", clause_property(Ref3out, erased)),
    % --- identity is by pointer: two refs of two identical clauses differ
    assertz(p(4), RefA), assertz(p(4), RefB),
    report("two identical clauses have two distinct references", RefA \== RefB),
    report("references are blobs of type clause",
           ( blob(RefA, T), format("   blob type = ~q~n", [T]) )),
    % --- the engine's own door: add_sexp/3 and stored_atom_of_ref/3
    transaction(add_sexp('&self', [probe_fact, 1], ERef)),
    format("engine ref minted inside tx: ~q~n", [ERef]),
    report("engine: stored_atom_of_ref decodes the committed ref to its space and atom",
           ( stored_atom_of_ref(ERef, Sp, At), format("   ~q ~q~n", [Sp, At]) )),
    snapshot(( add_sexp('&self', [probe_fact, 2], ERef2), nb_setval(probe_eref2, ERef2) )),
    nb_getval(probe_eref2, ERef2out),
    report("engine: stored_atom_of_ref FAILS for a snapshot-discarded ref (an erased ref decodes to nothing)",
           \+ stored_atom_of_ref(ERef2out, _, _)),
    report("engine: match still answers (probe_fact 1) after the snapshot",
           ( findall(V, match('&self', [probe_fact, V], V, V), Vs), format("   ~q~n", [Vs]), Vs == [1] )),
    % --- transaction_updates inside a transaction lists refs of atoms the engine added
    transaction(( add_sexp('&self', [probe_fact, 3], ERef3),
                  metta_remove_atom('&self', [probe_fact, 1], Removed),
                  transaction_updates(U3),
                  format("engine tx updates: ~q (removed=~w, minted=~q)~n", [U3, Removed, ERef3]) )),
    halt(0).
