<!-- Purpose: the ledger of host defects this engine works around, one entry per defect, keyed so a site comment can name it and the host-workarounds lane can hold the two in step. -->
# Host workarounds

The engine runs on hosts it does not own: SWI-Prolog, Janus, the C toolchain
and the operating system. When a host does something the engine has to work
around, the workaround is recorded twice and checked in both directions:

- at the site, a comment line in the file's own comment syntax of the shape
  `Workaround: <key> - <what this site does instead>`, followed by whatever
  explanation the site needs, where `<key>` is a heading in this file;
- here, one entry per defect under `## <key>`, with the fields below.

`tests/checks/check_host_workarounds.py`, the `host-workarounds` gate lane,
refuses a site whose key has no entry, an entry no site carries, an entry
missing a field, and a malformed site line. It then RUNS every entry's
reproduction on the host this tree runs on and reads the last line it prints:
`present` means the defect is still there and the workaround still earns its
keep; `absent` means the host no longer has it, and the lane fails naming
every site to lift, which is the signal to remove the workaround and the
entry together. Anything else is a broken reproduction and fails too. A
reproduction is a `.pl` file run as `swipl -q -f none -s FILE -g main -t halt`
or a `.sh` file run as `sh FILE`, under `bounded.sh`, with
`HOST_WORKAROUND_SCRATCH` naming a fresh directory of its own and `SWIPL`
naming the interpreter.

The fields, one per line, continuation lines indented:

- `Host:` the host and version the defect was measured on, with the source
  location that shows it.
- `Defect:` what the host does, stated as a mechanism.
- `Reproduction:` the tracked file whose last output line answers `present`
  or `absent`.
- `Workaround:` the shape every site uses, when there is one; each site
  states its own.
- `Lifted when:` the host change that makes the reproduction answer `absent`.
- `Record:` the journal thread that holds the evidence.

An entry lands with its first site and its reproduction in the same commit. A
site the ledger does not know is refused, and so is an entry nothing uses. The
journal keeps the history; this file holds only what is live.

## swi-cleanup-window
Host: SWI-Prolog 10.1.13; `setup_call_cleanup/3` is `sig_atomic(Setup),
  '$call_cleanup'` (boot/init.pl:680-682).
Defect: one call port lies between Setup returning and the cleanup being
  registered. An inference limit that trips at that port unwinds with Setup's
  effects in place and no cleanup owed, and a cleanup of several goals can be
  cut between its goals the same way. A signal cannot do this, because
  `sig_atomic/1` defers it; an inference limit is not a signal.
Reproduction: tests/checks/host_workarounds/swi-cleanup-window.pl, a budget
  sweep over an asserted guard; budget 4 of 64 leaks on 10.1.13.
Workaround: state that must not outlive its scope is a trailed write,
  `b_setval/2` on entry, `nb_setval/2` on the ordinary exit and `b_getval/2`
  to read; unwinding the exception unwinds the trail, so the cleanup is the
  fast ordinary exit rather than the thing correctness rests on.
Lifted when: the cleanup is registered before the call port that follows
  Setup, or the inference check honours the atomic region.
Record: docs/journal/2026-09-07-every-intermittent-root-caused.md, the
  20,000-budget sweep; docs/journal/2026-09-10-every-host-workaround-is-commented.md.

## swi-transaction-enumerator-repeats-parent
Host: SWI-Prolog 10.1.13; `src/pl-transaction.c:current_transaction/1` at
  fc7ef84b949378b729052c3ade79c90ce5416abb, lines 721-745.
Defect: a successful redo retains the same parent stack pointer, so enumerating
  two nested transactions returns the parent indefinitely.
Reproduction: tests/checks/host_workarounds/swi-transaction-enumerator-repeats-parent.pl,
  which asks for at most three answers from exactly two nested transactions.
Workaround: ask for existence with `once(current_transaction(_))` before a
  later condition can backtrack into the enumerator.
Lifted when: successful redo advances the parent pointer and the reproduction
  returns exactly two answers, printing absent.
Record: docs/journal/2026-09-11-classes-on-metta.md, transaction existence does
  not enumerate ancestors; docs/journal/2026-09-05-function-free-materialization.md.

## swi-wrapper-roundtrip-merges-closures
Host: SWI-Prolog 10.1.13; `library/prolog_wrap.pl:body_closure/3` at
  fc7ef84b949378b729052c3ade79c90ce5416abb.
Defect: `current_predicate_wrapper/4` replaces every native closure in a
  wrapper body with the same variable. Reinstalling its documented round-trip
  result makes other retained definitions call the wrapper's own definition.
Reproduction: tests/checks/host_workarounds/swi-wrapper-roundtrip-merges-closures.pl,
  an own/other union becomes own/own after the public round trip.
Workaround: read the wrapper's clause reference through `'$wrapped_predicate'/2`
  and copy its native body before reinstalling it to recover the original.
Lifted when: the public round trip preserves distinct closure identities and
  the reproduction prints absent.
Record: docs/journal/2026-09-11-classes-on-metta.md, binding ownership spans the
  native transition and its closure reconstruction follow-up.

## swi-locale-default-encoding
Host: SWI-Prolog 10.1.13; the default source encoding follows `setlocale()`.
Defect: a boot under `LC_ALL=C` reads a UTF-8 source as single bytes and
  compiles each non-ASCII character to U+FFFD. A `.qlf` written by that boot
  outlives the locale, since its mtime is newer than every source, so every
  later boot under a correct locale serves the poisoned compile; and an ASCII
  output stream does not fail on the mark, it escapes it.
Reproduction: tests/checks/host_workarounds/swi-locale-default-encoding.sh,
  which reads an atom written as U+2705 back under `LC_ALL=C`.
Workaround: the encoding flag and both standard streams are pinned to UTF-8
  before any file loads, and the artifact stamp carries the encoding beside
  the version, so a set compiled under another one is purged.
Lifted when: SWI reads source files as UTF-8 whatever the locale says.
Record: docs/journal/2026-09-07-the-gate-green-again.md, the artifact that
  outlived its locale.

## swi-qlf-extension-spec
Host: SWI-Prolog 10.1.13; `'$qlf_file'/5` in boot/init.pl decides by the
  shape of the spec.
Defect: a `load_files/2` spec that names its `.pl` extension compiles from
  source whatever `qcompile(auto)` says; only a bare stem reaches the artifact
  rule, which loads the `.qlf` when it is fresh and version-compatible and
  rewrites it when it is stale and the directory is writable.
Reproduction: tests/checks/host_workarounds/swi-qlf-extension-spec.sh, which
  loads one unit as `'one.pl'` and another as `two` and looks for the
  artifacts.
Workaround: `metta_load_source/2` strips the extension of a source the boot
  claims, so every runtime unit reaches the artifact rule.
Lifted when: the artifact rule applies to an extension-bearing spec too.
Record: docs/journal/2026-09-09-runtime-units-compile-beside-their-source.md.

## swi-qlf-failed-include-source-module
Host: SWI-Prolog 10.1.13 at fc7ef84b949378b729052c3ade79c90ce5416abb;
  boot/init.pl:$consult_file and src/pl-qlf.c:loadPredicate.
Defect: a failed nested include under qcompile(auto) leaves the source module
  changed. QLF replay then defines the next predicate in that module. A strong
  import there makes lookupProcedureToDefine return null, which loadPredicate
  dereferences, producing signal 11. The stripped library reports the nearest
  exported symbol, PL_cut_query, although the fault is in the QLF loader.
Reproduction: tests/checks/host_workarounds/swi-qlf-failed-include-source-module.sh,
  a module that imports an export into user before a failed nested include.
  The same QLF loads in the control with its optional entry disabled; replay
  with the broken entry enabled exits 139. The crash reporter can instead
  abort with exit 134 after its stack_avail___LD assertion; that result counts
  only with the original signal-11 report and the exact secondary assertion.
  No engine or Janus is loaded.
Workaround: loading_loudly/1 restores the source module on success, failure
  and exception before QLF replay continues. Nested diagnostic collection
  turns the printed include error into a refusal at the boot boundary.
Lifted when: the reproduction safely rejects or finishes replay instead of
  crashing, and the loader restores module state after a failed consult.
Record: docs/journal/2026-09-11-the-engine-and-packaging-lanes-after-the-wave.md.

## swi-query-frame-discarded-on-engine-destroy
Host: SWI-Prolog 10.1.13; `PL_close_query` in src/pl-wam.c closes the
  foreign frame before discarding the outer query frame, while
  `prolog_frame_attribute/3` marks inspected ancestors for `frame_finished`.
Defect: destroying a yielded engine delivers the event for that discarded
  outer frame. Opening the listener's query aborts on the host's assertion
  `PL_open_query: Assertion failed: (void*)fli_context > (void*)environment_frame`,
  exit 134 in the plain-host reproduction. The same path under the engine
  exits 139 when the crash reporter itself segfaults. A build without
  assertions reads a discarded frame instead; exit 0 there is not proof
  that the defect has gone.
Reproduction: tests/checks/host_workarounds/swi-query-frame-discarded-on-engine-destroy.sh,
  a frozen unsafe ancestor walk inside a plain-SWI transaction, followed by
  an engine yield and destruction. It loads no repository engine predicates.
  Exit 139, or 134 with the exact assertion above, answers `present`; exit 0
  answers `absent`; every other result is a broken reproduction.
Workaround: inspect only through the nearest live transaction frame and
  transfer its watch to the surviving transaction when it finishes. Exclude
  the finished frame ID because failure notification can start on that frame.
Lifted when: SWI no longer delivers `frame_finished` for the frame that
  `PL_close_query` discards, or excludes its outer query frame from
  `prolog_frame_attribute/3` marking. Verify that host change before treating
  `absent` from a build without assertions as a lift signal.
Record: docs/journal/2026-09-09-the-binding-collapse.md, transfer bound watches
  before native query destruction.

## swi-file-search-cache-autoload
Host: Janus 1.5.3 on SWI-Prolog 10.1.13; janus.pl's `py_call/4` failed-query
  branch resolves its declared `maplist/2` autoload on first use.
Defect: the first failed text query walks the file search path when the
  dependency's cached path has expired. The same query therefore pays a
  different inference cost according to earlier wall-clock state, despite
  performing the same program work. `file_search_cache_time=0` disables the
  cache before either the hit or sweep clauses; it reproduces the uncached
  walk, not a cache-expiry sweep.
Reproduction: tests/checks/host_workarounds/swi-file-search-cache-autoload.sh,
  four fresh Python Janus processes with no engine loaded. The first failed
  text query costs 1,281 with the primed default cache and 1,507 with the cache
  disabled at zero; explicitly importing `maplist/2` gives 8 in both arms.
  The native count surrounds the query, and each child restores the default
  flag value 10. This is the zero-setting uncached-walk control.
Workaround: import Janus's `maplist/2` dependency once at binding boot. Do
  not put the import on a query path or preload optional library helpers.
Lifted when: Janus resolves this dependency before its first failed text
  query, or SWI's autoload resolution no longer gives that query a cache-state
  dependent inference cost. Equal warm and uncached costs answer `absent`.
Record: docs/journal/2026-09-09-the-binding-collapse.md, first-use dependency
  attribution and deterministic 226/229 controls. The separate file-search
  cache maintenance sweep belongs to its own host-workaround entry.
## swi-gc-in-frame-finished-listener-clears-a-live-slot
Host: SWI-Prolog 10.1.13, commit fc7ef84b949378b729052c3ade79c90ce5416abb;
  src/pl-wam.c:884-899, src/pl-vmi.c:1243-1263 and 2160-2207,
  src/pl-gc.c:1886-1918, 2113-2117 and 3584-3694.
Defect: debug mode exposes B_UNIFY_FV as a temporary unification frame.
  prolog_frame_attribute/3 marks a frame for frame_finished notifications
  (src/pl-trace.c:2503). The observer references it at the call port through
  prolog_frame_attribute(Frame,pc,PC). On deterministic exit the parent has
  resumed in SWI's saved registers before frameFinished calls the listeners.
  Collection there rewinds the parent's saved PC to the completed B_UNIFY_FV,
  then clears its first-write slot as uninitialised. The arithmetic goals in
  translator:translate_clause_impl/4's slot 27 disappear at saved PC 209,
  rewound to instruction 206. Debug mode with an unreferenced frame does not
  notify the listener and preserves the value.
Reproduction: tests/checks/host_workarounds/swi-gc-in-frame-finished-listener-clears-a-live-slot.pl,
  Plain SWI, a frame_finished listener that calls garbage_collect/0, and
  sample([arithmetic],Output). The unreferenced debug control prints absent;
  the referenced run's last line is present iff Output == [], absent
  otherwise. Both verdicts exit 0.
Workaround: the process-wide trace hook first tests the captured starting
  thread's identity, then disables its gc flag at every exit port before
  frame inspection or observer work. Every non-exit port, including call,
  redo, fail, unify, exception and cut ports, restores the captured original
  value. Consecutive exits retain the deferral; observation teardown restores
  the original value even after a hook throws or execution is cancelled.
  The gc flag gates implicit collection and explicit garbage_collect/0
  (src/pl-gc.c:3827, 4418 and 4561-4577); this does not merely intercept
  explicit calls. Stacks can still grow while collection is deferred.
  The window starts at the exit hook's first call port and extends through
  its own work and the finished listeners until the next port. Its excess is
  the parent's straight-line VM instructions after the listeners return:
  collection there requires an instruction's own space check, which restarts
  that instruction, or the next port, so deferring it to that port loses no
  collection opportunity. A collection already requested before the exit
  hook can still run at its first call port, before the identity test and
  flag write alike; only a host fix removes that residual boundary. The guard
  adds no exposure there. Observation covers only the starting thread. Its
  hooks inspect frames and update maps and never create threads; source code
  reaches a restoring call port before thread creation. Other threads' flags
  are never written by this hook.
Lifted when: the reproduction prints absent because collection after a
  referenced inline unification no longer reinterprets its completed
  first-write instruction as pending. Fixing the saved-PC or live-slot
  treatment also removes the pre-hook residual boundary; a timing change is
  not evidence that the host condition has been repaired.
Record: docs/journal/2026-09-10-the-observed-equation-loses-its-arithmetic.md.
## swi-file-search-cache-sweep
Host: SWI-Prolog 10.1.13; boot/init.pl:1531-1564,
  https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/boot/init.pl#L1531-L1564.
Defect: the first library load after the file-search cache expires runs
  gc_file_search_cache/1, removing other expired lookup entries. The next
  lookup pays resolution and insertion work instead of the warm-cache cost;
  wall-clock state changes measured Prolog inferences. A zero timeout bypasses
  insertion and the sweep, so it tests an uncached walk rather than this event.
Reproduction: tests/checks/host_workarounds/swi-file-search-cache-sweep.pl,
  ages cache and sweep timestamps under a positive timeout, loads a previously
  unloaded library, and compares the next lookup with two warm lookups.
Workaround: extensions/python/tools/twin_coverage.py sets
  file_search_cache_time to 9223372036854775807 before MeTTa boot, so every
  measured child and its inherited engines keep the cache live for the lane.
Lifted when: the aged load's next lookup costs the same inferences as a warm
  lookup; the reproduction then answers absent instead of the current 818
  against 680. Unequal warm controls or a reversed difference are broken.
Record: docs/journal/2026-09-07-merged-tree-reconciliations.md, the cache-age
  controls and the 2026-09-10 host-reproduction section.

## swi-first-arg-index-dead-keys
Host: SWI-Prolog 10.1.13; next_clause_primary_index in src/pl-index.c:293-346
  and the clause-collection contract in src/pl-proc.c:2248-2276,
  https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-index.c#L293-L346.
Defect: retract leaves dead ClauseRef keys in the primary index until clause
  collection. A bound lookup for the sole live tail scans the retired keys;
  the physical scan grows although Prolog reports the same inference count.
Reproduction: tests/checks/host_workarounds/swi-first-arg-index-dead-keys.pl,
  retains 20000 retired rows, measures live-tail lookups, then collects clauses
  and measures the same lookups twice. Automatic collection is held off only
  in this fresh diagnostic process so it cannot erase the inspected state.
Workaround: extensions/cmetta/bridge.pl keeps cursor owners under one static
  recorded key; the C handle carries a bound record reference, and close erases
  the owner immediately instead of retracting a dynamic cursor row.
Lifted when: retained-key lookups cost no more than four times the collected
  control, so the reproduction answers absent. Unequal inference counts or
  a fourfold spread between collected controls report a broken reproduction.
Record: docs/journal/2026-09-07-merged-tree-reconciliations.md, immediate cursor
  retirement and the 2026-09-10 host-reproduction section.

## swi-inherited-empty-predicate-retry
Host: SWI-Prolog 10.1.13; S_VIRGIN in src/pl-vmi.c:3244-3270,
  https://github.com/SWI-Prolog/swipl-devel/blob/fc7ef84b949378b729052c3ade79c90ce5416abb/src/pl-vmi.c#L3244-L3270.
Defect: resolving a first inherited call retries and increments inferences
  when the provider's first-clause pointer is nonnull, even when every clause
  is retired. Clause collection clears that pointer and removes the retry,
  so identical logical state has a different first-call cost by GC schedule.
Reproduction: tests/checks/host_workarounds/swi-inherited-empty-predicate-retry.pl,
  compares inherited first/warm calls with retained and collected clauses in
  fresh plain-SWI processes, with direct provider calls controlling both arms.
Workaround: translator:runnable_head_awaits_its_definition/1 calls
  filereader:source_pending_definition/2 explicitly. The reader remains the
  same unique provider; no collection or counter adjustment enters the path.
Lifted when: inherited first-call counts agree in both states; the reproduction
  then answers absent. Currently retained reads4/3 and collected3/3, while
  direct calls read3/3 in both states. Inconsistent warm or direct controls,
  reversed costs and child failures are broken reproductions.
Record: docs/journal/2026-09-07-merged-tree-reconciliations.md, the 2026-09-11
  buffered VM trace and unchanged-body foldall controls.

## swi-concurrent-import-removal-resets-provider
Host: SWI-Prolog 10.1.13 at fc7ef84b949378b729052c3ade79c90ce5416abb;
  src/pl-proc.c:388-416, 1510-1544 and 2871-2935.
Defect: abolishProcedure replaces an imported Procedure's Definition with an
  empty child definition, then resetProcedure reads the Procedure again.
  Concurrent autoImport can install the provider between those operations.
  The reset then clears the provider's clause count and meta declaration
  while its original clauses remain. The two operations use different locks.
Reproduction: tests/checks/host_workarounds/swi-concurrent-import-removal-resets-provider.pl,
  a compiled child call racing with one million imported abolish operations.
  It loads no engine. The original provider clause survives but its metadata
  disappears; the last line is present.
Workaround: import repair retains an existing link when the first resolving
  base still selects its provider. Module refresh and rollback repair use
  that same reconciliation. This removes repeated detachment during unrelated
  mutation; actual concurrent shadow replacement still depends on the host's
  native rebinding semantics.
Lifted when: abolishProcedure resets its captured child Definition before
  publication, or synchronizes the entire transition with autoImport, and
  the reproduction retains the provider's metadata and prints absent.
Record: docs/journal/2026-09-11-classes-on-metta.md, import repair retains an
  unchanged provider.

## swi-nested-retract-loses-outer-assert
Host: SWI-Prolog 10.1.13 at fc7ef84b949378b729052c3ade79c90ce5416abb;
  src/pl-transaction.c:417-427, merge_clause_tables.
Defect: committing a nested erase of a clause asserted by its outer transaction
  overwrites the outer GEN_ASSERTA or GEN_ASSERTZ entry with GEN_NESTED_RETRACT.
  Outer rollback restores the erased generation instead of discarding the
  assertion. The clause is invisible outside a transaction but reappears when
  a later transaction advances past its creation generation.
Reproduction: tests/checks/host_workarounds/swi-nested-retract-loses-outer-assert.pl,
  an outer assert, committed inner erase, failed outer transaction, then 100
  unrelated assertions in a later transaction. No engine is loaded.
Workaround: engine/host_transactions.pl records fresh assertion references in
  a journal local to the executing engine and thread. A child journal belongs
  to its parent before any child writes. After rollback or snapshot exit it
  erases those references explicitly. Nontransactional host predicates retain
  their own semantics. This preserves savepoints and never deduplicates rows.
Lifted when: merge_clause_tables preserves outer assertion ownership when it
  merges a nested retract, so the plain-host reproduction prints absent.
Record: docs/journal/2026-09-11-classes-on-metta.md, repository ownership after
  nested rollback.
