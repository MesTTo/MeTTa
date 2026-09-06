"""Purpose: prove the parity lane subtracts the null control and reports a net below it.

Every plant passes through ``check_upstream_parity`` itself, with only
``_perf`` replaced, so the selftest and the production lane cannot drift into
testing different questions. No engine is started: ``_perf`` is the single
place this lane touches a process, and a table standing in for it exercises
the whole sampling, marker-parsing, memoising, netting and verdict path.

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

Assumes: an ``examples/`` corpus with at least two files, used only for their
  names and path shapes.
Guarantees:
  - a planted engine whose fixed cost exceeds its program run is reported as
    ``negative-net`` by ``measure`` and turns ``verdicts`` red, while the rule
    this file replaced records the same numbers and stays green
    [tested: this file is its own gate; commit=WORKTREE]
  - the recorded net is the program run minus the null run at that row's own
    path length AND directory count, and a control taken at another shape
    gives a different answer, so shape-matching is load-bearing rather than
    decorative [tested: this file is its own gate; commit=WORKTREE]
  - ``--rebaseline`` carries a meta note forward instead of dropping it
    [tested: this file is its own gate; commit=WORKTREE]
  - ``null_program`` builds a control with its example's character count AND
    its directory count, and refuses a shape its root cannot name, naming the
    edit [tested: this file is its own gate; commit=WORKTREE]
  - a measurement that outlives ``TIMEOUT`` leaves nothing running, checked on
    the real shape: the timed process is the wrapper and the survivor would be
    its grandchild [tested: this file is its own gate; commit=WORKTREE]
  - one cheap run in three is ignored rather than taken and the sample is
    extended; three cheap in seven still answer the cost the other four agree
    on; a cold first touch is discarded rather than counted; and a program
    with no mode at all is reported as having no cost
    [tested: this file is its own gate; commit=WORKTREE]
Fails when: the production lane stops exposing ``_perf`` as its only process
  call, or stops computing a row's net inside ``measure``.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import contextlib
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import check_upstream_parity as lane  # noqa: E402

#: The two costs a plant assigns, keyed by what the driver was handed.
#: A null control is any program under NULL_ROOT; everything else is an example.
PLANTED_INFERENCES = 4321


@contextlib.contextmanager
def planted(cost):
    """Run the production lane with `cost(engine_root, program)` standing in for perf."""
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
    return raw - boot


def main() -> int:
    failures: list[str] = []
    corpus = lane.corpus()
    if len(corpus) < 2:
        print("the examples corpus is too small to plant against", file=sys.stderr)
        return 1
    example, other = corpus[0], next(
        (p for p in corpus if len(str(p)) != len(str(corpus[0]))), corpus[1]
    )
    name = str(example.relative_to(lane.REPO))

    #A control that behaves: the program run costs its null control plus its
    #own work, and the work is what the row records.
    fixed, work = 1_000_000_000, 250_000

    def honest(engine_root, program):
        return fixed if is_null(program) else fixed + work

    with planted(honest):
        measured = lane.measure(lane.REPO, example)
    if measured["status"] != "ok":
        failures.append(f"an honest plant did not measure: {measured}")
    elif measured["instructions"] != work:
        failures.append(
            f"the net is {measured['instructions']} where the program's own work "
            f"is {work}; it is not being taken against the null control"
        )

    #The net must come from the control at THIS row's SHAPE. Plant a fixed cost
    #that rises with both the path length and the directory count, the way the
    #real one does, and check each row is charged its own shape.
    per_character = 5_638  # ours, measured 2026-09-06 across a 78-character span
    per_directory = 13_782  # ours, measured 2026-09-06 across six components

    def by_shape(engine_root, program):
        base = (fixed + per_character * len(program)
                + per_directory * program.count("/"))
        return base if is_null(program) else base + work

    deeper = next(
        (p for p in corpus if len(p.parts) != len(example.parts)), other
    )
    with planted(by_shape):
        here = lane.measure(lane.REPO, example)
        there = lane.measure(lane.REPO, other)
        below = lane.measure(lane.REPO, deeper)
    if any(row.get("instructions") != work for row in (here, there, below)):
        failures.append(
            "a shape-dependent fixed cost leaked into the net: "
            f"{here.get('instructions')}, {there.get('instructions')} and "
            f"{below.get('instructions')} against a planted {work} each"
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

    #One run in three lands 35,083,561 low, because SWI's collector thread
    #sometimes finishes inside the process and sometimes does not. The minimum
    #takes that run every time it appears; the median has to ignore it.
    excursion = 35_083_561
    seen = {"n": 0}

    def sometimes_cheap(engine_root, program):
        if is_null(program):
            return fixed
        seen["n"] += 1
        return fixed + work - (excursion if seen["n"] % 3 == 1 else 0)

    with planted(sometimes_cheap):
        steady = lane.measure(lane.REPO, example)
    if steady.get("instructions") != work:
        failures.append(
            f"one cheap run in three moved the recorded cost to "
            f"{steady.get('instructions')} against the {work} the other two agree on"
        )
    if steady.get("runs") != lane.RUNS + lane.EXTRA_RUNS:  # counted, not spawned
        failures.append(
            f"runs that disagreed by {excursion} were not extended: "
            f"{steady.get('runs')} runs taken"
        )

    #Three excursions in seven still leave the median where the other four
    #agree, and that is the answer, so it must NOT be reported as a defect: a
    #lane that failed there would fail on a busy box for nothing.
    seen["n"] = 0

    def cheap_three_in_seven(engine_root, program):
        if is_null(program):
            return fixed
        seen["n"] += 1
        return fixed + work - (excursion if seen["n"] in (1, 4, 6) else 0)

    with planted(cheap_three_in_seven):
        minority = lane.measure(lane.REPO, example)
    if minority.get("status") != "ok" or minority.get("instructions") != work:
        failures.append(
            f"three cheap runs in seven left the row {minority.get('status')} at "
            f"{minority.get('instructions')} rather than ok at {work}"
        )

    #The first touch of three corpus rows writes a cache their later runs read,
    #so its cost AND its inference count differ. One discarded run is what
    #stops that reading as a nondeterministic row on a fresh checkout.
    seen["n"] = 0

    def cold_first_touch(engine_root, program):
        if is_null(program):
            return fixed
        seen["n"] += 1
        if seen["n"] == 1:
            return fixed + work + 9_000_000, PLANTED_INFERENCES + 4_000
        return fixed + work, PLANTED_INFERENCES

    with planted(cold_first_touch):
        warmed = lane.measure(lane.REPO, example)
    if warmed["status"] != "ok" or warmed.get("instructions") != work:
        failures.append(
            f"a cold first touch left the row {warmed['status']} at "
            f"{warmed.get('instructions')}; the warm-up run is not being discarded"
        )
    elif warmed.get("inferences") != PLANTED_INFERENCES:
        failures.append(
            f"the row recorded the cold run's {warmed['inferences']} inferences"
        )

    #A program with no mode at all has no cost, and saying so beats picking a
    #number: every run lands somewhere different, so nothing supports a median.
    seen["n"] = 0

    def no_mode(engine_root, program):
        if is_null(program):
            return fixed
        seen["n"] += 1
        return fixed + work + seen["n"] * excursion

    with planted(no_mode):
        spread = lane.measure(lane.REPO, example)
    if spread["status"] != "unstable":
        failures.append(
            f"a program whose every run costs something different was reported "
            f"as {spread['status']}, not unstable"
        )

    #The defect itself: a fixed cost measured ABOVE what a run of the program
    #costs. This is what the boot fixture did, by 8,661,096 instructions.
    overstatement = 8_661_096

    def overstated(engine_root, program):
        return fixed + overstatement if is_null(program) else fixed + work

    with planted(overstated):
        broken = lane.measure(lane.REPO, example)
    if broken["status"] != "negative-net":
        failures.append(
            f"a control measured {overstatement} above the program run was reported "
            f"as {broken['status']}, not negative-net"
        )
    elif broken["instructions"] >= 0:
        failures.append("a negative-net row did not record its negative net")

    #and it must turn the lane red rather than passing quietly.
    baseline = {
        "//": {"status": "meta"},
        name: {
            "status": "measured",
            "upstream_instructions": 10_000_000,
            "upstream_null": fixed,
            "our_instructions": work,
            "our_null": fixed,
            "our_inferences": PLANTED_INFERENCES,
        },
    }
    with planted(overstated):
        verdict = lane.verdicts(baseline, remeasure=True)
    if verdict == 0:
        failures.append("a negative net passed the lane instead of failing it")

    #The discrimination, which is what makes the plant above a regression
    #rather than an assertion: the rule this file replaced records exactly the
    #same numbers and stays green, because a negative net is smaller than every
    #allowance there is.
    old_net = old_rule_net(fixed + work, fixed + overstatement)
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

    #A recorded negative net is a defect too, so a frozen baseline carrying one
    #cannot pass, under either the status this file writes for it or the
    #`measured` the old one wrote.
    frozen = {
        "//": {"status": "meta"},
        name: {
            "status": "negative-net",
            "our_instructions": -50_470_138,
            "our_null": fixed,
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

    #A re-pin note is a record. Rebuilding the meta block must not drop it.
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

    #A timed-out measurement must not leave the engine running. The topology is
    #the real one and it is the whole point: the process being timed is the
    #wrapper, bounded.sh's death signal reaches the wrapper's child, and the
    #engine is that child's OWN child. `sleep` here stands where swipl stands
    #under perf, one level below anything a kill or a pdeathsig reaches, so a
    #kill aimed at the timed process leaves it running exactly as it did on
    #2026-09-06.
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

    #The control has to match the example's directory count as well as its
    #length, or an empty file at seven components reads 139,684 instructions
    #against a control at one.
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

    #The one thing the control cannot do is name a path shorter than its root,
    #and it has to say so with the edit that fixes it.
    try:
        lane.null_program(len(str(lane.NULL_ROOT)) - 1, 0)
    except RuntimeError as refusal:
        if "NULL_ROOT" not in str(refusal):
            failures.append("the null-control refusal does not name the edit")
    else:
        failures.append("null_program accepted a length its root cannot name")

    for failure in failures:
        print(failure, file=sys.stderr)
    if failures:
        return 1
    print("upstream parity selftest: the null control is the subtrahend and a "
          "net below it fails the lane")
    return 0


if __name__ == "__main__":
    sys.exit(main())
