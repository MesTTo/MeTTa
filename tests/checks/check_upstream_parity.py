"""Purpose: performance parity with upstream PeTTa over the examples corpus.

Every example the pinned upstream checkout can run, this tree must run in no
more real work. Two lanes, because the two questions differ:

- Cross-engine, the gate the corpus exists for: instructions:u net of each
  engine's own NULL-PROGRAM run, median of three processes and of seven when
  the three disagree. Inference counts
  are NOT comparable across engines: upstream inlines arithmetic and comparison
  to VM instructions where this tree routes them through guarded predicates
  for ISO error classes, so the same real work counts up to 1.5x more
  inferences here while instructions stay within percents [measured
  2026-08-17: scale.metta 1.52x by inferences on identical files].
- Within this tree, the tripwire: inferences against the frozen baseline,
  deterministic to the last count, so a real engine regression trips at
  2% + 200 with zero noise. Inferences are counted inside one process and are
  unaffected by everything below, so this half is unchanged.

The fixed cost is the NULL PROGRAM, not a boot driver. Until 2026-09-06 it was
a separate fixture that consulted the engine and printed BOOTED, and
subtracting it was wrong in both directions at once:

- upstream's programs each paid 4,594,811 instructions that its boot fixture
  never reached, because `load_metta_file/2` is where its DCG parser, its
  `library(pcre)` and the rest of its first-use autoloads are charged. That
  constant sat in every upstream number and in none of ours, so a three-line
  program compared ~0.3M against ~5.5M and read 0.05x
  [measured 2026-09-06: upstream boot fixture 252,415,596, upstream empty
  program through the driver 257,010,407, in a clone at the canonical path
  length with the shipping artifacts; commit=2b61fa1947e4de5b02dd8d819ba0e16ec3a07276].
- ours went the other way and NEGATIVE, by 8,661,096 in the same clone
  (1,056,745,595 against 1,048,084,499), because the boot fixture and the
  driver are different processes with different command lines, and a process's
  instruction count moves with its own argv. One fixture, one engine, one
  identical consult, argv length the only difference: 1,332,326,774 against
  1,341,149,760, 8.8M or 0.66% apart, non-monotonic in the argument count
  [measured 2026-09-06: ai-tmp/probe/argc.py, three processes per shape, in a
  tree without the C artifacts, so the level differs from the clone's and the
  effect is the point; commit=2b61fa1947e4de5b02dd8d819ba0e16ec3a07276]. That is the ASPLOS 2009 measurement
  bias -- environment and link order shifting layout and moving a measurement
  by percents while nothing about the program changed [source: Mytkowicz,
  Diwan, Hauswirth, Sweeney, "Producing wrong data without doing anything
  obviously wrong!", doi:10.1145/1508244.1508275]. Seven rows of the
  2026-08-31 baseline came out at or below zero and the page dropped them
  rather than reporting a defect.

Together those two are a 13,255,907-instruction bias in this tree's favour on
every row of a corpus whose smallest rows are worth a few hundred thousand.

So the fixed cost is measured the way a benchmark harness measures the cost of
its own launcher: run the EMPTY program through the very same driver, and
subtract that [source: hyperfine calibrates the shell it launches through by
timing the shell with no command and subtracting the mean,
src/benchmark/executor.rs; it clamps a negative result to zero, which is the
one thing this file does NOT copy, because a negative result here is the
defect above and hiding it is what went wrong]. The null program is written at
the SAME PATH LENGTH and the SAME DIRECTORY COUNT as the example it is the
control for: equal length hands the two processes argv of identical size so
the layout term cancels, and equal depth makes them walk the same number of
path components, which is real work either way. With both matched, a program
of no content nets between -13,405 and +12,852 on this engine and between
-7,446 and -705 on upstream's, across nine corpus shapes, which is this
method's resolution [measured 2026-09-06;
command=ai-tmp/probe/validate_control.py; commit=2b61fa1947e4de5b02dd8d819ba0e16ec3a07276].

Assumes:
  - the upstream checkout at ../PeTTa-upstream is read-only, so its numbers
    freeze into the baseline; --rebaseline re-measures everything
    [assumed: the sibling checkout is a reference copy nothing in this
    repository writes to, which this tool relies on and cannot enforce]. That
    it is at the PINNED COMMIT is no longer assumed: upstream_head/0 reads it
    and --rebaseline refuses anything else
    [tested: tests/checks/check_upstream_parity_selftest.py; commit=fc990fa3042ee05d931d3928694e89021be32855].
  - every corpus path is long enough and deep enough that NULL_ROOT can name a
    control of the same shape; null_program refuses by name when it is not.
Guarantees:
  - the lane cannot pass in CI without measuring: an absent upstream checkout
    is a refusal where CI=true and a printed skip elsewhere, which is the line
    check.sh's documentation lane already draws
    [tested: tests/checks/check_upstream_parity_selftest.py; commit=fc990fa3042ee05d931d3928694e89021be32855].
  - a kernel or container that will not let this count instructions is named
    with the two knobs that decide it, rather than reported as a parse failure
    [tested: tests/checks/check_upstream_parity_selftest.py; commit=fc990fa3042ee05d931d3928694e89021be32855].
  - a row this BOX could not measure is not a row the TREE broke: a timed-out
    example and a row whose processes split between two costs are printed with
    their count and the load beside them, and are fatal only where CI=true,
    while a row whose inference counts disagree still fails on a desk
    [tested: tests/checks/check_upstream_parity_selftest.py; commit=WORKTREE].
  - a row whose own runs land on BOTH sides of the cross-engine allowance is
    reported as unmeasured with its ends rather than as a regression, because
    the verdict would otherwise be whichever half of its spread this run's
    median fell in; a row whose BEST run is still over the line fails
    [tested: tests/checks/check_upstream_parity_selftest.py,
    straddled_allowance_failures; commit=WORKTREE].
  - a row whose program run costs LESS than its own null control is reported
    as `negative-net` and fails the run, rather than being recorded and then
    dropped from the page
    [tested: tests/checks/check_upstream_parity_selftest.py; commit=2b61fa1947e4de5b02dd8d819ba0e16ec3a07276].
  - the net a row records is the program run minus the null run at that row's
    own path length and directory count, on the same engine, in the same
    harness process
    [tested: tests/checks/check_upstream_parity_selftest.py; commit=2b61fa1947e4de5b02dd8d819ba0e16ec3a07276].
  - --rebaseline carries every meta note the old baseline held forward; the
    re-pin history is a record, not a cache
    [tested: tests/checks/check_upstream_parity_selftest.py; commit=2b61fa1947e4de5b02dd8d819ba0e16ec3a07276].
  - a measurement that hits TIMEOUT leaves nothing running: the command owns a
    session and the session is what is killed, because the engine is `perf`'s
    child and outlives every signal aimed at its parents
    [tested: tests/checks/check_upstream_parity_selftest.py; commit=2b61fa1947e4de5b02dd8d819ba0e16ec3a07276].
Owns resources: NULL_ROOT holds one empty .metta per distinct corpus path
  length. They are 0-byte files under the ignored scratch root and are left in
  place between runs; nothing else reads them.
Decides:
  - the estimator is the MEDIAN of the runs, not the minimum, and the sample
    grows from RUNS to RUNS+EXTRA_RUNS when the runs disagree. See the comment
    above _sample: SWI's collector thread costs 35,083,561 instructions that
    perf counts and inferences do not, and whether it lands inside the process
    is a race, so the minimum picks the run that skipped it.
  - WARMUP_RUNS processes are discarded before the first counted one, because
    three corpus rows write a cache on their first touch in a tree and read it
    afterwards. Their cost is the steady-state one.
  - the allowances. Cross-engine, 2% + 150,000 instructions; within-tree,
    2% + 200 inferences. The absolute term is eleven times the method's
    measured resolution, the +-13,405 a program of no content nets across nine
    corpus shapes; the smallest row in the corpus is seventeen times that. It
    was 500,000 while the subtrahend was a boot fixture whose error it had to
    cover.
  - a net below MINUS the absolute allowance is a `negative-net` defect and
    fails the lane; between there and zero the row is `below-floor`, which is
    not a defect and not a measurement, and it is excluded with its status
    printed rather than given a ratio.
  - an example whose runs disagree on inferences is nondeterministic, and one
    whose runs have no majority around their median has no single cost. Both
    are excluded with their status printed, and both fail the lane rather than
    passing unchecked.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import argparse
import contextlib
import json
import os
import pathlib
import signal
import statistics
import subprocess
import sys

from bounded_spawn import CHILD_GRACE, bounded

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[1]
#The checkout this tree is aligned to, and the one
#tests/conformance/petta/ pins its answers from. It was PeTTa-base until
#2026-08-30, an older upstream in a layout that has no engine/metta.pl, so
#the existence guard below fired and this lane passed without measuring
#anything.
UPSTREAM = REPO.parent / "PeTTa-upstream"
#: The upstream this tree is compared against, and the commit every recorded
#: upstream number was measured from. PERFORMANCE.md names the same pin, the
#: workflow checks that commit out beside the repository before the gate, and
#: upstream_head/0 refuses a rebaseline against anything else. It was an
#: `assumed` in this header's Assumes block until 2026-09-06, when the
#: workflow gained a step that can satisfy it.
UPSTREAM_REMOTE = "https://github.com/trueagi-io/PeTTa"
UPSTREAM_COMMIT = "ae66fa8e41dcd5539d614706bd4e5cfb34f9608d"
#: The COMMITTED baseline, which lives with the other test data rather than
#: beside this script. It moved there when tests/ was put into folders by kind
#: and this constant did not follow, so the file below never existed: the
#: script took the "no baseline yet" branch on every run, rebuilt one from the
#: tree it was measuring, and compared each run against itself. The
#: cross-engine half still worked, because it compares against UPSTREAM rather
#: than against the frozen record, but the tree-drift half could not fire at
#: all -- a lane that cannot fail is not a lane. Pointing it back at the
#: committed file is what makes our_inferences a tripwire again.
BASELINE = REPO / "tests" / "data" / "upstream-parity-baseline.json"
#The driver lives under tests/fixtures/, which is where every other input
#rather than program does. It was named against HERE, tests/checks/, until
#2026-08-30: swipl cannot find a source it is given, prints one line and drops
#to its toplevel, and EXITS 0, so perf reported 123M for both "boots", every
#example came back `upstream-error`, and the lane passed having measured
#nothing.
DRIVER = REPO / "tests" / "fixtures" / "parity_driver.pl"
#: Where the null-program controls are written, one per distinct corpus path
#: shape. Deliberately NOT the gate's scratch directory: that name carries a
#: random six-character suffix, and the whole point of these files is that
#: their paths have the length and the depth this script chooses.
NULL_ROOT = REPO / "ai-tmp" / "parity-null"  # artifact-path-created
TIMEOUT = 120

INSTRUCTION_RATIO = 1.02
INSTRUCTION_ABSOLUTE = 150_000
INFERENCE_RATIO = 1.02
INFERENCE_ABSOLUTE = 200


#Janus chooses its embedded Python from VIRTUAL_ENV before any py-call. A
#direct invocation through the checks venv's own python, with an unrelated
#tool's VIRTUAL_ENV still exported, printed exactly `Janus: venv directory
#'<the inherited venv>' does not contain "<it>/lib/python3.14/site-packages"`.
#Mirror check.sh: a Python running from a venv supplies that same venv and its
#bin directory to every SWI child, for both compared engines
#[measured: PARITY-INFERENCES answered instead of a Janus venv warning,
# 2026-08-30; command=_perf over 07-torch.metta through the venv Python
# while inheriting a foreign VIRTUAL_ENV; fixture=07-torch.metta;
# commit=57f21ba9edf94bcf28cde11f938bce2c241a3709].
def _child_environment() -> dict[str, str]:
    environment = os.environ.copy()
    prefix = pathlib.Path(sys.prefix)
    if (prefix / "pyvenv.cfg").is_file():
        environment["VIRTUAL_ENV"] = str(prefix)
        existing_path = environment.get("PATH") or os.defpath
        environment["PATH"] = os.pathsep.join(
            (str(pathlib.Path(sys.executable).parent), existing_path)
        )
    return environment


CHILD_ENVIRONMENT = _child_environment()


#The timed-out engine has to die with the timer, and killing the timed
#process is not enough to do it: the death signal bounded.sh arms reaches
#`perf`, and `swipl` is perf's CHILD, so it survives its whole family and is
#reparented still running. Three corpus rows time out on upstream, and one
#--rebaseline left two swipl processes at 48% CPU with nothing left to bound
#them [measured 2026-09-06: pids 4090605 and 4121404, five and three minutes
#after their rows were recorded as `upstream-timeout`; commit=2b61fa1947e4de5b02dd8d819ba0e16ec3a07276]. So
#the command gets a session of its own and the SESSION is what the timeout
#kills, and the wrapper's own ceiling is set just above this one so a harness
#that dies without reaching this line still has a timer that reaps the group.
def _spawn(argv: list[str]) -> subprocess.CompletedProcess:
    """Run argv under the repository's bound, in a session this call can reap."""
    with subprocess.Popen(
        bounded(argv, ceiling=TIMEOUT + CHILD_GRACE),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        cwd=str(REPO),
        env=CHILD_ENVIRONMENT,
        start_new_session=True,
    ) as process:
        try:
            stdout, stderr = process.communicate(timeout=TIMEOUT)
        except subprocess.TimeoutExpired:
            with contextlib.suppress(ProcessLookupError):
                os.killpg(os.getpgid(process.pid), signal.SIGKILL)
            process.communicate()
            raise
    return subprocess.CompletedProcess(
        process.args, process.returncode, stdout, stderr
    )


#: What the kernel will let an unprivileged process count, read for the
#: refusal below rather than assumed. -1 on the machine these numbers were
#: taken on; 2 still permits a process to count itself, 3 and above permit
#: nothing.
PARANOID = pathlib.Path("/proc/sys/kernel/perf_event_paranoid")

#: What else the box was doing, printed beside every verdict. A number with no
#: load beside it cannot be judged later, and two of this tree's lanes have
#: already read a loaded box as a regression.
LOADAVG = pathlib.Path("/proc/loadavg")


class CounterUnavailableError(RuntimeError):
    """This box would not count, so nothing measured here says the tree moved.

    The seat benchmarks state the same rule in their own harness
    [source: extensions/python/metta/benchmarking.py, MeasurementRefusedError];
    this lane runs from the repository root, where that package is not on the
    path, so it carries the rule rather than importing it.
    """


def _loadavg() -> str:
    """The one-, five- and fifteen-minute averages, or why they could not be read."""
    try:
        return " ".join(LOADAVG.read_text(encoding="utf-8").split()[:3])
    except OSError:
        return "unreadable"


def refused(detail: str) -> int:
    """Print a box refusal and answer the status the lane should exit with.

    One policy, the same one upstream_prerequisite draws for a missing
    checkout: refuse where CI=true, because a runner that cannot measure is a
    broken runner and a lane that passes without measuring is worse than a red
    one; print a named skip elsewhere, because a developer's box is shared.
    """
    if os.environ.get("CI") == "true":
        print(
            f"error: {detail}; refusing to pass the parity gate without "
            f"measuring. loadavg {_loadavg()}",
            file=sys.stderr,
        )
        return 1
    print(
        f"note: {detail}; nothing was measured, so nothing here says the tree "
        f"moved. loadavg {_loadavg()}"
    )
    return 0


def _perf(command: list[str]) -> tuple[int, subprocess.CompletedProcess]:
    completed = _spawn(["perf", "stat", "-e", "instructions:u", "-x", ",", *command])
    instructions = None
    for line in completed.stderr.splitlines():
        if ",instructions:u" in line:
            instructions = int(line.split(",")[0])
    #Naming the two ways this fails, because they are not the tree's fault and
    #the old message ("perf reported no instruction count") sent the reader
    #into the harness. A container is the common one: Docker's default seccomp
    #profile denies perf_event_open outright, so `perf stat -e instructions:u`
    #answers `No permission to enable instructions:u event` even as root, and
    #`--security-opt seccomp=unconfined` is what lets it count [measured
    #2026-09-06: swipl:latest plus linux-perf, `perf stat -e instructions:u -x
    #, true` denied under the default profile and answering
    #`130379,,instructions:u,249770,100.00,,` unconfined; commit=fc990fa3042ee05d931d3928694e89021be32855].
    if instructions is None:
        paranoid = "unreadable"
        with contextlib.suppress(OSError):
            paranoid = PARANOID.read_text().strip()
        msg = (
            "perf did not report an instruction count, so nothing here can be "
            "measured. Either perf is absent, or this kernel refuses to let "
            f"this process count itself: {PARANOID} reads {paranoid}, where 2 "
            "or less is needed, and a container needs "
            "--security-opt seccomp=unconfined before perf_event_open is "
            f"permitted at all. perf said: {completed.stderr[-300:]}"
        )
        raise CounterUnavailableError(msg)
    return instructions, completed


def null_program(length: int, components: int) -> pathlib.Path:
    """An empty .metta file `length` characters long, `components` directories deep.

    Both halves are the control. Equal LENGTH means equal argv bytes, so the
    two processes start with the same layout and the layout term cancels.
    Equal COMPONENTS means the engine walks the same number of path elements:
    at a fixed 120 characters, one empty file measured 56,989 instructions at
    one component below the scratch root and 139,684 at seven, and a
    one-equation file rose from 685,835 to 772,826 over the same range
    [measured 2026-09-06; command=ai-tmp/probe/depth.py; commit=2b61fa1947e4de5b02dd8d819ba0e16ec3a07276]. A
    control that matched only the length charged that difference to the
    program.
    """
    room = length - len(str(NULL_ROOT)) - len("/.metta") - components
    if room < components + 1:
        message = (
            f"cannot write a null control {length} characters long and "
            f"{components} directories deep: {NULL_ROOT} alone is "
            f"{len(str(NULL_ROOT))} characters and {len(NULL_ROOT.parts)} "
            "components. Move NULL_ROOT nearer the repository root, for "
            f"example {REPO / 'ai-tmp' / 'n'}."
        )
        raise RuntimeError(message)
    each = room // (components + 1)
    parts = ["n" * each] * components
    stem = "n" * (room - each * components)
    program = NULL_ROOT.joinpath(*parts, stem + ".metta")
    if not program.is_file():
        program.parent.mkdir(parents=True, exist_ok=True)
        program.write_text("")
    return program


def null_shape(example: pathlib.Path) -> tuple[int, int]:
    """The length and the directory count a control for this example must match."""
    return len(str(example)), len(example.parts) - len(NULL_ROOT.parts) - 1


#The MEDIAN of the runs, not the minimum, and more runs when they disagree.
#Min-of-N is right when interference only ever adds work, and here it does not:
#SWI collects clauses on a `gc` thread, perf counts that thread and
#`statistics(inferences)` does not, and whether the collection lands inside the
#process or after it is a race with exit. One example, 120 processes: 119 read
#1,059.76e9 and one read 1,024.71e9, 35,083,561 apart at 3.42%, with the cheap
#run carrying one MORE clause because a collection it would have paid for never
#happened. The same 120 processes with `set_prolog_gc_thread(false)` spread
#38,479, or 0.0037% [measured 2026-09-06; command=ai-tmp/probe/hunt.py;
#fixture=examples/ch09-types/13-types_nondet.metta; commit=2b61fa1947e4de5b02dd8d819ba0e16ec3a07276].
#
#That excursion is bigger than most rows' entire cost, and the minimum picks it
#every time it appears: the first --rebaseline under the corrected control put
#three rows out by about 35.1M, two of them negative and one reading 35.5x
#against upstream where the true figure is 1.2x.
#
#The collector thread is NOT turned off here, for the reason
#docs/journal/2026-09-06-boot-inference-determinism.md gives for refusing it in
#the boot lane: it measures a configuration nothing ships and hides the
#per-clause cost instead of removing it. The estimator absorbs it instead.
RUNS = 3
EXTRA_RUNS = 4
#: Processes run and thrown away before the first counted one. Three corpus
#: rows write a cache on their first touch in a tree and read it afterwards --
#: the git-import fixture cache, a Python `__pycache__`, an import receipt --
#: so run one disagreed with runs two and three and the row came back
#: `nondeterministic` on a fresh checkout while reading one inference count six
#: times in a row on a warmed one [measured 2026-09-06: 03-python_import,
#: 06-git_import and relative/root.metta, 11,847 / 36,640 / 15,049 inferences
#: over six processes each; command=ai-tmp/probe/flaky.py; commit=2b61fa1947e4de5b02dd8d819ba0e16ec3a07276].
#: One discarded run is the ordinary answer to that, and it is what the
#: baseline's own fixture line has always assumed by saying the tree was
#: warmed.
WARMUP_RUNS = 1
#: How far two processes running the same program may sit apart and still be
#: called the same measurement. 0.1% clears the 0.025% that 120 ordinary
#: processes of one example spanned and is 34 times under the collector
#: excursion above.
SPREAD_RATIO = 0.001


def _sample(engine_root: pathlib.Path, program: pathlib.Path) -> dict:
    """One engine, one program: the median process cost and the inference count.

    WARMUP_RUNS processes are run and discarded, then RUNS are counted,
    extended by EXTRA_RUNS when they disagree by more than SPREAD_RATIO, so
    the median is taken over an odd sample that a single excursion cannot
    carry.
    """
    counts: list[int] = []
    inferences: set[int] = set()
    for batch, counted in ((WARMUP_RUNS, False), (RUNS, True), (EXTRA_RUNS, True)):
        for _ in range(batch):
            try:
                count, completed = _perf(
                    ["swipl", str(DRIVER), str(engine_root), str(program)]
                )
            except subprocess.TimeoutExpired:
                return {"status": "timeout"}
            marker = [
                line
                for line in completed.stdout.splitlines()
                if line.startswith("PARITY-INFERENCES:")
            ]
            if completed.returncode != 0 or not marker:
                return {
                    "status": "error",
                    "detail": (completed.stderr or completed.stdout).strip()[-300:],
                }
            if counted:
                counts.append(count)
                inferences.add(int(marker[-1].split(":")[1]))
        if counts and max(counts) - min(counts) <= min(counts) * SPREAD_RATIO:
            break
    if len(inferences) != 1:
        return {"status": "nondeterministic"}
    middle = int(statistics.median(counts))
    agreeing = [c for c in counts if abs(c - middle) <= middle * SPREAD_RATIO]
    #A median means something when a majority of the sample is around it. A
    #program whose processes are split between two costs has no single cost,
    #and saying so is better than picking one of them.
    if len(agreeing) * 2 <= len(counts):
        return {
            "status": "unstable",
            "detail": f"{len(agreeing)} of {len(counts)} runs within "
            f"{SPREAD_RATIO:.1%} of the median {middle}: {sorted(counts)}",
        }
    return {"status": "ok", "raw": middle, "runs": len(counts),
            #The whole sample, not only its middle. A cross-engine allowance is
            #a LINE, and a row whose runs land on both sides of it has no
            #verdict to give; the judge needs the ends to see that.
            "counts": sorted(counts),
            "inferences": inferences.pop()}


#: One measured null cost per (engine, path length, directory count), because
#: the whole corpus shares 90 such shapes between 272 files and the control
#: does not change within one.
_FIXED_COST: dict[tuple[str, int, int], int] = {}


def fixed_cost(engine_root: pathlib.Path, length: int, components: int) -> int:
    """One engine's cost for a program of no content at that path shape.

    This is what a run pays before its own work: loading the engine, whatever
    the first call to the file-loading path autoloads, and the per-process
    setup around both.
    """
    key = (str(engine_root), length, components)
    if key in _FIXED_COST:
        return _FIXED_COST[key]
    program = null_program(length, components)
    sample = _sample(engine_root, program)
    if sample["status"] != "ok":
        message = (
            f"the null control {program} came back {sample['status']} on "
            f"{engine_root}. Every net is taken against it, so this is fatal: "
            f"{sample.get('detail', '')}"
        )
        raise RuntimeError(message)
    _FIXED_COST[key] = sample["raw"]
    return _FIXED_COST[key]


def measure(engine_root: pathlib.Path, example: pathlib.Path) -> dict:
    """One engine, one example: net instructions, plus the inference count.

    The net is against this engine's null control at this example's own path
    length AND directory count. The inference count must agree across the
    counted runs to count at all.
    """
    sample = _sample(engine_root, example)
    if sample["status"] != "ok":
        return sample
    fixed = fixed_cost(engine_root, *null_shape(example))
    net = sample["raw"] - fixed
    #A program cannot do less work than no program at all through the same
    #driver at the same shape. A net BELOW the measurement's own floor means
    #the control is not measuring this run's fixed cost, which is the defect
    #this file was rebuilt to stop hiding, so it is reported rather than
    #clamped or dropped. Between the floor and zero the row is not a defect and
    #not a measurement either: a program of no content nets between -13,405 and
    #+12,852 across nine corpus shapes [measured 2026-09-06;
    #command=ai-tmp/probe/validate_control.py; commit=2b61fa1947e4de5b02dd8d819ba0e16ec3a07276], so a row that
    #lands there has less work in it than this method can see. Nothing in the
    #corpus does; the smallest row is seventeen times that.
    if net < -INSTRUCTION_ABSOLUTE:
        status = "negative-net"
    elif net <= 0:
        status = "below-floor"
    else:
        status = "ok"
    counts = sample.get("counts", [sample["raw"]])
    return {
        "status": status,
        "instructions": net,
        "fixed": fixed,
        "raw": sample["raw"],
        "runs": sample["runs"],
        #The same subtraction applied to the ends of the sample, so a caller
        #can ask whether the allowance falls INSIDE this row's own spread.
        "lowest": min(counts) - fixed,
        "highest": max(counts) - fixed,
        "inferences": sample["inferences"],
    }


def corpus() -> list[pathlib.Path]:
    """Every example the parity lanes measure, in a stable order."""
    return sorted((REPO / "examples").rglob("*.metta"))


def _carried_meta() -> dict:
    """The meta notes the committed baseline already holds.

    A re-pin is a record of why a number moved and survives the next
    measurement; only the fields this run computes are replaced.
    """
    if not BASELINE.exists():
        return {}
    try:
        stored = json.loads(BASELINE.read_text()).get("//", {})
    except (json.JSONDecodeError, OSError):
        return {}
    computed = {"status", "upstream_null", "our_null", "upstream_boot", "our_boot"}
    return {k: v for k, v in stored.items() if k not in computed}


def _null_summary(engine_root: pathlib.Path) -> dict:
    """What this engine's null control cost, across the shapes this run used."""
    costs = {
        (length, components): cost
        for (root, length, components), cost in _FIXED_COST.items()
        if root == str(engine_root)
    }
    if not costs:
        return {}
    shortest, longest = min(costs), max(costs)
    return {
        "shapes": len(costs),
        "shortest_path": list(shortest),
        "longest_path": list(longest),
        "at_shortest_path": costs[shortest],
        "at_longest_path": costs[longest],
        "median": int(statistics.median(costs.values())),
    }


#Programs the corpus holds that this comparison cannot ask a question about,
#each with the reason. Not a waiver: a waiver is a row that is measured and
#found wanting, and these are rows where the two engines would not be running
#the same program at all.
UNMEASURABLE = {
    "examples/ch20-extending-the-engine/20-06-files-and-processes/_fixtures/exit-status.metta": (
        "the fixture's whole purpose is to terminate its own process with"
        " status 17 at its second form, which this engine does and upstream,"
        " having no exit!, does not: upstream runs three forms and this tree"
        " runs two, so there is no common program to price. The driver reads"
        " the exit status, so the row would otherwise record `ours-fails`"
        " against an engine doing exactly what the fixture asks"
    ),
}


def build_baseline() -> dict:
    """Measure both engines over the whole corpus and answer a fresh baseline."""
    entries: dict[str, dict] = {"//": {"status": "meta", **_carried_meta()}}
    ratios = []
    negatives = []
    for example in corpus():
        name = str(example.relative_to(REPO))
        if name in UNMEASURABLE:
            entries[name] = {"status": "unmeasurable", "detail": UNMEASURABLE[name]}
            continue
        upstream = measure(UPSTREAM, example)
        if upstream["status"] == "below-floor":
            entries[name] = {"status": "upstream-below-floor"}
            print(f"  {name}: upstream's own net is under the measurement floor")
            continue
        if upstream["status"] == "negative-net":
            entries[name] = {
                "status": "upstream-negative-net",
                "upstream_instructions": upstream["instructions"],
                "upstream_null": upstream["fixed"],
            }
            negatives.append(f"{name}: upstream {upstream['instructions']}")
            print(f"  {name}: UPSTREAM NET BELOW ITS OWN NULL CONTROL")
            continue
        if upstream["status"] != "ok":
            entries[name] = {"status": f"upstream-{upstream['status']}"}
            continue
        ours = measure(REPO, example)
        if ours["status"] in ("nondeterministic", "unstable", "below-floor"):
            entries[name] = {"status": ours["status"], "detail": ours.get("detail", "")}
            print(f"  {name}: {ours['status']}, excluded ({ours.get('detail', '')})")
            continue
        if ours["status"] == "negative-net":
            entries[name] = {
                "status": "negative-net",
                "upstream_instructions": upstream["instructions"],
                "upstream_null": upstream["fixed"],
                "our_instructions": ours["instructions"],
                "our_null": ours["fixed"],
                "our_inferences": ours["inferences"],
            }
            negatives.append(f"{name}: ours {ours['instructions']}")
            print(f"  {name}: OUR NET BELOW OUR OWN NULL CONTROL")
            continue
        if ours["status"] != "ok":
            entries[name] = {
                "status": "ours-fails",
                "detail": ours.get("detail", ""),
            }
            print(f"  {name}: OURS FAILS where upstream runs")
            continue
        entries[name] = {
            "status": "measured",
            "upstream_instructions": upstream["instructions"],
            "upstream_null": upstream["fixed"],
            "our_instructions": ours["instructions"],
            "our_null": ours["fixed"],
            "our_inferences": ours["inferences"],
        }
        ratio = ours["instructions"] / max(upstream["instructions"], 1)
        ratios.append(ratio)
        print(
            f"  {name}: instructions {upstream['instructions']} -> "
            f"{ours['instructions']} ({ratio:.2f}x)"
        )
    entries["//"]["upstream_null"] = _null_summary(UPSTREAM)
    entries["//"]["our_null"] = _null_summary(REPO)
    print(f"upstream null program: {entries['//']['upstream_null']}")
    print(f"our null program:      {entries['//']['our_null']}")
    if ratios:
        print(f"median instruction ratio ours/upstream: {statistics.median(ratios):.3f}")
    for line in negatives:
        print(f"  NEGATIVE NET {line}")
    return entries


#Root-caused divergences, each waived with its cause on record; a waiver
#without a cause is a defect in this table. Anything not listed here
#still blocks.
MEMO_IMPORT = (
    "library-load machinery on the lib_memo import, the newtons_method"
    " cause exactly: the manifest pre-scan reads the whole 966-line .pl"
    " before running it, ~46M against these examples' ~110M upstream nets"
    " (measured 2026-08-17)"
)

METTA_IMPORT = (
    "metta-library import machinery, the pln_direct cause: the per-form"
    " source tracking and change hooks of the loader; lib_he alone"
    " measures 65.2M here against upstream's 39.2M (2026-08-17), and each"
    " of these examples is imports-dominated with evaluation at or better"
    " than parity underneath"
)

GUARDED_ARITHMETIC = (
    "the documented ISO-error-class arithmetic guards (the fibadd cause),"
    " density-proportional; fib.metta is fibadd's twin workload with"
    " identical numbers"
)

#The two rows the 2026-09-06 correction newly put over the allowance, and the
#only cause in this table that was measured by decomposing the programs rather
#than by profiling the engines. Both are files with FEW definitions and SEVERAL
#runnable forms, which is exactly where a per-form cost shows and where the
#13.3M bias used to hide it. The decomposition the string quotes
#[measured 2026-09-06; command=ai-tmp/probe/attribute.py and attribute2.py,
#both engines through this file's own measure/2; commit=2b61fa1947e4de5b02dd8d819ba0e16ec3a07276].
PER_FORM = (
    "per-top-level-form load bookkeeping, measured by decomposition: on both"
    " files this tree is cheaper at everything EXCEPT the `!(...)` form."
    " twostage's three definitions alone cost 1,652,075 here against"
    " upstream's 3,361,563; its first test form then adds 1,724,261 here"
    " against 492,613 there and its second 1,224,549 against 391,478."
    " holfunctions_intrinsicop's definitions cost 1,301,033 against 6,673,818,"
    " a bare `!(mymap ...)` over them leaves this tree at 0.932x, and wrapping"
    " the same call in `test` adds 3,806,718 here against 1,706,816 there."
    " test/3 is upstream's predicate almost verbatim -- the"
    " same =@=, two writes and a format, ours throwing where theirs halts --"
    " so the delta is the work AROUND each runnable form rather than the"
    " builtin: the effect classification, source tracking and support-graph"
    " bookkeeping the loader runs per form, the family the pln_direct entry"
    " prices at 516 inferences per source atom. OPEN, and the lever is that"
    " per-form path rather than either program: a file with many definitions"
    " and few forms reads 0.19x to 0.49x on the same decomposition."
)

DISPATCH_HOP = (
    "storage-module candidate dispatch: one native_expression/4 hop per" " enumerated candidate that upstream's direct user-module clauses do" " not pay; the differential profiles match call for call otherwise" " (permutations measured 2026-08-17: identical 1.885M candidate and" " 2.248M cycle-check counts on both engines, ours acyclic_term" " against their cyclic_term, the delta the dispatch hop)"
)

WAIVERS = {
    "examples/ch22-a-reasoner-you-can-serve/22-01-logic-programs/04-nilbc.metta": (
        "ROOT-CAUSED AND OPEN, not explained away. Argument type checking is"
        " 99.4% of this example (306,132,002 inferences against 1,866,723 with"
        " check_argument_type/3 stubbed, measured 2026-08-30), and it became so"
        " in one commit: ecb213fc on 2026-08-21 routed the typing decisions"
        " through the typing-rule registry where they had been inline"
        " comparisons, taking this file from 44,327,926 inferences to"
        " 236,070,644. Reverting that commit's engine/metta.pl hunks alone, at"
        " that commit, restores 44,328,446, so the attribution is a"
        " measurement rather than a reading of the diff."
        " The drift tripwire that would have failed the day it landed could"
        " not: BASELINE pointed at tests/checks/ while the committed baseline"
        " had moved to tests/data/, so every run rebuilt a baseline from the"
        " tree it was measuring and compared it against itself. That path is"
        " fixed, which is how this was found."
        " Three narrower fixes are IN and measured, and together they are"
        " small: the shipped-answer fast path for metta_types_match_in/3"
        " (0.8%), a bare type variable taking the candidate path as upstream's"
        " get-type does (0.2%), and guards that stop two registry walks that"
        " nothing can answer. A whole-cache ceiling on has_type_in/3 measures"
        " 16.4%, so the remaining cost is spread across the typing path rather"
        " than sitting in one predicate, and closing it is a redesign of the"
        " type-witness path against upstream's shape --"
        " `('get-type'(AV, T) *-> true ; 'get-metatype'(AV, T))`, one"
        " derivation with a metatype fallback -- rather than another guard"
    ),
    "examples/ch05-equations-and-evaluation/05-01-an-equation-is-a-rewrite/02-twostage.metta": (PER_FORM),
    "examples/ch08-data/08-01-atoms-lists-and-folds/03-holfunctions_intrinsicop.metta": (PER_FORM),
    "examples/ch07-control-flow/07-05-recursion/02-fib.metta": (GUARDED_ARITHMETIC),
    "examples/ch22-a-reasoner-you-can-serve/22-02-weighted-answers/04-plntestdirect.metta": (
        "ROOT-CAUSED AND OPEN, and it is NOT more work: this tree runs 30,047"
        " inferences on this file against upstream's 40,278, a quarter FEWER,"
        " and still costs 31,292,574 retired instructions against 30,337,471,"
        " +3.15%. So each step costs more rather than there being more steps,"
        " which is the class the two shared strings above name, and the file's"
        " shape says where to look: fourteen definitions and ONE runnable form,"
        " with 30,047 inferences netting 31M instructions, so the row is"
        " dominated by what happens around loading a 47-line file rather than"
        " by evaluating it."
        " It is not the September merge wave's and not this branch's: a"
        " first-parent ladder over the eight points where this file's own"
        " measurement method exists reads 31,034,356 to 31,141,141 with no"
        " trend, and the frozen our_instructions, 31,007,739, sits inside that"
        " spread."
        " What tipped it over is the LINE, not the tree. The allowance is"
        " 31,110,028 and the row's own spread crosses it, so at the pinned"
        " checkout length the verdict is whichever half a run lands in; from a"
        " checkout 23 characters longer the whole spread is above it, because"
        " the null control cancels 99.6% of the path (raw +38,887,046, control"
        " +38,716,562) and the 170,484 it leaves is 0.55% of a 31M net."
        " Closing this means the per-form loading path, which is the same"
        " open work the two shared reasons above carry"
        " [measured 2026-09-07: four runs in the branch worktree and sixteen"
        " over eleven ladder points; command=this file's own measure/2 against"
        " both engines]"
    ),
    "examples/ch22-a-reasoner-you-can-serve/22-02-weighted-answers/05-pln_direct.metta": (
        "metta-library import machinery: the lib_pln import alone costs"
        " 310.7M here against upstream's 275.7M (measured 2026-08-17), and"
        " that +35M covers the example's whole +28M flag, so evaluation is"
        " at parity and the delta is the loader's per-form source tracking"
        " and change hooks, the documented 516-inferences-per-source-atom"
        " path"
    ),
    "examples/ch06-many-answers/08-permutations.metta": (DISPATCH_HOP),
    "examples/ch22-a-reasoner-you-can-serve/22-03-search/02-tilepuzzle.metta": (DISPATCH_HOP),
    "examples/ch05-equations-and-evaluation/05-02-changing-the-equations/04-specialize.metta": (
        "translator per-clause richness on a 250-clause specializer demo:"
        " this tree records per-equation support-graph nodes with sequence"
        " ids, arity registration, effect classification and"
        " deferred-translation bookkeeping that upstream's compiler does not"
        " perform, and the demo is nothing but clause churn (88,270,238"
        " against 48,574,121 upstream, 1.82x, 2026-08-31 rebaseline). The"
        " levers that exist are exhausted: the fuel charge, the boolean"
        " scaffolding and the rule-gate probes are compiled away, and the"
        " residue is the invalidation machinery a redefinable engine keeps"
        " so that changing an equation is O(affected) rather than"
        " O(program)."
    ),
    #The seven-process spread the entry below quotes
    #[measured 2026-09-06; command=ai-tmp/probe/torch.py; commit=2b61fa1947e4de5b02dd8d819ba0e16ec3a07276].
    "examples/ch11-python-as-a-notation/07-torch.metta": (
        "SUPERSEDED 2026-09-06 and kept for the record. This row is no longer"
        " measured at all: seven upstream processes of it read 6,916,429,114"
        " to 7,432,625,840, a 7.46% spread with no mode, and seven of ours"
        " 7,812,902,156 to 8,344,224,046, 6.80%, so neither engine has a"
        " single instruction cost for a PyTorch workload and the row comes"
        " back `upstream-unstable`. The waiver it"
        " carried -- python-seam richness, 2.07% over, 8,327,251,946 against"
        " 7,982,385,732 -- was a min-of-three reading off that distribution's"
        " low tail, so its 2.07% was never a measurement. What it says about"
        " the per-crossing constants may still be true; nothing here shows it."
    ),
    "examples/ch19-spaces-backed-by-anything/19-03-a-builtin-in-c/01-c_extension.metta": (
        "feature-versus-absent: loading this example consult-time"
        " goal-expands the tree's OWN extension source (the arithmetic"
        " guard and effect classification over the C seat's bridge), work"
        " upstream does not do because it has no extension seam at all"
        " (87,886,158 against 52,510,511 upstream, 2026-08-31 rebaseline);"
        " the evaluation underneath is at parity."
    ),
    "examples/ch19-spaces-backed-by-anything/19-03-a-builtin-in-c/02-handle.metta": (
        "feature-versus-absent, the c_extension entry's sibling: the same"
        " consult-time goal expansion over the C seat's bridge plus the"
        " handle door's registration bookkeeping, none of which upstream"
        " performs because it has no extension seam (95,329,550 against"
        " 59,845,230 upstream, 2026-08-31 rebaseline); the evaluation"
        " underneath is at parity."
    ),
    "examples/ch20-extending-the-engine/20-02-metta-written-in-metta/02-callquoteevalreduce2.metta": (
        "meta-door richness, diffuse: quote/eval/reduce crossing costs"
        " spread over every meta operation (30,630,261 against 18,139,006"
        " upstream, 2026-08-31 rebaseline); the boundary and step doors"
        " are swapped away when idle, and what remains is the metatype"
        " bookkeeping the self-interpreter chapter exercises on every"
        " form."
    ),
    "examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/_fixtures/imports/relative/root.metta": (
        "import machinery, feature-versus-absent: the receipt digests,"
        " source tracking and invalidation hooks that make a re-import"
        " O(changed) are charged on first load (151,125,044 against"
        " 145,562,645 upstream, +5.5%, 2026-08-31 rebaseline); upstream"
        " re-consults blindly and pays nothing for the capability."
    ),
    "examples/ch05-equations-and-evaluation/05-02-changing-the-equations/06-specializecyclic.metta": (DISPATCH_HOP),
    "examples/ch10-errors-and-refusals/01-he_error.metta": (METTA_IMPORT),
    "examples/ch08-data/08-01-atoms-lists-and-folds/15-roman.metta": (METTA_IMPORT),
    "examples/ch18-performance/18-02-memoisation-and-tabling/09-tabling_fib.metta": (
        "library content growth, the builin_types cause: our lib_tabling"
        " is a 66-line metta surface plus a 290-line Prolog invalidation"
        " lane against upstream's 11-line stub; the import alone measures"
        " 72.7M against upstream's 11.7M (2026-08-17), covering the whole"
        " flag"
    ),
    "examples/ch22-a-reasoner-you-can-serve/22-03-search/05-fibadd.metta": (
        "the documented ISO-error-class arithmetic guards (the +2.1%"
        " scale.metta trade), density-proportional: a source-defined fib"
        " twin shows the same +6.8% net on both engines, ~70 instructions"
        " per guarded op with four per call (measured 2026-08-17); the"
        " specializer is the future lever"
    ),
    "examples/ch22-a-reasoner-you-can-serve/22-03-search/04-matespace2.metta": (DISPATCH_HOP),
    "examples/ch18-performance/18-01-larger-workloads/03-superpose_primes.metta": (DISPATCH_HOP),
    "examples/ch22-a-reasoner-you-can-serve/22-02-weighted-answers/08-nars_direct.metta": (DISPATCH_HOP),
    "examples/ch18-performance/18-01-larger-workloads/01-scale.metta": (
        "the add path's reload-erasure machinery, standing since before"
        " this session (flagged identically in the first baseline sweep):"
        " one million load-time add-atom calls each pay assertz/2 with a"
        " recorded reference so a later source error can erase the whole"
        " partial load, where upstream's bare assertz/1 records nothing;"
        " profiles otherwise matched call for call (measured 2026-08-17)."
        " The assertz/2-vs-assertz/1 4.4x per-call tick ratio deserves its"
        " own look, recorded in the survey ledger"
    ),
    "examples/ch22-a-reasoner-you-can-serve/22-03-search/03-matespace.metta": (DISPATCH_HOP),
}


def verdicts(baseline: dict, *, remeasure: bool) -> int:
    """Judge this tree against the baseline, remeasuring it first unless frozen."""
    cross, drift, negative, unstable = [], [], [], []
    waived, unmeasured = [], []
    checked = 0
    for name, entry in sorted(baseline.items()):
        if entry.get("status") == "negative-net":
            negative.append(
                f"{name}: recorded net {entry.get('our_instructions')} against "
                f"a null control of {entry.get('our_null')}"
            )
            continue
        if entry.get("status") != "measured":
            continue
        #A baseline written by this file cannot hold one, but the one this
        #replaced could and did: seven rows carried a net between -94,022 and
        #-50,470,138 under `measured`, and the page dropped them rather than
        #reporting them. A stored net at or below zero is the same defect as a
        #fresh one.
        if entry["our_instructions"] <= 0 or entry["upstream_instructions"] <= 0:
            negative.append(
                f"{name}: recorded {entry['our_instructions']} against upstream's "
                f"{entry['upstream_instructions']}, and a program cannot cost "
                "nothing"
            )
            continue
        example = REPO / name
        if not example.exists():
            continue
        if remeasure:
            ours = measure(REPO, example)
            if ours["status"] == "negative-net":
                negative.append(
                    f"{name}: {ours['raw']} instructions against a null control "
                    f"of {ours['fixed']} at the same path length"
                )
                continue
            #A row that stopped having ONE cost is not a regression, and saying
            #so mattered: three import rows read `nondeterministic` on a fresh
            #checkout, under the old "now fails to run" wording, purely because
            #their first touch writes the cache their later runs read.
            #A timeout and a split cost are the BOX's answers, not the
            #tree's: this file's own note above says a loaded box makes the
            #excursion behind `unstable` likelier, and a corpus row that ran
            #300.0s against a 300s ceiling at loadavg 33.81 was recorded as a
            #cross-engine regression it was not. Both go to the bucket that
            #names them and refuses only where CI=true, so contention on a
            #shared desk cannot report a code change that did not happen.
            if ours["status"] in ("timeout", "unstable"):
                unmeasured.append(
                    f"{name}: {ours['status']} {ours.get('detail', '')}".rstrip()
                )
                continue
            if ours["status"] in ("nondeterministic", "below-floor"):
                unstable.append(f"{name}: {ours['status']} {ours.get('detail', '')}")
                continue
            if ours["status"] != "ok":
                cross.append(f"{name}: now fails to run ({ours['status']})")
                continue
        else:
            ours = {
                "instructions": entry["our_instructions"],
                "inferences": entry["our_inferences"],
            }
        checked += 1
        allowed = (
            entry["upstream_instructions"] * INSTRUCTION_RATIO + INSTRUCTION_ABSOLUTE
        )
        if ours["instructions"] > allowed:
            line = (
                f"{name}: {ours['instructions']} instructions against "
                f"upstream's {entry['upstream_instructions']} "
                f"(allowed {allowed:.0f})"
            )
            #A row whose own runs land on BOTH sides of the allowance has not
            #failed, it has not been decided: the verdict would be whichever
            #half of its spread this run's median happened to fall in, and the
            #next run would say the other thing. Measured on
            #ch22/22-02/04-plntestdirect, which reads 31,034,356 to 31,141,141
            #across sixteen runs at the pinned checkout length against an
            #allowance of 31,110,028, and whose frozen our_instructions,
            #31,007,739, sits inside that same spread [measured 2026-09-07:
            #a first-parent ladder over the eight points where this file's
            #current method exists, two runs each, plus four in the branch
            #worktree]. So it goes to the bucket that names it rather than to
            #the one that blames the tree, and the ends are printed so the next
            #reader sees the straddle rather than re-deriving it.
            if remeasure and ours.get("lowest", allowed + 1) <= allowed:
                unmeasured.append(
                    f"{name}: its own runs straddle the allowance, "
                    f"{ours['lowest']} to {ours['highest']} against "
                    f"{allowed:.0f} over {ours.get('runs', 0)} runs"
                )
            elif name in WAIVERS:
                waived.append(line)
            else:
                cross.append(line)
        if remeasure:
            drift_allowed = (
                entry["our_inferences"] * INFERENCE_RATIO + INFERENCE_ABSOLUTE
            )
            if ours["inferences"] > drift_allowed:
                drift.append(
                    f"{name}: {ours['inferences']} inferences against the "
                    f"frozen {entry['our_inferences']}"
                )
    print(f"upstream parity: {checked} examples checked, loadavg {_loadavg()}")
    for line in cross:
        print(f"  CROSS-ENGINE REGRESSION {line}")
    for line in waived:
        print(f"  WAIVED (root-caused, see WAIVERS) {line}")
    for line in drift:
        print(f"  TREE DRIFT {line}")
    for line in negative:
        print(f"  NEGATIVE NET, THE CONTROL IS WRONG {line}")
    #A row here is not a regression, it is a row whose cost is not one number,
    #so its tripwire could not be read at all. It fails rather than being
    #skipped, because a check that stopped happening reports success. Run the
    #row alone before believing it: the excursion behind an `unstable` is a
    #race with process exit and a loaded box makes it likelier.
    for line in unstable:
        print(f"  NO SINGLE COST, THE ROW WAS NOT CHECKED {line}")
    #A row this box could not measure is printed with its count either way, so
    #"the check stopped happening" is never silent; what the CI line decides is
    #whether it is also fatal. On a runner it is: a row nobody measured is a
    #tripwire nobody read.
    for line in unmeasured:
        print(f"  NOT MEASURED ON THIS BOX {line}")
    if unmeasured:
        print(
            f"  {len(unmeasured)} row(s) the box would not measure at loadavg "
            f"{_loadavg()}"
        )
    fatal = bool(cross or drift or negative or unstable)
    if unmeasured and os.environ.get("CI") == "true":
        fatal = True
    return 1 if fatal else 0


def upstream_present() -> bool:
    """Whether the sibling checkout holds an engine this can measure."""
    return any((UPSTREAM / d / "metta.pl").exists() for d in ("engine", "src"))


def upstream_head() -> str | None:
    """The commit the sibling checkout is on, or None when it cannot say."""
    try:
        completed = subprocess.run(
            ["git", "-C", str(UPSTREAM), "rev-parse", "HEAD"],
            capture_output=True, text=True, timeout=30, check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    return completed.stdout.strip() if completed.returncode == 0 else None


#GitHub Actions sets CI=true, and check.sh already draws this exact line for a
#prerequisite the repository can provide: refuse where the lane is
#load-bearing, print a skip where a developer simply has not cloned it
#[source: check.sh:639, docs_prerequisite_missing]. Until 2026-09-06 this returned
#0 either way, and the workflow never cloned upstream, so the lane ran on every
#push and measured nothing -- and PERFORMANCE.md said the measurement ran in
#CI. The workflow clones the pin before the gate now, so a missing checkout
#there is a broken workflow rather than a missing option.
def upstream_prerequisite(
    remedy: str = "PERFORMANCE.md's 'Reproducing it' has the commands.",
) -> int | None:
    """None when the comparison can run, or the exit status when it cannot.

    `remedy` is the sentence the LOCAL skip ends on, because the two lanes that
    call this send a reader somewhere different: this one to the page carrying
    the numbers, and check_upstream_fuzz to its own lane. The POLICY -- refuse
    where CI=true, print a skip elsewhere -- is one piece of code on purpose,
    since two copies of it are two things that can drift into disagreeing about
    when a missing checkout is allowed to pass.
    """
    if upstream_present():
        return None
    absence = f"upstream checkout not found at {UPSTREAM}"
    if os.environ.get("CI") == "true":
        print(
            f"error: {absence}; refusing to pass the parity gate without it. "
            f"The workflow checks {UPSTREAM_REMOTE} out at "
            f"{UPSTREAM_COMMIT} beside the repository before this lane runs; "
            "if that step did not, this lane measured nothing.",
            file=sys.stderr,
        )
        return 1
    print(
        f"note: {absence}; nothing to compare. Check "
        f"{UPSTREAM_REMOTE} out at {UPSTREAM_COMMIT[:7]} there to run it; "
        f"{remedy}"
    )
    return 0


def main() -> int:
    """Report the parity verdicts, rebuilding the baseline under --rebaseline."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--rebaseline", action="store_true")
    parser.add_argument(
        "--frozen",
        action="store_true",
        help="judge the stored numbers without re-measuring this tree",
    )
    arguments = parser.parse_args()
    absent = upstream_prerequisite()
    if absent is not None:
        return absent
    try:
        return _judge(arguments)
    except CounterUnavailableError as unavailable:
        return refused(str(unavailable))


def _judge(arguments: argparse.Namespace) -> int:
    """Every verdict this lane reaches once the prerequisites hold."""
    #Only --rebaseline READS the sibling checkout; the gate path re-measures
    #this tree and compares against upstream numbers already frozen in the
    #baseline. So a checkout at the wrong commit is fatal to a rebaseline,
    #which would attribute fresh numbers to a pin they did not come from, and
    #is worth saying but not worth failing for anywhere else.
    head = upstream_head()
    if head is not None and head != UPSTREAM_COMMIT:
        drift = (
            f"{UPSTREAM} is at {head}, not the pinned {UPSTREAM_COMMIT} that "
            "the recorded upstream numbers were measured from"
        )
        if arguments.rebaseline:
            print(f"error: {drift}; refusing to rebaseline against it.",
                  file=sys.stderr)
            return 1
        print(f"note: {drift}; this run does not read it, so the verdicts hold.")
    if arguments.rebaseline or not BASELINE.exists():
        entries = build_baseline()
        BASELINE.write_text(json.dumps(entries, indent=1, sort_keys=True) + "\n")
        print(f"baseline written: {BASELINE}")
        broken = [n for n, e in entries.items() if e.get("status") == "ours-fails"]
        if broken:
            return 1
        return verdicts(entries, remeasure=False)
    return verdicts(json.loads(BASELINE.read_text()), remeasure=not arguments.frozen)


if __name__ == "__main__":
    sys.exit(main())
