# Executors in Python's own words, and an engine per worker process
Goal: make `EnginePool` a `concurrent.futures.Executor` so `submit`, `map`,
`shutdown`, `with`, `as_completed` and `wait` are Python's own words on it,
and add a process pool whose workers each boot an engine of their own, with
work units that carry text and atoms because an engine cannot cross a
process boundary.
Constraint: SWI-Prolog is one process-global system, so a second engine means
a second thread or a second process and never a second interpreter; a forked
child must not use an inherited one; and upstream PeTTa's semantics are
untouched by any of this, since none of it changes what a program answers.

## 2026-09-07

Tried: making `EnginePool` an `Executor` while `map` kept returning a `list`
-> refused by the type checker, and the refusal is right. Typeshed declares
`Executor.map(...) -> Iterator[_T]`
(`mypy/typeshed/stdlib/concurrent/futures/_base.pyi`), so a `list` return is
a Liskov violation, and shipping it behind `# type: ignore[override]` would
be a lie about a public method rather than a decision.

Tried: `Executor.map`'s own lazy reading, where nothing runs until the
iterator is consumed -> rejected. Measured by planting it: eight tests in
`test_engine_pool.py` went red, and the shape of the failures is the reason.
`test_a_worker_can_write_and_the_home_engine_sees_it` writes through
`p.map(...)` for the side effect and never consumes the result; under the
lazy reading it silently did nothing. `test_pool_runs_work_concurrently` and
`test_each_worker_holds_a_distinct_engine` hung on their barriers until the
timeouts, taking the run from 19 s to 247 s. A door that silently does
nothing is the class this library refuses.

Decided: every fan-out door SUBMITS the whole input and then answers an
`Iterator` over results that already exist. Execution is eager, which is
what these pools have always done ("the whole point is that the work already
ran"), and the TYPE is `Executor.map`'s own, so the class is an Executor
rather than something that resembles one. The one visible cost is that
`p.map(f, xs) == [...]` becomes `list(p.map(f, xs)) == [...]`; nine
assertions in the suite, one example and two docstrings were updated. That
failure is loud at the call site, where the lazy alternative's is silent.

Decided: `map`, `starmap` and `imap_unordered` are written once in a
`_FanOut` mixin over `Executor` and each pool supplies `submit`, so the two
boundaries cannot drift apart. `close(wait=)` stays as the pools' own name
for `shutdown(wait=)`; `shutdown` adds Executor's `cancel_futures`, draining
the work queue under the same state lock `submit` takes, which is
ThreadPoolExecutor's own transition.

Decided: `chunksize` is HONOURED rather than accepted and ignored, which is
what `ThreadPoolExecutor` does with it. A chunk is a real unit in both
pools, amortising queueing in one and a pickle round trip in the other, and
a parameter that silently does nothing is a wart. A chunk is one failure
unit; the default 1 keeps per-item grouping.

Tried: putting `ProcessPool` behind a lazy submodule to keep
`metta.parallel` light, since `concurrent.futures.process` pulls
`multiprocessing` -> rejected on the measurement. Given this module's own
imports the marginal cost is 3.5 ms and 14.7M instructions, 545.7M against
560.4M instructions:u for `import metta.parallel`, +2.7%
[command=`perf stat -e instructions:u python -c "import metta.parallel[,
concurrent.futures.process]"`, minimum of three, load 44]. A second module
name for one class costs more than that: the reference generator reads
module ASTs and would not see a class reached through `__getattr__`, and the
work units would pickle under a private module path.

Measured: a worker's engine boot. In instructions, which are deterministic
here: a bare interpreter is 76.3M, `import metta` is 174.1M, and a full boot
with one answer is 2,324.3M, so the engine costs 2,248M instructions and the
Python import 98M of it; three runs spanned 2,324.27M to 2,324.78M, 0.02%
[command=`perf stat -e instructions:u python -c "import metta;
metta.run('!(+ 1 2)')"`, load 75]. In wall clock, which the load owns: 0.37 s
with the `.qlf` set present and 0.96 s on the boot that had to compile it,
and inside a four-worker pool on the same box the workers reported 0.246 s
to 2.138 s each with the whole pool plus four units at 2.4 s to 2.7 s
[load 78]. The rule that follows is the one the class documents: a pool
worker costs a whole boot where a thread worker costs an engine
attachment, so reach for threads unless isolation is the point.

Tried: proving "three programs ran in three workers" without a clock. A
`multiprocessing.Barrier` cannot travel through a task queue, because its
`SemLock` refuses to pickle outside process spawning, and it cannot ride
`initargs` without putting a test-only parameter in the public constructor.
Decided: a directory rendezvous. Each unit touches a file named for its pid
and does not answer until the directory holds three, so the test can only
pass if three workers genuinely run at once, and background load cannot make
a one-worker run pass. That is `test_pool_runs_work_concurrently`'s barrier
argument carried across the process boundary.

Measured: a `Space` PICKLES, by name. `pickle.loads(pickle.dumps(m.self))`
answers `Space('&pyspace_1')` and `pickle.dumps(space.run)` succeeds, so a
handle sent to a worker would open the WORKER's own space of that name,
answer about it, and raise nothing. That is the hazard the process pool has
to fence, and it is why the refusal is at submit rather than left to pickle:
pickle is happy to do the wrong thing here.

Decided: the refusal walks the submitted callable and its arguments through
`inspect.getclosurevars`, the standard library's own answer, whose
`nonlocals` are the free variables actually bound and whose `globals` are
`__globals__` restricted to `co_names`, the names the body looks up. Ray's
serializability inspector walks a callable the same way
(`python/ray/util/check_serialize.py`, `_inspect_func_serialization`). The
global half is load-bearing: a function written beside a module-level
`space = ...` has an EMPTY `__closure__` and names `space` as a global
[measured: `co_names` ('sp', 'run'), `__closure__` None]. The walk goes two
callable hops, which reaches `_apply_chunk(user_fn, rows)` and `user_fn`'s
own closure; a handle inside a custom object is not seen, which is why the
work units never take one in the first place.

Decided: the work units are `program(source, space=)` and
`call(head, *arguments, space=)`, ordinary module-level functions rather
than closures, because a process pool pickles what it submits BY REFERENCE.
They are also ordinary functions in the parent, which is what makes
`map(program, texts)` the pool's own differential oracle against
`pool.map(program, texts)`. Answers cross as atoms by value, which is what
`Atom.__reduce__` already is, rather than through `to_wire()`: the wire form
of a `_NativeHandle` is `["h", id, text]`, plain data that would cross and
decode into a dangling id in the parent, while `__reduce__` refuses it. A
`Space` in an answer refuses explicitly, since it pickles.

Tried: letting a failed boot reach the caller as CPython does -> rejected. A
raising `initializer` makes CPython log the traceback and kill the worker,
and the caller reads `BrokenProcessPool: A process in the process pool was
terminated abruptly while the future was running or pending`, which names
neither the engine nor the boot [measured with a deliberately exploding
initializer]. Decided: the initializer records its own failure and the
worker survives to say what happened on the first work unit that needs an
engine. `test_a_worker_that_cannot_boot_says_why` pins both halves,
including that the second unit says it again.

Decided: `fork` is refused at construction. SWI's own C says why: the
comment above `PL_cleanup_fork()` states it "must be called between fork()
and exec() to remove traces of Prolog ... the code cannot lock or unlock any
mutex as the behaviour of mutexes is undefined over fork()", and the
`pthread_atfork` repair beside it sits behind an `O_ATFORK` its own comment
marks "Not yet default" (`swipl-devel/src/pl-thread.c`); `fork/1` raises
`permission_error(fork, process, main)` off the only thread because
"Forking a Prolog process with threads will typically deadlock". loky
reaches the same conclusion for the same reason and warns on an explicit
`fork` because it "does not respect POSIX".

Measured: the corruption is NOT immediate, which is the argument for
refusing rather than waiting for a crash. A forked child of a booted engine
on this box answered `!(+ 3 4)`, `!(hyperpose ((+ 1 1) (+ 2 2)))` and
`garbage_collect_atoms`, and answered again when the fork came from a
non-home thread while the home thread was inside a long call [load 44]. An
inherited engine LOOKS fine; a child reading plausible answers out of half a
runtime is exactly the silently-wrong class.

Decided: the refusal lives in `_engine`, not in the pool, because the hazard
belongs to any fork of a process that booted an engine and not only to the
pool that knows about it. `os.register_at_fork(after_in_child=...)`
substitutes a `_ForkedBridge` for the janus module, so every crossing
refuses at zero steady-state cost; a boolean tested in `Runtime.apply` would
have been paid by every call in every process. The handler only flips state
and never raises, because an exception inside an after-fork handler is
routed to `sys.unraisablehook` and the fork proceeds anyway (CPython
`Modules/posixmodule.c`, `run_at_forkers` calling `PyErr_FormatUnraisable`).
PyTorch answers the same hazard the same shape, with
`torch.cuda._is_in_bad_fork()` read lazily rather than at the fork.

Decided: the same handler resets `_LOCK` and `CONSULT_LOCK` and empties the
deferred-work queue. Only the forking thread survives a fork, so a lock
another thread held is held forever and a child would hang before reaching
the refusal; CPython repairs its own the same way in
`logging._after_at_fork_child_reinit_locks`. The queue's records belong to
the PARENT's engine and erasing one in the child is `PL_erase` against
another process's memory. `test_a_fork_resets_the_engine_locks` holds the
lock on the home thread, forks from a second thread, and asserts the child
can take it.

Measured, and it is the one trap a user will meet: `forkserver` runs
`__main__` ONCE in its fork server and forks workers from it, so an engine
booted at IMPORT time is booted in that server and inherited. All three
workers of a probe with a module-level `MeTTa()` refused; the same probe
with the boot under `if __name__ == "__main__":` answered. The refusal names
that edit and the `mp_context=multiprocessing.get_context("spawn")` escape,
`test_a_forkserver_worker_that_inherited_an_engine_says_so` pins it, and the
class docstring, `llms.txt` and the threads guide all carry it. It fires
only for a script with a path: the same script under `python -c` has no
`main_path` for the server to preload and answered normally.

Open: nothing in the pool measures whether `chunksize` pays for a process
work unit; the parameter is honoured and its cost is the caller's to
measure. `boot=` runs in the worker's `&self` rather than in a space the
caller names, so a boot into a named space is written in the program text.
