"""Purpose: report where this engine and the arbiter disagree on generated programs.

Both engines run each program and the answers are compared.

The conformance lane replays a FIXED corpus, so it can only ever find what
upstream's 156 examples happen to write. This one generates programs the corpus
never contained, out of the same vocabulary the corpus proves upstream reduces,
and compares the two engines' answers on each. Differential testing on random
programs is CSmith's discipline; drawing them from a grammar rather than from
free text is Pałka, Claessen, Russo and Hughes, "Testing an optimising compiler
by generating random lambda terms", AST 2011; and the shrinking is Hypothesis's,
which is why a finding arrives as the smallest program that still shows it.

The arbiter is upstream PeTTa at the pinned commit, and it is the ARBITER, not a
peer. A program it leaves unreduced is outside the surface it reduces at that
pin, and this records the miss against the census and moves on rather than
calling it a divergence: `!(unify $x c a no)` answers itself there and answers
`a` here, and that is this tree having more, not upstream being wrong.

REPORT, not GATE. It generates fresh programs, so what it finds moves run to
run, and a lane that blocks a push on a newly drawn program blocks it on the
draw rather than on the change. A finding is a Markdown file carrying the
divergence issue template's own fields, ready to be filed.

Assumes:
  - a checkout with the sibling upstream at tests/checks/check_upstream_parity's
    UPSTREAM, which is where its CI-refuses, local-skips rule comes from too.
  - tests/conformance/petta/HEADS.json was taken from that same commit; when it
    was not, the run says so, because the surface it draws from is that
    commit's.
  - hypothesis is installed, which the Python seat's test extra provides.
Guarantees:
  - a program the arbiter leaves unreduced, raises on, or does not finish is
    recorded and skipped, never reported as a divergence
    [tested: sh check.sh parity-fuzz-selftest; commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce]
  - a real disagreement is shrunk before it is written down, so the report
    carries the smallest program of the strategy's own language that still
    shows it [tested: sh check.sh parity-fuzz-selftest; commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce]
  - one run finds more than one KIND of disagreement: a divergence's signature
    is suppressed and the search re-entered, and the memo makes the programs
    already run free, so the whole run still costs N programs per engine
    [tested: sh check.sh parity-fuzz-selftest; commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce]
  - every engine run is a fresh bounded process in a session of its own, so a
    program that hangs cannot poison the next one and cannot outlive this
    script [tested: sh check.sh process-bounds; commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce]
Fails when:
  - the upstream checkout is absent: a refusal where CI=true and a printed skip
    elsewhere, the rule the parity lane draws and this one calls.
  - a divergence was found. The exit status is what puts the finding in the
    gate's summary line; the REPORT tier is what keeps it from blocking.
Owns resources:
  - one directory per run under ai-tmp/parity-fuzz/, holding every program it
    generated, the surface misses, and one report per divergence. Nothing is
    removed: the programs ARE the run's evidence.
Decides:
  - what a run REPORTS is stable and what it COUNTS is indicative. Two runs at
    seed 0 wrote the same four findings under the same four names and shared
    177 of their 200 programs, with the per-class counts moving by up to three
    [measured 2026-09-07; command=tests/checks/check_upstream_fuzz.py -n 200
    --seed 0 --report <fresh>, twice; fixture=tests/conformance/petta/HEADS.json;
    commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce]. Which programs fill the budget after the findings are
    located is not fully determined by the seed, and that is not root-caused.
  - 20 seconds is a program's ceiling on either engine, and a program that
    reaches it is recorded as a timeout rather than shrunk. Shrinking over a
    timeout costs the ceiling per attempt, which is the whole budget for a
    finding that says only that something was slow.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
from datetime import datetime
from difflib import SequenceMatcher
from pathlib import Path
from typing import NamedTuple

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
for reachable in (HERE, REPO / "tests" / "conformance", REPO / "extensions" / "python"):
    if str(reachable) not in sys.path:
        sys.path.insert(0, str(reachable))

import check_upstream_parity as parity  # noqa: E402  -- the paths are installed above
import petta  # noqa: E402  -- the alpha renaming the conformance lane compares with
import petta_capture  # noqa: E402  -- the engine invocation and the error shapes

#: Where a run keeps its programs and its findings. One directory per run,
#: created on demand.
REPORTS = REPO / "ai-tmp" / "parity-fuzz"  # artifact-path-created

#: The census the strategy draws from, and the commit it was taken at.
CENSUS = REPO / "tests" / "conformance" / "petta" / "HEADS.json"

#: A program's ceiling on ONE engine. Upstream answers a generated program in
#: 0.08 s and this engine in 0.20 s [measured 2026-09-07, min of three on a box
#: at load 52; command=/usr/bin/time -f %e sh bounded.sh swipl ... silent;
#: fixture=a ten-query program; commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce], so twenty seconds is two
#: orders of magnitude of headroom and reaching it means a program does not
#: terminate rather than that the box is slow.
CEILING = 20

#: What a program can be, in the order the questions have to be asked. The
#: arbiter's own health comes first: a program it raised on or did not finish
#: has no oracle, and comparing against one is comparing against nothing.
AGREE = "agree"
SURFACE_MISS = "unreduced-on-arbiter"
ARBITER_ERROR = "arbiter-error"
TIMEOUT = "timeout"
ERROR_ON_ONE = "error-on-one"
ANSWER_MISMATCH = "answer-mismatch"
CLASSES = (AGREE, SURFACE_MISS, ARBITER_ERROR, TIMEOUT, ERROR_ON_ONE, ANSWER_MISMATCH)
DIVERGENT = (ERROR_ON_ONE, ANSWER_MISMATCH)

#: What two findings have to share to be the same finding. Numbers, strings and
#: printed variable names are what the generator varies, so masking them groups
#: `(f 3)` answering 4 with `(f 5)` answering 6 and keeps the rounds looking for
#: a different disagreement rather than for another draw of the same one.
NOISE = re.compile(r"-?\d+(?:\.\d+)?|\"[^\"]*\"|\$[A-Za-z_0-9]+")

#: The blob hypothesis prints for a failing example, which is what puts the
#: exact draw back in a test file
#: [source: https://hypothesis.readthedocs.io/en/latest/reference/api.html#settings].
BLOB = re.compile(r"@reproduce_failure\([^)]*\)")


class Run(NamedTuple):
    """One engine's answer to one program."""

    rc: int | None
    out: str
    timed: bool


class Verdict(NamedTuple):
    """What one program showed, and what both engines printed for it."""

    kind: str
    source: str
    ours: Run
    theirs: Run
    path: Path


class DivergenceError(Exception):
    """Raised out of the property so hypothesis shrinks the program that showed it."""

    def __init__(self, verdict: Verdict) -> None:
        """Carry the classified program out of the property."""
        super().__init__(f"{verdict.kind} on a generated program")
        self.verdict = verdict
        #: The `@reproduce_failure(...)` line hypothesis prints for this draw,
        #: filled in by `survey` once shrinking has settled on a program.
        self.blob = ""


def engine_run(role: str, program: Path, timeout: int) -> Run:
    """One engine's run of one program, and the only place this starts a process.

    Both engines through `petta_capture.run`, so the arbiter's invocation is
    the one the corpus was captured with, character for character, and the
    seat flag is the single difference. The self-test replaces THIS function
    and nothing else, which is what keeps it testing the production classifier
    rather than a copy of it.
    """
    main_pl = (REPO / "engine" / "main.pl" if role == "ours"
               else parity.UPSTREAM / "src" / "main.pl")
    seat = "extensions" if role == "ours" else None
    return Run(*petta_capture.run(main_pl, program.parent, program.name, timeout, seat))


def queries(source: str) -> list[str]:
    """The query terms a generated program asks, as written."""
    return [line[1:].strip() for line in source.splitlines() if line.startswith("!")]


def records(text: str) -> list[str]:
    """The printed answers in `text`, each alpha-renamed on its own."""
    return [petta.alpha(line + "\n").strip() for line in text.splitlines() if line.strip()]


def classify(source: str, ours: Run, theirs: Run) -> str:
    """Which of the six a program is, asked in the order that keeps the oracle honest.

    The arbiter's own health decides first. Then the SURFACE: a printed answer
    that is still one of the queries means the arbiter did not reduce that head
    at this pin, so the program says nothing about where the two engines
    disagree and everything about where the census is too wide. Only then are
    the answers compared, and only up to the per-term variable renaming
    tests/conformance/petta.py already applies, because a printed `$_12345` is
    an allocation offset rather than a name.
    """
    if ours.timed or theirs.timed:
        return TIMEOUT
    if petta_capture.engine_error(theirs.rc, theirs.out):
        return ARBITER_ERROR
    asked = {petta.alpha(one + "\n").strip() for one in queries(source)}
    if asked.intersection(records(theirs.out)):
        return SURFACE_MISS
    if petta.alpha(ours.out) == petta.alpha(theirs.out) and ours.rc == theirs.rc:
        return AGREE
    if petta_capture.engine_error(ours.rc, ours.out):
        return ERROR_ON_ONE
    return ANSWER_MISMATCH


def shape(printed: str) -> str:
    """One printed answer reduced to what makes it that KIND of answer.

    A call becomes `head/arity`; anything else keeps its text with the numbers,
    strings and variable names masked out. This is what ALIGNS two answer sets
    in `signature` below, and `(and a a)`, `(and a b)` and `(and b a)` are one
    answer for that purpose: `and` left standing. A masked text keeps symbols,
    so the first real run reported those three as three separate findings
    [measured 2026-09-07: 4 reports over 164 programs at seed 0, of which 3
    were that one finding; command=tests/checks/check_upstream_fuzz.py -n 200
    --seed 0; fixture=tests/conformance/petta/HEADS.json; commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce].
    """
    read = petta_capture.forms(printed)
    if (len(read) == 1 and isinstance(read[0], list) and read[0]
            and isinstance(read[0][0], str)):
        return f"({read[0][0]}/{len(read[0]) - 1})"
    return NOISE.sub("#", printed)


def signature(verdict: Verdict) -> str:
    """What makes two divergences the same finding: the first EDIT between the answers.

    An edit rather than a comparison line by line, because ONE extra answer
    moves every answer after it. This engine leaves `and` standing where the
    arbiter answers nothing, and read by line that is a different finding for
    each query that FOLLOWS the `and`: line 1 differed against nothing, against
    `true` and against `(partial + ())` [measured 2026-09-07: 4 reports over
    172 programs by line and 2 by edit at the same seed;
    command=tests/checks/check_upstream_fuzz.py -n 200 --seed 0;
    fixture=tests/conformance/petta/HEADS.json; commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce].

    The arbiter is the `a` side, so an extra answer HERE is an insertion and a
    missing one is a deletion, which is the direction a reader of the report
    thinks in.
    """
    theirs, ours = records(verdict.theirs.out), records(verdict.ours.out)
    if theirs == ours:
        return f"{verdict.kind}: exit {verdict.theirs.rc} -> {verdict.ours.rc}"
    # SHAPES align the two answer sets and masked TEXT says what the difference
    # was, because neither alone is enough: aligning on text calls one extra
    # answer a new finding for every query after it, and reporting shapes alone
    # calls `(f 4)` against `(f 3)` and `(g true)` against `(g false)` the same
    # thing, both being one `(head/1)` against another.
    left, right = [shape(one) for one in theirs], [shape(one) for one in ours]
    for tag, start, end, mine, ends in SequenceMatcher(
        a=left, b=right, autojunk=False,
    ).get_opcodes():
        if tag == "equal":
            continue
        # An answer that APPEARED or VANISHED is identified by its kind: what
        # was found is that this engine emits an `(and/2)` the arbiter does
        # not. A REPLACE is two answers that lined up and are not the same, so
        # their masked text is what says which.
        if tag == "replace":
            return (f"{verdict.kind}: replace {[NOISE.sub('#', one) for one in theirs[start:end]]}"
                    f" -> {[NOISE.sub('#', one) for one in ours[mine:ends]]}")
        return f"{verdict.kind}: {tag} {left[start:end]} -> {right[mine:ends]}"
    for there, here in zip(theirs, ours, strict=False):
        if NOISE.sub("#", there) != NOISE.sub("#", here):
            return (f"{verdict.kind}: replace [{NOISE.sub('#', there)}]"
                    f" -> [{NOISE.sub('#', here)}]")
    # Every answer lines up and masks the same, so what differs IS a number, a
    # string or a variable name: `(f 3)` answering 4 here and 3 there, which is
    # one arithmetic disagreement however many draws it arrives in.
    return f"{verdict.kind}: values within {sorted(set(left))}"


def missed_heads(source: str, theirs: Run) -> list[str]:
    """The heads the arbiter left standing, which is what a surface miss names."""
    printed = set(records(theirs.out))
    out = []
    for one in queries(source):
        if petta.alpha(one + "\n").strip() in printed:
            token = one[1:].split(" ")[0].split(")")[0] if one.startswith("(") else one
            out.append(token)
    return sorted(set(out))


def write_program(work: Path, source: str) -> Path:
    """The program on disk, named by its own bytes so a redraw reuses the file."""
    work.mkdir(parents=True, exist_ok=True)
    path = work / f"p{hashlib.sha256(source.encode()).hexdigest()[:16]}.metta"
    if not path.exists():
        path.write_text(source, encoding="utf-8")
    return path


def report(verdict: Verdict, blob: str, arbiter: str, report_dir: Path) -> Path:
    """One finding, written with the fields .github/ISSUE_TEMPLATE/divergence.yml asks for.

    The template's own questions, in its own order, so filing the issue is a
    copy rather than a rewrite. `Which one you think is right` is the one field
    left to a person, because that is the question a differential cannot
    answer: this run knows the two engines disagree and not which of them the
    language meant.
    """
    ours_head = _describe(REPO)
    name = f"divergence-{verdict.kind}-{hashlib.sha256(signature(verdict).encode()).hexdigest()[:8]}.md"
    path = report_dir / name
    path.write_text(
        f"# Divergence: {verdict.kind}\n\n"
        f"**Which reference**: Upstream PeTTa on the same program\n\n"
        f"**Where in it**: `{arbiter}` via "
        f"`swipl --stack_limit=8g -q -s src/main.pl -- <file> silent`\n\n"
        f"**The MeTTa program** (`{verdict.path.name}`, shrunk):\n\n"
        f"```metta\n{verdict.source.rstrip()}\n```\n\n"
        f"**What the reference gives** (exit {verdict.theirs.rc}):\n\n"
        f"```\n{verdict.theirs.out.rstrip() or '<no output>'}\n```\n\n"
        f"**What this engine gives** (exit {verdict.ours.rc}):\n\n"
        f"```\n{verdict.ours.out.rstrip() or '<no output>'}\n```\n\n"
        f"**Which one you think is right, and why**: unanswered. A differential "
        f"says the two disagree, not which of them the language meant.\n\n"
        f"**Versions**: this engine at {ours_head} against upstream PeTTa at "
        f"{arbiter[:8]}\n\n"
        f"Reproduce the draw by adding `{blob or '<no blob printed>'}` to the "
        f"property, or run the program above on both engines.\n",
        encoding="utf-8",
    )
    return path


def shown(path: Path) -> str:
    """A path a reader can act on: repository-relative where it is under one.

    `--report` takes any directory, including a relative one and one outside
    this checkout, and `Path.relative_to` RAISES on both rather than answering
    the path unchanged.
    """
    resolved = path.resolve()
    return str(resolved.relative_to(REPO)) if resolved.is_relative_to(REPO) else str(resolved)


def _describe(root: Path) -> str:
    """This checkout's HEAD, or a word saying it could not be read."""
    # One call, in the one function that needs it, for the report's Versions field.
    import subprocess

    done = subprocess.run(["git", "-C", str(root), "rev-parse", "--short", "HEAD"],
                          capture_output=True, text=True, timeout=30, check=False)
    return done.stdout.strip() or "an unreadable checkout"


def strategy_for(census: dict):
    """The strategy this lane draws from, at the door's own defaults.

    One named function rather than a call buried in `main`, because it is the
    lane's second substitution point: the self-test plants a one-head census
    here the way it plants engines at `engine_run`, and everything between the
    two stays the production path.
    """
    # After the seat's path is installed at import time, above.
    from metta import testing

    return testing.programs(census=census)


def survey(strategy, *, number: int, seed: int, timeout: int, work: Path,
           store: Path, memo: dict[str, Verdict], order: list[str],
           suppressed: set[str], derandomize: bool) -> DivergenceError | None:
    """Draw programs, run both engines, and shrink the first unsuppressed divergence.

    The MEMO is what makes a second round nearly free. Generation is seeded, so
    a later round redraws the programs an earlier one already ran, and each of
    those costs a dictionary lookup rather than two engines. It is also the
    budget: `number` counts DISTINCT programs, so shrinking spends the same
    allowance generation does and the whole run stays inside the cost the lane
    advertises.
    """
    # Imported here rather than at module scope so the lane's refusals, and its
    # --help, work on a checkout where the test extra is not installed.
    from hypothesis import HealthCheck, given, settings
    from hypothesis import seed as with_seed
    from hypothesis.database import DirectoryBasedExampleDatabase

    # The database is what makes `Phase.reuse` mean anything: a failing draw is
    # stored and replayed FIRST on the next run, so a divergence keeps being
    # reported until it is fixed rather than waiting to be redrawn. It sits
    # above the per-run report directory for that reason; inside one it would
    # be written and never read again.
    #
    # derandomize=True implies database=None, which hypothesis refuses to be
    # given both of [source: hypothesis/_settings.py, "derandomize=True implies
    # database=None"], so the reuse half is the non-derandomised one.
    database = None if derandomize else DirectoryBasedExampleDatabase(store)

    @settings(max_examples=number, deadline=None, print_blob=True, database=database,
              derandomize=derandomize,
              suppress_health_check=[HealthCheck.too_slow, HealthCheck.data_too_large,
                                     HealthCheck.large_base_example,
                                     HealthCheck.filter_too_much])
    @with_seed(seed)
    @given(strategy)
    def compare(source: str) -> None:
        verdict = memo.get(source)
        if verdict is None:
            if len(memo) >= number:
                return
            path = write_program(work, source)
            verdict = Verdict(
                kind="", source=source, path=path,
                ours=engine_run("ours", path, timeout),
                theirs=engine_run("arbiter", path, timeout),
            )
            verdict = verdict._replace(kind=classify(source, verdict.ours, verdict.theirs))
            memo[source] = verdict
            order.append(source)
        if verdict.kind in DIVERGENT and signature(verdict) not in suppressed:
            raise DivergenceError(verdict)

    try:
        compare()
    except DivergenceError as found:
        # The blob arrives as a NOTE on the exception rather than on stdout:
        # hypothesis adds "You can reproduce this test case by temporarily
        # adding @reproduce_failure(...)" to __notes__ when print_blob is set,
        # so `hypothesis.reporting.with_reporter` captures nothing and the
        # notes are where to read
        # [tested: sh check.sh parity-fuzz-selftest, which requires the written
        # report to carry a blob; commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce].
        printed = BLOB.search("\n".join(getattr(found, "__notes__", [])))
        found.blob = printed.group(0) if printed else ""
        return found
    return None


def main(argv: list[str] | None = None) -> int:
    """Run the fuzz lane and print what it found."""
    ap = argparse.ArgumentParser(description="fuzz this engine against the arbiter")
    ap.add_argument("-n", "--number", type=int, default=200,
                    help="distinct programs to run on both engines")
    ap.add_argument("--seed", type=int, default=0,
                    help="the draw. The default is fixed so a finding is reproducible; "
                         "pass another to explore different ground")
    ap.add_argument("--rounds", type=int, default=4,
                    help="how many DISTINCT divergences one run may find. Each round "
                         "suppresses the signature the last one found and searches again")
    ap.add_argument("--timeout", type=int, default=CEILING)
    ap.add_argument("--report", type=Path, default=None,
                    help="where the programs and findings go "
                         "(default ai-tmp/parity-fuzz/<date>/)")
    args = ap.parse_args(argv)

    refusal = parity.upstream_prerequisite(
        remedy="`sh check.sh parity-fuzz` runs the comparison once it is there."
    )
    if refusal is not None:
        return refusal
    if not CENSUS.is_file():
        print(f"error: no head census at {shown(CENSUS)}; write one with\n"
              f"  python tests/conformance/petta_capture.py "
              f"--upstream {parity.UPSTREAM} --census", file=sys.stderr)
        return 1
    census = json.loads(CENSUS.read_text(encoding="utf-8"))
    arbiter = census["arbiter"]["commit"]
    head = parity.upstream_head()
    if head is not None and head != arbiter:
        print(f"note: the census was taken from {arbiter[:8]} and {parity.UPSTREAM} is at "
              f"{head[:8]}; the surface drawn from is the census's, not this checkout's.")

    report_dir = args.report or REPORTS / datetime.now().astimezone().strftime("%Y-%m-%d-%H%M%S")
    report_dir.mkdir(parents=True, exist_ok=True)
    work = report_dir / "programs"
    derandomize = os.environ.get("HYPOTHESIS_PROFILE") == "ci" or os.environ.get("CI") == "true"

    memo: dict[str, Verdict] = {}
    order: list[str] = []
    suppressed: set[str] = set()
    found: list[tuple[DivergenceError, Path]] = []
    strategy = strategy_for(census)
    for _ in range(args.rounds):
        divergence = survey(strategy, number=args.number, seed=args.seed,
                            timeout=args.timeout, work=work,
                            store=REPORTS / "hypothesis", memo=memo, order=order,
                            suppressed=suppressed, derandomize=derandomize)
        if divergence is None:
            break
        suppressed.add(signature(divergence.verdict))
        found.append((divergence,
                      report(divergence.verdict, divergence.blob, arbiter, report_dir)))

    misses = report_dir / "surface-misses.jsonl"
    with misses.open("a", encoding="utf-8") as handle:
        for source in order:
            verdict = memo[source]
            if verdict.kind == SURFACE_MISS:
                handle.write(json.dumps({
                    "heads": missed_heads(source, verdict.theirs),
                    "program": verdict.path.name,
                    "arbiter": arbiter,
                    "seen": datetime.now().astimezone().strftime("%Y-%m-%d"),
                }, sort_keys=True) + "\n")

    counts = {name: sum(1 for one in memo.values() if one.kind == name) for name in CLASSES}
    print(f"== fuzzing the arbiter, upstream {arbiter[:8]}, seed {args.seed}")
    print(f"programs run  : {len(memo)} of {args.number}")
    for name in CLASSES:
        print(f"{name:22}: {counts[name]}")
    heads: dict[str, int] = {}
    for source in order:
        if memo[source].kind == SURFACE_MISS:
            for one in missed_heads(source, memo[source].theirs):
                heads[one] = heads.get(one, 0) + 1
    if heads:
        print("surface misses by head: "
              + ", ".join(f"{name} ({count})" for name, count in
                          sorted(heads.items(), key=lambda kv: (-kv[1], kv[0]))))
    print(f"reports       : {shown(report_dir)}")
    for divergence, path in found:
        verdict = divergence.verdict
        print(f"\n--- {verdict.kind}  ({path.name})")
        print(verdict.source.rstrip())
        print(f"    arbiter : {verdict.theirs.out.strip()[:300]!r}")
        print(f"    ours    : {verdict.ours.out.strip()[:300]!r}")
    if found:
        print(f"\n{len(found)} divergence(s); each report carries the "
              f"divergence template's fields", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
