"""Purpose: give a harness script's own children the repository's bound.

`check.sh` starts each of these scripts through `bounded`, so the script itself
carries a deadline and a link to the gate that started it, and a GNU `timeout`
signals the whole process GROUP, which reaches what the script spawns. Two
things fall outside that.

A script run BY HAND has no lane above it, which is how a
`swipl -g "..., run_tests" -t halt <suite>` ran 7,540 seconds at 97.8% CPU on
2026-09-05. And `tests/conformance/petta.py` and `petta_capture.py` start their
engines with `start_new_session=True` so their own timeout handler can
`killpg` them, which puts those engines in a session of their own where NO
group signal from above can reach them; the only bound left on one is a
`subprocess.TimeoutExpired` handler in the parent, which is the mechanism that
already cost this repository 122 CPU-hours when the parent was killed.

Assumes:
  - bounded.sh at the repository root, two directories above this file.
Guarantees:
  - the wrapped argv starts a process that cannot outlive either its deadline
    or the process that started it, and that reports the command's own exit
    status [tested: tests/shell/test_bounded_reaping.sh]
  - `--owner` is this process's pid, read here rather than by the wrapper, so
    a caller that died before the wrapper's first line is detected rather than
    guessed at [tested: tests/shell/test_bounded_reaping.sh; commit=b96e1a15260b7538a8e42be613bcc5dd0dddd136]
Fails when: bounded.sh is not in the tree. It refuses rather than returning the
  command unwrapped, because a bound that silently became absent is the failure
  this file exists to prevent.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import os
from pathlib import Path

import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))

from gate_layout import BOUNDED as _BOUNDED  # noqa: E402  -- installed above

#: The repository's one bound. Every runner in this tree reaches the same file.
BOUNDED = Path(__file__).resolve().parents[2] / _BOUNDED

#: How far ABOVE a caller's own `timeout=` the child's ceiling sits. The
#: caller must still be the one that gives up first, so its
#: `subprocess.TimeoutExpired` keeps firing exactly where it did and keeps
#: deciding the outcome; the child's ceiling is not a second opinion about
#: how long the command may take, it is what remains when nobody is waiting.
CHILD_GRACE = 60


def bounded(command: list[str], ceiling: float | None = None,
            grace: float | None = None) -> list[str]:
    """The same command, bounded by a process that shares its fate.

    The ceiling defaults to bounded.sh's own hour, which is an orphan reaper
    rather than a statement about how long this command should take: a caller's
    own `timeout=` stays the thing that fires first and stays what decides the
    outcome. Pass one only where the caller has no `timeout=` of its own or
    where the child should die sooner than the caller would notice.
    """
    if not BOUNDED.is_file():
        refusal = (
            f"this script bounds the processes it starts through {BOUNDED}, "
            "and that file is not there. Without it a killed run leaves them "
            "with no bound at all, which has already cost 122 CPU-hours. "
            "Restore it rather than removing this call."
        )
        raise RuntimeError(refusal)
    options: list[str] = ["--owner", str(os.getpid())]
    if ceiling is not None:
        options += ["--ceiling", str(int(ceiling))]
    if grace is not None:
        options += ["--grace", str(int(grace))]
    return ["sh", str(BOUNDED), *options, *command]
