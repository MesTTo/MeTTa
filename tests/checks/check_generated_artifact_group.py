"""Purpose: expose the artifact manifest's drift check to the repository gate.

Guarantees: every declared artifact participates in the dependency-ordered
checks and guide [tested: check_generated_artifact_group_selftest.py;
commit=cd62330ceacc8f1254eed9791c3f6203b48a1c9e].
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "extensions/python/tools"))

from artifacts import findings, main  # noqa: E402

__all__ = ["findings", "main"]


if __name__ == "__main__":
    raise SystemExit(main())
