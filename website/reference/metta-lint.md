# `metta.lint`

Source: `extensions/python/metta/lint.py`.

> Diagnose declarations, equations and calls, and apply the repairs.

The entries below reproduce the source signatures and docstrings.

## `Skipped`

```python
class Skipped:
```

> One finding a repair pass did not apply, and why.

## `Repair`

```python
class Repair:
```

> What one repair pass did to one target.
>
> `applied` are the findings whose remedy was written, `skipped` the rest
> with their reasons, and `refused` is the one condition that stops the
> whole target rather than one finding: a file whose bytes changed since
> lint read them. `written` says whether anything reached the disk.

### `Repair.remaining`

```python
def remaining(self) -> int:
```

> How many findings this pass left standing.

## `lint`

```python
def lint(space) -> list[Finding]:
```

> Diagnose a space and return an empty list when no check fires.
>
> One of nine observability methods, the one for the silently-wrong
> class; rows.why() explains one empty answer, and the guide's
> observability page maps the family. space may be a context or a space.

## `lint_file`

```python
def lint_file(path: str | os.PathLike[str], *, m=None) -> list[Finding]:
```

> Diagnose one source file, each finding anchored to its line.
>
> The file loads into a scratch space and lint() runs there; every
> finding whose atom alpha-matches a top-level form then carries
> {"file", "line", "column"} in its payload, recovered exactly from
> the reader's own verbatim form texts, so a tool prints path:line
> without the engine ever tracking positions on its hot path. A
> finding about an atom no single form wrote, or one a form computed,
> stays unanchored rather than guessed. m may be a context or a space.
>
> Every finding also carries "digest", the sha256 of the bytes read
> here, which is what fix_file() compares against before writing.

## `apply`

```python
def apply(space, findings: list[Finding] | None = None) -> Repair:
```

> Write every machine remedy of FINDINGS into SPACE, and say what it left.
>
> A space is a multiset, so the two acts are exactly remove and add: a
> `replace` remedy removes the stored atom and adds its replacement, a
> removal remedy removes it and adds nothing, and an `edit` remedy adds
> the atom it names. Its longhand is that pair of calls per finding:
>
>     m.remove(finding.atom)
>     m.add(finding.remedy.replace[1])
>
> findings defaults to lint(space), so `apply(m)` is diagnose-and-repair.
> Only "machine" remedies are written; everything else comes back in
> `skipped` with its reason, which is what `cargo fix` does with rustc's
> non-MachineApplicable suggestions.

## `fix_file`

```python
def fix_file(
    path: str | os.PathLike[str],
    findings: list[Finding] | None = None,
    *,
    m=None,
) -> Repair:
```

> Rewrite one source file with the machine remedies its findings carry.
>
> A file finding is applied only where its line still holds exactly the
> form the finding stands on, so a stale anchor writes nothing. Edits are
> spliced from the end of the file backwards, which is how a fix-it
> applier keeps earlier offsets valid, and two repairs over one form leave
> the second unapplied rather than writing over each other.
>
> The whole file is refused, with nothing written, when its bytes differ
> from the ones lint_file() read; the digest travels in each finding's
> payload and is this library's document version. LSP writes the same
> guard as OptionalVersionedTextDocumentIdentifier, whose version is the
> one the edit was computed against, and a held-then-stale diagnostic is
> exactly the case findings= drives.
>
> findings defaults to lint_file(path, m=m), so `fix_file(path)` is
> diagnose-and-repair; its longhand is that call plus the splice, which
> `python -m metta lint --fix` runs.

## `diagnostics`

```python
def diagnostics(findings: list[Finding]) -> list[dict[str, Any]]:
```

> Every finding as one LSP 3.17 Diagnostic object.
>
> `range` is zero-based, which is LSP's own convention against the
> 1-based line a finding carries, and covers the whole line when only the
> line is known; `code` is the finding kind, `source` is "metta", and
> `data` carries the remedy and the docs link, which LSP preserves between
> publishDiagnostics and textDocument/codeAction so a client turns the
> remedy into a CodeAction without asking the server again.
>
> Its longhand is reading the fields off each Finding.
