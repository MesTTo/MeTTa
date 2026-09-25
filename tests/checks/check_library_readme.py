"""Purpose: hold lib/README.md to the library pack it documents and the corpus it quotes.

lib/README.md is the pack's front page, and a showcase: every library gets a
worked example. An example written for a page is a second description nothing
checks, and the ones the root page carried at 60e9df0ce said lib_roman was about
Roman numerals and lib_measure counted instructions. So each example is QUOTED
from a corpus program that exercises the library, which the examples lane runs,
and this lane holds the quote to its program. Four things on the page are
derived rather than written, and each is checked:

  ROSTER    an entry for every `lib_*` directory and every directory a
            `pkg.metta` manifest makes a library, and for nothing else; the
            count the opening sentence states, and each section's count in the
            section table, equal the entries.
  HEADS     every head an entry's table lists is spelled in a source of that
            library or of a library it requires. Spelled, not defined: this is
            the claim the page makes, and it catches a head renamed or removed.
  EXAMPLES  each entry cites one corpus file and a line range in GitHub's
            `#Lm-Ln` spelling, which is how embedme cites an excerpt for the
            same job [source 2026-09-25T15:20:54+10:00:
            https://github.com/zakhenry/embedme/blob/master/src/embedme.lib.ts
            getReplacement], and the fence under the citation is those lines
            less the ones that are only a comment, the corpus-coverage lane's
            definition of one. The range starts and ends on a line of code, so
            the highlighted lines are the example. The fence is `metta`, which
            the readme-fences lane runs on a fresh engine in a fresh directory,
            unless the excerpt could not run there, and then it is `text`,
            which nothing runs: it names one of that lane's non-hermetic
            marks, which the lane refuses to run, or the corpus's own
            `_fixtures/`, which a fresh directory does not hold. The corpus
            program runs either way.
  SUPERSET  the table of libraries that need a kernel whose syntax is a
            superset of PeTTa's. A library needs one when a source it loads, or
            a library it requires, writes a spelling upstream PeTTa reads as
            data: a sequence variable (`spaces:metta_seq_present/1`, the
            engine's own test), or a type form headed by reserved type syntax
            other than `->` (`metta_engine:type_alias_form_head/1`) or by `|`
            or `Annotated`, the two heads the engine's type readers recognise
            inline. The sources are READ by the engine's reader and never run.

`--write` refreshes what a machine can decide: it fills an empty fence from its
range, moves a range whose excerpt moved in its file, sets each fence's info
string, and rewrites the superset table. It refuses an excerpt whose text
changed, because the old range may now end inside a form, and only a person can
say where the example should stop.

Assumes:
  - the engine boots from this checkout with `swipl` on PATH, and the examples
    component is checked out at `examples/`.
Guarantees:
  - a library without an entry, a listed head no source spells, an entry
    without a worked example, a fence that is not its cited lines, a range that
    does not start and end on code, an unrunnable excerpt fenced to run and a
    runnable one fenced not to, a superset table that disagrees with the
    libraries' sources, and a section or opening count that disagrees with the
    entries each fail the lane and name the library [tested
    2026-09-25T16:13:37+10:00: tests/checks/check_library_readme_selftest.py]
  - `--write` fills an empty fence and follows a moved excerpt, and refuses a
    changed one [tested 2026-09-25T16:13:37+10:00:
    tests/checks/check_library_readme_selftest.py]
Fails when: a library starts writing an extension spelling the engine names
  nowhere this lane reads, such as a new type head recognised inline the way `|`
  and `Annotated` are; the table then omits that library until the head is
  added to INLINE_TYPE_HEADS.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
# The sys.path line above is what makes these importable.
from bounded_spawn import bounded
from check_readme_fences import NOT_HERMETIC

#: Derived, not counted, as check_readme_fences.py derives it.
ROOT = next(parent for parent in Path(__file__).resolve().parents
            if (parent / "engine").is_dir() and (parent / "lib").is_dir())
PAGE = Path("lib/README.md")
MANIFEST = "pkg.metta"
#: The branch every component publishes, the one tools/components.sh fetches.
BRANCH = "main"

#: What stops an excerpt running where readme-fences runs a fence: a mark that
#: lane refuses to run, or the corpus's input directory, which corpus-coverage
#: likewise reads as inputs rather than programs.
UNRUNNABLE = (*NOT_HERMETIC, "_fixtures/")

#: Type heads the engine reads inline rather than through
#: metta_engine:type_alias_form_head/1: a union at engine/metta/type_unions.pl
#: (`Head == '|'`) and a refinement at engine/metta/terms.pl (`Head == 'Annotated'`).
INLINE_TYPE_HEADS = ("'|'", "'Annotated'")

BEGIN = "<!-- begin generated superset libraries (tests/checks/check_library_readme.py --write) -->"
END = "<!-- end generated superset libraries -->"

HEADING = re.compile(r"^(?P<level>#{2,3}) (?P<title>.+?)\s*$", re.MULTILINE)
CITATION = re.compile(r"\]\((?P<url>[^)\s#]+)#L(?P<start>\d+)-L(?P<end>\d+)\)")
FENCE = re.compile(r"```(?P<info>[\w-]*)\n(?P<body>.*?)```", re.DOTALL)
SECTION_ROW = re.compile(r"^\| \[(?P<section>[^\]]+)\]\(#[^)]*\) \| (?P<count>\d+) \|$", re.MULTILINE)
HEAD_ROW = re.compile(r"^\| (?P<feature>[^|]+?) \| (?P<heads>.+) \|$", re.MULTILINE)
#: A code span holds no escapes in Markdown, except that a table cell escapes
#: its pipe even there, so `\|-` is the head `|-`.
CODE_SPAN = re.compile(r"`([^`]+)`")
TOTAL = re.compile(r"supplies (?P<count>\d+) libraries")

#: One engine process reads every library source and prints, per file, whether
#: it writes an extension spelling and what it imports or requires. `~w` of a
#: string is its text, so every field is tab-separated plain text.
_QUERY = """
ensure_loaded('engine/qlf_boot.pl'), ensure_loaded('engine/metta.pl'),
forall(member(F, {files}),
  catch(( read_file_to_string(F, S, []),
          filereader:metta_host_tagged_parse(S, Parsed),
          forall(( member(P, Parsed), arg(3, P, T) ),
                 ( ( spaces:metta_seq_present(T) -> format("EXT\\t~w~n", [F]) ; true ),
                   ( T = [':', _, Type], sub_term(Sub, Type), is_list(Sub), Sub = [H|_], atom(H),
                     ( metta_engine:type_alias_form_head(H), H \\== '->'
                     ; memberchk(H, [{inline}]) )
                   -> format("EXT\\t~w~n", [F]) ; true ),
                   ( ( T = ['import!', _, X] ; T = ['=', [package, requires], X] )
                   -> ( X = [library, N], atom(N) -> format("LIBRARY\\t~w\\t~w~n", [F, N])
                      ; X = [library, R], string(R) -> format("PACKFILE\\t~w\\t~w~n", [F, R])
                      ; atom(X), \\+ sub_atom(X, 0, 1, _, '&') -> format("LIBRARY\\t~w\\t~w~n", [F, X])
                      ; string(X) -> format("FILE\\t~w\\t~w~n", [F, X])
                      ; format("OTHER\\t~w\\t~q~n", [F, X]) )
                   ; true ) ))),
        E, format("ERROR\\t~w\\t~q~n", [F, E])))
"""


@dataclass(frozen=True)
class Entry:
    """One `### name` entry: its section and the text it spans in the page."""

    name: str
    section: str
    start: int
    end: int


@dataclass(frozen=True)
class Example:
    """One entry's citation and the fence under it, as positions in the page."""

    path: str
    start: int
    end: int
    citation: re.Match[str]
    fence: re.Match[str]


@dataclass(frozen=True)
class Pack:
    """What one engine read of the pack's sources says about each library.

    `files` is every source a library's manifest loads, closed over the paths
    they import; `requires` is every library they name; `writes` holds when one
    of those sources writes a spelling upstream PeTTa reads as data.
    """

    files: dict[str, frozenset[str]]
    requires: dict[str, tuple[str, ...]]
    writes: dict[str, bool]
    problems: tuple[str, ...]

    def required(self, name: str) -> list[str]:
        """Every library `name` requires, directly or through another."""
        found: list[str] = []
        pending = list(self.requires.get(name, ()))
        while pending:
            dependency = pending.pop()
            if dependency not in found:
                found.append(dependency)
                pending += self.requires.get(dependency, ())
        return sorted(found)


def roster(lib: Path) -> list[str]:
    """Every directory the page owes an entry, in name order.

    The `lib_*` directories are the pack's own convention, and a `pkg.metta` is
    what makes a directory a library the engine enters, which takes in
    minimal_metta_lib; lib_gitimport has no manifest and is still a directory of
    the pack a reader will look for.
    """
    return sorted(directory.name for directory in lib.iterdir()
                  if directory.is_dir()
                  and (directory.name.startswith("lib_") or (directory / MANIFEST).is_file()))


def corpus_url(root: Path) -> str:
    """The examples component's published blob URL, read from .gitmodules."""
    answered = subprocess.run(
        ["git", "config", "-f", str(root / ".gitmodules"), "submodule.examples.url"],
        capture_output=True, text=True, check=False,
    )
    url = answered.stdout.strip()
    if answered.returncode != 0 or not url:
        msg = f"{root / '.gitmodules'} names no examples component URL"
        raise RuntimeError(msg)
    return f"{url.removesuffix('.git')}/blob/{BRANCH}/"


def entries(text: str) -> list[Entry]:
    """Each `### ` entry, with the `## ` section above it."""
    found: list[Entry] = []
    section = ""
    headings = list(HEADING.finditer(text))
    for index, heading in enumerate(headings):
        if heading.group("level") == "##":
            section = heading.group("title")
            continue
        end = headings[index + 1].start() if index + 1 < len(headings) else len(text)
        found.append(Entry(heading.group("title").strip("`"), section, heading.end(), end))
    return found


def is_code(line: str) -> bool:
    """A line that is neither blank nor only a comment."""
    stripped = line.strip()
    return bool(stripped) and not stripped.startswith(";")


def excerpt(lines: list[str], start: int, end: int) -> str:
    """Lines start..end, one-based and inclusive, less the comment-only lines.

    Each run of blank lines those leave behind is kept as one.
    Time: end - start + 1 line tests. Space: the kept lines.
    """
    kept: list[str] = []
    for line in lines[start - 1:end]:
        if line.lstrip().startswith(";") or (not line.strip() and kept and not kept[-1]):
            continue
        kept.append(line.rstrip())
    return "\n".join(kept) + "\n"


def normalised(body: str) -> str:
    """A fence body with trailing whitespace dropped from each line."""
    return "\n".join(line.rstrip() for line in body.splitlines()) + "\n"


def fenced(excerpted: str) -> str:
    """The info string an excerpt is fenced with: `metta` when readme-fences can run it."""
    return "text" if any(mark in excerpted for mark in UNRUNNABLE) else "metta"


def example(text: str, entry: Entry, base: str) -> tuple[Example | None, str | None]:
    """The entry's one corpus citation and its fence, or why it has none."""
    citations = [match for match in CITATION.finditer(text, entry.start, entry.end)
                 if match.group("url").startswith(base)]
    if not citations:
        return None, (f"{entry.name} has no worked example: cite its corpus program as "
                      f"({base}<path>#Lm-Ln) and put the fence under it")
    if len(citations) > 1:
        return None, f"{entry.name} cites {len(citations)} corpus excerpts; an entry shows one"
    citation = citations[0]
    fence = FENCE.search(text, citation.end(), entry.end)
    if fence is None:
        return None, f"{entry.name} cites an example and has no fence under it"
    return Example(citation.group("url")[len(base):], int(citation.group("start")),
                   int(citation.group("end")), citation, fence), None


def example_findings(root: Path, text: str, entry: Entry, base: str) -> list[str]:
    """What is wrong with one entry's example."""
    found, problem = example(text, entry, base)
    if found is None:
        return [problem] if problem else []
    source = root / "examples" / found.path
    if not source.is_file():
        return [f"{entry.name} cites {found.path}, which is not in the examples component"]
    lines = source.read_text(encoding="utf-8").splitlines()
    where = f"{entry.name}'s example, lines {found.start}-{found.end} of {found.path}"
    if not 1 <= found.start <= found.end <= len(lines):
        return [f"{where}: the file has {len(lines)} lines"]
    problems = [f"{where}: line {number} is not code, so the range does not start and end on the example"
                for number in sorted({found.start, found.end}) if not is_code(lines[number - 1])]
    wanted = excerpt(lines, found.start, found.end)
    if "```" in wanted:
        problems.append(f"{where}: the excerpt holds a code fence, which would end this one early")
    if normalised(found.fence.group("body")) != wanted:
        problems.append(f"{where}: the fence is not those lines less their comments; run "
                        f"tests/checks/check_library_readme.py --write")
    if found.fence.group("info") != fenced(wanted):
        problems.append(
            f"{where}: fenced `{found.fence.group('info')}`, and an excerpt "
            + ("naming a file the corpus holds or a network address is fenced `text`, "
               "since readme-fences cannot run it" if fenced(wanted) == "text"
               else "readme-fences can run is fenced `metta` so that it does"))
    return problems


def head_findings(lib: Path, text: str, entry: Entry, pack: Pack) -> list[str]:
    """Every head the entry's table lists that no source it can come from spells.

    Time: one read of the library's and its requirements' sources, then H
    substring searches over them for H listed heads.
    """
    stop = next((match.start() for match in CITATION.finditer(text, entry.start, entry.end)),
                entry.end)
    heads = [span.replace("\\|", "|")
             for row in HEAD_ROW.finditer(text, entry.start, stop)
             if row.group("feature") != "Feature"
             for span in CODE_SPAN.findall(row.group("heads"))]
    places = [lib / name for name in (entry.name, *pack.required(entry.name))]
    paths = {path for place in places if place.is_dir()
             for path in place.rglob("*") if path.suffix in {".metta", ".pl"}}
    paths |= {lib / path for path in pack.files.get(entry.name, ())}
    sources = "".join(path.read_text(encoding="utf-8", errors="replace") for path in sorted(paths))
    return [f"{entry.name} lists `{head}`, which no source it loads or requires spells"
            for head in heads if head not in sources]


def roster_findings(root: Path, text: str, found: list[Entry]) -> list[str]:
    """The entries against the directories, and the page's counts against both."""
    names = roster(root / "lib")
    written = [entry.name for entry in found]
    problems = [f"{name} is a library directory with no entry" for name in names
                if name not in written]
    problems += [f"the entry {name} names no library directory" for name in written
                 if name not in names]
    problems += [f"{name} has {written.count(name)} entries" for name in sorted(set(written))
                 if written.count(name) > 1]
    stated = TOTAL.search(text)
    if stated is None:
        problems.append("the opening no longer says how many libraries the pack supplies")
    elif int(stated.group("count")) != len(names):
        problems.append(f"the opening says {stated.group('count')} libraries and the pack has {len(names)}")
    per_section = {section: sum(entry.section == section for entry in found)
                   for section in dict.fromkeys(entry.section for entry in found)}
    rows = {row.group("section"): int(row.group("count")) for row in SECTION_ROW.finditer(text)}
    problems += [f"the section table says {section} holds {rows.get(section)}, and it holds {count}"
                 for section, count in per_section.items() if rows.get(section) != count]
    problems += [f"the section table names {section}, which holds no entry"
                 for section in rows if section not in per_section]
    return problems


def scan(lib: Path, engine_root: Path = ROOT) -> dict[str, list[tuple[str, str]]]:
    """Each library source, with the facts one engine process read from it.

    Keys are paths relative to `lib`; each fact is (kind, value), kind one of
    EXT, LIBRARY, PACKFILE, FILE, OTHER and ERROR as _QUERY prints them.
    """
    files = sorted(lib.rglob("*.metta"))
    listed = ",".join("'" + str(path).replace("\\", "\\\\").replace("'", "\\'") + "'"
                      for path in files)
    goal = _QUERY.format(files=f"[{listed}]", inline=", ".join(INLINE_TYPE_HEADS))
    finished = subprocess.run(
        bounded(["swipl", "-q", "-g", goal, "-t", "halt", "--", "extensions"]),
        cwd=engine_root, capture_output=True, text=True, check=False,
        stdin=subprocess.DEVNULL,
    )
    if finished.returncode != 0:
        detail = (finished.stderr or finished.stdout).strip().splitlines()
        msg = f"the engine did not read the library sources: {detail[-1] if detail else 'no output'}"
        raise RuntimeError(msg)
    facts: dict[str, list[tuple[str, str]]] = {str(path.relative_to(lib)): [] for path in files}
    for line in finished.stdout.splitlines():
        kind, _, rest = line.partition("\t")
        if kind not in {"EXT", "LIBRARY", "PACKFILE", "FILE", "OTHER", "ERROR"}:
            continue
        path, _, value = rest.partition("\t")
        facts.setdefault(str(Path(path).relative_to(lib)), []).append((kind, value))
    return facts


def read_pack(lib: Path, engine_root: Path = ROOT) -> Pack:
    """Every library's sources, requirements and superset spellings, from one read.

    Time: one engine boot plus a parse of every source, then S steps over the
    S sources each manifest reaches.
    """
    facts = scan(lib, engine_root)
    problems = [f"lib/{path}: the engine could not read it: {value}"
                for path, rows in facts.items() for kind, value in rows if kind == "ERROR"]
    problems += [f"lib/{path} imports or requires {value}, a shape this lane cannot follow"
                 for path, rows in facts.items() for kind, value in rows if kind == "OTHER"]
    libraries = sorted(directory.name for directory in lib.iterdir()
                       if (directory / MANIFEST).is_file())
    files: dict[str, frozenset[str]] = {}
    requires: dict[str, tuple[str, ...]] = {}
    writes: dict[str, bool] = {}
    for name in libraries:
        pending, seen, needed = [f"{name}/{MANIFEST}"], set(), set()
        while pending:
            path = pending.pop()
            if path in seen:
                continue
            seen.add(path)
            for kind, value in facts.get(path, []):
                if kind == "LIBRARY":
                    needed.add(value)
                elif kind in {"FILE", "PACKFILE"}:
                    target = ((lib / value) if kind == "PACKFILE"
                              else (lib / path).parent / value).resolve()
                    if not target.is_file() or lib.resolve() not in target.parents:
                        problems.append(f"lib/{path} loads {value}, which is not a source of the pack")
                        continue
                    pending.append(str(target.relative_to(lib.resolve())))
        files[name] = frozenset(seen)
        requires[name] = tuple(sorted(needed))
        writes[name] = any(kind == "EXT" for path in seen for kind, _ in facts.get(path, []))
        problems += [f"{name} requires {dependency}, which is not a library of the pack"
                     for dependency in requires[name] if dependency not in libraries]
    return Pack(files, requires, writes, tuple(problems))


def superset(pack: Pack) -> dict[str, str | None]:
    """Each library needing the superset syntax, and the library it needs it through.

    The value is None where a source of the library's own writes the syntax.
    Time: at most L rounds of the requirement fixpoint over L libraries, each
    round O(L + R) for R requirements.
    """
    needs: dict[str, str | None] = {name: None for name, wrote in pack.writes.items() if wrote}
    changed = True
    while changed:
        changed = False
        for name in pack.writes:
            if name in needs:
                continue
            through = next((dependency for dependency in pack.requires[name]
                            if dependency in needs), None)
            if through is not None:
                needs[name] = through
                changed = True
    return dict(sorted(needs.items()))


def render(needs: dict[str, str | None], libraries: int) -> str:
    """The generated region's body.

    A row per library that needs the syntax, saying where it comes from, then
    how many of the rest do not.
    """
    rows = [f"{len(needs)} libraries need such a kernel:", "",
            "| Library | The superset syntax is in |", "|---|---|"]
    rows += [f"| `{name}` | "
             + ("its own source" if through is None else f"`{through}`, which it requires")
             + " |" for name, through in needs.items()]
    rows += ["", f"The other {libraries - len(needs)} write none of these spellings and "
                 "require no library that does."]
    return "\n".join(rows)


def region(text: str) -> tuple[int, int] | None:
    """Where the generated region's body sits, between its markers."""
    begin, end = text.find(BEGIN), text.find(END)
    if begin < 0 or end < begin or text.count(BEGIN) != 1 or text.count(END) != 1:
        return None
    return begin + len(BEGIN), end


def findings(root: Path = ROOT, engine_root: Path = ROOT) -> list[str]:
    """Everything wrong with the page, one finding each."""
    return page_findings(root, read_pack(root / "lib", engine_root))


def page_findings(root: Path, pack: Pack) -> list[str]:
    """Everything wrong with the page, given what the engine read of the pack."""
    text = (root / PAGE).read_text(encoding="utf-8")
    found = entries(text)
    base = corpus_url(root)
    problems = roster_findings(root, text, found) + list(pack.problems)
    for entry in found:
        problems += head_findings(root / "lib", text, entry, pack)
        problems += example_findings(root, text, entry, base)
    span = region(text)
    if span is None:
        problems.append(f"{PAGE} lacks exactly one generated superset region ({BEGIN} ... {END})")
    elif text[span[0]:span[1]].strip() != render(superset(pack), len(pack.writes)):
        problems.append(f"{PAGE}'s superset table disagrees with the libraries' sources; "
                        "run tests/checks/check_library_readme.py --write")
    return problems


def moved(lines: list[str], body: str) -> list[tuple[int, int]]:
    """Every code-bounded range of `lines` whose excerpt is `body`.

    Time: F * L candidate ranges for F lines equal to the body's first line and
    L equal to its last, each compared in O(range); the corpus files are under
    200 lines.
    """
    kept = body.splitlines()
    if not kept:
        return []
    firsts = [number for number, line in enumerate(lines, 1)
              if is_code(line) and line.rstrip() == kept[0]]
    lasts = [number for number, line in enumerate(lines, 1)
             if is_code(line) and line.rstrip() == kept[-1]]
    return [(first, last) for first in firsts for last in lasts
            if first <= last and excerpt(lines, first, last) == body]


def write(root: Path = ROOT, engine_root: Path = ROOT) -> list[str]:
    """Refresh the derived parts of the page; what could not be refreshed."""
    return write_page(root, read_pack(root / "lib", engine_root))


def write_page(root: Path, pack: Pack) -> list[str]:
    """Refresh the page from the pack the engine read; what could not be refreshed."""
    page = root / PAGE
    text = page.read_text(encoding="utf-8")
    base = corpus_url(root)
    refusals: list[str] = []
    # Last entry first, so an edit never moves a position still to be used.
    for entry in reversed(entries(text)):
        found, _ = example(text, entry, base)
        source = root / "examples" / found.path if found else None
        if found is None or source is None or not source.is_file():
            continue  # findings() names both, and nothing here can supply them
        lines = source.read_text(encoding="utf-8").splitlines()
        body = normalised(found.fence.group("body")) if found.fence.group("body").strip() else ""
        start, end = found.start, found.end
        held = 1 <= start <= end <= len(lines)
        if body and not (held and body == excerpt(lines, start, end)):
            spans = moved(lines, body)
            if len(spans) != 1:
                refusals.append(
                    f"{entry.name}: lines {start}-{end} of {found.path} no longer hold the "
                    f"fence's text ({len(spans)} places do); empty the fence to take those "
                    f"lines, or cite the lines the example should show")
                continue
            start, end = spans[0]
        elif not held:
            refusals.append(f"{entry.name}: {found.path} has no lines {start}-{end}")
            continue
        wanted = excerpt(lines, start, end)
        text = (text[:found.citation.start()] + f"]({base}{found.path}#L{start}-L{end})"
                + text[found.citation.end():found.fence.start()]
                + f"```{fenced(wanted)}\n{wanted}```" + text[found.fence.end():])
    refusals += pack.problems
    span = region(text)
    if span is None:
        refusals.append(f"{PAGE} lacks exactly one generated superset region to write")
    else:
        text = (text[:span[0]] + "\n" + render(superset(pack), len(pack.writes)) + "\n"
                + text[span[1]:])
    page.write_text(text, encoding="utf-8")
    return refusals


def main(argv: list[str] | None = None) -> int:
    """Check the page, or with --write refresh its derived parts first."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--write", action="store_true",
                        help="fill, move and re-fence examples and rewrite the superset table")
    arguments = parser.parse_args(argv)
    if arguments.write:
        for refusal in write():
            print(f"  {refusal}")
    problems = findings()
    for problem in problems:
        print(f"  {problem}")
    print(f"library-readme: {len(problems)} finding(s) over {len(roster(ROOT / 'lib'))} "
          f"library entries in {PAGE}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
