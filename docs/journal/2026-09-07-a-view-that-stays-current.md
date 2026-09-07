# A view that stays current
Goal: make a query's answer something a program HOLDS rather than something it
keeps asking for, kept current by the space's own committed writes, with the
maintenance visible and costed and the door unchanged when delta propagation
from tokens replaces the recompute underneath.
Constraint: upstream PeTTa is the semantics arbiter, so nothing here changes
what an answer IS; a view answers exactly what `match` answers, and the three
strategies are three ways to keep that true.

## 2026-09-07

Decided: the view's state is a multiset of ROWS, keyed by the query's own
column names as the engine names them. `LiveView` keyed by atom, which only
works for one pattern; a conjunction answers a row across several atoms and a
call answers values. One key, one set of reads, and the atom face is derived
where the query has one atom.

Tried: keying a row by the engine's answer values as they arrive -> the same
stored atom produced two keys. `(rule $x)` seeds as `Row(y=$_1)` through
`match` and arrives on its removal event as `$_2` through the directional
`_match`, because the engine names a fresh variable per answer and `_match`
names it after the stored atom's own. Decided: canonicalize a value that
carries variables, which `_canonical` already does for `PatternMap`, and count
how many held rows are not ground while doing it, because that count is what
makes the removal fast path sound.
[command=extensions/python/benchmarks/probes/live_view_cost.py --naming]

Decided: the removal fast path is "the removal's pattern is ground AND the view
holds no non-ground answer AND the row is held", replacing `LiveView`'s scan of
its held atoms for one that unifies. With every held answer ground, only the
named atom can have left. The engine refuses to store a bare variable at all
(`Arguments are not sufficiently instantiated`), so there is no atom that could
be taken but not held.

### The boundary the engine had and Python could not see

Tried: recomputing a conjunction view inside the subscription callback, once
per event -> correct, and wasteful in a way that shows on a transaction. The
whole diff is already applied and committed when the segment's FIRST event is
delivered (`observation_commit` dispatches after `nb_setval` clears the frame),
so events 2..n of a transaction re-answer an unmoving state and produce empty
diffs.

Rejected: detecting the boundary in Python from the outermost engine crossing
returning. It is a superset of a segment, so one `m.run` holding two
transactions would report one boundary; and it would need every write door
bracketed. Revisit if the engine ever dispatches a segment across two
crossings, which it does not.

Decided: the engine announces it. `seam:segment_committed/1` is a new EVENT
extension point carrying the sorted space names the segment touched, called
once per committed segment after every one of its atom events has been
dispatched, on the failing path too, because the writes committed whatever a
subscriber did with them. `observe/3`'s unscoped branch announces a segment of
one. Guarded twice so an unwatched tree pays nothing: the space list is built
only when `segment_committed/1` has a clause, and the Python shim installs that
clause only while some consumer asked for boundaries and crosses only for a
segment touching a subscribed space.

Tried: `runtime.must("metta_py_segments(Enabled)", Enabled=True)` with the
Prolog side testing `Enabled == true` -> the clause was never installed and no
boundary ever arrived, silently. A Python bool crosses janus as `@(true)`,
which the shim's own capture flag already tested for. Fixed at the test.

Measured: with the seam in place, one unscoped add announced at generation 1, a
two-atom transaction announced ONCE at generation 3 after both events, a
removal at 4, a rolled-back transaction announced nothing, and a write to an
unwatched space announced nothing.

### What the refusal could actually stand on

Tried: the design's refusal as written, "a query whose effect plan is not
read-only" -> it refuses every real query. The engine classifies `match` itself
as writesState (resolving a named cast space may create its execution module),
so a tabled call over a body that matches a space answers `oracleIO` and a
bare `(person $n $a)` answers `pureStructural`. A join-level gate would admit
only queries that read nothing.
[command=extensions/python/benchmarks/probes/live_view_cost.py --effects]

Decided: ask the effect plan about the query's OWN HEAD. `(add-atom &kb x)`
names `add-atom` at writesState in its operations list; `(alert $l)` in a space
that also defines `(= (alert $x) (println! $x))` names `println!` and NOT
`alert`. So the head test refuses the category error -- a call written where a
pattern belongs, which would answer nothing for as long as it stood -- and
admits the shadowed data head, whose view is a match and has no effect at all.

Decided: the `tabled` strategy does not consult the effect plan, because the
`incremental` policy requirement is a stronger statement about the same body:
lib_tabling only installs an incremental table when it resolved every read to a
watchable native space predicate. A policy without `incremental` is refused
naming the policy, because `monotonic` propagates without invalidating, `plain`
watches nothing, and `lattice` and `subsumptive` are refused a watch on this
SWI, so the counter the strategy watches never moves under any of them.

### Cost

Measured 2026-09-07 at loadavg 92-104, engine inferences (deterministic;
wall clock on this box is not), minimum of three, relations of 10, 100 and
1,000 rows. `command=extensions/python/benchmarks/probes/live_view_cost.py
--costs`; fixture=a ring of `(edge n_i n_i+1)` plus `(weight n_i i)` with a
tabled `(probe-total)` over the maximum weight.

| measurement | 10 | 100 | 1000 |
|---|---|---|---|
| `pattern`, touching write | 88 | 90 | 90 |
| `heads`, touching write | 167 | 445 | 3173 |
| `heads`, untouching write | 91 | 91 | 91 |
| `heads`, transaction of ten | 1011 | 1307 | 4035 |
| `tabled`, invalidating write | 1163 | 1696 | 7096 |
| `tabled`, table stays valid | 563 | 563 | 563 |
| recompute per event, touching write | 149 | 425 | 3153 |
| recompute per event, transaction of ten | 1524 | 4284 | 31564 |
| a bare subscription that does nothing | 90 | 90 | 90 |

Reading: `pattern` costs what delivery alone costs and does not move with the
relation, where the recompute it replaces is O(n); the class change is the
point, and 90 against 3,153 at a thousand rows is what it looks like. `heads`
pays the same re-answer as that consumer for ONE touching write -- it is that
recompute -- and wins on the commit, 4,035 against 31,564 for ten writes in one
transaction, and pays 91 flat for a write its heads do not name. `tabled` costs
more than `heads` per invalidating write, because the engine re-evaluates the
aggregate through the table, and buys the case `heads` cannot have: it watches
the WHOLE space and lets the engine's own counter filter, so a write that
leaves the table valid is 563 at every size.

Tried: measuring the recompute baseline as `sp.match(...).rows` outside a
callback -> 5 inferences for a 1,000-row join, and flat. Two reasons, both
worth writing down: `Answers.rows` is another LAZY view, so a discarded `.rows`
reads nothing; and a cursor opened outside a callback runs on its own engine,
which the home engine's counter does not see. The baseline is a subscription
whose callback does `list(sp.match(...))`, which runs on the home engine inside
the write exactly as the view's own re-answer does.

Tried: `(table-stats <call built as an atom>)` through `eval` before lib_tabling
was imported -> `(table-stats 3)`, the call reduced and the form left standing.
With lib_tabling loaded both the built atom and the source form answer the
counters, and a bound call answers the same row as an all-holes one, because
the counters are the sum over the head's tables. So `_call_spelling` exists for
the head-and-arity spelling the declarations want, not because the atom form
fails. [command=extensions/python/benchmarks/probes/live_view_cost.py --forms]

Decided: `LiveView` becomes the one-pattern atom face of `Live` rather than a
second maintenance loop. Two classes maintaining one multiset is two mechanisms
for one thing; the Node seat keeps its own `LiveView` and the Python name and
surface are unchanged.

Decided: the segment watch is installed lazily for a `pattern` view, only while
a `changes()` stream is open, so a view nobody reads deltas from costs what
`LiveView` cost before: 88-90 inferences per event against a bare
subscription's 90. `heads` and `tabled` install it at construction, because
they recompute at the boundary and it is not optional for them.

### What the seam costs the benchmarks

Tried: the committed benchmark ledger against a pristine control at the same
base (`git worktree add --detach ... 70ac99da`, `sh check.sh benchmarks` in
each) -> twenty benchmarks fail on BOTH, with the same overruns, so the ledger
is stale at this base and not something this branch did. Joining the two runs
by benchmark name, eighteen of the twenty observe the same inference count to
the digit; two do not: `source-load` +15 (235,240 to 235,255) and `space-name`
+1 (4,200,428 to 4,200,429).

Tried: attributing the +15 to the write path, by reverting `engine/ext_points.pl`
to its base version with everything else in place -> still 235,255. By removing
the `live-strategy` catalog preset -> still 235,255, though THAT is the whole of
`space-name`'s +1, which is one more `metta_catalog_preset/1` row to read. By
reverting `extensions/python/metta/shim.pl` alone -> 235,240, exactly the
control.

Decided: the +15 is the shim's PREDICATE-SET LOAD structure and not any per-write
or per-query cost. `source_load_case` boots an engine inside its measured region,
so it prices what the shim loads, and the ledger has priced this same class twice
before: "+23 arrives with the batch shim's predicate additions ... the moving part
is the predicate-set load-structure class" and "+6" for `metta_py_drain_many`
[source: extensions/python/benchmarks/baseline.json, the source-load comments
dated 2026-09-01]. The probe that isolates it: base shim plus the single line
`:- dynamic metta_py_segment_hook_ref/1.` and nothing else already reads 235,243,
+3 of the 15.

Measured again after the `delta-kind` vocabulary joined `live-strategy`: the
same twenty benchmarks fail on both trees, and against the control the only
differences are `eval-arith` +2 and `op-encoded` +2, one `metta_catalog_preset/1`
row each read per boot, and `source-load`'s +15. The instruction ledger reads
the same SIX cases outside the band on both trees, so nothing this branch does
moves an instruction pin.

Decided even so: the unscoped write keeps its DIRECT dispatch and the boundary's
catch frame is set up only when a handler exists, because a per-write cons cell,
catch and two-step recursion for a handler that is not there is a cost on the
engine's own write path whether or not this suite has a benchmark that would see
it. Neither guard moved any of the twenty numbers, which is why they are argued
from the mechanism rather than from a measurement.

### The view is its own module

Tried: `Live`, `Delta` and `Changes` in `metta.structures` beside the stores,
which is where the plan of record put them -> the `structures-dispatch`
instruction pin went from 593,464,324 to 597,039,924, +0.60%, past a band of
1% that earlier work had already spent half of; the pristine control reads
593,515,850 and is INSIDE. The benchmark measures importing the module, and
950 lines of class bodies is what they cost to build.

Tried: reducing that in place. `@dataclass(frozen=True, slots=True)` without
`slots` accounts for 207,589 of it; a lazy `metta.results` import accounts for
none, and neither does the `metta.vocabularies` import (base `structures.py`
plus `from .vocabularies import SubscriptionEdge` reads 593,474,696, the
control to within noise). The rest is the definitions themselves.

Rejected: re-pinning the baseline with the mechanism recorded. The number is
deterministic and the ledger has that door, but the question the benchmark was
asking is a real one: a program that wants `PatternMap` should not pay to build
a live view.

Decided: `metta.live` is its own module, and `metta.structures` reaches it only
when a `LiveView` is made. `structures-dispatch` then reads 593,363,311, inside
the band and below the control. `Live`, `Delta` and `Changes` are published
from `metta.live` alone rather than re-exported, because a second name for one
thing is what the ladder refuses; `metta.structures` keeps `LiveView`, which is
that module's own one-pattern atom face and what the engine's atom-hook comment
names. The reference page follows the module, so `website/reference/metta-live.md`
is where the three classes are documented.

Tried: the clock and the per-event generation on every delivery ->
`subscription-dispatch` 50,300,906 instructions against a base of 49,752,551,
+1.10%, past its 1% band. The lock in `_SegmentClock.tick` is 350,189 of it and
the per-fold `object.__setattr__` 198,166.
Decided: both are free when nothing watches. `tick` answers 0 while the watch
list is empty and the attribute is written only for a nonzero generation, which
reads 49,845,381, inside the band. The clock therefore stands still while
nothing is watching, which is the honest contract anyway: with no watch there
is no consumer to be current to.
[command=python -m benchmarks.check_instructions subscription-dispatch
structures-dispatch --rounds 3]

Open: a `progress` delta is emitted at every boundary the generation advanced
past, including a commit on another watched space. That is Materialize's own
reading (progress is about time, not about your data) and it is what makes
"you are current as of g" true. If the buffering it causes on a busy engine
becomes a problem, `segment_committed/1` already carries the touched spaces and
the filter can move into the callback without changing the door.

Open: the substrate reading of section 21.1 replaces the `heads` strategy's
recompute with delta propagation from tokens, behind this same door and this
same `Delta`. Nothing here should have to move for it.
