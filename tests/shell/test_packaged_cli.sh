#!/bin/sh
# Purpose: build this repository into a wheel, install it into a venv OUTSIDE
#   the checkout, and exercise the installed copy: the launcher runs programs
#   and imports libraries from an unrelated working directory, the runtime tree
#   setup.py maps into metta/_runtime/ is all there, metta.llms() prints the
#   whole cheat sheet, and the CLI carries its filter surface.
# Guarantees:
#   - new nested binding files ship through both source archives and wheels;
#     damaged wheel runtimes refuse by path through standalone and embedded
#     boot [tested: sh tools/check.sh packaged; commit=8ee8fcd4e43a932131909f7c58ad4fbe4dcf8d1d].
#   - every claim is made against the INSTALL. A resource the wheel drops is
#     invisible in a checkout, where the same door reads the repository root,
#     so a source-tree test cannot answer this question at all.
#   - the checkout's own llms.txt is the oracle for what the install printed,
#     because the wheel under test was built from it moments earlier.
#   - no boot writes to stderr. Every other claim here is about a VALUE, and a
#     failed use_module directive leaves every value right while the install is
#     broken, which is how the 0.9.0 shim.pl regression passed this file
#     [tested: sh tools/check.sh packaged; commit=1c8dde7ea24138f482c3e834b8a8152efd613cf8].
#   - every shipped module imports with no component root above the install,
#     which is what an ordinary pip install is. `import metta` succeeding says
#     nothing about the other 184 [tested: sh tools/check.sh packaged;
#     commit=1c8dde7ea24138f482c3e834b8a8152efd613cf8].
#   - the runtime tree is checked against setup.py's RUNTIME_RESOURCES rather
#     than a list repeated here, so an entry added to the map is covered
#     without editing this file [tested: sh tools/check.sh packaged;
#     commit=1c8dde7ea24138f482c3e834b8a8152efd613cf8].
#   - the installed CLI carries the filter surface: `run` names --json and the
#     standard-input operand, `doc` names --infer. Their BEHAVIOUR needs the
#     engine extra, which this dependency-free install does not have, and is
#     checked in the checkout instead.
# Fails when: uv or swipl is absent, which it refuses on rather than skipping.
# Owns resources: the EXIT trap removes the private build and install tree;
#   bounded.sh reaps subprocesses.
# Open Obligations:
#   To Do: None
#   Hacks: None
#   Future Enhancements: None
set -eu

# faulthandler armed for every interpreter below, including the one embedded in
# the packaged CLI's engine. These are the runs that boot SWI outside pytest, so
# nothing else arms it for them, and a fatal signal or a fault during
# interpreter shutdown would otherwise print nothing at all before the exit
# status [source: https://docs.python.org/3/library/faulthandler.html].
PYTHONFAULTHANDLER=1
export PYTHONFAULTHANDLER

command -v uv >/dev/null
command -v swipl >/dev/null

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
METTA_ROOT="$project_dir"
. "$project_dir/tools/select-python.sh"
bounded() { sh "$project_dir/tools/bounded.sh" "$@"; }
# A boot that writes to stderr is a broken install however right its answer.
# SWI reports a failed use_module directive there and CARRIES ON, so four
# ERROR lines at first boot coexisted with the correct answer for !(+ 1 2)
# and every assertion below passed: 0.9.0 nearly shipped a shim.pl whose
# imports were spelled relative to a file that ships at two depths. Empty
# rather than free-of-a-pattern, because the published 0.8.0 boots with zero
# bytes on this host [measured 2026-09-22: control and candidate arms both
# gave status 0, "answer: [[Grounded(3)]]" and a 0-byte stderr], so an
# allowlist would only be somewhere for the next one to hide. Debian's
# piuparts makes the same any-output-is-a-failure choice across its archive.
quiet() {
    log=$1
    shift
    bounded "$@" > "$log" 2> "$log.err"
    if [ -s "$log.err" ]; then
        printf 'the install wrote %s bytes to stderr, which a clean one does not:\n' \
            "$(wc -c < "$log.err")" >&2
        cat "$log.err" >&2
        exit 1
    fi
}
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT HUP INT TERM

bounded uv build --out-dir "$fixture/dist" "$project_dir"
wheel=$(find "$fixture/dist" -name 'pymetta-*.whl' -print -quit)
bounded uv venv --python "$PY" "$fixture/venv"
bounded uv pip install --python "$fixture/venv/bin/python" --no-deps "$wheel"
test -x "$fixture/venv/bin/metta"

mkdir "$fixture/unrelated cwd"
printf '!(+ 1 1)\n' > "$fixture/basic.metta"
printf '!(import! &self (library lib_import))\n' > "$fixture/import.metta"
printf '!(import! &self (library lib_roman))\n!(map-flat (+ 1) (1 2 3))\n' \
    > "$fixture/roman.metta"

(
    cd "$fixture/unrelated cwd"
    unset METTA_PATH
    quiet "$fixture/basic.log" "$fixture/venv/bin/metta" "$fixture/basic.metta"
    quiet "$fixture/import.log" "$fixture/venv/bin/metta" "$fixture/import.metta"
    quiet "$fixture/roman.log" "$fixture/venv/bin/metta" "$fixture/roman.metta"
    quiet "$fixture/llms.log" "$fixture/venv/bin/python" -c 'import metta; metta.llms()'
    quiet "$fixture/llms-verb.log" "$fixture/venv/bin/python" -m metta llms
    # The filter faces as far as an install WITHOUT the engine extra reaches:
    # the operand and the flag are argparse, and argparse runs before anything
    # imports janus. Running a program through them needs janus_swi, which
    # --no-deps deliberately leaves out (and which this box cannot install
    # anyway, its wheel linking libswipl.so.9 against a SWI 10), so the
    # BEHAVIOUR is checked in the checkout by
    # extensions/python/tests/ch01_getting_started/test_main_module.py and what
    # is checked here is that the wheel ships the surface at all.
    quiet "$fixture/run-help.log" "$fixture/venv/bin/python" -m metta run --help
    quiet "$fixture/doc-help.log" "$fixture/venv/bin/python" -m metta doc --help
    # The provenance faces, at the same depth and for the same reason: `card`
    # reads a library's own sources through the engine's reader and `lock`
    # runs the programs it pins, so both need janus to DO anything, and what
    # this install can answer is that the wheel ships them at all.
    quiet "$fixture/card-help.log" "$fixture/venv/bin/python" -m metta card --help
    quiet "$fixture/lock-help.log" "$fixture/venv/bin/python" -m metta lock --help
)

grep -Fxq '2' "$fixture/basic.log"
grep -Fq '(2 3 4)' "$fixture/roman.log"

# Short fragments, because argparse wraps its help to the terminal width and a
# whole sentence would be a width test rather than a surface one.
grep -Fq -- '--json' "$fixture/run-help.log"
grep -Fq -- '--json=wire' "$fixture/run-help.log"
grep -Fq 'no operand' "$fixture/run-help.log"
grep -Fq -- '--infer' "$fixture/doc-help.log"
grep -Fq 'lib_x' "$fixture/card-help.log"
grep -Fq -- '--locked' "$fixture/run-help.log"
grep -Fq 'metta.lock' "$fixture/lock-help.log"

# The cheat sheet is the one document a reader who pip-installed this has no
# checkout to find, so metta.llms() has to answer from the INSTALL or the door
# is a checkout-only convenience. Byte equality against the checkout's own file
# is the whole question: it says the file shipped, that all of it shipped, and
# that the first line is still the sheet's title, where a `test -s` would pass
# on a truncated copy. Same bytes from the subcommand, so the two faces cannot
# drift apart in a released wheel either.
cmp "$project_dir/llms.txt" "$fixture/llms.log"
cmp "$project_dir/llms.txt" "$fixture/llms-verb.log"

# The runtime tree an installed MeTTa has to find, checked in the install
# rather than in the checkout. extensions/ is here because the engine GLOBS it
# on every boot and expand_file_name/2 answers [] for a missing directory
# exactly as it does for one holding no built seat: an unshipped seam and an
# unbuilt seat are the same thing at run time, so nothing but a packaging check
# tells them apart. setup.py did not ship it until 2026-08-17, which made
# EXTENDING.md's "a seat is a folder with a control file" false for every
# wheel.
bounded "$fixture/venv/bin/python" - "$project_dir" <<'PY'
import ast
import importlib.util
import sys
from pathlib import Path

import metta

# setup.py's RUNTIME_RESOURCES is the ONE place that says what ships, so it is
# read rather than listed again here. The five names this replaced covered five
# of its eight and missed extensions/python/metta/_binding, which is where
# shim.pl lives: the file whose two-depth resolution is the one that nearly
# shipped broken. A hand-written copy of a declaration drifts, and the copy in
# .github/workflows/checks.yml already did, asserting `extensions/*.pl` for
# months after the seats moved to `extensions/*/` and matching nothing.
# Parsed rather than imported, because importing setup.py runs setuptools'
# argument handling; tests/ch01_getting_started/test_packaging.py reads the
# same assignment the same way.
declaration = ast.parse((Path(sys.argv[1]) / "setup.py").read_text(encoding="utf-8"))
resources = next(
    ast.literal_eval(node.value)
    for node in ast.walk(declaration)
    if isinstance(node, ast.Assign)
    and any(getattr(target, "id", None) == "RUNTIME_RESOURCES" for target in node.targets)
)
runtime = Path(metta.__file__).parent / "_runtime"
for required in sorted(resources.values()):
    assert (runtime / required).exists(), f"{required} is missing from the wheel"
print(f"{len(resources)} declared runtime resources all resolve in the install")
assert list((runtime / "extensions").glob("*/extension.pl")), "extensions/ shipped empty"
assert importlib.util.find_spec("pymetta") is None, "the distribution name became a module"
PY

# EVERY module the package ships, imported from an install with no component
# root above it. This is the generative form of a defect that three separate
# value assertions above could not see: `seat()` and `workspace()` raise by
# design in an install, so any module resolving one at IMPORT scope is dead for
# a user whose venv is not inside a project directory, and nothing here asked.
# Two module-level assignments took 37 of 185 modules down that way --
# metta.algebra, metta.library, metta.lint, metta.testing and the rest, through
# metta._declare.define -- while `import metta` itself still worked and every
# check in this file passed [measured 2026-09-22: the published 0.8.0 imports
# 97 of 98 from a rootless location, that tree 148 of 185].
#
# METTA_WORKSPACE and METTA_PATH are cleared rather than assumed absent: either
# one makes workspace() answer, which is exactly the accident that hides this.
# metta/_runtime is skipped because it is the engine tree shipped as a data
# payload and carries no __init__.py, so its .py files are not modules the
# package imports; engine/bench.py is a benchmark driver and reaches for the
# harness by a name only a checkout has.
# In a subshell rather than through `env`, because bounded is a shell function
# and env can only exec a program.
(
unset METTA_WORKSPACE METTA_PATH METTA_ROOT
bounded "$fixture/venv/bin/python" - <<'PY'
import importlib
import sys
import warnings
from pathlib import Path

import metta

package = Path(metta.__file__).parent
warnings.simplefilter("ignore")
names = []
for source in sorted(package.rglob("*.py")):
    relative = source.relative_to(package.parent).with_suffix("")
    parts = list(relative.parts)
    if "_runtime" in parts:
        continue
    if parts[-1] == "__init__":
        parts.pop()
    names.append(".".join(parts))

# What counts is the rootless refusal SPECIFICALLY, not any failure to import.
# This venv is installed --no-deps on purpose, so annotated_types, pytest and
# docstring_parser are absent and 79 modules say so; that is this file's own
# choice showing through, and metta.testing._machine's "install pymetta[test]"
# is a deliberate refusal working correctly. `_roots.py` is the only thing that
# raises RuntimeError naming the two component markers, so matching it is exact
# rather than a guess at which failures are real.
#
# What this therefore does NOT decide: a site that resolves a checkout path by
# counting parents instead of asking, which yields a wrong path silently rather
# than raising. That is the failure `_roots.py` exists to abolish and its
# docstring records 243 instances of; nothing here would see a 244th.
rootless = []
other = []
for name in names:
    try:
        importlib.import_module(name)
    except RuntimeError as error:
        (rootless if "no component above" in str(error)
         or "no workspace above" in str(error) else other).append((name, error))
    except Exception as error:                                       # noqa: BLE001
        other.append((name, error))
for name, error in rootless:
    print(f"  {name} needs a checkout: {str(error).splitlines()[0][:120]}", file=sys.stderr)
print(f"{len(names) - len(rootless)} of {len(names)} shipped modules import with no checkout "
      f"above them ({len(other)} unimportable for other reasons, which a --no-deps "
      f"install cannot tell apart from a real one)")
assert not rootless, f"{len(rootless)} shipped module(s) need a checkout to import"
PY
)

bounded "$PY" "$project_dir/tests/checks/check_packaged_runtime.py" "$wheel"

echo "packaged pymetta CLI tests passed"
