"""Purpose: every closed set in the Python seat says which of three answers it stands on.

The census this gate exists for was measured on 2026-09-07: the seat carried
seventy-seven module-level tables of six or more names, and a reader could not
tell which of them were the engine's own rows restated, which were the seat's
own surface, and which were policy somebody decided. Eleven of them restated an
engine vocabulary under a Python-chosen name, one of those listed six members
where the engine derived ten, and nothing said so.

So a closed set here answers one of three questions, ADJACENT to the set, in a
`# closed-set:` line the same shape `policy-inventory-exempt:` already uses:

    # closed-set: generated; by=<generator path>; lane=<gate lane>
    # closed-set: seam; point=<point name>; reason=<what a registrant adds>
    # closed-set: decides; policy=<what this decides>; reads=<row head or none>

`generated` is a table a tool writes from the engine's rows, with the lane that
fails on drift. `seam` is a table a registrant extends, naming the point.
`decides` is a policy this seat chose, naming what it decides and the row it
reads it from -- `reads=none` where the set IS the source, which is what makes
that a decision a reader can see rather than a number in a file.

Two answers are STRUCTURAL and need no line, stated here once:

  - `__all__` is a module's own export list. It restates nothing: ruff's F822
    already holds it to the names the module defines, and a per-module
    annotation of that would say nothing this sentence does not.
  - every table inside an output the artifact manifest declares
    (extensions/python/tools/artifacts.py) is generated: a whole-file output
    covers its file and a region output covers the tables between its
    markers. The manifest is what names the generator and the lane, so a
    generated table needs no line and nothing is read from a header's prose,
    which is how `__init__.py`'s `__lazy_exports__` went reported for a
    spelling the header did not use.

Assumes:
  - the census is the same AST scan the ledger measured with: a module-level
    assignment whose value is a tuple, list, set, dict or a `frozenset(...)`
    call holding six or more string literals
  - the artifact manifest's declared outputs are the one record of what is
    generated, and a region it declares can be located in the tree, which
    the generated-artifacts lane holds
Guarantees:
  - a closed set with no answer is reported with its path, line and name, and
    a malformed or unknown answer is reported as itself [tested:
    tests/checks/check_closed_sets_selftest.py; commit=c26b6a4d28ef8fb50742440feed2c0578ebb0f58]
  - a `generated` answer names a generator that exists and a lane check.sh
    runs; a `seam` answer names a point the seam declares; a `decides` answer
    names a policy and either a catalog row head or `none`
    [tested: tests/checks/check_closed_sets_selftest.py; commit=c26b6a4d28ef8fb50742440feed2c0578ebb0f58]
  - a public `str` parameter whose default is a member of a generated
    vocabulary is reported: the parameter's type is the vocabulary's enum,
    which still accepts the plain word [tested:
    tests/checks/check_closed_sets_selftest.py; commit=c26b6a4d28ef8fb50742440feed2c0578ebb0f58]
  - a table inside a declared whole-file or region output is not asked, a
    table outside the region is, and a declared region the tree cannot
    locate is reported as itself [tested:
    test_a_table_inside_a_declared_output_is_generated,
    test_a_table_outside_a_declared_region_is_still_asked,
    test_a_declared_region_the_tree_cannot_locate_is_reported;
    commit=e492f2a5bb995b6c2b86bdeb90cb1d2f27282b07]
Fails when:
  - read as a count. The number of closed sets is not a score; a policy this
    seat decides is a closed set and should stay one, and its line is what
    makes it visible.
Decides:
  - six string literals is the threshold, which is the ledger's own census
    scan; below it a table is a local detail rather than a vocabulary
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import ast
import re
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))

from evidence_runners import gate_scripts  # noqa: E402  -- installed above
from gate_layout import CHECK as _CHECK  # noqa: E402  -- installed above
from gate_layout import LANE_PREFIX  # noqa: E402  -- installed above

sys.path.insert(0, str(ROOT / "extensions/python/tools"))
from artifacts import ARTIFACTS  # noqa: E402 -- a checkout tool, imported once the root is known

PACKAGE = Path("extensions/python/metta")
CHECK = ROOT / _CHECK
SEAM = ROOT / PACKAGE / "seam.py"

#: The ledger's own census threshold.
THRESHOLD = 6

#: A module's own export list, which restates nothing.
STRUCTURAL_NAMES = frozenset({"__all__"})

MARKER = "closed-set:"
#: The same shape for the other rule: a public `str` parameter whose default is
#: a vocabulary member, where the enum cannot be the annotation.
PARAMETER_MARKER = "enum-parameter:"
PARAMETER_ANSWER = re.compile(
    r"^\s*#\s*enum-parameter:\s*enum=(?P<enum>\w+);\s*reason=(?P<reason>.+?)\s*$"
)
ANSWER = re.compile(
    r"^\s*#\s*closed-set:\s*(?P<kind>generated|seam|decides);\s*(?P<fields>.+?)\s*$"
)
FIELD = re.compile(r"(?P<name>[a-z]+)=(?P<value>[^;]+)")

#: The containers the census counts, which is the ledger's own scan.
_CONTAINERS = (ast.Tuple, ast.List, ast.Set, ast.Dict)
_CONTAINER_CALLS = frozenset({"frozenset", "set", "tuple", "list", "dict", "MappingProxyType"})


@dataclass(frozen=True)
class ClosedSet:
    """One module-level closed set, and where it is."""

    path: Path
    line: int
    name: str
    strings: int


def _strings(node: ast.AST) -> int:
    """How many string literals one value holds, at any depth."""
    return sum(
        1
        for child in ast.walk(node)
        if isinstance(child, ast.Constant) and isinstance(child.value, str)
    )


def closed_sets(text: str, path: Path) -> list[ClosedSet]:
    """Every module-level closed set in one file."""
    tree = ast.parse(text, filename=str(path))
    found: list[ClosedSet] = []
    for node in tree.body:
        if not isinstance(node, (ast.Assign, ast.AnnAssign)):
            continue
        value = node.value
        targets = node.targets if isinstance(node, ast.Assign) else [node.target]
        names = [target.id for target in targets if isinstance(target, ast.Name)]
        if not names or value is None:
            continue
        holder = isinstance(value, _CONTAINERS)
        if isinstance(value, ast.Call):
            called = getattr(value.func, "id", None) or getattr(value.func, "attr", None)
            holder = holder or called in _CONTAINER_CALLS
        if not holder:
            continue
        count = _strings(value)
        if count >= THRESHOLD:
            found.append(ClosedSet(path, node.lineno, names[0], count))
    return found


def _answer_above(lines: list[str], line: int) -> str | None:
    """The `closed-set:` line adjacent to one set, if there is one.

    Adjacent means the comment block immediately above it: a set whose value
    spans several lines is annotated above the assignment, and a `#:` doc
    comment may sit between, because that is where the set's own prose goes.
    """
    index = line - 2
    while index >= 0:
        text = lines[index].strip()
        if MARKER in text:
            return lines[index]
        if text.startswith(("#", "@")) or not text:
            index -= 1
            continue
        return None
    return None


def _lane_names() -> set[str]:
    """Every lane the umbrella and its component scripts register."""
    return {
        name
        for script in gate_scripts()
        for name in re.findall(
            LANE_PREFIX + r"(?:GATE|REPORT)\s+(\S+)", script.read_text(encoding="utf-8"), re.MULTILINE
        )
    }


def _seam_points() -> set[str]:
    """Every point the seam declares, read from its source.

    Read rather than imported, because this lane walks source and a point
    declared in a module the seam loads lazily would otherwise need an engine.
    """
    names: set[str] = set()
    for path in sorted((ROOT / PACKAGE).glob("*.py")):
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
        for call in (node for node in ast.walk(tree) if isinstance(node, ast.Call)):
            called = getattr(call.func, "id", None) or getattr(call.func, "attr", None)
            if called not in {"point", "service"} or not call.args:
                continue
            first = call.args[0]
            if isinstance(first, ast.Constant) and isinstance(first.value, str):
                names.add(first.value)
    return names


def validate_answer(
    line: str, *, lanes: set[str], points: set[str], root: Path
) -> str | None:
    """What is wrong with one `closed-set:` answer, or None."""
    match = ANSWER.match(line)
    if match is None:
        return (
            "malformed answer; expected 'closed-set: generated; by=<path>; "
            "lane=<lane>', 'closed-set: seam; point=<name>; reason=<text>' or "
            "'closed-set: decides; policy=<text>; reads=<row head or none>'"
        )
    kind = match.group("kind")
    fields = {
        found.group("name"): found.group("value").strip()
        for found in FIELD.finditer(match.group("fields"))
    }
    required = {
        "generated": ("by", "lane"),
        "seam": ("point", "reason"),
        "decides": ("policy", "reads"),
    }[kind]
    missing = [name for name in required if not fields.get(name)]
    if missing:
        return f"a {kind} answer needs {', '.join(missing)}"
    if kind == "generated":
        if not (root / fields["by"]).is_file():
            return f"the generator {fields['by']} does not exist"
        if fields["lane"] not in lanes:
            return f"check.sh runs no lane named {fields['lane']}"
    if kind == "seam" and fields["point"] not in points:
        return f"the seam declares no point named {fields['point']}"
    return None


Owned = dict[Path, tuple[tuple[int, int], ...]]


def generated_spans(root: Path) -> tuple[Owned, list[str]]:
    """Every line range a manifest artifact owns under this root, by file,
    and every declared region the tree cannot locate.

    A whole-file output owns its file; a region output owns the lines between
    its markers. Only Python outputs matter here, since that is all the
    census reads.
    """  # noqa: D205  -- the API contract is one continuous invariant, not summary-and-body prose
    owned: dict[Path, list[tuple[int, int]]] = {}
    problems: list[str] = []
    for artifact in ARTIFACTS:
        for output in artifact.outputs:
            for path in output.paths(root):
                if path.suffix != ".py":
                    continue
                text = path.read_text(encoding="utf-8")
                try:
                    start, end = output.span(text)
                except ValueError as error:
                    problems.append(f"{path.relative_to(root)}: {error}")
                    continue
                first = text.count("\n", 0, start) + 1
                last = text.count("\n", 0, end) + 1
                owned.setdefault(path.relative_to(root), []).append((first, last))
    return {path: tuple(ranges) for path, ranges in owned.items()}, problems


def _generated(owned: Owned, path: Path, line: int) -> bool:
    """Whether one line of one file sits inside an interval the manifest owns."""
    return any(first <= line <= last for first, last in owned.get(path, ()))


def scan_closed_sets(root: Path, owned: Owned | None = None) -> list[str]:
    """Report every closed set with no answer, and every bad answer."""
    package = root / PACKAGE
    if not package.is_dir():
        return [f"{PACKAGE}: the Python package is missing"]
    lanes = _lane_names() if CHECK.is_file() else set()
    points = _seam_points()
    if owned is None:
        owned, findings = generated_spans(root)
    else:
        findings = []
    for path in sorted(package.rglob("*.py")):
        relative = path.relative_to(root)
        text = path.read_text(encoding="utf-8")
        lines = text.splitlines()
        for found in closed_sets(text, relative):
            if found.name in STRUCTURAL_NAMES or _generated(owned, relative, found.line):
                continue
            answer = _answer_above(lines, found.line)
            if answer is None:
                findings.append(
                    f"{relative}:{found.line}: the closed set {found.name} "
                    f"({found.strings} names) says none of the three answers; "
                    f"add a `# closed-set: generated|seam|decides; ...` line "
                    f"above it"
                )
                continue
            problem = validate_answer(answer, lanes=lanes, points=points, root=root)
            if problem is not None:
                findings.append(f"{relative}:{found.line}: {found.name}: {problem}")
    return findings


def scan_string_parameters(
    root: Path, members: dict[str, set[str]], owned: Owned | None = None
) -> list[str]:
    """Report a public `str` parameter whose default is a vocabulary member.

    The parameter's type is that vocabulary's enum. A StrEnum member IS its
    word, so every caller that passed the plain string still passes; what
    changes is that the admitted set is now in the signature instead of in the
    prose beside it.
    """
    package = root / PACKAGE
    if owned is None:
        owned, _ = generated_spans(root)
    findings: list[str] = []
    for path in sorted(package.rglob("*.py")):
        relative = path.relative_to(root)
        text = path.read_text(encoding="utf-8")
        tree = ast.parse(text, filename=str(relative))
        for node in ast.walk(tree):
            if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                continue
            if _generated(owned, relative, node.lineno):
                continue
            arguments = node.args
            # Positional defaults align with the LAST parameters, and a
            # positional-only parameter is one of them, so the two lists are
            # zipped from the right.
            positional = [*arguments.posonlyargs, *arguments.args]
            named = [argument.arg for argument in positional[len(positional) - len(arguments.defaults) :]]
            defaults = dict(zip(named, arguments.defaults, strict=True))
            defaults.update(
                {
                    argument.arg: default
                    for argument, default in zip(
                        arguments.kwonlyargs, arguments.kw_defaults, strict=True
                    )
                    if default is not None
                }
            )
            if node.name.startswith("_"):
                # The rule is about a PUBLIC signature: an enum in a private
                # helper's annotation buys the caller nothing, and the two
                # modules below the vocabulary layer cannot import it at all.
                continue
            for argument in [*arguments.args, *arguments.kwonlyargs]:
                annotation = argument.annotation
                if annotation is None or ast.unparse(annotation) != "str":
                    continue
                default = defaults.get(argument.arg)
                if not (isinstance(default, ast.Constant) and isinstance(default.value, str)):
                    continue
                owners = sorted(
                    name for name, values in members.items() if default.value in values
                )
                if not owners:
                    continue
                excuse = _parameter_answer(text.splitlines(), node.lineno)
                if excuse is not None:
                    problem = _validate_parameter(excuse, members)
                    if problem is not None:
                        findings.append(
                            f"{relative}:{node.lineno}: {node.name}"
                            f"({argument.arg}=): {problem}"
                        )
                    continue
                findings.append(
                    f"{relative}:{node.lineno}: {node.name}({argument.arg}=) "
                    f"is typed str and defaults to {default.value!r}, which "
                    f"is a member of {', '.join(owners)}; the parameter's "
                    f"type is that enum, which still accepts the word. Where "
                    f"it cannot be, say so with an adjacent "
                    f"`# enum-parameter: enum=<name>; reason=<why>`"
                )
    return findings


def _parameter_answer(lines: list[str], line: int) -> str | None:
    """The `enum-parameter:` line above one signature, if there is one."""
    index = line - 2
    while index >= 0:
        text = lines[index].strip()
        if PARAMETER_MARKER in text:
            return lines[index]
        if text.startswith(("#", "@")) or not text:
            index -= 1
            continue
        return None
    return None


def _validate_parameter(line: str, members: dict[str, set[str]]) -> str | None:
    """What is wrong with one `enum-parameter:` answer, or None."""
    match = PARAMETER_ANSWER.match(line)
    if match is None:
        return (
            "malformed answer; expected "
            "'enum-parameter: enum=<name>; reason=<why the annotation is text>'"
        )
    if match.group("enum") not in members:
        return f"no generated vocabulary is named {match.group('enum')}"
    return None


def vocabulary_members(root: Path) -> dict[str, set[str]]:
    """Every generated vocabulary's members, read from the generated module."""
    path = root / PACKAGE / "vocabularies.py"
    if not path.is_file():
        return {}
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    found: dict[str, set[str]] = {}
    for node in tree.body:
        if not isinstance(node, ast.ClassDef) or node.name.startswith("_"):
            continue
        values = {
            statement.value.value
            for statement in node.body
            if isinstance(statement, ast.Assign)
            and isinstance(statement.value, ast.Constant)
            and isinstance(statement.value.value, str)
        }
        if values:
            found[node.name] = values
    return found


def main() -> int:
    """Print the census and fail on any set with no answer."""
    findings = scan_closed_sets(ROOT)
    findings.extend(scan_string_parameters(ROOT, vocabulary_members(ROOT)))
    counted = sum(
        1
        for path in sorted((ROOT / PACKAGE).rglob("*.py"))
        for found in closed_sets(path.read_text(encoding="utf-8"), path)
        if found.name not in STRUCTURAL_NAMES
    )
    for finding in findings:
        print(finding)
    print(f"closed sets: {counted} in the seat, {len(findings)} finding(s)")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
