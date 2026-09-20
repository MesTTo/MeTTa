# One grammar, every highlighter
Goal: colour MeTTa in Pygments' world -- Sphinx, mkdocs, rich, IPython,
nbconvert, Jupyter -- from the TextMate grammar the site and the editor already
use, with a test that says the two agree rather than a claim that they do. Give
the notebook surface a one-line magic beside its cell magic. Find out, by
starting it, whether the upstream Jupyter kernel this package says it composes
with can run here.
Constraint: the grammar stays the one source, and the seven repositories that
reuse it are not asked to change. A second hand-kept copy of the token model is
the thing this exists to prevent.

## 2026-09-07

### Reading the grammar at import, rejected

Tried: a lexer that reads `website/.vitepress/metta.tmLanguage.json` when the
entry point loads it. One file, no generated artefact.
Rejected: `[tool.setuptools.package-data]` ships `*.pyi`, `shim.pl` and
`py.typed`, so `website/` is not in the wheel and the lexer would work in a
checkout and raise in an installed package -- which is the only place the entry
point matters. Shipping the grammar as package data would fix that and buy an
import-time JSON parse plus a regex translation in every consumer's process,
with nowhere to REFUSE a pattern Python cannot compile except that process.
Decided: generate `metta/_pygments.py` with `tools/pygmentsgen.py` and gate it
with `pygments-sync`, the contract `vocabgen.py`, `aiogen.py`, `reference.py`
and `initstubgen.py` already keep here. The translation then happens once, in a
place that can refuse, and the wheel carries plain Python.
Revisit if the grammar ever has to be read at run time by something other than
a highlighter, which would make it package data for its own reasons.

### The two orders, and why the anchored one is faithful

A TextMate rule list is scanned for the EARLIEST match anywhere ahead of the
cursor, ties broken by list order. A Pygments `RegexLexer` tries each rule
ANCHORED at the cursor, in order, first match wins. Where anything matches at
the cursor the two agree, because the earliest match is then the cursor itself
and the tie-break is the same list order; where nothing does, TextMate skips
ahead and leaves the gap unscoped while a Pygments state has to consume
something. So the SCOPED spans agree exactly and only the chunking of unscoped
runs differs, which is why the comparison below is per character and treats
"no scope" as one value rather than comparing token counts.

### The oracle: shiki, not a reimplementation

Decided: `website/scripts/tokenise.mjs` goes through `shiki/core`,
`shiki/textmate` and `shiki/engine/oniguruma`, which is what VitePress
highlights this site with -- Microsoft's vscode-textmate over the real
Oniguruma in WebAssembly. Comparing against a reimplementation would only say
that two guesses agree. All three are documented subpath exports of the `shiki`
the website already depends on, so nothing new is installed and no transitive
package is reached into.
Rejected: a Python TextMate engine, which would have kept node out of the
lane. Both halves exist and install -- `textmate-grammar-python` 0.6.1, which
is a Python reimplementation of the TextMate algorithm over `onigurumacffi`
1.5.0, real Oniguruma through cffi -- so this was not a matter of availability.
It lost because it is a SECOND implementation of TextMate's semantics: a green
lane against it would say that two reimplementations agree, where a green lane
against shiki says a reader's Pygments colours match what this site shows. It
would also add a dependency to the `checks` extra, where the website's own
dependencies are already a prerequisite of the `docs` gate lane and CI already
runs `npm ci --prefix website` before the gate. Revisit if the site ever stops
highlighting through shiki, which would make shiki the second implementation
instead.

Two details the offsets depend on, found by probing rather than by reading:
vscode-textmate appends a newline to each line internally, so a token's
`endIndex` can be one past the line's own length (an empty line answers a
single token `[0, 1)`), and it never sees the line terminators at all. Ends are
clamped to the line and terminators are outside the comparison.

### `re.ASCII` was wrong, and the lane said so on its first run

Tried: `flags = re.MULTILINE | re.ASCII`, reasoning that Oniguruma under Ruby's
syntax has an ASCII `\s` and Python's is Unicode-aware.
-> The first parity run reported one disagreement, at the first probe:

    probe: a non-breaking space is not whitespace to Oniguruma:2:4:
    the grammar says Token.Literal.Number.Integer and the lexer says None
    for '1', in ...(f 1)\n(f<nbsp>1)...

so the grammar scoped `1` in `(f<nbsp>1)` as a number and the lexer did not.
The prediction was backwards: vscode-textmate's Oniguruma is Unicode-aware.

Measured, with `website/scripts/tokenise.mjs` against the same pattern under
Python's `re`, over every codepoint below U+3001 that `str.isspace()` accepts
plus U+001C-U+001F, U+0085, U+00A0, U+180E, U+200B, U+2060 and U+FEFF, each in
`(f<c>1)`:

| Python's flags | codepoints where the two disagree |
| --- | --- |
| `re.MULTILINE` | 4: U+001C, U+001D, U+001E, U+001F |
| `re.MULTILINE \| re.ASCII` | 19: every Unicode space |

The four are the ASCII file, group, record and unit separators: `str.isspace()`
is Unicode's White_Space property PLUS those four, and Oniguruma's `\s` is
White_Space alone.

The same probe for `\d`, over 455 codepoints including every digit Python's
Unicode `\d` accepts: `re.MULTILINE` disagrees on 30, `re.ASCII` on 410. The 30
are recently assigned digits (U+10D40.., U+1E4F0..) that this build of
Oniguruma's tables predate, so that difference is a Unicode VERSION skew
between two engines rather than a difference in meaning, and no rewrite can pin
it.

Decided: `re.MULTILINE` alone, and `\s` TRANSLATED rather than copied. The
generator writes the set out from the running Python's own Unicode tables, less
those four, so it follows a Python upgrade instead of rotting; the substitution
is class-context aware, and `\S` inside a character class is refused because
Python cannot spell a negated set inside a positive one. The four separators
are in the probe file, so the lane fails if the translation is removed.
Open: the 30 digit codepoints are outside the comparison because they are
outside the corpus and the probes. The lane's claim is what it measures --
these two tokenise the corpus and the probes identically -- and not more.

### The result

    sh tools/check.sh pygments-sync tokenisation tokenisation-selftest   -> 0
    521 sources, 874333 characters, 0 disagreement(s)

521 sources is every `.metta` file `git ls-files` reports plus the eleven named
probes plus one of them again with CRLF endings. About 3 seconds.

Planted, and each reported: the doctag rule deleted from the generated module
-> 11 disagreements and `pygments-sync` red; a grammar scoping `?x` instead of
`$x` -> reported; a group whose scope no token names -> the generator refuses
by name; a pattern holding `\h` -> refused as untranslatable.

### Where the token for each group came from

Not by translating the scope path, which would put `@doc` under `Keyword`
because its scope is `keyword.other.documentation`. By asking what token
Pygments' OWN lexers give that lexical role: `Comment.Single` for a `;` line
comment, `Name.Variable` for a sigil-prefixed variable, the
`Name.Builtin.Pseudo` that `self` and `this` get for `&self`, `Name.Decorator`
for an `@`-prefixed annotation -- which is also the purple the grammar's own
comment says metta-lang.dev gives `@doc`, since `Name.Decorator` is `#AA22FF`
in Pygments' default style. The two paren scopes share `Punctuation` because a
style distinguishing them would have nothing to say.

### Tuples, not lists, for the lexer's three lookup attributes

Tried: `aliases`, `filenames` and `mimetypes` as the lists Pygments' own lexers
declare. -> ruff's RUF012 (mutable class attribute). Annotating them
`ClassVar[list[str]]` answers RUF012 -> ty reports four
`invalid-attribute-override`, because Pygments' base class declares them as
instance attributes.
Decided: tuples. Measured that all four consumers read them by `in` or by
iterating -- `get_lexer_by_name`, `get_lexer_for_filename`,
`get_lexer_for_mimetype` and `get_all_lexers` each answer `MettaLexer` with
tuples in place. `tokens` stays a dict and carries a reasoned suppression,
since `RegexLexerMeta` compiles it once per class into `_tokens` and no
instance mutates it.

### `%metta`: one registration, two faces

Decided: `magic_kind="line_cell"`, IPython's own form for a name that has both,
which is how `%time` and `%%time` stay one magic. The asymmetry is IPython's
and is worth saying out loud: the LINE is the argument line in both forms, and
the argument is not the same thing -- for `%metta` it is the program, for
`%%metta` it names a space. So the line form has no room to name a space, and
`use(m)` is the rung below it. An empty `%metta` raises IPython's own
`UsageError`, naming both spellings, rather than running the empty program.

### The kernel: what it needs, and what it got

Section 10 of `docs/journal/2026-09-06-the-python-ecosystem-as-faces-of-the-engine.md`
said the upstream kernel "rides on the `metta` console script, which keeps
upstream's launcher contract for exactly this reason". That row is superseded
by this entry: it is wrong, and starting the kernel is what said so.
Measured, at `trueagi-io/jupyter-petta-kernel@b33e45ea`: `petta_jupyter/kernel.py`
puts `$PETTA_PATH/python` on `sys.path` at import, does `from petta import
PeTTa`, and calls `PeTTa(verbose=False)` once and `load_metta_file(path)` per
cell. It never runs a console script. Upstream's `PeTTa.__init__` consults
`$PETTA_PATH/src/main.pl` and `$PETTA_PATH/python/helper.pl` through janus.

Three runs, in `tests/checks/check_jupyter_kernel.py`:

    against this fork's tree       -> ImportError: No module named 'petta'
    against upstream at the pin    -> one MeTTa cell answered 3
    against this engine + adapter  -> one MeTTa cell answered 3

The adapter is fifteen lines and bridges two names: `PeTTa(verbose=False)` is
`MeTTa()` and `load_metta_file(path)` is `Space.load(path)` flattened to
strings. So the gap between the upstream kernel and this engine is a NAME gap
and not a semantic one, and that is the measurement worth having.

Rejected: shipping the adapter as a `petta` module. That is exactly the legacy
path the 2026-08-27 ruling removed, and the kernel's hook is the module NAME,
so there is no spelling of it that is not upstream compatibility. It stays a
fixture of the lane. Revisit if upstream ever lets a host name the module it
imports.

What this package does give the kernel is the lexer. The kernel's
`language_info` says `mimetype: text/x-metta` and `pygments_lexer: scheme`,
which is the fallback a language with no Pygments lexer takes; `text/x-metta`
now resolves, so an installed `pymetta` colours a MeTTa cell as MeTTa in every
front end that asks Pygments.

The launcher contract the row named is real, and is this fork's own rather than
the kernel's: `metta/cli.py` resolves an upstream `src/main.pl` tree as well as
this one, and the lane checks it with no network at all -- `METTA_PATH=<upstream>
metta program.metta` answered 3.

    sh tools/check.sh kernel   -> 0, about 23 seconds, 0 problem(s)

Open: the lane is REPORT because it fetches from github.com and a gate that
reaches the network fails for reasons that are not the tree. The `kernel` job
in `.github/workflows/checks.yml` runs the script DIRECTLY rather than through
`sh tools/check.sh kernel`, because a REPORT failure is forgiven by the driver and
would report a dead kernel as a green job.
