"""Purpose: say which files this repository's runners execute, and in which tier.

A tested claim can then be checked against the gate rather than against the
tree alone.

check_evidence_tags.py used to ask only whether a cited name existed. A name
can exist in a file nothing runs, which is how engine/translator.pl came to cite
a tests/performance/reduce_dispatch.pl for its operator-table guarantee: the
file was real, and no runner ever opened it. This lane is what found it, and
the citation names a plunit unit now.

Two ways of learning what a runner executes, because neither covers the other:

  literally    a path written into a runner is executed by it. check.sh names
               tests/prolog/static_checks.pl and extensions/python/tools/reference.py this
               way, and reading the paths out needs no model of anything.
  by glob      pytest, the plunit loop and test.sh each select a whole tree.
               Nothing in the text names the files, so each of the three is
               DECLARED below with the verbatim runner line it models. If that
               line moves, the anchor stops matching and this reports it,
               rather than quietly modelling a runner that no longer exists.

check.sh's own GATE and REPORT tiers are read off its `run` lines, because a
REPORT failure is forgiven and cannot back a claim. The two workflow files are
runners too, and untiered here: ci.yml runs three shell suites that check.sh
does not, and a claim resting on one of them is backed, just not by the local
gate.
Assumes:
  - `:- initialization(main, main)` exits 1 when main fails, so a Prolog script
    named by a runner reports its failure [measured 2026-08-18: swipl 10 exits
    1 on `main :- fail.` and 0 on `main :- true.`]
  - extensions/python/pyproject.toml leaves pytest's FILE selection at its
    documented defaults, which PYTEST_DISCOVERY_KEYS re-checks on every run, and
    names its collection root in testpaths, which _testpaths_problems compares
    against the collectors declared for that directory's runners
    [source: https://docs.pytest.org/en/stable/explanation/goodpractices.html]
Guarantees:
  - tsc output patterns keep their declared paths when outDir is a symlink
    [tested: tests/checks/check_evidence_selftest.py; commit=WORKTREE]
  - a file no runner reaches is absent from executed(), and a file only a
    REPORT lane reaches carries tier REPORT
    [tested 2026-08-18: tests/checks/check_evidence_selftest.py]
  - a declared collector whose anchor has left its runner is reported instead
    of being applied [tested 2026-08-18: tests/checks/check_evidence_selftest.py]
  - a lane written across a backslash-newline runs what it names, because the
    shell reads that as one logical line and so does this
    [tested 2026-09-05: tests/checks/check_evidence_selftest.py]
  - gate_scripts() answers the root driver AND every component check.sh it
    sources, so a lane that moved into a component is still the gate's lane;
    both selftests build a fixture whose pytest lane lives in a component and
    fail if it stops resolving [tested 2026-08-28:
    tests/checks/check_evidence_selftest.py,
    tests/checks/check_spec_status_selftest.py]
  - a lane running an npm script executes what that package's manifest says it
    does, `npm run` inside it expanded and `--prefix` honoured on either side
    of the name, and a selection naming tsc OUTPUT resolves to the sources
    that produce it even on a checkout nobody has built
    [tested 2026-09-07: tests/checks/check_evidence_selftest.py; commit=45615fb15d8a1d041e3ce0698d789d4d1392a0eb]
Fails when:
  - a Prolog file is handed to swipl by a Python script rather than by a
    runner or by another Prolog file's consult. tests/conformance/answer_groups.pl
    is the one case, and it reads as unexecuted here. Python path strings are
    not followed on purpose: reference.py names the pages it REWRITES, and
    reading those as executions would be worse than the gap.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import fnmatch
import json
import os
import re
from collections.abc import Iterator
from dataclasses import dataclass
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[2]

def _component_runners() -> tuple[str, ...]:
    """Every component's own check.sh, test.sh and bench.sh, discovered.

    A component's lanes moved out of the root gate into its own directory, and
    this list was four hardcoded names. A lane the evidence model cannot see is
    a lane whose paths look unrun, so a claim citing a file only that lane runs
    reads as unbacked. Measured 2026-08-28: discovery restores exactly one file
    to the executed model, extensions/node/test/atom.test.ts, and no tag cites it
    today -- so the exposure is latent rather than realised, and this exists to
    keep it that way as component lanes grow, not to repair a live break.

    test.sh and bench.sh are here for the same reason and are not latent. A
    component's check.sh lane CALLS them, so the npm script, the interpreter
    and the case table live in the called script rather than in the lane, and
    reading only the lane loses every extensions/node/test/*.test.ts the
    node-binding lane runs -- which is exactly what that lane's own comment
    warned about before test.sh existed.
    """
    found = []
    for pattern in (
        "engine/check.sh",
        "engine/test.sh",
        "engine/bench.sh",
        "extensions/*/check.sh",
        "extensions/*/test.sh",
        "extensions/*/bench.sh",
    ):
        found += [str(p.relative_to(ROOT)) for p in sorted(ROOT.glob(pattern))]
    return tuple(found)


# Every script that runs part of this repository. check.sh is the gate; test.sh
# is reached from it and owns the example corpus; the two workflows run check.sh
# and, in ci.yml's case, three shell suites it does not; and each component's
# own check.sh, which the gate SOURCES so its lanes share one summary.
RUNNERS = (
    "check.sh",
    "test.sh",
    ".github/workflows/checks.yml",
    ".github/workflows/ci.yml",
    *_component_runners(),
)


def gate_scripts() -> tuple[Path, ...]:
    """Every check.sh the gate runs: the root driver and each component's.

    `sh check.sh <lane>` names any of their lanes, because the root driver
    sources the components and its `run` filters on the argument list, so which
    file a lane sits in is not a property a caller can observe. Three readers
    asked the root file alone and each read a lane living in a component as a
    lane the gate does not run: check_evidence_tags.gate_lanes,
    check_spec_status._lane_tiers and check_imports_selftest._gate_text. All
    three were blind to node-binding and c-binding before any of this, since
    those components took their own lanes first [measured 2026-08-28: 52 lanes
    visible reading check.sh alone, against the gate's 82].
    """
    return tuple(
        ROOT / runner
        for runner in RUNNERS
        if runner.endswith("check.sh") and (ROOT / runner).is_file()
    )


# `run TIER NAME COMMAND...`, check.sh's own lane declaration, and the shell
# functions those lanes call. A lane's text is the command plus the body of
# every function it reaches, so a path written inside check_prolog_static
# belongs to the GATE lane that calls it.
LANE = re.compile(r"^run\s+(GATE|REPORT)\s+(\S+)\s+(.*)$", re.MULTILINE)
FUNCTION = re.compile(r"^([a-z_][a-z0-9_]*)\(\)\s*\{\n(.*?)^\}", re.MULTILINE | re.DOTALL)
ONE_LINE_FUNCTION = re.compile(r"^([a-z_][a-z0-9_]*)\(\)\s*\{([^\n]*)\}[ \t]*$", re.MULTILINE)
# A backslash-newline is ONE logical line to the shell, and LANE's `.` does not
# cross a newline, so a lane written that way carried the backslash as its whole
# command and everything it runs was recorded as run by nothing. Two GATE lanes
# in check.sh are written that way, and both of their scripts read as executed
# by no runner: check_generated_artifact_group.py and
# check_gate_scratch_selftest.py, one of them CITED by check.sh's own Guarantees
# block [measured 2026-09-05]. Joined here rather than in LANE itself because
# every pattern below reads the same text and all of them want logical lines.
LINE_CONTINUATION = re.compile(r"\\\n[ \t]*")

# A path written into a runner. Anchored on a suffix this repository executes,
# so `$SUMMARY` and `*.plt` are not mistaken for files. `.js` joined on
# 2026-09-07 with the ts-space lane, which runs a checked-in bundle by name:
# without it that lane read as running nothing and the 15 cases in the file
# stopped backing the four claims that cite one.
PATHISH = re.compile(r"[$\w./{}-]*[\w}-]\.(?:py|pl|plt|sh|metta|ts|mjs|js|c)\b")
# A lane that runs a package's own npm script runs whatever that script runs,
# and the script NAME is the whole indirection: nothing in the lane's text is a
# path. Reading the indirection is what lets an evidence claim written in a
# TypeScript source name a case in one of those suites; without it the claim is
# unbacked because this cannot see the suite at all.
#
# What the script runs was MODELLED here until 2026-09-07 -- `npm run test`,
# `typecheck` or `kit` was taken to mean every `<package>/test/*.test.ts` -- and
# the model was right for one seat and blind everywhere else. It recorded 35
# files the Node seat's suite lane runs and none of the three suites outside
# that one directory: tools/browser.test.mjs, which the checks.yml workflow runs
# as `npm run test:browser --prefix extensions/node`, and the TypeScript space
# example's own suite beside its server. It also recorded those 35 for
# `typecheck`, which compiles and runs nothing. The manifest's `scripts` map is
# the seat's own declaration of what each name runs, exactly as check.sh's `run`
# lines are the gate's and a Makefile's targets are the C seat's, so it is read
# rather than guessed at -- the rule make_requests below already follows.
#
# `npm <name>` with no `run` is npm's documented alias for `npm run <name>`, and
# only for the four lifecycle names; `ci`, `pack`, `install` and `publish` are
# npm's own work and name no script
# [source: https://docs.npmjs.com/cli/v11/commands/npm-test].
NPM_CALL = re.compile(r"\bnpm\s+([^\n&|;()]*)")
NPM_ALIASES = ("test", "start", "stop", "restart")
# npm's own way of naming the package a call runs in, which is how the workflow
# runs a seat's script from the repository root.
NPM_PREFIX = ("--prefix", "-C")
# node's test runner and the selection it is given: every pattern after `--test`
# up to the next shell operator. `node --test "build/test/*.test.js"` and
# `node --test tools/browser.test.mjs` are both this shape
# [source: https://nodejs.org/docs/latest-v22.x/api/test.html].
NODE_TEST_RUN = re.compile(r"\bnode\b[^\n&|;]*?\s--test\s+([^\n&|;]*)")
# What tsc rewrites a TypeScript extension to. `.mts` and `.cts` keep their
# module kind in the output, which is why this is not one entry
# [source: https://www.typescriptlang.org/docs/handbook/modules/reference.html].
TS_OUTPUT = {".ts": ".js", ".tsx": ".js", ".mts": ".mjs", ".cts": ".cjs"}
# The C seat's equivalent. Its test.sh runs `make -C <seat> test`, and the
# Makefile's test target builds tests/*.c and runs the binary, so the source
# a claim names is reached through a Makefile this model does not read. The
# npm rule above is the same shape for the same reason.
MAKE_TEST = re.compile(r"\bmake\b[^\n]*\btest\b")
# Everything a lane's `make` line asks for. A target is a bare word: `--quiet`
# is preceded by a dash, `$HERE` by a dollar, and every segment of a path by a
# slash, so none of them read as one. The result is intersected with the
# Makefile's own target names before it is believed.
MAKE_CALL = re.compile(r"\bmake\b([^\n]*)")
MAKE_WORD = re.compile(r"""(?<![-\w/$."'])([a-z][\w-]*)(?![\w/-])""")
# A Makefile target opens in column 1 and is followed by `:`, which `:=` is not.
MAKE_RULE = re.compile(r"^([A-Za-z][\w.-]*)\s*:(?!=)")


def npm_calls(text: str) -> Iterator[tuple[str | None, str]]:
    """Every script a runner's text asks npm to run, with the --prefix it names.

    npm consumes its own flags wherever they sit, on either side of the script
    name: check.sh writes `npm run --prefix "$site" docs:build` and the
    checks.yml workflow writes `npm run test:browser --prefix extensions/node`.
    So the first bare word is the script and the whole call is scanned for the
    prefix; stopping at the script instead read the workflow's call as running
    in whatever package the lane's path happened to reach first, which is the
    Node seat only by luck and would be the wrong package for any other.
    """
    for call in NPM_CALL.findall(text):
        words = [word.strip("\"'") for word in call.split()]
        explicit = bool(words) and words[0] == "run"
        prefix, script, index = None, None, 1 if explicit else 0
        while index < len(words):
            if words[index] in NPM_PREFIX and index + 1 < len(words):
                prefix = words[index + 1]
                index += 2
                continue
            if script is None and not words[index].startswith("-"):
                script = words[index]
            index += 1
        if script is not None and (explicit or script in NPM_ALIASES):
            yield prefix, script


def npm_scripts(package: Path) -> dict[str, str]:
    """One package's `scripts` map, or {} when it has none this can read."""
    try:
        manifest = json.loads((package / "package.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    scripts = manifest.get("scripts", {})
    return scripts if isinstance(scripts, dict) else {}


def npm_expansion(package: Path, script: str) -> str:
    """One script's command text, with every `npm run` inside it spent.

    The Node seat's `test` is `npm run build --silent && node --test
    "build/test/*.test.js"`, so what it runs is only visible once the inner
    call is expanded; `build` contributes the tsc invocation that decides where
    the sources it names come from.
    """
    scripts = npm_scripts(package)
    reached, seen, pending = "", set(), [script]
    while pending:
        name = pending.pop()
        if name in seen or name not in scripts:
            continue
        seen.add(name)
        reached += "\n" + scripts[name]
        pending += [inner for prefix, inner in npm_calls(scripts[name]) if prefix is None]
    return reached


def tsc_projects(package: Path) -> list[tuple[Path, Path]]:
    """(outDir, rootDir) for every emitting project file this package declares.

    Read from the project files rather than assumed, so a seat that moves its
    output directory keeps its suites visible. `extends` is followed because
    tsconfig.build.json's own settings are a layer over two more, and a seat
    that put outDir in the base would otherwise read as emitting nothing.
    These are compiler paths: following an output symlink into a shared build
    would lose the package-relative pattern that the npm command names.
    abspath normalizes paths without realpath's filesystem lookup
    [source: https://github.com/python/cpython/blob/v3.14.4/Lib/posixpath.py;
    commit=WORKTREE].
    """
    projects = []
    for project in sorted(package.glob("tsconfig*.json")):
        options = _tsconfig(project, frozenset())
        if options.get("noEmit") or "outDir" not in options:
            continue
        projects.append((
            Path(os.path.abspath(package / options["outDir"])),  # noqa: PTH100 -- preserve compiler paths through symlinks
            Path(os.path.abspath(package / options.get("rootDir", "."))),  # noqa: PTH100 -- same lexical normalization
        ))
    return projects


def _tsconfig(project: Path, seen: frozenset[Path]) -> dict:
    """One project file's compilerOptions, with its `extends` chain merged."""
    try:
        settings = json.loads(project.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    options = settings.get("compilerOptions", {})
    options = dict(options) if isinstance(options, dict) else {}
    base = settings.get("extends")
    if isinstance(base, str) and project not in seen:
        inherited = (project.parent / base).resolve()
        if inherited.is_file():
            options = {**_tsconfig(inherited, seen | {project}), **options}
    return options


def tsc_sources(package: Path, pattern: str) -> list[str]:
    """The source patterns tsc compiles into one a command names.

    The Node seat's gate lane BUILDS and then runs the output,
    `npm run build --silent && node --test "build/test/*.test.js"`, and a claim
    names the case in the source it was compiled from, so the output has to be
    read back to its source or all 35 of those suites belong to a file no
    runner executes and every case in them stops backing a claim.

    The PATTERN is translated rather than the files it matches, because on a
    checkout nobody has built yet the output does not exist: resolving what is
    on disk would report the whole seat as unrun on a fresh clone, and the
    build is part of the same command, so the files are there when node opens
    them. Same hop prolog_loads makes for a consult and make_owner for a
    recipe -- what a runner names is not always what an author cites.
    """
    patterns = []
    for out, root in tsc_projects(package):
        try:
            emitted_under = out.relative_to(package)
            source_under = root.relative_to(package)
        except ValueError:
            continue
        try:
            inside = PurePosixPath(pattern).relative_to(emitted_under)
        except ValueError:
            continue
        patterns += [
            str(source_under / f"{str(inside)[: -len(emitted)]}{suffix}")
            for suffix, emitted in TS_OUTPUT.items()
            if pattern.endswith(emitted)
        ]
    return patterns


def node_test_files(package: Path, command: str) -> list[Path]:
    """Every file a `node --test` in this command selects, sources included."""
    found: list[Path] = []
    for selection in NODE_TEST_RUN.findall(command):
        for token in selection.split():
            token = token.strip("\"'")
            if token.startswith("-"):
                continue
            for pattern in (token, *tsc_sources(package, token)):
                found += [
                    path.resolve()
                    for path in sorted(package.glob(pattern))
                    if path.is_file()
                ]
    return found


def npm_package(prefix: str | None, directories: tuple[Path, ...]) -> Path | None:
    """The package directory an npm call runs in, or None when it cannot be read.

    A `--prefix` still holding a shell variable this cannot spend names a
    package that cannot be identified, and guessing at the lane's directories
    instead would attribute one package's scripts to another: check.sh's
    `npm run --prefix "$site" docs:build` is the site's, and the nearest
    package.json on the lane's path is the Node seat's.
    """
    if prefix is not None:
        spent = _literal(prefix)
        if spent is None:
            return None
        candidate = (ROOT / spent).resolve()
        return candidate if (candidate / "package.json").is_file() else None
    return next(
        (directory for directory in directories if (directory / "package.json").is_file()),
        None,
    )


def make_owner(makefile: str, name: str) -> str | None:
    """The Makefile target whose recipe names this file, or None for the default.

    A seat's tests/ holds more than its unit suite. extensions/cmetta/tests/
    holds test_cmetta.c, which `make test` builds through TESTS, and
    install_consumer.c, which ONLY `make install-check` compiles. Recording
    every tests/*.c as run by the lane that runs `make test` said the consumer
    was executed by a lane that never opens it, so deleting the c-install lane
    would have left a claim naming it still reading as backed
    [measured 2026-08-31: `TESTS := tests/test_cmetta` is the whole of what the
    test target builds].

    A recipe line naming the file decides, because that is the line compiling
    it. A file no recipe names is built the ordinary way, through the target's
    own prerequisite variables, and belongs to the default.
    """
    owner = None
    for line in makefile.splitlines():
        if matched := MAKE_RULE.match(line):
            owner = matched.group(1)
        elif line.startswith("\t") and name in line:
            return owner
    return None


def make_requests(lane_text: str, makefile: str) -> set[str]:
    """Targets this lane asks make for, kept to ones the Makefile defines."""
    defined = {matched.group(1) for line in makefile.splitlines()
               if (matched := MAKE_RULE.match(line))}
    asked: set[str] = set()
    for tail in MAKE_CALL.findall(lane_text):
        asked |= set(MAKE_WORD.findall(tail))
    return asked & defined
CD = re.compile(r"\bcd\s+(?:--\s+)?[\"']?([$\w./-]+)")
# A path named to be LEFT OUT is not a path the runner executes. Reading these
# as executions marked examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/_fixtures/imports/
# import_error_broken.metta as gated by the very lane that skips it.
EXCLUSION = re.compile(
    r"(?:!\s+-path|-not\s+-path|--ignore|--exclude|--extend-exclude)(?:=|\s+)\S+"
)
SHELL_VARIABLES = (
    ("$HERE/", ""),
    ("${HERE}/", ""),
    # check.sh sets PYDIR="$HERE/extensions/python". These read "python/",
    # the pre-partition location, so any lane naming $PYDIR/<file> resolved
    # to a path that is not in the tree and its file read as unexecuted.
    # No lane writes that shape today, which is why nothing was lost yet.
    ("$PYDIR/", "extensions/python/"),
    ("./", ""),
    ("$HERE", "."),
    ("$PYDIR", "extensions/python"),
)

# pytest selects test FILES by its documented defaults, so the model below is
# only right while extensions/python/pyproject.toml stays silent about these three.
PYTEST_DISCOVERY_KEYS = ("python_files", "python_classes", "python_functions")

# testpaths is different: it is CONFIGURED, and reading it is what keeps the
# model true rather than what breaks it. extensions/python/test.sh names no path
# of its own, so what the pytest lane collects when the gate runs it is exactly
# what testpaths selects, and the collector's `root` below has to be the same
# directory. Forbidding the key was the old rule; comparing it is the rule that
# survives the runner learning to take flag-only arguments.
PYTEST_TESTPATHS = re.compile(r"^testpaths\s*=\s*\[([^\]]*)\]", re.MULTILINE)

# A Prolog file a runner names pulls in whatever it loads, and those clauses
# are as much a part of the run as its own: static_checks.pl reaches its
# published-surface check through `:- ensure_loaded(surface_walk)`. A Python
# import is NOT the same thing and is deliberately not followed, because pytest
# collects a test by the file it is written in, not by what imports it.
PROLOG_LOAD = re.compile(r"\b(?:ensure_loaded|consult|use_module|include)\(\s*'?([^'\s,)]+)'?")
PROLOG_COMMENT = re.compile(r"'(?:[^'\\]|\\.)*'|\"(?:[^\"\\]|\\.)*\"|%[^\n]*")


@dataclass(frozen=True)
class Execution:
    """How one file comes to be run."""

    tier: str
    runner: str


#: Where a runner starts the Prolog files under a directory, when that is not
#: the directory the file sits in. SWI resolves a LOAD-time relative path
#: against the file and a RUN-time one, an initialization goal or a consult in
#: a test body, against the WORKING DIRECTORY, so a suite two levels below its
#: runner's cwd writes both depths and only one of them is file-relative.
#: Following the file's directory alone lost fifteen files the moment the
#: suites were grouped: eight shipped libraries an
#: `initialization(consult('../../lib/...'))` pulls in, and the seven providers
#: a test body consults by bare name [measured 2026-08-27].
RUNNER_WORKING_DIRECTORY = {"tests/prolog": "tests/prolog"}


def prolog_loads(path: Path) -> list[Path]:
    """Every Prolog file this one loads, resolved the way SWI resolves it."""
    text = PROLOG_COMMENT.sub(
        lambda found: "" if found.group().startswith("%") else found.group(),
        path.read_text(encoding="utf-8", errors="replace"),
    )
    bases = [path.parent]
    relative = str(path.relative_to(ROOT)) if ROOT in path.parents else ""
    for prefix, working in RUNNER_WORKING_DIRECTORY.items():
        if relative.startswith(prefix + "/"):
            bases.append(ROOT / working)
    loaded = []
    for target in PROLOG_LOAD.findall(text):
        for base in bases:
            candidate = base / target
            if not candidate.suffix:
                candidate = candidate.with_suffix(".pl")
            if candidate.is_file():
                loaded.append(candidate.resolve())
                break
    return loaded


@dataclass(frozen=True)
class Collector:
    """A runner line that selects a whole tree, and what it selects.

    `anchor` is a verbatim fragment of the runner. It is checked before the
    collector is applied, so a moved or deleted runner line surfaces as a
    finding rather than as a model that has silently stopped matching.
    """

    runner: str
    tier: str
    lane: str
    anchor: str
    root: str
    patterns: tuple[str, ...]
    recursive: bool
    excludes: tuple[str, ...] = ()
    skip_file: str = ""
    skip_anchor: str = ""


COLLECTORS = (
    # The pytest lane is the Python component's, and lives in that component's
    # own check.sh. Naming the root gate here read as "the lane no longer
    # contains its anchor" the moment the lane moved, which dropped all 202
    # pytest files out of the executed model and turned 1080 backed claims
    # unbacked in one step [measured 2026-08-28: 575 executed files before the
    # move, 373 with this field stale, 575 again once it names the component].
    # The anchor follows the command, not the lane. The pytest invocation moved
    # out of the lane and into the seat's own test.sh, so that the gate and a
    # developer run one file; anchoring on the lane's text here would have
    # dropped all 202 test files out of this model the moment it did.
    # The fragment ends on the root because the defaults moved in front of the
    # caller's arguments on 2026-09-06 (so a caller's -n 0 wins); the old
    # `pytest tests -q` spelling stopped matching and this model dropped 2,584
    # backed claims in one step before the anchor followed.
    # The root left the anchor on 2026-09-07, when `tests` moved out of the
    # runner and into pyproject.toml's testpaths so that a flag-only invocation
    # keeps it. The anchor is now the worker protocol alone, and the root it
    # names is checked against that setting by _testpaths_problems rather than
    # by being repeated in two files.
    Collector(
        runner="extensions/python/test.sh",
        tier="GATE",
        lane="pytest",
        anchor="--max-worker-restart=0",
        root="extensions/python/tests",
        patterns=("test_*.py", "*_test.py"),
        recursive=True,
    ),
    # The seat's OTHER root, added 2026-09-08 with the extension packages: each
    # member under `extensions/python/ext/` keeps its own tests beside its own
    # module, and pytest's testpaths names both roots. One runner, two roots,
    # so the collector is doubled rather than the runner; _testpaths_problems
    # holds the two lists equal.
    Collector(
        runner="extensions/python/test.sh",
        tier="GATE",
        lane="pytest",
        anchor="--max-worker-restart=0",
        root="extensions/python/ext",
        patterns=("test_*.py", "*_test.py"),
        recursive=True,
    ),
    # The plunit lane is the engine component's, and lives in that component's
    # own check.sh. Same field and the same cost as the pytest collector above:
    # left naming the root, the anchor reads as gone and the suites drop out
    # carrying the files only they load [measured 2026-08-28: 601 executed
    # files with this field naming the component, 537 with it left on the root
    # -- 47 of the 49 .plt suites, the eight shipped libraries their bodies
    # consult, and nine tests/prolog providers, 64 files in all].
    # The loop moved into the engine's own test.sh, so the gate and a developer
    # run one body; the collector follows the loop rather than the lane. It also
    # ends an ambiguity: the anchor used to match twice inside check.sh, in this
    # lane and in dev-typed's, so removing either loop alone went undetected.
    # The anchor moved from the `for` to the `set --` on 2026-09-05, when
    # engine/test.sh gained a suite argument: the glob is what the runner
    # selects when it is given none, which is how the gate calls it, and the
    # `for` now walks whatever the argument list holds.
    Collector(
        runner="engine/test.sh",
        tier="GATE",
        lane="plunit",
        anchor="set -- suites/*/*.plt",
        root="tests/prolog/suites",
        patterns=("*.plt",),
        recursive=True,
    ),
    # test.sh runs each example under run.sh and fails the lane on a nonzero
    # exit, which is what makes an example's own !(test ...) forms evidence.
    Collector(
        runner="test.sh",
        tier="GATE",
        lane="shell",
        anchor="find ./examples -type f -name '*.metta'",
        root="examples",
        patterns=("*.metta",),
        recursive=True,
        excludes=("*/_fixtures/*",),
        skip_file="tests/data/example_skips.txt",
        skip_anchor="grep -v '^#' tests/data/example_skips.txt | awk 'NF {print $1}'",
    ),
)


def _literal(token: str) -> str | None:
    """A runner token with its shell variables spent, or None if it still has one."""
    for name, replacement in SHELL_VARIABLES:
        token = token.replace(name, replacement)
    return None if "$" in token or "{" in token else token


def _lane_texts(runner: str, text: str) -> list[tuple[str, str, str]]:
    """(tier, lane, text) for each unit of work the runner declares."""
    text = LINE_CONTINUATION.sub(" ", text)
    functions = dict(FUNCTION.findall(text)) | dict(ONE_LINE_FUNCTION.findall(text))
    lanes = []
    for tier, name, command in LANE.findall(text):
        reached, seen, pending = command, set(), [command]
        while pending:
            current = pending.pop()
            for function, body in functions.items():
                if function in seen or not re.search(rf"\b{re.escape(function)}\b", current):
                    continue
                seen.add(function)
                reached += "\n" + body
                pending.append(body)
        lanes.append((tier, f"{runner}: {name}", reached))
    if not lanes:
        # test.sh and the workflows declare no tiers. Both are reached from a
        # GATE lane or run the gate themselves, so their work is gating.
        lanes.append(("GATE", runner, text))
    return lanes


def _skipped(collector: Collector, text: str) -> tuple[frozenset[str], list[str]]:
    """The paths the runner drops from its selection, read where the runner reads them."""
    if not collector.skip_file:
        return frozenset(), []
    listing = ROOT / collector.skip_file
    if collector.skip_anchor not in text or not listing.is_file():
        return frozenset(), [
            f"{collector.runner}: it no longer reads {collector.skip_file} the way "
            f"{collector.skip_anchor!r} did, so the {collector.lane} lane's corpus "
            f"cannot be modelled"
        ]
    return frozenset(
        line.split()[0]
        for line in listing.read_text().splitlines()
        if line.strip() and not line.startswith("#")
    ), []


def executed() -> tuple[dict[Path, Execution], list[str]]:
    """Every file a runner executes, and everything about that this cannot decide."""
    runs: dict[Path, Execution] = {}
    problems: list[str] = []
    texts = {}

    def record(path: Path, tier: str, runner: str) -> None:
        previous = runs.get(path)
        if previous is None or (previous.tier == "REPORT" and tier == "GATE"):
            runs[path] = Execution(tier, runner)

    for runner in RUNNERS:
        path = ROOT / runner
        if not path.is_file():
            problems.append(f"{runner}: absent, so what it runs cannot be modelled")
            continue
        texts[runner] = path.read_text()

    for runner, text in texts.items():
        for tier, lane, lane_text in _lane_texts(runner, text):
            lane_text = EXCLUSION.sub(" ", lane_text)
            # A bare `static_checks.pl` is a path relative to whatever the lane
            # last changed into, so every directory it enters is a candidate.
            # The runner's OWN directory is one too: a component script sets
            # $HERE to its own folder and enters it, so extensions/node/test.sh
            # `cd "$HERE" && npm run test` resolves against extensions/node and
            # not against the root the root gate's $HERE means.
            directories = (
                ROOT,
                (ROOT / runner).parent,
                *(
                    candidate
                    for target in CD.findall(lane_text)
                    if (spent := _literal(target)) is not None
                    and (candidate := ROOT / spent).is_dir()
                ),
            )
            for token in PATHISH.findall(lane_text):
                spent = _literal(token)
                if spent is None:
                    continue
                for directory in directories:
                    if (candidate := directory / spent).is_file():
                        record(candidate.resolve(), tier, lane)
            for prefix, script in npm_calls(lane_text):
                package = npm_package(prefix, directories)
                if package is None:
                    continue
                if script not in npm_scripts(package):
                    problems.append(
                        f"{lane}: `npm run {script}` names no script in "
                        f"{package.relative_to(ROOT)}/package.json, so what it "
                        f"runs cannot be modelled"
                    )
                    continue
                for suite in node_test_files(package, npm_expansion(package, script)):
                    record(suite, tier, lane)
            for directory in directories:
                recipe = directory / "Makefile"
                if not recipe.is_file():
                    continue
                wanted = make_requests(lane_text, recipe.read_text(encoding="utf-8"))
                if not wanted:
                    break
                # A source belongs to the target whose recipe compiles it, and
                # one no recipe names belongs to `test`, which builds it through
                # its own prerequisites. The lane records only what IT asked for,
                # so the install lane owns install_consumer.c and the suite lane
                # owns test_cmetta.c instead of both owning everything.
                owners = recipe.read_text(encoding="utf-8")
                for suite in sorted((directory / "tests").glob("*.c")):
                    if (make_owner(owners, suite.name) or "test") in wanted:
                        record(suite.resolve(), tier, lane)
                break

    for collector in COLLECTORS:
        text = texts.get(collector.runner)
        if text is None or collector.anchor not in text:
            problems.append(
                f"{collector.runner}: the {collector.lane} lane no longer contains "
                f"{collector.anchor!r}, so what it runs cannot be modelled"
            )
            continue
        skips, trouble = _skipped(collector, text)
        problems.extend(trouble)
        root = ROOT / collector.root
        for pattern in collector.patterns:
            for found in root.rglob(pattern) if collector.recursive else root.glob(pattern):
                relative = str(found.relative_to(ROOT))
                if relative in skips or found.is_symlink():
                    continue
                if any(fnmatch.fnmatch(relative, exclude) for exclude in collector.excludes):
                    continue
                record(found.resolve(), collector.tier, f"{collector.runner}: {collector.lane}")

    pending = [path for path in runs if path.suffix in (".pl", ".plt")]
    while pending:
        current = pending.pop()
        execution = runs[current]
        for loaded in prolog_loads(current):
            known = runs.get(loaded)
            if known is None or (known.tier == "REPORT" and execution.tier == "GATE"):
                record(loaded, execution.tier, execution.runner)
                pending.append(loaded)

    configuration = ROOT / "extensions/python/pyproject.toml"
    if not configuration.is_file():
        problems.append(
            "extensions/python/pyproject.toml is absent, so whether pytest still discovers by its "
            "documented defaults cannot be read"
        )
        return runs, problems
    section = configuration.read_text().partition("[tool.pytest.ini_options]")[2]
    section = section.partition("\n[")[0]
    problems.extend(
        f"extensions/python/pyproject.toml sets pytest's {key}, so the collectors above "
        f"model a discovery this project no longer uses"
        for key in PYTEST_DISCOVERY_KEYS
        if re.search(rf"^{key}\s*=", section, re.MULTILINE)
    )
    problems.extend(_testpaths_problems(section, configuration.parent))
    return runs, problems


def _testpaths_problems(section: str, rootdir: Path) -> list[str]:
    """Whether the configured default root is the one the collectors model.

    pytest resolves testpaths against the directory holding the configuration,
    which is the directory extensions/python/test.sh enters, so the entries and
    the collectors declared for a runner in that directory name the same places
    or one of the two is describing a run that does not happen.
    """
    declared = PYTEST_TESTPATHS.search(section)
    modelled = {
        (ROOT / collector.root).resolve()
        for collector in COLLECTORS
        if (ROOT / collector.runner).parent == rootdir
    }
    if declared is None:
        return []
    named = {
        (rootdir / entry.strip().strip("\"'")).resolve()
        for entry in declared.group(1).split(",")
        if entry.strip()
    }
    if named == modelled:
        return []
    return [
        f"extensions/python/pyproject.toml sets pytest's testpaths to "
        f"{sorted(str(path) for path in named)}, and the collectors for runners "
        f"under {rootdir.relative_to(ROOT)} model "
        f"{sorted(str(path) for path in modelled)}, so one of the two describes "
        f"a run that does not happen"
    ]
