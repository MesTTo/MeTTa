# `metta.parallel`

Source: `extensions/python/metta/parallel.py`.

> Evaluate on more than one core, at either boundary. An EnginePool
> owns a fixed set of worker THREADS, each holding its own attached Prolog
> engine for the pool's lifetime, and runs ordinary Python callables on them;
> because a worker's engine is private to its thread, the process lock that
> serialises the home engine does not apply to it, so the branches genuinely
> run at once. A ProcessPool owns worker PROCESSES that each boot an engine of
> their own and share nothing, for when isolation is the point.
>
> Both are concurrent.futures.Executor, so `submit`, `map`, `shutdown`, `with`,
> `as_completed` and `wait` are Python's own words on them, and both take their
> fan-out doors from one _FanOut mixin so the two boundaries answer alike.
>
> This is the Python-side fan-out. Space.parallel() is the in-engine fan-out
> through hyperpose, below a single janus call. They compose: a pool worker may
> itself evaluate a hyperpose.
>
>     with metta.parallel.pool(workers=8) as p:
>         answers = list(p.map(lambda n: m.eval(S.solve(n))[0], range(64)))
>
>     with metta.parallel.process_pool(4, boot=rules) as p:
>         answers = list(p.map(metta.parallel.program, programs))
>
> Owns:
>   - one daemon thread and one attached Prolog engine per worker, from start
>     until close(). close() is idempotent and runs from __exit__.
>   - one process, one booted engine and one boot program per ProcessPool
>     worker, from the first submit until shutdown(), plus the SimpleQueue
>     carrying those workers' boot timings.
>   - one SWI message queue per Channel, released by close(), context exit, or a
>     finalizer that retains only the runtime and engine handle.
> "; fixture=this checkout
>     under load 44; commit=0179a14353a925115d545fc3ea0dc67eab4e4ecb].
>   - a fan-out door answers an ITERATOR over results that already exist, not
>     a list: the whole input is submitted and taken before the door returns,
>     which is what these pools have always done, while the type is
>     Executor.map's own so the class is one rather than resembling one.

The entries below reproduce the source signatures and docstrings.

## `EnginePool`

```python
class EnginePool(_FanOut):
```

> Worker threads that each hold their own Prolog engine.
>
> Construct through pool() or MeTTa.pool(). The pool starts its workers
> eagerly, so that a first map() does not pay engine attachment, and holds
> them until close(): attaching and detaching an engine is documented as
> relatively expensive (SWI manual section 10.6.1).
>
> It IS a concurrent.futures.Executor, so `submit`, `map`, `shutdown` and
> `with` are Python's own words on it and `as_completed(futures)` and
> `wait(futures)` read its Futures without knowing what a MeTTa engine is.
> `close(wait=)` is the same door as `shutdown(wait=)` under the name this
> pool has always had; `shutdown` adds Executor's `cancel_futures`. The
> fan-out doors come from _FanOut, which states their one shared rule.

### `EnginePool.submit`

```python
def submit(self, fn: Callable[..., R], /, *args: Any, **kwargs: Any) -> Future[R]:
```

> Queue one call on a worker and answer its Future.

### `EnginePool.shutdown`

```python
def shutdown(self, wait: bool = True, *, cancel_futures: bool = False) -> None:
```

> Executor's teardown: stop taking work, then release every engine.
>
> wait=False returns while the owned workers drain. A later waiting
> shutdown still joins them, including after an earlier join timed
> out. Cancelling a Future skips only that queued task, not worker
> teardown.
>
> cancel_futures=True cancels every task still QUEUED, leaving what a
> worker already started to finish; that is ThreadPoolExecutor's own
> reading, and it drains the queue under the same state lock that
> submit takes, so a task accepted after the drain cannot exist.

### `EnginePool.workers`

```python
def workers(self) -> int:
```

> How many worker threads, and therefore engines, this pool holds.

### `EnginePool.closed`

```python
def closed(self) -> bool:
```

> Whether close() has run.

## `pool`

```python
def pool(workers: int | None = None) -> EnginePool:
```

> A pool of worker threads that each hold their own Prolog engine.
>
> Use it as a context manager so the engines are released:
>
>     with metta.parallel.pool(workers=4) as p:
>         answers = list(p.map(lambda n: m.eval(S.fib(n))[0], range(20)))
>
> workers defaults to os.cpu_count().

## `imap_unordered`

```python
def imap_unordered(engine_pool: _FanOut, fn: Callable[[T], R], items: Iterable[T]) -> Iterator[R]:
```

> `pool.imap_unordered(fn, items)` written with the pool in front.
>
> The same door as the method, kept because it is the spelling this
> module has always published and because it reads as a free function
> over any pool. Either pool answers it.

## `program`

```python
def program(source: str, *, space: Symbol | str | None = None) -> list[list[Atom]]:
```

> Run MeTTa source on THIS process's engine: one answer list per `!`.
>
> The work unit a ProcessPool takes, and an ordinary function everywhere
> else: in the parent `program(text)` is exactly `metta.run(text)`, which
> is what makes a plain `map(program, texts)` the pool's own differential
> oracle. Program TEXT crosses a process boundary and an engine does not,
> so this is what a worker is sent instead of a callable closing over a
> space.
>
>     with metta.parallel.process_pool(3, boot="(= (sq $x) (* $x $x))") as p:
>         for answers in p.map(metta.parallel.program, ["!(sq 3)", "!(sq 4)"]):
>             print(answers)
>
> `space` names a space IN THE WORKER, by symbol or by exact string, the
> way `metta.space()` reads a name; a Space handle is refused. Answers
> cross as atoms by value, which is what `Atom.__reduce__` already is, and
> an answer that is a handle refuses rather than naming a space the worker
> owns.

## `call`

```python
def call(
    head: Symbol | str,
    *arguments: Any,
    space: Symbol | str | None = None,
) -> list[Atom | Undefined]:
```

> Apply a head the worker already knows to atoms, on THIS process's engine.
>
> The other work unit. Where `program` sends text to read and compile,
> this sends a NAME and its arguments, so a head the pool's `boot=`
> defined is called without re-reading its definition once per task:
>
>     with metta.parallel.process_pool(3, boot="(= (sq $x) (* $x $x))") as p:
>         list(p.starmap(metta.parallel.call, [(S.sq, 3), (S.sq, 4)]))
>
> Arguments and answers cross as atoms by value; a handle refuses in
> either direction, and so does an opaque grounded object, which is
> `Grounded.__reduce__`'s own refusal at the pickle boundary.

## `ProcessPool`

```python
class ProcessPool(_FanOut, ProcessPoolExecutor):
```

> Worker PROCESSES that each boot an engine of their own.
>
> EnginePool's sibling one boundary out. A thread pool shares this
> process's spaces, equations and compiled functions, which is what makes
> a callable closing over a handle the right thing to write there; a
> process pool shares NOTHING, which is the point of it. Each worker boots
> its own engine once, from the same fast image a fresh `metta` process
> boots from, and then runs work units that carry only text and atoms:
>
>     with metta.parallel.process_pool(3, boot="(= (sq $x) (* $x $x))") as p:
>         for answers in p.map(metta.parallel.program, programs):
>             print(answers)
>
> Use it when isolation is the point: one program must not see another's
> equations, a run must not be able to corrupt the caller's space, or a
> workload must survive a worker that dies. Use `pool()` instead when the
> work shares knowledge, which is most work; a thread there costs an
> engine attachment and a worker here costs a whole boot.
>
> `boot` is MeTTa program text every worker runs once after its engine
> starts, so a head `call` names is compiled per worker rather than per
> task.
>
> ONE TRAP, and it is the forkserver's rather than this pool's. On Linux
> the default start method runs your `__main__` ONCE in a fork server and
> forks each worker from it, so an engine your module boots at IMPORT time
> is booted in that server and inherited by every worker across a fork,
> which is the one thing SWI-Prolog does not survive. Every work unit in
> such a worker refuses, naming this. Keep the boot under
> `if __name__ == "__main__":`, which spawn and forkserver both want
> anyway, or pass `mp_context=multiprocessing.get_context("spawn")` and
> let each worker do its own import.
>
> Owns:
>   - one process, one Prolog engine and one boot per worker, from the
>     first submit until shutdown(); and one SimpleQueue carrying the
>     workers' boot timings, closed by shutdown().

### `ProcessPool.submit`

```python
def submit(self, fn: Callable[..., R], /, *args: Any, **kwargs: Any) -> Future[R]:
```

> Queue one call on a worker process and answer its Future.
>
> Executor.submit, with one refusal in front of it: a call that
> reaches an engine handle in this process is refused HERE, where the
> remedy can be named, rather than crossing and answering about the
> worker's own space.

### `ProcessPool.shutdown`

```python
def shutdown(self, wait: bool = True, *, cancel_futures: bool = False) -> None:
```

> Executor's teardown, and the close of the boot-timing queue.
>
> The timings already read stay readable afterwards, because the queue
> is drained before it is closed.

### `ProcessPool.boot_seconds`

```python
def boot_seconds(self) -> dict[int, float]:
```

> Seconds each started worker spent booting its engine, by pid.
>
> Empty until the first submit, because ProcessPoolExecutor starts a
> worker when there is work for it rather than at construction. A
> worker whose boot FAILED still reports its seconds; what it failed
> at arrives on the first work unit instead.

### `ProcessPool.workers`

```python
def workers(self) -> int:
```

> How many worker processes, and therefore engines, this pool holds.

### `ProcessPool.closed`

```python
def closed(self) -> bool:
```

> Whether shutdown() has run.

## `process_pool`

```python
def process_pool(
    workers: int | None = None,
    *,
    boot: str | None = None,
    mp_context: Any = None,
) -> ProcessPool:
```

> A pool of worker processes that each boot their own engine.
>
> `pool()`'s sibling one boundary out; see ProcessPool for what each
> boundary shares and what it does not.
>
>     with metta.parallel.process_pool(4, boot=rules) as p:
>         answers = list(p.map(metta.parallel.program, programs))
>
> workers defaults to os.cpu_count().

## `FutureSpace`

```python
class FutureSpace(Space):
```

> A spawned computation's ordinary answer space with lifecycle verbs.
>
> Abandoning one follows Python's own future semantics: the computation
> keeps running, exactly as a concurrent.futures future would, and the
> garbage collector emits asyncio's kind of ResourceWarning when a
> handle dies without anyone having observed settlement, so an
> accidentally dropped infinite producer names itself instead of
> spinning silently. ``cancel()`` remains the deliberate stop.

### `FutureSpace.wait`

```python
def wait(self):
```

> Wait until evaluation settles, then lazily expose every stored answer.

### `FutureSpace.settled`

```python
def settled(self) -> bool:
```

> Whether the computation has finished, without waiting.

### `FutureSpace.cancel`

```python
def cancel(self) -> bool:
```

> Stop a pending computation, answering whether it was stopped.

## `spawn`

```python
def spawn(expression: Any) -> FutureSpace:
```

> Start one expression now and return the space its answers fill.

## `every`

```python
def every(seconds: float, expression: Any) -> FutureSpace:
```

> Repeat one expression at each interval until its future is cancelled.

## `race`

```python
def race(*expressions: Any) -> Any:
```

> Return the first successful answer and cancel the remaining branches.

## `par_map`

```python
def par_map(function: Any, items: Iterable[Any]) -> Expression:
```

> Evaluate a unary MeTTa function concurrently, preserving input order.

## `Channel`

```python
class Channel:
```

> A bounded or unbounded lib_thread mailbox in Python dress.

### `Channel.send`

```python
def send(self, term: Any) -> bool:
```

> Block until capacity admits one copied term.

### `Channel.recv`

```python
def recv(self, *, deadline: float | None = None) -> Any:
```

> Take one term, raising Timeout when a finite wait is quiet.

### `Channel.try_recv`

```python
def try_recv(self) -> Any | None:
```

> Take one waiting term or return None without blocking.

### `Channel.close`

```python
def close(self) -> None:
```

> Destroy this mailbox. Closing twice is a no-op.

## `channel`

```python
def channel(*, max: int | None = None) -> Channel:
```

> Create a mailbox; max bounds queued terms and blocks full senders.
