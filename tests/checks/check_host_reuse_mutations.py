"""Purpose: prove run_selftest.sh would notice each rule tools/pymetta-host/run.sh keeps about reusing a host build going.

tools/pymetta-host/run_selftest.sh drives run.sh through the cases a reuse can
get wrong and passes. That answers "does run.sh hold today", not "would the
self-test notice if it stopped holding": a case can pass for a reason unrelated
to the rule it was written for, and a green self-test reads the same either
way. So each rule is TAKEN AWAY, one at a time, and the self-test has to go
red, the way check_evidence_mutations.py holds the evidence gate's self-test
and tools/pending_publishers_selftest.py --mutants holds the publisher plan's.

One mutant per rule, each the smallest edit that removes it, written against
a copy: run_selftest.sh reads the run.sh it tests from RUN_SH and works in
RUN_SELFTEST_WORK, so every mutant runs in its own directory under
ai-tmp/run-mutants and the real run.sh is only read.
Assumes:
  - run_selftest.sh tests the run.sh RUN_SH names and prints each failed case
    as `  <case>: wanted [...]`
    [source 2026-09-25T22:09:33+10:00: tools/pymetta-host/run_selftest.sh, RUN_SH and expect]
Guarantees:
  - the unmutated control has to pass, so a self-test broken to fail always
    cannot make every mutant look caught
    [tested 2026-09-25T22:10:42+10:00: host-reuse-mutants]
  - a mutant the self-test does not notice is reported by the rule it removes,
    and each one it notices is printed with the cases that caught it
    [tested 2026-09-25T22:10:42+10:00: host-reuse-mutants]
  - a mutant whose text is no longer in run.sh exactly once is reported rather
    than skipped, so a rule that moved cannot leave its mutant testing nothing
    [source 2026-09-25T22:11:40+10:00: tests/checks/check_host_reuse_mutations.py, main]
Fails when: run where ai-tmp is not writable.
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HOST = ROOT / "tools" / "pymetta-host"
WORK = ROOT / "ai-tmp" / "run-mutants"

#: (the rule it takes away, the text in run.sh, what replaces it).
MUTATIONS = (
    ("a failed stage stopping the run before anything is recorded",
     "set -euo pipefail\n", "set -uo pipefail\n"),
    ("the record's removal before a compile stage runs",
     '    rm -f "$OUT/host-inputs"\n', ""),
    ("the interpreters in the key",
     "    printf 'tags %s\\n' \"$TAGS\"\n", ""),
    ("the image in the key",
     "    printf 'image %s %s\\n' \"$IMAGE\" \"$(docker image inspect --format '{{.Id}}' \"$IMAGE\")\"\n", ""),
    ("the files of tools/pymetta-host in the key",
     "        printf 'file %s %s\\n'", "        : printf 'file %s %s\\n'"),
    ("the patch stack in the key",
     "        printf 'patch %s %s\\n'", "        : printf 'patch %s %s\\n'"),
    ("the refusal to reuse a build when the caller supplies SRC",
     'if [ -z "${SRC:-}" ] && [ -f "$OUT/host-inputs" ]; then', 'if [ -f "$OUT/host-inputs" ]; then'),
    ("the check that OUT/swipl and OUT/janus still exist",
     'elif [ ! -d "$OUT/swipl" ] || [ ! -d "$OUT/janus" ]; then', "elif false; then"),
    ("the lines that differ, printed before a rebuild",
     "        diff \"$OUT/host-inputs\" <(printf '%s\\n' \"$current\") | grep '^[<>]' || true\n",
     "        true\n"),
    ("the skip of a compile stage the record vouches for",
     "        vouched=1\n", "        vouched=0\n"),
    ("fetching the source only for a run that compiles",
     "compiles=0\nfor WHICH", "compiles=1\nfor WHICH"),
    ("mounting /src only for a compile stage",
     '    case " $COMPILE_STAGES " in *" $1 "*) mounts=(-v "$SRC:/src") ;; esac\n',
     '    mounts=(-v "${SRC:-/absent}:/src")\n'),
    ("recording only a build from the derived tree",
     'if [ "$derived" = 1 ]; then\n    for WHICH', "if true; then\n    for WHICH"),
    ("recording only when both compile stages ran",
     '        case $compiled in *" $WHICH "*) ;; *) exit 0 ;; esac\n', ""),
)

FAILED_CASE = re.compile(r"^  (.+?): wanted \[", re.MULTILINE)


def selftest(name: str, run_sh: Path) -> tuple[int, list[str], str]:
    """Run the self-test against RUN_SH in NAME's own directory; answer its code, failed cases and last line."""
    environment = dict(os.environ, RUN_SH=str(run_sh), RUN_SELFTEST_WORK=str(WORK / name / "work"))
    # unbounded: the self-test plants its trees, runs run.sh a few dozen times against stubs, and returns.
    done = subprocess.run(["sh", str(HOST / "run_selftest.sh")], capture_output=True, text=True,
                          check=False, env=environment)
    lines = (done.stdout + done.stderr).strip().splitlines()
    return done.returncode, FAILED_CASE.findall(done.stdout), lines[-1] if lines else ""


def main() -> int:
    """Take each rule away in turn, and report every one the self-test did not notice."""
    shutil.rmtree(WORK, ignore_errors=True)
    source = (HOST / "run.sh").read_text(encoding="utf-8")
    findings = []
    # The control first: without it a self-test broken to fail on any run.sh
    # would report every mutant as caught.
    code, failed, last = selftest("control", HOST / "run.sh")
    if code != 0:
        findings.append(f"the unmutated self-test does not pass ({last}), so nothing below means anything")
    runnable = []
    for what, old, new in MUTATIONS:
        if source.count(old) != 1:
            findings.append(f"run.sh holds the text for {what!r} {source.count(old)} times, not once, "
                            "so that mutant tests nothing until it follows the rule")
            continue
        name = f"mutant-{len(runnable) + 1:02d}"
        mutant = WORK / name / "run.sh"
        mutant.parent.mkdir(parents=True)
        mutant.write_text(source.replace(old, new), encoding="utf-8")
        runnable.append((what, name, mutant))
    width = int(os.environ.get("METTA_LANE_WIDTH") or os.cpu_count() or 1)
    with ThreadPoolExecutor(max_workers=width) as pool:
        results = list(pool.map(lambda item: selftest(item[1], item[2]), runnable))
    for (what, _name, _mutant), (code, failed, last) in zip(runnable, results, strict=True):
        if code == 0:
            findings.append(f"the self-test still passes without {what}")
        else:
            print(f"without {what}: caught by {'; '.join(failed) if failed else 'the self-test stopping: ' + last}")
    for finding in findings:
        print(finding)
    print(f"{len(findings)} unpinned rule(s), over {len(MUTATIONS)} mutations of run.sh and one unmutated control")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
