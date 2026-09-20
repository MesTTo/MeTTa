# Compiled calls retain their positional and keyword frames

Goal: keep completed native operand values separate from Python call control.

## 2026-09-14

Tried: the call-species probe observes 117 differences and 33 matching controls.
At pristine c75181adc it observes 83 differences, 27 matching controls and two
existing expansion refusals. Commands use `python
ai-tmp/ai-classes-c46-host-values-probe.py` with each checkout's METTA_ROOT
and PYTHONPATH. Logs: ai-classes-c46-host-values-controls.log and
ai-classes-c46-host-values-c751.log.

Those counts mix a framing defect with intentional representation choices.
`Defined.__call__` projects ordinary Python containers to native expressions;
`Grounded` retains a borrowed host container. `_catalog/containers.py` states
the same structural image and annotation-directed reconstruction contract.
The raw grounded-call floor then uses `surface.pl:py_arg_norm/2`, converting
native symbols and expressions to Python strings and lists. This differs
from the registered operation's atom codec. Changing every container image
to recover its former Python species would change that established notation.

Rejected: signature introspection at every opaque call. A callable's
`__signature__` may run arbitrary code, and ordinary Python invocation never
needs it. A trial shared atom invoker also changes the host tuple-result
contract. It passes 66 and fails 2 existing cases in
ai-classes-c46-typed-invocation-consumers.log. The other failure is an exact
assertion about the old generated body. This does not justify another type
registry or a tagged-container storage model.

Decided: retain independent native positional and keyword frames through
the existing `host.apply` operation. Its positional list cannot become the
terminal `(Kwargs ...)` protocol packet, and its keyword dictionary has
already been assembled. The host bridge continues to own input and output
conversion. Native callees keep their existing live application relations.
Host islands and simple carried calls use the same frame assembler as
expanded calls. A carried source variable is a completed value; its binding
must quote it rather than evaluate it again.

The existing CPython call protocol is the same structural separation:
`tp_call` accepts a positional tuple and an independent keyword dictionary;
vectorcall carries positional count and keyword names separately.
[CPython call protocol](https://docs.python.org/3.14/c-api/call.html#the-tp-call-protocol).
The trial using `host.apply` passes 67 of 68 existing cases in
ai-classes-c46-structural-frame-consumers.log. The remaining assertion names
the old direct-call spelling, not a different answer.

Tried: the tracked frame fixture initially fails 20 and passes 22 cases.
Four failures used an ordinary variadic definition, which still has the
pre-existing `_parameters` refusal. Using supported fixed-arity native
definitions gives 17 failures and 25 passes. A pristine c751 control on
the 24 plain host-call cases fails 12 and passes 12. Logs:
ai-classes-c46-frames-before.log, ai-classes-c46-frames-before-corrected.log
and ai-classes-c46-frames-c751.log. The ordinary variadic definition remains
a separate signature-lowering obligation.

The first implementation cohort fails 32 and passes 78. Its island binding
used unimported `_expr` and `S`; the local Expression/Symbol spelling fixes
that error. Four remaining operand-value failures exposed `append` reducing
its result before `_python-bind-call` received it. The trace in
ai-classes-c46-frame-trace.log prints `BIND (3)` for a supplied `(+ 1 2)`.

Decided: use the existing `union-atom` structural concatenation. Both
operations ultimately use Prolog append, but `lib_builtin_types` declares
union-atom's result as Atom and append's as Undefined. The former keeps the
assembled run as data. The subsequent trace prints `BIND ((+ 1 2))` on each
direct and expanded call. No engine primitive or container representation
change is required. Logs: ai-classes-c46-frame-union-trace.log and
ai-classes-c46-frames-union.log; the four-file cohort passes all 110 cases.

Tried: the complete first consumer run passes 1981 tests and fails six
computed Atom/Expression field assignments. Linking a call-binding operation
retires generated functions while the native runnable cache still references
them. The pristine c751 control reproduces that independent engine defect.
The separate runnable-artifact-dependencies journal records its repair and
verification; moving registrations earlier would only hide the stale cache.
Log: ai-classes-c46-python.log.

Tried: `sh ai-tmp/ai-classes-c46-verify.sh` after the cache repair passes
1990 Python tests, including the nested-data Hypothesis property, and 265
native tests plus 63 subtests in thirteen suites. Each phase deletes
engine/lib QLFs first. Layering, Ruff, mypy and refusal-grounds pass.
Logs: ai-classes-c46-verified-{python,native,checks}.log. The Python run
prints a 180-second faulthandler diagnostic during class-space cleanup;
cleanup completes and the run exits zero without intervention.

The first evidence check reports six unbacked references because its Git
file census excludes the new, unstaged test file. The existing claims name
the correct test functions. Staging the fixture makes it visible to the
evidence census; no code or test is changed to satisfy that check.

Tried: `sh tools/check.sh evidence` after staging passes with zero unbacked claims.
Log: ai-classes-c46-verified-evidence.log. The three production files' clone
scan reports 2342 lines, 22544 tokens and zero clones. Command: `jscpd
--min-lines 5 --min-tokens 70 --max-lines 10000 --max-size 1mb --noTips
--reporters console,json --output ai-tmp/ai-classes-c46-clones
extensions/python/metta/_compile/call_syntax.py
extensions/python/metta/_compile/expressions.py
extensions/python/metta/_declare/call_syntax.py`.
