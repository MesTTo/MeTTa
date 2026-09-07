# Jupyter notebooks

The executed [notebook tour](https://github.com/MesTTo/MeTTa-Kernel/blob/python-library/extensions/python/notebooks/tour.ipynb) starts with Python atoms, keeps Python and MeTTa in one session, and ends with a rendered derivation tree. Every structural argument in it is a built term; the one cell of MeTTa source is the `%%metta` cell, whose subject is that the two languages share a session.

Load the extension in an ordinary Python kernel. `use(m)` points the cell magic at an existing `MeTTa` instance, so Python calls and MeTTa cells read and write the same space:

```python
%load_ext metta.ipython
from metta.ipython import use

use(m)
```

Start a cell with `%%metta` to run the rest of that cell as MeTTa source. The magic prints one line for each directive and returns the structured answer groups as the cell value:

```python
%%metta
!(+ 1 2)
(Parent Zoe Lia)
!(match (context-space) (Parent $parent $child) ($parent $child))
```

Without `use(m)`, the extension creates its own default `MeTTa` runtime. A space name after `%%metta` targets that named space for one cell.

## One line at a time

`%metta` runs the rest of the line and nothing else:

```python
%metta !(+ 1 2)
```

It is the same magic as `%%metta`, registered once in IPython's `line_cell`
form the way `%time` and `%%time` are one magic. What the line means is what
differs, because it is the argument line in both and the argument is not the
same thing: for `%metta` the line is the program, for `%%metta` it names a
space. So a one-line evaluation has no room to name a space, and `use(m)` is
the rung below it, pointing both faces at one runtime for the session. `%metta`
with nothing after it refuses and names the two spellings that do something.

## Colour, and a kernel that needs no prefix

Installing the package registers a MeTTa lexer with Pygments, under the alias
`metta`, every filename ending in `.metta`, and the MIME type `text/x-metta`.
Nothing has to be imported to arrange it: Pygments reads the entry point out of
the installed distribution, so Sphinx, mkdocs, rich, IPython, nbconvert and a
Jupyter front end all colour MeTTa from that moment.

```python
from rich.console import Console
from rich.syntax import Syntax

Console().print(Syntax("!(+ 1 2)", "metta", theme="monokai"))
```

The lexer is generated from `website/.vitepress/metta.tmLanguage.json`, the
same TextMate grammar this site highlights with and the editor extension
loads, and a check lane tokenises every `.metta` file in the repository both
ways and requires the two to agree about every character. So a fence here and
a cell in your notebook are coloured by one grammar rather than by two that
drift.

The colouring is lexical: the grammar knows a comment from a string from a
`$variable`, and it does not know a definition from a call or a declared type
from an undeclared one. That is what the language server's semantic tokens
add, on top, in an editor.

For a notebook whose cells are MeTTa with no `%%metta` prefix, the kernel is
[trueagi-io/jupyter-petta-kernel](https://github.com/trueagi-io/jupyter-petta-kernel).
It asks its host for a `petta` module under `$PETTA_PATH/python`, which is
upstream PeTTa's layout and not this one, so point `PETTA_PATH` at an upstream
checkout to run it. Its `language_info` names `text/x-metta`, which is the
lexer above: with `pymetta` installed, an exported notebook's MeTTa cells are
coloured as MeTTa rather than as the Scheme the kernel falls back to.
