"""Purpose: prove the parity lane subtracts the null control and reports a net below it.

Every plant passes through ``check_upstream_parity`` itself, with only
``_perf`` replaced, so the selftest and the production lane cannot drift into
testing different questions. A table standing in for ``_perf`` exercises the
sampling, marker-parsing, fresh calibration, netting and verdict path. The artifact
fixture test separately runs the real shipping loader twice and restores the
generated files it borrowed.

The questions are the halves of the 2026-09-06 defect:

- the net must be taken against the NULL PROGRAM at the row's own path shape.
  Until 2026-09-06 it was taken against a separate boot fixture, which is a
  different process with a different command line, and on this box that
  fixture read 8,661,096 instructions ABOVE the null program for this engine
  and 4,594,811 BELOW it for upstream.
- a net below zero must be REPORTED. Under the old rule it was recorded as a
  measurement and the page dropped it: seven rows of the 2026-08-31 baseline
  read between -94,022 and -50,470,138 and PERFORMANCE.md said only that they
  were "excluded rather than reported as a negative".
- the estimator must survive one run in three landing 35,083,561 low, which is
  where SWI's collector thread finishing inside the process instead of after
  it puts a run.
- a measurement that times out must leave nothing running.

Each question is one function below, named for what it plants, and ``main``
runs them in order and prints what they answer.

Assumes: an ``examples/`` corpus with at least two files, used only for their
  names and path shapes.
Guarantees:
  - each program has a fresh null sample: a changed fixed cost cancels in
    either direction, while added program work still fails the same band
    [tested: check_upstream_parity_selftest.fresh_null_failures; commit=8ca8a387fc61d0918484b19a1a3baf85b6523043]
  - two shipping fixture generations have the same artifact set and content
    digests after removing only the embedded temporary filename's compiler
    PID and its derived offsets. A planted foreign artifact is removed
    [tested: check_upstream_parity_selftest.artifact_fixture_failures; commit=8ca8a387fc61d0918484b19a1a3baf85b6523043]
  - every active waiver remains visible while its separate measurement verdict
    is preserved [tested: parity-perf-selftest; commit=8ca8a387fc61d0918484b19a1a3baf85b6523043]
  - null extrema bound the compared difference, an overrun beyond the whole
    range still fails, and a null spread beyond its measured resolution is
    explicitly unmeasurable without hiding inference drift [tested:
    check_upstream_parity_selftest.null_range_failures; commit=8ca8a387fc61d0918484b19a1a3baf85b6523043]
  - both upstream lanes prefer METTA_UPSTREAM to the sibling checkout, including
    a configured path that is absent [tested: check_upstream_parity_selftest.upstream_selection_failures;
    commit=8ca8a387fc61d0918484b19a1a3baf85b6523043]
  - a planted engine whose fixed cost exceeds its program run is reported as
    ``negative-net`` by ``measure`` and turns ``verdicts`` red, while the rule
    this file replaced records the same numbers and stays green
    [tested: this file is its own gate; commit=2b61fa1947e4de5b02dd8d819ba0e16ec3a07276]
  - the recorded net is the program run minus the null run at that row's own
    path length AND directory count, and a control taken at another shape
    gives a different answer, so shape-matching is load-bearing rather than
    decorative [tested: this file is its own gate; commit=2b61fa1947e4de5b02dd8d819ba0e16ec3a07276]
  - ``--rebaseline`` carries a meta note forward instead of dropping it
    [tested: this file is its own gate; commit=2b61fa1947e4de5b02dd8d819ba0e16ec3a07276]
  - ``null_program`` builds a control with its example's character count AND
    its directory count, and refuses a shape its root cannot name, naming the
    edit [tested: this file is its own gate; commit=2b61fa1947e4de5b02dd8d819ba0e16ec3a07276]
  - a measurement that outlives ``TIMEOUT`` leaves nothing running, checked on
    the real shape: the timed process is the wrapper and the survivor would be
    its grandchild [tested: this file is its own gate; commit=2b61fa1947e4de5b02dd8d819ba0e16ec3a07276]
  - one cheap run in three is ignored rather than taken and the sample is
    extended; three cheap in seven still answer the cost the other four agree
    on; a cold first touch is discarded rather than counted; and a program
    with no mode at all is reported as having no cost
    [tested: this file is its own gate; commit=2b61fa1947e4de5b02dd8d819ba0e16ec3a07276]
  - an absent upstream checkout refuses where ``CI=true`` and prints a skip
    naming the pin elsewhere, the sibling checkout is AT that pin, and a
    kernel or container that denies the counter is named with the two knobs
    that decide it [tested: this file is its own gate; commit=fc990fa3042ee05d931d3928694e89021be32855]
Owns resources: artifact_fixture_failures restores the bytes and timestamps of
  the checkout's original generated artifacts and stamp, including on failure.
  check.sh serializes lanes that share them.
Fails when: the production lane stops exposing ``_perf`` as its measured process
  call, or stops computing a row's net inside ``measure``.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import argparse
import contextlib
import hashlib
import io
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import check_upstream_parity as lane  # noqa: E402
from qlf_header import NotQlfError, read_header  # noqa: E402

#: The two costs a plant assigns, keyed by what the driver was handed. A null
#: control is any program under NULL_ROOT and costs FIXED; everything else is
#: an example and costs FIXED plus its own WORK, which is what the row records.
FIXED = 1_000_000_000
WORK = 250_000

#: The inference count a plant reports unless it names its own.
PLANTED_INFERENCES = 4321

#: How far one run in three lands below the others, because SWI's collector
#: thread sometimes finishes inside the process and sometimes after it.
EXCURSION = 35_083_561


@contextlib.contextmanager
def planted(cost):
    """Run the production lane with `cost(engine_root, program)` standing in for perf.

    A plant is handed what the driver was handed, so a cost can differ per
    engine the way the real fixed cost does. Every plant below answers the
    same for both engines, and spells that parameter `_engine_root` to say so.
    """
    original = lane._perf
    lane._FIXED_COST.clear()

    def fake(command):
        engine_root, program = command[-2], command[-1]
        answer = cost(engine_root, program)
        #A plant may name the inference count too, which is how the discarded
        #warm-up run is testable: a cold first touch differs in both.
        instructions, inferences = (
            answer if isinstance(answer, tuple) else (answer, PLANTED_INFERENCES)
        )
        completed = subprocess.CompletedProcess(
            args=command,
            returncode=0,
            stdout=f"PARITY-INFERENCES:{inferences}\n",
            stderr="",
        )
        return instructions, completed

    lane._perf = fake
    try:
        yield
    finally:
        lane._perf = original
        lane._FIXED_COST.clear()


def is_null(program: str) -> bool:
    """Whether the driver was handed a null control rather than a corpus example."""
    return program.startswith(str(lane.NULL_ROOT))


#Reading /proc rather than matching a pattern with a tool whose own command
#line carries the pattern: this repository has already had a `pgrep -f` match
#the waiter that ran it.
def survivors(marker: str) -> list[int]:
    """Every live process whose command line carries `marker`."""
    found = []
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            command = (entry / "cmdline").read_bytes().decode(errors="replace")
        except OSError:
            continue
        if marker in command and int(entry.name) != os.getpid():
            found.append(int(entry.name))
    return found


#The rule this file replaced, in effect verbatim: a per-engine constant from
#tests/fixtures/parity_boot.pl, subtracted from every run.
#    instructions.append(count - boot)
#[source: tests/checks/check_upstream_parity.py at 749f5864, measure/3]
def old_rule_net(raw: int, boot: int) -> int:
    """The net the rule this file replaced would have recorded."""
    return raw - boot


def honest_plant_failures(example: Path) -> list[str]:
    """A control that behaves: the net a row records is the program's own work.

    The program run costs its null control plus that work, and the work is
    what has to come out the other side whatever the fixed cost was.
    """
    failures: list[str] = []

    def honest(_engine_root, program):
        return FIXED if is_null(program) else FIXED + WORK

    with planted(honest):
        measured = lane.measure(lane.REPO, example)
    if measured["status"] != "ok":
        failures.append(f"an honest plant did not measure: {measured}")
    elif measured["instructions"] != WORK:
        failures.append(
            f"the net is {measured['instructions']} where the program's own work "
            f"is {WORK}; it is not being taken against the null control"
        )
    return failures


def shape_matching_failures(corpus: list[Path], example: Path) -> list[str]:
    """The net must come from the control at THIS row's SHAPE.

    Plant a fixed cost that rises with both the path length and the directory
    count, the way the real one does, and check each row is charged its own
    shape.
    """
    failures: list[str] = []
    per_character = 5_638  # ours, measured 2026-09-06 across a 78-character span
    per_directory = 13_782  # ours, measured 2026-09-06 across six components

    def by_shape(_engine_root, program):
        base = (FIXED + per_character * len(program)
                + per_directory * program.count("/"))
        return base if is_null(program) else base + WORK

    other = next(
        (p for p in corpus if len(str(p)) != len(str(example))), corpus[1]
    )
    deeper = next(
        (p for p in corpus if len(p.parts) != len(example.parts)), other
    )
    with planted(by_shape):
        here = lane.measure(lane.REPO, example)
        there = lane.measure(lane.REPO, other)
        below = lane.measure(lane.REPO, deeper)
    if any(row.get("instructions") != WORK for row in (here, there, below)):
        failures.append(
            "a shape-dependent fixed cost leaked into the net: "
            f"{here.get('instructions')}, {there.get('instructions')} and "
            f"{below.get('instructions')} against a planted {WORK} each"
        )
    if len(str(example)) != len(str(other)) and here.get("fixed") == there.get("fixed"):
        failures.append(
            "two rows of different path length shared one control, so the "
            "control is not length-matched"
        )
    if len(example.parts) != len(deeper.parts) and here.get("fixed") == below.get("fixed"):
        failures.append(
            "two rows of different directory count shared one control, so the "
            "control is not depth-matched"
        )
    return failures


def excursion_failures(example: Path) -> list[str]:
    """One cheap run in three is ignored and the sample extended, three in seven are not.

    One run in three lands EXCURSION low, because SWI's collector thread
    sometimes finishes inside the process and sometimes does not. The minimum
    takes that run every time it appears; the median has to ignore it. Three
    excursions in seven still leave the median where the other four agree, and
    that is the answer, so it must NOT be reported as a defect: a lane that
    failed there would fail on a busy box for nothing.
    """
    failures: list[str] = []
    seen = {"n": 0}

    def sometimes_cheap(_engine_root, program):
        if is_null(program):
            return FIXED
        seen["n"] += 1
        return FIXED + WORK - (EXCURSION if seen["n"] % 3 == 1 else 0)

    with planted(sometimes_cheap):
        steady = lane.measure(lane.REPO, example)
    if steady.get("instructions") != WORK:
        failures.append(
            f"one cheap run in three moved the recorded cost to "
            f"{steady.get('instructions')} against the {WORK} the other two agree on"
        )
    if steady.get("runs") != lane.RUNS + lane.EXTRA_RUNS:  # counted, not spawned
        failures.append(
            f"runs that disagreed by {EXCURSION} were not extended: "
            f"{steady.get('runs')} runs taken"
        )

    seen["n"] = 0

    def cheap_three_in_seven(_engine_root, program):
        if is_null(program):
            return FIXED
        seen["n"] += 1
        return FIXED + WORK - (EXCURSION if seen["n"] in (1, 4, 6) else 0)

    with planted(cheap_three_in_seven):
        minority = lane.measure(lane.REPO, example)
    if minority.get("status") != "ok" or minority.get("instructions") != WORK:
        failures.append(
            f"three cheap runs in seven left the row {minority.get('status')} at "
            f"{minority.get('instructions')} rather than ok at {WORK}"
        )
    return failures


def warmup_failures(example: Path) -> list[str]:
    """A cold first touch is discarded rather than counted.

    The first touch of three corpus rows writes a cache their later runs read,
    so its cost AND its inference count differ. One discarded run is what
    stops that reading as a nondeterministic row on a fresh checkout.
    """
    failures: list[str] = []
    seen = {"n": 0}

    def cold_first_touch(_engine_root, program):
        if is_null(program):
            return FIXED
        seen["n"] += 1
        if seen["n"] == 1:
            return FIXED + WORK + 9_000_000, PLANTED_INFERENCES + 4_000
        return FIXED + WORK, PLANTED_INFERENCES

    with planted(cold_first_touch):
        warmed = lane.measure(lane.REPO, example)
    if warmed["status"] != "ok" or warmed.get("instructions") != WORK:
        failures.append(
            f"a cold first touch left the row {warmed['status']} at "
            f"{warmed.get('instructions')}; the warm-up run is not being discarded"
        )
    elif warmed.get("inferences") != PLANTED_INFERENCES:
        failures.append(
            f"the row recorded the cold run's {warmed['inferences']} inferences"
        )
    return failures


def modeless_failures(example: Path) -> list[str]:
    """A program with no mode at all is reported as having no cost.

    Saying so beats picking a number: every run lands somewhere different, so
    nothing supports a median.
    """
    failures: list[str] = []
    seen = {"n": 0}

    def no_mode(_engine_root, program):
        if is_null(program):
            return FIXED
        seen["n"] += 1
        return FIXED + WORK + seen["n"] * EXCURSION

    with planted(no_mode):
        spread = lane.measure(lane.REPO, example)
    if spread["status"] != "unstable":
        failures.append(
            f"a program whose every run costs something different was reported "
            f"as {spread['status']}, not unstable"
        )
    return failures


def overstated_control_failures(example: Path, name: str) -> list[str]:
    """The defect itself: a fixed cost measured ABOVE what a run of the program costs.

    This is what the boot fixture did, by 8,661,096 instructions. It must be
    reported as `negative-net` and turn the lane red rather than passing
    quietly. The discrimination is what makes the plant a regression rather
    than an assertion: the rule this file replaced records exactly the same
    numbers and stays green, because a negative net is smaller than every
    allowance there is.
    """
    failures: list[str] = []
    overstatement = 8_661_096

    def overstated(_engine_root, program):
        return FIXED + overstatement if is_null(program) else FIXED + WORK

    with planted(overstated):
        broken = lane.measure(lane.REPO, example)
    if broken["status"] != "negative-net":
        failures.append(
            f"a control measured {overstatement} above the program run was reported "
            f"as {broken['status']}, not negative-net"
        )
    elif broken["instructions"] >= 0:
        failures.append("a negative-net row did not record its negative net")

    baseline = {
        "//": {"status": "meta"},
        name: {
            "status": "measured",
            "upstream_instructions": 10_000_000,
            "upstream_null": FIXED,
            "our_instructions": WORK,
            "our_null": FIXED,
            "our_inferences": PLANTED_INFERENCES,
        },
    }
    with planted(overstated):
        verdict = lane.verdicts(baseline, remeasure=True)
    if verdict == 0:
        failures.append("a negative net passed the lane instead of failing it")

    old_net = old_rule_net(FIXED + WORK, FIXED + overstatement)
    if old_net >= 0:
        failures.append("the replayed old rule did not reproduce a negative net")
    old_allowed = (
        baseline[name]["upstream_instructions"] * lane.INSTRUCTION_RATIO
        + lane.INSTRUCTION_ABSOLUTE
    )
    if old_net > old_allowed:
        failures.append(
            "the replayed old rule flagged the planted row, so the plant does "
            "not discriminate between the two rules"
        )
    return failures


def frozen_negative_net_failures(name: str) -> list[str]:
    """A recorded negative net is a defect too, under either status a baseline writes.

    So a frozen baseline carrying one cannot pass, whether it says
    `negative-net` the way this file writes it or `measured` the way the old
    one wrote it seven times.
    """
    failures: list[str] = []
    frozen = {
        "//": {"status": "meta"},
        name: {
            "status": "negative-net",
            "our_instructions": -50_470_138,
            "our_null": FIXED,
        },
    }
    if lane.verdicts(frozen, remeasure=False) == 0:
        failures.append("a baseline holding a negative net passed the lane")
    as_measured = {
        "//": {"status": "meta"},
        name: {
            "status": "measured",
            "upstream_instructions": 6_086_421,
            "our_instructions": -50_470_138,
            "our_inferences": PLANTED_INFERENCES,
        },
    }
    if lane.verdicts(as_measured, remeasure=False) == 0:
        failures.append(
            "a baseline recording a negative net as `measured`, which is what "
            "the old one did seven times, passed the lane"
        )
    return failures


def carried_meta_failures() -> list[str]:
    """A re-pin note is a record: rebuilding the meta block must not drop it."""
    failures: list[str] = []
    with tempfile.TemporaryDirectory() as scratch:
        stored = Path(scratch) / "baseline.json"
        note = "RE-PINNED 2026-09-06, and this sentence has to survive a rebaseline"
        stored.write_text(json.dumps({"//": {"status": "meta", "a_repin": note,
                                             "our_boot": 1}}))
        original_baseline = lane.BASELINE
        lane.BASELINE = stored
        try:
            carried = lane._carried_meta()
        finally:
            lane.BASELINE = original_baseline
    if carried.get("a_repin") != note:
        failures.append("a rebaseline drops the meta notes the baseline already held")
    if "our_boot" in carried:
        failures.append("a rebaseline carries forward a field it recomputes")
    return failures


def timeout_failures() -> list[str]:
    """A timed-out measurement must not leave the engine running.

    The topology is the real one and it is the whole point: the process being
    timed is the wrapper, bounded.sh's death signal reaches the wrapper's
    child, and the engine is that child's OWN child. `sleep` here stands where
    swipl stands under perf, one level below anything a kill or a pdeathsig
    reaches, so a kill aimed at the timed process leaves it running exactly as
    it did on 2026-09-06.
    """
    failures: list[str] = []
    #The grandchild gets its own stdio on purpose. Holding the harness's pipe
    #makes the post-kill communicate() wait for the orphan to finish, so by the
    #time anything could look, the orphan has exited of its own accord and a
    #leak is invisible. Redirecting it separates the two failures and leaves
    #this check measuring the one it names.
    marker = f"{29.0 + os.getpid() % 1000 / 1000:.3f}"
    original_timeout = lane.TIMEOUT
    lane.TIMEOUT = 2
    try:
        lane._spawn(["sh", "-c", f"sleep {marker} >/dev/null 2>&1 & wait"])
    except subprocess.TimeoutExpired:
        pass
    else:
        failures.append("a command that outlives TIMEOUT did not raise")
    finally:
        lane.TIMEOUT = original_timeout
    left = survivors(marker)
    if left:
        for pid in left:
            with contextlib.suppress(ProcessLookupError):
                os.kill(pid, 9)
        failures.append(
            f"a timed-out measurement left {left} running; the kill reached the "
            "process being timed and not the session under it"
        )
    return failures


def null_program_failures(example: Path) -> list[str]:
    """The control has to match the example's directory count as well as its length.

    Or an empty file at seven components reads 139,684 instructions against a
    control at one.
    """
    failures: list[str] = []
    deep, shallow = lane.null_program(120, 6), lane.null_program(120, 0)
    if len(str(deep)) != 120 or len(str(shallow)) != 120:
        failures.append(
            f"a control asked for 120 characters answered {len(str(deep))} and "
            f"{len(str(shallow))}"
        )
    if len(deep.parts) - len(shallow.parts) != 6:
        failures.append(
            "a control asked for six directories and one for none differ by "
            f"{len(deep.parts) - len(shallow.parts)} components"
        )
    control = lane.null_program(*lane.null_shape(example))
    if len(control.parts) != len(example.parts) or len(str(control)) != len(str(example)):
        failures.append(
            f"a control for {example} has {len(control.parts)} components and "
            f"{len(str(control))} characters against the example's "
            f"{len(example.parts)} and {len(str(example))}"
        )
    return failures


def upstream_selection_failures() -> list[str]:
    """Both lanes honor the configured checkout before testing its presence."""
    failures: list[str] = []
    configured = lane.REPO / "ai-tmp" / "ai upstream selection fixture"
    code = (
        "import runpy, sys; from pathlib import Path; "
        "sys.path.insert(0, str(Path(sys.argv[1]).parent)); "
        "print(runpy.run_path(sys.argv[1])['UPSTREAM'])"
    )
    for script in ("check_upstream_parity.py", "check_jupyter_kernel.py"):
        for value in (None, str(configured)):
            environment = dict(os.environ)
            environment.pop("METTA_UPSTREAM", None)
            if value is not None:
                environment["METTA_UPSTREAM"] = value
            result = subprocess.run(
                [sys.executable, "-c", code, str(HERE / script)],
                capture_output=True, text=True, env=environment, check=False,
            )
            expected = configured if value is not None else lane.REPO.parent / "PeTTa-upstream"
            if result.returncode or Path(result.stdout.strip()).resolve() != expected.resolve():
                failures.append(
                    f"{script} with METTA_UPSTREAM={value!r}: expected {expected}, "
                    f"exit {result.returncode}, stdout {result.stdout!r}, stderr {result.stderr!r}"
                )
    return failures


def upstream_prerequisite_failures() -> list[str]:
    """The lane must not be able to pass in CI without measuring.

    Until 2026-09-06 an absent upstream checkout returned 0 everywhere, and the
    workflow never provided one, so the lane ran on every push and measured
    nothing while the page said the measurement ran there. The pin itself
    belongs here too: a present checkout still has to be the one the recorded
    upstream numbers came from before anything rebaselines against it.
    """
    failures: list[str] = []
    original_upstream, original_ci = lane.UPSTREAM, os.environ.get("CI")
    try:
        lane.UPSTREAM = lane.REPO / "ai-tmp" / "no-upstream-checkout-here"
        os.environ["CI"] = "true"
        if lane.upstream_prerequisite() != 1:
            failures.append(
                "an absent upstream checkout did not refuse under CI=true, so "
                "the lane can pass in CI without measuring"
            )
        os.environ.pop("CI")
        if lane.upstream_prerequisite() != 0:
            failures.append(
                "an absent upstream checkout refused off CI, where a developer "
                "who has not cloned it should get a printed skip"
            )
        #and the skip has to name the pin, or the reader cannot act on it.
        buffer = io.StringIO()
        with contextlib.redirect_stdout(buffer):
            lane.upstream_prerequisite()
        if lane.UPSTREAM_COMMIT[:7] not in buffer.getvalue():
            failures.append("the local skip does not name the pinned commit")
    finally:
        lane.UPSTREAM = original_upstream
        if original_ci is None:
            os.environ.pop("CI", None)
        else:
            os.environ["CI"] = original_ci

    if len(lane.UPSTREAM_COMMIT) != 40 or not all(
        character in "0123456789abcdef" for character in lane.UPSTREAM_COMMIT
    ):
        failures.append(
            f"UPSTREAM_COMMIT {lane.UPSTREAM_COMMIT!r} is not a full object ID"
        )
    if lane.upstream_present() and lane.upstream_head() != lane.UPSTREAM_COMMIT:
        failures.append(
            f"the checkout at {lane.UPSTREAM} is at {lane.upstream_head()}, "
            f"not the pinned {lane.UPSTREAM_COMMIT}"
        )
    return failures


def denied_counter_failures() -> list[str]:
    """A kernel or container that will not let this count has to say so.

    The plant is what a container under Docker's default seccomp profile
    actually prints, which is not a parse failure and must not be reported as
    one.
    """
    failures: list[str] = []
    denied = subprocess.CompletedProcess(
        args=[], returncode=0, stdout="",
        stderr="Error:\nNo permission to enable instructions:u event.\n",
    )
    original_spawn = lane._spawn
    lane._spawn = lambda _argv: denied
    try:
        lane._perf(["true"])
    except RuntimeError as refusal:
        failures.extend(
            f"the perf refusal does not name {expected}: {refusal}"
            for expected in ("perf_event_paranoid", "seccomp=unconfined")
            if expected not in str(refusal)
        )
    else:
        failures.append("perf answering no count at all did not refuse")
    finally:
        lane._spawn = original_spawn
    return failures


def null_program_refusal_failures() -> list[str]:
    """The one thing the control cannot do is name a path shorter than its root.

    And it has to say so with the edit that fixes it.
    """
    failures: list[str] = []
    try:
        lane.null_program(len(str(lane.NULL_ROOT)) - 1, 0)
    except RuntimeError as refusal:
        if "NULL_ROOT" not in str(refusal):
            failures.append("the null-control refusal does not name the edit")
    else:
        failures.append("null_program accepted a length its root cannot name")
    return failures


def unmeasured_row_failures(name: str) -> list[str]:
    """A row this BOX could not measure is not a row the TREE broke.

    A corpus example that runs out its ceiling at loadavg 33.81, and a row whose
    processes split between two costs, are both the box answering. Each is
    printed with its count either way, so a check that stopped happening is
    never silent, and each is fatal only where CI=true. A row whose inference
    counts disagree is not in that class and still fails on a desk, which is
    the plant that keeps this from becoming a blanket amnesty.
    """
    failures: list[str] = []
    frozen = {
        "//": {"status": "meta"},
        name: {
            "status": "measured",
            "upstream_instructions": 6_086_421,
            "our_instructions": 5_000_000,
            "our_inferences": PLANTED_INFERENCES,
        },
    }
    original_measure = lane.measure
    original_ci = os.environ.get("CI")

    def judged(status: str) -> tuple[int, str]:
        lane.measure = lambda _root, _example: {"status": status}
        printed = io.StringIO()
        try:
            with contextlib.redirect_stdout(printed):
                answer = lane.verdicts(frozen, remeasure=True)
        finally:
            lane.measure = original_measure
        return answer, printed.getvalue()

    try:
        os.environ.pop("CI", None)
        for status in ("timeout", "unstable"):
            answer, printed = judged(status)
            if answer != 0:
                failures.append(
                    f"a `{status}` row failed the lane on a desk, where it is the "
                    "box answering rather than the tree"
                )
            if "NOT MEASURED ON THIS BOX" not in printed:
                failures.append(f"a `{status}` row was not named as unmeasured")
            if "loadavg" not in printed:
                failures.append(f"a `{status}` row was reported with no load beside it")
        os.environ["CI"] = "true"
        for status in ("timeout", "unstable"):
            answer, _printed = judged(status)
            if answer == 0:
                failures.append(
                    f"a `{status}` row passed in CI, where a row nobody measured "
                    "is a tripwire nobody read"
                )
        os.environ.pop("CI", None)
        answer, _printed = judged("nondeterministic")
        if answer == 0:
            failures.append(
                "a row whose inference counts disagree passed on a desk; that is "
                "the tree's answer, not the box's"
            )
    finally:
        lane.measure = original_measure
        if original_ci is None:
            os.environ.pop("CI", None)
        else:
            os.environ["CI"] = original_ci
    return failures


def straddled_allowance_failures(name: str) -> list[str]:
    """A row whose own runs land on both sides of the allowance has no verdict.

    The cross-engine allowance is a LINE, and a row whose spread crosses it
    would be called a regression or not by whichever half of that spread this
    run's median happened to fall in, with the next run saying the other thing.
    That is the box picking, not the tree answering, so it goes to the bucket
    that names it. A row whose BEST run is still over the line is a different
    thing and still fails, which is the plant that keeps this from becoming a
    blanket amnesty for anything near the boundary.
    """
    failures: list[str] = []
    frozen = {
        "//": {"status": "meta"},
        name: {
            "status": "measured",
            "upstream_instructions": 1_000_000,
            "our_instructions": 1_000_000,
            "our_inferences": PLANTED_INFERENCES,
        },
    }
    #1,000,000 * 1.02 + 150,000 = 1,170,000.
    allowed = 1_170_000
    original_measure = lane.measure
    original_ci = os.environ.get("CI")

    def judged(lowest: int, median: int) -> tuple[int, str]:
        lane.measure = lambda _root, _example: {
            "status": "ok",
            "instructions": median,
            "lowest": lowest,
            "highest": median + (median - lowest),
            "program_range": [FIXED + lowest, FIXED + median + (median - lowest)],
            "null_range": [FIXED, FIXED],
            "runs": 5,
            "inferences": PLANTED_INFERENCES,
        }
        printed = io.StringIO()
        try:
            with contextlib.redirect_stdout(printed):
                answer = lane.verdicts(frozen, remeasure=True)
        finally:
            lane.measure = original_measure
        return answer, printed.getvalue()

    try:
        os.environ.pop("CI", None)
        answer, printed = judged(allowed - 1, allowed + 1)
        if answer != 0:
            failures.append(
                "a row whose runs straddle the allowance failed the lane on a "
                "desk, where the verdict is the spread rather than the tree"
            )
        if "straddle the allowance" not in printed:
            failures.append("a straddled row was not named as unmeasured")
        answer, printed = judged(allowed + 1, allowed + 2)
        if answer == 0:
            failures.append(
                "a row whose BEST run is over the allowance passed; that is the "
                "tree answering and it has to fail"
            )
        if "straddle the allowance" in printed:
            failures.append(
                "a row entirely over the allowance was called a straddle"
            )
    finally:
        lane.measure = original_measure
        if original_ci is None:
            os.environ.pop("CI", None)
        else:
            os.environ["CI"] = original_ci
    return failures


def counter_refusal_policy_failures() -> list[str]:
    """One line for a box that cannot count: a desk skips it, a runner refuses it."""
    failures: list[str] = []
    original_ci = os.environ.get("CI")
    try:
        os.environ.pop("CI", None)
        printed = io.StringIO()
        with contextlib.redirect_stdout(printed):
            answer = lane.refused("perf did not report an instruction count")
        if answer != 0 or "note:" not in printed.getvalue():
            failures.append(
                f"a desk did not skip a box that cannot count: {answer}, "
                f"{printed.getvalue()!r}"
            )
        if "loadavg" not in printed.getvalue():
            failures.append("the skip carries no load reading")
        os.environ["CI"] = "true"
        errors = io.StringIO()
        with contextlib.redirect_stderr(errors):
            answer = lane.refused("perf did not report an instruction count")
        if answer != 1 or "error:" not in errors.getvalue():
            failures.append(
                f"CI did not refuse a box that cannot count: {answer}, "
                f"{errors.getvalue()!r}"
            )
    finally:
        if original_ci is None:
            os.environ.pop("CI", None)
        else:
            os.environ["CI"] = original_ci
    return failures


def null_range_failures(example: Path, name: str) -> list[str]:
    """Plant both sides of interval subtraction and a control beyond resolution."""
    failures: list[str] = []
    allowed = 1_170_000
    frozen = {name: {"status": "measured", "upstream_instructions": 1_000_000,
                     "our_instructions": 1_000_000,
                     "our_inferences": PLANTED_INFERENCES}}
    original_ci = os.environ.get("CI")
    try:
        for delta, below, above, ci, inference_delta, expected in (
            (1, 13_405, 12_852, False, 0, "straddle"),
            (1, 13_405, 12_852, True, 0, "straddle"),
            (12_853, 13_405, 12_852, False, 0, "overrun"),
            (-13_406, 13_405, 12_852, False, 0, "within"),
            (1, 13_406, 12_852, False, 0, "unmeasurable-null"),
            (1, 13_405, 12_853, False, 0, "unmeasurable-null"),
            (1, 13_406, 12_852, True, 0, "unmeasurable-null"),
            (1, 13_406, 12_852, False, 1_000, "unmeasurable-null"),
        ):
            if ci:
                os.environ["CI"] = "true"
            else:
                os.environ.pop("CI", None)
            null_calls = 0
            program = FIXED + allowed + delta

            def cost(_root, path, program_cost=(program, PLANTED_INFERENCES + inference_delta),
                     null_offsets=(-below, 0, above)):
                nonlocal null_calls
                if not is_null(path):
                    return program_cost
                index = null_calls - lane.WARMUP_RUNS
                null_calls += 1
                return FIXED + (null_offsets[index % 3] if index >= 0 else 0)

            with planted(cost):
                measured = lane.measure(lane.REPO, example)
                printed = io.StringIO()
                with contextlib.redirect_stdout(printed):
                    answer = lane.verdicts(frozen, remeasure=True)
                summary = lane._null_summary(lane.REPO)
            label = f"null range {below}/{above}, delta {delta}, CI={ci}"
            expected_status = expected if expected == "unmeasurable-null" else "ok"
            if measured["status"] != expected_status:
                failures.append(f"{label}: expected {expected_status}, got {measured}")
            if measured.get("lowest") != allowed + delta - above or measured.get("highest") != allowed + delta + below:
                failures.append(f"{label}: difference does not subtract both null extrema: {measured}")
            if null_calls != 2 * (lane.WARMUP_RUNS + lane.RUNS) or summary.get("median") != FIXED:
                failures.append(f"{label}: fresh null sampling lost its sample or median")
            text = printed.getvalue()
            should_fail = expected == "overrun" or inference_delta or (ci and expected != "within")
            if bool(answer) != bool(should_fail):
                failures.append(f"{label}: verdict {answer}, expected failure={bool(should_fail)}")
            if expected == "straddle":
                failures.extend(
                    f"{label}: verdict does not print {fragment!r}"
                    for fragment in ("straddle the allowance", f"program {program}..{program}",
                                     f"null {FIXED - below}..{FIXED + above}")
                    if fragment not in text
                )
            if expected == "overrun":
                failures.extend(
                    f"{label}: overrun does not print {fragment!r}"
                    for fragment in (f"difference {measured['lowest']}..{measured['highest']}",
                                     f"program {program}..{program}",
                                     f"null {FIXED - below}..{FIXED + above}")
                    if fragment not in text
                )
            if expected == "unmeasurable-null":
                failures.extend(
                    f"{label}: refusal does not print {fragment!r}"
                    for fragment in ("NOT MEASURED ON THIS BOX", "unmeasurable-null",
                                     "resolution -13405/+12852", f"{FIXED - below}..{FIXED + above}")
                    if fragment not in text
                )
            if inference_delta and "TREE DRIFT" not in text:
                failures.append(f"{label}: the unusable null hid the program's inference drift")
    finally:
        if original_ci is None:
            os.environ.pop("CI", None)
        else:
            os.environ["CI"] = original_ci
    return failures


def fresh_null_failures(example: Path, name: str) -> list[str]:
    """A lazy artifact can change boot cost between rows of the same shape."""
    failures: list[str] = []
    allowed = WORK * lane.INSTRUCTION_RATIO + lane.INSTRUCTION_ABSOLUTE
    frozen = {name: {"status": "measured", "upstream_instructions": WORK,
                     "our_instructions": WORK,
                     "our_inferences": PLANTED_INFERENCES}}
    for fixed_delta in (-500_000, 500_000):
        for added_work in (0, int(allowed - WORK) + 1):
            epoch = [0]
            null_calls = 0

            def cost(_root, path, delta=fixed_delta, work=added_work, phase=epoch):
                nonlocal null_calls
                if is_null(path):
                    null_calls += 1
                    return FIXED + phase[0] * delta
                return FIXED + phase[0] * delta + WORK + phase[0] * work

            with planted(cost):
                first = lane.measure(lane.REPO, example)
                epoch[0] = 1
                second = lane.measure(lane.REPO, example)
                printed = io.StringIO()
                with contextlib.redirect_stdout(printed):
                    answer = lane.verdicts(frozen, remeasure=True)
                summary = lane._null_summary(lane.REPO)
            label = f"fixed cost {fixed_delta:+d}, program work {added_work:+d}"
            if first["instructions"] != WORK or second["instructions"] != WORK + added_work:
                failures.append(f"{label}: a previous null contaminated the next program: {second}")
            if null_calls != 3 * (lane.WARMUP_RUNS + lane.RUNS):
                failures.append(f"{label}: each program did not receive a fresh null sample")
            if summary.get("median") != FIXED + fixed_delta:
                failures.append(f"{label}: the summary did not retain the latest measured null")
            if bool(answer) != bool(added_work):
                failures.append(f"{label}: verdict {answer} changed the program's allowance")
            if added_work and "CROSS-ENGINE REGRESSION" not in printed.getvalue():
                failures.append(f"{label}: the planted program increase was not reported")
    return failures


def waiver_reporting_failures() -> list[str]:
    """Keep active rulings visible beside each independent measurement verdict."""
    failures: list[str] = []
    names = tuple(lane.WAIVERS)
    for instructions, status in ((WORK, "measured"),
                                 (2_000_000, "measured"),
                                 (WORK, "unmeasurable-null")):
        baseline = {name: {"status": status, "our_instructions": instructions,
                           "upstream_instructions": 1_000_000,
                           "our_inferences": PLANTED_INFERENCES}
                    for name in names}
        printed = io.StringIO()
        with contextlib.redirect_stdout(printed):
            answer = lane.verdicts(baseline, remeasure=False)
        text = printed.getvalue()
        expected = int(status == "unmeasurable-null" and os.environ.get("CI") == "true")
        if answer != expected:
            failures.append(f"active waivers changed {status}'s verdict: {answer}, expected {expected}")
        failures.extend(
            f"active waiver disappeared at {instructions}/{status}: {name}"
            for name in names
            if text.count(f"WAIVED (root-caused, see WAIVERS) {name}:") != 1
        )
        if status == "unmeasurable-null" and "NOT MEASURED ON THIS BOX" not in text:
            failures.append("an active waiver hid the independent null-control refusal")
    return failures


def qlf_content_digest(data: bytes) -> str:
    """Hash every QLF byte except its compiler PID and the resulting offsets.

    qlfOpen stores the atomic writer's temporary pathname; qlfClose appends
    source offsets. The three signed varints and the four-byte offset table
    are defined in SWI's src/pl-qlf.c at fc7ef84b949378b729052c3ade79c90ce5416abb,
    qlfPutInt64, qlfOpen and writeSourceMarks. No export or instruction bytes
    are omitted, and differing PID digit counts change no digest.
    """
    try:
        header = read_header(data)
    except NotQlfError as error:
        message = f"fixture is not a QLF artifact ({error})"
        raise ValueError(message) from error
    start, end = header.path_start, header.path_end
    filename, replacements = re.subn(rb"(\.[^/]+\.qlf)\.[0-9]+$", rb"\1.PID",
                                    header.saved_path)
    if replacements != 1:
        message = "QLF header has no atomic compiler pathname"
        raise ValueError(message)
    count = int.from_bytes(data[-4:], "big")
    table = len(data) - 4 * (count + 1)
    if not end <= table < len(data):
        message = "QLF source index overlaps its header"
        raise ValueError(message)
    offsets = b"".join((int.from_bytes(data[i:i + 4], "big") - end).to_bytes(4, "big")
                       for i in range(table, len(data) - 4, 4))
    content = data[:start] + filename + b"\0" + data[end:table] + offsets + data[-4:]
    return hashlib.sha256(content).hexdigest()


def artifact_fixture_failures() -> list[str]:
    """Regenerate twice after a foreign artifact, then restore the borrowed set."""
    def artifacts():
        return {path for directory in (lane.REPO / "engine", lane.REPO / "lib")
                for path in directory.rglob("*.qlf")}

    stamp = lane.REPO / "engine" / ".qlf-stamp"
    originals = artifacts() | ({stamp} if stamp.exists() else set())
    saved = {path: (path.stat(), path.read_bytes()) for path in originals}
    foreign = lane.REPO / "engine" / "ai-parity-foreign.qlf"
    if foreign.exists():
        return [f"artifact fixture refuses to overwrite {foreign}"]
    failures, generations = [], []
    calls = []

    def compare(_baseline, *, remeasure):
        calls.append(("compare", remeasure))
        return 0

    with (patch.object(lane, "prepare_artifacts", lambda: calls.append("prepare")),
          patch.object(lane, "verdicts", compare),
          patch.object(lane, "upstream_head", lambda: lane.UPSTREAM_COMMIT)):
        for frozen in (False, True):
            calls.clear()
            lane._judge(argparse.Namespace(rebaseline=False, frozen=frozen))
            expected = [("compare", False)] if frozen else ["prepare", ("compare", True)]
            if calls != expected:
                failures.append(f"parity fixture setup order at frozen={frozen}: {calls}")
    try:
        for generation in range(2):
            foreign.write_bytes(b"foreign producer; this artifact must be purged")
            paths = lane.prepare_artifacts()
            if foreign.exists():
                failures.append("shipping fixture retained a planted foreign artifact")
            inventory, raw_digests = {}, {}
            for path in paths:
                data = path.read_bytes()
                relative = str(path.relative_to(lane.REPO))
                inventory[relative] = qlf_content_digest(data)
                raw_digests[relative] = hashlib.sha256(data).hexdigest()
                # An executable-byte change must remain visible to this digest.
                if b"metta_engine" in data and qlf_content_digest(
                        data.replace(b"metta_engine", b"netta_engine", 1)) == inventory[relative]:
                    failures.append("QLF digest hid a planted module-name change")
            generations.append(inventory)
            print(f"parity fixture generation {generation + 1}: "
                  f"{json.dumps({'content': inventory, 'raw': raw_digests}, sort_keys=True)}")
        if generations[0] != generations[1]:
            failures.append("repeated shipping generations changed artifact set or content digests")
    finally:
        for path in artifacts() - originals:
            path.unlink()
        if stamp not in originals:
            stamp.unlink(missing_ok=True)
        for path, (metadata, data) in saved.items():
            path.write_bytes(data)
            path.chmod(metadata.st_mode & 0o7777)
            os.utime(path, ns=(metadata.st_atime_ns, metadata.st_mtime_ns))
        lane._FIXED_COST.clear()
    return failures


def main() -> int:
    """Plant every way this measurement can break, and report the ones the lane missed."""
    corpus = lane.corpus()
    if len(corpus) < 2:
        print("the examples corpus is too small to plant against", file=sys.stderr)
        return 1
    example = corpus[0]
    name = str(example.relative_to(lane.REPO))

    failures = [
        *honest_plant_failures(example),
        *shape_matching_failures(corpus, example),
        *excursion_failures(example),
        *warmup_failures(example),
        *modeless_failures(example),
        *overstated_control_failures(example, name),
        *frozen_negative_net_failures(name),
        *carried_meta_failures(),
        *timeout_failures(),
        *null_program_failures(example),
        *upstream_selection_failures(),
        *upstream_prerequisite_failures(),
        *denied_counter_failures(),
        *null_program_refusal_failures(),
        *unmeasured_row_failures(name),
        *straddled_allowance_failures(name),
        *null_range_failures(example, name),
        *fresh_null_failures(example, name),
        *counter_refusal_policy_failures(),
        *waiver_reporting_failures(),
        *artifact_fixture_failures(),
    ]

    for failure in failures:
        print(failure, file=sys.stderr)
    if failures:
        return 1
    print("upstream parity selftest: the null control is the subtrahend and a "
          "net below it fails the lane")
    return 0


if __name__ == "__main__":
    sys.exit(main())
