"""Purpose: falsify native face generation through source and execution fixtures.

Guarantees: private support and vendor sources do not become public faces
[tested: tests/checks/check_prologface_selftest.py; commit=7dcfe83fcf74742a1e944db240aa918596c8d4b0].

Owns resources: every mutable fixture lives in a temporary directory under
ai-tmp, removed by unittest cleanup; native readers use the bounded runner.
"""

from __future__ import annotations

import copy
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "extensions/python/tools"))
sys.path.insert(0, str(ROOT / "extensions/python"))

import prologface as model  # noqa: E402 -- checkout tool under test

FIXTURE = ROOT / "tests/data/prologface/lib_face_fixture.pl"


class PrologFaceTests(unittest.TestCase):
    """Check the source-derived interface and independent drift failures."""

    @classmethod
    def setUpClass(cls) -> None:
        """Read the unchanged positive fixture once."""
        cls.record = model.source_records([FIXTURE])[0]

    def setUp(self) -> None:
        """Give each mutation its own source and adjacent face."""
        scratch = tempfile.TemporaryDirectory(prefix="ai-prologface-", dir=ROOT / "ai-tmp")
        self.addCleanup(scratch.cleanup)
        self.root = Path(scratch.name)
        self.source = self.root / FIXTURE.name
        self.source.write_text(FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
        self.face = self.source.with_suffix(".metta")

    def render_fixture(self) -> str:
        """Generate the actual fixture through its declared artifact owner."""
        rows = model.interface(self.record, FIXTURE)
        return model.generated_body(rows, FIXTURE, "fixture notice")

    def test_typed_overloads_and_nondeterministic_results(self) -> None:
        """Exported modes give each arity its type, with no collector wrapper."""
        rows = model.interface(self.record, FIXTURE)
        self.assertEqual(len(rows), 5)
        text = self.render_fixture()
        self.assertIn("(: face-add (-> Number Number Number))", text)
        self.assertIn("(: face-zero (-> Number))", text)
        self.assertIn("(: face-choice (-> Expression %Undefined%))", text)
        self.assertIn("(: face-count (-> Expression Number Number))", text)
        self.assertIn('(@param "Items")', text)
        self.assertIn('(@param "Extra")', text)
        self.assertIn("retaining duplicate answers", text)
        self.assertNotIn("host_service", text)
        self.assertNotIn("collapse", text)

    def test_source_initializers_never_run(self) -> None:
        """A throwing initializer is source data to the metadata reader."""
        with self.source.open("a", encoding="utf-8") as stream:
            stream.write("\n:- initialization(throw(face_generator_executed_source)).\n")
        record = model.source_records([self.source])[0]
        self.assertEqual(len(model.interface(record, self.source)), 5)

    def test_source_syntax_errors_refuse(self) -> None:
        """A reported Prolog read error cannot become successful metadata."""
        with self.source.open("a", encoding="utf-8") as stream:
            stream.write("\nmalformed(.\n")
        with self.assertRaisesRegex(ValueError, "source reader exited"):
            model.source_records([self.source])

    def test_export_doc_type_and_output_defects_refuse(self) -> None:
        """Each missing declaration axis has an independent refusal."""
        cases = (
            ("description", lambda row: row.update(doc=""), "PlDoc description"),
            ("mode", lambda row: row.update(modes=[]), "forward mode"),
            ("type", lambda row: row["modes"][0]["args"][0].update(explicit=False), "explicit type"),
            ("result", lambda row: row["modes"][0]["args"][-1].update(mode="+"), "one output"),
            ("extra output", lambda row: row["modes"][0]["args"][0].update(mode="-"), "one output"),
            ("unknown type", lambda row: row["modes"][0]["args"][0].update(type="invented"), "unsupported PlDoc type"),
        )
        for label, change, message in cases:
            with self.subTest(label=label):
                record = copy.deepcopy(self.record)
                change(next(row for row in record["exports"] if row["name"] == "face-add"))
                with self.assertRaisesRegex(ValueError, message):
                    model.interface(record, FIXTURE)

    def test_new_export_without_a_mode_refuses(self) -> None:
        """The export list is authoritative when a new predicate is added."""
        text = self.source.read_text(encoding="utf-8").replace("host_service/0]", "host_service/0, undocumented/1]")
        self.source.write_text(text + "\nundocumented(1).\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "undocumented/1"):
            model.interface(model.source_records([self.source])[0], self.source)

    def test_module_name_mismatch_refuses(self) -> None:
        """A face cannot silently claim another module's exports."""
        record = dict(self.record, module="different")
        with self.assertRaisesRegex(ValueError, "module must be named"):
            model.interface(record, FIXTURE)

    def test_handwritten_bytes_survive(self) -> None:
        """Only the generated region changes, including a final authored newline."""
        original = "; before\n" + model.BEGIN + "\nold\n" + model.END + "\n(= (kept $x) $x)\n"
        wanted = model.project(original, self.render_fixture())
        self.assertTrue(wanted.startswith("; before\n"))
        self.assertTrue(wanted.endswith("\n(= (kept $x) $x)\n"))
        self.assertEqual(model.project(wanted, self.render_fixture()), wanted)
        for text in (model.BEGIN, model.END, model.END + model.BEGIN,
                     model.BEGIN + model.END + model.BEGIN):
            with self.subTest(text=text), self.assertRaises(ValueError):
                model.project(text, "body")

    def test_deleted_face_and_marker_remain_detectable(self) -> None:
        """Native modes discover a face even after its output markers disappear."""
        with patch.object(model, "SOURCE_ROOTS", ((self.root, "*.pl"),)), patch.object(model, "notice", return_value="fixture notice"):
            self.assertEqual(model.review(rewrite=True), ([], 1, 0))
            for transform in (lambda _: "", lambda text: text.replace(model.BEGIN, ""),
                              lambda text: text.replace("Number Number Number", "String String String")):
                self.face.write_text(model.project("", self.render_fixture()), encoding="utf-8")
                self.face.write_text(transform(self.face.read_text(encoding="utf-8")), encoding="utf-8")
                self.assertTrue(model.review()[0])
            self.face.unlink()
            self.assertTrue(model.review()[0])

    def test_failed_validation_writes_nothing(self) -> None:
        """A bad second source cannot leave a regenerated first source behind."""
        bad = self.root / "lib_bad.pl"
        bad.write_text(":- module(lib_bad, [bad/1]).\nbad(1).\n", encoding="utf-8")
        with patch.object(model, "notice", return_value="fixture notice"):
            problems, _, _ = model.review([self.source, bad], rewrite=True)
        self.assertTrue(problems)
        self.assertFalse(self.face.exists())

    def test_discovery_excludes_private_support_and_vendor_sources(self) -> None:
        """Only the declared library layout supplies public backing modules."""
        library = self.root / "lib_fixture"
        library.mkdir()
        source = library / FIXTURE.name
        source.write_text(FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
        for name in ("support", "vendor"):
            private = library / name
            private.mkdir()
            (private / "broken.pl").write_text("must_not_be_read(.\n", encoding="utf-8")
        with patch.object(model, "SOURCE_ROOTS", ((self.root, "*/*.pl"),)), patch.object(model, "notice", return_value="fixture notice"):
            self.assertEqual(model.review(rewrite=True), ([], 1, 0))
            self.assertEqual(model.review(), ([], 1, 0))

    def test_relative_source_paths_use_the_same_projection(self) -> None:
        """A command-line path relative to this checkout is a valid source."""
        with patch.object(model, "notice", return_value="fixture notice"):
            relative = Path(os.path.relpath(self.source))
            self.assertEqual(model.review([relative], rewrite=True), ([], 1, 0))
            self.assertEqual(model.review([self.source]), ([], 1, 0))

    def test_changed_output_and_replacement_failure_preserve_contents(self) -> None:
        """Concurrent edits and failed replacement never truncate the old face."""
        self.face.write_text("edited", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "changed during generation"):
            model.write_projection(self.face, "old", "new")
        # `os` directly, not through prologface: the module writes with
        # pathlib's Path.replace and never names os itself, so reaching the
        # global through it was an alias that kept an import ruff reports as
        # unused. pathlib calls os.replace, so patching it here is the same
        # interception with nothing in between.
        with patch.object(os, "replace", side_effect=OSError("replacement refused")), self.assertRaises(OSError):
            model.write_projection(self.face, "edited", "new")
        self.assertEqual(self.face.read_text(encoding="utf-8"), "edited")
        self.assertEqual(list(self.root.glob(".prologface-*")), [])

    def test_generated_face_executes_every_native_arity(self) -> None:
        """The engine executes generated imports, typed calls and answer bags."""
        from metta import MeTTa

        with MeTTa() as engine:
            engine.load(FIXTURE.with_suffix(".metta"))
            self.assertEqual(engine.run("!(face-add 20 22)"), [[42]])
            self.assertEqual(engine.run("!(face-zero)"), [[0]])
            self.assertEqual(engine.run("!(face-count (a b c))"), [[3]])
            self.assertEqual(engine.run("!(face-count (a b c) 4)"), [[7]])
            self.assertEqual(engine.run("!(face-choice (1 1 2))"), [[1, 1, 2]])
            self.assertEqual(engine.run("!(face-choice ())"), [[]])
            self.assertEqual(engine.run("!(face-square 7)"), [[49]])


if __name__ == "__main__":
    unittest.main()
