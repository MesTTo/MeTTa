#!/bin/sh
# Purpose: build this repository into a wheel, install it into a venv OUTSIDE
#   the checkout, and exercise the installed copy: the launcher runs programs
#   and imports libraries from an unrelated working directory, the runtime tree
#   setup.py maps into metta/_runtime/ is all there, metta.llms() prints the
#   whole cheat sheet, and the CLI carries its filter surface.
# Guarantees:
#   - new nested binding files ship through both source archives and wheels;
#     damaged wheel runtimes refuse by path through standalone and embedded
#     boot [tested: sh check.sh packaged; commit=8ee8fcd4e43a932131909f7c58ad4fbe4dcf8d1d].
#   - every claim is made against the INSTALL. A resource the wheel drops is
#     invisible in a checkout, where the same door reads the repository root,
#     so a source-tree test cannot answer this question at all.
#   - the checkout's own llms.txt is the oracle for what the install printed,
#     because the wheel under test was built from it moments earlier.
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
. "$project_dir/select-python.sh"
bounded() { sh "$project_dir/bounded.sh" "$@"; }
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
    bounded "$fixture/venv/bin/metta" "$fixture/basic.metta" > "$fixture/basic.log"
    bounded "$fixture/venv/bin/metta" "$fixture/import.metta" > "$fixture/import.log"
    bounded "$fixture/venv/bin/metta" "$fixture/roman.metta" > "$fixture/roman.log"
    bounded "$fixture/venv/bin/python" -c 'import metta; metta.llms()' > "$fixture/llms.log"
    bounded "$fixture/venv/bin/python" -m metta llms > "$fixture/llms-verb.log"
    # The filter faces as far as an install WITHOUT the engine extra reaches:
    # the operand and the flag are argparse, and argparse runs before anything
    # imports janus. Running a program through them needs janus_swi, which
    # --no-deps deliberately leaves out (and which this box cannot install
    # anyway, its wheel linking libswipl.so.9 against a SWI 10), so the
    # BEHAVIOUR is checked in the checkout by
    # extensions/python/tests/ch01_getting_started/test_main_module.py and what
    # is checked here is that the wheel ships the surface at all.
    bounded "$fixture/venv/bin/python" -m metta run --help > "$fixture/run-help.log"
    bounded "$fixture/venv/bin/python" -m metta doc --help > "$fixture/doc-help.log"
    # The provenance faces, at the same depth and for the same reason: `card`
    # reads a library's own sources through the engine's reader and `lock`
    # runs the programs it pins, so both need janus to DO anything, and what
    # this install can answer is that the wheel ships them at all.
    bounded "$fixture/venv/bin/python" -m metta card --help > "$fixture/card-help.log"
    bounded "$fixture/venv/bin/python" -m metta lock --help > "$fixture/lock-help.log"
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
bounded "$fixture/venv/bin/python" - <<'PY'
from pathlib import Path
import metta
import importlib.util

runtime = Path(metta.__file__).parent / "_runtime"
for required in (
    "engine",
    "lib",
    "extensions/mork/extension.pl",
    "extension.pl",
    "llms.txt",
):
    assert (runtime / required).exists(), f"{required} is missing from the wheel"
assert list((runtime / "extensions").glob("*/extension.pl")), "extensions/ shipped empty"
assert importlib.util.find_spec("pymetta") is None, "the distribution name became a module"
PY

bounded "$PY" "$project_dir/tests/checks/check_packaged_runtime.py" "$wheel"

echo "packaged pymetta CLI tests passed"
