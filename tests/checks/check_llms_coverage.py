"""Purpose: enumerate public names missing from the consumer's root llms.txt.

Assumes: the checkout's Python seat and engine can supply their own rosters.
Guarantees: missing names, empty rosters and unavailable sources have distinct
  outcomes [tested: tests/checks/check_llms_coverage_selftest.py; commit=2abd24a121d519a0a2b33d35a6f3c6fe4e9f3562].
Decides: a door is an explicit export of a public Python module, a declared
  door key, a callable engine or carried library head, a CLI command path, or
  an advertised entry-point group. Re-exports are separate public paths;
  repeated MeTTa heads and entry-point groups are counted once. A name is
  mentioned by an exact token in visible text, not a substring or HTML comment.
  Python exports also accept their unqualified exported spelling. Door keys
  keep their owner, and CLI commands keep their complete command path, either
  in an invocation or as inline code beside the CLI's name in one paragraph.
Fails when: any required source is empty, unreadable or invalid; exit 2 refuses
  an incomplete count. Exit 1 means a counted backlog; exit 0 means none.
  tools/check.sh registers this as REPORT, so neither outcome blocks release.
Open Obligations:
  To Do: promotion to GATE requires the owner's decision after backlog review.
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import argparse
import ast
import re
import sys
import tomllib
from collections.abc import Callable, Iterable
from dataclasses import dataclass
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(ROOT / "extensions/python"), str(ROOT / "extensions/python/tools")]


@dataclass(frozen=True, order=True)
class PublicName:
    """One public identity and the spellings that name it to a consumer."""

    source: str
    name: str
    spellings: tuple[str, ...]


def require_names(source: str, names: Iterable[str]) -> set[str]:
    """Refuse a lost roster instead of certifying an empty comparison."""
    found = set(names)
    if not found or any(not isinstance(name, str) or not name.strip() for name in found):
        message = f"{source}: empty or invalid public roster"
        raise ValueError(message)
    return found


def exported_names(path: Path, module: str) -> list[PublicName]:
    """Read explicit __all__ without importing optional provider dependencies.

    Only a literal declaration is accepted. Any other write refuses instead
    of returning a partial roster after a future change in declaration syntax.
    Time and space: O(n), n = source AST nodes.
    """
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    references = [node for node in ast.walk(tree)
                  if isinstance(node, ast.Name) and node.id == "__all__"]
    declarations = [node for node in tree.body
                    if isinstance(node, (ast.Assign, ast.AnnAssign))
                    and any(isinstance(target, ast.Name) and target.id == "__all__"
                            for target in (node.targets if isinstance(node, ast.Assign)
                                           else [node.target]))]
    imports = [node for node in ast.walk(tree) if isinstance(node, ast.alias)
               and (node.asname or node.name) == "__all__"]
    if not references and not imports:
        return []
    if len(references) != 1 or len(declarations) != 1 or imports:
        message = f"{path}: __all__ is not one literal declaration"
        raise ValueError(message)
    value = ast.literal_eval(declarations[0].value)
    if not isinstance(value, (list, tuple)) or any(
        not isinstance(name, str) or not name.isidentifier() for name in value
    ):
        message = f"{path}: __all__ must contain Python identifiers"
        raise ValueError(message)
    return [PublicName("python", f"{module}.{name}", (f"{module}.{name}", name))
            for name in sorted(set(value))]


def python_exports(root: Path, members: Iterable) -> list[PublicName]:
    """Public modules declare exports; private implementation modules do not."""
    package = root / "extensions/python/metta"
    paths = []
    for path in sorted(package.rglob("*.py")):
        parts = path.relative_to(package).with_suffix("").parts
        if parts[-1] == "__init__":
            parts = parts[:-1]
        if any(part.startswith("_") for part in parts):
            continue
        paths.append((path, ".".join(("metta", *parts))))
    for member in members:
        paths.extend((member.directory / (module.replace(".", "/") + ".py"), module)
                     for module in member.modules if not module.startswith("_"))
    return [name for path, module in paths for name in exported_names(path, module)]


class ParserCaptured(BaseException):
    """Stop the CLI before argument validation or command dispatch."""


def cli_commands(main: Callable) -> set[str]:
    """Ask the real argparse builder, including nested commands and aliases.

    The patch is scoped to this synchronous call and always restored. Walking
    argparse's action tree costs O(a + c) time and space for actions a and
    command paths c; command implementations are never called.
    """
    parsers = []

    def capture(parser, *_args, **_kwargs):
        parsers.append(parser)
        raise ParserCaptured

    with patch.object(argparse.ArgumentParser, "parse_args", capture):
        try:
            main([])
        except ParserCaptured:
            pass
    if len(parsers) != 1:
        message = "CLI: main did not expose exactly one argument parser"
        raise ValueError(message)
    names = set()
    pending = [(parsers[0], "")]
    while pending:
        parser, prefix = pending.pop()
        for action in parser._actions:
            if isinstance(action, argparse._SubParsersAction):
                for name, child in action.choices.items():
                    command = f"{prefix} {name}".strip()
                    names.add(command)
                    pending.append((child, command))
    return require_names("CLI", names)


def entry_point_groups(manifests: Iterable[Path]) -> set[str]:
    """Read advertised groups from project metadata, never the installed env."""
    groups = set()
    for path in manifests:
        project = tomllib.loads(path.read_text(encoding="utf-8"))["project"]
        for group, entries in project.get("entry-points", {}).items():
            if entries:
                groups.add(group)
        for table, group in (("scripts", "console_scripts"), ("gui-scripts", "gui_scripts")):
            if project.get(table):
                groups.add(group)
    return require_names("entry-points", groups)


def public_roster() -> list[PublicName]:
    """Reuse the readers that own membership, rather than a documentation list."""
    from check_corpus_coverage import carried_heads
    from check_layering import members
    from check_llms_names import engine_vocabulary
    from doorgen import all_rows

    from metta.__main__ import main as cli_main

    workspace = members(ROOT)
    exports = python_exports(ROOT, workspace)
    require_names("Python exports", (row.name for row in exports))
    doors = require_names("door contracts", (row.key for row in all_rows(ROOT)))
    engine = require_names("engine", engine_vocabulary())
    libraries = require_names("carried library heads", carried_heads())
    groups = entry_point_groups([ROOT / "pyproject.toml",
                                 *(member.directory / "pyproject.toml" for member in workspace)])
    return sorted({*exports,
            *(PublicName("door", name, (name,)) for name in sorted(doors)),
            *(PublicName("metta", name, (name,)) for name in sorted(engine | libraries)),
            *(PublicName("cli", name, (f"python -m metta {name}",))
              for name in sorted(cli_commands(cli_main))),
            *(PublicName("entry-point", name, (name,)) for name in sorted(groups))})


def missing_names(roster: Iterable[PublicName], text: str) -> list[PublicName]:
    """Exact names in visible prose or code count, regardless of formatting.

    Time: O(s * t), s = distinct spellings, t = sheet length. Space: O(s + t).
    Search results are shared by re-exports so repeated names scan once.
    """
    rows = sorted(set(roster))
    require_names("combined", (row.name for row in rows))
    visible = re.sub(r"<!--.*?-->", "", text, flags=re.DOTALL).replace(r"\|", "|")
    cli_paragraphs = [paragraph for paragraph in re.split(r"\n\s*\n", visible)
                      if "`python -m metta`" in paragraph]
    cli_mentions = {" ".join(name.split()) for paragraph in cli_paragraphs
                    for name in re.findall(r"`([^`\n]+)`", paragraph)}
    found = {}
    for row in rows:
        for spelling in row.spellings:
            key = (row.source, spelling)
            if key not in found:
                # A dot qualifies Python exports but belongs to a MeTTa name.
                boundary = r"\w?!*<>=/+#.\-:|\\&%~" if row.source == "metta" else r"\w.\-:"
                if row.source == "python" and "." not in spelling:
                    boundary = r"\w\-"
                pattern = r"\s+".join(re.escape(part) for part in spelling.split())
                found[key] = re.search(
                    rf"(?<![{boundary}]){pattern}(?![{boundary}])", visible
                ) is not None
    return [row for row in rows
            if not (row.source == "cli" and row.name in cli_mentions)
            and not any(found[row.source, name] for name in row.spellings)]


def main() -> int:
    """Print the complete backlog; a refused measurement never prints a total."""
    try:
        roster = public_roster()
        missing = missing_names(roster, (ROOT / "llms.txt").read_text(encoding="utf-8"))
    except (Exception, SystemExit) as error:
        print(f"llms-coverage: REFUSED: {type(error).__name__}: {error}")
        return 2
    for row in missing:
        print(f"  {row.source}: {row.name} is not named in llms.txt")
    for source in sorted({row.source for row in roster}):
        total = sum(row.source == source for row in roster)
        absent = sum(row.source == source for row in missing)
        print(f"  {source}: {absent} undescribed / {total} public doors")
    print(f"llms-coverage: {len(missing)} undescribed / {len(roster)} public doors")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
