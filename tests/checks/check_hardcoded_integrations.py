"""Purpose: refuse a third-party library named ANYWHERE in a seat's own sources.

A seat that asks "is this pandas?" in a branch cannot be extended by a second
frame library without an edit here, which is a fork. A seat that holds one ROW
per library, against a point it declared, can. Until 2026-09-08 this pass drew
that line at a REGISTRANT MODULE: a library could be named there and nowhere
else, and the table below carried one entry per library saying so. The ruling
that day removed the exception. pymetta ships zero integrations; every library
the Python seat can be extended by is its own distribution under
`extensions/python/ext/`, found through the `metta.extensions` entry-point
group exactly as a stranger's package is, and there is no site in the core
where a library may be named at all.

So ALLOWED holds DEPENDENCIES only, and a dependency is not an integration:
each is this seat's own implementation of a service the seat itself provides,
its class has one member by construction, and there is no second library to be
shut out. Every entry carries the sentence that says why in one line. An entry
for an integration is the smell wearing a uniform, and the whole point of this
pass after the ruling is that no such entry can be added: a new frame library,
array library, SQL engine or transport registers from its own distribution and
needs no line here, so a request to add one is a request to un-build the seam.

The names are DERIVED rather than listed. For each seat the pass reads what the
seat's own sources reach for: a Python import of a module that is neither the
standard library nor this repository's own, and a module name handed to one of
the four probes that import by name (`optional_module`, `require_module`,
`importlib.import_module`, `sys.modules.get`); a TypeScript import specifier
that is neither relative nor `node:`; a C `#include` of a header that is
neither the C standard library nor this seat's own. A new library therefore
needs no entry here to be seen.

The seat's own sources are its CORE. An extension package under `ext/` is a
distribution of its own and names its library on purpose -- that is what it is
for -- so the Python seat's scan is `extensions/python/metta/` and nothing
under `ext/`, which `tests/checks/check_layering.py` holds to its own rule: a
member names ONE library, and reaches the core only through public names.

Prose is not a finding. A docstring saying polars reads `iter_rows` faster than
the stream is a MEASUREMENT, and deleting it would delete the measurement; a
refusal sentence naming DuckDB belongs to DuckDB's own row. The Python scan
reads the syntax tree, so a name in a comment or a docstring is invisible to
it by construction; the TypeScript and C scans strip comments before matching.

Assumes: a checkout of this repository, and Python 3.10+ for
  sys.stdlib_module_names.
Guarantees:
  - a library named anywhere in a seat's core is reported with its path, its
    line and what to do instead, with no allowlist that could admit it
    [tested: tests/checks/check_hardcoded_integrations_selftest.py;
    commit=WORKTREE]
  - an ALLOWED entry whose site no longer names its library is reported, so
    the table shrinks with the code [tested:
    tests/checks/check_hardcoded_integrations_selftest.py; commit=WORKTREE]
  - a name in a comment, a docstring or a string that is not a module name is
    NOT a finding [tested:
    tests/checks/check_hardcoded_integrations_selftest.py; commit=WORKTREE]
  - a planted `import pandas` in the core is refused, which is the ruling this
    pass exists for [tested:
    tests/checks/check_hardcoded_integrations_selftest.py; commit=WORKTREE]
Fails when: a seat's sources are absent, which it reports rather than passing
  on an empty file list.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import ast
import re
import sys
from pathlib import Path
from typing import NamedTuple

ROOT = Path(__file__).resolve().parents[2]

#: This repository's own top-level names, which are never third-party: the
#: package itself, the workspace-path helper the checkout uses to reach its own
#: extension distributions, and the selftest's fixture name.
OURS = frozenset({"metta", "_workspace", "solars_selftest"})

#: The calls that import a module named as TEXT. A string literal reaching one
#: of these is a module name however it was spelled, which is the whole reason
#: the scan cannot stop at import statements: `optional_module("faiss")` is a
#: coupling and carries no import. Each is matched with its RECEIVER, because
#: `.get("something")` on a dict is not a module probe and there are thousands
#: of those.
PROBES = frozenset({"optional_module", "require_module", "import_module"})
RECEIVED_PROBES = frozenset(
    {("sys.modules", "get"), ("importlib", "import_module"), ("importlib.util", "find_spec")}
)

#: Headers the C seat may include: the C standard library, and SWI's own,
#: which IS the engine this seat embeds rather than a library it integrates.
C_HEADERS = frozenset(
    {
        "assert.h", "ctype.h", "errno.h", "float.h", "inttypes.h", "limits.h",
        "locale.h", "math.h", "setjmp.h", "signal.h", "stdarg.h", "stdbool.h",
        "stddef.h", "stdint.h", "stdio.h", "stdlib.h", "string.h", "time.h",
        "wchar.h", "wctype.h", "stdatomic.h", "threads.h", "dlfcn.h",
        "pthread.h", "unistd.h", "sys/types.h", "sys/stat.h", "fcntl.h",
        "SWI-Prolog.h", "SWI-Stream.h",
    }
)

#: Node specifiers that are the seat's own substrate rather than a library it
#: integrates with: the engine it mounts, and the parser its own lowering uses.
NODE_SUBSTRATE = frozenset({"swipl-wasm", "acorn", "node:test", "vitest"})


class Site(NamedTuple):
    """Where a library may be named, and the door it registers through.

    `paths` is a tuple because a DEPENDENCY, as opposed to an integration, is
    used where it is needed: pytest is in three compliance kits and rich in two
    renderers, and pretending otherwise would mean a wrapper module whose only
    job is to satisfy this pass.
    """

    paths: tuple[str, ...]
    door: str


#: Every library a seat's CORE may name, with the sentence that says why. There
#: is no integration category: an integration is a distribution of its own, and
#: an entry here for one would be the coupling this pass exists to refuse.
ALLOWED: dict[tuple[str, str], Site] = {
    # The engine this seat embeds. Not an integration: it IS the runtime, and
    # a second Prolog bridge is a different seat rather than a second row.
    ("python", "janus_swi"): Site(
        ("extensions/python/metta/_engine.py",), "the engine this seat embeds"
    ),
    # The seat's own tooling, each written in the library named. A test
    # framework, a property-testing framework, a terminal renderer, a docstring
    # reader, a highlighter and a notebook shell are not data or compute
    # libraries a program would swap: they are what these files ARE.
    ("python", "hypothesis"): Site(
        (
            "extensions/python/metta/testing.py",
            "extensions/python/metta/_space_machine.py",
        ),
        "the property-testing framework this seat's own generators are written in",
    ),
    ("python", "annotated_types"): Site(
        (
            "extensions/python/metta/testing.py",
            "extensions/python/metta/_refinements.py",
        ),
        "the refinement vocabulary the engine's own Len and Ge annotations use",
    ),
    ("python", "pytest"): Site(
        (
            "extensions/python/metta/_compliance.py",
            "extensions/python/metta/_gateway_compliance.py",
            "extensions/python/metta/pytest_plugin.py",
        ),
        "the test framework this seat ships fixtures and compliance kits for",
    ),
    ("python", "rich"): Site(
        (
            "extensions/python/metta/library.py",
            "extensions/python/metta/results.py",
        ),
        "the terminal renderer these two doors offer as an optional face",
    ),
    ("python", "docstring_parser"): Site(
        ("extensions/python/metta/_documentation.py",),
        "the docstring reader this seat's own documentation door uses",
    ),
    ("python", "pygments"): Site(
        ("extensions/python/metta/_pygments.py",),
        "the highlighter this seat generates a lexer for from its own grammar",
    ),
    ("python", "IPython"): Site(
        ("extensions/python/metta/ipython.py",),
        "the notebook surface this seat ships",
    ),
}

#: What an entry here may NOT be. A dependency is the seat's own tooling or the
#: engine it embeds; anything a program would choose between -- a frame
#: library, an array library, a SQL engine, a vector index, a transport, a
#: serialization framework, an observability API -- is an INTEGRATION and
#: reaches the seat as a distribution of its own. Refusing the addition here is
#: the whole of what the 2026-09-08 ruling changed.
NOT_A_DEPENDENCY = (
    "an integration reaches a seat as its own distribution, registering a row "
    "against a declared point; it is never a line in this table"
)


class Finding(NamedTuple):
    """One library named where no registration puts it."""

    seat: str
    library: str
    path: str
    line: int
    reason: str

    def __str__(self) -> str:
        """The path, the line and what to do instead."""
        return f"{self.path}:{self.line}: {self.reason}"


def _python_sources(seat_root: Path) -> list[Path]:
    return sorted(path for path in seat_root.rglob("*.py") if "__pycache__" not in path.parts)


def _third_party(name: str) -> str | None:
    """The top-level distribution a dotted module name belongs to, or None."""
    top = name.partition(".")[0]
    if not top or top in OURS or top in sys.stdlib_module_names:
        return None
    return top


def _python_names(path: Path) -> list[tuple[str, int]]:
    """Every third-party module name this file reaches for, with its line.

    The syntax tree, not the text: a name in a comment or a docstring is not a
    node, so prose is invisible here by construction rather than by an
    exception list.
    """
    found: list[tuple[str, int]] = []
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                name = _third_party(alias.name)
                if name is not None:
                    found.append((name, node.lineno))
        elif isinstance(node, ast.ImportFrom) and node.level == 0 and node.module:
            name = _third_party(node.module)
            if name is not None:
                found.append((name, node.lineno))
        elif isinstance(node, ast.Call) and _registers(node.func):
            for keyword in node.keywords:
                if keyword.arg == "module" and isinstance(keyword.value, ast.Constant):
                    name = _third_party(str(keyword.value.value))
                    if name is not None:
                        found.append((name, node.lineno))
        elif isinstance(node, ast.Call) and node.args and _is_probe(node.func):
            first = node.args[0]
            if isinstance(first, ast.Constant) and isinstance(first.value, str):
                name = _third_party(first.value)
                if name is not None:
                    found.append((name, node.lineno))
    return found


def _registers(func: ast.expr) -> bool:
    """Whether this call is a seam registration, whose `module=` names one.

    A row holds the module NAME rather than importing it, which is what keeps
    `import metta.tables` at 15 ms; no probe sees that string, so the scan has
    to read it where it is written or the registrant file would look as though
    it named nothing.
    """
    return isinstance(func, ast.Attribute) and func.attr == "register"


def _dotted(node: ast.expr) -> str:
    """The dotted spelling of an attribute chain, or "" for anything else."""
    if isinstance(node, ast.Name):
        return node.id
    if isinstance(node, ast.Attribute):
        base = _dotted(node.value)
        return f"{base}.{node.attr}" if base else ""
    return ""


def _is_probe(func: ast.expr) -> bool:
    """Whether this call imports a module named as text."""
    if isinstance(func, ast.Name):
        return func.id in PROBES
    if isinstance(func, ast.Attribute):
        if func.attr in PROBES and not _dotted(func.value):
            return True
        return (_dotted(func.value), func.attr) in RECEIVED_PROBES
    return False


_BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.DOTALL)
_LINE_COMMENT = re.compile(r"//[^\n]*")
_SPECIFIER = re.compile(r"""(?:from|import|require)\s*\(?\s*["']([^"'\n]+)["']""")


def _node_names(path: Path) -> list[tuple[str, int]]:
    """Every package a TypeScript file imports, with its line.

    Comments are stripped first, so a specifier written in prose is not a
    finding, and a relative or `node:` specifier is the seat's own code or the
    platform's rather than a library.
    """
    text = path.read_text(encoding="utf-8")
    stripped = _LINE_COMMENT.sub("", _BLOCK_COMMENT.sub(lambda m: "\n" * m.group().count("\n"), text))
    found = []
    for match in _SPECIFIER.finditer(stripped):
        specifier = match.group(1)
        if specifier.startswith((".", "node:", "#")):
            continue
        package = specifier.split("/")[0]
        if specifier.startswith("@"):
            package = "/".join(specifier.split("/")[:2])
        if package in NODE_SUBSTRATE or specifier in NODE_SUBSTRATE:
            continue
        found.append((package, stripped.count("\n", 0, match.start()) + 1))
    return found


_INCLUDE = re.compile(r'^\s*#\s*include\s*[<"]([^>"]+)[>"]', re.MULTILINE)


def _c_names(path: Path) -> list[tuple[str, int]]:
    """Every header a C file includes that is neither standard nor its own."""
    text = _LINE_COMMENT.sub(
        "", _BLOCK_COMMENT.sub(lambda m: "\n" * m.group().count("\n"), path.read_text(encoding="utf-8"))
    )
    found = []
    for match in _INCLUDE.finditer(text):
        header = match.group(1)
        if header in C_HEADERS or (path.parent / header).exists():
            continue
        found.append((header, text.count("\n", 0, match.start()) + 1))
    return found


def _seat_findings(seat: str, sources: list[Path], names) -> list[Finding]:
    findings = []
    for path in sources:
        relative = path.relative_to(ROOT).as_posix()
        for library, line in names(path):
            site = ALLOWED.get((seat, library))
            if site is None:
                findings.append(
                    Finding(
                        seat,
                        library,
                        relative,
                        line,
                        f"the {seat} seat's core names {library!r} here; "
                        f"{NOT_A_DEPENDENCY}. Move this to a package under "
                        f"extensions/python/ext/ that depends on "
                        f"{library!r} and registers a ROW against a declared "
                        f"point, the way every library this repository ships "
                        f"already arrives",
                    )
                )
            elif relative not in site.paths:
                findings.append(
                    Finding(
                        seat,
                        library,
                        relative,
                        line,
                        f"{library!r} belongs to {', '.join(site.paths)} "
                        f"through {site.door}; naming it here puts it in a "
                        f"branch again, which is the shape a second library "
                        f"of its kind cannot reach",
                    )
                )
    return findings


def _stale(seen: set[tuple[str, str]]) -> list[Finding]:
    """ALLOWED entries whose site no longer names their library."""
    return [
        Finding(
            seat,
            library,
            site.paths[0],
            0,
            f"ALLOWED says {library!r} is reached from "
            f"{', '.join(site.paths)} through {site.door}, and nothing there "
            f"names it any more; remove the entry",
        )
        for (seat, library), site in sorted(ALLOWED.items())
        if (seat, library) not in seen
    ]


def findings() -> list[Finding]:
    """Every library named outside its registration, and every stale entry."""
    seats = (
        ("python", _python_sources(ROOT / "extensions" / "python" / "metta"), _python_names),
        ("node", sorted((ROOT / "extensions" / "node" / "src").rglob("*.ts")), _node_names),
        (
            "cmetta",
            sorted((ROOT / "extensions" / "cmetta").glob("*.c"))
            + sorted((ROOT / "extensions" / "cmetta").glob("*.h")),
            _c_names,
        ),
    )
    found: list[Finding] = []
    seen: set[tuple[str, str]] = set()
    for seat, sources, names in seats:
        if not sources:
            message = f"the {seat} seat has no sources under {ROOT}"
            raise SystemExit(message)
        for path in sources:
            for library, _line in names(path):
                seen.add((seat, library))
        found.extend(_seat_findings(seat, sources, names))
    return found + _stale(seen)


def main() -> int:
    """Report every finding, exiting nonzero when there is one."""
    reported = findings()
    for finding in reported:
        print(finding)
    if reported:
        print(f"{len(reported)} hardcoded integration(s)")
        return 1
    print("no hardcoded integrations: no seat's core names a library it did not embed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
