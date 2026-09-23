<!--
Purpose: teach the PyMeTTa extension itself, which is a different job from the eight
  numbered tutorials: they teach the language and use Python as the notation,
  and this teaches the install, the first program, and the split install that is
  true of this extension and no other.
Assumes: the reader knows Python and nothing about MeTTa, and is on a machine
  with no SWI-Prolog yet.
Guarantees:
  - every fence was run against this checkout on 2026-08-29, and the outputs
    written beside them are what it printed
    [source: extensions/python/examples/basics/first_steps.py; commit=57f21ba9edf94bcf28cde11f938bce2c241a3709]
  - the two refusal messages are the engine's own words, not a paraphrase
    [source: extensions/python/metta/_binding/runtime.py:502; commit=cd62330ceacc8f1254eed9791c3f6203b48a1c9e]
  - the page is in the navigation and its links resolve
    [tested: test_every_site_page_is_reachable_from_the_navigation,
    npm run docs:build; commit=57f21ba9edf94bcf28cde11f938bce2c241a3709]
-->

# The PyMeTTa tutorial

Here is a whole program. It installs a rewrite and runs it, stores three facts,
and joins two patterns across them.

```python
from metta import MeTTa, S, V, equation

m = MeTTa().space()

m.run("(= (double $x) (* $x 2))\n!(double 21)")
# [[Grounded(42)]]

m.add(S.Parent(S.Tom, S.Bob), S.Parent(S.Bob, S.Ann), S.Parent(S.Ann, S.Zoe))
m.match(S.Parent(V.gp, V.p), S.Parent(V.p, V.gc))
# [Row(gp=Tom, p=Bob, gc=Ann), Row(gp=Bob, p=Ann, gc=Zoe)]
```

Two commands get you there, and the order matters.

## Installing it

The engine runs on a PATCHED SWI-Prolog. Stock SWI-Prolog has defects that
crash the engine or change its answers, so the engine checks its host when it
boots and refuses one that lacks the patches.

On Linux x86_64 with CPython 3.12, 3.13 or 3.14 the wheel carries the patched
host and the janus bridge built against it, so this is the whole install:

```sh
pip install pymetta
```

Anywhere else, build the patched host as [docs/patched-host.md](https://github.com/MesTTo/MeTTa/blob/main/docs/patched-host.md)
describes, then install the bridge with the `engine` extra:

```sh
pip install 'pymetta[engine]'
```

The distribution is `pymetta` and the import name is `metta`. From a checkout,
`pip install .` builds the same pure wheel, and `METTA_PATH` pointed at a clone
uses that tree in place.

## Why the bridge is an extra

`pip install pymetta` on its own always succeeds, even where no wheel carries a
host and no SWI-Prolog exists anywhere. That is deliberate. The bridge is
`janus_swi`, SWI-Prolog's own Python bridge, a C extension that compiles
against whichever SWI-Prolog is on the machine. As an ordinary dependency it
would make a plain install die inside somebody else's build step, with the
linker's words for an error.

So the first call that needs an engine is what tells you. Without a bridge, on
a platform no wheel covers:

```text
The MeTTa engine runs only on a PATCHED SWI-Prolog. pymetta's manylinux x86_64 wheels carry one, so on Linux `pip install pymetta` is the whole install. Here, build the patched SWI-Prolog as docs/patched-host.md describes (https://github.com/MesTTo/MeTTa/blob/main/docs/patched-host.md), then install the bridge against it:

    pip install 'pymetta[engine]'
```

With the bridge bound to a stock SWI-Prolog, the engine names every patch it is
missing, the home it looked in, and this same page. If you installed the source
distribution on Linux x86_64, where a wheel would have carried the host, the
message says to reinstall from the wheel instead.

The wheel is pure Python apart from the Linux ones, so there is nothing to
compile. The `platforms` job in `.github/workflows/checks.yml` installs it on
macOS and Windows against Python 3.12 and 3.14 *before* SWI-Prolog exists on the
runner, because that is the state a new reader is in. It asserts the refusal
above, installs a stock SWI-Prolog with the bridge, and asserts that the engine
refuses that host by name.

## The shortest spelling needs no instance

The module functions run over one lazily created default engine, which is the
shape `random` and `logging` already have:

```python
import metta

metta.add("(parent Tom Bob)")
metta.match("(parent Tom $x)")       # [Row(x=Bob)]
metta.run("!(+ 40 2)")               # [[Grounded(42)]]
```

`metta.engine()` hands the context over the moment you want control, and
`metta.space()` gives you a handle of your own. Every module function is one
line over the default context's handle, so nothing is lost by starting here.

## Terms are Python values, not strings

`S` mints symbols, `V` mints variables, and applying a symbol builds an
expression. None of it contacts the engine:

```python
from metta import S, V

S.Parent(S.Tom, S.Bob)      # (Parent Tom Bob)
V.x                         # $x
S.Parent(V.gp, V.p)         # (Parent $gp $p)
```

A string is for text, and for whole programs handed to `run`. A built term is
already knowledge; a string has to be parsed before it is.

## A space stores atoms and answers patterns

```python
from metta import S, V, space

m = space()
m.add(S.Parent(S.Tom, S.Bob), S.Parent(S.Bob, S.Ann))
m.match(S.Parent(V.x, V.y), S.Parent(V.y, V.z))
# [Row(x=Tom, y=Bob, z=Ann)]
```

Two patterns in one `match` is a join: `$y` is one variable across both, so a
row exists only where the same value satisfies each. A row is keyed by the
names you wrote, so `rows[0].y` reads the middle binding back by name rather
than by a child index.

## Two ways to give MeTTa a Python function

A Python function can become MeTTa two ways, and the choice is real rather than
a convenience and its longhand.

`@m.define` LOWERS the body: the function is read and installed as equations, so
the engine owns it and a call crosses into Python not at all.

```python
@m.define
def triple(x: int) -> int:
    return x * 3

m.eval(S.triple(7))                              # [Grounded(21)]
len(m.match(equation(S.triple(V.x)).to(V.body)))  # 1
```

The second line is the point. The definition became an ordinary `(= (triple $x)
(* $x 3))` atom in the space, so a pattern finds it and the engine can
type-check and specialise it. Nothing is opaque and nothing crosses back into
Python when the function is called.

`m.op` publishes a function the engine CALLS, for a body that has to stay
Python because it touches the network, holds a file, or wraps a library you are
not going to re-express:

```python
def shout(text: str) -> str:
    return text.upper()

m.op(shout, effect="pureStructural")
m.run('!(shout "hello")')                    # [[Grounded('HELLO')]]
```

The `effect=` is required, not advisory. The engine cannot see inside a called
function, so it has to be told what the function does before it can cache,
reorder, or roll back around it. Leaving it out refuses by name:

```text
TypeError: operation 'shout' requires effect= metadata; choose one of:
EffectClass.pureStructural, EffectClass.readOnlyLookup,
EffectClass.nondeterministicReadOnly, EffectClass.writesState,
EffectClass.oracleIO
```

Reach for `@m.define` when the body is expressible as MeTTa and `m.op` when it
is not. [Python functions in MeTTa](../../guide/python-functions.md) covers
both ways, the five effect classes, and crossing into Python from inside a
lowered body.

## The install is a command-line tool too

```sh
python -m metta run program.metta        # run a file, print each ! answer group
python -m metta repl                     # interactive, multi-line forms
python -m metta lint program.metta       # diagnostics; nonzero exit on findings
python -m metta doc car-atom             # a name's (@doc ...) documentation
python -m metta stubs program.metta -o program.pyi   # its declarations, as Python types
```

Each subcommand exits nonzero on failure, so all of them script.

## Where to go next

The [eight numbered tutorials](../../tutorials/) teach MeTTa itself from here,
one idea at a time, starting with atoms and ending with a drawn reduction. The
[guide](../../guide/) is the same surface arranged by task. The
[PyMeTTa extension page](./) says what the extension is made of: the control file, the two
`entry/2` roles, and the one library it needs.
