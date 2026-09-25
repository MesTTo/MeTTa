"""Purpose: hold a pymetta wheel that carries the SWI host to a first boot that rewrites nothing the install put down, whatever order the installer wrote the files in and wherever it put them.

SWI-Prolog loads a library from its .qlf file unless it judges that file out
of date, and 10.1.14 judged by time alone: '$qlf_out_of_date'/3 in
boot/init.pl calls a .qlf old whenever its .pl is newer, and the load then
compiles the source and writes a new .qlf over the installed one. A wheel
carries no times an installer honours. pip writes the members in archive
order, which puts each .qlf after its .pl, while uv extracts in parallel or
copies in directory order, so a fresh install of pymetta 0.9.2 by uv rewrote
2, 25 or 51 of the 51 bundled library .qlf files its first boot looked up,
each exactly one whose .pl had landed after it [measured
2026-09-25T15:09:50+10:00: pip, uv hardlinked and uv --link-mode=copy
installs of the cp314 wheel from PyPI on ext4], and a uv copy from tmpfs
rewrote all 51 [measured 2026-09-25T13:25:42+10:00]. A host built with
tools/pymetta-host/host-only/swi-qlf-recompiles-unchanged-newer-source.patch
decides by content instead, so this dates every bundled .qlf before every
other file the install wrote, the order in which every one of them reads
stale by time, and requires the boot to leave all of them alone.

Assumes:
  - the wheel's own interpreter: `--python`, or `python3.X` on PATH for the
    wheel's `cp3X` tag
  - `--find-links` names directories holding wheels of every requirement
    the wheel declares without an extra, since pip runs with `--no-index`:
    a gate that reaches the network fails for reasons that are not the tree
    (tools/check.sh), and tools/pymetta-host/assemble.sh downloads them into
    the wheelhouse beside the wheels it builds
  - a host that can run the wheel's platform tag
Guarantees:
  - every file the installed RECORD lists is compared before and after the
    boot by inode, modification time and SHA-256, so a file replaced by a
    rename, rewritten in place, re-dated or removed is a finding naming it
    [tested 2026-09-25T15:55:18+10:00:
    tests/checks/check_wheel_first_boot_selftest.py]
  - a file the boot creates under the bundled host, metta/_host, outside a
    __pycache__ directory, is a finding; one it creates elsewhere is counted
    and allowed, which is the engine's own .qlf cache under metta/_runtime
    that engine/qlf_boot.pl writes on a first boot by design, and Python's
    bytecode [tested 2026-09-25T15:55:18+10:00:
    tests/checks/check_wheel_first_boot_selftest.py]
  - before the boot every bundled .qlf is dated a minute before the oldest
    other installed file, and a wheel with no bundled .qlf beside its source
    is a finding, since then no load was judged at all
    [tested 2026-09-25T15:55:18+10:00:
    tests/checks/check_wheel_first_boot_selftest.py]
  - the boot must exit 0, print that (+ 1 2) answered [[3]], and write
    nothing to stderr, where SWI reports each recompile and where 0.9.0's
    four ERROR lines at first boot went while every value assertion passed
    [tested 2026-09-25T15:55:18+10:00:
    tests/checks/check_wheel_first_boot_selftest.py]
  - each wheel is installed into two fresh venvs and booted once in each,
    the second at another depth under a directory whose name holds a space,
    because a .qlf records the absolute paths it was compiled at and SWI
    relocates them by the directories the saved and loaded paths share
    [source 2026-09-25T15:26:24+10:00: src/pl-qlf.c pushPathTranslation() and
    qlfFixSourcePath() at swipl-devel V10.1.14, commit 69775434c822]
  - exit 1 on any finding, 125 when nothing could be measured (no wheel, no
    interpreter for its tag, or an install pip refused from the local
    files), and 0 when every install holds
    [tested 2026-09-25T15:55:18+10:00:
    tests/checks/check_wheel_first_boot_selftest.py]
Fails when: the wheel's platform cannot run here, which reads as an install
  pip refuses and exits 125 naming it.
Owns resources: one scratch directory per wheel under TMPDIR, removed when
  its checks end, however they end; every child runs under tools/bounded.sh
  through bounded_spawn, so none outlives this process.
Decides: the minute's margin, and the two install paths.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import os
import shutil
import subprocess
import sys
import tempfile
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from bounded_spawn import bounded

#: Where a pymetta wheel carries its SWI host, relative to site-packages
#: (extensions/python/metta/_host/__init__.py).
HOST = Path("metta/_host")

#: How far before the oldest installed file every bundled .qlf is dated. SWI
#: compares the two times strictly, so any margin makes each .qlf read stale;
#: a minute also clears the coarsest resolution a file system rounds a time to.
MARGIN_NS = 60 * 10**9

#: What one first boot runs: the engine's first answer, printed for the check.
BOOT = "from metta import MeTTa\nprint(MeTTa().run('!(+ 1 2)') == [[3]])\n"

#: The two installs, relative to the scratch directory: another depth, and a
#: space in a directory name.
PATHS = ("first", "second install/nested")

#: Exit status for a run that measured nothing, the word tools/check.sh reads
#: as `skipped`.
UNMEASURED = 125


@dataclass(frozen=True)
class Stamp:
    """What a file is, for deciding whether a boot touched it."""

    inode: int
    mtime_ns: int
    digest: str


@dataclass(frozen=True)
class Boot:
    """What a first boot did, as far as the check reads it."""

    returncode: int
    stdout: str
    stderr: str


def stamp(path: Path) -> Stamp | None:
    """The file's identity, time and content, or None where there is no file."""
    try:
        status = path.stat()
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
    except FileNotFoundError:
        return None
    return Stamp(status.st_ino, status.st_mtime_ns, digest)


def change(was: Stamp, now: Stamp | None) -> str | None:
    """How an installed file moved between two stamps, or None when it did not."""
    if now is None:
        return "removed"
    if now.inode != was.inode:
        return "replaced"
    if now.digest != was.digest:
        return "rewrote"
    if now.mtime_ns != was.mtime_ns:
        return "re-dated"
    return None


def record_files(site: Path) -> list[Path]:
    """Every file the installed pymetta RECORD lists, resolved against site-packages."""
    records = sorted(site.glob("pymetta-*.dist-info/RECORD"))
    if len(records) != 1:
        msg = f"{site} holds {len(records)} pymetta RECORD files, not one"
        raise RuntimeError(msg)
    with records[0].open(newline="", encoding="utf-8") as handle:
        return [Path(os.path.normpath(site / row[0])) for row in csv.reader(handle) if row]


def date_qlf_first(site: Path, files: list[Path]) -> int:
    """Date every bundled .qlf before every other installed file; answer how many sit beside a .pl.

    Time: one stat per installed file and one utime per bundled .qlf.
    """
    host = site / HOST
    qlfs = [path for path in files
            if path.suffix == ".qlf" and path.is_relative_to(host) and path.is_file()]
    others = [path.stat().st_mtime_ns for path in files
              if path.suffix != ".qlf" and path.is_file()]
    if not others:
        return 0
    at = min(others) - MARGIN_NS
    for qlf in qlfs:
        os.utime(qlf, ns=(qlf.stat().st_atime_ns, at))
    return sum(qlf.with_suffix(".pl").is_file() for qlf in qlfs)


def tree(root: Path) -> set[Path]:
    """Every file under a directory."""
    return {path for path in root.rglob("*") if path.is_file()}


def inspect_boot(site: Path, boot: Callable[[], Boot]) -> tuple[list[str], int, int]:
    """Date the bundled .qlf files first, run one boot, and answer what it did.

    Answers the findings, how many bundled .qlf files sit beside their source,
    and how many files the boot added outside the host.
    Time: two SHA-256 passes over the installed files and two walks of
    site-packages around the one boot.
    """
    files = record_files(site)
    beside = date_qlf_first(site, files)
    before = {path: was for path in files if (was := stamp(path)) is not None}
    present = tree(site)
    ran = boot()

    found = []
    if not beside:
        found.append("the wheel bundles no .qlf beside its source, so no load was judged")
    if ran.returncode != 0:
        found.append(f"the boot exited {ran.returncode}: {(ran.stderr or ran.stdout)[-400:]!r}")
    elif ran.stdout.strip() != "True":
        found.append(f"the boot printed {ran.stdout.strip()!r} where (+ 1 2) == [[3]] prints True")
    if ran.stderr:
        found.append(f"the boot wrote {len(ran.stderr)} bytes to stderr: {ran.stderr[:400]!r}")
    for path, was in before.items():
        moved = change(was, stamp(path))
        if moved:
            found.append(f"{moved} {os.path.relpath(path, site)}")
    host = site / HOST
    added = sorted(tree(site) - present)
    elsewhere = 0
    for path in added:
        if path.is_relative_to(host) and "__pycache__" not in path.parts:
            found.append(f"added {path.relative_to(site)} under the bundled host")
        else:
            elsewhere += 1
    return found, beside, elsewhere


def combine(statuses: list[int]) -> int:
    """One exit status for several: a finding outranks a run that measured nothing."""
    if 1 in statuses:
        return 1
    return UNMEASURED if UNMEASURED in statuses else 0


def python_version(wheel: Path) -> str | None:
    """The X.Y a wheel's cpXY tag names, or None for a tag naming no one CPython."""
    # {distribution}-{version}(-{build})?-{python}-{abi}-{platform}.whl
    python_tag = wheel.name.removesuffix(".whl").split("-")[-3]
    return f"3.{python_tag[3:]}" if python_tag.startswith("cp3") and python_tag[3:].isdigit() else None


def interpreter(wheel: Path, given: Path | None) -> Path | None:
    """The interpreter a wheel is installed with: the given one, or python3.X for its cp3X tag."""
    if given is not None:
        return given
    version = python_version(wheel)
    found = shutil.which(f"python{version}") if version else None
    return Path(found) if found else None


def run(argv: list[str], cwd: Path, env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    """One bounded child, its output captured."""
    return subprocess.run(bounded(argv), cwd=cwd, env=env, capture_output=True,
                          text=True, check=False)


def install(python: Path, wheel: Path, links: list[Path], root: Path,
            env: dict[str, str]) -> tuple[Path | None, str]:
    """Install a wheel into a fresh venv under root; answer site-packages, or None and pip's words."""
    venv = root / "venv"
    made = run([str(python), "-m", "venv", str(venv)], root, env)
    if made.returncode != 0:
        return None, made.stdout + made.stderr
    bin_python = venv / "bin" / "python"
    pip = [str(bin_python), "-m", "pip", "install", "--quiet", "--no-cache-dir",
           "--disable-pip-version-check", "--no-index"]
    for link in links:
        pip += ["--find-links", str(link)]
    installed = run([*pip, str(wheel)], root, env)
    if installed.returncode != 0:
        return None, installed.stdout + installed.stderr
    asked = run([str(bin_python), "-c",
                 "import sysconfig; print(sysconfig.get_path('platlib'))"], root, env)
    if asked.returncode != 0:
        return None, asked.stdout + asked.stderr
    return Path(asked.stdout.strip()), ""


def first_boot(python: Path, scratch: Path, env: dict[str, str]) -> Callable[[], Boot]:
    """The boot inspect_boot runs: BOOT in a fresh process, in a directory of its own."""
    def boot() -> Boot:
        cwd = scratch / "cwd"
        cwd.mkdir(exist_ok=True)
        ran = run([str(python), "-c", BOOT], cwd, env)
        return Boot(ran.returncode, ran.stdout, ran.stderr)
    return boot


def check_wheel(wheel: Path, python: Path | None, links: list[Path]) -> int:
    """Install and boot one wheel at both paths; print what each did; answer an exit status."""
    print(f"wheel-first-boot: {wheel.name}")
    chosen = interpreter(wheel, python)
    if chosen is None:
        print("  no interpreter for its tag: pass --python, or put the one it names on PATH")
        return UNMEASURED
    statuses = []
    scratch = Path(tempfile.mkdtemp(prefix="wheel-first-boot-"))
    try:
        # Only what a boot needs, so nothing in the caller's environment
        # (SWI_HOME_DIR, LD_LIBRARY_PATH, a PYTHONPATH, pip's configuration
        # through PIP_*) reaches the install or the boot.
        env = {"PATH": "/usr/bin:/bin", "HOME": str(scratch / "home"),
               "TMPDIR": str(scratch / "tmp")}
        for directory in ("home", "tmp"):
            (scratch / directory).mkdir()
        for place in PATHS:
            root = scratch / place
            root.mkdir(parents=True)
            site, refusal = install(chosen, wheel, links, root, env)
            if site is None:
                print(f"  at {place!r}: pip did not install it from the local files, so nothing"
                      f" was measured:\n    {refusal.strip()[-600:]}")
                statuses.append(UNMEASURED)
                continue
            boot = first_boot(root / "venv" / "bin" / "python", root, env)
            found, beside, elsewhere = inspect_boot(site, boot)
            print(f"  at {place!r}: {beside} bundled .qlf dated before their sources;"
                  f" the boot added {elsewhere} file(s) outside the host;"
                  f" {len(found)} finding(s)")
            for line in found:
                print(f"    {line}")
            statuses.append(1 if found else 0)
    finally:
        shutil.rmtree(scratch, ignore_errors=True)
    return combine(statuses)


def main(argv: list[str] | None = None) -> int:
    """Check every wheel given; exit 1 on a finding, 125 when nothing was measured."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("wheel", type=Path, nargs="*",
                        help="a pymetta wheel carrying the host, as tools/pymetta-host/assemble.sh builds it")
    parser.add_argument("--python", type=Path,
                        help="the interpreter to install with; by default python3.X on PATH for the cp3X tag")
    parser.add_argument("--find-links", type=Path, action="append", default=[],
                        help="a directory of wheels for the requirements; pip runs with --no-index")
    args = parser.parse_args(argv)
    if not args.wheel:
        print("wheel-first-boot: no wheel given, so nothing was measured. The wheels are a build"
              " artefact; tools/pymetta-host/assemble.sh runs this on each one it builds.")
        return UNMEASURED
    links = [link.resolve() for link in args.find_links]
    return combine([check_wheel(wheel.resolve(), args.python, links) for wheel in args.wheel])


if __name__ == "__main__":
    sys.exit(main())
