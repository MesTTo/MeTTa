"""Purpose: prove check_spread_calls.py finds a per-reference call and spares the rest.

Running the pass on this repository proves the analyser is clean today. It says
nothing about whether the pass can find the defect at all, which is its whole
job, and nothing about the three shapes it must NOT flag. All four are planted
here in a fixture module the test writes and throws away.

The exemption case is the load-bearing one. One site in the analyser genuinely
cannot be batched, because a forwarding body resolves its own intrinsic and its
own argument permutation per reference, so a pass with no way to say that would
be turned off within a day. It is planted as a positive and as a negative: the
marker WITH a reason passes, the marker with no reason does not, so the escape
hatch cannot become a silent one.

Assumes: a writable ai-tmp/ in this repository.
Guarantees:
  - a `Values` method called with a one-element set inside a loop is reported with
    its line [tested: this file; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f]
  - the same call outside a loop is NOT reported, because one reference is then
    all there is [tested: this file; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f]
  - a method whose first parameter is not annotated `Values` is NOT reported, which
    is what derives the method set from the source instead of a list
    [tested: this file; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f]
  - `# per-reference:` with a reason spares the site and the bare marker does not
    [tested: this file; commit=561cfeaa23b27fc84f86a9bcccf6ccf8b9d2e73f]
Fails when: run against a tree it did not write. It asserts on its own fixture.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))

from check_spread_calls import findings  # noqa: E402  -- the path is installed above

FIXTURE = '''
class CallGraph:
    def _protocol(self, values: Values, name: str, node: object) -> Values:
        return values

    def _plain(self, values: object, name: str) -> object:
        return values

    def caught(self, references):
        result = set()
        for reference in references:
            result.update(self._protocol(frozenset({reference}), "__call__", None))
        return result

    def spared_outside_a_loop(self, reference):
        return self._protocol(frozenset({reference}), "__call__", None)

    def spared_unannotated(self, references):
        for reference in references:
            self._plain(frozenset({reference}), "__call__")

    def spared_by_marker(self, references):
        for reference in references:
            # per-reference: each one resolves its own intrinsic, so there is no set to call once with
            self._protocol(frozenset({reference}), "__call__", None)

    def caught_by_a_bare_marker(self, references):
        for reference in references:
            # per-reference:
            self._protocol(frozenset({reference}), "__call__", None)
'''


def main() -> int:
    """Plant every shape the pass must separate, and check it separates them."""
    scratch = ROOT / "ai-tmp"
    scratch.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=scratch) as directory:
        planted = Path(directory) / "fixture.py"
        planted.write_text(FIXTURE, encoding="utf-8")
        numbered = list(enumerate(FIXTURE.splitlines(), 1))
        spreading = [f"{number}" for number, text in numbered if "self._protocol(frozenset" in text]
        unannotated = [f"{number}" for number, text in numbered if "self._plain(frozenset" in text]
        reported = {finding.split(":")[1] for finding in findings(planted)}
    inside_loop, outside, marked, bare = spreading
    assert inside_loop in reported, f"the per-reference call was not found: {reported}"
    assert outside not in reported, f"a call outside a loop was reported: {reported}"
    assert marked not in reported, f"an explained exemption was reported: {reported}"
    assert bare in reported, f"a bare exemption marker was accepted: {reported}"
    assert not set(unannotated) & reported, f"an unannotated method was reported: {reported}"
    assert reported == {inside_loop, bare}, f"unexpected findings: {reported}"
    print("spread-calls selftest: the per-reference call and the bare marker are found, "
          "the call outside a loop, the unannotated method and the explained exemption are not")
    return 0


if __name__ == "__main__":
    sys.exit(main())
