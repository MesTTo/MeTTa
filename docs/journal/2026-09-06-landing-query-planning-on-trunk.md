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
