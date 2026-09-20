# The plan becomes visible
Goal: `(explain (match ...))` names the join the matcher runs, a host door
answers the same atoms and can measure the query it explains, and a workload's
own call counts propose the cache rows they would justify without writing one.
Constraint: `match_conjunction/4` keeps exactly its behaviour and its cost; the
plan item follows the ROUTE rather than the query's shape; every proposal is
measured rather than argued.

## 2026-09-07

Found first, by probe, that the plan is the data: `native_conjunction_plan/4`
built the per-conjunct tries as part of deciding whether to use them, so
nothing could ask which join would run without paying for the join. The
admission gate splits into two halves that are not alike:

- the QUERY half, decided from the conjunct list plus the one-candidate probe
  the executor already makes (arity, flatness, incidence cycle, GYO cyclicity,
  the variable order, the column map). Constant in the data.
- the DATA half, `ground(Rows)` and `acyclic_term(Rows)` over each conjunct's
  projected candidate rows. Linear in the data, and it is a real gate: a space
  holding one stored `(edge $a $b)` beside three ground rows answers the
  triangle through the nested loop, which a probe confirmed before any of this
  was written.

Measured, over a two-out-degree ring, `PYTHONPATH=extensions/python
$VENV/bin/python ai-tmp/aa_probe13.py` at loadavg 62, SWI inferences:

| stored rows | query half | + data half | full plan with tries | whole explain door | the query itself |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 128 | 248 | 682 | 6,272 | 1,588 | 15,705 |
| 512 | 248 | 1,834 | 24,130 | 2,740 | 60,059 |
| 2,048 | 248 | 6,442 | 95,556 | 7,350 | 237,473 |

The query half is flat at 248 across a sixteenfold change in data, which is the
`O(conjuncts x arity)` the design claimed. The whole explain door, ten route
items and the plan and the materialization row together, is 10.1%, 4.6% and
3.1% of running the query, and the share FALLS as the data grows because the
tries and the traversal are what the door does not pay.

Decided: `native_conjunction_shape/4` is the query half, `join_rows/5` is the
data half AND the scan the trie build consumes, and
`native_conjunction_rows_admit/3` asks the data half without sorting or
building. The executor's work is unchanged: one `findall` per conjunct, the
same ground and acyclic tests, the same `msort` and trie. How the matcher and
the explain door both reach the shape without either re-deriving the other's
guards took a second pass, below.

Tried: one predicate holding the whole route decision, guards included, called
by both `match_conjunction/4` and the explain door, so nothing at all was
spelled twice. Rejected: its call FRAME costs +1 SWI inference per conjunctive
match whether or not planning is on, `direct-join` issues five of them per
sample, and the benchmark harness allows four
[source: extensions/python/metta/benchmarking.py, _COUNTER_TOLERANCE]. Measured
min-of-five on a 64-edge chain: 3,253 against the control's 3,252 with the
predicate, 3,252 against 3,252 without it. Decided: the two cheap guards, the
caller's extent and `cyclic_join_planning_enabled/0`, stay at the two call
sites and `native_conjunction_shape/4` takes the whole pattern, so what is
spelled twice is a CALL of one shared predicate and never a rule, and the law
test exercises the pragma-off case that a drift would break.
`native_conjunction_plan/4` is gone with the change: its two lines ARE the call
site now, and leaving it standing would have been a third name for one
decision. The completed join benchmark then moves by +4 to +6 inferences on the
PLANNED path only, flat across every size of all four families, and by zero
everywhere planning is off.

Rejected: making the query half complete by moving the ground test into it.
The executor would then scan twice per conjunct, once in the shape and once in
`findall`, which is +6.7% on the plan build at 2,048 rows and lands on the join
benchmarks. Revisit if the shape and the build are ever fused so the shape can
hand its rows on.

Rejected: a groundness flag maintained at the write funnel, which would make
the data half `O(1)` at plan time and give explain a constant cost. It costs a
`ground/1` and an `acyclic_term/1` on `add_sexp_in/4`, the hottest write path
in the engine, so it moves pinned inference rows across the benchmark suite for
a diagnostic door's benefit. Revisit if the planner grows a second consumer of
the same fact, or if explain becomes something a program runs per query rather
than a developer runs once.

Rejected: reporting `generic-join` from the query half alone. It is cheap and
wrong: the non-ground-row case reads the plan one way and runs the other, which
is the exact failure the self-honesty law exists to catch.

Decided the law's exact statement, because the obvious phrasing is false: a
PLANNED mode, `generic-join` or `empty-factor`, appears exactly when
`native_conjunction_answer/1` runs, and `nested-loop` exactly when it does not.
An empty factor IS a plan; it answers the empty bag through the same predicate
from a single zero-count leaf. The test counts that predicate's calls through
`wrap_predicate/4` over five configurations (planned, pragma off, non-ground
row, empty factor, single pattern) rather than reading a flag the engine sets,
because a flag would be the engine agreeing with itself
[tested: native_generic_join:the_plan_says_generic_join_exactly_when_the_planned_join_runs].

Tried: reporting source order in the `nested-loop` plan's `(order ...)`.
Rejected: `match_relational_conjuncts/5` hoists a conjunct that matches at most
one row, so source order is a lie whenever the hoist fires. Decided: the item
names the conjunct the matcher LEADS WITH, from `cheapest_conjunct/6` itself,
and says nothing about the levels below it, which are re-chosen under the
bindings above them and cannot be known without running the join.
`cheapest_conjunct/5` gained an output argument rather than a wrapper: a
wrapper is one extra frame per join level, and the argument is free.

Found while wiring `analyze=`: the engine's effect walk classifies EVERY match
as `oracleIO`. `metta_semantic_effect(match, writesState)` is there because
resolving a named space may create its execution module, and a variable-headed
template such as `($x $y $z)` answers `<dynamic-operation>-oracleIO` because
the walk cannot resolve it. Gating on the composed effect refused every query
the door exists for. Decided: the guard reads past those two rows and refuses
on any operation the engine can NAME, which catches the case that matters,
`(match &s (edge $x $y) (add-atom &s (seen $x)))` naming `add-atom`, because a
match template is evaluated once per answer. Measured before deciding: that
template really does write, three `(seen ...)` atoms for three edges.

Decided `Explanation` spells the full item list `.atoms` and not `.items`.
`Mapping.items()` is Python's pairs view and shadowing it would be a trap the
first caller falls into; and the two are not redundant, because a head can
repeat, an operation registered at two arities answering two `(op ...)` items
where the mapping keeps the last.

Found the `profile_extension(names=)` defect's real cause. The host read a
head's name back out of the way Prolog prints a predicate, and every compiled
MeTTa head is written `'$metta_exec:&pyspace_1':'aa-fib'/2`: a quoted module
atom carrying a colon, which the pattern stripping an unquoted module prefix
read as part of the name. Decided: the profiler knows the parts, so
`metta_py_profile_rows/4` sends `name` and `arity` as their own columns and
nothing re-parses Prolog syntax. It sends `recursive_calls` with them, from the
`<recursive>` caller SWI keeps a head's own recursion on, which the node's
`call` count does not include and which no host door could reach.

Measured on `(aa-fib 12)` through `(aa-twice 12)`: uncached, `aa-fib/2` reads
`calls=2` with 6,384 recursive calls; under the automatic memo it reads
`calls=13, recursive=0`, one entry per distinct argument, because a hit never
reaches the predicate. So a memoised head's profile counts its MISSES and the
hit ratio is a property of the PAIR of runs. The advisor measures both
configurations for that reason, and neither run alone carries the number.

Measured, and it decided the advisor's shape: profiling perturbs the inference
counter by about seven times, 20,538 plain against 145,284 profiled on the same
workload. So a configuration cannot be counted and profiled in one run. Each
configuration runs the file list TWICE, plain then profiled, in the same order,
so the warm-up each pays is the same and the difference between configurations
is the row's.

Decided: a what-if runs the WHOLE workload rather than only the files the head
appears in, and sums the inferences of those files afterwards. A corpus run in
one process carries state between files, and
`examples/ch18-performance/18-02-memoisation-and-tabling/12-tabling_statistics.metta`
reads the table counters the files before it left, so a subset changed what
those files cost for a reason that was not the row's.

The advisor's controls, `sh tools/check.sh memo-advisor-selftest`: a pure head called
1,000 times over three distinct arguments is proposed as `(cache weigh force)`
and measured at 3,644,672 inferences before and 165,016 after, a delta of
3,479,656 and a 99.7% hit ratio; a head declared `oracleIO`, called 300 times
and declined as not recursive exactly like the first, is never proposed; a
workload that calls no compiled head is refused by name.

The advisor's first run over `bench`, the memoisation chapter, is
`sh tools/check.sh memo-advisor`: 16 compiled heads called, the default eight
candidates, and six rows proposed, every one of them measured as a LOSS.
`(cache import_prolog_functions_from_file force)` at -24,893 inferences,
`(cache tabled force)` at -6,339, `(cache twohop force)` at -3,215,
`(cache reach force)` at -2,817, `(cache pick force)` at -279 and
`(cache shipping-cost force)` at -5, each with a 0% hit ratio. That is the
advisor working rather than failing: the chapter's heads are called with a
distinct argument every time, so a table is pure overhead there, and the report
says so instead of proposing on a call count alone. Five of the six deltas
reproduce to the inference across separate lane runs, and the sixth moves by 4
in 24,889, which is the workload's own file-order state and not the row's. `fib/2`, the most-called
head at 59, is not proposed at all: the memo declined it `explicit-tabling`,
because the program already wrote `!(tabled (fib $N))` and a second cache
substrate over SWI's own table is not a thing to advise.

The advisor over a real chapter of the corpus, which is the run worth reading:
`--workload examples/ch07-control-flow --candidates 3`, 29 compiled heads.
`(cache expand-once force)` is proposed and MEASURED at 1,507,858 inferences
before and 52,232 after, a delta of 1,455,626 and a 100% hit ratio, with the
verdict WRITE IT. Beside it, `(cache fib refuse)` on the automatically memoised
`fib` measures 30,532 against 39,056,516: refusing that memo would cost 39
million inferences, so the automatic decision is earning its keep by a factor
of 1,279 and the report says so with a number rather than by leaving it out.
One file, `07-05-recursion/04-fibsmartimport.metta`, is reported as raising: its
`import!` names a sibling relatively and the advisor runs a program's TEXT, so
the file's own location is not there to resolve it.

Found, and it decided which door the advisor runs a workload through: a
declared `(cache Fun force)` row reaches a program run as TEXT and does NOT
reach the same program loaded from a file. Measured on the pure-head plant,
`ai-tmp/aa_probe23.py`: 3,644,665 inferences plain and 163,147 under the row
through `run`, against 3,643,544 and 3,647,714 through `load`. Tried `load`
first, because it carries the file's location and fixes the relative `import!`
above; rejected, because an advisor whose what-if cannot apply the row it is
pricing measures nothing, and the selftest's plant caught it immediately, the
proposal falling from +3,479,656 to -4,239 with `distinct_calls` reading 1,000
where it should read 3. The asymmetry itself is left open below.

Decided the default workload is the memoisation chapter rather than
`18-01-larger-workloads`. Every configuration runs the whole workload, and one
file of the larger set costs 21 s on its own, so nine configurations of it is
not a lane.

Found while checking the benchmark pins: a source load costs +3 SWI inferences
for every predicate NAME this branch adds where the load path can see it, once
per load and never per form. Measured on the control by exporting two inert
facts from `spaces` and changing nothing else: 235,121 against 235,127, exactly
the -6 that reverting this branch's two `spaces` exports recovers. Eight new
names, `spaces` +2, `materialize` +1, the engine module +3, the shim +2, is
+24 on `source-load` and +2 on five smaller rows, and the mechanism is
`current_predicate/1`'s enumeration: `system:current_predicate/1` redos,
`assoc:get_assoc/3` and `system:'$btree_find_node'/5` each rise by exactly 8
between the two trees, and nothing else in the whole profile moves.
`sh tools/check.sh benchmarks instructions` is red on BOTH trees with the same 22
failures, `direct-join` reporting the identical `[121145, 121139, 121139]`
against a pinned 121,099 in each, so the pins at this base predate the branch
and the +24 rides on a lane already red by +205 on that row.

Rejected: shrinking the count by inlining the shared helpers back into their
callers, which is the duplication this whole change removes. Revisit if a
future measurement shows the enumeration on a path that runs per form rather
than per load.

Open: a `(cache Fun force)` row reaches a program run as text and not the same
program loaded from a file, measured above. Which door is right is an engine
question this thread did not settle; the advisor uses the one that honours the
row and says so.

Open: the advisor's run over the whole `examples` corpus is minutes of work per
configuration and is not the lane's default; the numbers for it are taken by
hand. Open: `explain` costs one scan per conjunct because the ground admission
is a property of the data, and the catalog fact that would make it constant is
rejected above rather than solved.
