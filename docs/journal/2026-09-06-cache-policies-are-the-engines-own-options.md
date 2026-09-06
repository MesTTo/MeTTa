# Cache policies are the engine's own options
Goal: `(cache Name Policy)` compiles to SWI-Prolog's `table/1` option list and
answer-subsumption mode, so monotonic, lattice, subsumptive, private and the
three restraints are one catalog vocabulary reached as terms from every seat,
and a policy the engine cannot honour is refused naming the remedy.
Constraint: the engine is SWI-Prolog 10.1.13 as shipped on this box; what its
tabling does on a write is measured here, not read from the manual, because
the manual and the build disagree in four places.

## 2026-09-07

Tried: `dynamic link/2 as (monotonic, incremental)` under a
`table reach/2 as (monotonic, shared)`, which is what the brief asked for
("and incremental, since SWI allows both") -> the incremental wrapper
invalidates the monotonic table on every assert and the next call
re-evaluates it: over a 200-link chain, assert 62 inferences and the next
call 4,776, against 50 and 415 with the storage predicate `as monotonic`
alone, and 10 and 2,350 for a pure incremental table
(`swipl -q ai-tmp/cp/probe17.pl`, every combination in one run). Rejected:
`incremental` on the storage predicate of a monotonic table, because it is
the worst of both: the propagation is paid at the write AND the table is
rebuilt at the read. Revisit if a later SWI stops routing a monotonic
dependency through the incremental wrapper.

Decided: a storage predicate carries one watch. Two functions reading one
space under different watches would need the predicate to be both, which is
the case above, so the second declaration is refused naming the first reader
and the two remedies (declare the same watch, or plain), and the property is
turned back off when the last reader under it is dropped.
`dynamic/2`'s `incremental(false)` is the documented door for one;
`monotonic(false)` is accepted and leaves the property standing on 10.1.13
(`probe18`), so the monotonic release goes through
`'$set_predicate_attribute'/3` plus `'$set_table_wrappers'/1`, the pair
`untable/1` and `dynamic/1` themselves run [source:
/usr/lib/swi-prolog/boot/tabling.pl].

Tried: `table p(_,_,lattice(join/3)) as (incremental, shared)` and
`as (monotonic, shared)`, then a write and a second call -> the re-evaluated
table answered `[]` (incremental) and then a second `c` answer beside the old
one, `[c-3, c-1, a-2, b-1]`, with `a-6` for a path that costs 2 (private,
either watch); and every SHARED moded table raised
`type_error(trie, <clause>)` from `trie_gen/2` on its second call whatever the
watch (`probe13_*`, six fresh processes). Decided: a lattice table is
`private` and `plain` on this SWI; `shared`, `incremental` and `monotonic`
beside `lattice` are refused at compile time with the measurement in the
message. The private moded table is exactly the shape `lib_memo`'s `sum`
tables have used all along, which is why that one never showed the defect.

Tried: `table r/2 as (subsumptive, incremental, shared)` and
`(subsumptive, monotonic, shared)`, a write, then any call ->
`existence_error(reset, call_info(...))`, "Cannot catch continuation through
findall/3" or "No matching reset/3 call" (`probe7`). Plain subsumptive works:
the specific call `sreach(a, Y)` answered from the general table and the
table count stayed at 1. Decided: `subsumptive` refuses a watch the same way.

Decided: the default watch. A variant table over a body the effect walk
classifies is `incremental`, as `tabled` has always built it; a body the walk
cannot classify is `plain`, as the 2026-09-06 memoisation ruling settled. A
`lattice` or `subsumptive` table defaults to `plain`, and when the body reads
a space the program has to write `plain` itself, because a default that leaves
a table stale after a write with no symptom is the 2026-08-16 failure again.
An explicit `incremental` or `monotonic` over a body the walk cannot classify
is refused rather than tabled plain under a word that promised a watch.

Tried: `table p/2 as (max_answers(3), shared)`, the tripwire hook installed,
the action flag at its default `error` -> the hook never fired; the table
completed with three answers and a fourth that binds nothing, conditional on
`answer_count_restraint/0` (bounded rationality), whatever the flag said. The
process-wide flag `max_answers_for_subgoal` does fire the hook, with the wire
`max_answers_for_subgoal` and a trie as context. The two size restraints fire
it as `max_table_subgoal_size` (context: the abstracted goal) and
`max_table_answer_size` (context: the trie). Decided: `max-answers` becomes a
signal at the dispatch seam, where the restrained table's goal is wrapped in
`call_delays/2` and the conditional answer raises
`metta_control_signal(restraint, [Word, Bound, Call])`; the size restraints
raise the same signal from `prolog:tripwire/2`, which claims only wires whose
context names a table this library installed with that restraint. The engine
lists the envelope as a control exception beside the two limit envelopes, so
a MeTTa `catch` cannot disarm a program's own bound, and the Python seat
classifies it as `RestraintError` under `ResourceLimitError`.

Tried: `table lz/2 as (monotonic, lazy, shared)` over `dynamic link/2 as
monotonic`, with the trie dumped through `get_returns/2` right after the
assert -> the new answer was already in the lazy table, exactly as in the
eager twin; the lazy table read `invalid` until its next call, which cost
545 inferences against 415 eager over the 200-link chain (`probe16`,
`probe17`). The same with a lazy table over an eager monotonic table
(`probe10`). `tdebug` is compiled out of the distribution build, so the
mechanism is not explained here, only measured. Decided: `lazy` is compiled
as written, verified through the predicate attribute, reported in the policy
in force, and documented as buying nothing measurable on this build.

Decided: the row is the declaration. `(cache f P)` installs the table for
every arity the engine's `arity/2` records for `f` that the speaking module
or `&self` can see, holds a `function_clauses_changed/1` handler while it
stands so a name defined after its row, or defined again after its space was
dropped, is tabled when the clauses arrive, and its removal takes the row's
tables away while a table a `(tabled ...)` call also asked for reverts to the
default. `untabled` under a standing row refuses, naming the row: taking the
table out while the row stands would put it back at the next clause change.
The reconcile is one predicate answering `seam:cache_policy_changed/1`, which
the engine fires for this library's own `(tabled ...)` reflection rows too,
so it is written to be a no-op on consistent state. A refusal removes the
row before it is raised, so the catalog never carries a declaration that is
not in force.

Tried: the reconcile's re-entrancy flag as `setup_call_cleanup` around the
goal -> a choice point left by the `tabled` call path postponed the cleanup,
the flag stayed set, and every later row was silently ignored; the plunit
suite caught it as a row that landed and did nothing. Decided: `once/1`
inside the guard, and the two clause-selected helpers rewritten as
if-then-else.

Decided: the catalog admits the row through a new argspec `(some-of Vocab)`
rather than a semantics clause, so `(kind cache symbol (some-of cache-policy))`
is self-describing and the one parser, `metta_policy_members/3`, serves the
write door and the compiler. An argument reads three ways and the claims
decide between them: a word, a word applied to the arguments its `takes`
claim declares, or a list of either; `(lattice join)` is one applied member
and not the pair of words `lattice` and `join`, a parametrised word never
stands bare, and a word claimed `alone` (`force`, `refuse`) never shares a
list. The `cache-mode` vocabulary becomes `cache-policy` with `force` and
`refuse` first, so both seats' generated enums rename to `CachePolicy`.

Measured: the class change through the Python surface
(`ai-tmp/cp/measure_monotonic.py`, `m.stats()` inferences, CPU beside, load
average 51). A chain of N links, both twins evaluated once, then five writes
each followed by a point read `(once (reach n0 $y))`:

    N    monotonic write / read      incremental write / read
    50   819 / 863                   763 / 1969..2033
    100  864 / 871                   789 / 3025..3101
    200  898 / 871                   799 / 5137..5211
    400  932 / 871                   809 / 9345..9421

The monotonic read is flat in N and the incremental one grows about 21
inferences per link, so a write moves from O(N) to O(1) for a chain; CPU
read 0.00027 s against 0.00083 s at N=400, advisory on a loaded box. The
first evaluation is dearer under monotonic (24,857 against 18,510 at N=400),
the dependency bookkeeping, which is the price of every later write. The
shared-head suite (`test_shared_head_cost.py`) is unchanged by this work:
nothing here runs per space holding a head.

Measured: the lattice shortest path. Plain evaluation of `(cost a c)` over the
four-edge cycle spends a 200,000-inference budget and raises
`InferenceLimitError`; under `(cache cost (plain (lattice shortest)))` it
answers 2 inside the same budget and the cycle answers itself at 3
[tested: test_a_lattice_table_answers_the_minimum_where_plain_evaluation_loops].

Open: the Node seat classifies control signals by reading the rendered
message (`extensions/node/src/errors.ts`), and a restraint arrives there as a
generic `EngineError` until that classifier learns the word.

Open: a `provenance` carrier will table a polynomial in the answer position;
`metta_tabling_moded_head/4` and the `moded` class of the policy table are
the two seams it extends, one row each.

## 2026-09-07, the probe programs behind the numbers above

Each ran as `swipl -q <file>` in a fresh process on SWI-Prolog 10.1.13, from
the repository root; the Python measurement ran as
`PYTHONPATH=extensions/python python measure_monotonic.py` with the
`.venv-pypetta` interpreter. They are recorded here so the numbers can be
re-taken from a tracked file after the scratch directory is gone.

### probe17.pl: propagation against re-evaluation per storage and table declaration

Generated once per pair of `$dyn` in `monotonic`, `(monotonic, incremental)`,
`incremental` and `$tbl` in `(monotonic, shared)`, `(monotonic, lazy, shared)`,
`(incremental, shared)`, skipping the three pairs SWI refuses:

```prolog
:- use_module(library(tableutil)).
:- dynamic link/2 as incremental.
:- table reach/2 as (incremental, shared).
reach(X, Y) :- link(X, Y).
reach(X, Z) :- reach(X, Y), link(Y, Z).
status(Head) :- ( current_table(user:T, Tr), T = Head, '${tbl}_table_status'(Tr, S) -> format("status=~w", [S]) ; format("status=?", []) ).
main :-
    N = 200,
    forall(between(1, N, I), (J is I + 1, assertz(link(I, J)))),
    statistics(inferences, A0), findall(Y, reach(1, Y), L0), statistics(inferences, A1), D0 is A1 - A0, length(L0, Len0),
    format("dyn incremental table (incremental, shared): first call ~w answers in ~w inferences ", [Len0, D0]), status(reach(1,_)), nl,
    M is N + 1, M2 is N + 2,
    statistics(inferences, B0), assertz(link(M, M2)), statistics(inferences, B1), DB is B1 - B0,
    ( catch(table_statistics(user:reach(1,_), answers, NA), _, fail) -> true ; NA = none ),
    format("  assert cost ~w inferences, answers before call ~w ", [DB, NA]), status(reach(1,_)), nl,
    statistics(inferences, C0), findall(Y, reach(1, Y), L1), statistics(inferences, C1), D1 is C1 - C0, length(L1, Len1),
    format("  next call ~w answers in ~w inferences ", [Len1, D1]), status(reach(1,_)), nl,
    M3 is N + 3,
    statistics(inferences, E0), assertz(link(M2, M3)), statistics(inferences, E1), DE is E1 - E0,
    statistics(inferences, F0), findall(Y, reach(1, Y), L2), statistics(inferences, F1), D2 is F1 - F0, length(L2, Len2),
    format("  second assert ~w, next call ~w answers in ~w inferences~n", [DE, Len2, D2]),
    statistics(inferences, G0), findall(Y, reach(1, Y), L3), statistics(inferences, G1), D3 is G1 - G0, length(L3, Len3),
    format("  repeat call ~w answers in ~w inferences~n", [Len3, D3]),
    retract(link(1, 2)),
    statistics(inferences, H0), findall(Y, reach(1, Y), L4), statistics(inferences, H1), D4 is H1 - H0, length(L4, Len4),
    format("  after retract link(1,2): ~w answers in ~w inferences~n", [Len4, D4]).
:- initialization(main, main).
```

### probe13: the moded-table matrix

Generated once per `$thread` in `shared`, `private` and `$watch` in `plain`,
`incremental`, `monotonic`:

```prolog
:- use_module(library(tableutil)).
shortest(A, B, C) :- ( A =< B -> C = A ; C = B ).
:- ( 'plain' == plain -> dynamic(pedge/3) ; 'plain' == incremental -> dynamic(pedge/3 as incremental) ; dynamic(pedge/3 as (monotonic, incremental)) ).
:- ( 'plain' == plain -> table(ppath(_,_,lattice(shortest/3)) as (${thread})) ; 'plain' == incremental -> table(ppath(_,_,lattice(shortest/3)) as (incremental, private)) ; table(ppath(_,_,lattice(shortest/3)) as (monotonic, private)) ).
ppath(X, Y, C) :- pedge(X, Y, C).
ppath(X, Z, C) :- ppath(X, Y, C0), pedge(Y, Z, C1), C is C0 + C1.
stats(V) :- forall(member(S, [tables, answers, complete_call, invalidated, reevaluated]),
                   ( (catch(table_statistics(V, S, N), _, fail) -> true ; N = none), format("~w=~w ", [S, N]))), nl.
vstats(Head) :- ( user:'$table_mode'(Head, V, _) -> stats(V) ; stats(Head) ).
props(Head) :- forall(predicate_property(Head, tabled(F)), (write(F), write(' '))), nl.
go(Label) :- catch((findall(Y-C, ppath(a, Y, C), L), format("~w: ~w  ", [Label, L]), vstats(ppath(a,_,_))), E, (format("~w: ERR ~q~n", [Label, E]))).
main :-
    write('${thread}/${watch} props: '), props(ppath(_,_,_)),
    assertz(pedge(a, b, 1)), assertz(pedge(b, c, 1)), assertz(pedge(c, a, 1)), assertz(pedge(a, c, 5)),
    go(first), go(second),
    assertz(pedge(a, c, 1)),
    write('after add, before call: '), vstats(ppath(a,_,_)),
    go('after add'), go('after add again'),
    ( user:'$table_mode'(ppath(_,_,_), PV, _) -> abolish_table_subgoals(user:PV) ; true ),
    go('after clear'),
    retract(pedge(a, c, 1)),
    go('after retract').
:- initialization(main, main).
```

### probe7.pl: subsumptive under a watch

```prolog
% Probe 7: subsumptive variants.
:- use_module(library(tableutil)).
:- dynamic sedge/2 as incremental.
:- table sreach/2 as (subsumptive, incremental, shared).
sreach(X, Y) :- sedge(X, Y).
sreach(X, Z) :- sreach(X, Y), sedge(Y, Z).
:- dynamic pedge/2.
:- table preach/2 as (subsumptive, shared).
preach(X, Y) :- pedge(X, Y).
preach(X, Z) :- preach(X, Y), pedge(Y, Z).
stats(V) :- forall(member(S, [tables, answers, complete_call, invalidated, reevaluated]),
                   ( (catch(table_statistics(V, S, N), _, fail) -> true ; N = none), format("~w=~w ", [S, N]))), nl.
try(Goal) :- catch((Goal -> format("OK: ~q~n", [Goal]) ; format("FAILED: ~q~n", [Goal])), E, (format("ERROR ~q: ", [Goal]), print_message(error, E))).
props(Head) :- forall(predicate_property(Head, tabled(F)), (write(F), write(' '))), nl.
main :-
    write('props: '), props(sreach(_,_)),
    assertz(sedge(a, b)), assertz(sedge(b, c)),
    findall(X-Y, sreach(X, Y), S0), format("all: ~w~n", [S0]), stats(sreach(_,_)),
    findall(Y, sreach(a, Y), S1), format("a: ~w~n", [S1]), stats(sreach(_,_)),
    assertz(sedge(c, d)),
    format("after assert: "), stats(sreach(_,_)),
    catch((forall(sreach(a, Y), format("  a->~w~n", [Y]))), E1, (format("forall ERR: ~q~n", [E1]))),
    stats(sreach(_,_)),
    catch((findall(Y, sreach(a, Y), S2), format("a after: ~w~n", [S2])), E2, (format("findall ERR: ~q~n", [E2]))),
    catch((findall(X-Y, sreach(X, Y), S3), format("all after: ~w~n", [S3])), E3, (format("findall-all ERR: ~q~n", [E3]))),
    catch((findall(Y, sreach(a, Y), S4), format("a after all: ~w~n", [S4])), E4, (format("findall ERR2: ~q~n", [E4]))),
    stats(sreach(_,_)),
    % plain subsumptive
    assertz(pedge(a, b)), assertz(pedge(b, c)),
    findall(X-Y, preach(X, Y), P0), format("plain all: ~w~n", [P0]), stats(preach(_,_)),
    findall(Y, preach(a, Y), P1), format("plain a: ~w~n", [P1]), stats(preach(_,_)),
    % subsumptive + monotonic
    try(dynamic(user:medge/2 as (monotonic, incremental))),
    try(table(user:mreach/2 as (subsumptive, monotonic, shared))),
    ( current_predicate(mreach/2) -> (write('mreach props: '), props(mreach(_,_))) ; true ),
    assertz((mreach(X, Y) :- medge(X, Y))), assertz((mreach(X, Z) :- mreach(X, Y), medge(Y, Z))),
    assertz(medge(a, b)),
    catch((findall(X-Y, mreach(X, Y), MR0), format("mreach all: ~w~n", [MR0])), EM0, (format("mreach ERR: ~q~n", [EM0]))),
    assertz(medge(b, c)),
    catch((findall(Y, mreach(a, Y), MR1), format("mreach a after assert: ~w~n", [MR1])), EM1, (format("mreach ERR2: ~q~n", [EM1]))),
    stats(mreach(_,_)).
:- initialization(main, main).
```

### probe8.pl: option conflicts and the tripwire routes

```prolog
% Probe 8: option conflicts, max_answers tripwire routes, module-qualified lattice, untable moded.
:- use_module(library(tableutil)).
:- multifile prolog:tripwire/2.
:- dynamic seen/2.
prolog:tripwire(Wire, Context) :-
    assertz(seen(Wire, Context)),
    format("TRIPWIRE ~q context ~q~n", [Wire, Context]),
    throw(error(my_signal(Wire), _)).
try(Goal) :- catch((Goal -> format("OK: ~q~n", [Goal]) ; format("FAILED: ~q~n", [Goal])), E, (format("ERROR ~q: ", [Goal]), print_message(error, E))).
props(Head) :- forall(predicate_property(Head, tabled(F)), (write(F), write(' '))), nl.
attr(Head, A) :- ( catch('$get_predicate_attribute'(Head, A, V), _, fail) -> format("~w=~w ", [A, V]) ; format("~w=? ", [A]) ).
:- table p/2 as (max_answers(3), shared).
p(M, N) :- between(1, M, N).
:- table p2/2 as shared.
p2(M, N) :- between(1, M, N).
shortest(A, B, C) :- ( A =< B -> C = A ; C = B ).
main :-
    try(table(user:ps/1 as (private, shared))), write('ps props: '), props(ps(_)),
    try(table(user:lz/1 as lazy)), write('lazy-alone props: '), props(lz(_)), attr(lz(_), lazy), attr(lz(_), monotonic), nl,
    try(table(user:lz2/1 as (monotonic, lazy))), write('mono-lazy props: '), props(lz2(_)), attr(lz2(_), lazy), attr(lz2(_), monotonic), nl,
    try(table(user:ma/2 as (max_answers(2), shared))), write('max_answers props: '), props(ma(_,_)), attr(ma(_,_), max_answers), attr(ma(_,_), subgoal_abstract), attr(ma(_,_), answer_abstract), nl,
    try(table(user:sa/2 as (subgoal_abstract(2), answer_abstract(3), shared))), attr(sa(_,_), max_answers), attr(sa(_,_), subgoal_abstract), attr(sa(_,_), answer_abstract), nl,
    try(table(user:pv/1 as private)), write('private props: '), props(pv(_)),
    try(table(user:mq(_,lattice(user:shortest/3)) as shared)), write('mq props: '), props(mq(_,_)),
    try(table(user:bogus/1 as bogus)),
    try(table(user:ma2/2 as max_answers(foo))),
    % max_answers per-predicate: which path
    set_prolog_flag(max_answers_for_subgoal_action, error),
    catch((findall(N, p(10, N), L), format("p answers (flag error): ~w~n", [L])), E, (format("caught: ~q~n", [E]))),
    set_prolog_flag(max_answers_for_subgoal_action, bounded_rationality),
    abolish_all_tables,
    catch((findall(N, p(10, N), L2), format("p answers (flag bounded_rationality): ~w~n", [L2])), E2, (format("caught: ~q~n", [E2]))),
    % global flag
    set_prolog_flag(max_answers_for_subgoal_action, error),
    set_prolog_flag(max_answers_for_subgoal, 3),
    abolish_all_tables,
    catch((findall(N, p2(10, N), L3), format("p2 answers (global flag 3): ~w~n", [L3])), E3, (format("caught: ~q~n", [E3]))),
    forall(seen(W, C), format("seen ~q ~q~n", [W, C])),
    forall(current_prolog_flag(F, V), ( (sub_atom(F, _, _, _, restraint) ; sub_atom(F, _, _, _, max_answers) ; sub_atom(F, _, _, _, max_table) ; sub_atom(F, _, _, _, table_)) -> format("flag ~w=~w~n", [F, V]) ; true )).
:- initialization(main, main).
```

### probe16.pl: the lazy table dumped after an assert

```prolog
:- use_module(library(tableutil)).
:- use_module(library(tables)).
:- dynamic link/2 as (monotonic, incremental).
:- table lz/2 as (monotonic, lazy, shared).
lz(X, Y) :- link(X, Y).
lz(X, Z) :- lz(X, Y), link(Y, Z).
:- table eg/2 as (monotonic, shared).
eg(X, Y) :- link(X, Y).
eg(X, Z) :- eg(X, Y), link(Y, Z).
dump(Label) :-
    format("~w~n", [Label]),
    forall(current_table(user:T, Tr),
           ( '$tbl_table_status'(Tr, S),
             findall(R, get_returns(Tr, R), Rs),
             ( catch(table_statistics(user:T, answers, N), _, fail) -> true ; N = none ),
             format("  ~q status=~w returns=~q table_statistics(answers)=~w~n", [T, S, Rs, N]) )).
main :-
    assertz(link(a, b)),
    findall(Y, lz(a, Y), _), findall(Y, eg(a, Y), _),
    dump('after first calls'),
    assertz(link(b, c)),
    dump('after assert link(b,c), before any call'),
    statistics(inferences, I0), findall(Y, lz(a, Y), L1), statistics(inferences, I1), D is I1 - I0,
    format("lz call ~w in ~w inferences~n", [L1, D]),
    dump('after lz call'),
    statistics(inferences, J0), findall(Y, eg(a, Y), E1), statistics(inferences, J1), D2 is J1 - J0,
    format("eg call ~w in ~w inferences~n", [E1, D2]),
    dump('after eg call').
:- initialization(main, main).
```

### probe18.pl: turning a storage watch back off

```prolog
:- use_module(library(tableutil)).
try(Goal) :- catch((Goal -> format("OK: ~q~n", [Goal]) ; format("FAILED: ~q~n", [Goal])), E, (format("ERROR ~q: ", [Goal]), print_message(error, E))).
dprops(Head) :- forall(( predicate_property(Head, P), memberchk(P, [dynamic, incremental, monotonic]) ), (write(P), write(' '))), nl.
main :-
    try(dynamic(user:link/2 as (monotonic))), write('after as monotonic: '), dprops(link(_,_)),
    try(dynamic(user:link/2 as incremental)), write('after as incremental: '), dprops(link(_,_)),
    try(dynamic([user:link/2], [incremental(false)])), write('after incremental(false): '), dprops(link(_,_)),
    try(dynamic([user:link/2], [monotonic(false)])), write('after monotonic(false): '), dprops(link(_,_)),
    try(dynamic([user:link/2], [monotonic(true)])), write('after monotonic(true): '), dprops(link(_,_)),
    try(('$set_predicate_attribute'(user:link(_,_), monotonic, false), '$set_table_wrappers'(user:link(_,_)))), write('after attribute reset: '), dprops(link(_,_)),
    % does a monotonic table over a now-non-monotonic dyn still work / error?
    assertz(link(a, b)),
    try(dynamic(user:link/2 as monotonic)), write('re-enabled: '), dprops(link(_,_)),
    try(table(user:reach/2 as (monotonic, shared))),
    assertz((reach(X, Y) :- link(X, Y))), assertz((reach(X, Z) :- reach(X, Y), link(Y, Z))),
    findall(Y, reach(a, Y), L0), format("reach ~w~n", [L0]),
    assertz(link(b, c)), ( table_statistics(user:reach(a,_), answers, N) -> format("answers before call ~w~n", [N]) ; true ),
    findall(Y, reach(a, Y), L1), format("reach ~w~n", [L1]),
    % a monotonic table over a storage predicate that is incremental ONLY: what happens on evaluation?
    try(dynamic(user:ilink/2 as incremental)),
    try(table(user:ireach/2 as (monotonic, shared))),
    assertz((ireach(X, Y) :- ilink(X, Y))), assertz((ireach(X, Z) :- ireach(X, Y), ilink(Y, Z))),
    assertz(ilink(a, b)),
    catch((findall(Y, ireach(a, Y), I0), format("ireach over incremental-only storage: ~w~n", [I0])), E, (format("ireach ERR: ~q~n", [E]))),
    assertz(ilink(b, c)),
    catch((findall(Y, ireach(a, Y), I1), format("ireach after add: ~w~n", [I1])), E2, (format("ireach ERR2: ~q~n", [E2]))),
    % a monotonic table over a plain dynamic predicate (neither): error?
    dynamic(user:plink/2),
    try(table(user:preach/2 as (monotonic, shared))),
    assertz((preach(X, Y) :- plink(X, Y))), assertz((preach(X, Z) :- preach(X, Y), plink(Y, Z))),
    assertz(plink(a, b)),
    catch((findall(Y, preach(a, Y), P0), format("preach over plain dynamic: ~w~n", [P0])), E3, (format("preach ERR: ~q~n", [E3]))),
    assertz(plink(b, c)),
    catch((findall(Y, preach(a, Y), P1), format("preach after add: ~w~n", [P1])), E4, (format("preach ERR2: ~q~n", [E4]))).
:- initialization(main, main).
```

### measure_monotonic.py: the class change through the Python surface

```python
"""M1: a monotonic table under a sequence of add-atom calls against the incremental table."""
import sys
from metta import MeTTa

def reach(m, head, space):
    m.run(f"(= ({head} $x $y) (match {space} (link $x $y) $y))")
    m.run(f"(= ({head} $x $z) (let $y ({head} $x $y) (match {space} (link $y $z) $z)))")

def measure(n, writes=5):
    m = MeTTa().space(f"&m1-{n}")
    m.run("!(import! &self (library lib_tabling))")
    m.run("!(bind! &mono-links (new-space))")
    m.run("!(bind! &incr-links (new-space))")
    for space in ("&mono-links", "&incr-links"):
        for i in range(n):
            m.run(f"!(add-atom {space} (link n{i} n{i + 1}))")
    reach(m, f"m1-mono-{n}", "&mono-links")
    reach(m, f"m1-incr-{n}", "&incr-links")
    m.run(f"!(add-atom &metta (cache m1-mono-{n} monotonic))")
    m.run(f"!(tabled (m1-incr-{n} $x $y))")
    with m.stats() as first_mono:
        assert len(m.run(f"!(collapse (m1-mono-{n} n0 $y))")[0][0].children) == n
    with m.stats() as first_incr:
        assert len(m.run(f"!(collapse (m1-incr-{n} n0 $y))")[0][0].children) == n
    rows = []
    for k in range(writes):
        tail = n + k
        with m.stats() as wm:
            m.run(f"!(add-atom &mono-links (link n{tail} n{tail + 1}))")
        with m.stats() as rm:
            m.run(f"!(once (m1-mono-{n} n0 $y))")
        with m.stats() as wi:
            m.run(f"!(add-atom &incr-links (link n{tail} n{tail + 1}))")
        with m.stats() as ri:
            m.run(f"!(once (m1-incr-{n} n0 $y))")
        rows.append((wm.inferences, rm.inferences, wm.cputime + rm.cputime, wi.inferences, ri.inferences, wi.cputime + ri.cputime))
    return first_mono.inferences, first_incr.inferences, rows

for n in (50, 100, 200, 400):
    fm, fi, rows = measure(n)
    print(f"N={n}: first evaluation mono={fm} incr={fi}")
    for k, (wm, rm, cm, wi, ri, ci) in enumerate(rows):
        print(f"  write {k + 1}: monotonic write={wm} read={rm} cpu={cm:.5f}s | incremental write={wi} read={ri} cpu={ci:.5f}s")
```
