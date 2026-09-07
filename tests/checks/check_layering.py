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
    tests/checks/check_layering_selftest.py; commit=WORKTREE]
  - a member importing a core underscore name is reported [tested:
    tests/checks/check_layering_selftest.py; commit=WORKTREE]
  - a member naming a library its own manifest does not declare is reported,
    so a package cannot quietly gain a second integration [tested:
    tests/checks/check_layering_selftest.py; commit=WORKTREE]
  - a member missing from `[tool.uv.sources]`, and a source naming no member,
    are each reported, so the resolver's view and the directory agree [tested:
    tests/checks/check_layering_selftest.py; commit=WORKTREE]
  - a member whose version, pymetta pin, entry point, README or tests are
    missing is reported [tested: tests/checks/check_layering_selftest.py;
    commit=WORKTREE]
  - an extra a seam point names, and an extra naming a package that is not a
    member, are each reported [tested:
    tests/checks/check_layering_selftest.py; commit=WORKTREE]
  - an ADVERTISED member whose module body reaches the core facade is
    reported, because discovery loads every advertised package on the first
    dispatch and the cost would be every program's [tested:
    tests/checks/check_layering_selftest.py; commit=WORKTREE]
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
import subprocess
import sys
import tomllib
from importlib import metadata
from pathlib import Path
from typing import NamedTuple

ROOT = Path(__file__).resolve().parents[2]
SEAT = ROOT / "extensions" / "python"
CORE = SEAT / "metta"

sys.path.insert(0, str(Path(__file__).resolve().parent))

import check_hardcoded_integrations as libraries  # noqa: E402  -- the path is installed above

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


def _manifest(path: Path) -> dict:
    return tomllib.loads(path.read_text(encoding="utf-8"))


def _requirement_name(requirement: str) -> str:
    match = REQUIREMENT.match(requirement.strip())
    return match.group(1) if match else requirement.strip()


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
                project["name"],
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
                dict(project.get("entry-points", {}).get(GROUP, {})),
            )
        )
    return found


def _imports(path: Path) -> list[tuple[str, int]]:
    """Every module this file imports, dotted, with its line."""
    found: list[tuple[str, int]] = []
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            found.extend((alias.name, node.lineno) for alias in node.names)
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
    shipped = {member.module: member.distribution for member in roster}
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
        if distribution in owners
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
                if library in allowed or library == member.module:
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
    declared = manifest.get("tool", {}).get("uv", {}).get("sources", {})
    named = {member.distribution for member in roster}
    return [
        *(
            Finding(
                "pyproject.toml",
                f"{distribution} is a workspace member and is not in "
                f"[tool.uv.sources]; without it an extra that requires it "
                f"resolves from an index instead of from this checkout",
            )
            for distribution in sorted(named - set(declared))
        ),
        *(
            Finding(
                "pyproject.toml",
                f"[tool.uv.sources] names {distribution}, which is no longer a "
                f"workspace member; remove the entry",
            )
            for distribution in sorted(set(declared) - named)
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
        if not (member.directory / f"{expected}.py").exists():
            findings.append(Finding(where, f"declares {expected!r} and no such module is here"))
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
        if advertised and advertised.get(member.distribution) != member.module:
            findings.append(
                Finding(
                    where,
                    f"advertises {advertised} under {GROUP}; a member either "
                    f"advertises {{{member.distribution!r}: {member.module!r}}}, so "
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
    subject. `metta._space` is the facade and is the cost: with it, `import
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
        f"for name in {[member.module for member in advertised]!r}:\n"
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
                "extensions/python/ext",
                f"importing every advertised member failed: "
                f"{finished.stderr.strip().splitlines()[-1] if finished.stderr else 'no output'}",
            )
        ]
    lines = finished.stdout.split()
    facade = [one for one in lines[1:] if one == "metta._space"]
    if not facade:
        return []
    return [
        Finding(
            "extensions/python/ext",
            f"importing the advertised members loads metta._space and "
            f"{lines[0]} modules in all; discovery loads every advertised "
            f"package on the first dispatch, so the facade would be dragged "
            f"in by a program that never asked for any of them. Move the "
            f"heavy import inside the callable that needs it, or drop the "
            f"{GROUP} entry point and let a caller import the package",
        )
    ]


def findings(root: Path = ROOT) -> list[Finding]:
    """Every crossing of the workspace boundary, in reading order."""
    roster = members(root)
    return [
        *_core_imports_no_member(roster),
        *_members_reach_only_the_public_core(roster),
        *_members_declare_what_they_name(roster),
        *_the_roster_and_the_resolver_agree(roster, root),
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
