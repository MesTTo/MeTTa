# Reclamation counts
Goal: the engine and the Python side hold nothing for a space life once it is
over, and the controls that say so count every registration, retained
completion and Python cell at a fixpoint rather than after a fixed pause.
Constraint: janus releases a py_object blob's Python reference at atom GC and
drains that release at the next Prolog-to-Python call; SWI's atom GC marks
every atom a live record or stack names; the classes package's drop and
transaction paths cross the seam in both directions and must leave nothing
behind after thousands of lives.

## 2026-09-16
Found by: extensions/python/tests/ch04_spaces_and_matching/test_reclamation.py,
the R6 unit of the classes package (ai-tmp/ai-retirement-state-contract.md):
lease rows, retirement witnesses, release bookkeeping, pending shadow repairs,
storage caches, exec-module rows, reference sight and slots, exec modules,
lease cells, admissions and pending withdrawals, before and after each
scenario.

Tried: counting cells through `lease._BY_NAME` -> a name map keeps only a
name's newest cell and cannot count the lives a scenario left behind.
Decided: `_BY_LEASE`, one weak entry per life.

Tried: handing the engine `SpaceHandle._released` as the release completion
and the transaction body as `py_call(F:'__call__'(), R)` -> both were held
by their blobs until atom GC and the next Prolog-to-Python call, and with
them the handle, its lease cell and what the closure held; 200 committed
retirements left 200 dead cells until the barrier. Decided: integer tickets,
`_COMPLETIONS` and `_BODIES`, resolved by `drop_completed(ticket, outcome)`
and `transaction_body(ticket)`; nothing of the handle crosses. The binding's
`metta_py_drop_space_completing/2` and `metta_py_transaction/2` take the
ticket; `metta_py_space_released/2` and the callable capability rows go.

Tried: a per-handle `_ephemeral` flag -> an alias's drop never pooled the
name. Decided: `Cell.ephemeral`, the life's property; `_finish_drop` also
removes the handle from its minter's `_minted` when it is the registered one,
because a registered dead handle kept its cell.

Tried: the failed-close and aborted-birth controls -> a dead cell stayed after
six atom GC passes: `&pyspace_1`, the aborted-birth context's own handle, held
by 200 pairs of `transaction`/`Space.transaction` frames
(ai-tmp/ai-r6-python-9.log). Bisection with ai_probe_retention.py and
ai_probe_blob_scan.pl: engine globals (`nb_current/2`), records, dynamic
clauses, tables (`current_table/2`) and message queues hold no PyObject blob;
`janus.Term` objects alive equalled the exceptions raised. Cause: the janus
`PrologError` keeps the ball as a `janus.Term`, a `PL_record` erased only in
`Term.__del__`; the record marks the `python_error` blob for atom GC, the blob
holds the exception, the exception holds the boundary through `__cause__`
after `raise original from error`, and the boundary holds the record, so
neither collector can close the cycle; `Runtime._raise`'s frame in the
traceback held the Term and the original as locals as well. Decided:
`_raise` classifies through `_classify`, which returns its reading, so the
frames that held the record and the original are gone before the raise;
`_release_record` leaves the boundary with the message, `.original` and no
record, clearing `exc.args` as well because CPython normalises janus's
`cls(term)` into `.args`; the four sites that re-read the record now read
`original_exception(error)`. Measured (ai_probe_blobs.py, 3 bodies): Terms
alive 3 -> 0; blobs surviving atom GC 6 -> 1.

Tried: the one surviving blob -> a probe artifact: enumerating `current_blob/2`
before the barrier pins the last enumerated atom; with no enumeration before
the barrier every blob goes (ai_probe_pin2.py, all four modes).

Tried: the exceptions themselves still alive after atom GC and the drain, at
refcount one above their tracked referrers (ai_probe_pin3.py) -> a janus-only
reproducer (ai_probe_janus_leak2.py, every mode): after atom GC and the drain
each exception a callback raised keeps refcount 2 with one tracked referrer.
Cause: janus/janus.c `check_error` fetches type, value and traceback with
`PyErr_Fetch` to build `python_error(Class, Obj)` and returns without
releasing them; upstream packages-swipy master b0356a162 (2026-07-28) is the
same code. Decided: patch it, per the ruling that the host is patchable
(user, 2026-09-16); tests/checks/host_workarounds/janus-callback-exception-leak.patch
releases the three references on every exit of `check_error`, and the
janus-swi 1.5.3 sdist with it applied was installed into the seat's
interpreter with `uv pip install --reinstall --no-deps`. Measured: the
reproducer's 2 alive -> 0; the reclamation controls 6/7 -> 7/7 -> 8/8
(ai-tmp/ai-r6-python-12.log, -13.log).

Decided: the host ledger gains the patched state. `Patch:` names the tracked
patch; the lane needs no site for such an entry, expects `absent` from its
reproduction and names the patch on `present`; selftest cases plant all three.
`janus-callback-exception-leak` is the first entry; 19 entries (1 patched),
42 sites. The same mechanism carries any later host fix, which is how the
other workarounds would retire one by one: fix the host, flip the entry to
`Patch:`, lift the sites the lane names.

Decided: `_settle` runs the barrier to its fixpoint, a round in which
`gc.collect()` collected nothing and `statistics(agc_gained)` did not move,
replacing a fixed six rounds; every count sits at that fixpoint, so a
scenario's residue never lands on the next scenario's baseline.

Rejected: clearing the leaked traceback's frames from the funnel
(`traceback.clear_frames`), because it blinds post-mortem debugging of the
body's own frames to work around a host defect the host can carry the fix
for. Revisit if a host cannot be rebuilt.

Prior art: PEP 3110, which unbinds `except ... as e` at block end because an
exception's traceback reaches the frame that holds it; Blink/V8 unified
tracing for DOM/JS cross-heap cycles, the general shape of the record cycle,
unavailable here, so the redundant edge is removed instead;
`traceback.clear_frames` as CPython's remedy when a traceback must be kept.

Tried: the whole Python suite, unshuffled, in a battery worktree on the
patched janus (ai-tmp/ai-r6-b1-python-full-1.log) -> 6 failed, 6897 passed.
Two were this unit's own tests: the twin warm-up stub took the child
environment as `_env` while `parity._run` passes it as `env=` (the ruff
rename after the run that verified it), and the callback facade control
listed the callbacks by hand and lacked `drop_completed`, `transaction_body`
and the two lease callbacks. Two were ch03 controls asserting the engine's
`released_scope_space` for a kept callable whose scoped home the outer scope
released: since a9b0ddb6 (every handle of one name shares one life) the
handle reads dropped first and refuses as itself, which is the documented
law; they pass at a9b0ddb6^ and fail after, and now accept either refusal.
One is older: ch14 `test_define_methods_run_on_terms_and_handles` answers
`[]` for a method applied to a live handle
(`m.eval((MethodPoint-norm <grounded MethodPoint>))`); `git bisect run` over
ai_probe_methods.py names ba819bfa2 (2026-09-14, receiver equations with
live native dispatch) as the first bad commit, independent of janus (same
answer under the original build). The last is the environment: the
`operations/concurrency_handles` example, the `prolog-static` lane and
`glxinfo -B` all die on `X_GLXCreateContext BadValue` on this box today.

Found: what puts xpce in the engine. `set_prolog_flag(verbose_autoload,
true)` in the example shows `autoloading '$metta_exec:&pyspace_1':send/3
from xpce/prolog/lib/pce`: the channel door calls the MeTTa function `send`
in the owner's exec module before its lib_thread face is defined, SWI's
autoloader resolves the undefined `send/3` against the library index before
the engine's `user:exception(undefined_predicate, ...)` hooks see it, and
xpce's `send/3` wins, loading `pl2xpce.so` and opening the display. Any
deferred MeTTa name that an autoloadable library exports (`send`, `free`,
`new`, `get`, `append`, `member`, ...) is open to the same capture. SWI's
flag value `user_or_explicit` keeps explicit `:- autoload/1,2` declarations
(library(ugraphs) declares its `append/3`) and restricts index-driven
autoload to module `user` [source: /usr/lib/swi-prolog/boot/autoload.pl,
autoload_in/3]. Not changed in this unit; it is the next one, with the
gate's independence from GLX as its control.

Open: the autoload capture above; the ch14 live-handle method regression
from ba819bfa2; the pre-existing red at ch17 `test_async_engine_injection_*`
under the eight-chapter battery (already red at 54102ad92; passes alone);
the seeded removal defect and the ch19 shuffle hang recorded in
2026-09-16-release-phases-and-reference-bindings.md; the class-definition
cost unit.
