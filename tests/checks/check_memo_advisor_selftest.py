"""Purpose: prove the memo advisor proposes the row that wins and refuses the rest.

Assumes:
  - the selected interpreter boots the engine, because the advisor spawns
    processes that do; the lane's own command is read out of the gate text so
    this follows the lane rather than the file it currently lives in
Guarantees:
  - a run that DOES propose a row leaves every byte of its workload untouched,
    so "never applies" is checked on the case where applying would have been
    tempting [tested: test_the_advisor_writes_no_row; commit=WORKTREE]
  - a pure head called a thousand times over three distinct arguments is
    proposed as `(cache weigh force)` with a POSITIVE measured inference delta,
    so the advisor's what-if is a measurement and not a guess
    [tested: test_a_reused_pure_head_is_proposed_with_a_measured_gain;
    commit=WORKTREE]
  - a head declared `oracleIO` is never proposed, though it is called three
    hundred times and the memo declined it as not recursive, which is the same
    shape the proposed head has minus its purity
    [tested: test_an_oracle_head_is_never_proposed; commit=WORKTREE]
  - a workload that ran no compiled head at all is refused by NAME rather than
    reported as having nothing to say
    [tested: test_a_workload_with_no_calls_is_refused; commit=WORKTREE]
Fails when: the advisor stops proposing a row that a measurement says wins,
  starts proposing one whose effect row says it reaches outside the engine, or
  applies one. All three are the discrimination this lane exists to hold, so a
  green run here is a claim about the advisor and not about these three files.
Owns resources: one TemporaryDirectory per case, removed on every path; the
  advisor's own spawned processes are reaped by bench.finish_process.
Decides: the plants are written here rather than committed under examples/,
  because the corpus is documentation that runs and a deliberately pathological
  workload is neither.
"""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

from evidence_runners import gate_scripts

ROOT = Path(__file__).resolve().parents[2]
PYTHON_ROOT = ROOT / "extensions" / "python"
COMMAND_TIMEOUT_SECONDS = 290
ADVISOR_MODULE = "benchmarks.memo_advisor"

#: A pure head reached a thousand times over three distinct arguments, behind a
#: driver the memo declines on its own (one recursive body call), so the only
#: cache decision left is the one this lane is about.
PURE_PLANT = """\
(= (sum-to $n) (if (< $n 1) 0 (+ $n (sum-to (- $n 1)))))
(= (weigh $k) (sum-to (+ 300 $k)))
(= (drive $n) (if (< $n 1) 0 (+ (weigh (% $n 3)) (drive (- $n 1)))))
!(test (> (drive 1000) 0) True)
"""

#: The same shape with one difference: the head declares an effect that reaches
#: outside the engine, so no cache may be chosen for it on anyone's initiative.
ORACLE_PLANT = """\
!(add-atom &metta (effect roll oracleIO))
(= (roll $k) (+ $k 1))
(= (spin $n) (if (< $n 1) 0 (+ (roll (% $n 3)) (spin (- $n 1)))))
!(test (> (spin 300) 0) True)
"""

#: Arithmetic and nothing else: no equation, so no compiled head is called.
EMPTY_PLANT = "!(test (+ 1 2) 3)\n"


def _gate_text() -> str:
    """The whole gate's text, so the command below follows the lane."""
    return "\n".join(script.read_text(encoding="utf-8") for script in gate_scripts())


def _advise(directory: Path, *, candidates: int = 8) -> subprocess.CompletedProcess[str]:
    """Run the advisor over one directory of plants, as the lane runs it."""
    env = os.environ.copy()
    env["PYTHONPATH"] = str(PYTHON_ROOT)
    return subprocess.run(
        [sys.executable, "-m", ADVISOR_MODULE, "--workload", str(directory),
         "--json", "--candidates", str(candidates)],
        cwd=PYTHON_ROOT,
        env=env,
        check=False,
        capture_output=True,
        text=True,
        timeout=COMMAND_TIMEOUT_SECONDS,
    )


def _tree_digest(root: Path) -> dict[str, str]:
    """Every file under a directory, by path and content digest."""
    return {
        str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in sorted(root.rglob("*"))
        if path.is_file()
    }


def _report(plants: dict[str, str], *, candidates: int = 8) -> dict:
    """Write the plants, run the advisor, and answer its JSON report."""
    with tempfile.TemporaryDirectory(prefix="metta-memo-advisor-") as directory:
        scratch = Path(directory)
        for name, text in plants.items():
            (scratch / name).write_text(text, encoding="utf-8")
        completed = _advise(scratch, candidates=candidates)
        assert completed.returncode == 0, completed.stdout + completed.stderr
        return json.loads(completed.stdout)


def test_a_reused_pure_head_is_proposed_with_a_measured_gain() -> None:
    """Require the winning row to be proposed, and its gain to be measured."""
    assert ADVISOR_MODULE in _gate_text()
    report = _report({"01-pure-head.metta": PURE_PLANT})
    heads = {row["name"]: row for row in report["heads"]}
    assert "weigh" in heads, report
    assert heads["weigh"]["entry_calls"] == 1000, heads["weigh"]
    assert heads["weigh"]["policy"] == "declined", heads["weigh"]
    assert heads["weigh"]["reason"] == "not-recursive", heads["weigh"]

    proposals = {item["head"].split("/")[0]: item for item in report["proposals"]}
    assert "weigh" in proposals, report["proposals"]
    proposal = proposals["weigh"]
    assert proposal["row"] == "(cache weigh force)", proposal
    assert proposal["delta"] > 0, proposal
    assert proposal["inferences_after"] < proposal["inferences_before"], proposal
    assert proposal["distinct_calls"] == 3, proposal
    assert proposal["total_calls"] == 1000, proposal
    assert proposal["hit_ratio"] is not None and proposal["hit_ratio"] > 0.99, proposal
    print(
        "memo advisor selftest: (cache weigh force) proposed, "
        f"{proposal['inferences_before']} -> {proposal['inferences_after']} "
        f"inferences, delta {proposal['delta']}, hit {proposal['hit_ratio']:.1%}"
    )


def test_the_advisor_writes_no_row() -> None:
    """Require the run that proposes a winning row to write nothing at all.

    The check is on the case where applying would have been tempting: the
    advisor measures `(cache weigh force)` as a large win and still leaves
    every byte of the workload where it was. A run that proposed nothing would
    pass this vacuously, so the proposal is asserted first.
    """
    with tempfile.TemporaryDirectory(prefix="metta-memo-advisor-") as directory:
        scratch = Path(directory)
        (scratch / "01-pure-head.metta").write_text(PURE_PLANT, encoding="utf-8")
        before = _tree_digest(scratch)
        completed = _advise(scratch)
        assert completed.returncode == 0, completed.stdout + completed.stderr
        report = json.loads(completed.stdout)
        proposed = [item["row"] for item in report["proposals"]]
        assert "(cache weigh force)" in proposed, report["proposals"]
        after = _tree_digest(scratch)
        assert after == before, f"the advisor changed {sorted(set(after) ^ set(before))}"
    print(
        "memo advisor selftest: a run proposing (cache weigh force) left "
        f"{len(before)} workload file(s) byte-identical"
    )


def test_an_oracle_head_is_never_proposed() -> None:
    """Require a head whose effect reaches outside the engine to stay unproposed."""
    report = _report({"02-oracle-head.metta": ORACLE_PLANT})
    heads = {row["name"]: row for row in report["heads"]}
    assert "roll" in heads, report
    assert heads["roll"]["effect"] == "oracleIO", heads["roll"]
    assert heads["roll"]["entry_calls"] == 300, heads["roll"]
    assert heads["roll"]["policy"] == "declined", heads["roll"]
    assert heads["roll"]["reason"] == "not-recursive", heads["roll"]
    proposed = [item["head"].split("/")[0] for item in report["proposals"]]
    assert "roll" not in proposed, report["proposals"]
    print(
        "memo advisor selftest: roll/2 ran 300 calls, was declined as "
        "not-recursive, and was NOT proposed because its effect row is oracleIO"
    )


def test_a_workload_with_no_calls_is_refused() -> None:
    """Require a workload that called no compiled head to be refused by name."""
    with tempfile.TemporaryDirectory(prefix="metta-memo-advisor-") as directory:
        scratch = Path(directory)
        (scratch / "03-no-heads.metta").write_text(EMPTY_PLANT, encoding="utf-8")
        completed = _advise(scratch)
        output = completed.stdout + completed.stderr
        assert completed.returncode != 0, output
        assert "ran zero calls of any compiled head" in output, output
        assert str(scratch) in output, output
    print(
        "memo advisor selftest: a workload calling no compiled head exited "
        f"{completed.returncode} and named itself"
    )


def main() -> int:
    """Run the three planted cases without depending on pytest collection."""
    failures: list[str] = []
    for check in (
        test_a_reused_pure_head_is_proposed_with_a_measured_gain,
        test_the_advisor_writes_no_row,
        test_an_oracle_head_is_never_proposed,
        test_a_workload_with_no_calls_is_refused,
    ):
        try:
            check()
        except AssertionError as exc:
            failures.append(f"{check.__name__}: {exc}")
    for failure in failures:
        print(failure)
    print(f"memo advisor selftest: 4 planted case(s), {len(failures)} failure(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
