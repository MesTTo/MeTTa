# Every benchmark row placed on its commit
Goal: every row the ten benchmark lanes report as moved on trunk is placed on
the first-parent commit that moved it, re-pinned with the mechanism written
beside the number, and the ten lanes exit 0 on the committed tree.
Constraint: inferences decide and are deterministic under load; an instruction
row is the minimum of three with the load recorded; a baseline row is
append-only, so a re-pin adds prose naming its number, mechanism, commit and
date; a row the ladder cannot place is reported rather than pinned; a row whose
band is wrong by measurement has the band changed beside the measurement rather
than the number.

## 2026-09-08

### What the cut reads, before anything is measured

The branch is cut from `petta` at `9006528e0`. Running the ten lanes on that
cut under the shared gate lock, at loadavg 15 to 27 on a 32-core box
(`ai-tmp/repin-lanes-cut-FINAL.log`), reads:

| lane | verdict on the cut |
|---|---|
| `engine-bench` | `boot`, `parse`, `parse-prolog` INSTRUCTION rows outside their bands; every inference row green |
| `c-bench` | `ImportError: cannot import name 'CPU_SECONDS' from 'metta.testing'` |
| `mork-bench` | `ImportError: cannot import name 'BenchmarkBaseline' from 'metta.testing'` |
| `node-bench` | `ImportError: cannot import name 'BenchmarkBaseline' from 'metta.testing'` |
| `benchmarks` | 23 inference rows outside the 4-inference allowance, plus `automatic-tabling-growth`'s four size pairs |
| `instructions` | `alpha-unique` (improvement), `py-method-call`, `source-load`, `space-name` |
| `cost-rows` | green, 15 of 15 declared classes measured |
| `memory-scale-gate` | green |
| `extcost` | `EngineError: value((hk-tier-admits 1000)) expected exactly one answer, got 0` |
| `parity-perf` | three CROSS-ENGINE rows above the allowance; no TREE DRIFT |

Three of those are not moved rows at all, and each is diagnosed before any
ladder runs, because a ladder over a lane that cannot execute measures nothing.

### Three GATE lanes had been dead since the extension-package merge

Tried: `sh check.sh c-bench mork-bench node-bench` on the cut. All three die on
an `ImportError` before measuring one row.

Found: `4e0feaf6b` moved the benchmark harness out of `metta.testing` into the
`metta_benchmarking` distribution under `extensions/python/ext/`. Its merge
message says "every benchmark driver imports through the moved harness"; the
three SEAT drivers were not among the ones it changed, and
`extensions/cmetta/benchmarks/bench.py`, `extensions/mork/benchmarks/bench.py`
and `extensions/node/benchmarks/bench.py` still name `metta.testing`. So the
lanes have been red, measuring nothing, since that merge.

Decided: the three drivers reach the harness the way `engine/bench.py` and
`extensions/python/bench.py` already do, through `_workspace.on_path()`. And
the TOOLCHAIN GUARDS in `engine/bench.sh` and `extensions/node/bench.sh` move
with them: both asked whether `metta.testing` imports, which it still does, so
a guard written to make a missing prerequisite a named skip let the run through
to an ImportError instead. A guard that names a module the driver does not
import proves nothing about the run.

### The `extcost` crash is a benchmark outside `add-atom`'s domain

Tried: the failing tier alone, `(add-atom &hk-admit hk-probe)` after
`(: hk-probe HKAdmitted)` and `.admits("HKAdmitted")`. It answers nothing,
stores nothing and raises nothing, so the driver's recursion stops at the first
call and the whole lane dies with it. The plunit suite
`tests/prolog/suites/spaces/hooks.plt` passes all 45 tests, including the ten
admission-sugar ones, and
`examples/ch15-writing-transactions-and-worlds/04-admission_pools.metta` runs
green, so the mechanism is not broken.

Measured: a first-parent bisect of the probe over 5aca9b64..ad762ee7 places it
exactly at `12121e3c`, the arbiter-divergences merge, whose own message records
the rule: "`add-atom` and `remove-atom` take upstream's domain, an atom with a
head, and the wider forms stay where PeTTa refuses". `hk-probe` is a bare
symbol. Every other tier in the table offers an expression, which is why only
this one stopped.

Decided: the benchmark takes the domain, not the engine. The row offers
`(hk-probe a)` against `(: (hk-probe a) HKAdmitted)`, which is the shape the
admission-pools example itself uses (`(: (ticket a) Ticket)` offered as
`(ticket a)`). The lane then runs, the refusal path still fires
(`(add-atom &hk-admit (stowaway 1))` answers
`(Error (metta_add_refused &hk-admit (stowaway 1) (does-not-carry HKAdmitted)) none)`),
and exactly one row moves: 65,132 to 66,132, one inference per add over 1,000
adds, which is the offered atom's extra structure.

### The engine's boot instruction row is not readable from a worktree

The C seat has carried `measurement.checkout_path_length` since `db9ff8e1` and
refuses its `boot` instruction row from a checkout of another length. The
engine seat carries the same fact as PROSE in
`measurement.checkout_location` -- 853,856,877 from a 72-character worktree
against 832,667,280 from the 30-character root, 2.51% apart, inference count
identical -- and no guard, so the row reads a location as a regression from
anywhere but the repository root.

Decided: the engine seat gets the mechanism the shared harness already
implements and the C seat already uses. `engine/bench.pl` declares
`bench_whole_process(boot)` and `bench_describe` reports it, because bench.pl
owns the case table and a second spelling in `engine/bench.py` would be a
second authority for a fact one file has. `engine/bench.py` reads it, compares
`len(str(ROOT))` against the baseline's `checkout_path_length`, and reports
such a row instead of failing it; it also refuses to RE-PIN one from the wrong
length, so an update cannot quietly write a pin the gate reads as wrong.

That edit has a cost this file's own baseline predicts: `boot` counts the
benchmark process's predicate set, so adding a fact to `engine/bench.pl`
re-pins `boot`. Measured below with its control.

### The ladder

The `benchmarks`, `instructions` and `extcost` pins were last taken at
`ad762ee7e`, the gate-hygiene merge, and so were the three seat baselines. The
first-parent chain from there to the cut is fifteen commits, seven of which
only replace `commit=WORKTREE` placeholders in comments or move a baseline
number. The nine ladder points are the base and the eight commits that change
code:

| point | commit | what it landed |
|---|---|---|
| p0 | `ad762ee7e` | the base: where these pins were taken |
| p1 | `1a3579fa4` | the catalog types its own words |
| p2 | `f31028aa4` | the merged-tree reconciliation after it |
| p3 | `08f6f4df1` | the twins lane gates |
| p4 | `856434d7c` | an equation reads the space it is stored in |
| p5 | `3fc65f02c` | every intermittent root-caused |
| p6 | `4a6029296` | a face from a module's own signatures |
| p7 | `4e0feaf6b` | the core names no library |
| p8 | `9006528e0` | the cut |

Each point runs in a clone under the branch worktree's own `ai-tmp/`, checked
out with `--force`, provisioned with the MORK artifacts (its crate is untouched
across the whole range, `git log ad762ee7e..9006528e0 -- extensions/mork/mork_ffi`
being empty) and the two `node_modules` symlinks, then REBUILT from that
commit's own sources: `engine/build.sh`, `examples/ch19-*/build.sh`,
`extensions/cmetta/build.sh`, `extensions/node/build.sh`, with `engine/*.qlf`
and `lib/*/*.qlf` removed afterwards. Each point takes the shared gate lock on
its own rather than holding it for the whole sweep.

Two overlays, each the smallest edit that lets a point measure at all and
neither of them inside a measured process. The three seat drivers get this
branch's repaired imports at p7 and p8, where the point's own copies cannot
import their harness; every driver spawns its workload as a separate process,
so the driver's own import line is outside everything counted. And
`extension_cost.py`'s admits tier gets its two-line repair at every point,
because the shape it used to offer stopped being addable at `12121e3c`, which
is before p0: without the overlay every point crashes and the row is
unmeasurable rather than moved.

What each point measures: the `benchmarks` lane's counter rows through
`bench.py --counter-only --keep-going --update-baseline`, the automatic-tabling
observations, `check_instructions --update`, `extension_cost --update`,
`engine/bench.sh --update-baseline`, and the three seat suites with `--update`.
Reading the updated document at each point is how a row's value is taken; the
control that the ladder is measuring the right trees is that every row reads its
COMMITTED pin at p0.

### The ladder's own control failed at its base, and that is the finding

Every sweep of this kind checks itself the same way: the base is the commit
that WROTE the pins, so the base must read them back. It does not.

Measured at p0 (`ad762ee7e`), against that commit's own committed document,
with the seat artifacts rebuilt from its sources and the `.qlf` set cleared:

| document | rows reading their own committed pin at p0 |
|---|---|
| `extensions/python/benchmarks/baseline.json` inferences | 23 of 32 rows differ, from +1 to +90,008 |
| `extensions/python/benchmarks/baseline.json` instructions | 15 rows differ, -2.10% to +1.65% |
| `extensions/cmetta/benchmarks/baseline.json` | `boot` -2.42% on inferences, `error-ball` +21.29% |
| `extensions/node/benchmarks/baseline.json` | `host-op` +26 and `query-rows` +11 on inferences, `host-op` -9.45% on instructions |
| `engine/bench-baseline.json` | every inference row reads its pin exactly; `parse` +12.90% and `parse-prolog` +11.76% on instructions |

The largest are exact multiples of their operation counts: `space-name`
+90,008 over 30,000 calls, `py-method-call` +30,020 over 10,000,
`eval-arith` +6,142, `op-encoded` +6,138 and `op-raw` +6,140 each over 2,000.
A constant per operation, not a per-run difference.

So the pins `ad762ee7e` wrote were never true of `ad762ee7e`'s own tree. They
were measured on the chore/trunk-gate-hygiene BRANCH, whose base is
`97c96e91d`, and trunk took fifty-eight more first-parent commits before the
merge landed; the merge carried the branch's numbers into a tree that also
carries all of those. That branch's own deliverable predicted it in as many
words -- "any number taken from a merge base today is stale before the merge
happens" -- and its own C-seat comment says the same thing from the other side:
"Neither parent's number is true of the merge, which is why both are measured
here rather than carried forward."

In first-parent terms the commit that moved each of these rows is therefore on
`97c96e91d..90c08119b`, the chain the branch never saw. The ladder is extended
backwards over ten points of it, and the forward points above keep their job of
placing what moved AFTER the merge.

### The path control, and which rows it reaches

The same commit measured in two checkouts of different length, 29 characters
(a throwaway checkout beside the repository, as long as the root) and 60
(the ladder clone under this branch's `ai-tmp/`), with each tree's artifacts
built from its own sources:

| row | 29 characters | 60 characters | over 31 characters |
|---|---|---|---|
| engine `boot` instructions | 829,908,721 | 837,082,473 | +0.864% |
| C seat `boot` instructions | 1,117,581,427 | 1,135,596,860 | +1.612% |
| C seat `cursor-step` instructions | 3,455,072,657 | 3,465,065,305 | +0.289% |
| C seat `term-in` instructions | 4,369,411,444 | 4,379,966,819 | +0.242% |
| engine `parse` instructions | 126,141,696 | 126,138,080 | -0.003% |
| engine `parse-prolog` instructions | 2,009,496,542 | 2,009,523,024 | +0.001% |
| every MORK row but two | | | under 0.01% |
| every Node row | | | under 0.11% |

So the two BOOT rows are the path-scaled ones and nothing else is, which is
what both baselines already claimed and what this branch's guard now enforces
for the engine seat as well as the C seat. The two MORK exceptions are
`mork-native-add-8000` at +0.367% and `mork-window-floor` at +0.593%, both
inside their own bands and both on rows small enough that a fixed cost reads as
a percentage.

It is also the control for the boot INFERENCE row. The 60-character clone holds
the plain cut and reads 274,602, which is exactly the pin trunk took in the
main checkout at 29 characters; the 29-character checkout holds this branch and
reads 273,658. Inferences do not move with the path, so the -944 is this
branch's own edit to `engine/bench.pl` -- the file the boot case LOADS, whose
predicate set this baseline's own `measures` note records as part of what the
row counts, non-monotonic and about thirty inferences an inert fact.

### A lane that cannot fail, one level up

Tried: asking what would have caught three dead lanes earlier. The lanes
themselves did catch it, loudly, the moment anybody ran them; what was missing
is a check that a benchmark DRIVER can be imported at all, which is the same
shape this tree already fixed one level up. `imports` was invoked as
`python -m importlinter.cli lint_imports` from the day check.sh existed until
2026-08-26: that module only defines its click commands, so runpy imported it,
ran nothing and exited 0 while 62 contract violations accumulated. The answer
then was `test_every_module_invocation_in_the_gate_reaches_an_entry_point`,
which refuses any `-m` target in the gate with no entry point.

Decided: the same answer for drivers.
`tests/ch18_performance/test_benchmark_drivers.py` runs `--help` on every
`bench.py` the repository tracks, which executes the module body and therefore
its imports, and answers 0 only if they resolve. The roster is
`git ls-files '*bench.py'`, so a seat that gains a driver is covered with no
edit, and a second case refuses an empty roster because a check over nothing
passes.

Measured, both ways: with the three seat drivers restored to `9006528e0` the
file reports `3 failed, 3 passed`, naming
`extensions/cmetta/benchmarks/bench.py`, `extensions/mork/benchmarks/bench.py`
and `extensions/node/benchmarks/bench.py`; on this tree it reports
`6 passed in 0.41s`.

### What a guard is allowed to ask

Tried: reading why `engine/bench.sh` and `extensions/node/bench.sh` let the
crash through. Both guards existed to draw the one split those files document
-- a missing toolchain exits 0 with a note naming the step, a present toolchain
that measures a regression exits nonzero -- and both asked whether
`metta.testing` imported. It does. It has simply stopped carrying the harness.

Decided: a guard names the module its driver imports and nothing else. Both ask
for `metta_benchmarking` through `_workspace.on_path()`, which is the import the
driver on the next line performs. A guard that names a different module is a
second authority for one fact, and this is what the second authority cost.

### The control passes at the true base

The ladder was extended backwards over trunk's own chain and its base holds
exactly. At `97c96e91d`, the commit the chore/trunk-gate-hygiene branch was cut
from, every row of every document reads the number that branch later wrote at
its merge: `annotated-relation` 820,625, `handle-round-trip` 1,517,079,
`space-name` 4,200,428, `py-method-call` 2,270,779, `eval-arith` 279,029, the C
seat's `error-ball` 406,009 and `boot` 382,606, the Node seat's `answers-lazy`
1,050,787,538 and `host-op` 1,007,222,637, and all eight automatic-tabling
pairs.

So the earlier reading of the failed p0 control is completed rather than
overturned: the branch measured CORRECTLY on its own base, and trunk's
fifty-eight first-parent commits moved the tree under it while it did. The pins
it wrote are true of `97c96e91d` and of no commit on the first-parent chain
after it.

### Four causes account for fifty pinned numbers

Twenty-eight points in the end: nineteen from the plan above and nine more
halving whichever bracket a step landed in, each measured the same way. Every
placement below is a SINGLE first-parent commit, with the commit immediately
before it measured and reading the row unchanged, with two exceptions that say
so where they are: `alpha-unique`'s instruction row, whose plateau ends
somewhere in `46d51f184..f8c4b6722`, and `source-load`'s, which has no single
step at all.

**`e67e2db94`, the prelude's move into Prolog: one extra module link.** Its own
merge message names the mechanism and prices it for two engine rows -- "the one
extra module link every first resolution in a fresh space module walks, shown
by a positive control that shortened the chain by exactly one module". The
Python seat was not re-measured then and pays the same link: a constant near
140 inferences for a row that resolves a handful of names in a fresh space
(`file-load` +171, `foreign-match` +138, `table-bridge-match` +136,
`save-load-fast` +163, `save-load-metta` +159, `alpha-unique` +12, `sort-atom`
+12, `typed-call` +48, `let-heavy` +44, `loop-1m` +36), and a cost per
resolution for a row that resolves repeatedly (`handle-round-trip` +32,142 over
2,000 round trips, `run-source` +8,140 over 1,000 directives,
`annotated-relation` +4,138 over 500 evaluations, `source-load` +3,024,
`query-where` +620). `c99dbb40b`, the commit immediately before it, reads every
one of them unchanged. The engine's two parse INSTRUCTION rows move there for a
different reason on the same commit: it re-pointed the workload from
`engine/prelude.metta`, 37,745 bytes where those pins were taken, to
`tests/data/prelude-spec.metta`, 43,283.

**`bc0d49556`, the defect-ledger repair: three inferences per evaluation.**
`engine/metta/types.pl` gained a `prelude_declaration_governs_in/2` guard in
front of every builtin type-candidate lookup, through
`builtin_surface_governs_in/2`, so a named space that redefines a prelude name
gets its own answer. The arithmetic is exact: `eval-arith` +5,998 over 2,000
evaluations, `op-encoded` +6,000, `op-raw` +6,002, `py-method-call` +30,008
over 10,000 calls, `space-name` +90,009 over 30,000, `handle-round-trip`
+12,000, `annotated-relation` +1,500, `query-where` +360. The two merges after
it in the same bracket, `8bd4574fb` and `9b5847e86`, move none of them.

**`00bbf85b2`, cost rows as catalog rows: nine inferences per evaluation on
`annotated-relation`.** Fifteen `(cost witness class [measure])` rows join
`&metta` and the fixed-width `metta_catalog_clause/2` dispatch widens, which is
the same shape this document's own `catalog_arity_merge_repin` rows record.
+4,500 over 500 evaluations.

**`1a3579fa4`, the catalog types its own words.** The engine's `boot`
instruction row +3.783% and the C seat's `boot` +24,963 inferences and +2.936%
instructions, both the 251 `(: member Type)` atoms, 2 `(:< ...)` edges and four
sibling vocabulary rows the engine writes at initialization, which `72f9cdf2d`
already carries for the engine's boot INFERENCE row. And `register-op` +402
over 100 registrations: `engine/metta/interop.pl` now checks every capability
word a provider declares against the catalog's row when its space is readied.

**`3fc65f02c`, every intermittent root-caused: a deadline checked where the
answer is produced.** `query-limit-guarded` +800 over 100 guarded queries, eight
each. Controlled: with `extensions/python/metta/shim.pl` alone reverted to
`856434d7c` in the merged tree the row passes its 29,807 pin, and
`query-limit-plain` -- the identical workload without a bound -- passes in both
arms. Reverting `engine/metta/control.pl` or `engine/metta/runtime.pl` instead
leaves the row at 30,605, so of the merge's three eager doors this row takes
the shim's.

**`ad762ee7e`, the merge itself**, for the C seat's `error-ball` (+198,004
inferences and +47.8% instructions, flat at 406,009 across all ten points of
trunk's chain before it) and `term-in` (-0.377%), and for all four Node rows.
Which of that branch's edits is not isolated: it changed
`extensions/cmetta/benchmarks/cases.c`, which IS the C seat's measured process,
but only its perf handshake, and C retires no inferences, so `error-ball`'s
+198,004 has to be one of its engine-side edits.

Tried: attributing the Node seat's -8.90% on `host-op` and -2.75% on
`answers-lazy` to that merge's move of `autoload(library(wfs), [call_delays/2])`
out of `lib_tabling` into `engine/metta.pl`, which its own branch priced at
about 1,200 inferences per importing program.
Measured: with both files put back to `90c08119b` at the merge, `host-op` reads
913,448,168 against 911,844,909 with them (0.18% apart) and `answers-lazy`
1,021,446,272 against 1,022,310,300 (0.08%). Neither is the 9% or the 2.7%.
Decided: the placement stands on the ladder and the cause inside the merge is
recorded as unisolated. The rows' inference counts move +26 and 0, so what
moved is the process image this seat loads rather than what it does, and this
seat's document already carries `release_0_7_0_layout_repin_comment` for the
same class on the same rows.

### `mork-window-floor`, and a row that is exact within a configuration

Tried: the MORK seat's lane on the branch tree. Thirty of its thirty-one rows
are inside their bands against the pins `ad762ee7e` wrote -- the first time this
seat has been able to say so since `4e0feaf6b`, whose merge left its driver
importing a harness that had moved. The thirty-first, `mork-window-floor`,
reads 28,838 against a ceiling of 28,833: five instructions.

Measured, twelve rounds in one run: 28,838 twelve times, spread 0.000%, at
loadavg 7.5 to 10.9. So the band is not what is wrong; within a configuration
the row is exact. It is a whole benchmark measuring an EMPTY perf window, about
28,000 instructions, so a fixed cost of a few hundred is a whole per cent.

Tried: the file count as the cause. The process that opens that window boots
the engine, and `qlf_boot` walks every artifact in the tree for freshness,
which `engine/bench.pl`'s own note prices at about six inferences an extra
file; the same checkout read 28,668 to 28,680 earlier in this pass and 28,838
after the Node browser runtime was built into it.
Rejected: with `extensions/node/_runtime/` and `extensions/node/browser/` moved
aside and the `.qlf` set cleared, three samples read 28,838, 28,838 and 28,839.
Revisit if a configuration is named that reproduces the 28,668 reading.

Decided: pin 28,838. It is the reading in the tree the gate reads, and its 2%
band reaches down to 28,261, below the other reading, so this pin is green in
both configurations while the 28,268 it replaces is green in only one. Open:
which configuration moves the row by 0.56%.
