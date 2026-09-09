"""Purpose: retain the website reference command through its single generator.

Guarantees: this command uses the same discovery, renderer and drift check as
extensions/python/tools/reference.py [tested:
test_the_legacy_reference_generator_tracks_the_narrow_public_modules; commit=cd62330ceacc8f1254eed9791c3f6203b48a1c9e].
"""

from __future__ import annotations

import runpy
import sys
from pathlib import Path


def main() -> int:
    """Regenerate the source reference through the authoritative entry point."""
    path = Path(__file__).resolve().parents[2] / "extensions/python/tools/reference.py"
    tool = runpy.run_path(str(path))
    return tool["main"](["--write"])


if __name__ == "__main__":
    sys.exit(main())
