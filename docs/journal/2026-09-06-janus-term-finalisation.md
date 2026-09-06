# A janus Term finalised on a thread with no Prolog engine
Goal: explain the SIGSEGV that killed pytest worker gw3 during
`tests/ch17_concurrency_and_the_loop/test_async_scheduler.py`, with
`janus_swi/janus.py:488 in __del__` on top of the Python traceback, and say
what would remove it.
Constraint: SWI-Prolog 10.1.13 and the installed `janus_swi` are what ship.
Nothing here changed code: this entry records a diagnosis and a reproduction so
the repair is not designed from a model.

## 2026-09-06

Found: the core says exactly where it died. `coredumpctl` 827444, the gw3
worker, crashing thread 834080:

    #0  libswipl.so.10 + 0x12e563
    #1  PL_unregister_atom (libswipl.so.10 + 0xdf068)
    #2  libswipl.so.10 + 0x12b055
    #3  libswipl.so.10 + 0x12afa2
    #4  py_free_record (_swipl.cpython-314-x86_64-linux-gnu.so + 0x5c90)
    ... PyObject_CallFinalizerFromDealloc, Term.__del__

Under gdb the faulting frame reads

    => 0x...12e563:  test BYTE PTR [r8+0x690],0x10
    r8  0x0

and the two instructions above it are `call __tls_get_addr@plt` followed by
`mov 0x0(%rax),%r8`. That is `GET_LD` and then
`truePrologFlag(PLFLAG_GCTHREAD)`, which is
`LD->prolog_flag.mask.flags[..] & bit` with NO null guard
[source: SWI-Prolog 10.1.13 src/pl-incl.h:2839 truePrologFlag,
src/pl-thread.c:7353 signalGCThread;
commit=81d05b34f938ff97f835ca1c00205220690cb6f0].
`r8 == 0` is `LD == NULL`: the thread had no Prolog engine.

The path in: `Term.__del__` calls `_swipl.erase(record)`, janus's
`py_free_record` calls `PL_erase`, the record's atoms are unregistered, and
`unregister_atom()` calls `considerAGC()` when the last reference goes.
`considerAGC()` signals atom GC once `GD->atoms.unregistered` passes
`GD->atoms.non_garbage + GD->atoms.margin`, and `signalGCThread()` reads the
flag through `LD` before it reaches the `raiseSignal(ld, sig)` that IS guarded
[source: SWI-Prolog 10.1.13 src/pl-atom.c:1475 considerAGC, src/pl-wam.c:258
raiseSignal; commit=81d05b34f938ff97f835ca1c00205220690cb6f0].

Rejected as the mechanism: `LD->atoms.unregistering = p->atom` a few lines
earlier in the same function. It is the obvious suspect and it is guarded, by
`if ( HAS_LD )` [source: SWI-Prolog 10.1.13 src/pl-atom.c:1639;
commit=81d05b34f938ff97f835ca1c00205220690cb6f0].

Reproduced, exactly. `ai-tmp/ai-janus-term-probes/term_del_bulk.py` builds
50,000 janus Terms on a worker thread, detaches the engine, and drops them:
5 runs out of 5 die, and the stack is the same five frames as the production
core, `+0x12e563` under `PL_unregister_atom` under `+0x12b055` under
`+0x12afa2` under `py_free_record`. Dropping the same 50,000 with the engine
still attached is 5 runs out of 5 clean
[command=sh ai-tmp/ai-janus-term-probes/bulk_tally.sh 50000 5;
fixture=janus_swi in .venv-pypetta, swipl 10.1.13;
commit=81d05b34f938ff97f835ca1c00205220690cb6f0].

Where this repository meets it: `metta_py_cursor_open/8` answers
`prolog(Engine)`, so every cursor handle crosses as a `janus_swi.Term`
[source: extensions/python/metta/shim.pl:1230;
commit=81d05b34f938ff97f835ca1c00205220690cb6f0]. In
`_space_execution.py` the `stream()` generator holds that handle in a local,
closes the cursor in its `finally` through `rt.do/2`, and then lets the frame
die. `rt.do/2` attaches an engine for the length of the call and detaches it
again, so the Term is finalised a moment later with no engine. That is the
frame the production traceback shows above `__del__`: `__next__` at
`_space_execution.py:616`.

Open, and why no repair is here yet: a repair has to be verified against a
LIBRARY-level reproduction, and the accelerator needed to get one competes
with the target. `library_burst.py` drops 4,000 unstarted cursor handles in one
go on an engine-less thread and survives with the shipped `agc_margin`; lowering
the margin to 500 or 1 does crash it, but at a DIFFERENT instruction --
`considerAGCType(p->type)` inside `unregister_atom` with a garbage `p->type`,
reached from `PL_thread_destroy_engine` on janus's per-call engine detach --
which is a second SWI defect the low margin exposes rather than the one above.
So the mechanism is proven and the site in our code is named, but a fix
written now would be verified against a model.

The three candidates, for whoever takes it. Keeping a Prolog engine attached
for the life of any thread that touches janus removes the whole class and
costs an engine per thread, released at thread exit. Erasing the handle's
record while the engine is still attached, and neutering the Term by zeroing
its `_record` so `py_free_record` skips its `PL_erase`, is the smallest change
and depends on a janus private attribute. Not crossing engine handles as
`prolog(Engine)` at all, and keying a Prolog-side table with an integer
instead, removes the Term rather than managing it, and is a wire change in the
answer path.

Noted in passing: `Term.__del__` writes `self.record = 0`, not `self._record`,
so its own double-erase guard sets an attribute nothing reads. CPython runs a
finaliser once per object, so it is latent rather than active
[source: .venv-pypetta/lib/python3.14/site-packages/janus_swi/janus.py:485-488;
commit=81d05b34f938ff97f835ca1c00205220690cb6f0].
