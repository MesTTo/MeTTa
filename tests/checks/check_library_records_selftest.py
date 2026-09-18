"""Purpose: check the derived README counts against omissions and drift."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "extensions/python/tools"))

from example_origins import readme_counts  # noqa: E402 -- repository generator


class LibraryRecordTests(unittest.TestCase):
    """Exercise the prose projection without modifying the shipped README."""

    def test_changed_counts_preserve_the_authored_context(self) -> None:
        """Only the four stated counts change, and regeneration is stable."""
        text = (ROOT / "examples/README.md").read_text(encoding="utf-8")
        wanted = readme_counts(text, derived_count=17, total=30, credited=3, runnable=28)
        self.assertIn("The merged corpus contains 28 examples", wanted)
        self.assertIn("17 of the 30 programs here derive", wanted)
        self.assertIn("3 people wrote them", wanted)
        self.assertIn("The other\n13 examples were written", wanted)
        self.assertIn("## How the numbers work", wanted)
        self.assertEqual(readme_counts(wanted, derived_count=17, total=30, credited=3, runnable=28), wanted)

    def test_missing_or_repeated_count_anchors_refuse(self) -> None:
        """A prose edit cannot silently discard a count obligation."""
        text = (ROOT / "examples/README.md").read_text(encoding="utf-8")
        for planted in (text.replace("The merged corpus contains", "The corpus contains"), text + text):
            with self.subTest(planted=planted[:40]), self.assertRaisesRegex(ValueError, "missing or repeated"):
                readme_counts(planted, derived_count=17, total=30, credited=3, runnable=28)


if __name__ == "__main__":
    unittest.main()
