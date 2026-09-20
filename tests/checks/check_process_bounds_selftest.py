"""Purpose: prove check_process_bounds.py can find, and can spare.

Running the pass over this repository proves the repository is bounded. It says
nothing about whether the pass can find an unbounded spawn at all, which is the
whole of its job. Both halves are planted here in a fixture the test writes and
throws away.

Four negatives are load-bearing. `$(dirname "$(dirname "$PY")")` holds `$PY`
without starting a Python, so a pass matching the line rather than the command
POSITION would report it and be turned off within a day. `in_py() { ...; }` is
a one-line function whose closing brace is not at column 0, so a parser
tracking only `^}` would treat the remaining 400 lines of check.sh as its body
and report every top-level lane in it: that exact mistake produced 32 false
findings while this check was being written. A command CONTINUED over two lines
is one command, and reading the halves apart reported the bound on the first
line and an unbounded spawn on the second. And a line that must not be bounded
says so in place, with a reason, because the two such lines in the tree are the
reaping suite's own fixtures and excluding them from somewhere else would put
the exclusion where nobody reading the line can see it.

Assumes: a writable ai-tmp/ in this repository.
Guarantees:
  - a planted unbounded swipl, sh, "$PY" and make inside a lane function are
    each reported with lane and line
    [tested: tests/checks/check_process_bounds_selftest.py; commit=b0d85db82c8069fa5c2bb864b1ce8a93bccf40f8]
  - a planted unbounded spawn in a RUNNER, which has no lane functions at all,
    is reported. That population is the one the 7,540-second spinner of
    2026-09-05 came from, and the pass did not read it until that day
    [tested: tests/checks/check_process_bounds_selftest.py; commit=b0d85db82c8069fa5c2bb864b1ce8a93bccf40f8]
  - a `bounded` helper that stops naming bounded.sh is reported, even though
    every `bounded ...` call in the same file still looks bounded
    [tested: tests/checks/check_process_bounds_selftest.py; commit=b0d85db82c8069fa5c2bb864b1ce8a93bccf40f8]
  - an `in_py` that stops calling `bounded` is reported for the same reason
    [tested: tests/checks/check_process_bounds_selftest.py; commit=b0d85db82c8069fa5c2bb864b1ce8a93bccf40f8]
  - a `bounded ...` written ABOVE its own definition is reported. In POSIX sh
    that call is a `not found` exiting 127, and an `if !` around it reads the
    thing it was probing for as absent
    [tested: tests/checks/check_process_bounds_selftest.py; commit=b0d85db82c8069fa5c2bb864b1ce8a93bccf40f8]
  - a planted unbounded engine spawn in a HARNESS script's Python is reported,
    and so is an argv the pass cannot read, while a wrapped one, a `git` call
    and a `sys.executable` call are not
    [tested: tests/checks/check_process_bounds_selftest.py; commit=b0d85db82c8069fa5c2bb864b1ce8a93bccf40f8]
  - a `bounded` spawn, an `in_py` spawn, a comment, a dirname substitution, a
    one-line function, a continued command bounded on its first line, and a
    line carrying `# unbounded: <reason>` are NOT reported
    [tested: tests/checks/check_process_bounds_selftest.py; commit=b0d85db82c8069fa5c2bb864b1ce8a93bccf40f8]
  - every shell shape that opens a command position is judged by the command
    that WRAPS the spawn: a `$( )`, a backtick, a pipeline, an `&&` chain, a
    `||` alternative, a `{ ...; }` group, an `if` and a `while` condition, a
    `for` body, a `case` arm, an assignment prefix holding a quoted space, a
    leading `>&2` redirection and an `env NAME=value` wrapper, each planted
    bounded and unbounded, are reported in the second form and spared in the
    first. The old command-position pattern got ten of the thirteen wrong,
    nine of them by sparing the unbounded half [measured 2026-09-06: the
    pattern answered 7 findings over 11 spawns where the grammar answers 13
    over 26, over the POSITIONS fixture below]
    [tested: tests/checks/check_process_bounds_selftest.py; commit=b0d85db82c8069fa5c2bb864b1ce8a93bccf40f8]
  - a spawner NAMED inside a quoted argument, `sed 's|sh tools/run.sh ...|'`, is not
    a command and is not reported
    [tested: tests/checks/check_process_bounds_selftest.py; commit=b0d85db82c8069fa5c2bb864b1ce8a93bccf40f8]
Fails when: run against a tree it did not write. It asserts on its own fixture.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))

from check_process_bounds import commands, findings  # noqa: E402  -- the path is installed above

BOUND_IN_PY = 'in_py() { ( cd "$PYDIR" && bounded "$@" ); }\n'
LOOSE_IN_PY = 'in_py() { ( cd "$PYDIR" && "$@" ); }\n'

GOOD_HELPER = 'bounded() { sh "$HERE/bounded.sh" "$@"; }\n'
LOOSE_HELPER = 'bounded() { timeout --preserve-status -k 10 3600 "$@"; }\n'

#: The helper defined BELOW its first call. In POSIX sh that call is a `not
#: found` and exits 127, and an `if !` above it then reads a present toolchain
#: as absent: extensions/mork/mork_ffi/build.sh did exactly this on 2026-09-05
#: and a gate run printed "missing: rust-nightly-toolchain" for an installed
#: one.
LATE_HELPER = """#!/bin/sh
HERE=$(cd -- "$(dirname -- "$0")" && pwd)
if command -v cargo >/dev/null 2>&1 && ! bounded cargo --version >/dev/null; then
    echo "no cargo" >&2
fi
""" + GOOD_HELPER

#: Top-level lines that follow the one-line function, which is the shape
#: check.sh actually has: in_py() { ...; } and then 400 lines of `run` calls
#: before the next function opens. A parser that treats the one-liner as open
#: attributes every one of them to it. Reported here as a NEGATIVE, because
#: `run()` already wraps a lane whose command word is a program.
TOP_LEVEL = """
run GATE   evidence   "$PY" "$HERE/tests/checks/check_evidence_tags.py"
run GATE   petta      sh -c "cd '$HERE' && '$PY' tests/conformance/petta.py"
"""

LANES = """
check_bad_swipl() {
    swipl -q --on-error=status thing.pl
}

check_bad_sh() {
    sh "$HERE/engine/test.sh"
}

check_bad_python() {
    ( cd "$HERE" && "$PY" -m ruff check $found )
}

# The case that hung a real gate run: `make` drives a sanitizer build whose
# llvm-symbolizer went to 0% CPU and never returned, and `make` was missing
# from the spawner list, so this check called that lane clean.
check_bad_make() {
    make --quiet -C "$binding" sanitize
}

check_good_swipl() {
    bounded swipl -q --on-error=status thing.pl
}

check_good_via_in_py() {
    in_py "$PY" bench.py --json out.json
}

check_only_a_comment() {
    # ( swipl -q thing.pl ) would run here if this were not a comment, and the
    # paren puts it at a command position, so only the comment skip spares it
    return 0
}

check_dirname_only() {
    py_prefix=$(dirname "$(dirname "$PY")")
    printf '%s\\n' "$py_prefix"
}

check_prose_only() {
    echo "note: node_modules is absent, the built-package \\
check will not run; npm ci fetches swipl-wasm and a gate does not reach the \\
network" >&2
    return 0
}
"""

#: A runner has no lane functions. Every command position in it belongs to a
#: process a person can start directly, so all four cases below are top level.
RUNNER = """#!/bin/sh
set -u
HERE=$(cd -- "$(dirname -- "$0")" && pwd)
""" + GOOD_HELPER + """
bounded swipl -g halt -s "$HERE/engine/main.pl" -- extensions

# unbounded: the child under test; giving it the link would remove the subject.
sh -c 'while :; do :; done' &

bounded sh "$HERE/engine/test.sh" \\
    suites/reader/parser.plt

npm run --silent build
"""

RUNNER_CONTINUED = """#!/bin/sh
HERE=$(cd -- "$(dirname -- "$0")" && pwd)
""" + GOOD_HELPER + """
"$PY" -m pytest tests \\
    -q -p no:benchmark
"""

#: `exec` keeps the command position open, and every seat's test.sh ends with
#: one. Deleting the wrapper from `exec sh tools/bounded.sh "$PY" -m pytest` leaves
#: `exec "$PY" -m pytest`, which read as clean until this case was planted.
#: `command -v` must NOT match for the same reason it never has: it asks PATH a
#: question and starts nothing.
RUNNER_EXEC = """#!/bin/sh
HERE=$(cd -- "$(dirname -- "$0")" && pwd)
command -v swipl >/dev/null 2>&1 || exit 0
exec "$PY" -m pytest tests
"""

#: Every shell shape that opens a command position, planted TWICE: once with
#: the bound in front of the spawn and once without. The marker in each
#: command's last argument is what the assertions name, so a shape that flips
#: reads as itself rather than as a line number.
#:
#: Thirteen shapes, because a pass that reads the first word after an
#: assignment prefix gets three backwards at once. `reading=$(bounded swipl ...)`
#: is BOUNDED and read as an unbounded swipl, which is what
#: tests/shell/test_boot_inference_determinism.sh was reworded around; ``
#: `swipl ...` `` after an assignment is UNBOUNDED and was spared entirely,
#: because a backtick is not an operator the old pattern knew; and
#: `RUSTFLAGS="-C target-cpu=native" cargo build` is unbounded and was spared
#: because the prefix pattern's `\\S*` stopped at the space inside the quotes.
#: That last one was real: extensions/mork/mork_ffi/build.sh carried it.
#:
#: The `sed` line is the negative the other shapes need. Its expression NAMES
#: `sh tools/run.sh`, and reading a quoted word as a command reported it; the
#: opt-out that spared it in tests/shell/test_example_runner_surfaces_failures.sh
#: was a workaround for this pass and is gone with it.
POSITIONS = """#!/bin/sh
HERE=$(cd -- "$(dirname -- "$0")" && pwd)
""" + GOOD_HELPER + """
substitution_bound=$(bounded swipl -g halt substitution-bound.pl)
substitution_loose=$(swipl -g halt substitution-loose.pl)

backtick_bound=`bounded swipl -g halt backtick-bound.pl`
backtick_loose=`swipl -g halt backtick-loose.pl`

bounded swipl -g halt pipeline-bound.pl | sed -n 1p
swipl -g halt pipeline-loose.pl | sed -n 1p

cd "$HERE" && bounded swipl -g halt chain-bound.pl
cd "$HERE" && swipl -g halt chain-loose.pl

cd "$HERE" || bounded swipl -g halt alternative-bound.pl
cd "$HERE" || swipl -g halt alternative-loose.pl

command -v swipl >/dev/null 2>&1 || { bounded swipl -g halt block-bound.pl; }
command -v swipl >/dev/null 2>&1 || { swipl -g halt block-loose.pl; }

if bounded swipl -g halt condition-bound.pl; then echo yes; fi
if swipl -g halt condition-loose.pl; then echo yes; fi

while bounded swipl -g halt loop-bound.pl; do break; done
while swipl -g halt loop-loose.pl; do break; done

for suite in a b; do bounded swipl -g halt body-bound.pl; done
for suite in a b; do swipl -g halt body-loose.pl; done

case "$mode" in
    fast) bounded swipl -g halt arm-bound.pl ;;
    slow) swipl -g halt arm-loose.pl ;;
esac

RUSTFLAGS="-C target-cpu=native" TMPDIR="$HERE" bounded cargo build prefix-bound
RUSTFLAGS="-C target-cpu=native" TMPDIR="$HERE" cargo build prefix-loose

>&2 bounded swipl -g halt redirect-bound.pl
>&2 swipl -g halt redirect-loose.pl

bounded env METTA_PROBE=1 swipl -g halt env-bound.pl
env METTA_PROBE=1 swipl -g halt env-loose.pl

sed 's|sh tools/run.sh "$f" 2>&1|sh tools/run.sh "$f"|' "$HERE/test.sh" > quoted-argument.sh
"""

#: Spans whose only job is to be CUT. `truncations` below reads every prefix
#: of every fixture line, and an unterminated span is where a hand-written
#: scanner over quoting and nesting fails; these are the spans the fixtures
#: above do not hold. An arithmetic expansion, because `$((` cut short is a
#: `$(` that never closes and reading it as a substitution walks past the end;
#: a nested `${ }`, for the same reason one level down; a continuation, whose
#: last character is a backslash with nothing after it; and quotes inside
#: quotes, so a cut lands between them.
TRUNCATABLE = """#!/bin/sh
count=$((count + 1))
goal=${METTA_GOAL:-${METTA_FALLBACK:-halt}}
bounded swipl -g "${goal}" -t halt "$HERE/engine/bench.pl"
printf '%s: "%s"\\n' "a 'quoted' word" "$goal"
sed -n 's/.*inferences=\\([0-9][0-9]*\\).*/\\1/p' "$out"
"""

#: The thirteen, in the order they are planted above. `chain` and
#: `alternative` are the two halves of an and-or list and `block` is the brace
#: group a `|| { ...; }` opens, which build.sh at the root writes; they are
#: separate cases because a reader checking a shape against this list should
#: find the shape rather than have to know which ones share a code path.
#:
#: `redirect` and `env` each separate a WORKING pass from a plausible one.
#: `>&2 swipl ...` is a leading redirection in front of a spawn, and it reads
#: as `2 swipl ...` with the spawn spared for any tokenizer that treats the
#: `&` in `2>&1` as the control operator it is everywhere else. `env NAME=v
#: swipl ...` is a command that RUNS its operand, and a head that stops at it
#: spares the spawn behind it; four lines in this tree write `bounded env
#: NAME=value sh <script>` and dropping the `bounded` from one of them is
#: exactly the regression this check exists to catch.
SHAPES = ("substitution", "backtick", "pipeline", "chain", "alternative",
          "block", "condition", "loop", "body", "arm", "prefix", "redirect",
          "env")


#: A harness script, read as Python rather than as shell. Six shapes: an engine
#: spawn with no bound, the same one wrapped, an argv the pass cannot read, a
#: `git` call, a `sys.executable` call, and an excused one. Only the first and
#: the third are findings.
HARNESS = '''"""A planted harness script."""
import subprocess
import sys
from bounded_spawn import bounded


def unbounded_engine():
    return subprocess.run(["swipl", "-q", "-g", "halt"], check=False)


def bounded_engine():
    return subprocess.run(bounded(["swipl", "-q", "-g", "halt"]), check=False)


def argv_in_a_variable(command):
    return subprocess.run(command, check=False)


def git_is_not_a_spawner():
    return subprocess.run(["git", "rev-parse", "HEAD"], check=False)


def another_check_is_not_an_engine():
    return subprocess.run([sys.executable, "-c", "pass"], check=False)


def excused():
    # unbounded: the child under test; the bound would remove the subject.
    return subprocess.Popen(["swipl", "-q", "-g", "halt"])
'''


def report(check_text: str, runner_text: str | None = None,
           python_text: str | None = None):
    """The pass's findings over a planted tree, and its spawn count."""
    with tempfile.TemporaryDirectory(dir=ROOT / "ai-tmp") as work:
        root = Path(work)
        (root / "check.sh").write_text(check_text, encoding="utf-8")
        runners = []
        if runner_text is not None:
            (root / "test.sh").write_text(runner_text, encoding="utf-8")
            runners = [root / "test.sh"]
        harness = []
        if python_text is not None:
            (root / "harness.py").write_text(python_text, encoding="utf-8")
            harness = [root / "harness.py"]
        return findings([root / "check.sh"], root, runners, harness)


def lane_names(found: list[str]) -> set[str]:
    """The lane or file each spawn finding names, for the assertions below."""
    return {line.split(": ")[1].split(" starts")[0]
            for line in found if " starts a process" in line}


def truncations() -> int:
    """Every PREFIX of every fixture line, read as a command list.

    The pass reads shell by its grammar, and a hand-written scanner over
    quoting and nesting fails at a span that never closes: a `$(`, a `${`, a
    quote or a backslash cut off at the end of the text. Reading every prefix
    reaches each of those at every position it can occur at. The property is
    that none of them raises and none of them fails to advance, and it matters
    more than a finding would: this module is imported by the check itself, so
    an exception here is every lane that reads a shell script at once.

    Deterministic rather than random on purpose, because a seed is a number
    somebody has to keep. The wider sweep was run once beside it: 489,697
    random and truncated inputs over an alphabet of shell punctuation, no
    exception raised and none that did not end [measured 2026-09-06].
    """
    checked = 0
    for fixture in (POSITIONS, TRUNCATABLE, LANES, RUNNER, RUNNER_EXEC,
                    RUNNER_CONTINUED, LATE_HELPER, TOP_LEVEL, GOOD_HELPER,
                    BOUND_IN_PY):
        for line in fixture.splitlines():
            for cut in range(len(line) + 1):
                commands(line[:cut])
                checked += 1
    return checked


def main() -> int:
    """Every planted case, positive and negative."""
    problems: list[str] = []

    found, total = report(GOOD_HELPER + BOUND_IN_PY + TOP_LEVEL + LANES, RUNNER)
    lanes = lane_names(found)
    problems.extend(
        f"{expected}: an unbounded spawn was NOT reported"
        for expected in ("check_bad_swipl", "check_bad_sh", "check_bad_python",
                         "check_bad_make")
        if expected not in lanes
    )
    problems.extend(
        f"{spared}: reported, and it must not be"
        for spared in ("check_good_swipl", "check_good_via_in_py",
                       "check_only_a_comment", "check_dirname_only",
                       "check_prose_only")
        if spared in lanes
    )
    if "test.sh" not in lanes:
        problems.append(
            "the planted `npm run build` in a RUNNER was not reported. A "
            "runner has no lane functions, and reading only lane functions is "
            "what let a hand-started swipl run 7,540 seconds outside every "
            "lane on 2026-09-05."
        )
    if len(found) != 5:
        problems.append(f"expected exactly 5 findings, got {len(found)}: {found}")
    #: Four unbounded lane spawns, one `bounded swipl`, one `in_py`, and four in
    #: the runner: its own `bounded swipl`, the excused child, the continued
    #: `bounded sh`, and the unbounded npm. A pass that forgot how to see a
    #: bounded spawn would still report the same findings over fewer of them.
    if total != 10:
        problems.append(
            f"expected 10 spawns to be looked at, got {total}. A pass that "
            f"stops recognising `bounded` as a spawn line reports the same "
            f"findings while covering less."
        )

    # The one-line function must not swallow what follows it.
    if "in_py" in lanes:
        problems.append(
            "the one-line in_py was treated as an open function body, so the "
            "top-level lines after it were reported as spawns inside it. That "
            "is the mistake that produced 32 false findings."
        )

    # Every command position, bounded and unbounded, one pair per shape.
    positions, positions_total = report(GOOD_HELPER + BOUND_IN_PY, POSITIONS)
    reported = "\n".join(positions)
    problems.extend(
        f"{shape}-loose: an unbounded spawn at this command position was NOT "
        f"reported. A position the pass cannot see is one an unbounded spawn "
        f"can be written at forever."
        for shape in SHAPES if f"{shape}-loose" not in reported
    )
    problems.extend(
        f"{shape}-bound: a spawn WRAPPED at this command position WAS "
        f"reported. A false finding here is what gets the shape reworded "
        f"around the pass instead of the pass fixed."
        for shape in SHAPES if f"{shape}-bound" in reported
    )
    if len(positions) != len(SHAPES):
        problems.append(
            f"expected {len(SHAPES)} findings over the command positions, got "
            f"{len(positions)}: {positions}")
    if positions_total != 2 * len(SHAPES):
        problems.append(
            f"expected {2 * len(SHAPES)} spawns to be looked at over the "
            f"command positions, got {positions_total}. Each shape is planted "
            f"twice and both halves are spawns; a pass that stops seeing the "
            f"bounded half reports the same findings while covering less.")
    if "run.sh" in reported:
        problems.append(
            "the planted `sed 's|sh tools/run.sh ...|'` was reported. Its expression "
            "NAMES a command and is not one, and reading it as a spawn is what "
            "put an opt-out on that line in the tree.")

    # in_py losing its bound is a finding even when every caller looks bounded.
    loose, _ = report(GOOD_HELPER + LOOSE_IN_PY + TOP_LEVEL + LANES)
    if not any("in_py no longer calls" in line for line in loose):
        problems.append("in_py without `bounded` was NOT reported")

    # A helper defined below its first call is a `not found`, not a bound.
    late, _ = report(GOOD_HELPER + BOUND_IN_PY, LATE_HELPER)
    if not any("defined at line" in line for line in late):
        problems.append(
            "a `bounded ...` ABOVE its own definition was not reported. That "
            "call exits 127, and the `if !` around it reads the thing it was "
            "probing for as absent.")

    # And the same for the helper every `bounded ...` in a file reaches.
    helper, _ = report(LOOSE_HELPER + BOUND_IN_PY + TOP_LEVEL + LANES)
    if not any("does not name bounded.sh" in line for line in helper):
        problems.append(
            "a `bounded` helper that stopped naming bounded.sh was NOT "
            "reported. Every `bounded ...` in that file still reads as bounded "
            "here while none of them is."
        )

    # A continued command is one command: the bound sits at its front.
    joined, joined_total = report(GOOD_HELPER + BOUND_IN_PY, RUNNER_CONTINUED)
    if not any("test.sh" in line for line in joined):
        problems.append(
            "a continued `\"$PY\" -m pytest` with no bound was NOT reported")
    if len(joined) != 1:
        problems.append(
            f"a two-line continuation was counted as {len(joined)} findings, "
            f"not one: {joined}")
    if joined_total != 1:
        problems.append(
            f"a two-line continuation was counted as {joined_total} spawns, "
            f"not one")

    # `exec` keeps the command position open; `command -v` does not open one.
    execed, exec_total = report(GOOD_HELPER + BOUND_IN_PY, RUNNER_EXEC)
    if len(execed) != 1:
        problems.append(
            f"a bare `exec \"$PY\" -m pytest` was counted as {len(execed)} "
            f"findings, not one: {execed}. Either exec does not open a command "
            f"position here, or `command -v swipl` opened one and must not."
        )
    if exec_total != 1:
        problems.append(
            f"expected 1 spawn in the exec fixture, got {exec_total}: "
            f"`command -v swipl` asks PATH a question and starts nothing."
        )

    # The Python half. A harness script's own subprocess calls are read as
    # Python, because two of them put their engine in a session of its own
    # where no group signal from the lane above can reach it.
    harness_found, harness_total = report(
        GOOD_HELPER + BOUND_IN_PY, None, HARNESS)
    reported = {line.split(":")[1] for line in harness_found}
    if len(harness_found) != 2:
        problems.append(
            f"expected 2 findings over the planted harness, got "
            f"{len(harness_found)}: {harness_found}")
    if harness_total != 4:
        problems.append(
            f"expected 4 harness spawns to be looked at, got {harness_total}. "
            f"The unbounded engine, the bounded one, the argv it cannot read "
            f"and the excused one are all LOOKED AT; the `git` call and the "
            f"`sys.executable` call are not a spawn this asks about at all. A "
            f"pass that stopped seeing the bounded one, or the excused one, "
            f"would report the same two findings while covering less.")
    if not any("swipl" in line for line in harness_found):
        problems.append("the planted unbounded swipl in Python was NOT reported")
    if not any("subprocess.run(command" in line for line in harness_found):
        problems.append(
            "an argv the pass cannot read was SPARED. A check that spares what "
            "it cannot see reports a clean run over a gap.")
    if any("bounded([" in line for line in harness_found):
        problems.append("a `bounded([...])` call was reported, and must not be")
    if any('"git"' in line for line in harness_found):
        problems.append("a `git` call was reported; git returns")
    if any("sys.executable" in line for line in harness_found):
        problems.append(
            "a `sys.executable` call was reported; it starts another check, "
            "which runs and returns")
    del reported


    # The scanner over every truncated fixture line. Reported as a problem
    # rather than raised, so a break here reads as this pass's finding and not
    # as the pass being unable to run at all.
    truncated = 0
    try:
        truncated = truncations()
    # Any exception is the finding, which is why this catches every one.
    except Exception as error:
        problems.append(
            f"the scanner raised {type(error).__name__} reading a truncated "
            f"line: {error}. Every lane that reads a shell script imports "
            f"this scanner, so an unterminated `$(`, `${{`, quote or backslash "
            f"that raises here is all of them.")

    for problem in problems:
        print(f"  {problem}")
    print(f"{len(problems)} finding(s) over {29 + 2 * len(SHAPES) + 1} "
          f"planted cases and {truncated} truncated lines")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
