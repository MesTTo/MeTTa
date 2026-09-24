"""Purpose: run the upstream Jupyter kernel, trueagi-io/jupyter-petta-kernel,
and say exactly what it needs, what it gets here, and what this package gives
it back.

`metta/ipython.py` has said since it was written that the full-notebook
experience is that kernel and that this package composes with it. Nothing had
ever started it. What that claim rests on is four separate questions, and this
answers each with a run rather than with a reading.

  WHAT THE KERNEL NEEDS. Measured, not assumed: it does NOT use the `metta`
  console script, and the `metta` console script is not what it rides on.
  `petta_jupyter/kernel.py` puts `$PETTA_PATH/python` on `sys.path` and does
  `from petta import PeTTa`, then calls `PeTTa(verbose=False)` and
  `load_metta_file(path)` per cell; upstream's `PeTTa.__init__` consults
  `$PETTA_PATH/src/main.pl` and `$PETTA_PATH/python/helper.pl` through janus.
  So it needs a TREE in upstream's layout with a module named `petta` in it.

  AGAINST THIS FORK'S OWN TREE. This fork has every one of those things under
  different names -- `extensions/python/metta`, `engine/main.pl`,
  `metta/_binding/shim.pl` -- and upstream compatibility was withdrawn on 2026-08-27,
  so it ships no `petta`. The kernel therefore cannot start here, and this
  runs it to record the refusal it actually gives rather than the one it
  probably gives.

  AGAINST UPSTREAM AT THE PARITY PIN. The kernel's own configuration, so this
  is the run that says whether the kernel works at all: a notebook, one MeTTa
  cell, executed under its kernelspec through nbclient, answer asserted.

  AGAINST THIS ENGINE, THROUGH THE NAMES IT ASKS FOR. The gap is a NAME gap
  rather than a semantic one, and the fifteen lines of ADAPTER below are the
  measurement of how wide it is: `PeTTa.load_metta_file` is `Space.load`, and
  with nothing else bridged the upstream kernel evaluates MeTTa on this
  engine and answers correctly. The adapter is a fixture of this lane and is
  not shipped; shipping it would be the `petta` module the ruling removed.

And the launcher contract that row of the journal named, which is real and is
this fork's: `metta/cli.py` resolves an upstream `src/main.pl` tree as well as
this one, so `METTA_PATH=<upstream> metta program.metta` runs upstream's
engine through this fork's command. That is checked here with no network at
all, beside the kernel runs it was thought to underwrite.

What this package gives the kernel back is the lexer: the kernel's
`language_info` says `mimetype: text/x-metta` and falls back to Scheme for
colour, and `metta._pygments` is registered for that MIME type, so an
installed pymetta colours a MeTTa cell in every front end that asks Pygments.

Assumes:
  - nbclient, nbformat, ipykernel and janus_swi are importable, pip can reach
    github.com, and the configured upstream checkout the parity lanes require
    exists; each missing piece is named and skipped, and under
    CI the workflow provides them and this refuses instead
Guarantees:
  - the upstream checkout is check_upstream_parity.py's UPSTREAM, so both
    lanes read the one METTA_UPSTREAM names or, when it is unset, the one found
    beside the tree or beside the repository's main checkout [tested:
    check_upstream_parity_selftest.upstream_selection_failures; commit=2b1d45b347027f0290a86315ccc770f3dac08851]
  - the kernel is installed at a pinned commit and started, rather than read
    [tested: tests/checks/check_jupyter_kernel.py; commit=7ba114f280ec3b132658cacb562064d0bac23f41]
  - the fork's launcher runs an upstream `src/main.pl` tree, which is the
    contract cli.py keeps for this [tested: tests/checks/check_jupyter_kernel.py;
    commit=7ba114f280ec3b132658cacb562064d0bac23f41]
Fails when: asked to judge a machine with no network. It says so and passes,
  because a developer offline has not broken anything; the workflow's kernel
  job sets CI and it refuses there.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""  # noqa: D205  -- the contract is one continuous invariant, not summary-and-body prose

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import check_upstream_parity as parity  # the lane beside this file

ROOT = Path(__file__).resolve().parents[2]
# One derivation of where upstream is, the parity lane's: a copy of its default
# here missed the checkout from every battery the way the lane itself did.
UPSTREAM = parity.UPSTREAM
PYDIR = ROOT / "extensions" / "python"

#: The kernel, at the commit this was measured against. A moving branch would
#: make a red lane here mean either a change upstream or a change in this tree,
#: which is two questions and one answer.
KERNEL_REMOTE = "https://github.com/trueagi-io/jupyter-petta-kernel"
KERNEL_COMMIT = "b33e45eaee53975d81e8cee44641447ccd3f06ec"

#: `PeTTa.load_metta_file` is `Space.load`, and that is the whole bridge. Held
#: here rather than in the package: this fork ships no `petta`, and this is a
#: measurement of the distance to one, not a step towards shipping it.
ADAPTER = '''"""The two calls trueagi-io/jupyter-petta-kernel makes, over this fork.

Written by tests/checks/check_jupyter_kernel.py into a scratch tree and never
installed. `PeTTa(verbose=False)` and `load_metta_file(path)` are the whole of
what petta_jupyter/kernel.py asks its host for; `Space.load` is a consult of a
file into a space, which is what upstream's `load_metta_file` is, and the flat
list of strings is what `petta_jupyter/output_formatter.py` formats.
"""

from metta import MeTTa


class PeTTa:
    def __init__(self, verbose=False, petta_path=None):
        self._space = MeTTa()

    def load_metta_file(self, path):
        return [str(atom) for group in self._space.load(path) for atom in group]
'''

CELL = "!(+ 1 2)\n"
ANSWER = "3"


def note(missing: str, remedy: str) -> int:
    """Print a skip, or refuse where the lane is load-bearing.

    125 rather than 0, because both call sites are `return note(...)` from
    `main` and so end the lane without starting a kernel. That is the gate's
    own word for a run that says nothing about the tree: check.sh's `run()`
    reports it as `skipped` and names the lane under MEASURED NOTHING, where 0
    reported `ok` for a lane that launched nothing.

    The per-part "skipped: no upstream checkout" message below is a different
    thing and does not reach here: the lane carries on and tests the kernel
    against this fork's own tree, so it has measured something and says `ok`.
    """
    if os.environ.get("CI") == "true":
        print(f"error: {missing}; refusing to pass the kernel gate without it. {remedy}",
              file=sys.stderr)
        return 1
    print(f"note: {missing}; the kernel was not started. {remedy}")
    return 125


def importable(name: str) -> bool:
    """Whether one module imports in the interpreter this lane runs under."""
    done = subprocess.run(
        [sys.executable, "-c", f"import {name}"], capture_output=True, check=False,
    )
    return done.returncode == 0


def install(site: Path) -> str | None:
    """Put the pinned kernel under `site`, or answer why it could not."""
    done = subprocess.run(
        [
            sys.executable, "-m", "pip", "install", "--quiet", "--no-deps",
            "--target", str(site), f"git+{KERNEL_REMOTE}@{KERNEL_COMMIT}",
        ],
        capture_output=True, text=True, check=False,
    )
    if done.returncode != 0:
        return (done.stderr or done.stdout).strip().splitlines()[-1][:300]
    return None


def kernelspec(directory: Path) -> Path:
    """A kernelspec starting the upstream kernel on THIS interpreter.

    Upstream's own resources/kernel.json spells the command `python3`, which on
    a machine with more than one interpreter is not the one holding ipykernel
    and janus_swi. The module and its arguments are upstream's; only the
    interpreter is resolved, which is what `jupyter kernelspec install` into a
    virtual environment does for the same reason.

    No `env` block, deliberately: a kernelspec's own env is applied AFTER the
    caller's, so a PYTHONPATH here would have silently replaced the one each
    run below needs, and the adapter run answered `No module named 'metta'`
    while looking like a kernel that had simply died.
    """
    kernels = directory / "kernels" / "petta"
    kernels.mkdir(parents=True, exist_ok=True)
    (kernels / "kernel.json").write_text(
        json.dumps(
            {
                "argv": [sys.executable, "-m", "petta_jupyter", "-f", "{connection_file}"],
                "display_name": "PeTTa (MeTTa)",
                "language": "MeTTa",
            }
        ),
        encoding="utf-8",
    )
    return directory


def evaluate(jupyter: Path, environment: dict[str, str], cwd: Path) -> tuple[str, str]:
    """Run one MeTTa cell under the kernel; answer (stdout, stderr) of the cell."""
    # Imported here rather than at the top: this lane reports their absence
    # as a skip before it reaches this function.
    import nbclient
    import nbformat

    # In THIS process, not in the child: nbclient resolves the kernelspec here
    # and only then launches, so a JUPYTER_PATH passed to the child alone
    # answers `No such kernel named petta`.
    os.environ["JUPYTER_PATH"] = str(jupyter)
    notebook = nbformat.v4.new_notebook(cells=[nbformat.v4.new_code_cell(CELL)])
    client = nbclient.NotebookClient(
        notebook,
        timeout=180,
        kernel_name="petta",
        allow_errors=True,
        resources={"metadata": {"path": str(cwd)}},
    )
    client.execute(cwd=str(cwd), env={**os.environ, **environment})
    streams = {"stdout": [], "stderr": []}
    for output in notebook.cells[0].outputs:
        if output.get("output_type") == "stream":
            streams[output["name"]].append(output["text"])
        elif output.get("output_type") == "error":
            streams["stderr"].append("\n".join(output.get("traceback", [])))
    return "".join(streams["stdout"]).strip(), "".join(streams["stderr"]).strip()


def launcher_runs_an_upstream_tree() -> str | None:
    """The `metta` command against an upstream layout, or why it was not run."""
    if not (UPSTREAM / "src" / "main.pl").is_file():
        return f"skipped: no upstream checkout at {UPSTREAM.resolve()}"
    program = ROOT / "ai-tmp" / "kernel-launcher-probe.metta"
    program.parent.mkdir(exist_ok=True)
    program.write_text("!(+ 1 2)\n", encoding="utf-8")
    try:
        done = subprocess.run(
            [sys.executable, "-c",
             "import sys; from metta.cli import main; sys.exit(main(sys.argv[1:]))",
             str(program)],
            capture_output=True, text=True, check=False, cwd=str(ROOT),
            env={**os.environ, "METTA_PATH": str(UPSTREAM.resolve()),
                 "PYTHONPATH": os.pathsep.join([str(PYDIR), os.environ.get("PYTHONPATH", "")])},
        )
    finally:
        program.unlink(missing_ok=True)
    if done.returncode != 0 or ANSWER not in done.stdout:
        return (
            f"FAILED: exit {done.returncode}, stdout {done.stdout.strip()[:200]!r}, "
            f"stderr {done.stderr.strip()[:200]!r}"
        )
    return None


def main() -> int:
    """Start the kernel three ways and report what each one answered."""
    problems: list[str] = []

    print(f"== the launcher against an upstream tree at {UPSTREAM.resolve()}", flush=True)
    failure = launcher_runs_an_upstream_tree()
    if failure is None:
        print(f"   ok: METTA_PATH=<upstream> metta program.metta answered {ANSWER}", flush=True)
    elif failure.startswith("skipped"):
        print(f"   {failure}", flush=True)
    else:
        problems.append(f"the launcher no longer runs an upstream tree: {failure}")

    for module in ("nbclient", "nbformat", "ipykernel", "janus_swi"):
        if not importable(module):
            return note(f"{module} is not importable", "Install it beside this interpreter.")

    # Cleared, so a second run installs into an empty target rather than over
    # whatever the first left: `pip install --target` merges into what is there.
    scratch = ROOT / "ai-tmp" / "jupyter-kernel-lane"
    shutil.rmtree(scratch, ignore_errors=True)
    site = scratch / "site"
    site.mkdir(parents=True)
    print(f"== installing {KERNEL_REMOTE}@{KERNEL_COMMIT[:7]} into {site.relative_to(ROOT)}", flush=True)
    refused = install(site)
    if refused is not None:
        return note(f"the kernel would not install ({refused})",
                    f"It is fetched from {KERNEL_REMOTE}, so this needs the network.")

    jupyter = kernelspec(scratch / "jupyter")

    print("== the kernel against this fork's own tree", flush=True)
    started = subprocess.run(
        [sys.executable, "-c", "import petta_jupyter.kernel"],
        capture_output=True, text=True, check=False,
        env={**os.environ, "PYTHONPATH": str(site), "PETTA_PATH": str(ROOT)},
    )
    if started.returncode == 0:
        problems.append(
            "the kernel imported against this fork's tree, which means this "
            "tree now provides a `petta` module; the ruling of 2026-08-27 says "
            "it should not"
        )
    else:
        last = started.stderr.strip().splitlines()[-1][:200]
        print(f"   refuses, as recorded: {last}", flush=True)

    print("== the kernel against upstream PeTTa at the parity pin", flush=True)
    if (UPSTREAM / "src" / "main.pl").is_file():
        out, err = evaluate(
            jupyter,
            {"PETTA_PATH": str(UPSTREAM.resolve()), "PYTHONPATH": str(site)},
            scratch,
        )
        if out != ANSWER:
            problems.append(f"upstream's own configuration answered {out!r}, not {ANSWER!r}; {err[:300]}")
        else:
            print(f"   ok: one MeTTa cell answered {out}", flush=True)
    else:
        print(f"   skipped: no upstream checkout at {UPSTREAM.resolve()}", flush=True)

    print("== the kernel against THIS engine, through a fifteen-line adapter", flush=True)
    adapter = scratch / "adapter" / "python" / "petta"
    adapter.mkdir(parents=True, exist_ok=True)
    (adapter / "__init__.py").write_text(ADAPTER, encoding="utf-8")
    out, err = evaluate(
        jupyter,
        {
            "PETTA_PATH": str(scratch / "adapter"),
            "PYTHONPATH": os.pathsep.join([str(site), str(PYDIR)]),
            "METTA_PATH": str(ROOT),
        },
        scratch,
    )
    if out != ANSWER:
        problems.append(
            f"the upstream kernel over this engine answered {out!r}, not {ANSWER!r}; {err[:300]}"
        )
    else:
        print(f"   ok: one MeTTa cell answered {out} on this fork's engine", flush=True)

    for line in problems:
        print(f"PROBLEM: {line}")
    print(f"{len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
