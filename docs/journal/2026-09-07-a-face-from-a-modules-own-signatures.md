# A face from a module's own signatures

Goal: a MeTTa library that wraps a Python module is generated from that
module, not kept by hand; `lib_torch` is its first output and the two examples
that exercise it keep their answers.

Constraint: the selection is the user's choice in the shape of Python's own
import forms (the ruling in `ai-derived-not-hardcoded-discussion.md` section 12,
Q21); the equation applies the name through `py-call`; the effect class comes
from the tree's own rule with a per-name override in the face's header and
never in the generator; the generator names no library.

## 2026-09-07

### Decided: the head is `attribute_name`, because the hand-written face
### already was

Measured before anything was written: all 20 heads of the hand-written
`lib_torch` are exactly `torch-` plus `_name_mapping.attribute_name` of the
Python name, trailing-underscore rule included, so `requires_grad_` is
`torch-requires-grad`. The map already exists, is tested, and is what `S.car_atom`
and `m.op` apply. Nothing new was invented for the head spelling; the dotted
alternative from the design record (`torch.matmul` as the head) is rejected
because `08-torch_lib.metta` calls the hyphenated names and the naming ruling
keeps MeTTa's own convention on MeTTa's side of the map.

### Rejected: naming the module's own types in the arrows

The design record's sketch is `(: torch.matmul (-> DLTensor DLTensor
DLTensor))`, and `_type_annotations.type_atoms_for(torch.Tensor)` really does
answer the symbol `Tensor`, so it looked reachable.

Tried: a face declaring every result type its annotations name, then the 08
example's own first case -> `is (), should ((58.0 64.0) (139.0 154.0))`. The
compiled goal carries `check_argument_type_under_live_policy(..., list,
ordinary)` and the value fails it [command=sh run.sh
ai-tmp/ai-face-probe-typed.metta; fixture=torch 2.13.0+cpu].

Bisected, because the first reading of that failure was wrong. `Tensor` is NOT
the refusal: `(: t (-[det,writesState]-> %Undefined% Tensor))` over `(py-call
(torch.tensor ...))` answers the tensor under both seats, and `Nonesuch` in the
same slot answers nothing, so the check is live and reads the value's own class
chain. What refuses is `list` over `.tolist`, and the same declaration over
`.split` does NOT refuse. One head settles it: `(: s (-> %Undefined% list))`
over `(py-call (sorted $xs))` answers `(a b)` for `("b" "a")` and answers
NOTHING for `(3 1 2)`, because a crossed expression of numbers carries an
element-wise type the word `list` does not fit while an expression of symbols
does [command=sh run.sh ai-tmp/ai-face-probe-typed5.metta, and the same three
runs through the library engine].

So a declared type is checked against the CROSSED VALUE, and which of a
module's own type names survive the crossing depends on the value rather than
on the annotation. A generator reading `-> list` cannot know which calls would
answer and which would refuse.

Decided: the type map is `metta_type_for`, the projection table's Python column
read backwards, which names the scalar rows and answers `%Undefined%` for
everything else. It is also the map `_documentation.py` uses, so a face's arrow
and its `(@doc ...)` atom cannot disagree. Revisit if the crossing ever gives a
foreign value a type name that holds for every value of that type, which is a
property of the bridge rather than of the face.

### Decided: the signature ladder, and what each rung is

torch's 14 module functions have NO `inspect.signature`: every one raises
`ValueError: no signature found for builtin`, and `__text_signature__` is None.
Their signatures are in the docstring's first line, `matmul(input, other, *,
out=None) -> Tensor`, which is the Argument Clinic convention written as prose.

Tried: `mypy.stubdoc.infer_sig_from_docstring`, the battle-tested reader
`stubgen` uses for C modules. Rejected on measurement: it drops the
keyword-only distinction, so `matmul` came back with `out` as a positional
parameter with a default and the face would have written a `(torch-matmul $a
$b $out)` equation that torch refuses; and it scans the WHOLE docstring, so
`torch.sum` picked up `sum(a)` out of an example block and `Tensor.tolist`
came back with three overloads, two of them invented. It also answers `[]` for
`zeros`, `ones` and `randn`, which is where this reader has to do better rather
than worse.

Decided: `ast.parse("def " + line + ": ...")`, which is CPython's own reader for
a text signature [source: /usr/lib/python3.14/inspect.py:2152,
`_signature_fromstr`]. Applied to the docstring's LEADING lines only, so an
example block is not a signature, and one line per overload, which is how
`range` states its two forms. Measured over torch: 9 of 14 parse as written;
`zeros`, `ones` and `randn` parse after one repair, a bare `*` marker sitting
after a `*args`, which is redundant by Python's own rule and which torch's
factory docstrings write anyway; `arange` does not parse at all, because
`arange(start=0, end, step=1)` puts a defaulted parameter before a required one
and no mechanical repair can say what that means; and `relu` has no docstring.
Those last two are what the header's `Signature:` lines are for, and the
generator reports a declaration for a name the module DOES describe, so the
escape cannot rot.

### Decided: the header is the face's input, so checking is one comparison

The alternative was a list of faces inside the tool, which would put library
names in a file whose whole point is naming none. Instead every face carries
its own import statements, its declared signatures, its effect reviews and the
version it was read from, and the tool regenerates from that header and
requires the same bytes. A mistyped field the reader drops is re-rendered
without it, so it comes back as drift rather than as silence, and the `Read
from:` line is an INPUT like every other field: a box whose torch has moved on
renders the same bytes and is told the difference.

### Measured: a Python tuple crossing py-call is neither data nor a handle

The hand-written face reads `(= (torch-shape $a) (py-call (list (py-call
(getattr $a shape)))))` and the `list` looked redundant: both spellings print
`(3 2)`. They do not compare equal. `!(== (py-call (divmod 7 2)) (3 1))` is
False and `!(== (py-call (list (py-call (divmod 7 2)))) (3 1))` is True; the
same holds for `Tensor.shape` [command=sh run.sh
ai-tmp/ai-face-probe-tuple.metta]. The generated face dropped the wrapper on
the first pass and `08-torch_lib.metta` failed its third case with `is (3 2),
should (3 2)`, which is what a printed answer that unifies with nothing looks
like. Decided: a call whose declared result is a tuple, subclasses included, is
written through `builtins.list`, which is a rule about the crossing rather than
about torch.

### Decided: two py-call spellings, because its grammar reaches one dot

`py-call`'s `mod.fun` branch splits the spec on EVERY dot and unifies with a
two-element list, so a module of any depth misses it: `(py-call (os.path.join
"a" "b"))` raises `No module named 'path'`. Measured alternatives:
`((py-atom os.path.join) "a" "b")` answers `"a/b"` and compares equal to it;
`(py-call (.join (py-atom os.path) "a" "b"))` answers the SYMBOL `a/b`, which
compares False against the string, because py-call converts by janus's
defaults [command=sh run.sh ai-tmp/ai-face-probe-dotted2.metta]. Decided: the
`mod.fun` spelling where it reaches, which is what the shipped face uses and
what keeps its answers, and the `py-atom` application where it does not.

### Decided: the effect class is derived from the declared result

`arrays.py` states the tree's rule for a foreign module's operations:
operations returning mutable arrays are `writesState`, scalar inspections are
`readOnlyLookup`, random construction is `oracleIO`. Two thirds of that is
readable off a signature: a result that crosses as MeTTa data (a scalar or a
container) is the lookup, a live foreign object or a `None` is the write. The
third is not, which is exactly what the header's `Effect:` reviews are for, and
`randn` carries one. A result nothing declares is `oracleIO`, the top, which is
what `bridge.pl` declares for `py-call` itself with the reason this rule
inherits: a weaker class would let a world admit the call and be wrong.

Measured while deciding whether a wrong review is dangerous: a declared
`pureStructural` on a py-call head does NOT enable memoisation here.
`!(== (prnd 1) (prnd 1))` over `(= (prnd $a) (py-call (random.random)))` is
False with `pureStructural`, `readOnlyLookup` and no declaration alike
[command=sh run.sh ai-tmp/ai-face-probe-cache.metta]. The class is a promise
reflection and worlds read, not a silent optimiser trigger, which is why the
review demands its reason in writing.

### The regenerated face, against the hand-written one

20 heads, unchanged, in the same order. 21 equations became 39: `zeros`, `ones`
and `randn` reach arities 0 to 4 rather than 1, `arange` reaches 1 to 3, and
`backward` reaches 1 to 5, each because the signature says so and because that
is the arity set a `module_ops` registration of the same name serves. Every
head gained an arrow with its effect class, and 19 of 20 gained the `(@doc ...)`
atom torch's own docstring carries; `torch.relu` has no docstring, so it has no
documentation, which is the module's own gap rather than a hidden one.

Verification: `sh run.sh` on both torch examples, answer lines diffed against
the same runs before the change, identical. `sh check.sh face-sync llms
llms-selftest ruff mypy examples evidence provenance-pin-selftest`, and the
chapter suite.

Open: the whole-module shape (`import x`) is exercised by the fixture and by
`json` in the tests and by no shipped face; the first one that takes a module
whole will find out what a roster of hundreds costs to render. A face over a
module whose docstrings use the `[, optional]` bracket notation refuses that
name rather than guessing what the brackets mean, and declares it instead.
