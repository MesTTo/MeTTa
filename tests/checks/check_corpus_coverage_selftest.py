"""Purpose: prove check_corpus_coverage.py reports each of the four ways it can be wrong.

Running the pass on THIS repository proves the corpus is covered. It says
nothing about whether the pass can SEE an uncovered head, which is the whole
of its job, and nothing about the three allowlist findings that keep the
exception list from rotting. All four are planted here.

The comment rule is the one worth planting hardest. `(register-token! "x" Y)`
written inside a comment used to count as a call, because the audit this lane
grew out of read the corpus's raw text; two heads passed that way and were
found the moment full-line comments were removed. A fixture example with the
head in a comment and nowhere else is a NEGATIVE here, so the decision to
strip comments cannot be quietly reversed.

Assumes: a writable ai-tmp/ in this repository. No engine, because every
  question here is asked of the pass's own readers over planted text.
Guarantees:
  - an uncovered engine callable and an uncovered carried library head are
    each reported, naming the library where there is one
    [tested: tests/checks/check_corpus_coverage_selftest.py; commit=WORKTREE]
  - an allowlisted head an example calls, an allowlisted head the corpus never
    mentions, and an allowlist row for a head nothing carries are each
    reported [tested: tests/checks/check_corpus_coverage_selftest.py; commit=WORKTREE]
  - a head called in any of the three positions is NOT reported, and a head
    that appears only inside a comment or only under `_fixtures/` IS
    [tested: tests/checks/check_corpus_coverage_selftest.py; commit=WORKTREE]
  - the shipped allowlist parses into the rows it states, each with a reason
    [tested: tests/checks/check_corpus_coverage_selftest.py; commit=WORKTREE]
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

from check_corpus_coverage import (  # noqa: E402  -- the path is installed above
    allowlist,
    findings,
    is_called,
    source_text,
)

#: An example that calls three heads in the three shapes the lane accepts, and
#: NAMES three more without calling them: one in a comment, one in argument
#: position, one only as a bare symbol.
EXAMPLE = """;a comment calling (commented-head 1), which is not a call
!(test (applied-head 1) 1)
!(test (collapse (nullary-head)) ())
!(test (line-end-head
          1)
       1)
!(test (get-type bare-head) Type)
!(test (typed-head-argument (: x argument-head)) x)
"""

#: A fixture that must not be read at all: `_fixtures/` holds inputs, one of
#: which is a permanent negative control the runners never execute.
FIXTURE = "!(test (fixture-only-head 1) 1)\n"


def planted(problems: list[str]) -> None:
    """Every finding the pass owes, over one fixture corpus."""
    scratch = ROOT / "ai-tmp"
    scratch.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(
        prefix="corpus-coverage-selftest-", dir=scratch
    ) as name:
        corpus = Path(name)
        (corpus / "ch01").mkdir()
        (corpus / "ch01" / "01-example.metta").write_text(EXAMPLE, encoding="utf-8")
        (corpus / "ch01" / "_fixtures").mkdir()
        (corpus / "ch01" / "_fixtures" / "input.metta").write_text(
            FIXTURE, encoding="utf-8"
        )
        allowed = corpus / "allowlist.txt"
        allowed.write_text(
            "# a header line the reader skips\n"
            "\n"
            "bare-head\ta Type, so it is never applied\n"
            "applied-head\tclaimed uncallable, and the example calls it\n"
            "absent-head\tclaimed uncallable, and no example writes it at all\n"
            "unknown-head\tneither the engine nor a library carries this\n",
            encoding="utf-8",
        )

        text = source_text(corpus)
        rows = allowlist(allowed)

        problems.extend(
            f"a call to `{head}` was not seen as one"
            for head in ("applied-head", "nullary-head", "line-end-head")
            if not is_called(head, text)
        )
        problems.extend(
            f"`{head}` was read as a call and is not one"
            for head in ("commented-head", "bare-head", "fixture-only-head")
            if is_called(head, text)
        )

        reported = findings(
            engine={"applied-head", "uncovered-engine-head", "absent-head"},
            carried={
                "nullary-head": {"lib_demo"},
                "line-end-head": {"lib_demo"},
                "bare-head": {"lib_demo"},
                "uncovered-library-head": {"lib_demo", "lib_other"},
                "commented-head": {"lib_demo"},
                "fixture-only-head": {"lib_demo"},
            },
            text=text,
            allowed=rows,
        )
        joined = "\n".join(reported)

        owed = {
            "an uncovered engine callable": "`uncovered-engine-head` (an engine callable) is called by no example",
            "an uncovered library head with its libraries": "`uncovered-library-head` (carried by lib_demo, lib_other) is called by no example",
            "a head called only inside a comment": "`commented-head` (carried by lib_demo) is called by no example",
            "a head called only under _fixtures/": "`fixture-only-head` (carried by lib_demo) is called by no example",
            "an allowlisted head an example calls": "`applied-head` is allowlisted",
            "an allowlisted head no example mentions": "`absent-head` is allowlisted",
            "an allowlist row for a head nothing carries": "`unknown-head` is allowlisted",
        }
        for what, fragment in owed.items():
            if fragment not in joined:
                problems.append(f"{what} was not reported: {reported}")

        spared = ("`nullary-head`", "`line-end-head`", "`bare-head`")
        problems.extend(
            f"{fragment} was reported; it is either called or allowlisted "
            f"and mentioned"
            for fragment in spared
            if fragment in joined
        )


def shipped(problems: list[str]) -> None:
    """The allowlist this repository ships reads back as rows with reasons."""
    rows = allowlist()
    if not rows:
        problems.append("the shipped allowlist parsed to nothing")
    for name, reason in rows.items():
        if not reason:
            problems.append(f"the allowlist row for `{name}` carries no reason")
        if "\t" in name or not name:
            problems.append(f"the allowlist row {name!r} did not split on its tab")


def main() -> int:
    """Plant each shape and hold the pass to what it reports."""
    problems: list[str] = []
    planted(problems)
    shipped(problems)
    for problem in problems:
        print(f"  {problem}")
    print(f"corpus-coverage-selftest: {len(problems)} finding(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
