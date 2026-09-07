<!--
Purpose: document thread ownership, async execution, lifecycle rules, and serialization boundaries.
Guarantees: public names in the boundary table match the narrow surface.
[tested: npm run docs:build; commit=WORKTREE]
-->

# Threads, tasks, and what pickles

Python's own documentation states, per type, what is atomic, what locks, and what a caller must serialize. This page is that statement for MeTTa. Every claim on it is pinned by a named test in the suite, so the guarantees are enforced rather than intended.

## One process, one home engine

A process holds one embedded Prolog runtime. The thread that first uses it holds the home engine, and every other bare thread's calls serialize on one lock around that engine, so calling any `Space` method from any thread is safe and correct, just not parallel (`test_bare_threads_share_the_home_engine_serialized`). The lock choice is per OS thread and decided once, when a thread attaches an engine, not per call.

## State cells and compound updates

`cell.value` reads and `cell.value = replacement` writes one thread-shared
engine cell. Each property operation is serialized. The compound statement
`cell.value += 1` is still a read followed by a separate write, so two threads
can both read the same value and lose one increment. Engine-call serialization
does not make the pair atomic
(`test_state_increment_requires_a_lock_around_read_modify_write`).

Put a caller-owned `threading.Lock` around the whole read-modify-write when
Python owns the update. When MeTTa owns it, import `lib_thread` and put the
whole expression under `with-lock`. A one-atom space can instead act as a
token: `Space.take()` removes and claims the atom, and adding the replacement
releases the next waiter. Restore the atom if the computation raises. The lock
or token must cover both the read and the write.

Real parallelism is a second engine, and there are four ways to get one:

- `metta.parallel.engine_thread()` attaches an engine to the current thread for a block, releasing exactly what it attached (`test_engine_thread_owns_only_its_attachment`). Inside the block this thread's calls stop sharing the home lock; measured 1.94x, 3.90x and 7.26x at 2, 4 and 8 threads.
- `m.pool(workers=n)` owns n threads that each hold their own engine (`test_each_worker_holds_a_distinct_engine`), proves genuine overlap with a barrier rather than a clock (`test_pool_runs_work_concurrently`), answers `map` in input order however workers finish, and reports every failure, one plainly and several as one `ExceptionGroup` in input order (`test_map_raises_every_failure_in_input_order`).
- `metta.parallel.process_pool(workers=n, boot=...)` owns n PROCESSES that each boot an engine of their own and share nothing. It is the section below.
- `m.parallel(...)` fans out INSIDE the engine through `concurrent_and/2`, one SWI thread per branch. Answers arrive in completion order, and there is deliberately no `inferences=` bound on it, because the counter counts the calling thread while the work runs in workers; an unenforceable bound is worse than an absent one.

Functions compile into shared modules, so an attached engine sees what the home engine compiled; only Prolog global variables are per engine, which is why the current-space scope below behaves.

## Both pools are executors

`EnginePool` and `ProcessPool` are `concurrent.futures.Executor`, so nothing
has to learn a second vocabulary to drive them:

```python
with m.pool(workers=4) as p:
    futures = [p.submit(m.eval, S.solve(n)) for n in range(8)]
    for future in as_completed(futures):
        print(future.result())
```

`submit`, `map`, `starmap`, `imap_unordered`, `shutdown(wait=, cancel_futures=)`
and `with` are the whole surface; `as_completed` and `wait` read the Futures.
`close(wait=)` is the pools' own older name for `shutdown(wait=)`.

Every fan-out door SUBMITS its whole input and then answers an **iterator over
results that already exist**, so `list(p.map(f, xs))` is how you compare one to
a list, and a `map` written for its side effects still runs. The eagerness is
the point rather than an accident: `Executor.map`'s lazy reading makes a
side-effecting map do nothing at all until someone consumes it, which is a
silent no-op this library will not ship (measured 2026-09-07: planting the lazy
reading turned eight passing tests red, three of them by doing nothing and five
by hanging on their barriers).

`map` and `starmap` take Executor's `timeout=`, `chunksize=` and `buffersize=`.
`chunksize` is honoured rather than ignored (`ThreadPoolExecutor` ignores it):
a chunk is one submitted task, so its items share one worker in order and a
chunk is one failure unit. `timeout=` raises `Timeout` and cancels whatever has
not started.

## The other boundary: a process per engine

A thread pool shares this process's spaces, equations and compiled functions,
which is why a callable closing over a handle is the right thing to write
there. A process pool shares nothing, which is the point of it: one program
cannot see another's equations, a run cannot corrupt the caller's space, and a
worker that dies takes only its own work with it.

```python
with metta.parallel.process_pool(3, boot="(= (sq $x) (* $x $x))") as p:
    for answers in p.map(metta.parallel.program, ["!(sq 3)", "!(sq 4)", "!(sq 5)"]):
        print(answers)
```

An engine costs a whole boot per worker where a thread costs an attachment
(measured 2026-09-07: 2,248M instructions:u for the boot, 0.37s wall with the
`.qlf` set present on an idle-ish box), so reach for `m.pool` unless isolation
is what you want.

An engine cannot cross a process boundary, so a worker is sent WORK rather than
a callable over a handle. The two work units are ordinary functions:
`metta.parallel.program(source)` runs program text on the worker's engine, and
`metta.parallel.call(head, *arguments)` applies a head the pool's `boot=`
defined. They are ordinary functions in this process too, which is what makes
`map(program, texts)` the pool's own oracle for `pool.map(program, texts)`
(`test_a_process_pool_answers_what_the_sequential_run_answers`).

A call that reaches a live handle refuses at `submit`, naming the remedy. The
refusal is not there because a handle fails to cross; it is there because it
succeeds: a `Space` pickles by NAME, so a worker receiving one would open its
own space of that name, answer about it, and raise nothing. The walk reads the
callable's closure, the globals it names, its defaults, a `partial`'s parts and
a bound method's receiver, two callable hops deep
(`test_a_closure_over_a_space_refuses_at_submit`,
`test_a_module_global_space_refuses_at_submit`). An ANSWER that is a handle
refuses inside the work unit, where no submit-time walk could see it.

The pool uses the `forkserver` start method on Linux and `spawn` elsewhere, and
REFUSES `fork` at construction. SWI-Prolog does not survive a fork: its own
`PL_cleanup_fork()` is documented for the fork-then-exec case only and warns
that "the behaviour of mutexes is undefined over fork()", and `fork/1` refuses
off the only thread because "Forking a Prolog process with threads will
typically deadlock". A child that inherits one anyway refuses at its first
crossing rather than answering out of half a runtime
(`test_a_forked_child_refuses_the_inherited_engine`), which matters because the
corruption is not immediate: a forked child on this box happily answered
`!(+ 3 4)` and even `!(hyperpose ...)`.

**The one trap.** `forkserver` runs your `__main__` ONCE in its fork server and
forks each worker from it, so an engine booted at IMPORT time is booted in that
server and inherited by every worker. Every work unit then refuses, naming this.
Keep the boot under `if __name__ == "__main__":`, which spawn and forkserver
both want anyway, or pass `mp_context=multiprocessing.get_context("spawn")` so
each worker does its own import
(`test_a_forkserver_worker_that_inherited_an_engine_says_so`).

## asyncio: one worker, contexts that travel

`AsyncMeTTa` puts every engine call on one dedicated worker thread and serializes requests whole, aiosqlite's architecture, so two tasks never interleave inside an evaluation. Scoped state travels correctly: `with m.limits(...)` and `m.batch()` ride `contextvars`, each request copies the submitting task's context, and the worker runs inside it, so a with-block on the event loop bounds engine work happening on another thread (`test_aio_scoped_limits_cross_to_the_worker`). Interpreter shutdown attempts every worker and reports the failures together (`test_aio_shutdown_handler_attempts_every_worker`).

The current-space context is not Python state at all: the engine tracks it in a Prolog global (`'$metta_module'`) set and restored around each evaluation, per engine and therefore per thread, so tasks sharing the aio worker cannot clobber each other's space. The one `threading.local` in the package is the per-thread lock choice above, and it is deliberately thread-keyed rather than a `ContextVar`: a Prolog engine attaches to an OS thread, so two tasks on one thread genuinely share one engine and must share its lock decision.

## Subscriptions, satellite cursors, finalizers

Subscription state lives behind one registry lock, real locking rather than a bet on the GIL, so the queue and cancellation are safe under free-threaded Python too (`test_subscription_queue_is_thread_safe`, `test_subscription_cancel_is_thread_safe`). A callback runs synchronously inside the write that caused it, on the writing thread; `cancel()` waits for deliveries already in flight (`test_subscription_cancel_waits_for_inflight_delivery`), and `events()` blocks its consumer thread on a condition variable, ending at cancellation.

Core `Space.match()` is eager. Streaming cursors belong to the `aio` and `remote`
satellites. Individual pulls serialize on their owning engine or connection, but
the iteration protocol itself is single-consumer, exactly as with every Python
iterator, so share rows rather than a cursor. An abandoned satellite cursor is
reaped by a finalizer that may run on whatever thread collection runs on,
warning as it does (`test_abandoned_stream_warns_before_reaping`); a `Handle`'s
`__del__` is likewise a best-effort release from an arbitrary thread, with
explicit `release()` or a `with` block as the deterministic path.

A `RemoteSpace` client builds one stateless HTTP request per operation, so concurrent use is safe; the serving side runs every operation through one engine worker, interleaving whole operations (`test_threaded_clients_interleave_whole_operations`).

## What pickles

Serialization guarantees live here too, because they are the other half of "what crosses a boundary":

| object | pickles? | why |
|---|---|---|
| `Symbol`, `Variable`, `Expression`, `Grounded` of plain values | yes, by value | `test_atoms_pickle_by_value` |
| `Grounded` of a live object and `Handle` | refuses, by design | process-local identity cannot cross (`test_process_local_grounded_values_refuse_pickle`) |
| `Rows` and `Row` | yes | `test_rows_copy_and_pickle_protocols` |
| `lint` `Finding` | yes, with a stable public identity | `test_finding_retains_public_pickle_identity` |
| `Space` | handle name only | stored atoms and the live engine do not cross; `save()`/`load()` persist content |
| `MeTTa`, satellite cursors, subscriptions | no | live engine state; the remote protocol's wire forms cross processes |
| a callable reaching a `Space`, `MeTTa`, `Runtime` or `EnginePool` | refused by `ProcessPool.submit` | it would pickle, and name a different space in the worker (`test_a_bound_method_of_a_space_refuses_at_submit`) |
| `metta.parallel.program` and `metta.parallel.call` | yes, by reference | module-level functions carrying only text and atoms, which is what a worker is sent instead |

Pickling an atom only makes a process argument transportable by value. Pickling
a `Space` carries its name as a handle, not its stored atoms. Neither operation
turns the source space into shared storage. Threads in one process can use the
same local `Space` under the rules above. Separate processes have separate
runtimes and local spaces; to share live knowledge, each process must connect
to the same remote-backed space. The shipped `metta.remote` path uses HTTP and
the atom wire format. A local socket transport is not implied by pickling and
is not part of the local `Space` contract. See
[contexts and remotes](../live/contexts.md) and
[`metta.remote`](../reference/metta-remote.md).
