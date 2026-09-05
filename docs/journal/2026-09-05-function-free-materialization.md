# Function-free load-time materialization
Goal: answer repeated finite function-free derivations from one preprocessed relation while preserving every answer occurrence.
Constraint: retain source equations and the ordinary compiled program, including its behaviour outside the admitted fragment.

## 2026-09-05

Tried: a completed public `Space.eval` call for a chain's first and last node after source loading. At 16, 32, 64, 128 and 256 edges, the second query costs 525, 877, 1581, 2989 and 5805 inferences. Every answer bag contains one `True`. The exact curve is `173 + 22n`; source loading alone does not compute the ordinary equation's relation. The unsupported triage pointer to tagged `algebra.py` names a separate surface. The original routing assessment concerns ordinary function-free equations, which this witness exercises.

Research: Motik, Nenov, Piro, Horrocks and Olteanu, *Parallel Materialisation of Datalog Programs in Centralised, Main-Memory RDF Systems*, AAAI 2014, algorithm 1 and section 4, computes a program's consequences once. Green, Karvounarakis and Tannen, *Provenance Semirings*, PODS 2007, distinguishes alternative derivations by addition and joint premises by multiplication. The existing `metta-on-mork` routing compiler at `a5f312063529ab7d8df92275c83b288d493edb7e`, `src/program/mod.rs:compile_routing`, supplies the function-free, range-restricted, co-materialized-callee gate. Its counted-table differential exposed catchall and equation-introspection failures. Retaining original source and compiled clauses avoids those changes of representation.

Decided before implementation: materialize flat immutable relational inputs, nested native matches and a terminal co-admitted function call. Range restriction grounds every output from premises. Build the finite grounded call graph and require it to be acyclic, including unproductive calls. Reverse topological evaluation adds duplicate premise proofs and multiplies callee counts. Arbitrary precision integer counts preserve bags. A guarded first compiled clause selects an immutable indexed table; original clauses remain beneath it. Generation stamps detect data, definitions, declarations, translation rules and module recycling. Reader pins retain a retired table until its final active query exits. Snapshot construction and transactional publication prevent partial relations.

Current complexity: a one-answer chain query is `Theta(n)` every time. Target complexity: after `Theta(n^2)` materialization and storage for the chain's full relation, a fixed-arity ground query is `Theta(1 + output occurrences)`. Enumerating the whole relation still costs its output size. Bag cycles can have infinitely many proofs, so a finite set fixed point is not an admissible substitute. The ground DAG gate declines such programs before evaluation, preserving the original query bounds and errors. General cyclic bag materialization has no finite-output class improvement to claim.

Verification design: `function_free_materialization` compares sorted bags against a second identical space with its derived relation discarded. It covers duplicate equations and facts, multiple paths, open and ground queries, repeated variables, ground heads, nested matches, inadmissible stored variables and compounds, typed/evaluated/unbound templates, mutation, rollback and source-prefix visibility. A three-size query growth assertion must fail before implementation.

Rejected: global compile-dispatch handlers, because an already-compiled caller would retain its direct call until rebuilt. A guarded clause at the compiled predicate covers those callers and avoids pricing unrelated dispatches. The wrapper is a derived artifact with a recorded clause reference, so invalidation removes it and exposes the retained original clauses.

## 2026-09-05: source visibility and relation ownership

Superseded: the guarded-first-clause decision above. Proof search and effect analysis inspect original compiled clauses. A synthetic clause would change what they inspect. A probe of SWI's `wrap_predicate` preserved `clause/3`, but the wrapper survived both transaction rollback and `abolish/1`; the old materialized answer remained callable after the underlying predicate was removed. That ownership cannot follow transactional space life.

Decided: retain every compiled source clause and use the existing `seam:dispatch_call/4` boundary for query expressions. Source compilation modes `enabled` and `disabled` must retain ordinary calls. The first guarded-only implementation preserved source runnables but missed the Python library's direct `translate_expr` entry point, which has no mode value. Both direct expression translation and guarded runnables need admission; tracked equations, untracked clauses and nested lambda compilation keep ordinary bodies.

Tried: an eager later equation `(= (proof-later $x $y) (match &self (start $x) (proof-reach $x $y)))` after loading a four-edge chain. Retaining a materialized call in its body produced a complete proof at depths 2 and 4 with only one rule and one fact. The original path was incomplete at both depths and had five rules and five facts at depth 20. `test_a_later_retained_caller_preserves_bounded_derivations` records that differential. Restricting the seam to query translation restores the original tree. Variable names in separate proofs are alpha-normalized by the test.

Rejected: dynamic reader pin counters. An outer transaction sees a snapshot of a counter, so it can reclaim a relation another thread pinned after that snapshot began. Making transactional clear a no-op avoided that race but left a live materialization after committed clear and even after committed release. The review witnesses observed a retained snapshot, lifetime row and handler after the space identity had gone. The replacement stores one immutable result descriptor per complete ground call. Reading that descriptor copies it into the query's ordinary term lifetime; transactional row deletion can then reclaim all database state immediately while an active reader finishes its duplicate count.

Decided: descriptors are `none`, `one(Value, ProofCount)`, or `original`. A ground call with multiple distinct values stores `original`, because copying all values before its first answer would change constant prefix startup to linear startup. Open inputs, attributed outputs, active reduction fuel, non-boolean algebras and retained clauses also use compiled execution. One static seam avoids a second transaction race in reference-counted installation of shared function handlers.

Tried: the first differential utility loaded its reference after the tested space. That could change global function metadata and invalidate a multi-function materialization before comparison. The utility now refreshes the tested space after loading the reference, and admitted fixtures assert the expected result descriptor. The terminal-callee fixture proves multiplication: two matching seed facts and two callee proofs produce four occurrences of `yes`.

Verification: `run_tests(function_free_materialization)` passes 26 cases, including 24 generated acyclic bags and every ordered pair of their six nodes, duplicate facts and equations, multiple paths, ground and open queries, typed and evaluated refusal cases, attributed variables, source prefixes, rollback, committed clear/release, a reader that starts after another transaction begins, and a many-value prefix growth gate. The query growth gate uses 32, 128 and 512 edges. Logs are `ai-tmp/ai-materialization-admission-prolog.log` and its separate status file, status 0. This precedes the final public-entry and transaction-load changes and must be rerun on their final state.

Planted controls: removing duplicate replay fails both bag fixtures with `[true] == [true,true,true]` and `[yes] == [yes,yes,yes,yes]`; `ai-tmp/ai-materialization-duplicate-loss-control.log`, status 1. Disabling construction and lookup fails the query-growth gate at `3283 < 1171*1.5` and `11731 < 3283*1.5`; `ai-tmp/ai-materialization-no-construction-control.log`, status 1. Both controls run in isolated processes and modify no repository source.

## 2026-09-05: preprocessing cost and load boundaries

Superseded: the earlier `Theta(n^2)` preprocessing time claim. SWI's list-based `top_sort/2` scans vertices while removing each edge and was the dominant cost on the quadratic ground-call graph. The original ten-test gate reached its final 512-edge case and continued running after the smaller cases passed. No timeout or forced termination was applied. CPython 3.13.0 `graphlib.TopologicalSorter.done` keeps predecessor counts in an index and enqueues a node when its last predecessor completes. The materializer follows that scheduler with SWI AVL associations and a difference-list queue. Edge updates cost `O(log V)` and queue insertion costs `O(1)`. Source: `https://github.com/python/cpython/blob/v3.13.0/Lib/graphlib.py`.

Current complexity: the two-rule chain has one answer and spends `Theta(n)` per completed query. Target complexity: build its `Theta(n^2)` ground graph in `O(n^2 log n)` time and `Theta(n^2)` stored descriptors, then spend expected `O(1 + output size)` on an admitted ground query. For `q=n^2`, the complete workload changes from `Theta(n^3)` to `O(n^2 log n + q)`, including construction. These are data-complexity statements for fixed signatures and arities. Generation validation walks those program properties. Counts use arbitrary precision arithmetic; the chain's count is one, so the sweep does not hide increasing integer bit cost.

Tried: the first public `Space.eval` sweep paid for materialization but retained linear query execution. At 16, 32, 64, 128 and 256 edges, warmed queries spent 527, 879, 1583, 2991 and 5809 inferences. Construction-disabled queries followed the same curve. The combined materialized totals were 206512, 1152683, 7493522, 53240792 and 398648926 inferences. This is a failed optimization measurement, not evidence of the target class. The missing direct-expression admission is recorded above; `test_public_eval_reuses_the_loaded_ground_relation` now gates that public entry point. The failed sweep artifacts remain under `ai-tmp/ai-materialization-sweep-*` pending the distinctly named final sweep.

Tried: a fresh 64-edge file load under inference bounds of 20000, 50000 and 100000. Each raised its inference-limit error and left only the pre-existing `(kept value)` atom. `test_a_bounded_first_load_rolls_back_materialization_preprocessing` fixes the 50000 case, and `test_a_bounded_reload_restores_the_previous_materialized_bag` checks failed replacement. The public non-fast subset passes four tests with one fast-cache test deselected; `ai-tmp/ai-materialization-python-atomic.log`, status 0.

Found: stored equations do not identify whether `&self` was bound by the reader or supplied literally through native `metta_add_atom`. The reader compiles the receiving space; native admission preserves the literal engine root. `compiled_local_matches/2` therefore validates the compiled clause's recorded source, rather than inferring local semantics from the stored atom. A late externally asserted parent is likewise checked by `snapshot_current/3`; its planted differential initially returned one proof instead of the inherited two and now passes.

Found: fast-cache restore already loses that reader/native distinction on the clean rebased source. A reader-loaded duplicate chain answers two occurrences before save and none after restore because the restored body calls `match('&self',...)`. The clean baseline reproduces this independently; the row-restoration code was authored in `d2279ea32`. The image needs compiled-source provenance to preserve both ingress meanings. Its repair and transaction-load stamp validation are integration obligations, not grounds for weakening the roundtrip test.

Open: finish the public dispatch gate, atomic transaction-load publication and fast-image provenance repair; rerun the public amortized sweep with separate load/query CPU and inference columns, the full differential, and both planted controls on the final functional snapshot. Record the original scheduler gate's exact eventual outcome.

## 2026-09-05, transactional publication design

Rejected: rebuilding after a file replacement commits. Preparation can fail or exhaust an inference budget, so it belongs inside the source load's rollback boundary. A runtime probe found predicate generations of 3323 before a transaction, 3325 inside it and 3324 after commit. The SWI reference manual's *Impact of transactions* also documents that an external modification can change a reported generation without making that change visible inside a transaction. A captured numeric generation alone cannot certify the prepared relation.

Decided before this extension: capture complete ordered clause-reference receipts in the same snapshot as the relation. These are an optimistic read set, like a transaction's dependency validation. For a normal load, compare the receipt in a fresh snapshot bracketed by outside generation reads before publication. For a transactional load, publish the receipt with the relation before commit, then validate and promote it to ordinary generation stamps on the first query after commit. Added clauses must invalidate a receipt as well as erased clauses. Module life and parent status are checked separately. No derivation moves past commit and no mutation listener is added.

Current complexity: each chain query traverses `Theta(n)` edges. Target: `O(n^2 log n)` preparation and `O(n^2)` relation storage, one `O(n)` receipt validation after a transactional commit, then `O(1 + output occurrences)` per fixed-arity query. With `q = n^2`, the total target is `O(n^2 log n + q)` instead of `Theta(q n)`. Both the first query and all `q` queries must be measured, alongside source preparation, so a warmed plateau cannot conceal the total cost.

Verified: all four transaction admission tests failed before the receipt extension. After it, all 30 then-present materialization tests passed. The concurrent witness starts a transaction, adds a fact outside its snapshot, then lets it prepare and commit the old relation. First lookup detects the new clause and answers the current two-occurrence bag through ordinary execution. A planted `receipt_current/3` that always succeeds makes both addition tests return `[true]` instead of `[true,true]`; the control exits 1. The normal suite exits 0. Exact logs are `query-a20256a5-materialization-transaction-{red,green}.log` and `query-a20256a5-materialization-receipt-mutant.log` under `ai-tmp/`.

Verified integration: the existing layering walk reported the new subsystem's ten dependency pairs and failed two tests before its contract was updated. Each pair now names its source, dispatch, policy, lifetime or support role, and the declared mutually recursive component includes `materialize`. The seven layering tests, including planted undeclared edges and stale permissions, pass. The gate and export checks are unchanged.

## 2026-09-05: prepare the physical lookup index

Tried: the repaired public-entry sweep completes every bag correctly and has 288 warmed inferences from 16 through 512 edges. Its first-query CPU still grows from 0.000456 seconds at 32 edges to 0.001282, 0.005142, 0.023433 and 0.084821 seconds at 64, 128, 256 and 512. The unchanged first-query inference count hid SWI's clause-index construction in C. The SWI 10.0.0 manual's *Just-in-time clause indexing* and `src/pl-index.c:first_clause_guarded` specify construction on first call. The two-rule chain's relation contains quadratic rows, so this is quadratic cold-query work.

Rejected: priming the dynamic row predicate inside publication. It prepares the initial image, but an outer transaction can remove the prepared index after its last opportunity to prime it. `ai-tmp/ai-materialization-jiti-transactions.pl` primes a 101000-row predicate inside a transaction; deleting 100000 rows and priming the remainder still leaves no index after commit. Its next lookup spends 0.010642 CPU seconds and only 11 inferences. Rolling back a 500000-row insertion similarly removes the index after cleanup. Priming after an owned transaction cannot cover arbitrary enclosing transactions. The source is [SWI 10.0.0 `pl-index.c`](https://github.com/SWI-Prolog/swipl-devel/blob/V10.0.0/src/pl-index.c), especially `deleteActiveClauseFromIndexes` and `fill_clause_index`.

Decided before the representation change: build one immutable SWI trie for each image, before acquiring the publication mutex. The trie maps a complete ground call to its existing singleton result descriptor. The snapshot's token becomes its blob handle. Dynamic snapshot and signature facts own that handle transactionally; publication never mutates a visible trie and removal never explicitly destroys one. Source rollback therefore restores the same usable index. A lookup copies one descriptor, retaining the existing duplicate enumerator and multiple-value refusal. Images have independent indexes, so adding or clearing another image cannot rebuild this one's lookup structure.

Research: SWI 10.0.0 [`src/pl-trie.c:release_trie_ref`](https://github.com/SWI-Prolog/swipl-devel/blob/V10.0.0/src/pl-trie.c#L155-L164) destroys trie nodes when atom garbage collection releases the blob. `trie_lookup/3` follows an already constructed term path. The manual documents variant-key semantics and atom-GC ownership. The lifetime probe verifies committed clear, rollback, and a reader that finishes three duplicates after its image is removed. A separate Janus query-boundary probe publishes and retracts a trie, then collects in a subsequent query: live trie counts are zero before and zero after. The earlier single-query probe retained clause/query roots; it did not establish a leak. Reclamation follows ordinary clause and atom lifetime, rather than an eager-destruction promise.

Current cold complexity: `Theta(n^2)` physical index work on the first ground query, invisible to the inference counter. Target: retain `O(n^2 log n)` preparation and `O(n^2)` image storage, with the physical index included in preparation. An admitted lookup costs the key and copied descriptor sizes plus output occurrences; these sizes are fixed in the chain family. A transactional load also pays its one `O(n)` clause receipt validation on its first committed query. The complete `q=n^2` workload remains `O(n^2 log n + q)`, compared with original `Theta(n^3)`. The final sweep must report load, cold query, warmed query and total CPU as well as inferences.

## 2026-09-05: outer transaction ownership

Verified: the immutable-trie differential passes 35 Prolog cases and nine public Python cases. A global live-trie count was an invalid ownership assertion: the combined process reported 24 instead of the expected 23, while the isolated case passed. The replacement returns only printed identities, collects after a separate Janus query boundary, and checks the particular retired image. A live image remains usable, a rolled-back replacement disappears, and a released image disappears. Exact artifacts are `ai-tmp/ai-materialization-final-trie-prolog.log` and `ai-tmp/ai-materialization-identity-python.log`, both status 0.

Found: locking the publication body does not serialize an enclosing transaction's commit. Two transactions can each publish an image from their old view and leave two images. A transaction that builds before another thread clears or releases can publish after that lifetime ends. The reverse ordering also leaks: an old transaction's clear cannot see an image published after its snapshot began. Six explicit differentials reproduce these cases in `ai-tmp/ai-materialization-owned-publication-red.log`, status 1. The returned bags still agree; the lost invariant is ownership of the quadratic image.

Research: [SWI 10.0.0 `transaction/3`](https://github.com/SWI-Prolog/swipl-devel/blob/V10.0.0/src/pl-transaction.c#L632-L650) changes to the current global view, runs its constraint, and commits while holding the supplied mutex. The nested branch at lines 562–563 simply calls the constraint; it acquires no mutex and never changes to a fresh view. Nested `bulk(true)` predicate events can run before the outer transaction returns and therefore supply no outer commit hook. This is an optimistic compare-and-swap publication problem, and the documented outer constraint is its matching mechanism.

Decided before the repair: the existing source-replacement and public user-transaction boundaries own `materialization_transaction/1`. Its body prepares relations and records only touched spaces. Immediately before entering the commit constraint it captures each touched space's final candidate image. The constraint revalidates that candidate against current source and lifetime receipts, removes every globally visible image for that space, and publishes at most one valid replacement. The mutex remains held through commit. Failure or throw rolls back both source and image changes. A wrapper inside an unmanaged outer SWI transaction does not claim to own that commit; construction declines there and ordinary queries retain their original bag. First source loads remain outside a whole-load transaction, preserving source visibility to worker threads.

Verified design: `ai-tmp/ai-materialization-commit-prototype.pl` checks overlapping publication, both clear orderings, outer and nested rollback, and unmanaged-transaction refusal. All five cases pass with status 0. The constraint walks only the touched spaces and their source receipts. Current and target query classes remain unchanged; one additional `O(n)` validation is part of a transactional chain load's `O(n^2 log n)` preparation. The unmanaged clear/release resource path is still under investigation and is not covered by the construction gate alone.

Decided before unmanaged-lifetime repair: each image retains one exact stored-equation clause reference captured in its build snapshot. SWI's `erase` event for that source owner retires the exact trie token when clause collection proves the source can never be read again. `pl-proc.c:cleanDefinition` announces the event before unlinking; `DBREF_CLAUSE` delays allocation release rather than this event. `pl-gc.c:markPredicatesInEnvironments` protects clauses visible to active transaction start generations. These choices follow [SWI 10.1.13 source](https://github.com/SWI-Prolog/swipl-devel/blob/V10.1.13/src/pl-proc.c#L1849-L1850), with the matching `pl-dbref.c` and `pl-gc.c` release files. An old transaction therefore postpones owner collection until any image it could publish has settled. This adds one owner row per image, rather than one per premise.

Rejected: retiring the owner through ordinary dynamic writes in the erase callback's current transaction. With synchronous clause collection, callback cleanup can roll back after the one-time source-erasure event has already happened. A new Prolog engine supplies independent transaction visibility; acquiring the mutex in that child deadlocks when the caller already holds it. The verified protocol acquires the publication mutex in the current engine, creates a synchronous child engine only when the callback is transactional, and performs exact-token retirement there without reacquiring the mutex. `setup_call_cleanup` destroys the child on success or exception. No worker, deferred query sweep or source reconstruction is required.

Verified design: `ai-tmp/ai-swi-erase-owner.pl` passes nine cases covering retained source references, rollback, an active older transaction, stale-view clear, collection inside rollback, collection while the parent holds the mutex, an independent newer image, an owner hidden from the callback's transaction view, and cleanup after an exception. Three engine-level resource regressions fail before the repair in `ai-tmp/ai-materialization-source-owner-red.log`, status 1. Nontransactional publication also starts its assertion transaction before receipt validation; unchanged numeric generations bracket that transaction's read, closing the gap in which an owner could otherwise be collected before publication began.

Verified: the six owned-publication regressions pass in `ai-tmp/ai-materialization-owned-publication-green.log`, status 0. The three native source-owner cleanup regressions pass in `ai-tmp/ai-materialization-source-owner-green.log`, status 0, including synchronous collection inside a rolling-back transaction while its parent holds the publication mutex. The tracked suite additionally exercises an older transaction that postpones owner collection and a collector whose snapshot predates the image ownership row.

Decided for final measurement: `extensions/python/benchmarks/query_planning_materialization.py` runs each construction control in a separate process. It measures direct source, text replacement and fast-cache replacement, and checks every timed bag. For each size, preparation and `q=n*n` queries are paid together; the first query is included in that query count. Preparation, first query, complete query workload, total workload and an extra warmed query each report SWI inferences, SWI CPU and complete-process CPU. Trie rows and bytes are observed only after the cold query. Temporary source and cache files are removed when the fixture closes. Shared source fingerprints before and after each process reject concurrent source changes.

Research: [CPython 3.14.0 `time.process_time`](https://github.com/python/cpython/blob/v3.14.0/Doc/library/time.rst) measures process-wide user plus system CPU. [SWI `statistics/2`](https://www.swi-prolog.org/pldoc/man?predicate=statistics/2) documents its calling-thread user CPU and, since 9.1.9, completed child threads joined by that caller. SWI inference counts exclude native-call internals and Python work. Both CPU scopes are therefore reported instead of treating a flat Prolog counter as proof of physical lookup cost.

Verified: the complete 46-case owner differential initially passed 44 cases and failed two post-collection assertions. Running with the background collector stopped fixed stale-clear collection; SWI's explicit clause collector returns when another collector owns the global collection flag. The hidden-owner test still failed because its generation tick was inside the collector transaction. A local transaction generation cannot make the just-erased source older than the global collection start. The tests now stop and join background GC at the asserted checkpoint and advance the hidden owner's global generation before sending its collector message. Production cleanup did not change. All 46 cases pass in `ai-tmp/ai-materialization-owner-final-green.log`, status 0. A planted owner lookup before entering the fresh cleanup engine fails the hidden-owner assertion, status 1 in `ai-tmp/ai-materialization-hidden-owner-control.log`.

Found: a second source addition through nested public transactions diverges while calling the transaction-owner marker. The new pure-Prolog regression `nested_source_transactions_finish_and_restore_the_rolled_back_bag` reaches its 100000-inference limit before the inner addition returns; `ai-tmp/ai-materialization-nested-source-red.log`, status 1. The public equivalent also raises `metta.errors.InferenceLimitError: the 100000 inference limit was reached` when bounded. The unbounded original pytest and scratch processes were explicitly terminated with SIGKILL after diagnosis; their separate status files both record 137. This is an implementation defect, not a harness failure.

Superseded outcome: the original list-scheduler ten-case run did not complete its last 512-edge test. After 7540 seconds it was explicitly terminated as a divergent reproduction, with process status 137 in `ai-tmp/ai-materialization-after.status`. Nine cases passed before that last test. The indexed scheduler's full 46-case run completes in about 14 seconds; the original run is failed evidence and is not counted as a passing gate. Subsequent suites use the explicitly requested 60-second containment and all other processes use 290 seconds.

Root cause: the flush admission conjunction used `current_transaction(_), \+ materialization_transaction_owner`. When an owned transaction made the second goal fail, Prolog backtracked into the transaction enumerator. SWI 10.1.13 `pl-transaction.c:current_transaction/1` repeats the same ancestor on `FRG_REDO` at lines 721-745. Testing existence with `once(current_transaction(_))` avoids that enumerator path. The transaction owner remains a thread-local fact. A backtrackable global marker was rejected because the marker was not the cause. The bounded public reproducer now returns three `True` occurrences inside the inner transaction and two after the outer rollback, status 0; the full native/public gates follow this change.

The exact repaired public output is recorded in `ai-tmp/query-a20256a5-nested-fixed.log` with separate status 0. The enumerator branch is pinned to [SWI 10.1.13 `pl-transaction.c`](https://github.com/SWI-Prolog/swipl-devel/blob/V10.1.13/src/pl-transaction.c#L721-L745); it was read alongside that witness before recording the cause.

## 2026-09-05: the divergent gate run, attributed

Tried: the shipped tree's `suites/spaces/materialization.plt` under the 60-second
containment -> 49 tests pass in 19.6 seconds, exit 0. The 512-edge growth gate
`a_ground_chain_query_reuses_the_load_time_relation` is 18.2 of those seconds.

Found: planting `library(ugraphs)` `top_sort/2` over `indexed_topological_order/2`
with `wrap_predicate/4`, and changing nothing else, stops the same suite at
`[28/49] a_ground_chain_query_reuses_the_load_time_relation` and it does not
finish inside 60 seconds. Two stack samples ten seconds apart, taken by an
`alarm/4` goal running on top of the interrupted one, both read
`ugraphs:incr_list/4` under `ugraphs:count_edges/4` at ugraphs.pl:476, under
`top_sort/2`, under `derive_ground_bags/2` at materialize.pl:352, at frame
depths 21,634 then 43,683: the in-degree count is still walking. The goal burns
552,299,187 inferences in 35 seconds without finishing one 512-edge build. This
is the cause of the killed run recorded above, whose last named goal was that
test: `count_edges/4` calls `incr_list/4` once per edge and `incr_list/4` walks
the whole vertex list, so it is `O(V*E)`, and the two-rule chain's ground call
graph has `V = E = Theta(n^2)`, giving `Theta(n^4)`.

Measured, plain source load of the chain, CPU seconds, indexed scheduler against
planted `top_sort/2`: 0.0054/0.0230 at 16, 0.0142/0.1471 at 32, 0.0618/1.7946 at
64 and 0.2561/24.4322 at 128. The planted arm's doubling factors are 6.4, 12.2
and 13.6, consistent with `n^4`; extrapolated to 512 that is about 6,250 seconds
for the last case alone, against the 7,540 seconds the killed process ran. At
512 the shipped scheduler builds in 5.06 CPU seconds and the planted one is
still running when SIGKILL arrives at 60. Logs: `ai-tmp/qp-finish/scheduler-*.log`,
`ai-tmp/qp-finish/mat-list-scheduler-red.log`, `ai-tmp/qp-finish/scheduler-stack.log`.

Correction to the note above: the killed process was not left unattributed for
want of evidence. Its cause is reproducible by planting the scheduler it ran
with. The `current_transaction/1` enumerator defect remains a separate, also
reproduced failure.

## 2026-09-05: sparse dispatch ownership

Found: the full engine gate fails the existing context-read assertion with `40==0` and the native dispatch ceiling with `38.0015<30`. The unconditional materialization seam reads planning mode and module context for every unrelated call. The former direct dispatch measured about 29 inferences. These are integration regressions, not a reason to change the existing ceilings. The red gate is `ai-tmp/query-a20256a5-final-engine.log`, status 1.

Decided before the repair: follow the ground function heads in `lib_memo:memo_install_dispatch_handler/1`, introduced in `9e7d5dc2cad810940e5386d52636ac6946df279d`. Each image owns one exact seam clause reference per admitted signature. Publication and removal include these references in the image transaction. Unlike the previously rejected shared-handler reference counts, images never share a mutable owner count. An old transaction cannot erase a newer image's handler by function name. The existing outer commit constraint and source-owner cleanup retire exact image tokens. The selected handler still checks the calling module and permits only guarded or direct query expressions, preserving compiled source bodies.

Current and target materialization classes remain unchanged. The repair restores the existing unrelated-call ceiling and prevents the number of other images from entering that path. The new dispatch differential is written before changing publication; it covers 0, 1, 16 and 64 unrelated images, same-name images in distinct spaces, exact removal and rollback. The full owner, concurrency and source-bag differential remains required.

## 2026-09-05: historical failure attribution and static reconsult

Correction: the killed ten-case process's last named goal was `function_free_materialization:a_ground_chain_query_reuses_the_load_time_relation`. It started before the owned-transaction marker existed. Its loaded source bytes and Prolog stack were not captured, so its cause cannot be confirmed. The old list scheduler's cost is consistent with that chronology, but the later `current_transaction/1` enumerator defect is a separate reproduced failure. The old process's status remains 137, and no result from it is counted as passing evidence.

Rejected: the optional native-predicate prefilter in `source_owner_erased/1`. Dynamic lifetime probes passed, including a thousand unrelated clause references, but they did not establish static reconsult safety. The full engine gate and isolated `lib_memo.plt` and `lib_strategy.plt` loads crash with status -11 in `$get_clause_attribute`, displaying a `<garbage_collected>` module. An initialization containing only the normal engine boot and `consult(lib_memo.pl)` reproduces the same failure. During these erase events, predicate metadata can already have been reclaimed. Identity-only owner lookup is restored. Outside a transaction it uses the indexed owner table; inside a transaction, even an apparently unrelated reference may require the fresh cleanup engine because the caller's old view can hide its owner row. Exact diagnostics are `ai-tmp/ai-erased-reference-library-initialization-red.log` and its status file.

## 2026-09-05: the reconsult segfault, reproduced from the committed source

Tried: `swipl -g true -t halt` over a file that consults the engine and then
`consult('lib/lib_memo/lib_memo.pl')`, with `engine/materialize.pl` at commit
`988fb647` -> SIGSEGV, status 139, in `system:$get_clause_attribute/3` under
`materialize:source_owner_erased/1` under `system:$fixup_reconsult/1`. Planting
only the `blob/2` plus `clause_property/2` prefilter into the current source
reproduces it three times out of three, and the current source without that
prefilter exits 0. So the prefilter alone is the cause, not any other part of
the committed file. Restoring the same two goals through `wrap_predicate/4`
instead does NOT reproduce it; an interposed wrapper frame changes the outcome
and why is not established. Logs:
`ai-tmp/qp-finish/reconsult-prefilter-only-red-{1,2,3}.log`,
`ai-tmp/qp-finish/reconsult-headsource-red.log`, `ai-tmp/qp-finish/reconsult-green.log`.

Found: dropping the whole prefilter also dropped a resource guarantee, and the
test that held it was deleted rather than repaired. Measured which operations
reach the `erase` channel at all: `erase/1` on a clause reference fires nothing,
`erase/1` on a recorded reference fires immediately, and clause collection fires
once per physically removed clause. The deleted test's real content was
therefore the recorded reference: one erase of a record inside a transaction,
which the identity-only callback answers by creating a cleanup engine.

Decided: keep `blob(Reference, clause)` and drop only `clause_property/2`. An
owner is always a clause of a space's storage predicate, so the type test is
exact for records, costs one builtin, and never asks the reference about its
predicate, which is where SWI crashes. `an_unrelated_record_erasure_creates_no_cleanup_engine`
replaces the deleted test with the half that is still true; it fails `1==0`
without the guard.

Open, with its price: a clause collection that runs inside a transaction still
creates one cleanup engine per collected clause, because the caller's view can
hide a newer image's owner row. Measured with `gc_thread` false, 5,000 collected
clauses inside a transaction cost 331 engines and 0.0030 CPU seconds against
0.00033 with the callback disabled. `gc_thread` is true by default, so ordinary
collection runs on a thread with no transaction and takes the indexed path.
Revisit if a workload collects inside transactions: a non-transactional owner
index, keyed by the clause reference in a store transactions do not govern,
would make the membership test exact without a fresh view.

## 2026-09-05: finalize each completed load once

Found: a wrapped `build_materialization/7` probe records one construction for plain source, a first text load and a first fast load, but two for text and fast replacements. The source-final flush builds before `run_source_repairs/1`; the repair then invalidates that image and the existing final hook builds again. `ai-tmp/ai-materialization-load-build-count.log` records counts `1, 1, 2, 0, 1, 2` for direct run, first text load, text replacement, fast save, first fast load and fast replacement respectively, with status 0. The full 12-process sweep completed and retained unchanged source hashes, but it is a checkpoint preceding this once-at-load repair and the sparse-dispatch repair.

Design before the repair: this is the same batching boundary as the loader's existing deferred support repairs in commit `0446cb05a8b09358dea492dc09d7e58aa9b9d9cb`. Database deferred constraints, compiler final passes, reactive notification batches and transaction commit callbacks all separate intermediate observations from final reconciliation. Here an explicit `with_source_materialization_batch/3` owns preparation, final materialization and source publication. Source-final requests collect distinct spaces under a thread-local batch; runnable-prefix requests stay eager. After preparation and dependency repair, the active batch marker is removed and each queued space is materialized once. Nested batches forward their final requests into the restored outer batch, including fast-image children.

Failure ownership: the pending-space rows survive through final construction and source publication. If a later child build or publication throws after another image was installed, cleanup discards every pending space before removing those rows. First loads retain their existing nontransactional source journal and worker visibility; replacement loads retain their existing owned transaction. No derivation moves after commit. The cleanup shape follows SWI's [`setup_call_catcher_cleanup/4`](https://github.com/SWI-Prolog/swipl-devel/blob/V10.1.13/man/builtin.doc) resource lifetime contract. A named `library(prolog_wrap)` wrapper counts actual successful construction only inside the differential test and is removed on every outcome.

Complexity: the admitted chain's preparation remains `O(n^2 log n)` and the paid workload remains `O(n^2 log n + q)`, compared with original `Theta(q n)`. Removing a second identical preparation does not establish a further complexity-class change. It fulfills the explicit once-at-load requirement; the final phase-separated sweep must remeasure the changed load paths. Correctness gates cover exact duplicate bags, one construction per completed plain/text/fast load, intermediate source prefixes, nested batches, partial finalization failure and publication failure.

## 2026-09-05: one preparation per completed load

Found: the once-at-load requirement recorded above was designed and not built.
`with_source_materialization_batch/3` did not exist, and a wrapped
`build_materialization/7` counter still reads 1, 1, 2, 0, 1, 2 for direct run,
first text load, text replacement, fast save, first fast load and fast
replacement. Two backtraces at the second build show the first from
`flush_source_materialization/0` inside `metta_host_run_source/4`, and the
second from `materialize_source/1` in `with_source_load/3`, after
`run_source_repairs/1`. Instrumenting the repair set separates the two shapes
the earlier pytest could not: a load that defines a self-recursive function
records `repairs ['materialized-reach']` and rebuilds, while a load of a name
another space already defined records `repairs []` and does not. The committed
pytest used the second shape, so it asserted 1 and passed with the defect
present.

Decided: `with_source_materialization_batch(Space, Prepare, Publish)` owns
preparation, final materialization and publication in `with_source_load/3`. A
flush inside the batch queues its space instead of building; the batch closes
before publication and materializes each queued space once; a nested load
forwards its queue to the enclosing batch, which is what covers a fast image's
child spaces, none of which the caller names. Deferring is invisible inside the
file because every lookup revalidates its stamp and falls back to the retained
compiled clauses. Cleanup discards every queued space when the load does not
exit cleanly.

Verified: the six load paths now read 1, 1, 1, 0, 1, 1.
`test_a_reloaded_program_builds_its_relation_once` uses function names no other
case defines, so the repair fires; it fails `assert 2 == 1` with the loader hunk
reverted and passes with it.

## 2026-09-05: preparation is a declared choice

Found: preparation is quadratic in the derived relation and a load pays it
whether or not the program ever asks. Loading the two-rule chain costs 6,181
inferences and 0.0017 CPU seconds at 512 edges without construction, and
78,622,783 inferences and 7.26 CPU seconds with it: 4,243 times the CPU. Load
inferences at 32, 64, 128, 256 and 512 edges are 258,626, 1,023,717, 4,290,475,
18,291,605 and 78,622,783 against 3,410, 3,493, 3,877, 4,645 and 6,181. A
completed ground query costs 724 inferences either way against 1,176, 1,880,
3,288, 6,104 and 11,736, so the saving per query is 11,012 at 512 edges and the
break-even is about 7,100 queries there and 1,670 at 128. Command:
`swipl -g main -t halt ai-tmp/qp-finish/load-cost.pl -- extensions`, with
`MATERIALIZE_MODE` unset and `=control`.

Decided: gate construction on the `materialize-source-relations` pragma, off
unless a program asks. A load cannot know how many queries follow, and the
existing admission gate places no bound on the derived relation, so a knowledge
base with a transitive rule over a few thousand facts would spend the load in
derivation. The pragma is the engine's existing per-run declaration registry,
the same shape `verify-specializations` and `verify-discharges` use. Both
materialization suites and the ch18 cases declare it for their own scope and
restore the unset value, and `preparation_is_declared_rather_than_the_default`
pins the default in each surface.

Rejected: a work budget that declines construction past a fixed number of ground
rules. It keeps small programs automatic, but it picks a constant, it makes
behaviour discontinuous in the data, and it still pays the budget on every
admitted load that ends up declining. Revisit if a measured workload wants
automatic preparation: the budget belongs on the `findnsols/4` that enumerates
ground rules, where it bounds the enumeration rather than checking after it.

Rejected: leaving construction on by default and documenting the cost. The load
regression is unbounded in the relation size, which is the shape of the
7,540-second run this thread opened with.

## 2026-09-05: an index is collected in one round or two

Found: `test_a_rolled_back_index_is_collected_while_the_live_index_answers` and
`test_a_released_index_is_collected_after_its_query_boundary` were intermittent,
three of four whole-file runs red for the first and about one in eight for the
second. Neither is a leak. `garbage_collect_clauses/0` returns immediately when
the collector thread already owns the collection flag, so the clauses that hold
a retired index survive the call; stopping and joining that thread first, which
is what the Prolog suite's `collect_materialization_owners/0` already does, makes
the first case deterministic. The second needs a second round: over 25 released
images the retired index disappeared after one or two collections and the live
trie population returned to 22 every time, so the atom pass that reclaims the
blob can already have run when the clause pass drops the last reference to it.
The helper now collects to a fixed point, bounded at four rounds; a retained root
survives all of them. Ten consecutive whole-file runs are green.

## 2026-09-05: the same collection round in the Prolog suite, and one crash

Found by running the Prolog suite twenty times rather than once:
`an_unmanaged_stale_clear_retires_its_image_at_source_collection` failed its
post-collection assertion in one of the twenty. It is the defect above one level
down. `collect_materialization_owners/0` already stops and joins the collector,
which is the half that makes the assertion possible at all, but it then ran a
single clause and atom pass. It now runs four. Twenty-five consecutive
whole-suite runs are green against one failure in the twenty before.

Recorded unexplained: one run in that same period died with signal 11 during
`an_unmanaged_stale_release_retires_its_image_at_source_collection`. The C stack
is inside `__pthread_clockjoin_ex` under the signal handler, which is the join
`set_prolog_gc_thread(false)` performs on the clause collector, and the Prolog
stack printed empty. It has not recurred in 30 isolated runs of the two
unmanaged cases, 11 whole-suite runs before the collector change or 25 after, at
loadavg between 29 and 64. No cause established; the next occurrence should not
be treated as the first.

## 2026-09-05: what the source doors paid when nothing was materialized

Found by a benchmark lane neither gate here runs: 2,000 completed
`(collapse (match &bench-provider (edge a $x) $x))` calls in one space, with
nothing materialized and both pragmas off, cost 816,831 SWI inferences against
786,829 at `8f853f99`. Exactly +15.001 per completed source. Bisecting the ten
commits puts all of it at `4d0713ac`, the commit that introduced this file, and
none of it at the nine others.

Rejected: the clause-collection listener as the cause. `prolog_listen(erase,
...)` is installed unconditionally and takes `current_transaction(_) ->
engine_create(...)`, which reads like a per-erase engine allocation gated on a
feature that is off. It is not what the workload pays.
`statistics(engines_created)` reports a delta of zero across all three samples,
counting the events shows 0, 47 and 157 erase events across a whole 2,000-call
run rather than several per call, and removing the listener with
`prolog_unlisten/2` moves the count by two inferences. Revisit only with an
event count that shows erases arriving per query.

Measured instead by replacing the two entry points with pass-throughs:
`with_source_materialization/3` and `flush_source_materialization/0` cost 12
inferences of body per completed source, and their two call frames cost the
other 3. Each runs exactly once per `space.run`, confirmed by wrapping them and
counting 2,000 of each.

Decided: three gates, each on a condition the caller already holds. A parse
that found no equation cannot make a relation admissible, so
`with_named_program_order/3` keeps its pre-subsystem shape for that case. The
per-runnable flush moves onto the compiled-definition boundary that already
decides when a prefix can have changed. And `source_materialization_dormant/1`,
two indexed lookups, lets `with_source_materialization/3` and
`materialize_source/1` return before walking every stored atom for candidate
names when the pragma is off and the space has no image. A relation the change
invalidated is still discarded, by `select_relation/5`'s stamp check, which
already answered the same bag from the retained clauses.

Verified: foreign-match returns to 786,829, equal to the base. Twenty other
benchmark rows return with it: `space-name` -240,013, `source-load` -92,778,
`table-bridge-match` -30,004, `op-raw` and `op-encoded` -16,000 each,
`eval-arith` -16,000, `register-op` -9,282, `run-source` -22,000,
`annotated-relation` -11,000, `query-where` -480, `save-load-metta` -905,
`loop-1m` -479, `file-load` -422.

Found while measuring: a data-only source rebuilt the relation while `add()`
never did. Both doors now leave the invalidated relation for the next lookup to
discard, and `test_a_source_that_defines_nothing_costs_no_construction` pins
them together rather than pinning the asymmetry.

Open, attributed and not ours: after these gates, `run-source` remains +7,002,
`annotated-relation` +1,500 and `query-where` +240 against the base, and every
one of those appears at `b1bd8646` and at no earlier commit, which is the
constant-folding admission probe running at each compiled call site.
`save-load-fast` remains +20,079, appearing at `4d0713ac`, which is the
fast-cache equation-binding half of that commit recording a binding per
restored equation. Both are proportional to the work their feature does rather
than fixed costs on unrelated paths, which is what separates them from the tax
removed here.
