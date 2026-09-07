"""Purpose: prove every plant in check_evidence_selftest.py is load-bearing.

The self-test plants a violation of each rule the evidence gate states and
checks the gate reports it. That answers "does the gate see this today" and not
"is this plant still attached to anything": a rule can be widened, a plant can
start passing for a reason that has nothing to do with what it was written for,
and a green self-test says the same thing either way. Running the gate on a
clean tree is the same mistake one level up, and it is the mistake the gate
itself exists to catch.

So each rule is TAKEN AWAY, one at a time, and the self-test has to go red. A
mutation that nothing notices is a plant pinning nothing.

This is mutation testing with a hand-written mutant set rather than a generated
one, which is what a targeted question wants: one mutant per guarantee, each
naming the rule it removes, against the generated space a tool like mutmut
explores for coverage. The repository already runs the generated kind over the
Python package in the `mutation` REPORT lane; this is the same idea aimed at
the checker.

Nothing here writes to the repository. The self-test copies the two modules
into its own fixture tree, and METTA_EVIDENCE_MUTATION patches THAT copy on the
way in, so a run killed at any point leaves the checkout exactly as it found
it. A harness that patched the real file and restored it in a `finally` is one
SIGKILL away from committing a mutated gate.
Assumes:
  - check_evidence_selftest.build() applies METTA_EVIDENCE_MUTATION to the
    module it names while copying [source: tests/checks/check_evidence_selftest.py,
    MUTATION and build; commit=WORKTREE]
Guarantees:
  - a mutation the self-test does not notice is reported by name, and the
    unmutated control has to pass, so a self-test broken to fail always cannot
    make every mutation look caught
    [tested 2026-09-07: evidence-mutations; commit=WORKTREE]
  - a mutation whose text is no longer in the module it names is reported
    rather than skipped, so a rule that moved cannot leave its plant untested
    in silence [tested 2026-09-07: evidence-mutations; commit=WORKTREE]
Fails when:
  - asked which plant catches which mutation. Several plants answer one
    mutation and one plant answers several; what is checked is that every
    mutation is caught by SOMETHING, which is the property that matters.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent

TAGS = "check_evidence_tags.py"
RUNNERS = "evidence_runners.py"

#: (what it takes away, module, the text, what replaces it). One per rule the
#: gate gained on 2026-09-07, each written as the smallest edit that puts the
#: rule back the way it was.
MUTATIONS = (
    (
        "the quoted lookup, so a name written as a sentence is dropped in silence",
        TAGS,
        "    if quoted and (found := known.targets.get(token)):\n        return found\n",
        "",
    ),
    (
        "the finding a quoted miss produces, which is the silence itself",
        TAGS,
        "    if not quoted:\n        return []\n",
        "    if True:\n        return []\n",
    ),
    (
        "`test` among the shapes node --test registers a case with",
        TAGS,
        r'r"""^\s*(?:it|test|describe)\(',
        r'r"""^\s*(?:it|describe)\(',
    ),
    (
        "the exactness of a quoted token, so a name ending in () loses it",
        TAGS,
        "        if not was_quoted:\n            token = token.strip(\" :.'\\\"`()\")",
        "        token = token.strip(\" :.'`()\") if was_quoted else token.strip(\" :.'\\\"`()\")",
    ),
    (
        "the widened suite discovery, leaving one directory's suites",
        TAGS,
        "    for path in _node_suites():\n        resolved = path.resolve()",
        '    for path in sorted((ROOT / "extensions" / "node" / "test").glob("*.test.ts")):'
        "\n        resolved = path.resolve()",
    ),
    (
        "the C CASE harvest, leaving only the function main() dispatches",
        TAGS,
        "        for function, case in _c_cases(text):\n"
        "            targets.setdefault(case, []).append(\n"
        '                Target("c", path, runner, *_c_verdict(function, called, run, reports))\n'
        "            )\n",
        "",
    ),
    (
        "the check that main() calls a C case at all",
        TAGS,
        "    if function not in called:\n"
        '        return None, "main() does not call it, so the binary never runs it"\n',
        '    if False:\n        return None, "unreachable"\n',
    ),
    (
        "the glob that reads a tracked probe's own claims",
        TAGS,
        '    "extensions/python/benchmarks/probes/*.py",\n',
        "",
    ),
    (
        "the scratch refusal",
        TAGS,
        "        if root is not None:\n            problems += scratch_problems(body, under, root)\n",
        "",
    ),
    (
        "the tsconfig hop, so a suite compiled before it runs reads as unrun",
        RUNNERS,
        "            for pattern in (token, *tsc_sources(package, token)):",
        "            for pattern in (token,):",
    ),
)


def selftest(mutation: dict[str, str] | None) -> int:
    """The real self-test, over a fixture built with this mutation applied."""
    environment = dict(os.environ)
    with tempfile.TemporaryDirectory() as directory:
        if mutation is None:
            environment.pop("METTA_EVIDENCE_MUTATION", None)
        else:
            asked = Path(directory) / "mutation.json"
            asked.write_text(json.dumps(mutation), encoding="utf-8")
            environment["METTA_EVIDENCE_MUTATION"] = str(asked)
        # unbounded: the self-test writes temporary trees and returns.
        return subprocess.run(
            [sys.executable, str(HERE / "check_evidence_selftest.py")],
            capture_output=True,
            text=True,
            check=False,
            env=environment,
        ).returncode


def main() -> int:
    """Take each rule away in turn, and report every one nothing noticed."""
    findings = []
    # The control first. Without it a self-test broken to fail on any tree
    # would report every mutation as caught, which is the shape of green this
    # whole file exists to distrust.
    if selftest(None) != 0:
        findings.append(
            "the unmutated self-test does not pass, so nothing below means anything"
        )
    for what, module, old, new in MUTATIONS:
        if old not in (HERE / module).read_text(encoding="utf-8"):
            findings.append(
                f"{module} no longer contains the text for {what!r}, so that rule's "
                f"plant is untested until this mutation follows it"
            )
            continue
        if selftest({"module": module, "old": old, "new": new}) == 0:
            findings.append(f"the self-test still passes without {what}")
    for finding in findings:
        print(finding)
    print(
        f"{len(findings)} unpinned rule(s), over {len(MUTATIONS)} mutations of the "
        f"evidence gate and one unmutated control"
    )
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
