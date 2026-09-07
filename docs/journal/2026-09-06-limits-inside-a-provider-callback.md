# Limits inside a provider callback
Goal: a Python space provider whose `match` re-enters the engine, or runs
while `inferences=`/`timeout=` is active, must reach the caller as the
exception it is, with the engine clean for the next call.
Constraint: janus is the system SWI-Prolog 10.1.13 build's `janus.so`; the
crossing behaviour cannot be patched, only worked with.

## 2026-09-06

Tried: reproducing the reported
`EngineError: the engine could not accept this call's inputs: <built-in
function apply_once> returned a result with an exception set` on unchanged
`petta` (468350eb) -> reproduced on all three doors, and the plain
`Space.match(pattern, inferences=20_000)` door does something worse: SIGSEGV,
exit 139, with the C stack `swipl_apply_once` -> `Py_SetPrologError` ->
`Py_SetPrologErrorFromObject`. Both are now
`test_a_reentrant_provider_generator_reports_the_budget_that_stopped_it` and
`test_an_inference_limit_spent_inside_a_provider_callback_is_an_inference_limit_error`;
the second one CRASHES pytest on unchanged trunk rather than failing.

Tried: a minimal janus probe, no engine involved, to find what the crossing
actually does with a raising generator -> `py_iter/2` over a generator that
yields 1 and then raises answered `L = [1]`, ran the goal's `assertz` marker
afterwards, and let no Prolog `catch/3` see anything; the ValueError surfaced
later, at the query's own result conversion. The same goal over a generator
that raises before its first yield answered `L = []`, so a raising provider is
read as an empty one.

Decided: the root is `py_iter3` in janus.c. Both of its
`state->next = PyIter_Next(state->iterator)` calls go unchecked, where
`PyObject_GetIter` above them is wrapped in `check_error`. `PyIter_Next`
returns NULL both for exhaustion and for a raise, so a raising pull is read as
the end of the stream: the Prolog goal continues over a SILENTLY TRUNCATED
answer set and the Python error indicator stays set until some later C
function returns a value with it pending. Where that lands decides the
symptom. `_Py_CheckFunctionResult` turns it into the reported `SystemError`;
inside janus's own error path it is fatal, because `py_record` asks Python to
build a `Term` while the indicator is set, CPython refuses and answers NULL,
and `Py_SetPrologErrorFromObject` does `Py_INCREF(obj)` on that NULL.

Decided: no stream this library hands to `py_iter` may raise. Each ends a
failure with the reserved `["x","raise",Class,Exception]` frame instead, and
the Prolog side hands the live exception straight back through
`py_call(metta_ops:stream_reraise(Obj), _)`. Nothing is reconstructed on
either side: janus's own `check_error` then converts it exactly as it converts
a deterministic `py_call` callback's exception, so the streaming doors and the
deterministic doors report the same exception the same way by construction,
`KeyboardInterrupt` and `SystemExit`'s unwind forms included, and
`metta_py_original_exception/2` still finds the object for the Python boundary
to re-raise. The frame already existed for two operation doors
(`_ops._stream_error`); this makes it the rule for all of them.

Rejected: mapping the escaping exception's CLASS to the engine's
`metta_control_signal(Kind, Detail)` envelope in Prolog, so a limit stays
uncatchable from MeTTa. It needs a class-name table on the Prolog side and a
`limit` field on `ResourceLimitError` to round-trip Detail, and it would still
disagree with what the deterministic doors do with the same exception. Revisit
if a MeTTa `(catch ...)` is ever measured swallowing a budget that a provider
callback spent; the deterministic doors have the same property today, so it is
one question about the operation seam rather than two.

Rejected: a side-channel stash keyed by a token, popped by the Prolog side.
The frame can carry the live object itself, so the stash would only add a way
to leak an entry when a Prolog cut abandons a failed stream.

Tried: the fix, then the landed branch's own probe again, all six
door/resource pairs -> the `SystemError` is gone from every one, and two of
them then read `EngineError: Unknown message: inference_limit_exceeded`. Traced by printing the whole exception chain with its Prolog
terms: both the provider's nested call and the outer door received the term
`inference_limit_exceeded`, SWI's own ball rather than the engine's envelope.
`apply_once` opens its query with `PL_Q_CATCH_EXCEPTION`, so it takes the ball
before the enclosing `call_with_inference_limit/3` can convert it, and a
callback that re-enters the engine is exactly that shape. This was already
recorded on the branch that landed provider premises, as
`EngineError: Unknown message: inference_limit_exceeded` in a red typed-provider
run, and was masked by the `SystemError` on the doors this repair fixes.

Decided: `metta_control_signal_info/3` classifies `inference_limit_exceeded`
and `time_limit_exceeded` themselves, which the engine already names control
exceptions in `engine/metta/registration.pl`. Their Detail is answered as
absent rather than guessed: the number lives in the frame that installed it,
`metta_host_inference_budget/3`'s own `Inferences`, which has unwound by the
time the classifier runs in a later janus query. `_reserved_message` says "the
inference limit was reached" for that case instead of naming a limit of
`None`; every bound that expires in its own goal still carries its number.

Tried: the same guard on the neighbouring doors that pull `py_iter` ->
`dispatch_inverse` and `dispatch_inverse_raw` had no handler at all, so a
raising preimage generator kept its already-yielded rows and delivered janus's
own wording naming no MeTTa call; `dispatch_many` and `dispatch_raw_many`
handled `Exception` only, so a `KeyboardInterrupt` out of a streaming
operation printed `foreign predicate system:$new_findall_bag/0 did not clear
exception: unwind(keyboard_interrupt)` and the provider door printed
`system:engine_destroy/1` twice. All eight doors carry the guard now, and
`test_a_control_signal_out_of_a_python_stream_leaves_no_pending_exception`
reads a child process's stderr for both.

Decided: the provider seam names the space and the provider on an exception
that is not already ours. A provider that raised a `MettaError` keeps its own
sentence, a `TransportFailure` keeps its class for the declared error modes,
and a `BaseException` that is not an `Exception` is never wrapped.

Tried: pricing the per-candidate guard, since both provider routes consult it
once per item -> over 2000 provider candidates, `get-atoms` costs 52,036
inferences unguarded, 58,036 with the guard written as an if-then-else and
56,036 with it written as two clauses; the same 2,000-candidate match through
`collapse` costs 66,311, 70,311 and 68,311. So the shipped guard is +2
inferences per candidate, 6.0% of that synthetic match, and the if-then-else
form would have been +3.
Rejected: spelling `metta_py_stream_frame/2`'s three goals into the first
clause head of `metta_py_stream_item/1`, which would take it to +1 by letting
clause selection do the discrimination. One reservation rule serves five doors
and no benchmark row names this constant. Revisit if a provider bench does.

Decided: the wrap is an `EngineError`, not the bare `MettaError`
`_require_provider` raises for a DECLINED request. A provider that declined
made a policy decision and one that crashed is a backend fault, and the
hierarchy already separates them; `test_the_undeclared_floor_aborts` had
pinned `EngineError` for this floor since before the crossing was touched.

Open: `py-iter`/`py-iter-once` in extensions/python/bridge.pl pull the USER's
own Python iterator through the same `py_iter/2` and have no guard. Measured
on trunk, a raising iterator there is reported, but at the next crossing and
attributed to the `py-atom` call rather than to the `py-iter`. Same root,
different seat's decoder, and no regression pins it yet.

Open: SWI's `did not clear exception` diagnostic is written by its own C error
stream and reaches neither pytest's fd capture nor the library's `capture()`,
so the regression that pins its absence runs the case in a child process and
reads that child's stderr.

## 2026-09-07

Tried: the open item above, `py-iter` and `py-iter-once` in
`extensions/python/bridge.pl`, measured on `petta` at 70ac99da before touching
anything. THREE symptoms, not the one recorded:

    !(once (py-iter G))      G raises 1st  -> EngineError: the engine could not
                                              accept this call's inputs:
                                              <built-in function apply_once>
                                              returned a result with an
                                              exception set
    !(collapse (py-iter G))  G raises 3rd  -> EngineError: Python 'ValueError':
                                              ... Python stack: metta_py.py:166
    !(catch (collapse ...))                -> the same, uncaught

The first is the LAZY pull and is the worst of the three: the whole nested
query returns with the error indicator still set, `_Py_CheckFunctionResult`
turns that into a `SystemError`, and the class, the message and the place are
all gone. The second keeps the exception but never enters `metta_py_guard/2`,
so it wears janus's own rendering with a live Python stack and names no MeTTa
call. The recorded "attributed to the py-atom call" was the shape of the first
report; what actually happens is that no MeTTa call is named at all.

Decided: the same repair as the operation and provider doors, with a different
frame. `metta_py.py` ends a failed enumeration with `(_STREAM_FAILURE, error)`
and `bridge.pl` raises it back through `py_call(metta_py:stream_reraise(E), _)`
INSIDE the goal `metta_py_guard/2` already wraps, so the attribution is the
guard's and nothing is reconstructed.

Rejected: reusing `metta.errors.stream_failure`'s four-element list
`["x","raise",Class,Exception]`. This seat crosses under `py_object(true)`,
and a janus probe settles it: `['x','raise',...]` arrives as
`<py>(0x..,list)`, an opaque blob Prolog cannot take apart without a second
crossing PER ITEM, while the exact tuple `(tag, exc)` arrives as
`<py>(0x..,object)-<py>(0x..,'ValueError')` with both elements in hand. The
pair is also the stronger reservation: the tag is a private module singleton
compared by blob identity, where the string tags are spellable by an
iterator's own data. Revisit if this seat ever stops asking for
`py_object(true)`.

Rejected: recovering the failure OUT OF BAND after the enumeration ends, the
`bufio.Scanner.Err()` and `ferror(3)` shape, which needs no reservation at all.
`py_iter/2` backtracks with one-item lookahead, so a source that raises on its
SECOND item raises during the lookahead for the first and `py_iter` then
SUCCEEDS deterministically; an end-of-stream check never runs and the crossing
stays poisoned. In-band is the only place the lookahead pull can be seen.

Decided: a replayable source REMEMBERS its failure, as the last entry of the
cache `_ReplayableIterator` already keeps, so `_done` and the cache carry it
and `replay` needs no new branch. The source is spent once it has raised, so
the alternative is not a retry: it is a second enumeration reading a truncated
prefix as a complete answer, which is the defect this whole mechanism exists to
close. That is RxJava's rule for a shared sequence, `Single.cache()` "caches
its success or error event and replays it to all the downstream subscribers",
and not `itertools.tee`'s, whose `_tee.__next__` calls `next(self.iterator)`
with no handler so the failure reaches whichever tee pulled it and the others
read the prefix [source:
https://javadoc.io/doc/io.reactivex/rxjava/latest/rx/Single.html;
CPython 3.14 itertools documentation, the tee() equivalent]. Python's own
community reads the ambiguity the same way: `groupby` treats a raising source
as unexhausted and `islice` as exhausted, and the answer given is that the
grave risk is "the exception being silently overlooked"
[source: https://discuss.python.org/t/is-an-iterable-that-raises-an-exception-exhausted/68720].

Tried: naming the three new predicates `metta_py_stream_*` the way this file
names its helpers -> `Warning: Redefined static procedure
metta_py_stream_raise/1, Previously defined at bridge.pl:670`. Neither
`bridge.pl` nor `metta/shim.pl` declares a module, so both load into `user` and
the shim's own `metta_py_stream_raise/1`, which hands ITS frame back through
`metta_ops`, silently won in every hosted process. Renamed to `py_iter_tag/1`,
`py_iter_item/2` and `py_iter_raise/1`, for the door rather than the file.

Tried: pricing the per-item guard, since every pulled item is asked -> over
20,000 items the pull costs 40,004 inferences unguarded and 60,004 guarded,
+1.00 an item exactly, 0.169 against 0.213 microseconds an item at loadavg
46.20; `metta_py._guarded` adds 5.6 nanoseconds an item to a 9.1 nanosecond
bare loop, 3.29% of one guarded pull. `extensions/python/benchmarks/py_iter_guard.py`,
`--items 20000 --rounds 3`. The +1 is clause selection doing the work:
`py_iter_item(Tag-Exception, Tag)` is a head whose REPEATED VARIABLE is the
reservation test, and first-argument indexing on `-/2` sends every item that is
not a pair straight to the second clause. The shim's equivalent costs +2
because its frame needs a separate predicate to destructure.

Planted, both directions: the six new tests against the unchanged
`metta_py.py` and `bridge.pl`, five red; and the reservation weakened from the
tag's identity to the pair's SHAPE, one red, an iterator of ordinary two-element
tuples read as a terminal failure.

Open: `esbuild` is declared in `extensions/node/package.json` and absent from
this workspace's one `node_modules`, so `npm run build:browser` cannot finish
and `extensions/node/llms.txt:238`'s `browser/` names nothing any tree here
holds. The `llms` lane reports it in a worktree and does NOT report it in the
main checkout, because `check_llms_names._resolves` falls back to
`REPO.rglob(tail)` and that glob descends into `ai-tmp/`: the main checkout's
green is supplied by `ai-tmp/wt-design-faces/extensions/node/browser`, another
agent's worktree. The lane should exclude `ai-tmp/` the way it already excludes
`.git`, and then the claim needs either the dependency or a rewrite. Left to
the seat that owns that sheet.
