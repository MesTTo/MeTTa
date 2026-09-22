"""Purpose: refuse a file-relative path expression that no longer resolves.

`b54dea73` renamed the chapter-19 C artifacts on 2026-08-27 and left three
consumers holding the old directory. Each was found separately, months apart, by
somebody noticing a test skip: `test_benchmarks.py` and
`benchmarks/configuration.py` under finding 26, and
`tests/.../test_c_handle_crossing.py` under finding 35, which survived the
repair of the other two because nothing asked the question in general. A path
that stopped resolving turns a guard into a permanent skip, and a permanent skip
reports success.

Grepping for the literal cannot do this. `examples/integration/c_extension` was
renamed while `extensions/python/examples/integration/` still exists, so the
same word is stale in one place and current in seven others. So each expression
is EVALUATED instead: `ast` folds `Path(__file__).resolve().parents[N] / "a" /
"b"` into a real path and the path is asked whether it exists.

A path that is CREATED at runtime rather than read has not stopped resolving and
is not a finding. It says so in place, on the same line or the one above:

    fixture = Path(__file__).resolve().parents[2] / "out" / "built.so"  # artifact-path-created

The door is deliberate. A wall with no door gets the lane disabled the first
time somebody writes an output path; a door that has to name itself keeps the
next stale constant visible.

Assumes: a checkout of this repository, and Python's own `ast`.
Guarantees:
  - a file-relative path expression naming something that does not exist fails
    the run, with the file, the line, and the path it folded to
    [tested: tests/checks/check_artifact_paths_selftest.py; commit=1b689c7f4ce1be7fd151c0bd5b7ef017c4c12e9f]
  - an expression marked `artifact-path-created` is not a finding, so a runtime
    output path does not have to disable the lane
    [tested: tests/checks/check_artifact_paths_selftest.py; commit=1b689c7f4ce1be7fd151c0bd5b7ef017c4c12e9f]
Fails when: an expression's segments are not literals, which it skips rather
  than guessing; a computed path is outside what this can decide.
Open Obligations:
  To Do: None
  Hacks: None
  Future Enhancements: None
"""

from __future__ import annotations

import ast
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OPT_OUT = "artifact-path-created"


def ignored(root: Path, sources: list[Path]) -> set[Path]:
    """Which of these git treats as ignored, and so as not this tree's content.

    Asked rather than listed. A hand-written skip list held `/ai-tmp/`,
    `/.claude/`, `/node_modules/`, `/build/`, `/.git/` and `/.mutmut/`, and
    went stale the moment a battery tree appeared beside them: `ai-battery-2`
    and `ai-battery-3` are ignored by .gitignore and were walked anyway, so the
    lane reported their copies' relative paths as unresolved. Every name on
    that list is already an ignore rule, which makes the list a second
    description of one fact.

    A root that is not a repository ignores nothing, which is the answer the
    selftest needs: it plants its fixture in a temporary tree and expects the
    walk to reach it.

    Time: one `git check-ignore` over the whole batch, against one substring
    test per path per pattern.
    """
    if not (root / ".git").exists():
        # Not a repository, so it has no ignore rules and nothing is skipped.
        # This is the selftest's case: it plants its fixture in a temporary
        # tree that happens to sit under ai-tmp/, and the old skip list got
        # this right by testing names RELATIVE to the root under examination.
        return set()
    answer = subprocess.run(
        ["git", "-C", str(root), "check-ignore", "--stdin", "-z"],
        input="\0".join(str(source) for source in sources),
        capture_output=True, text=True, check=False,
    )
    return {Path(name) for name in answer.stdout.split("\0") if name}


def folded(node: ast.BinOp, source: Path) -> Path | None:
    """Fold a `parents[N] / "a" / "b"` chain into the path it names, or None."""
    parts: list[str] = []
    current: ast.expr = node
    while isinstance(current, ast.BinOp) and isinstance(current.op, ast.Div):
        right = current.right
        if not (isinstance(right, ast.Constant) and isinstance(right.value, str)):
            return None
        parts.append(right.value)
        current = current.left
    if not (isinstance(current, ast.Subscript) and isinstance(current.slice, ast.Constant)):
        return None
    text = ast.unparse(current)
    if "__file__" not in text or "parents" not in text:
        return None
    base = source.resolve()
    for _ in range(current.slice.value + 1):
        base = base.parent
    for segment in reversed(parts):
        base = base / segment
    return base


def findings(root: Path) -> list[str]:
    """Every folded path that does not exist and did not opt out."""
    out: list[str] = []
    sources = sorted(root.rglob("*.py"))
    skipped = ignored(root, sources)
    for source in sources:
        if source in skipped or ".git" in source.parts:
            continue
        try:
            text = source.read_text(encoding="utf-8")
            tree = ast.parse(text)
        except (OSError, SyntaxError, UnicodeDecodeError):
            continue
        lines = text.splitlines()
        seen: set[int] = set()
        for node in ast.walk(tree):
            if not (isinstance(node, ast.BinOp) and isinstance(node.op, ast.Div)):
                continue
            if node.lineno in seen:
                continue
            path = folded(node, source)
            if path is None or path.exists():
                continue
            window = "\n".join(lines[max(0, node.lineno - 2) : node.end_lineno])
            if OPT_OUT in window:
                continue
            seen.add(node.lineno)
            name = source.relative_to(root)
            out.append(f"{name}:{node.lineno}: path does not resolve: {path}")
    return out


def main() -> int:
    """Report every stale file-relative path expression."""
    problems = findings(ROOT)
    for problem in problems:
        print(f"  {problem}")
    print(f"artifact-paths: {len(problems)} finding(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
