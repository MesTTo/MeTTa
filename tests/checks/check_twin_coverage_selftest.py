"""Purpose: prove the twins lane can fail, on each of the four things it decides.

The lane became a GATE on 2026-09-07, and a gate nobody has watched fail is a
gate nobody knows the shape of. So every decision it makes is planted here and
the plant has to turn it red: a false claim, a budget outside its allowance, a
stored-content difference that is not the declared one, and a band overrun that
is not declared.

The failing twin is REAL. It is a shipped twin copied into scratch with one
assertion flipped, and it is run through the lane's own `run_twin`, so the
AssertionError the lane reads is one Python actually raised. The two process
seams, `run_example` and `run_twin`, are then the only things replaced when a
plant needs a specific pair of runs, which is the discipline
check_upstream_parity_selftest.py already follows: the plant reaches the
production verdict path or it is testing a copy of the lane.

Assumes:
  - `examples/ch05-equations-and-evaluation/05-01-an-equation-is-a-rewrite/01-identity.metta`
    and its twin ship and pass, because every plant here is that pair with one
    thing changed; a red control means the plant proves nothing
  - the scratch directory is the gate's own, under ai-tmp/check-runs, which
    `tests/checks/gate_scratch.sh` exports as TMPDIR before any lane runs
Guarantees:
  - a twin whose assertion is false is a finding naming the failed run, and the
    same twin unflipped is silent [tested: this file is its own gate;
    commit=9010a79b01c9b2a66b96a3952fa378fb3e939dc3]
  - a budget moved by the allowance passes and one moved past it fails, in both
    directions, so the two-sided band is the thing deciding
    [tested: this file is its own gate; commit=9010a79b01c9b2a66b96a3952fa378fb3e939dc3]
  - a declared DIVERGENCE passes only for the difference it names: a stale one
    over two agreeing spaces, and a wrong one over two differing spaces, are
    both findings [tested: this file is its own gate; commit=9010a79b01c9b2a66b96a3952fa378fb3e939dc3]
  - an undeclared band overrun is a finding, the declared one passes, and a
    declaration the twin no longer needs is itself a finding
    [tested: this file is its own gate; commit=9010a79b01c9b2a66b96a3952fa378fb3e939dc3]
  - the lane's re-pin reads a tag's time exactly as the evidence gate does,
    so it cannot write a stamp the gate reports
    [tested 2026-09-25T00:40:16+10:00: sh tools/check.sh twins-selftest]
  - where the lane runs does not move a count: 31-system_lib's example and twin,
    which walk the whole environment, read the same from a lane process inside
    a metta-bounded scope and from one outside it, and one variable planted in
    the lane's child environment moves the example, so the equality is about
    the environment and not a plant that cannot see it; where no scope can be
    made no lane runs inside one, and the plant says it is skipped
    [tested 2026-09-25T16:08:59+10:00:
    tests/checks/check_twin_coverage_selftest.py]
Fails when: the lane stops exposing `run_example` and `run_twin` as its only
  process calls, or moves a verdict out of `check`.
Owns resources: one TemporaryDirectory per plant, removed on every path.
Decides: the plants are written into scratch rather than committed under
  `extensions/python/examples/language-feature-examples/`, because that corpus
  is documentation that runs and a deliberately false twin is not.
"""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "extensions" / "python"))
sys.path.insert(0, str(ROOT / "extensions" / "python" / "tools"))

import twin_coverage as lane  # noqa: E402
from bounded_spawn import BOUNDED, bounded  # noqa: E402

#: The pair every plant is built from: one equation, one claim, no imports.
EXAMPLE = ROOT / (
    "examples/ch05-equations-and-evaluation/"
    "05-01-an-equation-is-a-rewrite/01-identity.metta"
)
RELATIVE = str(EXAMPLE.relative_to(ROOT))

#: The claim to flip, and what to flip it to. A twin that asserts the square of
#: one is two disagrees with its example about the one thing the example says.
TRUE_CLAIM = "assert f(1) == [1]"
FALSE_CLAIM = "assert f(1) == [2]"


def _twin_source() -> str:
    """The shipped twin's text, with the claim this file flips present in it."""
    text = lane.twin_for(EXAMPLE).read_text(encoding="utf-8")
    if TRUE_CLAIM not in text:
        msg = f"{lane.twin_for(EXAMPLE)} no longer states {TRUE_CLAIM!r}"
        raise RuntimeError(msg)
    return text


def _planted(scratch: Path, source: str, name: str = "planted.py") -> Path:
    path = scratch / name
    path.write_text(source, encoding="utf-8")
    return path


def _findings(twin: Path, *, left: lane.Run, right: lane.Run) -> list[str]:
    """The lane's verdict on one pair of runs, with only the seams replaced."""
    seams = lane.run_example, lane.run_twin, lane.twin_for
    lane.run_example = lambda *_a, **_k: left
    lane.run_twin = lambda *_a, **_k: right
    lane.twin_for = lambda *_a, **_k: twin
    try:
        return list(lane.check(EXAMPLE, lane.residue()).findings)
    finally:
        lane.run_example, lane.run_twin, lane.twin_for = seams


def false_claim_failures() -> list[str]:
    """A real twin, really run, with one assertion flipped."""
    failures = []
    with tempfile.TemporaryDirectory(prefix="metta-twins-selftest-") as directory:
        scratch = Path(directory)
        honest = _planted(scratch, _twin_source(), "honest.py")
        flipped = _planted(
            scratch, _twin_source().replace(TRUE_CLAIM, FALSE_CLAIM), "flipped.py"
        )
        left = lane.run_example(EXAMPLE)
        if left.outcome.error is not None:
            return [f"the control example does not run: {left.outcome.error}"]
        good, bad = lane.run_twin(honest), lane.run_twin(flipped)
        if bad.outcome.error is None:
            failures.append("a twin asserting f(1) == [2] ran without an error")
        if good.outcome.error is not None:
            failures.append(f"the unflipped copy does not run: {good.outcome.error}")
        reported = _findings(flipped, left=left, right=bad)
        if not any("the twin failed to run" in finding for finding in reported):
            failures.append(f"the lane passed a false claim: {reported}")
        control = _findings(honest, left=left, right=good)
        if any("failed to run" in finding for finding in control):
            failures.append(f"the lane failed the honest copy: {control}")
    return failures


def budget_failures() -> list[str]:
    """A budget moved by the allowance, and one moved past it."""
    failures = []
    with tempfile.TemporaryDirectory(prefix="metta-twins-selftest-") as directory:
        scratch = Path(directory)
        honest = _planted(scratch, _twin_source(), "honest.py")
        run = lane.run_twin(honest)
        if run.cost is None:
            return [f"the control twin does not run: {run.outcome.error}"]
        allowance = lane.allowance_of(honest) or lane.TOLERANCE
        for offset, expected in (
            (allowance, False),
            (-allowance, False),
            (allowance + 1, True),
            (-(allowance + 1), True),
        ):
            moved = _planted(
                scratch,
                lane.repinned(
                    _twin_source(),
                    run.cost + offset,
                    "a planted move, to prove the band decides",
                    stamp="2026-09-07T10:11:12+10:00",
                ),
                f"budget{offset}.py",
            )
            reported = lane._budget_findings(
                RELATIVE, moved, run, lane.SERIAL_PROTOCOL
            )
            named = any("pinned budget" in finding for finding in reported)
            if named is not expected:
                failures.append(
                    f"a budget {offset:+d} from the measured {run.cost} "
                    f"{'passed' if expected else 'failed'} its allowance of "
                    f"{allowance}: {reported}"
                )
    return failures


def divergence_failures() -> list[str]:
    """A declared stored-content difference, stale and wrong and right."""
    failures = []
    agreeing = lane.Run(
        lane.parity.Outcome(0, None), 100, (), "a" * 64, None, ("(f 1)",)
    )
    differing = lane.Run(
        lane.parity.Outcome(0, None), 100, (), "b" * 64, None, ("(f 1)", "(g 2)")
    )
    observed = lane.content_divergence([], ["(g 2)"])
    with tempfile.TemporaryDirectory(prefix="metta-twins-selftest-") as directory:
        scratch = Path(directory)
        # The shipped twin DECLARES a divergence of its own, so the two cases
        # about a twin that declares nothing are built from it with the
        # declaration dropped, which is the door that drops one.
        plain = lane.rediverged(_twin_source(), None, "", "", stamp="2026-09-07T10:11:12+10:00")
        cases = (
            ("undeclared", plain, agreeing, differing, True),
            ("right", _diverged(observed), agreeing, differing, False),
            ("wrong", _diverged("c" * 64), agreeing, differing, True),
            ("stale", _diverged(observed), agreeing, agreeing, True),
            ("silent", plain, agreeing, agreeing, False),
        )
        for name, source, left, right, expected in cases:
            twin = _planted(scratch, source, f"divergence-{name}.py")
            reported = lane._stored(RELATIVE, twin, left, right)
            if bool(reported) is not expected:
                failures.append(
                    f"the {name} divergence "
                    f"{'passed' if expected else 'failed'}: {reported}"
                )
    return failures


def _diverged(digest: str) -> str:
    """The control twin declaring one stored-content divergence."""
    return lane.rediverged(
        _twin_source(),
        digest,
        "a planted divergence, to prove the declaration decides",
        "the twin holds 1 atom the example does not (1 g)",
        stamp="2026-09-07T10:11:12+10:00",
    )


def overrun_failures() -> list[str]:
    """An undeclared band overrun, the declared one, and one no longer needed."""
    failures = []
    example_cost = 1000
    with tempfile.TemporaryDirectory(prefix="metta-twins-selftest-") as directory:
        scratch = Path(directory)
        source = _twin_source()
        # The control twin authors one definition, so its own ceiling already
        # carries the authoring allowance; the plant is 500 past THAT.
        authored = lane.definitions(_planted(scratch, source, "shape.py"))
        ceiling = example_cost * (1 + lane.BAND_PERCENT / 100) + (
            lane.DEFINITION_WARMUP + lane.DEFINITION_COST * authored if authored else 0
        )
        over = int(ceiling) + 500
        cases = (
            ("undeclared", source, over, True, "band ceiling"),
            ("declared", f"{source}OVERRUN = 500\n", over, False, "band ceiling"),
            ("needless", f"{source}OVERRUN = 500\n", int(ceiling), True, "drop OVERRUN"),
        )
        for name, text, cost, expected, wording in cases:
            twin = _planted(scratch, text, f"overrun-{name}.py")
            left = lane.Run(lane.parity.Outcome(0, None), example_cost, ())
            right = lane.Run(lane.parity.Outcome(0, None), cost, ())
            reported = [
                finding
                for finding in lane._price(RELATIVE, twin, left, right)
                if wording in finding
            ]
            if bool(reported) is not expected:
                failures.append(
                    f"the {name} overrun "
                    f"{'passed' if expected else 'failed'}: {reported}"
                )
    return failures


def capability_failures() -> list[str]:
    """A twin whose `available(m)` answers False keeps its budget uncompared, and one answering True is priced."""
    failures = []
    with tempfile.TemporaryDirectory(prefix="metta-twins-selftest-") as directory:
        scratch = Path(directory)
        control = lane.run_twin(_planted(scratch, _twin_source(), "honest.py"))
        if control.cost is None:
            return [f"the control twin does not run: {control.outcome.error}"]
        wrong = 1 if control.cost > 1_000 else control.cost + 1_000_000
        for answer in (False, True):
            source = _twin_source().replace(
                f"BUDGET = {lane.budget_of(_planted(scratch, _twin_source(), 'b.py'))}",
                f"BUDGET = {wrong}",
            ) + f"\n\ndef available(m):\n    return {answer}\n"
            twin = _planted(scratch, source, f"capability-{answer}.py")
            run = lane.run_twin(twin)
            if run.available is not answer:
                failures.append(
                    f"the driver reported available={run.available!r} for a twin "
                    f"answering {answer}"
                )
            left = lane.run_example(EXAMPLE)
            reported = _findings(twin, left=left, right=run)
            priced = any("pinned budget" in finding for finding in reported)
            if answer is False and priced:
                failures.append(
                    "the lane priced a twin whose available(m) answered False: "
                    f"{reported}"
                )
            if answer is True and not priced:
                failures.append(
                    "the lane did not price a wrong budget on a twin whose "
                    f"available(m) answered True: {reported}"
                )
    return failures


def _git(where: Path, *arguments: str) -> None:
    """One git command in a planted tree, identity supplied so a commit lands."""
    subprocess.run(
        ["git", "-C", str(where),
         "-c", "user.name=selftest", "-c", "user.email=selftest@example.invalid",
         *arguments],
        check=True, capture_output=True, text=True,
    )


def orphan_failures() -> list[str]:
    """A tracked twin the corpus does not run is reported; a file belonging to a repository mounted inside the twins tree is not.

    The corpus IS mounted inside the twins repository, so a directory walk
    reached a second repository and called its examples twins of examples
    nothing runs. The plant is that shape rather than that case: a twins
    repository holding one live twin, one whose example does not exist, and a
    mounted repository of its own. The walk assertion is why this proves
    something -- it confirms the foreign file is reachable by walking, so a
    silent answer means the boundary is what decided and not an empty tree.
    """
    failures = []
    with tempfile.TemporaryDirectory(prefix="metta-twins-orphan-") as directory:
        root = Path(directory)
        (root / "examples" / "ch00").mkdir(parents=True)
        (root / "examples" / "ch00" / "01-real.metta").write_text(
            "!(test 1 1)\n", encoding="utf-8")

        twins = lane.twins_root(root)
        (twins / "ch00").mkdir(parents=True)
        for name in ("01-real.py", "02-gone.py"):
            (twins / "ch00" / name).write_text("def twin(m):\n    pass\n", encoding="utf-8")
        _git(twins, "init", "-q")

        mounted = twins / "mounted"
        (mounted / "ch00").mkdir(parents=True)
        (mounted / "ch00" / "03-foreign.py").write_text(
            "def twin(m):\n    pass\n", encoding="utf-8")
        _git(mounted, "init", "-q")
        _git(mounted, "add", "ch00/03-foreign.py")
        _git(mounted, "commit", "-qm", "the mounted repository's own file")

        _git(twins, "add", "ch00", "mounted")
        _git(twins, "commit", "-qm", "two twins and a mounted repository")

        reported = {path.name for path in lane.orphans(root)}
        walked = {path.name for path in twins.rglob("*.py")}

        if "02-gone.py" not in reported:
            failures.append(
                "a tracked twin whose example the corpus does not run was not "
                f"reported as an orphan: {sorted(reported)}"
            )
        if "01-real.py" in reported:
            failures.append(
                "a twin whose example the corpus DOES run was reported as an "
                f"orphan: {sorted(reported)}"
            )
        if "03-foreign.py" not in walked:
            failures.append(
                "the plant is wrong: a directory walk did not reach the mounted "
                "repository, so a silent answer proves nothing about the boundary"
            )
        if "03-foreign.py" in reported:
            failures.append(
                "a file belonging to a repository mounted inside the twins tree "
                f"was reported as an orphan twin: {sorted(reported)}"
            )
    return failures


#: The example that walks its whole environment, three times, and so the one
#: whose count read where the lane ran: tools/bounded.sh exported whether a
#: scope could be made only from a rung that sat outside one (its Guarantees).
CONTEXT_EXAMPLE = ROOT / (
    "examples/ch08-data/08-03-the-shipped-libraries/31-system_lib.metta"
)

#: One lane process, measuring from wherever it was started: its cgroup, then
#: the example and its twin through the lane's own run_example and run_twin,
#: one fresh child each. Any NAME=VALUE after the example is planted into the
#: environment the lane builds for its children and the example measured once
#: more, which is the control: a plant that cannot move the count cannot say
#: that where the lane ran does not.
_LANE = """\
import json, sys
from pathlib import Path
root, example = Path(sys.argv[1]), Path(sys.argv[2])
sys.path.insert(0, str(root / "extensions" / "python"))
sys.path.insert(0, str(root / "extensions" / "python" / "tools"))
import twin_coverage as lane
reading = {
    "cgroup": Path("/proc/self/cgroup").read_text(encoding="utf-8").strip(),
    "example": lane.run_example(example).cost,
    "twin": lane.run_twin(lane.twin_for(example)).cost,
}
if sys.argv[3:]:
    built, planted = lane._environment, dict(p.split("=", 1) for p in sys.argv[3:])
    lane._environment = lambda: built() | planted
    reading["planted"] = lane.run_example(example).cost
print(json.dumps(reading))
"""


def _reading(completed: subprocess.CompletedProcess[str], where: str) -> dict[str, Any]:
    """A lane process's reading, with an `error` naming what went wrong instead."""
    lines = [line for line in completed.stdout.splitlines() if line.startswith("{")]
    if completed.returncode != 0 or not lines:
        tail = (completed.stderr or completed.stdout).strip().splitlines()[-3:]
        return {"error": f"the lane process {where} exited {completed.returncode}: {tail}"}
    reading = json.loads(lines[-1])
    missing = [key for key, value in reading.items() if value is None]
    if missing:
        return {"error": f"the lane process {where} measured no cost for {missing}"}
    return reading


def context_failures() -> list[str]:
    """The same example reads the same count from a lane inside a bounded scope and outside one.

    The two lane processes are started the two ways a lane is: through
    bounded.sh, which makes a scope from outside one and nests inside one, and
    through bounded.sh with no memory bound under a scope of systemd-run's
    own, which no metta-bounded scope encloses wherever this runs. The gate
    runs this file inside a scope, which is why the second needs the escape,
    as tests/shell/test_bounded_reaping.sh's outermost-rung cases do. Where no
    scope can be made, no lane ever runs inside one and there is nothing to
    compare, which is said rather than passed over.
    """
    answer = subprocess.run(
        ["sh", str(BOUNDED), "--memory-scope"],
        capture_output=True, text=True, check=False,
    ).stdout.strip()
    if answer != "yes":
        print("twins selftest: the context plant is skipped, since no memory "
              "scope can be made here and no lane runs inside one")
        return []
    measure = [sys.executable, "-c", _LANE, str(ROOT), str(CONTEXT_EXAMPLE)]
    inside = _reading(subprocess.run(
        bounded([*measure, "METTA_TWINS_SELFTEST_PLANT=1"]),
        capture_output=True, text=True, check=False, cwd=ROOT,
    ), "inside a scope")
    outside = _reading(subprocess.run(
        ["systemd-run", "--user", "--scope", "--quiet",
         "--expand-environment=no", "--", *bounded(measure, memory="none")],
        capture_output=True, text=True, check=False, cwd=ROOT,
    ), "outside a scope")
    failures = [reading["error"] for reading in (inside, outside) if "error" in reading]
    if failures:
        return failures
    scoped = "/metta-bounded.slice/"
    if scoped not in inside["cgroup"] or scoped in outside["cgroup"]:
        return [
            "the plant is wrong: the lane meant to run inside a scope ran in "
            f"{inside['cgroup']!r} and the one meant to run outside in "
            f"{outside['cgroup']!r}"
        ]
    if inside["planted"] <= inside["example"]:
        failures.append(
            "the plant is wrong: one more variable in the lane's child "
            f"environment left {CONTEXT_EXAMPLE.name} at {inside['planted']} "
            f"against {inside['example']}, so equal readings in and out of a "
            "scope say nothing about the environment"
        )
    failures.extend(
        f"{CONTEXT_EXAMPLE.name}'s {side} costs {inside[side]} inferences "
        f"from a lane inside a bounded scope and {outside[side]} from one "
        "outside it, so a lane run by hand and the gate's read different "
        "counts against one pin"
        for side in ("example", "twin")
        if inside[side] != outside[side]
    )
    if not failures:
        print(f"twins selftest: {CONTEXT_EXAMPLE.name} reads {inside['example']} "
              f"and its twin {inside['twin']} inferences from a lane inside a "
              f"scope and outside one, and {inside['planted']} with one "
              "variable planted in the lane's child environment")
    return failures


def stamp_failures() -> list[str]:
    """The lane's re-pin reads a tag's time exactly as the evidence gate does.

    tests/checks/check_evidence_tags.py:STAMP is the authority for what a
    tag's time is. The lane keeps its own copy because the Python seat is a
    repository of its own and cannot import this one's checks, so the two are
    held equal here; apart, the tool could write a stamp the gate reports, or
    refuse one the gate reads.
    """
    sys.path.insert(0, str(ROOT / "tests" / "checks"))
    from check_evidence_tags import STAMP

    if lane._STAMP.pattern != STAMP.pattern:
        return [
            f"the re-pin reads a stamp as {lane._STAMP.pattern!r} and the "
            f"evidence gate as {STAMP.pattern!r}"
        ]
    return []


def main() -> int:
    """Plant every verdict the lane makes, and report the ones it missed."""
    failures = [
        *false_claim_failures(),
        *budget_failures(),
        *divergence_failures(),
        *overrun_failures(),
        *capability_failures(),
        *orphan_failures(),
        *stamp_failures(),
        *context_failures(),
    ]
    for failure in failures:
        print(f"twins selftest: {failure}", file=sys.stderr)
    if failures:
        return 1
    print(
        "twins selftest: a flipped assertion, a budget past its allowance in "
        "both directions, a stale and a wrong stored-content divergence, and "
        "an undeclared band overrun each fail the lane, a budget declared "
        "where a capability is present stays uncompared where it is absent, "
        "and a twin covering nothing is reported while a mounted repository's "
        "own file is not; the honest copies of all four pass, the re-pin "
        "reads a tag's time as the evidence gate does, and wherever a scope "
        "can be made a lane inside one and a lane outside one read the same "
        "counts for an example that walks its whole environment"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
