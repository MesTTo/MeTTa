"""Purpose: hold the workspace's two layering rules, both derived from the tree.

The Python seat is a core distribution and a set of extension distributions
beside it, one per library. Two rules make that a real boundary rather than a
folder split wearing a package's clothes, and this pass is both:

  1. the CORE imports no member. If it did, deleting `ext/` would break it, and
     the extra that installs a member would be a requirement of the core in all
     but name.
  2. a MEMBER reaches the core through PUBLIC names and the seam only, never
     through an underscore name. That is the rule Airflow had to invent a Task
     SDK for and the rule a pytest plugin breaks every release by ignoring: a
     distribution that reaches another's privates is not separately releasable
     [source: https://airflow.apache.org/docs/apache-airflow/stable/public-airflow-interface.html].

Everything it reads is derived. The roster is the `[tool.uv.workspace] members`
glob, the module a member ships is its `py-modules` entry, and the libraries a
member may name are the dependencies its own `pyproject.toml` declares, read
from the syntax tree by the same reader the no-hardcoded-integration pass uses.
A package added under `ext/` therefore needs no line here.

Assumes: a checkout of this repository with `pyproject.toml` at its root.
Guarantees:
  - a core module importing a member is reported [tested:
    tests/checks/check_layering_selftest.py; commit=b615b5a33b43252ef9826e5387da7c9bd7f6b543]
  - generated provider annotations are checked against door rows, while
    imports in other TYPE_CHECKING blocks remain subject to both layer rules
    [tested: tests/checks/check_hardcoded_integrations_selftest.py,
    tests/checks/check_layering_selftest.py; commit=b615b5a33b43252ef9826e5387da7c9bd7f6b543]
  - a member importing a core underscore name is reported [tested:
    tests/checks/check_layering_selftest.py; commit=94057a0f073c0fab0a35c42beff2c324d8a0addd]
  - a member naming a library its own manifest does not declare is reported,
    so a package cannot quietly gain a second integration [tested:
    tests/checks/check_layering_selftest.py; commit=94057a0f073c0fab0a35c42beff2c324d8a0addd]
  - a member missing from `[tool.uv.sources]`, and a source naming no member,
    are each reported, so the resolver's view and the directory agree [tested:
    tests/checks/check_layering_selftest.py; commit=94057a0f073c0fab0a35c42beff2c324d8a0addd]
  - a `_workspace.py` whose `EXT` reaches a different set of directories than
    the glob names is reported, so a moved `ext/` fails here rather than as
    `ModuleNotFoundError` in the member suites [tested:
    tests/checks/check_layering_selftest.py; commit=500290ef67f6198adc1ce17c1f70e5a5173647bb]
  - a member whose version, pymetta pin, entry point, README or tests are
    missing is reported [tested: tests/checks/check_layering_selftest.py;
    commit=94057a0f073c0fab0a35c42beff2c324d8a0addd]
  - an extra a seam point names, and an extra naming a package that is not a
    member, are each reported [tested:
    tests/checks/check_layering_selftest.py; commit=94057a0f073c0fab0a35c42beff2c324d8a0addd]
  - an ADVERTISED member whose module body reaches the core facade is
    reported, because discovery loads every advertised package on the first
    dispatch and the cost would be every program's [tested:
    tests/checks/check_layering_selftest.py; commit=94057a0f073c0fab0a35c42beff2c324d8a0addd]
Fails when: the workspace glob matches nothing, which it reports rather than
  passing on an empty roster.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import ast
import os
import re
import runpy
import subprocess
import sys
import tomllib
from functools import cache
from graphlib import CycleError
from importlib import metadata
from pathlib import Path
from pkgutil import iter_modules
from typing import NamedTuple

ROOT = Path(__file__).resolve().parents[2]
SEAT = ROOT / "extensions" / "python"
CORE = SEAT / "metta"

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(SEAT))

import check_hardcoded_integrations as libraries  # noqa: E402  -- the path is installed above

#: Name identity, from the module that already decides it for the import
#: system. `_workspace.normalised` is what answers `import metta_live` against
#: `importlib.metadata`'s `metta-live`, so a roster comparison reaching for a
#: second copy of PEP 503 would be a second opinion on the same question.
from _workspace import normalised as _canonical  # noqa: E402  -- SEAT is installed above

#: The group a member advertises under, which is what makes discovery work at
#: all; the seam reads this name and nothing else.
GROUP = "metta.extensions"

#: The requirement name a version specifier is written after, so `polars>=1.3`
#: reads as polars. PEP 508 owns the grammar; this is the part of it a roster
#: comparison needs.
REQUIREMENT = re.compile(r"^([A-Za-z0-9][A-Za-z0-9._-]*)")


class Finding(NamedTuple):
    """One crossing of the boundary, with what to do instead."""

    where: str
    reason: str

    def __str__(self) -> str:
        """The file and the remedy."""
        return f"{self.where}: {self.reason}"


class Member(NamedTuple):
    """One extension distribution, as its own manifest describes it."""

    directory: Path
    distribution: str
    module: str
    version: str
    requires: frozenset[str]
    entry_points: dict[str, str]
    modules: tuple[str, ...] = ()


def _manifest(path: Path) -> dict:
    return tomllib.loads(path.read_text(encoding="utf-8"))


def _requirement_name(requirement: str) -> str:
    """The distribution a requirement names, in PEP 503's one spelling."""
    match = REQUIREMENT.match(requirement.strip())
    return _canonical(match.group(1) if match else requirement.strip())


def members(root: Path = ROOT) -> list[Member]:
    """Every workspace member, read from the glob its root declares."""
    manifest = _manifest(root / "pyproject.toml")
    patterns = manifest["tool"]["uv"]["workspace"]["members"]
    directories = [
        path
        for pattern in patterns
        for path in sorted(root.glob(pattern))
        if (path / "pyproject.toml").exists()
    ]
    if not directories:
        message = f"the workspace glob {patterns} matches nothing under {root}"
        raise SystemExit(message)
    found = []
    for directory in directories:
        own = _manifest(directory / "pyproject.toml")
        project = own["project"]
        modules = own.get("tool", {}).get("setuptools", {}).get("py-modules", [])
        found.append(
            Member(
                directory,
                # Canonical from the moment it is read, so no comparison below
                # can see a name in a spelling another tool would not recognise.
                _canonical(project["name"]),
                modules[0] if modules else "",
                project.get("version", ""),
                frozenset(
                    _requirement_name(requirement)
                    for group in (
                        project.get("dependencies", []),
                        *project.get("optional-dependencies", {}).values(),
                    )
                    for requirement in group
                ),
                # EXACT, not canonical. An entry-point name is not a
                # distribution name: `_workspace.py` writes each one verbatim
                # into `entry_points.txt` and `seam.py` reads it back through
                # `metadata.entry_points`, which preserves it, so discovery
                # matches the spelling the manifest wrote. Normalising here
                # would accept a member that discovery cannot find, and would
                # collapse `metta-a` and `metta_a` into one key on the way.
                dict(project.get("entry-points", {}).get(GROUP, {})),
                tuple(modules),
            )
        )
    return found


def _imports(path: Path) -> list[tuple[str, int]]:
    """Every module this file imports, dotted, with its line."""
    found: list[tuple[str, int]] = []
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    annotations = libraries._door_annotations(path)
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            found.extend((alias.name, node.lineno) for alias in node.names
                         if (alias.name.partition('.')[0], node.lineno) not in annotations)
        elif isinstance(node, ast.ImportFrom) and node.level == 0 and node.module:
            found.append((node.module, node.lineno))
    return found


def _sources(directory: Path) -> list[Path]:
    return sorted(
        path
        for path in directory.rglob("*.py")
        if "__pycache__" not in path.parts
    )


def _core_imports_no_member(roster: list[Member]) -> list[Finding]:
    """Rule one: nothing in the core reaches an extension distribution."""
    shipped = {module: member.distribution for member in roster for module in member.modules or (member.module,)}
    findings = []
    for path in _sources(CORE):
        for imported, line in _imports(path):
            top = imported.partition(".")[0]
            if top in shipped:
                findings.append(
                    Finding(
                        f"{path.relative_to(ROOT).as_posix()}:{line}",
                        f"the core imports {top!r}, which is the workspace "
                        f"member {shipped[top]}; the core survives without "
                        f"every member, so reach it through a seam point or "
                        f"move this code into the member",
                    )
                )
    return findings


def _members_reach_only_the_public_core(roster: list[Member]) -> list[Finding]:
    """Rule two: a member imports no underscore name of the core."""
    findings = []
    for member in roster:
        for path in _sources(member.directory):
            for imported, line in _imports(path):
                parts = imported.split(".")
                if parts[0] != "metta" or len(parts) < 2 or not parts[1].startswith("_"):
                    continue
                findings.append(
                    Finding(
                        f"{path.relative_to(ROOT).as_posix()}:{line}",
                        f"{member.distribution} imports {imported!r}, which is "
                        f"the core's private name; a member reaches the core "
                        f"through public names and the seam's services only, "
                        f"so publish a service for what this needs",
                    )
                )
    return findings


# Pure in the installed environment, which does not change while the gate runs,
# and called once per requirement of every member. Without this each call walks
# every installed distribution and normalises each owner name it holds.
# Time: one `packages_distributions()` walk per distinct name, D owners each,
# where D is the installed distribution count. Space: one set per distinct name.
@cache
def _modules_of(distribution: str) -> set[str]:
    """Which top-level modules a distribution provides, as installed here.

    A distribution name and an import name are different facts and only the
    environment relates them: `websocket-client` provides `websocket`, and
    nothing in either manifest says so. `packages_distributions()` is the
    standard answer, and where the distribution is not installed the two
    ordinary spellings are accepted instead.
    """
    provided = {
        module
        for module, owners in metadata.packages_distributions().items()
        # `packages_distributions()` answers each owner in the spelling its own
        # metadata uses, so a `Django` there and a `django` here are one
        # distribution and only the normalisation says so.
        if distribution in {_canonical(owner) for owner in owners}
    }
    return provided or {distribution, distribution.replace("-", "_")}


def _members_declare_what_they_name(roster: list[Member]) -> list[Finding]:
    """A member may name the libraries its own manifest declares, and no other."""
    findings = []
    for member in roster:
        allowed = {
            module for name in member.requires for module in _modules_of(name)
        } | set(member.requires)
        for path in _sources(member.directory):
            # A member's own suite is the SUITE, and reaches pytest, hypothesis,
            # the benchmark drivers and a sibling member the way every other
            # test file here does. What this rule is about is the package: the
            # module a user installs may name the library it integrates and no
            # other, which is what "one package, one library" means.
            if "tests" in path.relative_to(member.directory).parts:
                continue
            for library, line in libraries._python_names(path):
                if library in allowed or library in (member.modules or (member.module,)):
                    continue
                findings.append(
                    Finding(
                        f"{path.relative_to(ROOT).as_posix()}:{line}",
                        f"{member.distribution} names {library!r} and does not "
                        f"declare it; a package names ONE library and says so "
                        f"in its own dependencies, or it is two integrations "
                        f"wearing one name",
                    )
                )
    return findings


def _the_roster_and_the_resolver_agree(roster: list[Member], root: Path) -> list[Finding]:
    """Every member is a workspace source, and every source is a member."""
    manifest = _manifest(root / "pyproject.toml")
    #: Keyed canonically, because a TOML key is written by hand and uv reads it
    #: as a distribution name rather than as the string it looks like.
    declared = {
        _canonical(name)
        for name in manifest.get("tool", {}).get("uv", {}).get("sources", {})
    }
    named = {member.distribution for member in roster}
    # The workspace ROOT's own distribution is PERMITTED here beside the members,
    # never required. `members()` builds the roster from the `ext/metta-*` glob,
    # which cannot match the root, so the roster alone cannot know it. uv
    # disagrees that it is not a member and REQUIRES the entry: deleting
    # `pymetta = { workspace = true }` makes `uv lock --offline --check` exit 2
    # with "`pymetta` is included as a workspace member, but is missing an entry
    # in `tool.uv.sources`", so the earlier reading here -- that nothing may
    # demand it be declared -- was right about this rule and wrong about uv
    # [measured 2026-09-21: the removal probed in a battery worktree at
    # 358c8dc15; commit=c6ed562a1a6f964aba906206f2558489b107dc24]
    # [tested: tests/checks/check_layering_selftest.py; commit=500290ef67f6198adc1ce17c1f70e5a5173647bb].
    allowed = named | {_canonical(manifest.get("project", {}).get("name", ""))}
    return [
        *(
            Finding(
                "pyproject.toml",
                f"{distribution} is a workspace member and is not in "
                f"[tool.uv.sources]; without it an extra that requires it "
                f"resolves from an index instead of from this checkout",
            )
            for distribution in sorted(named - declared)
        ),
        *(
            Finding(
                "pyproject.toml",
                f"[tool.uv.sources] names {distribution}, which is no longer a "
                f"workspace member; remove the entry",
            )
            for distribution in sorted(declared - allowed)
        ),
    ]


def _the_checkout_finder_sees_the_roster(roster: list[Member], root: Path) -> list[Finding]:
    """The checkout's path helper reaches exactly the members the glob names.

    `_workspace.py` is what makes `import metta_pandas` work from a checkout,
    and it locates `ext/` by walking up from its own file rather than by reading
    a manifest, because it runs before anything that could parse one. A wrong
    number of levels there does not raise: the glob matches nothing, `members()`
    answers an empty list, every member silently stops being importable, and the
    member suites fail with `ModuleNotFoundError` a long way from the cause
    [measured 2026-09-19: moving `ext/` out of the seat left this reaching
    `extensions/python/ext`, and the six distributions whose tests import their
    own module raised 22 collection errors while every lane stayed green].
    Comparing the helper against the roster puts that mismatch here instead.
    """
    source = root / "extensions" / "python" / "_workspace.py"
    if not source.exists():
        return [
            Finding(
                "extensions/python/_workspace.py",
                "the seat ships no path helper, so a checkout can import no member",
            )
        ]
    namespace = runpy.run_path(str(source))
    reached = {path.resolve() for path in namespace["members"]()}
    named = {member.directory.resolve() for member in roster}
    return [
        *(
            [
                Finding(
                    "extensions/python/_workspace.py",
                    f"EXT is {namespace['EXT']}, which does not reach "
                    f"{', '.join(sorted(path.name for path in named - reached))}; "
                    f"the workspace glob names them, so this checkout ships members "
                    f"it cannot import",
                )
            ]
            if named - reached
            else []
        ),
        *(
            [
                Finding(
                    "extensions/python/_workspace.py",
                    f"EXT is {namespace['EXT']}, which reaches "
                    f"{', '.join(sorted(path.name for path in reached - named))}; "
                    f"the workspace glob names no such member",
                )
            ]
            if reached - named
            else []
        ),
    ]


def _core_version(root: Path) -> str:
    """Pymetta's version, read from the module the manifest points at.

    The core's version is dynamic (`attr = metta._version.__version__`), so the
    manifest does not carry it and this reads the attribute's own source rather
    than importing a package that needs an engine.
    """
    source = (root / "extensions" / "python" / "metta" / "_version.py").read_text(encoding="utf-8")
    tree = ast.parse(source)
    for node in ast.walk(tree):
        if isinstance(node, ast.Assign) and any(
            getattr(target, "id", "") == "__version__" for target in node.targets
        ):
            return node.value.value
    message = "metta/_version.py declares no __version__"
    raise SystemExit(message)


def _each_member_is_whole(roster: list[Member], root: Path) -> list[Finding]:
    """A member ships a module, a README, tests, a pin and an entry point."""
    core_version = _core_version(root)
    findings = []
    for member in roster:
        where = (member.directory / "pyproject.toml").relative_to(root).as_posix()
        expected = member.directory.name.replace("-", "_")
        if member.module != expected:
            findings.append(
                Finding(where, f"ships {member.module!r} where its directory says {expected!r}")
            )
        findings.extend(
            Finding(where, f"declares {module!r} and no such module is here")
            for module in member.modules or (member.module,)
            if not (member.directory / f"{module}.py").is_file()
        )
        findings.extend(
            Finding(where, f"has no {required}")
            for required in ("README.md", "tests")
            if not (member.directory / required).exists()
        )
        if "pymetta" not in member.requires:
            findings.append(
                Finding(where, "does not depend on pymetta; a member is released with the core")
            )
        if member.version != core_version:
            findings.append(
                Finding(
                    where,
                    f"is version {member.version!r} where the core is "
                    f"{core_version!r}; a member is released with the core, so "
                    f"a row can never meet a seam that moved without it",
                )
            )
        advertised = member.entry_points
        shipped = member.modules or (member.module,)
        target = advertised.get(member.distribution, "").partition(":")[0]
        if advertised and (set(advertised) != {member.distribution} or target not in shipped):
            findings.append(
                Finding(
                    where,
                    f"advertises {advertised} under {GROUP}; a member either "
                    f"advertises its own name and a module in {shipped!r}, so "
                    f"a dispatch can discover it, or advertises nothing at all "
                    f"because it is a library a caller imports by name",
                )
            )
    return findings


def _every_extra_installs_members(roster: list[Member], root: Path) -> list[Finding]:
    """An extra names members and the engine, and a seam extra exists."""
    manifest = _manifest(root / "pyproject.toml")
    extras = manifest["project"]["optional-dependencies"]
    named = {member.distribution for member in roster}
    findings = []
    for extra, requirements in extras.items():
        for requirement in requirements:
            name = _requirement_name(requirement)
            if not name.startswith("metta-"):
                continue
            if name not in named:
                findings.append(
                    Finding(
                        "pyproject.toml",
                        f"the {extra!r} extra requires {name}, which is not a "
                        f"workspace member",
                    )
                )
    declared = _seam_extras()
    for point, extra in sorted(declared.items()):
        if extra not in extras:
            findings.append(
                Finding(
                    "extensions/python/metta/seam.py",
                    f"the {point!r} point names the extra {extra!r}, which "
                    f"pyproject.toml does not declare, so its refusal ends in "
                    f"a command that does not work",
                )
            )
    return findings


def _seam_extras() -> dict[str, str]:
    """Each point's `extra=`, read from the seam's own source rather than run.

    The syntax tree, so this pass needs no engine and no import: it is a
    packaging check and runs where janus does not.
    """
    tree = ast.parse((CORE / "seam.py").read_text(encoding="utf-8"))
    found: dict[str, str] = {}
    for node in ast.walk(tree):
        if not (isinstance(node, ast.Call) and getattr(node.func, "id", "") == "point"):
            continue
        if not (node.args and isinstance(node.args[0], ast.Constant)):
            continue
        name = node.args[0].value
        for keyword in node.keywords:
            if keyword.arg == "extra" and isinstance(keyword.value, ast.Constant):
                found[name] = keyword.value.value
    return found


def _discovery_stays_cheap(roster: list[Member], root: Path) -> list[Finding]:
    """Importing every ADVERTISED member must not load the core facade.

    Discovery loads the whole group on the first dispatch of any point a
    registrant writes, so what one advertised package costs to import, every
    program pays once -- including a program that never touches that package's
    subject. `metta._spaces.handle` is the facade and is the cost: with it, `import
    metta_pandas` was 124 ms and 196 modules; without, 5 ms and 33 [measured
    2026-09-08]. So the rule is one name rather than a budget: an advertised
    member's module body may register rows and may hold the NAME of its
    library, and may not reach the facade.

    Run in a subprocess, because the answer is what `sys.modules` holds and
    this process has already imported half the tree.
    """
    advertised = [member for member in roster if member.entry_points]
    if not advertised:
        return []
    seat = root / "extensions" / "python"
    program = (
        "import sys\n"
        "import metta\n"
        "before = set(sys.modules)\n"
        f"for name in {[target.partition(':')[0] for member in advertised for target in member.entry_points.values()]!r}:\n"
        "    __import__(name)\n"
        "arrived = sorted(set(sys.modules) - before)\n"
        "print(len(arrived))\n"
        "print('\\n'.join(one for one in arrived if one.startswith('metta.')))\n"
    )
    path = os.pathsep.join(
        [str(seat), *(str(member.directory) for member in advertised)]
    )
    finished = subprocess.run(
        [sys.executable, "-c", program],
        capture_output=True,
        text=True,
        env={**os.environ, "PYTHONPATH": path},
        check=False,
    )
    if finished.returncode != 0:
        return [
            Finding(
                "ext",
                f"importing every advertised member failed: "
                f"{finished.stderr.strip().splitlines()[-1] if finished.stderr else 'no output'}",
            )
        ]
    lines = finished.stdout.split()
    facade = [one for one in lines[1:] if one == "metta._spaces.handle"]
    if not facade:
        return []
    return [
        Finding(
            "ext",
            f"importing the advertised members loads metta._spaces.handle and "
            f"{lines[0]} modules in all; discovery loads every advertised "
            f"package on the first dispatch, so the facade would be dragged "
            f"in by a program that never asked for any of them. Move the "
            f"heavy import inside the callable that needs it, or drop the "
            f"{GROUP} entry point and let a caller import the package",
        )
    ]


def _package_architecture(root: Path) -> list[Finding]:
    """Check the actual import graph and directory against the declared DAG.

    Grimp reads source without importing the package. Annotation-only edges
    are excluded; function-local ordinary imports remain static dependencies.
    """
    import grimp

    core = root / "extensions/python/metta"
    try:
        lattice = runpy.run_path(str(core / "_layers.py"))
    except (ValueError, CycleError) as error:
        return [Finding("extensions/python/metta/_layers.py", str(error))]
    declared = lattice["BUILDS_ON"]
    foundations, orders = lattice["FOUNDATIONS"], lattice["ORDERS"]
    shipped = {entry.name for entry in iter_modules([str(core)])} | {"metta"}
    findings = [
        Finding("extensions/python/metta", f"package {name!r} is absent from BUILDS_ON")
        for name in sorted(shipped - declared.keys())
    ] + [
        Finding("extensions/python/metta/_layers.py", f"BUILDS_ON names absent package {name!r}")
        for name in sorted(declared.keys() - shipped)
    ]
    source = core / "__init__.pyi"
    if not source.exists():
        source = core / "__init__.py"
    for node in ast.parse(source.read_text()).body:
        if isinstance(node, ast.Assign) and any(
            isinstance(target, ast.Name) and target.id == "__all__" for target in node.targets
        ):
            findings.extend(
                Finding(str(source.relative_to(root)), f"root export {name!r} collides with a module entry")
                for name in sorted(set(ast.literal_eval(node.value)) & (shipped - {"metta"}))
            )
    if shipped != declared.keys():
        return findings
    original_path = list(sys.path)
    sys.path.insert(0, str(core.parent))
    try:
        graph = grimp.build_graph("metta", exclude_type_checking_imports=True, cache_dir=None)
    finally:
        sys.path[:] = original_path
    package_of = lattice["package_of"]
    for importer in sorted(graph.modules):
        origin = package_of(importer)
        for imported in sorted(graph.find_modules_directly_imported_by(importer)):
            target = package_of(imported)
            if origin == target or target in foundations[origin]:
                continue
            findings.extend(
                Finding(
                    f"{importer}:{detail['line_number']}",
                    f"static import of {imported} is outside {origin}'s declared foundations",
                ) for detail in graph.get_import_details(importer=importer, imported=imported)
            )
    for path in _sources(core):
        module = "metta." + ".".join(path.relative_to(core).with_suffix("").parts)
        module = module.removesuffix(".__init__")
        origin = package_of(module)
        for target, line in _lazy_targets(path):
            where = f"{path.relative_to(root)}:{line}"
            if target is None:
                findings.append(Finding(where, "lazy target is not a literal module name"))
            elif target == "metta" or target.startswith("metta."):
                try:
                    destination = package_of(target)
                except ValueError as error:
                    findings.append(Finding(where, str(error)))
                else:
                    if orders[destination] <= orders[origin]:
                        findings.append(Finding(
                            where, f"lazy target {target} must be strictly above {origin}; "
                            "import foundations directly",
                        ))
    return findings


def _lazy_targets(path: Path) -> list[tuple[str | None, int]]:
    """Read deferred call sites, resolving imported aliases and skipping typing."""
    tree = ast.parse(path.read_text())
    functions, modules = set(), set()
    for node in ast.walk(tree):
        if isinstance(node, ast.ImportFrom) and node.module == "metta._lazy":
            functions.update(alias.asname or alias.name for alias in node.names if alias.name == "lazy")
        elif isinstance(node, ast.Import):
            modules.update(alias.asname or alias.name for alias in node.names if alias.name == "metta._lazy")
    found = []

    class Calls(ast.NodeVisitor):
        def visit_If(self, node: ast.If) -> None:
            test = node.test
            if (isinstance(test, ast.Name) and test.id == "TYPE_CHECKING") or (
                isinstance(test, ast.Attribute) and test.attr == "TYPE_CHECKING"
            ):
                for child in node.orelse:
                    self.visit(child)
            else:
                self.generic_visit(node)

        def visit_Call(self, node: ast.Call) -> None:
            target = node.func
            is_lazy = isinstance(target, ast.Name) and target.id in functions
            is_lazy |= isinstance(target, ast.Attribute) and target.attr == "lazy" and ast.unparse(target.value) in modules
            if is_lazy:
                argument = node.args[0] if node.args else None
                value = argument.value if isinstance(argument, ast.Constant) else None
                found.append((value if isinstance(value, str) else None, node.lineno))
            self.generic_visit(node)

    Calls().visit(tree)
    return found


def findings(root: Path = ROOT) -> list[Finding]:
    """Every crossing of the workspace boundary, in reading order."""
    roster = members(root)
    return [
        *_package_architecture(root),
        *_core_imports_no_member(roster),
        *_members_reach_only_the_public_core(roster),
        *_members_declare_what_they_name(roster),
        *_the_roster_and_the_resolver_agree(roster, root),
        *_the_checkout_finder_sees_the_roster(roster, root),
        *_each_member_is_whole(roster, root),
        *_every_extra_installs_members(roster, root),
        *_discovery_stays_cheap(roster, root),
    ]


def main() -> int:
    """Report every finding, exiting nonzero when there is one."""
    reported = findings()
    for finding in reported:
        print(finding)
    if reported:
        print(f"{len(reported)} layering violation(s)")
        return 1
    print(
        f"the workspace layers hold: {len(members())} members, "
        f"none reached by the core and none reaching its privates"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
