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
