"""Purpose: check this engine against upstream PeTTa, which is the arbiter.
    tests/conformance/petta/ holds upstream's example corpus and the exact
    stdout upstream printed for each file, captured by petta_capture.py from a
    named commit. This replays every entry through THIS engine and diffs, which
    is the difference between "PeTTa is the oracle" as a habit and as a check.

    Verify mode; petta_capture.py is record mode. The pin lives in this
    repository rather than in a sibling checkout, so CI gates on it and a
    neighbouring working tree cannot move a lane under it.

Assumes:
  - the pin was captured with the engines' shared `silent` flag, so the bytes
    compared are the program's own answers and not translator banners.
  - the corpus keeps upstream's examples/ + lib/ sibling layout, because its
    relative-path imports (`../lib/lib_he`) resolve against the importing
    file's directory while `(library X)` resolves against the engine's own
    (engine/metta.pl:373). Both halves are deliberate: a path import names the
    same bytes on both sides, a library import names each engine's own.
Guarantees:
  - SWI variable identifiers ($_12345) expose allocation history rather than
    meaning, so a mismatch is re-compared after first-occurrence alpha
    renaming and reported as renamed-only when that is all it was, the
    technique tests/upstream_bench.sh already uses.
  - that renaming is SYNTAX-AWARE and scoped to one printed term: a `$_7`
    inside a string literal is data and is left alone, and two independent
    answers that reuse an allocation slot are not one variable, while sharing
    inside one term still decides
    [tested: test_a_variable_identifier_inside_a_string_is_data,
    test_two_answers_reusing_a_slot_are_not_one_variable,
    test_sharing_inside_one_printed_term_still_decides; commit=819393cb9608052a198ef0b2a8c0676d9ef9e824]
  - a recorded skip whose capability has since arrived is reported on every
    run, so a stale exclusion is visible rather than believed
    [tested: test_a_skip_whose_capability_arrived_is_reported; commit=819393cb9608052a198ef0b2a8c0676d9ef9e824]
  - a file whose status is `diverges` carries the difference it is ALLOWED to
    have, so it cannot drift further without failing: a recorded divergence is
    a ruling, not an exemption.
  - a run that raises or times out is reported as such rather than counted as
    agreeing.
Fails when:
  - --gate is passed and any `conforms` entry differs, or any `diverges` entry
    stops differing in exactly the recorded way. Without --gate this is a
    REPORT surface: it prints and exits 0.
  - the pin is absent: that is a configuration error and says so, rather than
    passing an empty corpus quietly.
Decides:
  - the unit of promotion is the FILE, not a percentage and not an area. An
    entry gates as soon as it agrees, so the burn-down's finish line is real
    and per-file.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import argparse
import json
import os
import re
import signal
import subprocess
import sys
from collections.abc import Iterator
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

# The bound every runner in this tree reaches, one directory over.
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "checks"))
from bounded_spawn import CHILD_GRACE, bounded  # noqa: E402  -- the path is installed above

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
#The pin directory, overridable so the gate itself can be tested. A gate that
#cannot be pointed at a planted disagreement is a wall nobody has watched fail
#[tested: test_the_conformance_gate_tells_the_three_cases_apart].
PIN = Path(os.environ.get("PETTA_PIN", HERE / "petta"))
CORPUS = PIN / "examples"
EXPECTED = PIN / "expected"
MANIFEST = PIN / "MANIFEST.json"

ANSI = re.compile(r"\x1b\[[0-9;]*m")

#: The stable spelling the writer emits for a variable, and one of exactly two:
#: `$_<index>` from the numbervars path and `$<name>` from the named one, whose
#: name already carries its `#<epoch>` where one written name covers distinct
#: variables [source: engine/parser.pl:682-683, swrite_mode//2]. The stable one
#: is matched positively so it stops at its last DIGIT rather than at the next
#: token boundary: `should $_0.` then yields `$_0` and leaves the harness's own
#: full stop as text to compare.
STABLE_VARIABLE = re.compile(r"\$_\d+")
#: Where a MeTTa token ends, taken from the engine rather than restated: the
#: Unicode White_Space property plus `(`, `)` and `;`. The four ASCII
#: information separators look like whitespace to Python and are NOT boundaries
#: here, which is the reader's own pinned answer [source: engine/parser.pl:27-34,
#: metta_token_boundary/2; tests/prolog/suites/reader/parser.plt,
#: parser_unicode_layout].
INFORMATION_SEPARATORS = "\x1c\x1d\x1e\x1f"
#: `is <actual>, should <expected>. <mark>` is what the corpus is mostly made
#: of: 559 of the pin's 1,439 expected lines are one, every one of them carrying
#: this delimiter and one of these suffixes [measured 2026-09-05].
VERDICT_OPEN = "is "
VERDICT_DELIMITER = ", should "
VERDICT_SUFFIXES = (". ✅ ", ". ❌ ", ". ✅", ". ❌")


def _ends_token(character: str) -> bool:
    """Whether this character ends a MeTTa token."""
    if character in INFORMATION_SEPARATORS:
        return False
    return character.isspace() or character in "();"


def _variable_end(text: str, at: int) -> int:
    """Where the variable token opening at `at` ends, or `at` if none does."""
    stable = STABLE_VARIABLE.match(text, at)
    if stable is not None:
        return stable.end()
    end = at + 1
    while end < len(text) and not _ends_token(text[end]):
        end += 1
    return end if end > at + 1 else at


def _canonical_term(text: str) -> str:
    """One printed term, its variables renamed by first occurrence.

    First-occurrence numbering in a fixed traversal order is the canonical form
    for VARIANT equality of a first-order term, which is the relation this gate
    wants: two terms are variants when one bijective renaming of variables
    carries each to the other, and their numbered forms are then identical.
    SWI spells the same construction as copy_term/2 plus numbervars/3 and
    decides it with =@=/2 [source:
    https://www.swi-prolog.org/pldoc/man?predicate=%3D%40%3D%2F2]. What must
    survive is SHARING: `(pair $_0 $_0)` and `(pair $_0 $_1)` stay different.

    A STRING LITERAL is data and is copied through untouched. The regex this
    replaced renamed inside one, so two engines that printed different text in
    a string compared EQUAL and the gate passed on a real divergence
    [tested: test_a_variable_identifier_inside_a_string_is_data].

    An unterminated quote makes the rest of the term string data. That is the
    conservative direction on purpose: leaving text alone can only report a
    difference that is not there, never hide one that is.
    """
    renamed: dict[str, str] = {}
    out: list[str] = []
    index = 0
    while index < len(text):
        character = text[index]
        if character == '"':
            end = index + 1
            while end < len(text) and text[end] != '"':
                end += 2 if text[end] == "\\" else 1
            out.append(text[index : end + 1])
            index = end + 1
            continue
        if character != "$":
            out.append(character)
            index += 1
            continue
        end = _variable_end(text, index)
        if end == index:
            out.append(character)
            index += 1
            continue
        out.append(renamed.setdefault(text[index:end], f"$V{len(renamed)}"))
        index = end
    return "".join(out)


def _top_level(text: str, needle: str) -> int:
    """Where `needle` sits outside every bracket and string literal, or -1."""
    depth = 0
    index = 0
    while index < len(text):
        character = text[index]
        if character == '"':
            index += 1
            while index < len(text) and text[index] != '"':
                index += 2 if text[index] == "\\" else 1
            index += 1
            continue
        if character in "([{":
            depth += 1
        elif character in ")]}":
            depth -= 1
        elif depth == 0 and text.startswith(needle, index):
            return index
        index += 1
    return -1


def _canonical_record(record: str) -> str:
    """One record, with a verdict line's two halves scoped apart.

    `is <actual>, should <expected>` prints two SEPARATE terms and each numbers
    its own variables from zero: `!(test (foo $x) (foo $y))`, whose variables
    are distinct, prints `is (foo $_0), should (foo $_0)` [measured 2026-09-05
    against engine/main.pl]. Canonicalising the line as one namespace therefore
    invents a coreference the writer never expressed, and splitting it loses
    none. CeTTa's own corpus generator draws the line in the same place
    [source: CeTTa scripts/petta_corpus_manifest.py, test_diagnostic_parts and
    alpha_canonicalize_output, at
    MesTTo/CeTTa@0ca2f4bad47205174608d7af54dd12a4c12b2e0b].
    """
    body = record.rstrip("\r\n")
    ending = record[len(body) :]
    if body.startswith(VERDICT_OPEN):
        suffix = next((s for s in VERDICT_SUFFIXES if body.endswith(s)), "")
        middle = body[len(VERDICT_OPEN) : len(body) - len(suffix)]
        cut = _top_level(middle, VERDICT_DELIMITER)
        if cut >= 0:
            actual = _canonical_term(middle[:cut])
            expected = _canonical_term(middle[cut + len(VERDICT_DELIMITER) :])
            return f"{VERDICT_OPEN}{actual}{VERDICT_DELIMITER}{expected}{suffix}{ending}"
    return _canonical_term(body) + ending


def _records(text: str) -> Iterator[str]:
    """The text cut into records, each one lexically complete.

    A record ends at a newline where no bracket and no string literal is open,
    so a term printed over several lines stays ONE record and keeps its
    variable sharing. Resetting at every physical line would destroy it:
    `(pair $_7` / `$_7)` and `(pair $_8` / `$_9)` are different terms and a
    per-line reset makes them the same text. FileCheck draws the same
    distinction, clearing pattern variables at a CHECK-LABEL block rather than
    at a line [source:
    https://llvm.org/docs/CommandGuide/FileCheck.html#the-check-label-directive].
    Unbalanced text WIDENS a record, which is the safe direction: a wider
    namespace can report a difference that is not there, never hide one.
    """
    held: list[str] = []
    depth = 0
    quoted = False
    for line in text.splitlines(keepends=True):
        held.append(line)
        index = 0
        while index < len(line):
            character = line[index]
            if quoted:
                if character == "\\":
                    index += 1
                elif character == '"':
                    quoted = False
            elif character == '"':
                quoted = True
            elif character in "([{":
                depth += 1
            elif character in ")]}":
                depth -= 1
            index += 1
        if depth <= 0 and not quoted:
            yield "".join(held)
            held, depth = [], 0
    if held:
        yield "".join(held)


def alpha(text: str) -> str:
    """Printed variables renamed to their first-occurrence position, per term.

    The identifiers expose allocation history rather than meaning, so two runs
    that mean the same thing spell it differently. The SCOPE is one printed
    term rather than the whole file: two independent answers that happen to
    reuse an allocation slot are not sharing a variable, and a file-wide
    namespace reported that as a divergence nobody wrote
    [tested: test_two_answers_reusing_a_slot_are_not_one_variable].
    """
    return "".join(_canonical_record(record) for record in _records(text))


def stale_skips(manifest: dict) -> dict[str, str]:
    """Recorded skips whose capability has since ARRIVED, with the reason given.

    A skip is derived from a declared capability, so it can stop being true
    without anyone noticing: torch.metta was skipped for "needs torch
    installed" on a box where torch imports [measured 2026-09-05]. REPORTED
    and not failed, because whether a machine has torch is an environment fact
    and refusing on it would make the gate red for having more, not less
    [tested: test_a_skip_whose_capability_arrived_is_reported].
    """
    sys.path.insert(0, str(HERE))
    import petta_capture  # noqa: PLC0415  -- the record side, imported only for its declaration

    recorded = manifest.get("skips", {})
    live = petta_capture.skips()
    return {
        name: why for name, why in recorded.items() if name not in live
    }


def run_ours(name: str, timeout: int) -> tuple[int | None, str, bool]:
    proc = subprocess.Popen(
        # The `extensions` seat, because upstream loads janus unconditionally
        # and the pin was captured from an engine that had it. Without the
        # seat every python-touching entry differs on this side alone
        # [measured 2026-08-30: python.metta and python_import.metta].
        # start_new_session below puts this engine in a SESSION of its own,
        # so no group signal from the lane above can reach it and the only
        # bound left would be the `communicate(timeout=)` in this process --
        # which is the mechanism that already cost 122 CPU-hours when the
        # process holding it was killed. The bound travels WITH the command
        # instead. `communicate` still fires first and still decides the
        # outcome; this is what remains when nobody is waiting.
        bounded(["swipl", "--stack_limit=8g", "-q",
                 "-s", str(ROOT / "engine" / "main.pl"),
                 "--", f"examples/{name}", "silent", "extensions"],
                ceiling=timeout + CHILD_GRACE),
        cwd=PIN, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, text=True, start_new_session=True,
    )
    try:
        out, err = proc.communicate(timeout=timeout)
        timed = False
    except subprocess.TimeoutExpired:
        os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
        out, err = proc.communicate()
        timed = True
    return proc.returncode, ANSI.sub("", (out or "") + (err or "")), timed


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--gate", action="store_true",
                    help="exit nonzero when a conforming entry differs")
    ap.add_argument("--record-divergences", action="store_true",
                    help="rule every entry that differs RIGHT NOW as `diverges`, "
                         "storing the output it gives, so the gate blocks a NEW "
                         "difference and any drift in a recorded one while the "
                         "known backlog burns down. Run it deliberately, never "
                         "to make a red lane green.")
    ap.add_argument("--timeout", type=int, default=90)
    ap.add_argument("--jobs", type=int, default=4)
    ap.add_argument("--show", type=int, default=8,
                    help="how many differing entries to print in full")
    args = ap.parse_args()

    if not MANIFEST.exists():
        print(f"petta: no pin at {MANIFEST.relative_to(ROOT)}. Capture one with\n"
              f"  python tests/conformance/petta_capture.py --upstream <checkout>",
              file=sys.stderr)
        return 2
    manifest = json.loads(MANIFEST.read_text())
    entries = manifest["entries"]

    def check(item: tuple[str, dict]) -> dict:
        name, ruling = item
        want = (EXPECTED / f"{name}.out").read_text()
        rc, got, timed = run_ours(name, args.timeout)
        return {"name": name, "status": ruling["status"], "want_rc": ruling["rc"],
                "rc": rc, "timeout": timed, "want": want, "got": got,
                "equal": got == want, "alpha_equal": alpha(got) == alpha(want),
                "recorded": ruling.get("ours")}

    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        results = list(pool.map(check, sorted(entries.items())))

    agree, blocking, ruled = [], [], []
    for r in results:
        if r["status"] == "conforms":
            (agree if r["alpha_equal"] and r["rc"] == r["want_rc"] else blocking).append(r)
        else:
            # A recorded divergence must still differ in exactly the way the
            # ruling says, or the ruling is stale and the run must say so.
            if r["recorded"] is not None and alpha(r["got"]) != alpha(r["recorded"]):
                blocking.append(r)
            else:
                ruled.append(r)

    total = len(results)
    print(f"== PeTTa conformance, upstream {manifest['commit'][:8]}")
    print(f"agreeing        : {len(agree)}/{total}")
    print(f"recorded rulings: {len(ruled)}")
    print(f"blocking        : {len(blocking)}")
    for name, why in sorted(stale_skips(manifest).items()):
        print(f"stale skip      : {name} was left out because it {why}")
    for r in blocking[: args.show]:
        print(f"\n--- {r['name']}  (status {r['status']}, "
              f"exit {r['want_rc']} -> {r['rc']}"
              f"{', TIMED OUT' if r['timeout'] else ''})")
        want, got = r["want"].splitlines(), r["got"].splitlines()
        for i in range(max(len(want), len(got))):
            a = want[i] if i < len(want) else "<no line>"
            b = got[i] if i < len(got) else "<no line>"
            if a != b:
                print(f"    upstream: {a[:110]}")
                print(f"    ours    : {b[:110]}")
                break
    if len(blocking) > args.show:
        print(f"\n... and {len(blocking) - args.show} more")

    if args.record_divergences:
        for r in results:
            entry = entries[r["name"]]
            if r["alpha_equal"] and r["rc"] == r["want_rc"]:
                entry["status"] = "conforms"
                entry.pop("ours", None)
            else:
                entry["status"] = "diverges"
                entry["ours"] = r["got"]
                entry["ours_rc"] = r["rc"]
        manifest["entries"] = entries
        MANIFEST.write_text(json.dumps(manifest, indent=1, sort_keys=True) + "\n")
        ruled = sum(1 for e in entries.values() if e["status"] == "diverges")
        print(f"\nrecorded: {len(entries) - ruled} conform, {ruled} ruled `diverges`")
        return 0

    if args.gate and blocking:
        print(f"\npetta: {len(blocking)} entries block the gate", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
