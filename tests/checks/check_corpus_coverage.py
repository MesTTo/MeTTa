"""Purpose: every engine callable and every carried library head is CALLED by an example.

`llms` already holds the other direction: every head the corpus calls has to
be named in llms.txt. Nothing held this one, and the gap was the larger of the
two. Of the 721 heads this lane knows, 245 engine callables and 641 distinct
heads the 38 shipped libraries carry across 659 rows, 287 were called by no
example: 61 of the engine's own, and 226 that only a library carries, spread
over 28 of the 38 libraries. A head nothing calls is a head no change to it
can break, which is the state `examples/` exists to make impossible.
[measured 2026-09-07: this file's own `source_text`, `is_called`,
`engine_corpus_vocabulary` and `carried_heads` over the corpus at 31d54e19,
extracted with `git archive 31d54e19 examples | tar -x -C <dir>`;
commit=WORKTREE]

The two sources are the ones the audit read, and neither is a list kept here:
the engine's own `fun/1` plus `translator:metta_translated_head/1`, and
`metta.library.rows(name).carried` over `metta.library.roster()`. A list
maintained beside the corpus would drift from the engine on the first
registration; asking the engine cannot.

CALL POSITION, not mention. `(name `, `(name)` and `(name` at a line end are
the three shapes, which is what a head being EXERCISED means: an example that
merely spells a name in a comment proves nothing about it. Full-line comments
are removed before the scan for that reason, and `_fixtures/` is excluded, the
same two rules `check_llms_names.corpus_head_uses` reads the corpus under.

THE ALLOWLIST IS EXACT, in both directions, which is what keeps it from
rotting into the place uncovered heads go to be forgotten:

  - a head it names that an example now CALLS is a finding, so a covered head
    cannot stay listed
  - a head it names that appears NOWHERE in the corpus is a finding, so the
    stated reason ("a Type, so it appears in declaration position") has to
    stay true; a head genuinely absent from the corpus is not allowlistable
  - a row naming something neither the engine nor a library carries is a
    finding, so a deleted head takes its row with it

Assumes:
  - swipl on PATH and a bootable engine; without the engine the callable set
    cannot be read and this reports that rather than passing
  - `metta.library` imports, which boots the engine once for the roster
Guarantees:
  - an engine callable or carried library head that no example calls is
    reported with the library that carries it
    [tested: tests/checks/check_corpus_coverage_selftest.py; commit=WORKTREE]
  - an allowlisted head an example calls, an allowlisted head the corpus never
    mentions, and an allowlist row for a head nothing carries are each
    reported independently
    [tested: tests/checks/check_corpus_coverage_selftest.py; commit=WORKTREE]
  - the four uncovered names it passes today are the three Types and the one
    nullary constructor, each of which appears in the corpus in declaration or
    argument position [tested: corpus-coverage; commit=WORKTREE]
Fails when: run on a tree whose engine does not boot. That is reported as a
  finding rather than as a skip, because a lane that cannot read its source
  and says nothing is the fail-open shape a gate exists to refuse.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import re
import sys
from collections.abc import Iterable, Mapping
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(ROOT / "extensions" / "python"))

from check_llms_names import (  # noqa: E402  -- the path inserts above are what make these resolve
    EngineUnavailableError,
    engine_corpus_vocabulary,
)

#: One row per head the corpus cannot call, `name`, a tab, and the reason.
ALLOWLIST = ROOT / "tests" / "data" / "corpus_coverage_allowlist.txt"

#: A token that could be a MeTTa head. Deliberately wider than
#: `check_llms_names._CALL_HEAD`, which requires a leading letter and so cannot
#: see `#//`, `~>`, `/?\` or lib_mm2's full-width operators; every one of those
#: is a head this lane has to be able to find.
_MENTION = re.compile(r"[^\s()]+")


def source_text(corpus_root: Path) -> str:
    """Every example's code, comments and fixtures removed.

    Full-line comments go because a name spelled in prose is not exercised by
    it, and `_fixtures/` goes because a fixture is an input rather than a
    program: one of them is a permanent negative control that must never run.
    """
    bodies: list[str] = []
    for path in sorted(corpus_root.rglob("*.metta")):
        if path.is_symlink() or "_fixtures" in path.parts:
            continue
        bodies.append(
            "\n".join(
                line
                for line in path.read_text(encoding="utf-8").splitlines()
                if not line.lstrip().startswith(";")
            )
        )
    return "\n".join(bodies)


def is_called(name: str, text: str) -> bool:
    """Whether the corpus applies this head to something, or to nothing."""
    return f"({name} " in text or f"({name})" in text or f"({name}\n" in text


def mentions(text: str) -> set[str]:
    """Every token the corpus's code holds, in any position."""
    return set(_MENTION.findall(text))


def allowlist(path: Path = ALLOWLIST) -> dict[str, str]:
    """Each head the corpus cannot call, and the reason it cannot."""
    rows: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        name, _, reason = line.partition("\t")
        rows[name.strip()] = reason.strip()
    return rows


def carried_heads() -> dict[str, set[str]]:
    """Every head a shipped library carries, and which libraries carry it."""
    from metta.library import roster, rows  # noqa: I001  -- the import is local because it BOOTS an engine, so it happens once and only when the lane runs

    carried: dict[str, set[str]] = {}
    for library in roster():
        for row in rows(library):
            if row.carried:
                carried.setdefault(row.name, set()).add(library)
    return carried


def findings(
    *,
    engine: Iterable[str],
    carried: Mapping[str, set[str]],
    text: str,
    allowed: Mapping[str, str],
) -> list[str]:
    """Every head the corpus fails to call, and every stale allowlist row."""
    out: list[str] = []
    spelled = mentions(text)
    known = set(engine) | set(carried)

    for name in sorted(known):
        if is_called(name, text):
            if name in allowed:
                out.append(
                    f"`{name}` is allowlisted as \"{allowed[name]}\", and an "
                    f"example now calls it; remove its row from "
                    f"{ALLOWLIST.relative_to(ROOT)}"
                )
            continue
        if name in allowed:
            if name not in spelled:
                out.append(
                    f"`{name}` is allowlisted as \"{allowed[name]}\", and no "
                    f"example mentions it at all; a head the corpus never "
                    f"writes is not allowlistable"
                )
            continue
        where = (
            f"carried by {', '.join(sorted(carried[name]))}"
            if name in carried
            else "an engine callable"
        )
        out.append(
            f"`{name}` ({where}) is called by no example; write one, or add a "
            f"row to {ALLOWLIST.relative_to(ROOT)} saying why it cannot be "
            f"called"
        )

    for name, reason in sorted(allowed.items()):
        if name not in known:
            out.append(
                f"`{name}` is allowlisted as \"{reason}\", and neither the "
                f"engine nor any library carries it; remove the row"
            )
    return out


def main(argv: list[str] | None = None) -> int:
    """Report every uncalled head and every stale allowlist row."""
    del argv
    try:
        engine = engine_corpus_vocabulary()
    except EngineUnavailableError:
        print("corpus-coverage: swipl is not installed, so the engine's "
              "callable set cannot be read")
        return 2
    except RuntimeError as broken:
        print(f"corpus-coverage: {broken}")
        return 2

    carried = carried_heads()
    text = source_text(ROOT / "examples")
    allowed = allowlist()
    problems = findings(engine=engine, carried=carried, text=text, allowed=allowed)
    for problem in problems:
        print(f"  {problem}")
    print(
        f"corpus-coverage: {len(engine)} engine callable(s), {len(carried)} "
        f"carried library head(s), {len(allowed)} allowlisted, "
        f"{len(problems)} finding(s)"
    )
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
