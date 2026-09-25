"""Purpose: hold check_wheel_first_boot to what it reports about a boot, without a wheel, pip or SWI.

The check's verdict is only as good as its reading of the install, so each
way a boot can touch an installed file is planted here and the check has to
name it: a replacement by rename, which is how SWI installs a recompiled .qlf
and which leaves the bytes possibly identical; a rewrite in place; a new
time alone; a removal; a new file under the bundled host. So is each way a
boot can go wrong without touching a file, and the two files a first boot is
allowed to add, since a check that refuses those would be one nobody could
pass.

Assumes: nothing about any real wheel or host; every case plants its own
    site-packages under a temporary directory and boots with a function.
Guarantees:
  - each planted change to an installed file is reported under its own word,
    and an untouched install is not, in case_boots
    [tested 2026-09-25T23:17:35+10:00: tests/checks/check_wheel_first_boot_selftest.py]
  - a file added under the bundled host is reported, one added under the
    engine's runtime or in a __pycache__ is counted and allowed, in case_boots
    [tested 2026-09-25T23:17:35+10:00: tests/checks/check_wheel_first_boot_selftest.py]
  - every bundled .qlf is dated before every other installed file, and an
    install bundling no .qlf beside its source is reported, in case_dating
    and case_no_qlf_beside_a_source
    [tested 2026-09-25T23:17:35+10:00: tests/checks/check_wheel_first_boot_selftest.py]
  - a boot that exits nonzero, prints anything but True, or writes to
    stderr is reported, in case_boots
    [tested 2026-09-25T23:17:35+10:00: tests/checks/check_wheel_first_boot_selftest.py]
  - statuses combine to 1 over 125 over 0, and a run given no wheel exits
    125, in case_statuses
    [tested 2026-09-25T23:17:35+10:00: tests/checks/check_wheel_first_boot_selftest.py]
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import contextlib
import io
import os
import sys
import tempfile
from collections.abc import Callable
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_wheel_first_boot as checker

LIBRARY = "metta/_host/swipl/lib/swipl/library"
INSTALLED = {
    f"{LIBRARY}/a.pl": "a(1).\n",
    f"{LIBRARY}/a.qlf": "compiled a\n",
    f"{LIBRARY}/b.pl": "b(1).\n",
    f"{LIBRARY}/b.qlf": "compiled b\n",
    "metta/_runtime/engine/x.pl": "x.\n",
    "../../../bin/tool": "#!/bin/sh\n",
}
QUIET = checker.Boot(0, "True\n", "")


def plant(work: Path, files: dict[str, str] = INSTALLED) -> Path:
    """A site-packages holding the files and a RECORD listing them, as pip leaves one."""
    site = work / "venv" / "lib" / "python3.14" / "site-packages"
    record = site / "pymetta-1.0.dist-info" / "RECORD"
    record.parent.mkdir(parents=True)
    for name, text in files.items():
        path = Path(os.path.normpath(site / name))
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
    rows = [f"{name},," for name in files] + ["pymetta-1.0.dist-info/RECORD,,"]
    record.write_text("\n".join(rows) + "\n", encoding="utf-8")
    return site


def acting(act: Callable[[Path], None], ran: checker.Boot = QUIET) -> Callable[[Path], Callable[[], checker.Boot]]:
    """A boot that does `act` to site-packages and answers `ran`."""
    def boot_for(site: Path) -> Callable[[], checker.Boot]:
        def boot() -> checker.Boot:
            act(site)
            return ran
        return boot
    return boot_for


def nothing(site: Path) -> None:
    """A boot that touches no file."""


def replace(site: Path) -> None:
    """SWI's way: the same bytes staged beside the file and renamed over it."""
    target = site / LIBRARY / "a.qlf"
    staged = target.with_name(".a.qlf.1234")
    staged.write_bytes(target.read_bytes())
    staged.replace(target)


def rewrite(site: Path) -> None:
    """New bytes written into the same inode."""
    with (site / LIBRARY / "b.qlf").open("r+b") as handle:
        handle.write(b"recompiled")


def redate(site: Path) -> None:
    """A new time and nothing else."""
    os.utime(site / LIBRARY / "a.pl", ns=(0, 10**9))


def remove(site: Path) -> None:
    """An installed file gone."""
    (site / LIBRARY / "b.pl").unlink()


def add_to_host(site: Path) -> None:
    """A file the host never shipped, written into it."""
    (site / LIBRARY / "c.qlf").write_text("new\n", encoding="utf-8")


def add_caches(site: Path) -> None:
    """What a first boot may add: the engine's artifact and Python's bytecode."""
    (site / "metta/_runtime/engine/x.qlf").write_text("engine cache\n", encoding="utf-8")
    cache = site / "metta/_host/__pycache__"
    cache.mkdir()
    (cache / "__init__.cpython-314.pyc").write_bytes(b"\0")


#: (name, boot, the words each expected finding starts with, how many files
#: the boot may add outside the host)
CASES = [
    ("an untouched install", acting(nothing), [], 0),
    ("a rename over a .qlf", acting(replace), [f"replaced {LIBRARY}/a.qlf"], 0),
    ("a rewrite in place", acting(rewrite), [f"rewrote {LIBRARY}/b.qlf"], 0),
    ("a new time", acting(redate), [f"re-dated {LIBRARY}/a.pl"], 0),
    ("a removal", acting(remove), [f"removed {LIBRARY}/b.pl"], 0),
    ("a file added to the host", acting(add_to_host), [f"added {LIBRARY}/c.qlf under the bundled host"], 0),
    ("the caches a boot may add", acting(add_caches), [], 2),
    ("a boot that fails", acting(nothing, checker.Boot(1, "", "boom")),
     ["the boot exited 1", "the boot wrote 4 bytes to stderr"], 0),
    ("a wrong answer", acting(nothing, checker.Boot(0, "False\n", "")), ["the boot printed 'False'"], 0),
    ("a word on stderr", acting(nothing, checker.Boot(0, "True\n", "% recompiling\n")),
     ["the boot wrote 14 bytes to stderr"], 0),
]


def case_boots(work: Path) -> list[str]:
    """Each planted boot is reported exactly as expected."""
    problems = []
    for index, (name, boot_for, expected, allowed) in enumerate(CASES):
        site = plant(work / str(index))
        found, beside, elsewhere = checker.inspect_boot(site, boot_for(site))
        if beside != 2:
            problems.append(f"{name}: {beside} .qlf read as beside their source, not 2")
        if len(found) != len(expected) or not all(
                line.startswith(want) for line, want in zip(found, expected, strict=True)):
            problems.append(f"{name}: reported {found}, wanted lines starting {expected}")
        if elsewhere != allowed:
            problems.append(f"{name}: counted {elsewhere} file(s) added outside the host, not {allowed}")
    return problems


def case_dating(work: Path) -> list[str]:
    """Every bundled .qlf ends older than every other installed file, a lone one included."""
    site = plant(work, {**INSTALLED, f"{LIBRARY}/lone.qlf": "no source\n"})
    files = checker.record_files(site)
    beside = checker.date_qlf_first(site, files)
    problems = [] if beside == 2 else [f"counted {beside} .qlf beside a source, not 2"]
    qlf = [path.stat().st_mtime_ns for path in files if path.suffix == ".qlf"]
    rest = [path.stat().st_mtime_ns for path in files if path.suffix != ".qlf"]
    if len(qlf) != 3 or max(qlf) >= min(rest):
        problems.append(f"the .qlf times {qlf} do not all precede the other files' {rest}")
    return problems


def case_no_qlf_beside_a_source(work: Path) -> list[str]:
    """An install with nothing to judge is a finding, not a pass."""
    site = plant(work, {"metta/_runtime/engine/x.pl": "x.\n"})
    found, beside, _ = checker.inspect_boot(site, acting(nothing)(site))
    if beside == 0 and found == ["the wheel bundles no .qlf beside its source, so no load was judged"]:
        return []
    return [f"an install with no bundled .qlf reported {found} with {beside} beside a source"]


def case_record_paths(work: Path) -> list[str]:
    """RECORD's paths resolve against site-packages, one outside it included."""
    site = plant(work)
    files = set(checker.record_files(site))
    tool = Path(os.path.normpath(site / "../../../bin/tool"))
    if tool in files and tool.is_file() and site / LIBRARY / "a.qlf" in files:
        return []
    return [f"RECORD resolved to {sorted(files)}"]


def case_statuses(work: Path) -> list[str]:
    """A finding outranks a run that measured nothing, which outranks a pass; no wheel measures nothing."""
    del work
    table = {(0, 0): 0, (0, 125): 125, (125, 1): 1, (): 0}
    problems = [f"combine{list(given)} answered {checker.combine(list(given))}, not {want}"
                for given, want in table.items() if checker.combine(list(given)) != want]
    with contextlib.redirect_stdout(io.StringIO()):
        unmeasured = checker.main([])
    if unmeasured != checker.UNMEASURED:
        problems.append("a run given no wheel did not exit 125")
    tags = {"pymetta-0.9.2-cp314-cp314-manylinux_2_28_x86_64.whl": "3.14",
            "pymetta-0.9.2-cp312-cp312-manylinux_2_28_x86_64.whl": "3.12",
            "pymetta-0.9.2-py3-none-any.whl": None}
    problems += [f"{name} read as {checker.python_version(Path(name))!r}, not {want!r}"
                 for name, want in tags.items() if checker.python_version(Path(name)) != want]
    return problems


def main() -> int:
    """Run every case in a directory of its own; exit 1 if any fails."""
    cases = [case_boots, case_dating, case_no_qlf_beside_a_source, case_record_paths, case_statuses]
    bad = 0
    for case in cases:
        with tempfile.TemporaryDirectory(prefix="wheel-first-boot-selftest-") as scratch:
            problems = case(Path(scratch))
        for problem in problems:
            print(f"  {case.__name__}: {problem}")
        bad += bool(problems)
    print(f"wheel-first-boot-selftest: {len(cases) - bad} of {len(cases)} cases hold")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
