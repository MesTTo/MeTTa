# The binding collapse

Goal: describe the Python seat's evaluation, dispatch, service crossings and wire grammar once, while preserving public answers and measured costs.
Constraint: cut `3e5855a35d7b206c847845f12467551ea4c54a59`; preserve the engine/host split and sibling package ownership. Node remains a consumer of the shared grammar.

## 2026-09-09

### Evidence before implementation

The source parser uses `prolog_read_source_term/4`, including Janus operators and zero-arity compounds. Counts exclude comments and distinguish predicate indicators from repeated clauses.

| Description | At the cut |
|---|---:|
| Binding files | 44 |
| Evaluation predicate indicators | 27 |
| Python evaluation target spellings | 17 |
| Prolog dispatch family indicators | 17 |
| Python dispatch functions | 12 |
| Parsed `py_call` terms | 75 |
| Distinct `metta_host_*` terms | 45 |
| Seam predicate indicators supplied by clauses | 39 |
| Prolog encode/decode clauses | 44 |
| Wire-tag rows | 13 |
| Core/workspace door rows | 208/225 |
| Package foundations | 43 |
| Generated artifact/check rows | 18/36 |

The 45 host spellings include the `metta_host_interrupted` exception atom and the qualified private parser `filereader:metta_host_tagged_parse/2`; they are not 45 published services. Eight clauses are exact native forwards. No `py_call` clause is only a direct callback; each carries preparation, ownership, error, or result policy.

The exact forwards are `metta_py_cursor_chunk/3`, `metta_py_cursor_close/1`, `metta_control_signal_line/2`, `metta_py_space_capability_error/4`, `metta_py_function_generation/1`, `metta_py_clear/1`, `metta_py_fast_load/2`, and `metta_py_unregister_token/1`. Their engine targets already have `host_service` rows. The earlier estimate of thirty mechanical forwards does not describe this cut.

Physical lines, counted with `len(text.splitlines())`, and compilation ownership:

| Unit | Before | Decision |
|---|---:|---|
| __init__.py | 5 | Python module |
| algebra.pl | 14 | include |
| bounds.pl | 76 | module |
| callbacks.py | 228 | Python module |
| control.pl | 455 | include |
| cursors.pl | 211 | include |
| debug.pl | 80 | include |
| derivation.pl | 370 | include |
| dispatch.py | 835 | Python module |
| door_catalog.pl | 31 | include |
| errors.pl | 167 | include |
| evaluation.pl | 509 | include |
| foreign.pl | 334 | include |
| handles.pl | 22 | include |
| host.py | 921 | Python module |
| inference.pl | 168 | include |
| json.pl | 99 | include |
| json.py | 126 | Python module |
| library.pl | 300 | include |
| lifecycle.pl | 198 | include |
| messages.pl | 79 | include |
| modules.pl | 42 | include |
| operations.pl | 988 | include |
| persistence.pl | 96 | include |
| positions.pl | 131 | include |
| positions.py | 198 | Python module |
| printer.pl | 37 | include |
| profiling.pl | 203 | include |
| protocol.pl | 42 | include |
| query.pl | 451 | include |
| reader.pl | 86 | include |
| reflection.pl | 16 | include |
| runtime.py | 1808 | Python module |
| shim.pl | 506 | host entry |
| source.pl | 113 | include |
| store.pl | 197 | include |
| subscriptions.pl | 114 | include |
| surface.pl | 978 | engine entry |
| task_context.py | 150 | Python module |
| tokens.py | 24 | Python module |
| trace.pl | 89 | include |
| transport_errors.pl | 17 | include |
| wire.pl | 585 | include |
| worlds.pl | 318 | include |

The include units share the host's binding namespace and private helpers. Their purpose is source ownership; separate export lists would restate those internal crossings. `bounds.pl` keeps its module because its transaction listener's private state and helpers have an existing namespace contract. `surface.pl` loads for engine-only Python use; `shim.pl` loads for the full Python seat. Those audiences remain distinct.

Tried: an evaluation module exporting its existing heads, imported by the otherwise unchanged shim. `python bench.py --counter-only eval-arith` measured 277272 versus the include's 285272 inferences over 2000 evaluations. The native-operation extcost deltas were unchanged; storage rows decreased by two or four inferences. The probe failed the stale improvement pins. Restored both probe files in the detached cut control.

Decided: retain includes for the shared host units and the existing bounds module. The evaluator collapse will remove redundant execution frames in its shared kernel; a namespace is not required to do that. Revisit a module boundary when a unit owns a distinct private API or mutable state that callers should not address.

Tried: reusing the unchanged eager evaluation body behind a six-field record head, a specialized record head, and six list-option lookups. On the actual `eval-arith` workload, record and specialized record both measured [285281, 285272, 285272]; the list measured [309281, 309272, 309272]. Record and specialized probes passed. The list probe failed with `eval-arith inference regression: minimum of [309281, 309272, 309272] is 309272, baseline 285269 plus the 4 inference allowance`.

Decided: fixed records. The measurement proves the representation cost, not the completed evaluator's cost. Final rows must still measure the complete implementation.

[SWI's option documentation](https://www.swi-prolog.org/pldoc/man?section=option) recommends records or dictionaries for hot option access. [predicate_options](https://www.swi-prolog.org/pldoc/man?section=predicate_options) declares option lists, not fixed records. The binding lane will check the actual record grammar instead of declaring an option-list contract the runtime does not implement. SWI's `library(apply_macros)` supplies the precedent for expanding source conveniences before execution.

### Evaluation design

The authoritative `Binding` record gains an evaluation-axes field. The record is currently defined in `doors/__init__.py`; `doors/_catalog.py` publishes it. The field's dataclass declarations, defaults, choices and documentation generate the runtime tuple record, the Prolog record declaration/source-call constructor, catalog representation and reference text. There is no independent hand-maintained options table in the binding.

| Axis | Meaning |
|---|---|
| form | Wire/text target or an already decoded term |
| using | Named substitutions, absent for the identity path |
| answers | One answer, eager bag, held cursor, count, retained count, or status rows |
| fuel | Reuse/open the engine fuel scope |
| inferences | One cumulative engine-step budget; a negative value is unbounded |
| seconds | The engine's time budget; a negative value is unbounded |
| under | Selected evaluation context and direction, or absent |
| policy | Held execution mode and capture policy, or absent |
| repeatable | Require the engine's effect-safe count certificate |
| columns | Caller names to project beside cursor answers |
| accounting | Return the work measured inside the evaluation |
| batch | Preserve one result group per input target |
| unmatched | Preserve the original after an unmatched eager call |

`runtime.py` constructs one immutable record from the calling door's generated defaults and its dynamic arguments. The one engine entry is `metta_py_evaluate/4`: record, space, target, result. Source conveniences construct the same fixed record before a call; they do not scan option lists while evaluating.

One unencoded solution kernel owns target reduction and WFS truth. Resolution and execution share one module scope. Fuel wraps the solution once, and ordinary, retained and status answers use the same truth encoder. Collection varies independently through one answer-form dispatch. Using substitutions operate on decoded terms, preserving host identity. The repeatability refusal remains `[]`; an admitted count remains `[Count]`. Count retention enumerates on the caller's transaction thread, then holds the unencoded bag until it is pulled or released.

Cursor rows keep their current value, caller bindings, optional annotation and cumulative inference count. Ordering materializes and sorts inside the time budget before yielding. Execution policy remains inside held continuations; capture and atomic/speculative state resume with each pull. Ordinary eager calls still use the eager entry, preserving memo observation.

The current plain batch uses unfueled evaluation without unmatched preservation, while a using batch opens fuel and preserves unmatched terms. Public-answer preservation requires representing that distinction explicitly with `fuel` and `unmatched`; it must not disappear as an accidental consequence of sharing the kernel. A regression witness will hold the distinction and the scalar fuel behavior.

### Dispatch design

One dispatch key carries the catalog op kind, raw transport and inverse direction. The catalog kind determines deterministic, streaming or asynchronous behavior. Inverse dispatch always streams, including an inverse attached to a deterministic forward operation.

One Prolog predicate replaces the transport family and six context-selecting wrappers. One Python dispatcher receives the key, optional context token, name, payload and error mode. Context selection is independent of transport and direction; streams enter the retained context for every pull and close. Conversion follows raw versus encoded transport, and collection follows forward kind versus inverse relation. Native equality and truth tests remain ahead of generic dispatch.

Async preparation, transaction-deferred launch, rollback discard, terminal settlement and landing publication retain their existing ownership and ordering. Operation errors, relational candidates, Answer bindings and annotations, declined results, receipts and stream cleanup retain their established policies.

### Services and supplied seam clauses

The engine's `kind/2` rows determine native service identity and arity. Binding projection rows name only the Python-facing spelling for the eight measured mechanical native forwards. Generate their clauses and reject an absent, wrongly classified or mismatched engine target.

The Python callback interface declares the host services and their lazy target objects. Generate the callback facade's name and annotation projections from those rows. The crossing lane parses actual `py_call`, `py_iter` and `metta_ops:` terms. Static callbacks must have a row with the right call shape. Dynamic object/member calls have explicit capability rows tied to the owning predicate and structural call shape; they are not a blanket permission for undeclared callbacks. Mutation tests plant unknown callbacks, wrong arities, unregistered dynamic crossings and wrong native service rows.

Author supplied seam clauses once in `provides/<kind>.pl`, grouped by the engine's kind table. Each declaration retains its load audience and original defining module. Generate the engine-entry and host-entry clause projections from these declarations. This retains engine-only loading and the bounds module's private helper resolution. It also avoids a mutable load-time audience flag.

This is the import/export staging used by [wit-bindgen's WorldGenerator](https://github.com/bytecodealliance/wit-bindgen/blob/2c401164d3a4757d4d860f82af478a27db68372b/crates/core/src/lib.rs): one interface description, separate emissions for the consumers and loading phases. The generated files contain no second authored seam model.

### Wire grammar and remaining consumers

Keep the catalog's thirteen `wire-tag` rows authoritative. Enumerating tests must exercise both codec directions and every payload/frame class, including object identity, handles, undefined truth, Answer, control and relational frames. Validate the schema, projection and Node tables against the same rows. Plant a missing or changed tag to prove the lane fails.

Operation conversion retains annotation, projection and raw identity policy, then delegates to the existing atom codec. Error and remedy syntax construction is not another atom-wire grammar. The duplicated remedy-act reading in `_refusal_remedy` and `Remedy.from_atom` will use one parser. `integrate.space_of` already delegates to `_atoms.designation.space_of`; preserve that one resolver and verify its existing contract.

Tagged matching currently reuses the full timeout and inference limit for every guard after algebra evaluation. Use the existing `_EvaluationBudget` for derivation and all guards in that query. Separate the public algebra entry's budget construction from its evaluation core so the query can own one budget. Native matching keeps its one engine cursor budget. Tests must make several individually cheap guards exceed one shared quota and must preserve capture, bindings and annotations.

### Wide projection

Tried: shared, eager-indexed and retained-lazy-index decoders at 2, 16, 64 and 128 names, with one fact and 1000 complete queries per sample. Warmup uses `forall(Goal,true)` so it does not bind inputs into subsequent repeats.

| Names | Shared query inferences | Indexed query inferences | Shared CPU s | Indexed CPU s |
|---:|---:|---:|---:|---:|
| 2 | 101018 | 112018 | 0.002845 | 0.003052 |
| 16 | 767114 | 890138 | 0.020171 | 0.019951 |
| 64 | 3115474 | 3618538 | 0.100928 | 0.079113 |
| 128 | 6245946 | 7249106 | 0.252761 | 0.160036 |

Decoding is linear in both arms. The shared row projector repeats `memberchk/2` over the bindings, so its C-level work is quadratic and is hidden by the inference count. Retaining the shared decoder's index gives the indexed arm's behavior. Sixteen names is too close in these observations to establish a stable crossover; sixty-four is the first measured width with a separated CPU result.

Decided: repeat the crossover measurement with complete sample ranges, and derive one named crossover declaration from that evidence. Generate the head shape from that declaration, so three handwritten sixty-four-element skeletons cannot disagree. A prepared projection of live cells is a separate candidate only if its measured setup cost satisfies the small-query budgets; do not claim that linear decoding proves linear projection.

### Gates, integration and landing

Turn door-order into a failing gate for mixed, open or recursive boundaries, with independent planted witnesses. Preserve the report's evidence and leave unresolved orders unnumbered. At this cut it already reports 92 mixed, 165 open and 75 recursive rows; do not fabricate integers or quietly baseline those findings. Audit the remaining findings and their source causes while integrating the binding. Any still failing lane must be attributed against the cut.

Required consumers include door metadata and generators, execution policy/cursors, operation declaration/compilation callers, error/remedy decoding, tagged query budget ownership, tests, artifacts and documentation. Every edit outside the binding must name that dependency in the landing report.

Before measurements and complete suites are recorded in worktree scratch. The initial whole Python suite returned 1 failed, 5400 passed and 75 skipped in 509.19 seconds. The failing documentation refusal test and pre-existing cost/twin failures require cut controls. No failed lane is a successful verification.

After implementation: regenerate the declared artifacts, run focused behavior and mutation gates, measure all cost rows, repair regressions, checkpoint coherent verified work, then soft-reset to the named cut. Commit the functional state with WORKTREE evidence markers, pin it with the repository's provenance tool, and commit only header pins. Run the required whole suites and aggregate command on that committed state. Record exact exits, every counter row, ownership and any unresolved failures.

### Counter and evaluator results during verification

Correction to the module probe above: the detached control lacked `morklib.so`.
The resulting absence of `mork_owns_space/1` and `sub_atom/5` removed four
inferences per evaluation. Linking both shared objects restores the control's
1000-call raw readings from 138018 to 142018. The earlier module saving and
storage deltas are confounded; they are not evidence for a namespace decision.
The include decision still follows the shared private API. Repeat the module
comparison with both native objects before closing that obligation.

Tried: the complete evaluator with Python boolean and None terms crossing as
`@(true)`, `@(false)` and `@(none)`. The focused evaluation/operation suite passed
90 tests. `python extensions/python/bench.py --counter-only eval-arith` read
[303281, 303272, 303272], nine inferences per call above the cut. A call profile
attributes six to comparisons against compound flag terms. Native atom flags
remove those comparisons. The door grammar now projects unbounded quotas to
the native `none` sentinel as well; negative public quotas retain their meaning.

Rejected: constructing the decoder's conditionals inside the dynamic work goal.
The cost lane read [293281, 293272, 293272], four extra inferences per call.
Keep those conditionals in a compiled helper. SWI's `compile_meta_arguments`
control setting also added one inference per call in the earlier profile;
revisit only with a compiler-level cost result that reverses it.

Decided: require the engine's declared `space_module/2` and
`with_metta_module/2` services. Their per-call availability tests selected an
obsolete stock-engine fallback to `user`; that fallback contradicts the module
boundary the current engine guarantees. These now join the mechanical forward
projection rather than retaining a second service-selection policy.

Tried: 32 concurrent fresh processes measuring the same 400- and
400000-inference loops with heartbeat intervals 0, 100000, 1000 and 0 again.
`python ai-tmp/ai-binding-heartbeat-probe.py` produced identical corrected
readings, 409 and 400009, across 522240 windows and 1097728 ticks. The actual
instrumented handler crossed Python for exactly two inferences in each of
1117472 ticks. This does not establish the cause of PERF's +229 excursions;
instrumented twin reproduction remains open. An initial instrumentation reload
added a second multifile hook rather than replacing the shim-owned clause;
the corrected probe replaces that clause in its private subprocess.

### Service and codec verification

The strict parser counts 76 `py_call` terms in 14 units at the cut. The earlier
75 count excluded `py_call/1`, including the heartbeat. Both arities are now
checked. The supplied clauses moved into ownership, declaration and event
files, retaining 69, 13 and 8 source declarations or templates respectively.
Two module-service forwards join the original eight. Generated projections
retain the engine/host audiences and the bounds module's defining context.

Tried: reading provision terms with `prolog_read_source_term/4`'s default
error recovery. Four `@true` clauses were skipped because the provision file
had no Janus operator declaration. The tuple-application regression answered
`(<type>)` instead of `()`. The reader now enters its Janus-aware source
module and uses `syntax_errors(error)`. Atom serialization uses `atom_string/2`
so atoms named `true` retain their syntax identity in the parser's JSON.
`test_binding_interface.py` plants malformed syntax as well as unknown
callbacks, arities, dynamic owners, native kinds, projection drift and load
audience defects. The corrected interface and focused behavior run passed
209 behavior cases; the parser's reserved-atom assertion was repaired and
passed in the subsequent 82-case contract run.

The final evaluation/dispatch regressions pass all 12 cases, including
deterministic-forward oracle inverses with two answers and six scheduler
handoffs, context restoration on every pull and close, tagged guards sharing
one 20000-inference quota, and complete projections at 2, 16, 63, 64, 65 and
128 columns. The batch fixture restores its engine-wide stack-depth pragma
in `finally`; its initial missing restoration was caught by the suite's
transactional cleanup assertion. A cutoff-control probe established the
empty-result fixture's expected behavior before correcting the assertion.

The remedy-act readers now share one parser. Eight added valid/malformed
fixtures pass with the existing remedy suite. The door-order mutation tests
pass all 18 cases. The actual door-order command exits 1 with the cut's same
92 mixed, 165 open and 75 recursive rows; those numbers are findings, not
orders or accepted baselines.

The query crossover is one declaration expanded into the original compiled
head shape. `python extensions/python/benchmarks/probes/query_projection.py
--repeats 1000 --samples 11` remeasures both complete singleton-query routes.
At 64 columns, shared/indexed CPU ranges are 0.101544–0.152413 and
0.080958–0.085403 seconds; at 128 they are 0.260161–0.292965 and
0.158773–0.172332. The 16-column ranges overlap. The generated expansion
therefore retains 64 as the first measured separated width. Its initial
discontiguous-clause warning was fixed by emitting adjacent expansion clauses.

### Concurrent counter attribution

Disabling heartbeats does not remove the +229 excursion. The cut's 384 fresh
twin processes at workers=32 produced reading_forms 8129/8358 and nilbc
302970762/302970991 with zero ticks, zero recorded handler entries, zero
Prolog collections and identical held-engine work. The permanent heartbeat
regression passes under 32 workers across intervals 0, 100000, 1000 and 0.

An instrumented 512-process cut cohort isolated all 229 extra inferences to
the first failing Janus text query: `metta_py_original_exception/2` for
reading_forms and `metta_py_function_visible/2` for ifsimple. Raw
`self_inferences` has the same difference as `inferences`, ruling out joined
child counters. A 64-process trace with an inference reading at every port
places the complete difference between failure-status assignment and entry
to Janus's `maplist/2`: 1236 versus 1465 inferences. Predicate port sequences
are otherwise identical. The first profiler comparison had no populated
nodes, so it does not establish equal call counts; the complete port trace
does. Janus declares that failure-path dependency through `autoload/2`.
Autoload and file-resolution instrumentation is the remaining attribution
probe. No heartbeat arithmetic was changed on the basis of an unrelated
counter excursion.

The attribution is now complete. Wrapping the cut's autoload and file-lookup
predicates places the entire difference in `absolute_file_name/3` for
`library(apply)`: 653 versus 882 inferences. `library_info/5` consequently
costs 1081 versus 1310, while `do_autoload/3` costs 118 in either case.
Refreshing the file-cache timestamps produces only the lower twin costs in
128 fresh processes at workers=32; expiring them produces only the higher
costs in another 128. SWI 10.1.13 `boot/init.pl:'$chk_alias_file'/6` uses a
ten-second `file_search_cache_time`. The first failed Janus text query asks
its lazily imported `maplist/2` to bind absent outputs. Concurrent startup
can exceed the file cache's lifetime before that query arrives.

Decided: resolve Janus's required `maplist/2` dependency when the binding
loads. An eager-import cut cohort has one cost for each twin in all 128
processes: reading_forms 6902 and ifsimple 2694. This removes deferred loading
from the measured operation; it does not subtract work from the counter.
The new regression prepares a successful text query, expires file lookups
through SWI's public cache setting, then measures its first four failures.
The cut fails with `[1519, 14, 14, 14]`. The binding passes both that assertion
and the multi-interval heartbeat assertion with 32 concurrent workers.
The combined wire, counter and callback-identity run passes 27 tests.

The wire witnesses now exercise all 13 rows. Node's distribution binary
reports `ERR_NO_TYPESCRIPT` for its stripping flag, so the Node witness uses
the seat's existing esbuild dependency to load the same source into memory;
it writes no build products. Python and native tests preserve host identity,
native handle ownership, variable sharing and the u/a/x/r frame consumers.

### Representation cost and namespace controls

The corrected module experiment exports all 35 evaluation-unit heads and
changes only its include to a module import. Both include and module measure
eval-arith 285272 with both MORK shared objects present. This supersedes the
earlier confounded module saving. The detached control was restored after
the comparison.

The complete cost lane exposed dispatch regressions: encoded +20000 and raw
+16000 over 2000 evaluations; annotated relation +7500. A direct 1000-call
probe measures encoded/raw dispatch at 20002/12002 in the cut and 31002/21002
with compound Janus boolean flags. Native atom flags measure 19002/11002.
The same compiler behavior was measured for evaluation: atomic equality
tests compile directly, while `@(true)` and `@(false)` cost runtime calls.
Decided: the native dispatch key uses atom flags and the Python entry decodes
them once. Keep one dispatcher and the independent axes; do not recreate the
predicate family to specialize constants. The full suites currently running
retain the earlier source snapshot; apply and verify the measured repair
after they finish.

### Repairs exposed by the whole suite

The first complete implementation run returned 25 failed, 5438 passed and
76 skipped in 410.92 seconds. The service relocation removed clauses by
predicate name, including the foreign-provider `metta_py_clear/1` policy,
the unit-returning `metta_py_clear/2` and captured/retained cursor close
clauses. A generated catch-all loaded before the restored policies would
still select the wrong behavior.

Decided: each owning unit retains a `binding_forward(Name/Arity)` declaration
at the original forwarding clause's position. The interface generates its
clause through a scoped term expansion, preserving the defining module and
clause order without a runtime dispatcher. This uses the sentinel-import
pattern documented by SWI's `term_expansion/2`. The checker requires exactly
one declaration per service and distinguishes complete predicate indicators
and exact forwarding bodies from local policy clauses. Mutation witnesses
cover unknown, missing, duplicate and hand-written forwards; behavior tests
hold foreign clears and both cursor representations.

The generated evaluation record also needs explicit constructor values and
typed option normalization: mutable class defaults and an inferred dictionary
union fail the seat's existing Ruff and mypy gates. The authoritative door
defaults remain unchanged. Top-level evaluation-axis catalog rows must be
visited by the door grammar witness alongside nested contract records.

Open: reproduce the remaining named-space wrappers, repeated specialization,
tracer bound and asynchronous context failures after the service repair.
The first after-cost run has 34 observations; account for the missing 35th
row before claiming the complete lane. No cost pins have changed.

The repaired focused run passes 84 cases and fails two. The tracer's 257/258
event mismatch reproduces in the pristine cut, which passes the other three
focused controls. The asynchronous failure is a missed binding consumer:
`lib/lib_thread/lib_thread.pl` tests for the retired dispatch predicate before
capturing the Python context. Both scalar and batch capture must recognize
the one dispatch entry. This is the only required library edit; coordinate
these two probes with the import-semantics package.

The complete observation files contain 34 distinct benchmark names and 36
measurements, including two slope observations. Both before and after contain
the same set. The earlier reference to a missing 35th name was a census error.
Fifteen retired-instruction rows are measured separately; term-operators and
wire-codec intentionally have no Prolog-inference sample.

### Stream validation and instruction costs

Tried: the actual annotated-relation setup with 500 complete top-one queries,
three samples per arm. The current dispatcher reads 1000007 in each sample.
Removing its duplicate stream-decline test reads 998007 in each sample and
preserves the answer `(tense)`. Python `_operation_stream` discards `None`
before encoding, while `_encode_result` returns the declined sentinel only
for `None`. The cut checked deterministic results and trusted that producer
contract for streams. Decided: preserve that boundary once, in the producer;
the shared native dispatch still checks deterministic encoded results.

The repaired native engine lane returns the cut's counts within one inference.
The retired-instruction lane exposes new work in py-method-call and space-name:
2421119405 to 2925499267, and 4782417270 to 6284054751 respectively. Their
Prolog counts improve by one per evaluation. Profile Python record construction
and Janus conversion before pinning; lower Prolog counts alone do not establish
a cost improvement across the host boundary.

The separate automatic-tabling case is the 35th benchmark. It calls its own
scaling observation helper, so the generic baseline observer's 34 unique names
are not a complete census of measured counter values. Capture its eight cells
in the cut and final states as well.

## 2026-09-10

The automatic-tabling control and binding have identical three-sample vectors
at every size. Minima for plain/automatic at 12, 15, 18 and 20 are
122198/14614, 953686/15744, 7605590/16878 and 30412118/17634. The complete
benchmark census is 35 cases, with 34 generic observation names and this
separately sampled eight-cell growth assertion.

Tried: `ai-binding-evaluation-profile.py` on the instruction lane's 30000
space-name evaluations. It records 60000 calls each to `with_options` and
`NamedTuple._replace`: the target constructor and policy boundary rebuild
the same defaults independently. A private controlled-perf probe keeps each
workload's setup outside the measurement and changes one representation at a
time. These are measured candidates, not shipped runtime code:

| Candidate | Minimum instructions |
|---|---:|
| Current interpreted record | 6280523444 |
| Reuse defaults when no axis changes | 5553512852 |
| Reuse and retain defaults as Janus terms | 5430610495 |
| Reuse and put work in a compiled predicate | 5440568452 |
| Reuse and compile control meta-arguments | 5491896260 |
| Reuse, compiled work and retained terms | 5319026935 |
| Reuse and generated symbolic default forwards | 5362180844 |
| Reuse, compiled work and producer-owned encoding | 5355988091 |

The cut's public workload minimum is 4782417270, so none of these candidates
alone establishes cost preservation. Native profiling of 100000 is-space
calls shows extra self time in `metta_py_evaluate/4` and `metta_py_collect/6`.
The next control separates public policy, Janus argument conversion and the
native evaluator loop before choosing the representation.

[Janus Term](https://www.swi-prolog.org/pldoc/man?section=janus-class-term)
retains a Prolog record and restores a copy when passed back. Its local
Janus 1.5.3 `py_unify_record` uses `PL_recorded` followed by `PL_unify`.
Retaining defaults therefore preserves native value identity and scope, but
the measured saving above is insufficient to justify a resource cache by
itself. [SWI's compile_meta_arguments flag](https://www.swi-prolog.org/pldoc/man?section=flags)
explains the compiled-work controls: a control term otherwise compiles into
a temporary clause at each meta-call. The earlier rejection based only on
one added inference was incomplete; the instruction counter must also price
that tradeoff.

The layer control isolates 30000 space-name evaluations in three samples.
Native cut/current minima are 2563032854/2826321819; the same fixed arguments
crossing Janus on every call cost 3126906084/3777942105. Relative to the public
costs above, the increases are 263288965 native instructions, 387747056 in
conversion and 846066153 in host policy. This calls for compile-time selection
of static axes as well as avoiding repeated record construction.

The counter follow-up adds memo_stats (25751/25980), tabling_fib
(50830/50834/51137) and tabling_space_write (36156/36160/36463) from the
ten-round concurrent observation. Only the memo difference currently matches
the established autoload cost. Additional first-use imports are the next
control; a second periodic event is not yet established. The permanent
first-failure test must compare file_search_cache_time 0 and 10, with a
lazy-import control showing the 229 delta and the boot import showing zero.

The three-twin control now establishes both constants. At workers=32, eight
fresh processes per cell in the cut produce the following exact costs. The
two independent controls set existing cache-entry timestamps and the last
cache-sweep timestamp before measuring; these private timestamps are scratch
instrumentation, not a production API or the permanent test's mechanism.

| Cache entries / sweep | memo_stats | tabling_fib | tabling_space_write |
|---|---:|---:|---:|
| Fresh / fresh | 25756 | 50837 | 36173 |
| Fresh / expired | 25756 | 50841 | 36177 |
| Expired / fresh | 25985 | 51066 | 36402 |
| Expired / expired | 25985 | 51144 | 36480 |

`lib_tabling` first imports `library(tableutil)`. Resolving that new alias
enters `system:gc_file_search_cache/1`, which skips a recent sweep, scans
fresh entries, or removes expired entries. Removing the existing apply entry
also changes Janus's later lookup from a cache refresh to insertion. The
combined extra work is 78 over the 229 lookup delta; scanning instead of
skipping already contributes four, yielding the observed 307/303 spread.
The instrumented run names these exact calls. The uninstrumented grid above
establishes their cost without the wrappers' added calls and cache entries.
No tabling-completion event or heartbeat leak is involved.

The eager Janus import alone leaves 75 inferences between the tabling cells
because the maplist lookup no longer follows the sweep. Preparing tableutil
at binding boot removes the sweep from the workload too: all 96 processes
in `ai-binding-tabling-cache-current-warm.jsonl` have one cost per twin under
all four states. Decided: load `library(tableutil)` without importing its
exports at binding boot. `lib_tabling` still owns its predicates and import.

The deterministic public-flag probe catches an important distinction:
`file_search_cache_time=0` bypasses `$cache_file_found/4` maintenance and is
three inferences cheaper than normal expiry. All 16 repeats per cell at
workers=32 read lazy 1367/1593/1596 for flags 10/0/-1; eager reads 14/14/14.
The negative integer forces the complete expired-cache branch without a
sleep. Decided: test both deltas, 226 at zero and 229 at -1, and always restore
10 in `finally`. The lazy control skips only the binding's eager directive
through a process-local, file-scoped term-expansion plant. A preparatory
query initially failed because `source_file/2` cannot name the foreign
py_call implementation; checking every preparation's truth caught that
hidden warm-up. Janus's package file supplies its actual relative path.

An earlier autoload probe used nb_getval state from the caller's engine and
failed inside the library-import cursor with `nb_getval/2: variable
\u0060'$ai_autoload'\u0027 does not exist`. Process-local dynamic observations retain
records across those engine boundaries. The corrected cohorts all returned
zero; no failed probe is counted as attribution evidence.

The tableutil preload decision is superseded. It shifts one optional
library's first-use cost into every binding boot and leaves the next new
alias exposed to the same wall-clock sweep. The library's own explicit
import is correct. The measurement harness owns wall-clock cache policy:
use a non-expiring file-search cache for the named full-lane protocol, with
the exact flag handed to the performance package. Keep only Janus's actual
missing failure-path dependency in binding boot. Before coordination closes,
enumerate one full lane's post-boot autoload and library-load events, compare
the three-twin and full-corpus costs under the fixed cache policy, and retain
the deterministic 226/229 first-failure regression. The preload candidate's
three tests passed in 57.22 seconds before it was withdrawn.

The final no-preload regression passes all three tests in 148.80 seconds
while the full census and cost cohorts run concurrently. The census runs
all 277 twins with verbose_autoload and verbose_load enabled after boot;
all children exit zero. Its native stderr names 45 distinct autoloaded
predicate indicators and 40 first-use library modules. A mistaken observer
hook module left the structured events empty, so only native messages are
the census evidence. The fixed-cache full cohort also completes 277/277;
96 processes of the three twins read exactly 24515, 49667 and 35058 on this
binding snapshot, with file_search_cache_time=9223372036854775807.

The census identifies direct binding calls to aggregate_all/3, gensym/2
and limit/2 whose providers were imported only into metta_engine, not user.
It also identifies lib_redis:uuid/1 at initialization and subscription setup.
Decided: declare those dependencies at their owners. The reserved Redis
change is one import hunk with no-autoload evidence; optional tableutil and
upstream libraries' explicit autoload declarations remain lazy. The engine
no-autoload gate already passes before the Redis declaration, so it proves
preserved operation, while the census proves the removed deferred lookup.

The census projection now records 45 autoloads, 40 library loads, twelve
distinct ordinary compilation entries and one QLF compilation entry, retaining
every native message and example in `ai-binding-autoload-census.json` in the
main checkout's scratch directory. Source checks identify the remaining
autoloads as SWI 10.1.13's explicit declarations, plus socket's native
predicate-options annotations. The Redis owner change is reserved and added.

The four-test dependency/counter run returned three passed and one failed in
110.30 seconds: fib read 49735 or 49788 under the fixed cache setting. A
subsequent 96-process interval cohort and a 384-process repeat read one cost
at every interval, with no Prolog collections. The latter's costs/held-engine
contributions are memo 24520/20470, fib 49735/21733, table-write 34975/21115.
The 53-inference observation remains unattributed. It must not become a band.

A separate SWI control establishes that an engine retains its creator's
Prolog flags from creation: `engine_create(X,current_prolog_flag(
file_search_cache_time,X),E),set_prolog_flag(file_search_cache_time,
9223372036854775807),engine_next(E,Read)` answers 10. Set the harness flag
before MeTTa boot to cover every subsequently created engine. This fact alone
does not attribute the 53. Instrumented first-use tableutil lookups in 96
processes observed the large lifetime and six inferences for the guarded
sweep, both when set before and after boot. The public-flag preboot control's
96 processes return memo 24515, fib 49667 and table-write 34901 under the
canonical twin launch environment.

Tried: one compositional evaluation goal planner, with the three default
door bodies generated from it and dynamic records calling it at run time.
`ai-binding-plan-cost.py` measures 4850109017 space-name instructions; removing
the host boundary's empty option-dictionary allocation gives 4836126403.
Generating four producer clauses for static transport/fuel pairs worsens the
minimum to 4847137756. That producer specialization is rejected.

The dynamic-record control rejects the runtime planner itself. Over 1000
evaluations it adds 2000 inferences to one-answer collection, 5000 to all and
status, and 3000 to count, cursor and retained collection. The same deltas
hold with substitutions and with time/inference quotas. Initial first-use
observations are recorded separately in `ai-binding-plan-record-costs-v2.json`.
Decided: any planner must emit both default and general runtime clauses at
load time. It cannot be another per-call interpreter beside the record.

The next compiler control uses the existing source-compilation primitive:
SWI's `term_expansion/2` emits native clauses from goal templates, and only
pure comparisons of known option fields are folded. Runtime argument values,
side effects, output unifications, cut scope and answer order stay residual.
This avoids the unsafe approach of executing every ground goal in a partial
evaluator. SWI's own `apply_macros.pl` and the upstream goal-expansion contract
require preserving caller-variable bindings; the templates are constructors
of code, not arbitrary procedure unfolding. The general collector clauses
retain indexed collection heads, so generation does not enumerate an entire
cross-product of thirteen axes.

The load-time template control measures 4843750790 instructions. Resolving
only constructor-local aliases after selecting a static branch lowers this
to 4835598366. Keeping symbolic preset names at the Janus boundary still
converts a string on every evaluation. Generated numeric identifiers for
the same door rows lower the minimum to 4820989640, within the unchanged
4788306837 pin's one-percent allowance. Identifiers are private projections
of the rows, not another authored mode table or retained native resource.

The general-record control initially adds one inference per unbounded
evaluation and five with quotas. Inlining preparation and work removes two
calls, but declaring the guard a meta-predicate makes bounded evaluations
eleven inferences dearer. Reject that declaration. The next control gives
the guard a compiled accounted-work predicate, constructed by the same
template that supplies the unbounded entry, so it need not compile a compound
callable per invocation. SWI 10.1.13's `apply_macros.pl` and
`compile_aux_clauses/1` establish the source-owned compilation mechanism;
the final expander will use an imported sentinel and fold only control
combinators and pure comparisons, never traverse program data.

The counter regression with seed 2099707967 now passes all four tests in
120.26 seconds with the fixed cache flag set before boot. The earlier 53
remains unexplained. A Python-GC observer that retained every callback event
under a threshold of one created its own growing collection workload and
was stopped explicitly, not timed out. It supplies no attribution evidence.
The replacement counts callback kinds and observes deferred native releases.

The staged-bound control settles the evaluator design. A compiled accounted
predicate crosses the quota delimiter while the ordinary entry inlines that
same template. Preparation and work are construction helpers only. Over
1000 calls the general records save 1000 inferences for every unbounded
collection and preserve the bounded counts exactly, including substitutions;
cursors save 1000 with or without quotas. First-use warm-up costs are separate
in `ai-binding-staged-bounds-records.json`. The space-name instruction minimum
is 4814179332 over three samples. Implement this shape with numeric default
projections, one host option-construction boundary, and scoped source
expansion. Keep the bounded guard's existing calling convention.

The corrected GC control completes all 216 processes at workers=32. Normal,
disabled and forced Python collection all read memo 24520, fib 49735 and
table-write 34975 at heartbeat intervals 0, 100000 and 1000. No observed
collection policy reproduces 53. The result narrows the search but does not
attribute the original failing sample.

The 53-inference observation is now reproduced exactly and attributed to
owned library artifacts, not heartbeat or file-cache accounting. At the
preserved c282bd32d snapshot, forcing both `lib_import.qlf` and
`lib_tabling.qlf` absent changes fib 49735 to 49788, including a held-engine
contribution of 21733 to 21786. A source-level coverage control identifies
`metta_qlf_boot:qlf_child/2`, which launches the hermetic compilation child.
The raw two-repeat artifact-state grid is `ai-binding-53-qlf-grid.jsonl`.
With only one missing the cost is 49763; with both missing it is 49788.
The child can repair other governed artifacts while booting, so a stale
artifact is a different path and is recorded separately in that grid.

The workers=32 cold cohort reproduces 49788 twice, 49763 three times and
49735 twenty-seven times as the shared artifacts become available. All 32
warm controls read 49735. The regression will complete an unmeasured warm-up
of its three real twins before starting fresh measured processes. Its
one-cost assertion remains exact. The first import in each process remains
measured; only shared compiled artifacts are prepared, as the corpus pins
already assume. Receipts: `ai-binding-53-qlf-cohort.jsonl` and its zero exit.

The required door-schema cohort with seed 1938997014 fails identically on
the cut and binding: after provider registration tests withdraw their rows,
the grammar has a `door-provider` constructor but no remaining row instantiates
it. Both isolated tests pass, which confirms the order dependency. The cohort
counts are cut 68 passed/1 failed and binding 68 passed/1 failed. Add the
existing explicit provider fixture to the grammar walk, just as it already
constructs the absent-body variant. No installed optional provider is a
precondition of the grammar check.

The compiled evaluator's whole suite exposed a context left by
`test_tagged_algebra_debits_inferences_across_operations[combine]`; the next
49 failures inherited `evaluation_context('bounded-aggregate-combine',0,none)`.
A before/after observer reproduces the leak with that test alone. The native
1..2000 inference-budget sweep reproduces three leaks without an outer scope
and two with one. This is the `setup_call_cleanup/3` interruption window
already established in `2026-09-07-every-intermittent-root-caused.md` for fuel.

Rejected: only replacing the push with `b_setval/2`. It leaves two first-scope
leaks because `metta_evaluation_context_pop(none)` catches the inference
signal before `nb_delete/1` runs. That success prevents unwinding the trail.
Decided: trail the push and let deletion propagate control signals. Copy the
incoming context first to retain the old snapshot semantics for variables.
The private combined repair has zero leaks in both sweep arms; the exact
control is `ai-binding-context-sweep-v3.log`. The integrator reserves only
the two engine predicates, their minimal contract addition and the existing
native answer suite. No effect-plan code changes.

Verified: `sh engine/test.sh suites/evaluation/answers.plt` passes21 tests
and one additional sweep arm. Both arms check the context inside the outer
scope and its absence after that scope exits. The Python feature, evaluation
context, typed-context, tagged-provider and counter cohort passes205 tests
in82.33 seconds atseed2776990893, including the original leaking test and all
four concurrent counter regressions. The corrected door grammar cohort
passes69 tests in256.01 seconds atseed1938997014.

Clone assessment: `jscpd --format python --min-lines 5 --min-tokens 50
--reporters console,json --output ai-tmp/ai-binding-final-clones
--ignore '**/options.py,**/__pycache__/**' extensions/python/metta/_binding`
reports0 clones in9 authored Python files,2446 logical lines. This is a
maintenance check for those files, not a measure of Prolog duplication or
the number of independent semantic implementations.

The final 277-process cost comparison exposed source-load increases in the
regex, conformance and C-provider twins. Crossing controls isolate exactly
144, 684 and 90 extra inferences in their `consult_global/1` calls. The two
generic `system:goal_expansion/2` hooks try the binding's scope checks on every
unrelated source goal. This is nine extra inferences per source goal. In a
plain SWI control, 1,000 `expand_goal/2` calls cost 74,002 before importing the
macros, 92,002 afterward, and 74,002 with heads indexed by the source goal.
The count doubles because `expand_goal/2` visits the unchanged goal again.
Receipts: `ai-binding-positive-twin-crossings.jsonl`,
`ai-binding-indexed-twin-crossings.jsonl`, and
`ai-binding-macro-expansion-probe.log`.

Decided: generate the indexed hook and its replacement clause from each one
macro rule. One shared emitter serves the options and source-macro generators;
it retains the imported-sentinel check before executing a selected rule.
SWI's `library(debug)` uses the same input-head indexing. The control restores
all three consultation costs exactly to the cut. A native regression compares
unrelated expansion before and after importing the macros, checks that a
non-importing module does not interpret malformed binding syntax, and checks
that an importing module still expands a record.

Verified: the binding-interface and evaluator cohort passes 50 tests in
9.07 seconds. Eight fresh processes per formerly increased twin all read
regex 28,947, conformance 18,403, C-space 40,911 and C-extension 26,972.
Each is below its cut control. No point or empirical allowance changed.
The four concurrent counter tests also pass at the earlier failing seed
3133533041 in 70.05 seconds; the raw 96 three-twin samples are retained in
`ai-binding-final-counter-observations.jsonl`. Their first-failure controls
read eager 14 at flags 10, 0 and -1, and lazy 1,367, 1,593 and 1,596.
The earlier isolated 24,514/24,515 memo observation has not reproduced in
the stable-source controls and is not attributed by those passing runs.

The ch17/05 idle-pool assertion failed in one of the binding's 277-process
fixed-cache observations and one of 32 targeted observations. Receipts are
`ai-binding-final-fixed-twins.jsonl` and `ai-binding-pool-binding.jsonl`.
The performance package's cut control reproduces it twice in96 trials.
Its deterministic `tests/prolog/suites/libraries/lib_thread_completion.plt`
reproduces both cached-result await paths and the inconsistent pool snapshot.
The first two tests fail with `awaited(10)==joining`; the snapshot test fails
with `0+0=:=1` before its repair. See the performance branch's
`docs/journal/2026-09-07-merged-tree-reconciliations.md`, section
"2026-09-09, performance reconciliation and pool completion".

The cached-result paths answer `Worker=none` before publication cleanup
finishes, so await skips the join while the pool still owns the worker.
Separate `thread_pool_property/2` requests can also observe running=0 and
free=0 from different snapshots. The performance package retains the worker
join in both paths and reads one pool snapshot. Its three deterministic tests
and96 fresh trials pass after that repair. This binding package changes only
the two previously reserved Python-context availability probes in lib_thread;
the example assertion and all pool implementation predicates remain intact.

The final instruction run exposed one remaining boundary cost:
`space-name instruction regression: minimum of [4838633947, 4838624699, 4838634412]
is 4838624699, baseline 4788306837 plus 1% is 4836189905`.
The evaluation collector already classifies whether its work remains in a
held engine. `_controlled_run` nevertheless looked up that classified call in
both legacy cursor maps and recomputed the same result on every evaluation.
This is a fixed crossing cost; the number of lookups is already O(1).

Tried: retain the collector's classification and consult the legacy maps
only for the other native doors. `ai-binding-controlled-classification.py`
prices 30,000 space-name evaluations through the official controlled counter.
Current samples are4837422397/4837274550/4836943021; classified samples are
4803516416/4804235925/4804565973. The native predicate and arguments are
unchanged. Decided: reuse the existing classification at its owner, preserving
the shared policy application below both branches. No default-only policy,
new mode, cached scope or additional dispatch table is introduced.

Verified: the classified execution boundary passes159 tests in23.56 seconds.
The official instruction lane reads2429626999 for py-method-call and
4814801417 for space-name, both inside their unchanged one-percent bands.
Its six remaining red rows also fail on the pristine cut. Ruff passes and
mypy passes174,1,3 and1 source files. The first static launch mistakenly
executed the component's sourced lane definitions and reported
`extensions/python/check.sh: 47: run: not found`; the root gate is the runner.

The final native verbose census completes277 successful processes at32
workers and still records41 autoloads,40 library loads,12 compilations and
one QLF compilation. Both final default-cache and fixed-cache full lanes
complete277 successful processes. The fixed-cache96-process control reads
32 identical samples each: memo24514, fib49601, table-write34760. Source-hook
indexing removes72 and144 compilation inferences from the two tabling twins.
No additional runtime dependency appears after that repair. The main-checkout
`ai-binding-autoload-census-closed.md` and JSON companion preserve every entry.

Default-cache versus fixed-cache observations differ in22 rows:12 by75,
two by4, two by793, one by871, and five concurrency observations by73,
14127,12,53 and-934. The file-cache maintenance differences disappear in
the fixed-cache controls; the concurrency examples retain their existing
protocol-specific treatment. They are not evidence of heartbeat leakage.
The earlier C-store reading30004 is a separate missing-artifact branch:
16 isolated controls with its local CSTORE_SO path absent all read30004;
16 with the artifact present all read40911. No shared artifact was removed
by that control. The final complete lanes exercise the provider branch.

Clone-check correction: the final explicit `npx --yes jscpd --format python
--min-lines 5 --min-tokens 50 --reporters console,json --ignore
'**/options.py,**/__pycache__/**' extensions/python/metta/_binding` finds the
same seven-line refusal-decoration tail in Runtime._refused and _classified
on cut and binding. It reports1 clone in8/9 files and4290/4258 lines. The
earlier zero-clone receipt is not reproduced by this command. The two error
classification entry points have different fallback and class-construction
contracts; the short unchanged final decoration is retained. No new clone
appears. Physical line counts below use splitlines and include generated
projections, independently of the detector's line count.

## 2026-09-10 final measurement tables

The before tree is the provisioned cut3e5855a35 with both MORK shared objects.
The after inference receipts follow the indexed macro repair; the subsequent
host classification change leaves every native predicate and argument intact.
The instruction receipts include that classification repair. Benchmarks use
three samples; both extra slope rows and all eight automatic-tabling cells
are included. Native engine instructions were measured independently even
where an earlier stale inference pin would have stopped their ordinary gate.
Twins use one complete fixed-cache lane on each tree and the declared32 workers.
All sample arrays and full example paths remain in the corresponding
`ai-binding-closed-*`, `ai-binding-final-cut-*` and `ai-binding-before-*`
receipts. The complete table projection is `ai-binding-cost-tables.json`.

Twelve Python benchmark points and three extension-cost points moved by more
than four inferences because of this binding change. Their new comments name
both the measured cut and the binding, retaining the distinction between an
older stale pin and this change's delta. Other points, all instruction bands,
all slope shapes and every empirical envelope remain unchanged.

Physical lines per binding unit, including generated projections. A zero means absent in that snapshot.

| Unit | Cut | Binding | Compilation ownership |
|---|---|---|---|
| __init__.py | 5 | 5 | Python module |
| algebra.pl | 14 | 0 | removed; clauses now grouped by seam kind |
| bounds.pl | 76 | 74 | module; owns transaction listener state |
| callbacks.py | 228 | 195 | Python module |
| control.pl | 455 | 446 | include; shared host-private namespace |
| cursors.pl | 211 | 209 | include; shared host-private namespace |
| debug.pl | 80 | 80 | include; shared host-private namespace |
| derivation.pl | 370 | 370 | include; shared host-private namespace |
| dispatch.py | 835 | 698 | Python module |
| door_catalog.pl | 31 | 31 | include; shared host-private namespace |
| errors.pl | 167 | 165 | include; shared host-private namespace |
| evaluation.pl | 509 | 188 | include; shared host-private namespace |
| evaluation_policy.pl | 0 | 163 | compiler module; scoped expansion API |
| foreign.pl | 334 | 142 | include; shared host-private namespace |
| handles.pl | 22 | 22 | include; shared host-private namespace |
| host.py | 921 | 921 | Python module |
| inference.pl | 168 | 168 | include; shared host-private namespace |
| interface.py | 0 | 138 | Python module |
| json.pl | 99 | 99 | include; shared host-private namespace |
| json.py | 126 | 126 | Python module |
| library.pl | 300 | 298 | include; shared host-private namespace |
| lifecycle.pl | 198 | 182 | include; shared host-private namespace |
| messages.pl | 79 | 79 | include; shared host-private namespace |
| modules.pl | 42 | 36 | include; shared host-private namespace |
| operations.pl | 988 | 868 | include; shared host-private namespace |
| options.pl | 0 | 94 | compiler module; scoped expansion API; generated |
| options.py | 0 | 39 | Python module; generated |
| persistence.pl | 96 | 94 | include; shared host-private namespace |
| positions.pl | 131 | 131 | include; shared host-private namespace |
| positions.py | 198 | 198 | Python module |
| printer.pl | 37 | 37 | include; shared host-private namespace |
| profiling.pl | 203 | 203 | include; shared host-private namespace |
| protocol.pl | 42 | 33 | include; shared host-private namespace |
| provides/declaration.pl | 0 | 59 | authoritative kind input; generator reads it |
| provides/event.pl | 0 | 31 | authoritative kind input; generator reads it |
| provides/ownership.pl | 0 | 543 | authoritative kind input; generator reads it |
| provides_engine_user.pl | 0 | 137 | include; shared host-private namespace; generated |
| provides_host_metta_python_bounds.pl | 0 | 6 | include; shared host-private namespace; generated |
| provides_host_user.pl | 0 | 232 | include; shared host-private namespace; generated |
| query.pl | 451 | 413 | include; shared host-private namespace |
| reader.pl | 86 | 74 | include; shared host-private namespace |
| reflection.pl | 16 | 16 | include; shared host-private namespace |
| runtime.py | 1808 | 1808 | Python module |
| services.pl | 0 | 25 | compiler module; scoped expansion API; generated |
| shim.pl | 506 | 524 | host entry; owns host boot namespace |
| source.pl | 113 | 113 | include; shared host-private namespace |
| source_macros.pl | 0 | 29 | compiler module; scoped expansion API; generated |
| store.pl | 197 | 181 | include; shared host-private namespace |
| subscriptions.pl | 114 | 113 | include; shared host-private namespace |
| surface.pl | 978 | 809 | engine entry; supports engine-only loading |
| task_context.py | 150 | 150 | Python module |
| tokens.py | 24 | 24 | Python module |
| trace.pl | 89 | 89 | include; shared host-private namespace |
| transport_errors.pl | 17 | 9 | include; shared host-private namespace |
| wire.pl | 585 | 585 | include; shared host-private namespace |
| worlds.pl | 318 | 314 | include; shared host-private namespace |

Python benchmark inference minima; `none` means the row executes no Prolog work.

| Row | Operations | Cut | Binding | Delta |
|---|---|---|---|---|
| add-batch | 2000 | 54057 | 54057 | +0 |
| add-single | 2000 | 66036 | 66036 | +0 |
| add-table-rows | 2000 | 62057 | 62057 | +0 |
| alpha-unique | 50000 | 4161495 | 4161492 | -3 |
| annotated-relation | 500 | 1002846 | 1001346 | -1500 |
| direct-join | 9995 | 122017 | 122017 | +0 |
| eval-arith | 2000 | 285272 | 279272 | -6000 |
| file-load | 20001 | 846872 | 846715 | -157 |
| foreign-match | 2000 | 793272 | 793272 | +0 |
| handle-round-trip | 2000 | 1593272 | 1593272 | +0 |
| json-wire | 2000 | 158007 | 158007 | +0 |
| let-heavy | 1000000 | 16005530 | 16005527 | -3 |
| loop-1m | 1000000 | 11004644 | 11004644 | +0 |
| op-encoded | 2000 | 325272 | 317272 | -8000 |
| op-raw | 2000 | 305272 | 297272 | -8000 |
| prepared-join | 9995 | 281082 | 281082 | +0 |
| py-method-call | 10000 | 2300732 | 2270732 | -30000 |
| query-2k-rows | 40000 | 83627 | 83627 | +0 |
| query-limit-guarded | 5000 | 37707 | 37707 | +0 |
| query-limit-plain | 5000 | 33407 | 33407 | +0 |
| query-where | 10160 | 72755 | 72715 | -40 |
| register-op | 100 | 124431 | 124231 | -200 |
| run-source | 1000 | 444272 | 444272 | +0 |
| save-load-fast | 20001 | 4050173 | 4049764 | -409 |
| save-load-metta | 20001 | 1048424 | 1047985 | -439 |
| sort-atom | 100000 | 1301595 | 1301592 | -3 |
| source-load | 1000 | 258686 | 258599 | -87 |
| space-digest | 20000 | 920269 | 920269 | +0 |
| space-name | 30000 | 4290270 | 4200270 | -90000 |
| subscribe-tax | 2000 | 54071 | 54071 | +0 |
| table-bridge-match | 2000 | 793272 | 793272 | +0 |
| term-operators | 20000 | none | none | none |
| typed-call | 500000 | 12505434 | 12505431 | -3 |
| wire-codec | 504000 | none | none | none |

The 35th benchmark is automatic tabling; all eight measured cells are below.

| Size | Mode | Cut | Binding | Delta |
|---|---|---|---|---|
| 12 | plain | 122198 | 122198 | 0 |
| 12 | automatic | 14614 | 14614 | 0 |
| 15 | plain | 953686 | 953686 | 0 |
| 15 | automatic | 15744 | 15744 | 0 |
| 18 | plain | 7605590 | 7605590 | 0 |
| 18 | automatic | 16878 | 16878 | 0 |
| 20 | plain | 30412118 | 30412118 | 0 |
| 20 | automatic | 17634 | 17634 | 0 |

Both separately measured slopes retain their growth.

| Row | Sizes | Cut small/large | Binding small/large | Growth |
|---|---|---|---|---|
| let-heavy | 100000/1000000 | 1605463/16005463 | 1605460/16005460 | 14400000 |
| typed-call | 50000/500000 | 1255374/12505374 | 1255371/12505371 | 11250000 |

Retired user instructions, minimum of three controlled fresh processes.

| Row | Cut | Binding | Delta |
|---|---|---|---|
| alpha-unique | 2954268445 | 2949480087 | -0.162% |
| json-wire | 26262502518 | 26263217517 | +0.003% |
| let-heavy | 8706449652 | 8701520369 | -0.057% |
| py-method-call | 2418445757 | 2429626999 | +0.462% |
| save-load-fast | 6375695173 | 6344060180 | -0.496% |
| save-load-metta | 3493578397 | 3446232347 | -1.355% |
| sort-atom | 4002741600 | 4095266971 | +2.312% |
| source-load | 258663214 | 258640226 | -0.009% |
| space-digest | 1532205665 | 1530496123 | -0.112% |
| space-name | 4781060730 | 4814801417 | +0.706% |
| structures-dispatch | 591651073 | 591695868 | +0.008% |
| subscription-dispatch | 59821112 | 59816888 | -0.007% |
| term-operators | 1020675706 | 1019036443 | -0.161% |
| typed-call | 7427153079 | 7435159999 | +0.108% |
| wire-codec | 3451808706 | 3451700702 | -0.003% |

All fourteen extension-cost rows, inference minima.

| Row | Operations | Cut | Binding | Delta |
|---|---|---|---|---|
| the driver itself | 3000 | 21132 | 21129 | -3 |
| ordinary MeTTa function | 3000 | 30132 | 30129 | -3 |
| @m.define, no annotations | 3000 | 105132 | 102129 | -3003 |
| @m.define, annotated | 3000 | 30132 | 30129 | -3 |
| translator rule (a macro) | 3000 | 21132 | 21129 | -3 |
| Prolog grounded predicate | 3000 | 27132 | 27129 | -3 |
| Python operation, transport="raw" | 3000 | 57132 | 54129 | -3003 |
| Python operation, encoded | 3000 | 81132 | 78129 | -3003 |
| C foreign predicate | 3000 | 24132 | 24129 | -3 |
| the add driver itself | 1000 | 7132 | 7129 | -3 |
| add-atom, no claims on the space | 1000 | 43132 | 43129 | -3 |
| add-atom through an accept-all pre-add hook | 1000 | 60132 | 60129 | -3 |
| add-atom into a pool with a declared admits type | 1000 | 72132 | 72129 | -3 |
| add-atom into a pool with a declared capacity | 1000 | 80132 | 80129 | -3 |

All seven native engine rows. Later Python-only classification preserves this native source state.

| Row | Cut inferences | Binding inferences | Cut instructions | Binding instructions |
|---|---|---|---|---|
| boot | 296767 | 296767 | 969176997 | 969020894 |
| parse | 152 | 152 | 126939048 | 126938651 |
| parse-prolog | 3517359 | 3517359 | 2009973930 | 2010147902 |
| translate | 313726 | 313726 | 320112641 | 319601419 |
| match | 267402 | 267402 | 172734265 | 170552516 |
| match-skew | 208102 | 208102 | 489787090 | 489800782 |
| evaluate | 559106 | 559105 | 508230281 | 505031008 |

All 277 twin observations use workers=32 and file_search_cache_time=9223372036854775807 before boot. Keys shorten only chapter folder names; the JSON companion records every full path. Empirical rows are observations and retain their existing envelopes. Redis's guarded path is shown but its available(m) is false, so it is not a measured provider cost.

| Twin | Cut | Binding | Delta | Budget kind |
|---|---|---|---|---|
| ch03/01-comments | 2399 | 1162 | -1237 | point |
| ch03/02-string | 177 | 174 | -3 | point |
| ch03/03-string_comments | 4005 | 2736 | -1269 | point |
| ch03/04-repr | 2923 | 2870 | -53 | point |
| ch03/05-parse | 672 | 634 | -38 | point |
| ch03/06-reading_forms | 8129 | 6661 | -1468 | point |
| ch04/04-01/01-spaces | 4059 | 2822 | -1237 | point |
| ch04/04-01/02-spaces2 | 3123 | 1878 | -1245 | point |
| ch04/04-01/03-spaces3 | 528 | 371 | -157 | point |
| ch04/04-01/04-spaces_find | 10287 | 10110 | -177 | point |
| ch04/04-01/05-spaces_succeedspredicate | 8034 | 8024 | -10 | point |
| ch04/04-01/06-spaces_removeallatoms | 14362 | 12955 | -1407 | point |
| ch04/04-01/07-add_atom_fun_space | 3853 | 2439 | -1414 | point |
| ch04/04-01/08-spacefunction | 7372 | 6140 | -1232 | point |
| ch04/04-01/09-selfprog | 4713 | 3472 | -1241 | point |
| ch04/04-01/12-add_reducts_and_containment | 6541 | 6188 | -353 | point |
| ch04/04-01/13-migrating_and_counting | 15651 | 15309 | -342 | point |
| ch04/04-02/01-matchsingle | 4756 | 4749 | -7 | point |
| ch04/04-02/02-matchnested | 3539 | 2313 | -1226 | point |
| ch04/04-02/03-matchnested2 | 3307 | 2081 | -1226 | point |
| ch04/04-02/04-match_snapshot | 5834 | 4428 | -1406 | point |
| ch04/04-02/05-constanthead | 4972 | 3744 | -1228 | point |
| ch04/04-02/06-listhead | 5257 | 4025 | -1232 | point |
| ch04/04-02/07-unify | 11267 | 9982 | -1285 | point |
| ch04/04-02/08-unify_eval_branches | 6829 | 6810 | -19 | point |
| ch05/05-01/01-identity | 3706 | 2478 | -1228 | point |
| ch05/05-01/02-twostage | 7602 | 6352 | -1250 | point |
| ch05/05-01/03-program_order | 1066 | 1060 | -6 | point |
| ch05/05-01/04-partialdef | 6198 | 4966 | -1232 | point |
| ch05/05-01/05-smartdispatch | 12045 | 10804 | -1241 | point |
| ch05/05-01/06-functionhead | 10442 | 9207 | -1235 | point |
| ch05/05-01/07-functionhead2 | 14349 | 13120 | -1229 | point |
| ch05/05-01/08-functionhead3 | 8638 | 7390 | -1248 | point |
| ch05/05-01/09-multicall | 5590 | 4362 | -1228 | point |
| ch05/05-02/01-dispatch_policies | 1774 | 1714 | -60 | point |
| ch05/05-02/02-functionremoval | 13731 | 12493 | -1238 | point |
| ch05/05-02/03-functionremovalspec | 14855 | 13620 | -1235 | point |
| ch05/05-02/04-specialize | 81978 | 80695 | -1283 | point |
| ch05/05-02/05-specialize_recursive_wrap | 13906 | 12517 | -1389 | point |
| ch05/05-02/06-specializecyclic | 26043 | 26037 | -6 | point |
| ch05/05-02/07-specializefunctiontypes | 6667 | 5439 | -1228 | point |
| ch05/05-03/01-math | 11873 | 10137 | -1736 | point |
| ch05/05-03/02-math_exp_random | 9357 | 8079 | -1278 | point |
| ch05/05-03/03-exp_and_seeded_randomness | 4382 | 4303 | -79 | point |
| ch05/05-03/04-bit_operations | 3910 | 3688 | -222 | point |
| ch05/05-04/01-backward_arithmetic | 37501 | 36024 | -1477 | point |
| ch05/05-04/02-relational_arithmetic | 7245 | 7012 | -233 | point |
| ch05/05-04/03-constraint_domains | 61867 | 61643 | -224 | point |
| ch05/05-04/04-relational_integer_division | 9034 | 8939 | -95 | point |
| ch06/01-superpose_nested | 4113 | 2876 | -1237 | point |
| ch06/02-casenew | 5988 | 4751 | -1237 | point |
| ch06/03-collapse | 269 | 266 | -3 | point |
| ch06/04-supercollapse | 9007 | 7779 | -1228 | point |
| ch06/05-empty | 2515 | 1289 | -1226 | point |
| ch06/06-once | 3915 | 2687 | -1228 | point |
| ch06/07-tests | 12759 | 11360 | -1399 | point |
| ch06/08-permutations | 23889644 | 23889488 | -156 | point |
| ch06/09-streamops | 5571 | 5556 | -15 | point |
| ch06/10-mettaset | 375 | 375 | 0 | point |
| ch07/07-01/01-ifsimple | 3920 | 2683 | -1237 | point |
| ch07/07-01/02-if | 3285 | 2048 | -1237 | point |
| ch07/07-01/03-if2 | 4792 | 3550 | -1242 | point |
| ch07/07-01/04-if3 | 4967 | 3574 | -1393 | point |
| ch07/07-01/05-if4 | 5779 | 4377 | -1402 | point |
| ch07/07-01/06-if_branch_binding | 15019 | 13779 | -1240 | point |
| ch07/07-01/07-and_or | 1508 | 1506 | -2 | point |
| ch07/07-01/08-booleansolver | 1618 | 1615 | -3 | point |
| ch07/07-01/09-xor | 6565 | 5330 | -1235 | point |
| ch07/07-01/10-and_then_or_else | 20633 | 19184 | -1449 | point |
| ch07/07-01/12-implication_and_unifiability | 13874 | 13599 | -275 | point |
| ch07/07-02/01-case | 2939 | 1702 | -1237 | point |
| ch07/07-02/02-case2 | 2911 | 1674 | -1237 | point |
| ch07/07-02/03-caseconstrain | 7 | 7 | 0 | point |
| ch07/07-02/04-caseempty | 5836 | 4586 | -1250 | point |
| ch07/07-02/05-casecomputed | 11613 | 10256 | -1357 | point |
| ch07/07-02/06-ifcasenondet | 7385 | 6150 | -1235 | point |
| ch07/07-02/07-let_superpose_if_case | 6225 | 4983 | -1242 | point |
| ch07/07-03/01-letstar | 2994 | 1757 | -1237 | point |
| ch07/07-03/02-letlet | 1152 | 1149 | -3 | point |
| ch07/07-03/03-letext | 1290 | 1284 | -6 | point |
| ch07/07-03/04-letstarcomputed | 10907 | 9621 | -1286 | point |
| ch07/07-03/05-metta4_prog | 763 | 757 | -6 | point |
| ch07/07-03/06-chain | 5443 | 4193 | -1250 | point |
| ch07/07-03/07-eval | 18925 | 17693 | -1232 | point |
| ch07/07-03/08-sealed | 11207 | 9763 | -1444 | point |
| ch07/07-03/09-walrus | 7508 | 6274 | -1234 | point |
| ch07/07-03/11-nop | 3868 | 3682 | -186 | point |
| ch07/07-04/01-forall | 23485 | 22223 | -1262 | point |
| ch07/07-04/02-metta4_streams | 9380 | 7978 | -1402 | point |
| ch07/07-04/03-take | 7450 | 6212 | -1238 | point |
| ch07/07-04/04-cut | 4293 | 3065 | -1228 | point |
| ch07/07-04/05-foldall | 25811 | 24395 | -1416 | point |
| ch07/07-04/06-foldallmatch | 7987 | 6737 | -1250 | point |
| ch07/07-04/07-foldallspacecount | 7297 | 6069 | -1228 | point |
| ch07/07-05/01-factorial | 6891 | 5502 | -1389 | point |
| ch07/07-05/02-fib | 31833 | 30605 | -1228 | point |
| ch07/07-05/03-fibsmart | 11381 | 9992 | -1389 | point |
| ch07/07-05/04-fibsmartimport | 7118 | 7092 | -26 | point |
| ch07/07-05/05-iter | 5132 | 3885 | -1247 | point |
| ch07/07-05/06-peano | 1474486 | 1473080 | -1406 | point |
| ch07/07-05/07-invertpeanoplus | 7853 | 7841 | -12 | point |
| ch08/08-01/01-nestedcons | 3687 | 2459 | -1228 | point |
| ch08/08-01/02-holfunctions | 32551 | 31238 | -1313 | point |
| ch08/08-01/03-holfunctions_intrinsicop | 13145 | 11914 | -1231 | point |
| ch08/08-01/04-curry | 24197 | 22931 | -1266 | point |
| ch08/08-01/05-lambda | 23859 | 22572 | -1287 | point |
| ch08/08-01/06-invertfunction | 7553 | 6318 | -1235 | point |
| ch08/08-01/07-atomops | 12181 | 11875 | -306 | point |
| ch08/08-01/08-alpha_member | 25940 | 25688 | -252 | point |
| ch08/08-01/09-alpha_unique_atom | 15309 | 15097 | -212 | point |
| ch08/08-01/10-multiset_operations | 7697 | 7666 | -31 | point |
| ch08/08-01/11-patrick | 17959 | 17783 | -176 | point |
| ch08/08-01/12-patrick_iterate_fib | 16324 | 15082 | -1242 | point |
| ch08/08-01/13-patrick_iterate_quad | 11530425 | 11529193 | -1232 | point |
| ch08/08-01/14-lib_roman_pair_helpers | 22197 | 20956 | -1241 | point |
| ch08/08-01/15-roman | 324164 | 322677 | -1487 | point |
| ch08/08-01/16-if_decons_expr | 9269 | 9080 | -189 | point |
| ch08/08-01/17-swi_term_doors | 14785 | 14408 | -377 | point |
| ch08/08-01/18-sorting_and_deduplication | 16625 | 16408 | -217 | point |
| ch08/08-01/19-decons_and_substitution | 11713 | 11501 | -212 | point |
| ch08/08-01/20-roman_general_operators | 133500 | 132180 | -1320 | point |
| ch08/08-01/21-compose | 35433 | 34170 | -1263 | point |
| ch08/08-02/01-segments | 10650 | 9169 | -1481 | point |
| ch08/08-02/02-in-an-equation-head | 17148 | 17080 | -68 | point |
| ch08/08-02/03-the-one-sided-fragment | 8294 | 8188 | -106 | point |
| ch08/08-02/04-the-two-sided-fragments | 12163 | 10741 | -1422 | point |
| ch08/08-02/05-the-fence | 6568 | 5332 | -1236 | point |
| ch08/08-03/01-library | 18592 | 18585 | -7 | point |
| ch08/08-03/02-datastructures_fingertree | 236982 | 236734 | -248 | point |
| ch08/08-03/03-text_lib | 37286 | 35512 | -1774 | point |
| ch08/08-03/04-regex_lib | 29081 | 28947 | -134 | point |
| ch08/08-03/05-json_lib | 24860 | 24622 | -238 | point |
| ch08/08-03/06-crypto_lib | 17437 | 16139 | -1298 | point |
| ch08/08-03/07-datetime | 15110 | 14983 | -127 | point |
| ch08/08-03/08-doc_lib | 9034 | 7778 | -1256 | point |
| ch08/08-03/09-conformance | 18438 | 18403 | -35 | point |
| ch08/08-03/10-documentation_as_data | 49849 | 48521 | -1328 | point |
| ch08/08-03/11-combinatorics_lib | 87075 | 86991 | -84 | point |
| ch08/08-03/12-dict_lib | 54196 | 54123 | -73 | point |
| ch08/08-03/13-vector_lib | 31636 | 31537 | -99 | point |
| ch08/08-03/14-reflect_lib | 118067 | 116349 | -1718 | point |
| ch08/08-03/15-fingertree_internals | 208290 | 208128 | -162 | point |
| ch08/08-03/16-the_prolog_rung | 63985 | 63593 | -392 | point |
| ch09/01-types | 15176 | 13753 | -1423 | point |
| ch09/02-builin_types | 68915 | 68646 | -269 | point |
| ch09/03-functiontypes | 14560 | 13320 | -1240 | point |
| ch09/04-outputtype | 8560 | 7326 | -1234 | point |
| ch09/05-meta_types | 1926 | 1747 | -179 | point |
| ch09/06-dont_eval_type | 3907 | 2679 | -1228 | point |
| ch09/08-parametric_types | 6841 | 5609 | -1232 | point |
| ch09/09-recursive_types | 4523 | 4510 | -13 | point |
| ch09/10-recursive_types2 | 9473 | 9466 | -7 | point |
| ch09/11-subtyping | 10885 | 9638 | -1247 | point |
| ch09/12-types_dependent | 17728 | 16497 | -1231 | point |
| ch09/13-types_nondet | 9880 | 8639 | -1241 | point |
| ch09/14-matchtypes | 4565 | 4483 | -82 | point |
| ch09/15-engine_surface | 19131 | 18742 | -389 | point |
| ch09/16-typing_rules | 9830 | 8578 | -1252 | point |
| ch09/18-compiled_overloads | 5116 | 3881 | -1235 | point |
| ch09/20-type_casts_that_hold | 11377 | 9959 | -1418 | point |
| ch09/21-a_librarys_declared_types | 23682 | 23578 | -104 | point |
| ch10/01-he_error | 10359 | 10142 | -217 | point |
| ch10/02-throwing_and_tracing | 17434 | 15920 | -1514 | point |
| ch11/01-python | 16239 | 14978 | -1261 | point |
| ch11/02-python_booleans | 8456 | 8429 | -27 | point |
| ch11/03-python_import | 2420 | 2402 | -18 | point |
| ch11/05-py_numpy | 5022 | 4994 | -28 | point |
| ch11/06-door_combinations | 49833 | 48399 | -1434 | point |
| ch11/09-compiled_structural_vocabulary | 14239 | 12956 | -1283 | point |
| ch11/10-torch-library-surface | 144949 | 144795 | -154 | point |
| ch12/01-he_assert | 18723 | 17288 | -1435 | point |
| ch12/02-he_equalreduct | 3369 | 3348 | -21 | point |
| ch12/03-assertion_difference | 9592 | 8343 | -1249 | point |
| ch12/04-assert_answers | 10811 | 9554 | -1257 | point |
| ch14/01-time_and_pragmas | 49579 | 48065 | -1514 | point |
| ch14/03-the_clock_and_the_command_line | 21863 | 21614 | -249 | point |
| ch15/01-mutex_and_transaction | 17033 | 16860 | -173 | empirical |
| ch15/02-state | 3167 | 3111 | -56 | point |
| ch15/03-pre_add_hooks | 8767 | 7521 | -1246 | point |
| ch15/04-admission_pools | 31956 | 30509 | -1447 | point |
| ch15/05-post_add_hooks | 12963 | 11687 | -1276 | point |
| ch16/01-event_catalog | 2544 | 1318 | -1226 | point |
| ch17/01-thread_lib | 312211 | 295437 | -16774 | empirical |
| ch17/02-thread_linda | 134883 | 133407 | -1476 | empirical |
| ch17/03-hyperpose_primes | 17957 | 16569 | -1388 | point |
| ch17/04-thin_forms | 31376 | 29828 | -1548 | point |
| ch17/05-channels_pools_and_the_machine | 96324 | 94647 | -1677 | empirical |
| ch17/06-the_prolog_rung_under_lib_thread | 122942 | 121093 | -1849 | empirical |
| ch18/18-01/01-scale | 29219170 | 29217933 | -1237 | point |
| ch18/18-01/02-holbenchmark | 34137375 | 34135968 | -1407 | point |
| ch18/18-01/03-superpose_primes | 636749 | 635360 | -1389 | point |
| ch18/18-01/04-peanofast | 104576 | 103021 | -1555 | point |
| ch18/18-01/05-matespacefast | 84422984 | 84421742 | -1242 | point |
| ch18/18-01/06-a-gap-query-and-its-index | 67328 | 66076 | -1252 | point |
| ch18/18-02/01-memo_multi_answer | 23257 | 21998 | -1259 | point |
| ch18/18-02/02-memo_aggregate | 26605 | 25335 | -1270 | point |
| ch18/18-02/03-memo_per_arity | 30116 | 28818 | -1298 | point |
| ch18/18-02/04-memo_same_name_multi_arity | 32805 | 31481 | -1324 | point |
| ch18/18-02/05-memo_variant_nonground | 21065 | 20888 | -177 | point |
| ch18/18-02/06-memo_dependency_invalidation | 23344 | 22105 | -1239 | point |
| ch18/18-02/07-memo_spaces | 35580 | 34231 | -1349 | point |
| ch18/18-02/08-memo_stats | 25756 | 24514 | -1242 | point |
| ch18/18-02/09-tabling_fib | 50837 | 49601 | -1236 | point |
| ch18/18-02/10-tabling_equation_change | 27473 | 26188 | -1285 | point |
| ch18/18-02/11-tabling_space_write | 36173 | 34760 | -1413 | point |
| ch18/18-02/12-tabling_statistics | 33676 | 32260 | -1416 | point |
| ch18/18-02/17-memo_controls | 31518 | 30112 | -1406 | point |
| ch18/18-02/18-tabling_doors | 62074 | 60562 | -1512 | point |
| ch19/19-01/01-inherited_spaces | 1757 | 1754 | -3 | point |
| ch19/19-01/02-restricted_spaces | 53151 | 51916 | -1235 | point |
| ch19/19-01/03-parametric_spaces | 5098 | 5089 | -9 | point |
| ch19/19-01/04-super | 12358 | 11102 | -1256 | point |
| ch19/19-01/05-evalc | 13889 | 12607 | -1282 | point |
| ch19/19-01/06-a-shared-space-on-redis | 11910 | 12054 | 144 | capability absent |
| ch19/19-02/01-c_space | 40926 | 40911 | -15 | point |
| ch19/19-03/01-c_extension | 26993 | 26972 | -21 | point |
| ch19/19-03/02-handle | 33696 | 32425 | -1271 | point |
| ch19/19-04/01-mm2-operators | 50368 | 48884 | -1484 | point |
| ch20/20-01/01-translatorrule | 7933 | 6691 | -1242 | point |
| ch20/20-01/02-translatorrule_direction | 17938 | 16673 | -1265 | point |
| ch20/20-01/03-translatorrule_guard | 19956 | 18672 | -1284 | point |
| ch20/20-01/04-translatorrule_cost | 13529 | 12119 | -1410 | point |
| ch20/20-01/05-translatorrule_for | 8017 | 6624 | -1393 | point |
| ch20/20-01/06-translatorrule_fib | 16259 | 14866 | -1393 | point |
| ch20/20-01/07-translatorrule_refusal | 6701 | 5464 | -1237 | point |
| ch20/20-01/08-derived_forms | 10272 | 8867 | -1405 | point |
| ch20/20-02/01-callquoteevalreduce | 70102 | 68851 | -1251 | point |
| ch20/20-02/02-callquoteevalreduce2 | 44198 | 42961 | -1237 | point |
| ch20/20-02/03-myinterpreter | 7134 | 5903 | -1231 | point |
| ch20/20-02/04-minimal_metta | 185105 | 183595 | -1510 | point |
| ch20/20-02/05-he_minimalmetta | 28990631 | 28989399 | -1232 | point |
| ch20/20-02/06-he_evaluation | 5928 | 4666 | -1262 | point |
| ch20/20-02/07-he_quoting | 3444 | 3420 | -24 | point |
| ch20/20-02/08-he_atomspace | 4316 | 4296 | -20 | point |
| ch20/20-02/09-he_types | 9292 | 9151 | -141 | point |
| ch20/20-02/10-he_math | 6561 | 6267 | -294 | point |
| ch20/20-02/12-interpret_and_metta_thread | 31185 | 29899 | -1286 | point |
| ch20/20-02/13-strategy_internals | 402016 | 400713 | -1303 | point |
| ch20/20-03/01-translatepredicate | 780 | 778 | -2 | point |
| ch20/20-03/03-foreign_rules | 26388 | 25143 | -1245 | point |
| ch20/20-03/04-registering_prolog_predicates | 30445 | 29102 | -1343 | point |
| ch20/20-03/05-the-module-doors | 74349 | 72917 | -1432 | point |
| ch20/20-04/01-import_order_independence | 6625 | 6599 | -26 | point |
| ch20/20-04/02-import_relative_nested | 8271 | 8231 | -40 | point |
| ch20/20-04/03-import_duplicate_cycle | 8336 | 8251 | -85 | point |
| ch20/20-04/04-import_error_surface | 4276 | 4265 | -11 | point |
| ch20/20-04/05-import_space_identity | 19774 | 19501 | -273 | point |
| ch20/20-04/06-git_import | 24590 | 26048 | 1458 | empirical |
| ch20/20-04/08-catalog | 3038 | 3033 | -5 | point |
| ch20/20-04/09-carrier_vocabulary | 327 | 327 | 0 | point |
| ch20/20-04/10-include | 5336 | 5257 | -79 | point |
| ch20/20-06/05-seeking-and-sizing | 31775 | 31243 | -532 | point |
| ch20/20-07/01-reader-tokens | 8088 | 7970 | -118 | point |
| ch22/22-01/01-logicprog | 8995 | 8992 | -3 | point |
| ch22/22-01/02-logicprogset | 4685 | 4682 | -3 | point |
| ch22/22-01/03-constructive_negation | 90482 | 88602 | -1880 | point |
| ch22/22-01/04-nilbc | 302970762 | 302969340 | -1422 | point |
| ch22/22-01/05-scallop_readme | 84110 | 82648 | -1462 | point |
| ch22/22-01/06-case-duals | 10228 | 8985 | -1243 | point |
| ch22/22-02/01-measure | 130488 | 129150 | -1338 | empirical |
| ch22/22-02/02-soft | 292403 | 292091 | -312 | point |
| ch22/22-02/03-plntest | 42734 | 41498 | -1236 | point |
| ch22/22-02/04-plntestdirect | 47605 | 46370 | -1235 | point |
| ch22/22-02/06-pln_roman | 2253902 | 2252589 | -1313 | point |
| ch22/22-02/09-nars_tuffy | 4699583 | 4699576 | -7 | point |
| ch22/22-02/13-the_measure_algebra_underneath | 44693 | 44614 | -79 | point |
| ch22/22-02/14-soft_aggregation_underneath | 125553 | 125479 | -74 | point |
| ch22/22-02/15-independent_supports | 17992 | 16719 | -1273 | point |
| ch22/22-02/16-nars_truth_functions | 122789 | 122495 | -294 | point |
| ch22/22-02/17-nars_derivation_control | 244639 | 244506 | -133 | point |
| ch22/22-02/18-pln_formulas | 178890 | 178488 | -402 | point |
| ch22/22-02/19-pln_derivation_control | 346305 | 346095 | -210 | point |
| ch22/22-03/01-newtons_method | 45192 | 43950 | -1242 | point |
| ch22/22-03/02-tilepuzzle | 31322926 | 31321694 | -1232 | point |
| ch22/22-03/03-matespace | 24121538 | 24119985 | -1553 | point |
| ch22/22-03/04-matespace2 | 39647822 | 39646418 | -1404 | point |
| ch22/22-03/05-fibadd | 31833 | 30605 | -1228 | point |

## 2026-09-10 provenance coverage and interrupted point update

The provenance preflight found `extensions/python/tools/binding_source.pl`
outside the evidence gate's globs. The new source parser is the Prolog half
of the binding checker, so `tests/checks/check_evidence_tags.py` now includes
`extensions/python/tools/*.pl` beside its Python tools pattern. The same
`pin_provenance.scan()` and `unscanned()` pass now finds its claim and reports
no unscanned files. This one-line consumer edit makes the new helper subject
to the existing evidence and provenance gates.

The point updater was interrupted after 542 observations. Its first 180
rows each have three complete samples and a point-only source change. The
two samples for the next row did not produce a pin. The resumed updater
starts every remaining row with three fresh processes. The current selection
contains 257 measured point rows and excludes the unavailable Redis provider;
77 remain after the preserved 180-row checkpoint. The earlier scratch count
of 256 is superseded by this source and receipt audit. No allowance, empirical
envelope, workload or stored-content declaration changed in those 180 rows.

Compilation-ownership clarification for the table above:
`provides_engine_user.pl` is included for the engine audience in `user`;
`provides_host_metta_python_bounds.pl` is included inside
`metta_python_bounds`, whose transaction listener state it serves. Neither
projection changes the source template's audience or defining module.

The C-store comparison requires its built provider artifact. Sixteen controls
with that artifact read 40,911 inferences and sixteen controls forcing only
the local missing-artifact branch read 30,004. Only 40,911 prices the provider
workload. The completed normal and fixed-cache lanes both exercise that path.

The evidence lane now plants a Prolog tool with one backed claim and one
absent test. Removing the new pattern from the copied checker makes the
cell fail with `Prolog tools must report only their planted absent test: []`;
with the pattern, only the absent test is reported on line 4. The complete
`python tests/checks/check_evidence_selftest.py` returns zero defects over
its 36 citation cases and all additional controls. Ruff passes for both
evidence files. The integrator reserved this pattern and requested the cell;
the checker has no other edit.

The fresh cut instruction gate again reads sort-atom below its old pin:
4,001,622,090 minimum. The binding's earlier 4,095,266,971 is inside that
unchanged pin but 2.34% above this cut observation. A private control keeps
the workload unchanged and calls the existing controlled window through one
common launcher. Cold minima are cut 4,102,460,428 and binding 4,095,033,845;
after one unmeasured identical sort they are 3,832,582,952 and 3,835,089,194.
Thus the cut's own cold count moves by more than the observed branch
difference when only its launch setup changes, while the common warmed
control differs by 0.065%. The ordinary inference counts remain cut
1,301,595 and binding 1,301,592.

The diagnostic first sort in both trees causes one native collection,
three global shifts and five local shifts. Its collected and retained byte
counts differ; subsequent identical sorts encounter different heap states.
These observations establish sensitivity to initialization, not a unique
causal assignment of the entire instruction difference to one GC event.
The existing `benchmarks/pure.py` warm-up policy and the 2026-09-08 waiver
journal record related large-term effects. No workload, warm-up policy or
instruction pin is changed here. Keep the original before/after instruction
table and these controls together. Receipts are
`ai-binding-sort-{cut,current}-control.jsonl`, produced by the same scratch
driver with three fresh controlled samples per arm; both exit zero.

The resumed official twin updater completed the remaining 77 rows, exit zero.
The combined audit reads 771 valid samples for 257 updated points and discards
the two incomplete samples from the interrupted process. Every point equals
its minimum of three and decreases. All 277 twin ASTs are unchanged apart
from `BUDGET`; all seven empirical dictionaries are unchanged.
The C-store's three provider samples are all 40,911. Measurement comments
retain the normalization, mechanism and `commit=WORKTREE` provenance token.
The audit is `ai-binding-audit-repins.py`; its full result is
`ai-binding-repin-audit.json`. No stored-content declaration changed.

The pristine cut's complete required aggregate command finished with exit 1:
`engine-bench`, `benchmarks`, `instructions`, `extcost` and `llms` fail.
The remaining selected gates pass, including all 18 generated artifacts and
their selftests. The five cheat-sheet findings are in the unchanged Node
sheet at lines 308-310: `browser/`, two `_runtime/` mentions, `runtime.json`
and `wasm/` name absent build outputs. The control worktree remains clean.
The raw receipt is `ai-binding-cut-landing-gates.log`; the committed binding
tree will be checked with the same command and compared row by row.

## 2026-09-10 committed checks and cost-consumer repairs

The first functional/provenance pair passed `sh engine/test.sh`: 97 suite
summaries, 2,568 tests and 1,510 sub-tests. The whole Python suite reported
3 failures, 5,484 passes and 75 skips in 478.35 seconds. The browser-kit
refusal is the cut's existing `ERR_MODULE_NOT_FOUND` failure. Two failures
belong to this change: the extension table retained 12.00 for raw operations
after its pin moved to 11.00, and three new measurement comments cited an
absolute workspace path. Both have been corrected at their consumers.

The evidence lane also rejected the crossover's undated measurement and the
projection probe's self-citation as a test. The dated crossover retains its
2026-09-09 samples. The probe now states the check it actually makes, both
decoders' first answer against the fixture before sampling, with source
evidence naming `query_projection.py:main`. The evidence checker is unchanged
apart from its separately reserved Prolog-tools pattern.

The extension table's three current marginal points are raw 11, encoded 19
and unannotated define 27. Its timing columns retain the dated 2026-09-06
run and are labeled accordingly. The write table retains the committed
30/47/59/67 points owned by the performance package; the measured
36/53/65/73 write costs remain an explicit cut-reproduced gate failure.
The argument-size rows now use the actual 200-call harness output:
19/11, 30/11, 54/11, 150/11, 62/11 and 102/11 for encoded/raw. The axis test
derives the raw marginal point from the existing driver and operation pins
and retains its one-inference tolerance and every complexity assertion.
`benchmarks/extension_cost.py` gains only the corrected 27-versus-3 header
claim. These two additional cost consumers are necessary out-of-package edits.

Fresh `cd extensions/python && python -m benchmarks.axes` controls in the
cut and binding trees both exit zero. Instruction columns are min-of-three
fresh processes; inference columns use their own fresh process. Direction
uses 20,000 crossings; value images use 2,000. The measured instruction
increase on the engine-out and opaque rows is retained alongside the
inference reduction, not inferred from the latter.

| Axis | Cut instructions | Binding instructions | Cut inferences | Binding inferences |
|---|---:|---:|---:|---:|
| Engine calls out | 23,483.3 | 34,745.7 | 12.02 | 11.02 |
| Host drives a built term | 154,367.6 | 154,698.1 | 137.03 | 134.03 |
| Host drives text | 154,090.6 | 154,862.0 | 135.03 | 132.03 |
| Transparent, 1 element | 78,192.0 | 89,154.0 | 22.16 | 21.16 |
| Transparent, 10 elements | 177,479.0 | 187,193.9 | 58.16 | 57.16 |
| Transparent, 100 elements | 1,159,108.9 | 1,170,053.4 | 418.16 | 417.16 |
| Transparent, 1,000 elements | 11,432,224.4 | 11,311,099.6 | 4,018.16 | 4,017.16 |
| Opaque, 1 element | 27,896.4 | 38,546.9 | 12.16 | 11.16 |
| Opaque, 10 elements | 27,791.4 | 38,519.6 | 12.16 | 11.16 |
| Opaque, 100 elements | 27,736.2 | 38,556.2 | 12.16 | 11.16 |
| Opaque, 1,000 elements | 27,598.4 | 38,768.7 | 12.16 | 11.16 |

The first complete twin gate reported 36 findings. Two point rows were
missed by the earlier selection because that selection compared against the
cut, not their older committed pins: string reads 174 versus cut 177 and pin
179; collapse reads 266 versus cut 269 and pin 271. They require the same
official three-sample repin as the other points, with the three-inference
fixed setup reduction recorded. Twelve declared overruns are now unnecessary
because the collapsed binding's cost falls below the unextended ceiling.
Their declarations and explanatory overrun paragraphs are removed. The
historical point-repin paragraphs mixed into the assert twin's overrun
comment run are retained. Removing these allowances strengthens the gate;
the program bodies, assertions, stored-content declarations and all seven
empirical dictionaries remain unchanged.

Default-cache observations also produced point excursions during the full
gate. The existing scratch launch applies the validated maximum cache age
before boot and now runs the actual complete gate judgment, in addition to
the earlier successful program-only controls. The tracked harness remains
PERF's. Empirical observations retain their original declarations for that
owner's merged-tree re-observation.

The normalized full gate completes all 277 twin programs with only five
findings: mutex 16,858, thread_linda 133,407, channels/pools 94,647, the
Prolog thread rung 120,790 and measure 129,117 are below their unchanged
empirical envelopes. There are no point, overrun or stored-content findings.
All twelve removed overrun declarations remain unnecessary under the fixed
cache policy. The two final point rows have samples 174/174/174 and
266/266/266. The final AST and receipt audit verifies 259 decreased points,
777 full samples, two discarded partial samples, twelve removed overruns
and seven unchanged empirical dictionaries. The raw default-cache gate is
retained separately; its first-use point excursions disappear in this run.

The cost-consumer and required context-capture tests pass six cases in
93.61 seconds. The evidence gate reports zero unbacked claims in 7,172
claims after the source/date repairs. Its ten current worktree placeholders
will be resolved with all earlier placeholders in the replacement landing
pair. An ad hoc Ruff command included the normally excluded benchmark
directory. Six extension-cost findings reproduce in the cut: D205 twice,
D209, ARG001 twice and D103. The new probe's unused E402 suppression is
removed; the other three selected files pass Ruff. The official Ruff lane
retains its established scope.

The raw-callback instruction increase is real in a controlled window as
well. `ai-binding-dispatch-layers.py` compares 20,000 calls per sample, three
fresh processes per layer and tree, with one identical warm-up outside the
window. Both commands exit zero. Each row includes the layers beneath it:

| Raw callback layer | Cut instructions/call | Binding instructions/call |
|---|---:|---:|
| Python dispatcher only | 6,273.88 | 7,031.89 |
| Janus call including Python | 19,590.40 | 28,950.65 |
| Native dispatcher including Janus | 23,590.12 | 34,424.81 |

The increase decomposes into about 758 instructions in Python selection,
8,602 between the Python and Janus boundaries, and 1,474 in the native
dispatcher. The shared entry passes its key, context and error mode where
the old raw entry passed only name and payload; Janus converts the additional
values on each crossing. The conversion contract is documented in
[Janus data conversion](https://www.swi-prolog.org/pldoc/man?section=janus-data)
and [py_call/2](https://www.swi-prolog.org/pldoc/man?predicate=py_call%2F2).
The required inference price improves from 12 to 11 per call, but that does
not establish an instruction improvement. Retain this constant cost in the
before/after tables. Reintroducing a family of specialized entry functions
would reverse the requested collapse; no such family or new resource cache
is introduced. The fifteen required instruction rows retain their existing
bands and their separately reported cut attributions.

## 2026-09-10: transfer bound watches before native query destruction

PERF's receipts investigation exposed the same pre-existing ownership defect
in the Python limit mirror. The child command
`python ai-tmp/ai-binding-bound-frame-probe.py <tree>` boots the seat, adds
`(limit display-rows 7)` inside a native transaction, completes it, yields the
engine and destroys it. Both the pristine cut and the binding exit by
SIGABRT, subprocess return code -6, before answering the query. The exact
native error is `./src/pl-wam.c:2904: PL_open_query: Assertion failed:
(void*)fli_context > (void*)environment_frame`; crash reporting subsequently
raises `./src/pl-trace.c:107: PL_put_frame: Assertion failed: fr >= lBase &&
fr < lTop`. The raw receipts are `ai-binding-bound-frame-{cut,branch}.log`.
Core dumps are disabled in those children; no runtime deadline is imposed.

The old ancestor walk examines the native engine's outer query frame.
`prolog_frame_attribute/3` marks each examined frame for `frame_finished`,
including that query frame, and `PL_close_query` closes its foreign frame
before discarding the query. Reentering the listener then violates SWI's
foreign-frame ordering. Source: SWI V10.1.13
[`pl-trace.c:2484-2503`](https://github.com/SWI-Prolog/swipl-devel/blob/V10.1.13/src/pl-trace.c#L2484-L2503)
and [`pl-wam.c:3052-3064`](https://github.com/SWI-Prolog/swipl-devel/blob/V10.1.13/src/pl-wam.c#L3052-L3064).
On failure, `frameFailed` also makes the finishing frame the current
environment, so a callback's ancestry walk must exclude that frame ID.
Source: [`pl-wam.c:902-916`](https://github.com/SWI-Prolog/swipl-devel/blob/V10.1.13/src/pl-wam.c#L902-L916).

The transfer design follows PERF's `metta_receipt_watch_transaction/2` and
`metta_receipt_nearest_frame/3`: a first bound write watches the nearest live
transaction. Its completion transfers the same mirror suspension to the
remaining transaction, excluding the finished ID. Only outer completion
retires the marker and calls Python's finish callback. The standing listener
remains installed. A nearest-only watch would release the mirror at inner
completion and admit a stale fill before outer rollback.

The disposable candidate changes only the bounds predicates. It makes both
original crash controls exit zero, with value 7 and an empty pending set.
The full candidate matrix passes all 20 cut/branch cases: nested depths 1..4,
inner failure and exception rollback followed by another write, and outer
transaction/1, transaction/2, transaction/3 and snapshot/1. At every live
checkpoint Python reads the correct row and cannot fill the mirror; every
case records exactly one start and one finish, resumes cache fills afterwards,
and safely destroys the yielded engine. Receipt:
`ai-binding-bound-frame-transfer-matrix.json`.

The delivered witness is sensitive to both parts of the repair. Its original
outer walk aborts with return code -6. A nearest watch without ownership
transfer fails the nested case with `AssertionError` on the native result;
transfer without finished-ID exclusion fails the inner-failure case at the
same assertion. Receipts:
`ai-binding-bound-frame-{original,no-transfer,no-exclusion}.json`.

No engine receipts code changes in this package. The bounds module keeps its
private helpers and its existing callback owners. The source, regression,
CHANGELOG and this record will land together after the active transactional
artifact gates restore their guarded files.

## 2026-09-10: preserve a newly observed fuel-policy failure

The second committed whole Python gate at e0e275ff4 returns two failures,
5,485 passes and 75 skips in 627.17 seconds, seed 3461229234. The browser-kit
proof is the cut failure. The new batch/fuel witness raises
`InferenceLimitError: the 10000 inference limit was reached` on its scalar
arm, which expects a fuel overflow answer. Its quota remains 10,000.

Controls have not reproduced that failure. The 27-test binding evaluation
file passes at the same seed; collecting the entire suite but selecting only
the failing test also passes. Fresh scalar first calls cost 2,083 on the cut
and 2,075 on the binding, with repeated calls 309 and 301. Loading memo,
tabling and thread libraries separately and together leaves both trees green.
Adding 10,000 unrelated rows or 1,000 unrelated equations also leaves both
green. Those controls reject simple corpus-size and library-presence causes.
A scratch observer records the fuel/context state and deferred function
around the unchanged call, replays a failed fueled call at the same quota,
and reraises the original failure. Its focused check passes. The whole-suite
reproduction remains to run; no test or runtime repair is inferred yet.

The native boot baseline failure was also present in the earlier committed
aggregate; the native lane has five failures, not the four in the earlier
working summary. Its cut/current readings were 296,767 and 296,740, both
below the unchanged 301,230 pin. A cut control replacing only context
push/pop does not explain the difference. After deleting engine/lib QLFs
and warming the official boot case, the original, replacement and restored
clauses all measure 296,761 three times. The cut is restored and clean.
Receipts: `../wt-bindctl/ai-tmp/ai-binding-native-boot-fresh-{cut,context,restored}.log`.
The six-inference change in the cut observation and the remaining difference
are retained as fixture observations, not assigned to context cleanup.

## 2026-09-10: count independent native owners on one Python thread

An additional composition control runs one native engine's transaction
inside another engine's transaction on the same Python thread. The inner
engine completes, yields and is destroyed before the outer completes. With
the corrected native watch and the original Python set, inner completion
removes the shared thread-ID entry; outer completion raises
`error(python_error('KeyError',...),context(_,python_stack(...)))`.
`ai-binding-bound-engine-owners-corrected.json` retains the exact exception.

The mirror owns pending transactions, whose count per Python thread can
exceed one. A set discarded that multiplicity. Replace it with positive
counts under the existing mirror lock; a finish decrements its thread's
count and only the last finish removes the key. The hot read still checks
only whether any owner remains. Callback signatures, the native marker and
the single-owner behavior are unchanged. This consumer repair belongs in
`metta/_catalog/bounds.py`; the existing simultaneous-writer test checks the
set of pending threads, independent of that internal representation.

The complete disposable design passes all 26 cut/branch cases. The new
three cells cover overlapping native engines followed by outer commit,
failure or exception rollback. They verify that the inner independent
transaction's committed chunk limit remains 8, the outer display limit is
committed or discarded correctly, the mirror cannot fill before outer
completion, and two starts receive two finishes. Restoring the old set
makes the same behavioral assertion fail after inner completion, before
outer cleanup. Receipt: `ai-binding-bound-frame-owner-matrix.json`.
The watcher and counted mirror will be implemented together with these
13 permanent subprocess cells. No source in PERF's receipts changes.

The implemented watcher and counted mirror pass the 59-test configuration,
native-frame and binding-evaluation cohort in 73.76 seconds. The binding
drift gate and all 77 mutation tests pass in 74.96 seconds; Ruff, mypy and
evidence also pass, with zero unbacked claims. Receipts:
`ai-binding-bound-frames-{focused,static}.log`, both exit zero.
The clone check over the binding, the Python mirror and the new regression
finds only the existing seven-line Runtime refusal-decoration clone:
11 files, 5,045 tool lines, one clone. Command: `npx --yes jscpd --format
python --min-lines 5 --min-tokens 50 --reporters console,json --output
ai-tmp/ai-binding-bound-clones --ignore '**/options.py,**/__pycache__/**'
extensions/python/metta/_binding extensions/python/metta/_catalog/bounds.py
extensions/python/tests/ch01_getting_started/test_bound_transaction_frames.py`.
No new extraction is justified by that result.

## 2026-09-10: distinguish compilation work from the fuel-policy witness

The same-seed whole-suite observer reproduces the failure: two failures,
5,498 passes and 75 skips in 668.15 seconds. Immediately before the failing
call, fuel is closed/off, the evaluation context is absent and the pragma
is 20. The first call exhausts its unchanged 10,000 inference quota; the
same call then returns `(Error 18 StackOverflow)` at that quota. The deferred
row disappears during the first call. Receipt:
`ai-binding-fuel-runtime-645378.jsonl`. This supersedes the open attribution
in the earlier section, not its recorded observations.

Sixty-four already compiled recursive functions reproduce the cold failure
on both the cut and binding. Thirty-two leave the binding cold call at
8,284 inferences; 64 exceed 10,000. Ordinary facts and non-recursive
equations did not reproduce it because the cost depends on the recursive
graph, not total source rows. Explicitly forcing the new function outside
the execution measurement costs 14,217 inferences with diagnostic wrappers.
Of that, `announce_function_call_graph_changed/2` takes 12,987. A second
decomposition records `memo_automatic_module_plan/2` at 11,836 and
`memo_automatic_apply_plan/2` at 364; the observer itself adds calls, so these
are attribution counts, not replacement performance pins. Receipts:
`ai-binding-fuel-recursive-{32-current,64-current,64-cut,64-no-memo}.log`,
`ai-binding-fuel-force-components.log`, `ai-binding-fuel-graph-components.log`.

The first force announces a changed compiled call graph; lib_memo reconciles
its recursive components before the first execution. That work belongs to
the caller's inference limit. SWI counts predicate calls and redos within
the bounded goal, including compilation and observers; see
[call_with_inference_limit/3](https://www.swi-prolog.org/pldoc/man?predicate=call_with_inference_limit%2F3).
Diagnostic wrappers follow its
[wrap_predicate/4 contract](https://www.swi-prolog.org/pldoc/man?predicate=wrap_predicate%2F4).
The binding therefore preserves the cut's behavior. The test incorrectly
assumed that its first compilation always fitted under 10,000 after other
tests populated the worker's recursive graph.

Decided: explicitly prepare `binding-spin` before the existing execution
policy comparison and retain every 10,000 quota and answer assertion. Add a
separate cold-call witness whose real compilation event performs 20,000
iterations, so the limit must fire independently of corpus state. Retrying
the compiled function must then return StackOverflow under the same quota.
The observer is removed and the pragma restored on every exit; its private
world is released. Both cut and binding pass that control. Moving the force
outside the bounded call makes the witness fail with `AssertionError:
deferred compilation escaped the evaluation's inference budget`. Receipts:
`ai-binding-fuel-boundary-{current,cut,negative}-corrected.log`.

Rejected: increasing the inference quota, changing the recursive body,
accepting either result, or moving runtime compilation outside its quota.
Each would hide the distinction between legitimate first-use work and
the fuel policy the original witness intends to test. No engine or memo
runtime change is required. The initial diagnostic mistakenly sent query
text to `Runtime.do_must`, which takes a predicate name; `Runtime.must`
corrects that probe. Its failed receipts remain retained.

The final bound-row control also passes at the cut and binding. Both read
arms cost 51 inferences per match. Writes cost 43.02 in &metta, 33.02 in
&self and 394.07 per equation. Thus the frame repair leaves ordinary read
and write inference costs unchanged. Command: `python
extensions/python/benchmarks/probes/bound_row_cost.py --read --write`;
receipts `ai-binding-bound-cost-final.log` and the control's
`ai-binding-bound-cost-cut.log`, both exit zero. The binding now contains
12,830 physical lines across its 55 files; the original 44 contained 12,417.

Verification: the completed boundary cohort passes all 64 tests in 72.70
seconds at seed 3461229234: evaluation, the four concurrent counter
regressions, native transaction frames and configuration. Ruff passes and
the evidence lane reports zero unbacked claims across 7,176 claims and
12,605 known test names. Receipts:
`ai-binding-final-boundaries-{focused,static}.log`, both exit zero.

## 2026-09-10: count every native test summary

The native totals in "committed checks and cost-consumer repairs" omitted
the line containing `12 (+2,052 sub-tests)`: the scratch parser did not accept
the thousands separator. Re-reading `ai-binding-committed-engine.log`,
`ai-binding-final-committed-engine.log` and `ai-binding-landing-engine.log`
with that separator handled gives 98 passing summaries, 2,580 tests and
3,562 sub-tests in every run. The earlier 97/2,568/1,510 totals are superseded;
this is a reporting correction, not an additional test or changed result.

The committed 401883f78 runtime passes 5,500 Python tests with 75 skips at
seed 3461229234 in 488.19 seconds. Its only failure is the cut's browser-kit
refusal proof. Both fuel-policy witnesses and all counter and native-frame
regressions pass. Receipt: `ai-binding-landing-python.log`.

## 2026-09-10: locate the bounds boot's catalog-arity price changes

The committed normalized lane exposed 142 points five inferences below their
pins, several other five-inference multiples, and two scheduling point twins.
The earlier complete boundary tests passed because they hold the operation
costs after boot; a first open-width catalog lookup was the moving part.

Tried: swap only `_binding/bounds.pl` to its pre-repair source and restore it,
with three fresh processes per twin in each arm. Comments reads
1,157/1,162/1,157; the string control stays 174; event catalog reads
1,323/1,318/1,323; catalog reads 3,048/3,033/3,048. Every arm's three samples
are identical. No Python, engine or library source changes in this control.
Command: `python ai-tmp/ai-binding-bound-layout.py`; receipt
`ai-binding-bound-layout.jsonl`, exit zero, tracked source restored exactly.

Native call-site coverage locates every difference in
`spaces:metta_catalog_clause/2` at its open-width branch. Its
`current_predicate(Module:'&metta'/N)` returns the same arities in different
orders after the bounds helper changes the boot's predicate set. Comments
visits 32 versus 33 arities, event catalog six versus five, and catalog
118 versus 115. Each visit calls `current_predicate/1`, `>=/2`, `functor/3`,
`metta_storage_term/4` and `clause/3`, accounting for -5, +5 and +15 exactly.
Every other covered call site has the same entry and exit counts. The
coverage observer changes absolute totals, so the uninstrumented arm above
remains the price authority. Command: `python
ai-tmp/ai-binding-bound-layout-cov.py`; receipt
`ai-binding-bound-layout-cov.jsonl`, exit zero.

This makes the earlier journal's "load-structure movement" class precise.
SWI's partially specified `current_predicate/1` enumerates its procedure hash
table with `newTableEnumWP` and `advanceTableEnum`; it does not order arities
[source](https://github.com/SWI-Prolog/swipl-devel/blob/V10.1.13/src/pl-proc.c#L937-L1143).
The lookup's implementation and successful answers are unchanged. Its first
successful arity now occupies a different position in that enumeration.
Do not attribute the difference to heartbeat accounting or a new bounds
callback in the measured window: neither appears in the coverage delta.

Decided: retain the necessary frame-safety repair and measure the final
points through the official three-sample updater. Keep every point allowance
and empirical dictionary unchanged. No catalog implementation change is
required for this binding repair, and that file belongs to the import work.
The frame transfer and owner-count regressions remain the behavioral gate.

## 2026-09-10: close the bounds counter controls

The official updater completed all 269 capable point rows with three fresh
samples each. An interruption left 94 completed updater receipts; those were
verified and retained, and only the unfinished rows were resumed. Thirty-seven
unfinished samples were retained separately and excluded. All 807 completed
samples have successful workloads and unchanged stored-content declarations.
The final audit checks all 277 program ASTs and all seven empirical dictionaries.
Only point metadata and the twelve already-obsolete overruns differ from the
cut. Receipts: `ai-binding-bound-repin/{before,results}.json`, the directory's
269 JSONL files, and `ai-binding-bound-repin-audit.json`.

The inherited-spaces point moves 1,757 to 1,749: its earlier complete-lane
reading was already 1,754, three below that pin, and the bounds change removes
five more. Hyperpose's three samples are 16,563/16,565/16,563. A separate
32-worker control reads 17,955..17,959 at the cut and 16,560..16,565 here;
its existing four-inference allowance around the measured 16,563 contains
every current observation. This is the scheduler variation already carried
by that point, beside the boot lookup's movement.

Thin forms initially reads 29,823 three times, four below the old 29,827
point, so the official updater correctly leaves it standing. The same
32-worker control reads 31,372..31,376 at the cut and 29,819..29,823 here.
The four-inference spread is unchanged, but the old point misses its lower
readings after the bounds change. An official 32-round serial remeasurement
reads fifteen 29,822, fifteen 29,823, one 29,820 and one 29,819. It pins
29,819, retaining the four-inference allowance and the entire workload.
Commands: `python ai-tmp/ai-binding-thread-envelope-control.py
03-hyperpose_primes.py 04-thin_forms.py` and `python
ai-tmp/ai-binding-thin-repin.py`, both exit zero. No empirical envelope changes.

The combined audit retains 1,616 complete samples across the original and
final point passes, and excludes 39 interrupted samples across both runs.
There are 260 net point changes against the cut, all decreases except the
catalog twin's 3,038 to 3,048. Its net +10 is the earlier -5 collapse plus
the +15 open-arity lookup movement established above. There are 152 point
moves after the bounds repair. Every rationale names the measured owner;
no allowance or stored-content declaration is loosened.

The final canonical 96-process fixed-cache control is exact at workers=32:
32 samples each read memo 24,509, Fibonacci 49,601 and table-write 34,755.
Command: `python ai-tmp/ai-binding-counter-final96.py`, exit zero. The three
library artifacts are prepared before measurement, and every fresh child's
first import remains inside the window. This supersedes the earlier pre-bounds
24,514/49,601/34,760 readings. The permanent 226/229 and heartbeat assertions
are unchanged.

All 35 Python benchmark rows, the eight automatic-tabling cells and both
slope records match the earlier complete measurement exactly. All fourteen
extension rows also match. The benchmark driver returns one for the same ten
cut-reproduced pins; the extension observer returns one for the same four
cut-reproduced write pins. Receipts:
`ai-binding-bound-observations{.jsonl,-resumed.log}` and
`ai-binding-bound-extcost{.json,-resumed.log}`.

The last full lane's thread-lib reading of 351,165 also exceeds an empirical
envelope. A separate 32-worker cut/current control completes all 64 programs:
the cut spans 282,725..526,130, with two observations above its 313,661 upper
bound; binding spans 280,817..305,626. Thus the above-envelope event is
cut-reproduced. This cohort is an attribution control, not the full-lane
protocol from which an envelope may be derived. PERF retains that ownership.
Receipt: `ai-binding-thread-envelope-control.jsonl`, exit zero. The separate
pool-state assertion remains PERF's already-reproduced cached-result/join
and mixed-snapshot defect.

## 2026-09-10: unwind automatic memo reconciliation on an inference limit

The release Python cohort exposes two failures on one worker: the recursive
profile reads 928 recursive calls instead of zero, and the automatic
coefficient declaration is absent. A cut control sends a real inference
limit through reconciliation at every budget from 1 through 500. Budget 215
leaves `memo_automatic_reconciling/0` asserted. Executing both original Python
test bodies after that signal reproduces both failures; clearing only that
guard makes both pass. Both cut and binding have the defect. Receipts:
`ai-binding-release-memo-signal-cut.json` and
`ai-binding-release-memo-consequences-{cut,binding}.json`.

Decided: apply the trailed-marker rule already established in
`2026-09-07-every-intermittent-root-caused.md`. `nb_current/2` treats a missing
marker as false because the library can load after workers exist. Entry uses
`b_setval/2`, ordinary exit writes false with `nb_setval/2`, and exception
unwinding restores the previous state. There is no asserted guard or cleanup
registration to leak. The native regression sweeps through the first
completing budget with both unset and false initial states and proves the
next reconciliation actually publishes its plan. Python repeats the original
profile and occurrence assertions after real quota interruptions.

Rejected: asserting inside Goal and parking the reference non-backtrackably.
Cleanup runs after Goal's bindings have unwound, and the plain-SWI control
still leaks at budgets 3 through 8. The trailed state has no cleanup debt.
No other cleanup sites change, and the unsafe-reason clauses remain separate.

The permanent native regression fails on the cut and on the old binding:
the next reconciliation leaves both its dirty module and its stale decision.
The repaired memo suite passes 25 tests plus one sub-test. The context suite
passes 21 tests plus one sub-test, including the 1..2000 quota sweep. The
isolated memo sweep completes first at budget 214 in both initial states.
The two permanent Python regressions invoke the original test functions;
separate fresh cut processes fail at their original assertions, and binding
processes pass. The focused six-test Python cohort passes in 4.13 seconds.
Receipts: `ai-binding-memo-{before,after}-{native,python}.log`,
`ai-binding-memo-cut-native.log`, `ai-binding-memo-cut-current-python.json`,
and `ai-binding-memo-frontiers.log`.

A direct 1,000-call control reads 13,003 inferences for empty drains on both
trees and 221,003 at the cut versus 219,003 here when each drain has one
dirty empty module. The repair removes two inferences per reconciliation
with work and changes no empty-drain cost. The canonical 96-process control
at workers=32 reads 24,515/49,598/34,753, with 32 identical samples per twin.
The four permanent concurrent counter tests also pass. All fourteen extension
cost rows equal their previous measurements; the four stale write pins stay
red. Receipts: `ai-binding-memo-guard-{cut,current}.jsonl`,
`ai-binding-memo-counter96.jsonl`, `ai-binding-memo-counter-regression.log`
and `ai-binding-memo-extcost.json`.

## 2026-09-10: make each host workaround test its host

The required convention and its provenance pin were cherry-picked verbatim
from 2bd6b250a and 6558fb1d4. Their original evidence tags remain unchanged.
The discarded-frame entry, frozen plain-SWI reproduction and bounds site
were delivered separately in 5a1127efe0f575668061e8a24c59b8ab60e6122a; the
one-token provenance commit is 10ab9e644e6679868e8a41c210c62478cddd3a3d.
Other consumers reuse those bytes and add their own site lines.

The original engine command exits 139 after the host's own assertion and
then its crash reporter's segfault. Both plain-SWI reductions abort with
134 at `PL_open_query: Assertion failed: (void*)fli_context > (void*)environment_frame`.
The wrapper recognizes that exact assertion or exit 139, answers absent only
on zero, and leaves all other failures unclassified. Five wrapper controls
cover both present outcomes, absent, unrelated 134 and exit 3. The fixture
freezes the unsafe ancestor walk and loads no engine code. Calling the fixed
consumer would falsely announce an upstream repair, so that shape was rejected.
Receipts: `ai-binding-host-frame-{raw,plain,frozen}.log`, their exit files,
and `ai-binding-host-frame-verdicts.json`.

The Janus reproduction likewise loads only the affected Python Janus host.
Four fresh processes compare a primed default cache and a disabled cache:
1,281/1,507 inferences lazily, 8/8 with an explicit maplist import. A sixth-cell
diagnostic also reads 1,510 with flag -1. Zero bypasses the cache-hit and sweep
clauses and measures the uncached walk; it does not trigger expiry maintenance.
The separately installed system Janus resolves the import eagerly and reads
8 in all cells, so the Python package is the reproduction's explicit host.
The binding's existing 226/229 assertions are unchanged. Five ledger entries
and seven sites pass both host-workaround lanes, including ten planted cases.
The first evidence pass rejected the new measured tag's missing date;
adding its actual measurement date makes the evidence lane pass.

## 2026-09-10: hold Git-import fixture state equal

The earlier 24,590 cut observation and 26,048 binding observation used
different fixture states. Paired fresh processes with the source and clone
directories present read 26,074 at the cut and 26,048 here. Removing those
owned directories costs 1,498 on either tree. Starting without their parent
directories adds 14, giving 24,590 at the cut and 24,564 here. Thus the apparent
increase is 1,484 of fixture-state work minus a 26-inference binding saving.
All original directories are restored in finally blocks. The first parent
guard refused the extra empty `.lock` file before mutating anything; the
corrected guard includes that owner-created file. Receipts:
`ai-binding-release-git-fixture{,-state,-parents-corrected}.jsonl`.

## 2026-09-10: separate the memo marker's first and repeated costs

The post-repair full lane completes all 277 programs and exposes 143 stale
price findings before remeasurement. The 35 Python counter benchmarks retain
the same ten failing rows; only loop-1m moves, down two inferences. All fourteen
extension measurements are unchanged. These observations do not justify any
allowance change.

Tried: replace only `lib/lib_memo/lib_memo.pl` with its previous source, restore
the repair, repeat the old source, and restore the repair again. Warm library
artifacts before each arm. All 72 uninstrumented fresh processes agree within
their arm. Twelve additional native-coverage processes identify the changed
call sites. The original file is restored byte for byte. Command: `python
ai-tmp/ai-binding-memo-layout.py`, exit zero.

| Twin | Previous | Repaired | Dirty reconciliations | Arity visits changed | First unset-marker reads | Accounted delta |
|---|---:|---:|---:|---:|---:|---:|
| comments | 1157 | 1162 | 0 | +1 catalog | 0 | +5 |
| event catalog | 1323 | 1318 | 0 | -1 catalog | 0 | -5 |
| catalog | 3048 | 3033 | 0 | -3 catalog | 0 | -15 |
| memo stats | 24509 | 24515 | 1 | +1 catalog | 1 | -2 + 5 + 3 = +6 |
| tabling Fibonacci | 49601 | 49598 | 4 | 0 | 2 | -8 + 3 + 2 = -3 |
| tabling space write | 34755 | 34753 | 6 | +1 native match | 2 | -12 + 5 + 3 + 2 = -2 |

The removed thread-local predicate changes the same procedure enumeration
previously isolated for the bounds repair. Coverage gives catalog arity counts
32 to 33, 6 to 5 and 118 to 115 in the first three rows. The table-write row
instead visits one more arity in the partial-list arm of `get_native_atom/3`:
`current_predicate/1`, the arity guard, `functor/3`, `arg/3` and the native call.
Each extra visit costs five. No catalog or matching implementation changes.

The marker's first read has a distinct host cost. `nb_current/2` on a name
with no entry calls `auto_define_gvar`, which invokes `user:exception/3` and
then records a no-value entry. Subsequent absent reads avoid that hook
[source](https://github.com/SWI-Prolog/swipl-devel/blob/V10.1.13/src/pl-gvar.c#L277-L391).
A native first/repeat control reads 17 then 14 for the empty guard, against
14 throughout with the old predicate. Wrapped inner/outer measurements retain
the two-inference steady saving and expose later first reads at two inferences.
An actual `user:exception/3` observer sees one missing-marker read on the
import engine for memo stats, and that import engine plus the main engine for
each tabling twin. This accounts for every remainder in the table. The earlier
1,000-drain measurement described the warmed cost, not the first read.

Rejected: treating a first-use global read as periodic accounting leakage, or
pre-initializing a worker default as the runtime repair. The library may load
after workers exist; the unset-safe read is required. The first preload
experiment also showed the already-established +28 QLF artifact branch on
four cells; those cells are not used as price authority. The complete
old/current/restored control warms all affected libraries and has no such
branch. Receipts: `ai-binding-memo-layout.jsonl`,
`ai-binding-memo-first-controls.jsonl`, `ai-binding-memo-wrapped-cost.jsonl`
and `ai-binding-memo-global-reads.jsonl`.

Decided: retain the assigned guard repair and refresh the capable point rows
through the official updater, three fresh samples per row with 32 concurrent
row runners and the validated pre-boot cache lifetime. Keep every workload,
stored-content declaration, point allowance and empirical dictionary unchanged.

The official three-sample pass completes all 269 capable point rows, 807
successful samples, and moves 138 points. Across the package, 261 points now
differ from the original cut and every one decreases. The full AST audit
preserves all 277 workloads and allowances, all seven empirical dictionaries
byte for byte, and every stored-content declaration. Twelve obsolete overruns
remain the only other executable metadata removals. Combined complete receipts
number 2,423; 39 earlier interrupted samples remain excluded. Eleven first
samples take the known artifact-launch branch, nine by 28 and two by 53;
their two following warm samples agree and supply the official minimum.
The scheduler's hyperpose samples are 16,568/16,569/16,569. Receipts:
`ai-binding-memo-repin/{before,results}.json`, its 269 JSONL files and
`ai-binding-memo-repin-audit.json`.

The audit initially retained an obsolete exact 40,911 C-provider assertion.
The exercised provider now reads 40,914 three times. A further old/current/
old/current control gives twelve identical within-arm samples, 40,911/40,914,
with no provider or artifact change. Native coverage shows two dirty drains
and no arity-visit change; the actual missing-global observer records three
created engines, accounting for -4 + 3 + 2 + 2 = +3. The original four-inference
point allowance already contains it, so the official updater leaves the pin.
The audit now checks the built provider artifact and the successful provider
receipt's actual cost and content digest. The 30,004 missing-artifact branch
remains excluded from provider measurements. Receipts:
`ai-binding-memo-provider-control.jsonl` and
`ai-binding-memo-provider-global-reads.jsonl`.

Thirty-two further fresh sequential thin-forms measurements read 29,828
twenty-one times and 29,829 eleven times. Its new 29,829 point contains every
sample under the unchanged four-inference allowance; the official updater
changes nothing. The combined audit now retains 2,455 complete measurements.
Receipt: `ai-binding-memo-thin-repin.jsonl`, updater exit zero. This closes the
scheduler point's first-three-sample concern before the final committed gates.

## 2026-09-10: release the compilation observer by identity

The next whole Python run reports thirteen failures: the known browser-kit
proof and twelve automatic-memo assertions on one worker. The trailed marker
passes the native sweep and a fresh 26-test live-view/memo cohort. Reading the
new cold-compilation witness finds a different defect: its cleanup uses
`retractall(seam:function_call_graph_changed('binding-cold-spin',_))`. That
head also unifies with the generic engine and lib_memo listeners, so the
cleanup removes the event that schedules every later automatic decision.

Tried: run the cold-compilation witness, explicit-tabling precedence and both
memo interruption consequences serially with `--randomly-dont-reorganize`.
The first test passes and the other three fail, including the original
`assert 928 == 0` and `assert [Grounded(False)] == [True]` assertions.
Receipt: `ai-binding-memo-listener-before.log`, exit one. The full diagnostic
then places those files on different workers and reports 5,502 passed,
75 skipped and only the known browser failure. Every observed main-engine
marker is inactive. Receipt: `ai-binding-memo-whole-guard.log` and its four
worker JSONL files. This distinguishes the new fixture's listener deletion
from the separate, cut-reproduced asserted-guard defect above; the original
whole worker's guard was never captured.

Decided: retain the observer's `assertz/2` reference and erase exactly that
reference, following `memo_remove_dispatch_handler/1` in lib_memo. Capture
the existing listener references before registration and compare them after
release, so the witness itself detects this defect in a fresh process. Keep
pragma restoration outside that owned observer's lifetime. SWI's
[assertz/2 contract](https://www.swi-prolog.org/pldoc/man?predicate=assertz%2F2)
provides the reference; Janus's [data conversion](https://www.swi-prolog.org/pldoc/man?section=janus-data)
preserves it through `prolog(Ref)`. A raw clause blob is rejected with a
`py_term` domain error; the documented carrier passes the plain-SWI
assert/erase control. No runtime guard, quota, cost pin or allowance changes.

The repaired ordered cohort passes all 44 evaluation, automatic-tabling,
interruption, recursive-profile and occurrence tests in 5.31 seconds. Ruff
passes the changed file. Receipts: `ai-binding-memo-listener-after.log` and
`ai-binding-memo-listener-ruff.log`, both exit zero. The reference comparison
now checks listener ownership inside the cold-compilation witness itself.

## 2026-09-10: account for the native memo price changes

The committed native gate now reads evaluate 559,102, inside the unchanged
559,101 plus four allowance, and translate 313,666, below its old 313,715
point. A fresh complete native observation retains all seven inference and
instruction rows for both cut and binding. The cut reads evaluate 559,106
and translate 313,726; matching and both reader counts are unchanged.
Receipts: `ai-binding-memo-native.jsonl` and
`ai-binding-memo-cut-native.jsonl`, both successful with empty stderr. The
latter's status is `ai-binding-memo-cut-native-observation.exit`, distinct
from the earlier negative regression with the same basename.

Tried: replace only lib_memo with the preceding source, warm its artifact,
then measure old/current/old/current in fresh native processes. All 36
samples agree within their arms. Six native coverage observations show
exactly thirty dirty reconciliations in translation and two in evaluation,
unchanged between arms. Each costs two fewer inferences, accounting for
313,726 to 313,666 and 559,106 to 559,102. No host binding is loaded in these
processes. Receipt: `ai-binding-memo-native-layout.jsonl`, exit zero; source
restoration is asserted in its finally block.

Boot in that restored-source control reads 296,761/296,752. Its coverage has
no dirty reconciliation and differs only in one fewer `thread_local/1`
declaration and that declaration's predicate-attribute helpers. Removing the
old guard removes this nine-inference contribution in the actual QLF loading
window. A separate direct-call control reads one inference for an empty
window and eleven with the declaration, including the direct invocation;
it is a different measurement boundary and does not replace the boot price.
The native entry names this attribute path in SWI 10.1.13
`boot/init.pl:thread_local/1`, `'$set_pattr'/3` and `'$set_pi_attr'/3`.

The independent fresh pair reads boot 296,734/296,731, and the preceding
control had read 296,767/296,767. This residual launch/artifact sensitivity
remains unassigned, as already recorded above; every variant is below the
unchanged 301,230 pin. The isolated memo contribution is nine, not a claim
that every observed boot difference is caused by the repair. No native pin
or allowance changes. The direct controls are
`ai-binding-memo-native-{qualified-,}attribute-control.json`.

## 2026-09-10: identify the binding's closed-set policies

The cut's `sh tools/check.sh closed-sets` returns one with ten unanswered sets.
Three are `_BINARY_NUMERIC_OPERATORS`, `_ARRAY_NUMERIC_OPERATORS` and
`_UNARY_NUMERIC_OPERATORS` in `_binding/host.py`. The changed
`_spaces/execution.py` also owns `_DEFERRED_EXECUTION_OPENERS`. The other six
findings are in four unchanged files: `metta/__init__.py`, `_layers.py`,
`_spaces/profile.py` and `lint/_analysis.py`. The latter has three findings
at this cut. Receipt: `ai-binding-closed-sets-cut.log` and `.exit`.

Read: `check_closed_sets.py`, the complete numeric adapter and controlled
execution units, `metta_math_operation/2` and the numeric refusal rows in
`engine/metta/terms.pl`, and `grounded_numeric_operation/3` in
`engine/ext_points.pl`. The numeric protocol was introduced in
`a0f1cc5f15a15e5ca6958fe02a20be8832c7237f`. Its native rows describe names,
arities and admission; its host implementation chooses Python callables and
array namespace methods. Python's [operator protocol](https://docs.python.org/3.14/library/operator.html)
and the [Array API namespace contract](https://data-apis.org/array-api/2024.12/API_specification/generated/array_api.array.__array_namespace__.html)
define those host interfaces. The exception mapping in
`2026-09-08-every-closed-set-derived.md` records the same ownership distinction.

Decided: each of the four tables answers `decides; reads=none`. No registrant
extends these dictionaries, and no engine row supplies their implementation
targets. The three numeric tables choose operators, array method names and
scalar math functions. The opener table selects the held query and debugger
wrappers whose execution policy survives suspension. It is host execution
policy, rather than a copy of the native service vocabulary.

Rejected: generating these mappings from operation membership alone. That
membership does not say which Python callable or namespace attribute to use,
or which wrapper retains a held query's policy. Putting those implementation
choices in the engine would move the binding's policy out of its owner.
Preserve every table value and function body; add only the four adjacent
policy declarations, then check the lane and its planted-defect selftest.

The preceding clean committed runtime verification is retained at
`020148d9d44859afd2426d29faf0c9e070ad9293` with provenance
`815d4ebbd6a8ae9881ab3ffb2e1adffb923bd52c`. Native tests pass 2,581 tests and
3,563 sub-tests. Python passes 5,502 with 75 skips and only the cut-reproduced
browser-kit refusal proof failure. The normalized complete twin lane runs
277 successful children, no point or semantic failure, and five empirical
below-range findings. All generated-artifact drift and mutation checks pass.
The final comment-only change will be checked against this executable source;
the provenance and policy lanes run again on the resulting committed pair.

The first branch check reports seven findings after the four declarations.
Six are the cut findings in the four unchanged files; the seventh is the
new generated `_CALLBACKS` projection. `callbacks.py` is a mixed file: its
table is generated, while the lazy entry wrappers are handwritten. A
module-wide generated-file exemption would therefore be false. Make
`bindinggen.callback_projection()` emit the adjacent `generated` declaration
with `by=extensions/python/tools/bindinggen.py; lane=binding`, then regenerate
through the existing tool. Its projection mutation witness already plants
callback drift and verifies the lane refuses it.

The new interface's three host-selected sets also replace their explanatory
`reads` prose with the precise `reads=none`: `CALLBACK_GROUPS`,
`PYTHON_SERVICES` and `CAPABILITIES` are declarations authored here, not rows
read from another owner. Their signature and capability checks remain in
the existing contracts and checker. `NATIVE_FORWARDS` continues to name
`engine/ext_points.pl:kind/2`, which is the actual row it reads. No row or
callable changes.

Verification: `python extensions/python/tools/bindinggen.py --write` returns
zero. `sh tools/check.sh closed-sets closed-sets-selftest binding binding-selftest
ruff` passes binding, all 78 binding mutation tests in 74.94 seconds, and
Ruff. The closed-set scan now reports 55 sets and exactly the six remaining
cut findings in the four unchanged files. The full closed-set selftest runs
its eight fixture cases, then fails its ninth case,
`test_the_shipped_tree_passes_its_own_gate`, at `assert main() == 0`.
The pristine cut's exact selftest command fails at the same assertion with
its ten unanswered sets. Neither checker nor selftest is changed to hide
those findings. Receipts: `ai-binding-policy-{generate,gates}.log` and
`ai-binding-closed-sets-selftest-cut.log`, each with its `.exit` companion.

The regenerated unit census is 12,417 physical lines at the cut and 12,836
here. The last metadata additions account for four lines: three host policy
comments and one generated callback marker. All 56 units, 35 benchmark rows,
15 instruction rows, fourteen extension rows, seven native rows and 277
twin observations are retained in the regenerated report tables. The
execution policy comment is outside the binding's unit count.

## 2026-09-10: derive held entry pairs from the shim's return signatures

The preceding opener-policy decision is superseded. It checked engine rows,
but the binding's own clauses already state the required distinction. Every
`metta_py_wrappable/1` entry ending in `_controlled` returns either a
`prolog/1` handle or a two-element payload/text packet. The former opens a
held execution and accepts its policy before the output; the latter resumes
it. Removing the suffix supplies the existing host lookup name, including
the debugger's virtual base, which needs no native forwarding clause.

Decided: generate both maps from those admitted names and parsed clause heads.
Require a definition for each admitted name, an explicit supported return
shape, and agreement among its clauses. A newly declared handle-returning
entry must appear even when its name does not contain `open`; a resume must
not enter the opener map. Plant missing definitions, unknown and conflicting
return shapes, generated-map drift and missing region delimiters. Register
the new region with the binding artifact and run its mutation lane and the
existing execution-scope, cursor-transaction and debugger tests. The emitted
values and all runtime bodies remain unchanged; full runtime receipts stay
at the previously verified snapshot with an explicit equivalence audit.

Verification: both emitters return zero. Binding passes 85 tests, including
the seven new declaration and projection cases, in 72.99 seconds. The artifact
manifest and its twelve mutation cases pass. The execution-scope, debugger,
cursor-transaction and algebra cohort passes 161 tests in 26.03 seconds.
Ruff initially rejects six positional arguments in a new test; bundling its
three mutation fields as one case fixes the signature, and Ruff then passes.
The closed-set lane still reports exactly six integrator-owned findings.

A controlled before/after checker comparison plants the identical wrong
debugger target in the execution map. The previous generator at `34a58b36b`
reports no finding; the repaired generator reports `binding projection drift:
extensions/python/metta/_spaces/execution.py`. Neither native source nor the
planted map differs between arms. Receipt: `ai-binding-controlled-drift-control.json`.
The new region is declared alongside the existing disjoint evaluation-keyword
region in the artifact manifest. No runtime function body or table value changes.

The focused clone scan of `bindinggen.py`, its interface tests and
`_spaces/execution.py` reports two existing function-signature fragments,
17 tool-counted lines and 102 tokens. Both are repeated public parameter
lists, not duplicated implementation bodies; extracting them would hide the
signatures the door catalog reads. The generator and new witnesses have no
clone. Receipt: `ai-binding-controlled-clones.log`, exit zero.
