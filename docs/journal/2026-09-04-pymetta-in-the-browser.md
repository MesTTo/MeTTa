# pymetta in the browser

Goal: decide what it would take to run the `metta` Python surface in a browser,
and whether the janus dependency forces a fork.
Constraint: `janus_swi` links the C embedding API of both CPython and SWI, and
the SWI WebAssembly build is `--disable-mt`, builds no packages, and disables
janus under `STATIC_EXTENSIONS=ON`. So janus itself is unavailable there.

## 2026-09-04

Decided: no fork. The package's whole coupling to janus is the `JanusBridge`
Protocol at `extensions/python/metta/_engine.py:210` — eleven methods and
`PrologError` — resolved by one line, `importlib.import_module("janus_swi")` at
`:373`, cast to that Protocol. Measured usage across the package:

```
16  query_once      6  consult          2  version_str
12  PrologError     4  detach_engine    2  query
10  engine          4  attach_engine    2  cmd
                    3  prolog           1  heartbeat, 1 apply_once
```

Nothing outside `_engine.py` knows what janus is. A second implementation of
that Protocol is the work; porting a CPython C extension to Emscripten is not.

Tried: reading janus's nondeterminism against swipl-wasm's, because
backtracking across the Pyodide boundary looked like the hard part. It is a
one-to-one translation. `janus.py:199-224` is a 25-line Python class over three
C calls, `open_query` / `next_solution` / `close_query`; swipl-wasm binds
`PL_open_query`, `PL_next_solution` and `PL_close_query` (6-7 references each in
`dist/swipl/swipl-web.js`) and exposes `prolog.query(goal, input)` returning a
`Query`, taking the same `(goal, inputs)` pair janus takes.

Tried: settling whether the bridge must be async, because `common.d.ts` shows
`forEach` returning a `Promise` and a `CallOptions.async` "call as yieldable".
It must not. Measured in `swipl-web.js`: no `Asyncify`, no `JSPI`, no
`SharedArrayBuffer`, no `Atomics`. The runtime `Query` has four methods, of
which the shipped `.d.ts` declares two:

```
once()  next()  next_yieldable()  close()
```

`next()` is a synchronous call that returns a solution or a yield record.
`next_yieldable()` is a `while(true)` driver that absorbs the periodic `"beat"`
request by calling `set_yield_result("true")` and continuing, throttled to 20ms,
and only becomes asynchronous when a yield request is an actual `Promise` —
which happens when Prolog awaits a JS API, never during ordinary resolution.

So a synchronous bridge is correct for every goal the engine runs on its own.
The only `await` is `initSWIPL(...)` at boot. `JanusBridge.heartbeat(interval)`,
one use site, is the same concept as the `"beat"` request.

Rejected: driving the engine from a worker with Atomics, and waiting for JSPI.
Both answer a blocking problem the query path does not have. Revisit if MeTTa
code needs to await a JS API (`fetch`, `sleep`) inside a goal, which is the one
case that reaches the `Promise` branch of `__next_yieldable`.

Open, and these are the real work:

- `consult` (6 uses) must mount `engine/` and `lib/` into Emscripten's MEMFS.
  The Node seat already does this and already hit one trap worth reading first:
  `extensions/node/src/engine.ts:1139-1143` filters `.qlf` files out of the
  mount, because this build's older wasm SWI resolves a compiled artifact
  instead of the `.pl` and derails the load along with the refusal census.
- `PrologError` (12 uses) needs an exception carrying the Prolog term in the
  shape those sites expect, not just the name.
- Threads are off, so `attach_engine`, `detach_engine` and `m.pool` refuse
  loudly rather than degrading.
- The data crossing is the remaining unknown. `extensions/node/src/wire.ts:111`
  records that `Prolog.toJSON` recurses once per level, which is a
  representation and cost question rather than a control-flow one.

`extensions/node/src/engine.ts` is the reference: it is already this mapping,
written in TypeScript and held by the `node-binding` lane. `CODEC.md` covers the
grammar either way, with `tests/codec/corpus.json` as the conformance kit.

One lifecycle detail this repository has already learned, and a new binding
must repeat: `extensions/cmetta/cmetta.c:2457-2493` cuts a successful query with
`PL_cut_query` rather than closing it, because closing undoes the bindings the
caller still has to read out of the argument vector, and it records the
exception before cutting, because query-stack term references stop being valid
after. `ai-cmetta-c-constraints.md:244-265` carries the reasoning. janus hides
this behind `close_query`; a bridge written against the raw three does not get
to.

## 2026-09-05

The 2026-09-04 revisit condition, "MeTTa code awaiting a JS API inside a goal",
is retired: it is answered twice already, and neither answer needs the
synchronous bridge to change.

Decided: forking janus buys nothing, and the reason is structural rather than
effort. The engine never imports `library(janus)` and never calls `py_call`;
every janus mention under `engine/` is a comment describing seat behaviour, and
`py-atom` reaches the engine through `engine/ext_points.pl` as a seam a seat
fills. janus is one seat's transport, not the engine's dependency. A fork would
have to port CPython-embedded-in-SWI to Emscripten, which is the thing whose
absence started this.

The two directions, both already answered for WebAssembly:

- Host to engine: the `JanusBridge` Protocol, eleven methods, one resolution
  site. Recorded above.
- Engine to host, async included: `engine_yield/1`, `engine_post/2` and
  `engine_fetch/1`, the coroutine trampoline the Node seat chose over the JS
  bridge. `ai-node-typescript-constraints.md:44-66` records it measured
  2026-08-27 — a goal yielded `hostcall(double, 20)`, the host posted `40`, the
  goal resumed and answered `41`, all three predicates present in the
  WebAssembly build — and records why: no globals, no `eval` so it is CSP-clean
  as a browser target requires, the host may `await` between the step and the
  reply so an async op is ordinary, and the request/reply pair is
  transport-independent.

So a JS `await` inside a goal has two routes, and they are not rivals. The
trampoline suspends the goal and resumes it with the reply. The `async` op kind
does not suspend at all: its compiled result is a `FutureSpace`
(`engine/spaces/catalog.pl:17-19`, `test_an_async_operation_answers_a_future_space`),
the coroutine launches after the transaction commits, and `(async-op <name>
<future-space> launch|landing)` makes both ends observable. A future is a space,
so awaiting is matching. In a page the second is usually the one wanted: a
suspending await holds the only engine the tab has until the network answers.

Open, inherited either way, both already measured by the Node seat:

- `ai-node-typescript-constraints.md:139-171`, C8: a yield cannot cross
  `transaction/1` or `snapshot/1`, which raise
  `'$engine_yield'/2: No permission to execute vmi 'I_YIELD' (not an engine)`
  because both open a nested C-level query frame the yield cannot unwind
  through. So a host operation cannot fire inside `petta_transaction/1` or
  `petta_speculate/1`, and a world cannot be an engine suspended inside an open
  transaction across host calls. The seat's answer is the child-space draft,
  Immer's produce-a-draft and git's index shape, with one stated limitation:
  between a remove and the commit, an engine-side query outside the world's own
  read doors still sees the atom.
- C2's consequence: a host op fires only inside an engine, so every evaluation
  door in the seat must run its goal in one, `run` and `load` included.

Open: what `_async_ops.py` becomes without threads. It runs coroutines on a
daemon `threading.Thread` with `asyncio.new_event_loop()`, plus a transient
attached-engine thread per landing; Pyodide has the browser's one loop and no
threads. The contract already reads for the swap — "start schedules it on one
process event loop only after the engine publishes the launch event" — but the
per-landing thread has no browser counterpart, and re-entering the engine from
the browser loop at landing needs a design.

Correction, same day. The paragraph above is right that `engine/` never imports
`library(janus)`, and wrong to leave the impression that the eleven-method
`JanusBridge` is the whole coupling. The SEAT's Prolog half does import it:
`extensions/python/metta/shim.pl:312` is `:- use_module(library(janus))`, and
the file carries 82 `py_call`/`py_iter` sites. So there are two doors, not one.

Counted by target, the engine-to-host door is narrower than 82 suggests:

```
27  py_call(metta_ops: …)      2  py_call(builtins: …)
12  py_iter(metta_ops: …)      6  py_call(<held callable>:'__call__'(), …)
```

Thirty-nine of them aim at one Python module, `metta_ops`, on one convention.
`shim.pl:721` already names the design that makes this tractable: "The wire is
transport-agnostic; janus is one carrier of it." So `py_call(metta_ops:F(A), R)`
becomes `hostcall(F, A)` over `engine_yield`/`engine_post`, and the work is
collapsing 39 sites onto one routed predicate in `shim.pl`, not forking janus.

The six held-callable sites are the ones that need a decision. They invoke a
Python object the engine holds by reference (`py_call(F:'__call__'(), R)`).
Over a trampoline that has to become a handle in a host-side table, which is
what the `o` tag already is — and `CODEC.md:339-362` restricts live `o` and `h`
references to in-process encodings. Whether a trampolined seat counts as
in-process is the open question, and it is the one that decides how much of the
current shim survives.

Second correction, same day, from the SWI source at
`/home/user/Dev/swipl-devel-10.1.13/src`. The C8 constraint quoted above
explains the yield refusal as a nested C-level query frame the yield cannot
unwind through. The guard is narrower and worth stating exactly, because it
changes who can fix it.

`I_YIELD` reads the flags of the INNERMOST query and refuses on a missing bit:

```c
/* SWI-Prolog.h:411 */
#define PL_Q_ALLOW_YIELD  0x0020  /* Support I_YIELD */

/* pl-vmi.c:2340-2345 */
VMI(I_YIELD, VIF_BREAK, 0, ())
{ QF = QueryFromQid(QID);
  if ( !(QF->flags & PL_Q_ALLOW_YIELD) )
  { PL_error(NULL, 0, "not an engine", ERR_PERMISSION_VMI, "I_YIELD");
```

`pl-thread.c:4145` is the only site that sets that bit, at engine creation.
`transaction/1` runs its goal through a nested query that does not carry it:

```c
/* pl-transaction.c:561 and :629 */
rc = callProlog(NULL, goal, PL_Q_PASS_EXCEPTION, NULL);
```

So "not an engine" means "this query was not opened with the yield flag". The
flag exists for the reason C8 gives — a yield would return into `callProlog`'s
C frame mid-transaction with no way to suspend and resume it — but the
mechanism is a flag test, not an unwind failure, and the in-tree proof that the
VM path is fine is that `catch/3`, `once/1`, `findall/3`, `forall/2` and
`setup_call_cleanup/3` all yield, because none of them goes through
`callProlog`.

That makes the fix taxonomy concrete, and only the third is ours:

1. Run the transaction's goal in the SAME query rather than through
   `callProlog`. Upstream.
2. A continuation at the `callProlog` boundary. This is Lua's history exactly:
   5.1 raised "attempt to yield across a C-call boundary", and 5.2 added
   `lua_callk`/`lua_pcallk`, where the C caller supplies a continuation that
   runs on resume instead of returning into the destroyed frame. Emscripten's
   Asyncify and JSPI answer the same question by switching the whole stack, and
   greenlet does it for CPython. Upstream.
3. Do not host-call inside a transaction. The child-space draft, shipped.

Open, and it joins this thread to the throughput campaign rather than sitting
beside it: `ai-rewrite-throughput.md` (charter, 2026-08-30) is already this
workload — "Q is the bang (the query), K is the equation store (the pattern
keys), V is what it reduces to, and the Q/K/V get rewritten every token step" —
and its measured bottleneck is crossings, 11 per py-method call at roughly 1.5k
instructions. A trampolined seat raises the per-crossing constant, so it
multiplies exactly that cost. Its lever 3, one crossing per rewrite batch or an
engine-resident loop, is therefore also the precondition for a browser seat
being usable at all. The two tracks want one architecture.

Two consequences for tensors, both following from the above:

- Arrays cross by reference with identity through DLPack, the `o` tag
  (`extensions/python/metta/arrays.py:1-10`). In a page, Pyodide and swipl-wasm
  share one JS heap, so a JS-side handle table supplies `o`: the bytes stay in
  Pyodide's heap and SWI holds an index, the same discipline janus uses when
  `py_call(builtins:object(), Obj)` binds a `py` blob (`shim.pl:351`). A seat
  that fell back to the remote JSON profile would serialise a tensor per
  crossing. That is why the `o`-tag question above is the first one to settle.
- Every `m.op` on a trampolined seat needs a yield, so a training step cannot
  wrap its tensor calls in `petta_transaction/1` or `petta_speculate/1`, and an
  engine-resident loop does not rescue this because those calls remain host
  calls. Keep the transaction around the pure-data commit.

The `o`-tag question this thread twice called the first thing to settle is
settled, and the answer was already shipped. A WebAssembly seat carries `o`.

`ai-node-typescript-constraints.md` C3 is the ruling: `CODEC.md` gives `o` for a
live host value crossing by reference "in process only", the engine holds no
JavaScript values, so the only honest representation is a HANDLE — the host
keeps the object in a registry and the engine holds the id. The private engine
transport carries `["o", id]`; the public strict decoder `fromTransport` keeps
refusing `o`, because an `o` payload written down elsewhere is not a reference
this host can honour. That is the same strict-wire/known-engine split the `p`
tag already has on both sides.

So "in process only" means only within the session that issued the id, not
within one C address space, and the existence proof is that the Node seat does
this today over swipl-wasm while sharing an address space with nothing.

The two seats differ only for a local reason. Python decodes `o` straight to
the live value (`extensions/python/metta/_atom_wire.py:159-162`,
`Grounded(_unbox_wire_value(payload))`) because janus hands the object across
in-process as a `py` blob. That is an optimisation janus permits, not the
contract; the handle is the portable form.

A Pyodide seat therefore takes the Node model unchanged: a registry on the
Python side, an integer on the wire, tensor bytes that never move, and an `id`
crossing the trampoline as a number. DLPack, zero-copy and the autograd tape
survive because the bytes were never what crossed. Two properties make it
usable rather than merely possible, both already pinned: identity holds across
crossings (`extensions/node/src/wire.ts:40`, "repeated crossings of one
primitive host value reuse its live handle"), which is what
`extensions/python/metta/arrays.py` means by "arrays cross the boundary by
reference with identity"; and lifetime fails loudly (`wire.ts:225`, "host
reference ${id} was released; a stale id is an error rather than a fresh
value"), with `extensions/node/bridge.pl:378` declaring `seam:host_object/1`.

What a browser Python seat actually needs here is the registry, which Python
lacks only because janus made it unnecessary, and its release policy. Both are
ports of working code rather than designs, so nothing in this thread is gated
behind this question any more.
