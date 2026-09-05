# Landing the query-planning branch on trunk
Goal: replay the 22 query-planning commits onto the current trunk, resolve every
overlap by reading both sides, and re-establish the evidence on the tree that
ships.
Constraint: no `git stash`; every hash an evidence tag or a comment names must
resolve on the lineage that lands; the suites and the benchmark rows are
re-measured on the replayed tree rather than carried over.

## 2026-09-06

Tried: three replays, because trunk moved twice while this ran. The 22 commits
landed on `50f21419` with five conflicting regions, then on `f2946e17` after
trunk gained three, then on `ad711777` after it gained sixteen more.

Tried: the third replay, expecting the same fight. It had no conflict at all.
Trunk's 16 commits touch 25 files and share only two with this branch,
`CHANGELOG.md` and `tests/prolog/layering.pl`, and in `layering.pl` the two
edits are in different regions: trunk's `8ec7de24` moved
`metta_ensure_source_observation/0` out of a load-time directive and into
`measure_layer_edges/0`, while this branch added `materialize` to the declared
tangle and nine `reaches/3` rows below it. A clean auto-merge of a file two
authors edited is worth checking rather than trusting, so both callers were
run: `swipl -q --on-error=status -g layering_gate -t 'halt(0)' layering.pl`
from `tests/prolog` exits 0 with 929 cross-subsystem calls over 80 contract
lines, which is trunk's own 874 over 71 plus exactly the nine rows this branch
adds, and `suites/seams/layering.plt` passes its 7.

Tried: re-reading the identity twin's re-pin comment against the tree it now
sits on. The comment claimed "the MeTTa side is unchanged either way",
borrowing a sentence from the two paragraphs above it where it was a control: a
row that counts engine clause layout moves without the work moving, and an
unchanged MeTTa side is what says so. Measured: 2291 on `ad711777` and 2357
here, min-of-3 in fresh processes with the `.qlf` set rebuilt on both arms,
identical across repeats. The claim was false.

Tried: attributing that +66 by sweeping the branch's own commits in a
provisioned base worktree, rebuilding the `.qlf` set at each one
(`twin_coverage.py --measure --rounds 3` on
`examples/ch05-equations-and-evaluation/05-01-an-equation-is-a-rewrite/01-identity.metta`):
2291 at trunk, 2291 after the Generic Join dispatch, 2298 after folding, 2298
after the extent argument, 2310 after the metadata index, 2764 where
materialization is introduced, 2523 after preparing once per completed load,
2451 after the pragma, 2357 after charging the source doors only when a program
has asked. So +7 folding, +12 metadata, +47 left of materialization, and the
comment now states that instead of denying it. The budget itself does not move,
3422 before and after, so this was a correction rather than a re-pin.

Decided: pin the benchmark attribution to commits rather than to the tip. The
same sweep over nine rows says the three gates take materialization to zero on
every row but `save-load-fast`, where +20,044 of its fast-cache half survives,
and that the residue elsewhere sits inside the +-2 a row moves by whenever the
engine's predicate count changes at all: `foreign-match` read 784,863, 784,865
and 784,867 across commits that cannot touch it.

Tried: the full Python suite on the replayed tree. One run in several failed
`test_variadic_doors.py::test_an_abandoned_future_warns`, which passes alone
and passes with its own file. The test asserted that NO abandoned-future
warning was raised while it deleted a future it had waited on, but
`gc.collect()` reclaims every unreachable object, so a future another test in
the same xdist worker dropped into a reference cycle is finalized inside the
same `catch_warnings` block and its warning lands in the same record.

Tried: proving that rather than calling it an intermittent. Planting one
un-waited `FutureSpace` in a reference cycle and then running the test body
verbatim reproduces it every time, and names the culprit: the record holds
`FutureSpace &future-1 was abandoned` while the test deleted `&future-3`. Both
halves now read the record by the name of the future their own block deleted,
which is in the warning text already. Six test files spawn futures and
`--dist loadfile` can put several of them on one worker, so the negative half
was contaminable by any of them and the positive half satisfiable by any of
them.

Open: trunk carries fifteen benchmark rows that exceed their own pins, which
`22ce91dd` records as deliberate. This branch moves three more and moves no pin.

Tried: attributing the other suite failure,
`test_shared_head_cost.py::test_a_first_evaluation_costs_the_same_in_every_space`,
which failed two of three full runs here and one of three on `ad711777`. A
directory sweep makes it deterministic: `pytest tests/ch14_seeing_your_program
tests/ch18_performance/test_shared_head_cost.py -n 0` fails on BOTH trees with
the same slope, 3,744 inferences per space here and 3,746 there. Bisecting the
directory reaches one test,
`test_lint.py::test_an_annotated_arrow_is_diagnosed_like_its_plain_twin`, and
bisecting that test's body reaches one line of it: a live annotated arrow
declaration. `(: h (-[det]-> Number Number))` in any space, `&self` or a child,
makes every later first evaluation of a shared head cost
`[17550, 19269, 23000, 26728, 30468, 34206, 37926, 41650]` over eight spaces;
`(: h (-> Number Number))` in the same place leaves it flat at
`[17554, 15451, 15475, ...]`, and dropping the holding space restores flat. The
effect class does not matter, `det`, `semidet` and `nondet` all do it.

Decided: the slope is per call rather than per reduction, because it is 3,707,
3,718, 3,729 and 3,742 at evaluation depths 4, 8, 12 and 16, and it is linear
in spaces, 3,734 with 4 rooms and 3,729 with 16.

Tried: SWI's own profiler around the second and the eighth room's first call in
one process. The work that grows is `metta_host_goal_effect_plan/4`, 1 call to
7, with `metta_operation_effect/2` 13 to 85, `metta_declared_effect_classes/2`
64 to 136, `spaces:match_stored/4` 44 to 212 and
`spaces:metta_catalog_ref_erased/1` 38 to 218.

Decided: the owner is `memo_refuse_compiled_arrow_effect/1`,
`lib/lib_memo/lib_memo.pl:362`, from `c455fdc4`. Its guard is
`metta_annotated_operation_effect(_, _)` with both arguments unbound, which is
an "any annotated arrow exists anywhere in this process" test rather than a
question about the name being compiled, so one live annotated declaration turns
the body on for every compiled memoized name. The body then walks
`memo_state_modules(Cached, Modules)`, every module where that name is
memoized, and `memo_compiled_operation/3` computes a full host goal effect plan
in each, so the cost is O(spaces holding the head) per first evaluation. That
is the shape `22ce91dd` removed from three other mechanisms.

Tried: the positive control. Wrapping `user:memo_refuse_compiled_arrow_effect/1`
to `true` with `library(prolog_wrap)` in the same process takes the row from
`SLOPED [17550, 19269, ..., 41650]` to `FLAT [15440, 15447, ..., 15537]`, with
the predicate reporting `not wrapped` before and `wrapped by [slope_control]`
after, so the control is known to have run.

Open, and not fixed here: the repair is a design choice inside lib_memo rather
than a repair. `seam:function_clauses_changed/1` carries no module, so the scan
over every module holding the cache is how the check copes with a
module-less event; narrowing it means either widening that seam, caching the
per-module effect plan with its own invalidation, or recording a per-module
generation and skipping unchanged ones. Each is the subsystem author's call.
The reproduction above is deterministic and the control names the predicate.

Tried: attributing the whole order-dependent class at once instead of one test
at a time, by running the suite serially, `pytest tests -n 0`, so every file's
state accumulates in one engine. That is not the shipping configuration,
`-n 4 --dist loadfile` is, but both trees then meet the same accumulated state.
This branch fails five: `ch09_types/test_typing_rules`,
`ch11_python_as_a_notation/test_compiled_vocabulary`, two in
`ch14_seeing_your_program/test_trace`, and `ch18_performance/test_shared_head_cost`.
`ad711777` fails the same five plus the identity twin, 3,364 passed in 506s here
against 3,282 in 583s there.

Decided: the branch's order-dependent failures are a strict subset of trunk's,
and it removes one. That is a stronger statement than counting intermittent
runs, which had read two of three here against one of three there and said
nothing, since which files share an xdist worker changes between runs.
