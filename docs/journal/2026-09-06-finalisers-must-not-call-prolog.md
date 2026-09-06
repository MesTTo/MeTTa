# A finaliser may not call into Prolog
Goal: stop the Python seat dying under load, where the deaths all come from
code that runs when Python decides to free something rather than when this
library decides to call.
Constraint: SWI-Prolog 10.1.13 and janus_swi 1.5.3 are what ship. Nothing here
may make the explicit doors slower or later: an explicit `close()` still closes
when it is called.

## 2026-09-06

Found: three process deaths, one rule.

Two were `janus_swi.Term.__del__` reaching `PL_erase` on a thread with no
engine. `PL_erase` unregisters the record's atoms; when the last reference to
one goes, `unregister_atom` calls `considerAGC`, and past the margin that calls
`signalGCThread`, whose first act is `truePrologFlag(PLFLAG_GCTHREAD)` --
`LD->prolog_flag.mask.flags[..]` with no null guard. Cores 827444 and the
50,000-Term probe both fault at `libswipl+0x12e563`, which under gdb is
`test BYTE PTR [r8+0x690],0x10` two instructions after `call __tls_get_addr`,
with `r8 == 0`. Recorded in full at
`docs/journal/2026-09-06-janus-term-finalisation.md`.

The third is a different fault with the same cause. The cyclic collector ran a
finaliser in the middle of a Hypothesis draw, that finaliser closed a cursor by
calling `rt.do/2`, and SWI aborted:

    ERROR: ./src/pl-rec.c:1560: copy_record___LD: Assertion failed: 0
    [4] py_unify_record() at janus.c:1597
    [5] py_unify_dict()   at janus.c:1004
    [6] unify_input()     at mod_swipl.c:145

`copy_record`'s `assert(0)` is the `default:` arm of its switch over record
tags, which is what reading an ALREADY ERASED record looks like. Python stack,
from core 77563 / `merged22-python.log`: `Garbage-collecting` ->
`_engine.py:778 do` -> `_space_execution.py:812 stream` ->
`_space_execution.py:626 close` -> `results.py:1269 __del__`.

Found, and this is the second defect in janus's four-line `__del__`: janus
1.5.3 writes `self.record = 0` where it means `self._record`
[janus_swi 1.5.3 janus.py:485-488]. A released Term therefore keeps a dangling
record id, and anything that hands it back to Prolog reaches `PL_recorded` on
freed memory. Reproduced in twelve lines: release a Term with `__del__()`, pass
it to `query_once`, and the process aborts on exactly the assertion above,
while `record after release` prints the id unchanged. On the branch the same
script prints `0` and the crossing is refused cleanly, because janus's own
zero check -- `py_unify_record` opens `(v=PyLong_AsLongLong(r)) && ...` --
becomes real once the attribute it reads is the one that gets cleared.

Decided, THE RULE: a finaliser may only enqueue. It runs at a point no caller
chooses, on any thread, possibly while that thread is already inside a
crossing, and within one reference cycle the collector finalises members in no
defined order. No call site can be made safe one at a time, so the crossing
itself moves out of finalisers entirely: `_DEFERRED_WORK` in `_engine.py` takes
record ids and shim calls, and `_drain_deferred` does them from `_thread_lock`,
which every crossing consults before taking any lock. A deque because its
append and popleft are single bytecodes, so a finaliser never takes a lock; the
drain pops inside `try/except IndexError` rather than testing `while queue`,
which is the shape jedi's `CompiledSubprocess.run` uses to drain its own
deletion queue.

Found while building it, and it is why the first version did not work: the
cursor handle is a janus Term, and a Term released by the collector goes inert.
A handle reachable ONLY from the view that owns it can be finalised BEFORE that
view's own finaliser runs. Measured exactly that: the deferred close then
carried a handle whose `_record` was already `0`, and Prolog answered
`Type error: engine expected, found <py_Term>(0x...)`, leaving the engine open
and `_live_engines` one above baseline. `_OPEN_CURSORS` in `_space_execution.py`
now holds every open handle from the moment it is opened, which is a reference
outside every cycle, so the handle is never garbage while a cursor is open and
the ordering question does not arise.

Rejected: an engine attached for the life of every janus-touching thread,
released at thread exit through a `threading.local` finalizer. It makes the
first two deaths impossible, but the release still runs from a finaliser at
thread exit, in an order Python does not define against the Terms that thread
still holds, and it does nothing at all about the third death, which happened
on a thread that HAD an engine. Revisit only if a workload appears where the
deferral's one-crossing latency is a cost.

Rejected: clearing `_record` alone (the second defect), or moving the cursor
off `prolog(Engine)` onto an integer key. Each fixes one of the three and the
rule fixes all three; the `_record` clear is kept as well, because a released
Term that is still inert-on-use is what makes the deferral safe against a
`repr()` -- pytest's own assertion rewriting called `repr()` on a released Term
and that alone aborted the process on the parent commit.

Rejected: draining inside `__del__` when the thread happens to have an engine.
It was the first version and it is wrong for the reason the third death shows:
a finaliser on a thread that has an engine is still a finaliser, and may be
running inside another crossing.

Verified. The 50,000-Term worker-thread burst, reached through this library's
own `bridge()`: 5 runs out of 5 abort with `engine/materialize.pl`'s parent
`_engine.py` and 5 out of 5 survive here, against an attached-thread control
that is 5 out of 5 clean either way. The regression file aborts the pytest
process outright on the parent commit -- two clean failures and then
`Fatal Python error: Aborted` through `janus.py:482 __repr__` -- and is 8
passes here. `sh extensions/python/test.sh` is 1 failed / 3422 passed against
the parent's 1 failed / 3414 passed, the same pre-existing twin-coverage case.
`sh extensions/python/test.sh tests/ch17_concurrency_and_the_loop` ten times at
loadavg 17 to 43: 10 exit 0.

Found while writing the drain test, and worth keeping: the first version of
`test_deferred_work_is_drained_by_the_next_engine_crossing` asserted only that
the queue emptied. It passed against a drain whose erase primitive had never
been captured and was `None` -- the queue emptied because the item is popped
before the call, and the failure was swallowed exactly as a finaliser's failure
should be. It now watches the erase itself, and fails when the capture is
removed.

Open: `_drain_deferred` returns without draining on a thread with no engine, so
a process whose only remaining work happens on bare threads keeps its queue.
That is bounded by the number of Terms and cursors such a program drops, and it
is a leak rather than a fault; a periodic drain from the home thread would
close it if a workload ever shows one.
