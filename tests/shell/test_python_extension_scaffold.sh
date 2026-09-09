#!/bin/sh
# Purpose: build and install the distribution the extension-new command writes.
# Guarantees: installed metadata advertises its door, both receiver tiers call
#   it, and withdrawal invalidates a retained method [tested:
#   sh check.sh extension-scaffold; commit=WORKTREE].
# Owns resources: the temporary distribution, wheel and installation are removed
#   by the EXIT trap [source: this file; commit=WORKTREE].
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
: "${CHECK_PY:=python3}"
command -v uv >/dev/null
scratch=$(mktemp -d "${TMPDIR:-$project_dir/ai-tmp}/extension-scaffold.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
cd "$scratch"
PYTHONPATH="$project_dir/extensions/python${PYTHONPATH:+:$PYTHONPATH}" \
    "$CHECK_PY" -m metta extension new aurora-beam
uv build --wheel --python "$CHECK_PY" --out-dir "$scratch/wheels" "$scratch/aurora-beam"
uv pip install --python "$CHECK_PY" --target "$scratch/site" --no-deps \
    "$scratch/wheels/aurora_beam-0.1.0-py3-none-any.whl"
export PYTHONPATH="$scratch/site:$project_dir/extensions/python${PYTHONPATH:+:$PYTHONPATH}"
"$CHECK_PY" - <<'PY'
import sys
from importlib.metadata import distribution

from metta import MeTTa, S, doors, seam

package = distribution("aurora-beam")
assert package.version == "0.1.0"
assert "aurora-beam" in seam.advertised()
assert "aurora_beam" not in sys.modules
with MeTTa() as context:
    assert context.aurora_beam.echo(42) == 42
    assert context.self.aurora_beam.echo(S.example) is S.example
    row = doors.table()["aurora_beam:echo"]
    assert row.body.module == "aurora_beam"
    assert row.body.symbol == "echo"
    assert "Return the supplied value" in row.docs
    retained = context.aurora_beam.echo
    seam.door.unregister("aurora-beam")
    try:
        retained(1)
    except AttributeError as refusal:
        assert "withdrawn" in str(refusal)
    else:
        raise AssertionError("a retained method invoked a withdrawn door")
print("installed scaffold: advertised, typed, called on both tiers, withdrawn")
PY
"$CHECK_PY" -m pytest --noconftest -c /dev/null -q -p no:benchmark \
    -o "cache_dir=$scratch/pytest-cache" "$scratch/aurora-beam/tests"
"$CHECK_PY" "$scratch/aurora-beam/examples/echo.py" > "$scratch/example.log"
grep -Fxq hello "$scratch/example.log"
"$CHECK_PY" "$scratch/aurora-beam/benchmarks/echo.py"
echo "extension scaffold: built, installed, tested and executed"
