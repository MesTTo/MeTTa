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
  [measured 2026-09-06: three processes per shape, in a
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
method's resolution [measured 2026-09-06 over the null programs below;
commit=2b61fa1947e4de5b02dd8d819ba0e16ec3a07276].

Assumes:
  - the configured upstream checkout is read-only, so its numbers
    freeze into the baseline; --rebaseline re-measures every row, or only the
    rows it names
    [assumed: the sibling checkout is a reference copy nothing in this
    repository writes to, which this tool relies on and cannot enforce]. That
    it is at the PINNED COMMIT is no longer assumed: upstream_head/0 reads it
    and --rebaseline refuses anything else
    [tested: tests/checks/check_upstream_parity_selftest.py; commit=fc990fa3042ee05d931d3928694e89021be32855].
  - every corpus path is long enough and deep enough that NULL_ROOT can name a
    control of the same shape; null_program refuses by name when it is not.
Guarantees:
  - prepare_artifacts uses bounded_spawn.bounded for the producer's lifetime
    [tested: process-bounds, parity-perf-selftest; commit=801110debd5646a41c40391cee4075355a49d27b]
  - every program is paired with a freshly measured null, so artifacts
    generated by an earlier library load cannot stale the subtracted fixed
    cost [tested: check_upstream_parity_selftest.fresh_null_failures; commit=8ca8a387fc61d0918484b19a1a3baf85b6523043]
  - live comparisons start with the boot's purge and shipping qlf_load_engine
    producer, independently of artifacts an earlier lane left. The measured
    driver and whole-process boundary are unchanged [tested:
    check_upstream_parity_selftest.artifact_fixture_failures; commit=8ca8a387fc61d0918484b19a1a3baf85b6523043]
  - active WAIVERS remain printed as root-caused rulings even when the current
    sample is inside its band or cannot be measured. Measurement refusals and
    inference drift remain independent [tested: parity-perf-selftest;
    commit=8ca8a387fc61d0918484b19a1a3baf85b6523043]
  - the compared range subtracts the null maximum from the program minimum
    and the null minimum from the program maximum. A null sample extending
    more than 13,405 below or 12,852 above its median refuses the instruction
    comparison as unmeasurable; the program's inference check still runs.
    Straddles and overruns print both operands and their difference range
    [tested: check_upstream_parity_selftest.null_range_failures; commit=8ca8a387fc61d0918484b19a1a3baf85b6523043]
  - METTA_UPSTREAM selects the reference checkout; when unset, the lane
    looks for PeTTa-upstream beside the tree and then beside the repository's
    main checkout, so a worktree at any depth and a battery find the checkout
    the main one has [tested:
    check_upstream_parity_selftest.upstream_selection_failures,
    check_upstream_parity_selftest.upstream_derivation_failures;
    commit=WORKTREE]
  - the lane cannot pass without measuring: an absent upstream checkout is a
    refusal, exit 1, naming every place it looked; METTA_UPSTREAM_OPTIONAL=1
    turns it into a printed skip, exit 125, except where CI=true
    [tested: check_upstream_parity_selftest.upstream_prerequisite_failures;
    commit=WORKTREE].
  - a kernel or container that will not let this count instructions is named
    with the two knobs that decide it, rather than reported as a parse failure
    [tested: tests/checks/check_upstream_parity_selftest.py; commit=fc990fa3042ee05d931d3928694e89021be32855].
  - a row this BOX could not measure is not a row the TREE broke: a timed-out
    example and a row whose processes split between two costs are printed with
    their count and the load beside them, and are fatal only where CI=true,
    while a row whose inference counts disagree still fails on a desk
    [tested: tests/checks/check_upstream_parity_selftest.py; commit=11afdcdbad5bbbe37168b5d8528c23a21c42b4b6].
  - a row whose own runs land on BOTH sides of the cross-engine allowance is
    reported as unmeasured with its ends rather than as a regression, because
    the verdict would otherwise be whichever half of its spread this run's
    median fell in; a row whose BEST run is still over the line fails
    [tested: tests/checks/check_upstream_parity_selftest.py;
    commit=11afdcdbad5bbbe37168b5d8528c23a21c42b4b6].
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
  - --rebaseline takes each half of a row on its own: a net this run cannot
    resolve keeps the committed one and `carried` names it, while the
    inference tripwire is this run's whenever our program ran to one count,
    so a loaded box re-pins it; a named rebaseline leaves every other row as
    committed, and a name outside the corpus is refused
    [tested: check_upstream_parity_selftest.rebaseline_half_failures;
    commit=df94e0828c7bafb14179b6ae4d55643faa63a00e].
  - a measurement that hits TIMEOUT leaves nothing running: the command owns a
    session and the session is what is killed, because the engine is `perf`'s
    child and outlives every signal aimed at its parents
    [tested: tests/checks/check_upstream_parity_selftest.py; commit=2b61fa1947e4de5b02dd8d819ba0e16ec3a07276].
Owns resources: NULL_ROOT holds one empty .metta per distinct corpus path
  length. They are 0-byte files under the ignored scratch root and are left in
  place between runs; nothing else reads them. Before live comparisons the
  boot replaces its governed generated artifacts through its own purge door.
  check.sh serializes lanes that share those artifacts.
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
UPSTREAM_SIBLING = "PeTTa-upstream"


def upstream_candidates(root: pathlib.Path) -> list[pathlib.Path]:
    """Where the upstream checkout is looked for from the tree at `root`, in order.

    METTA_UPSTREAM alone when the operator names one, present or not, because
    an operator who says where it is outranks anything inferred. Otherwise
    beside `root`, then beside the repository's MAIN checkout. A worktree's
    parent is not the main checkout's parent and a battery's is neither: from
    ai-tmp/wt-merge/ai-tmp/wt-battery-119 the sibling beside the tree is
    .../wt-merge/ai-tmp/PeTTa-upstream, which nothing provides, so this lane
    skipped in every battery [measured 2026-09-24: battery-119 run at
    19:42 printed "upstream checkout not found at
    .../wt-merge/ai-tmp/PeTTa-upstream" and the summary read `parity-perf
    skipped`]. `--git-common-dir` names the main .git from every worktree of
    the repository, and a battery's git is one (tools/battery.sh,
    battery_git_identity), so the main checkout's sibling is found from all of
    them with nothing linked; extensions/python/tools/example_origins.py's
    upstream_root() answers PeTTa-base the same way.
    """
    named = os.environ.get("METTA_UPSTREAM")
    if named:
        return [pathlib.Path(named)]
    looked = [root.parent / UPSTREAM_SIBLING]
    common = subprocess.run(
        ["git", "rev-parse", "--path-format=absolute", "--git-common-dir"],
        cwd=root, capture_output=True, text=True, check=False,
    )
    if common.returncode == 0 and common.stdout.strip():
        beside_main = pathlib.Path(common.stdout.strip()).parent.parent / UPSTREAM_SIBLING
        if beside_main not in looked:
            looked.append(beside_main)
    return looked


def holds_engine(checkout: pathlib.Path) -> bool:
    """Whether a checkout holds an engine this lane can measure."""
    return any((checkout / d / "metta.pl").exists() for d in ("engine", "src"))


def located(candidates: list[pathlib.Path]) -> pathlib.Path:
    """The first candidate holding an engine, else the first one looked at."""
    return next((c for c in candidates if holds_engine(c)), candidates[0])


UPSTREAM_CANDIDATES = upstream_candidates(REPO)
UPSTREAM = located(UPSTREAM_CANDIDATES)
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

PROTOCOL = (
    "whole-process instructions:u; median-of-3-or-7 after one warm process; "
    "null=fresh same-path-shape per program; "
    "artifacts=purge_all_qlf then shipping qlf_load_engine/0"
)


def prepare_artifacts() -> tuple[pathlib.Path, ...]:
    """Generate this checkout's fixture through the shipping producer once.

    A direct qcompile(auto) consult keeps its caller's compilation context;
    qlf_load_engine/0 delegates to the hermetic child that shipping hosts use.
    This setup is outside every measured process. The boot owns the generated
    set, including library artifacts left by previous lanes.
    """
    completed = subprocess.run(
        bounded(["swipl", "-q", "-f", "none", "--no-packs", "-s",
         str(REPO / "engine" / "qlf_boot.pl"), "-g",
         "metta_qlf_boot:purge_all_qlf,"
         "metta_qlf_boot:qlf_boot_directory(Here),"
         "metta_qlf_boot:qlf_files(Here,[]),"
         "metta_qlf_boot:qlf_load_engine,"
         "atom_concat(Here,'/metta.qlf',Umbrella),system:exists_file(Umbrella),"
         "metta_qlf_boot:qlf_files(Here,Files),"
         "use_module(library(http/json),[]),"
         "format('PARITY-ARTIFACTS:'),json:json_write(current_output,Files,[width(0)]),nl",
         "-t", "halt"]),
        cwd=REPO, env=CHILD_ENVIRONMENT, capture_output=True, text=True, check=True,
    )
    marker = "PARITY-ARTIFACTS:"
    inventories = [json.loads(line.removeprefix(marker))
                   for line in completed.stdout.splitlines() if line.startswith(marker)]
    if len(inventories) != 1 or not inventories[0]:
        message = f"parity artifact setup returned no inventory: {completed.stdout!r}"
        raise RuntimeError(message)
    _FIXED_COST.clear()
    artifacts = tuple(pathlib.Path(path).resolve() for path in inventories[0])
    print(f"parity fixture: {len(artifacts)} governed QLF artifacts; {PROTOCOL}")
    return artifacts


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
    [source: ext/metta-benchmarking/metta_benchmarking.py, MeasurementRefusedError];
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
    [measured 2026-09-06; commit=2b61fa1947e4de5b02dd8d819ba0e16ec3a07276]. A
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
#38,479, or 0.0037% [measured 2026-09-06;
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
#: over six processes each; commit=2b61fa1947e4de5b02dd8d819ba0e16ec3a07276].
#: One discarded run is the ordinary answer to that, and it is what the
#: baseline's own fixture line has always assumed by saying the tree was
#: warmed.
WARMUP_RUNS = 1
#: How far two processes running the same program may sit apart and still be
#: called the same measurement. 0.1% clears the 0.025% that 120 ordinary
#: processes of one example spanned and is 34 times under the collector
#: excursion above.
SPREAD_RATIO = 0.001
# The null program's measured resolution above, applied to its own sample.
# A broken control cannot enlarge every row's compared interval.
NULL_RESOLUTION_BELOW = 13_405
NULL_RESOLUTION_ABOVE = 12_852


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


#: The latest null sample at each shape, for _null_summary's descriptive
#: metadata only. Reusing it for another program is unsound: an intervening
#: library load can create QLF artifacts and change the next process's boot
#: cost. The paired controls are recorded in the 2026-09-10 fresh-null section
#: of docs/journal/2026-09-07-merged-tree-reconciliations.md.
_FIXED_COST: dict[tuple[str, int, int], dict] = {}


def fixed_cost(engine_root: pathlib.Path, length: int, components: int) -> dict:
    """One engine's fresh complete null sample at that path shape.

    This is what a run pays before its own work: loading the engine, whatever
    the first call to the file-loading path autoloads, and the per-process
    setup around both.
    """
    key = (str(engine_root), length, components)
    program = null_program(length, components)
    sample = _sample(engine_root, program)
    if sample["status"] != "ok":
        message = (
            f"the null control {program} came back {sample['status']} on "
            f"{engine_root}. Every net is taken against it, so this is fatal: "
            f"{sample.get('detail', '')}"
        )
        raise RuntimeError(message)
    low, high = min(sample["counts"]), max(sample["counts"])
    if (sample["raw"] - low > NULL_RESOLUTION_BELOW
            or high - sample["raw"] > NULL_RESOLUTION_ABOVE):
        sample = {**sample, "status": "unmeasurable-null", "detail": (
            f"null {low}..{high}, median {sample['raw']} over {sample['runs']} runs "
            f"exceeds resolution -{NULL_RESOLUTION_BELOW}/+{NULL_RESOLUTION_ABOVE}; "
            "refusing this instruction comparison"
        )}
    _FIXED_COST[key] = sample
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
    null = fixed_cost(engine_root, *null_shape(example))
    fixed = null["raw"]
    net = sample["raw"] - fixed
    #A program cannot do less work than no program at all through the same
    #driver at the same shape. A net BELOW the measurement's own floor means
    #the control is not measuring this run's fixed cost, which is the defect
    #this file was rebuilt to stop hiding, so it is reported rather than
    #clamped or dropped. Between the floor and zero the row is not a defect and
    #not a measurement either: a program of no content nets between -13,405 and
    #+12,852 across nine corpus shapes [measured 2026-09-06 over the null
    #programs above; commit=2b61fa1947e4de5b02dd8d819ba0e16ec3a07276], so a row that
    #lands there has less work in it than this method can see. Nothing in the
    #corpus does; the smallest row is seventeen times that.
    if null["status"] != "ok":
        status = null["status"]
    elif net < -INSTRUCTION_ABSOLUTE:
        status = "negative-net"
    elif net <= 0:
        status = "below-floor"
    else:
        status = "ok"
    program_range = [min(sample["counts"]), max(sample["counts"])]
    null_range = [min(null["counts"]), max(null["counts"])]
    return {
        "status": status,
        "detail": null.get("detail", ""),
        "instructions": net,
        "fixed": fixed,
        "raw": sample["raw"],
        "runs": sample["runs"],
        # Both operands are measured. Retaining only the null median would
        # make its uncertainty look like work added by the program.
        "lowest": program_range[0] - null_range[1],
        "highest": program_range[1] - null_range[0],
        "program_range": program_range,
        "null_range": null_range,
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
    """The latest null observation at each shape, for descriptive metadata."""
    costs = {
        (length, components): cost["raw"]
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


#: The statuses that leave the row without a measurement, as against
#: `negative-net`, which is a DEFECT this file exists to report and so is
#: always recorded. `below-floor` is here rather than there because this file's
#: own contract puts it here: a net between minus the absolute allowance and
#: zero "is not a defect and not a measurement", so it has nothing to overwrite
#: a known number with. None of these say anything about the row, and a
#: baseline that replaces a good measurement with one of them has lost
#: information rather than recorded any.
_UNMEASURED = ("nondeterministic", "unstable", "below-floor", "unmeasurable-null", "timeout")


#: The fields each half of a measured row owns. A row is three measurements
#: that depend on different things, so each is taken, or kept, on its own: the
#: two nets are instruction counts, which a loaded box cannot resolve, and the
#: inference count is counted inside one process and is exact at any load.
_UPSTREAM_HALF = ("upstream_instructions", "upstream_null")
_OUR_HALF = ("our_instructions", "our_null")


def _excluded(name: str, status: str, detail: str) -> dict:
    """The row a run records when it measured nothing and had nothing to keep."""
    print(f"  {name}: {status}, excluded ({detail})")
    return {"status": status, "detail": detail}


def rebaseline_names(arguments: list[str]) -> set[str] | None:
    """The corpus rows a named rebaseline re-measures, or None for all of them.

    A name is a corpus example, spelled from the repository root or absolute.
    One that is not in the corpus is refused rather than skipped, because a
    re-pin that silently measured nothing reads exactly like one that measured.
    """
    if not arguments:
        return None
    known = {str(example.relative_to(REPO)) for example in corpus()}
    names = set()
    for argument in arguments:
        # Normalised and never resolved: corpus() does not follow a symlinked
        # alias to its target, so resolving here would rename the row.
        path = pathlib.Path(os.path.normpath(REPO / argument))
        name = str(path.relative_to(REPO)) if path.is_relative_to(REPO) else argument
        if name not in known:
            msg = f"{argument} is not an example this lane measures"
            raise ValueError(msg)
        names.add(name)
    return names


def build_baseline(names: set[str] | None = None) -> dict:
    """Measure both engines over the corpus, or over the named rows, and answer a baseline.

    A half this run CANNOT measure keeps whatever the committed row already
    holds, and `carried` names which halves those are, instead of the row being
    flattened to a status-only stub. Not having measured something and having
    no measurement of it are different outcomes, and they were written the same
    way: on a box under load 163 of these rows come back `unmeasurable-null`,
    because the instruction null control's own spread exceeds resolution, so a
    rebaseline there discarded 163 rows of work taken on a quiet one [measured
    2026-09-22]. That made `--rebaseline` an operation you could only run on an
    idle machine, and the machine is not always idle.

    Carrying was then the WHOLE row, which kept the stale inference count along
    with the nets the box could not resolve, so the tripwire this lane fails on
    could still only be re-pinned on an idle machine: eight rows read TREE
    DRIFT on deterministic inference counts at loadavg 90, and a rebaseline
    there would have carried every one of them unchanged [measured 2026-09-24
    in battery 12 at HEAD 1cd69eed5, 06-spaces_removeallatoms 27005 against a
    frozen 15519 among them]. The inference count is now this run's whenever
    our program ran to a single count, whatever either net did, which is the
    re-pin 48b3eedf9 and the baseline's own `wave3_merge_repin` note did by
    hand: "the within-tree inference tripwire only; no instruction number and
    no upstream number is touched".

    `names` restricts the run to those rows, and every other row and the null
    summary are copied from the committed baseline unchanged, so re-pinning
    eight rows neither pays for the other 353 nor absorbs whatever drift they
    carry.

    Only what this run could not measure is carried, and `carried` says which
    half that was, so nothing here ever tells a reader a stale number is fresh.
    Time: one measure/2 per engine per re-measured row, and one more for ours
    even where upstream's half is carried, since the inference count is ours.
    """
    previous = json.loads(BASELINE.read_text()) if BASELINE.exists() else {}
    if names is None:
        entries: dict[str, dict] = {"//": {"status": "meta", **_carried_meta()}}
    else:
        entries = {"//": previous.get("//", {"status": "meta"})}
    ratios = []
    negatives = []
    for example in corpus():
        name = str(example.relative_to(REPO))
        if names is not None and name not in names:
            if name in previous:
                entries[name] = previous[name]
            continue
        if name in UNMEASURABLE:
            entries[name] = {"status": "unmeasurable", "detail": UNMEASURABLE[name]}
            continue
        kept = previous.get(name, {})
        kept = kept if kept.get("status") == "measured" else {}
        carried = []
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
        if upstream["status"] == "ok":
            theirs = {"upstream_instructions": upstream["instructions"],
                      "upstream_null": upstream["fixed"]}
        elif upstream["status"] in _UNMEASURED and kept:
            theirs = {field: kept[field] for field in _UPSTREAM_HALF}
            carried.append(f"upstream-{upstream['status']}")
        else:
            entries[name] = _excluded(name, f"upstream-{upstream['status']}",
                                      upstream.get("detail", ""))
            continue
        ours = measure(REPO, example)
        if ours["status"] == "negative-net":
            entries[name] = {
                "status": "negative-net",
                **theirs,
                "our_instructions": ours["instructions"],
                "our_null": ours["fixed"],
                "our_inferences": ours["inferences"],
            }
            negatives.append(f"{name}: ours {ours['instructions']}")
            print(f"  {name}: OUR NET BELOW OUR OWN NULL CONTROL")
            continue
        if ours["status"] == "ok":
            mine = {"our_instructions": ours["instructions"], "our_null": ours["fixed"]}
        elif ours["status"] in _UNMEASURED and kept:
            mine = {field: kept[field] for field in _OUR_HALF}
            carried.append(ours["status"])
        elif ours["status"] in _UNMEASURED:
            entries[name] = _excluded(name, ours["status"], ours.get("detail", ""))
            continue
        else:
            entries[name] = {
                "status": "ours-fails",
                "detail": ours.get("detail", ""),
            }
            print(f"  {name}: OURS FAILS where upstream runs")
            continue
        # A program that ran to one count has an inference count whatever its
        # null did; `nondeterministic`, `unstable` and `timeout` leave none,
        # and only then is the committed count the one to keep.
        if "inferences" in ours:
            inferences = ours["inferences"]
        else:
            inferences = kept["our_inferences"]
            carried.append("inferences")
        entries[name] = {"status": "measured", **theirs, **mine,
                         "our_inferences": inferences}
        if carried:
            entries[name]["carried"] = ", ".join(carried)
            print(f"  {name}: carried {entries[name]['carried']}; "
                  f"inferences {kept.get('our_inferences')} -> {inferences}")
            continue
        ratio = ours["instructions"] / max(upstream["instructions"], 1)
        ratios.append(ratio)
        print(
            f"  {name}: instructions {upstream['instructions']} -> "
            f"{ours['instructions']} ({ratio:.2f}x)"
        )
    if names is None:
        entries["//"]["upstream_null"] = _null_summary(UPSTREAM)
        entries["//"]["our_null"] = _null_summary(REPO)
    print(f"upstream null program: {entries['//'].get('upstream_null')}")
    print(f"our null program:      {entries['//'].get('our_null')}")
    if ratios:
        print(f"median instruction ratio ours/upstream: {statistics.median(ratios):.3f}")
    for line in negatives:
        print(f"  NEGATIVE NET {line}")
    return entries


#Root-caused divergences, each waived with its cause on record; a waiver
#without a cause is a defect in this table. Anything not listed here
#still blocks.
# Each entry records the retained mechanism, an isolated control and the next
# unresolved lever. The complete before/after/upstream table and transcripts
# are indexed by docs/journal/2026-09-08-what-the-waivers-were-paying-for.md.
# Controls that disable observers or refusals price them; they are not shipped.
# [source: docs/journal/2026-09-08-what-the-waivers-were-paying-for.md:515;
# commit=32650f9ff4d1c4aa0749d8eb8b153e5bb448ee5c].
WAIVERS = {
    # Publication removes repeated owner selection and fixed envelope work.
    # These four entries remain until an accepted measurement clears the same
    # band; a refused null is never evidence for removing a waiver.
    # [source: docs/journal/2026-09-08-what-the-waivers-were-paying-for.md:728;
    # commit=e246959279271d22f166a1c8fb1840896295a020].
    "examples/ch05-equations-and-evaluation/05-02-changing-the-equations/03-functionremovalspec.metta": (
        "RULING for module isolation, OPEN for specialization invalidation and"
        " rebuilding. Grouped exact-reference retirement and scoped publication"
        " reduce the cut's 12631234/11932 to 12521592/11814 instructions/"
        " inferences; the unchanged upstream instruction pin is 10547671."
        " This remains outside the band. Suppressing source recording also"
        " changes three specialization installations to one and two retirements"
        " to one by leaving metadata behind, so that control cannot price"
        " removable journal work. Each erase and callback remains required;"
        " further savings must preserve ownership-dependent rebuilds."
    ),
    "examples/ch06-many-answers/02-casenew.metta": (
        "RULING for module isolation, OPEN for form-specific translation."
        " Fixed runnable controls now share compiled reader clauses and source"
        " publication reuses its owner decision. Inferences fall from 4791 to"
        " 4754. The supplied-window observation accepts 5623210 instructions"
        " against cut 5624218 and the unchanged upstream pin 4500639; the cut"
        " and final ranges overlap. Earlier null refusals remain recorded."
        " Each form still translates"
        " against its arrived source prefix and retains its ordinary effects."
    ),
    "examples/ch08-data/08-01-atoms-lists-and-folds/02-holfunctions.metta": (
        "RULING for module isolation, OPEN for generated-clause translation"
        " and its required ownership rows. Owner selection is now installed"
        " once per publication scope; every reference is still journalled at"
        " its original callback boundary. Inferences fall from 17360 to 17057."
        " The supplied window accepts 20080712 instructions against cut"
        " 20319982 and the unchanged upstream pin 17067487. Earlier null"
        " refusals remain recorded. Omitting the remaining"
        " journal writes loses failed-load cleanup and exact reload withdrawal."
    ),
    "examples/ch22-a-reasoner-you-can-serve/22-02-weighted-answers/03-plntest.metta": (
        "RULING for module isolation, OPEN for runtime type derivation and"
        " declaration publication. Compiled indexed expected-family witnesses"
        " and scoped ownership reduce 32700368/28408 to 32117704/27335"
        " instructions/inferences; the unchanged upstream instruction pin is"
        " 30032944, so the band is still exceeded. Actual accepted, failed and"
        " throwing get_type_rule callbacks retain their output and source error"
        " frames. Query-dependent tuple derivations cannot be discarded merely"
        " because the installed policy patterns are compiled."
    ),
    "examples/ch22-a-reasoner-you-can-serve/22-01-logic-programs/04-nilbc.metta": (
        "OPEN: repeated tuple type-witness derivation and dynamic rule-state"
        " reads. Indexed expected-family witnesses and source publication"
        " reduce the current cut's 150872089770/318186853 to"
        " 144677296125/310976936 instructions/inferences; live pinned upstream"
        " reads 11588345604/17937607. The unchanged instruction pin is"
        " 11592875186. The throwing tuple-retry differential retains four first"
        " callbacks followed by the second callback's exception and source"
        " frame. Installed policy witnesses cannot replace those runtime effects."
    ),
    "examples/ch05-equations-and-evaluation/05-01-an-equation-is-a-rewrite/02-twostage.metta": (
        "OPEN: form-specific translation and source ownership. Fixed runnable"
        " controls are now compiled once in the reader. Inferences fall from"
        " 4794 to 4763; final instructions are 5365097 against the unchanged"
        " upstream pin 4225208. Cut instructions are 5360867 with an overlapping"
        " range; the earlier null refusal remains recorded. Translation"
        " still reads the source prefix before each form; suppressing journal"
        " writes is not a sound substitute for that work."
    ),
    "examples/ch08-data/08-01-atoms-lists-and-folds/03-holfunctions_intrinsicop.metta": (
        "OPEN: runnable test-form translation and effect classification."
        " The fixed answer, name and fuel envelope is now shared compiled code;"
        " scoped publication retains every journal write. Inferences fall from"
        " 11244 to 11159. The supplied window accepts cut 12499450 and final"
        " 12547385 instructions with overlapping ranges; the unchanged upstream"
        " instruction pin is 10184408. Earlier null refusals remain recorded."
        " The remaining form-specific conjunction"
        " still compiles against the current source prefix."
    ),
    "examples/ch07-control-flow/07-05-recursion/02-fib.metta": (
        "RULING: pinned upstream fails the explicit with-pragma! wrapper."
        " Removing only that wrapper gives the same 832040 answer on both"
        " engines, 26852009 instructions/23434 inferences here against"
        " 7359284574/17510131 upstream. The compiled recursive cache_call"
        " visits 31 Fibonacci states. This is automatic memoization, not"
        " an arithmetic-guard regression; the original row has no ratio."
    ),
    "examples/ch22-a-reasoner-you-can-serve/22-02-weighted-answers/04-plntestdirect.metta": (
        "OPEN: equation installation and support/source ownership. The"
        " journal-write control removes 99 inferences and 582157 instructions"
        " with the same answer transcript. The full row still retires more"
        " instructions despite fewer inferences than upstream. Next: price"
        " declaration compilation separately from support-edge installation;"
        " no source-only scan is inferred from the whole-file ratio."
    ),
    "examples/ch22-a-reasoner-you-can-serve/22-02-weighted-answers/05-pln_direct.metta": (
        "RULING: upstream fails this file's noeval answer assertion; its"
        " cost is not a comparable successful program. Our file costs"
        " 89510921 instructions/90012 inferences. A paired source-journal"
        " control removes 403 inferences and 1279054 instructions with the"
        " same successful answers. OPEN: separate premise translation and"
        " support invalidation after choosing a common upstream answer fixture."
    ),
    "examples/ch06-many-answers/08-permutations.metta": (
        "OPEN: native candidate enumeration and relational-conjunct choice."
        " Removing only the output-template acyclic_term checks saves"
        " 362880 inferences and 706919398 instructions. Those checks are"
        " required for upstream's cyclic-template refusal and are retained."
        " Next: compile stable candidate dispatch and conjunct selection"
        " while preserving duplicate witnesses and bounded streaming."
    ),
    "examples/ch22-a-reasoner-you-can-serve/22-03-search/02-tilepuzzle.metta": (
        "OPEN: native candidate enumeration plus 483842 public repra keys"
        " in add-unique-or-fail. Omitting only output-template cycle checks"
        " removes 302402 inferences and 70274860 instructions. Omitting"
        " source-journal writes does not reduce instructions, so it is not"
        " the measured instruction bottleneck here. Next: compile native"
        " dispatch and price serialization without changing stored Symbol"
        " keys, duplicate answers or cyclic-template refusals."
    ),
    "examples/ch05-equations-and-evaluation/05-02-changing-the-equations/04-specialize.metta": (
        "OPEN: effect classification and source-owned generated clauses."
        " Removing source-journal writes saves 330 inferences/1868481"
        " instructions; returning an empty declared-effect set saves 1472"
        " inferences/834948 instructions. Neither capability is removed."
        " Next: retain one effect/support summary per installed clause and"
        " invalidate only the changed dependencies during specialization."
    ),
    "examples/ch11-python-as-a-notation/07-torch.metta": (
        "UNMEASURED: both engines have no majority instruction mode across"
        " seven processes after warmup. No crossing price or instruction"
        " ratio follows from that distribution. Next: isolate a warmed"
        " tensor operation with an empty-call control before attributing"
        " Python or PyTorch initialization and allocator work."
    ),
    "examples/ch19-spaces-backed-by-anything/19-03-a-builtin-in-c/01-c_extension.metta": (
        "RULING: upstream takes the missing-file SKIP branch because the"
        " file-exists preflight is unavailable, although its C seam works."
        " A common program that calls and checks c-bump costs 31256118"
        " instructions here versus 47490682 upstream. Direct loops price"
        " the call at 414 instructions and one inference on both engines."
        " The original 158272382/48573209 comparison prices different work,"
        " including our lib_file preflight; it is not a crossing regression."
    ),
    "examples/ch19-spaces-backed-by-anything/19-03-a-builtin-in-c/02-handle.metta": (
        "RULING: upstream skips the original file preflight. The shared"
        " three-call handle program passes both engines at 39459407 versus"
        " 52045508 instructions; direct calls cost 583 instructions and one"
        " inference each on both. Upstream then fails the original Grounded"
        " metatype check when forced to execute it. The 167201091/55931310"
        " original costs do not compare the same capability."
    ),
    "examples/ch20-extending-the-engine/20-02-metta-written-in-metta/02-callquoteevalreduce2.metta": (
        "OPEN: translation of the quote/eval/reduce interpreter and its"
        " source-owned clauses. The journal-write control saves 84"
        " inferences and 392481 instructions with unchanged answers. That"
        " does not price the remaining meta-evaluation result checks. Next:"
        " split compiled interpreter installation from repeated calls and"
        " compare their result-orientation checks independently."
    ),
    "examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/_fixtures/imports/relative/root.metta": (
        "OPEN: import receipt/content hashing and source-owned declarations."
        " The source-journal control removes eight inferences but only"
        " 42797 instructions, below the measurement floor. It does not"
        " explain the whole 11820790-instruction gap. Next: isolate receipt"
        " digest and support invalidation separately, preserving the"
        " unchanged-import and failed-load behavior."
    ),
    "examples/ch05-equations-and-evaluation/05-02-changing-the-equations/06-specializecyclic.metta": (
        "OPEN: installing specialized recursive clauses and their source"
        " ownership. Omitting journal writes saves 92 inferences/431737"
        " instructions; omitting declared-effect reads changes no inferences"
        " and only 42464 instructions, below the measurement floor. Next:"
        " price the generated-clause support graph independently of its"
        " recursive evaluation, retaining dependency invalidation."
    ),
    "examples/ch10-errors-and-refusals/01-he_error.metta": (
        "RULING: upstream aborts with Arithmetic: a/0 is not a function;"
        " this engine returns Error data and executes the remaining forms,"
        " at 6595565 instructions/8122 inferences for the complete file."
        " Removing journal writes changes only two inferences and 2554"
        " instructions, below the floor. No successful cross-engine ratio"
        " exists; the retained capability is error reification and recovery."
    ),
    "examples/ch08-data/08-01-atoms-lists-and-folds/15-roman.metta": (
        "OPEN: repeated effect classification during operator-clause"
        " installation and support invalidation. The empty-effect control"
        " removes 15584 inferences/9663023 instructions; removing only"
        " source-journal writes removes 776/3761186. The controls preserve"
        " this answer transcript but disable observers, so are not shipped."
        " Next: reuse clause effect summaries with dependency-scoped invalidation."
    ),
    "examples/ch18-performance/18-02-memoisation-and-tabling/09-tabling_fib.metta": (
        "OPEN: first installation of the table policy and invalidation"
        " declarations. Import alone costs 126156652 instructions here"
        " versus 15289509 upstream, out of full-file 144806322/20708161."
        " The effect-read control saves 1632 inferences/1590833 instructions."
        " Direct compiled-versus-raw table calls price retained result"
        " checks at two inferences and about 1240 instructions per call."
        " Next: compile invariant declaration work while preserving policy"
        " registration, table ownership and targeted invalidation."
    ),
    "examples/ch22-a-reasoner-you-can-serve/22-03-search/05-fibadd.metta": (
        "RULING: pinned upstream fails the explicit with-pragma! wrapper."
        " Without only that wrapper both engines answer 832040; ours costs"
        " 26244027 instructions/23211 inferences versus 7368816467/17510470."
        " Automatic recursive memoization explains the improvement. The"
        " original file has no comparable successful upstream cost."
    ),
    "examples/ch22-a-reasoner-you-can-serve/22-03-search/04-matespace2.metta": (
        "OPEN: private-storage candidate dispatch and output-template cycle"
        " checks. Omitting the checks saves 2823702 inferences and"
        " 6001414772 instructions; omitting journal writes does not save"
        " instructions. Cyclic-template refusal remains required. Next:"
        " compile storage calls from known relation shapes while retaining"
        " duplicate witnesses, answer checks and streaming backtracking."
    ),
    "examples/ch18-performance/18-01-larger-workloads/03-superpose_primes.metta": (
        "RULING: upstream fails the explicit with-pragma! wrapper. Without"
        " that wrapper both engines answer four true values, at 193063512"
        " instructions/418718 inferences here versus 144509714/336481."
        " The original budget adds 122052 inferences in the paired program"
        " control. OPEN: the common program's guarded arithmetic and"
        " compiled call envelope still exceed upstream; separate them with"
        " valid and invalid operand controls before changing either."
    ),
    "examples/ch22-a-reasoner-you-can-serve/22-02-weighted-answers/08-nars_direct.metta": (
        "RULING: upstream fails the noeval answer assertion; the original"
        " file has no comparable successful upstream cost. Ours costs"
        " 88713675 instructions/74438 inferences. Omitting source-journal"
        " writes saves 348 inferences/1057842 instructions with unchanged"
        " successful answers. OPEN: isolate premise translation and"
        " support invalidation on a common upstream answer fixture."
    ),
    "examples/ch18-performance/18-01-larger-workloads/01-scale.metta": (
        "RULING for source ownership, OPEN for the remaining write path:"
        " one million additions retain source references so failure or reload"
        " can withdraw their contribution. Omitting those journal assertions"
        " saves 1000051 inferences and 2467983272 instructions while this"
        " successful file's answers stay unchanged. Removing them would"
        " break rollback and reload. Next: batch ownership records with the"
        " native write operation, preserving per-clause erasure references."
    ),
    "examples/ch22-a-reasoner-you-can-serve/22-03-search/03-matespace.metta": (
        "RULING for the cycle refusal, OPEN for native dispatch: omitting"
        " only output-template checks saves 2050426 inferences and"
        " 6206977297 instructions, enough to cross the allowance in that"
        " control. A cyclic template must still fail as upstream requires."
        " Journal-write removal does not reduce instructions. Next: prove"
        " cycle safety at compiled call sites or remove candidate-call"
        " construction while retaining rational-tree bindings and answer bags."
    ),
}


def verdicts(baseline: dict, *, remeasure: bool) -> int:
    """Judge this tree against the baseline, remeasuring it first unless frozen."""
    cross, drift, negative, unstable = [], [], [], []
    waived, unmeasured = {}, []
    checked = 0
    for name, entry in sorted(baseline.items()):
        if entry.get("status") in ("unmeasurable-null", "upstream-unmeasurable-null"):
            unmeasured.append(f"{name}: {entry['status']} {entry.get('detail', '')}")
            continue
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
            # A usable program sample still prices its inferences when its
            # separately measured null cannot support an instruction verdict.
            drift_allowed = (
                entry["our_inferences"] * INFERENCE_RATIO + INFERENCE_ABSOLUTE
            )
            if ours.get("inferences", 0) > drift_allowed:
                drift.append(
                    f"{name}: {ours['inferences']} inferences against the "
                    f"frozen {entry['our_inferences']}"
                )
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
            if ours["status"] in ("timeout", "unstable", "unmeasurable-null"):
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
            if remeasure:
                line += (
                    f"; difference {ours['lowest']}..{ours['highest']}; "
                    f"program {ours['program_range'][0]}..{ours['program_range'][1]}, "
                    f"null {ours['null_range'][0]}..{ours['null_range'][1]}"
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
                    f"{allowed:.0f} over {ours['runs']} runs; "
                    f"program {ours['program_range'][0]}..{ours['program_range'][1]}, "
                    f"null {ours['null_range'][0]}..{ours['null_range'][1]}"
                )
            elif name in WAIVERS:
                waived[name] = line
            else:
                cross.append(line)
    print(f"upstream parity: {checked} examples checked, loadavg {_loadavg()}")
    for line in cross:
        print(f"  CROSS-ENGINE REGRESSION {line}")
    for name in sorted(baseline.keys() & WAIVERS.keys()):
        line = waived.get(name, f"{name}: active ruling; no cross-engine excess "
                          "established in this comparison")
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
    """Whether the upstream checkout holds an engine this can measure."""
    return holds_engine(UPSTREAM)


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

    `remedy` is the sentence a refusal or skip ends on, because the two lanes
    that call this send a reader somewhere different: this one to the page
    carrying the numbers, and check_upstream_fuzz to its own lane. The POLICY
    is one piece of code on purpose, since two copies of it are two things that
    can drift into disagreeing about when a missing checkout is allowed to pass.

    An absent checkout REFUSES, exit 1, wherever the lane runs. It used to
    refuse only where CI=true and print a skip elsewhere, and a skip is a
    verdict about nothing: every battery run carried this lane as `skipped`
    until 2026-09-24, because no battery found the checkout (see
    upstream_candidates). METTA_UPSTREAM_OPTIONAL=1 is the operator saying so
    explicitly, and turns the refusal into that skip, 125, which check.sh's
    run() reports as `skipped` under MEASURED NOTHING rather than as a pass.
    CI=true refuses whatever it says, since an opt-out that reached CI would
    let the gate pass there having measured nothing.
    """
    if upstream_present():
        return None
    looked = UPSTREAM_CANDIDATES if UPSTREAM in UPSTREAM_CANDIDATES else [UPSTREAM]
    absence = "upstream checkout not found at " + ", ".join(str(p) for p in looked)
    supply = (
        f"Check {UPSTREAM_REMOTE} out at {UPSTREAM_COMMIT} beside the "
        "repository's main checkout, or name one with METTA_UPSTREAM"
    )
    optional = os.environ.get("METTA_UPSTREAM_OPTIONAL") == "1"
    if optional and os.environ.get("CI") != "true":
        print(f"note: {absence}; METTA_UPSTREAM_OPTIONAL=1 skips the comparison. "
              f"{supply}; {remedy}")
        return 125
    why = ("METTA_UPSTREAM_OPTIONAL does not apply where CI=true" if optional
           else "METTA_UPSTREAM_OPTIONAL=1 skips it outside CI")
    print(f"error: {absence}; refusing to pass the parity gate without it "
          f"({why}). {supply}; {remedy}", file=sys.stderr)
    return 1


def parse_arguments(argv: list[str] | None = None) -> argparse.Namespace:
    """The lane's command line, parsed: the one place its shape is decided.

    `rebaseline` is None without the flag and the list of named rows with it,
    empty meaning every row. A caller that built the namespace by hand wrote
    `rebaseline=False`, the shape of the boolean flag this replaced, which the
    list shape reads as given: the artifact fixture then ran a full rebaseline
    over the real corpus instead of the fixture it meant [measured 2026-09-24
    in battery 16, 1881s]. So the selftest parses through here too.
    """
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--rebaseline",
        nargs="*",
        metavar="EXAMPLE",
        help="re-measure the named corpus rows, or every row when none is named",
    )
    parser.add_argument(
        "--frozen",
        action="store_true",
        help="judge the stored numbers without re-measuring this tree",
    )
    return parser.parse_args(argv)


def main() -> int:
    """Report the parity verdicts, rebuilding the baseline under --rebaseline."""
    arguments = parse_arguments()
    absent = upstream_prerequisite()
    if absent is not None:
        return absent
    try:
        return _judge(arguments)
    except CounterUnavailableError as unavailable:
        return refused(str(unavailable))
    except subprocess.CalledProcessError as failed:
        print(f"error: parity artifact setup failed at exit {failed.returncode}: "
              f"{(failed.stderr or failed.stdout or '').strip()}", file=sys.stderr)
        return 1


def _judge(arguments: argparse.Namespace) -> int:
    """Every verdict this lane reaches once the prerequisites hold."""
    #Only --rebaseline READS the sibling checkout; the gate path re-measures
    #this tree and compares against upstream numbers already frozen in the
    #baseline. So a checkout at the wrong commit is fatal to a rebaseline,
    #which would attribute fresh numbers to a pin they did not come from, and
    #is worth saying but not worth failing for anywhere else.
    #`--rebaseline` with no example is an empty list, which is falsy, so the
    #question is whether the flag was given at all.
    rebaseline = arguments.rebaseline is not None
    try:
        names = rebaseline_names(arguments.rebaseline or [])
    except ValueError as unknown:
        print(f"error: {unknown}; refusing to rebaseline.", file=sys.stderr)
        return 2
    head = upstream_head()
    if head is not None and head != UPSTREAM_COMMIT:
        drift = (
            f"{UPSTREAM} is at {head}, not the pinned {UPSTREAM_COMMIT} that "
            "the recorded upstream numbers were measured from"
        )
        if rebaseline:
            print(f"error: {drift}; refusing to rebaseline against it.",
                  file=sys.stderr)
            return 1
        print(f"note: {drift}; this run does not read it, so the verdicts hold.")
    if rebaseline or not arguments.frozen or not BASELINE.exists():
        prepare_artifacts()
    if rebaseline or not BASELINE.exists():
        entries = build_baseline(names)
        BASELINE.write_text(json.dumps(entries, indent=1, sort_keys=True) + "\n")
        print(f"baseline written: {BASELINE}")
        broken = [n for n, e in entries.items() if e.get("status") == "ours-fails"]
        if broken:
            return 1
        return verdicts(entries, remeasure=False)
    return verdicts(json.loads(BASELINE.read_text()), remeasure=not arguments.frozen)


if __name__ == "__main__":
    sys.exit(main())
