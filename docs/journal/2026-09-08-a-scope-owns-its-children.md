# A scope owns its children

Goal: leaving a block joins its computations and releases its resources; a
failure stops siblings, and cancellation reports an acknowledged stop.
Constraint: lib_thread owns the policy and state. Python projects those rows.
The cut is f0d33dcad438f91556459ba43c80212d9b46b760. Executors are present;
effect handlers and AL are not.

## 2026-09-08

### Design, before implementation

The problem is a lifetime tree. Nursery joins, RAII destruction, process-group
cancellation, capability revocation and transaction rollback share its two
obligations: stop dependants before releasing their inputs, and preserve the
failure that caused unwinding. Transaction rollback alone cannot implement it:
threads, host objects and channel buffers outlive a database snapshot.

| Prior-art operation | Library operation and invariant |
| --- | --- |
| Trio nursery / JEP 505 `StructuredTaskScope.open()` | `(scope body)` and `with metta.scope():`; exit waits for every child. |
| Trio `start_soon` / JEP 505 `fork` | Existing `spawn` and executor submission enrol in the current scope before publication. |
| Nursery cancellation / JEP 505 all-successful joiner | First child failure requests sibling cancellation before joining any sibling; all failures remain observable. |
| Trio checkpoint | Every host engine call checks the scope before and after execution; running Prolog receives a guarded signal at a predicate safe point. |
| Trio `move_on_after` | A deadline on the same scope row, scheduled by lib_thread's existing timer service; only that scope's cancellation is suppressed. |
| JEP 505 owner confinement | The entering engine or host thread alone closes or transfers resources from its scope. Children inherit ownership, not the right to close their parent. |
| Nursery child set | Resource rows hold futures, child scopes, newly minted spaces, bounded channel spaces, explicitly created pools and subscriptions. |
| RAII and revocable capability | Join first, then release resources in reverse acquisition order. A retained handle to a released scoped space refuses subsequent use. |

Sources: [Trio 0.30.0 nursery implementation](https://github.com/python-trio/trio/blob/v0.30.0/src/trio/_core/_run.py)
(`Nursery._nested_child_finished`, `_child_finished`, `__aexit__`),
[JEP 505](https://openjdk.org/jeps/505), and
[SWI `thread_signal/2`](https://www.swi-prolog.org/pldoc/man?predicate=thread_signal/2).
JEP 505's joiner defines shutdown policy; the old `ShutdownOnFailure` subclass
is not its proposed interface.

The authoritative scope and resource rows live in lib_thread. Scope handles
identify a parent, owner, open/joining/cancelled state, failure receipts and an
optional deadline. A resource has one owner and one lifetime token. Scope
membership is an index of those tokens. The recorded database keeps lifetime
bookkeeping outside SWI transactions; a rollback must not forget a resource
that still needs releasing. Mutations and signal publication are protected by
one scope mutex; callbacks, joins and engine destruction run outside it.

An engine context seam captures the current scope when a host opens a held
goal. Its wrapper runs inside the held engine. The transaction-cursor host
services remain the only host engine allocator. lib_thread's existing task
context carries its Python context token and its scope independently. Python
adds one ContextVar containing the library scope handle, with no child set,
timer, cancellation scheduler or independent ownership policy.

Normal exit first joins children, allowing already-running children to create
descendants until they finish. A body exception or child exception cancels
the tree before joining. Cancellation marks the scope before signalling its
active engine handles; queued and suspended scheduler tasks are disposed or
woken through the existing scheduler. The signal checks a registration token,
so a signal delivered after its guard has left cannot interrupt later work.
The close path is shielded and attempts every cleanup before reporting errors.
A scope cannot be opened inside a transaction, and starting an asynchronous
child from a transaction inside a scope refuses before publication: such a
child cannot participate in the caller's transaction snapshot.

Space creation and release events enrol and retire native and foreign spaces.
Borrowed spaces remain borrowed. Returning a space from a MeTTa scope transfers
it to the parent; Python spells the explicit transfer `scope.keep(value)`.
The transfer walks the returned value and transfers the space dependencies it
contains. Futures still join even when their answer spaces are returned.
Failure transfers nothing. A scoped space name is not recycled after release;
its revocation marker contains no host object or live resource. Python aliases
carry the same lifetime token. This preserves refusal for an escaped name as
well as for the original object, while SWI's native storage modules already
retain their names after release.

A channel is a foreign space whose recorded FIFO is its sole term store. The
message queue contains capacity tokens, not a second copy of the terms.
Enqueue, dequeue and size are constant time; snapshot and pattern removal cost
the number of inspected terms. Send/receive and space add/remove share that
provider. Existing scheduler wakeups and private host notification queues wait
for capacity or data. Close wakes both kinds of waiter. The buffer remains
outside database transactions, preserving the existing channel contract.
[SWI's recorded database](https://www.swi-prolog.org/pldoc/man?section=db)
defines `recordz`, ordered `recorded` enumeration and reference-based `erase`.

`capture` is public as a value describing evaluation in the current space:
`(capture expr)` returns `(evalc expr <current-space>)` with `expr` held.
Evaluating that value, including through `spawn`, uses the captured space.
It composes the existing `evalc` primitive and introduces no second evaluator.
Hyperon's `CaptureOp` also retains a space and interprets its argument there;
its tokenizer-specific grounded representation is not required here
([source](https://github.com/trueagi-io/hyperon-experimental/blob/main/lib/src/metta/runner/stdlib/core.rs),
`CaptureOp`, `register_context_dependent_tokens`). Python's output-capture
context manager keeps its separate existing meaning.

Python's door is `metta.scope()` and the receiver door is `m.scope()`. AL must
adopt that spelling and compose its later keywords with this ownership scope.
`metta.move_on_after(seconds)` is the deadline projection. Executor futures
retain `concurrent.futures` cancellation semantics; a scope still joins their
running Python call. Arbitrary Python code and foreign calls cannot be
preempted until they return to an engine checkpoint. The Node WASM seat has
JavaScript event-loop tasks, but explicitly lacks SWI scheduler lanes and
lib_thread. The brief's conditional Node lane face therefore does not apply.

### Cancellation probe and rejected signal target

Tried: a 300 ms loop, SWI `sleep(0.3)` and a Python callback executing
`time.sleep(0.3)`, signalled 20 ms after readiness, three runs each.
`ai-tmp/ai-sc-latency.py` and `.pl` drive the disposable probe. Seconds below
measure signal submission through the guarded result receipt.

| Signal target | Body | Cancellation latency, milliseconds | Outcome |
| --- | --- | ---: | --- |
| Raw thread | Prolog loop | 0.04077–0.04458 | cancelled |
| Raw thread | SWI sleep | 280.043–280.053 | cancelled |
| Raw thread | Python sleep | 280.095–280.104 | cancelled |
| Engine handle | Prolog loop | 0.07129–0.08726 | cancelled |
| Engine handle | SWI sleep | 280.0734–280.0789 | cancelled |
| Engine handle | Python sleep | 280.0858–280.1523 | cancelled |
| Carrier thread | All three bodies | 278.5–281.77 | done, not cancelled |

The engine runs observed one-minute load averages 16.29–16.41 and five-minute
averages 21.94–22.06. These are observations under load, not a scheduling SLA.
Rejected: signalling the carrier. SWI keeps the nested engine's signal state
separate; the body finished normally. Signal the engine and acknowledge its
terminal result instead. A foreign function may poll SWI signals itself, but
these two sleeps did not. Cancellation waits for return and prevents later
answer publication; it cannot undo foreign side effects already performed.

The pristine baseline returned `[False]` in 0.000409140 seconds for a running
300 ms future, and subsequently returned `[done]` from await. The corrected
fixture used `S['sc_finite']`, because `S.sc_finite` spells `sc-finite` and did
not invoke the registered underscore-named operation. That earlier disposable
probe blocked on readiness and was stopped with SIGTERM, exit 143. The first
latency harness also needed `term_string` for its compound outcome; Janus
reported `Domain error: 'py_term' expected, found 'result(cancelled,exit)'`.
The corrected latency run exited 0.

### Deferred to after handlers

No handler interface is implemented or called in this package. The follow-up
requires the `choose` **control family**, a perform site at the evaluator's
production of an alternative (including `superpose` and equation alternatives),
and the public spelling `with-handler choose par ...`. It must provide a
resumable continuation per alternative, preserve answer multiplicity and
bindings, and let cancellation close every unresumed continuation. `par` then
submits those continuations to this scope's existing scheduler and joins their
answer spaces. It must not race already-evaluated values or invent a second
scope lifecycle.

The ownership reading additionally needs the `write` **control family** at
`metta_add_atom/3` and `metta_remove_atom/3`, with public spelling
`with-handler write ...`. The handler must distinguish writes to borrowed
spaces from creation of owned spaces and delegate the actual write once. The
scope's resource events remain its ownership authority; intercepting writes
alone does not identify resource allocation. These family names, perform
sites and spellings are the requested dependency contract, pending verification
against the handlers package when it lands.

Open: implement and verify the design above; pin the functional evidence
snapshot in a separate provenance commit.

### Integration evidence and ownership refinements

Tried: the native thread, cancellation and scope suites passed 83 tests.
Expanded scope, module and layering checks passed 9 + 20 + 7 tests. Python's
scope suite passed 28 tests with `--randomly-seed=3580260195`, including owned
process pools, coroutine finalizers, landing observers, transaction rollback,
alias revocation, inherited spaces and cleanup retry. Final combined gates
remain open until the ownership entry-point audit below is complete.

Rejected: a MeTTa definition wrapping `capture_expr`. Its Atom result type
holds the right-hand side, so the public call returned `(capture_expr ...)`.
The direct native `capture/2` import returns the existing `evalc` value. The
Hyperon comparison above is now pinned at
[437a1bf49099ff1b996a68456263ce387fded013](https://github.com/trueagi-io/hyperon-experimental/blob/437a1bf49099ff1b996a68456263ce387fded013/lib/src/metta/runner/stdlib/core.rs).

Rejected: signalling siblings while holding a future's completion mutex.
Two simultaneous failures could acquire each other's completion locks.
Completion records the fault and marks its scope before publishing terminal
state, then requests sibling stops outside the mutex. Signals target guarded
registration tokens, so delayed delivery cannot stop later work.

Tried: a capacity-one progress queue with `thread_send_message(...,
[timeout(0)])` hung on a second notification while the scope mutex was held.
The disposable trace stopped between entry to `scope_progress_` and its return.
The isolated SWI queue probe did not reproduce it, so this is not evidence of
a general SWI defect. Under that same mutex, checking `size(0)` before sending
coalesces notifications and passed the previously blocked suite. Disposable
blocked probes were stopped; no test gate was given a runtime deadline.

Decided: a space's lifetime row retains the creating handle's cleanup callable,
not the most recent alias. Engine retirement revokes every alias immediately;
Python satellite and owned-journal cleanup may then retry. Transfers occur
only after all other cleanup succeeds. Rollback can restore an anonymous-name
pool entry or counter, so the allocator checks `space_parent_child_used/1`
before probing contents. The previous order raised
`No permission to access released_scope_space '&pyspace_2'` on the next mint.

Async cancellation has two receipts: preventing a prepared coroutine from
starting is already a stop, while a running Task must finish its finalizers
before cancellation returns True. Waiting from that Task's own event loop
refuses rather than deadlocking it. The initial bridge expected a list from
a Python tuple and produced `one() expected exactly one answer, got 0`;
Janus's tuple representation is `-/2`, verified by a direct crossing.
`scope_publish/2` keeps a landing producer owned until its observers leave,
even though the future's terminal state is visible earlier. This preserves
the existing asynchronous publication order. Explicit scope cancellation is
consumed by its own scope, like a deadline; ancestor cancellation still reaches
the ancestor's next checkpoint.

The entry-point audit requires the same rule for AsyncMeTTa requests and its
worker lifetime. The final host row representation is therefore a cancellation
callable plus a completion queue for work, or a cleanup callable for a resource.
Executor completion callbacks and async-worker completion publish to that same
queue. Joining needs only that receipt, not a conversion of `Future.result()`:
converting a process result containing a leaf Atom raised
`Grounded(3) is a leaf atom and has no length`. Janus `py_call/1` discards its
return, but removing the redundant result read is the shorter complete rule.
Pool shutdown, subscription cancellation and AsyncMeTTa stop are ordinary
cleanup callables; there is no per-host-type cleanup policy in Python or the
library. AsyncMeTTa stop accepts an unbounded join for scope cleanup while its
existing public timeout default remains unchanged. A borrowed worker survives
scoped requests. Worker completion, including abandonment and refusal, must
publish exactly one receipt before scope exit can release the request's inputs.

Sources for those refinements: Python 3.14's
[Task groups](https://docs.python.org/3.14/library/asyncio-task.html#task-groups)
wait for finalizers and allow descendants during exit; SWI Janus's
[call and conversion contract](https://www.swi-prolog.org/pldoc/man?section=janus)
distinguishes calling for effects from converting the returned object.

Open: finish the async-worker entry-point audit, rerun affected tests and the
required gates, then pin A's evidence in B. The handler follow-up remains as
specified above.

Tried: a cancelled AsyncMeTTa request whose callable sleeps in Python hung its
scope join. A faulthandler dump, without terminating the test, found the worker
at `runtime()` acquiring `_LOCK` from `_EngineThread._drain`, and the owner
inside `scope_close/4` holding that same home-engine lock. The published
runtime already has the unlocked `active_runtime()` reader. A no-argument
`runtime()` now uses that reference, while initialization and explicit
configuration requests retain their lock. This fixes the shared getter rather
than adding a special getter at each worker completion site.

Tried: the complete concurrency and executor suites reported 193 passes and
two failures. The channel collector retained handles because passing a bound
cleanup callable through Janus creates a Python-object blob even when the
library has no lifetime row to retain it. Ask the library whether the name is
scoped before passing its cleanup callable. The bare-thread rendezvous fixture
still observed waiters on the old term queue; its observation now reads the
provider's actual host waiter queue. The behavioral assertion stays unchanged.

Tried: both unstarted and suspended debuggers escaped a scope, producing
`Failed: DID NOT RAISE MettaError` in the new regression. Debugger and dirty
generator engines now use `metta_host_hold/3` and its stepping/release services.
Debugger close is an ordinary scope cleanup callable and marks itself closed
after teardown succeeds. The debugger still uses SWI's reified pull protocol,
now over the host service. A failed nested-scope cleanup stays in the closing
state so the parent's remaining cleanups are attempted before errors leave.

Tried: the amended concurrency, pool and debugger suite passed 209 tests.
The async acquisition probe then failed with `subscription stop waited for
the event-loop continuation`. Registration had completed on the worker while
`_acquiring` remained true until the loop resumed. The worker now publishes
the subscription and clears its acquisition receipt before returning. A scope
owns the async stream's cleanup callable as well as the underlying fold;
closing wakes a queued consumer on its loop. Release crossings suspend the
scope checkpoint, so cancellation does not cancel the cleanup itself.

Tried: the injected coroutine signal refusal returned True without stopping
the body, failing `DID NOT RAISE RuntimeError`. A refused loop submission now
leaves the running Task owned and propagates the refusal. Only successful
submission installs the cancellation marker, under the completion lock;
terminal publication still comes from the Task's completion callback.

The complexity audit corrects the design's constant-time channel claim for
complete operations: the queue's size and tail insertion are constant in the
buffer length, while notifications visit W registered waiters and a recorded
lookup can also pass their metadata. Snapshot and pattern removal inspect
buffer terms. The package makes no throughput or constant-time send/receive
claim; the recorded FIFO remains the sole term store.

Tried: native integration passed 73 thread, 3 cancellation, 9 scope, 17 host
hold, 20 module and 7 layering tests. Python integration passed 259 cases and
failed the refusal test's exception-class expectation: the established host
boundary wraps a foreign RuntimeError as `EngineError: Python 'RuntimeError':
coroutine signal refused`. The test now expects that existing boundary class.
Mypy passed 126 files; Ruff found import order and two try-block placement
findings, corrected without changing the acquisition protocol.

Tried: the final focused scope suite passed 36 tests, and Ruff and mypy passed.
The source generators refreshed the async mirror, package stub and five
reference pages. Ownership implementation and its focused checks are complete;
the requested committed-tree gates and A/B landing remain open.

Tried: committed-tree integration passed 260 Python tests and 129 native tests.
Ruff, mypy (126 files), stubtest (111 modules), process-bounds, the async mirror,
package stub, reference and library-documentation checks passed. The llms lane
and its selftest found the source table still counted 17 events and 15
declarations after this package added six events and two declarations. The
table now states 23 and 17. Evidence checking found four bare `test_scopes.py`
paths; the headers now name the full repository path. Node's generated browser
and runtime directories were absent, and the documentation gate skipped its
build because this worktree had no website dependencies. Build those artifacts
using the main checkout's installed dependencies before the final gate run.

Tried: cancelling inside a signal-atomic allocation left the newly allocated
space live after scope exit. The native regression failed with
`Assertion: plunit_lib_thread_scope:scope_space_dead('&sc-cancelled-allocation')`.
Decided: the creation event records an allocation that has already happened,
even when cancellation has marked its owner. The active call prevents scope
closure until the next checkpoint; raising from the ownership event itself
would discard the only cleanup receipt. Admission still checks cancellation
before an engine call or new asynchronous child starts.

The duplicate-code check found one existing nine-line worker-count validation
shared by the thread and process executor constructors, 0.1% of the targeted
Python surface. A helper would couple those independent constructor boundaries
without shortening their contracts. No second scope registry or cleanup policy
was found in Python.

Tried: the amended committed tree passed 260 Python tests, 130 native tests and
all twelve requested or generated checks. The additional `docs` gate failed
with `[vitepress] 1 dead link(s) found.` The pristine control at
`f0d33dcad438f91556459ba43c80212d9b46b760` reproduced the same failure:
`./../../docs/journal/2026-09-08-the-mork-pin-advanced` from the MORK include.
Blame attributes that link to `6da518669cb9e39557d537857c0aa7190dd2e78f`.
The journal exists in that commit. Its repository-relative link is correct
in the README and outside the website source tree when included there.
Decided: link to that immutable repository source, preserving the same journal
for both readers. Do not disable the site's dead-link check or add a second
copy of the journal to the published site. The source and navigation contracts
stay unchanged; the build can now verify the new concurrency guide.

The cancellation audit found that `maplist` stops at the first refused host
signal, leaving later siblings unrequested. A host completion also published
its receipt only after that fallible cancellation pass. The same distinction
as cleanup applies: request every stop, then report the collected refusals;
automatic failure or deadline delivery retains those errors in the library's
fault rows. A completion must publish its receipt even if a sibling refuses
cancellation. Explicit cancellation and close may report refusal with the
scope still owning its resources, allowing a later close to retry.

Tried: `test_a_cancel_refusal_does_not_skip_later_siblings` failed with
`assert queued.cancelled()` while that future remained pending. The library
now collects refusals after attempting every resource and active engine.
Automatic cancellation records refusals for close instead of aborting a
completion publisher or the timer service. The amended scope suite passed
38 tests, including a host completion whose sibling's cancellation raises.
The receipt fixture initially tried to return a SWI queue blob through Janus;
keeping that variable private to the goal fixed the fixture.

Tried: cancelling an unknown future returned False, so the new native case
expecting `existence_error(metta_future, '&sc-unknown-future')` failed. Unknown
handles now refuse; False is reserved for an already completed future.

The foreign-call regression now also executes Python `time.sleep(0.02)` after
the scheduler has recorded a cancellation request. Its explicit gate prevents
the sleep finishing before the test submits cancellation, and True is asserted
only with the callback's return receipt set. This tests the measured foreign
boundary without imposing a wall-clock cancellation threshold.

Tried: that amended fixture first failed with `NameError: name 'time' is not
defined`; importing its new dependency made the foreign-sleep regression pass.
The error exposed a missing scheduler result arm. The body's guard returns
`error(Error)` as its terminal result, but the dispatcher treated
`the(error(Error))` as an unknown protocol message. A native regression then
expected `error(scope_test_failure,context(test,child))` and received
`error(metta_scheduler_protocol(the(error(error(scope_test_failure,context(test,child))))),context(metta_scheduler_step/2,'a scheduled engine yielded an unknown event'))`.
The dispatcher now preserves that guarded terminal error just as it preserves
done and cancelled. Scope failure propagation therefore retains the actual
child failure instead of wrapping it as a scheduler protocol defect.

Tried: the candidate passed 262 Python tests, 132 native tests, all 25 MORK
seat tests and its three absence controls, and all required and generated
gates including the documentation build. The final lock audit then found
unlocked reads of records that writers replace with erase followed by record.
`ai-tmp/ai-sc-state-read.py` observed `missing` while a writer held the scope
mutex; its first fixture also exposed an unbound output variable to Janus,
which refused with `Arguments are not sufficiently instantiated`.
The corrected state and lifetime regressions both observed the missing row.
Decided: readers take the writer's mutex, including the combined revocation
check. SWI mutexes are recursive, so callers already holding the same mutex
remain valid ([mutex_lock/1](https://www.swi-prolog.org/pldoc/man?predicate=mutex_lock/1)).
The tests pause a synthetic replacement to expose the interval; they assert
the record's presence and make no latency guarantee.

Tried: all 40 Python scope cases passed after the reader fix. The provenance
preflight found two HTML comment headers outside the code pinning tool's
grammar: `website/guide/threads.md` and `extensions/mork/README.md`. Commit B
will replace those two exact header tokens and run the standard pinning tool
for the code headers. The final diff must equal only WORKTREE-to-A replacement
at every changed byte; no provenance tooling or release policy changes.
The library's old future-work pointer named absent `ai-todo-parallel.md`; its
handler follow-up now names this journal, while the other future-work items
remain listed.

Tried: the next integration run passed 263 Python cases and failed the cursor
churn test with `assert 0 == 2`: two older engines retired during the cycle.
The pristine cut passed its 224 cases at the same seed, 2421019667; that run
does not reproduce the failure. Blame places the count-equality assertion in
`ef5b91d795`. The finaliser journal already records deferred cursor retirement.
Decided: retain a snapshot of engine identities and require that no new engine
survives churn. Equality rejects unrelated retirement, while a count ceiling
can conceal a newly leaked engine behind one that retired. A planted
replacement proves the identity check detects that case, and closing the
replacement clears it. The focused finaliser suite passed all 11 cases. The
runtime finalisation protocol is unchanged.

Tried: the integration suite passed 265 tests at seed 2421019667, including
all 40 scope cases, concurrency, engine pools, debuggers, space lifetimes and
transaction cursors. Mypy passed 126 files and evidence found zero unbacked
claims. Ruff found `D103 Missing docstring in public function` on the new
replacement control; the test now states its purpose.

Verified: the native command covered 132 tests: 73 thread, four cancellation,
11 scope, 17 host hold, 20 module and seven layering cases. MORK ran all 25
seat tests and the absent, half-built and unloaded-backend refusal controls.
The final feature gate run passed Ruff, mypy, stubtest, process-bounds, llms,
llms-selftest, evidence, aio-mirror, init-stub, reference, libdoc and docs.
The site build warned that some chunks exceed 500 kB; it completed.
Commands and logs are recorded in the package deliverable. These are focused
package and integration receipts; the integrator's merged-tree battery remains
separate. The only deferred feature is the handler reading recorded above.

Verified: Ruff passed after the test docstring correction. The raw-thread
latency samples recorded load averages 24.43, 24.50 and 20.50 over one, five
and fifteen minutes; the engine and carrier samples have their separate load
range above. No cancellation deadline or throughput guarantee is inferred
from those observations.
