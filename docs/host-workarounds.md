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
- `Patch:` the tracked patch the host this tree runs on is built with, when
  the defect is fixed in the host rather than worked around in the tree.
- `Record:` the journal thread that holds the evidence.

An entry lands with its first site and its reproduction in the same commit. A
site the ledger does not know is refused, and so is an entry nothing uses. The
journal keeps the history; this file holds only what is live.

An entry with `Patch:` is the dual state. Its host is built from the patched
source, so it needs no site, its reproduction must answer `absent`, and
`present` means this environment's host was built without the patch: the lane
fails naming the patch to rebuild with. The reproduction still describes the
defect as shipped, so a fresh environment learns what its host must carry.

## janus-callback-exception-leak
Host: janus-swi 1.5.3 (janus/janus.c `check_error`, the same code at upstream
  packages-swipy master b0356a162, 2026-07-28, and in swipl-devel V10.1.14's
  packages/swipy) on SWI-Prolog 10.1.13 and 10.1.14.
Defect: when a Python callback raises, `check_error` fetches the exception's
  type, value and traceback with `PyErr_Fetch` to build the
  `python_error(Class, Obj)` ball, and returns without releasing the three
  references it owns. The blobs the ball carries release theirs at atom GC;
  these never do, so every exception a callback raised stays alive for the
  process with its traceback, every frame below the callback and every local
  those frames hold. In this engine that kept a dropped space's handle, its
  lease cell and the transaction frames of each rolled-back body.
Reproduction: tests/checks/host_workarounds/janus-callback-exception-leak.sh,
  one Python child raising three exceptions inside `py_call/2`, then atom GC,
  a Prolog-to-Python call to drain the deferred releases and a Python
  collection; `present` when an instance survives.
Patch: tests/checks/host_workarounds/janus-callback-exception-leak.patch,
  applied to swipl-devel's packages/swipy at the tag the seat runs (V10.1.14),
  built there against the patched SWI-Prolog (`rm -rf build; SWIPL=<its swipl>
  uv build --wheel --no-build-isolation`, a stale `build/` keeps a `_swipl`
  linked to another libswipl) and installed into the seat's interpreter with
  `uv pip install --reinstall --no-deps`; it releases the fetched references on
  every exit of `check_error`. The interpreter's `swipl` and its janus must
  resolve to that one build, or the janus reproduction answers for a host the
  engine does not run on.
Lifted when: janus-swi releases what `PyErr_Fetch` handed `check_error`; the
  entry and the patch go together once the installed janus carries that.
Record: docs/journal/2026-09-16-reclamation-counts.md, the retention bisection
  from the reclamation counts to the hidden reference and the patched build.

## swi-bound-clause-reference-ignores-snapshot
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped, this tree running on 10.1.14 built with the patch below; at fc7ef84b949378b729052c3ade79c90ce5416abb;
  src/pl-dbref.c:PL_get_clref and src/pl-comp.c:clause.
Defect: bound-reference clause/3 rejects the global CL_ERASED flag even when
  enumeration in the caller's older transaction still admits that occurrence.
  A second read can therefore lose the source or owner that the first read saw.
Reproduction: tests/checks/host_workarounds/swi-bound-clause-reference-ignores-snapshot.pl,
  an old transaction enumerates its original fact after an independently joined
  eraser, then compares bound-reference reading with retained-term decompilation.
Patch: tests/checks/host_workarounds/swi-bound-clause-reference-ignores-snapshot.patch,
  against swipl-devel V10.1.14 src/pl-comp.c: clause/3 with a bound reference
  admits an erased clause that is still visible at the caller's generation
  (`current_generation()` of its predicate), the view enumeration takes, so
  a second read returns the occurrence the first read saw. The reproduction
  answers absent and SWI's core, db, transaction and tabling groups pass.
Lifted when: SWI-Prolog as shipped reads a bound reference at the caller's
  generation, so the reproduction prints absent; the patch and the entry go
  together then.
Record: docs/journal/2026-09-15-native-owned-records.md.

## swi-cached-undefined-supervisor
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped; src/pl-proc.c:trapUndefined,
  src/pl-supervisor.c:createUndefSupervisor and src/pl-vmi.c:S_UNDEF. This
  tree runs on 10.1.14 built with the patch below.
Defect: an unsuccessful undefined-predicate hook installs an S_UNDEF
  supervisor. A later compiled call can reuse it and throw directly, bypassing
  a hook whose deferred source has become available since the first call.
Reproduction: tests/checks/host_workarounds/swi-cached-undefined-supervisor.pl,
  a failed call followed by an available loader and an explicitly qualified
  compiled caller. A fresh predicate verifies that the same loader works.
Patch: tests/checks/host_workarounds/swi-cached-undefined-supervisor.patch,
  against swipl-devel V10.1.14 src/pl-vmi.c on top of
  swi-erased-definition-bypasses-loader.patch: S_UNDEF's error case consults
  the loader once more (`trapUndefined()`) before raising, when autoloading is
  on and the system has booted, and continues into the definition it yields;
  a loader that defines nothing still raises, and the `unknown` flag's fail
  and warning cases keep their cached answer. The reproduction answers absent
  and SWI's core, db, transaction, tabling, save, files, compile, attvar and
  engines groups pass on the build.
Lifted when: SWI-Prolog as shipped consults the loader from a cached undefined
  call, so the reproduction prints absent; the patch and the entry go together
  then.
Record: docs/journal/2026-09-17-host-patches.md;
  docs/journal/2026-09-15-deferred-definitions-rearm-undefined-calls.md.
## swi-empty-indexed-snapshot
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped; src/pl-index.c,
  first_clause_guarded. This tree runs on 10.1.14 built with the patch below.
Defect: a call or an unbound clause/3 on a dynamic predicate whose current
  clause count is zero returns no clause before the caller's transaction
  generation is applied, so an older transaction loses the rows it should
  still see once the last current clause is erased, while nth_clause/3 and
  '$clause'/4 still admit them.
Reproduction: tests/checks/host_workarounds/swi-empty-indexed-snapshot.pl,
  an old transaction reads one and sixteen facts after an independently joined
  thread erases every current clause of the predicate.
Patch: tests/checks/host_workarounds/swi-empty-indexed-snapshot.patch, against
  swipl-devel V10.1.14 src/pl-index.c: when the current count is zero and the
  caller runs inside a transaction, `first_clause_guarded()` walks the
  clause list with the generation check (`next_clause_unindexed()`) instead
  of answering nothing; outside a transaction the empty answer stands, which
  undo/1's erase at the call port relies on (SWI's `undo:undo_or` and
  `undo:clauses` tests read the erase through it). SWI's core_lang,
  transaction, db and tabling groups pass on the build.
Lifted when: SWI-Prolog as shipped routes the empty-current list through the
  visibility-aware reader for a transaction, so the reproduction prints
  absent; the patch and the entry go together then.
Record: docs/journal/2026-09-17-host-patches.md, the walk and the inert
  clause it retires; docs/journal/2026-09-15-native-owned-records.md.
## swi-erased-definition-bypasses-loader
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped; src/pl-vmi.c:S_VIRGIN,
  src/pl-wam.c:getProcDefinedDefinition, src/pl-proc.c:resetProcedure and
  src/pl-supervisor.c:undefSupervisor. This tree runs on 10.1.14 built with
  the patch below.
Defect: abolish can leave erased clauses linked to a definition. S_VIRGIN
  treats the nonnull first-clause pointer as a definition and skips the loader;
  supervisor creation then sees zero live clauses and installs S_UNDEF.
  Repeating abolish resets the supervisor but retains the same condition.
Reproduction: tests/checks/host_workarounds/swi-erased-definition-bypasses-loader.pl,
  a compiled call after abolish while an earlier call retains its logical
  update view. A fresh predicate verifies the same loader independently.
Patch: tests/checks/host_workarounds/swi-erased-definition-bypasses-loader.patch,
  against swipl-devel V10.1.14 src/pl-wam.c and src/pl-vmi.c: one test,
  `undefinedForCall()`, says a call must resolve its definition first when the
  predicate is not declared and either has no definition or is a clause
  predicate with no live clause, whatever erased clauses it still links; the
  VM's call sites and `getProcDefinedDefinition()` use it in place of the raw
  first-clause pointer, so the loader (exception/3, autoload) is consulted for
  a reset predicate and a loader that defines nothing still ends in the
  undefined supervisor. The reproduction answers absent; SWI's core, db,
  transaction, tabling, save, files and compile groups pass on the build.
Lifted when: SWI-Prolog as shipped consults the loader for a reset predicate
  despite retained erased clauses, so the reproduction prints absent; the
  patch and the entry go together then.
Record: docs/journal/2026-09-17-host-patches.md;
  docs/journal/2026-09-15-copied-specializations-materialize-before-calls.md.
## swi-cleanup-window
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped; `setup_call_cleanup/3` is
  `sig_atomic(Setup), '$call_cleanup'` (boot/init.pl:680-682). This tree
  runs on 10.1.14 built with the patch below.
Defect: `raiseInferenceLimitException()` (src/pl-prims.c) raises inside
  `sig_atomic/1`'s critical region, so an inference limit that trips at the
  call port of Setup's own goal is delivered when the region ends, between
  Setup's effects and the cleanup's registration in `I_CALLCLEANUP`, and no
  cleanup is owed; a cleanup of several goals can be cut between its goals
  the same way. A signal cannot do this, because `sig_atomic/1` defers it;
  the inference check did not.
Reproduction: tests/checks/host_workarounds/swi-cleanup-window.pl, a budget
  sweep over an asserted guard; budget 4 of 64 leaks on 10.1.13 and 10.1.14
  as shipped, none with the patch.
Patch: tests/checks/host_workarounds/swi-cleanup-window.patch, against
  swipl-devel V10.1.14 src/pl-prims.c: `raiseInferenceLimitException()`
  returns without raising while `LD->critical` is set, so the limit is
  honoured the way a signal is, at the first call port after the region. A
  region is one indivisible step to the limit: a limited goal whose last step
  is a region completes with `!`, as one whose last step is a long foreign
  call already does, and a cleanup handler, which `callCleanupHandler()` runs
  between `startCritical()` and `endCritical()`, is never cut between its
  goals. SWI's own suite passes on the build (87 of 88, `pldoc:man_links`
  needs the documentation the build omits; `tests/core_lang/test_inflimit.pl`
  among the passes).
Lifted when: SWI-Prolog as shipped registers the cleanup before the call port
  that follows Setup, or its inference check honours the atomic region as the
  patch makes it; the patch and the entry go together then. The Workaround
  field goes with the last lifted site.
Record: docs/journal/2026-09-17-host-patches.md, the budget sweep and the
  traced run that placed the exception inside `asserta/2`;
  docs/journal/2026-09-07-every-intermittent-root-caused.md, the
  20,000-budget sweep; docs/journal/2026-09-10-every-host-workaround-is-commented.md.

## swi-transaction-enumerator-repeats-parent
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped; `src/pl-transaction.c:current_transaction/1`.
  This tree runs on 10.1.14 built with the patch below.
Defect: a successful redo retains the same parent stack pointer, so enumerating
  two nested transactions returns the parent indefinitely.
Reproduction: tests/checks/host_workarounds/swi-transaction-enumerator-repeats-parent.pl,
  which asks for at most three answers from exactly two nested transactions.
Patch: tests/checks/host_workarounds/swi-transaction-enumerator-repeats-parent.patch,
  against swipl-devel V10.1.14 src/pl-transaction.c: the redo case takes the
  entry's id and advances to its parent before answering, so the saved redo
  pointer is the next ancestor and the last one answers deterministically;
  three nested transactions enumerate exactly three ids, and SWI's
  transaction group passes on the build.
Lifted when: SWI-Prolog as shipped advances the parent pointer on redo, so the
  reproduction prints absent; the patch and the entry go together then.
Record: docs/journal/2026-09-17-host-patches.md; docs/journal/2026-09-11-classes-on-metta.md,
  transaction existence does not enumerate ancestors;
  docs/journal/2026-09-05-function-free-materialization.md.
## swi-ugraphs-implicit-append
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped, this tree running on 10.1.14 built with the patch below;, library/ugraphs.pl:460 (`top_sort/2`); the same
  line at swipl-devel V10.1.14.
Defect: the library declares its lists dependency as `append/3` alone and
  `top_sort/2` calls `append/2`, which only the library index supplies. With
  autoload off (run.sh `NO_AUTOLOAD=1`, the engine's `no-autoload` gate) the
  first `top_sort/2`, which the engine's release plan
  (`metta_space_release_plan/2`) calls, raises
  `existence_error(procedure, ugraphs:append/2)`.
Reproduction: tests/checks/host_workarounds/swi-ugraphs-implicit-append.pl,
  `top_sort/2` with autoload off; `present` when it raises the existence
  error.
Patch: tests/checks/host_workarounds/swi-ugraphs-implicit-append.patch, against
  swipl-devel V10.1.14 library/ugraphs.pl: the lists dependency declares
  `append/2` beside `append/3`, so `top_sort/2` resolves it with autoload off.
  The reproduction answers absent.
Lifted when: ugraphs.pl as shipped declares `append/2`; the reproduction then answers
  `absent` and the patch and the entry go together.
Record: docs/journal/2026-09-16-exec-modules-never-autoload.md.

## swi-wrapper-roundtrip-merges-closures
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped, this tree running on 10.1.14 built with the patch below;; `library/prolog_wrap.pl:body_closure/3` at
  fc7ef84b949378b729052c3ade79c90ce5416abb.
Defect: `current_predicate_wrapper/4` replaces every native closure in a
  wrapper body with the same variable. Reinstalling its documented round-trip
  result makes other retained definitions call the wrapper's own definition.
Reproduction: tests/checks/host_workarounds/swi-wrapper-roundtrip-merges-closures.pl,
  an own/other union becomes own/own after the public round trip.
Patch: tests/checks/host_workarounds/swi-wrapper-roundtrip-merges-closures.patch,
  against swipl-devel V10.1.14 library/prolog_wrap.pl: `body_closure//`
  replaces only a closure over the wrapped predicate itself, identified
  through `'$closure_predicate'/2` against the predicate's implementation
  module and name/arity, so closures over other predicates keep their
  identity on the round trip. The reproduction answers absent and SWI's
  library group passes.
Lifted when: the public round trip as shipped preserves distinct closure identities
  and the reproduction prints absent; the patch and the entry go together
  then.
Record: docs/journal/2026-09-11-classes-on-metta.md, binding ownership spans the
  native transition and its closure reconstruction follow-up.

## swi-locale-default-encoding
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped, where the default source
  encoding follows `setlocale()`; this tree runs on 10.1.14 built with the
  patch below.
Defect: a boot under `LC_ALL=C` reads a UTF-8 source as single bytes and
  compiles each non-ASCII character to U+FFFD. A `.qlf` written by that boot
  outlives the locale, since its mtime is newer than every source, so every
  later boot under a correct locale serves the poisoned compile; and an ASCII
  output stream does not fail on the mark, it escapes it.
Reproduction: tests/checks/host_workarounds/swi-locale-default-encoding.sh,
  which reads an atom written as U+2705 back under `LC_ALL=C`.
Patch: tests/checks/host_workarounds/swi-locale-default-encoding.patch, against
  swipl-devel V10.1.14 src/os/pl-ctype.c: `init_locale()` reads and writes
  UTF-8 when the C library's LC_CTYPE is the C or POSIX locale, as Python's
  UTF-8 mode does for the same case, so a UTF-8 source compiles the same
  under every locale; the `encoding` flag reads `utf8` under `LC_ALL=C`.
  The reproduction answers absent and SWI's core, files, charset and library
  groups pass.
Lifted when: SWI-Prolog as shipped reads UTF-8 under the C locale; the reproduction
  then answers absent and the patch and the entry go together.
Record: docs/journal/2026-09-07-the-gate-green-again.md, the artifact that
  outlived its locale.

## swi-qlf-extension-spec
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped, this tree running on 10.1.14 built with the patch below;; `'$qlf_file'/5` in boot/init.pl decides by the
  shape of the spec.
Defect: a `load_files/2` spec that names its `.pl` extension compiles from
  source whatever `qcompile(auto)` says; only a bare stem reaches the artifact
  rule, which loads the `.qlf` when it is fresh and version-compatible and
  rewrites it when it is stale and the directory is writable.
Reproduction: tests/checks/host_workarounds/swi-qlf-extension-spec.sh, which
  loads one unit as `'one.pl'` and another as `two` and looks for the
  artifacts.
Patch: tests/checks/host_workarounds/swi-qlf-extension-spec.patch, against
  swipl-devel V10.1.14 boot/init.pl: `'$qlf_file'/5` keeps loading a
  spec that names its Prolog extension from source when only the process-wide
  `qcompile` flag is on, which keeps that flag from writing an artifact beside
  every file a program names by path, and lets the spec reach the artifact
  rule like a stem when the call carries its own `qcompile` option. A first
  shape that let the flag reach it too wrote artifacts beside the engine's
  backends and the binding's shim during the umbrella boot. The reproduction
  answers absent and SWI's core, files, save and compile groups pass.
Lifted when: the artifact rule as shipped applies to an extension-bearing spec too; the
  reproduction then prints absent and the patch and the entry go together.
Record: docs/journal/2026-09-09-runtime-units-compile-beside-their-source.md.

## swi-qlf-failed-include-source-module
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped; boot/init.pl:$consult_file and
  src/pl-qlf.c:loadPredicate. This tree runs on 10.1.14 built with the patch
  below.
Defect: a failed nested include under qcompile(auto) leaves the source module
  changed, because `'$consult_file'/5` restores it only on success. QLF replay
  then defines the next predicate in that module. A strong import there makes
  lookupProcedureToDefine return null, which loadPredicate dereferences,
  producing signal 11, or an assertion in whatever the corrupted state reaches
  first on a build with assertions.
Reproduction: tests/checks/host_workarounds/swi-qlf-failed-include-source-module.sh,
  a module that imports an export into user before a failed nested include.
  The same QLF loads in the control with its optional entry disabled; replay
  with the broken entry enabled exits 139, or 134 with the crash reporter's
  `stack_avail___LD` assertion, on the host as shipped. No engine or Janus is
  loaded.
Patch: tests/checks/host_workarounds/swi-qlf-failed-include-source-module.patch,
  against swipl-devel V10.1.14: `'$consult_file'/5` restores the source module
  in a cleanup, on failure and exception as on success, and `loadPredicate()`
  returns the pending permission error instead of dereferencing a null
  procedure. Replay of the reproduction's QLF finishes (`safe-replay`) three
  runs out of three, and SWI's core, save, files and compile groups pass on
  the build.
Lifted when: SWI-Prolog as shipped restores the source module after a failed
  consult and refuses a null procedure in the QLF loader, so the reproduction
  prints absent; the patch and the entry go together then.
Record: docs/journal/2026-09-17-host-patches.md; docs/journal/2026-09-11-the-engine-and-packaging-lanes-after-the-wave.md.
## swi-query-frame-discarded-on-engine-destroy
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped; `PL_close_query` in
  src/pl-wam.c closes the foreign frame before discarding the outer query
  frame, while `prolog_frame_attribute/3` marks inspected ancestors for
  `frame_finished`. This tree runs on 10.1.14 built with the patch below.
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
Patch: tests/checks/host_workarounds/swi-query-frame-discarded-on-engine-destroy.patch,
  against swipl-devel V10.1.14 src/pl-wam.c: `discard_query()` makes the
  query frame the environment before it notifies, since every frame above it
  is discarded and a yielded engine's environment lies in that region, and
  `frameFinished()` runs the listener inside a foreign frame of its own above
  the finished frame, as the cleanup handler already does. The reproduction
  answers absent three runs of three, and SWI's core, engines, debug, GC,
  signals, db and transaction groups pass on the build.
Lifted when: SWI-Prolog as shipped delivers `frame_finished` for a discarded
  query frame from a sane environment and foreign frame, so the reproduction
  prints absent; the patch and the entry go together then.
Record: docs/journal/2026-09-17-host-patches.md; docs/journal/2026-09-09-the-binding-collapse.md,
  transfer bound watches before native query destruction.
## swi-file-search-cache-autoload
Host: janus-swi 1.5.3, the same janus.pl in swipl-devel V10.1.14's
  packages/swipy, on SWI-Prolog 10.1.13 and 10.1.14 as shipped; the venv's
  janus wheel is built from that tree with the patch below.
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
Patch: tests/checks/host_workarounds/swi-file-search-cache-autoload.patch, against
  swipl-devel V10.1.14 packages/swipy janus/janus.pl: the library imports its
  lists, apply, error, dicts and option dependencies when it loads instead of
  declaring them for lazy autoloading, so the failed-query branch of
  `py_call/4` resolves nothing at its first use. The reproduction answers
  absent.
Lifted when: janus.pl as shipped imports its failure-path dependencies eagerly; the
  reproduction then answers absent and the patch and the entry go together.
Record: docs/journal/2026-09-09-the-binding-collapse.md, first-use dependency
  attribution and deterministic 226/229 controls. The separate file-search
  cache maintenance sweep belongs to its own host-workaround entry.
## swi-gc-in-frame-finished-listener-clears-a-live-slot
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped, this tree running on 10.1.14
  built with the patch below; src/pl-gc.c setStartOfVMI() and
  clearUninitialisedVarsFrame(), src/pl-vmi.c B_UNIFY_FF, B_UNIFY_FV,
  B_UNIFY_FC, B_ARG_CF, A_ADD_FC and exit_continue, src/pl-wam.c
  frameFinished(), at V10.1.14.
Defect: the collector reads a saved PC at the end of an instruction as that
  instruction in progress and starts its walk there, so the instruction's
  first-var operand counts as unwritten and is cleared. That is right for an
  instruction that requested stack space after reading its operands. It is
  wrong after a call from inside the instruction returns to the same PC:
  under the debugger, B_UNIFY_FF, B_UNIFY_FV, B_UNIFY_VF and B_UNIFY_FC call
  =/2, B_ARG_CF and B_ARG_VF call arg/3 and A_ADD_FC calls is/2, each after
  writing its first var, and the deterministic exit of that callee resumes
  the caller in the VM registers before frameFinished() runs the
  frame_finished listeners (exit_continue). prolog_frame_attribute/3 marks
  the callee's frame for those notifications when the debugger references
  it at the call port. Collection in the listener then clears the completed
  slot: the arithmetic goals in translator:translate_clause_impl/4's slot 27
  disappeared at saved PC 209, and every sample of the reproduction answers
  a fresh variable.
Reproduction: tests/checks/host_workarounds/swi-gc-in-frame-finished-listener-clears-a-live-slot.pl,
  plain SWI, a frame_finished listener that calls garbage_collect/0, a trace
  hook that references every call-port frame, and one sample per
  instruction. The unreferenced control must keep every value; `present`
  iff a referenced sample answers something other than its expected value.
Patch: tests/checks/host_workarounds/swi-gc-in-frame-finished-listener-clears-a-live-slot.patch,
  against swipl-devel V10.1.14 src/pl-gc.c and src/pl-vmi.c: a saved PC
  exactly at the end of one of those seven instructions is a return address,
  so setStartOfVMI() starts the walk after it, as the walk of a parent frame
  starts at its return address. The rule holds because none of the seven
  requests space once its operands are read with the first var unwritten:
  B_UNIFY_FC reserves its cell before reading its operands as B_UNIFY_FV and
  B_UNIFY_FF do, and A_ADD_FC reserves the debugger's cells before its
  operands and makes its result slot a variable before the two inline
  requests that need one. The reproduction answers absent for all seven
  samples and SWI's basic, core, db, attvar, debug, GC, compile, tabling,
  transaction and engines groups pass.
Lifted when: the collector as shipped starts after a completed first-var
  instruction whose call returned to its end; the reproduction then answers
  absent and the patch and the entry go together.
Record: docs/journal/2026-09-10-the-observed-equation-loses-its-arithmetic.md
  and docs/journal/2026-09-17-host-patches.md.

## swi-file-search-cache-sweep
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped; boot/init.pl's file-search
  cache. This tree runs on 10.1.14 built with the patch below.
Defect: the first library load after the file-search cache expires runs
  gc_file_search_cache/1, removing other expired lookup entries. The next
  lookup pays resolution and insertion work instead of the warm-cache cost;
  wall-clock state changes measured Prolog inferences. A zero timeout bypasses
  insertion and the sweep, so it tests an uncached walk rather than this event.
Reproduction: tests/checks/host_workarounds/swi-file-search-cache-sweep.pl,
  ages cache and sweep timestamps under a positive timeout, loads a previously
  unloaded library, and compares the next lookup with two warm lookups.
Patch: tests/checks/host_workarounds/swi-file-search-cache-sweep.patch, against
  swipl-devel V10.1.14 boot/init.pl: a cached path stays a hit while its file
  still satisfies the conditions, whatever its age, and the sweep removes
  only entries that are old and whose file is gone; the flag disables the
  cache at 0 and otherwise paces the sweep. The key carries the expanded
  search path, so a changed path is a new key; a file that appears earlier in
  an unchanged path is seen after the cache is cleared or the process
  restarts, as Python's import cache does for a directory it has already
  listed. The reproduction answers absent and SWI's core, files, library,
  load and save groups pass.
Lifted when: an aged lookup as shipped costs what a warm one costs; the reproduction
  then answers absent and the patch and the entry go together.
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
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped; S_VIRGIN in src/pl-vmi.c.
  This tree runs on 10.1.14 built with the patch below.
Defect: resolving a first inherited call retries and increments inferences
  when the provider's first-clause pointer is nonnull, even when every clause
  is retired. Clause collection clears that pointer and removes the retry,
  so identical logical state has a different first-call cost by GC schedule.
Reproduction: tests/checks/host_workarounds/swi-inherited-empty-predicate-retry.pl,
  compares inherited first/warm calls with retained and collected clauses in
  fresh plain-SWI processes, with direct provider calls controlling both arms.
Patch: tests/checks/host_workarounds/swi-erased-definition-bypasses-loader.patch,
  the same change: S_VIRGIN decides whether a call must resolve its definition
  by `undefinedForCall()`, a clause predicate's live clause count rather than
  its first-clause pointer, so a provider whose clauses are all retired reads
  the same whether or not clause collection has run; inherited first-call
  counts agree in both states and the reproduction answers absent.
Lifted when: SWI-Prolog as shipped reads the live count there, so the
  reproduction prints absent; the patch and the entry go together then.
Record: docs/journal/2026-09-17-host-patches.md;
  docs/journal/2026-09-07-merged-tree-reconciliations.md, the 2026-09-11
  buffered VM trace and unchanged-body foldall controls.
## swi-concurrent-import-removal-resets-provider
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped, this tree running on 10.1.14 built with the patch below; at fc7ef84b949378b729052c3ade79c90ce5416abb;
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
Patch: tests/checks/host_workarounds/swi-concurrent-import-removal-resets-provider.patch,
  against swipl-devel V10.1.14 src/pl-proc.c: `abolishProcedure()` resets the
  definition it captured and locked, the empty child before publishing it
  and the local definition in the other branches, never `proc->definition`
  read again after a concurrent `autoImport()` may have relinked the
  provider. The reproduction, a million abolishes against a million reads,
  keeps the provider's clause and meta declaration and answers absent; SWI's
  core, db, library and engines groups pass.
Lifted when: SWI-Prolog as shipped resets only the captured definition, so the
  reproduction prints absent; the patch and the entry go together then.
Record: docs/journal/2026-09-11-classes-on-metta.md, import repair retains an
  unchanged provider.

## swi-nested-retract-loses-outer-assert
Host: SWI-Prolog 10.1.13 and 10.1.14 as shipped, and upstream master at
  2026-09-16; src/pl-transaction.c, merge_clause_tables. This tree runs on
  10.1.14 built with the patch below.
Defect: committing a nested erase of a clause asserted by its outer transaction
  overwrites the outer GEN_ASSERTA or GEN_ASSERTZ entry with GEN_NESTED_RETRACT.
  Outer rollback restores the erased generation instead of discarding the
  assertion. The clause is invisible outside a transaction but reappears when
  a later transaction advances past its creation generation.
Reproduction: tests/checks/host_workarounds/swi-nested-retract-loses-outer-assert.pl,
  an outer assert, committed inner erase, failed outer transaction, then 100
  unrelated assertions in a later transaction. No engine is loaded.
Patch: tests/checks/host_workarounds/swi-nested-retract-loses-outer-assert.patch,
  against swipl-devel V10.1.14 src/pl-transaction.c: when the nested table
  brings a nested retract of a clause the outer table holds as asserted,
  `merge_clause_tables()` keeps the outer assert marker and completes the
  retract bookkeeping the nested retract deferred (`retract_clause()`), so the
  clause is an in-transaction assertion that was retracted, which the outer
  commit discards and the outer rollback does not revive; the nested commit
  merges its clause table before its predicate table, because that bookkeeping
  records the predicate as modified in the nested table and the predicate
  merge carries it to the parent (merging predicates first destroyed the
  table the bookkeeping then wrote to, a crash). Verified by the
  reproduction and eight scenarios (asserta and retract/1, a grandchild
  erase, a child assert with a grandchild erase under an outer commit, a
  rolled-back nested erase, a pre-existing row, clause GC afterwards); SWI's
  own suite passes on the build (87 of 88, `pldoc:man_links` needs the
  documentation the build omits; tests/transaction among the passes).
Lifted when: SWI-Prolog as shipped merges a nested retract without losing the
  outer assertion, so the reproduction prints absent; the patch and the entry
  go together then.
Record: docs/journal/2026-09-17-host-patches.md, the merge fix and the
  ownership journal it retires; docs/journal/2026-09-11-classes-on-metta.md,
  repository ownership after nested rollback.
