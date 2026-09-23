"""Purpose: refuse a hand-counted walk to a checkout root in the Python seat.

`Path(__file__).resolve().parents[N]` is a literal count of the directory levels
between one file and a root. It is silent when it is wrong: the path simply names
somewhere that does not exist, and what fails is whatever reads it, far from the
cause. Moving a file changes its depth, and the many-repo split moved a great many:
the count went from 96 occurrences to 243 across 203 files at six different depths,
of which 167 resolved to just two directories under ten different names
[measured 2026-09-19].

`metta._roots` replaced them by DERIVING both: `seat()` is the nearest ancestor
holding a `pyproject.toml` or a `.git`, `workspace()` the nearest holding both
`engine/` and `lib/`. A file that cannot import it, because its walk exists to put
the seat on `sys.path` in the first place, writes the derivation inline instead,
which is the same rule spelled out rather than a number.

So this refuses a count that reaches a ROOT, meaning the seat or anything above it.
A count landing INSIDE the seat is a different thing and is left alone: a module
naming a file in a sibling package, `parents[1] / "_binding" / "door_catalog.pl"`,
is package-relative and travels with the package rather than with the checkout. The
rule is computed from where the count lands rather than from how large it is,
because a depth threshold would be a guess at the same question.

Where a count starts and lands is found by EVALUATING it, never by matching how it
is spelled. Every upward step in a file, `B.parents[N]`, a chain of `.parent`, an
`os.path.dirname` chain, is evaluated over the module's path imports and top-level
bindings, with `metta._roots` as the checked seat ships it, so `parents[2]`,
`.parent.parent.parent`, a base without `.resolve()`, a base reached through a name
and a base that is `seat()` all land where they land. A count is a step that
crosses the seat's boundary upward: it starts at or inside the seat, where the
layout is this repository's, and lands on the seat or above it. `seat().parents[1]`
is therefore a count, the seat's depth in the workspace written as a number, and
`workspace().parent` is not, since it starts above the seat and leaves the checkout
rather than counting a level of it. A matcher for the one spelling
`Path(__file__).resolve().parents[N]` let sixteen counts through [measured
2026-09-24: `.parent.parent` at benchmarks/axes.py:189, `Path(__file__).parents[N]`
three times in two tests, `TOOLS.parents[2]` in four tools and `SEAT.parents[1]` in
`_workspace.py`, `seat().parents[1]` or a path under the seat counted up in five
places, and `CORE.parent` in two]. The one landing
exempt is the file's own directory: it moves with the file, so no move can make it
wrong, and a count of zero levels is not a count.

The derivation is checked too, and by its RESULT rather than its spelling. Checking
the marker cannot work: `.git` is a correct seat marker and was still the wrong one
at 29 sites, because every submodule this superproject mounts has a `.git` of its
own, so a walk looking for that marker stops at the nearest component instead of
reaching the tree that holds `engine/` and `lib/`. What separates a right root from a
wrong one is the only thing that must differ: the path it goes on to name. A module
binding `ROOT = <derivation>` and then `SEAT = ROOT / "extensions/python"` names
`extensions/python/extensions/python` under the wrong root, and nothing on disk
answers to that. So the bindings built from a walk are carried forward and each
resulting path must exist. A path under `ai-tmp/` is exempt because that is this
repository's scratch, written by the program rather than read by it [measured
2026-09-19: 72 path bindings in files that walk, 71 naming a real path and the one
exception a probe's own output]. A path built from the file's own directory is not
checked at all, because no walk built it: package data present only in a built
wheel, like `metta/_host`'s SWI home and vendored bridge, names nothing in a checkout
and is still right.

Assumes: the Python seat is at `extensions/python`.
Guarantees:
  - a `parents[N]` walk in the seat fails the run and is named with its line
    [tested: tests/checks/check_root_walks_selftest.py; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f]
  - so does the same count spelled as a `.parent` chain, an `os.path.dirname`
    chain, without `.resolve()`, through a top-level name, inside a function, or
    taken from `seat()` or a path inside the seat, a relative import of
    `metta._roots` included
    [tested: tests/checks/check_root_walks_selftest.py; commit=WORKTREE]
  - a step landing on the file's own directory is NOT a finding, nor a path built
    under that directory which exists only in a built wheel, nor a walk starting
    above the seat, which leaves the checkout
    [tested: tests/checks/check_root_walks_selftest.py; commit=WORKTREE]
  - evaluating a module's bindings runs no builtin that opens, imports or executes:
    the sandbox carries only the pure ones a derivation uses
    [tested: tests/checks/check_root_walks_selftest.py; commit=WORKTREE]
  - the derivation is NOT a finding, because it names the marker rather than a depth
    [tested: tests/checks/check_root_walks_selftest.py; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f]
  - `metta/_roots.py` itself is exempt, being where the derivation is written
    [tested: tests/checks/check_root_walks_selftest.py; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f]
  - a derivation whose root is wrong is named through the path it goes on to miss,
    which is what a marker check cannot see
    [tested: tests/checks/check_root_walks_selftest.py; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f]
  - a derivation asking for `.git` ALONE is named, because that marker is absent
    in a tree copied without its history and every gate here runs in one
    [tested: tests/checks/check_root_walks_selftest.py; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f]
Fails when: run outside a checkout with a Python seat, which it reports.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import ast
import builtins
import importlib.util
import os
import sys
from pathlib import Path, PurePath
from types import SimpleNamespace

#: Derived, not counted. This file sits outside the seat so its own rule does not
#: reach it, but a count here is silent in exactly the way the rule exists to stop.
ROOT = next(parent for parent in Path(__file__).resolve().parents
            if (parent / "engine").is_dir() and (parent / "lib").is_dir())
SEAT = ROOT / "extensions/python"
#: Where the derivation is written down, so its own `parents` use is the definition
#: rather than an instance of the thing being refused.
EXEMPT = ("metta/_roots.py",)


#: What a module's bindings may call while they are evaluated: the pure builtins a
#: derivation uses. With nothing else in `__builtins__`, a module line calling
#: `open` or `__import__("subprocess")` raises here and is skipped rather than
#: run. Leaving `__builtins__` out would not do it, since `eval` then supplies
#: the whole builtins module.
_SANDBOX = {
    "__builtins__": {name: getattr(builtins, name) for name in (
        "all", "any", "bool", "enumerate", "frozenset", "int", "isinstance", "len",
        "list", "max", "min", "next", "reversed", "set", "sorted", "str", "tuple", "zip")},
}
#: The standard library's two path APIs, supplied under whatever names the module
#: imports them as, so `pathlib.Path(__file__)`, `from pathlib import Path as P`
#: and `_os.path.dirname(...)` evaluate alike. `os` is represented by its `path`
#: alone, so nothing here removes, spawns or execs.
_PATH_APIS: dict[str, object] = {
    "pathlib": SimpleNamespace(Path=Path, PurePath=PurePath),
    "os": SimpleNamespace(path=os.path, sep=os.sep),
    "os.path": os.path,
}
#: A value the sandbox could not compute, distinct from a binding to None.
_UNKNOWN = object()


def _apis(seat: Path) -> dict[str, object]:
    """The path APIs a module in `seat` may import, `metta._roots` as that seat ships it.

    `seat()` and `workspace()` answer derived roots, and a count taken from one,
    `seat().parents[1]`, is as silent as a count taken from `__file__`: it is the
    seat's depth in the workspace, written as a number. The seat's own `_roots.py`
    is executed on its own, never through `import metta`, so its derivation is all
    that runs; a `_roots.py` defining neither, as a fixture's may, leaves calls to
    them unevaluated.
    """
    apis = dict(_PATH_APIS)
    source = seat / "metta" / "_roots.py"
    spec = importlib.util.spec_from_file_location("metta_roots_under_check", source)
    if not source.is_file() or spec is None or spec.loader is None:
        return apis
    roots = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(roots)
    if hasattr(roots, "seat") and hasattr(roots, "workspace"):
        apis["metta._roots"] = roots
        apis["metta"] = SimpleNamespace(_roots=roots)
    return apis


def _imports(tree: ast.Module, apis: dict[str, object], package: str | None) -> dict[str, object]:
    """The path APIs this module imports anywhere, under the names it binds.

    Anywhere rather than at top level, since a function importing `Path` for
    itself walks as surely as a module does; the names are the path APIs alone,
    so seeing one a scope did not import changes no verdict. A relative import is
    resolved against `package`, so `from .._roots import seat` inside `metta` is
    the same import as the absolute one.
    """
    scope: dict[str, object] = {}
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                # `import os.path` binds `os`; `import os.path as p` binds the submodule.
                module = alias.name if alias.asname else alias.name.split(".")[0]
                if module in apis:
                    scope[alias.asname or module] = apis[module]
        elif isinstance(node, ast.ImportFrom):
            module = node.module or ""
            if node.level:
                try:
                    module = importlib.util.resolve_name("." * node.level + module, package or "")
                except (ImportError, ValueError):
                    # Beyond the top package, which Python refuses the same way.
                    continue
            api = apis.get(module)
            for alias in node.names:
                if api is not None and hasattr(api, alias.name):
                    scope[alias.asname or alias.name] = getattr(api, alias.name)
    return scope


def _callee(node: ast.Call, context: dict[str, object]) -> object:
    """What a call calls: the object a bare name is bound to, else the attribute's name.

    A bare name is looked up in the module's imports and then in the sandbox's
    builtins, so `up(x)` after `from os.path import dirname as up` is dirname.
    """
    if isinstance(node.func, ast.Name):
        return context.get(node.func.id, _SANDBOX["__builtins__"].get(node.func.id, _UNKNOWN))
    return node.func.attr if isinstance(node.func, ast.Attribute) else _UNKNOWN


def _below(node: ast.AST, context: dict[str, object]) -> ast.expr | None:
    """The base an upward step is taken from, or None when `node` is not a step.

    A step is `B.parents[N]`, `B.parent`, a bare `B.parents`, or `os.path.dirname(B)`
    under any name the module reached it by.
    """
    if (isinstance(node, ast.Subscript) and isinstance(node.value, ast.Attribute)
            and node.value.attr == "parents"):
        return node.value.value
    if isinstance(node, ast.Attribute) and node.attr in ("parent", "parents"):
        return node.value
    if isinstance(node, ast.Call) and len(node.args) == 1 and not node.keywords:
        callee = _callee(node, context)
        if callee is os.path.dirname or callee == "dirname":
            return node.args[0]
    return None


def _base(step: ast.expr, context: dict[str, object]) -> ast.expr:
    """What a step, however many levels it chains, starts from."""
    node = step
    while (below := _below(node, context)) is not None:
        node = below
    return node


def _steps(tree: ast.AST, context: dict[str, object]) -> list[ast.expr]:
    """Each outermost upward step in `tree`.

    Outermost, so `ROOT.parents[1].parent` is one step landing where the whole
    expression lands rather than two findings on one line. `ast.walk` is
    breadth-first, so an enclosing step is met before the steps inside it.
    """
    covered: set[int] = set()
    out: list[ast.expr] = []
    for node in ast.walk(tree):
        if id(node) in covered or _below(node, context) is None:
            continue
        out.append(node)
        inner: ast.AST = node
        while (below := _below(inner, context)) is not None:
            covered.add(id(inner))
            if isinstance(inner, ast.Subscript):
                covered.add(id(inner.value))
            inner = below
    return out


def _evaluate(node: ast.expr, filename: str, context: dict[str, object]) -> object:
    """The value of `node` in the sandbox over the module's imports and bindings, or `_UNKNOWN`.

    The context goes in as globals rather than locals, because a generator
    expression is a scope of its own and sees only globals: a marker test naming a
    module constant inside `next(p for p in ROOT.parents if ...)` needs it there.
    """
    scope = {**_SANDBOX, "__file__": filename, **context}
    try:
        return eval(compile(ast.Expression(node), filename, "eval"), scope)
    except Exception:
        return _UNKNOWN


def _position(node: ast.expr, filename: str, context: dict[str, object]) -> Path | None:
    """The place `node` names, resolved, or None when it names no one place.

    `os.path` answers a string where `pathlib` answers a Path, and both name a
    place when absolute.
    """
    value = _evaluate(node, filename, context)
    if isinstance(value, str):
        value = Path(value)
    return value.resolve() if isinstance(value, Path) and value.is_absolute() else None


def findings(seat: Path) -> list[str]:
    """Each counted walk in the seat, named by path and line."""
    if not seat.is_dir():
        message = f"no Python seat to check: {seat}"
        raise SystemExit(message)
    apis = _apis(seat)
    out: list[str] = []
    for path in sorted(seat.rglob("*.py")):
        rel = path.relative_to(seat).as_posix()
        if "__pycache__" in rel or rel in EXEMPT:
            continue
        try:
            source = path.read_text(encoding="utf-8")
            tree = ast.parse(source)
        except (OSError, UnicodeDecodeError, SyntaxError):
            continue
        # Every step `_below` recognises spells one of these, `.parents` included,
        # so a file with none takes no step up.
        if ".parent" not in source and "dirname" not in source:
            continue
        filename, here = str(path), path.resolve().parent
        context, derived = _bindings(tree, filename, _imports(tree, apis, _package(rel)))
        for step in _steps(tree, context):
            # A count crosses the seat's boundary upward: it starts at or inside the
            # seat, where the layout is this repository's, and lands on the seat or
            # above it. Starting above the seat, `workspace().parent`, it leaves the
            # checkout rather than counting a level of it.
            landing = _position(step, filename, context)
            if landing is None or landing == here or not seat.is_relative_to(landing):
                continue
            start = _position(_base(step, context), filename, context)
            if start is None or not start.is_relative_to(seat):
                continue
            origin = start.parent if start.is_file() else start
            levels = len(origin.parts) - len(landing.parts)
            where = "the seat" if landing == seat else f"{landing}, above the seat"
            out.append(
                f"extensions/python/{rel}:{step.lineno}: counts {levels} directory "
                f"level{'' if levels == 1 else 's'} to {where}; call metta._roots.seat() "
                f"or workspace(), or write the derivation inline where neither can be "
                f"imported yet")
        out.extend(
            f"extensions/python/{rel}:{line}: derives a root from `.git` alone, which "
            f"is absent in a tree copied without its history; ask for a "
            f"`pyproject.toml` too, as metta._roots.seat() does"
            for line in _single_marker(tree))
        out.extend(
            f"extensions/python/{rel}:{line}: {name} derives a root and then names "
            f"{value}, which does not exist; the walk reached the wrong ancestor, so "
            f"check whether it wants the seat's marker or the workspace's engine/ and lib/"
            for name, line, value, names in derived
            if not value.exists() and not _scratch(names))
    return out


#: Written by the program rather than read by it, so a path here naming nothing is
#: the normal case rather than a wrong root. Matched against what the SOURCE names,
#: never against where the file sits: a fixture seat planted under this repository's
#: own ai-tmp/ would otherwise exempt everything in it, which is how the first
#: version of this check passed while catching nothing.
SCRATCH = ("ai-tmp", "ai-tmp-")


def _single_marker(tree: ast.Module) -> list[int]:
    """Each parents-walk whose marker test names `.git` and nothing else.

    A marker check cannot say which root a walk SHOULD reach, which is why the
    result is what the check above compares. It can say when the marker set is
    incomplete, and that is a different failure: `seat()` asks for a
    `pyproject.toml` OR a `.git` because a component is a distribution or a
    repository, and a tree copied without its history has only the first. Every
    gate in this repository runs in such a tree, so a `.git`-only walk answers a
    different directory there and the failure arrives as whatever reads the path
    [measured 2026-09-19: eleven sites, and the door-order gate reported thirteen
    false findings from one of them].
    """
    out: list[int] = []
    for node in ast.walk(tree):
        if not isinstance(node, (ast.GeneratorExp, ast.ListComp, ast.SetComp)):
            continue
        for generator in node.generators:
            if not (isinstance(generator.iter, ast.Attribute)
                    and generator.iter.attr == "parents"):
                continue
            markers = {constant.value
                       for test in generator.ifs
                       for constant in ast.walk(test)
                       if isinstance(constant, ast.Constant)
                       and isinstance(constant.value, str)}
            if markers == {".git"}:
                out.append(node.lineno)
    return out


def _package(rel: str) -> str | None:
    """The package a seat file's relative imports resolve against, or None at the top.

    Its directory, dotted: `metta/doors/_order.py` imports relative to
    `metta.doors`, and so does `metta/doors/__init__.py`, which is that package.
    """
    return ".".join(rel.split("/")[:-1]) or None


def _bindings(tree: ast.Module, filename: str, context: dict[str, object]) -> tuple[
        dict[str, object], list[tuple[str, int, Path, str]]]:
    """Evaluate the module's top-level bindings in order, carrying each one forward.

    Starts from the module's path imports and answers them extended by every
    binding the sandbox could compute, which the counts are evaluated over, and
    each Path built by a walk past the file's own directory, which must exist. A
    derivation on its own always names a real directory, whichever marker it used,
    because every ancestor exists. The wrong root only becomes observable once
    something is joined onto it, and that happens on a later line under a
    different name. A path built from the file's own directory took no walk, so
    its absence says nothing about a root.
    """
    here = Path(filename).resolve().parent
    context = dict(context)
    named: dict[str, str] = {}
    walked: set[str] = set()
    out: list[tuple[str, int, Path, str]] = []
    for node in tree.body:
        if (isinstance(node, ast.Assign) and len(node.targets) == 1
                and isinstance(node.targets[0], ast.Name)):
            target, expression = node.targets[0].id, node.value
        elif (isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name)
                and node.value is not None):
            target, expression = node.target.id, node.value
        else:
            continue
        value = _evaluate(expression, filename, context)
        if value is _UNKNOWN:
            continue
        names = [name.id for name in ast.walk(expression) if isinstance(name, ast.Name)]
        if walked.intersection(names) or any(
                _position(step, filename, context) != here for step in _steps(expression, context)):
            walked.add(target)
        context[target] = value
        # What this binding NAMES, carried forward through the names it was built
        # from, so `OUT = ROOT / "ai-tmp" / "x"` is recognised wherever ROOT came from.
        named[target] = ast.unparse(expression) + " " + " ".join(named.get(name, "") for name in names)
        if isinstance(value, Path) and target in walked:
            out.append((target, node.lineno, value, named[target]))
    return context, out


def _scratch(names: str) -> bool:
    """Whether the expression that built this path names scratch of its own."""
    return any(mark in names for mark in SCRATCH)


def main() -> int:
    """Report every counted root walk in the seat."""
    problems = findings(SEAT)
    for problem in problems:
        print(f"  {problem}")
    print(f"root-walks: {len(problems)} finding(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
