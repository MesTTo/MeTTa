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
    commit=WORKTREE]
  - a budget moved by the allowance passes and one moved past it fails, in both
    directions, so the two-sided band is the thing deciding
    [tested: this file is its own gate; commit=WORKTREE]
  - a declared DIVERGENCE passes only for the difference it names: a stale one
    over two agreeing spaces, and a wrong one over two differing spaces, are
    both findings [tested: this file is its own gate; commit=WORKTREE]
  - an undeclared band overrun is a finding, the declared one passes, and a
    declaration the twin no longer needs is itself a finding
    [tested: this file is its own gate; commit=WORKTREE]
Fails when: the lane stops exposing `run_example` and `run_twin` as its only
  process calls, or moves a verdict out of `check`.
Owns resources: one TemporaryDirectory per plant, removed on every path.
Decides: the plants are written into scratch rather than committed under
  `extensions/python/examples/language-feature-examples/`, because that corpus
  is documentation that runs and a deliberately false twin is not.
"""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "extensions" / "python"))
sys.path.insert(0, str(ROOT / "extensions" / "python" / "tools"))

import twin_coverage as lane  # noqa: E402

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
                    today="2026-09-07",
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
        plain = lane.rediverged(_twin_source(), None, "", "", today="2026-09-07")
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
        today="2026-09-07",
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


def main() -> int:
    """Plant every verdict the lane makes, and report the ones it missed."""
    failures = [
        *false_claim_failures(),
        *budget_failures(),
        *divergence_failures(),
        *overrun_failures(),
    ]
    for failure in failures:
        print(f"twins selftest: {failure}", file=sys.stderr)
    if failures:
        return 1
    print(
        "twins selftest: a flipped assertion, a budget past its allowance in "
        "both directions, a stale and a wrong stored-content divergence, and "
        "an undeclared band overrun each fail the lane; the honest copies of "
        "all four pass"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
