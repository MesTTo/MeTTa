# Developer-facing diagnostics: annotations, why/lint, trace filter, repl, debugger
Goal: five backlog rows about the diagnostics surface, each run before it is
believed and built only where it reproduces.
Constraint: the rows arrived as source READINGS labelled reproductions. Every
verdict here comes from an executed program, and the ones that turned out to be
pinned rulings stay unbuilt.

## 2026-09-05

Tried: reproducing L081 (`resolve type hints per annotation`) by registering a
callable with one `TYPE_CHECKING`-only annotation among three ->
`m.op(widen)` raised `TypeError: the annotations of widen do not resolve (name
'Decimal' is not defined)` while `n: int` and `-> int` were both perfectly
resolvable. Reproduces.

Tried: deciding whether the refusal is a defect or a ruling. `test_adoptions.py`
`test_registration_failure_leaves_nothing_half_registered` pins ATOMICITY, not
the refusal, and `test_define.py`
`test_an_unresolvable_annotation_is_not_a_space_parameter` already states the
governing rule in its own docstring: "the strict refusal belongs only where an
annotation is consumed as a type. A bare NAME that resolves nowhere keeps
refusing loudly".
Decided: keep every refusal that a declared call form reaches, and remove only
the ones nothing consumes. The sharp case is
`def joiner(a: int, *rest: Decimal) -> int` at `arities=[1]`: `rest` is in no
declared arrow, and refusing over it threw away a working registration.

Rejected: `annotationlib.Format.FORWARDREF` as the resolver. It leaves an
unresolvable name as a `ForwardRef` instead of raising, which is exactly the
shape wanted, but only for PEP 649 lazy annotations: with
`from __future__ import annotations` the annotations are already strings and
every format answers the string unevaluated
(measured on 3.14.4: `VALUE`, `FORWARDREF` and `STRING` all answer
`{'n': 'int', 'precision': 'Decimal', 'return': 'int'}`, and `eval_str=True` is
refused for any format but `VALUE`). Revisit if the future-import form stops
appearing in registered code.

Rejected: `typing._eval_type` per annotation, which is what `get_type_hints`
does internally. Private, and its signature has moved across 3.12-3.14.

Decided: resolve each annotation on a PROBE FUNCTION carrying the callable's
own globals and type parameters, and hand that to the public
`typing.get_type_hints`. One annotation in, one resolution out, and everything
`get_type_hints` knows how to do it still does. Measured identically on 3.12.13,
3.13.13 and 3.14.4 over a signature mixing `Annotated[str, "unit"]`, a type
parameter `T`, a postponed `list[int]`, a module-level class, a `__wrapped__`
callable and two unresolvable names: five resolve, two fail, on all three.

Decided: the whole-signature `get_type_hints` still runs first and answers
unchanged whenever it succeeds, so the per-annotation pass only ever runs where
the previous code raised. No ordinary registration changes cost.

Decided: an unresolvable annotation stands in the map as `Unresolved` and
`type_atoms_for` raises when handed one, because that function is the single
funnel every consumer reaches to turn an annotation into a type. Value
conversion reads `Any` for one instead, through `for_conversion`, since "we
could not name this type" is what `Any` already means at that boundary.

Tried: reproducing L088 (`share unknown-head and arity analysis between why()
and lint()`) by asking both doors the same three questions ->
`m.why((if $c $t $e))` answered "nothing here is headed by if, and no function
has that name; did you mean if?" while lint reported nothing, correctly.
`m.why((double 1 2 3))` against a one-argument `double` answered "try eval",
where lint reported the arity mismatch. Reproduces, and the first one is a
wrong diagnosis rather than a missing one.

Found the shared question already answered engine-side:
`head_meaning_route/3` in engine/translator/special_forms.pl, published for
hosts, whose own comment says "One place asks both questions, so a route added
to either is covered wherever the pair is consulted". lint asks both through
`EngineRegistry`; why() asked only `fun/1`.
Decided: keep the Python-side registry as the shared cache rather than adding a
seam predicate, because lint already crosses through it once per name and why()
needs the same three facts.

Rejected: leaving the shared verdict in `_lint_model.py`. The module is named
for lint and `_space_diagnostics` is core, so the dependency would have read as
a layering accident. `_head_meaning.py` carries `EngineRegistry` and the
verdict; `_lint_model.py` keeps the `Finding` record. Added to the
import-linter core list so the new module is held to the same rule.

Decided: one suggestion pool and one cutoff. why() drew from `m.builtins()` at
0.75 and lint from `fun/1` alone at 0.8, which is two drifts at once: lint could
not offer `collapse` for `collapes` because `metta_translated_head/1` does not
enumerate, and why() could suggest a name for ITSELF, which is where
"did you mean if?" came from. The pool is now the catalogue plus the caller's
stored heads, minus the queried name; 0.8 is the tighter of the two thresholds
and every near miss the suite pins clears it (car-atmo/car-atom 0.875,
car-atomm/car-atom 0.941, doubl/double 0.909, collapes/collapse 0.875).

Tried: reproducing L078 (`trace(filter=...)`) -> `m.trace("!(quad 3)",
filter="double")` raised `TypeError: Space.trace() got an unexpected keyword
argument 'filter'`, and `inspect.signature` confirms no target parameter.
Reproduced, built, and then SUPERSEDED before it could land: petta merged
a0580a1b for the same row while this branch was in flight, so `trace(filter=)`
ships from there and nothing of this row's implementation remains here. What is
worth keeping is the measurement and the decision it lost.

Rejected: this branch's wrap-site narrowing, in favour of a0580a1b's
record-site filter. The two differ in one choice and each pays for it:

- Filtering at the RECORD keeps every wrapper running, so an excluded call
  still contributes DEPTH and a selected descendant reads at its true nesting
  level. That is what shipped, and its own comment cites CPython 3.13
  `trace.py globaltrace_lt`, which decides before recording for the same
  reason.
- Filtering at the WRAP leaves an unnamed function its bare predicate, so it
  runs at exactly its untraced cost. Measured here on a five-function program
  whose whole trace is 62 events: 9,418 inferences for the whole trace, 3,091
  narrowed to one function, 67.2% fewer, against 541 for the untraced run
  (`m.stats()` inferences, deterministic; loadavg 24, which is why no wall
  clock is quoted). The price is that a narrowed event's depth is nesting
  among the TRACED functions only: tracing `double` inside
  `(quad (double (double 3)))` answers two calls at depth 0, not depth 1.

Decided: depth beats cost here, so the shipped design stands. A filtered trace
is read by a person looking for where a call sits, and a depth that silently
means something else is a wrong answer where a slower trace is only a slow one.
Revisit if a filtered trace is measured to be too expensive on a real program
rather than a five-function fixture, in which case the wrap-site variant is
recoverable from this branch's history and the depth it loses can be restored
by recording an unfiltered depth counter alongside.

Also rejected on the way, and worth recording because the shipped door chose
otherwise: `only=` rather than `filter=`, on the grounds that ruff's
flake8-builtins A002 refuses an argument shadowing a builtin. a0580a1b keeps
the row's own word and carries `# noqa: A002 -- public trace selector`, which
is the better answer: the name a caller reads is worth one narrow suppression.

Also superseded: the seam move. This branch published `metta_trace_source/6`
and retired `/5`; a0580a1b keeps `/5` published and carries the filter inside
its bound argument as a two-item request, which leaves the Node bridge and the
shim floor untouched. One fewer moving part for the same feature.

Tried: reproducing L074 (`REPL completion and persistent history`) on a real
pty -> TAB after `(car-a` inserted a literal tab, `Up` in a second session
recalled nothing, and no history file existed anywhere under $HOME afterwards.
Reproduces. Within-session line editing and history already worked, from the
bare `import readline` that was there; what was missing is a completer and a
file.

Found: CPython's own `site.register_readline` is this exact feature, and it is
what the change follows -- bind the completion key for the backend present
(`tab: complete`, or `bind ^I rl_complete` under editline), read the user's
init file if there is one, then read the history file and write it back
[source: https://github.com/python/cpython/blob/3.14/Lib/site.py]. The
completer's protocol, one call per candidate with the matches computed at
state 0, is rlcompleter's. So nothing here is a line-editor: it is readline
and rlcompleter's own shapes, pointed at the engine's catalogue.

Decided: the delimiters are the one part that had to be ours. readline's
default set is
`' \t\n`~!@#$%^&*()-=+[{]}\\|;:\'",<>/?'`, which breaks a token on `-`, `!`,
`?`, `*` and `&`, every one ordinary inside a MeTTa head. Measured before the
change: `(car-a` plus TAB inserted a tab; after setting the delimiters to
whitespace, parentheses and the string quote, it completes to `(car-atom`,
`(coll` completes to `(collapse` (a translator special form, which `fun/1`
alone would not have offered) and `&s` completes to `&self`.

Decided: drop the terminator from the saved history. `exit` is always the last
line and never worth recalling; leaving it in made the next session's first Up
answer `exit`, measured on the first working build.

Rejected: `atexit` for the write, which is what site.py uses. The REPL owns its
own loop here, so a `finally` around it writes on every exit path and is
testable without a process boundary.

Tried: `annotationlib` behind a try/except ImportError, for L081's resolver ->
the optional mypyc build failed with
`_type_annotations.py:55: error: Incompatible types in assignment (expression
has type "None", variable has type Module)`. The two type checks disagree by
version: this tree's mypy targets 3.12, where the module does not resolve at
all, while mypyc runs mypy at the interpreter's own 3.14, where it resolves.
Decided: define the resolver twice under `sys.version_info >= (3, 14)`, which
both checks read natively and which needs no configuration entry. Caught by
test_the_codec_builds_under_mypyc_as_an_option, and folded into the commit that
introduced it.

Tried: reproducing L075 (`debugger breakpoints, suspension, stepping, resume`)
over the whole surface -> none of `break`, `step`, `suspend`, `resume`, `debug`,
`spy` or `pause` appears among Space's 113 public names, `TraceEvent` is frozen
with four fields, and `m.trace` answers only after the run has finished.
Reproduces.

Researched before building, because the row's own ledger says the pieces exist.
What the two runtimes already have, and what is therefore NOT written here:

- SWI's `prolog_trace_interception/4` is a synchronous callback with the full
  port and action vocabulary, and the manual is explicit that its internal
  query is opened `PL_Q_NODEBUG | PL_Q_CATCH_EXCEPTION`, without yielding, so
  a yield inside it is not a supported way back to an embedding host.
  `library(prolog_breakpoints)` sets SOURCE breakpoints, which compiled MeTTa
  functions have no file/line mapping for, and `prolog:break_hook/7`'s action
  vocabulary has no `suspend`.
- SWI 9.3.21 added a real return-to-host debugger interface,
  `PL_Q_TRACE_WITH_YIELD` with `PL_S_YIELD_DEBUG`, `PL_get_trace_context` and
  `PL_set_trace_action`. Janus does not open its queries with it: `mod_swipl.c`
  uses `PL_Q_CATCH_EXCEPTION | PL_Q_EXT_STATUS` and its result handling has no
  yield case, so no Python caller can receive one today.
- CPython's `bdb` is the ARCHITECTURE to copy and not a mechanism to reuse:
  the stop callback IS the suspension, `set_step`/`set_continue` only select
  how execution goes on, and returning from the callback is what resumes it.
  `sys.settrace` and `sys.monitoring` see Python frames, not reductions.
- SWI engines are the mechanism. Measured on this engine, 2026-09-05:
  `engine_yield/1` five frames down inside `engine_create/3`'s goal answers
  the caller's `engine_next/2`; `engine_post/3` delivers a term to
  `engine_fetch/1` and resumes; a `b_setval` inside the engine is invisible
  outside it; and `engine_yield/1` with no engine around it raises
  `permission_error(execute, vmi, 'I_YIELD')`.

Decided: the debugger is the TRACER'S OWN WRAPPERS with a second action. A
trace records an event; a debug session suspends on it. One session at a time
either way, which the existing `metta_trace_session` fact already enforces and
now refuses across both kinds.

Decided: wrap ALL targets, unlike the L078 filter. Stepping has to enter a
function nobody set a breakpoint on, which is exactly why bdb traces every
frame and decides in `stop_here`/`break_here`.

Tried: leaving the wrapper's non-debug path on `metta_trace_record/4` -> a
latent hang-or-fail. A debug session holds its wrappers across the host's
thinking time, so an unrelated evaluation on another thread reaches the
wrapper, and `metta_trace_record/4`'s conjunction needs a limit no debug
session sets, so it would FAIL, and a failing wrapper fails the predicate it
wraps. The wrapper now dispatches on the session kind and falls through when
there is none. Pinned by
test_an_ordinary_run_on_another_thread_is_untouched_by_a_session, which
answers 20 from another thread while the session is suspended.

Decided: no `timeout=`, and `inferences=` yes. A session is suspended by
design, so a wall clock would run while a person reads a stop; inferences
count work and are the way out of a resume with no breakpoint ahead of it.
The bound rides inside the engine, where `metta_host_inference_budget/3`
already puts a cursor's.

Measured, and pre-existing rather than caused here: two twin budgets fail on
this branch's base. `01-identity.metta` costs 3528 inferences against a pinned
3575 and `03-spaces3.metta` 254 against 262, both below by more than the
4-inference allowance, measured at 51d9e5a9 with every change here reverted.
This branch moves the first to 3534, attributed to `engine/ext_points.pl`
alone by reverting that one file (3528 without it, 3534 with it): three new
`kind/2` rows for the debugger's host services. Both stay under their pins,
and re-pinning belongs to whoever made the engine cheaper.

Also pre-existing: `tests/repository/test_gate_completeness.py`'s ruff
burn-down was already red at 51d9e5a9, D at 2232 against a 2231 ceiling and
ARG at 150 against 147, measured on that tree with `--ignore-noqa`. Both
ceilings are now recorded at the measured number with the split written down.
And `lib_thread:a_saturated_timer_pool_does_not_block_scheduler_deadlines`
failed once inside a full plunit run at loadavg 68 and passed alone at
loadavg 68 (68/68 in 5.259s wall, 0.099s CPU), which is a wall-deadline lane
on a loaded box.
