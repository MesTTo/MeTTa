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
parent was killed. Their argv is read with `ast` rather than with a pattern:
a Python list is a Python list, and guessing at one with a regex is how a
check starts sparing what it cannot see.

The SHELL is read the same way, by its own grammar rather than by a pattern,
for the reason the Python half already had. A line holds more than one
command: a pipeline, an `&&` chain, an `if` or `while` condition, a `for`
body, a `case` arm, a subshell and a `$( )` each open a command position, and
each command there is bounded or not on its own. A pattern that finds the
first recognised word after an assignment prefix answers about the wrong one.
It called `reading=$(bounded swipl ...)` an unbounded swipl, which is what
tests/shell/test_boot_inference_determinism.sh was reworded around rather than
this file being fixed; it spared ``bad=`swipl ...` `` entirely, because a
backtick is not an operator it knew; it spared an unbounded spawn in every
`if`, `while`, `for` and `case` position and inside every `{ ...; }` group;
and it spared `RUSTFLAGS="-C target-cpu=native" ... cargo build`, because its
prefix pattern stopped at the space inside the quotes. That last one was the
tree's one unbounded spawn when this was written [measured 2026-09-06: over
the thirteen planted command positions the pattern answered 7 findings across
11 spawns and got ten shapes wrong, nine by sparing; the grammar answers 13
across 26 and gets all thirteen right;
fixture=tests/checks/check_process_bounds_selftest.py's POSITIONS].

Assumes:
  - a lane function is `name() {` at column 0 in one of the check scripts, and
    ends at a `}` at column 0, which is how every one of them is written
  - a logical line is POSIX sh: quoting, `$( )`, backticks and `${ }` nest the
    way the shell nests them, and a `#` opening a word comments out the rest.
    A `$( )` a line leaves open is read as the commands the lines below it
    are, which is what they are
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
from dataclasses import dataclass
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

#: The shell OPERATORS that end one command and open the position where the
#: next one begins. Longest first, because `;;` is not two `;` and `&&` is not
#: two `&`. `(` and `)` are here because a subshell and a `case` pattern both
#: open a command position with one.
OPERATORS = (";;", "&&", "||", ";", "&", "|", "(", ")")

#: Words that stand in FRONT of a command without being one, so the word after
#: them is still the command word. `exec` replaces the shell with what follows
#: and every seat's test.sh ends with one: deleting the wrapper from `exec sh
#: bounded.sh "$PY" -m pytest` leaves `exec "$PY" -m pytest`, and that read as
#: clean until `exec` was recognised. `{` and `}` group commands and are
#: RESERVED WORDS rather than operators, which is why they are matched as whole
#: words and `${VAR}` is not one.
#:
#: `env` is here for the same reason `exec` is. It is not a reserved word, it
#: is a command that runs its operand, and this tree writes it: four lines in
#: engine/check.sh and extensions/cmetta/check.sh read `bounded env NAME=value
#: sh <script>`. Drop the `bounded` from one of those and the spawn is `sh`,
#: which is exactly the regression this check exists to catch and which a head
#: stopping at `env` would spare. The assignments after it are stepped over by
#: the same rule that steps over a `LC_ALL=C sort` prefix.
LEADING = frozenset({"exec", "env", "!", "time", "if", "then", "elif", "else",
                     "while", "until", "do", "done", "fi", "esac"})

#: The words that separate one command from the next without being operators.
BLOCK = frozenset({"{", "}"})

#: Reserved words whose remaining words are a NAME and a word LIST rather than
#: a command: `for f in a b`, `case "$x" in`, `select f in a b`. The list is
#: not run. A `$( )` inside it IS, which is why `commands` reads a word's
#: substitutions whether or not the word names a program.
WORD_LISTS = frozenset({"for", "case", "select"})

#: An assignment standing in front of a command, `LC_ALL=C sort`, or standing
#: alone as the whole command, `reading=$(bounded swipl ...)`. Reading the word
#: after this prefix as the command word is what made the second shape read as
#: an unbounded swipl: the prefix swallowed `$(bounded` and `swipl` was the
#: next word. The command a `$( )` runs is inside the substitution and is read
#: there, at its own command position, with its own bound.
ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z_0-9]*(\[[^]]*\])?\+?=")

#: A redirection standing in front of the command word, `>out cmd` or
#: `2>&1 cmd`. When the operator is the whole word its target is the next one.
REDIRECTION = re.compile(r"^\d*(>>|<>|>\||<&|>&|<<-?|<|>)")

#: The door, so a line that must not be bounded says so in place rather than
#: being excluded from somewhere else. The reason is required: a marker with
#: nothing after it is a finding of its own.
OPT_OUT = re.compile(r"#\s*unbounded:\s*(?P<reason>\S.*)")


@dataclass(frozen=True, slots=True)
class _Token:
    """One word or operator of a logical line, with where it sits in it."""

    text: str
    start: int
    end: int
    operator: bool = False
    #: The source of each command substitution inside this word, in order.
    #: `$( )` and backticks only: a command inside one runs, at a command
    #: position of its own, and carries its own bound or does not.
    substitutions: tuple[str, ...] = ()


def _quoted(text: str, index: int, quote: str) -> int:
    """Just past the closing quote of the span opening at index.

    An unterminated span ends at the end of the text, which is what the shell
    itself does across a newline and what a line read on its own leaves.
    """
    index += 1
    while index < len(text):
        if text[index] == "\\" and quote != "'":
            index += 2
            continue
        if text[index] == quote:
            return index + 1
        index += 1
    return len(text)


def _double(text: str, index: int) -> int:
    """Just past the closing double quote, over the substitutions inside it.

    Inside `$( )` the quoting starts over, so `"$(dirname "$PY")"` closes at
    the LAST quote and not at the one in front of `$PY`. Reading it as three
    spans instead of one is how a substitution's own words get attributed to
    the line around it.
    """
    index += 1
    while index < len(text):
        if text[index] == "\\":
            index += 2
            continue
        if text.startswith("$(", index):
            index = _closing(text, index + 2, "(", ")")
            continue
        if text[index] == "`":
            index = _quoted(text, index, "`")
            continue
        if text[index] == '"':
            return index + 1
        index += 1
    return len(text)


def _closing(text: str, start: int, opener: str, closer: str) -> int:
    """Just past the CLOSER matching an opener the caller has consumed.

    Depth-counted and quote-aware, so `$(printf ')')` closes at the second
    paren rather than the first and `$(sh -c "cmd; cmd")` does not end at the
    semicolon inside the string.
    """
    depth = 0
    index = start
    while index < len(text):
        char = text[index]
        if char == "\\":
            index += 2
            continue
        if char == "'":
            index = _quoted(text, index, "'")
            continue
        if char == '"':
            index = _double(text, index)
            continue
        if text.startswith(opener, index):
            depth += 1
            index += len(opener)
            continue
        if text.startswith(closer, index):
            if depth == 0:
                return index + len(closer)
            depth -= 1
            index += len(closer)
            continue
        index += 1
    return len(text)


def _arithmetic(text: str, index: int) -> int:
    """Just past a `$(( ... ))`, which computes rather than running anything."""
    end = _closing(text, index + 3, "(", ")")
    return end + 1 if end < len(text) and text[end] == ")" else end


def _substitutions(text: str, *, quoted: bool = False) -> list[str]:
    """The source of every command substitution in one word.

    `quoted` says the text is the INSIDE of a double-quoted span, where a
    single quote is an ordinary character and a `$( )` still runs. Only the
    outermost substitution of each nest is answered: its source is read as a
    command list of its own, and the words in THAT are scanned again.
    """
    found: list[str] = []
    index = 0
    while index < len(text):
        char = text[index]
        if char == "\\":
            index += 2
        elif not quoted and char == "'":
            index = _quoted(text, index, "'")
        elif not quoted and char == '"':
            end = _double(text, index)
            found.extend(_substitutions(text[index + 1:max(index + 1, end - 1)],
                                        quoted=True))
            index = end
        elif text.startswith("$((", index):
            index = _arithmetic(text, index)
        elif text.startswith("$(", index):
            end = _closing(text, index + 2, "(", ")")
            found.append(text[index + 2:max(index + 2, end - 1)])
            index = end
        elif char == "`":
            end = _quoted(text, index, "`")
            found.append(text[index + 1:max(index + 1, end - 1)])
            index = end
        else:
            index += 1
    return found


def _tokens(line: str) -> list[_Token]:
    """One logical line as words and operators, with its quoting respected.

    A quoted or substituted span is part of the WORD that holds it, so the
    `;` in `sh -c 'while :; do :; done'` does not open a command position and
    the `swipl` in `$(bounded swipl ...)` is not a word of this line at all.
    """
    found: list[_Token] = []
    index = 0
    start: int | None = None

    def flush(at: int) -> None:
        nonlocal start
        if start is not None:
            text = line[start:at]
            found.append(_Token(text, start, at,
                                substitutions=tuple(_substitutions(text))))
            start = None

    while index < len(line):
        char = line[index]
        if char in " \t":
            flush(index)
            index += 1
            continue
        # A `#` opening a word comments out the rest of the line; one inside a
        # word, `sed 's/#.*//'`, is data.
        if start is None and char == "#":
            break
        symbol = next((op for op in OPERATORS if line.startswith(op, index)),
                      None)
        # An `&` that follows a redirection is part of it. `2>&1` is one word
        # and `cmd &` is two; splitting the first at the `&` left 221 phantom
        # commands headed `1` and `2` across the scanned scripts, none of them
        # a spawn but every one a word the head resolution had to answer about.
        if symbol == "&" and start is not None and line[index - 1] in "<>":
            symbol = None
        if symbol is not None:
            flush(index)
            found.append(_Token(symbol, index, index + len(symbol),
                                operator=True))
            index += len(symbol)
            continue
        if start is None:
            start = index
        if char == "\\":
            index += 2
        elif char == "'":
            index = _quoted(line, index, "'")
        elif char == '"':
            index = _double(line, index)
        elif char == "`":
            index = _quoted(line, index, "`")
        elif line.startswith("$((", index):
            index = _arithmetic(line, index)
        elif line.startswith("$(", index):
            index = _closing(line, index + 2, "(", ")")
        elif line.startswith("${", index):
            index = _closing(line, index + 2, "{", "}")
        else:
            index += 1
    flush(len(line))
    return found


def _simple_commands(line: str) -> list[list[_Token]]:
    """The line's words, split at every operator and at `{` and `}`.

    Each group is one simple command: the words a single program is started
    with, or the words of something that starts nothing.
    """
    groups: list[list[_Token]] = [[]]
    for token in _tokens(line):
        if token.operator or token.text in BLOCK:
            groups.append([])
            continue
        groups[-1].append(token)
    return [group for group in groups if group]


def _unquote(word: str) -> str:
    """The word with its quoting removed, `'$PY'` and `"$PY"` both to `$PY`.

    Only ever asked about a word that might NAME a program, so dropping every
    quote character is enough: a program name does not contain one.
    """
    return re.sub(r"\\(.)|['\"]", lambda m: m.group(1) or "", word)


def _name(word: str) -> str:
    """The last path component of a word, `"$HERE/bounded.sh"` to bounded.sh."""
    return _unquote(word).rsplit("/", 1)[-1]


def _through_command(words: list[_Token], index: int) -> int | None:
    """The word `command` runs, or None when it is only asking about one.

    `command -v swipl` asks PATH a question and starts nothing, and the check
    scripts hold fourteen of those; `command grep -v ...` in test.sh runs a
    grep. POSIX gives `command` three options and only -p leaves it running
    the operand, so the presence of -v or -V is the whole distinction.
    """
    index += 1
    while index < len(words) and words[index].text.startswith("-"):
        if set(words[index].text[1:]) & {"v", "V"}:
            return None
        index += 1
    return index if index < len(words) else None


def _head(words: list[_Token]) -> int | None:
    """The index of the word that NAMES the program this command runs.

    Assignments, redirections and the reserved words that stand in front of a
    command are stepped over. A command that is ONLY assignments names no
    program: `reading=$(bounded swipl ...)` runs its swipl inside the
    substitution, at a command position of its own, where the `bounded` in
    front of it is the command word it actually has.
    """
    index = 0
    while index < len(words):
        text = words[index].text
        if text in LEADING or ASSIGNMENT.match(text):
            index += 1
            continue
        redirection = REDIRECTION.match(text)
        if redirection:
            index += 1 if redirection.end() < len(text) else 2
            continue
        break
    if index >= len(words):
        return None
    head = _unquote(words[index].text)
    if head in WORD_LISTS:
        return None
    return _through_command(words, index) if head == "command" else index


def commands(line: str) -> list[tuple[str, tuple[str, ...], str]]:
    """Every command this line RUNS: its head, its arguments and its text.

    One line holds more than one. A pipeline, an `&&` chain, an `if` or
    `while` condition, a `for` body, a subshell and a `case` arm each open a
    command position, and a `$( )` or a backtick opens a whole command list
    whose commands are read here too. Each is judged by the head IT has, which
    is what makes `reading=$(bounded swipl ...)` bounded and
    ``bad=`swipl ...` `` not: the first names `bounded` and the second names
    `swipl`, where reading the first word after the assignment prefix called
    the one bounded command in this tree unbounded and spared the backticked
    one entirely.
    """
    found: list[tuple[str, tuple[str, ...], str]] = []
    for words in _simple_commands(line):
        for word in words:
            for inner in word.substitutions:
                found.extend(commands(inner))
        index = _head(words)
        if index is not None:
            found.append((words[index].text,
                          tuple(word.text for word in words[index + 1:]),
                          line[words[index].start:words[-1].end]))
    return found


def _bound(head: str, arguments: tuple[str, ...]) -> bool:
    """Whether this command IS the bound rather than something needing one.

    Three spellings reach the same file: the `bounded` and `in_py` helpers,
    and `sh tools/bounded.sh` written out, which is what the helpers themselves and
    every `exec` at the end of a seat's test.sh use. Only the first operand is
    read, so a bounded.sh named inside a `-g` goal or a `-c` script is not
    mistaken for the wrapper.
    """
    if _name(head) in BOUNDING or _name(head) == IMPLEMENTATION:
        return True
    operand = next((word for word in arguments if not word.startswith("-")), None)
    return operand is not None and _name(operand) == IMPLEMENTATION


def _spawner(head: str) -> bool:
    """Whether this head names a program that can outlive the script."""
    return head in SPAWNERS or _unquote(head) in SPAWNERS


def line_spawns(line: str) -> list[tuple[str, bool]]:
    """Every spawn one logical line makes, as its text and whether it is bound.

    A command that IS the bound counts as a spawn too, so a pass that stops
    recognising `bounded` reports the same findings over a smaller population
    and says so in its own count instead of reading clean.
    """
    found: list[tuple[str, bool]] = []
    for head, arguments, text in commands(line):
        bound = _bound(head, arguments)
        if bound or _spawner(head):
            found.append((text, bound))
    return found


def scripts() -> list[Path]:
    """The gate scripts, discovered the way check.sh discovers them."""
    found = [REPO / "tools" / "check.sh", REPO / "engine" / "check.sh"]
    found += sorted((REPO / "extensions").glob("*/check.sh"))
    return [p for p in found if p.is_file()]


def runners() -> list[Path]:
    """Every script a person or a lane can start a process through.

    Discovered rather than listed, so a new seat's test.sh is covered by
    existing there. bounded.sh itself is excluded because it IS the bound, and
    select-python.sh and gate_scratch.sh because they are sourced and start
    nothing.
    """
    excluded = {REPO / "tools" / "bounded.sh",
                REPO / "tools" / "select-python.sh",
                REPO / "tests" / "checks" / "gate_scratch.sh"}
    found = [
        # Derived rather than listed: the helper scripts live in tools/ and the
        # set changes, so a hand-written roster goes stale the next time one
        # arrives. The excluded set below removes the ones that start nothing.
        *sorted((REPO / "tools").glob("*.sh")),
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
    reported `bounded sh tools/bounded.sh \\` as bounded and the `"$PY" -m pytest`
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
        out.extend((number, lane, text.strip(), bound, excused)
                   for text, bound in line_spawns(line))
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
        out.extend((number, name, text.strip(), bound, excused)
                   for text, bound in line_spawns(line))
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
            if any(_name(head) == "bounded" for head, _args, _text
                   in commands(line)):
                found.append(
                    f"{name}:{number}: `bounded` is called here and defined at "
                    f"line {defined_at}, below it. A shell function that is "
                    f"not defined yet is a `not found`, which exits 127, which "
                    f"an `if ! ...` reads as the thing it was probing for "
                    f"being absent.\n    {line.strip()[:100]}\n"
                    f"    Move the definition above the first call."
                )
                break
    # The top-level driver, wherever it sits. It moved into tools/, and a
    # hard-coded root/check.sh stopped being a file, which made the check
    # below pass without looking at anything while 18 lanes went unbounded.
    # The selftest plants its own at the root of a fixture, so both are read
    # out of the list this function was already given.
    driver = next((path for path in paths
                   if path.name == "check.sh"
                   and path.parent in (root, root / "tools")),
                  root / "check.sh")
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
