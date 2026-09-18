# Schedule-independent counters
Goal: every twinned example's inference count is a point the lane pins, so
the eight empirical envelopes and the pooling rule retire, and a lane run
is a gate rather than a coin with bias 2/(n+1) per envelope twin
(docs/journal/2026-09-08-the-twins-lane-gates.md, the coin-toss finding).
Constraint: `m.stats()` keeps counting the workers a block waits for
(2026-09-08: a joined 2,000,000-inference thread moves the joiner by
2,000,013, a detached one by 7); the host is patchable and every host
compromise is a candidate to lift (user, 2026-09-16); lib_thread's
lifecycle needs every worker joined before its queues and Python contexts
go, so losers cannot simply be detached.
Plan:
1. Attribute (measured, not assumed): where each envelope's spread comes
   from. Established today: SWI credits a joined child's inferences to its
   creator at thread_join (src/pl-thread.c:2957, `joined_by_creator`), so a
   race's aborted loser lands its partial spin in the twin's count
   (thread_lib, spread 94,478 over 25); lib_thread joins every worker
   through metta_thread_settled_/2, a sleep-backoff poll of about ten
   inferences a wakeup, because thread_join/2 is unsafe while the joinee
   detaches its engine (detach_engine zeroes info->tid, thread_join reads
   it unguarded); par_any and par_forall stop early through
   concurrent_forall/2, whose aborted workers are credited the same way.
   The other six envelopes are attributed by the same method before they
   are touched.
2. Host: a patch `swi-thread-join-detach-window` against V10.1.14
   src/pl-thread.c: detach_engine keeps a real thread's tid (only an
   interactor, `is_engine`, has no OS thread while detached), so
   thread_join/2 always joins the right pthread; reproduction script under
   tests/checks/host_workarounds/ that churns engine_create/engine_destroy
   on a worker while joining it and answers present on a crash, absent on a
   clean join; ledger entry with Patch:; the host and the janus wheel
   rebuilt from the patched tree (the CLAUDE.md recipe), after the running
   measurements finish, since a rebuild under a running lane changes the
   host mid-corpus. Upstream master (fetched 2026-09-18, 73a6750) carries
   the same detach_engine and thread_join, so nothing lifts by upgrade.
3. lib_thread: metta_thread_join_settled/2 becomes the plain blocking join
   (no poll, so the joiner's own count is fixed); one first-wins mechanism
   under par_race, par_any and par_forall (one worker per branch, the
   first answer that decides wins, the rest are stopped), where the
   winner's thread is joined and charged and every other worker is joined
   through a discarding join that brackets thread_join with two
   statistics(inferences) reads and adds the credited difference to a
   process tally; cancel of a future or timer uses the same discarding
   join. Law: a block is charged for its own thread's work and for the
   workers whose answers it used; a stopped branch's work is discarded.
4. Seat: metta_py_stats/1 carries the tally; _StatsBlock subtracts its
   delta beside the interrupt poll's charge; the docstring states the law
   and the measurement.
5. Evidence: a lib_thread suite test that a race's cost is the same
   integer over repeated runs and equals main plus winner; a seat test
   that a cancelled future is not charged; the host reproduction; then
   `--observe --rounds 10` reading zero spread for the eight, each
   envelope converted to a point with its conversion paragraph, and the
   lane green.

## 2026-09-18
Found: the envelope twins' spread is joined-worker work whose size the
schedule decides, plus the polling join. thread_lib: minimum 322,447,
maximum 416,925 over 25 (a 300,000-inference loser aborted at a
schedule-chosen point); mutex 12, linda 29, channels 643, prolog rung
2,053, git_import 0, reference_loading 3,856, measure 99 (spreads over the
25-observation envelopes on 0e7679245).
Rejected: counting only the calling thread's own inferences, because it
blinds the lane to a regression inside the workers every parallel door
delegates to, and reverses the 2026-09-08 decision that waiting for work
is doing it. Revisit if the lane ever prices worker-side work separately.
Rejected: detaching losers instead of joining them, because race_stop_/1
joins so the queues and Python contexts outlive every worker; a detached
loser can still send into a destroyed queue or run in a released context.
Rejected: a bounded worker pool under par_any (concurrent_forall's shape),
because a worker that took several elements before the deciding one
carries their work into the charged count, and which elements it took is
the schedule's; one worker per branch makes the charged work exactly the
deciding branch's.
Supersedes, for the join: docs/journal/2026-09-06-materialization-segv.md
("closed at the joiner"), which rejected a host-side fix because the host
was not this tree's to change and adopted the polling wait at the joiner,
leaving a raw thread_join/2 in a MeTTa program exposed. The condition
changed on 2026-09-16 (hosts are patchable, every host compromise is a
candidate to lift), and the poll's own inferences are exactly what a
deterministic counter cannot carry. The upstream write-up
(docs/journal/2026-09-06-swi-defects-to-report-upstream.md, item 1)
suggested thread_join/2 refusing or waiting on has_tid; the patch takes
the other side, since a real thread's OS identity never changes while its
engine is detached, so there is nothing for the join to wait for.
Decided: the plan above, as its own unit after the twins re-pin and the
ledger re-take on the merged tree, so those pins are measured once on
the tree the trunk fast-forwards to.

## 2026-09-18, the construction
Decided: the counter law is "cost follows the answer": a block is charged
for its own thread's work and for the workers whose answers it used. The
engine owns it (engine/metta/control.pl): metta_join_measured/3 brackets
thread_join/2 with two statistics(inferences) reads and answers the
joinee's credit (the bracket's own cost is the two call ports between the
reads), metta_join_discarding/2 adds that credit to a per-thread tally
(a global variable, per thread in SWI, so a worker discarding its own
losers cannot touch its creator's tally, whose counter never saw that
credit), and metta_py_stats/1 and metta_py_work/1 subtract the tally beside
the interrupt poll's charge. The seat's stats block subtracts the delta.
Decided: par_race, par_any and par_forall are three faces of first_wins_/3
in lib_thread: one worker per branch, a start barrier, a results mailbox
whose messages carry the worker; the first deciding answer wins, its
worker is joined through metta_thread_join/2 (the library's one charged
join door, kept as a named predicate so the completion suite can wrap it),
every other worker is stopped and joined through the discarding door; an
exhausted call charges every branch. concurrent_forall/2 leaves the
library.
Decided: a cancel whose charge depends on an outcome known only after the
join (cancel_future_worker_/4: the worker may have settled first) joins
through the measured door and discards the credit only when the cancel
took. A stopped repeating timer and a timer whose registration failed are
discarded outright.
Decided: the raw statistics(inferences) reads behind the inference limit
door (metta_host_inference_budget/3) stay raw: a limit bounds what a query
spends, and a stopped branch's spend was spent.
Tried: the join-window reproduction on the current host (10.1.14 with the
ledger's earlier patches) -> present, three runs of three
(tests/checks/host_workarounds/swi-thread-join-detach-window.sh). The patch
is applied to /home/user/Dev/swipl-devel's working tree beside the other
patches and not yet built: a rebuild under the running lane would change
the host mid-corpus.
Open: the measurement on the rebuilt host: the two lib_thread tests, the
seat's cancelled-future test, the churn regressions under the plain join,
then --observe over the eight envelopes reading zero spread.
Tried: the plunit, examples and shell lanes with the patched build's swipl
first on PATH (wt-battery-6, ai-remedy-lanes.log) -> shell and examples
green; plunit red on lib_thread's churn regression with a SIGSEGV and a
glibc malloc assertion from the crash reporter. The core
(coredumpctl 3220344) names the executable
/home/user/Dev/swipl-patched/lib/swipl/bin/x86_64-linux/swipl, the
installed unpatched host, and its trace is __pthread_clockjoin_ex under
pl_thread_join2_va, the null-tid join the entry describes: the runner
takes the venv's swipl ahead of PATH, so the lane ran the poll-free join on
the host without the patch. On the patched build's binary the churn
regression passes 20 of 20 alone, the whole lib_thread suite 8 of 8 and 20
of 20 under gdb (ai-churn-*.log). The lanes are re-run after the install.
Found: the seat's shim suite consults the shim without the engine and stubs
the engine doors the codec touches, so the counters door's new read of the
engine's tally gets the same stub (metta_discarded_inferences(0)) and the
snapshot's width assertion moves to eleven; the door is declared a
host_service in engine/ext_points.pl (135 now).

## 2026-09-19
Found: the twins lane on the remedied tree (wt-battery-3,
ai-twins-lane-c7e27cf2a.log) -> 293 of 294 twins at exactly +5 over their
pins: metta_py_stats/1 and metta_py_work/1 read the discarded tally after
the inference read, so at a window's opening edge the read sat inside the
window (the six inferences an empty block costs became eleven).
Decided: the doors take the edge they read for, metta_py_stats/2 and
metta_py_work/2 with `open` reading the tally before the inference read and
`close` after it; the arithmetic stays inline in both clauses because a
helper call after the opening read would move every pin by one. The corpus
pins stand.
Measured: the corpus observed ten rounds on the remedied tree (wt-battery-3,
ai-observe-remedy.log, 294 twins, 0 failures): of the eight envelope twins
only git_import reads one integer (30449, as before the remedy); thread_lib
narrows from 319852..353464 (spread 33,612) to 309915..336432 (26,517),
the_prolog_rung_under_lib_thread from 151672..152620 (948, and 2,053 on
2026-09-08) to 139741..141733 (1,992), channels_pools_and_the_machine
121041..121714 (673) to 121129..121932 (803), thread_linda 149803..149803
(0) to 149978..150103 (125), mutex_and_transaction 23258..23264 (6) to
23258..23265 (7), reference_loading 369521..372889 (3,368) to
372287..376159 (3,872), measure 133662..133728 (66) to 133629..133728 (99).
Found: what the remedy removes is the spend of a stopped branch, which is
what thread_lib's spread was mostly made of; the spread these twins keep
is their own schedule-bound work (which thread takes a channel or linda
message, a timer's firing position, a reference load's worker order), which
no join accounting reaches. The envelopes stay envelopes, re-observed under
the remedy as their mechanism; git_import becomes a point.
Rejected: converting the seven to points from the remedy's claim, because
the observation refutes the claim for them; and pooling the old ranges into
the new, because the old ranges were the pre-remedy engine's.
Open: a schedule-independent counter for message passing and timers (the
2026-09-08 thread's three remedies, still the user's ruling).
Found: the gate on 10da82e4a read the seat rows past their pins after the
commit (engine translate +1.44% instructions, C term-in +0.41%, MORK
match rows +17.6k and conjunction rows +3.8% to +4.2% proportional to
size, the direct-join and prepared-join slopes -3,720 and -1,872, the
extension add-atom tier -1999 inferences). A/B on the tip in wt-battery-2,
the index reset between runs (ai-ab-remedy-3.log to -6.log; the first two
rounds restored files from a moved index and measured one tree twice,
recorded in the ledger journal): lib_thread's rewrite reverted alone moves
nothing; the ext-points row reverted alone leaves the rows moved; the
four doors defined but NOT exported read every row at its pin (translate
327,107,206 against the pin 328,195,107; MORK conjunction-400 4,807,021
against 4,826,988); the four names exported with the doors undefined move
the rows (translate 332,096,887); four dummy names exported, of arity 0 or
of arity 1 to 3, defined, read every row at its pin (326,049,869 and
326,889,743). So the cost is the presence of these four names in
metta_engine's export list, not their count, arity, definition or the
ext-points row.
The tally door metta_discarded_inferences/1 exported alone reads every
row at its pin too (wt-battery-3 ai-ab-remedy-7.log: translate
327,014,703), and the seam requires a declared host service to be exported
(engine_modules:every_declared_service_is_exported_to_the_host).
Decided: the three join doors stay in engine/metta/control.pl and leave
the export list, lib_thread calls them metta_engine-qualified; the tally
door stays exported and its callers unqualified; the seat rows measured
in a fresh process keep the pins measured on 4c0533704 and the seat
re-pins written for them are withdrawn.
Found (the Python-seat rows): direct-join and prepared-join's slope pins
and the extension add-atom tier's pin were stale, not moved: on 4c0533704
with a purged QLF set the same test's point-count assertion failed first
and masked them, and the tool's table read 33.00 per add there as on the
tip; source-load alone moves +15 at 323356870 (260,317 on 4c0533704,
55d451b67 and 43800c685; 260,332 on the tip) and the commit's seat files,
lib_thread, the door exports and the ext-points row each reverted alone
still read 260,332, so it is the commit's as a whole and inside the
accepted cost difference. Both are re-pinned with that as the mechanism;
the harness gains BenchmarkBaseline.collecting() so a row's every
comparison reaches the log (the ledger journal).
Open: why exporting these four names costs a fresh process 5.7M
instructions and a MORK conjunction 4% per operation while four other
names do not; the shape fits the functors' placement in a procedure table
the evaluator probes on every meta-call, which is the host's and is not
pursued further under the engine's retirement.
