% Purpose: probe (b) for the tokens design: whether SWI exposes a clause's
%   creation generation to Prolog. Enumerates clause_property/2 keys, tries
%   candidate '$get_clause_attribute'/3 keys, reads
%   predicate_property(_, last_modified_generation(_)) inside and outside
%   transactions, and records what prolog_listen/2 delivers for an assert
%   inside a snapshot, a transaction and a rolled-back transaction.
% Run: cd <worktree> && timeout -s KILL 120 swipl -q -g main -t halt ai-tmp/probes/probe_b_generation_exposure.pl
:- dynamic p/1, seen/1.

try_attr(Ref, Key) :-
    (   catch('$get_clause_attribute'(Ref, Key, V), E, (format("  ~w -> EXCEPTION ~q~n", [Key, E]), fail))
    ->  format("  ~w -> ~q~n", [Key, V])
    ;   format("  ~w -> fails~n", [Key])
    ).

listener(Pred, Action, Context) :-
    assertz(seen(Pred-Action-Context)),
    format("  event: ~w ~q ~q~n", [Pred, Action, Context]).

dump_seen(Label) :-
    findall(S, seen(S), L),
    format("~w: ~q~n", [Label, L]),
    retractall(seen(_)).

main :-
    assertz(p(1), Ref),
    format("documented clause_property keys on a fresh dynamic clause:~n"),
    forall(clause_property(Ref, P), format("  ~q~n", [P])),
    format("candidate '$get_clause_attribute' keys:~n"),
    forall(member(K, [file, line_count, owner, size, fact, erased, predicate_indicator, module,
                      generation, created, erased_generation, birth, death, created_generation,
                      generations, generation_created, generation_erased, references, mark]),
           try_attr(Ref, K)),
    predicate_property(p(_), last_modified_generation(G0)),
    format("last_modified_generation outside any transaction after 1 assert: ~w~n", [G0]),
    assertz(p(2)),
    predicate_property(p(_), last_modified_generation(G1)),
    format("after a second assert: ~w (delta ~w)~n", [G1, G1 - G0]),
    transaction(( assertz(p(3)),
                  predicate_property(p(_), last_modified_generation(Gt)),
                  format("inside a transaction after an assert: ~w~n", [Gt]) )),
    predicate_property(p(_), last_modified_generation(G2)),
    format("after that transaction committed: ~w~n", [G2]),
    snapshot(( assertz(p(4)),
               predicate_property(p(_), last_modified_generation(Gs)),
               format("inside a snapshot after an assert: ~w~n", [Gs]) )),
    predicate_property(p(_), last_modified_generation(G3)),
    format("after the snapshot discarded: ~w~n", [G3]),
    % generation-like system flags
    forall(member(F, [generation, dynamic_generation]),
           ( ( catch(current_prolog_flag(F, V), _, fail) -> true ; V = none ), format("prolog_flag ~w: ~q~n", [F, V]) )),
    forall(member(K, [generations, clauses, codes, atoms, predicates, modules, table_space_used]),
           ( ( catch(statistics(K, V2), _, fail) -> true ; V2 = none ), format("statistics ~w: ~q~n", [K, V2]) )),
    % prolog_listen delivery timing
    prolog_listen(p/1, listener(p/1)),
    format("-- assert outside any transaction:~n"),
    assertz(p(10)), dump_seen("events"),
    format("-- assert inside a committed transaction (default options):~n"),
    transaction(( assertz(p(11)), format("  (inside, before commit)~n") )), dump_seen("events"),
    format("-- assert inside a rolled-back transaction:~n"),
    catch(transaction(( assertz(p(12)), throw(abandon) )), abandon, true), dump_seen("events"),
    format("-- assert inside a snapshot:~n"),
    snapshot(assertz(p(13))), dump_seen("events"),
    format("-- transaction with bulk(true):~n"),
    transaction(( assertz(p(14)), format("  (inside, before commit)~n") ), [bulk(true)]), dump_seen("events"),
    format("-- retract outside:~n"),
    retract(p(10)), dump_seen("events"),
    format("-- retract inside a rolled-back transaction:~n"),
    catch(transaction(( retract(p(11)), throw(abandon) )), abandon, true), dump_seen("events"),
    prolog_unlisten(p/1, listener(p/1)),
    halt(0).
