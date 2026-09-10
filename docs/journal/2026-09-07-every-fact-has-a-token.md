# Every fact has a token

Goal: identify each stored occurrence by actor and generation while preserving ordinary answer bags, indexed reads and the measured storage budget.
Constraint: step 0 of the substrate design; the cut is f0d33dcad438f91556459ba43c80212d9b46b760. History and commit records belong to step 1.

## 2026-09-09, parametric enumeration reaches scalar storage

Tried: the new public/bulk write regression stores two copies of six atom
shapes in named and parametric spaces. Both contain twelve unique tokens,
but the parametric unbound read returns only four expression rows. On the
pristine cut, storing `[[row],scalar,17,[],"text"]` and enumerating the
parametric space returns `[[row]]`, exit 1 against the five-row assertion.
The cut in the parametric enumeration clause dates to b48abf7576 and excludes
the shared scalar clause. SWI's `!/0` contract confirms that it commits to
the current predicate clause, not just the expression alternative.

Decided: use `native_storage_functor/2`, already used by token enumeration,
in one open expression clause. Its next clause then enumerates scalar storage
for both name shapes. Keep the bound indexed clauses. This repair needs
`engine/spaces/native_matching.pl`; the integrator has been asked to reserve
that hunk. The write regression covers both bags and occurrence identity.

## 2026-09-09, call the token-aware write body directly

Tried: the MORK workload's foreign scalar additions gain exactly one inference
per atom at the tokens merge: 36174 to 36674 at 500 before resolving the
separate 159-inference autoload. `metta_add_atom/3` now only forwards to /4.
Native additions gain six per atom: the same forwarding call and five
inferences in SWI's atomic `flag/3` update. An isolated update reads six
including the ending `statistics(inferences,_)` call.

Decided: the two public `add-atom/3` bodies call the existing /4 body with an
unbound token, and the native bulk loop calls `add_sexp_in/5` directly.
The lower-arity entry points remain available to callers. Allocation, type
alias observers, source journaling and provider effects stay in their existing
canonical bodies. `engine/spaces/lifecycle.pl` is outside the initial file
list because it owns both public write bodies; the integrator is coordinating
these two calls with the import package. Add a public/bulk token-and-bag
differential for named and parametric stores, then rerun the complete focused
space suites and cost families.

Rejected: replacing the atomic generation counter with thread-local state,
because independent writers must mint distinct identities and loads advance
the same clock. The native write remains O(n), with one retained identity per
occurrence; that output bound prevents a sublinear total write cost.

## 2026-09-08

The purpose is to distinguish equal stored occurrences without retaining dead storage. The settled mechanism appends the identity to the storage clause. The related structures are database row identities, observed-remove multiset dots, Lamport clocks, MVCC rollback, incremental dataflow aggregates and source-to-compiled-code provenance. They respectively explain duplicate identity, observed deletion, ordering, abandoned generations, the non-idempotent sum hazard and the equation link. Sections 25 and 22 of `2026-09-06-the-python-ecosystem-as-faces-of-the-engine.md` fix the migration order and design law.

Tried: before source edits, a recursive nondeterministic function with base bag `{1: 2, 2: 1}` and recursive body `(+ (f $n) (f $n))`, through `MeTTa.run`, under `(cache f refuse)`, automatic memo and `(cache f force)`. Depths 0, 1, 2 and 3 returned identical bags with 3, 9, 81 and 6,561 occurrences. `is-memoized` reported false, true and true respectively. The load average was 40.68 / 24.36 / 19.86. No recursive counting defect was observed in these finite, descending variants.

Tried: SWI 10.1.13, `dynamic f/1 as incremental`, `table t/1 as (incremental,shared)`, `t(X) :- f(X)`. A committed transaction changed `[base]` to `[base,committed]`; a rolled-back write temporarily added `rolled_back` and restored `[base,committed]`; a snapshot temporarily added `snapshot` and restored the same pair. The invalidated/reevaluated counters progressed 0/0, 1/1, 2/2, 3/3, 4/4, 5/5.

Tried: the same shared table with a second thread reading before rollback. The writer's table answered `[uncommitted,base]`; the other thread's database answered `[base]` but its table answered `[base,uncommitted]`. After rollback both answered `[base]`. This is a pre-existing isolation defect at the cut, before tokens exist.

Decided: refuse execution of a shared table inside `current_transaction/1`, naming the head and the private-table remedy. Install the check with `library(prolog_wrap):wrap_predicate/4` on the tabled predicate, so a previously compiled direct call is covered. Private tables retain SWI's transaction machinery. A dispatch-only guard would miss direct compiled callers; switching a live shared predicate to private would mutate another thread's table policy. Revisit when SWI supports isolated shared-table evaluation.

Sources: the installed `library/prolog_wrap.pl` and SWI's [transaction-impact manual](https://www.swi-prolog.org/pldoc/man?section=transaction-impact) describe predicate wrappers and transaction-aware local tables. The manual says shared tables should not be combined with transactions; the two-thread witness demonstrates the consequence on 10.1.13.

Tried: an in-memory wrapper prototype rejected the transaction, retained `[base]`, and an explicitly private replacement committed `[yes,base]`. An earlier probe called nonexistent `transaction_property/2` and failed with `guard/1: Unknown procedure: transaction_property/2`; the documented predicate is `current_transaction/1`.

Tried: the tracked a/c probes initially resolved their `../../engine/` imports in the main checkout and printed the deprecated working-directory-search warning. Those engine measurements are excluded. Loading the same source through `load_files(user,[stream(user_input)])` with absolute worktree imports removes the ambiguity. The first stdin spelling failed with `Prolog initialisation failed: file '\''/dev/stdin'\'' does not exist`; the stream option is the working door.

Tried: `sh engine/test.sh suites/libraries/tabling_transactions.plt` passed all 6 tests, covering compiled callers, raw and MeTTa transaction/snapshot doors, private commit and nested rollback, two-thread visibility, and wrapper retirement. `sh engine/test.sh suites/libraries/lib_tabling.plt` passed 20 tests and 61 sub-tests. The focused jscpd report contains zero clones.

Tried: the corrected worktree-relative probe commands, `swipl -q -g main -t halt tests/prolog/probes/tokens/probe_a_clause_ref_identity.pl` and `swipl -q -g main -t halt tests/prolog/probes/tokens/probe_c_token_cost.pl`, both exited 0. At 100,000 atoms, raw storage used 14,400,128 bytes and trailing integer storage 16,000,128 bytes. Integer-token writes used 1,000,006 inferences against 500,006 raw; bound reads used 1,012 and scans 100,012 in both representations. The engine add control used 1,200,006. Held erased clause references survived collection; snapshot references no longer decoded after the snapshot.

Tried: two engine threads each called `flag('$metta_generation', Gen, Gen+1)` 100,000 times. Both joined with `true`; 200,000 results contained 200,000 distinct integers, with minimum 0, maximum 199,999 and final counter 200,000. A separate boundary probe setting a flag to 18,446,744,073,709,551,616 raised `error(representation_error(int64_t),context(:(system,/(set_flag,2)),_))`. The counter is signed 64-bit, not an unbounded Prolog integer.

Tried: a throwaway SWI FLI constructor appended or decoded the trailing argument without constructing two intermediate Prolog lists. Its raw 100,000-write differential, including the flag call, was 599,999 inferences; direct reads were 100,013 on both sides. The constant call-frame offset is excluded from per-atom slopes. The constructor preserves variable sharing. WASM's existing `uuid/1` returned a UUID, so the Node seat needs no separate identity generator.

Decided: keep the relation first and occurrence last. `metta_storage_term/4` implements the representation bijection; the native FLI implementation and portable Prolog specification share its contract. Explicit token arguments thread persistence metadata through existing write paths, including batched loads and annotation expansion. Fresh writes mint at the storage funnel. Received identities validate and advance the atomic flag before publication. Exhaustion raises before storage changes. No token registry retains stored clause references.

Decided: boot configuration accepts `--actor=` and `--generation=`, with `METTA_ACTOR` and `METTA_GENERATION` as environment equivalents. An unspecified actor is a boot UUID. Restoring an actor requires the caller to supply its saved next generation before catalog initialization; a fresh actor starts at zero. Actor identity is immutable for the process. Local tokens are integers; portable tokens are `t(Actor, Gen)` and the host door returns the existing expression representation `(t Actor Gen)`.

Decided: token order is generation then actor. Subtraction observes matching clause references and selects the least token in linear time with constant auxiliary storage. Draining snapshots the observed references, so callbacks cannot cause a later equal occurrence to be erased. Equation compilation records exactly one token row per native compiled clause and preserves it through recompilation; source ownership remains separate.

Decided: fast image version 5 carries actor, next generation and one token beside every atom. The existing equation binding and world-node relocation remain intact. Content digest remains content-only. A foreign provider's `tokens` capability supplies `(token, atom)` pairs, avoiding an equality join that would square duplicate multiplicities. Missing capability is a `SpaceCapabilityError` whose remedy names a native overlay or stable provider identity.

Rejected: sorting all matches for subtraction, because only the minimum is needed. Revisit if another operation needs the complete order. Rejected: matching compiled equations back to stored equations by content, because duplicate equations need distinct identities. Rejected: a process-wide current-token setting, because explicit metadata must survive nested callbacks without being consumed by unrelated writes.

Open: the existing image loader adds occurrences on repeated loads. A cut probe returned counts 1, 2 and 3 after adding one atom, loading its saved image, and loading a byte-identical file under another name. Preserving all incoming tokens would violate distinct identity; deduplication would change answers. The collision policy has been requested from the package coordinator. Independent storage work does not depend on that policy. Remaining gates are listed in the task plan.

Tried: `swipl -q -g main -t halt tests/prolog/probes/tokens/probe_c_token_cost.pl` after storage migration exited 0. At 100,000 atoms, engine adds use 1,800,006 inferences against 1,200,006 at the cut, exactly +6 per atom. Bound reads remain 2,021 per 1,000 answers and scans remain 200,021 per 100,000 answers. Clause storage grows from 14,400,128 to 16,000,128 bytes, exactly +16 bytes per atom. The native constructor builds with `swipl-ld -shared -O2 -Wall -Wextra -Werror` and its differential covers widths 0 through 1,000 and variable sharing.

Tried: the storage integration selection exposed old-arity reads in catalog priorities, direct type declarations and materialization watchers. Updating their shared storage decoding repaired the failures. The spaces suites pass 335 cases, hooks 56, materialization 53 and occurrence laws 19, including two-thread native minting and the loaded MORK capability refusal. A bulk native clear consumes one operation generation before its C-level retractall sweep; compiled withdrawals consume their individual generations. This preserves constant Prolog inference cost for clearing plain data.

Tried: Node's WASM build has neither `library(shlib)` nor `shared_object_extension`. The unconditional import raised `source_sink 'library(shlib)' does not exist`; the earlier extension lookup then silently skipped the portable constructor. Gating the native-library branch on actual platform predicates and installing the Prolog specification otherwise repairs both. A Node smoke boot with actor `t0-node-resume` and generation 100,000 returns two distinct `(t t0-node-resume Gen)` values through `Space.blame`.

Tried: the reader's late-definition cost check failed at `8931 < max(-5783,0)*2.5+500`. Profiling found that the first late load deferred while a later load compiled on arrival. Recompiled function metadata survived cleanup without a source owner. The regression `filereader_source_reload:recompiled_metadata_keeps_the_equations_source_owner` fails for all four metadata rows both here and in a detached cut control. `record_source_assertion/1` ignored `source_recompile_owners/1`, although grouped graph assertions already honored it. The same owner precedence now covers every recorded assertion. The complete reader suite passes 60 tests and 3 subtests; its original cost bound is unchanged. The fixture's silent flag now names its module owner, filereader.

Decided: process identity belongs in `engine/identity.pl`, loaded and validated by the host boot call before the engine umbrella. SWI consult reports directive exceptions and continues, so a directive alone cannot reject invalid boot input. Native hosts use `qlf_load_engine/0`; Python now calls that checked goal, and Node validates identity before its source-only umbrella load. `METTA_GENERATION=bad` raises a generation domain error; the runtime remains unpublished and `current_predicate(spaces:add_sexp/2)` is false. Generation errors cannot leave a catalog allocated under an absent actor.

Decided: an image load preserves every non-colliding occurrence token and mints a fresh token for each copy whose incoming token already exists in the destination. The load is the act that adds that occurrence. Exact save/load equality holds into an empty space. The cut control counts are 1 before loading, 2 after the first load, 2 after repeating that same filename, and 3 after loading a byte-identical copy under a second filename. The middle load replaces its own previous source contribution, as the existing source lifecycle requires. The collision rule preserves this lifecycle and all four counts. Rejected: refusing a colliding load, because it changes an accepted operation; deduplicating incoming atoms, because it changes the answer bag.

Decided: image version 5 retains the existing world graph and binding indices, with process identity and a parallel occurrence-token list per space. Tokens do not undergo world relocation. Validation checks token shape, parallel cardinality, per-space uniqueness and the captured next generation before publication. Receipt advances the clock before any copy can mint a collision replacement; fresh replacements still mint through the native write funnel. Collision lookup uses a temporary index of the destination's current tokens, with no persistent clause-reference registry.

Tried: the version-5 loader preserves counts 1, 2, 2, 3 and distinct tokens, and an empty target retains the original token exactly. The existing fast/reload selection passed 92 tests and exposed a header assertion still naming version 4 and a nested compilation ownership regression. A recompile forced an unrelated deferred equation and the broad owner precedence assigned that equation to the caller's file. The cut passes `test_source_replacement_retains_recompiled_binding_ownership`; the corrected recompile context passes it here. Recompile ownership now applies only while the same active load context remains innermost, so a nested deferred source pin selects its own owner.

Tried: a QLF data-payload probe compiled one fact, erased it, and loaded the compiled file twice. Each load restored exactly one payload with its variable sharing intact. SWI's `qcompile_/3` calls `load_files/2` with a QLF output option, so compiling already loads the payload. Source: `SWI-Prolog/swipl-devel` at `fc7ef84b949378b729052c3ade79c90ce5416abb`, `boot/qlf.pl:qcompile_/3`.

Decided: static caches carry a versioned inert data image, compiled as one temporary payload fact. The receiving engine validates and stores each occurrence through the native funnel, retaining equation inertness and the existing source journal for replacement and rollback. The writer uses an owned temporary native space so cached tokens are minted by that same funnel. Cache names gain `.tokens-v1` so older clauses with a different storage arity cannot be loaded accidentally; a present source regenerates them. The payload fact is erased after both success and failure. QLF digests read binary bytes. Rejected: compiling native storage facts directly, because loading under another actor would publish unnormalized tokens before Lamport receipt and could store into the writer's runtime space.

Tried: two raw outer transactions started before either image load. Loading byte-identical files into the same empty destination and committing both returned `statuses true true tokens [723,723]`. A mutex around each load cannot repair a caller's older transaction view. Nested `transaction/3` and `snapshot/1` inherit that view; `transaction_updates/1` reports only the innermost pending delta. A frame listener sees the outer `system:'$transaction'/2` frame finish after `current_transaction/1` has become false. Commands: `swipl -q -g main -t halt ai-tmp/ai-image-concurrency.pl` and `swipl -q -g main -t halt ai-tmp/ai-transaction-frame-probe.pl`.

Decided: image receipt checks the caller's rows, the committed rows and reservations held by other unfinished transactions under one mutex. Reservations disappear at outer transaction completion; nested rollback releases its own reservations through SWI's predicate rollback event. A transactional deletion journal excludes the caller's own removed references from the committed view, including deletions in an enclosing transaction. This is the same visibility distinction used by PostgreSQL unique indexes (`https://www.postgresql.org/docs/18/index-unique-checks.html`). A competing pending receipt gets a fresh token immediately, so neither callback replay nor waiting on another transaction is needed. Ordinary writes retain only their trailing argument. The standing engine supplies a fresh committed view, following `materialize:source_owner_retirement_loop`; it is created at engine boot, never from a callback. Source: SWI `fc7ef84b949378b729052c3ade79c90ce5416abb`, `src/pl-transaction.c:transaction`, and the `frame_finished` and predicate `rollback(Action)` events.

Rejected: a permanent occurrence registry, because it repeats storage identity and retains references; serializing all transactions, because it changes unrelated concurrency; retokenizing at commit, because it changes identities already observed inside the transaction; retrying a transaction, because it repeats host effects. Native erasures record references only until their enclosing transaction finishes. A bulk clear inside a transaction visits those references; a plain clear retains its C-level sweep.

Tried: registering the global `frame_finished` listener from each worker deadlocked two transaction callbacks. A minimal transaction-scope probe reproduced the wait without images. SWI's `src/pl-event.c` keeps that event in the global event list. Registering it once at boot removes the lock cycle; the image probe now returns `statuses true true tokens [723,724]`.

Tried: decoding a receipt marker during `rollback(assertz)` failed because SWI had already erased the clause. Attaching its reference while live lets rollback release by identity. `sh engine/test.sh suites/spaces/tokens.plt` passes 24 tests and 2 sub-tests, including concurrent receipt, stale transaction views, nested rollback, snapshots, parent deletion and an injected restore failure while the outer transaction stays open.

Decided: classify storage expressions only after checking `nonvar(Atom)` and compare the relation to `':'` by identity. Unifying those dispatch patterns changed variable-headed expressions and bare variable atoms before the constructor saw them. The storage-shape law now includes both forms and preserves variable sharing.

Tried: `test_recursive_memo_coefficients` passes with catalog declarations applied through `add-atom &metta`: refused, automatic and forced modes retain bags of 3, 9, 81 and 6,561 answers, and report memoization false, true and true. A first fixture placed the policy in an ordinary space and observed true instead of false; `metta_contract_fact/1` reads the catalog, so the fixture now uses the existing policy door and removes its declarations in `finally`.

Tried: 43 Python image/provider/reload cases and all 6 Node token cases pass. `aiogen.py --write`, `initstubgen.py --write`, `reference.py --write`, `vocabgen.py --write` and `fngen.py --write` exit 0. Node provider token pairs pass through the existing expression encoder; token-only providers are recognized by the provider adapter.

Correction to the earlier flag boundary inference: this SWI build accepts 72,057,594,037,927,935 (`max_tagged_integer`) through `flag/3`, but larger tested integers raise `representation_error(int64_t)`. The refusal names the C representation; it does not establish acceptance of every signed 64-bit value. Invalid and exhausted Python boot probes leave the runtime unpublished.

Correction to the earlier duplication result: a default scan can ignore this entire worktree through `**/ai-tmp/**`. The explicit-file scan uses `--no-gitignore` and checks the report's file and token counts before interpreting zero clones.

Tried: the complete suites on the persistence checkpoint exposed seven Prolog fixture failures, nineteen Python failures and ten setup/teardown errors, and four Node startup failures. The native cut passed every Prolog suite and its full corpus. The cut Python run had one environment failure: its website dependencies were not linked. The repairs update storage watch arities, the identity leaf edges, static cache names, capability compliance and generated inventories. The open-arity catalog reader now rejects an improper list explicitly, preserving the previous type error.

Decided: a live view's atomic seed uses the existing transaction and therefore requires a private table. The live-view tests and cost probe declare that scoped policy; a separate refusal test preserves the named shared-table remedy. Ordinary ground subtraction must inspect matching occurrence tokens to choose their minimum. The view overhead test subtracts the plain-storage cost from the subscribed cost, so it measures the view's constant overhead rather than asserting that unordered token minimum selection is constant time.

Tried: `PYTHONPATH=extensions/python python extensions/python/benchmarks/probes/live_view_cost.py` with token storage and the private policy. At 10, 100 and 1,000 rows: pattern writes 90/90/90; conjunction writes 200/575/4245; untouching writes 95/95/95; tabled invalidating writes 1156/1689/7089; table-valid writes 557/557/557; recomputation 178/553/4223. Forms report two tables and two answers for all three call shapes; effects and variable naming retain their previous results.

Tried: linked Node output initially loaded the main checkout's old engine. Preserving module links bound it to the edited checkout, after which 643 of 644 tests passed; the CLI exited zero with empty output. Its entry check resolved only process.argv[1]. Decided: resolve both entry paths with realpathSync and fileURLToPath. Node v22.22.1 documents that --preserve-symlinks-main keeps the main module link: https://github.com/nodejs/node/blob/v22.22.1/doc/api/cli.md#--preserve-symlinks-main. A linked-checkout test exercises both policies. `cd extensions/node && npm test` then passed 645 tests.

Tried: forced `load_files('engine/spaces.pl', [if(true)])` after boot made metta_storage_term/4 fail while predicate_property reported both foreign and dynamic. SWI retained the loaded library and did not repeat its registration. Decided: remove the dynamic declaration of the foreign predicate; assertz creates the portable fallback's dynamic predicate only when needed. The subprocess regression retains the actor and original occurrence, reloads storage and adds a later occurrence.

Tried: jscpd with explicit files, Prolog format mapping and --no-gitignore read eight files, 1,083 lines and 13,087 tokens; one clone covered nine lines and ninety tokens in two concurrency fixtures. Rejected: extracting those two cleanup blocks, because their explicit queue/thread/space lifetime is clearer at each fixture and no production logic is duplicated.

Tried: an equal-length benchmark control first lacked empty_prune.so and mbr.so, which the four-field benchmark stamp does not detect; match-skew incorrectly read 308202 against the fully provisioned cut's 208062. After copying every engine shared object, the inference rows matched their cut pins. The same 29-character path is used for every ladder point; its cut instruction counts are recorded separately from the older pins. Empirical Python and memory envelopes remain unchanged under the integration ruling.

Tried: the equal-path inference ladder, each minimum of three fresh processes after clearing engine/lib QLF artifacts, using `sh engine/bench.sh --counter-only`:

| State | Boot | Evaluate | Translate | Bound match | Skew match |
| --- | ---: | ---: | ---: | ---: | ---: |
| Cut f0d33dcad | 286857 | 558940 | 310749 | 266202 | 208062 |
| Shared-table refusal cbe3c6d74 | 286857 | 558940 | 310749 | 266202 | 208062 |
| Native occurrence storage 8e4a7f520 | 297167 | 559048 | 312877 | 266202 | 208062 |
| Portable images and receipts f1ea49f67 | 298169 | 559101 | 313714 | 266202 | 208062 |
| Integrated source-reload repair 3cb251c1d | 301330 | 559101 | 313715 | 266202 | 208062 |

The image checkpoint's translate samples were 313714/313715/313715; all other listed triples were identical. Parse remains 152 and the Prolog splitter remains 3517359 throughout. The final five moved rows were re-pinned with `sh engine/bench.sh --update-baseline boot evaluate match match-skew translate`. Their final instruction minima are 965561590, 504998657, 171194422, 489762799 and 319207971 respectively. The cut control at the same path reads 936739989, 504667553, 162903990, 483301680 and 307811607. Boot and translate already exceed their older instruction pins at the cut. Counter allowances and advisory wall fields were retained.

Tried: the twin re-pin tool measured all 277 twins, updated 268 point budgets and left four empirical envelopes unchanged. The static-import twin initially failed because it still expected the old cache names; after migrating the fixture and its cleanup to tokens-v1, its point re-pin passed at 135358 inferences, down from 141374. The tool re-priced 269 twins in total. The full Python suite then passed 4725 tests, skipped 75 and failed one Ruff assertion for a missing fixture docstring; the fixture now states its supplied rows. The source-reload regression and complete host source walk both passed in a separate subprocess run.


Tried: the final functional suites passed: `sh engine/test.sh` counted 2510 tests and 1503 sub-tests; `sh test.sh` passed 312 files and 2512 assertion checkmarks; Node passed 645 tests in 140 suites; the C seat passed its complete contract runner. The pristine cut counted 2475 tests and 1501 sub-tests and the same 312 corpus files and 2512 checkmarks. The loaded MORK capability test ran and passed. The repeated token cost probe retained +6 inferences per add, +0 for bound and scanning reads, and +16 bytes per atom.

Tried: `sh check.sh petta parity engine-bench memory-scale-gate benchmarks llms llms-selftest evidence` returned 1. PeTTa agreed on 154 of 156 cases, with two recorded rulings and zero blockers; parity agreed on 312 of 312 examples. The two sheet checks reported zero findings and 64 of 64 planted controls. A malformed benchmark JSON edit raised `JSONDecodeError: Extra data: line 115 column 7 (char 93038)`; restoring valid row structure and rerunning engine-bench passed all seven rows with the existing four-inference and instruction bands. Evidence found two measurement tags without dates; adding their observation date yielded 7121 claims, zero unbacked tags and 307 WORKTREE placeholders before pinning.

Tried: the final Python suite's only failure after the fixture docstring repair was `test_no_tracked_file_cites_an_absolute_workspace_path`. The new journal command and baseline comments named a local checkout. Replacing those machine-specific spellings with relative commands passed that check and Ruff together, two tests. The website build then found `[vitepress] 1 dead link(s) found.` The MORK README link was introduced by 6da518669cb9e39557d537857c0aa7190dd2e78f and points outside the built site. Describing its actual repository path preserves the journal reference; `cd website && npm run docs:build` passes.

Tried: the Python counter gate failed 29 of 35 cases, while its pristine cut control failed 25. `python bench.py --counter-only --keep-going --update-baseline` from extensions/python passed all 35 workloads and remeasured their points and slopes. The four already-accepted points retain their former pins. Native add, batch, table rows and subscription writes gain six inferences per inserted atom; equation provenance and source ownership affect registration and first compilation; fast loading also validates and reserves incoming identities. Rows equal at the cut and token state are prior drift. Neither instruction bands nor wall observations nor empirical envelopes were changed.

| Python counter row | Former pin | Cut observation | Token pin |
| --- | ---: | ---: | ---: |
| add-batch | 42049 | old pin passes | 54050 |
| add-single | 54029 | old pin passes | 66029 |
| add-table-rows | 50048 | old pin passes | 62050 |
| annotated-relation | 830765 | 834843 | 862843 |
| direct-join (point unchanged) | 121139 | old pin passes | 121139 |
| eval-arith | 285167 | 285269 | 285269 |
| file-load | 726602 | 726852 | 846863 |
| foreign-match | 793189 | 793269 | 793269 |
| handle-round-trip | 1561221 | 1593269 | 1593269 |
| let-heavy | 16006080 | 16005486 | 16005527 |
| loop-1m | 11004923 | 11004521 | 11004640 |
| op-encoded | 325171 | 325269 | 325269 |
| op-raw | 305169 | 305269 | 305269 |
| prepared-join | 280652 | 280642 | 280642 |
| py-method-call | 2300796 | 2300723 | 2300729 |
| query-limit-guarded | 30605 | 31307 | 31307 |
| query-where | 59984 | 71652 | 71652 |
| register-op | 107223 | 107421 | 124024 |
| run-source | 436175 | 444269 | 444269 |
| save-load-fast | 2949912 | 2949927 | 4050175 |
| save-load-metta | 928230 | 928327 | 1048412 |
| sort-atom | 1301578 | 1301592 | 1301592 |
| source-load | 239452 | 244415 | 258629 |
| space-digest | 920301 | 920269 | 920269 |
| space-name | 4290437 | 4290267 | 4290267 |
| subscribe-tax | 42064 | old pin passes | 54064 |
| table-bridge-match | 793189 | 793269 | 793269 |
| typed-call | 12505813 | 12505367 | 12505441 |

The direct-join slope is 581256 at both cut and token state, against the old 581280 pin. The other updated slopes are 14400000 for let-heavy, 1346880 for prepared-join and 11250000 for typed-call. Automatic memo's four plain samples gain exactly 37 inferences over the cut and its automatic samples exactly 120; the new n=20 separation is 1725x against the unchanged 900x floor. All point and slope allowances remain four inferences.

Tried: the memory-scale gate measured all 23 families, with seven old-envelope failures. Every expected-family normalized RMS stays below the 0.10 bound. Its report-only Python eager peak and MORK process-memory rows remain advisory. The native storage series grows by exactly sixteen bytes per atom; load-metta gains six inferences per atom; load-fast adds token validation and collision reservation; support cleanup removes the extra equation links and transaction receipt bookkeeping. MORK's width row already fails at the cut, 50 against the 38 ceiling, and reads 49 here. Join-shared grows from 473456077 at the cut to 486255792 instructions, rather than attributing the older pin's entire difference to token storage.

| Memory-scale row | Cut at largest size | Token at largest size | Existing ceiling | Expected-family NRMS |
| --- | ---: | ---: | ---: | ---: |
| atom-reclamation | 8 | 8 | 12 | 0.0000 |
| compiled-equations | 5004480 | 5004480 | 5254704 | 0.0016 |
| hyperpose-branches | 279551 | 279596 | 419527 | 0.0038 |
| join-projection | 963994789 | 976603613 | 993884945 | 0.0020 |
| join-shared | 473456077 | 486255792 | 478603299 | 0.0035 |
| live-spaces | 7424000 | 7440000 | 7669200 | 0.0000 |
| load-fast | 361522 | 891626 | 369054 | 0.0000 |
| load-metta | 210769 | 270769 | 221269 | 0.0000 |
| mork-join-width | 50 | 49 | 38 | 0.0000 |
| mork-space-reclamation | 0 | 0 | 4 | 0.0000 |
| object-reclamation | 0 | 0 | 4 | 0.0000 |
| query-eager | 4534618 | 4534470 | advisory | 0.0000 |
| query-stream | 272802 | 272802 | 286438 | 0.0001 |
| save-fast | 982067 | 1012092 | 1031195 | 0.0000 |
| save-metta | 221396 | 221396 | 232473 | 0.0000 |
| space-reuse | 0 | 0 | 4 | 0.0000 |
| stored-atoms-mork | 15745024 | 15777792 | advisory | 0.0043 |
| stored-atoms-native | 1281256 | 1441256 | 1345319 | 0.0000 |
| support-drop-one | 253565 | 521809 | 293488 | 0.0000 |
| support-drop-spaces | 7656155 | 8150173 | 7768369 | 0.0000 |
| table-reclamation | 168 | 168 | 177 | 0.0000 |
| wire-intern-symbols | 65536 | 65536 | 68813 | 0.0000 |
| wire-intern-variables | 65536 | 65536 | 68813 | 0.0000 |

Tried: after reconciling the deterministic points, a normal Python counter run passed 34 of 35 cases. Fast save/load failed at 4050223 against 4050175 plus four. Fixed actor configuration and disabling poll accounting in a throwaway probe did not remove the variation. Paired profiles differed only in `>=/2` and `=</2` calls. The old 64-character checksum validator uses 198 inferences for digits and 390 for lowercase letters; token-bearing payloads change their checksums. The new regression first failed with `Assertion: [198,390]=[_2569734]`; its independent language test already passed.

Decided: use one lowercase hexadecimal validator for both header readers, with `code_type/2` character classes and equal calls for every accepted character. The accepted language remains exactly 64 ASCII lowercase hexadecimal characters. Rejected: fixing actor identity, suppressing poll accounting or widening the four-inference band, because none repairs the checksum-dependent work. Source: SWI's `code_type/2` reference documents `xdigit(Weight)` and `upper`.

Tried: the complete Python suite after the documentation-path repair passed 4726 tests and skipped 75, with no failures.

Tried: the corrected validator takes 263 inferences for each of the four 64-character headers (`0`, `9`, `a`, `f`). The language and cost tests pass; the complete token suite passes 26 tests and 2 sub-tests. Fast save/load re-pins to 4050161 and a normal `python bench.py --counter-only --keep-going` passes all 35 cases. Equal-path boot control f9c1ba822 reads 301330/301330/301330; f5069cade reads 301230/301230/301230. Sharing the two validators removes duplicated loader code and 100 boot inferences. Its 965089743 instruction minimum remains inside the existing 965561590 pin, which is retained, along with every band and advisory wall field. The other six engine inference rows do not move.

Tried: the final native suites pass 2512 tests and 1503 sub-tests across 91 runners; the corpus retains 2512 assertions in 312 files; Node passes 645 tests in 140 suites; the C seat again passes its complete runner. The Python run passes 4725 tests, skips 75 and fails one twin cost check: identity reads 3604, below 3664 by more than its allowance of 20. Equal-path serial controls with `twin_coverage.py --measure --rounds 3` read twin 3664 before the checksum helper and 3604 after it, while the MeTTa side stays 2435. The twin's recorded inert-clause experiment already establishes that its compiler term follows engine predicate layout. The point re-pin pass preserves declared allowances and empirical envelopes.

Tried: the final duplication scan explicitly maps Prolog, Python, TypeScript and C, reads ten files, 2730 lines and 27110 tokens, and finds only the same nine-line, ninety-token concurrency cleanup clone. The consumer audit updates the write funnel's old arity in comments and the declaration projection's stored-clause examples.

Tried: `swipl -q -g main -t halt ai-tmp/ai-equation-link-cost.pl` compiles 100, 1000 and 10000 equal equations and measures exactly that many token-link rows. Link-predicate byte deltas are 16000, 159136 and 1600000; the steady clause cost is 160 bytes per compiled occurrence. Releasing each space leaves zero links. Post-collection size deltas are +888, -864 and 0, a net fixed 24-byte predicate allocation across the sweep rather than retained occurrences.

Tried: the checksum-layout re-pin pass exits 0, updates 158 out-of-band point budgets and finds zero changed content divergences across 277 twins. All four empirical twin envelopes and every declared allowance remain unchanged.

Open: these empirical envelopes remain unchanged for the integrator's single observation on the merged tree, as the integration ruling requires. The complete raw gate receipts are retained with this worktree's task logs.

## 2026-09-09

Tried: the completed checkpoint's Python suite passes 4726 tests and skips 75. Its combined gate passes all 35 Python counter workloads, 154 of 156 PeTTa cases with two recorded rulings and zero blockers, all 312 parity examples, both sheet checks and evidence. The slowest parity child is 22.8 seconds against 300, with load average 16.03 to 19.60. Evidence reports 7122 claims, zero unbacked tags and 470 pending provenance pins.

Tried: the combined gate's boot row reads 301243 against 301230 plus four. The paired control reads 301230 in every sample; all six non-boot rows agree. Rebuilding only the control's identity artifact through a Python boot leaves that count at 301230, so that proposed cause is rejected. Clearing the worktree's engine and library QLF artifacts and rerunning `sh engine/bench.sh` restores 301230/301230/301230 without a source edit or re-pin. All seven rows then pass their existing four-inference and instruction bands. The final instruction minima are boot 972790443, evaluate 505015353, match 171191061, match-skew 489763193, parse 127053715, parse-prolog 2010205622 and translate 319475956. Decided: record the artifact-state effect and retain the controlled pin; the 13-inference observation is not evidence of added engine work.

Tried: the final memory-scale pass retains all 23 expected growth families within normalized RMS 0.0044, below 0.10, and the same seven old-envelope failures. The largest changed observations since the table above are hyperpose 279592, join-projection 976523228, join-shared 486178753, load-fast 891613 and stored-atoms-mork 15740928. Load-fast's checksum-dependent noise falls from 66 to zero. The remaining largest-size observations and ceilings are unchanged.

Tried: `sh check.sh ledger aio-mirror init-stub reference vocab-sync refusals refusal-sync evidence provenance-pin-selftest` exits 0. All generated mirrors, inventories and reference pages agree, and the provenance selftest restores its guarded files. The final header audit names the compiled-equation link and static payload owners explicitly.

Open: empirical envelope reconciliation remains the integrator's merged-tree observation. No empirical envelope was changed here.

## 2026-09-09, receipt and fast-load cost repair

Goal: remove repeated receipt ownership and token conversion work while
preserving native occurrence identity, nested rollback and concurrent loads.

Tried: on cut `3e5855a35d7b206c847845f12467551ea4c54a59`, after deleting
engine and library QLF files and warming one Python boot,
`python ai-tmp/ai-profile.py drop 2000` reads 1,036,804 inferences.
Adding `--profile` reads 1,308,143, with 104,000 frame-attribute calls,
52,000 member checks and 24,011 frame-finished callbacks. The unprofiled
wall observation is 0.159505 seconds at load averages 25.25/23.95/19.68.
`python ai-tmp/ai-profile.py load-fast 10000` reads 891,612 inferences,
0.096691 seconds at 24.46/23.82/19.68; profiling reads 1,075,911 and
20,002 engine posts. Wall observations do not decide either change.
The tokens, materialization, spaces and filereader suites all exit zero.

Decided: an unnested transaction stops ownership discovery at its nearest
native transaction frame. `current_transaction/1` enumerates the native
transaction stack, including snapshots, so one `findall/3` distinguishes
that case from a nested transaction, which retains the outer-frame walk.
The implementation is grounded in SWI's
[transaction stack and native frame definitions](https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-transaction.c#L678-L762).
Only a transaction that reserved tokens posts a reservation cleanup request.
The frame-finished listener remains installed for the engine's lifetime.

Decided: each incoming batch has one transactional rollback marker. Its
clause reference is the reservation key before the standing engine sees the
request, so no later attachment is needed. A nested rollback removes only
that batch's claims; outer completion removes its remaining claims. This is
the existing transaction-ownership protocol at batch granularity. The
supplied attachment-batching patch is measured independently before choosing
it; batching attachments alone retains one cleanup post per kept token.

Decided: image validation returns its normalized portable occurrence tokens
instead of discarding them. Restore advances the generation clock once per
image, passes the validated identities to the receipt, then lets the native
write funnel convert each retained identity exactly once. No image format or
collision rule changes. The load remains linear in incoming atom content
plus sorting/indexing cost; the measured repeated boundary work is the
constant being removed. Tests must cover malformed images, duplicate tokens,
mixed collisions, nested rollback, and overlapping transaction views.

Tried: the first full enumeration of `current_transaction/1` raises
`Stack limit (1.0Gb) exceeded` in the nested rollback and materialization
fixtures. A standalone
`transaction(transaction(findnsols(5,T,current_transaction(T),Ts)))`
returns the inner transaction followed by four copies of its parent. The
installed SWI source's redo arm retains the same stack pointer. Rejected:
unbounded counting; revisit only if enumeration is needed and SWI advances
that pointer. Decided: `findnsols(2,1,current_transaction(_),[_,_])` asks only
whether a second answer exists. The outer-frame walk still identifies the
actual owner at any nesting depth; no full count is needed.

Tried: with both MORK shared objects present, the supplied attachment-batching
patch reads 901,625 inferences against 891,612 on a pristine cut at an equal
path length. Controlled instruction triples are
1,371,655,317/1,368,005,282/1,367,156,702 versus
1,327,192,237/1,322,168,897/1,326,105,240. The minima increase 3.40%.
The command is `python ai-tmp/ai-profile.py load-fast 10000 --controlled`
through `metta_benchmarking.measure_counters`, three fresh processes per arm,
after a purge and warm boot. Load averages are 10.72/13.67/18.04. Rejected:
the attachment-batching patch, because it adds a second list traversal and
retains per-token rollback cleanup. The batch marker replaces attachment.

Measured after the repair, with the same profiling command and fixtures:

| Counter | Before | After |
| --- | ---: | ---: |
| Drop 2,000 equations, unprofiled inferences | 1,036,804 | 914,781 |
| Drop, profiled inferences | 1,308,143 | 1,101,760 |
| Drop, frame-attribute calls | 104,000 | 34,000 |
| Drop, frame-finished callbacks | 24,011 | 20,000 |
| Drop, receipt engine posts | 2,000 | 0 |
| Load 10,000 atoms, unprofiled inferences | 891,612 | 591,623 |
| Load, receipt engine posts | 20,002 | 3 |
| Load, occurrence validation calls | 20,000 | 10,000 |
| Load, native token receive calls | 20,000 | 10,000 |

The repaired load instruction triple is 754,137,710/754,119,609/754,028,133.
Its unprofiled wall observation is 0.039450 seconds at 12.63/19.25/20.94;
drop is 0.100187 seconds at 12.86/19.41/21.00. The load retains 10,000 atoms.
Validation and physical insertion remain linear in atom content; only the
per-atom receipt messages become a fixed three per batch. The native write
door still validates received identities and advances its atomic counter.

Tried: the four required suites exit zero, with 26 tests plus two subtests,
53 tests, 217 tests plus 118 subtests, and 60 tests plus three subtests.
The added batch test then passes empty, singleton, two-atom and 17-atom images
with mixed local collisions and retained remote identities. Cleanup assertions
also check that no reserved-owner fact survives. The duplication scan over
the changed source and tests reports zero clones; `git diff --check` passes.

## 2026-09-10: receipt watches stop before the discarded query frame

The final helper is `metta_receipt_nearest_frame/3`. SWI's `frameFailed`
sets `environment_frame` to the finishing frame, so a callback ancestry walk
can reselect the completed transaction. The helper excludes that finished
frame while walking the callback's live ancestry, then watches the nearest
remaining native transaction with the same receipt scope.
Source: [SWI V10.1.13 frameFailed](https://github.com/SWI-Prolog/swipl-devel/blob/V10.1.13/src/pl-wam.c#L902-L916).

FROM found a pre-existing receipts crash at the cut
`3e5855a35d7b206c847845f12467551ea4c54a59`. This command exits 139 there and
on its branch, with receipts in each checkout's `ai-tmp/ai-receipt-query-frame.log`:

```sh
/usr/bin/swipl -f none -q -s engine/qlf_boot.pl -s engine/metta.pl -g "engine_create(ready,(transaction(spaces:metta_receipt_transaction_scope(_)),engine_yield(ready)),E),engine_next(E,ready),engine_destroy(E)" -t halt
```

`prolog_frame_attribute/3` marks every inspected input frame `FR_NOTIFY`.
The former outer walk reaches the engine's outer query frame. During
`engine_destroy/1`, `PL_close_query` discards that frame after closing its
foreign frame, and the frame-finished event enters Prolog before the receipt
callback's body can run. The assertion is
`PL_open_query: Assertion failed: (void*)fli_context > (void*)environment_frame`.
FROM's debug build identifies `destroy_interactor` immediately after
`PL_close_query`, `engine_destroy/1`, and `pl-event.c`'s `call_event_list`.
The stripped binary's nearest exported `PL_thread_at_exit` label was an
incorrect attribution. Source: [the notification flag](https://github.com/SWI-Prolog/swipl-devel/blob/V10.1.13/src/pl-trace.c#L2484-L2503)
and [discard_query](https://github.com/SWI-Prolog/swipl-devel/blob/V10.1.13/src/pl-wam.c#L3052-L3064).

The earlier unnested shortcut already makes the exact command pass at e70.
Adding an inner transaction still aborts with exit 134 there, in
`ai-tmp/ai-receipt-query-frame-perf-nested-before.log`. The new ownership
regression against e70 exits 139 in `ai-tmp/ai-receipts-frame-regression-before.log`.
Moving `engine_yield/1` inside a native transaction is not an equivalent
control: SWI rejects it with `No permission to execute vmi 'I_YIELD' (not an engine)`.
The regression retains the reported order: finish the receipt transaction,
yield the engine, then destroy it.

Rejected: reading the completed frame's parent in the callback. The success
path has already invalidated that frame; the probe raises
`prolog_frame_attribute/3: Type error: 'frame_reference' expected, found '158' (an integer)`.
Rejected: transfer through the callback's nearest transaction without excluding
the completed frame. The failure path selects itself, `1351 -> 1351`, and
leaks the owner after inner rollback. Both failures and the corrected control
are retained in `ai-tmp/ai-receipt-watch-transfer-{probe,current-probe,isolated,excluded}.log`.
An outer-frame walk bounded by a query-frame guess was not implemented:
the public choicepoint parent chain stops at each foreign query and supplies
no safe general outer bound. Ownership transfer follows the native transaction
completion boundary instead.

Decided: every first receipt watches its nearest native transaction. At
completion, an active outer transaction inherits the same scope; otherwise
the scope retires. This removes the nesting query and the unbounded outer
walk. No frame above the live transaction needs inspection. The standing
listener remains installed, and the existing transactional markers still
release only the rolled-back batch. A scope with no reservations still sends
no cleanup request.

The complete throwaway candidate passes four new tests with seven subtests,
including depths 1..4, exactly one scope retirement after engine destruction,
no early retirement during nested commit, failure and exception rollback,
and transaction/1, transaction/2, transaction/3 and snapshot/1 outer owners.
The eight existing image tests and five subtests also pass. Command:
`swipl -f none -q -s engine/qlf_boot.pl -s engine/metta.pl -s tests/prolog/suites/spaces/tokens.plt -s ai-tmp/ai-receipts-frame-candidate.pl -s ai-tmp/ai-receipts-frame-tests.pl -g 'run_tests([receipt_frames_probe,spaces_token_images])' -t halt`.
The receipt is `ai-tmp/ai-receipts-frame-candidate-complete.log`, exit 0.
Tracked implementation, focused verification and cost controls follow this
design; their results will be appended when measured.

Tracked verification: `sh engine/test.sh suites/spaces/receipt_frames.plt
suites/spaces/tokens.plt suites/spaces/materialization.plt
suites/spaces/spaces.plt suites/libraries/lib_thread_completion.plt` exits 0.
The counts are 4+7, 29+5, 53, 217+118 and 3 tests/subtests, respectively,
in `ai-tmp/ai-receipts-frame-tracked-focused.log`. The literal command above
and its nested-transaction variant both exit 0, with empty output, in
`ai-tmp/ai-receipt-query-frame-{final,nested-final}.log`.

Paired measurements at `../../../boot5`, relative to the worktree root, change only receipts.pl
from its e70 body to the tracked watcher. Three unprofiled processes per
arm read 914,781 to 886,777 inferences for 2,000-equation drop. The profile
removes 2,000 `findnsols2/5` and `findnsols_loop/5` calls; frame inspection
stays 34,000, receipt listener calls stay 20,000 and cleanup requests stay
zero. Watching the nearest transaction directly removes the separate
nesting enumeration while retaining every ownership boundary. The 10,000-atom
load stays 591,623 inferences and three receipt requests. Profiled counts
are 1,101,602 to 1,073,712 for drop and 775,368 to 775,475 for load; profile
overhead differs and is not used as an unprofiled cost.

The same-path engine boot stays 296,185 inferences in three processes.
C boot changes 457,890 to 457,910, also three identical processes per arm,
with 21 governed artifacts in both. Its instruction minima are 1,249,000,372
and 1,249,269,201, both inside the existing 0.1% band around 1,248,231,076.
The changed receipt predicate inventory is isolated; the whole-process
boundary, fixture and instruction price stay fixed. The controls are
`ai-tmp/ai-receipts-frame-cost-control.py` and
`ai-tmp/ai-receipts-frame-cost-{before,after}.{json,log}`. The remaining
point-counter and relative-ceiling checks follow this runtime change.

C boot retains its 457,890 inference pin: the isolated 457,910 reading is
inside the existing allowance of 32. The other boot prices, margins and
the 21-artifact fixture also stay. This is a measured movement inside the
published comparison rule, not a new boot re-pin.
