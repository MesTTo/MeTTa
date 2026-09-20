"""Purpose: vendor upstream PeTTa's example corpus and freeze the answers it
    prints, so tests/conformance/petta.py gates against an oracle THIS
    repository owns rather than against whatever a sibling checkout happens to
    contain today. Record mode; petta.py is verify mode.

    Upstream's specification is executable: `test.sh` runs each
    `examples/*.metta`, greps stdout for `is ... should ...` lines, fails on a
    `❌` and requires a `✅`. The corpus IS the spec, so it is copied here byte
    for byte and its stdout captured beside it, the way TC39's test262 is
    vendored by the engines that must satisfy it.

    `--census` is the second thing that corpus can say. Which heads the arbiter
    REDUCES is a fact about the arbiter, and the corpus is where it is written
    down, so the census reads every call head out of the vendored examples,
    keeps the ones no example defines and three or more write, and then asks
    the arbiter itself what each one does with kind-directed arguments. The
    answer lands in petta/HEADS.json and is what metta.testing.programs draws
    from, so a generated program is inside the arbiter's surface by
    construction rather than by hope.

Assumes:
  - an upstream PeTTa checkout is given with --upstream; its git HEAD is
    recorded in MANIFEST.json and a dirty worktree is refused, because a pin
    taken from uncommitted files names a state nobody can return to.
  - both engines accept the `silent` flag, so the captured bytes are the
    program's own answers rather than translator banners
    [source: upstream src/main.pl:3-13, engine/main.pl:54-57].
Guarantees:
  - every captured file is reproducible from the recorded commit: rerunning
    this against the same commit rewrites identical bytes, or the run is
    reported as nondeterministic and the file is ruled out of the corpus.
  - an input git does not TRACK cannot enter the artefact, so the commit the
    pin names contains every byte it froze
    [tested: test_an_untracked_corpus_input_is_refused; commit=819393cb9608052a198ef0b2a8c0676d9ef9e824]
  - a skip is DERIVED from a declared capability rather than listed by name,
    and carries that capability's own sentence, so the reason and the decision
    cannot disagree [tested: test_a_skip_is_derived_from_a_declared_capability;
    commit=819393cb9608052a198ef0b2a8c0676d9ef9e824]
  - a census head is drawable only where the ARBITER reduced it, decided by
    running it rather than by a list, and a head whose two runs disagree is
    recorded as nondeterministic instead
    [tested: sh tools/check.sh parity-fuzz-selftest; commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce]
Fails when:
  - asked to capture from a dirty or unresolvable checkout, or from one whose
    corpus holds an untracked file.
  - upstream itself prints a ❌ for a file: the oracle must be green before it
    can be an oracle, so that file is reported and left out.
  - `--census` is asked for and the vendored corpus is absent: the census is a
    reading of that corpus and cannot be taken without it.
Decides:
  - membership moves with the ENVIRONMENT, because that is what "derived"
    means: a box with torch captures the torch examples and one without skips
    them, and the manifest records which it was so a reader can tell. The
    verify side reports a recorded skip whose capability has since arrived
    rather than leaving it to be believed.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import itertools
import json
import os
import re
import signal
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

# The bound every runner in this tree reaches, one directory over.
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "checks"))
from bounded_spawn import CHILD_GRACE, bounded  # noqa: E402  -- the path is installed above

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
PIN = HERE / "petta"
CORPUS = PIN / "examples"
LIBDIR = PIN / "lib"
EXPECTED = PIN / "expected"
MANIFEST = PIN / "MANIFEST.json"

ANSI = re.compile(r"\x1b\[[0-9;]*m")

# What a corpus entry may need from the ENVIRONMENT, how each is decided, and
# what an entry needing it is without. Membership is DERIVED from this rather
# than from a list of names: a hand-kept skip carries a sentence nobody checks,
# and this one was wrong here on 2026-09-05, when torch.metta and
# torch_lib.metta were skipped for "needs torch installed" on a box where
# importlib.util.find_spec("torch") answers a module. The same lesson is
# recorded against the CeTTa generator's own capability table, which named 3
# cases where measurement names 28: deriving a classification by running the
# thing beats keeping a list by hand
# [source: ai-report-cetta-corpus-repin.md, "Its hand-kept capability table
# was incomplete and nothing checked it"].
#
# Deliberately NOT the engine's metta_platform_capability/3 census. That one
# answers whether this BUILD has library(process) or library(zlib), and says
# in its own comment that it is the PLATFORM's vocabulary and not the
# allow-a-space-to-do-it one [source: engine/metta.pl:570-581]. These are the
# environment's, which neither vocabulary covers.
#
# A capability is decided by a PROBE or by a stated repository RULING, never by
# prose. `network` is a ruling: this repository's gates do not reach the
# network, because a gate that does fails for reasons that are not the tree,
# which check.sh states where it refuses to provision [source: check.sh, the
# component build loop].
#
# lib_llm.metta constructs openai.OpenAI(), whose documented default is to read
# OPENAI_API_KEY from the environment, which is what `api-key` asks
# [source: the upstream arbiter's lib/lib_llm.metta:26].
CAPABILITIES: dict[str, tuple[bool, str]] = {
    "terminal": (sys.stdin.isatty(), "needs an interactive terminal"),
    "network": (False, "reaches the network, which this repository's gates do not"),
    "torch": (importlib.util.find_spec("torch") is not None, "needs torch installed"),
    "api-key": (
        bool(os.environ.get("OPENAI_API_KEY")),
        "needs an OpenAI API key in OPENAI_API_KEY",
    ),
}

# What each upstream example needs, which is the part a person writes down. The
# reason a skip carries is then BUILT from the capability rather than typed
# beside it, so the two cannot disagree.
REQUIREMENTS: dict[str, tuple[str, ...]] = {
    # readln!/1 is read_line_to_string/2, which answers end_of_file forever
    # once stdin is at EOF, so under a runner the command loop never ends
    # rather than running long [source: tests/data/example_skips.txt].
    "greedy_chess.metta": ("terminal",),
    "repl.metta": ("terminal",),
    "llm_cities.metta": ("network", "api-key"),
    "torch.metta": ("torch",),
    "torch_lib.metta": ("torch",),
    "git_import.metta": ("network",),
    "git_import2.metta": ("network",),
}


def skips() -> dict[str, str]:
    """The derived skip set: a name is out when something it needs is absent."""
    out: dict[str, str] = {}
    for name, wanted in sorted(REQUIREMENTS.items()):
        missing = [need for need in wanted if not CAPABILITIES[need][0]]
        if missing:
            out[name] = "; ".join(CAPABILITIES[need][1] for need in missing)
    return out


def capability_state() -> dict[str, bool]:
    """What each declared capability answered here, for the manifest to record."""
    return {name: present for name, (present, _) in sorted(CAPABILITIES.items())}


def tracked_examples(upstream: Path) -> frozenset[str]:
    """The example basenames git tracks, so a scratch file cannot become an oracle.

    A frozen artefact is pinned to a COMMIT, so every byte it copies has to be
    reachable from that commit or the pin names a state nobody can return to.
    upstream_commit's cleanliness check cannot answer this and must not try: it
    deliberately ignores `??` lines because an upstream checkout carries build
    output and editor files that have nothing to do with the corpus, and that
    same tolerance is the hole. CeTTa's generator recorded
    `git_state: untracked` for 21 such files and froze them anyway, so from
    2026-08-03 its differential compared against 21 files no PeTTa checkout has
    [source: ai-report-cetta-corpus-repin.md, "It froze 21 untracked scratch
    files into a shared artefact"]. Recording is not refusing.
    """
    listed = subprocess.run(
        ["git", "-C", str(upstream), "ls-files", "-z", "--", "examples", "lib"],
        capture_output=True, text=True, check=True,
    ).stdout
    return frozenset(name for name in listed.split("\0") if name)


def run(main_pl: Path, cwd: Path, rel: str, timeout: int,
        seat: str | None = None) -> tuple[int | None, str, bool]:
    """One engine run. start_new_session so a timeout kills swipl rather than
    orphaning it behind the shell, the shape
    extensions/python/tests/repository/test_example_parity.py already uses.

    `seat` is the extra flag this tree's own engine takes and upstream does
    not, so one function starts both engines and the fuzz lane cannot drift
    into a third copy of the invocation. The arbiter is always called without
    it, which is what keeps the captured bytes upstream's own.
    """
    proc = subprocess.Popen(
        # Bounded because start_new_session puts this engine in a session of
        # its own, out of reach of any group signal from above.
        bounded(["swipl", "--stack_limit=8g", "-q", "-s", str(main_pl),
                 "--", rel, "silent", *([seat] if seat else [])],
                ceiling=timeout + CHILD_GRACE),
        cwd=cwd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, text=True, start_new_session=True,
    )
    try:
        out, err = proc.communicate(timeout=timeout)
        timed = False
    except subprocess.TimeoutExpired:
        os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
        out, err = proc.communicate()
        timed = True
    return proc.returncode, ANSI.sub("", (out or "") + (err or "")), timed


def upstream_commit(upstream: Path) -> str:
    dirty = subprocess.run(["git", "-C", str(upstream), "status", "--porcelain"],
                           capture_output=True, text=True, check=True).stdout
    tracked = [ln for ln in dirty.splitlines() if not ln.startswith("??")]
    if tracked:
        sys.exit(f"petta_capture: {upstream} has uncommitted changes; a pin taken "
                 f"from them names a state nobody can return to:\n" + "\n".join(tracked))
    return subprocess.run(["git", "-C", str(upstream), "rev-parse", "HEAD"],
                          capture_output=True, text=True, check=True).stdout.strip()


def refuse_untracked(upstream: Path, wanted: list[str]) -> None:
    """Stop before an input git does not track enters the frozen artefact.

    Every path this copies is checked, not just the examples: the corpus keeps
    upstream's lib/ beside its examples/ and two examples import a sibling that
    is not a .metta file, so an untracked one of those is the same hole with a
    different extension.
    """
    tracked = tracked_examples(upstream)
    missing = sorted(name for name in wanted if name not in tracked)
    if not missing:
        return
    listed = "\n".join(f"  {name}" for name in missing)
    sys.exit(
        f"petta_capture: {len(missing)} corpus input(s) in {upstream} are not "
        f"tracked by git, so the commit this pin names does not contain them "
        f"and nobody can reproduce the capture:\n{listed}\n"
        f"Commit them upstream, or remove them from the checkout."
    )


# ----------------------------------------------------------------- census mode

#: Where the census lands: beside the corpus it is taken from, because it
#: describes THAT corpus at THAT pin. The arbiter's own examples are what say
#: which heads upstream reduces, so a census read from anywhere else would
#: describe a different surface.
HEADS = PIN / "HEADS.json"

#: Where a probe program is written. Repository-local scratch, the rule every
#: runner here follows, and created on demand.
CENSUS_WORK = ROOT / "ai-tmp" / "petta-census"  # artifact-path-created

#: How many distinct corpus files a head must appear in before it counts as
#: LANGUAGE rather than as one example's own vocabulary. Measured over the
#: vendored corpus on 2026-09-07: of 514 written call heads, 199 are defined by
#: the corpus itself and 316 never are; of those 316, 134 appear in two files or
#: more and 81 in three or more. Two admits a helper a pair of examples share;
#: three is where per-file names stop appearing
#: [measured 2026-09-07; command=tests/conformance/petta_capture.py --census;
#: fixture=tests/conformance/petta/examples, 156 files; commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce].
CENSUS_MIN_FILES = 3

#: The written values each argument kind is probed with. The probe walks the
#: cross product and keeps the first tuple the arbiter reduces, so a head whose
#: first position wants a space is not written off for having been handed a
#: number.
#:
#: `(+ 1 1)` is in the expression list because an `expression` position in this
#: corpus usually means a COMPUTATION rather than a term: `/` is written
#: `(/ $x <expr>)` throughout, an inert `(a b)` there raises, and the arbiter's
#: own division went into the census as an error until an evaluating expression
#: was among the values [measured 2026-09-07: of 100 (head, arity) pairs, 47
#: reduce with the inert values alone and 49 with this list, `/`/2 and `<=`/2
#: being the two; command=tests/conformance/petta_capture.py --census;
#: fixture=tests/conformance/petta/examples; commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce].
#:
#: `true` rather than `True` reads the way the corpus mostly writes it. It is
#: not load-bearing: the boolean spelling is canonicalised by the engine, and
#: same_call below sees through that, so the census is the same either way
#: [measured 2026-09-07: 49 pairs reduce with each spelling;
#: command=tests/conformance/petta_capture.py --census;
#: fixture=tests/conformance/petta/examples; commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce].
CENSUS_VALUES: dict[str, tuple[str, ...]] = {
    "number": ("1", "2"),
    "symbol": ("a", "true"),
    "string": ('"s"',),
    "expression": ("(a b)", "(rel a b)", "(+ 1 1)"),
    "variable": ("$x",),
    "space": ("&self",),
    "any": ("1", "a", "true", "(a b)"),
}

#: Heads a generated program must not call, because reducing one reaches
#: OUTSIDE the program: the two engines then differ for a reason that is not
#: semantics, on every program that draws the head. Each entry is a
#: MEASUREMENT, not a worry [measured 2026-09-07, one query per file over
#: `(rel a b)`, arbiter then this engine;
#: command=swipl --stack_limit=8g -q -s <main.pl> -- <file> silent;
#: commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce]. Only what derivation cannot reach is here: `library`
#: answers a path inside the engine that ran it and the derived net below sees
#: that in the answer, so it is not in this table and the net is what rules it
#: out; these three say nothing a reader of one answer could tell.
CENSUS_WORLD: dict[str, str] = {
    "import!": "loads a file, so it answers each checkout's own module tree: "
               "`!(import! &self 1)` answers nothing upstream and raises here",
    "|->": "answers a gensym from an engine-internal counter, `lambda_1` "
           "upstream against `lambda_2` here for the same one-line program",
    "add-translator-rule!": "rewrites the translator, so it changes how the "
                            "rest of the program is READ rather than answering",
}

#: How many argument tuples one (head, arity) is probed with before it is
#: recorded as unreduced. It bounds the tail rather than deciding the answer,
#: since the tuples are walked most-typical first, but the tail is where two
#: heads sat, `/`/2 and `<=`/2 [measured 2026-09-07: of 100 (head, arity)
#: pairs, 47 reduce at a cap of 12, 49 at 24 and 49 at 40;
#: command=tests/conformance/petta_capture.py --census;
#: fixture=tests/conformance/petta/examples; commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce]. At the measured
#: 0.08 s per arbiter run this is under two seconds for one head.
CENSUS_TUPLES = 24

#: The fact every probe program carries, so a head that reads the space has
#: something to find and `match` is decided on a hit rather than on a miss.
CENSUS_PRELUDE = "(rel a b)\n"

#: The recorded stand-in for the arbiter's own directory. An engine names its
#: own path in an error and in `library`'s answer, so a census that stored the
#: bytes would be one box's census: it would differ between two checkouts of
#: the same commit and could not be committed
#: [tested: sh extensions/python/test.sh tests/repository/test_workspace_paths.py;
#: commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce].
CENSUS_ROOT = "<arbiter>"

#: SWI's own error prefix, which is how an engine says it raised rather than
#: answered. Only `ERROR:`, not `Warning:`: a warning with a zero exit is text
#: the comparison can read like any other, and treating it as a refusal would
#: throw away the program instead of reporting the difference.
ENGINE_ERROR = re.compile(r"^ERROR:", re.MULTILINE)

#: What the reader accepts as a number, spelled positively rather than by
#: asking float() to decide: float() answers for `inf` and `nan`, which are
#: symbols here, and a census that called them numbers would generate
#: arithmetic over them.
NUMBER = re.compile(r"^[+-]?(?:\d+\.?\d*(?:[eE][+-]?\d+)?|\.\d+(?:[eE][+-]?\d+)?)$")


def engine_error(rc: int | None, out: str) -> bool:
    """Whether an engine run reported an error rather than answering.

    Two shapes, because the engines choose differently: upstream raises out of
    its command loop, printing SWI's own `ERROR:` line and exiting nonzero,
    while this tree answers an `(Error ...)` atom and exits 0 [measured
    2026-09-07: `!(/ 1 0)` gives upstream
    `ERROR: [Thread main] ... Arithmetic: evaluation error: 'zero_divisor'` at
    exit 2, and this engine `(Error (/ 1 0) DivisionByZero)` at exit 0;
    commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce].
    """
    return rc != 0 or bool(ENGINE_ERROR.search(out)) or "(Error " in out


def forms(text: str) -> list:
    """Every top-level form in MeTTa source, as nested lists of token strings.

    Enough of the reader to count what a corpus writes: `;` runs to end of
    line, a double-quoted string is one token with `\\` escaping, and `(`, `)`
    and `;` end a token, which is the boundary the engine draws [source:
    engine/parser.pl:27-34, metta_token_boundary/2]. Unbalanced text answers
    with what closed, because a census over 156 files must not stop at one of
    them.
    """
    index, length = 0, len(text)
    stack: list[list] = []
    out: list = []
    while index < length:
        character = text[index]
        if character == ";":
            while index < length and text[index] != "\n":
                index += 1
            continue
        if character.isspace():
            index += 1
            continue
        if character == "(":
            stack.append([])
            index += 1
            continue
        if character == ")":
            index += 1
            if not stack:
                continue
            closed = stack.pop()
            (stack[-1] if stack else out).append(closed)
            continue
        if character == '"':
            end = index + 1
            while end < length and text[end] != '"':
                end += 2 if text[end] == "\\" else 1
            token, index = text[index : min(end + 1, length)], end + 1
        else:
            end = index
            while end < length and not text[end].isspace() and text[end] not in "();":
                end += 1
            token, index = text[index:end], end
        (stack[-1] if stack else out).append(token)
    return out


def kind(node: list | str) -> str:
    """Which of the census's kinds a written argument belongs to.

    Seven rather than the six a term carries, because a SPACE is not a symbol:
    `match`'s first position is `&self` and a generator handed an ordinary
    symbol there produces a program neither engine reduces, which would have
    cost the census its most-used three-argument head.
    """
    if isinstance(node, list):
        return "expression"
    if node.startswith("$"):
        return "variable"
    if node.startswith("&"):
        return "space"
    if node.startswith('"'):
        return "string"
    return "number" if NUMBER.match(node) else "symbol"


def corpus_census(corpus: Path) -> dict:
    """What the corpus writes: per head, its arities and each position's kinds.

    A head is a SYMBOL in head position. `(1 2 3)` is data and its head is a
    number, so counting it would put `1` in the census with seven arities,
    which is what a first pass did [measured 2026-09-07;
    command=tests/conformance/petta_capture.py --census;
    fixture=tests/conformance/petta/examples; commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce].
    """
    uses: dict[str, int] = {}
    where: dict[str, set[str]] = {}
    positions: dict[tuple[str, int, int], dict[str, int]] = {}
    arity_uses: dict[tuple[str, int], int] = {}
    defined: set[str] = set()
    sites = 0
    files = sorted(corpus.glob("*.metta"))

    def visit(node: list | str, name: str) -> None:
        nonlocal sites
        if not isinstance(node, list) or not node:
            return
        head, arguments = node[0], node[1:]
        if (isinstance(head, str) and head == "=" and node[1:]
                and isinstance(node[1], list) and node[1]
                and isinstance(node[1][0], str)):
            defined.add(node[1][0])
        if isinstance(head, str) and kind(head) == "symbol":
            sites += 1
            uses[head] = uses.get(head, 0) + 1
            where.setdefault(head, set()).add(name)
            arity_uses[(head, len(arguments))] = arity_uses.get((head, len(arguments)), 0) + 1
            for index, argument in enumerate(arguments):
                seen = positions.setdefault((head, len(arguments), index), {})
                written = kind(argument)
                seen[written] = seen.get(written, 0) + 1
        for child in node:
            visit(child, name)

    for path in files:
        for form in forms(path.read_text(encoding="utf-8", errors="replace")):
            visit(form, path.name)

    heads = {}
    for head in sorted(uses):
        arities = {}
        for (name, arity), count in sorted(arity_uses.items()):
            if name != head:
                continue
            arities[str(arity)] = {
                "uses": count,
                # Every kind the corpus wrote at this position and HOW OFTEN,
                # not the one name a collapse would leave. A position that saw
                # more than one kind is the census's `any`, and spelling it out
                # is what lets the probe and the generator draw what the corpus
                # actually writes there: a collapsed `any` had the probe hand
                # `match`'s space position a number, and the arbiter's
                # most-used three-argument head went into the census as
                # answering nothing. The COUNTS are here for the same reason
                # one step further on: with the kinds unordered the probe met
                # `!(+ (a b) (a b))` before `!(+ 1 1)` [measured 2026-09-07:
                # of 100 (head, arity) pairs, 48 reduce with the kinds sorted
                # by name and 49 by descending use;
                # command=tests/conformance/petta_capture.py --census;
                # fixture=tests/conformance/petta/examples; commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce].
                "positions": [positions[(head, arity, index)] for index in range(arity)],
            }
        heads[head] = {"uses": uses[head], "files": len(where[head]), "arities": arities}
    return {
        "files": len(files),
        "call_sites": sites,
        "distinct_heads": len(heads),
        "defined_in_corpus": sorted(defined),
        "heads": heads,
    }


def position_kinds(seen: dict[str, int]) -> list[str]:
    """The kinds one position saw, most written first, ties broken by name."""
    return sorted(seen, key=lambda name: (-seen[name], name)) or ["any"]


def probe_arguments(positions: list[dict[str, int]]) -> list[tuple[str, ...]]:
    """The argument tuples one (head, arity) is probed with, most typical first.

    A position offers every value of every kind the corpus wrote there, in
    descending order of how often it wrote each, so `+` is tried with numbers
    before expressions and `match` with a space rather than with a number.
    """
    values = [
        tuple(value for one in position_kinds(seen) for value in CENSUS_VALUES.get(one, ()))
        or CENSUS_VALUES["any"]
        for seen in positions
    ]
    # islice over a lazy product, not a list of one: the corpus writes a
    # 29-argument `,`, and five values per position there is 5^29 tuples.
    #
    # Moving VARIABLES to the back of each position was tried, on the reading
    # that a probe is a closed query where `$x` is unbound while the corpus
    # writes `(+ $x 1)` inside an equation where it is not. It changed no
    # verdict at any cap, so the order stays the corpus's own [measured
    # 2026-09-07: 49 (head, arity) pairs reduce either way, and the same four
    # raise; command=tests/conformance/petta_capture.py --census;
    # fixture=tests/conformance/petta/examples; commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce].
    return list(itertools.islice(itertools.product(*values), CENSUS_TUPLES))


#: The two symbols whose written spelling the engine canonicalises, so a head
#: comparison has to see through it: `!(True a)` answers `(true a)`
#: [source: metta.testing.names, "true/false ARE the boolean atoms so their
#: symbol spellings canonicalize"].
CANONICAL = {"True": "true", "False": "false"}


def same_call(answer: list | str, query: list | str) -> bool:
    """Whether an answer is still the query's own call: same head, same arity.

    The comparison the census wants is about the HEAD, not about the text. A
    text comparison says "reduced" whenever any ARGUMENT evaluated, and a probe
    argument has to be allowed to evaluate: `/` is written `(/ $x <expr>)`
    throughout the corpus, so probing it with an inert `(a b)` raises and the
    arbiter's own division read as an error. Handing it `(+ 1 1)` fixes that
    and breaks the text test, which then reads `!(a (+ 1 1))` answering
    `(a 2)` as `a` having reduced [measured 2026-09-07: of 100 (head, arity)
    pairs the text test calls 79 reducing and this one 49, the 30 being data
    constructors the corpus writes and the arbiter leaves alone;
    command=tests/conformance/petta_capture.py --census;
    fixture=tests/conformance/petta/examples; commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce].
    """
    if not (isinstance(answer, list) and isinstance(query, list)):
        return False
    if not answer or len(answer) != len(query):
        return False
    head, wanted = answer[0], query[0]
    if not (isinstance(head, str) and isinstance(wanted, str)):
        return False
    return CANONICAL.get(head, head) == CANONICAL.get(wanted, wanted)


def probe_verdict(query: str, rc: int | None, out: str,
                  timed: bool) -> tuple[str, str | None]:
    """What the arbiter did with one probe: reduce it, leave it, raise, or hang.

    A head outside the arbiter's surface answers with its own call: `!(unify $x
    c a no)` answers `(unify $_0 c a no)` at the pin, and `!(nosuchhead 1 2)`
    answers `(nosuchhead 1 2)` [measured 2026-09-07;
    command=swipl --stack_limit=8g -q -s src/main.pl -- p.metta silent;
    fixture=a one-query program over `(rel a b)`; commit=5e53dfba208acc69c1eb8a5f2e8aa90c9864a5ce].
    """
    if timed:
        return "timeout", None
    if engine_error(rc, out):
        return "error", None
    answers = [line for line in out.splitlines() if line.strip()]
    if not answers:
        return "reduces", None
    read = forms(answers[0]) if len(answers) == 1 else []
    asked = forms(query)
    if len(read) != 1:
        return "reduces", None
    if len(asked) == 1 and same_call(read[0], asked[0]):
        return "unreduced", None
    return "reduces", kind(read[0])


def probe_head(main_pl: Path, work: Path, head: str, arity: str, entry: dict,
               timeout: int) -> dict:
    """Ask the arbiter what this head does, and whether it answers the same twice.

    The first tuple that reduces is kept and RE-RUN, the rule the capture side
    already applies to the corpus: a head whose two runs disagree has no single
    answer and cannot be a generator's building block.
    """
    if head in CENSUS_WORLD:
        return {**entry, "verdict": "world", "result": None,
                "probe": None, "answer": CENSUS_WORLD[head]}
    root = str(main_pl.parents[1])
    name = f"h{hashlib.sha256(f'{head}/{arity}'.encode()).hexdigest()[:16]}.metta"
    last: tuple[str, str, str | None, str] = ("unreduced", "", None, "")
    for values in probe_arguments(entry["positions"]):
        query = f"({head}{''.join(' ' + one for one in values)})"
        (work / name).write_text(f"{CENSUS_PRELUDE}!{query}\n")
        rc, out, timed = run(main_pl, work, name, timeout)
        out = out.replace(root, CENSUS_ROOT)
        verdict, result = probe_verdict(query, rc, out, timed)
        last = (verdict, query, result, out.strip())
        if verdict == "reduces":
            # The derived half of the world rule: an answer that names the
            # engine's own directory is that engine's, not the language's, and
            # the two checkouts sit at different paths. `library` is caught
            # here rather than declared, which is what keeps the next head of
            # its shape from needing an edit.
            if CENSUS_ROOT in out:
                last = ("world", query, None,
                        "answers a path inside the engine that ran it")
                break
            rc, again, timed = run(main_pl, work, name, timeout)
            again = again.replace(root, CENSUS_ROOT)
            if timed or again.strip() != out.strip():
                last = ("nondeterministic", query, None, out.strip())
            break
    verdict, query, result, answer = last
    return {**entry, "verdict": verdict, "result": result,
            "probe": f"!{query}" if query else None, "answer": answer}


def build_census(upstream: Path, timeout: int, jobs: int) -> dict:
    """The corpus census, with every candidate head decided by the arbiter itself.

    A head is a CANDIDATE when the corpus never defines it and at least
    CENSUS_MIN_FILES files write it, which leaves the vocabulary rather than
    any one example's names. What that vocabulary MEANS is then measured rather
    than declared: each candidate is run on the arbiter and recorded as
    reducing, left unreduced, raising, hanging, or answering differently twice.
    Only the reducing ones are the surface a generator may draw from, and the
    rest stay in the file with their verdict so the exclusion is readable.
    """
    written = corpus_census(CORPUS)
    defined = set(written["defined_in_corpus"])
    candidates, excluded = {}, {}
    for head, entry in written["heads"].items():
        if head in defined:
            excluded[head] = "the corpus defines it, so it is an example's own name"
        elif entry["files"] < CENSUS_MIN_FILES:
            excluded[head] = (
                f"written in {entry['files']} corpus file(s), below the {CENSUS_MIN_FILES} "
                f"that separate vocabulary from one example's names"
            )
        else:
            candidates[head] = entry

    CENSUS_WORK.mkdir(parents=True, exist_ok=True)
    main_pl = upstream / "src" / "main.pl"
    work = [(head, arity, entry["arities"][arity])
            for head, entry in sorted(candidates.items())
            for arity in sorted(entry["arities"], key=int)]
    print(f"probing {len(work)} (head, arity) pairs on the arbiter", flush=True)
    with ThreadPoolExecutor(max_workers=jobs) as pool:
        probed = list(pool.map(
            lambda item: (item[0], item[1],
                          probe_head(main_pl, CENSUS_WORK, item[0], item[1], item[2],
                                     timeout)),
            work,
        ))

    heads: dict[str, dict] = {}
    counts: dict[str, int] = {}
    for head, arity, answer in probed:
        counts[answer["verdict"]] = counts.get(answer["verdict"], 0) + 1
        entry = heads.setdefault(head, {"uses": candidates[head]["uses"],
                                        "files": candidates[head]["files"],
                                        "arities": {}})
        entry["arities"][arity] = answer
    return {
        "arbiter": {
            "commit": upstream_commit(upstream),
            "remote": "https://github.com/trueagi-io/PeTTa.git",
            "invocation": "swipl --stack_limit=8g -q -s src/main.pl -- <file> silent",
        },
        "corpus": {
            "path": str(CORPUS.relative_to(ROOT)),
            "files": written["files"],
            "call_sites": written["call_sites"],
            "distinct_heads": written["distinct_heads"],
            "defined_in_corpus": len(defined),
        },
        "policy": {
            "min_files": CENSUS_MIN_FILES,
            "probe_tuples": CENSUS_TUPLES,
            "prelude": CENSUS_PRELUDE.strip(),
            "values": {name: list(values) for name, values in sorted(CENSUS_VALUES.items())},
        },
        "counts": {"candidates": len(candidates), **dict(sorted(counts.items()))},
        "heads": dict(sorted(heads.items())),
        "excluded": dict(sorted(excluded.items())),
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--upstream", required=True, type=Path,
                    help="a clean upstream PeTTa checkout to capture from")
    ap.add_argument("--census", action="store_true",
                    help="write the head census the fuzz strategy draws from, "
                         "taken from the vendored corpus and decided by the arbiter, "
                         "instead of capturing the corpus")
    ap.add_argument("--timeout", type=int, default=90)
    ap.add_argument("--jobs", type=int, default=4)
    args = ap.parse_args()

    upstream = args.upstream.resolve()
    main_pl = upstream / "src" / "main.pl"
    if not main_pl.exists():
        sys.exit(f"petta_capture: {main_pl} does not exist")

    if args.census:
        if not CORPUS.is_dir():
            sys.exit(f"petta_capture: no vendored corpus at {CORPUS}, and the census "
                     f"is a reading of it. Capture one first, without --census.")
        # A probe is one query over one fact, so the corpus timeout is the wrong
        # bound entirely: a head that has not answered in 20 seconds has hung.
        census = build_census(upstream, min(args.timeout, 20), args.jobs)
        HEADS.write_text(json.dumps(census, indent=1, sort_keys=True) + "\n")
        print(f"census written: {HEADS.relative_to(ROOT)}")
        print(f"corpus  : {census['corpus']['files']} files, "
              f"{census['corpus']['call_sites']} call sites, "
              f"{census['corpus']['distinct_heads']} distinct heads")
        for name, count in census["counts"].items():
            print(f"    {name}: {count}")
        return 0

    commit = upstream_commit(upstream)

    excluded_by_capability = skips()
    names = sorted(p.name for p in (upstream / "examples").glob("*.metta")
                   if p.name not in excluded_by_capability)
    # Everything this copies, checked against git before the first engine runs.
    refuse_untracked(
        upstream,
        [f"examples/{name}" for name in names]
        + [f"examples/{name}" for name in ("prologimport_example.pl", "python_import_file.py")
           if (upstream / "examples" / name).exists()]
        + [f"lib/{support.name}" for support in (upstream / "lib").iterdir()
           if support.is_file()],
    )
    print(f"capturing {len(names)} examples from {upstream} @ {commit[:8]}", flush=True)
    for capability, present in sorted(capability_state().items()):
        print(f"  capability {capability}: {'present' if present else 'absent'}")

    def capture(name: str) -> dict:
        rel = f"examples/{name}"
        rc, out, timed = run(main_pl, upstream, rel, args.timeout)
        rc2, out2, timed2 = run(main_pl, upstream, rel, args.timeout)
        return {"name": name, "rc": rc, "out": out, "timeout": timed,
                "stable": (rc, out, timed) == (rc2, out2, timed2)}

    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        results = list(pool.map(capture, names))

    # The corpus keeps upstream's examples/ + lib/ SIBLING layout, because 41 of
    # these examples import by relative path (`../lib/lib_he`), which resolves
    # against the importing FILE's directory. `(library X)` is the other form
    # and resolves against the ENGINE's own directory (engine/metta.pl:373), so
    # that half still reaches this tree's libraries: path imports name the same
    # bytes on both sides, library imports name each engine's own, and that is
    # exactly the as-shipped comparison this lane wants.
    CORPUS.mkdir(parents=True, exist_ok=True)
    EXPECTED.mkdir(parents=True, exist_ok=True)
    LIBDIR.mkdir(parents=True, exist_ok=True)
    for stale in (list(CORPUS.glob("*")) + list(EXPECTED.glob("*.out"))
                  + list(LIBDIR.glob("*"))):
        if stale.is_file():
            stale.unlink()
    for support in (upstream / "lib").iterdir():
        if support.is_file():
            (LIBDIR / support.name).write_bytes(support.read_bytes())
    # Two examples import a sibling that is not a .metta file.
    for support in ("prologimport_example.pl", "python_import_file.py"):
        src = upstream / "examples" / support
        if src.exists():
            (CORPUS / support).write_bytes(src.read_bytes())

    entries, excluded = {}, {}
    for r in results:
        if r["timeout"]:
            excluded[r["name"]] = "upstream itself did not finish within the timeout"
        elif not r["stable"]:
            excluded[r["name"]] = "upstream's own output is not reproducible run to run"
        elif "❌" in r["out"]:
            excluded[r["name"]] = "upstream itself fails this example, so it cannot be an oracle"
        else:
            (CORPUS / r["name"]).write_bytes((upstream / "examples" / r["name"]).read_bytes())
            (EXPECTED / f"{r['name']}.out").write_text(r["out"])
            entries[r["name"]] = {"rc": r["rc"], "status": "conforms"}

    MANIFEST.write_text(json.dumps({
        "upstream": "https://github.com/trueagi-io/PeTTa.git",
        "commit": commit,
        "captured_with": "tests/conformance/petta_capture.py",
        "engine_flag": "silent",
        "skips": excluded_by_capability,
        # What each capability answered HERE, so a skip can be re-decided
        # later instead of being believed: the verify side reports a recorded
        # skip whose capability has since arrived.
        "capabilities": capability_state(),
        "requirements": {name: list(need) for name, need in sorted(REQUIREMENTS.items())},
        "excluded": excluded,
        "entries": entries,
    }, indent=1, sort_keys=True) + "\n")

    print(f"corpus  : {len(entries)} files")
    print(f"excluded: {len(excluded)}")
    for name, why in sorted(excluded.items()):
        print(f"    {name}: {why}")
    print(f"skipped : {len(excluded_by_capability)}")
    for name, why in sorted(excluded_by_capability.items()):
        print(f"    {name}: {why}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
