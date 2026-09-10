"""Purpose: prove check_evidence_tags.py catches the things it claims to.

Each of them is planted on purpose in a small tree, and the real checker runs
over it.

Running the checker on THIS repository proves the repository is clean. It says
nothing about whether the checker can see a violation, which is the same
mistake the checker exists to catch: engine/translator.pl cited a benchmark that
runs nowhere, and the citation looked exactly like the two hundred good ones
above it. So the guarantees in check_evidence_tags.py's own header are tested
here, against planted violations, and not by the gate run that finds nothing.

The tree is written from scratch each time under a temporary directory: a
check.sh with both tiers, the engine, Python, C and Node components' own
check.sh files that the root one sources, a test.sh with the example corpus,
one plunit suite, one gate script, one example, one collected pytest module, a
C suite naming its cases twice, two node --test suites in different
directories, the runner that declares where scratch goes, and the orphans and
mutes that are supposed to be rejected. The checker is copied into
<tree>/tools/checks rather than <tree>/tests, because its own SOURCES reads
tests/*.py and a copy sitting there would have its docstring read as claims
about a tree it is only visiting.

Every citation is built from a TAG variable instead of being written out. A
literal one in this file is a claim about THIS repository as far as the gate is
concerned, and the fixtures are deliberately unbacked.
Guarantees:
  - Prolog tools accept a backed claim and report an absent test on its own line
    [tested: tests/checks/check_evidence_selftest.py; commit=8358dfc233bf299bb23eceddd94593a62372fe4b]
  - a shared build symlink preserves the selected TypeScript sources and
    still refuses a source the command does not select
    [tested: tests/checks/check_evidence_selftest.py; commit=ea2c1bde39a7b002b1e5948cf6c53bc469dac084]
  - a planted citation of each rejected kind produces exactly one finding on
    its own line, and none of the accepted kinds produces any
    [tested 2026-08-18: tests/checks/check_evidence_selftest.py]
  - a collector whose anchor has left the runner is reported
    [tested 2026-08-18: tests/checks/check_evidence_selftest.py]
  - a gate command is accepted when check.sh runs the lane it names and
    reported when it does not, which is the second half of the scheme's
    "test name or exact gate command" and the form llms.txt's checker uses
    [tested 2026-08-22: tests/checks/check_evidence_selftest.py]
  - every plant here fails when the rule it pins is taken away, because
    METTA_EVIDENCE_MUTATION patches the COPIED checker and nothing else
    [tested 2026-09-07: evidence-mutations; commit=45615fb15d8a1d041e3ce0698d789d4d1392a0eb]
Fails when:
  - run against a tree it did not write. It asserts exact line numbers in a
    fixture it generates, and nothing else.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent

sys.path.insert(0, str(HERE))
from check_evidence_tags import PLACEHOLDER  # noqa: E402  -- HERE must be on the path first
from evidence_runners import COLLECTORS  # noqa: E402  -- HERE must be on the path first

#: The pytest collector's own anchor, READ from the collector rather than
#: restated here. Two self-tests plant it into a fixture tree and both used to
#: write it out: `a025e10f` moved the seat runner's default flags in front of
#: its arguments, which moved the selection `tests` to the end of the command,
#: and `7ec761da` followed the collector in one fixture and not the other, so
#: `spec-status-selftest` read its planted FIXED case as OPEN. A restated
#: anchor is a second authority for one fact, which is the shape
#: `test_the_repin_tag_uses_the_gates_own_placeholder` already rules out for
#: the re-pin tag.
PYTEST_ANCHOR = next(
    collector.anchor for collector in COLLECTORS if collector.lane == "pytest"
)

#: A mutation to apply to the COPIED checker, as a JSON file naming the module,
#: the text to replace and what to replace it with. It is how
#: check_evidence_mutations.py asks whether a plant here is load-bearing, and
#: it edits the copy under <tree>/tools/checks and nothing else: a harness that
#: patched the repository's own file would leave it patched on any exit that is
#: not the one it planned for.
MUTATION = json.loads(Path(os.environ["METTA_EVIDENCE_MUTATION"]).read_text()) if (
    os.environ.get("METTA_EVIDENCE_MUTATION")
) else None

TAG = "tested"
#: The other tag word a plant needs, and a variable for the same reason TAG is
#: one. Written out, an opening bracket followed by the word is a claim about
#: THIS repository as far as the gate is concerned, and it read the scratch
#: plant below as one -- as it read this very sentence, until the word left it.
MEASURED = "measured"
#: And the scratch directory, spelled once here and written into the fixture's
#: own gate_scratch.sh, so the plant and the runner the checker reads it from
#: cannot disagree about what the rule is refusing.
SCRATCH = "ai-tmp"
WHEN = "2026-08-18"

# (accepted, what the citation names, why it is written this way)
CITATIONS = (
    (True, "a_plunit_test", "a plunit test in a suite the plunit lane globs"),
    (True, "a_unit:a_plunit_test", "the same test named with the unit it is in"),
    (False, "b_unit:a_plunit_test",
     "the same test named with a unit it is NOT in, which resolved until the "
     "pairing stopped being a cross-product"),
    (True, "test_collected", "a pytest function in a module the pytest lane collects"),
    (True, "kept", "an example test.sh runs, holding a test form"),
    (True, "checked_thing", "a predicate the gate script's entry goal reaches"),
    (True, "tests/prolog/gate_script.pl", "a gate script cited whole"),
    (True, "tests/checked.py", "a Python gate script cited whole, run by a GATE lane"),
    (False, "tests/orphan/orphan_check.pl", "a script that can fail and that nothing runs"),
    (False, "tests/orphan/mute.pl", "a script a lane runs that has no way to fail"),
    (False, "tests/printer.py", "a Python script a lane runs that only prints"),
    (False, "quiet", "an example test.sh runs that holds no test form"),
    (False, "tests/orphan/reported.pl", "a script only a REPORT lane runs"),
    (False, "test_uncollected", "a pytest function in a module pytest does not collect"),
    (True, "loaded_check", "a predicate in a file the gate script loads, which has no entry"),
    (True, "test_a_c_case_main_runs",
     "a C case its suite's main() calls, reached through a Makefile the "
     "runner model cannot read and a seat test.sh that can"),
    (False, "test_a_c_case_main_forgot",
     "a C case defined beside it that main() never calls, which is the C "
     "suite's version of an uncollected pytest function"),
    (True, '"a C case named in prose"',
     "the SECOND name that C suite gives the same case: CASE(...) is what the "
     "CHECK macro prints beside a failure, so it is the name a reader is shown"),
    (False, '"a C case in a function main forgot"',
     "a CASE(...) inside a function main() never calls, which is as dead as "
     "the function and must not read as backed on its own"),
    (True, '"a quoted case the suite declares"',
     "a node --test case named in PROSE, which carries spaces and so fails "
     "IDENTIFIER; every name written this way was dropped in silence, so a "
     "correct citation and a renamed one were accepted for the same reason"),
    (False, '"a quoted case that was renamed"',
     "the same shape naming a case no suite declares, which is what the "
     "silent drop could not tell from the line above"),
    (True, '"a case in a suite outside the old glob"',
     "a case in tools/, which the harvester reached nothing of when it globbed "
     "one directory, run through the workflow's `npm run ... --prefix`"),
    (True, '"a case whose suite is compiled before it runs"',
     "a case in the source the seat's npm script COMPILES and then runs; the "
     "output does not exist in this fixture, exactly as on a fresh clone, so "
     "the pattern has to be read back through the seat's own tsconfig"),
    (True, '"a quoted case whose name ends in settled()"',
     "a case whose own name ends in parentheses, which the punctuation strip "
     "for a BARE word took off and turned into a citation of nothing"),
    (False, "skipped", "an example holding a test form that the skip list drops"),
    (False, "no_such_thing_at_all", "a name the tree does not define"),
    (True, "GATE_ONLY=1 sh check.sh plunit",
     "an exact gate command naming a lane check.sh runs, which the "
     "obligation-header scheme accepts beside a test name"),
    (False, "GATE_ONLY=1 sh check.sh no-such-lane",
     "a gate command naming a lane check.sh does not run"),
    (True, "python tests/checked.py --gate",
     "the interpreter-led shape of the same thing: a script a GATE lane runs, "
     "with the script's own flags after it"),
    (False, "python tests/printer.py --gate",
     "an interpreter-led command naming a script that cannot fail, which the "
     "word split used to read as a test named `python`"),
    (True, "CHECK_PY=$VENV/bin/python sh extensions/python/test.sh tests/test_collected.py",
     "a SHELL runner a GATE lane runs, with an environment assignment in "
     "front of it that the word split used to read as a file that is not in "
     "the tree"),
    (False, "sh tests/absent.sh",
     "a shell runner that is not in the tree"),
    (False, "sh tests/printer.py",
     "a shell command naming something that cannot report a failure"),
    (True, "make -C extensions/cmetta test",
     "a MAKE command naming a target the seat's Makefile defines, whose "
     "`-C <seat>` argument the word split used to read as a missing file"),
    (False, "make -C extensions/cmetta no-such-target",
     "a make command naming a target the seat's Makefile does not define"),
    (False, "make -C extensions/nowhere test",
     "a make command naming a seat that holds no Makefile"),
)

CHECK_SH = """\
run() { :; }
in_py() { ( cd "$PYDIR" && "$@" ); }

run GATE shell sh -c "cd '$HERE' && sh test.sh"
run GATE gate-script sh -c "cd '$HERE/tests/prolog' && swipl gate_script.pl"
run GATE checked sh -c "cd '$HERE' && '$PY' tests/checked.py"
run GATE printer sh -c "cd '$HERE' && '$PY' tests/printer.py"
run GATE mute sh -c "cd '$HERE' && swipl tests/orphan/mute.pl"
run REPORT reported sh -c "cd '$HERE' && swipl tests/orphan/reported.pl"

for component_check in "$HERE"/engine/check.sh "$HERE"/extensions/*/check.sh; do
    [ -f "$component_check" ] || continue
    . "$component_check"
done
"""

# The pytest lane is the Python component's and sits in that component's own
# check.sh, sourced by the root gate above. The fixture mirrors the split so the
# collector is proven against the shape the tree actually has: with the lane
# written into the root file instead, the collector passed here while the real
# model had already stopped seeing every pytest file.
#
# The lane DELEGATES to the seat's test.sh, and the pytest command lives there,
# which is why the collector anchors on that file. The fixture mirrors that too:
# anchoring on the lane's own text passed here while the real model saw nothing.
PYTHON_CHECK_SH = """\
run GATE pytest env CHECK_PY="$PY" sh "$HERE/extensions/python/test.sh"
"""

# `set -eu` because the real one has it, and because a claim naming this script
# is only evidence if the script can report a failure. Without it the fixture
# modelled a runner that always exits 0, and a shell-command citation of it
# read as unbacked while the same citation in the tree is backed.
PYTHON_TEST_SH = """\
set -eu
exec "$PY" -m {pytest_anchor}
"""

# The plunit lane is the engine component's, for the same reason and with the
# same consequence: a root-file copy of it would leave this fixture proving a
# shape the tree does not have, while the real model quietly lost 47 of the 49
# suites and the 17 files only they load.
# The engine's lane DELEGATES to its own test.sh, and the plunit loop lives
# there, which is why the collector anchors on that file. The fixture mirrors
# the split for the same reason the Python one does: with the loop written into
# the lane, this selftest would prove a shape the tree no longer has.
# The C seat's lane delegates to its own test.sh, which delegates again to a
# Makefile. The fixture mirrors both hops, because the model reads shell text
# and cannot read a Makefile: with the binary named in the lane instead, this
# would prove a shape no seat has.
CMETTA_CHECK_SH = """\
run GATE c-binding sh "$HERE/extensions/cmetta/test.sh"
"""

CMETTA_TEST_SH = """\
exec make --quiet -C "$HERE" test
"""

# The Node seat's lane delegates the same way, and the indirection it delegates
# INTO is the package manifest: the lane names a script, the script names what
# node runs. Modelling that as "an npm lane runs <package>/test/*.test.ts" was
# right for one seat and blind for every suite outside that one directory, so
# the fixture makes the seat's `test` compile into build/ and run THAT, which
# is what the real one does and what a fresh checkout does not have on disk.
NODE_CHECK_SH = """\
run GATE node-binding sh "$HERE/extensions/node/test.sh"
"""

NODE_TEST_SH = """\
set -eu
cd "$HERE/extensions/node" && npm run --silent test
"""

ENGINE_CHECK_SH = """\
check_plunit() {
    sh "$HERE/engine/test.sh"
}
run GATE plunit check_plunit
"""

ENGINE_TEST_SH = """\
cd "$HERE/tests/prolog" || exit 1
if [ "$#" -eq 0 ]; then
    set -- suites/*/*.plt
fi
for suite in "$@"; do
    bounded swipl -g "run_tests" -t halt "$suite" || exit 1
done
"""

TEST_SH = """\
find ./examples -type f -name '*.metta' \\
    ! -path '*/_fixtures/*' -print | LC_ALL=C sort > "$filelist"
SKIPS=$(command grep -v '^#' tests/data/example_skips.txt | awk 'NF {print $1}')
while IFS= read -r f; do
    rel=${f#./}
    case "
$SKIPS
" in *"
$rel
"*) continue ;;
    esac
    sh run.sh "$f" || exit 1
done < "$filelist"
"""

FILES = {
    "extensions/python/pyproject.toml": '[tool.pytest.ini_options]\npythonpath = ["."]\n',
    # The workflow runs one script check.sh does not, the shape the real one
    # takes for the browser suite: `npm run <script> --prefix <package>`, with
    # npm's own flag AFTER the name it selects.
    ".github/workflows/checks.yml": (
        "run: sh check.sh\nrun: npm run test:tools --prefix extensions/node\n"
    ),
    ".github/workflows/ci.yml": "run: sh test.sh\n",
    "extensions/python/tests/test_collected.py": "def test_collected():\n    assert True\n",
    "extensions/python/tests/helpers.py": "def test_uncollected():\n    assert True\n",
    "tests/checked.py": (
        "import sys\n\n\ndef main():\n    return 1\n\n\n"
        'if __name__ == "__main__":\n    sys.exit(main())\n'
    ),
    "tests/printer.py": 'print("a number")\n',
    # TWO units, because the interesting citation names one of them. A test
    # used to be registered under every unit in its file, so `b_unit:...`
    # resolved for a test written in a_unit and a reader was sent to the wrong
    # place; four citations in the tree were doing exactly that.
    "tests/prolog/suites/a_group/suite.plt": (
        ":- begin_tests(a_unit).\n\ntest(a_plunit_test) :-\n    1 =:= 1.\n\n"
        ":- end_tests(a_unit).\n\n"
        ":- begin_tests(b_unit).\n\ntest(b_plunit_test) :-\n    2 =:= 2.\n\n"
        ":- end_tests(b_unit).\n"
    ),
    "tests/prolog/gate_script.pl": (
        ":- ensure_loaded(loaded_helper).\n:- initialization(main, main).\n\n"
        "main :-\n    checked_thing,\n    loaded_check.\n\n"
        "checked_thing :-\n    \\+ absent_offender(_).\n\nabsent_offender(_) :- fail.\n"
    ),
    "tests/prolog/loaded_helper.pl": "loaded_check :-\n    1 =:= 1.\n",
    "tests/orphan/orphan_check.pl": (
        ":- initialization(main, main).\n\nmain :-\n    1 =:= 1.\n"
    ),
    "tests/orphan/mute.pl": "report :-\n    format('a number~n').\n",
    "tests/orphan/reported.pl": (
        ":- initialization(main, main).\n\nmain :-\n    format('findings~n').\n"
    ),
    "extensions/cmetta/Makefile": "test:\n\t./tests/c_suite\n",
    # Both of the C suite's naming levels, because a citation may use either:
    # the FUNCTION main() dispatches, and the CASE(...) inside it that the
    # CHECK macro prints when a check fails. The two `{ CASE(` shapes are the
    # two the real suite writes, on the brace's own line and beneath it.
    "extensions/cmetta/tests/c_suite.c": (
        "#include <stdio.h>\n\n"
        "static const char *current_case;\n"
        "#define CASE(name) current_case = (name)\n\n"
        "static void test_a_c_case_main_runs(void)\n"
        "{ CASE(\"a C case named in prose\");\n  printf(\"ran\\n\");\n}\n\n"
        "static void test_a_c_case_main_forgot(void)\n{\n"
        "  CASE(\"a C case in a function main forgot\");\n  printf(\"never\\n\");\n}\n\n"
        "int main(void)\n{ test_a_c_case_main_runs();\n  return 0;\n}\n"
    ),
    # The Node seat, whose suites are the ones named in PROSE. Three shapes at
    # once, because the tree has all three and each was blind on its own: the
    # `test/` suite the seat's own npm script COMPILES and then runs, so the
    # pattern names an output that a fresh checkout does not have; the suite in
    # `tools/` that only the workflow runs, one directory outside the glob the
    # harvester used to be rooted at; and the `--prefix` that workflow reaches
    # the package through, which is written AFTER the script name.
    "extensions/node/package.json": (
        '{\n  "scripts": {\n'
        '    "build": "tsc -p tsconfig.build.json",\n'
        '    "test": "npm run build --silent && node --test \\"build/test/*.test.js\\"",\n'
        '    "test:tools": "node --test tools/probe.test.mjs"\n'
        "  }\n}\n"
    ),
    "extensions/node/tsconfig.build.json": (
        '{\n  "compilerOptions": { "outDir": "build", "rootDir": "." }\n}\n'
    ),
    "extensions/node/test/suite.test.ts": (
        'import { describe, it } from "node:test";\n\n'
        'describe("the seat", () => {\n'
        '  it("a quoted case the suite declares", () => {});\n'
        '  it("a case whose suite is compiled before it runs", () => {});\n'
        '  it("a quoted case whose name ends in settled()", () => {});\n'
        "});\n"
    ),
    "extensions/node/tools/probe.test.mjs": (
        'import { test } from "node:test";\n\n'
        'test("a case in a suite outside the old glob", () => {});\n'
    ),
    # Where the gate allocates its own scratch, which is where the checker
    # READS the directory a tag may not offer as evidence.
    "tests/checks/gate_scratch.sh": (
        "metta_gate_scratch_open() {\n"
        f'    METTA_GATE_SCRATCH_BASE="$root/{SCRATCH}/check-runs"\n'
        "}\n"
    ),
    "examples/kept.metta": "!(test (+ 1 2) 3)\n",
    "examples/quiet.metta": "!(+ 1 2)\n",
    "examples/skipped.metta": "!(test (+ 1 2) 3)\n",
    "tests/data/example_skips.txt": (
        "# One path per line, then its reason.\nexamples/skipped.metta   needs a terminal\n"
    ),
}


def build(root: Path, pytest_anchor: str) -> dict[str, int]:
    """Write the tree, and answer with the fixture line each citation sits on."""
    for name, content in FILES.items():
        path = root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
    (root / "check.sh").write_text(CHECK_SH)
    # Three gate scripts, because the tree has three: the root, the Python
    # seat's, and the engine's. The pytest command lives in the seat's test.sh
    # and the plunit loop in the engine's check.sh, so the fixture builds each
    # where the collector looks for it. Writing either into the root file would
    # make this selftest prove a shape the tree no longer has.
    for name, content in (
        ("extensions/python/check.sh", PYTHON_CHECK_SH),
        ("extensions/python/test.sh", PYTHON_TEST_SH.format(pytest_anchor=pytest_anchor)),
        ("engine/check.sh", ENGINE_CHECK_SH),
        ("engine/test.sh", ENGINE_TEST_SH),
        ("extensions/cmetta/check.sh", CMETTA_CHECK_SH),
        ("extensions/cmetta/test.sh", CMETTA_TEST_SH),
        ("extensions/node/check.sh", NODE_CHECK_SH),
        ("extensions/node/test.sh", NODE_TEST_SH),
    ):
        component = root / name
        component.parent.mkdir(parents=True, exist_ok=True)
        component.write_text(content)
    (root / "test.sh").write_text(TEST_SH)

    # Two levels down, mirroring the real tests/checks/ so the checker's own
    # ROOT, which is parents[2] of evidence_runners.py, lands on <tree>. Not
    # under <tree>/tests/checks, which is where the real ones live, because
    # SOURCES scans that directory and a visiting copy's docstring would be
    # read as claims about the tree it is only inspecting.
    tools = root / "tools" / "checks"
    tools.mkdir(parents=True, exist_ok=True)
    for module in ("check_evidence_tags.py", "evidence_runners.py"):
        text = (HERE / module).read_text(encoding="utf-8")
        if MUTATION is not None and MUTATION["module"] == module:
            text = text.replace(MUTATION["old"], MUTATION["new"])
        (tools / module).write_text(text, encoding="utf-8")

    lines = ["% Purpose: fixtures for check_evidence_selftest.py.", "% Guarantees:"]
    at = {}
    for _, names, why in CITATIONS:
        at[names] = len(lines) + 1
        lines.append(f"%   - {why} [{TAG} {WHEN}: {names}].")
    lines += ["% Open Obligations:", "%   To Do: None", "%   Hacks: None",
              "%   Future Enhancements: None", "", "fixture_predicate."]
    (root / "engine").mkdir(exist_ok=True)
    (root / "engine/fixture.pl").write_text("\n".join(lines) + "\n")
    return at


def run(root: Path) -> list[str]:
    """Run the real checker over one fixture tree and answer its report lines."""
    finished = subprocess.run(
        [sys.executable, str(root / "tools/checks/check_evidence_tags.py")],
        capture_output=True,
        text=True,
        check=False,
    )
    # An uncaught exception also exits 1, which is the exit a clean report
    # with findings uses, so the traceback is what tells them apart: on
    # 2026-09-09 an import the fixture tree could not satisfy printed no
    # report, and every planted bad citation read as accepted.
    if finished.returncode not in (0, 1) or "Traceback (most recent call last)" in finished.stderr:
        msg = f"the checker crashed on the fixture tree:\n{finished.stderr}"
        raise SystemExit(msg)
    return finished.stdout.splitlines()



def symlinked_output_complaints() -> list[str]:
    """Compiler output paths belong to the command even when storage is shared."""
    complaints = []
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory) / "tree"
        at = build(root, PYTEST_ANCHOR)
        shared = Path(directory) / "shared-build"
        shared.mkdir()
        package = root / "extensions/node"
        (package / "build").symlink_to(shared, target_is_directory=True)
        name = '"a case whose suite is compiled before it runs"'
        marker = f"engine/fixture.pl:{at[name]}:"
        if any(line.startswith(marker) for line in run(root)):
            complaints.append("a symlinked outDir hid its selected TypeScript suite")

        manifest = package / "package.json"
        manifest.write_text(manifest.read_text().replace("build/test/", "unselected/test/"))
        if not any(line.startswith(marker) for line in run(root)):
            complaints.append("a symlinked outDir admitted a suite the command does not select")
    return complaints


def seat_relative_path_complaints() -> list[str]:
    """A path in a citation is read from the root AND from the citing file.

    A seat's header cites the file beside it the way a reader of that seat
    would type it: cmetta.h sits in extensions/cmetta/ and names
    `tests/test_cmetta.c`. Resolving only against the repository root called
    ten such citations unbacked on the day the C seat first came under this
    lane, which is why the rule exists and why the negative control below
    matters as much as the positive one.
    """
    complaints = []
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        build(root, PYTEST_ANCHOR)
        header = root / "extensions/cmetta/fixture.h"
        header.write_text(
            "/* Purpose: a fixture beside the C suite.\n"
            " * Guarantees:\n"
            f" *   - the suite next door backs this [{TAG} {WHEN}: tests/c_suite.c].\n"
            f" *   - this one names a suite that is not there [{TAG} {WHEN}: tests/absent.c].\n"
            " * Open Obligations:\n"
            " *   To Do: None\n"
            " *   Hacks: None\n"
            " *   Future Enhancements: None\n"
            " */\n"
        )
        output = run(root)
        # Only what this header said: the citation table's own plants name the
        # same suite from engine/fixture.pl, and one of them is meant to be
        # reported.
        mine = [line for line in output if line.startswith("extensions/cmetta/fixture.h:")]
        beside = [line for line in mine if "tests/c_suite.c" in line]
        missing = [line for line in mine if "tests/absent.c" in line]
        if beside:
            complaints.append(f"rejected a path beside its citing file: {beside[0]}")
        if not missing:
            complaints.append(
                "accepted tests/absent.c, which is beside nothing and under no root"
            )
    return complaints


def line_continuation_complaints() -> list[str]:
    """A lane written across a backslash-newline runs what it names.

    A backslash-newline is ONE logical line to the shell, and the lane pattern
    read only the physical one, so the command was the backslash and every
    script such a lane runs was modelled as run by nothing. Two GATE lanes in
    the real check.sh are written that way and both of their scripts read as
    unexecuted [measured 2026-09-05]. The negative half matters as much: a
    script no lane names at all must still be reported, or joining the lines
    would have made the model believe everything.
    """
    complaints = []
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        build(root, PYTEST_ANCHOR)
        (root / "check.sh").write_text(
            CHECK_SH.replace(
                "run GATE checked sh -c \"cd '$HERE' && '$PY' tests/checked.py\"",
                "run GATE checked \\\n    sh -c \"cd '$HERE' && '$PY' tests/checked.py\"",
            )
        )
        fixture = root / "engine/fixture.pl"
        lines = fixture.read_text().splitlines()
        head = lines.index("% Open Obligations:")
        planted = [
            f"%   - a continued lane's script [{TAG} {WHEN}: tests/checked.py].",
            f"%   - a script no lane names [{TAG} {WHEN}: tests/orphan/orphan_check.pl].",
        ]
        at_continued, at_orphan = head + 1, head + 2
        fixture.write_text("\n".join(lines[:head] + planted + lines[head:]) + "\n")

        output = run(root)
        if any(line.startswith(f"engine/fixture.pl:{at_continued}:") for line in output):
            complaints.append(
                "a lane written across a line continuation still reads as running nothing"
            )
        if not any(line.startswith(f"engine/fixture.pl:{at_orphan}:") for line in output):
            complaints.append(
                "joining line continuations made a script no lane names read as executed"
            )
    return complaints


def seat_root_path_complaints() -> list[str]:
    """A path in a citation is read from the SEAT root as well.

    extensions/python/tests/ch17_concurrency_and_the_loop/test_async_space.py
    cites its own path from extensions/python/, which is neither beside it nor
    at the repository root; a reader standing in the seat types exactly that.
    A seat is a directory holding its own control file, which is the test
    build.sh and check.sh already apply, so the negative control is a path
    that resolves under NO seat.
    """
    complaints = []
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        build(root, PYTEST_ANCHOR)
        probe = root / "extensions/cmetta/tests/seat_probe.c"
        probe.write_text(
            "/* Purpose: a fixture one directory inside the C seat.\n"
            " * Guarantees:\n"
            f" *   - the seat's suite backs this [{TAG} {WHEN}: tests/c_suite.c].\n"
            f" *   - this names nothing under any seat [{TAG} {WHEN}: tests/absent.c].\n"
            " * Open Obligations:\n"
            " *   To Do: None\n"
            " *   Hacks: None\n"
            " *   Future Enhancements: None\n"
            " */\n"
        )
        output = run(root)
        mine = [line for line in output if line.startswith("extensions/cmetta/tests/seat_probe.c:")]
        if [line for line in mine if "tests/c_suite.c" in line]:
            complaints.append(
                "rejected a path cited from the seat root rather than from beside the file"
            )
        if not [line for line in mine if "tests/absent.c" in line]:
            complaints.append("accepted tests/absent.c, which resolves under no seat")
    return complaints


def tracked_probe_complaints() -> list[str]:
    """A tracked probe's own claims are read, and a stale citation is reported.

    A probe is where a measurement's reproduction is KEPT when the fixture is
    worth having, which is exactly what the scratch rule asks an author to do
    instead of naming a path that goes with the checkout. So the one directory
    holding those reproductions cannot be the one directory whose own claims
    nothing reads: four pins in it had to be written by hand, because
    pin_provenance refuses a placeholder outside the gate's globs, and a
    citation there going stale would have been nobody's finding.
    """
    complaints = []
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        build(root, PYTEST_ANCHOR)
        probe = root / "extensions/python/benchmarks/probes/probe.py"
        probe.parent.mkdir(parents=True, exist_ok=True)
        probe.write_text(
            '"""Purpose: a fixture probe among the seat\'s tracked ones.\n'
            "Guarantees:\n"
            f"  - the collected test backs this [{TAG} {WHEN}: test_collected].\n"
            f"  - this one names nothing [{TAG} {WHEN}: no_such_probe_test].\n"
            "Open Obligations:\n"
            "  To Do: None\n"
            "  Hacks: None\n"
            "  Future Enhancements: None\n"
            '"""\n'
        )
        output = run(root)
        mine = [
            line for line in output
            if line.startswith("extensions/python/benchmarks/probes/probe.py:")
        ]
        if [line for line in mine if "test_collected" in line]:
            complaints.append("rejected a probe's citation of a test the pytest lane collects")
        if not [line for line in mine if "no_such_probe_test" in line]:
            complaints.append(
                "accepted a probe's citation of a name the tree does not define, so "
                "nothing reads a tracked probe's claims"
            )
    return complaints


def prolog_tool_complaints() -> list[str]:
    """A Prolog tool's claims are checked beside the Python tools' claims."""
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        build(root, PYTEST_ANCHOR)
        relative = "extensions/python/tools/fixture.pl"
        tool = root / relative
        tool.parent.mkdir(parents=True, exist_ok=True)
        tool.write_text(
            "% Purpose: a fixture among the binding checker's native tools.\n"
            "% Guarantees:\n"
            f"%   - a collected test backs this [{TAG} {WHEN}: test_collected].\n"
            f"%   - this names no test [{TAG} {WHEN}: no_such_binding_tool_test].\n"
        )
        reported = [line for line in run(root) if line.startswith(f"{relative}:")]
        if len(reported) != 1 or not reported[0].startswith(f"{relative}:4:") or (
            "no_such_binding_tool_test" not in reported[0]
        ):
            return [f"Prolog tools must report only their planted absent test: {reported!r}"]
    return []


def scratch_path_complaints() -> list[str]:
    """A tag may not offer a path under the repository's own scratch directory.

    That path goes with the checkout that wrote it, so the claim above it is
    one only its author could ever check. This tree carried 73 such tags and
    not one of the 64 distinct paths in them still existed anywhere on the
    machine that wrote them [measured 2026-09-07].

    Three things, and the third is what makes the rule a rule rather than a
    list: a tracked path is fine, a scratch one is reported, and the scratch
    DIRECTORY is read from the runner that allocates it, so a run that cannot
    find that assignment says so instead of quietly accepting everything.
    """
    complaints = []
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        build(root, PYTEST_ANCHOR)
        fixture = root / "engine/fixture.pl"
        lines = fixture.read_text().splitlines()
        head = lines.index("% Open Obligations:")
        planted = [
            f"%   - a tracked fixture [{MEASURED} {WHEN}: "
            f"fixture=tests/data/example_skips.txt].",
            f"%   - one under the scratch root [{MEASURED} {WHEN}: "
            f"fixture={SCRATCH}/probe.pl].",
        ]
        at_tracked, at_scratch = head + 1, head + 2
        fixture.write_text("\n".join(lines[:head] + planted + lines[head:]) + "\n")

        output = run(root)
        if any(line.startswith(f"engine/fixture.pl:{at_tracked}:") for line in output):
            complaints.append("rejected a fixture path the repository tracks")
        reported = [
            line for line in output
            if line.startswith(f"engine/fixture.pl:{at_scratch}:")
        ]
        if not reported:
            complaints.append(
                "accepted a fixture under the scratch root, which goes with the "
                "checkout that wrote it"
            )
        elif len(reported) > 1:
            complaints.append(f"reported the scratch fixture {len(reported)} times, expected once")

        # And the rule's own authority. The scratch directory is the gate's,
        # not this file's, so a runner that stops declaring it must surface as
        # a finding rather than as a refusal that has silently stopped
        # refusing -- the same contract a collector's anchor carries.
        (root / "tests/checks/gate_scratch.sh").write_text("metta_gate_scratch_open() { :; }\n")
        moved = run(root)
        if not any("METTA_GATE_SCRATCH_BASE" in line for line in moved):
            complaints.append(
                "a gate_scratch.sh that no longer declares its scratch root went "
                "unreported, so the refusal stopped refusing in silence"
            )
    return complaints


def commit_pin_complaints() -> list[str]:
    """A commit= must name a real commit, and WORKTREE must not survive a release.

    The fixture is a real repository with one commit, so the live object ID is
    known and the fabricated one differs from it only in its tail: that is the
    shape the check found in the tree on 2026-08-26, where a citation carried
    a full object ID sharing eight characters with a real commit and nothing
    else.
    """
    complaints = []
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        build(root, PYTEST_ANCHOR)
        for command in (
            ["git", "init", "-q"],
            ["git", "add", "-A"],
            ["git", "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "fixture"],
        ):
            # unbounded: git over a temporary directory, which returns.
            subprocess.run(command, cwd=root, check=True, capture_output=True)
        live = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=root, check=True, capture_output=True, text=True,
        ).stdout.strip()
        fabricated = live[:8] + ("0" * (len(live) - 8) if live[8] != "0" else "1" * (len(live) - 8))

        fixture = root / "engine/fixture.pl"
        lines = fixture.read_text().splitlines()
        head = lines.index("% Open Obligations:")
        planted = [
            f"%   - a live pin [{TAG} {WHEN}: test_collected; commit={live}].",
            f"%   - a dangling pin [{TAG} {WHEN}: test_collected; commit={fabricated}].",
            f"%   - an unresolved pin [{TAG} {WHEN}: test_collected; commit={PLACEHOLDER}].",
        ]
        at_live, at_dangling, at_worktree = head + 1, head + 2, head + 3
        fixture.write_text("\n".join(lines[:head] + planted + lines[head:]) + "\n")

        output = run(root)
        for line, what, wanted in (
            (at_live, "a live commit pin", False),
            (at_dangling, "a dangling commit pin", True),
        ):
            reported = [
                item for item in output
                if item.startswith(f"engine/fixture.pl:{line}:") and "commit=" in item
            ]
            if wanted and not reported:
                complaints.append(f"accepted {what}, which names no commit in the repository")
            if not wanted and reported:
                complaints.append(f"rejected {what}: {reported[0]}")
        if not any(f"commit={PLACEHOLDER} placeholder" in item for item in output):
            complaints.append(f"the report does not count commit={PLACEHOLDER} placeholders")

        # The fixture plants rejected citations too, so this tree exits 1
        # either way and the exit code says nothing. The refusal SENTENCE is
        # what discriminates, and it must appear only under RELEASE=1.
        refusal = f"still say commit={PLACEHOLDER}"
        released = subprocess.run(
            [sys.executable, str(root / "tools/checks/check_evidence_tags.py")],
            cwd=root, capture_output=True, text=True, check=False,
            env={**os.environ, "RELEASE": "1"},
        )
        if refusal not in released.stdout:
            complaints.append(
                f"RELEASE=1 accepted a tree with a commit={PLACEHOLDER} placeholder "
                f"at engine/fixture.pl:{at_worktree}"
            )
        if any(refusal in item for item in output):
            complaints.append(
                f"an ordinary run refuses commit={PLACEHOLDER}, which is the "
                "in-progress spelling and must only fail a release"
            )
    return complaints


def main() -> int:
    """Plant every fault, run the real checker over each, and report what it missed."""
    complaints = []
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        at = build(root, PYTEST_ANCHOR)
        output = run(root)
        for accepted, names, why in CITATIONS:
            marker = f"engine/fixture.pl:{at[names]}:"
            reported = [line for line in output if line.startswith(marker)]
            if accepted and reported:
                complaints.append(f"rejected {why}, which is backed: {reported[0]}")
            elif not accepted and not reported:
                complaints.append(f"accepted {why} [{names}], which is not backed")
            elif not accepted and len(reported) > 1:
                complaints.append(f"reported {names} {len(reported)} times, expected once")
        # Nothing else may be said about a tree this file wrote, so a model
        # that has drifted from the runners cannot hide behind the count.
        expected = {f"engine/fixture.pl:{at[names]}:" for accepted, names, _ in CITATIONS}
        complaints.extend(
            f"reported something the fixture did not plant: {line}"
            for line in output[:-1]
            if not any(line.startswith(marker) for marker in expected)
        )

    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        build(root, "pytest tests -q --moved-since-the-model-was-written")
        output = run(root)
        if not any("no longer contains" in line for line in output):
            complaints.append("a collector whose anchor left the runner went unreported")

    complaints += symlinked_output_complaints()
    complaints += seat_relative_path_complaints()
    complaints += seat_root_path_complaints()
    complaints += line_continuation_complaints()
    complaints += tracked_probe_complaints()
    complaints += prolog_tool_complaints()
    complaints += scratch_path_complaints()
    complaints += commit_pin_complaints()

    for complaint in complaints:
        print(complaint)
    print(
        f"{len(complaints)} defect(s) in the evidence gate, over "
        f"{len(CITATIONS)} planted citations, one moved anchor, three commit "
        f"pins, a symlinked output directory, a path cited from beside its own file, a path cited from its "
        f"seat root, a lane written across a line continuation, a fixture "
        f"under the scratch root beside one the tree tracks, and a tracked "
        f"probe and a Prolog tool citing tests that are not there"
    )
    return 1 if complaints else 0


if __name__ == "__main__":
    sys.exit(main())
