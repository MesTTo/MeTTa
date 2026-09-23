"""Purpose: hold check_release_resolvable to the distinctions it exists for.

Every case plants its own index and its own upload step, with no network and no
real project named.

The checker's value is that it separates four answers about one upload step: a
resolution this step would break, a resolution that SUCCEEDS with the wrong
version of something the step is sending, a failure the index already had, and
a distribution nothing publishes at all. Collapsing the second into "it
resolved" is the defect the whole check exists for -- a member pinning the core
exactly sends the resolver back to an older core, the install works, and the
reader gets the version the release was replacing. Collapsing the third into
the first makes the gate refuse for ever: pymetta 0.9.1's `engine` extra cannot
be repaired by any upload, because PyPI never frees a version.

Every case plants its own index and its own step under ai-tmp, never /tmp,
which is tmpfs on this box, and every distribution is named `relcheck-*` so no
case can reach a real project even if --no-index were ever dropped.

Assumes: uv on PATH or in $UV. No network: the index is a directory and uv is
    given --no-index --offline, so a case cannot pass or fail because of
    pypi.org. The one case that needs an index which ANSWERS binds a
    http.server to 127.0.0.1 on a port the kernel picks, and that one never
    reaches a resolver at all.
Guarantees:
  - a step whose entry points all resolve passes
    [tested: this file; commit=89bd27b1e15e5f733a138143196ddef3981001c6]
  - a step naming a distribution no index carries is refused, and the report
    names the entry point and carries uv's own reason
    [tested: this file; commit=89bd27b1e15e5f733a138143196ddef3981001c6]
  - a step whose member pins an older core is refused as a BACKTRACK even
    though the resolution succeeds
    [tested: this file; commit=89bd27b1e15e5f733a138143196ddef3981001c6]
  - a failure the index already carries is reported and does NOT refuse, and
    an unrelated upload beside it still passes
    [tested: this file; commit=89bd27b1e15e5f733a138143196ddef3981001c6]
  - a distribution of the release set on neither the index nor the step
    REFUSES on its own, with every resolution in that run succeeding
    [tested: this file; commit=89bd27b1e15e5f733a138143196ddef3981001c6]
  - a step holding two versions of one distribution is refused before any
    resolution runs [tested: this file; commit=89bd27b1e15e5f733a138143196ddef3981001c6]
  - the platform axis is real: a requirement gated to one platform's marker
    fails on that platform and nowhere else
    [tested: this file; commit=89bd27b1e15e5f733a138143196ddef3981001c6]
  - the interpreter axis is real: a distribution's own Requires-Python takes
    its cells out of the sweep [tested: this file; commit=89bd27b1e15e5f733a138143196ddef3981001c6]
  - a file named like a distribution that cannot be read refuses rather than
    being skipped [tested: this file; commit=89bd27b1e15e5f733a138143196ddef3981001c6]
  - an index answering neither 200 nor 404 stops the run and names the status,
    rather than reading it as absence [tested: this file; commit=89bd27b1e15e5f733a138143196ddef3981001c6]
  - a step whose files were built into two directories is read as one step
    [tested: this file; commit=89bd27b1e15e5f733a138143196ddef3981001c6]
  - a step file for a name the index has no project for refuses and names the
    pending-publisher round, although every resolution reading it succeeds
    [tested: this file; commit=89bd27b1e15e5f733a138143196ddef3981001c6]
Fails when: nothing about the real tree or the real index. It is a unit test of
    the checker.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import contextlib
import http.server
import io
import shutil
import sys
import threading
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_release_resolvable as checker

SCRATCH = Path(__file__).resolve().parents[2] / "ai-tmp" / "release-check" / "selftest"  # artifact-path-created

#: The interpreters every planted distribution claims, so the checker DERIVES
#: two of them from the classifiers rather than being told. A case that wants
#: one interpreter says so with --python.
CLASSIFIED = ("3.12", "3.13")


def _under_extra(requirement: str, extra: str) -> str:
    """A requirement moved under an extra, keeping any marker it already had.

    PEP 508 gives a requirement ONE marker expression, so an extra is ANDed
    into the marker rather than written as a second `;` clause; the two-clause
    spelling is invalid metadata and `packaging` rejects the whole file
    [source: https://peps.python.org/pep-0508/#grammar].
    """
    left, _, marker = requirement.partition(";")
    condition = f'({marker.strip()}) and extra == "{extra}"' if marker.strip() \
        else f'extra == "{extra}"'
    return f"Requires-Dist: {left.strip()}; {condition}"


def wheel(directory: Path, name: str, version: str, *,
          requires: tuple[str, ...] = (), extras: dict[str, tuple[str, ...]] | None = None,
          requires_python: str = ">=3.12",
          pythons: tuple[str, ...] = CLASSIFIED) -> Path:
    """One pure wheel carrying exactly the metadata a resolver reads.

    Built here rather than through `python -m build` because the fixture is
    the METADATA: a case wants a Requires-Dist nobody can satisfy or a marker
    that holds on one platform, and a setuptools project per case would be
    fifty times the code for the same three headers.
    """
    directory.mkdir(parents=True, exist_ok=True)
    stem = f"{name.replace('-', '_')}-{version}"
    lines = [
        "Metadata-Version: 2.1",
        f"Name: {name}",
        f"Version: {version}",
        f"Requires-Python: {requires_python}",
        *(f"Classifier: Programming Language :: Python :: {python}" for python in pythons),
        *(f"Provides-Extra: {extra}" for extra in (extras or {})),
        *(f"Requires-Dist: {requirement}" for requirement in requires),
        *(_under_extra(requirement, extra)
          for extra, members in (extras or {}).items() for requirement in members),
        "",
        f"{name} {version}",
        "",
    ]
    path = directory / f"{stem}-py3-none-any.whl"
    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr(f"{stem}.dist-info/METADATA", "\n".join(lines))
        archive.writestr(f"{stem}.dist-info/WHEEL",
                         "Wheel-Version: 1.0\nGenerator: selftest\n"
                         "Root-Is-Purelib: true\nTag: py3-none-any\n")
        archive.writestr(f"{name.replace('-', '_')}.py", "\n")
        archive.writestr(f"{stem}.dist-info/RECORD",
                         f"{name.replace('-', '_')}.py,,\n{stem}.dist-info/RECORD,,\n")
    return path


def run(index: Path, step: Path | tuple[Path, ...], distributions: tuple[str, ...],
        pythons: tuple[str, ...] = ()) -> tuple[int, str]:
    """The checker as the release path runs it, with its output captured."""
    steps = step if isinstance(step, tuple) else (step,)
    argv = ["--flat-index", str(index), "--jobs", "6"]
    for directory in steps:
        argv += ["--upload", str(directory)]
    for name in distributions:
        argv += ["--distribution", name]
    for python in pythons:
        argv += ["--python", python]
    written = io.StringIO()
    with contextlib.redirect_stdout(written):
        status = checker.main(argv)
    return status, written.getvalue()


def case_clean(world: Path) -> list[str]:
    """A core and its member, both at the new version: nothing to say."""
    index, step = world / "index", world / "step"
    wheel(index, "relcheck-core", "1.0")
    wheel(index, "relcheck-plug", "1.0", requires=("relcheck-core==1.0",))
    wheel(step, "relcheck-core", "2.0", extras={"p": ("relcheck-plug",)})
    wheel(step, "relcheck-plug", "2.0", requires=("relcheck-core==2.0",))
    status, output = run(index, step, ("relcheck-core", "relcheck-plug"))
    if status != 0:
        return [f"a complete step must pass, got {status}:\n{output}"]
    return [] if "0 refuse this step" in output else [f"expected no refusals:\n{output}"]


def case_missing_project(world: Path) -> list[str]:
    """An extra naming a distribution nothing carries: the pymetta-host shape."""
    index, step = world / "index", world / "step"
    wheel(index, "relcheck-core", "1.0")
    wheel(step, "relcheck-core", "2.0", extras={"p": ("relcheck-ghost",)})
    status, output = run(index, step, ("relcheck-core",))
    wrong = []
    if status != 1:
        wrong.append(f"a step naming an absent project must refuse, got {status}")
    if "NEW FAILURES" not in output or "relcheck-core[p]==2.0" not in output:
        wrong.append("the report must name the failing entry point")
    if "relcheck-ghost" not in output:
        wrong.append("the report must carry uv's own reason, which names the ghost")
    return [f"{problem}:\n{output}" for problem in wrong]


def case_backtrack(world: Path) -> list[str]:
    """A member whose pin lags: it RESOLVES, to the version being replaced.

    relcheck-other 2.0 still pins the 1.0 core, so asking for it drags the old
    core and the old member back in. Every resolution succeeds and the reader
    gets neither of the two the step is sending.
    """
    index, step = world / "index", world / "step"
    wheel(index, "relcheck-core", "1.0")
    wheel(index, "relcheck-plug", "1.0", requires=("relcheck-core==1.0",))
    wheel(index, "relcheck-other", "1.0", requires=("relcheck-core==1.0",))
    wheel(step, "relcheck-core", "2.0")
    wheel(step, "relcheck-plug", "2.0", requires=("relcheck-core==2.0",))
    wheel(step, "relcheck-other", "2.0", requires=("relcheck-core==1.0",),
          extras={"q": ("relcheck-plug",)})
    status, output = run(index, step, ("relcheck-core", "relcheck-plug", "relcheck-other"))
    wrong = []
    if status != 1:
        wrong.append(f"a lagging pin must refuse, got {status}")
    if "BACKTRACKS" not in output:
        wrong.append("a successful resolution with the wrong version is a backtrack")
    if "relcheck-core resolved to 1.0 where this step sends 2.0" not in output:
        wrong.append("the report must name the version resolved and the version sent")
    return [f"{problem}:\n{output}" for problem in wrong]


def case_preexisting(world: Path) -> list[str]:
    """A failure the index already has does not refuse the step that ignores it.

    Britney's rule: an item is allowed to migrate with an issue the target
    suite already has, because that is not a regression. Without it this gate
    refuses every upload for ever on a published version nobody can repair.
    """
    index, step = world / "index", world / "step"
    wheel(index, "relcheck-core", "1.0", extras={"p": ("relcheck-ghost",)})
    wheel(index, "relcheck-plug", "1.0")
    wheel(step, "relcheck-plug", "2.0", requires=("relcheck-core==1.0",))
    status, output = run(index, step, ("relcheck-core", "relcheck-plug"))
    wrong = []
    if status != 0:
        wrong.append(f"a pre-existing failure must not refuse an unrelated step, got {status}")
    if "PRE-EXISTING FAILURES" not in output or "relcheck-core[p]==1.0" not in output:
        wrong.append("a pre-existing failure must still be reported")
    if "NEW FAILURES" in output:
        wrong.append("a failure the index already had is not new")
    return [f"{problem}:\n{output}" for problem in wrong]


def case_unpublished(world: Path) -> list[str]:
    """A distribution of the release set that no index and no step carries.

    It REFUSES on its own, with every resolution in the run succeeding. This
    is the 0.9.1 failure exactly: pymetta-host is named by the release set and
    exists nowhere, and a check that printed that and exited 0 would fail open
    on the one state it was written for.
    """
    index, step = world / "index", world / "step"
    wheel(index, "relcheck-core", "1.0")
    wheel(step, "relcheck-core", "2.0")
    status, output = run(index, step, ("relcheck-core", "relcheck-ghost"))
    wrong = []
    if "UNPUBLISHED" not in output or "relcheck-ghost" not in output:
        wrong.append("a distribution nothing carries must be named")
    if status != 1:
        wrong.append(f"a distribution published nowhere must refuse on its own, got {status}")
    if "0 refuse this step" not in output:
        wrong.append("no resolution failed here, so the refusal is the unpublished one alone")
    return [f"{problem}:\n{output}" for problem in wrong]


def case_two_versions(world: Path) -> list[str]:
    """A step holding one distribution twice: refused before anything resolves."""
    index, step = world / "index", world / "step"
    wheel(index, "relcheck-core", "1.0")
    wheel(step, "relcheck-core", "2.0")
    wheel(step, "relcheck-core", "2.1")
    status, output = run(index, step, ("relcheck-core",))
    if status != 1 or "holds relcheck-core at 2.0 and 2.1" not in output:
        return [f"two versions of one distribution must refuse, got {status}:\n{output}"]
    return []


def case_one_platform(world: Path) -> list[str]:
    """A marker holding on one platform fails there and passes everywhere else."""
    index, step = world / "index", world / "step"
    wheel(index, "relcheck-core", "1.0")
    wheel(step, "relcheck-core", "2.0",
          extras={"p": ('relcheck-ghost; sys_platform == "win32"',)})
    status, output = run(index, step, ("relcheck-core",), pythons=("3.12",))
    wrong = []
    if status != 1:
        wrong.append(f"a failure on one platform refuses, got {status}")
    if "on windows amd64 / cp312\n" not in output:
        wrong.append("the failing cell must name windows and only windows")
    if "linux x86_64 / cp312," in output:
        wrong.append("the platforms whose marker is false must resolve")
    if "1 refuse this step" not in output:
        wrong.append("exactly one of the five platform cells fails")
    return [f"{problem}:\n{output}" for problem in wrong]


def case_requires_python(world: Path) -> list[str]:
    """Requires-Python takes cells out of the sweep, and the count says so."""
    index, step = world / "index", world / "step"
    wheel(index, "relcheck-core", "1.0")
    wheel(step, "relcheck-core", "2.0", requires_python=">=3.13")
    status, output = run(index, step, ("relcheck-core",))
    # Two interpreters are derived from the classifiers and one distribution
    # with one entry point sits on five platforms, so 3.12 being excluded is
    # the difference between ten cells and five.
    if status != 0 or "5 cell(s)" not in output:
        return [f"a >=3.13 distribution owes 5 cells, not 10, got {status}:\n{output}"]
    return []


class _Refusing(http.server.BaseHTTPRequestHandler):
    """An index that answers 503 to everything, which pypi.org really does."""

    def do_GET(self) -> None:
        """Refuse, the way a loaded index refuses."""
        self.send_error(503)

    def log_message(self, format: str, *args: object) -> None:  # noqa: A002  -- the base class names it
        """Say nothing: the selftest's own output is its report."""


def case_index_unanswerable(world: Path) -> list[str]:
    """An index answering neither 200 nor 404 stops the run, naming the status.

    Fail-closed, and measured rather than imagined: pypi.org answered 503 for
    two of twenty names on one sweep here on 2026-09-23. Reading that as
    absence would report a published project as missing and refuse a release
    that is fine.
    """
    step = world / "step"
    wheel(step, "relcheck-core", "2.0")
    server = http.server.HTTPServer(("127.0.0.1", 0), _Refusing)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        argv = ["--index", f"http://127.0.0.1:{server.server_port}",
                "--upload", str(step), "--distribution", "relcheck-absent"]
        written = io.StringIO()
        try:
            with contextlib.redirect_stdout(written):
                status = checker.main(argv)
        except SystemExit as refusal:
            message = str(refusal)
            if "503" not in message or "neither present nor absent" not in message:
                return [f"the refusal must name the status it got: {message}"]
            return []
    finally:
        server.shutdown()
        server.server_close()
        thread.join()
    return [f"an index that cannot answer must stop the run, got {status}:\n"
            f"{written.getvalue()}"]


def case_two_upload_directories(world: Path) -> list[str]:
    """One step whose files were built in two places is still one step.

    pymetta 0.9.2 is the shape: `python -m build` writes the sdist and the
    pure wheel where the release is staged, and the manylinux wheels carrying
    the patched SWI come out of a container into a directory of their own.
    Reading only one of them would report the other's distributions as
    published nowhere, which is a refusal about the checker rather than about
    the release.
    """
    index, built, container = world / "index", world / "step", world / "container"
    wheel(index, "relcheck-core", "1.0")
    wheel(index, "relcheck-plug", "1.0")
    wheel(built, "relcheck-core", "2.0")
    wheel(container, "relcheck-plug", "2.0", requires=("relcheck-core==2.0",))
    status, output = run(index, (built, container), ("relcheck-core", "relcheck-plug"))
    wrong = []
    if status != 0:
        wrong.append(f"both directories are one step, got {status}")
    if "UNPUBLISHED" in output:
        wrong.append("nothing here is published nowhere; both are in the step")
    if "2 distribution(s))" not in output:
        wrong.append("the step holds both distributions")
    return [f"{problem}:\n{output}" for problem in wrong]


def case_awaiting_a_project(world: Path) -> list[str]:
    """A step file for a name the index has no project for refuses.

    Nothing here fails to resolve: the file is in the step, so every reader of
    it is satisfied. What has not happened is the upload, and PyPI creates a
    project on first use only for a pending Trusted Publisher. This is the
    nine integration members of the 0.9.2 release exactly -- their files are
    built and their resolutions are clean, and until each name has a project
    the upload carrying it does not land.
    """
    index, step = world / "index", world / "step"
    wheel(index, "relcheck-core", "1.0")
    wheel(step, "relcheck-core", "2.0", extras={"p": ("relcheck-new",)})
    wheel(step, "relcheck-new", "2.0", requires=("relcheck-core==2.0",))
    status, output = run(index, step, ("relcheck-core", "relcheck-new"))
    wrong = []
    if status != 1:
        wrong.append(f"a step file with no PyPI project must refuse, got {status}")
    if "AWAITING A PYPI PROJECT" not in output or "relcheck-new" not in output:
        wrong.append("the report must name it, with the round that creates it")
    if "pending-publishers.py" not in output:
        wrong.append("the remedy is named beside the refusal, not left to be guessed")
    if "0 refuse this step" not in output or "495" in output:
        wrong.append("every resolution here succeeds; the refusal is the missing project")
    return [f"{problem}:\n{output}" for problem in wrong]


def case_unreadable(world: Path) -> list[str]:
    """A file named like a wheel that is not one: refused, not skipped."""
    index, step = world / "index", world / "step"
    wheel(index, "relcheck-core", "1.0")
    wheel(step, "relcheck-core", "2.0")
    (step / "relcheck_broken-2.0-py3-none-any.whl").write_bytes(b"not a zip")
    status, output = run(index, step, ("relcheck-core",))
    if status != 1 or "relcheck_broken-2.0-py3-none-any.whl" not in output:
        return [f"an unreadable distribution file must refuse, got {status}:\n{output}"]
    return []


def cases():
    """Every case, so the count in the summary cannot drift from the table."""
    return (case_clean, case_missing_project, case_backtrack, case_preexisting,
            case_unpublished, case_two_versions, case_one_platform, case_requires_python,
            case_unreadable, case_index_unanswerable, case_two_upload_directories,
            case_awaiting_a_project)


def main() -> int:
    """Run every case in its own world, and say how many hold."""
    shutil.rmtree(SCRATCH, ignore_errors=True)
    bad = 0
    for case in cases():
        world = SCRATCH / case.__name__
        world.mkdir(parents=True)
        (world / "step").mkdir()
        problems = case(world)
        for problem in problems:
            print(f"  {case.__name__}: {problem}")
        bad += 1 if problems else 0
    shutil.rmtree(SCRATCH, ignore_errors=True)
    total = len(cases())
    print(f"release-resolvable-selftest: {total - bad} of {total} cases hold")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
