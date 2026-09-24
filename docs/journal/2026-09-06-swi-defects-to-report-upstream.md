# Two SWI-Prolog defects to report upstream
Goal: state both in the form a bug report needs -- version, source line,
mechanism, minimal reproduction, observed fault -- so reporting them is
copying, not re-deriving.
Constraint: nothing here has been posted anywhere. Both are worked around in
this repository; the workarounds are `engine/materialize.pl`'s standing
retirement engine and `extensions/python/metta/_engine.py`'s deferred record
release, and neither is a fix for the defect itself.

Version: SWI-Prolog 10.1.13 (`swipl --version`), package
`swi-prolog 10.1.13-2-ge2aaea4b0-resoluteppa2`, x86_64-linux. Both defects are
still present at `swipl-devel` `dec2acf` (2026-02-24), which is the newest
checkout on this machine.

## 2026-09-06

### 1. `thread_join/2` reads a `pthread_t` that `PL_set_engine` has zeroed

`detach_engine()` sets `info->has_tid` false and memsets `info->tid` to zero
[`src/pl-thread.c:7038`]. `PL_set_engine(New, &Caller)` calls it on the CALLER
[`:7056`, its line `:7077`], so a thread is without a valid `pthread_t` for as
long as it is inside `'$engine_create'/3` [`:4083`, the pair at `:4134` and
`:4148`] or `destroy_interactor` [`:4164`, the pair at `:4168` and `:4170`].

`thread_join/2` reads `info->tid` once, with no `has_tid` test, and passes it
to `pthread_join_interruptible` [`:2898`, the read at `:2927`, the function at
`:2873`], which calls `pthread_timedjoin_np`. A join that lands in that window
therefore calls `pthread_timedjoin_np(0, ...)` and glibc dereferences a null
`struct pthread`.

Observed: SIGSEGV in `__pthread_clockjoin_ex` at
`./nptl/pthread_join_common.c:47`, with `threadid=0x0` and `rdi 0x0` in the
core.

Reproduction, no library involved:
`tests/prolog/probes/engine_join_window.pl destroy` parks a worker inside
`engine_destroy/1` with a message queue and joins it from the main thread; it
dies 10 runs out of 10. The same probe's `post`, `next` and `create_idle` modes
join cleanly 10 out of 10, which locates the window at `PL_set_engine` rather
than at engines generally.

Suggested fix: `thread_join/2` refusing, or waiting, when `info->has_tid` is
false. The field already exists and is already maintained.

### 2. `signalGCThread()` dereferences `LD` without a null guard

`unregister_atom()` calls `considerAGC()` when an atom's last reference goes
[`src/pl-atom.c`, the call at the end of `unregister_atom`], and `considerAGC`
calls `signalGCThread(SIG_ATOM_GC)` once `GD->atoms.unregistered` passes
`GD->atoms.non_garbage + GD->atoms.margin` [`src/pl-atom.c:1475`].

`signalGCThread()` opens with `truePrologFlag(PLFLAG_GCTHREAD)`
[`src/pl-thread.c:7353`, the test at `:7358`], and that macro is
`LD->prolog_flag.mask.flags[(flag-1)/(sizeof(int)*8)] & ...`
[`src/pl-incl.h:2839`]. On a thread with no engine `LD` is null. The
`raiseSignal(LD, sig)` it falls through to IS guarded [`src/pl-wam.c:258`], and
so is the `LD->atoms.unregistering` write a few lines earlier in
`unregister_atom` [`src/pl-atom.c:1639`, guarded by `if ( HAS_LD )`] -- the
flag read is the one that is not.

Observed: SIGSEGV at `libswipl+0x12e563`, which under gdb is
`test BYTE PTR [r8+0x690],0x10` two instructions after `call __tls_get_addr`,
with `r8 == 0`.

Reproduction: `PL_erase` on a thread with no engine, from foreign code. Through
janus that is 50,000 `janus_swi.Term`s built on a worker thread, the engine
detached, and the Terms dropped: 5 runs out of 5 die, against 5 out of 5 clean
when the same Terms are dropped with the engine still attached. Lowering
`agc_margin` makes the AGC threshold reachable sooner.

Suggested fix: `signalGCThread()` testing `LD` before reading the flag, as
`raiseSignal` already does. Foreign code is allowed to call `PL_erase` from an
unattached thread -- `PL_erase` needs no engine of its own -- so the atom
bookkeeping it reaches should not require one either.

### Adjacent, lower confidence

Lowering `agc_margin` to 1 or 500 and churning janus's per-call engine
attach/detach reaches a THIRD fault: `unregister_atom` -> `considerAGCType`
reading `p->type` at `libswipl+0xdf022` with a garbage `p->type`, under
`PL_thread_destroy_engine`. It looks like an atom reclaimed while a reference
to it was still being dropped, i.e. an AGC race the low margin makes frequent
rather than a consequence of either defect above. Not reduced to a minimal
case, and reported here only so the next person meeting it knows it is a third
thing.

### Not SWI: janus_swi 1.5.3

`Term.__del__` clears `self.record` where it means `self._record`
[janus_swi 1.5.3 `janus.py:485-488`], so a released Term keeps a dangling
record id and the next crossing that carries it reaches `PL_recorded` on freed
memory: `./src/pl-rec.c:1560: copy_record___LD: Assertion failed: 0`, the
`default:` arm of the switch over record tags. Twelve-line reproduction:
release a Term with `__del__()` and pass it to `query_once`.

### Also janus, found later the same day: `py_iter/2` never checks `PyIter_Next`

Both `state->next = PyIter_Next(state->iterator)` calls in janus's `py_iter/2`
are unchecked, while the `PyObject_GetIter` above them is wrapped in
`check_error`. `PyIter_Next` returns NULL for exhaustion and for a raise
alike, so a Python generator that raises is indistinguishable from one that is
exhausted: the Prolog goal continues over a silently truncated answer set and
the still-set Python exception surfaces at whatever C function returns a value
next. In the common case that is `_Py_CheckFunctionResult`'s `SystemError`;
inside janus's own error path it is fatal, because `py_record` asks Python to
build a `Term` while the error indicator is set, CPython answers NULL, and
`Py_SetPrologErrorFromObject` increments that NULL.

Reproduction, engine-free: `findall(X, py_iter(g(), X), L)` over a generator
that yields 1 then raises answers `L = [1]`, runs the goal's `assertz` marker
afterwards, and no Prolog `catch/3` sees anything. Through this library the
plain `Space.match(pattern, inferences=20_000)` door exited 139 on the trunk
before ff997ad3. The library's side of the repair is the
`["x","raise",Class,Exception]` terminal frame carried across every `py_iter`
door and re-raised through `stream_reraise/1`, recorded in
`2026-09-06-limits-inside-a-provider-callback.md`.

Suggested fix: check `PyIter_Next`'s NULL with `PyErr_Occurred()` at both
sites and convert through the same path `check_error` uses, so a raising
iterator raises in Prolog the way a raising deterministic callback already
does.

## 2026-09-07: answer subsumption under a watch, a shared moded table, and the count restraint

Found while compiling cache policies to `table/1` options
(`2026-09-06-cache-policies-are-the-engines-own-options.md`), each in a
fresh `swipl -q` process on 10.1.13, probes under `ai-tmp/cp/`:

- A shared answer-subsumption table (`table p(_,_,lattice(j/3)) as shared`)
  raises `type_error(trie, <clause>(...))` from `trie_gen/2` on its second
  call, with any watch or none (`probe13_shared_*`). Private works.
- An incremental or monotonic answer-subsumption table re-evaluates to a
  wrong table after a write: `[]` on the first re-evaluation of the shared
  variant, and for a private one two answers for one input,
  `[c-3, c-1, a-2, b-1]` where the minimum is `c-1`, and `a-6` for a path
  that costs 2 (`probe13_private_incremental`, `probe13_private_monotonic`).
- A subsumptive table that is also incremental or monotonic raises
  `existence_error(reset, call_info(...))` ("Cannot catch continuation
  through findall/3", or "No matching reset/3 call" outside findall) on the
  first call after an invalidating write (`probe7`).
- `table p/2 as max_answers(N)` never calls `prolog:tripwire/2` and takes
  the bounded-rationality path whatever `max_answers_for_subgoal_action`
  says; the process-wide `max_answers_for_subgoal` flag does call it
  (`probe8`). The manual (7.11) says the tripwire actions apply to both.
- `dynamic([P], [monotonic(false)])` is accepted and leaves the monotonic
  property standing; `incremental(false)` clears its property (`probe18`).
- `table p/2 as (monotonic, lazy)` propagates a dynamic fact into the table
  at the assert, as the eager form does, and only marks the table invalid
  until its next call (`probe16`); the manual (7.8.1) says the answer is
  queued until then.

The library refuses the first three combinations at compile time with the
measurement in the message, routes the count restraint through
`call_delays/2`, releases the monotonic property through the attribute door,
and compiles `lazy` as written.

## 2026-09-24: both patched here, one found twice, one with a second field

Item 2 above is patched in this tree's host since 2026-09-24,
`swi-gc-signal-engineless-thread` in docs/host-workarounds.md. The C seat met
it again erasing dropped handles' records on a plain pthread, and upstream
master at d7d2a2bb8f5b (fetched 2026-09-24) still reads the flag first. The
fix went one step past the suggestion above: with no engine,
`signalGCThread()` hands the request to a GC thread that is already running,
found through `gc_running()`, which reads only `GD`. Testing `LD` and
returning alone avoids the crash but drops the request, and with a GC thread
running, 20000 records erased on an engineless thread then left the atom-GC
count at 1 for five seconds, where the handoff collected them.

### 3. `abolishProcedure()` builds an import link's replacement by hand, and two fields drifted

The branch of `abolishProcedure()` commented `imported predicate; remove link`
[`src/pl-proc.c`, 10.1.14 and master at d7d2a2bb8f5b, last changed at
ca9227829f75] allocates the procedure's new definition and fills it field by
field beside `lookupProcedure()`, which its own comment says it "should be
merged with". Two fields differ. `shared` stays 0 where `lookupProcedure()`
counts the procedure's reference, so once a second module links the
definition through `shareDefinition()`, the first of the two procedures
`PL_cleanup()` unallocates frees it under the other, whose
`unallocProcedure()` then decrements freed memory. And the argument info is
allocated without being zeroed, and `createSupervisor()` and
`update_primary_index()` read it through `setDefaultSupervisor()`.

Reproduction, pure SWI, under valgrind: a file that runs
`:- import(system:exists_file/1).`, `:- redefine_system_predicate(exists_file(_)).`,
`exists_file(_).` and `probe :- probe_m:exists_file(x).`, consulted by a host
program that calls `probe/0` and then `PL_cleanup(0)`: 4 errors from 2
contexts, the invalid read and the uninitialised one, against 0 for the same
program without the import line. Any `redefine_system_predicate/1` of a
predicate the module has already linked takes the branch.

Suggested fix: one initialiser for both, which is this tree's patch,
`swi-unlinked-definition-uninitialised.patch`.

### 4. `Prolog.url_properties()` reports a missing size as NaN

`url_properties(url)` in `src/wasm/prolog.js` [line 1094 at 10.1.14, and
unchanged on master at d7d2a2bb8f5b] parses the size with
`parseInt(r.headers.get("content-length"))` and then tests
`if ( ! size instanceof Number ) size = -1;`. That parses as
`(!size) instanceof Number`, a boolean tested against Number, so it is
always false and a response without Content-Length reports `size: NaN`
where -1 was meant. esbuild flags the line as suspicious-boolean-not when it
bundles the loader.

Reproduction under Node, against a local server that answers HEAD with
`Transfer-Encoding: chunked` and so sends no Content-Length:

```js
const server = createServer((req, res) => { res.writeHead(200, { "Transfer-Encoding": "chunked" }); res.end(); });
await new Promise((ok) => server.listen(0, "127.0.0.1", ok));
const swipl = await bootHost("extensions/node/_host");   // tools/wasm-host/host.mjs
const props = await swipl.prolog.url_properties(`http://127.0.0.1:${server.address().port}/x.pl`);
// props.size is NaN, status 200, last_modified set
```

Nothing this tree runs reads the value. `library(wasm)`'s one reader of
`size`, the `http(size, URL, Size)` clause, is compiled out by
`:- if(true). http(_,_,_) :- !, fail.`, its load hook's `load_options/4` reads
`status` and `last_modified` alone, and tsmetta never calls
`url_properties`. Suggested fix: `if ( Number.isNaN(size) ) size = -1;`.

### 5. `expand_file_name/2` copies from a path it has just unterminated

`expand()` in `src/os/pl-glob.c` [the meta-segment branch, lines 697-713 at
10.1.14, and the same lines on master, whose last change to the file is
9cb544583d24 of 2026-01-18] builds `path` from the directory being expanded
and its prefix, and when `path` does not end in `/` it appends one with
`path[plen++] = '/'`, overwriting the terminating NUL without writing another.
For every entry the pattern matches it then runs `strcpy(newp, path)`, which
scans past `plen` into stale stack bytes until it meets a NUL, followed by
`strcpy(&newp[plen], e->d_name)`, which overwrites from `plen` on. So the
returned list is right whatever the stale bytes hold. Only two things depend
on them: how far the first copy runs, and, with no NUL left within the
buffer, whether `__strcpy_chk` aborts the process.

Reproduction under valgrind, over `d/one/a.txt`, `d/one/b.txt` and
`d/two/c.txt`: `expand_file_name('d/*/*', L)` reports 3 conditional jumps on
uninitialised values in `__strcpy_chk` under `pl_expand_file_name2_va`, one
per entry matched below the first expanded level, while `d/*` and `d/one/*`
are clean, because a first-level prefix keeps its slash. The lists are right
in all three. This engine's boot through janus makes 316 such reads, all
before a twin's measured window: none fall inside it for class_grains or
reference_maps (measured 2026-09-24 by exiting the same valgrind run just
before and just after the window), and the code shows they cannot move an
inference count in any case.

Suggested fix: write `path[plen] = EOS;` after appending the separator, or
copy the prefix with `memcpy(newp, path, plen)`.


## 2026-09-24: build 9, ten patched here and one recorded

Items 6 to 15 are patched in this tree's hosts since build 9. Each but item
11 is a `Patch:` entry of the same key in docs/host-workarounds.md with its
reproduction; item 11's fix is built into the hosts, but nothing this engine
runs meets its defect, so it has no entry. Item 16 is recorded and not
patched, since nothing this engine runs reaches it.
Every location is at 10.1.14 and was read again on master at d7d2a2bb8f5b
(packages-clib master for item 11), fetched 2026-09-24, where each defect is
unchanged.

### 6. `trie_gen/2,3` follow a child an emptied hashed root does not have

`add_choice()` in `src/pl-trie.c` starts a general enumeration of a node's
hashed children table with `advanceTableEnum(ch->table_enum, &tk, &tv)` and
uses `tk` and `tv` without looking at its return. The table can be empty. A
node's children become a hash table at its second key, and `prune_node()`
removes a deleted key's node from its parent's table but keeps the root's
table when the last key goes. So once `trie_delete/3` has removed every key of
a trie that held two, `trie_gen/2,3` take a child from an enumeration that
produced none and follow it. On a native host that is SIGSEGV. On the
WebAssembly host the stray read lands in linear memory, does not trap, and
happened to answer `[]`.

Reproduction:
`trie_new(T), trie_insert(T, a), trie_insert(T, b), trie_delete(T, a, _), trie_delete(T, b, _), findall(K, trie_gen(T, K), Ks)`
dies on 10.1.14 and on master. A trie that only ever held one key has no
table, and one still holding a key enumerates it, so neither dies.

Suggested fix: this tree's patch. When `advanceTableEnum()` finds nothing,
free the enumerator and pop the choice, as the `var_mask` branch above does
on failure; `is_leaf_trie_node()` already reads an empty table as no
children. `swi-trie-gen-empty-hashed-root`.

### 7. Halt passes over a thread that is created and not yet running

`exitPrologThreads()` in `src/pl-thread.c` joins the threads that finished
and signals the running ones, and a thread `thread_create/3` has marked
`PL_THREAD_CREATED` falls to `default: break;`: it is neither signalled nor
counted in the wait, and it then runs its goal while `PL_cleanup()` frees the
module tables `callProlog()` looks the goal up in. It could not be signalled
in any case, because `PL_thread_raise()` wants the `LD_MAGIC` that
`initialise_thread()` sets only at its end.

Reproduction: a C host that calls `PL_initialise()`, runs
`forall(between(1, 8, _), thread_create(true, _, [detached(true)]))` and then
`PL_cleanup(0)` dies 16 runs of 20, of SIGSEGV in `lookupModule()` under
`start_thread()` while the main thread is in `unallocModule()`, and once at
the `!queue->waiting` assertion in `destroy_message_queue()`.

Suggested fix: this tree's patch. `exitPrologThreads()` re-reads a created
thread's status under `L_THREAD`, sets its `exit_requested` and counts it;
`start_thread()` reads that under the same lock as it marks itself running,
and leaves through its cleanup handler without calling the goal, so
`freePrologThread()` posts the semaphore the count waits for. The same patch
closes a creation that straddles the start of halt: `pl_thread_create()`
repeats its `GD->halt.cleaning` test under `L_THREAD` where it marks the
thread created, and `exitPrologThreads()` takes `L_THREAD` once before its
scan. `swi-halt-passes-created-thread`.

### 8. An engine's query offers a foreign yield `engine_next/2` cannot take

`engine_create/3` opens its engine's query with `PL_Q_ALLOW_YIELD` for
`engine_yield/1`, and that flag is all `'$can_yield'` (`src/pl-pro.c`),
`PL_can_yield()` (`src/pl-wam.c`) and the foreign-yield check in
`I_FEXITNDET` (`src/pl-vmi.c`) read. So inside an engine `'$can_yield'`
succeeds and a foreign yield is let through, and it returns `PL_S_YIELD` to
`engine_next/2`, whose `interactor_post_answer()` handles `engine_yield/1`'s
code alone. Its `default:` branch raises `domain_error(engine_yield_code,
255)` from inside `WITH_LD(activate_interactor(th))` and returns without
`suspend_interactor()`, so the calling engine is never restored.

Reproduction: a C host registers a foreign predicate that returns
`PL_yield_address(&anchor)` once and succeeds when resumed. In a query opened
with `PL_Q_ALLOW_YIELD` it yields and resumes, and `'$can_yield'` succeeds,
both as intended. Inside `engine_create(X, ..., E), engine_next(E, A)`
`'$can_yield'` also succeeds, and the same yield kills the process with
SIGSEGV. On the WebAssembly host, library(wasm)'s `sleep/1` asks
`is_async/0`, which is `'$can_yield'`, and awaits a promise inside any engine,
which aborts the process.

Suggested fix: this tree's patch. `engine_create/3` marks its query with a
kernel-only flag, `PL_Q_INTERACTOR`; one test reads `PL_Q_ALLOW_YIELD`
without it, and `PL_can_yield()`, `'$can_yield'` and the foreign-yield check
all ask it, so a foreign yield inside an engine is refused where it is made
with the existing permission error and library(wasm) falls back to
`system:sleep/1`. The `default:` branch of `interactor_post_answer()` is
unreachable for a foreign yield after that and still loses the caller's
engine; restoring it there, with `suspend_interactor()` around the raise as
the `PL_S_EXCEPTION` branch does, would make it harmless on its own.
`swi-engine-query-offers-foreign-yield`.

### 9. The JavaScript bridge starts every `:=` chain from `window`

`eval_chain()` inside `prolog_js_call()` in `src/wasm/prolog.js` begins
`obj = obj||window`, so a chain with no receiver starts from `window` before
it looks at the chain, and Node and Web Workers have none. Every such `:=/2`
raises `ReferenceError: window is not defined`, `X := prolog.promise_sleep(S)`
in library(wasm)'s own `sleep/1` included.

Reproduction, under Node:
`expand_goal((X := 'Math'.max(1, 2)), G), call(G)` raises
`js_eval_error('ReferenceError: window is not defined', _)`.

Suggested fix: `obj = obj||globalThis`, which is `window` in a page, `self` in
a worker and `global` in Node. `swi-wasm-js-bridge-assumes-window`.

### 10. A stack the heap refuses to grow is reported as a stack over its limit

When `stack_realloc()` fails in `grow_stacks()` (`src/pl-gc.c`), the function
returns the stack's `overflow_id`, the code a stack at its limit returns, and
`outOfStack()` (`src/pl-alloc.c`) raises `resource_error(stack)`, printed as
`Stack limit (...) exceeded`, though the limit was checked earlier in the same
call and did not bind.

Reproduction: under `ulimit -v 1000000`,
`set_prolog_flag(stack_limit, 8000000000), numlist(1, 200000000, _)` is
refused with `resource_error(stack)` at a `globalused` of 524,287 KB. On the
WebAssembly host the refusal lands at the same depth whatever the stack limit
is.

Suggested fix: this tree's patch. `grow_stacks()` keeps its codes and records
per thread that its last growth failed in `malloc()`; `outOfStack()` writes
`resource_error(no_memory)` then. Raising `ERR_NOMEM` from
`raiseStackOverflow()` instead does not survive: `PL_error()` builds its ball
on the global stack the heap has just refused, asks the heap again and
recurses until the C stack overflows. `swi-heap-refusal-reported-as-stack-limit`.

### 11. The alarm scheduler thread returns holding its mutex

`alarm_loop()` in `packages/clib/time.c` takes `mutex` when it starts and
returns when it sees `sched->stop` without releasing it. `cleanup()`, the
library's halt hook, sets `stop`, removes every pending alarm with
`removeEvent()`, which signals the scheduler each time, and then locks
`mutex` itself. A scheduler that wakes between two removals leaves holding
the mutex, and halt waits for ever in `cleanup()`.

Reproduction: `swipl -g "use_module(library(time)), forall(between(1, 1000, _), alarm(1000, true, _))" -t halt`
does not exit, in the first of twenty runs each time it was tried; with one
pending alarm the window is a few instructions wide and sixty runs all exited.

Suggested fix: `UNLOCK()` after the loop. This tree's hosts carry that fix,
though nothing this engine runs halts with an alarm pending: `halt/1` unwinds
`call_with_time_limit/2`'s cleanup, which removes its alarm, so twenty runs of
a program exiting inside a max-time bound all exited on an unpatched host.

### 12. Destroying an engine inside a tabled leader leaves its shared tables to the dead engine

`finished_leader/4` in `boot/tabling.pl` is the cleanup of the
`setup_call_catcher_cleanup/4` that runs a tabled leader. It discards the
leader's component for `exception(_)`, accepts `exit` and `fail`, and prints
`tabling(unexpected_result(...))` for anything else. Destroying an engine
suspended inside a tabled leader discards its frames, so the cleanup receives
`!`: it prints the message and skips `'$tbl_table_discard_all'/1`. The
component is freed with the engine while a shared table still names the dead
engine as its owner and points at its worklist. The next claim then either
waits on `GD->tabling.cvar` for an owner that is gone, when the claimant has
another thread id, or takes the table as its own and reads the freed worklist,
when it is an engine attached under the dead one's id: SIGSEGV in
`unify_table_status()`. A build without threads prints the message on every
such destroy.

Reproduction: with `:- table p/1 as shared.` and a `p/1` that yields once
through `engine_yield/1` before answering `a` and `b`,
`engine_create(X, p(X), E), engine_next(E, inside), engine_destroy(E), findall(Y, p(Y), Ys)`
never returns on a threaded 10.1.14; the same destroy followed by a second
engine asking `p/1` exits 139.

Suggested fix: this tree's patch. `finished_leader/4` treats `!` as it treats
an exception and discards the component, which resets each incomplete table
to fresh and releases it. `run_leader/5` is deterministic, so `!` reaches the
cleanup only when the leader's frames are discarded from outside, and
`'$tbl_table_discard_all'/1` already leaves a merged component alone.
`swi-destroyed-leader-keeps-shared-table`.

### 13. `'$tbl_reeval_prepare'/2` writes past its two arguments after waiting

In a threaded build, `'$tbl_reeval_prepare'/2` in `src/pl-tabling.c` claims a
shared table asking for a clause reference, and when the claim comes back
with the table complete it returns `PL_unify_atom(A3, cref)`. The predicate
has two arguments, so A3 is a term reference past them in the foreign frame:
when the thread it waited for re-evaluated the table, the call writes the
table's clause there and succeeds with its Variant unbound, where its
contract is to fail, as the check below it does for a table re-evaluated
before the call ("someone else re-evaluated it").

Reproduction: with `:- table sr/1 as (incremental,shared)` over an
incremental dynamic `sr_d/1`, a second thread starts re-evaluating `sr/1`
after `sr_d(2)` is asserted and signals main, which calls
`'$tbl_reeval_prepare'/2` on the table's trie while the thread holds it.
The call succeeds with its argument unbound on 10.1.14; the table then
answers `[1,2]` either way.

Suggested fix: this tree's patch. The threaded branch claims with no clause
reference and falls through to the falsecount check below it, which fails
for a table the other thread re-evaluated and prepares one that still needs
it. `swi-reeval-prepare-writes-past-its-arguments`.

### 14. A claim waits for ever for an owner suspended beneath it on one OS thread

`claim_answer_table()` in `src/pl-tabling.c` waits on `GD->tabling.cvar`
for whichever thread or engine owns an incomplete shared table, and
`is_deadlock()` finds only cycles of threads each waiting for a table. An
owner can be suspended beneath its claimant on the same OS thread: engine 1,
completing a shared table, runs a second engine through `engine_next/2` or
`engine_post/3`, and the second engine asks for the same variant. It waits
for engine 1, which runs again only once the second engine returns, and
engine 1 waits for no table, so nothing sees a cycle and the process hangs.
Through janus it happens whenever a Python function Prolog calls while one
engine completes a table pulls a lazy view of the same call.

Reproduction: engine 1 completes `p/1` (`table p/1 as shared`), whose first
clause asks for `p/1` from a second engine it holds in `engine_next/2`. On
10.1.14 the process never returns; the main thread sits in
`pthread_cond_timedwait()` under `claim_answer_table()`, under
`'$tbl_variant_table'/6`, under `engine_next/2`.

Suggested fix: this tree's patch. `interactor_post_answer_nolock()` records
the calling engine in the callee's new `LD->thread.caller` for as long as
the nested `PL_next_solution()` runs, and `claim_answer_table()` walks that
chain before it registers as waiting. An owner found there raises
`permission_error(wait, shared_table, Variant)` rather than throwing
`deadlock`, which `restart_tabling/3` would retry for ever; the owner's
leader receives the exception and discards its component. An owner on
another OS thread, or one suspended beneath nothing, is waited for as
before. `swi-shared-table-waits-for-owner-beneath`.

### 15. A table declared `as shared` is private to each engine without threads

`get_answer_table()` in `src/pl-tabling.c` sets `shared = false` for every
table when `O_PLMT` is undefined, and the shared variant table, its node pool
and table ownership (`trie.tid`, `claim_answer_table()`) exist only under
`O_PLMT`. So in a build without threads, the WebAssembly one, the declaration
is accepted and has no effect: two engines asking a shared table each
evaluate it, and a table dies with the engine that filled it.

Reproduction, on the WebAssembly host: with `:- table p/1 as shared.` and
`p(X) :- flag(p_body, N, N+1), member(X, [a,b,c]).`, two engines that each
run `findall(X, p(X), L)` both answer `[a,b,c]` and the flag reads 2.

Suggested fix: this tree's patch, which is a design rather than a one-line
repair, so it is offered for upstream to weigh. The shared variant table,
ownership, waiting, deadlock detection and `shared_table_space` move from
`O_PLMT` to `O_ENGINES`, and only the blocking (the mutex, the condition
variable, `wait_for_table_to_complete()`) stays under `O_PLMT`. An owner
without threads is the engine's own tabling id, since every engine there runs
attached under one thread id. A claim that meets a table another engine owns
answers `wait(Owner)`, and `boot/tabling.pl` retries after `tabling_wait/2`,
which calls a multifile `prolog:tabling_wait/1` for the embedding host to
suspend the engine and raises `permission_error(wait, shared_table, Goal)`
where no hook does. Re-evaluating a complete shared table answers the
table's compiled clause, as the threaded branch does, so a re-evaluating call
counts one call to a completed table on both builds; a moded table answers its
trie, which `moded_gen_answer/3` reads. A threaded build compiles
`pl-tabling.o` to the same instructions apart from `__LINE__` immediates.
SWI's tabling suite passes on both builds, 214 single-threaded (with a new
randomised engine-scheduler suite) and 174 threaded.
`swi-threadless-shared-table-private-per-engine`.

### 16. An answer holding a `'[]'` compound leaves an exception pending

`toJSON()`'s compound branch in `src/wasm/prolog.js` reads a functor's name
through `atom_chars()`, whose `get_chars()` passes `CVT_EXCEPTION`, and the
reserved `[]` of SWI-7, which the block syntax `A[B]` builds as a functor
name, is not text to it. The conversion answers `null` for the name and
leaves `type_error(atom, [])` pending, and the next query from JavaScript
fails with it, once.

Reproduction: `swipl.prolog.query("compound_name_arguments(X, [], [a, b])").once()`
answers `{"$t":"t","null":[["a","b"]]}`, and the following
`swipl.prolog.query("X = 1").once()` answers
`'$c_call_prolog'/0: Type error: atom expected, found [] (an empty_list)`.

Suggested fix: read a functor's name without `CVT_EXCEPTION`, or clear what a
failed conversion raised, and give `[]` a name the JSON side can carry.
