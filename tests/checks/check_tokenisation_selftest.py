r"""Purpose: prove the two tokenisation lanes can fail, by planting on each side
of each of them.

Running `pygments-sync` and `tokenisation` on THIS repository proves the
repository agrees with itself. It says nothing about whether either lane can
tell a disagreement from agreement, which is the whole of their job, and a
generated-file lane is the easiest kind to write so that it never fails: it
compares a file against a function that produced it.

Four plants, one for every way the derivation can go wrong.

  GRAMMAR CHANGED, LEXER NOT. The site starts scoping something the installed
  lexer does not. This is the case the whole design exists to catch.
  LEXER CHANGED, GRAMMAR NOT. Somebody edits the generated module by hand.
  A GROUP WITH NO TOKEN. The grammar grows a thirteenth group and nothing in
  the generator names a colour for it, which would otherwise reach every
  reader as plain text.
  A PATTERN PYTHON CANNOT SPELL. `\h` compiles under Oniguruma and not under
  Python's `re`, and a generator that let it through would put the failure in
  a consumer's import rather than in this tree.

Assumes: a writable ai-tmp/ in this repository; the two plants that need the
  grammar's own tokeniser also need node and website/node_modules, and follow
  the lane's own policy when they are missing.
Guarantees:
  - astral characters before tokens, in strings and comments, and on preceding
    lines retain matching character offsets [tested:
    tests/checks/check_tokenisation_selftest.py; commit=WORKTREE]
  - a grammar change the lexer does not carry is reported [tested:
    tests/checks/check_tokenisation_selftest.py; commit=7ba114f280ec3b132658cacb562064d0bac23f41]
  - a lexer change the grammar does not carry is reported [tested:
    tests/checks/check_tokenisation_selftest.py; commit=7ba114f280ec3b132658cacb562064d0bac23f41]
  - a group with no token, and a pattern Python's re cannot compile, are each
    refused by name rather than dropped [tested:
    tests/checks/check_tokenisation_selftest.py; commit=7ba114f280ec3b132658cacb562064d0bac23f41]
  - the generated module is compared against the generator's output, so an
    edit to either side is drift [tested:
    tests/checks/check_tokenisation_selftest.py; commit=7ba114f280ec3b132658cacb562064d0bac23f41]
Fails when: run against a tree it did not write. It asserts on fixtures it
  builds and on the repository's own grammar, and changes neither.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""  # noqa: D205  -- the contract is one continuous invariant, not summary-and-body prose

from __future__ import annotations

import copy
import json
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(ROOT / "extensions" / "python"))

from check_tokenisation_parity import (  # noqa: E402  -- the paths are installed above
    GRAMMAR,
    mismatches,
    prerequisite,
)
from tools.pygmentsgen import (  # noqa: E402  -- the paths are installed above
    MODULE,
    GrammarError,
    module_text,
)

from metta._pygments import MettaLexer  # noqa: E402  -- the paths are installed above

#: Small, and every group in it. A plant that changed a group this does not
#: exercise would be reported by nothing here and the selftest would pass on a
#: lane that had stopped looking.
FIXTURE = [
    (
        "selftest",
        '; a comment\n(= (f $x) "a\\nb")\n!(+ 1 2.5)\n(: Bool Type)\n'
        "%Undefined% &self @doc 'c' (== a b)\n"
        '🙂 (= (f $x) "π🙂") ; 🦊\n!(+ 1 2)\n"🙂\n🦊" (: Bool Type)\n',
    )
]


def planted_grammar(grammar: dict) -> dict:
    """The grammar with `$x` scoped only when it is spelled `?x`."""
    changed = copy.deepcopy(grammar)
    pattern = changed["repository"]["variable"]["patterns"][0]
    pattern["match"] = pattern["match"].replace(r"\$", r"\?")
    return changed


def planted_lexer() -> type:
    """The lexer with its comment rule removed, and nothing else changed."""
    root = [rule for rule in MettaLexer.tokens["root"] if rule[0] != r";.*$"]
    if len(root) == len(MettaLexer.tokens["root"]):
        msg = "the comment rule this plant removes is no longer spelled ';.*$'"
        raise SystemExit(msg)
    return type("PlantedLexer", (MettaLexer,), {"tokens": {**MettaLexer.tokens, "root": root}})


def refusal(grammar: dict, note: str) -> str | None:
    """The refusal a planted grammar draws, or None when it drew none."""
    try:
        module_text(grammar)
    except GrammarError as error:
        return str(error)
    return f"{note} was accepted; the generator refused nothing"


def main() -> int:
    """Plant each shape and hold the lanes to what they report."""
    problems: list[str] = []
    grammar = json.loads(GRAMMAR.read_text(encoding="utf-8"))

    unknown = copy.deepcopy(grammar)
    unknown["repository"]["variable"]["patterns"][0]["name"] = "invented.group.metta"
    message = refusal(unknown, "a group with an unnamed scope")
    if "invented.group.metta" not in message:
        problems.append(f"the unnamed scope was not refused by name: {message}")

    unspellable = copy.deepcopy(grammar)
    unspellable["repository"]["variable"]["patterns"][0]["match"] = r"\$\h+"
    message = refusal(unspellable, r"a pattern holding \h")
    if "Oniguruma escape" not in message:
        problems.append(rf"\h was not refused as untranslatable: {message}")

    current = MODULE.read_text(encoding="utf-8")
    if module_text(grammar) != current:
        problems.append(f"{MODULE.relative_to(ROOT)} is not what the generator writes")
    if module_text(planted_grammar(grammar)) == current:
        problems.append(
            "a planted grammar produced the checked-in module byte for byte, so "
            "the pygments-sync lane compares against something that ignores the grammar"
        )

    refused = prerequisite()
    if refused is not None:
        print("the two parity plants need the grammar's own tokeniser; not planted")
    else:
        with tempfile.TemporaryDirectory(prefix="tokenisation-selftest-", dir=ROOT / "ai-tmp") as name:
            path = Path(name) / "planted.tmLanguage.json"
            path.write_text(json.dumps(planted_grammar(grammar)), encoding="utf-8")
            if not mismatches(FIXTURE, grammar=path):
                problems.append(
                    "a grammar that scopes ?x instead of $x agreed with the lexer, "
                    "so the tokenisation lane is not reading the grammar"
                )
        if not mismatches(FIXTURE, lexer_class=planted_lexer()):
            problems.append(
                "a lexer with no comment rule agreed with the grammar, so the "
                "tokenisation lane is not reading the lexer"
            )
        if mismatches(FIXTURE):
            problems.append("the unplanted fixture disagreed, so the plants prove nothing")

    for line in problems:
        print(line)
    print(f"{len(problems)} problem(s); 4 shapes planted")
    return 1 if problems else refused or 0


if __name__ == "__main__":
    raise SystemExit(main())
