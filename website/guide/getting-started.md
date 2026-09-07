<!--
Purpose: install MeTTa and introduce its module primitives, runtime context, and Space handle.
Guarantees: examples use the current narrow public surface.
[tested: npm run docs:build; commit=5fe3175632a6b60b3b54ca9125b75607ac82401a]
-->

# Install and first steps

## Run it here

Nothing is installed yet and this already runs. Press Run: the page fetches the
engine, about 8 MB of WebAssembly and MeTTa source, into a Web Worker and
evaluates the program below in it. The first press pays for the engine, a second
or two; every press after it, and every other fence on this page, is the program
alone.

::: run examples/ch05-equations-and-evaluation/05-01-an-equation-is-a-rewrite/01-identity.metta
```metta
(= (f $x) (* $x $x))

!(test (f 1) 1)
```
:::

An equation rewrites: `(f 1)` becomes `(* 1 1)` becomes `1`, and `test` compares
that against the `1` written beside it and answers `true`. That is the corpus's
own idiom, and it is why every example here checks itself.

The program is not a sample of that file. It IS that file, byte for byte:
`examples/ch05-equations-and-evaluation/05-01-an-equation-is-a-rewrite/01-identity.metta`
is what `sh test.sh` runs in the gate, and the site build refuses a `::: run`
fence whose text has drifted from the file it names. Here is the first program in
the corpus, which prints a number rather than checking one:

::: run examples/ch01-getting-started/01-hello.metta
```metta
;The first program. There is no main, no declaration and no import: a file
;is a list of forms, and a form prefixed with ! is RUN when the reader
;reaches it. The engine prints what it answers.
;
;    sh run.sh examples/ch01-getting-started/01-hello.metta
;
;prints 42.
!(+ 40 2)

;A form without the ! is DATA. This one is stored, not run, and nothing is
;printed for it.
(the-answer 42)

;So the same text means two things depending on one character, and that is
;the whole of the directive. Chapter 5 comes back to why data and calls look
;alike; for now, ! means run.
!(+ 2 (* 2 20))
```
:::

What this browser engine does NOT have is a host beside it: no Python, so
`py-atom` and its family are refused by name rather than answering themselves;
no threads, so `hyperpose` and `lib_thread` are refused with the engine's own
census sentence, which says what the absence costs; and no processes, so
`git-import!` is. It does carry the whole standard library, so
`!(import! &self (library lib_regex))` works here as it does anywhere. What it
cannot reach is the example's own directory: only the fence's bytes cross, so a
file an example imports from beside itself is not there. 225 of the
repository's 258 runnable examples run here unchanged. Everything else on this
page is the Python surface, which needs the install below.

The `metta` module is the Python surface for the engine. MeTTa runs on SWI-Prolog, which is a program rather than a Python package, so it is installed first and pip cannot do it for you: `sudo apt install swi-prolog`, `brew install swi-prolog`, or `winget install SWI-Prolog.SWI-Prolog`. Then `pip install 'pymetta[engine]'`, or `pip install '.[engine]'` from a checkout. The runtime is bundled; only the engine underneath it is not. To use a checkout in place, point `METTA_PATH` at the repository tree.

`pymetta` without the `engine` extra installs and imports on a machine that has no SWI-Prolog, and the first engine call names the two commands above. That is what the extra is for: the bridge compiles against whichever SWI-Prolog is present, so requiring it would make a plain install fail inside another package's build.

The shortest spelling needs no instance at all. Module functions run over one lazily created default engine, which is `random`'s and `logging`'s own shape, and `metta.engine()` hands the context over the moment you want control.

```python
import metta

metta.add("(parent Tom Bob)")
metta.match("(parent Tom $x)")       # [Row(x=Bob)]
metta.run("!(+ 40 2)")               # [[Grounded(42)]]
```

Every module function is one line over the default context's `Space` handle. Each row is sugar for the one below it:

| today | shorter |
|---|---|
| `m = metta.space()` in every script | `import metta; metta.match(...)` |
| `timeout=` / `inferences=` on every call | one `with m.limits(...)` block |
| query, then reshape rows by hand | `m.match(..., into=Edge)` |
| add-loops crossing per atom | `with m.batch():` crosses once |
| hand-rolled engine fixtures in your tests | the shipped pytest plugin's `metta` and `scratch_space` |

Create a `Space` handle, run source, then move between source terms and Python atoms:

```python
from metta import S, V, space

m = space()
m.run("(= (foo) boo) !(foo)")        # [[boo]]
m.run("!(+ 40 2)")                   # [[Grounded(42)]]

m.add(S.Parent(S.Tom, S.Bob), S.Parent(S.Bob, S.Ann))
m.match(S.Parent(V.x, V.y), S.Parent(V.y, V.z))
# [Row(x=Tom, y=Bob, z=Ann)]
```

`run` uses the engine's reader, compiler, and evaluator. It returns one answer list for each `!` directive. Grounded answers compare as Python values. Symbols stay symbols. Stored Python objects return as the same objects.

## Python version floor

MeTTa supports Python 3.12 and newer. The floor spelling builds terms directly,
such as `term = S.Order(7, 5)`, and reconstructs or calls `__replace__` on a
MeTTa-defined record when one field changes. Those forms work on 3.12.

Python 3.13 adds `copy.replace(edge, b="new")` as the general functional
update spelling. Python 3.14 adds t-string syntax, which creates a structured
`Template`; it is optional integration sugar and is not accepted directly by
`Space.run`. Neither feature changes the 3.12 floor. See
[term building](./atoms-terms.md#build-terms-not-source-text) and
[record replacement](./python-functions.md#declaring-a-data-class) for the
runnable forms.

The repository has 24 self-verifying Python examples organised by topic. Run the first from the repository root:

```bash
PYTHONPATH=extensions/python/examples python extensions/python/examples/basics/first_steps.py
```

The installed wheel is a complete command-line tool too, `-m` fashion:

```bash
python -m metta run program.metta        # run files, print each ! answer group
echo '!(+ 1 2)' | python -m metta run -  # `-`, or no operand, reads standard input
python -m metta run --json prog.metta    # one JSON object per ! group, a line each
python -m metta repl                     # interactive loop, multi-line forms
python -m metta serve kb.metta --port 8700   # expose spaces over HTTP
python -m metta boot app.metta           # assemble a (boot ...) manifest
python -m metta lint program.metta       # diagnostics; nonzero exit on findings
python -m metta doc car-atom             # a name's (@doc ...) documentation
python -m metta doc --infer program.metta   # the declarations its own atoms justify
python -m metta llms                     # print llms.txt, the sheet for an agent
python -m metta stubs program.metta -o program.pyi   # the program's declarations, as Python types
```

Each subcommand exits nonzero on failure, so all of them script. The bare `metta` console command keeps the direct-file launcher contract, running a file through `swipl` directly.

`llms.txt` is the one document an LLM agent reads before writing anything against this library, and it ships inside the wheel. `metta.llms()` prints it from Python the way `help()` prints, so neither a person nor an agent needs a checkout to read it.

`run` is a Unix filter. The operand `-` means standard input, guideline 13 of
the POSIX Utility Syntax Guidelines, and so does no operand at all; `-` with
nothing else to run and a terminal on standard input is a usage error rather
than a process that blocks. `--json` frames the answers as
[JSON Lines](https://jsonlines.org) instead of printing them: one
`{"query": "<the ! form's text>", "answers": ["<atom text>", ...]}` a line on
stdout, one `{"error": "...", "line": <input line, or null>}` a line on stderr,
and the program's own `println!` moved to stderr so `jq -c` can read the
stream. `--json=wire` puts the tagged atom forms in `answers`, which
`metta.atoms._atom_from_wire` reads back. The flag changes the framing and not
the run: exit status, execution and answers are what the same command without
it gives.

`doc --infer` prints the `(: head (-> ...))` declarations a program's own atoms
justify, the same proposals `m.infer_types()` answers. It adds nothing; the
Python door adds them on request with `m.infer_types(declare=True)`.

`stubs` writes what an editor needs: one `def` per head the program declares, with the arrow's types as Python annotations and the `(@doc ...)` as the docstring, so completion and `mypy` reach a MeTTa program the way they reach any module. `metta.stubs(space)` is the same generator from Python, returning the text.

Examples that need DuckDB, NumPy, or PyTorch skip when that optional dependency is absent.

When something misbehaves, `metta.engine().info()` answers the MeTTa, janus, SWI-Prolog, and Python versions plus the consulted runtime tree in one dict, which is exactly what a bug report needs.

The library logs under the `metta` namespace and installs a `NullHandler`, so it stays silent until your app configures it. `logging.getLogger("metta").setLevel(logging.DEBUG)` with a handler is the whole debug incantation.

Continue with [atoms, operators, and term building](./atoms-terms).
