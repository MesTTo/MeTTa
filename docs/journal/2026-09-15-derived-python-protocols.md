# Derive Python protocols from their source contracts

Goal: derive Python's operation inventory and project shared protocol shapes
into native equations, compiler bindings and differential tests.

## 2026-09-15

Source: at `15059fadefb33295bd30d927be5e25559528c2df`,
`extensions/python/metta/_declare/prelude.py:install` registers `py-operator`
at two flat arities. `_compile/call_syntax.py:application`
already separates operand computation from held argument frames. CPython's
`operator.call` has a variadic call signature, while syntax operands and Atom
builders have their own contracts. The existing compiler's min/max paths fold
binary applications, so they do not expose the service's arity limit directly.

Decided: use the existing operation service with a selector and one expression
of completed operands. Its signature derives one native arity. Compile each
expression operand into a fresh native let, in source order, then hold the
assembled frame. Variables and literal atoms are already completed values.
This uses the existing expression representation and operation registration;
the selector inventory is unchanged in this unit.

Rejected: enumerate additional service arities or add a second variadic
operator service. Either would repeat the call protocol for a cardinality that
the native operand expression already represents. The required frame has
linear construction cost in its operand count; no sublinear representation
can expose all supplied operands. This unit claims structural cardinality,
evaluation order and native rewriting, not a performance improvement.

Tried: after deleting engine and library QLF files, the following command
against unchanged providers passes the evaluation-order control and fails the
frame call with `TypeError: 'tuple' object is not callable`. The temporary
operator.call selector receives the entire frame as one tuple under the old
flat convention. Log: `ai-tmp/ai-classes-c59-frames-before.log`.

```sh
python -m pytest -q -n 0 --benchmark-disable --randomly-seed=1125382488 \
  extensions/python/tests/ch11_python_as_a_notation/test_operator_frames.py
```

The frame witnesses cover empty call operands, several operands, falsey
values, a scalar symbol with an active native rule, grounded Atom identity,
ordered computed effects, and native equation matching and replacement.
Existing compiler and fold assertions now inspect the same frame contract.

Verified: the focused command above, also selecting
`extensions/python/tests/ch08_data/test_reduce_lowering.py`, passes five tests
after the ABI migration. Log: `ai-tmp/ai-classes-c59-frames-after.log`.
`sh check.sh layering ruff mypy ty evidence policy-inventory` passes all
selected checks, with 7,851 evidence claims and zero unbacked references.
Log: `ai-tmp/ai-classes-c59-checks.log`. The five-file clone scan in
`ai-tmp/ai-classes-c59-verify.sh` reports 4,652 lines, 40,351 tokens and zero
clones. Log: `ai-tmp/ai-classes-c59-clones.log`.

Verified: `GATE_ONLY=1 sh check.sh door-sync reference` passes the 227-contract
projection checks, 69 door controls, 58 refusal controls and four reference
controls. After deleting engine and library QLF files, `sh engine/test.sh`
with `libraries/lib_reflect.plt`, `host/python_surface.plt` and
`evaluation/grounded_effects.plt` under `tests/prolog/suites/` passes 68 tests
and 15 subtests in three processes. The Python command in
`ai-tmp/ai-classes-c59-verify.sh` passes 1,071 tests with `-n 0`, covering data,
notation, class methods, construction, grains, costs and operator projections.
The complete commands and outputs are in `ai-tmp/ai-classes-c59-verify.sh`,
`ai-tmp/ai-classes-c59-projections.log`, `ai-tmp/ai-classes-c59-native.log` and
`ai-tmp/ai-classes-c59-python.log`. `/usr/bin/time -v` reports peak resident
memory of 40,788 KiB for the native runner and 1,628,776 KiB for Python.

Open: derive the operation inventory and connect its protocol shapes to native
class dispatch. This operand-frame unit does not establish Python protocol
fallback semantics.

## 2026-09-15: source inventory

Decided: derive names, signatures, aliases and syntax from CPython 3.14.4 at
`23116f998f6789d8c2fbe5ed5b8146854c8c2a4f`. The source lock retains exact Python
files, C slot and Clinic regions, ASDL and reference directives, with original
line positions and SHA-256 hashes. The class journal's named requirements are
a separately pinned input. Normal extraction and checking use local files;
an explicit refresh verifies complete upstream files before publishing an
absent destination. Python 3.12 can read the pinned inputs.

The inventory keeps member identity, slot role, callable contract and syntax
operands separate. CPython's accelerated operator functions replace fallback
definitions before trailing aliases run. `operator.inv` and `operator.invert`
are therefore distinct functions. Guarded `concat` and `iconcat` bodies remain
complete source forms; their final addition cannot erase the sequence guard.
The manifest and source README record immutable upstream URLs and exact spans.

Rejected: another maintained dunder roster or live-module introspection as the
build authority. A roster repeats the reference, and live introspection cannot
recover C dispatch roles or a missing export on another supported interpreter.
The running CPython interpreter instead supplies independent signature, alias
and syntax controls. Comparison swaps and C entry recipes remain additional
source relations for the dependent native dispatch unit.

Tried: the first source packs omitted the slot table's closing line, read only
one line of a Clinic signature and missed lazy typing exports. Each failed with
its named parser error. Exact records and corrections are in
`ai-tmp/ai-protocol-source-receipt.md`. Repository review then found 155 Ruff
findings, including inventory complexity 54 against the limit 35. Separating
export discovery from accelerated callable resolution and applying the existing
style policy resolved those findings. The source inventory and upstream bytes
remain unchanged. Vendor inputs are excluded from authored-code linting;
their byte checks remain mandatory on every inventory read.

Verified: the integrated source suite passes all 13 tests on CPython 3.14.4.
Python 3.12.13 passes 12 and skips the explicitly versioned live-3.14.4 oracle.
Both interpreters accept the same complete inventory and refresh all 19 full
upstream files into identical inputs: 22 source records, 406 exact segments,
447,599 retained bytes. Their offline audit refuses sockets, subprocesses and
`os.system` and confirms no PeTTa import. The commands are:

```sh
python extensions/python/tests/repository/test_protocol_source.py
python3.12 extensions/python/tests/repository/test_protocol_source.py
python extensions/python/tools/protocol_source.py inventory > ai-tmp/ai-classes-c60-inventory.json
python extensions/python/tools/protocol_source.py check ai-tmp/ai-classes-c60-inventory.json
python3.12 extensions/python/tools/protocol_source.py check ai-tmp/ai-protocol-source-inventory.json
python ai-tmp/ai-verify-protocol-source-refresh.py extensions/python/tools/protocol_source.py
python3.12 ai-tmp/ai-verify-protocol-source-refresh.py extensions/python/tools/protocol_source.py
sh check.sh ruff deptry layering evidence policy-inventory
jscpd --reporters console,json --format python --min-lines 5 --min-tokens 50 --noTips --output ai-tmp/ai-classes-c60-clones extensions/python/tools/protocol_source.py extensions/python/tests/repository/test_protocol_source.py
```

Source output has 572 members, 234 callables and 100 forms, 90 direct. Required
sets contain 109 reference identities, 74 journal hooks, 51 APIs and 81
parameters. The live signature/alias test covers 231 available signatures and
46 aliases. All selected static checks pass; the clone scan reports 1,181
handwritten lines, 16,667 tokens and zero clones. Evidence reports 7,853 claims
and zero unbacked references. Receipts are `ai-tmp/ai-classes-c60-source314.log`,
`ai-tmp/ai-classes-c60-source312.log`, `ai-tmp/ai-classes-c60-refresh314.json`,
`ai-tmp/ai-classes-c60-refresh312.json`, `ai-tmp/ai-classes-c60-checks.log` and
`ai-tmp/ai-classes-c60-clones.log`. Deptry passes while reporting its skipped
`notebooks/tour.ipynb` parser diagnostic; that output is retained in the checks
log. These checks establish source extraction and its Python floor, not native
protocol execution on either interpreter.
