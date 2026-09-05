"""Purpose: bound every process this repository starts, past its starter.

`check.sh`'s `run()` wraps a lane whose command word is an external program, and
CANNOT wrap one whose command word is a shell function, because the wrapper
execs and a function is not on disk. 25 of the 33 lane functions start swipl,
node or a Python of their own, so most of what this gate runs would carry no
bound at all if those spawns did not carry it themselves. They do, spelled
`bounded swipl ...`, and this is what says so.

The cost of not saying so is measured twice, and the second time is why this
reads more than the check scripts. Two swipl children spawned under this gate
ran from 2026-09-01 to 2026-09-03, spinning at 100% for 122 CPU-hours between
them, after the session that started them was killed; the only bound on them
was `subprocess.run(timeout=)`, which is enforced in the parent's wait loop and
stops enforcing when the parent does. Then on 2026-09-05 a
`swipl -g "set_test_options([format(log)]), run_tests" -t halt
tests/prolog/suites/spaces/materialization.plt` ran 7,540 seconds at 97.8% CPU
and needed SIGKILL. That one was started by hand, outside every lane function,
so a pass reading only the check scripts called the tree clean while it ran. The
RUNNERS are read for that reason: test.sh, run.sh, engine/test.sh, every seat's
test.sh, bench.sh and build.sh, and the shell suites under tests/shell, each of
which a person can start directly.

The harness scripts under tests/checks and tests/conformance are read too, and
in PYTHON rather than in shell, because two of them put their engine in a
session of its own with `start_new_session=True` so their own timeout handler
can killpg it. That is the one shape no group signal from the lane above can
reach, which leaves a `subprocess.TimeoutExpired` handler in the parent as the
only bound -- the mechanism that already cost 122 CPU-hours here when the
parent was killed. Their argv is read with `ast` rather than with the regex
above: a Python list is a Python list, and guessing at one with a pattern is
how a check starts sparing what it cannot see.

Assumes:
  - a lane function is `name() {` at column 0 in one of the check scripts, and
    ends at a `}` at column 0, which is how every one of them is written
  - `bounded`, `in_py` and `bounded.sh` are the three spellings of the bound.
    `in_py` carries it because its own body calls `bounded`, and each script's
    `bounded` carries it because its own body names `bounded.sh`; both are
    checked here rather than assumed
  - a runner opts a line out of the check in place, with `# unbounded:` and a
    reason on the line above it, and a Python caller does the same on the line
    above the statement
  - a Python caller reaches the bound through `bounded_spawn.bounded`, which
    puts a CALL where the argv list was. So a call whose argv is a call is
    bound, a call whose argv begins with a literal this does not recognise is
    spared, and anything else is reported as undecidable rather than spared
Guarantees:
  - a spawn added without a bound is named, with its file, line and the text,
    so the fix is the line the report prints
    [tested: tests/checks/check_process_bounds_selftest.py]
  - a `bounded` helper that stops naming bounded.sh is reported even though
    every call site still LOOKS bounded
    [tested: tests/checks/check_process_bounds_selftest.py]
Fails when: a script starts a process through a name this does not know. The
  known set is printed with the findings for that reason, so an unrecognised
  spawn reads as a gap in this check rather than as a clean run.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import ast
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]

#: The programs a script starts that can outlive it. `sh` is here because every
#: test.sh and bench.sh the lanes call is a shell script that starts more, and
#: the build tools are here because the gate run that first verified this check
#: HUNG in `make -C extensions/cmetta sanitize` for 360 seconds: LeakSanitizer
#: spawned llvm-symbolizer to report a leak, the symbolizer went to 0% CPU, and
#: the test blocked forever on its pipe. `make` was not on this list, so the
#: check called that lane clean while it was the one lane that could not end.
#: `swipl-ld` is here because it drives a C compiler, and `perf` because it
#: waits on whatever it measures.
SPAWNERS = ("swipl", "swipl-ld", "node", "npx", "sh", '"$PY"', "$PY",
            "make", "gcc", "clang", "cargo", "npm", "python3", "perf")

#: Spellings that carry the bound. Each is verified, not trusted: `in_py` by
#: its body calling `bounded`, and `bounded` by its body naming bounded.sh.
BOUNDING = ("bounded", "in_py")

#: The one implementation, named as a path where a shell function will not do
#: -- an `exec` cannot exec a function, and neither can Python's subprocess.
IMPLEMENTATION = "bounded.sh"

#: The programs a HARNESS SCRIPT starts from Python that can outlive it. An
#: engine, a build tool or a profiler; `git` and `sh` are deliberately absent.
#: Every `git` here runs over a temporary directory and returns, and every `sh`
#: is a fixture script, one of which sets PATH=/nonexistent on purpose to make
#: the allocator refuse -- wrapping that one would have the wrapper refuse
#: instead and change the subject. `sys.executable` is absent for the same kind
#: of reason: it starts another check, which runs and returns, and whose own
#: engine spawns carry the bound themselves.
PY_SPAWNERS = frozenset({"swipl", "swipl-ld", "node", "npx", "npm", "make",
                         "cargo", "perf", "cc", "gcc", "clang"})

#: The subprocess doors. `subprocess.` is required in front of each, because a
#: bare `run` is not a spawn.
PY_STARTERS = frozenset({"run", "Popen", "call", "check_call", "check_output"})

#: Command position: start of line, or after a shell operator, optionally
#: preceded by `exec` and by environment assignments. `$(dirname "$(dirname
#: "$PY")")` must not match, which is why the executable has to sit at a command
#: position rather than merely appear on the line. `exec` does, and every seat's
#: test.sh ends with one; without it, deleting the wrapper from `exec sh
#: bounded.sh "$PY" -m pytest` left `exec "$PY" -m pytest` reading as clean.
#: `command` is deliberately NOT here: `command -v swipl` asks PATH a question
#: and starts nothing, and this file has fourteen of them.
POSITION = re.compile(
    r"(?:^|\(|&&|\|\||;|\||!|\$\()\s*"
    r"(?:exec\s+)?"
    r"(?:[A-Za-z_][A-Za-z_0-9]*=\S*\s+)*"
    r"(?:exec\s+)?"
    r"(" + "|".join(re.escape(s) for s in SPAWNERS + BOUNDING) + r")(?![\w-])"
)

#: The door, so a line that must not be bounded says so in place rather than
#: being excluded from somewhere else. The reason is required: a marker with
#: nothing after it is a finding of its own.
OPT_OUT = re.compile(r"#\s*unbounded:\s*(?P<reason>\S.*)")


def scripts() -> list[Path]:
    """The gate scripts, discovered the way check.sh discovers them."""
    found = [REPO / "check.sh", REPO / "engine" / "check.sh"]
    found += sorted((REPO / "extensions").glob("*/check.sh"))
    return [p for p in found if p.is_file()]


def runners() -> list[Path]:
    """Every script a person or a lane can start a process through.

    Discovered rather than listed, so a new seat's test.sh is covered by
    existing there. bounded.sh itself is excluded because it IS the bound, and
    select-python.sh and gate_scratch.sh because they are sourced and start
    nothing.
    """
    excluded = {REPO / "bounded.sh",
                REPO / "select-python.sh",
                REPO / "tests" / "checks" / "gate_scratch.sh"}
    found = [
        *(REPO / name for name in ("test.sh", "run.sh", "bench.sh", "build.sh",
                                   "worktree.sh")),
        *sorted((REPO / "engine").glob("*.sh")),
        *sorted((REPO / "extensions").glob("*/*.sh")),
        *sorted((REPO / "extensions").glob("*/*/*.sh")),
        *sorted((REPO / "extensions").glob("*/tests/*.sh")),
        *sorted((REPO / "examples").glob("*/build.sh")),
        *sorted((REPO / "tests").glob("*.sh")),
        *sorted((REPO / "tests" / "shell").glob("*.sh")),
    ]
    ordered: list[Path] = []
    for path in found:
        if path in excluded or path in ordered or not path.is_file():
            continue
        if path.name == "check.sh":
            continue  # read as a gate script above, lane by lane
        ordered.append(path)
    return ordered


def _uncommented(lines: list[str]) -> list[tuple[int, str, str | None]]:
    r"""Line number, code, and the opt-out reason a preceding comment gave.

    A double quote left open by one line makes the next one prose, and prose
    contains shell punctuation: `check will not run; npm ci fetches swipl-wasm`
    reads as a command separator followed by a spawn unless the string it sits
    inside is tracked.

    A backslash continuation is JOINED, because a continued command is one
    command and its bound sits at the front of it. Reading the halves apart
    reported `bounded sh bounded.sh \\` as bounded and the `"$PY" -m pytest`
    on the next line as an unbounded spawn, which is the same command twice.
    """
    out: list[tuple[int, str, str | None]] = []
    inside_string = False
    excused: str | None = None
    pending = ""
    pending_at = 0
    for number, line in enumerate(lines, 1):
        was_inside, inside_string = inside_string, inside_string ^ (
            len(re.findall(r'(?<!\\)"', line)) % 2 == 1
        )
        if was_inside:
            continue
        if not pending and line.lstrip().startswith("#"):
            door = OPT_OUT.search(line)
            excused = door.group("reason") if door else excused
            continue
        if pending:
            joined = pending + " " + line.strip()
        else:
            joined, pending_at = line, number
        if joined.rstrip().endswith("\\"):
            pending = joined.rstrip()[:-1].rstrip()
            continue
        pending = ""
        out.append((pending_at, joined, excused))
        excused = None
    if pending:
        out.append((pending_at, pending, excused))
    return out


def spawns(path: Path) -> list[tuple[int, str, str, bool, str | None]]:
    """Every spawn inside a multi-line lane function.

    Answers line, lane, text, whether it is bound, and the opt-out reason.
    """
    out: list[tuple[int, str, str, bool, str | None]] = []
    lane: str | None = None
    lines = path.read_text(encoding="utf-8").splitlines()
    for number, line, excused in _uncommented(lines):
        opening = re.match(r"^([a-z_][a-z_0-9]*)\(\)\s*\{", line)
        if opening:
            # A one-line function body cannot hold an unbounded continuation.
            lane = None if line.rstrip().endswith("}") else opening.group(1)
            continue
        if lane is None:
            continue
        if line.startswith("}"):
            lane = None
            continue
        words = POSITION.findall(line)
        if not words:
            continue
        bound = any(w in BOUNDING for w in words) or IMPLEMENTATION in line
        out.append((number, lane, line.strip(), bound, excused))
    return out


def runner_spawns(path: Path) -> list[tuple[int, str, str, bool, str | None]]:
    """Every spawn in a runner, at any nesting level.

    A runner has no lane structure to follow: a person can start it directly,
    so every command position in it is one a process can escape from. The lane
    name reported is the file's own, which is what the reader needs.
    """
    out: list[tuple[int, str, str, bool, str | None]] = []
    name = path.name
    for number, line, excused in _uncommented(
            path.read_text(encoding="utf-8").splitlines()):
        # The `bounded` helper's own one-line definition is not a spawn site in
        # the flow of the script, and helper_defects below owns whether it
        # still carries the bound. Counting it here would move the spawn count
        # of every file that gains one and report the same defect twice.
        if re.match(r"^bounded\(\)\s*\{.*\}\s*$", line):
            continue
        words = POSITION.findall(line)
        if not words:
            continue
        bound = any(w in BOUNDING for w in words) or IMPLEMENTATION in line
        out.append((number, name, line.strip(), bound, excused))
    return out


def python_harness() -> list[Path]:
    """Every harness script whose own Python starts processes."""
    found = [
        *sorted((REPO / "tests" / "checks").glob("*.py")),
        *sorted((REPO / "tests" / "conformance").glob("*.py")),
    ]
    return [path for path in found if path.is_file()]


def _python_starter(func: ast.expr) -> bool:
    """Whether this call is one of subprocess's spawn doors."""
    return (isinstance(func, ast.Attribute)
            and func.attr in PY_STARTERS
            and isinstance(func.value, ast.Name)
            and func.value.id == "subprocess")


def _python_argv(node: ast.Call) -> ast.expr | None:
    """The argument that names the program, positional or by keyword."""
    if node.args:
        return node.args[0]
    for keyword in node.keywords:
        if keyword.arg == "args":
            return keyword.value
    return None


def _python_statements(tree: ast.AST) -> dict[ast.AST, ast.stmt]:
    """The INNERMOST statement each node belongs to.

    Innermost, because the opt-out sits on the line above the call and the
    outermost enclosing statement is the function that contains it. `ast.walk`
    is breadth-first, so a deeper statement is visited later and the plain
    assignment below keeps it; `setdefault` kept the outermost and read the
    wrong line, which spared nothing and reported both planted opt-outs.
    """
    owner: dict[ast.AST, ast.stmt] = {}
    for statement in ast.walk(tree):
        if not isinstance(statement, ast.stmt):
            continue
        for node in ast.walk(statement):
            owner[node] = statement
    return owner


def _python_excuse(lines: list[str], statement_line: int) -> str | None:
    """The reason a comment block directly above the statement gave, if any."""
    index = statement_line - 2
    while index >= 0 and lines[index].lstrip().startswith("#"):
        door = OPT_OUT.search(lines[index])
        if door:
            return door.group("reason")
        index -= 1
    return None


def python_spawns(path: Path) -> list[tuple[int, str, str, bool, str | None]]:
    """Every subprocess call in a harness script, read as Python.

    A call is BOUND when its argv is itself a call, which is the shape
    `bounded_spawn.bounded` produces. It is SPARED when its argv begins with a
    literal program this does not recognise, or with `sys.executable`. Anything
    else is REPORTED, including an argv this cannot read: a check that spares
    what it cannot see is a check that reports a clean run over a gap.
    """
    out: list[tuple[int, str, str, bool, str | None]] = []
    source = path.read_text(encoding="utf-8")
    lines = source.splitlines()
    tree = ast.parse(source)
    owner = _python_statements(tree)
    name = path.name
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call) or not _python_starter(node.func):
            continue
        statement = owner.get(node)
        excused = _python_excuse(
            lines, getattr(statement, "lineno", node.lineno))
        argv = _python_argv(node)
        if isinstance(argv, ast.Call):
            out.append((node.lineno, name, lines[node.lineno - 1].strip(),
                        True, excused))
            continue
        if isinstance(argv, (ast.List, ast.Tuple)) and argv.elts:
            head = argv.elts[0]
            if (isinstance(head, ast.Attribute) and head.attr == "executable"
                    and isinstance(head.value, ast.Name)
                    and head.value.id == "sys"):
                continue
            if isinstance(head, ast.Constant) and isinstance(head.value, str):
                if Path(head.value).name not in PY_SPAWNERS:
                    continue
                out.append((node.lineno, name, lines[node.lineno - 1].strip(),
                            False, excused))
                continue
        out.append((node.lineno, name, lines[node.lineno - 1].strip(),
                    False, excused))
    return out


def helper_defects(paths: list[Path], root: Path) -> list[str]:
    """Every `bounded` or `in_py` definition that no longer carries the bound.

    Checked rather than trusted. `bounded` is the word every call site is
    written with, so a definition that stopped naming bounded.sh leaves every
    one of them reading as bounded here while none of them is.

    ORDER is checked for the same reason. A `bounded ...` above its own
    definition is not a weaker bound, it is a `not found`, and sh answers 127
    for one: `if command -v cargo && ! bounded cargo +nightly --version` then
    reads a present toolchain as absent, which is what extensions/mork/mork_ffi/
    build.sh did on 2026-09-05 until a gate run printed "missing:
    rust-nightly-toolchain" for a nightly that was installed.
    """
    found: list[str] = []
    remedy = f'    Write it `bounded() {{ sh "$ROOT/{IMPLEMENTATION}" "$@"; }}`.'
    for path in paths:
        name = str(path.relative_to(root))
        text = path.read_text(encoding="utf-8")
        found.extend(
            f"{name}: its `bounded` helper does not name {IMPLEMENTATION}, so "
            f"every `bounded ...` in this file reads as bounded here and is "
            f"not.\n{remedy}"
            for match in re.finditer(r"^bounded\(\)\s*\{(?P<body>[^}]*)\}",
                                     text, re.MULTILINE)
            if IMPLEMENTATION not in match.group("body")
        )
        define = re.search(r"^bounded\(\)\s*\{", text, re.MULTILINE)
        if define is None:
            continue
        defined_at = text[:define.start()].count("\n") + 1
        for number, line, _excused in _uncommented(text.splitlines()):
            if number >= defined_at:
                break
            if "bounded" in POSITION.findall(line):
                found.append(
                    f"{name}:{number}: `bounded` is called here and defined at "
                    f"line {defined_at}, below it. A shell function that is "
                    f"not defined yet is a `not found`, which exits 127, which "
                    f"an `if ! ...` reads as the thing it was probing for "
                    f"being absent.\n    {line.strip()[:100]}\n"
                    f"    Move the definition above the first call."
                )
                break
    driver = root / "check.sh"
    if driver.is_file() and not re.search(
        r"^in_py\(\)\s*\{[^}]*\bbounded\b",
        driver.read_text(encoding="utf-8"), re.MULTILINE
    ):
        found.append(
            "check.sh: in_py no longer calls `bounded`, and 18 lanes reach "
            "their command through it. Those lanes are unbounded and this "
            "check would otherwise still pass them."
        )
    return found


def findings(paths: list[Path], root: Path,
             runner_paths: list[Path] | None = None,
             python_paths: list[Path] | None = None) -> tuple[list[str], int]:
    """Every unbounded spawn, and how many spawns were looked at.

    Split out of main so the selftest can put a planted tree in front of it
    without building a whole repository around it.
    """
    found: list[str] = []
    total = 0
    runner_paths = list(runner_paths or [])
    python_paths = list(python_paths or [])
    reading: list[tuple[Path, object]] = [
        *((path, spawns) for path in paths),
        *((path, runner_spawns) for path in runner_paths),
        *((path, python_spawns) for path in python_paths),
    ]
    for path, read in reading:
        name = path.name if path.parent == root else str(
            path.relative_to(root) if root in path.parents else path)
        for number, lane, text, bound, excused in read(path):
            total += 1
            if bound or excused:
                continue
            found.append(
                f"{name}:{number}: {lane} starts a process with no bound.\n"
                f"    {text[:100]}\n"
                f"    Prefix it with `bounded`, which is this repository's one "
                f"definition of the ceiling and of the link to the process "
                f"that started it. A bound kept by the caller stops being kept "
                f"when the caller is killed, and a deadline without that link "
                f"leaves an orphan burning a core until the deadline."
            )
    found.extend(helper_defects([*paths, *runner_paths], root))
    return found, total


def main() -> int:
    """Name every spawn that carries no bound."""
    paths = scripts()
    runner_paths = runners()
    harness = python_harness()
    found, total = findings(paths, REPO, runner_paths, harness)
    for finding in found:
        print(f"  {finding}")
    print(f"{len(found)} finding(s) over {total} spawns "
          f"in {len(paths)} gate scripts, {len(runner_paths)} runners "
          f"and {len(harness)} harness scripts")
    # The recognised set, on a clean run as well as a dirty one. Without it a
    # reader cannot tell a tree with no unbounded spawn from a pass that did
    # not look for the one it has, which is the difference between a clean run
    # and a gap.
    print(f"  shell: {' '.join(sorted(SPAWNERS))}")
    print(f"  python: {' '.join(sorted(PY_SPAWNERS))}, and nothing else; "
          f"an argv it cannot read is reported rather than spared")
    return 1 if found else 0


if __name__ == "__main__":
    raise SystemExit(main())
