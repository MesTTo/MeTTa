# Complete Python call signatures

Goal: project Python's argument grammar through native callable values,
parameter records and independent positional and keyword-entry segments.

## 2026-09-14

Source: `_catalog/call_signatures.py:project` already records all five
parameter kinds, annotations and defaults. `NativeCallable.application`
already binds them when given an exact native lambda image. Its named
reference path instead chooses the native parameter count from the number
of supplied arguments. These counts differ when defaults or either variadic
segment participates. The compiled-method layer already has a separate,
visible application relation for projecting collected values into native
expressions and dictionary spaces.

Decided: named references read the existing native ports and their live
contracts. A fixed positional port of the supplied arity is the specific
native dispatch case. Otherwise exactly one accepting contract supplies the
layout; overlapping variadic layouts require the caller to carry an explicit
native lambda image. A retained name observes later contract edits. No
parallel signature registry or cached Python callable owns this decision.

Rejected: equating supplied argument count with canonical slot count, because
`f(value, /, offset=2, *extra, scale=3, **options)` has five canonical slots
and accepts arbitrarily many positional and keyword entries. Also rejected
changing existing handwritten lambda contracts from borrowed tuple/dict
values to another grain. The explicit native application relation already
states that projection for compiled methods and can serve other compiled
callables.

Tried: the named-port fixture fails all nine cases before the repair. A
single contract reports an anonymous `*args` signature, a defaulted call
returns an unapplied value, overlapping variadic ports do not refuse, and
the binding property exposes both missing binding errors and wrong results.
Command: `python -m pytest -q -n 3 --benchmark-disable
--randomly-seed=1125382488
extensions/python/tests/ch03_atoms_and_expressions/test_callable_ports.py`.
Log: `ai-tmp/ai-classes-c47-ports-before.log`.

Verified: that fixture plus `test_callable_values.py`,
`ch11_python_as_a_notation/test_expanded_call_values.py` and
`ch09_types/test_class_call_contracts.py`, under the same pytest options,
passes 94 cases after the repair. Log:
`ai-tmp/ai-classes-c47-ports-after.log`. The full consumer run also includes
compiled frames and captured positional-only parameters with repeated
keyword labels.

Tried: review removed speculative argument binding when a port is unique or
has the exact fixed positional arity. A string-subclass keyword fixture
compares its hash/equality effects with an explicit native image. Its first
run compared two fresh borrowed dictionaries by native identity and failed
with `(received 1 2 <tuple> 4 <dict>) != (received 1 2 <tuple> 4 <dict>)`;
2004 other tests passed. The corrected fixture compares Python contents and
effects. The same identity distinction is present at pristine `c75181adc`:
`python ai-tmp/ai-classes-c47-grounded-control.py` prints `native_equal False`
and `python_values_equal True` against both providers. The control export's
202 Python package files match their Git blobs at that cut. Logs:
`ai-tmp/ai-classes-c47-ports-final-python.log`,
`ai-tmp/ai-classes-c47-grounded-{main,c751}.log` and
`ai-tmp/ai-classes-c47-grounded-control-sources.log`.

Verified: `sh ai-tmp/ai-classes-c47-ports-verify.sh final2` passes 2005 Python
cases and 265 native tests plus 63 subtests in thirteen suites. The script
deletes engine/library QLF files before each phase and uses the exact
commands in `ai-tmp/ai-classes-c46-{python,native,checks}.command`. Logs:
`ai-tmp/ai-classes-c47-ports-final2-{python,native,checks}.log`. Layering,
mypy, refusal grounds and evidence pass. Ruff requests combining two nested
conditions (`SIM102`); the equivalent conjunction is checked by the focused
consumer suite and static checks before commit.

Measured: `jscpd --min-lines 5 --min-tokens 70 --max-lines 10000 --max-size
1mb --noTips --reporters console,json --output
ai-tmp/ai-classes-c47-ports-clones-final
extensions/python/metta/_catalog/call_values.py
extensions/python/metta/_declare/call_syntax.py` reports zero clones across
662 lines and 7643 tokens before that one-line condition flattening. Log:
`ai-tmp/ai-classes-c47-ports-clones-final.log`.

Verified: the flattened condition passes the same four-file focused command
with 100 cases, including the two keyword-effect witnesses. `sh check.sh
layering ruff mypy evidence refusal-grounds` passes every lane. Logs:
`ai-tmp/ai-classes-c47-ports-final-focused.log` and
`ai-tmp/ai-classes-c47-ports-final-checks.log`. The clone command above with
output `ai-tmp/ai-classes-c47-ports-clones-publish` reports zero clones across
662 lines and 7644 tokens; its log has the same name plus `.log`.

Open: ordinary definition lowering must preserve literal-default head
patterns. Nested definitions and lambdas need creation-time defaults and
retained lexical bindings. Their current source refusals and the dropped
nested positional-only parameter are reproduced in
`ai-tmp/ai-classes-c47-signature-baseline.log` by
`python ai-tmp/ai-classes-c47-signature-probe.py` with the worktree's Python
environment and cold engine/library QLFs. Operation declarations still
require a separate audit against their host application boundary.

## 2026-09-14: compiled parameter applications

Source: `ClassDeclaration.argument_sources` already packs fixed values,
positional segments and keyword-entry segments into canonical native slots.
Each method nevertheless registers a Python closure capturing its class,
signature lookup and target. Ordinary definitions would need another callback
ownership registry to copy that arrangement.

Mapped: closure conversion separates code and environment; defunctionalization
makes the environment explicit data consumed by a shared application function.
Danvy and Nielsen describe that transformation in section 1 of
[Defunctionalization at Work, BRICS RS-01-23](https://www.brics.dk/RS/01/23/BRICS-RS-01-23.pdf).
Here the environment is already a native lexical home and callable image.
The existing parameter, binding and application relations describe its grammar.

Decided: factor the existing packing algorithm and link one shared parameter
binder. Its four native inputs are home, canonical callable image, positional
frame and keyword-entry frame. It reads the live contract and returns source;
the caller evaluates that source in its lexical home. Canonical method images
own the single signature; bound and unbound entry images refer to it through
`@python-binding`. This prevents the canonical application from re-entering
its own argument wrapper. Constructor allocation retains its transaction and
source defaults, while methods hold already evaluated defaults.

Rejected: per-definition Python binder closures, because they duplicate an
ownership registry and obscure the environment in a host object. Also rejected
changing handwritten callable collectors globally: explicit native application
relations already distinguish compiled expressions and dictionary spaces from
borrowed host tuple and dictionary values. Revisit either decision only if a
native image cannot express an actual callable contract or retention edge.

Tried: the independent native fixture initially used noeval expressions as
raw Atom arguments, stored a symbol through native add-atom, and declared
an Atom result while expecting body evaluation. Those are three different
native contracts. The corrected fixture uses let-bound inputs, a headed
effect marker and an evaluated result. It compares variables within each
value or stored row; separate native occurrences have separate variables.
The initial consumer run passes93existing cases. The corrected fixture then
exposes two actual keyword-storage failures: `(+ 1 2)` becomes3 and a scalar
symbol with a rule becomes97. Logs:
`ai-tmp/ai-classes-c48-parameters-{after,witness-storage}.log`.

Measured: `python ai-tmp/ai-classes-c48-keyword-boundary.py` compares
`(let $pairs (noeval DATA) (evalc (dict-space $pairs) HOME))` with
`(evalc (let $pairs (noeval DATA) (dict-space $pairs)) HOME)` for those two
values. The former preserves neither; the latter preserves both, here and
at pristine `c75181adc999adf0028616ee69565e2bbfbf739f`. The control runs with
METTA_ROOT and PYTHONPATH selecting its export. Its344engine, library and
Python provider files match the cut's Git blobs, verified by
`python ai-tmp/ai-classes-c48-control-sources.py`. Logs:
`ai-tmp/ai-classes-c48-keyword-boundary-{main,c751}.log` and
`ai-tmp/ai-classes-c48-control-sources.log`.

Decided: bind dictionary entries inside their lexical evaluator. This is the
same value boundary that `apply_sources` already preserves for scoped lambda
bodies. Native evaluation is unchanged; the compiled packing expression must
keep its data binding in the evaluator that consumes it.

Tried: a named canonical method image otherwise receives borrowed collectors
and reports `(BadArgType 4 Expression tuple)`. Publish its existing compiled
application relation on the canonical image as well as the bound and unbound
entries. The canonical-method witness passes after that relation is added.
Log: `ai-tmp/ai-classes-c48-canonical-before.log`; the passing case appears in
`ai-tmp/ai-classes-c48-parameters-witness-storage.log` beside the two keyword
storage failures that motivated the packing correction.

Verified: `sh ai-tmp/ai-classes-c48-parameters-verify.sh verified` passes
2027 Python cases, 265 native tests plus 63 subtests in thirteen suites,
and layering, Ruff, mypy, evidence and refusal grounds. The script deletes
QLF files before each phase and runs the unchanged commands recorded in
`ai-tmp/ai-classes-c46-{python,native,checks}.command`. Logs:
`ai-tmp/ai-classes-c48-parameters-verified-{python,native,checks}.log`.

Measured: `jscpd --min-lines 5 --min-tokens 70 --max-lines 10000 --max-size
1mb --noTips --reporters console,json --output
ai-tmp/ai-classes-c48-parameters-clones-final
extensions/python/metta/_catalog/call_values.py
extensions/python/metta/_declare/call_syntax.py
extensions/python/metta/_declare/classes.py
extensions/python/metta/_declare/methods.py` reports zero clones across
2024 lines and 26274 tokens. Log:
`ai-tmp/ai-classes-c48-parameters-clones-final.log`.

Open: `python ai-tmp/ai-classes-c49-collector-returns.py` isolates a separate
result representation gap. Typed tuple and list results return correctly;
both a dictionary literal and a keyword collector returned as `dict[str, int]`
report `EngineError: one() expected exactly one answer, got 0`. Log:
`ai-tmp/ai-classes-c49-collector-returns-before.log`. This remains mandatory
before completing callable support. An explicit `Atom` result instead quotes
its body by the existing native contract and must retain that behavior.

## 2026-09-15: mapping result conversion

The collector result gap above is closed through the annotation-owned
container inverse. The native body still returns its dictionary space;
mapping annotations admit and reconstruct that value. The design and
verification are recorded in `2026-09-14-mapping-space-results.md`.
Ordinary and lexical signature lowering remain open.
