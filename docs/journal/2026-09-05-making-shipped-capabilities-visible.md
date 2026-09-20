# Making shipped capabilities visible
Goal: give every shipped user-facing capability an observable and discoverable
entry point from the surface where its intended user works.
Constraint: add the smallest door that exposes existing behavior; leave policy
choices open rather than choosing them through an audit.

## 2026-09-05
Tried: searched all 42 tracked Prolog engine files for dynamic state, flag and
non-backtrackable writes, then correlated each write with readers inside and
outside its owner file. Of 180 dynamic or thread-local declarations covering
174 unique predicate indicators, 95 had no cross-file reader; manual call-site
classification reduced that set to two engine-internal predicates and one
user-facing tally, `ho_specialization_unverified/2`.

Tried: ran a higher-order function under
`(pragma! verify-specializations true)` through `sh tools/run.sh` -> the test passed,
the verifier recorded its result, and neither stdout nor stderr named coverage.

Rejected: `print_message(informational, ...)`, because `sh tools/run.sh` invokes SWI
with `-q` and suppresses that channel. Revisit for diagnostics a user did not
explicitly request.

Decided: one lifecycle marker starts a fresh specialization tally when the
mode becomes active, reports it when the mode is disabled, and reports an
environment-selected run at process exit. The report writes to `user_error`,
matching the discharge verifier's already-corrected mechanism, because it is
requested output rather than ambient logging.

Decided: the corpus differential parses and aggregates the report. A clean run
with zero reported checks fails as vacuous; inference-bounded checks remain
visible without silently changing the verifier's existing acceptance policy.

Tried: `sh tools/run.sh examples/ch14-seeing-your-program/01-time_and_pragmas.metta`
-> exit 0 and stderr contained `verify-specializations checked 1
specialization(s): 1 agreed, 0 could not be checked inside the
200000-inference bound` under the launcher's normal `-q` path.

Tried: the `spec-differential-selftest` gate through `ai-gate-lock.sh` -> 0
problems across one planted disagreement, one nonspecializing control, one
agreed control, and one one-inference-bounded control.

Tried: enumerated every executable `print_message/2` in the 42-file Prolog
engine corpus -> seven calls, two at `informational`, none at `silent` or
`debug`. The informational calls are the equation-head authoring note in
`engine/translator/analysis.pl` and the source-replacement report in
`engine/filereader/source_lifecycle.pl`. `sh tools/run.sh` always supplied `-q`, so
neither had a standalone user-visible invocation.

Rejected: raising either message to `warning`, because both are optional
authoring detail and the default quiet invocation is intentional.

Decided: `sh tools/run.sh --verbose file.metta` omits SWI's `-q` and the engine strips
the option before choosing the file. One general launcher door exposes both
reports at their existing level; Python already has the equivalent
`MeTTa(verbose=True)` door.

Tried: the `runner-verbose` and `llms` gates through `ai-gate-lock.sh` -> both
passed. The runner control saw no head-pattern note by default and the exact
note under `--verbose`; the cheat-sheet check covered all 154 corpus-used
callable names.

Tried: correlated persistent-provider constructor keywords with the sole
public space factory -> `PersistentFactSpace(rename=...)` performed a complete
one-open schema migration, while `MeTTa.space` and root `metta.space` exposed
`journal`, `schema`, and `sync` but dropped `rename` before construction.

Decided: forward `rename` through the existing factory and reject it without
`journal`, matching `sync`'s boundary rule. The provider and migration
algorithm stay unchanged; the new door is one keyword at each public tier.

Tried: the two public-factory regression cases with the required Python -> 2
passed; `integration/persistent_migration.py` then migrated and reopened the
journal through root `metta.space`, printed both checked claims, and exited 0.

Tried: compared the 107 root Python exports with `llms.txt` and all runnable
Python examples -> `Config` and `config` were the only process-control exports
with neither a consumer-sheet spelling nor an example. Tests exercised the
object, but a package user had no discovery path to its four settings or their
startup boundary.

Decided: document the exact settings and environment variables beside first
engine construction, and add one checked example that inspects the roster,
configures before startup, observes the freeze, and changes a live setting.

Tried: `operations/runtime_configuration.py` with the required interpreter ->
four checked claims, `OK runtime_configuration`, exit 0.

Tried: compared the provider interface with its consumer sheet ->
`SpaceProvider.can_run` described implemented capabilities, while
`should_run(capability, **request)` and `refusal(capability, **request)` were
the actual per-request policy and explanation hooks; neither latter spelling
occurred in `llms.txt` or an executable example.

Decided: distinguish structural support from request policy in the existing
provider paragraph and add one curated-store example. The example admits a
user fact, declines a reserved system fact before it reaches `add`, and checks
that the exception carries the provider's own remedy.

Tried: searched `llms.txt`, root examples, and Python examples for `Request`,
`cursor_idle`, `cursor_limit`, and `server_capabilities` -> no occurrences,
although the remote server already accepted every control and the generated
protocol reference described them.

Decided: expand the existing remote roster rather than add another API. A
loopback example exercises the actual HTTP authorization boundary, reads the
server advertisement before writing, and proves a one-cursor ceiling refuses
the second live stream and releases the first explicitly.

Tried: searched the consumer sheet and executable examples for `stack-limit`
and `limits(stack=...)` -> the pragma roster named `stack-limit` after the
verification-mode repair, but no runnable example selected either door and
the general limits paragraph omitted the Python keyword.

Decided: add `stack` to the existing `m.limits` roster and execute a finite
call under a four-megabyte scoped ceiling in the engine-controls example. This
uses the same public block that carries the byte count to `metta_py_limited/6`.

Tried: searched `llms.txt`, root examples, and runnable Python examples for
`saga` and `compensates` -> neither appeared, although the public runner,
receipt model, reverse recovery, and async twin were complete and tested.

Decided: put sagas beside transactions and add a checked example using the
built-in `add-atom` effect. Its MeTTa recovery equation removes the recorded
atom; the example observes the committed receipt before an application
exception, then observes both the effect and receipt gone after recovery.

Tried: searched `llms.txt` and both example corpora for `accessors=False` and
`methods=False` -> no occurrences. A direct `space.define(Class, ...)` probe
kept the type declaration while suppressing the requested field equations and
method operations; the natural keyword-only decorator form raised `TypeError`.

Decided: document and execute the supported direct form. The definitions
example uses a default-exposed class as its positive control, then proves both
registrations are absent for a class declared with the two controls disabled.
Supporting a keyword-only decorator remains a separate API decision.

Tried: searched `llms.txt`, both example corpora, the README, extension guide,
and website for `__from_metta__` -> no occurrence. Source and tests showed it
is the reverse half of the already-supported class-owned `__metta__` hook and
needs no registry entry.

Decided: name the paired hooks at the existing conversion door and extend the
object example with an unregistered projection and `build(atom, Class)`
round-trip. Registry-based dataclass conversion remains beside it as a positive
control for the other ownership model.

Tried: searched all consumer material for `AssertionFailure` -> only source
and tests named it. The error taxonomy listed its siblings but gave harness
authors no way to distinguish a false program claim from a broken engine.

Decided: add the exception to that taxonomy and execute one false `(test ...)`
in a checked example. The catch verifies `operation`, `actual`, and `expected`
as data rather than parsing the diagnostic sentence.

Tried: searched the consumer sheet and both example corpora for `.subs(` -> no
executable occurrence. The generated reference alone showed that `Atom.unify`
returns exactly the atom-keyed mapping `Atom.subs` consumes, while the sheet
named only the older free functions.

Decided: put the producer and consumer beside each other and extend the
first-steps example with one direct `template.subs(pattern.unify(fact))`
round-trip. The check uses both variables so a partial or name-keyed mapping
cannot pass accidentally.

Tried: compared all 107 root package exports with the sheet and executable
examples -> `not_` and `in_` were the only atom builders absent from both.
Their trailing underscores are the package's usable spellings for Python
keywords; generated reference pages and tests were the only readers.

Decided: name the complete five-builder logic family together and check the
exact `(not ...)` and `(in ... ...)` terms in the first-steps example.

Tried: searched `llms.txt` and both example corpora for `starmap` and
`try_recv` -> no occurrences. Tests alone used the returned pool and channel
methods, so a caller could obtain either handle without finding its
multi-argument or nonblocking operation.

Decided: document both methods at the concurrency entry and add one checked
handle-lifecycle example. `starmap` evaluates two engine calls through separate
argument rows in input order; `try_recv` is checked both empty and carrying a
waiting term.

Tried: searched the sheet and examples for `entry_points`, `load_entry_point`,
`METTA_REQUIRES`, and the exact integration `unregister_` names -> no
occurrences. Generated reference and tests proved unloaded discovery,
factory-by-name loading, dependency ordering, and symmetric hook removal.

Decided: expand the existing integration paragraph with those lifecycle doors
and add a checked example that discovers without loading, installs three
process-wide protocol hooks, observes each effect, removes all three in a
`finally` block, and proves reflection no longer claims the object.

Tried: searched the sheet and examples for `BoundedMatcher`, `Snapshotter`,
and `WorldCommitter` -> no occurrences. Their protocols were public and their
engine routes were tested, but a backend author could not discover which
method signatures unlock bound pushdown and provider-owned worlds.

Decided: document the three signatures in the provider section and add one
small provider implementing all three. Its example checks that an exact
one-answer query passes `limit=1`, a reified write leaves the provider
untouched, and `Space.commit` hands the provider one base-relative atomic diff.

Tried: searched the sheet and examples for `raise_for_errors` -> no
occurrences, although query rows deliberately preserve stored `(Error ...)`
atoms as data and the website guide named this opt-in exception bridge.

Decided: put both `Rows` and `Answers` spellings in the error model and extend
the error-handling example. A clean row set is the positive chaining control;
a stored error row must raise `MettaResultError` with its culprit intact.

Tried: searched the sheet and examples for `.folds(` -> no occurrence. The
event stream retained a public registration-order roster, but only generated
reference exposed it to the observability owner responsible for live folds.

Decided: name `EventStream.folds(space_name)` beside fold construction and
extend the standing-query example. Four active subscriptions are the positive
control; cancelling all four must leave an empty roster.

Tried: searched `llms.txt` and both executable example corpora for the
`relation` keyword on `object_view` -> no occurrence. The default `py-field`
form was visible, but an application whose fact vocabulary already owns that
head had no discoverable spelling for the implemented collision-avoidance
control.

Decided: show `object_view(obj, relation=...)` at the existing object-view
door and query a checked live view under `robot-field`. The provider and its
default remain unchanged.

Tried: searched root `llms.txt` and both executable example corpora for
`metta.speculate()` -> no occurrence. The object-tier speculative scope was
documented, and the generated phrasebook named the root spelling, but a lazy
module-tier consumer did not encounter it in either required consumer door.

Decided: put `with metta.speculate():` beside `Space.speculative()` and execute
a default-context write whose absence after the scope proves that it was
discarded.

Tried: searched root `llms.txt` and both executable example corpora for
`from_pattern` -> no occurrence. Source tests and the generated website
phrasebook exercised it, but the property-test author named by the public
`metta.testing` module had no required consumer-sheet or runnable-example door.

Decided: add the exact strategy signature to the testing roster and a checked
Hypothesis example. One generated instance proves repeated named variables
share a value; a second finds distinct values for two anonymous holes.

Tried: searched root `llms.txt` and both executable example corpora for
`vector_for` -> no occurrence. The website reference and tests used the
method, but the embedding-store paragraph exposed only its registered MeTTa
operations, leaving a Python retrieval caller with no door to the stored
vector by key.

Decided: name `EmbeddingStore.keys()` and `vector_for(key)` at the existing
embedding door and read a checked stored vector in the custom-matcher example.
No search or storage behavior changes.

Tried: searched the consumer sheet and both executable example corpora for
`measure_counters`, `CounterRuns`, and `observe_measurement` -> no occurrence.
The sheet named only the older one-event `measure_instructions` helper, even
though performance authors need the general result shape when one command
reports engine inferences while perf counts foreign work.

Decided: document the full general signature, returned event/output mappings,
and the three baseline comparison doors beside the existing benchmark roster.
The existing `test_measure_counters_reads_every_requested_event` is the
executable positive control. A topical example was rejected because a normal
example run cannot require exclusive PMU access; the current PMU is held by
another repository, so live `instructions:u` remains unrun in this thread.

Tried: searched the consumer sheet and executable examples for
`is_transport_failure` -> no occurrence. Git history and its public docstring
identify remote-backend authors as the audience for the shared outage
classifier; the foreign seam also uses it internally, but it remains exported
from `metta.errors` for transports outside that seam.

Decided: name the classifier beside `TransportFailure` and add positive
`ConnectionError` and negative `ValueError` controls to the remote example.
The classification implementation remains unchanged.

Tried: searched the sheet and executable examples for `free_variables` -> no
exact property spelling. The sheet said lexical captures were available on a
`Defined` value and the generated guide named the property, but neither
canonical door showed a compiled function reading it.

Decided: name all four AST-derived `Defined` properties together and add one
compiled definition whose sole lexical dependency is observed as
`("anyatom",)`.

Open: the audit's remaining surface findings are recorded below as their doors
land or are left for a product decision.

## 2026-09-06

Landing the thread on trunk, 273 commits later. Each entry below is a change
the rebase required, with the trunk work that required it.

Found: `set_metta_pragma/2`'s refresh chain had grown a third arm,
`verify-cardinality`, from the annotated-arrow product. Both sides edited the
same if-then-else, so the merge conflicted; the resolution keeps all three and
the comment above it names what each key materialises instead of counting the
verification modes, which is the sentence that went stale.

Found: `llms.txt`'s `pragma!` roster was a closed set that had fallen three
keys behind the engine's own registry. `verify-cardinality`,
`plan-cyclic-joins` and `materialize-source-relations` are in
`metta_pragma_key/2` and were in no consumer sentence. The `llms` lane cannot
see this class: it derives libraries, source-table counts, operator words and
call heads, and a pragma key is none of those. Completed the roster and gave
the three keys one sentence each from the registry's own description, because
this thread's whole subject is a shipped capability with no reader.

Open, recorded rather than fixed: `verify-discharges` reports its coverage on
the pragma's OFF transition only, so `METTA_VERIFY_DISCHARGES=1` with no
closing pragma still reports nothing at process exit. The specialization half
takes the `at_halt/1` route for exactly that reason; the discharge half is
`engine/metta/terms.pl`'s and is left to its own thread.

Found: `tests/prolog/layering.pl` is trunk's engine layering contract, an
allow-list over every cross-subsystem call, and the pragma door's new call into
the specializer is one: `metta:set_metta_pragma/2 calls
specializer:metta_refresh_specialization_verification/0, and no contract line
lets it`. The lane printed the remedy, so the line is
`reaches(metta, specializer, ...)` with the reason. It creates no NEW tangle,
because metta and specializer already sit in the declared SCC, and the contract
also requires a cross-subsystem call to reach an EXPORT, which is why both
lifecycle predicates stay in the module's export list even though every caller
qualifies them.

Measured: the corpus differential reads `0 disagreements; 71 checked, 66
agreed, 5 unverified` over the example corpus. The five inference-bounded
checks are the first ones this engine has ever reported; the discharge
verifier's own thread recorded that nothing in the corpus reached its bound, so
the 200,000-inference ceiling is now known to bind for the specializer half.

Measured, and re-pinned: the identity twin's budget moves 3422 -> 3432 (+10).
It is the predicate-count class the row's own chain already records twice. The
positive control is decisive: an UNREACHABLE set of the same shape, one dynamic
and five static predicates that nothing calls, added to trunk's own
`engine/specializer.pl`, reads the identical 3432; the same set in
`engine/tracer.pl` leaves the row at 3422; and the dynamic marker alone reads
3417, which is BELOW the pin, so the relation is not even monotone in the count.
The MeTTa side is 2357 on every arm, which is what says the work is unchanged.
Open: what makes this row read `engine/specializer.pl`'s predicate table at
all. It is not `tracer`'s, so it is not the whole-process predicate count, and
naming the scan belongs to the engine's own cost thread rather than this one.

Found: `examples/ch14-seeing-your-program/01-time_and_pragmas.metta` is TWINNED,
and the twin lane read the new block as a divergence: `the twin's space does not
answer a (= $head $body) match with verified-inc/1 verified-twice/2
verified-twice_Spec_[verified-inc]/2, so a definition the example makes
matchable is hidden in Python`. The example half was written before the twin
corpus covered this file's chapter.

Decided: give the twin the same block rather than move the example. A compiled
`def verified_twice(f, x): return f(f(x))` lowers to `($_1 ($_1 $_2))`, the
example's own form, so the twin specializes the same call and the generated
`verified-twice_Spec_[verified-inc]/2` matches on both sides. `verified_inc`
takes `x: int`, because without the annotation the body compiles to
`(py-operator add $x 1)` where the example writes `(+ $x 1)`; the annotation
costs one twin-only type declaration, which is the class this row already
carries for `spin`. The pragma value is `S.true`/`S.false`, the symbols the
example writes: a Python `False` also disables the mode, but only by comparing
unequal to `false` rather than by being it, and ruff's FBT003 refuses the
positional boolean.

Tried: turning the pragma off, then defining and calling a SECOND higher-order
specialization -> exactly one report, at the off-write, and nothing at process
exit. That is the control saying `S.false` disables the mode rather than the
report coming from `at_halt/1` with the mode still on.

Re-pinned: that twin's budget 44455 -> 49767. Unlike the identity row this is
work, not shape: the twin now runs the block the example runs.

Found: `run.sh` now goes through `bounded.sh`, which gives every process this
repository starts a deadline and a parent-death link, and
`tests/checks/check_process_bounds.py` reads every `tests/shell/*.sh` for a
command position that skipped it. The verbosity lane's two launcher calls were
written before that existed, so they are `bounded sh tools/run.sh ...` here and the
probe directory is a plain `mktemp -d`, which the gate's repository-local
scratch supplies through `TMPDIR`. Nesting is what `bounded.sh` documents: the
tighter of the outer and inner ceilings is the one in force.

Tried: `sh tests/shell/test_run_verbose.sh` on the rebased tree -> exit 0, the
default run silent about the head-pattern note and the `--verbose` run carrying
it, so trunk's `-q`-suppressed informational channel behaves as it did when the
door was written.

Found: trunk grew a THIRD public space factory while this thread was open.
`AsyncMeTTa.space` took `journal`, `schema` and `sync` and had none of them
when the sync door's `rename` was written, and
`tests/repository/test_async_mirror.py::test_every_async_counterpart_has_the_sync_parameters`
compares the two parameter lists, so adding one keyword to `MeTTa.space` alone
turns that lane red. It did: `DRIFT space: MeTTa.space (... 'rename' ...);
AsyncMeTTa (... no rename ...)`.

Decided: forward the keyword rather than record a divergence. A migration
keyword the async surface cannot spell is the same defect this thread is
about, one surface further out, and the sibling test's own planted failure
uses `journal` for the same reason. `tools/reference.py --write` republishes
the two docstrings that changed.

Tried: the async door against a journal the sync door wrote under old heads ->
migrated to `(new value)` and the reopen without `rename=` answered the same,
which is the one-open rule holding across the worker crossing
[tested: test_the_async_space_factory_exposes_replay_rename].

Found: the public factory's refusal regression wrote
`pytest.raises(TypeError, match="rename.*journal")`, and trunk's ruff
configuration now gates RUF043, which refuses a `match=` pattern carrying
metacharacters in a plain string. Raw string; the pattern is unchanged.
