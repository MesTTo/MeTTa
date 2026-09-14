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
