#!/usr/bin/env python3
"""Purpose: refuse an upload step that would leave a published entry point unresolvable.

Every distribution name this repository publishes, with each extra it declares
and with none, is resolved at the version it will carry after the step, on each
target platform and each supported CPython, against the live index PLUS exactly
the files that step is about to send.

WHY IT EXISTS. pymetta 0.9.1 went to PyPI naming `pymetta-host` in its `engine`
extra under a Linux x86_64 marker, and pypi.org answers 404 for pymetta-host,
so `pip install "pymetta[engine]"` cannot resolve there at all. Nine of the
integration members its other extras name were absent the same way. Nothing on
the release path had ever resolved a single requirement: tools/build-
distributions.sh builds, tools/publish-new-projects.sh asks pypi.org only
whether a PROJECT EXISTS, and the publish workflow uploads. Project existence
is not resolvability -- every member pins `pymetta==<its own version>` exactly,
so a family whose members lag also makes a resolver select an OLDER member than
the one being shipped -- and a PyPI version is never freed, which makes the
mistake permanent.

THE RESOLVER IS NOT REIMPLEMENTED. uv resolves for a target platform and a
target interpreter without installing anything, which is the whole of what this
needs [source: https://docs.astral.sh/uv/pip/compile/]. Writing a resolver here
would be a second opinion about PEP 508 markers, wheel tags and backtracking,
and the one that matters is the installer's.

WHAT REFUSES, AS ONE RULE: a finding refuses when SOMETHING STILL TO BE DONE
would clear it. Everything else about the verdict follows from that and nothing
is decided case by case.

  - a distribution of the release set published nowhere REFUSES: the step could
    have carried the file, and after it nothing can install that name;
  - a distribution IN the step for which the index has no project at all
    REFUSES unless the step acknowledges it, because that file lands only
    through a route that creates the project: a pending Trusted Publisher,
    three per round, which tools/pending-publishers.py prints and the publish
    workflow's bootstrap job spends, or an account token's first upload, which
    is tools/publish-new-projects.sh. Resolution cannot see this -- the file is
    in the step, so everything naming it resolves -- and every one of those
    resolutions is conditional on the route;
  - a resolution this step would break REFUSES, and so does one that succeeds
    while pinning a distribution of the step to some other version;
  - a failure the index ALREADY has, at a version the index already carries,
    is REPORTED and does not refuse, because PyPI never frees a version and no
    upload can reach it.

One acknowledgement moves a refusal into a report, and only by name. The release
order the project follows uploads the core BEFORE the members PyPI has no
project for yet, and creates those afterwards over pending-publisher rounds. So
`--awaiting NAME` says "this release creates NAME later": that project's own
absence, and every cell that fails ONLY because it does not exist yet, go into
an AWAITING CREATION section and do not fail the run. "Only" is asked of the
resolver, not read from its prose: the cell is resolved again with a stand-in
wheel for each acknowledged name, built from that member's own pyproject.toml
so it carries the version and requirements the release will give it, and the
cell is waived exactly when that succeeds.
The acknowledgement is refused outright when a name is not in the release set
tools/build-distributions.sh --list prints, which is a typo or a retired
distribution such as pymetta-host; when the index already carries it, which
leaves nothing to await; or when its pyproject.toml does not declare the
version and requirements statically, which leaves nothing faithful to stand
in. Both routes that create projects acknowledge what they create: the
workflow's resolvable job for the bootstrap and deferred projects, and
tools/publish-new-projects.sh for each name it is about to create.

The last of the four refusal rules is Debian's, in britney2's own words: a migration is
admitted when "installability will not regress", and "if a package has an
existing issue in the target suite, the item including a new version of that
package is generally allowed to migrate if it has the same issue (as it is not
a regression)"
[source: https://release.debian.org/doc/britney/short-intro-to-migrations.html].
It is not a convenience here: pymetta 0.9.1's engine extra cannot be repaired
by any upload, so a gate that refused on it would block for ever the very
uploads that fix the other nine. `dnf repoclosure` asks the same question of an
RPM repository one state at a time [source:
https://dnf-plugins-core.readthedocs.io/en/latest/repoclosure.html].

Assumes:
  - `uv` on PATH or in $UV. It is already this repository's installer
    (`uv sync --extra checks`), so this adds no tool.
  - the index answers PyPI's JSON API at <index>/pypi/<name>/json and a
    PEP 503 index at <index>/simple. A flat directory is the other accepted
    shape, through --flat-index, and is what the selftest uses.
  - `packaging` is importable. It is the specification's own reader for core
    metadata, PEP 503 names, PEP 440 versions and version specifiers, and a
    hand-written copy of any of those would be a second opinion about the
    grammar the installer already decides. It is NOT declared in
    extensions/python/pyproject.toml and arrives transitively under
    `uv sync --extra checks`, through pytest, build, deptry and pip-audit,
    every one of which requires it
    [measured 2026-09-23: packaging 26.3 in .venv-pypetta, named by no extra].
    A clean environment without it raises ModuleNotFoundError naming it.
Guarantees:
  - every (distribution, extra, platform, python) cell that fails is reported
    with the resolver's own words, grouped by the reason so no cell is dropped
    and no paragraph is printed fifteen times
    [tested: tests/checks/check_release_resolvable_selftest.py; commit=89bd27b1e15e5f733a138143196ddef3981001c6]
  - every finding kind reaches the exit status: an unpublished distribution, a
    distribution in the step with no project on the index, a new failure, a
    backtrack, an unreadable file in the step and a step holding one
    distribution twice each exit 1, and only a failure the index already has
    exits 0. A finding that is printed and not counted is a check that
    fails open on the state it was written for
    [tested: tests/checks/check_release_resolvable_selftest.py; commit=89bd27b1e15e5f733a138143196ddef3981001c6]
  - a resolution that SUCCEEDS but pins a distribution of this step to a
    version other than the step's is a backtrack and refuses, which is the
    shape a lagging member takes: it resolves, and the user gets the old one
    [tested: tests/checks/check_release_resolvable_selftest.py; commit=89bd27b1e15e5f733a138143196ddef3981001c6]
  - a distribution of the release set with no version in the step and none on
    the index is named, with the round that creates it, because after this step
    nothing can install it
    [tested: tests/checks/check_release_resolvable_selftest.py; commit=89bd27b1e15e5f733a138143196ddef3981001c6]
  - a distribution in the step whose name the index carries no project for is
    named and refuses unless acknowledged, although every resolution reading
    its file succeeds: the file lands only through a route that creates its
    project
    [tested: tests/checks/check_release_resolvable_selftest.py; commit=89bd27b1e15e5f733a138143196ddef3981001c6]
  - `--awaiting NAME` waives an acknowledged project's absence and exactly the
    cells whose resolution succeeds once it exists as its pyproject.toml
    declares it, keeps refusing any cell with a second cause and any the
    member itself could not satisfy, and is itself refused for a name outside
    the canonical release set, one the index already carries, or one declared
    dynamically; with none given, no probe runs and nothing changes
    [tested: tests/checks/check_release_resolvable_selftest.py; commit=738f36cfe674f987db2fd9890dc6e4706f8a602c]
  - `--upload` is repeatable and the step is their union, so a distribution
    whose files are built in two places -- pymetta's pure wheel and sdist
    beside the manylinux wheels a container writes -- is one upload of one
    distribution [tested: tests/checks/check_release_resolvable_selftest.py;
    commit=89bd27b1e15e5f733a138143196ddef3981001c6]
Fails when:
  - the index answers neither 200 nor 404 for a name. It refuses rather than
    reading a 503 as absence, which is the same fail-closed rule
    tools/publish-new-projects.sh draws, and for the same reason: pypi.org
    answered 503 for two of twenty names on one sweep here
    [measured 2026-09-23: metta-sqlite and metta-remote, 404 on the retry]
    [tested: tests/checks/check_release_resolvable_selftest.py; commit=89bd27b1e15e5f733a138143196ddef3981001c6].
  - a resolution needs to BUILD a source distribution whose build refuses on
    this machine. uv reads static metadata where it can -- janus-swi 1.5.3 is
    sdist-only off Windows and resolved on macOS arm64 with nothing built
    [measured 2026-09-23] -- so this has not been hit, and it would surface as
    a failing cell carrying the build's own error rather than as a wrong pass.
Owns resources: one `uv` subprocess per cell, and one more for a failing cell
    whose meaning needs a second resolution -- the probe with stand-ins under
    --awaiting, and the index-only baseline that decides whether a failure was
    already there -- each started through
    tests/checks/bounded_spawn.py so a killed run cannot leave 495 of them
    unreaped, and run to completion. Under --awaiting it also owns
    ai-tmp/release-check/awaiting.<pid>/, the stand-in wheels, created for the
    run and removed in a `finally` however the run ends; nothing is written to
    /tmp.
Decides:
  - the five platform rows and their uv triples, below. They are fixed outside
    this program by what the project supports, not observable from it.
  - the interpreters are the minor versions the checked distributions' OWN
    classifiers name, so a release that starts claiming 3.15 is checked on it
    with no edit here; the running interpreter is the fallback when the family
    names none.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import argparse
import concurrent.futures
import functools
import json
import os
import re
import shutil
import subprocess  # nosec B404 # only uv and build-distributions.sh, fixed argv
import sys
import tarfile
import time
import tomllib
import urllib.error
import urllib.request
import zipfile
from pathlib import Path
from typing import NamedTuple

from bounded_spawn import bounded
from packaging.metadata import InvalidMetadata, Metadata
from packaging.specifiers import InvalidSpecifier, SpecifierSet
from packaging.utils import canonicalize_name
from packaging.version import Version

ROOT = next(parent for parent in Path(__file__).resolve().parents
            if (parent / "tools" / "build-distributions.sh").is_file())

#: The platforms a reader installs on, as uv spells them. Fixed by what this
#: project supports rather than by anything it can observe, so a constant with
#: its own name beside each triple: the triple is uv's vocabulary and the label
#: is the one a person reads in a refusal.
PLATFORMS = (
    ("linux x86_64", "x86_64-unknown-linux-gnu"),
    ("linux aarch64", "aarch64-unknown-linux-gnu"),
    ("macOS arm64", "aarch64-apple-darwin"),
    ("macOS x86_64", "x86_64-apple-darwin"),
    ("windows amd64", "x86_64-pc-windows-msvc"),
)

#: How many times a 5xx from the index is retried before the run refuses. Not a
#: guess at a duration: it is the number of independent observations taken
#: before calling an answer the index's own, and two sufficed on 2026-09-23.
ATTEMPTS = 3

_PYTHON_CLASSIFIER = re.compile(r"^Programming Language :: Python :: (\d+\.\d+)$")
_EXTRA_MARKER = re.compile(r"""extra\s*==\s*["']([^"']+)["']""")
_PIN = re.compile(r"^([A-Za-z0-9][A-Za-z0-9._-]*)==([^\s;]+)\s*$")


class Facts(NamedTuple):
    """What one distribution's own metadata says about where it installs.

    Read from the distribution file wherever there is one, so the extras this
    checks are the extras a resolver sees rather than a manifest's opinion of
    them: the tree can have moved on from what was uploaded, and the uploaded
    one is what a user resolves.
    """

    version: str
    extras: tuple[str, ...]
    requires_python: SpecifierSet
    #: Minor versions this distribution's classifiers name, e.g. ("3.12",).
    #: Empty is normal and means the classifiers say only "Python :: 3".
    pythons: tuple[str, ...]


class Cell(NamedTuple):
    """One question: this entry point, on this platform, for this interpreter."""

    distribution: str
    version: str
    extra: str | None
    platform: str
    triple: str
    python: str

    @property
    def requirement(self) -> str:
        """What a reader would type, which is what gets resolved."""
        extra = f"[{self.extra}]" if self.extra else ""
        return f"{self.distribution}{extra}=={self.version}"

    @property
    def where(self) -> str:
        """The platform and interpreter, as a report names them."""
        return f"{self.platform} / cp{self.python.replace('.', '')}"


class Verdict(NamedTuple):
    """A cell's answer, with the resolver's own words when it is not `ok`."""

    cell: Cell
    kind: str  # ok | failed | backtrack | awaited
    reason: str
    preexisting: bool


def write_wheel(directory: Path, name: str, version: str, metadata: str) -> Path:
    """One pure wheel carrying exactly this metadata, which is all a resolver reads.

    The CHECK needs one: an acknowledged project has no files anywhere, and
    standing one in is how the resolver is asked whether a cell fails for that
    reason alone. tests/checks/check_release_resolvable_selftest.py writes its
    fixtures through this same function, so a wheel's container is described
    once in this tree rather than twice.
    """
    directory.mkdir(parents=True, exist_ok=True)
    module = name.replace("-", "_")
    stem = f"{module}-{version}"
    path = directory / f"{stem}-py3-none-any.whl"
    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr(f"{stem}.dist-info/METADATA", metadata)
        archive.writestr(f"{stem}.dist-info/WHEEL",
                         "Wheel-Version: 1.0\nGenerator: check_release_resolvable\n"
                         "Root-Is-Purelib: true\nTag: py3-none-any\n")
        archive.writestr(f"{module}.py", "\n")
        archive.writestr(f"{stem}.dist-info/RECORD",
                         f"{module}.py,,\n{stem}.dist-info/RECORD,,\n")
    return path


def under_extra(requirement: str, extra: str) -> str:
    """A Requires-Dist line for a requirement moved under an extra.

    PEP 508 gives a requirement ONE marker expression, so the extra is ANDed
    into any marker it already has rather than written as a second `;` clause,
    which is invalid metadata that `packaging` rejects whole
    [source: https://peps.python.org/pep-0508/#grammar].
    """
    left, _, marker = requirement.partition(";")
    condition = (f'({marker.strip()}) and extra == "{extra}"' if marker.strip()
                 else f'extra == "{extra}"')
    return f"Requires-Dist: {left.strip()}; {condition}"


def declared_metadata(name: str) -> str | None:
    """The core metadata a release-set member will be built with, or None.

    Read from the member's own ext/<name>/pyproject.toml, the file
    tools/build-distributions.sh found it by, and transcribed field for field
    the way PEP 621 defines them: `dependencies` are Requires-Dist,
    `optional-dependencies` are Provides-Extra with their requirements under
    the extra's marker, `requires-python` is Requires-Python
    [source: https://packaging.python.org/en/latest/specifications/pyproject-toml/].
    Only the fields a resolver reads, because a stand-in is resolved and never
    installed. None when the tree does not declare them statically, since a
    stand-in guessed at is exactly the thing this is here to avoid.
    """
    manifest = ROOT / "ext" / name / "pyproject.toml"
    if not manifest.is_file():
        return None
    project = tomllib.loads(manifest.read_text(encoding="utf-8")).get("project", {})
    resolved_by = {"version", "requires-python", "dependencies", "optional-dependencies"}
    if (canonicalize_name(project.get("name", "")) != name or "version" not in project
            or resolved_by & set(project.get("dynamic", []))):
        return None
    lines = ["Metadata-Version: 2.1", f"Name: {project['name']}",
             f"Version: {project['version']}"]
    if project.get("requires-python"):
        lines.append(f"Requires-Python: {project['requires-python']}")
    lines += [f"Requires-Dist: {requirement}" for requirement in project.get("dependencies", [])]
    for extra, requirements in project.get("optional-dependencies", {}).items():
        lines.append(f"Provides-Extra: {extra}")
        lines += [under_extra(requirement, extra) for requirement in requirements]
    return "\n".join(lines) + "\n"


def stand_ins(directory: Path, declared: dict[str, str]) -> list[str]:
    """A find-links directory standing in for projects that do not exist yet.

    Each stand-in is the member AS THE TREE WILL BUILD IT: its declared version,
    requirements and extras, not a bare name. That is what makes the probe
    answer "fails only because this does not exist yet" rather than "fails
    because this does not exist yet, among other things": a member whose own
    pin lags -- `pymetta==0.9.1` in a 0.9.2 release -- leaves the core's extra
    unresolvable even once it exists, and a stand-in carrying the name alone
    would waive exactly the hazard this check was written for. `declared` is the
    one computation main() refused every acknowledgement against, so each name
    here has its metadata.
    """
    for name, metadata in declared.items():
        version = Metadata.from_email(metadata, validate=False).version
        write_wheel(directory, name, str(version), metadata)
    return ["--find-links", str(directory)] if declared else []


def _metadata_text(path: Path) -> str:
    """The METADATA of a wheel or the PKG-INFO of an sdist, as text.

    One reader for both, because the step directory and a flat index hold the
    same two shapes and the fields this wants are the same core metadata in
    each [source: https://packaging.python.org/en/latest/specifications/core-metadata/].
    """
    if path.name.endswith(".whl"):
        with zipfile.ZipFile(path) as archive:
            inner = next(name for name in archive.namelist()
                         if name.endswith(".dist-info/METADATA") and name.count("/") == 1)
            return archive.read(inner).decode("utf-8", "replace")
    with tarfile.open(path) as archive:  # nosec B202 # nothing is extracted to disk
        member = next(entry for entry in archive.getmembers()
                      if entry.name.endswith("/PKG-INFO") and entry.name.count("/") == 1)
        handle = archive.extractfile(member)
        if handle is None:
            unreadable = f"{path} has an unreadable PKG-INFO"
            raise ValueError(unreadable)
        return handle.read().decode("utf-8", "replace")


def _facts_of_file(path: Path) -> tuple[str, Facts]:
    """One distribution file's canonical name and what its metadata says.

    Parsed by `packaging.metadata`, which is the specification's own reader:
    it normalises the name and every extra, hands back `requires_python` as a
    SpecifierSet and `requires_dist` as Requirements, and a second reading of
    core metadata here would be a second opinion about the same file
    [source: https://packaging.python.org/en/latest/specifications/core-metadata/].
    """
    parsed = Metadata.from_email(_metadata_text(path), validate=False)
    extras = {canonicalize_name(value) for value in parsed.provides_extra or []}
    for requirement in parsed.requires_dist or []:
        if requirement.marker:
            extras.update(canonicalize_name(found)
                          for found in _EXTRA_MARKER.findall(str(requirement.marker)))
    pythons = tuple(found.group(1) for value in parsed.classifiers or []
                    for found in [_PYTHON_CLASSIFIER.match(value)] if found)
    return canonicalize_name(parsed.name), Facts(
        version=str(parsed.version),
        extras=tuple(sorted(extras)),
        requires_python=parsed.requires_python or SpecifierSet(""),
        pythons=pythons,
    )


class Directory(NamedTuple):
    """What a directory of files holds, and what in it could not be read."""

    held: dict[str, dict[str, Facts]]
    unreadable: list[str]


def read_directory(directory: Path) -> Directory:
    """Every distribution a directory of files holds, by name and version.

    The same function serves the upload step and a flat index, because they
    are the same thing seen from two sides: a set of files uv can install
    from. A file whose NAME is not a distribution's is skipped, since a dist/
    carries logs beside its artifacts; one that is named like a distribution
    and cannot be read is REPORTED, because the alternative is a release gate
    that quietly checks fewer files than the upload sends. The selftest found
    this by planting a wheel with an invalid Requires-Dist: the whole step
    read as empty and every case about it passed for no reason
    [tested: tests/checks/check_release_resolvable_selftest.py; commit=89bd27b1e15e5f733a138143196ddef3981001c6].
    """
    found: dict[str, dict[str, Facts]] = {}
    unreadable: list[str] = []
    for path in sorted(directory.iterdir()) if directory.is_dir() else []:
        if not (path.name.endswith(".whl") or path.name.endswith(".tar.gz")):
            continue
        try:
            name, facts = _facts_of_file(path)
        except (InvalidMetadata, KeyError, ValueError, StopIteration, OSError,
                zipfile.BadZipFile, tarfile.TarError) as error:
            unreadable.append(f"{path.name}: {error}")
            continue
        # A wheel wins a tie: it is what a resolver reads without building,
        # and it carries the same core metadata the sdist does.
        held = found.setdefault(name, {})
        if facts.version not in held or path.name.endswith(".whl"):
            held[facts.version] = facts
    return Directory(found, unreadable)


class FlatIndex:
    """An index that is a directory of files, which is what the selftest plants."""

    def __init__(self, directory: Path) -> None:
        """Read the directory once; every question below is answered from it."""
        self.directory = directory
        self.held, self.unreadable = read_directory(directory)

    def latest(self, name: str) -> str | None:
        """The newest version of a name here, by PEP 440 ordering, or None."""
        versions = self.held.get(canonicalize_name(name))
        return max(versions, key=Version) if versions else None

    def has(self, name: str, version: str) -> bool:
        """Whether this index carries that exact release."""
        return version in self.held.get(canonicalize_name(name), {})

    def facts(self, name: str, version: str) -> Facts:
        """What that release's own metadata says about where it installs."""
        return self.held[canonicalize_name(name)][version]

    def uv_args(self) -> list[str]:
        """How uv is told to resolve against this index and nothing else."""
        return ["--no-index", "--find-links", str(self.directory), "--offline"]

    def __str__(self) -> str:
        """What a report calls this index."""
        return f"flat index {self.directory}"


class WebIndex:
    """PyPI, or anything answering its JSON API and a PEP 503 simple index."""

    def __init__(self, base: str) -> None:
        """Answers are cached per path, so one name costs one request."""
        self.base = base.rstrip("/")
        self._cache: dict[str, dict | None] = {}

    def _json(self, path: str) -> dict | None:
        """The document, or None for 404. Any other answer stops the run.

        Fail-closed, the rule tools/publish-new-projects.sh draws: only 404
        means absent, and reading a 503 as absence would report a published
        project as missing and a release as broken that is not.
        """
        if path in self._cache:
            return self._cache[path]
        last = ""
        for attempt in range(ATTEMPTS):
            try:
                with urllib.request.urlopen(  # nosec B310 # scheme comes from --index
                        f"{self.base}{path}", timeout=30) as answer:
                    self._cache[path] = json.loads(answer.read().decode())
                    return self._cache[path]
            except urllib.error.HTTPError as error:
                if error.code == 404:
                    self._cache[path] = None
                    return None
                last = f"HTTP {error.code}"
            except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
                last = str(error)
            if attempt + 1 < ATTEMPTS:
                time.sleep(2 ** attempt)
        unanswered = (
            f"release-resolvable: {self.base}{path} answered {last} on {ATTEMPTS} attempts,\n"
            "which says neither present nor absent. Refusing rather than reporting an\n"
            "index answer nobody has.")
        raise SystemExit(unanswered)

    def latest(self, name: str) -> str | None:
        """The version the index itself calls current, or None for 404."""
        document = self._json(f"/pypi/{canonicalize_name(name)}/json")
        return document["info"]["version"] if document else None

    def has(self, name: str, version: str) -> bool:
        """Whether the index carries that exact release."""
        return self._json(f"/pypi/{canonicalize_name(name)}/{version}/json") is not None

    def facts(self, name: str, version: str) -> Facts:
        """What the index says about a release, from the metadata it parsed.

        `provides_extra` alone is not enough: it reads None for a release with
        no extras and there is no way to tell that from a column never filled,
        so the extras named in `requires_dist` markers are unioned in. Both are
        warehouse's own parse of the uploaded metadata
        [measured 2026-09-23: pymetta 0.9.1 answers thirteen extras and
        metta-arrays 0.9.1 answers None, which is its pyproject exactly].
        """
        document = self._json(f"/pypi/{canonicalize_name(name)}/{version}/json")
        if document is None:
            absent = f"{name}=={version} is not on {self.base}"
            raise KeyError(absent)
        info = document["info"]
        extras = {canonicalize_name(value) for value in info.get("provides_extra") or []}
        for requirement in info.get("requires_dist") or []:
            extras.update(canonicalize_name(found) for found in _EXTRA_MARKER.findall(requirement))
        pythons = tuple(found.group(1) for value in info.get("classifiers") or []
                        for found in [_PYTHON_CLASSIFIER.match(value)] if found)
        try:
            wanted = SpecifierSet(info.get("requires_python") or "")
        except InvalidSpecifier:
            # An index can carry a Requires-Python no specifier grammar accepts;
            # treating it as unconstrained checks MORE interpreters, never fewer.
            wanted = SpecifierSet("")
        return Facts(version=version, extras=tuple(sorted(extras)),
                     requires_python=wanted, pythons=pythons)

    def uv_args(self) -> list[str]:
        """How uv is told to resolve against this index."""
        return ["--index-url", f"{self.base}/simple"]

    def __str__(self) -> str:
        """What a report calls this index."""
        return self.base


def release_set() -> list[str]:
    """Every distribution this repository publishes, as its own builder says.

    Read from tools/build-distributions.sh --list rather than re-globbed here,
    for the reason tools/pending-publishers.py gives: a second definition of
    "what the release publishes" is free to drift from the one the release uses.
    """
    listed = subprocess.run(  # nosec B603
        bounded(["sh", str(ROOT / "tools" / "build-distributions.sh"), "--list"]),
        capture_output=True, text=True, check=True).stdout.split()
    if not listed:
        silent = "release-resolvable: build-distributions.sh --list named nothing"
        raise SystemExit(silent)
    return [canonicalize_name(name) for name in listed]


def resolve(uv: str, requirement: str, cell: Cell,
            arguments: list[str]) -> tuple[bool, dict[str, str], str]:
    """One resolution, for one platform and one interpreter.

    --no-config because this repository's own pyproject.toml carries a
    [tool.uv.workspace], and a resolution that picked it up would answer about
    the working tree instead of about the index.

    Bounded, because a run of this spawns one uv per cell -- 495 of them on the
    real release -- and a killed session would otherwise leave every one of
    them with no bound at all. No ceiling is passed: a resolution is allowed to
    take as long as it takes, and bounded.sh's own hour is the orphan reaper
    for a run nobody is waiting on rather than a deadline on the work.
    """
    done = subprocess.run(  # nosec B603
        bounded([uv, "pip", "compile", "--no-config", "--quiet", "--no-header",
                 "--no-annotate", "--python-platform", cell.triple,
                 "--python-version", cell.python, *arguments, "-"]),
        input=f"{requirement}\n", capture_output=True, text=True, check=False)
    pins = {}
    for line in done.stdout.splitlines():
        found = _PIN.match(line)
        if found:
            pins[canonicalize_name(found.group(1))] = found.group(2)
    return done.returncode == 0, pins, (done.stderr.strip() or done.stdout.strip())


class Run(NamedTuple):
    """What every cell of one run is judged against; only the cell varies."""

    uv: str
    index: FlatIndex | WebIndex
    step_versions: dict[str, str]
    step_links: list[str]
    #: Empty unless --awaiting named something, and then the probe that tells a
    #: cell failing for an awaited project from one failing for anything else.
    awaited_links: list[str]


def judge(run: Run, cell: Cell) -> Verdict:
    """Resolve one cell, and say what its answer means for this step.

    Four outcomes, and the second is the one nothing was looking for: a
    resolution can SUCCEED and still be wrong, by pinning a distribution this
    step is uploading to some other version. That is what a lagging member
    does -- the exact pin on the core sends the resolver back to an older
    member, the install works, and the user has the wrong one.
    """
    uv, index, step_versions, step_links, awaited_links = run
    after = index.uv_args() + step_links
    ok, pins, reason = resolve(uv, cell.requirement, cell, after)
    if ok:
        wrong = [f"{name} resolved to {pins[name]} where this step sends {wanted}"
                 for name, wanted in step_versions.items()
                 if name in pins and pins[name] != wanted]
        if wrong:
            return Verdict(cell, "backtrack", "; ".join(wrong), preexisting=False)
        return Verdict(cell, "ok", "", preexisting=False)
    # ONLY because of an acknowledged project, asked of the resolver rather
    # than of its prose: run the same cell again with a stand-in for each
    # acknowledged name and see whether it resolves. uv names ONE unavailable
    # package in a message answering a whole extra, so reading the reason would
    # waive a cell whose second cause nobody saw; a resolution that succeeds
    # once those names exist, and only then, is the claim being made.
    if awaited_links and resolve(uv, cell.requirement, cell, after + awaited_links)[0]:
        return Verdict(cell, "awaited", reason, preexisting=False)
    # Britney's question: did the index already have this failure? Only asked
    # when the step contributes files at all and when the index really carries
    # this exact release, because a version the index does not have cannot have
    # failed there for any reason but its own absence.
    preexisting = False
    if step_links and index.has(cell.distribution, cell.version):
        preexisting = not resolve(uv, cell.requirement, cell, index.uv_args())[0]
    elif not step_links:
        preexisting = index.has(cell.distribution, cell.version)
    return Verdict(cell, "failed", reason, preexisting=preexisting)


def _pythons_for(facts: Facts, candidates: tuple[str, ...]) -> list[str]:
    """The interpreters a distribution claims, out of the family's candidates."""
    return [python for python in candidates if facts.requires_python.contains(python)]


def report(verdicts: list[Verdict], acknowledged: list[str]) -> None:
    """Every failing cell, grouped by the reason it failed.

    Grouped rather than listed one paragraph each: the same resolver message
    answers fifteen cells of one entry point, and printing it fifteen times
    buries the second entry point. The cells are all still named, which is what
    the report owes.

    One stream, stdout, for the whole report including the refusals: a gate's
    log is read in order, and splitting a verdict across two streams printed
    the summary above the findings it summarised.
    """
    # Refusals first, then what does not refuse: a reader deciding whether the
    # step may go needs the blocking sections at the top, and each section is
    # printed whole, so the acknowledged names sit with the cells they explain.
    for heading, chosen, names in (
            ("NEW FAILURES, which this step would introduce",
             [v for v in verdicts if v.kind == "failed" and not v.preexisting], []),
            ("BACKTRACKS, where the resolution succeeds with the wrong version",
             [v for v in verdicts if v.kind == "backtrack"], []),
            ("AWAITING CREATION, acknowledged with --awaiting. These projects do "
             "not exist on the index and this release creates them, through a "
             "pending Trusted Publisher three per round or through "
             "tools/publish-new-projects.sh. Nothing here fails the run, and a cell "
             "is here only when the same resolution succeeds once they exist",
             [v for v in verdicts if v.kind == "awaited"], acknowledged),
            ("PRE-EXISTING FAILURES, which the index already has and this step "
             "neither causes nor fixes",
             [v for v in verdicts if v.kind == "failed" and v.preexisting], [])):
        if not chosen and not names:
            continue
        print(f"\n{heading}:")
        for name in names:
            print(f"  {name}")
        if names and chosen:
            print("  and the cells that fail only for them:")
        grouped: dict[tuple[str, str], list[Cell]] = {}
        for verdict in chosen:
            grouped.setdefault((verdict.cell.requirement, verdict.reason),
                               []).append(verdict.cell)
        for (requirement, reason), cells in sorted(grouped.items()):
            print(f"  {requirement}")
            print(f"    on {', '.join(cell.where for cell in cells)}")
            for line in reason.splitlines():
                print(f"    | {line}")


def main(argv: list[str] | None = None) -> int:
    """The whole check: read the step, build the cells, judge them, report."""
    parser = argparse.ArgumentParser(
        description="Resolve every entry point this repository publishes, "
                    "against the live index plus one upload step's files.")
    parser.add_argument("--upload", type=Path, action="append",
                        help="a directory of files this upload step will send; "
                             "repeatable, because one step's files can be built in "
                             "more than one place (defaults to $DIST, else dist/)")
    parser.add_argument("--index", default="https://pypi.org",
                        help="an index answering PyPI's JSON API and /simple")
    parser.add_argument("--flat-index", type=Path,
                        help="use a directory of files as the index instead")
    parser.add_argument("--distribution", action="append", default=[],
                        help="check this distribution instead of the release set")
    parser.add_argument("--python", action="append", default=[],
                        help="check this interpreter instead of the declared ones")
    parser.add_argument("--jobs", type=int, default=8,
                        help="resolutions to run at once")
    parser.add_argument("--awaiting", action="append", default=[],
                        help="a release-set project this release creates later, whose "
                             "absence, and the cells failing only for it, are reported "
                             "without failing the run; repeatable")
    arguments = parser.parse_args(argv)

    uv = os.environ.get("UV") or shutil.which("uv")
    if not uv:
        print("release-resolvable: no uv on PATH and $UV is unset. This repository\n"
              "already installs with it (`uv sync --extra checks`); install it from\n"
              "https://docs.astral.sh/uv/getting-started/installation/", file=sys.stderr)
        return 2

    index = FlatIndex(arguments.flat_index) if arguments.flat_index else WebIndex(arguments.index)
    #: One step, however many directories its files were built into. pymetta
    #: 0.9.2 is the case that forced it: `python -m build` writes its sdist and
    #: pure wheel where the release is staged, and the manylinux wheels
    #: carrying the patched SWI come out of a container into a directory of
    #: their own, and all of them are one upload of one distribution.
    uploads = arguments.upload or [Path(os.environ.get("DIST", ROOT / "dist"))]
    step: dict[str, dict[str, Facts]] = {}
    unreadable: list[str] = []
    for upload in uploads:
        held, refused = read_directory(upload)
        unreadable += refused
        for name, versions in held.items():
            step.setdefault(name, {}).update(versions)
    step_links = [argument for upload in uploads if upload.is_dir()
                  for argument in ("--find-links", str(upload))] if step else []

    unreadable += getattr(index, "unreadable", [])
    if unreadable:
        for problem in unreadable:
            print(f"release-resolvable: {problem}")
        print("A file named like a distribution that cannot be read is one this check "
              "would silently leave out of an upload it is meant to be checking.")
        return 1

    ambiguous = {name: sorted(versions) for name, versions in step.items() if len(versions) > 1}
    if ambiguous:
        for name, versions in sorted(ambiguous.items()):
            print(f"release-resolvable: this step holds {name} at "
                  f"{' and '.join(versions)}; an upload step sends one version of a "
                  "distribution, and which one a resolver picks is not this check's "
                  "to guess")
        return 1

    narrowed = [canonicalize_name(name) for name in arguments.distribution]
    family = narrowed or release_set()
    checked = sorted(set(family) | set(step))
    step_versions = {name: next(iter(versions)) for name, versions in step.items()}

    #: The acknowledgement is itself checked before anything it would waive:
    #: a name outside the release set is a typo or a retired distribution --
    #: pymetta-host is the one this exists to catch -- and a name the index
    #: already carries has nothing left to await. Either would turn a real
    #: refusal into a line nobody reads, so either refuses the run outright.
    #: Membership is asked of the CANONICAL release set even when
    #: --distribution narrows what is checked, because narrowing the check
    #: does not change what the release publishes.
    acknowledged = sorted({canonicalize_name(name) for name in arguments.awaiting})
    release = (release_set() if narrowed else family) if acknowledged else []
    #: Computed once and used twice, by the refusal below and by the stand-ins,
    #: so a stand-in can never be asked of a name nobody declared.
    declared = {name: declared_metadata(name) for name in acknowledged}

    def refusal(name: str) -> str | None:
        """Why this acknowledgement cannot stand, by the first rule it breaks."""
        if name not in release:
            return (f"not in the release set build-distributions.sh --list prints "
                    f"({', '.join(release)}), so there is nothing of this release to await")
        if (published := index.latest(name)) is not None:
            return f"{index} already carries it at {published}, so there is nothing left to await"
        if declared[name] is None:
            return (f"ext/{name}/pyproject.toml does not declare its version and "
                    "requirements statically, so nothing can stand in for it and no cell "
                    "needing it could be told apart from one failing for another reason")
        return None

    misnamed = [f"--awaiting {name}: {why}" for name in acknowledged
                if (why := refusal(name)) is not None]
    if misnamed:
        for problem in misnamed:
            print(f"release-resolvable: {problem}")
        print("An acknowledgement waives a refusal, so it is refused itself when it "
              "names anything but a project this release has yet to create.")
        return 1

    #: Version and facts per distribution: the step's when it sends one,
    #: otherwise what the index publishes. That is what a user gets after this
    #: step, which is the only state the question is about.
    entries: dict[str, Facts] = {}
    unpublished: list[str] = []
    for name in checked:
        if name in step_versions:
            entries[name] = step[name][step_versions[name]]
            continue
        latest = index.latest(name)
        if latest is None:
            unpublished.append(name)
            continue
        entries[name] = index.facts(name, latest)

    #: In the step, and PyPI has no project of that name at all. Every
    #: resolution below reads its file and succeeds, which is what a resolver
    #: would do once it is uploaded -- and the upload itself is what has not
    #: happened: warehouse creates a project on first use only for a pending
    #: Trusted Publisher, three at a time. So this is invisible to resolution
    #: and decides whether any of it holds.
    unfounded = sorted(name for name in step_versions if index.latest(name) is None)
    # What the acknowledgement covers is every finding whose ONE cause is that
    # the project does not exist yet: its absence from the index, whether or
    # not this step carries its file. The rest stay refusals.
    unpublished = [name for name in unpublished if name not in acknowledged]
    unfounded = [name for name in unfounded if name not in acknowledged]

    named = sorted({python for facts in entries.values() for python in facts.pythons})
    candidates = tuple(arguments.python or named or [f"{sys.version_info[0]}.{sys.version_info[1]}"])

    cells = [Cell(name, facts.version, extra, label, triple, python)
             for name, facts in sorted(entries.items())
             for extra in (None, *facts.extras)
             for label, triple in PLATFORMS
             for python in _pythons_for(facts, candidates)]

    print(f"release-resolvable: index {index}, upload "
          f"{', '.join(str(upload) for upload in uploads)} "
          f"({len(step)} distribution(s))")
    print(f"  {len(entries)} distribution(s), {len(cells)} cell(s) over "
          f"{len(PLATFORMS)} platform(s) and python {', '.join(candidates)}")

    # The stand-ins live for this run only, under the repository's scratch
    # root, never /tmp, and go when it ends however it ends.
    stand_in_root = ROOT / "ai-tmp" / "release-check" / f"awaiting.{os.getpid()}"
    try:
        run = Run(uv, index, step_versions, step_links,
                  stand_ins(stand_in_root, {name: declared[name] or "" for name in acknowledged}))
        with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, arguments.jobs)) as pool:
            verdicts = list(pool.map(functools.partial(judge, run), cells))
    finally:
        shutil.rmtree(stand_in_root, ignore_errors=True)

    if unpublished:
        print("\nUNPUBLISHED, in the release set with no version in this step and "
              "none on the index. Nothing can install these after this step, and "
              "every extra of this family that names one cannot resolve. These are "
              "what a pending-publisher round creates: tools/pending-publishers.py "
              "prints the rows to register, three per round, and the publish "
              "workflow's bootstrap job uploads them:")
        for name in unpublished:
            print(f"  {name}")
    if unfounded:
        print("\nAWAITING A PYPI PROJECT, in this step with no project on the index. "
              "A file for a project that does not exist lands only through a route "
              "that creates the project: a pending Trusted Publisher, three per "
              "round, which tools/pending-publishers.py prints and the publish "
              "workflow's bootstrap job spends, or an account token's first upload, "
              "which is tools/publish-new-projects.sh. A step that IS such a route "
              "says so with --awaiting for each name it creates. Every resolution "
              "below that reads one of these files is conditional on that:")
        for name in unfounded:
            print(f"  {name}")
    report(verdicts, acknowledged)

    refused = [verdict for verdict in verdicts
               if verdict.kind == "backtrack"
               or (verdict.kind == "failed" and not verdict.preexisting)]
    tolerated = [verdict for verdict in verdicts if verdict.kind == "failed" and verdict.preexisting]
    waived = [verdict for verdict in verdicts if verdict.kind == "awaited"]
    print(f"\n{len(cells) - len(refused) - len(tolerated) - len(waived)} of {len(cells)} "
          f"cell(s) resolve; {len(refused)} refuse this step, {len(tolerated)} were already "
          f"broken, {len(waived)} await an acknowledged project.")
    if unpublished:
        print(f"{len(unpublished)} distribution(s) of the release set are published nowhere.")
    if unfounded:
        print(f"{len(unfounded)} distribution(s) in this step have no PyPI project yet.")
    if acknowledged:
        print(f"{len(acknowledged)} acknowledged with --awaiting: "
              f"{', '.join(acknowledged)}.")
    return 1 if refused or unpublished or unfounded else 0


if __name__ == "__main__":
    sys.exit(main())
