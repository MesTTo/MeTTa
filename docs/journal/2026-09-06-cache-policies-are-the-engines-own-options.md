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
