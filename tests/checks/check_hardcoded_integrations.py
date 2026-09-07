"""Purpose: refuse a third-party library named anywhere but its own registration.

A seat that asks "is this pandas?" in a branch cannot be extended by a second
frame library without an edit here, which is a fork. A seat that holds one ROW
per library, against a point it declared, can: the shipped library is the first
registrant and a stranger's is the second. This pass is what keeps the second
shape from decaying into the first, so `EXTENDING.md`'s promise stays true for
the seats and not only for the engine.

The names are DERIVED rather than listed. For each seat the pass reads what the
seat's own sources reach for: a Python import of a module that is neither the
standard library nor this package, and a module name handed to one of the four
probes that import by name (`optional_module`, `require_module`,
`importlib.import_module`, `sys.modules.get`); a TypeScript import specifier
that is neither relative nor `node:`; a C `#include` of a header that is
neither the C standard library nor this seat's own. A new library therefore
needs no entry here to be seen.

What each seat DOES need is one line in ALLOWED per library, naming the file
the registration lives in and the door it registers through. That line is the
review: adding one is a deliberate act, and the pass reports an entry whose
file no longer names the library, so the table cannot rot into a list of names
nobody registers any more.

Prose is not a finding. A docstring saying polars reads `iter_rows` faster than
the stream is a MEASUREMENT, and deleting it would delete the measurement; a
refusal sentence naming DuckDB belongs to DuckDB's own row. The Python scan
reads the syntax tree, so a name in a comment or a docstring is invisible to
it by construction; the TypeScript and C scans strip comments before matching.

Assumes: a checkout of this repository, and Python 3.10+ for
  sys.stdlib_module_names.
Guarantees:
  - a library named outside its declared registration site is reported with
    its path, its line and the door it should have used [tested:
    tests/checks/check_hardcoded_integrations_selftest.py; commit=50fc21b0179082d6aca1ac5fe2223d47baa2d828]
  - an ALLOWED entry whose site no longer names its library is reported, so
    the table shrinks with the code [tested:
    tests/checks/check_hardcoded_integrations_selftest.py; commit=50fc21b0179082d6aca1ac5fe2223d47baa2d828]
  - a name in a comment, a docstring or a string that is not a module name is
    NOT a finding [tested:
    tests/checks/check_hardcoded_integrations_selftest.py; commit=50fc21b0179082d6aca1ac5fe2223d47baa2d828]
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

#: This package's own top-level names, which are never third-party.
OURS = frozenset({"metta", "solars_selftest"})

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


#: One entry per library a seat knows, naming the ONE file its registration
#: lives in and the point it registers against. Anything else is a finding.
#: Reviewing an addition here is reviewing a new coupling, which is the point.
REGISTRANTS = ("extensions/python/metta/_registrants.py",)

ALLOWED: dict[tuple[str, str], Site] = {
    # INTEGRATIONS. Each is one row against one declared point, and the file
    # they share is the seat's registrant module. A second library of any of
    # these kinds needs no line here at all: it registers from its own package.
    ("python", "pandas"): Site(REGISTRANTS, "metta.seam.frame"),
    ("python", "polars"): Site(REGISTRANTS, "metta.seam.frame"),
    ("python", "duckdb"): Site(REGISTRANTS, "metta.seam.sql"),
    ("python", "numpy"): Site(REGISTRANTS, "metta.seam.array"),
    ("python", "faiss"): Site(REGISTRANTS, "metta.seam.index"),
    ("python", "nanoarrow"): Site(REGISTRANTS, "metta.seam.arrow"),
    ("python", "websocket"): Site(REGISTRANTS, "metta.seam.transport_error"),
    ("python", "pydantic"): Site(REGISTRANTS, "metta.seam.image"),
    # DEPENDENCIES. Not integrations: each is this seat's own implementation of
    # a service the seat itself provides, and its class has one member by
    # construction, so there is no second library to be shut out.
    ("python", "janus_swi"): Site(
        ("extensions/python/metta/_engine.py",), "the engine this seat embeds"
    ),
    ("python", "array_api_compat"): Site(
        ("extensions/python/metta/arrays.py",),
        "the Array API standard's own compatibility layer, which has one member",
    ),
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
                        f"the {seat} seat names {library!r} here and nothing "
                        f"registers it; a library reaches this seat as a ROW "
                        f"against a declared point, so register it in the "
                        f"seat's registrant file and add its line to ALLOWED "
                        f"naming the door",
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
    print("no hardcoded integrations: every library name is a registration")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
