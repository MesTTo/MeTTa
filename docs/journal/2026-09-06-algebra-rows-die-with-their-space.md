# Algebra declarations share their space's lifetime and check carrier values
Goal: close catalog declaration lifetime leaks, admit tensor algebras by type, and report one specific grounded argument refusal.
Constraint: laws require exhaustive checking over an explicit finite carrier; no law follows from a type or samples.

## 2026-09-06
Tried: the shipped 749f5864a9cd84863fb177e0c1e985b14ab3772e with `METTA_PATH="$PWD" PYTHONPATH="$PWD/extensions/python" "$CHECK_PY" ai-tmp/ai-algebra-reproduce.py`. Both the named `&energies-repro` and reused `&pyspace_1` reject redeclaration with `algebra_already_declared(recycled-product)`. Both `space.algebra` and the callable module reject array max over two equal zero arrays with `algebra_carrier_not_closed`; the inputs and output are distinct live object handles.
Tried: the duplicate-error probe reports both `BadArgType 1 Number ndarray` and `BadArgType 1 Number DLTensor`. The same object supplies two type witnesses to one refusal generator.
Decided: follow the existing typing-rule retirement in 84327245373bba29fba00cf2cea62d8257a9f5cb. Catalog rows and the mechanisms they install leave through the existing release lifecycle.
Decided: `type=` names a Python type, a MeTTa type atom, or a predicate. It validates inputs and results without supplying a law certificate. `carrier=` remains an explicit finite enumeration, and only exhaustive checking of that finite domain permits a certificate. Tensor membership and equality compare values and shapes, never opaque handle identity. This boundary was explicitly confirmed: samples cannot certify a law over an infinite type. A refusal names a finite carrier or `prov` plus `.under()` as the remedies.
Rejected: certifying tensor laws from representative samples, because the current certificate is exhaustive and sampling would weaken it silently.
Rejected: globally changing grounded-atom equality, because storage and matching intentionally preserve opaque object identity. Algebra value comparison is its own semantic boundary.

Research mapping: catalog retirement is the same ownership rule as database cascading foreign keys, resource scopes, and compiler symbol-table scopes. Carrier membership is domain membership as in SymPy's `Domain.of_type`, runtime refinement predicates, and Python's `isinstance`. Exhaustive law checking is finite-model checking. One grounded refusal is diagnostic selection over several witnesses, distinct from nondeterministic execution alternatives.

Tried: the final lifecycle plunit fixture on the shipped tree fails four tests
and passes five controls. Its Python drop/redeclare fixture fails both named
and pooled cases on that tree. The repaired plunit fixture passes all nine;
the repaired Python lifecycle and type fixtures pass 17 tests at that point.
The fixtures distinguish release from ordinary clear and preserve declarations
when storage cleanup fails or a transaction rolls back.

Decided: retire these 24 shipped row families through
`with_metta_space_releasing/2`: `handles`, `on-error`, `annotations`, `source`,
`context`, `admits`, `capacity`, `writes`, `events`, `emits`, `image`, `on`,
`agenda`, `tabled`, `defined`, `subscription`, `inherits`, `restricted`,
`grants`, `parametric`, `covers`, `pre-add`, `post-add`, and `algebra`.
The first 23 own their first argument; algebra owns column 10 including its
head. Custom context-routed kinds share the same retirement. Law certificates
and finite carriers are fields of the algebra row. Semiring and algebra-law
vocabularies, alias claims, ordered-semiring claims, and preset algebra rows
are global definitions and remain global. Removing rows through
`metta_remove_atom/3` preserves invalidation; pre/post hooks also retire their
live registry claims. Catalog retirement runs after successful storage cleanup
so policies remain available while clearing.

Rejected: removing every row that mentions the space's symbol, because a
vocabulary entry or operation with that spelling need not belong to the space.
Rejected: clearing only reflected hook rows, because the live compiled hook
would still execute.

Tried: finite tensor equality now certifies the entire four-element carrier of
two-coordinate Boolean arrays through both constructors. All five finite
tensor regressions pass, including false associativity, shape mismatch and NaN
refusals. Initial identity validation catches NaN before law checking, because
NaN does not equal itself by value. A shape fixture originally omitted its
multiplicative identity; including that identity makes the fixture exercise
closure instead of initial membership.

Decided: the algebra equality seam uses exact shape and element equality,
following NumPy's `array_equal` semantics in
`numpy/_core/numeric.py` at release `v2.5.0`. It leaves ordinary atom matching
and opaque storage identity unchanged. Finite membership and law equations
use the same relation. Python classes use `isinstance`; MeTTa type atoms use
`type_witness_in/3`; predicates must return one Boolean answer.

Tried: type and array tests pass 141 cases and error tests pass 48 cases after
the grounded refusal repair. The new two-case plunit fixture fails on the
shipped tree and passes after repair, alongside 253 runtime tests and 138
subtests. The repaired array multiplication reports only
`(BadArgType 1 Number ndarray)`. Bag evaluation raises `AlgebraOperationError`
with the original `BadArgType 2 Number ndarray` atom.

Decided: preserve all class/protocol witnesses for acceptance and select the
first concrete witness only when every witness rejects a host value. Keep
independent MeTTa declared-type and overload alternatives. The Python algebra
boundary refuses an Error before using it as another operation's input.
Rejected: a global `once/1` around diagnostics, because it would erase distinct
MeTTa overload refusals that the existing arbiter tests require.

Tried: integration probes found public `(annotation)` bypassing validation
through `metta_annotation/1`, and a refused functional constructor leaving
its callbacks registered. Native annotation reads and extension now share
membership checking, including identity shortcuts and results. Four native
carrier tests pass. Constructor installation uses the existing transaction;
Python algebra mirrors enlist their preimages in its existing undo log.

Tried: composing a finite int16 tensor domain with a dtype predicate exposed
an equal-valued int64 operation result receiving a certificate. The regression
failed while the other ten composition tests passed. Closure and each law
operation now retain the full carrier descriptor and check every intermediate
input and result. The combined certificate, tensor and existing algebra tests
pass 22 cases.

Tried: an uncertified native algebra with `extend=+` and `one=1` returned 3
for extension of 1 and 3, because the engine assumed the declared one was an
identity. Decided: identity shortcuts require `extend-one-identity`, just as
fusion requires its own laws. The additional native regression returns 4;
all five native carrier tests pass. A type admits values, never optimizations.

Tried: the full engine runner passed 79 suites, 2,189 tests and 1,436
subtests after the descriptor and identity repairs, with no failed tests,
load errors or unexpected choicepoints. The exact command was
`TMPDIR="$PWD/ai-tmp" sh engine/test.sh`.

Tried: the generic grounded-call transport erases a native Symbol into a Python
string. A predicate using `isinstance(value, str)` then wrongly admits a Symbol,
while a predicate requiring `Symbol` wrongly refuses it. Both regressions fail
beside 11 passing composition controls. Decided: carrier predicates must use
the existing tagged atom codec at an explicit membership boundary. Changing
ordinary grounded-call conversion would alter an independent interop contract.

Tried: the full Python integration run exposed 20 failures: stale generated
async/reference surfaces, a test still expecting two grounded refusals, the
new predicate/budget regressions, a pooled-name fixture assuming immediate
reuse, and repository contract pins. The pooled regression now retains earlier
queue entries until the released name is allocated, bounded by the actual free
pool size. It remains red in both shipped cases and passes after repair in
suite order. Generated surfaces were regenerated from their authorities.

Decided: retain five narrow `type` keyword suppressions, including the generated
async mirror, because Python's public word is required; internal normalization
uses `carrier_type`. The suppression pin moves from 22 to 27 for those five
sites. Publish `metta_require_algebra_value/3` as a host service because the
engine owns membership policy; the host only decodes the values. The new
`grounded_algebra_type/3` ownership seam preserves Symbol and Expression kinds
through the existing tagged codec. The 36 composition, tensor and type cases
pass after this transport repair.

Tried: adding carrier predicates also exposed an unmetered engine crossing.
The corrected finite probes fail at all four phases and across accumulated
initial tags under the old behavior. Carrier checks now use the same remaining
inference and time budget as operations. Nested Janus calls can catch a raw
limit signal before the outer guard; classification uses its preserved term,
never message text. Seven budget regressions and five existing tagged budget
cases pass. The combined identity, type, array, error and budget run passes
256 cases.

Tried: the repository path gate found a pre-existing absolute checkout path
in the user-authored release-repin journal. Respelling it as the sibling
`../repin` preserves the recorded path-length comparison and passes the gate.

The six requested check lanes pass together: `llms` reads five sheets with no
findings; `llms-selftest` passes 61 planted cases; `layering` accounts for 944
calls with 81 contract lines across six components; `lib-surface` checks 895
clauses and 470 equations; `policy-inventory` finds no violations across 20
runtime rows; `kernel-ledger` finds none across 68 heads. Command:
`sh check.sh llms llms-selftest layering lib-surface policy-inventory kernel-ledger`.

Final verification: `sh extensions/python/test.sh` exits 0 with 3,544 passed,
48 skipped and five warnings in 208.35 seconds. `sh engine/test.sh` exits 0
with 79 suites, 2,189 tests and 1,436 subtests, with no errors or unexpected
choicepoints. The six named check lanes exit 0 together. The algebra typing
surface passes mypy, generated async/reference/stub checks agree with their
sources, and the final Python duplication scan reports zero clones. Prolog
files were not counted by that scanner, so that result makes no Prolog
coverage claim.

## Unification

A space-keyed declaration lives exactly as long as its space; a carrier is a
type. Finite enumeration defines a type small enough to check laws by
exhaustion. A general type or predicate validates values but grants no
certificate, fusion, or identity shortcut. Declaration, native annotations,
Python operations, captured tags, and law witnesses now share membership.
The same resource budget covers membership and the operation it guards.

The following sibling doors remain, listed rather than repaired:

- A target-owned hook declared from another space retains a reference to its
  declaring execution module after that module is released. The executed
  probe retains `metta_hook_claim/4` and the next write raises
  `type_error(metta_execution_module, ...)`.
- A raw native release of a Python-declared algebra removes its catalog row
  immediately but retains the Python mirror until `get()` evicts it.
  `Space.drop()` removes both immediately. The executed probe confirms there
  is no stale lookup result; the remaining issue is retained host memory.
- Custom `order=` metadata exists only in the Python mirror. The executed
  probe finds no global ordering claim, and direct catalog reconstruction or
  mirror eviction loses the custom order. It is not a space-keyed catalog row.
- Native `metta_apply_algebra_operation/6` still accepts an Error as a result
  for an unconstrained preset, as the executed bad-string multiplication
  probe demonstrates. Its `once(eval(...))` also truncates nondeterministic
  alternatives by source inspection. The Python operation boundary now refuses
  the original Error; typed native membership also rejects out-of-carrier
  results. General native cardinality remains a separate obligation.
- Carrier objects and callable definitions can change after a finite
  certificate is checked. No dependency/version mechanism invalidates that
  certificate. This is a source-inspected obligation concerning mutable
  declarations, not a measured claim about a specific backend.

## 2026-09-06: integration with one evaluation context

Tried: replaying the implementation onto `14e70c7a` reports content conflicts
in CHANGELOG.md, algebra.py and llms.txt. Read
`2026-09-06-one-evaluation-context.md` and the context implementation before
resolving them. Both changelog narratives and both sets of cheat-sheet
sentences are retained. The combined live seam roster has 91 host services,
58 services, 38 ownership seams, 14 events and 13 declarations.

Decided: carrier membership is another evaluation crossing within the same
ask. `_EvaluationBudget` retains `EvaluationContext` and passes it to both
ordinary/accounted operation evaluation and accounted membership. Trunk's
binding preparation stays before operation evaluation. Direct algebra
operations create the context before checking operands; retained derivation
interpretation shares it through each recursive membership and operation.
Captured native annotations receive their held cursor's context, including
its limit and ordering. Explicit algebra objects remain explicit objects.
This uses the existing context propagation and cleanup boundary described by
the companion journal, rather than introducing another ambient carrier.

Rejected: choosing one side of the accounting conflict. Keeping only the
operation context drops predicate context; keeping only membership metering
drops trunk's operation context and binding preparation. Both are necessary
parts of the one-ask contract.

Tried: the trunk callback fixture declared the finite domain `(0, 1)` and
then evaluated tags 2, 3 and 5. That domain cannot certify those runtime values.
Use the complete `range(16)` domain, max, and multiplication modulo 16. Both
operations remain closed and the exhaustive combine-associativity check is
retained. Products 2*5=10 and 3*5=15, all callback observations, the final
annotation 15, and the original demand/order/restoration assertions are
unchanged. Context, binding and carrier-budget tests pass 54 cases; five
existing tagged budget cases pass separately. Original lifecycle, carrier,
tensor and refusal regressions pass 51 cases.

Tried: a mutation that drops only membership's context makes
`test_carrier_predicates_share_the_operation_evaluation_context[None]` fail:
operations observe `(typed-carrier-context, 2, descending)` while predicates
observe the outer tropical context. With the shared crossing, all 20 new
context/type tests pass. Tensor, retained-object reinterpretation and native
capture composition pass 39 tests together. The tests cover both unlimited
and accounted evaluation, rejection, and restoration of the outer context.

Tried: the integrated `sh extensions/python/test.sh` passes 3611 tests with
48 skips and five warnings in 127.46 seconds. `sh engine/test.sh` exits zero
across 79 suite invocations, 2195 tests and 1436 subtests. The exact requested
`sh check.sh llms llms-selftest layering lib-surface policy-inventory kernel-ledger`
exits zero with all six gates green. Layering covers 949 calls through 81
contracts. Generated async, stub and reference checks agree; the algebra
surface type check reports no issues.

Tried: the default duplication scan excluded the large algebra and Space
files, so its earlier zero-clone receipt does not establish their coverage.
Repeating with `--max-lines 10000 --max-size 2mb` includes both files and finds
nine clone pairs on both trunk and the integration. Eight pairs are unchanged
Space implementations. The ninth repeats the public constructor signature;
adding `type=` extends it by one line. No new clone pair is introduced.

Decided: refresh three pre-existing tested evidence pins that are not
ancestors of the rebased branch. The policy-list inventory selftest passes
all nine planted cases, and the full engine run checks the support-graph
invalidation and file effect-row claims. Their new pins name the same
verified implementation snapshot as the carrier repair; the new provenance
commit contains only evidence-pin substitutions.

## 2026-09-06: integration with tensor shape claims

Tried: replay the verified context integration onto `2e72490f` after reading
`2026-09-06-shape-claims-are-read.md`. CHANGELOG.md and terms.pl conflict;
the Python shim and both cheat sheets merge automatically. Keep both complete
changelog narratives and all added cheat-sheet sentences. Preserve trunk's
structural protocol projection and detached `metta_bad_argument_reason/3`
construction, together with the one-value refusal consolidation.

Tried: 192 Python lifecycle, carrier, tensor, shape, refusal and context
regressions pass. The native tensor-shape suite then exposes two integration
failures: the old expectation held both bare DLTensor and the shaped witness,
while consolidation retains only bare DLTensor. One answer satisfies the
cardinality contract but loses the actual dimensions needed for the refusal.

Decided: the single refusal must retain the witness relevant to the expected
refinement. A matching structural refinement names the actual shape; an
ordinary scalar requirement still names the concrete host class. Acceptance
continues to consider every witness. Trunk's evaluated-argument evidence and
original written-call context remain separate from reason construction.

Rejected: restoring both bare and shaped Error answers, because two witnesses
of one host value must not become two failed operation results. Also reject
always choosing the first class when the expected refinement has a more
specific witness: that would erase the shape claim's failure evidence.

Tried: the next combined array/refusal run has two failures and 129 passes.
Trunk's `_ops.type_names` puts structural protocol expressions before named
classes. Selecting the first witness therefore changes the scalar refusal
from ndarray to an Annotated shape after the array projector is installed.

Decided: match the rejected requirement rather than rely on list order. A
corresponding Annotated base selects its structural witness; otherwise the
first named witness preserves the bridge's concrete class order. A bridge
with only structural witnesses retains its first available type. The public
type projection and all acceptance alternatives remain unchanged. Explicit
protocol fixtures pin this independently of prior array installation.

Tried: final focused native coverage passes 17 shape, two grounded-refusal
and four typing-rule tests. Python array/refusal ordering tests pass 136 cases
in each order. The complete focused lifecycle, carrier, context, shape and
refusal selection passes 197 cases in 16.49 seconds. Five new shaped-carrier
cases cover both constructors, fresh products, changed live dimensions,
exhaustive finite certificates, and exact retained Error atoms through host
and equation operations. Their duplication scan includes the complete file
and finds no clone pair.

Tried: the full Python gate passes 3660 tests with 48 skips and five warnings
in 151.98 seconds. The six requested check lanes all pass; layering now covers
954 calls through 81 contracts. Generated async, stub and reference checks
agree, the algebra mypy surface is clean, and all nine policy inventory
selftests pass.

Tried: running the engine gate alongside check.sh exposes an artifact race:
`open_shared_object/3` reports `morklib.so: file too short`, followed by
`Unknown procedure: mork/3 (mork/3 did not register on load)`. check.sh builds
each component before its lanes, replacing the native shim while the engine
suite boots. The completed shim's SHA-256 matches the provisioned main copy.
Run the final engine gate alone after all builds finish; do not treat the
raced receipt as acceptance evidence.

Tried: the final isolated `sh engine/test.sh` exits zero across 80 suite
invocations, 2212 tests and 1438 subtests, with no errors or choicepoints.
All required acceptance evidence now covers the final composed source.

### Unification after integration

A space-keyed declaration lives exactly as long as its space; a carrier is a
type. One ask carries one evaluation context through membership, operations,
native capture and retained-trace reinterpretation. A type validates values;
only an explicit finite enumeration admits exhaustive law certificates.
A refused value supplies one diagnostic witness relevant to its requirement;
retaining actual dimensions is compatible with one Error per host value.
The five sibling obligations listed in the earlier Unification section remain
open with the same scope: foreign hook execution references, lazy native-drop
mirror eviction, Python-only custom ordering, native Error/cardinality
handling, and mutable certificate dependencies.
