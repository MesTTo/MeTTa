"""Purpose: exercise runtime directory closure and damaged installed engines.

Guarantees: a fixture's new nested include ships through the real setuptools
builder, a file-enumerating control omits it, and incomplete wheel runtimes
refuse through both standalone and embedded boot with the failing path named
[tested: tests/shell/test_packaged_cli.sh; commit=8ee8fcd4e43a932131909f7c58ad4fbe4dcf8d1d].
Owns resources: TemporaryDirectory owns all fixture sources and wheel copies;
bounded subprocesses are reaped before those trees are removed.
"""

from __future__ import annotations

import os
import runpy
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path
from unittest.mock import patch

from bounded_spawn import bounded
from setuptools import Distribution

ROOT = Path(__file__).resolve().parents[2]
BINDING = "extensions/python/metta/_binding"


def check_directory_closure(scratch: Path) -> None:
    """Build a new nested source through the real runtime-copying command."""
    with patch("setuptools.setup"):
        setup = runpy.run_path(str(ROOT / "setup.py"))
    builder = setup["build_py_with_runtime"]
    inputs = scratch / "inputs"
    resources = setup["RUNTIME_RESOURCES"]
    for relative in resources:
        destination = inputs / relative
        if (ROOT / relative).is_dir():
            destination.mkdir(parents=True, exist_ok=True)
        else:
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text("", encoding="utf-8")
    binding = inputs / BINDING
    (binding / "nested" / "deeper").mkdir(parents=True)
    fixture = {
        "surface.pl": ":- include('nested/new.pl').\n",
        "nested/new.pl": ":- include('deeper/leaf.pl').\n",
        "nested/deeper/leaf.pl": "new_runtime_dependency.\n",
    }
    for name, source in fixture.items():
        (binding / name).write_text(source, encoding="utf-8")
    (binding / "nested" / "debris.qlf").write_bytes(b"must not ship")
    command_globals = builder.run.__globals__
    command_globals["HERE"] = inputs
    # Replace directory ownership with a single named entry as the negative
    # control. It has the complete input tree, but cannot discover either include.
    enumerated = dict(resources)
    enumerated.pop(BINDING, None)
    enumerated[f"{BINDING}/surface.pl"] = f"{BINDING}/surface.pl"
    for name, roots in (("derived", resources), ("enumerated", enumerated)):
        command_globals["RUNTIME_RESOURCES"] = roots
        command = builder(Distribution({"packages": [], "py_modules": []}))
        command.ensure_finalized()
        command.build_lib = str(scratch / name)
        command.run()
        shipped = Path(command.build_lib) / "metta" / "_runtime" / BINDING
        if name == "derived":
            for relative, source in fixture.items():
                assert (shipped / relative).read_text(encoding="utf-8") == source
            assert not (shipped / "nested" / "debris.qlf").exists()
        else:
            assert (shipped / "surface.pl").is_file()
            assert not (shipped / "nested" / "new.pl").exists()
    print("runtime closure: both nested includes shipped; enumeration control omitted them")


def check_broken_wheel(wheel: Path, scratch: Path) -> None:
    """Exercise actual wheel files through the CLI and the embedding query."""
    extracted = scratch / "wheel"
    with zipfile.ZipFile(wheel) as archive:
        archive.extractall(extracted)
    runtime = extracted / "metta" / "_runtime"
    program = scratch / "program.metta"
    program.write_text("!(+ 1 1)\n", encoding="utf-8")
    cli = ["swipl", "-q", "-f", "none", "--no-packs", "-s",
           str(runtime / "engine" / "main.pl"), "--", str(program), "extensions"]
    # Import the binding from the extracted wheel with the selected test
    # interpreter's Janus dependency, independently of checkout path discovery.
    environment = dict(os.environ, PYTHONPATH=str(extracted), METTA_PATH=str(runtime))
    embedded = [sys.executable, "-c", "import metta; metta.space()"]
    for door, argv in (("standalone", cli), ("embedded", embedded)):
        completed = subprocess.run(bounded(argv), cwd=scratch, env=environment,
                                   capture_output=True, text=True, check=False)
        assert completed.returncode == 0, (door, completed.stdout, completed.stderr)
        # stderr was already in hand here and only ever reached the FAILURE
        # message, so a door that booted with a broken load reported success:
        # SWI prints a failed use_module directive there and carries on, which
        # is how 0.9.0's shim.pl emitted four ERROR lines at first boot while
        # every value assertion passed. Measured 2026-09-22 against the built
        # 0.9.0 wheel: both doors write 0 bytes, and the standalone one writes
        # its whole transpiler trace to STDOUT, so this costs no allowlist.
        assert not completed.stderr, (
            f"the {door} door wrote {len(completed.stderr)} bytes to stderr, "
            f"which a sound runtime does not: {completed.stderr[:400]}")
    assert (runtime / "engine" / "metta.qlf").is_file(), "the negative test must replay QLF"

    for relative, replacement in (
        ("surface.pl", None),
        ("provides_engine_user.pl", None),
        ("surface.pl", "\n:- fail.\n"),
    ):
        target = runtime / BINDING / relative
        original = target.read_bytes()
        if replacement is None:
            target.unlink()
        else:
            target.write_bytes(original + replacement.encode())
        try:
            for door, argv in (("standalone", cli), ("embedded", embedded)):
                completed = subprocess.run(bounded(argv), cwd=scratch, env=environment,
                                           capture_output=True, text=True, check=False)
                output = completed.stdout + completed.stderr
                assert 0 < completed.returncode < 125, (door, completed.returncode, output)
                assert relative in output, (door, relative, output)
                assert "the Prolog source did not load cleanly" in output, (door, output)
                assert "fatal signal" not in output and "Segmentation fault" not in output
                print(f"broken wheel: {door}, {relative}, "
                      f"{'missing' if replacement is None else 'failed directive'}: "
                      f"exit {completed.returncode}, named refusal")
        finally:
            target.write_bytes(original)


def main() -> None:
    """Run the derivation control and both damaged-wheel boot doors."""
    with tempfile.TemporaryDirectory(prefix="packaged-runtime-") as directory:
        scratch = Path(directory)
        check_directory_closure(scratch)
        check_broken_wheel(Path(sys.argv[1]).resolve(), scratch)


if __name__ == "__main__":
    main()
