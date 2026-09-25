"""Purpose: prove the llms lane can fail, one planted fault per check.

A green lane is worth what its red is worth. The llms lane exists because a
cheat sheet claimed a gate that did not exist and drifted for three days
behind the claim, so this file plants exactly the drift each half is supposed
to catch and fails when the checker reports it green.

The checker's nine parts are pure functions over (sheet, text), so each
fault is planted in TEXT rather than by writing a broken llms.txt into the
tree: a selftest that edited the shipped sheet would race the lane reading it.
The engine half takes its vocabulary as an argument for the same reason, and
so runs here without swipl.

Assumes: it runs from a checkout of this repository.
Guarantees:
  - a path claim naming nothing, a roster omitting a shipped library, a roster
    naming an absent one, a count disagreeing with lib/, and a language-surface
    name the engine does not know are each caught, and a clean text of the same
    shape reports nothing [tested: this file is its own test, run by the gate;
    commit=b089d4309f34b205c5fdaee46960d1fcd9c1ac42]
  - Python methods are checked on the class named by their receiver, including
    calls in compact unlabelled API blocks [tested: this file is its own test,
    run by the gate; commit=b089d4309f34b205c5fdaee46960d1fcd9c1ac42]
  - the real sheets are read by the lane itself, never edited here, so a
    planted fault cannot race the lane reading the shipped file [tested:
    tests/checks/check_llms_names.py; commit=b089d4309f34b205c5fdaee46960d1fcd9c1ac42]
  - a wrong source-table count and an omitted corpus-used engine head each
    turn their production checker red independently [tested: this file is its
    own test, run by the gate; commit=2c376be0bca6f85920288863ac89f09a44e6c0c7]
  - the planted library-table count uses the directory roster that includes
    both MeTTa and Prolog implementations [tested: this file is its own test,
    run by the gate; commit=1bfad3db85807fff774cad370ff8e57f7400ae99]
  - a documented return type is checked against the live annotation, with the
    four decorations that are not disagreements planted beside the one that
    is [tested: this file is its own test, run by the gate; commit=4ef96c94579db405fafed8fdaab20e33901a2298]
  - every required closed-value roster catches omission, invention, wrong
    order where order is semantic, a false count and total absence [tested:
    this file is its own test, run by the gate; commit=2e627a593413191cda3170f2eb716835f7f62543]
  - a same-count substitution in the algebra-law roster and a changed alias
    expansion in its table are each caught [tested: this file is its own test,
    run by the gate; commit=5e0ae6c22d604c4b980766e3cc4811ee545e5c9e]
  - a vocabulary roster sentence omitting a member, a sentence read past its
    end, the engine-unit, special-form, setting and info-key rosters each
    omitting a member or deleted, a wrong count beside the special forms or the
    settings, and a compound count word each turn their checker red, while a
    one-member mention, an enum-less constant, a period inside code and a seat
    sheet stay quiet
    [tested 2026-09-25T22:44:33+10:00: tests/checks/check_llms_selftest.py]
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None.
"""

from __future__ import annotations

import re
import shutil
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

from check_llms_names import (  # noqa: E402  -- HERE must be on the path first
    REPO,
    _number,
    _unreachable,
    builtin_count_findings,
    closed_value_findings,
    closed_value_source_findings,
    config_roster_findings,
    count_findings,
    dotted_findings,
    head_findings,
    info_roster_findings,
    library_findings,
    method_findings,
    near_miss_findings,
    omitted_head_findings,
    operator_word_findings,
    operator_words,
    path_findings,
    refresh_source_claims,
    return_findings,
    shipped_libraries,
    special_form_findings,
    unit_roster_findings,
    vocabulary_roster_findings,
)

SHEET = REPO / "llms.txt"
PYTHON_SHEET = REPO / "extensions/python/llms.txt"
#: The node seat's sheet, which names what its build produces rather than what
#: the tree holds, and is the only sheet with that shape.
NODE_SHEET = REPO / "extensions/node/llms.txt"

SEMIRINGS = (
    "bool", "bag", "counting", "set", "ranked", "tropical", "prob", "prov",
    "budget", "amplitude",
)
EFFECTS = (
    "pureStructural", "readOnlyLookup", "nondeterministicReadOnly",
    "writesState", "oracleIO",
)
CAPABILITIES = (
    "match", "enumerate", "add", "add-many", "remove", "clear", "subscribe",
    "plan", "rules",
)
ALGEBRA_LAWS = (
    "combine-associative", "combine-commutative", "extend-associative",
    "extend-commutative", "left-distributive", "right-distributive",
    "combine-idempotent", "combine-zero-identity", "extend-one-identity",
    "extend-zero-annihilates", "contraction", "roundtrip", "equivalent",
    "associative", "commutative", "distributive", "idempotent", "identity",
    "distributes-over",
)
#: One row per alias, flattened the way the checker flattens the table, so a
#: changed expansion is a changed string rather than a same-length list.
LAW_ALIASES = (
    "associative=combine-associative=extend-associative",
    "commutative=combine-commutative",
    "distributive=left-distributive=right-distributive",
    "idempotent=combine-idempotent",
    "contraction=contraction",
    "identity=combine-zero-identity=extend-one-identity",
    "distributes-over=left-distributive=right-distributive",
)
CLOSED_VALUES = {
    "semiring": SEMIRINGS,
    "algebra-presets": SEMIRINGS,
    "algebra-law": ALGEBRA_LAWS,
    "algebra-law-aliases": LAW_ALIASES,
    "effect-class": EFFECTS,
    "provider-capabilities": CAPABILITIES,
}


def _shipped() -> list[str]:
    """The checker's own roster, not a second copy of the rule that names it."""
    return shipped_libraries(REPO)


def _roster(names: list[str], count: int | None = None) -> str:
    listed = ", ".join(f"`{name}`" for name in names)
    total = len(names) if count is None else count
    return f"{total} libraries load with `!(import! ...)`: {listed}. Scored answers"


def _builtins(count: int) -> str:
    return f"{count} builtins are registered; `m.self.builtins()` lists them.\n"


def _operators(words: list[str], count: str = "FOURTEEN") -> str:
    rows = "\n".join(f"| `S.{word}` | `x` |" for word in words)
    return (
        f"{count} ATTRIBUTE NAMES ON `S` ARE OPERATOR WORDS, NOT SPELLINGS.\n\n"
        f"{rows}\n"
    )


def _surface(body: str) -> str:
    return f"## The MeTTa language surface\n\nblah\n\n```\n{body}\n```\n"


def _listed(values: tuple[str, ...], prefix: str = "") -> str:
    return ", ".join(f"`{prefix}{value}`" for value in values)


def _closed_text(*, root: bool) -> str:
    aliases = (
        "| algebra-law alias | expands to |\n|---|---|\n"
        "| `associative` | `combine-associative`, `extend-associative` |\n"
        "| `commutative` | `combine-commutative` |\n"
        "| `distributive` | `left-distributive`, `right-distributive` |\n"
        "| `idempotent` | `combine-idempotent` |\n"
        "| `contraction` | `contraction` |\n"
        "| `identity` | `combine-zero-identity`, `extend-one-identity` |\n"
        "| `distributes-over` | `left-distributive`, `right-distributive` |\n"
    )
    shared = (
        f"`metta.vocabularies.Semiring` names the closed set: {_listed(SEMIRINGS)}.\n\n"
        f"`metta.vocabularies.AlgebraLaw` names the accepted set: "
        f"{_listed(ALGEBRA_LAWS)}.\n\n"
        f"{aliases}\n"
        f"The ordered `EffectClass` members are: {_listed(EFFECTS)}. "
        "A plan's class is their join.\n\n"
        f"Capabilities are declared, not guessed: {_listed(CAPABILITIES)}, "
        "and an unsupported operation refuses.\n"
    )
    if not root:
        return shared
    rows = "\n".join(f"| `{value}` | x |" for value in SEMIRINGS)
    return (
        "| carrier | combine |\n|---|---|\n"
        f"{rows}\n\n"
        f"Ten are objects: {_listed(SEMIRINGS, 'metta.')}\n\n"
        f"{shared}"
    )


def main() -> int:
    """Plant one fault per check and require each to be caught."""
    failures: list[str] = []
    cases = 0

    def expect(condition: bool, message: str) -> None:  # noqa: FBT001  -- the boolean IS the claim being asserted, and every call reads as one sentence
        nonlocal cases
        cases += 1
        if not condition:
            failures.append(message)

    # DOTTED: a package path deeper than the one segment method_findings reads.
    expect(
        dotted_findings(SHEET, "the repair is `metta._errors.errors.Remedy`") == [],
        "a resolving dotted package path was reported",
    )
    expect(
        len(dotted_findings(SHEET, "the repair is `metta._errors.errors.NoSuchName`")) == 1,
        "a dotted path whose LAST segment names nothing was NOT reported",
    )
    expect(
        len(dotted_findings(SHEET, "the repair is `metta._nonexistent.module.Thing`")) == 1,
        "a dotted path whose MIDDLE segment names nothing was NOT reported",
    )
    # The span a claim sits in can cross a line break, and the span pattern
    # PATHS uses is line-bounded so an unclosed backtick cannot swallow the
    # file. Anchoring on the opening backtick is what reaches this one; the
    # first version of the check read the span and missed it.
    expect(
        len(dotted_findings(SHEET, "`metta._errors.errors.NoSuchName(title,\nkind)`")) == 1,
        "a dotted path in a span that wraps a line was NOT reported",
    )
    # One segment is method_findings' claim, not this one, and reading it here
    # would report every `metta.algebra` twice.
    expect(
        dotted_findings(SHEET, "declare it with `metta.algebra`") == [],
        "a one-segment path was read as a dotted package path",
    )
    # Another language's sheet may spell `metta.` meaning its own namespace.
    expect(
        dotted_findings(NODE_SHEET, "`metta._nonexistent.module.Thing`") == [],
        "a dotted path was read off a sheet that does not teach Python",
    )
    # A module that EXISTS and breaks while importing is a different fact from
    # one that is absent, and the difference is subtle: both arrive as
    # ModuleNotFoundError and only the `name` on it tells them apart. Reporting
    # a breakage as a stale sheet claim would send a reader to edit the
    # documentation over a broken module. The walk derives its root from the
    # package it is handed, so a planted package exercises the taxonomy without
    # writing anything into metta/.
    planted = Path(tempfile.mkdtemp(prefix="llms-selftest-import-", dir=REPO / "ai-tmp"))
    try:
        package = planted / "plantedpkg"
        package.mkdir()
        (package / "__init__.py").write_text("", encoding="utf-8")
        (package / "broken.py").write_text(
            "import definitely_not_a_real_module\n", encoding="utf-8")
        sys.path.insert(0, str(planted))
        import plantedpkg
        expect(
            _unreachable(plantedpkg, ["absent"]) == "plantedpkg.absent",
            "an absent submodule was not reported absent",
        )
        broke = False
        try:
            _unreachable(plantedpkg, ["broken"])
        except ModuleNotFoundError:
            broke = True
        expect(broke, "a submodule that BREAKS while importing was called absent")
        # The other half of the taxonomy: a module raising ImportError DIRECTLY
        # never reaches the ModuleNotFoundError arm, so it is a separate branch
        # and needs its own plant.
        (package / "refuses.py").write_text(
            "raise ImportError('planted refusal')\n", encoding="utf-8")
        refused = False
        try:
            _unreachable(plantedpkg, ["refuses"])
        except ImportError:
            refused = True
        expect(refused, "a submodule raising ImportError directly was called absent")
        # And the finding a reader actually meets. dotted_findings takes the
        # root it resolves against, so this reaches the real branch without
        # writing a broken module into the shipped package and racing a
        # parallel run.
        reported = dotted_findings(
            SHEET, "`plantedpkg.refuses.thing`", package=plantedpkg)
        expect(
            len(reported) == 1 and "could not be resolved" in reported[0],
            "a module that raises while importing was not reported as a breakage",
        )
    finally:
        sys.path.remove(str(planted))
        shutil.rmtree(planted, ignore_errors=True)

    # PATHS: a claim that resolves, and one that does not.
    expect(
        path_findings(SHEET, "see `engine/ext_points.pl` for the seams") == [],
        "a resolving path claim was reported",
    )
    expect(
        len(path_findings(SHEET, "see `engine/no_such_unit.pl` for the seams")) == 1,
        "a path claim naming nothing was NOT reported",
    )
    expect(
        path_findings(SHEET, "`add-atom/3` and `metta.run/match/eval`") == [],
        "a predicate indicator or door list was read as a path",
    )
    # A component this tree MOUNTS holds a `.git` exactly as a foreign checkout
    # does, and calling it foreign hid everything inside every submodule: a glob
    # into one then reported that it named nothing.
    expect(
        path_findings(SHEET, "every engine unit is `engine/metta/*.pl`") == [],
        "a glob into a mounted component was reported",
    )
    expect(
        path_findings(SHEET, "the libraries are `lib/*/`") == [],
        "a glob naming the library directories was reported",
    )
    # A path the tree deliberately does not hold is a claim about what a BUILD
    # produces. Reporting it is reporting the documentation for being accurate.
    expect(
        path_findings(NODE_SHEET, "a page serves `_runtime/`") == [],
        "a build output the tree ignores was reported",
    )
    expect(
        len(path_findings(NODE_SHEET, "a page serves `_no_such_output/`")) == 1,
        "a path that is neither held nor ignored was NOT reported",
    )
    # And not every ignored path: scratch is ignored too, so asking git alone
    # would let any typo under ai-tmp/ resolve, which the PATHS contract says
    # never answers a claim.
    expect(
        len(path_findings(SHEET, "written to `ai-tmp/no-such-receipt.md`")) == 1,
        "a scratch path was allowed to answer a claim",
    )
    # The shorthand resolves a bare tail against THIS checkout only: a file
    # that exists solely under ai-tmp/ (scratch, where agent worktrees live) or
    # under a directory carrying its own .git (another checkout) must not
    # supply the green, since a worktree under ai-tmp/ once did.
    (REPO / "ai-tmp").mkdir(exist_ok=True)
    scratch = Path(tempfile.mkdtemp(prefix="llms-selftest-", dir=REPO / "ai-tmp"))
    nested = Path(tempfile.mkdtemp(prefix="llms-selftest-nested-", dir=HERE))
    try:
        (scratch / "only_under_scratch.plt").write_text("", encoding="utf-8")
        (nested / ".git").write_text("gitdir: elsewhere\n", encoding="utf-8")
        (nested / "only_under_another_checkout.plt").write_text("", encoding="utf-8")
        expect(
            len(path_findings(SHEET, "`only_under_scratch.plt`")) == 1,
            "a file that exists only under ai-tmp/ resolved a bare-name claim",
        )
        expect(
            len(path_findings(SHEET, "`only_under_another_checkout.plt`")) == 1,
            "a file that exists only under another checkout resolved a bare-name claim",
        )
        expect(
            path_findings(SHEET, "`ext_points.plt`") == [],
            "a bare name this checkout holds stopped resolving",
        )
    finally:
        shutil.rmtree(scratch)
        shutil.rmtree(nested)

    # LIBRARIES: the roster and both statements of its count.
    shipped = _shipped()
    expect(
        library_findings(SHEET, _roster(shipped)) == [],
        "an exact roster was reported",
    )
    expect(
        any(
            "omits" in finding
            for finding in library_findings(SHEET, _roster(shipped[:-1], len(shipped)))
        ),
        "a roster omitting a shipped library was NOT reported",
    )
    expect(
        any(
            "does not ship" in finding
            for finding in library_findings(
                SHEET, _roster([*shipped, "lib_invented"], len(shipped))
            )
        ),
        "a roster naming an absent library was NOT reported",
    )
    expect(
        any(
            "libraries, lib/ ships" in finding
            for finding in library_findings(SHEET, _roster(shipped, len(shipped) - 1))
        ),
        "a roster count disagreeing with lib/ was NOT reported",
    )
    table = f"| `lib/*/` | {len(shipped) - 1} MeTTa libraries loaded with x |"
    expect(
        any("sources table says" in finding for finding in library_findings(SHEET, table)),
        "a sources-table count disagreeing with lib/ was NOT reported",
    )

    expect(
        any(
            "roster is gone" in finding
            for finding in library_findings(SHEET, "a sheet with no roster at all")
        ),
        "a root sheet whose roster vanished was NOT reported",
    )
    expect(
        library_findings(REPO / "extensions/python/llms.txt", "a seat sheet") == [],
        "a seat sheet without a roster was reported",
    )

    # CLOSED SETS: each roster is explicit and exact. Unlike the library
    # roster, these values come from the engine catalog and one Python
    # protocol constant rather than from directory names.
    root_closed = _closed_text(root=True)
    python_closed = _closed_text(root=False)
    expect(
        closed_value_source_findings(CLOSED_VALUES) == [],
        "matching catalog semiring and algebra preset sets were reported",
    )
    split_sources = dict(CLOSED_VALUES)
    split_sources["algebra-presets"] = SEMIRINGS[:-1]
    expect(
        len(closed_value_source_findings(split_sources)) == 1,
        "a catalog algebra preset omitted from the semiring vocabulary was NOT reported",
    )
    expect(
        closed_value_findings(SHEET, root_closed, CLOSED_VALUES) == [],
        "exact root closed-value rosters were reported",
    )
    expect(
        closed_value_findings(PYTHON_SHEET, python_closed, CLOSED_VALUES) == [],
        "exact Python closed-value rosters were reported",
    )
    expect(
        any(
            "module algebra object" in finding
            for finding in closed_value_findings(
                SHEET,
                root_closed.replace("`metta.amplitude`", "", 1),
                CLOSED_VALUES,
            )
        ),
        "a module algebra object omission was NOT reported",
    )
    expect(
        any(
            "Semiring" in finding
            for finding in closed_value_findings(
                SHEET,
                root_closed.replace("`amplitude`.", "`amplitude`, `invented`.", 1),
                CLOSED_VALUES,
            )
        ),
        "an invented Semiring member was NOT reported",
    )
    expect(
        any(
            "AlgebraLaw" in finding
            for finding in closed_value_findings(
                SHEET,
                root_closed.replace("`distributes-over`.", "`absorptive`.", 1),
                CLOSED_VALUES,
            )
        ),
        "a same-count algebra-law substitution was NOT reported",
    )
    expect(
        any(
            "algebra-law alias" in finding
            for finding in closed_value_findings(
                SHEET,
                root_closed.replace(
                    "| `idempotent` | `combine-idempotent` |",
                    "| `idempotent` | `combine-associative` |",
                    1,
                ),
                CLOSED_VALUES,
            )
        ),
        "a changed algebra-law alias expansion was NOT reported",
    )
    expect(
        any(
            "EffectClass" in finding
            for finding in closed_value_findings(
                SHEET,
                root_closed.replace(
                    "`pureStructural`, `readOnlyLookup`",
                    "`readOnlyLookup`, `pureStructural`",
                    1,
                ),
                CLOSED_VALUES,
            )
        ),
        "a reordered EffectClass roster was NOT reported",
    )
    expect(
        any(
            "SpaceProvider capability" in finding
            for finding in closed_value_findings(
                PYTHON_SHEET,
                python_closed.replace(", `rules`, and an unsupported", ", and an unsupported"),
                CLOSED_VALUES,
            )
        ),
        "an omitted provider capability was NOT reported",
    )
    expect(
        any(
            "Semiring" in finding and "roster is missing" in finding
            for finding in closed_value_findings(
                SHEET,
                root_closed.replace(
                    "`metta.vocabularies.Semiring` names the closed set:",
                    "The enum contains:",
                ),
                CLOSED_VALUES,
            )
        ),
        "a Semiring roster deleted from the ROOT sheet was NOT reported",
    )
    expect(
        closed_value_findings(PYTHON_SHEET, "a seat sheet with no roster", CLOSED_VALUES)
        == [],
        "a seat sheet that covers none of these sets was reported",
    )
    expect(
        any(
            "EffectClass" in finding
            for finding in closed_value_findings(
                PYTHON_SHEET,
                python_closed.replace("`oracleIO`.", "`oracleIO`, `invented`.", 1),
                CLOSED_VALUES,
            )
        ),
        "an invented member in a seat sheet's own roster was NOT reported",
    )
    expect(
        any(
            "object roster says 9" in finding
            for finding in closed_value_findings(
                SHEET, root_closed.replace("Ten are objects", "Nine are objects"), CLOSED_VALUES
            )
        ),
        "a false module object roster count was NOT reported",
    )

    # VOCABULARY ROSTERS: a sentence naming a generated enum and two of its
    # words has to name them all. The rule is the prose's own shape, so each
    # case below is a sentence shape rather than a per-roster anchor.
    words = {"Refinement": ("Gt", "Ge", "Lt", "Literal")}
    whole = "`metta.vocabularies.Refinement` names `Gt`, `Ge`, `Lt` and `Literal`; `doc(x)` is not one."
    expect(
        vocabulary_roster_findings(SHEET, whole, words) == [],
        "a whole vocabulary roster was reported",
    )
    expect(
        any(
            "omits `Literal`" in finding
            for finding in vocabulary_roster_findings(
                SHEET, whole.replace(" and `Literal`", ""), words
            )
        ),
        "a vocabulary member the roster sentence omits was NOT reported",
    )
    expect(
        any(
            "omits `Lt`, `Literal`" in finding
            for finding in vocabulary_roster_findings(
                SHEET,
                "`metta.vocabularies.Refinement` names `Gt` and `Ge`. Then `Lt` and `Literal`.",
                words,
            )
        ),
        "a vocabulary roster sentence was read past its end",
    )
    expect(
        vocabulary_roster_findings(
            SHEET, "`metta.vocabularies.Refinement` such as `Gt` is one.", words
        )
        == [],
        "a one-member mention of a vocabulary was read as its roster",
    )
    expect(
        vocabulary_roster_findings(
            SHEET, "`metta.vocabularies.WIRE_TAGS` holds `s` and `g`.", words
        )
        == [],
        "a vocabulary constant that is no enum was read as a roster",
    )
    expect(
        vocabulary_roster_findings(
            SHEET,
            "`metta.vocabularies.Refinement` names `Gt`, `m.self.x`, `Ge`, `Lt` and `Literal`.",
            words,
        )
        == [],
        "a period inside inline code ended a vocabulary roster sentence",
    )

    # ENGINE UNITS, SPECIAL FORMS, SETTINGS: exact rosters with injected
    # sources, required on the root sheet and absent from a seat's.
    units = {"engine/metta": ("a", "b"), "engine/translator": ("c",), "engine/spaces": ("d", "e")}
    unit_text = (
        "| `engine/**/*.pl` | the two `engine/metta/*.pl` units (a, b), the one "
        "`engine/translator/*.pl` units (c), the two `engine/spaces/*.pl` units (e, d) |"
    )
    expect(unit_roster_findings(SHEET, unit_text, units) == [], "exact engine unit rosters were reported")
    expect(
        any(
            "engine/metta/*.pl" in finding
            for finding in unit_roster_findings(SHEET, unit_text.replace("(a, b)", "(a)"), units)
        ),
        "an engine unit its roster omits was NOT reported",
    )
    expect(
        any(
            "engine/spaces/*.pl" in finding and "missing" in finding
            for finding in unit_roster_findings(
                SHEET, unit_text.replace("`engine/spaces/*.pl` units (e, d)", "spaces"), units
            )
        ),
        "a deleted engine unit roster was NOT reported",
    )
    expect(
        unit_roster_findings(PYTHON_SHEET, "no unit rosters here", units) == [],
        "a seat sheet was held to the engine unit rosters",
    )
    forms = ("case", "chain", "case", "__metta_type_syntax__")
    form_text = "These two, plus the internal `__metta_type_syntax__` below:\n\n```\nchain case\n```\n"
    expect(special_form_findings(SHEET, form_text, forms) == [], "an exact special-form roster was reported")
    expect(
        any(
            "says 3" in finding
            for finding in special_form_findings(SHEET, form_text.replace("These two", "These three"), forms)
        ),
        "a wrong special-form count was NOT reported",
    )
    expect(
        any(
            "special-form roster must be" in finding
            for finding in special_form_findings(SHEET, form_text.replace("chain case", "chain"), forms)
        ),
        "a special form its roster omits was NOT reported",
    )
    expect(
        any("missing" in finding for finding in special_form_findings(SHEET, "no roster", forms)),
        "a deleted special-form roster was NOT reported",
    )
    settings = ("alpha", "beta")
    config_text = (
        "Inspect all two settings\nwith `config.as_dict()` and set them atomically with\n"
        "`config.configure(alpha=..., beta=...)`."
    )
    expect(config_roster_findings(SHEET, config_text, settings) == [], "an exact setting roster was reported")
    expect(
        any(
            "says 3" in finding
            for finding in config_roster_findings(SHEET, config_text.replace("all two", "all three"), settings)
        ),
        "a wrong setting count was NOT reported",
    )
    expect(
        any(
            "process setting roster must be" in finding
            for finding in config_roster_findings(SHEET, config_text.replace(", beta=...", ""), settings)
        ),
        "a setting its roster omits was NOT reported",
    )
    expect(
        any("missing" in finding for finding in config_roster_findings(SHEET, "no settings sentence", settings)),
        "a deleted setting roster was NOT reported",
    )
    keys = ("metta", "actor")
    info_text = "metta.engine().info() -> {metta, actor}: the version and the actor"
    expect(info_roster_findings(SHEET, info_text, keys) == [], "an exact info-key roster was reported")
    expect(
        any(
            "`engine().info()` key roster must be" in finding
            for finding in info_roster_findings(SHEET, info_text.replace(", actor", ""), keys)
        ),
        "an info key its roster omits was NOT reported",
    )
    expect(
        any("missing" in finding for finding in info_roster_findings(SHEET, "no info sentence", keys)),
        "a deleted info-key roster was NOT reported",
    )
    expect(
        (_number("sixty-nine"), _number("Sixty"), _number("twenty"), _number("1,000")) == (69, 60, 20, 1000),
        "a compound or plain count word was misread",
    )
    rejected = False
    try:
        _number("sixty-ten")
    except KeyError:
        rejected = True
    expect(rejected, "an impossible compound count word was accepted")

    # COUNTS: use the real table as the clean control, then corrupt one claim
    # in memory. The production derivation still reads the named source.
    source_text = SHEET.read_text(encoding="utf-8")
    refreshed = refresh_source_claims(source_text)
    expect(count_findings(SHEET, refreshed) == [], "regenerated source counts disagreed with their checker")
    expect(library_findings(SHEET, refreshed) == [], "regenerated library roster disagreed with its checker")
    expect(refresh_source_claims(refreshed) == refreshed, "source claim regeneration was not idempotent")
    expect(
        count_findings(SHEET, source_text) == [],
        "the sources table's exact counts were reported",
    )
    count = re.search(r"(?P<count>\d+) executable programs", source_text)
    expect(count is not None, "the planted count target vanished from llms.txt")
    if count is not None:
        wrong_count = str(int(count.group("count")) + 1)
        planted = (
            source_text[: count.start("count")] + wrong_count + source_text[count.end("count") :]
        )
        expect(
            any(
                "executable example programs" in finding
                for finding in count_findings(SHEET, planted)
            ),
            "a wrong source-table count was NOT reported",
        )
        expect(
            refresh_source_claims(planted) == refreshed,
            "regeneration did not repair a planted count while preserving the sheet",
        )

    # The engine half must not fail OPEN: a swipl that ran and failed is a
    # finding, where a swipl that is not installed is a skip.
    # Imported here, not at the top: this is the one case that patches it.
    import check_llms_names as lane

    original = lane.subprocess.run
    try:
        lane.subprocess.run = lambda *a, **k: type(  # noqa: ARG005  -- the stub answers the same failure whatever it is called with
            "Result", (), {"returncode": 1, "stdout": "", "stderr": "boom"}
        )()
        broke = False
        try:
            lane.engine_vocabulary()
        except RuntimeError:
            broke = True
        except lane.EngineUnavailableError:
            broke = False
        expect(broke, "an engine that RAN and failed was treated as absent")
    finally:
        lane.subprocess.run = original

    # HEADS: the surface block against a vocabulary the engine supplies.
    known = {"if", "case", "let"}
    expect(
        head_findings(SHEET, _surface("if case let"), known) == [],
        "a surface block of known heads was reported",
    )
    expect(
        len(head_findings(SHEET, _surface("if case let not-a-head"), known)) == 1,
        "a surface name the engine does not know was NOT reported",
    )

    expect(
        any(
            "language-surface block is gone" in finding
            for finding in head_findings(SHEET, "a sheet with no surface block", known)
        ),
        "a root sheet whose surface block vanished was NOT reported",
    )
    expect(
        head_findings(REPO / "extensions/python/llms.txt", "a seat sheet", known) == [],
        "a seat sheet without a surface block was reported",
    )

    # USED HEADS: the reverse direction. An exact token mention covers a live,
    # corpus-used head; a longer neighbouring symbol does not.
    uses = {"println!": 76, "get-atoms": 15}
    used_known = set(uses)
    expect(
        omitted_head_findings(SHEET, "`println!` and `get-atoms`", used_known, uses) == [],
        "documented corpus-used heads were reported",
    )
    omitted = omitted_head_findings(SHEET, "`println!` only", used_known, uses)
    expect(
        len(omitted) == 1 and "`get-atoms`" in omitted[0],
        "an omitted corpus-used engine head was NOT reported",
    )
    expect(
        any(
            "`print`" in finding
            for finding in omitted_head_findings(
                SHEET,
                "`println!` is a different head",
                {"print"},
                {"print": 1},
            )
        ),
        "a longer head name falsely covered an omitted shorter one",
    )

    # METHODS: a code block teaches, while prose can discuss or deny a name.
    block = "```python\nm.query(pattern)\n```"
    expect(
        any("m.query" in finding for finding in method_findings(SHEET, block)),
        "a method the library does not have was NOT reported",
    )
    expect(
        method_findings(SHEET, "```python\nm.match(pattern)\nkb.remove(a)\n```") == [],
        "real methods were reported",
    )
    expect(
        method_findings(SHEET, "prose saying there is no `metta.matching` here") == [],
        "prose DENYING a method was read as teaching it",
    )
    expect(
        method_findings(SHEET, "```ts\nm.dispose()\n```") == [],
        "another language's block was read as this package's methods",
    )
    expect(
        any(
            "m.query" in finding
            for finding in method_findings(PYTHON_SHEET, "```\nm.query(pattern)\n```")
        ),
        "an unlabelled Python API block was NOT inspected",
    )
    expect(
        any(
            "m.to_wire" in finding
            for finding in method_findings(
                PYTHON_SHEET,
                "```python\nm.to_wire()\n```",
            )
        ),
        "a Space-only method written on a MeTTa context was NOT reported",
    )
    expect(
        any(
            "kb.close" in finding
            for finding in method_findings(PYTHON_SHEET, "```python\nkb.close()\n```")
        ),
        "a MeTTa-only method written on a Space was NOT reported",
    )
    expect(
        any(
            "context.answers" in finding
            for finding in method_findings(SHEET, "```python\ncontext.answers(term)\n```")
        ),
        "an invalid method on the named context receiver was NOT reported",
    )
    expect(
        method_findings(
            SHEET,
            "```python\nm.answers(term)\ncontext.close()\n```",
        )
        == [],
        "valid methods were reported on the root sheet's Space and context",
    )
    expect(
        method_findings(
            PYTHON_SHEET,
            "```python\nm.close()\nkb.answers(term)\nkb.to_wire()\n```",
        )
        == [],
        "valid methods were reported on the Python sheet's context and Space",
    )

    # RETURNS: a documented `-> Type` against the live annotation. The stale
    # line this check was built for said `-> list[TraceEvent(...)]` while the
    # method answered a Trace, so a reader had no way to learn that
    # `.truncated` exists or that a cut trace looks exactly like a whole one.
    expect(
        any(
            "answers Trace" in finding
            for finding in return_findings(
                SHEET, "```python\nm.trace(src) -> list[TraceEvent(depth, kind)]\n```"
            )
        ),
        "a documented return type the method contradicts was NOT reported",
    )
    expect(
        return_findings(
            SHEET, "```python\nm.trace(src) -> Trace of TraceEvent(depth, kind)\n```"
        )
        == [],
        "the true return type was reported",
    )
    expect(
        return_findings(SHEET, "```python\nm.match(query) -> Answers\n```") == [],
        "a live `Any` was read as a disagreement rather than as silence",
    )
    expect(
        return_findings(SHEET, "```python\nm.derivation(t) -> list[Derivation]\n```") == [],
        "a sheet more precise than the annotation was reported",
    )
    expect(
        return_findings(SHEET, "```python\nm.save(path) -> int   (atomic, fsynced)\n```")
        == [],
        "a prose tail after the type was read as part of the type",
    )
    expect(
        return_findings(SHEET, "```python\nm.limits(inferences=10_000)\n```") == [],
        "a call example with no `->` was read as a signature",
    )

    # OPERATORS: the claim is prose, so removing it must not disable the check,
    # and the roster is read as well as the count so a swap cannot hide.
    live = sorted(operator_words())
    expect(
        operator_word_findings(SHEET, _operators(live)) == [],
        "the true operator-word count and roster were reported",
    )
    expect(
        len(operator_word_findings(SHEET, _operators(live, "THIRTEEN"))) == 1,
        "an operator-word count one short of the package was NOT reported",
    )
    expect(
        len(operator_word_findings(SHEET, _operators(live[1:]))) == 1,
        "a word dropped from the table went unreported while the count still agreed",
    )

    # BUILTINS: the same shape as OPERATORS and for the same reason. The live
    # number comes out of the lane's OWN message rather than a second boot,
    # which costs a second and would only ask whether two callers of
    # m.self.builtins() agree. What is planted here is whether the check can
    # go red at all, which the real sheet answered once by drifting and will
    # not answer again now that the number is right.
    probe = builtin_count_findings(SHEET, _builtins(0))
    expect(len(probe) == 1, "a builtin count of zero was NOT reported")
    registered = int(probe[0].rsplit(" ", 1)[1])
    expect(
        builtin_count_findings(SHEET, _builtins(registered)) == [],
        "the true builtin count was reported as a finding",
    )
    expect(
        len(builtin_count_findings(SHEET, _builtins(registered - 1))) == 1,
        "a builtin count one short of the engine was NOT reported",
    )
    expect(
        len(builtin_count_findings(SHEET, "no claim about builtins here")) == 1,
        "deleting the builtin claim silenced its check",
    )
    expect(
        any(
            "its own spelling" in finding
            for finding in operator_word_findings(SHEET, _operators([*live, "truth"]))
        ),
        "a table row naming a plain spelling was NOT reported",
    )
    expect(
        len(operator_word_findings(SHEET, "S has some operator words")) == 1,
        "deleting the operator-word claim silently disabled its check",
    )

    # NEAR MISS: the bang ladder both ways, and the two shapes that must NOT
    # fire. Library heads carry these, so no engine is needed.
    expect(
        near_miss_findings(SHEET, "`ws-sample!` draws from it") == [],
        "a real library head was reported as a near miss",
    )
    expect(
        len(near_miss_findings(SHEET, "`ws-sample` draws from it")) == 1,
        "a dropped bang on a library head was NOT reported",
    )
    expect(
        len(near_miss_findings(SHEET, "`car-atom!` takes the head", {"car-atom"})) == 1,
        "a bang wrongly added to an engine head was NOT reported",
    )
    expect(
        near_miss_findings(SHEET, "`not-a-head-at-all-xyz` is prose") == [],
        "a head-shaped token with no bang variant was reported",
    )
    expect(
        near_miss_findings(SHEET, "`engine/metta.pl` and `lib/lib_soft/`") == [],
        "a path was read as a call head",
    )

    for failure in failures:
        print(failure, file=sys.stderr)
    print(f"llms selftest: {cases} planted case(s), {len(failures)} failure(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
