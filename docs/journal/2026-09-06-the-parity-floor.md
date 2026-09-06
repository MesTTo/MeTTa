# The parity floor

Goal: make the cross-engine performance comparison symmetric, so PERFORMANCE.md
reports what a program costs rather than what the two engines' launchers cost.

Constraint: the harness, its baseline, its page and its tests only. No engine,
library or Python-seat change, so every number here moves for measurement
reasons and nothing else.

## 2026-09-06

The page's "Where it wins" table read 0.049x for
`ch06-many-answers/03-collapse.metta` and 0.051x for four more three-line
programs. A twenty-fold win on a program that is one `!(collapse ...)` form is
not a win, it is a measurement artifact, and the whole page rested on the same
subtraction.

The method was: per program, `instructions:u` minimum of three processes, minus
that engine's boot, where the boot was measured by a second fixture
(`tests/fixtures/parity_boot.pl`) that consulted the engine and printed BOOTED.
Two asymmetries, in opposite directions, both of them worth more than a small
program's whole cost.

Tried: run an EMPTY program through the real driver and compare it with the
boot fixture, on both engines, in a clone at the canonical path length with the
shipping artifacts present.

```
upstream  boot fixture 252,415,596   null program 257,010,407   -4,594,811
ours      boot fixture 1,056,745,595 null program 1,048,084,499  +8,661,096
```

So upstream's boot fixture measured 4,594,811 instructions BELOW what an
upstream program actually pays before its own work, and ours measured 8,661,096
ABOVE. The old net therefore charged upstream 4.6M of work it does not do and
credited this tree with 8.7M it does not save: a 13,255,907-instruction bias in
our favour on every row of the corpus, against a corpus whose smallest rows are
worth a few hundred thousand.

The upstream half has a plain cause. Upstream's fixed cost is not all in the
consult: `load_metta_file/2` is the first call into its DCG parser, its
`library(pcre)` and the rest of its first-use autoloads, and none of that is
reached by a fixture that consults and stops. The committed baseline shows the
shape from the outside: over 142 comparable rows the smallest upstream net was
5,259,534 and the 5th percentile 5,599,379, a floor no upstream program went
below, which is what a constant added to every row looks like.

The other half is not a missing load, it is layout. The boot fixture and the
driver are different processes with different command lines, and a process's
retired-instruction count moves with its own argv. One fixture, one engine, one
identical consult, argv the only difference:

```
v_boot_argc <root>                       1,332,326,774
v_boot_argc <root> <program>             1,341,149,760   +8,822,986  (+0.66%)
v_boot_argc <root> <program> bootargv    1,332,476,833     +150,059
v_boot_argc <root>            (repeat)   1,332,316,970       -9,804
```

Non-monotonic in the argument count, reproducible to five digits, and 0.66% of
a boot is 8.8M where a three-line program costs 0.3M. Two instrumented
variants doing the identical consult confirmed the Prolog side is untouched:
786,758 against 786,783 inferences, the same atom, clause and
garbage-collection counts, 9,684,013 instructions apart. This is the ASPLOS
2009 measurement bias, environment and link order moving a measurement by
percents while nothing about the program changes
[Mytkowicz, Diwan, Hauswirth, Sweeney, doi:10.1145/1508244.1508275].

Seven rows of the 2026-08-31 baseline came out at or below zero, three of them
near -50M, and every one of the seven is a long-path `ch20` fixture: the
negative rows are the ones whose own work is smallest, exactly where a wrong
constant shows.

Rejected: clamping a negative net to zero, which is what hyperfine does with
its shell-spawning subtraction (`(result.time_real -
spawning_time.time_real).max(0.0)`, src/benchmark/executor.rs). It is right for
a tool whose overhead estimate is sound and whose users want a number; here a
negative net IS the defect, and clamping or excluding it is how this survived
three rebaselines. Revisit if the control is ever proven exact by construction,
which it is not.

Rejected: measuring the fixed cost once per engine and reusing it for every
row. Our null program costs 1,048,084,499 at a 64-character path and
1,048,524,259 at 142, a 439,760 span at about 5,638 instructions per character,
and upstream's spans 269,107 at about 3,450. A single constant is wrong by up
to 440k across a corpus whose median row is a few million.

Rejected: fitting the null cost as a line in path length and evaluating the fit,
which is 18 processes instead of 213. The relation is close to linear, but a
fitted control puts a model between the engine and the number, and a model that
drifts is invisible. Revisit if the per-length measurement ever dominates the
lane's runtime.

Decided: the fixed cost is the NULL PROGRAM. An empty `.metta` file, run
through the very same driver, at the SAME PATH LENGTH as the example it is the
control for, minimum of three processes, memoised per (engine, length) because
149 files share 60 lengths. Equal path length means equal argv bytes, so the
layout term is the same in both processes and cancels; the file's contents are
then the only thing left between them. This is hyperfine's shell-spawning
calibration with the subtrahend measured through the real path rather than a
proxy for it, and it is what SPEC-style harnesses call a null-program control.

Decided: a net below zero is a `negative-net` row that FAILS the lane, and a
baseline holding one fails it too. It cannot happen while the control is
sound, which is the point of reporting it.

Decided: `tests/fixtures/parity_boot.pl` is deleted rather than kept for
reporting. Keeping a second, non-comparable fixed cost on the page is an
invitation to subtract it again.

Tried: the corpus re-measured with the null control, both engines, three
processes each, in `/home/user/Dev/PyPeTTa1/pnull`, a clone whose path is the
same 29 characters as the main checkout, provisioned with the five engine `.so`
artifacts, the three chapter-19 artifacts, `libcmetta.so`, both MORK artifacts
and the git-import fixture cache, `.qlf` purged and then warmed.

Four sweeps, because the first three found defects in the method rather than
in the engine. The first, netting against a length-matched control with a
minimum-of-three, put three rows out by the 35.1M collector excursion below.
The second, with the median, was clean of that and put four rows over the
allowance. The third, with the control matched on directory depth too,
recovered two of the four. The fourth, with a discarded warm-up run, is the
baseline that ships.

| | before | after |
|---|---:|---:|
| median, ours / upstream | 0.379x | 0.512x |
| geometric mean | 0.355x | 0.477x |
| cheaper than upstream on | 125 of 142 (88%) | 124 of 149 (83%) |
| corpus total, ours | 549,522,280,393 | 556,873,062,348 |
| corpus total, upstream | 380,258,571,038 | 371,624,178,028 |
| total ratio | 1.445x | 1.498x |
| cheapest row | 0.049x | 0.066x |
| rows with a net at or below zero | 7, dropped from the page | 0 |
| rows over the allowance | 15 | 16 |

The extreme wins were the artifact and they are gone: 0.049x on
`ch06-many-answers/03-collapse.metta` is 0.290x, and the five rows the old page
listed under "Where it wins" were two, three, three, six and two lines long,
each with a whole cost smaller than the bias. What survives is a median of
about half, a corpus total 1.5x dearer, and 25 of 149 rows dearer than
upstream against 17 of 142.

Two rows the correction newly put over the allowance are
`05-01-an-equation-is-a-rewrite/02-twostage.metta` at 1.072x and
`08-01-atoms-lists-and-folds/03-holfunctions_intrinsicop.metta` at 1.111x on
the third sweep, 1.073x and 1.105x on the fourth.

Tried: decomposing both rather than profiling the engines. Definitions only,
then definitions plus one form, then the whole file, on both engines through
the harness's own `measure/2` ->

    twostage       definitions only    ours 1,652,075   upstream 3,361,563
                   + one test form     ours 3,376,336   upstream 3,854,176
                   whole file          ours 4,600,885   upstream 4,245,654
    holfunctions   definitions only    ours 1,301,033   upstream 6,673,818
                   + a bare !(mymap)   ours 7,427,316   upstream 7,965,652
                   + one test form     ours 11,234,034  upstream 9,672,468

So this tree is cheaper at everything except the runnable form: it loads
definitions 2x and 5x cheaper and evaluates a bare call 0.93x, and its per-form
marginal cost is 1.72M and 1.22M against upstream's 0.49M and 0.39M on
twostage, 3.81M against 1.71M on holfunctions. `test/3` is upstream's predicate
almost verbatim, so the delta is the work around each form rather than the
builtin.

Decided: both are waived under one new cause, PER_FORM, with that
decomposition and marked OPEN. The lever named is the per-form path, not either
program.

Also found, and not looked for: `ch11-python-as-a-notation/07-torch.metta` has
no single cost on either engine. Seven upstream processes read 6,916,429,114 to
7,432,625,840, a 7.46% spread with no mode; seven of ours read 7,812,902,156 to
8,344,224,046, 6.80%. Its old waiver priced it at 2.07% over upstream, which
was a minimum read off that distribution's low tail. The row now leaves the
comparable set and the waiver records why.

Also: `20-06-files-and-processes/_fixtures/exit-status.metta` is declared
UNMEASURABLE by name. It calls `exit! 17` at its second of three forms, which
this engine honours and upstream, having no `exit!`, does not, so the two
engines do not run the same program; the driver reads the exit status, so the
row would otherwise be recorded as `ours-fails` against an engine doing exactly
what the fixture asks. It is a new file, so the old baseline never met it.

The recorded `our_inferences` move on 135 of the 148 rows measured in both
baselines, 84 of them downward, and not one exceeds the old pin's 2% + 200. No
engine source changed, so those are the stale half of the 0.8.0 re-pin being
brought to this tip: that re-pin advanced thirteen inference fields and left the
rest at their 2026-08-31 values.

## 2026-09-06, the minimum was the wrong statistic

The first re-measure under the null control put three rows out by about 35.1M:
`ch09-types/13-types_nondet.metta` at -28,933,533,
`ch20-.../01-translatepredicate.metta` at -34,741,441, and
`ch20-.../overhaul/space_payload.metta` at 35,934,564 against upstream's
1,012,112, a reported 35.5x where the row is really 1.2x. Three independent
rows, one quantum: 35,107,698, 35,096,329 and 35,096,926.

Tried: measuring the two negative rows again with their controls interleaved,
five processes each -> `translatepredicate` reads +354,888 and holds it, and
`space_payload` reads +837,638. So the rebaseline's numbers were not those
rows' costs. `types_nondet` reproduced it once: five processes read
1,019,192,572 then 1,054,300,270, 1,054,290,956, 1,054,308,674, 1,054,298,095,
with all five agreeing on 8,712 inferences.

Tried: 120 processes of `types_nondet` with a census of what each one loaded ->
119 read 1,059.76e9 and one read 1,024,713,761, 35,083,561 apart at 3.42%. Same
93 files, same 2,201 predicates, same 17,823 atoms, and ONE more clause in the
cheap run: 5,356 against 5,355.

Found: SWI collects retracted clauses on a `gc` thread. `perf` counts every
thread of the process and `statistics(inferences)` counts only the thread that
reads it, so a collection that lands inside the process is 35.1M instructions
that the inference counter cannot see, and whether it lands there at all is a
race with process exit. The cheap run is the one that exited first, which is
why it carries the extra clause. This tree already met the same race on the
other channel: `docs/journal/2026-09-06-boot-inference-determinism.md` traces
the boot's inference spread to which thread runs the `erase` listener.

Tried: the positive control, 120 processes with `set_prolog_gc_thread(false)`
-> spread 38,479, or 0.0037%, and one clause count in all 120. So the collector
thread is the whole excursion.

Rejected: shipping that flag in the driver, for the reason the boot-determinism
entry gives for refusing it in `engine-bench`: it measures a configuration
nothing ships and hides the per-clause cost instead of removing it. Revisit if
the excursion ever appears in a configuration that does ship.

Decided: the estimator is the MEDIAN of the runs, and the sample grows from
three processes to seven when the three disagree by more than 0.1%. The minimum
is right when interference only ever ADDS work; here the excursion subtracts,
so the minimum picks it every time it appears. 0.1% is chosen between the
0.025% those 120 ordinary processes spanned and the 3.42% excursion.

Decided: a sample with no majority around its median has no single cost and the
row says so instead of picking one of its modes. Three excursions in seven
still leave the median where the other four agree, and that case must NOT fail,
or a busy box fails the lane for nothing.

Open: the residual case a small sample cannot see is a program genuinely split
near half and half between two costs. Nothing in the corpus behaves that way,
and the excursion is boot-level rather than program-level, so the rate is the
same for every row.

## 2026-09-06, the control had to match the depth too

Found while attributing the four rows that the corrected measurement newly put
over the allowance: the same file measured in two places did not cost the same.
`_fixtures/imports/relative/second.metta`, one equation and nothing else, read
822,873 as a corpus row and 661,954 as a byte-identical copy under `ai-tmp/`,
with the length term already subtracted in both.

Tried: holding the path LENGTH at 120 characters and varying only the number of
directories, same content ->

    directories   upstream net    our net
              1        590,172    685,835
              2        598,421    718,051
              4        607,924    741,151
              7        617,725    772,826

and with EMPTY content, which is what a control is, 18,689 / 56,989 at one
directory against 42,110 / 139,684 at seven. So a control matched only on
length charged the example up to 139,684 instructions of path walking that the
control never did, and the corpus's files sit at 9 to 14 components against the
control's 9.

Decided: `null_program(length, components)`. The control carries the example's
character count AND its directory count, and `null_shape/1` derives both. The
corpus's 272 files share 90 such shapes against 71 lengths, so the extra
measurement is 27% more null runs and nothing else.

Tried: the property the whole method rests on, measured rather than assumed. A
program of no content, at nine shapes taken across the corpus's range, nets
between -13,405 and +12,852 on this engine and between -7,446 and -705 on
upstream's. That is the method's resolution, the smallest corpus row is
seventeen times it, and it is where the cross-engine allowance's absolute term
now comes from: 150,000, eleven times the resolution, against the 500,000 that
had to cover a boot fixture's error.

Decided: a net below MINUS that allowance is the `negative-net` defect; between
there and zero the row is `below-floor`, excluded and printed, because +-13,405
of resolution means a program with less work in it than that has no ratio worth
printing. Nothing in the corpus lands there.

## 2026-09-06, what the corrected measurement newly exposes

Open: the recorded -50,470,138 on
`ch20-.../20-03-prolog-underneath/01-translatepredicate.metta` is three times
larger than the +8,661,096 boot overstatement this clone measures. The
direction and the mechanism are established by direct A/B; the magnitude
belonged to the main checkout's artifact and `.qlf` state on 2026-08-31, which
is not reconstructible now. Under the null control that row and its six
siblings are all positive, so the question is closed for the lane and open only
as an attribution.

## 2026-09-06, the first touch in a tree is not a measurement

Found by running the lane in a checkout that had never run it. Three rows came
back `nondeterministic` and the lane called them cross-engine regressions:
`ch11-python-as-a-notation/03-python_import.metta`,
`20-04-modules-and-the-catalog/06-git_import.metta`, and
`_fixtures/imports/relative/root.metta`.

Tried: six processes of each on the same tree, after the failing run had
already touched them -> 11,847, 36,640 and 15,049 inferences, six times each,
with instruction spreads of 0.016%, 0.058% and 0.021%. So they are not
nondeterministic, they are COLD: the first touch in a tree writes something the
later runs read -- the git-import fixture cache, a Python `__pycache__`, an
import receipt -- and run one then disagrees with runs two and three.

Decided: `WARMUP_RUNS = 1`, discarded before the first counted run, which is
what hyperfine's `--warmup` and JMH's warmup iterations are for and what the
baseline's own fixture line has always assumed by saying the tree was warmed.
The cost a row records is its steady-state cost.

Decided: a row that stops having one cost is reported as `NO SINGLE COST, THE
ROW WAS NOT CHECKED` rather than as a cross-engine regression. It still fails
the lane, because a check that stopped happening reports success, but the
wording no longer sends the reader after a performance change that did not
happen.

## 2026-09-06, the page said the measurement runs in CI, and it does not

Found while checking the page's own claims rather than its numbers. The
opening sentence read "the measurement runs in CI, so this page can be checked
rather than believed", and `.github/workflows/checks.yml` runs
`GATE_ONLY=1 sh check.sh`, which does include `parity-perf`. But nothing in
`.github/` mentions `trueagi` or `PeTTa-upstream`, so the sibling checkout the
lane needs is never there: the guard at the top of `main/0` prints
`upstream checkout not found at ...; nothing to compare` and returns 0. The
lane runs in CI and measures nothing.

Decided, then superseded the same day: the page said that, in the same
paragraph that says where the numbers came from. Superseded by the section
below, which makes the sentence true instead of qualifying it.

## 2026-09-06, making the lane able to fail in CI

A lane that cannot fail is not a lane, so the answer was not to describe the
skip but to remove it. Three prerequisites, and each was measured rather than
assumed, because two of them are properties of a container this repository has
never run perf inside.

Tried: `git ls-remote` and then the shallow fetch-by-object-ID recipe against
github.com -> `git init` + `remote add` + `fetch --depth 1 origin <sha>` +
`checkout FETCH_HEAD` answers `ae66fa8e41dcd5539d614706bd4e5cfb34f9608d`, so
the pin is fetchable without the history. github.com serves an arbitrary
object ID to `want`, which not every host does.

Tried: the CI image. `swipl:latest` is Debian trixie and has NO `perf`; the
package that provides it there is `linux-perf`. Built the image with it and
ran `perf stat -e instructions:u -x , true` inside:

    default seccomp profile   Error: No permission to enable instructions:u event.
    seccomp=unconfined        130379,,instructions:u,249770,100.00,,

So Docker's default profile denies `perf_event_open` and the gate job needs
`options: --security-opt seccomp=unconfined`. That is the narrowest option
that lets the syscall through and it grants no privileges.

Tried: both workflow step bodies, verbatim, inside the built image, with the
option and without ->

    with --security-opt seccomp=unconfined   exit 0, "counter readable"
    default profile                          exit 1, the diagnostic

Found, by running that second control rather than trusting the first: the
preflight step's own test was broken. It read
`perf stat ... | grep -q instructions:u`, and perf's REFUSAL says
`No permission to enable instructions:u event`, which contains that string, so
the step reported a readable counter inside a container that could not count
at all. It now asks what `_perf` asks: a `-x ,` row whose third field is the
event and whose first is a number.

Decided: `upstream_prerequisite/0` refuses where `CI=true` and prints a skip
naming the pin elsewhere, which is the line `docs_prerequisite_missing` already
draws in check.sh. Decided: `UPSTREAM_COMMIT` is a constant, `upstream_head/0`
reads the checkout's HEAD, and `--rebaseline` refuses against any other commit
-- that turns this file's own `assumed: the sibling checkout is ... pinned`
into something enforced. The gate path does not read the sibling at all, so a
drifted checkout there is a printed note rather than a refusal.

Decided: a perf that cannot count is named with the two knobs that decide it,
`perf_event_paranoid` and the seccomp profile, instead of the old
`perf reported no instruction count`, which sent the reader into the harness.

Open: `/proc/sys/kernel/perf_event_paranoid` on GitHub's own runners. It reads
-1 here and 2 or less is enough, but a container job cannot change the host's
value, so if theirs is 3 or more the preflight step fails and the remedy is
the runner's rather than this repository's. That is the one link in this chain
measured nowhere but on this box.

## 2026-09-06, the timeout that left the engine running

Found while re-measuring, not looked for: `--rebaseline` leaves a live `swipl`
behind for every row that times out. `_perf` timed the process it started, and
the process it started is `bounded.sh`'s wrapper; the death signal that wrapper
arms reaches `perf`, and the engine is `perf`'s CHILD, one level below anything
aimed at its parents.

Tried: watching the run. `cycle_a.metta` and `cycle_b.metta` were recorded as
`upstream-timeout` and their engines were still running five and three minutes
later at 48% CPU each, reparented, with nothing left to bound them (pids
4090605 and 4121404, killed by hand). Three corpus rows time out, so every
rebaseline leaks three.

Decided: the measured command gets a session of its own and the timeout kills
the SESSION, with the wrapper's own ceiling set to `TIMEOUT + CHILD_GRACE` so a
harness that dies before reaching that line still has a timer that reaps the
group.

Tried: a selftest for it, first written as `sh -c "exec sleep N"`. It passed
against the OLD kill, because that shape has one process level too few: the
`exec` leaves nothing under the process the death signal reaches. `sh -c "sleep
N & wait"` reproduces the real topology and then passed against the old kill
too, this time because the orphan inherits the harness's pipes, so the
post-kill `communicate()` waits for the orphan to exit and by the time anything
can look, it has. Giving the grandchild its own stdio separates the two and the
check finally discriminates: red against `process.kill()`, green against
`os.killpg`.
