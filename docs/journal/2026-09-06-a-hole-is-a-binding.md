# A hole is a binding

Goal: one door that reads program text with holes, with a t-string literal, a
template object from a backport, and a keyword call all feeding it, so a Python
value reaches a MeTTa program by position rather than by name and cannot
collide with a symbol the program already uses.

Constraint: the supported Python floor stays 3.12, so the 3.14 `Template` class
may never be named in an `isinstance`; the hole rides the `bind` mechanism that
already exists rather than a second one; values enter through `encode`; there is
no new marker vocabulary, the atom constructors are the markers; rendering the
template to text is rejected, because that is the escaping problem PEP 750
exists to remove.

## 2026-09-06

### The prior art that shaped it

Three systems solve this exact shape and were read before anything was written.

`tdom`, the PEP 750 HTML templater, splices a GENERATED placeholder into the
text at each interpolation, hands the assembled text to a real HTML parser, and
translates parser positions back to template positions for its errors
[source: https://github.com/t-strings/tdom/blob/main/tdom/placeholders.py,
`make_placeholder_config`, and `tdom/parser_utils.py`,
`make_parser_pos_translator`]. That is the whole architecture here: generate,
splice, let the engine's own reader parse, report positions in the text the
author wrote. tdom randomises its placeholder (`t🐍xx-0-yy🐍t`) against content
that might look like one, with a `test_placeholder_collision_avoidance` behind
it. We do not need randomness, because we can scan the author's literal
segments for the reserved prefix and refuse: that is exact where randomness is
merely improbable, and it keeps the spliced name deterministic, so a refusal
message and a test read the same on every run.

psycopg 3.3 shipped a t-string face for SQL with format specifiers `i`
(identifier), `l` (client-side literal) and `q` (verbatim statement snippet)
[source: https://www.psycopg.org/psycopg3/docs/basic/tstrings.html]. It is the
same three-way split the design already reached from the other direction:
`sym` is `i`, the default value path is `l`, and `expr` is `q`. Their discussion
thread is explicit that the interesting question is what happens when a value
lands where a parameter cannot go, and that the answer must not be silent
[source: https://github.com/psycopg/psycopg/discussions/1044]. Independent
arrival at the same vocabulary is the strongest evidence available that the
three roles are the real ones.

Lisp's `gensym` is the third: a macro that splices a name into code it did not
write generates one nothing else can capture. `metta.atoms.fresh` already does
this for variables, `Variable(f"__metta_fresh_{uuid4().hex}")`, so the library
had the convention and the prefix; a hole is the same idea one kind over.

### Decided: the reserved spelling is `__metta_hole_<k>`

`k` counts holes across the whole call, flattened, so several targets in one
`eval(a, b)` and a nested template cannot collide.

The engine's reader accepts it because a token ends at exactly the Unicode
White_Space property plus `(`, `)` and `;` and at nothing else
[source: engine/parser.pl, `metta_token_boundary/2`], and a token that is not a
number, not a string, not `True`/`False` and does not start with `$` becomes a
symbol through `metta_reader_default/2`. Measured: `parse("(f __metta_hole_0)")`
answers `(f __metta_hole_0)` with the second child a `Symbol`, and
`with m.bind({"__metta_hole_0": 10}): m.run("!(+ __metta_hole_0 1)")` answers
`[[Grounded(11)]]`.

Collision is closed on both surfaces rather than made improbable. The author's
literal segments are scanned and a segment containing `__metta_hole_` is
refused with its position; `bind()` refuses a key in that namespace. The
substitution itself cannot re-enter a value, because `metta_host_substitute/3`
cuts after replacing an atom and never walks what it substituted
[source: engine/filereader.pl:663-668], so a value that itself contains a hole
symbol is safe.

Rejected: a random component per call, tdom's answer. It buys nothing once the
text is scanned, and it costs determinism in error messages and tests.

### Decided: the hole must be its own token, checked against the reader's grammar

The brief's rule was adjacency: a hole is inside a symbol when the preceding
segment ends with a symbol character or the following begins with one. That
rule refuses `!(f "a"{x})`, and the reader accepts it: measured,
`parse('(f "a"__metta_hole_0)')` answers `(f, Grounded('a'), __metta_hole_0)`,
two atoms, because a `"` at a token start commits to the quoted scanner and the
next token starts after the closing quote. A wall neither language requires is
a defect, so the check is the exact property instead: walk the assembled text
with the reader's own grammar (layout, `;` comment to `\n` only, `"` quoted
token with backslash escapes, otherwise a run of non-boundary characters) and
require the hole's spliced name to occupy exactly one whole token. The
adjacency case is then reported in the words the author needs ("glued to
`fib`"), and the string and comment cases get their own messages.

The comment case is not in the brief and is kept, for two reasons. Tracking
comment state is REQUIRED for the string check to be right, since a `"` inside
a `;` comment must not open a string. And a hole inside a comment is a value
the reader silently discards, which is the same defect class as the other two.

### Decided: `{x=}` expands to two holes

PEP 750 folds the debug form's label into the PRECEDING string and sets
conversion `r`; measured on 3.14.4, `t"!(log {x=})"` has
`strings == ('!(log x=', ')')`, `expression == 'x'`, `conversion == 'r'`, and
`t"{x = }"` keeps the author's spacing in the fold while `expression` stays
`'x'`. Left alone, every debug hole would be refused as glued to a symbol,
which is a useless answer to a form the author wrote on purpose. So a fold is
recognised (conversion `r`, empty spec, and the segment ending in the
expression followed by optional space, `=`, optional space) and split: the
label enters as a String atom, a space, then the value as its repr, also a
String atom. `!(log {x=})` is `(log "x=" "42")`. Python's own `f"{x=}"` puts the
same two pieces of text out; MeTTa has atoms rather than one string, so it is
two atoms, and the library never concatenates on the author's behalf because
that is the rendering the design rejected.

An author who writes `t"!(f v={v!r})"` by hand is indistinguishable from
`t"!(f {v=})"` in the Template, by PEP 750's design, and gets the same two
atoms. That is the only honest reading.

### Decided: a nested template splices, a converted one does not

`t"!(foo {inner})"` where `inner` is itself a template composes: the inner
text becomes text and its holes become holes of the outer call. A nested
template is a LITERAL the author wrote, so it carries no injection risk, which
is exactly why psycopg lets a `sql.SQL`/`Composed` compose while a runtime
`str` must be wrapped. A runtime `str` of MeTTa text still needs the visible
escape, `{parse(text)}` or `{text:expr}`. A nested template with a conversion
or a spec is not spliced: the conversion or spec says "treat this as a value",
and it is.

### Decided: the door list, and the two doors that refuse

Accepting: `run`, `profile`, `profile_extension`, `eval`, `answers`,
`eval_status`, `match` and `parse`, on `Space` and therefore on the three
mirrors `tools/aiogen.py` generates.

`eval`, `answers` and `eval_status` hand the holes to the engine as ordinary
`bind` pairs, because they already thread `using`. `match` and `parse` cannot:
`Cursor` opens through `metta_py_cursor_open`, which takes no bindings, and
`parse` runs nothing. Both therefore parse and then apply `_substituted`
host-side, which is the substitution written once for exactly this case, and
they pay one reader crossing for it. The values are encoded to atoms BEFORE
substitution, which is what makes the two paths agree: `_substituted` calls
`_to_atom`, and `_to_atom` PARSES a `str` where the engine path ENCODES it, so
an unencoded `str` value would mean two different things at the two doors.

`run_status` refuses, naming the reason: `metta_host_run_source_status/3` takes
no bindings, so `bind()` does not reach it either and a hole there would have
nowhere to land.

`load` refuses. It takes a PATH, and a path is not program text: a hole in a
filename is an f-string, which Python already spells. The refusal names `run`
for program text with holes and an f-string for a computed path.

`define` has no text form to extend: its four overloads take a function, a
class, `name=` or `prolog=`.

Open: `run_status` gains the face when the engine's status door gains a
bindings argument; that is an engine change, not a library one.

### Decided: the keyword face takes `**values`, and refuses what it cannot use

`m.run("!(fib {n})", n=10)` needs the values as keywords, which is what the
face is for. Three rules keep it from eating mistakes:

- the face engages only when keyword values are passed. A plain
  `m.run("!(f {x})")` is unchanged and unscanned, so a program whose symbols
  contain braces still runs and the existing path costs nothing.
- a keyword no field uses is refused. Without that, `m.run(src, timout=5)` would
  be swallowed where today it is a `TypeError`.
- a field whose name is one of the door's own keywords (`timeout`, `under`,
  `where`, ...) is refused naming the collision, because the named parameter
  wins and the field can never be reached. The remedy in the message is the
  template literal, where there are no keywords to collide with.

`string.Formatter().parse` supplies the split, with `{{` and `}}` already
resolved in the literal chunks, and `Formatter().get_field` resolves `{a.b}`
and `{a[0]}` exactly as `str.format` does. `{}` and `{0}` are refused: a hole
must be named.

### Decided: the protocol is read-only, and lives with the API-boundary types

`TemplateLike` and `InterpolationLike` are read-only property protocols, not
attribute protocols. A mutable protocol attribute is invariant, and
`string.templatelib.Interpolation.conversion` is `Literal['a','r','s'] | None`,
which is not the same type as `str | None`; as properties the members are
covariant and the 3.14 class satisfies them. A hand-written class with plain
instance attributes satisfies a read-only member too, so the backport and a
test double both pass.

They live in `_api_types.py`, the module whose whole content is API-boundary
types and whose only import is `typing`, and are re-exported from the package
root because they name the type of the first argument of eight public doors.

Deliberately not `runtime_checkable`: the runtime gate is two `getattr` calls
asking for tuples, which is faster than a protocol `isinstance` and actually
checks the tuple-ness the assembly relies on.

### Not here: the Node seat

The same door on the Node seat is a tagged template literal,
`` metta`!(fib ${n})` ``, the construct PEP 750 was modelled on: the strings and
values arrive at the tag function in the same two pieces. It lands in the
metta-node repository after the split, not here.

## 2026-09-07

### Built, and what the build changed about the plan

Landed on `feat/template-holes`. `_templates.py` reads the three faces into
`(text, {name: Atom})`; `_api_types.py` carries the two protocols; the doors
are `run`, `profile`, `profile_extension`, `eval`, `answers`, `eval_status`,
`match` and `parse` on `Space`, mirrored to the async, module and context tiers
by `tools/aiogen.py`. Four things were decided at the keyboard, each because
something measured said so.

Tried: `**values` on `eval` beside its two overloads -> mypy `misc`,
"Overloaded function implementation does not accept all possible parameters of
signature 2". Reduced to eleven lines in `ai-tmp/probe/ov.py`: with `**values`
present, a caller can write `ev(a, b, target=1)`, which the positional-only
overload accepts into its `**values` and an implementation with a
positional-OR-keyword `target` cannot. Decided: the first parameter of every
door taking `**values` becomes positional-only. It costs nothing (nothing in
the tree calls `run(source=...)`, `eval(target=...)` or their siblings, checked
by grep) and it BUYS the field names: `{source}` and `{target}` are now usable
holes, where a positional-or-keyword parameter would have swallowed them.

Tried: giving the delegating branches the holes as engine binding pairs ->
lost. `answers(theory=...)` re-asks through `_answers_with_theory`, inside a
generator pulled later, and `eval_status(theory=...)` recurses; a pair cannot
follow a target through a hand-off that has not happened yet. Decided: `_held`,
which substitutes the values into the TERM on exactly the branches that hand
the target on (a theory, an interpreter or a carrier), and keeps the cheaper
pair everywhere else. The cost lands on the branch that already mints a scratch
space. `match` and `parse` sit on the substituting side permanently, since
`metta_py_cursor_open` carries no bindings and `parse` runs nothing.

Tried: `_substituted` for the hole substitution -> it calls `_to_atom` on each
value, and `_to_atom` PARSES a `str` where the engine path ENCODES it, so a
`str` at a hole would have been a symbol at `match` and a String at `run`.
Decided: `_templates.apply`, which takes values that are already atoms, and the
reader encodes every value before it is placed. The two paths now agree by
construction rather than by care.

Tried: the brief's adjacency rule for "inside a symbol" -> refuses text the
reader accepts. Measured: `parse('(pair "a"__metta_hole_0)')` answers
`(pair "a" __metta_hole_0)`, two atoms. Decided: the check walks the assembled
text with the reader's own grammar and requires the hole to be one whole token,
which is the exact property, and reports the adjacency case in the words the
author needs.

### Measured

- The engine's `metta_token_boundary/2` is 28 codepoints; this library's copy
  is compared against it at runtime rather than trusted
  (`test_the_boundary_table_matches_the_engines`). Python's `str.isspace` is a
  superset, answering True for U+001C to U+001F, which is why the table is
  written out at all.
- `mypy --python-version 3.14 tests/typing/template_surface.py` passes, so the
  3.14 `Template` and `Interpolation` satisfy `TemplateLike` and
  `InterpolationLike`. Replacing the read-only `conversion` property with a
  mutable `conversion: str | None` attribute made it 7 errors, the first
  reading `interpolations: expected "tuple[InterpolationLike, ...]", got
  "tuple[Interpolation[Any], ...]"`. The lane is `mypy-template-surface`.
- Ruff at `target-version = "py312"` refuses to PARSE a t-string literal
  ("Cannot use t-strings on Python 3.12"), so the literals live in one file
  with a `[tool.ruff.per-file-target-version]` entry, imported only inside a
  `sys.version_info >= (3, 14)` guard and never collected. Verified in
  `ai-tmp/probe/pf/` that the entry admits the named file and that a sibling
  without one still fails.

### Decided at the keyboard: the keyword face engages only with values

`m.run("!(id {x})")` with no keywords is unchanged and unscanned: `{x}` stays
the symbol it has always been, since `{` and `}` are ordinary symbol characters
to the reader. The consequence is that `{{` and `}}` are `str.format` escapes
only when a value is there to resolve, which is exactly `str.format`'s own
rule, and it is documented rather than smoothed over. Making the face always
engage would have changed the meaning of every existing program holding a
brace.

Open: `run_status` has no bindings channel, because
`metta_host_run_source_status/3` takes no Bindings argument, so `bind()` does
not reach it either. It refuses a template naming that reason. The face lands
there when the engine's status door grows the argument; that is an engine
change, not a library one.

## 2026-09-07, after the merge: where the two protocols are public

The full battery on the merged trunk found three roster failures the
four-directory verification did not reach. All three are about the SURFACE, not
the mechanism, and the first two are one decision.

Tried: exporting `TemplateLike` and `InterpolationLike` from the package root,
because they name the type of the first argument of eight public doors and a
reader of `m.run`'s signature has to be able to reach the name. It went red
twice: `test_canonical_context_types_replace_public_newtypes` asserts
`_api_types.__all__ == []`, and `test_m7_narrow_core_surface` pins the root at
`FINAL_METTA_EXPORTS = 113` where the root now had 115.

Decided: `metta.atoms` publishes them, `_api_types` defines them and publishes
nothing, and the root keeps its count. Three reasons, in the order they
decided it. The narrow-core ruling is a ruling: a name earns a place on the
root by being a verb a program calls, and a structural type is not that.
`metta.atoms` is the module the reader door already lives in, so a caller who
has `parse` in scope has the type of `parse`'s argument in scope with it. And
a hole's markers ARE the atom constructors, `Symbol`, `Grounded` and `parse`,
every one of them already on that roster, so the type of the thing they are
markers inside belongs beside them.

The module tier's annotation follows the convention that table already has:
`aiogen.py`'s `MODULE_ALIASES` gains `("TemplateLike", "_TemplateLike")` and
`__init__.py` imports it under `TYPE_CHECKING` as `_TemplateLike`, which is how
`Callable`, `Literal`, `Defined` and the rest stay out of `metta.<TAB>` while
still typing the generated signatures. `InterpolationLike` gets no alias
because no door's signature names it.

Rejected: leaving them at the root and advancing `FINAL_METTA_EXPORTS` to 115.
The count is not the claim; the ruling behind it is, and this change had no
argument against the ruling. Revisit only if a door ever takes a protocol as a
VALUE rather than as an annotation.

The third failure is a pin doing its job. `test_aio_covers_the_whole_synchronous_surface`
spells out `AsyncMeTTa.run`'s and `.match`'s parameters, and its own comment
says an exact list goes red on every legitimate widening, so the pin advances:
`values` joins both lists. Two assertions go with it, because the same pin
exists to say what a name alone cannot: `source` is POSITIONAL_ONLY and
`values` is VAR_KEYWORD. The first is load-bearing rather than cosmetic. It is
what lets a hole be named `{source}`, since a positional-or-keyword parameter
of that name would take the value before the field could see it, and it is what
mypy required of the `eval` overloads.

Not touched: three order-dependent lifecycle failures in the same battery,
which are another worker's.
