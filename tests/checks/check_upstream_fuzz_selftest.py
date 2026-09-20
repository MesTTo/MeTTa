"""Purpose: prove the fuzz lane tells its six outcomes apart and shrinks a real one.

Every plant passes through ``check_upstream_fuzz`` itself with only
``engine_run``, ``strategy_for`` and the sibling-checkout prerequisite
replaced, so the self-test and the production lane cannot drift into testing
different questions. The prerequisite is replaced because it belongs to the
LANE and not to this file: no engine here reads an upstream, and leaving the
real check in made the self-test depend on an optional clone sitting beside the
tree, present next to a working checkout and absent next to a battery.

No engine is started: ``engine_run`` is the single place that lane touches a
process, and a stand-in evaluator over the planted census's own language
exercises the whole classify, suppress, shrink and report path.

The questions are the ones a differential against an ARBITER has to get right:

- a disagreement is found, shrunk, and written down. The plant is an engine
  that answers 4 for ``(+ 1 2)`` and is otherwise correct, so exactly one
  disagreement exists and the program reported for it carries no facts, one
  query, and no line the disagreement does not need.
- an arbiter that prints the query term back has not reduced it, and the
  program says nothing about the two engines. Recorded as a surface miss and
  skipped, never reported.
- an arbiter that raises is not an oracle on that program. Recorded and
  skipped.
- the six classes are decided in an order that keeps the oracle's own health
  first, checked against strings both engines really printed.
- the strategy writes only heads the census records as reducing, and every
  equation body uses ``$x``.

Assumes: hypothesis is installed, and the committed census at
  tests/conformance/petta/HEADS.json, which the strategy half reads.
Guarantees:
  - an engine that answers one expression wrongly yields exactly one
    answer-mismatch, and the program reported for it carries no facts, one
    query, and no line that can be dropped with the disagreement surviving
    [tested: this file is its own gate; commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce]
  - an arbiter that prints the query term is classified as a surface miss and
    an arbiter that raises is classified as an arbiter error, and neither is
    reported as a divergence [tested: this file is its own gate; commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce]
  - the classifier answers each of the six on strings the two engines really
    printed, including a pair that differs only in printed variable identity
    [tested: this file is its own gate; commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce]
  - two divergences differing only in their numbers share one signature, which
    is what stops the rounds re-reporting one finding
    [tested: this file is its own gate; commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce]
  - the strategy writes only census heads and its own generated names, and
    every equation body uses `$x`
    [tested: this file is its own gate; commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce]
  - a report carries the divergence template's fields and the reproduction blob
    [tested: this file is its own gate; commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce]
Fails when: the lane stops exposing ``engine_run`` as its only process call, or
  stops deciding a program's class in ``classify``.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import contextlib
import io
import re
import shutil
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import check_upstream_fuzz as lane  # noqa: E402  -- the path is installed above
import petta_capture  # noqa: E402  -- reached through the lane's own path setup

#: A census with one head, so a planted engine can be a page of arithmetic
#: rather than a MeTTa implementation. Its shape is the real file's, taken from
#: tests/conformance/petta/HEADS.json's `+`/2 row.
PLANTED = {
    "arbiter": {"commit": "0" * 40,
                "remote": "https://example.invalid/planted",
                "invocation": "a planted engine"},
    "heads": {
        "+": {
            "uses": 9,
            "files": 9,
            "arities": {
                "2": {
                    "uses": 9,
                    "positions": [{"number": 9}, {"number": 9}],
                    "verdict": "reduces",
                    "result": "number",
                    "probe": "!(+ 1 1)",
                    "answer": "2",
                },
            },
        },
    },
}

#: A head the census records as NOT reducing. The strategy must never write it,
#: which is the difference between drawing from the census and drawing from the
#: file it lives in.
PLANTED_LEFT_STANDING = {
    "uses": 4, "files": 4,
    "arities": {"1": {"uses": 4, "positions": [{"number": 4}],
                      "verdict": "unreduced", "result": None,
                      "probe": "!(nope 1)", "answer": "(nope 1)"}},
}


def _evaluate(source: str, add) -> str:
    """A stand-in engine over the planted census's language: integers and `+`.

    Small enough to read in one sitting and complete for what the planted
    census can generate, which is what makes a substituted engine a test of the
    lane rather than a second implementation to get wrong.
    """
    equations: dict[str, list] = {}
    printed: list[str] = []
    for form in petta_capture.forms(source):
        if (isinstance(form, list) and len(form) == 3 and form[0] == "="
                and isinstance(form[1], list)):
            equations[form[1][0]] = form[2]

    def written(node) -> str:
        return f"({' '.join(written(one) for one in node)})" if isinstance(node, list) else node

    def value(node, bound):
        if isinstance(node, str):
            if node == "$x":
                return bound
            return int(node) if petta_capture.NUMBER.match(node) else node
        if not node:
            return written(node)
        if node[0] == "+" and len(node) == 3:
            left, right = value(node[1], bound), value(node[2], bound)
            if isinstance(left, int) and isinstance(right, int):
                return add(left, right)
            return written(node)
        if node[0] in equations and len(node) == 2:
            return value(equations[node[0]], value(node[1], bound))
        return written(node)

    for line in source.splitlines():
        if not line.startswith("!"):
            continue
        read = petta_capture.forms(line[1:])
        printed.append(str(value(read[0], None)) if read else "")
    return "".join(one + "\n" for one in printed)


def planted(role_outputs):
    """Run the lane with `role_outputs(role, source)` standing in for both engines."""

    @contextlib.contextmanager
    def swapped():
        original = lane.engine_run
        # The deadline is the production runner's; a planted engine answers
        # from the program text alone and never waits.
        lane.engine_run = lambda role, program, _timeout: lane.Run(
            *role_outputs(role, program.read_text(encoding="utf-8"))
        )
        try:
            yield
        finally:
            lane.engine_run = original

    return swapped()


def _run(role_outputs, argv, *, facts=(0, 2), queries=(1, 2),
         census=None) -> tuple[int, dict[str, int], str, Path]:
    """One whole lane run against planted engines, with its output captured.

    Both substitution points at once: `engine_run` for what an engine answers
    and `strategy_for` for what is drawn, so the census under test is a
    one-head one and the shrunk program stays readable.
    """
    # The lane installs the seat's path when this file imports it.
    from metta import testing

    lane.REPORTS.mkdir(parents=True, exist_ok=True)
    where = Path(tempfile.mkdtemp(prefix="selftest-", dir=lane.REPORTS))
    original = lane.strategy_for
    lane.strategy_for = lambda _census: testing.programs(
        census=census or PLANTED, facts=facts, queries=queries)
    # The sibling checkout is the lane's prerequisite and NOT this file's: every
    # engine here is `_off_by_one`, ten lines of Python, so no upstream is ever
    # read. Leaving the real check in place made the selftest depend on an
    # optional clone that sits BESIDE the tree, which is present next to a
    # working checkout and absent next to a battery, where the parent directory
    # is a different one. The lane then skipped, wrote no report, and the first
    # case read that as the shrinker having found nothing
    # [measured 2026-09-20: status 125 and `upstream checkout not found`, in a
    # battery whose parent holds no PeTTa-upstream while the checkout's does].
    #
    # Replaced rather than worked around, the same way `engine_run` and
    # `strategy_for` are: what this file tests is the classifier and the
    # shrinker, and neither reads a sibling.
    original_present = lane.parity.upstream_present
    lane.parity.upstream_present = lambda: True
    buffer = io.StringIO()
    try:
        with planted(role_outputs), contextlib.redirect_stdout(buffer), \
                contextlib.redirect_stderr(buffer):
            status = lane.main(["--report", str(where), "--timeout", "1", *argv])
    finally:
        lane.strategy_for = original
        lane.parity.upstream_present = original_present
    printed = buffer.getvalue()
    return status, _counts(printed), printed, where


def _counts(printed: str) -> dict[str, int]:
    """The lane's own per-class counts, read back off what it printed."""
    out = {}
    for line in printed.splitlines():
        name, _, count = line.partition(":")
        if name.strip() in lane.CLASSES and count.strip().isdigit():
            out[name.strip()] = int(count.strip())
    return out


def _off_by_one(role, source):
    """Two engines that agree everywhere except that `ours` answers 4 for `(+ 1 2)`."""
    add = (lambda a, b: a + b + 1 if (a, b) == (1, 2) else a + b) if role == "ours" \
        else (lambda a, b: a + b)
    return 0, _evaluate(source, add), False


def _still_diverges(program: str) -> bool:
    """Whether the planted pair still disagrees on this program."""
    ours = lane.Run(*_off_by_one("ours", program))
    theirs = lane.Run(*_off_by_one("arbiter", program))
    return lane.classify(program, ours, theirs) in lane.DIVERGENT


def a_wrong_answer_is_shrunk_to_one_query() -> list[str]:
    """An engine that answers 4 for `(+ 1 2)` gives one finding, shrunk.

    MINIMAL is checked by removing lines rather than by counting them, which is
    the delta-debugging question and the one a reader of the report has: every
    line that is there has to be load-bearing, or the reader rules it out by
    hand. The design that settled this lane expected `!(+ 1 2)` alone; what the
    shrinker reaches is that equation and its query, two lines with no facts,
    each of which the disagreement needs.
    """
    outputs = _off_by_one

    status, counts, _, where = _run(outputs, ["-n", "150", "--seed", "0"])

    failures = []
    reports = sorted(where.glob("divergence-*.md"))
    if len(reports) != 1:
        failures.append(f"one wrong answer gave {len(reports)} report(s), not 1")
    if status == 0:
        failures.append("a divergence left the lane's exit status at 0")
    if not counts.get(lane.ANSWER_MISMATCH):
        failures.append(f"the wrong answer was not classified as an answer-mismatch: {counts}")
    if reports:
        body = reports[0].read_text(encoding="utf-8")
        program = body.split("```metta\n", 1)[-1].split("```", 1)[0].strip()
        lines = program.splitlines()
        if any(not line.startswith(("!", "(= ")) for line in lines):
            failures.append(f"the minimal program still carries a fact: {program!r}")
        if sum(1 for line in lines if line.startswith("!")) != 1:
            failures.append(f"the minimal program is not one query: {program!r}")
        if not _still_diverges(program + "\n"):
            failures.append(f"the reported program does not show the disagreement: {program!r}")
        for dropped in range(len(lines)):
            shorter = "\n".join(lines[:dropped] + lines[dropped + 1:]) + "\n"
            if _still_diverges(shorter):
                failures.append(
                    f"line {dropped + 1} is not load-bearing, so the program is not minimal: "
                    f"{lines[dropped]!r} in {program!r}")
        failures += [
            f"the report omits the divergence template's `{field}` field"
            for field in ("Which reference", "Where in it", "What the reference gives",
                          "What this engine gives", "Versions")
            if f"**{field}**" not in body
        ]
        if "@reproduce_failure(" not in body:
            failures.append("the report carries no reproduction blob")
    return failures


def an_unreduced_arbiter_is_a_surface_miss() -> list[str]:
    """An arbiter that prints the query back has not reduced it."""
    def outputs(role, source):
        if role == "arbiter":
            asked = [one + "\n" for one in lane.queries(source)]
            return 0, "".join(asked), False
        return 0, _evaluate(source, lambda a, b: a + b), False

    status, counts, printed, where = _run(outputs, ["-n", "12", "--seed", "0"])

    failures = []
    if sorted(where.glob("divergence-*.md")):
        failures.append("an unreduced arbiter was reported as a divergence")
    if status != 0:
        failures.append("an unreduced arbiter failed the lane instead of being recorded")
    if counts.get(lane.SURFACE_MISS) != sum(counts.values()):
        failures.append(f"not every program was recorded as a surface miss: {counts}")
    misses = (where / "surface-misses.jsonl").read_text(encoding="utf-8")
    if '"heads": ["+"]' not in misses and '"heads": ["f0"]' not in misses:
        failures.append(f"surface-misses.jsonl names no head:\n{misses}")
    return failures


def a_raising_arbiter_is_skipped() -> list[str]:
    """An arbiter with no answer is not an oracle, whatever this engine printed."""
    def outputs(role, source):
        if role == "arbiter":
            return 2, "ERROR: [Thread main] planted: the arbiter did not answer\n", False
        return 0, _evaluate(source, lambda a, b: a + b + 1), False

    status, counts, _, where = _run(outputs, ["-n", "12", "--seed", "0"])

    failures = []
    if sorted(where.glob("divergence-*.md")):
        failures.append("a raising arbiter was reported as a divergence")
    if status != 0:
        failures.append("a raising arbiter failed the lane instead of being recorded")
    if counts.get(lane.ARBITER_ERROR) != sum(counts.values()):
        failures.append(f"not every program was recorded as an arbiter error: {counts}")
    return failures


#: Strings both engines really printed, and what each pair has to be classified
#: as [measured 2026-09-07, one query per file over `(rel a b)`;
#: command=swipl --stack_limit=8g -q -s <main.pl> -- <file> silent;
#: commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce].
CAPTURED = (
    ("agreement", "!(f0 2)\n", (0, "3\n", False), (0, "3\n", False), lane.AGREE),
    ("a variable printed from another slot", "!(f0 2)\n",
     (0, "(pair $_7 $_7)\n", False), (0, "(pair $_1 $_1)\n", False), lane.AGREE),
    ("sharing that really differs", "!(f0 2)\n",
     (0, "(pair $_7 $_7)\n", False), (0, "(pair $_1 $_2)\n", False), lane.ANSWER_MISMATCH),
    ("the arbiter leaving a head standing", "!(unify $x c a no)\n",
     (0, "a\n", False), (0, "(unify $_0 c a no)\n", False), lane.SURFACE_MISS),
    #: BOTH engines leaving it, which is the pair that decides the ORDER of the
    #: surface question and the agreement question. They agree, so `agree` is
    #: not wrong about them; recording the miss is what narrows the census, and
    #: it costs nothing here because there is no divergence to hide. Without
    #: this row the two orders are indistinguishable and one of them is not a
    #: choice anybody made.
    ("both engines leaving one head standing", "!(unify $x c a no)\n",
     (0, "(unify $_0 c a no)\n", False), (0, "(unify $_0 c a no)\n", False),
     lane.SURFACE_MISS),
    ("the arbiter raising", "!(/ 1 0)\n",
     (0, "(Error (/ 1 0) DivisionByZero)\n", False),
     (2, "ERROR: [Thread main] Arithmetic: evaluation error: `zero_divisor'\n", False),
     lane.ARBITER_ERROR),
    ("this engine raising alone", "!(/ 1 0)\n",
     (0, "(Error (/ 1 0) DivisionByZero)\n", False), (0, "3\n", False), lane.ERROR_ON_ONE),
    ("a plain disagreement", "!(f0 2)\n",
     (0, "false\n", False), (0, "true\n", False), lane.ANSWER_MISMATCH),
    ("a run that did not finish", "!(f0 2)\n",
     (0, "", True), (0, "3\n", False), lane.TIMEOUT),
)


def the_classifier_answers_each_case() -> list[str]:
    """Each of the six, on strings the engines printed rather than on invented ones."""
    failures = []
    for name, source, ours, theirs, wanted in CAPTURED:
        answered = lane.classify(source, lane.Run(*ours), lane.Run(*theirs))
        if answered != wanted:
            failures.append(f"{name}: classified {answered}, wanted {wanted}")
    return failures


def one_finding_has_one_signature() -> list[str]:
    """Two draws of one disagreement group, and two disagreements do not."""
    def verdict(kind, ours, theirs):
        return lane.Verdict(kind=kind, source="!(f0 1)\n", path=Path("p.metta"),
                            ours=lane.Run(rc=0, out=ours, timed=False),
                            theirs=lane.Run(rc=0, out=theirs, timed=False))

    same = (lane.signature(verdict(lane.ANSWER_MISMATCH, "(f 4)\n", "(f 3)\n")),
            lane.signature(verdict(lane.ANSWER_MISMATCH, "(f 8)\n", "(f 7)\n")))
    #: The same head left standing over different SYMBOLS, which a masked-text
    #: signature reported as three findings on the first real run: `and` was
    #: left standing by this engine over `(a a)`, `(a b)` and `(b a)` and each
    #: got a report of its own [measured 2026-09-07; command=
    #: tests/checks/check_upstream_fuzz.py -n 200 --seed 0;
    #: fixture=tests/conformance/petta/HEADS.json; commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce].
    symbols = (lane.signature(verdict(lane.ANSWER_MISMATCH, "(and a a)\n", "")),
               lane.signature(verdict(lane.ANSWER_MISMATCH, "(and b a)\n", "")))
    #: The same extra answer with different queries after it, which a
    #: line-by-line signature reported as three findings on the first real run:
    #: an answer this engine adds moves every answer the arbiter printed after
    #: it, so line 1 differed against nothing, against `true` and against
    #: `(partial + ())` [measured 2026-09-07; command=
    #: tests/checks/check_upstream_fuzz.py -n 200 --seed 0;
    #: fixture=tests/conformance/petta/HEADS.json; commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce].
    shifted = (lane.signature(verdict(lane.ANSWER_MISMATCH, "(and a a)\ntrue\n", "true\n")),
               lane.signature(verdict(lane.ANSWER_MISMATCH,
                                      "(and a a)\n(partial + ())\n", "(partial + ())\n")))
    other = lane.signature(verdict(lane.ANSWER_MISMATCH, "(g true)\n", "(g false)\n"))
    arity = lane.signature(verdict(lane.ANSWER_MISMATCH, "(and a a a)\n", ""))
    failures = []
    if same[0] != same[1]:
        failures.append(f"two draws of one disagreement got two signatures: {same}")
    if symbols[0] != symbols[1]:
        failures.append(f"one head left standing over two symbols got two signatures: {symbols}")
    if len({*symbols, *shifted}) != 1:
        failures.append(
            f"one extra answer got a signature per query after it: {(*symbols, *shifted)}")
    if same[0] == other:
        failures.append("two different disagreements collapsed into one signature")
    if symbols[0] == arity:
        failures.append("one head at two arities collapsed into one signature")
    return failures


def the_strategy_stays_inside_the_census() -> list[str]:
    """Only heads the census records as reducing, and `$x` in every body.

    Every head in the tree, not only the outermost one, which is exact HERE and
    would not be against the real census: the planted one holds number
    positions alone, so the strategy writes no data lists and every bracket in
    a drawn program is a call. The seat's own
    tests/ch12_testing/test_program_strategy.py asks the outermost question of
    the committed census, where `(a c)` is a list rather than a call to `a`.
    """
    # Both imported here: the lane installs the seat's path when this file
    # imports it, and hypothesis is only needed by this one plant.
    from hypothesis import HealthCheck, Phase, given, settings

    from metta import testing

    census = {**PLANTED, "heads": {**PLANTED["heads"], "nope": PLANTED_LEFT_STANDING}}
    drawn: list[str] = []

    @settings(max_examples=40, phases=[Phase.generate], database=None, deadline=None,
              derandomize=True, suppress_health_check=list(HealthCheck))
    @given(testing.programs(census=census))
    def collect(source: str) -> None:
        drawn.append(source)

    collect()
    failures = []
    #: `=` is the definition form the strategy writes itself, and `relN` and
    #: `fN` are the names it mints. Everything else has to come from the census.
    minted = re.compile(r"^(?:rel|f)\d+$")
    for source in drawn:
        failures += [
            f"an equation body does not use $x: {line!r}"
            for line in source.splitlines()
            if line.startswith("(= ") and "$x" not in line.split(")", 1)[-1]
        ]
        failures += [
            f"the strategy wrote `{head}`, which the census does not record as reducing: "
            f"{source!r}"
            for form in petta_capture.forms(source)
            for head in _heads(form)
            if head not in {"=", "+"} and not minted.match(head)
        ]
    if not drawn:
        failures.append("the strategy drew nothing")
    return failures


def _heads(node) -> list[str]:
    """Every symbol in head position in one form."""
    if not isinstance(node, list) or not node:
        return []
    out = [node[0]] if isinstance(node[0], str) and petta_capture.kind(node[0]) == "symbol" else []
    for child in node:
        out += _heads(child)
    return out


CASES = (
    a_wrong_answer_is_shrunk_to_one_query,
    an_unreduced_arbiter_is_a_surface_miss,
    a_raising_arbiter_is_skipped,
    the_classifier_answers_each_case,
    one_finding_has_one_signature,
    the_strategy_stays_inside_the_census,
)


def main() -> int:
    """Run every plant in order and print what each answered."""
    failures: list[str] = []
    for case in CASES:
        found = case()
        print(f"{'FAIL' if found else 'ok  '}  {case.__name__}")
        for line in found:
            print(f"        {line}")
        failures += found
    for stale in lane.REPORTS.glob("selftest-*"):
        shutil.rmtree(stale, ignore_errors=True)
    if failures:
        print(f"\n{len(failures)} failure(s) in the fuzz lane's own checks", file=sys.stderr)
        return 1
    print(f"\n{len(CASES)} plants, all answered")
    return 0


if __name__ == "__main__":
    sys.exit(main())
