"""Purpose: every host workaround names a ledger entry whose defect still reproduces, and every host patch one whose defect no longer does.

The engine runs on hosts it does not own, SWI-Prolog first among them, and
works around what they do: an inference limit that strikes between a Setup and
its cleanup, an encoding that follows the locale into a compiled artifact, a
load spec that never reaches the artifact rule. Each such workaround used to
live in the prose of the comment that carried it, which is where a later
reader, an upstream fix or a port would have had to find it by reading
everything. So a workaround is recorded twice and this lane holds the two in
step:

  - at the site, a comment line in the file's own comment syntax made of the
    marker, a key, a hyphen and what the site does instead, for example
    `% Workaround: swi-cleanup-window - the marker is a trailed write.`;
  - in `docs/host-workarounds.md`, one entry under `## <key>` with the host,
    the defect as a mechanism, a tracked reproduction and the change that
    lifts it.

The reproduction is what makes an entry more than prose: it prints `present`
while the host still has the defect and `absent` once it does not, and this
lane RUNS it. A workaround whose reason has gone fails the gate naming the
sites to lift, rather than outliving its reason unnoticed.

An entry may instead carry `Patch:`, a tracked patch the host this tree runs
on is built with. That is the dual state: the defect is fixed in the host
rather than worked around in the tree, so the entry needs no site, its
reproduction must answer `absent`, and `present` means this environment's
host was built without the patch; the lane fails naming the patch.

Assumes:
  - the tree is a git checkout: sites are read from `git ls-files`, so a
    scratch file or a linked `node_modules` is never scanned
  - a reproduction is a `.pl` file run as `swipl -q -f none -s FILE -g main
    -t halt` or a `.sh` file run as `sh FILE`, prints its verdict as its last
    non-empty line and exits 0; it reads `HOST_WORKAROUND_SCRATCH` for a fresh
    directory of its own, `SWIPL` for the interpreter, and `CHECK_PY` for the
    Python host, which is always the interpreter running this lane, so a
    janus reproduction imports the janus the gate's interpreter is paired with
    rather than whatever `python3` a bare shell finds
Guarantees:
  - a site whose key has no entry, an entry with no site, an entry missing a
    required field, a key entered twice, a malformed site line and a
    reproduction that is not a tracked .pl or .sh file are each reported with
    their path and line [tested:
    tests/checks/check_host_workarounds_selftest.py; commit=2bd6b250a22d9898ced449595c168a8dc3a78768]
  - an entry whose reproduction answers `absent` is reported with every site
    to lift, and one whose reproduction answers neither word or exits nonzero
    is reported as broken [tested:
    tests/checks/check_host_workarounds_selftest.py; commit=2bd6b250a22d9898ced449595c168a8dc3a78768]
  - an entry carrying `Patch:` passes with no site when its reproduction
    answers `absent`, is reported naming the patch to rebuild with when it
    answers `present`, and is refused when the patch is not a tracked .patch
    file [tested: test_a_patched_host_passes_without_a_site,
    test_a_patched_host_that_still_shows_the_defect_names_the_patch,
    test_a_patch_must_be_tracked; commit=928be33b031956e3eed5a05d62c7f2f3bd534631]
  - the shipped tree passes: every worked-around entry has a site and answers
    `present`, and every patched one answers `absent`, on SWI-Prolog 10.1.13
    with Janus 1.5.3 built with the tracked patches [tested:
    test_the_shipped_tree_passes_its_own_gate; commit=928be33b031956e3eed5a05d62c7f2f3bd534631]
Fails when:
  - read as a count. The number of entries is not a score; the lane's value is
    that every one of them is live, reproduced and findable.
Decides:
  - Markdown and plain-text files are not scanned, because they describe the
    shape rather than carry it
  - a reproduction runs under `bounded.sh` with a 120 second ceiling, in a
    fresh directory of its own under the run's TMPDIR, which a root gate run
    allocates beneath `ai-tmp/check-runs/`
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))

from gate_layout import BOUNDED  # noqa: E402  -- installed above

LEDGER = Path("docs/host-workarounds.md")
KEY = r"[a-z0-9]+(?:-[a-z0-9]+)*"
MARKER = re.compile(r"^[\s%#;/*!]*Workaround:(.*)$")
SITE = re.compile(r"^\s+(" + KEY + r")\s+-\s+(\S.*)$")
FIELD = re.compile(r"^([A-Z][a-z]+(?: [a-z]+)?):\s+(\S.*)$")
REQUIRED = ("Host", "Defect", "Reproduction", "Lifted when")
OPTIONAL = ("Workaround", "Record", "Patch")
UNSCANNED = frozenset({".md", ".txt"})
RUNNABLE = frozenset({".pl", ".sh"})
VERDICTS = frozenset({"present", "absent"})
CEILING_SECONDS = 120


@dataclass(frozen=True)
class Site:
    """One marker line: where it is and which entry it names."""

    path: Path
    line: int
    key: str
    what: str


@dataclass
class Entry:
    """One `## <key>` section of the ledger and the fields it states."""

    key: str
    line: int
    fields: dict[str, str] = field(default_factory=dict)


@dataclass
class Report:
    """What one check of a tree found."""

    sites: list[Site]
    entries: list[Entry]
    findings: list[str]


def tracked_files(root: Path) -> list[Path]:
    """Every file git tracks or has staged under root, relative to it."""
    listing = subprocess.run(
        ["git", "ls-files", "--recurse-submodules", "-z"], cwd=root, capture_output=True, check=True
    )
    return [Path(name) for name in listing.stdout.decode("utf-8").split("\0") if name]


def scan_sites(root: Path, files: list[Path]) -> tuple[list[Site], list[str]]:
    """Find every marker line in the scanned files, reporting the malformed ones."""
    sites: list[Site] = []
    findings: list[str] = []
    for rel in files:
        if rel.suffix in UNSCANNED or rel == LEDGER:
            continue
        try:
            text = (root / rel).read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        for number, line in enumerate(text.splitlines(), 1):
            marked = MARKER.match(line)
            if marked is None:
                continue
            parsed = SITE.match(marked.group(1))
            if parsed is None:
                findings.append(
                    f"{rel}:{number}: malformed workaround line; write"
                    " `Workaround: <key> - <what this site does instead>`"
                )
                continue
            sites.append(Site(rel, number, parsed.group(1), parsed.group(2).strip()))
    return sites, findings


def parse_ledger(text: str) -> tuple[list[Entry], list[str]]:
    """Read the ledger into entries, reporting every defect of shape."""
    entries: list[Entry] = []
    findings: list[str] = []
    current: Entry | None = None
    continuing: str | None = None
    for number, line in enumerate(text.splitlines(), 1):
        if line.startswith("## "):
            key = line[3:].strip()
            if re.fullmatch(KEY, key) is None:
                findings.append(
                    f"{LEDGER}:{number}: heading `{key}` is not a key:"
                    " lowercase words joined by hyphens"
                )
            if any(entry.key == key for entry in entries):
                findings.append(f"{LEDGER}:{number}: `{key}` is entered twice")
            current = Entry(key, number)
            entries.append(current)
            continuing = None
            continue
        if current is None:
            continue
        if not line.strip():
            continuing = None
            continue
        named = FIELD.match(line)
        if named is not None and named.group(1) in REQUIRED + OPTIONAL:
            name = named.group(1)
            if name in current.fields:
                findings.append(f"{LEDGER}:{number}: `{current.key}` states `{name}:` twice")
            current.fields[name] = named.group(2).strip()
            continuing = name
        elif continuing is not None:
            current.fields[continuing] += " " + line.strip()
    for entry in entries:
        findings.extend(
            f"{LEDGER}:{entry.line}: `{entry.key}` lacks `{name}:`"
            for name in REQUIRED
            if name not in entry.fields
        )
    return entries, findings


def cross_check(sites: list[Site], entries: list[Entry]) -> list[str]:
    """Hold the sites and the entries to each other in both directions."""
    keys = {entry.key for entry in entries}
    carried = {site.key for site in sites}
    findings = [
        f"{site.path}:{site.line}: `{site.key}` has no entry in {LEDGER}"
        for site in sites
        if site.key not in keys
    ]
    # A patched host has nothing at a site to lift; the reproduction alone
    # says whether this environment carries the patch.
    findings.extend(
        f"{LEDGER}:{entry.line}: no site carries `Workaround: {entry.key} - ...`"
        for entry in entries
        if entry.key not in carried and "Patch" not in entry.fields
    )
    return findings


def named_file(entry: Entry, name: str) -> Path | None:
    """The file an entry's `<name>:` field names first, or None when it names nothing."""
    words = entry.fields.get(name, "").split()
    return Path(words[0].rstrip(",;")) if words else None


def interpreter() -> str:
    """The swipl the reproductions run under."""
    return os.environ.get("SWIPL") or shutil.which("swipl") or "swipl"


def run_reproduction(root: Path, path: Path) -> tuple[str, str]:
    """Run one reproduction; answer its verdict and, when it is broken, why."""
    if path.suffix == ".pl":
        command = [
            interpreter(), "-q", "-f", "none", "-s", str(root / path), "-g", "main", "-t", "halt",
        ]
    else:
        command = ["sh", str(root / path)]
    scratch = tempfile.mkdtemp(prefix=f"host-workaround-{path.stem}-")
    env = {**os.environ, "HOST_WORKAROUND_SCRATCH": scratch, "SWIPL": interpreter(),
           "CHECK_PY": sys.executable}
    try:
        ran = subprocess.run(
            ["sh", str(ROOT / BOUNDED), "--ceiling", str(CEILING_SECONDS), *command],
            cwd=root,
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )
    finally:
        shutil.rmtree(scratch, ignore_errors=True)
    lines = [line.strip() for line in ran.stdout.splitlines() if line.strip()]
    verdict = lines[-1] if lines else ""
    if ran.returncode != 0 or verdict not in VERDICTS:
        detail = f"exit {ran.returncode}, last line {verdict!r}, stderr {ran.stderr.strip()[-400:]!r}"
        return "broken", detail
    return verdict, ""


def check_tree(root: Path, *, run: bool = True) -> Report:
    """Check one tree: the ledger's shape, both directions, and every reproduction."""
    files = tracked_files(root)
    sites, findings = scan_sites(root, files)
    ledger = root / LEDGER
    if not ledger.is_file():
        return Report(sites, [], [*findings, f"{LEDGER}: missing"])
    entries, shape = parse_ledger(ledger.read_text(encoding="utf-8"))
    findings.extend(shape)
    findings.extend(cross_check(sites, entries))
    tracked = set(files)
    for entry in entries:
        path = named_file(entry, "Reproduction")
        if path is None or path not in tracked or path.suffix not in RUNNABLE:
            findings.append(
                f"{LEDGER}:{entry.line}: `{entry.key}` needs `Reproduction:`"
                " to name a tracked .pl or .sh file"
            )
            continue
        patch = named_file(entry, "Patch")
        if "Patch" in entry.fields and (
            patch is None or patch not in tracked or patch.suffix != ".patch"
        ):
            findings.append(
                f"{LEDGER}:{entry.line}: `{entry.key}` needs `Patch:`"
                " to name a tracked .patch file"
            )
            continue
        if not run:
            continue
        verdict, detail = run_reproduction(root, path)
        if verdict == "broken":
            findings.append(f"{entry.key}: reproduction {path} is broken: {detail}")
        elif patch is not None:
            if verdict == "present":
                findings.append(
                    f"{entry.key}: this environment's host still shows the defect ({path}"
                    f" answered present); rebuild it with {patch}"
                )
        elif verdict == "absent":
            where = ", ".join(f"{s.path}:{s.line}" for s in sites if s.key == entry.key)
            findings.append(
                f"{entry.key}: the host no longer shows this defect ({path} answered"
                f" absent); lift the workaround at {where} and remove the entry"
            )
    return Report(sites, entries, findings)


def main() -> int:
    """Check the shipped tree; print every finding; exit 1 when there is one."""
    report = check_tree(ROOT)
    for finding in report.findings:
        print(finding)
    if report.findings:
        return 1
    patched = sum("Patch" in entry.fields for entry in report.entries)
    print(
        f"host workarounds: {len(report.entries)} entries ({patched} patched),"
        f" {len(report.sites)} sites, every worked-around defect answers present"
        " and every patched one absent"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
