# Expanded calls use native callable contracts

Goal: preserve Python call construction while the callable, its argument
contract and its keyword mapping remain native values that can be rewritten.

## 2026-09-14

Decided: compile argument evaluation and assembly once for arbitrary callable
values. Native `let`, `append`, `collapse` and `eval` carry the operands and
execute the resulting application. The binding operation only constructs
that application. Named keyword runs evaluate before their merge; a lone
starred operand materializes after keywords, while mixed positional runs
materialize before them. CPython v3.14.4 `Python/codegen.c:4022–4072` supplies
the ordering, and `Objects/dictobject.c:3722–3836` supplies mapping merge.
`_PyDict_MergeEx` preserves dict-subclass and key-iteration effects. Native
keyword spaces read their current occurrence rows.

Rejected: a Python mapping loop, which adds observable hashes and changes
dict-subclass behavior; copying every accumulated keyword prefix, which
makes repeated expansion quadratic; making arbitrary expression heads into
registered spaces. The operand relation already distinguishes spaces.

Definition and operation reflection owners publish the existing
`@python-callable` records. Each native port supplies its parameter labels
and answer cardinality. Definition rows carry their lexical home; global
operation rows retain the caller's home. Replacement, rollback and retirement
use the existing fact ownership. Repeated variadic labels cannot identify
individual keyword positions, so those ports have positional-only names.
Ordinary definition defaults remain native head patterns.

Tried: the initial shared cohort passes 53 cases, including compiled, host
and operation calls, native contract/default/body edits, keyword-space edits
and stream/container consumers. `ai-classes-c33-call-assembly-named.log`
records `python -m pytest -q -n 3 --benchmark-disable
--randomly-seed=1125382488` over `test_expanded_call_values.py`,
`test_call_site_keywords.py`, `test_callable_values.py` and
`test_callable_operation_arguments.py` under their tracked chapter folders.

A lifecycle fixture initially passed the operation's Python wrapper, which
correctly retained its Python function after native re-registration. The
corrected fixture passes a native symbol and retains the wrapper as a control.
The native arity matrix then exposes three failures: converted multi-arity
functions lose keyword labels, and variadic streams become returned iterables.
`ai-classes-c33-native-ports-before.log` records three failures and fourteen
passes for `python -m pytest -q --benchmark-disable
--randomly-seed=1125382488
extensions/python/tests/ch11_python_as_a_notation/test_expanded_call_values.py`.
The errors are `missing a required argument: 'x2'` and
`Python TypeError in (py-iter-once 3): 'int' object is not iterable`.

Decided: anonymous source recovery uses clause ownership independently of
whether a signature exists. On application, an unannotated forwarding lambda
can select its target's native port from the supplied arity. Recognize the
existing `cons-atom`/`eval` forwarding expression structurally, preserving
its lexical home and captures. Its fixed binders must remain distinct and
must not occur in captured operands. An explicit contract on the original
lambda takes precedence. This is eta contraction at the argument boundary;
it neither executes nor copies the target's body. GHC 9.12.2 applies the same
free-variable side condition in `compiler/GHC/Core/Opt/Arity.hs:tryEtaReduce`:
https://github.com/ghc/ghc/blob/ghc-9.12.2-release/compiler/GHC/Core/Opt/Arity.hs.

Rejected: caching a callable's signature, recognizing generated names by
spelling, or publishing another signature when a value crosses a space.
These would separate the value from later native contract changes.

The partial-application controls exposed the same issue at value creation:
the first visible type arrow froze an optional three-argument operation's
reference to one parameter. Capturing that parameter left a nullary value;
the next expanded call raised `too many positional arguments` in
`ai-classes-c33-call-captures.log`, with 61 other cases passing.
Named references therefore use the existing segment forwarding form for
every arity. Their argument boundary reads the current native port; an
anonymous lambda retains its actual binder. This also permits later arity
changes without rebuilding stored references. The single-arrow and unknown-
arrow construction branches are removed.

The isolated call-layer tree passes 1,082 Python cases, but two existing
tests identify static bracket builders wrongly classified as computed
callees, and three overload fixtures fail during space teardown. All ten
controls in `test_library_fixes.py::test_compiled_boolean_call_is_a_direct_condition`,
`test_mention_doors.py::test_compiled_operator_word_calls_preserve_composite_images`
and `test_compiled_overload_declarations.py` pass at pristine c75181adc:
`ai-classes-c33-call-control.log`. The expanded compiler now consults its
existing builder identities. Contract rows retain the immutable native
space atom, so removing reflection after native teardown does not call a
released host handle. The failing run is
`ai-classes-c33-general-call-A-python.log`.

The compiler depends on the catalog's shared signature representation.
`BUILDS_ON` records that foundation, and `layergen.py --write` derives the
import contract and developer map. Duplicating the signature schema in the
compiler would create two authorities for the same record.

Stacked clauses may give the same positional port different local parameter
names. Publishing each roster independently made expanded positional calls
fail with `a native callable needs one Python signature and answer-cardinality
declaration`. The equal-name control passes and the different-name case
fails in `ai-classes-c33-stacked-contracts-control.log`. Publish one aggregate
contract per arity: a common roster keeps its keyword names, while ambiguous
rosters remain positional. The native equation family still performs dispatch.
The first fixture mistakenly used a literal head-pattern parameter as a body
variable; its compiler refusal is in `ai-classes-c33-stacked-contracts-before.log`.

The final shuffled cohort exposed a fixture collision: the integration test
already registers `target` with raw_det ports zero through four. A later
typed operation on that global name adds a det port and is refused because
one operation has one kind. The same two registrations print the identical
error at pristine c75181adc and at the call-layer tree; run
`python ai-tmp/ai-classes-c34-operation-kind-probe.py` with each checkout's
`extensions/python` on PYTHONPATH. The current and control logs are
`ai-classes-c34-operation-kind-{current,control}.log`, both ending `present`.
The new independent call fixture now owns `expanded-known-target` and removes
that registration in its cleanup.
