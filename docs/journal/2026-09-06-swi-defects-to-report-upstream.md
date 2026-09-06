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
