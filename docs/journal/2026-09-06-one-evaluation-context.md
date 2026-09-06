# One evaluation context
Goal: preserve the active algebra and answer demand through tagged operations,
query guards, held cursors and retained-answer reinterpretation.

## 2026-09-06

Tried: `METTA_PATH="$PWD" PYTHONPATH="$PWD/extensions/python" sh bounded.sh
--ceiling 300 "$CHECK_PY"
ai-tmp/ai-carrier-probe.py` on `749f5864a9cd84863fb177e0c1e985b14ab3772e`.
Both tagged queries returned annotation `[1]`. Their four extend calls, one
combine and one guard observed `None` with no annotations row and `tropical`
with that row, although the asks selected `observed` and `observed-row`.
Ranked explicit limit, slice and source `top` all returned `[best, middle]`,
but the provider received `[None]`, `[2]` and `[2]` respectively. Direct
retained-answer pairing with an algebra declared in a separate space already
returned `6`; its callback context and same-name collision remain to test.

Tried: source and history search found the carrier stack introduced by
`c7468b2789746bcf95c4bacc0e2d517ec4d972fa` and the operation budget from
`51e719767e3dd322a9cf88bd096410bbc5647493`. The operation path passes neither
carrier nor demand to either its ordinary or inference-accounted crossing.
The tagged guard crosses separately with the same omission. Ordered cursor
construction replaces the producer limit with zero. A Python slice compensates
by implementing a separate provider-order license.

Decided: represent one evaluation context as algebra, answer limit and order.
The immutable Python record travels through the existing call arguments and
resource record; the engine holds its corresponding term in the existing
cleanup-delimited dynamic stack. `metta_with_under/2` changes the algebra in
that context and retains its demand. No additional ambient carrier channel is
needed. Internal operation evaluation retains plain atom results, while public
answer doors retain their existing tagged answer shapes.

Decided: the ordered provider license belongs beside `metta_top_pushable/2` in
the engine. A single unguarded pattern may offer its positive bound only when
its source promises the same algebra/order, Exact routing and best-first
emission. Joins and guards retain the complete candidate stream. Slices may
supply a tighter demand to a pristine repeatable view; the engine makes the
same ordering decision for slices and explicit limits.

Rejected: passing public `under=` to an internal algebra operation, because it
changes operation results into tagged answers and can recursively select the
tagged evaluator. Revisit only if public evaluation and internal operation
execution acquire the same result contract.

Rejected: a second Python callback-only carrier variable, because engine
operations and nested held engines must read the same selection. The existing
engine dynamic scope is the execution authority.

Prior art: this is context propagation across execution boundaries, combined
with safe relational limit pushdown. Distributed tracing attaches and restores
one context; transactions delimit a complete state lifetime; locale and decimal
contexts override only their selected policy; compiler environments carry
bindings through recursion; database scans combine filter, order and fetch
requirements. These analogies select explicit context transport and one
cleanup boundary rather than per-callback patches.
OpenTelemetry Python v1.36.0's `ContextVarsRuntimeContext.attach/detach` confirms
token-based restoration of the previous whole context:
https://github.com/open-telemetry/opentelemetry-python/blob/v1.36.0/opentelemetry-api/src/opentelemetry/context/contextvars_context.py
DataFusion 55.0.0's `TableProvider.scan` documents why an inexact filter
prevents a scan limit from being pushed down:
https://docs.rs/datafusion/55.0.0/datafusion/datasource/trait.TableProvider.html#tymethod.scan
No dependency or copied implementation is needed; both principles already have
local implementations in the context stack and licensed provider options.

Tried: the final 30 Python regression cases on a complete archive of
`749f5864a9cd84863fb177e0c1e985b14ab3772e`, with the same native libraries and
Node dependencies: `sh extensions/python/test.sh
 tests/ch06_many_answers/test_evaluation_context.py -n 0` returned 18 failed,
12 passed. On the changed tree the command returned 30 passed. The controls
retain all candidates for guards, joins, mismatched algebras, partial routing
and sources without best-first emission. Callbacks check all three context
fields, restoration, nested carrier overrides and exception cleanup.

Tried: the first integration run rejected the internal context wrapper under
an inference quota with `Domain error: metta_py_wrappable expected, found
metta_py_in_evaluation_context`. The wrapper must join the existing executable
predicate roster. After that correction, ordered queries reported
`Unknown procedure: metta_ordered_match_limit/6`. Removing compiled caches did
not change it: the spaces module's explicit export list also needed the new
published service. The Prolog regression now calls it unqualified to exercise
host visibility as well as its implementation.

Tried: review compared scoped bindings at the new crossing with the shipped
tree. A guard bound to threshold 5 returned `[a]` before and `[]` after;
an operation bound to weight 5 received `5` before and `weight` after. The
raw evaluator had bypassed `Space._prepared_ask`. Preserve that preparation
for guards and operations, including atom keys, literal strings and host
object identity, before entering the context. This is required integration.

Tried: the reproduction script now returns the same answers as before, while
all combine, extend and guard calls observe `observed` or `observed-row`
according to the ask. Explicit limit, slice and source top each return
`[best, middle]` and each offer provider limits `[2]`. Direct pairing still
returns `6`; the same-name collision and callback tests now pass as well.

Tried: clone detection over the five changed Python implementation files with
`jscpd --reporters ai --noTips --max-lines 10000 --max-size 2mb` reports
10 clones and 3.3 percent duplication. The identical shipped-file selection
reports the same 10 clone pairs and percentage. They lie in existing query
implementations and duplicated public documentation; the context adds no
clone pair. The default 1000-line ceiling skips these large modules, so the
explicit larger ceiling is necessary evidence.

Tried: the first full Python suite returned 5 failed, 3515 passed and 48
skipped in 134.66 seconds. One regression fixture's suppression reason was
shorter than the repository's documented threshold and now names its precise
protocol obligation. The tracked-path check also found a shipped absolute
workspace path in the release journal, introduced by
`2e26e376b` and owned by the repository author. Its spelling is now the
repo-relative sibling `../repin`; the historical measurement and its path
length comparison are unchanged. The other three failures came from the
shrink ledger and require a stable source snapshot before attribution.

Tried: stable-source shrink-ledger tests returned four passes. The classifier
uses `inspect.getsource` on imported methods; source edits shifting their line
positions invalidated the earlier run. The ledger and generated page need no
change. The next full Python run returned 1 failed, 3535 passed and 48 skipped:
`P0.13 suppression burn-down increased (observed, maximum): {'ARG': (153, 152)}`.
The fixture now names its unused positional argument `_pattern` and requires
no suppression; the repository's existing suppression ceiling remains intact.

Tried: the final Prolog fixture against the shipped engine returned six failed
and thirteen passed. The carrier witness reported `tropical==observed`; the
new context and ordered-limit services were absent. With the implementation,
the same nineteen answers cases pass, as do thirty-seven catalog cases and one
subtest. The full `sh engine/test.sh` returned exit zero, with seventy-five
suite receipts reporting 2178 tests and 1436 subtests. The combined Python
carrier, binding, existing algebra and shim-surface selection returned
113 passed in 4.44 seconds.

Tried: `sh check.sh llms llms-selftest layering lib-surface aio-mirror reference`
returned exit zero on the completed implementation. All six named lanes are
green: 943 cross-subsystem calls covered by 81 contract lines, 470 library
equations checked, zero cheat-sheet findings, 61 planted cheat-sheet cases
passed, and all three generated mirrors plus reference pages agree with their
sources. No generated file needed rewriting.

Tried: final error-path review reproduced a public refusal rendering the
whole `DeclaredAlgebra` descriptor after the call began passing that object
internally. The existing message is
`algebra_derivation_did_not_reach_fixpoint(ranked, rounds=64)`. Resolve the
message through `declaration.name`, preserving that contract. Its regression
failed before the repair and passes now; it also passes on the shipped tree.
The final thirty-one-case shipped run returns 18 failed and 13 passed. The
current regression, binding and policy selection returns 52 passed.

Tried: final `sh extensions/python/test.sh` returned exit zero with
3537 passed, 48 skipped and 5 warnings in 114.35 seconds. The skips are the
suite's reported optional cases, not converted failures. The warnings come
from benchmark-plugin and dependency deprecations. Independent review of the
completed diff found no additional introduced semantic defect. All 106
existing full commit references in changed files resolve to commit objects.

## Unification

Decided: one ask owns one evaluation context containing its selected algebra,
answer limit and ordering. Tagged arithmetic, guards, held annotated cursors
and retained derivation interpretation transport that record to the engine's
existing dynamic scope. Engine algebra overrides replace only the carrier;
cleanup restores the complete prior context. One engine license determines
whether ordered demand may cross to a provider. Explicit algebra objects
retain their identity during interpretation.

Remaining siblings, recorded without changing their behavior:

- `extensions/python/metta/_space_execution.py:850` and
  `extensions/python/metta/shim.pl:3286` open a plain lazy answer cursor
  without copying an already active engine context. An executed custom
  operation observes `review-nested-carrier`, opens `space.answers(...)`,
  and its nested callback observes `None`. The shipped tree loses that nested
  carrier too. The ordinary match cursor at
  `extensions/python/metta/shim.pl:1266` has the same source-level omission;
  it was not separately reproduced.
- `extensions/python/metta/shim.pl:2756` receives a match-count limit but
  installs only the algebra. Evaluation-count siblings at lines 3431 and
  3439 also carry only the algebra. They inherit an outer demand or default
  to zero instead of recording their own count request. Aggregate limits
  still apply to the query.
- `extensions/python/metta/algebra.py:1443` and
  `extensions/python/metta/shim.pl:2782` count tagged proof trees without
  installing evaluation context. Their aggregate does not call custom
  algebra arithmetic.
- `engine/spaces/bounded_matching.pl:840` and line 858 implement generic
  take and single-match take with local limits, without recording demand
  in evaluation context.
- `engine/spaces/bounded_matching.pl:890` implements generic top with a
  local count. Its single-match sibling at line 906 shares the ordered
  provider license but does not construct context demand for its count.
  The provider receives that limit through the existing options path.

Except for the executed nested-cursor witness, these are source-inspected
context boundaries, not claims of incorrect answers. They remain listed as
requested; the carrier propagation and ordered-match limit failures have
separate executed regressions above.
