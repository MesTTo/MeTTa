# A template reads and writes

Goal: the same template that reads program text with holes into a program
renders answers to text, with format specs symmetric to the entry specs, so a
card, a reference page or a documentation section is a template over a catalog
query rather than a program that prints.

Constraint: the floor stays 3.12, so every rendering spelling has a keyword
face beside the 3.14 literal and neither may name `string.templatelib`; one
spec table serves both directions so they cannot drift; upstream PeTTa's
semantics decide what a rendered value looks like; the generator rewritten as
the proof must produce byte-identical output.

## 2026-09-07

### The prior art, and what each one settled

PEP 750's own rendering loop is the shape: for each item, `convert(value,
conversion)` then `format(converted, format_spec)`, with the literal segments
between. Measured on this box (3.14.4): that loop over `t"n={x} s={s!r}
f={x:>6}"` reproduces `f"n={x} s={s!r} f={x:>6}"` byte for byte, and over
`t"{x=}"` reproduces `f"{x=}"`, because the compiler folds the label into the
preceding segment and the loop writes segments whole. So the reading
direction's `_debug_fold`, which splits that label out to make it its own
atom, is exactly the thing rendering must NOT do
[source: https://docs.python.org/3.14/library/string.templatelib.html].

psycopg 3.3's t-string face gave the reading specs their shape (`i`, `l`, `q`
against `sym`, the default and `expr`), and its other half gave this one's:
`sql.Composed.as_string(conn)` renders the same composed object the connection
executes, so one object both composes and renders and the renderer needs the
context the composer had. That is why `{v:json}` goes through the engine's
codec rather than a Python one.

Common Lisp's printer settled the default. `princ`/`~A` writes a string's
characters for a reader; `prin1`/`~S` writes it so `read` inverts it. Python
inherited the pair as `str` and `repr`. A homoiconic language needs both, and
the two are `{v}` and `{v:sexp}` here.

PostgreSQL's `format()` is the same three roles on the writing side, `%I`,
`%L`, `%s`, which is where `quoted` comes from: `quote_literal` is exactly
"the value's text, as a string literal the parser reads back".

### Decided: the engine already owns both renderings, and they are asked for

The arbiter has a template renderer of its own. `format-args` interpolates
each argument through `metta_console_text/2`, which is "a string is its own
characters, anything else is `sdisplay`", and its comment names upstream's
`formatArgsString` as the source
[source: engine/metta/operators.pl:757-762]. `println!` and `repr` use
`sdisplay/2` alone [source: engine/metta/runtime.pl:220].

So the two rendering rules were not invented here:

- a bare hole is `metta_console_text/2`, the engine's `{}`;
- `{v:sexp}` is `sdisplay/2`, what `repr` answers and `parse` reads back.

Measured, Python against the engine over nine atom kinds
(`"hi"`, `42`, `3.5`, `foo`, `(f "hi" 1)`, `1r2`, `True`, `(a (b c))`,
`"a|b"`), comparing `render("{v}", v=parse(src))` with
`(format-args "{}" (src))` and `render("{v:sexp}", ...)` with `(repr src)`:
eight of nine agree exactly in both columns. The ninth is the boolean, where
this library writes `True` and the engine writes `true`; that is
`Grounded.__str__`'s deliberate choice of the source spelling, both read back
as the same atom, and the difference is now pinned by
`test_a_boolean_renders_its_source_spelling` rather than left to be
rediscovered. The two comparisons run as tests against the live engine rather
than against literals, so neither side can move alone.

Decided therefore: `format(atom, "")` stays `str(atom)`, Python's law, which
for a String atom is the quoted literal, while a BARE HOLE is the engine's
`{}`, the characters. The two are different doors and the one-sentence rule is
written in `llms.txt` and in `_console`'s own docstring.

### Decided: one table, two directions, and the refusal is derived

`_SPECS` carries every spec with the direction it works in and a gloss.
`_spec_list(direction)` builds the sentence a refusal uses and
`_spec_refusal(spec, shown, direction)` is the one refusal both doors raise,
so a spec of the wrong direction is refused as MISPLACED, naming the door that
owns it, and an unknown one names this direction's specs. Adding a spec to
either direction changes both messages without either being written twice.

Rejected: two spec tables, one per direction. It is the drift the brief names,
and the refusal text would have had to repeat the other side's vocabulary by
hand.

The sharing goes further than the table, because the FACES were the other
place two implementations could drift. `_Holes` is the sink both directions
fill: `_Assembly` turns a hole into an atom and `_Text` into text, and
everything else -- the three faces, nested composition, `{{`/`}}`, field
resolution, the positional-hole and unused-keyword refusals, the conversions
-- is written once. The debug fold is the sink's `prefix` method, which is the
one place the directions genuinely differ.

### Decided: a rendered hole that is not ours is Python's

An unknown spec at a READING hole is refused, because the hole becomes an atom
and Python's presentation specs make text. At a RENDERING hole the same specs
compose, because the hole IS text: `{n:.2f}` and `{name:<20}` fall through to
`format(value, spec)` and mean what they mean in an f-string, and only a spec
Python also refuses is refused. The direction check runs FIRST, and that
ordering is load-bearing rather than tidy: `format(datetime(2026, 9, 7),
"sym")` answers the four characters `sym`, because `strftime` passes text it
does not recognise through, so a door that fell through to the value would
render a reading spec instead of refusing it. Pinned by
`test_an_entry_spec_at_a_rendered_hole_names_the_reader`, which was
strengthened for exactly this after a planted defect passed the first version
of it.

### Decided: `__format__` is the third face, and it found a defect

`Atom.__format__` and `Grounded.__format__` already existed, so the rendering
table goes there rather than beside them: an empty spec stays `str(self)`, a
spec from the table is that rendering, anything else is Python's presentation
grammar as before. `f"{atom:sexp}"` and `format(rows, "table")` therefore
reach the same code as `render(t"{atom:sexp}")` with no import, and `Rows` and
`Answers` gained the same method.

Writing it found a defect in the shipped `Grounded.__format__`: it read
`self.value` before deciding anything, and a `Handle` is a Grounded species
whose value slot is deliberately unset, so `format(space, ">10")` raised
`'Space' object has no attribute 'value'`. The first version of this change
made the empty-spec case reach it too, which turned
`test_world_coverage_uses_the_annotated_effect` red. The slot is now read
through `getattr` and only when a spec needs it, which repairs the latent case
as well; `test_a_handle_formats_without_a_value_slot` covers both.

### Rejected: a `render` method ON the template

The brief asked for `Template.render(...)` "on the library's own template
object (the one `bind` reads)". There is no such object and there should not
be one. The reading door accepts a `TemplateLike` STRUCTURALLY -- the 3.14
class, a backport's object, a test double -- precisely so that the library
names no template class, and the 3.14 class cannot be given a method anyway:
measured, `Template.render = ...` answers `TypeError: cannot set 'render'
attribute of immutable type 'string.templatelib.Template'`. Shipping our own
template class to hang the method on would be a second mechanism for a face
that already has one, which the plan's own principle forbids and which the
3.12-floor design already rejected once when it declined to ship a backport.

Decided: the free function `metta.render(source, **values)` is the door, and
the method faces are on the things being RENDERED rather than on the template
-- `rows.render`, `answers.render`, and `__format__` on `Atom`, `Rows` and
`Answers`, which is Python's own protocol for "value plus format spec answers
text". `f"{rows:table}"` is then the method face with no method call at all.

### Decided: iteration lives in Python, and the reason is measured twice

`{for row in rows}...{end}` is not spellable, on two independent grounds.

Measured on 3.14.4: `t"{for row in rows}x{end}"` is a SyntaxError,
`t-string: expecting a valid expression after '{'`, because PEP 750's
interpolation is the f-string grammar and `for row in rows` is not an
expression. The keyword face would accept it, since
`string.Formatter().parse` answers a field named `for row in rows` and only
`get_field` then fails, so a loop would be a spelling the 3.12 face has and
the 3.14 face cannot parse. That alone ends it.

Measured, second and independent: a literal's values are evaluated when the
LITERAL is. `tpl = t"row {n}"` captures `n` at construction and rebinding `n`
afterwards does not change `tpl.interpolations[0].value`, so a per-item
template could not be re-bound per item even if the grammar allowed the loop.
A `Rows.render` that rendered its template once per row would therefore work
on the keyword face and be impossible on the literal face, which is the same
split the first measurement forbids.

Decided: the claim is one-level rendering. Iteration is a Python
comprehension, and the pieces compose two ways that both work on both floors:
a nested template renders into its host exactly as it splices at the reading
door, and `{parts:lines}` renders a list of templates or strings one to a
line. The report shape is in `llms.txt` and in
`test_a_report_is_a_template_over_a_query`.

Rejected: `Rows.render(template)` rendering once per row, for the reason
above. It stays the method face of `metta.render(source, rows=self)`, binding
the receiver as `rows`; `Answers.render` binds the same name rather than
`answers`, so a report written over an eager result renders the lazy view
unchanged.

### Decided: `{rows:table}` writes every row, and is Markdown

The table renders as a GitHub-flavoured pipe table, which is what every
generated page in this repository already writes, so `{coverage:table}` could
replace a hand-assembled table byte for byte. Cells escape a backslash, then a
pipe, and a newline becomes `<br>`, because a pipe-table row is one line
[source: https://github.github.com/gfm, example 200: "Include a pipe in a
cell's content by escaping it, including inside other inline spans"]; the
backslash-first order is what keeps a cell holding `\|` from reading as an
escape.

Decided: every row is written, where `__rich__` and `_repr_html_` stop at
`config.display_rows`. A terminal is being fitted; a document asked for the
rows. Said plainly in `llms.txt` beside the note that an unbounded view must
be bounded before it is rendered.

Structural rather than an isinstance: a value with `columns` and `to_dicts`
renders as a table, which is `Rows` and `Answers` today and any later
projection that grows the same two doors, and `_templates` therefore imports
`results` never. The edge runs the other way, `results` to `_templates`, and
`_atoms_core` defers its import inside `__format__`.

### The generator, rewritten, byte for byte

The cards package has not landed, so the generator rewritten as a template
over a catalog query is the libraries reference page, which the brief's third
item allows.

`tools/libdoc.py` is now two halves. `catalog()` answers three `Rows` --
coverage (`library`, `names`, `documented`), entries (one row per `@doc` atom,
carrying that atom's parts in written order), gaps (one row per declared name
no `@doc` covers) -- and no text at all. Everything else is templates, with
`{coverage:table}` where the hand-assembled table was. The library name is a
`Symbol` in the rows rather than a `str`, which is what makes `group_by` mean
what it says and renders identically, a name being a name.

Measured: the page is byte-identical.
`sha256sum website/reference/metta-libraries.md` is
`ccff738354c74cffaca4dda113f5a8c63af85760ead048eac8ecb512cf98d2e8` before the
rewrite and after `tools/libdoc.py --write`, and `git status` reports the file
unchanged. The `libdoc` gate lane is the comparator that keeps it so.

One deliberate difference in an unreachable case: `(@params ())` with no
parameters now contributes no block, where the line-list assembly emitted a
stray blank line. No library writes one (`grep -rn '@params ()' lib/` finds
nothing), so the page is unaffected.

`libdoc._text`, the generator's own "a string value decodes; anything else
renders as written", is deleted: it was the console rule, hand-written, and
the plain hole is that rule now.

### The lanes, and the reds attributed

`sh check.sh ruff mypy mypy-template-surface llms llms-selftest evidence
libdoc reference init-stub` all pass. `mypy-template-surface` grew a
`check_rendering` function, so the 3.14 conformance lane covers the render
door's annotations as well as the reader's.

Two reds were worktree provisioning rather than defects, the hazard the wave's
constraints name. `llms` reported five findings against
`extensions/node/llms.txt` for `browser/`, `_runtime/`, `runtime.json` and
`wasm/`: those are untracked build artifacts, present in the main checkout and
absent from a fresh worktree, and `Path.rglob` does not descend into a
symlinked directory, so they had to be copied rather than linked. With them
copied the lane reports 0 findings.

Three `test_ipython.py` errors are environmental and pre-existing: IPython
warns "Attempting to work in a virtualenv" and the suite runs with
`filterwarnings = error`. Reproduced identically in the main checkout at the
same base, so they are not this branch's.

`test_the_ruff_configuration_enables_every_family_or_records_why_not` is red
at the base and stays red here, at the same number. Measured on a detached
control worktree cut from b78dbd1f: `D: (2252, 2233)`, 19 docstring findings
over the burn-down ceiling before this branch exists. The first version of
this change made it 2254 by giving the two new `__format__` methods
`# noqa: D105` instead of docstrings; they have docstrings now and the count
is the base's 2252 again, so the branch adds nothing to a backlog another
package owns. Counted with `ruff check --ignore-noqa` over
`extensions/python` in both trees: 2439 findings in the `D` family either way.

`test_every_remedy_naming_raise_site_carries_a_remedy` went red on a local
variable NAME. The lane reads the word "remedy" anywhere in a raise's
footprint, the assignments included, as a promise that the repair is carried
as structured data; `_spec_refusal` had a local `remedy` holding the sentence
that names the OTHER DOOR, which is not a repair an editor could apply. It is
`door` now, which is what it says, and the lane is green. The systematic
`Remedy` pass over this file's prose refusals belongs to the refusals-as-code
-actions package, not here.

### The battery on the committed tree

`sh extensions/python/test.sh` over the whole seat: 4132 passed, 48 skipped, 2
failed in 400.66 s, shuffled seed 1262444922, with the box at loadavg 98
(four `codex-as-mcp` processes at 98% and a benchmark run beside them).

The first failure is the ruff burn-down above, red at the base with the same
number. The second is `test_the_snippet_auditor_runs_from_the_gate`, which
spawns `sh check.sh snippets` under a 30-second bound inside the test itself:
alone it passes in 28.42 s, which is that bound minus a second and a half, so
four pytest workers and the rest of the box push it over. Nothing on this
branch touches `check.sh` or the auditor. Read as load, per the wave's own
rule that a timing lane's red is load until a control says otherwise; the
control here is the isolated run.

### Open

- `Answers.render` and `{rows:table}` over a LAZY view read every answer, so
  an unbounded generator never finishes rendering. Bounding it is the caller's
  (`view[:n]`), and the alternative -- rendering the display bound and saying
  so in a caption -- was rejected because a document that silently holds 100
  of 5,000 rows is worse than one that takes a moment.
- The `json` spec writes what the engine's codec writes, which sorts object
  keys and spaces a list as `[1, "two" ]`. That is `metta._json`'s own output
  and the CLI's `--json` shape; if the codec's spacing is ever tightened, this
  spec follows it rather than carrying a second opinion.
