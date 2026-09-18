"""Purpose: drive engine/bench.pl and hand its counters to the shared
benchmark harness, so the engine's own pins use the one baseline format and
the one regression protocol every component here uses.

This is NOT engine code and no measured process loads it. Each measurement is
a fresh `swipl` running engine/bench.pl and nothing else; this file starts
those processes, reads the line each prints, and calls BenchmarkBaseline.
Assumes:
  - extensions/python is importable from ROOT, which is where
    metta_benchmarking is put on the path by the benchmarks package's own
    init. DEVELOPING.md's rule is that a sibling imports BenchmarkBaseline,
    benchmark_case, count_atoms and measure_instructions from
    metta_benchmarking rather than copying the harness, and that is the whole
    reason this file exists instead of a second comparison protocol
    [source: DEVELOPING.md:149-151].
  - engine/bench.pl prints one `metta-bench ...` line per run and answers
    `bench_describe` with its case table and its workload list, so no case
    name, unit, operation count or corpus path is written twice.
Guarantees:
  - both boot counters decline a different declared checkout length or depth,
    even when the reading matches its pin; runtime rows still compare
    [tested: test_boot_path_refuses_both_counters_and_preserves_pins,
    test_comparable_counters_still_gate; commit=8ca8a387fc61d0918484b19a1a3baf85b6523043]
  - a box that would not count is told apart from a tree that moved: this
    lane exits 0 with a named skip on a developer's box and 1 where CI=true,
    and never reports a refused measurement as a moved row
    [tested: test_a_benchmark_lane_skips_a_refusal_locally_and_refuses_it_in_ci;
    commit=11afdcdbad5bbbe37168b5d8528c23a21c42b4b6]
  - the deciding counter is inferences, taken from three fresh processes that
    perf is NOT watching, so a machine with no perf still gates
    [tested: engine/bench.sh; commit=c41b54d69e951882e5075393f851a33438247372].
  - a sample reads the same count from a bare run and from under check.sh,
    which allocates a scratch directory and exports TMP, TMPDIR and TEMP into
    every lane. SWI reads TMP for its temporary directory and the boot case is
    sensitive to the one atom that creates, so the samples run without them
    [tested: tests/shell/test_boot_inference_determinism.sh, its third arm;
    commit=11afdcdbad5bbbe37168b5d8528c23a21c42b4b6].
  - retired instructions are measured over the same region and not over the
    process, through perf's control descriptors, so a case's instruction pin
    excludes the engine boot that every case would otherwise carry
    [measured 2026-08-28: the parse case reads 109,337,650 instructions in
    its controlled window against 1,119,242,969 for the whole process, so
    without the window nine tenths of its pin would be the boot].
  - the configuration stamp carries the four artifact keys
    benchmarks/configuration.py decides comparability by, PLUS a digest of
    every corpus file the cases read, so editing a workload REFUSES the
    comparison instead of reporting a move the engine did not make
    [tested: engine/bench.sh; commit=c41b54d69e951882e5075393f851a33438247372].
  - every selected case is measured and every failure is reported before the
    nonzero exit, so one regression cannot hide another
    [source: extensions/python/benchmarks/check_instructions.py, whose
    stop-at-first-failure form masked four stale pins for days].
  - the .qlf artifact set is warmed before any sample, because the boot that
    GENERATES it is a different workload from the boot that loads it and a
    cold first run has inverted a measured win before
    [measured 2026-08-28: 3,129,543 inferences on a generating boot against
    612,598 warm, same tree, same command].
Owns resources:
  - each swipl process is run to completion with an explicit timeout and its
    output captured; a timeout is reported as a failed case rather than
    raised past the loop
    [source: engine/bench.py's _run, whose subprocess.run passes
    capture_output=True and timeout=TIMEOUT and whose except clause turns
    subprocess.TimeoutExpired into a returned failure].
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""  # noqa: D205  -- the API contract is one continuous invariant, not summary-and-body prose

from __future__ import annotations

import argparse
import hashlib
import os
import shutil
import subprocess
import sys
from collections.abc import Mapping, Sequence
from pathlib import Path
from typing import Any, NamedTuple

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(ROOT / "extensions" / "python"))

# E402 on both: the sys.path line above is what makes either importable, so
# these cannot precede it. The benchmarks package's init puts the workspace's
# extension distributions on the path, which is what makes the second import
# resolve; isort groups the two together, neither being first-party.
from benchmarks.configuration import counter_configuration  # noqa: E402
from metta_benchmarking import (  # noqa: E402
    BenchmarkBaseline,
    measure_instructions,
    measured_main,
    prepare_governed_artifacts,
    refusal_is_fatal,
)

BASELINE = HERE / "bench-baseline.json"
BENCH = HERE / "bench.pl"
#: The shared harness decides on the minimum of three samples; taking fewer
#: here would hand it a shorter list than it accepts.
SAMPLES = 3
#: Every case is well under a second warm. The limit exists so a hung engine
#: fails the case instead of the run.
TIMEOUT = 120.0
#: The caller's temporary directory, removed from every sample's environment.
#:
#: SWI reads TMP for its own, and the boot case's inference count is sensitive
#: to the atom table's exact state: TMP set to anything but `/tmp` creates one
#: atom, the tmp_dir flag's value, before the process starts, and the row reads
#: 268,390 instead of 268,417. Twenty-seven is seven times the harness's
#: four-inference allowance, and `check.sh` allocates a scratch directory and
#: exports all three names into every lane, so without this the SAME TREE is
#: green from `sh engine/bench.sh` and red under `sh check.sh engine-bench`,
#: whichever way the row is pinned.
#:
#: The sensitivity is the engine's, not this file's, and it is the same
#: non-monotonic shape engine/bench.pl's header records for the process's
#: predicate set. Measured with a positive control rather than inferred: with
#: engine/qlf_boot.pl loaded, creating ONE atom before the load reads 267,933
#: against 267,961 for none, while two, three, five and eight read 267,961
#: again [measured 2026-09-07; command=`swipl -q -g "forall(between(1,N,I),
#: (atom_concat(hyprobe_,I,A), atom_length(A,_))), user:ensure_loaded(
#: 'engine/qlf_boot'), statistics(inferences,I0), user:ensure_loaded(
#: 'engine/metta'), statistics(inferences,I1), X is I1-I0, writeln(X)" -t halt`;
#: commit=11afdcdbad5bbbe37168b5d8528c23a21c42b4b6]. No other variable this gate sets or a shell carries moves
#: the row: LANG, LC_ALL, PYTHONHASHSEED, CI, HOME, SHELL, METTA_TIMEOUT and an
#: invented name all read 268,417.
#:
#: All three names go, not only the one that bites, so a future SWI that
#: prefers TMPDIR does not reintroduce this silently. Nothing is lost by
#: dropping them: a whole `--counter-only` run with them pointed at an empty
#: directory leaves it empty, because no case writes a temporary file.
#:
#: Known limitation: this makes the INFERENCE samples caller-independent in
#: the one way that was measured to matter, not in every way. The instruction
#: samples are already independent by construction and more strictly -- they
#: go through metta_benchmarking's measure_counters, which BUILDS a four-name
#: environment with LC_ALL=C and PYTHONHASHSEED=0. Handing that same built
#: environment to the inference samples would close the class rather than the
#: case, and it is not done here because it moves boot to 263,515, evaluate to
#: 560,367 and translate to 308,653, numbers no sweep point has measured, so
#: every attribution those rows carry would become an inference. The two
#: counters therefore describe two configurations that differ by the locale.
TEMPORARY_DIRECTORY_VARIABLES = ("TMP", "TMPDIR", "TEMP")


def _environment() -> dict[str, str]:
    """The caller's environment without its temporary directory."""
    return {
        name: value
        for name, value in os.environ.items()
        if name not in TEMPORARY_DIRECTORY_VARIABLES
    }


def _command(goal: str) -> list[str]:
    """The one swipl invocation shape: no host, one goal, then halt.

    --stack_limit matches run.sh, so the engine is measured in the stack
    configuration it ships with rather than SWI's default.
    """
    return [
        "swipl",
        "-q",
        "--stack_limit=8g",
        "-g",
        goal,
        "-t",
        "halt",
        str(BENCH),
    ]


def _goal(name: str) -> str:
    """bench_run for one case, module-qualified and quoted.

    A bare parse-prolog reads as a term rather than an atom.
    """
    return f"metta_bench:bench_run('{name}')"


class CaseFailureError(Exception):
    """One case could not be measured; the run continues and reports it."""


def _run(goal: str) -> str:
    """Run one swipl process and return its standard output."""
    try:
        # The argument vector is built here from a fixed executable name and
        # a case name out of bench.pl's own table, never from input.
        finished = subprocess.run(
            _command(goal),
            capture_output=True,
            text=True,
            timeout=TIMEOUT,
            check=False,
            env=_environment(),
        )
    except subprocess.TimeoutExpired as expired:
        msg = f"{goal} exceeded its {TIMEOUT:g} second limit"
        raise CaseFailureError(msg) from expired
    if finished.returncode != 0:
        detail = (finished.stderr or finished.stdout).strip()
        msg = f"{goal} exited with status {finished.returncode}: {detail}"
        raise CaseFailureError(msg)
    return finished.stdout


class Case(NamedTuple):
    """One case as bench.pl declares it.

    `whole_process` is bench.pl's `bench_whole_process/1`: the measured region
    contains the engine load, so the row's instruction count scales with the
    length of this checkout's path and is true of one location only.
    """

    unit: str
    operations: int
    whole_process: bool


def _fields(line: str, prefix: str) -> dict[str, str] | None:
    """key=value fields from one of bench.pl's tagged lines."""
    head, _, rest = line.partition(" ")
    if head != prefix:
        return None
    return dict(field.split("=", 1) for field in rest.split() if "=" in field)


def describe() -> tuple[dict[str, Case], tuple[str, ...]]:
    """The case table and the workload list, read from bench.pl itself."""
    output = _run("metta_bench:bench_describe")
    cases: dict[str, Case] = {}
    sources: list[str] = []
    for line in output.splitlines():
        case = _fields(line, "metta-bench-case")
        if case is not None:
            if "whole_process" not in case:
                msg = (
                    f"{case['name']}: bench_describe reported no whole_process "
                    "field; bench.pl owns that declaration and this reader "
                    "will not guess it"
                )
                raise CaseFailureError(msg)
            cases[case["name"]] = Case(
                case["unit"],
                int(case["operations"]),
                case["whole_process"] == "true",
            )
            continue
        source = _fields(line, "metta-bench-source")
        if source is not None:
            sources.append(source["path"])
    if not cases or not sources:
        msg = f"bench_describe answered no cases or no sources:\n{output}"
        raise CaseFailureError(msg)
    return cases, tuple(sources)


def stamp(sources: Sequence[str]) -> dict[str, Any]:
    """The configuration a pin is only comparable within.

    The four artifact keys are benchmarks/configuration.py's, unchanged: the
    C reader alone moved one Python case from 8,704,891 inferences to 722,264
    with no code change, and it moves this suite's parse case by four orders
    of magnitude the same way. The workload digests are the same idea applied
    to the other input a pin depends on. These cases read the tree's own
    corpus, so an edit to one changes the measured work; digesting them makes
    that a refusal naming the file rather than a regression naming the engine.
    """
    return counter_configuration() | {
        "workloads": {
            relative: hashlib.sha256((ROOT / relative).read_bytes()).hexdigest()[:16]
            for relative in sources
        }
    }


def counter_samples(name: str) -> tuple[list[int], float, float]:
    """Inferences from three fresh processes, plus advisory cpu and wall.

    A fresh process per sample is the strongest form of the harness's own
    fresh-setup rule: nothing an earlier case did to the engine's global state
    can reach this one. It is also what makes the numbers reproducible by
    hand, since each sample is one command anybody can run.
    """
    inferences: list[int] = []
    cpu: list[float] = []
    wall: list[float] = []
    for _ in range(SAMPLES):
        output = _run(_goal(name))
        reading = None
        for line in output.splitlines():
            reading = _fields(line, "metta-bench") or reading
        if reading is None or reading.get("case") != name:
            msg = f"{name} printed no metta-bench line:\n{output}"
            raise CaseFailureError(msg)
        inferences.append(int(reading["inferences"]))
        cpu.append(float(reading["cputime"]))
        wall.append(float(reading["walltime"]))
    return inferences, min(cpu), min(wall)


def instruction_samples(name: str) -> tuple[int, ...]:
    """Retired instructions over the same region, through perf's control fds."""
    return measure_instructions(
        _command(_goal(name)),
        rounds=SAMPLES,
        controlled=True,
        timeout=TIMEOUT,
    )


def _movement(previous: Mapping[str, Any] | None, key: str, observed: int) -> str:
    """What an update changed for one pinned number."""
    before = None if previous is None else previous.get(key)
    if not isinstance(before, int) or isinstance(before, bool):
        return f"{key} {observed} (new)"
    delta = observed - before
    percent = 100.0 * delta / before if before else 0.0
    return f"{key} {before} -> {observed} ({delta:+d}, {percent:+.3f}%)"


class RowRefusedError(Exception):
    """One row this checkout cannot read, with the others still deciding.

    Not MeasurementRefusedError, which `measured_main` turns into a skip of the
    WHOLE lane: a boot row the path length disqualifies leaves six other rows
    that decide perfectly well here, and skipping them would hide a regression
    behind a location.
    """


def observe(
    baseline: BenchmarkBaseline,
    name: str,
    case: Case,
    *,
    instructions: bool,
    path_refusal: str | None,
) -> str:
    """Measure one case and either compare it or re-pin it.

    A different declared checkout shape refuses both boot counters. Every
    other row's window excludes the load and keeps its comparisons.
    """
    previous = dict(baseline.cases[name]) if name in baseline.cases else None
    samples, cpu, wall = counter_samples(name)
    moved = [_movement(previous, "inferences", min(samples))]
    reported = [f"inference samples={samples}"]
    refusal = path_refusal if case.whole_process else None
    if refusal is None:
        baseline.observe_counter(
            name, unit=case.unit, operations=case.operations, samples=samples
        )
    baseline.observe_wall(name, wall / case.operations)
    if instructions:
        retired = instruction_samples(name)
        moved.append(_movement(previous, "instructions", min(retired)))
        spread = 100.0 * (max(retired) - min(retired)) / min(retired)
        reported.append(f"instruction samples={list(retired)} spread={spread:.3f}%")
        if refusal is None:
            baseline.observe_instructions(name, retired)
    line = (
        f"{name}: {'; '.join(moved)}; {'; '.join(reported)}; "
        f"cpu={cpu:.6f}s wall={wall:.6f}s (advisory)"
    )
    if refusal is not None:
        message = f"{line} NOT MEASURED IN THIS CONFIGURATION\n  {refusal}"
        raise RowRefusedError(message)
    return line


# The loop keeps measurement, reporting and the keep-going contract together;
# splitting them would hide which failures were collected.
def main(argv: Sequence[str] | None = None) -> int:
    """Measure the selected cases against engine/bench-baseline.json."""
    try:
        cases, sources = describe()
    except (CaseFailureError, OSError) as unreadable:
        print(f"engine/bench.sh: cannot read the case table: {unreadable}", file=sys.stderr)
        return 2
    known = tuple(sorted(cases))
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("names", nargs="*", choices=known, default=known)
    parser.add_argument("--list", action="store_true", dest="list_cases")
    parser.add_argument(
        "--counter-only",
        action="store_true",
        help="skip perf; inferences alone decide",
    )
    parser.add_argument("--update-baseline", action="store_true")
    arguments = parser.parse_args(argv)
    if arguments.list_cases:
        print("\n".join(known))
        return 0
    selected = list(arguments.names)

    instructions = not arguments.counter_only
    if instructions and shutil.which("perf") is None:
        print("note: perf not found, instruction pins will not be checked")
        instructions = False

    baseline = BenchmarkBaseline(BASELINE, update=arguments.update_baseline)
    # A refusal is not a regression and does not get a regression's exit code.
    # Reaching the cases at all after the stamp differs would report the
    # configuration's cost as the engine's, which is the whole reason the stamp
    # exists: the C reader alone moves the parse case from 152 inferences to
    # 5,065,952.
    try:
        # The generating boot is a different workload from the loading one, and
        # every case here starts by loading the engine.
        _run(_goal("boot"))
        baseline.observe_configuration(stamp(sources))
    except AssertionError as refusal:
        print(f"engine/bench.sh: {refusal}", file=sys.stderr)
        print(
            "engine/bench.sh: REFUSING to compare across configurations rather "
            "than reporting a move the engine did not make",
            file=sys.stderr,
        )
        return 2
    except (CaseFailureError, OSError) as unusable:
        print(f"engine/bench.sh: cannot measure this tree: {unusable}", file=sys.stderr)
        return 2

    # Boot also carries non-monotonic atom/predicate inventory costs. The
    # baseline records the depth controls and the fresh-atom positive control;
    # neither a different length nor a different depth can re-pin this row.
    path_refusal = baseline.checkout_path_refusal(ROOT)

    failures: list[str] = []
    refused: list[str] = []
    for name in selected:
        case = cases[name]
        if arguments.update_baseline and case.whole_process and path_refusal is not None:
            refused.append(
                f"{name}: not re-pinned; {path_refusal}. `sh engine/bench.sh "
                f"{name}` reports the samples here"
            )
            print(f"{name}: NOT RE-PINNED IN THIS CONFIGURATION")
            continue
        try:
            if case.whole_process:
                # The boot row reads one artifact state whatever lane ran before
                # it: the governed set is purged and warmed through the ordinary
                # boot in children of their own (a library artifact another lane
                # left beside the three the boot compiles moved this row 17
                # inferences, past its four-inference allowance
                # [measured 2026-09-11: 319,073 against 319,090; commit=23033852660c31aeadeb2719a1eead355c36e0bf]).
                try:
                    inventory = prepare_governed_artifacts(ROOT)
                except subprocess.CalledProcessError as unprepared:
                    detail = (unprepared.stderr or unprepared.stdout or "").strip()
                    msg = f"the governed artifact set could not be prepared: {detail}"
                    raise CaseFailureError(msg) from unprepared
                print(
                    f"{name} fixture: {len(inventory)} governed QLF artifacts after "
                    "the purge and the ordinary warm boot"
                )
            print(
                observe(
                    baseline,
                    name,
                    case,
                    instructions=instructions,
                    path_refusal=path_refusal,
                )
            )
        except RowRefusedError as refusal:
            refused.append(f"{name}: {refusal}")
            print(str(refusal))
        # AssertionError is how the harness reports a band; the rest are how the
        # INSTRUMENT reports that it could not take a reading. Both have to land
        # here rather than unwind: a failure in one case that ends the run hides
        # every case after it, which is the exact shape check_instructions.py
        # records as having masked four stale pins for days.
        except (
            AssertionError,
            CaseFailureError,
            FileNotFoundError,
            KeyError,
            RuntimeError,
            TimeoutError,
            ValueError,
        ) as failure:
            failures.append(f"{name}: {failure}")
            print(f"{name}: FAILED")
    baseline.finish()
    if arguments.update_baseline:
        print(f"re-pinned {len(selected) - len(refused)} case(s) in {BASELINE}")
    # Printed either way, so "the check stopped happening" is never silent;
    # what refusal_is_fatal decides is whether it is also red. On a runner it
    # is, because a row nobody measured is a tripwire nobody read, and CI runs
    # at the repository root where the length agrees anyway.
    for message in refused:
        print(f"NOT MEASURED IN THIS CONFIGURATION {message}", file=sys.stderr)
    if refused and refusal_is_fatal():
        failures = failures + refused
    if failures:
        for message in failures:
            print(message, file=sys.stderr)
        print(f"{len(failures)} of {len(selected)} case(s) failed", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(measured_main(main))
