# Python call values at native entries

Goal: pass computed Python argument values into native functions without
executing their data as source a second time.

## 2026-09-14

Tried: Defined and NativeCallable construct raw native applications from their
encoded arguments. All nine value-grain receiver cases reduce a stored
`(+ 1 2)` to 3 or fail its Expression/refinement contract. Eighteen mutable
receiver cases pass. A native let/noeval control preserves all twenty-seven
receiver values. Command: `python -m pytest -q -n 3 --benchmark-disable
--randomly-seed=1125382488 --tb=short
extensions/python/tests/ch09_types/test_class_receiver_values.py`.
Log: `ai-classes-c38-receiver-before.log`.

The corresponding syntax-argument matrix fails eight cases and passes one
across three input annotations and three callable entries. The same command
with `-k python_call_values` selects those nine cases. Log:
`ai-classes-c38-argument-values-before.log`. Each fixture first verifies the
native source/value distinction with a quoted value binding.

Decided: use the constructor source-binding rule at the Python callable
boundary. The existing application builder moves to call_values.apply_sources;
constructors, field setters and callable applications share it. Binding each
computation to a fresh native variable before applying the entry is the
ordinary administrative binding used in an A-normal form. Supplied Python
values use noeval computations; constructor factories retain executable
computations. No engine evaluator or argument type changes.

Rule-variable calls still stage the written term. Ground rule calls evaluate
their supplied values and fold only one answer; zero or multiple answers
retain the written term. Native callable applicators retain their two data
frames, while an ordinary callable receives its reflected parameter values.

Rejected: quote only frozen record arguments, because plain syntax arguments
have the same defect. Rewriting Atom's native meaning would change authored
metaprograms. Copying the constructor binder would add a second description
of the same native let composition.

Python's call rule evaluates argument expressions before invoking a callable:
[language reference](https://docs.python.org/3.14/reference/expressions.html#calls).
The source/value distinction is measured in the native controls above; the
native function-namespace door and explicit space evaluation keep their
existing source semantics.

Outer bindings alone pass 298 cases and fail ten native callable cases in
the combined constructor, field, callable and staging cohort. The lexical
evalc wrapper receives a substituted term and evaluates its arguments as
source again. This follows translate_special_dl(evalc, ...) and
metta_evalc_step/3. Log: `ai-classes-c38-call-values-after.log`.

Tried: remove a lambda's evalc wrapper when its home is already selected.
The probe passes 76 callable cases, `ai-classes-c38-call-home-probe.log`.
Rejected: that changes the explicit evalc boundary and does not cover an
applicator pointing to another home. The foreign-home frame probe fails with
`one() expected exactly one answer, got 0`,
`ai-classes-c38-foreign-application-before.log`.

Decided: retain the original lambda parameters and evalc home expression.
Rename the parameters' occurrences in the carried body to fresh variables,
then bind those variables from quoted matched values inside evalc. Parameter
patterns, segment binding, home selection and the evalc guard keep their
positions. Atom.subs supplies the existing simultaneous tree substitution.
No new native form or fixed-arity replacement is needed.

The rebinding probe passes the foreign-home frame and all 76 callable cases,
`ai-classes-c38-call-rebinding-direct.log`. An earlier version inserted an
extra inner lambda and also passed; direct let bindings express the same
value flow with fewer forms. Command:
`python ai-tmp/ai-classes-c38-call-rebinding-probe.py`.

The combined cohort passes 315 tests after rebinding, including seven new
foreign-home, patterned and segment cases. Log:
`ai-classes-c38-call-values-rebound.log`. Ruff and layering pass. Mypy
requires the known nonempty call head to be held as a Symbol rather than
read through Expression.head's optional type. The evidence scan also needs
the new fixture in Git's index before it can discover its names. Both are
pre-commit verification findings; `ai-classes-c38-call-values-shape.log`
records their exact diagnostics.

The full callable A run passes 1,659 Python cases and fails the existing
endless-producer cost check: Defined costs 930 inferences against the native
take expression's 624. Native suites pass 245 tests and 52 subtests, and
layering, Ruff, mypy and evidence pass. Five production files contain 2,889
lines and no clones. Commands and logs: `ai-classes-c38-call-values-A-*`.
The exact failing Python test passes on pristine c75181adc999adf0028616ee69565e2bbfbf739f,
`ai-classes-c38-call-cost-control.log`. Its command is the same pytest
selection below with only the endless-producer test, run in the cut archive.

The added let/noeval around an already literal argument forces a general
expression cursor instead of the direct named-function cursor. Decided:
propagate native variables and nonsymbol literals through apply_sources.
The wire decoder's v/n/g/o/h tags provide those shapes, and
translate_eager_argument_dl already leaves them unchanged. Retain bindings
for expressions and atoms, including Boolean and named-space tags, since
scalar equations can rewrite them. Argument assembly remains linear in the
number of arguments; the repaired cost is the unnecessary general-cursor
dispatch, not an asymptotic claim.

Nine additional cases install and remove two scalar rules on symbols and
booleans, comparing explicit native source calls with Python argument calls
through Defined, named callable and lexical lambda entries. All 46 focused
cases pass, including the cost regression. Command: `python -m pytest -q
-n 3 --benchmark-disable --randomly-seed=1125382488 --tb=short
extensions/python/tests/ch09_types/test_class_receiver_values.py
extensions/python/tests/ch11_python_as_a_notation/test_library_fixes.py::test_function_calls_suspend_endless_producers`.
Log: `ai-classes-c39-call-literals-corrected.log`. The first fixture used
Space.add as a context manager, although it returns None; its nine failures
are fixture errors, corrected to add/remove, `ai-classes-c39-call-literals.log`.

The standalone existing cursor fixture, observed at its return with
`python ai-tmp/ai-classes-c39-call-cost.py`, records native take616,
function handle273 and Defined358 inferences. The observer reads completed
Stats objects and does not add native calls inside a measured interval.
Log: `ai-classes-c39-call-cost.log`, exit0. These are the standalone process
deltas; the pytest process above has its own instrumented baseline.

The complete corrected run at 2028f851a316b2fd0e4a01c29f951028a504aaba
passes 1,669 Python tests and 245 native tests with 52 subtests. Layering,
mypy and evidence pass; 2,905 lines in five production files have no clones.
Ruff's two FBT003 findings are positional Boolean payloads in the new test.
They use keyword payload spelling before the final evidence snapshot.
Commands and logs: `ai-classes-c39-call-values-A-*`.

## 2026-09-18

Supersedes the 2026-09-14 decision above ("use the constructor source-binding
rule at the Python callable boundary": every Python argument quoted).

Tried: the twin lane on the branch tip d761b9c43. Eleven twins fail to run;
eight of them at a call whose argument is syntax the twin wrote, `f(S.add(1,
1)) == [44]` under `(: f (-> Number %Undefined%))` in ch09 04-outputtype,
`both(S.gt(2, 1), S.gt(3, 2))` in ch07 10-and_then_or_else, `kind(S.half(3))`
in ch09 11-subtyping, `wu1(S.add(2, 4), S.add(4, 2))` in ch09 03-functiontypes,
`wrapper2(ADD_ONE)` in ch05 04-specialize, `f(S.g, 42)` in ch05
07-specializefunctiontypes, a lambda handed to `maplist` in ch08 05-lambda
(`apply:maplist/3: Unknown procedure: '[|]'/4`, the quoted lambda reaching the
list predicate as data). Every one answers the unevaluated argument, because
`Defined.__call__` wraps each argument in `noeval` and binds it before the
application, so the callee's declared parameter type never sees it.
Command: `python ai-tmp/ai_run_twin.py <twin>` in wt-battery-5 (logs
`ai-tmp/ai-twin-*.log`). The same twins pass on trunk fafab2703, whose door
was `self.space.answers(term)`.

Measured: what the two engines do with an argument written at a call site,
one collapsed answer per runnable, `ai-tmp/ai-probe-upstream-collapse.metta`
through PeTTa-base `run.sh` and this tree's `run.sh`:

| runnable | upstream 43705f5 | this tree |
|---|---|---|
| `(f (+ 1 1))`, `(-> Number ...)` | `(44)` | `(44)` |
| `(e (+ 1 2))`, `(-> Expression ...)` | `()` | `()` |
| `(a (+ 1 2))`, `(-> Atom ...)` | `((+ 1 2))` | `((+ 1 2))` |
| `(obs (C (+ 1 2)))`, `(: C (-> Atom C))` | `()` | `(3)` |
| `(u sym)`, `(= sym 7)`, `(-> %Undefined% ...)` | `(sym)` | `(7)` |
| `(let $w (C (+ 1 2)) (obs $w))` | `()` | `(3)` |
| `((|-> ($x) (a $x)) (+ 1 2))` | `(3)` | `(3)` |

So: only an Atom position takes its argument as written (Expression evaluates
and then checks, `non_evaluated_parameter_type/1`); a constructor's declared
Atom parameter does not protect a nested argument in either engine; a lambda
evaluates its argument whatever its body does with it; and a value bound to a
variable is passed as it is, which is how `(let $r (noeval (C (+ 1 2))) (obs
$r))` answers `(+ 1 2)` in this tree (the receiver test's own control).

Decided: a Python call spells the MeTTa application. An `Atom` argument is
syntax written at the call site and enters the application as written, so
the callee's arrow decides it exactly as `m.eval` would; a Python object is
a value the caller computed and crosses under `noeval`, bound to a fresh
variable, which is the engine's own rule for a bound variable. That is the
distinction PeTTa itself draws between a literal call-site expression, which
it translates to evaluation goals, and a bound variable, which it passes.
`call_values.source` states it once; `Written` marks the first kind so
`apply_sources` places it as it stands, and `argument_sources` takes
`written=` to tell a Python call site from a frame of completed values. A
lambda image has no arrow the engine could read, so the door holds the
positions its `Callable[[Atom, ...], R]` annotation or `@python-callable`
signature rows declare Atom, and a frame element that is written syntax for
an evaluated position runs before it enters the frame (`pack`). The engine's
mask now sees through a refinement, `(Annotated Atom (MinLen 2))` keeping
Atom's mask and its own check on the written term, so `Annotated[Atom, ...]`
parameters behave as Atom at the boundary too.

Rejected: keeping every argument quoted and repairing the twins, because the
twins are the semantics documentation and their claim, that `f(S.add(1, 1))`
IS `!(f (+ 1 1))`, is the library's law (Python is notation, MeTTa is
meaning). Rejected: quoting only declared-class instances, because a list or a
generator is a value for the same reason an instance is; `source` says "Atom
or not", which covers them all.

What changes for a Python author: an Expression-typed position no longer
stores `S.add(1, 2)` as syntax from Python; it evaluates it, as MeTTa does,
and the payload-preserving spelling is `S.noeval(S.add(1, 2))`, the form the
examples already use. An Atom-typed position stores syntax either way.
test_class_receiver_values.py, test_class_argument_values.py and the two
carried-frame tests in test_callable_applications.py state the new law; the
2026-09-14 test that asserted a Python call ignores a live scalar rule
(`test_python_call_values_preserve_symbols_with_live_scalar_rules`) is
replaced by `test_written_symbol_arguments_follow_live_scalar_rules`, which
asserts the Python call and the written application answer alike.

### The same day, what the first cut of the rule missed

Tried: the first `source` said "an Atom is written, anything else is a value".
The translator-rule twin (ch20 01-translatorrule) calls `compileeval42((43,))`:
the tuple encodes to `(43)`, and as a value it is bound to a variable before
the call, where a translator rule needs its argument written at the call
site; the call answered nothing. And `identity(CarriedClass)` passed the
class object as written: its image is the constructor lambda, which the
evaluated position turned into the engine's closure, and `convert.build`
could no longer recognise the class. Decided: a Python container is a literal
the codec spells, so it is written; an image, anything that is neither an
Atom, nor a container, nor grounded, is a value. `runtime_annotation`, the
container test `argument` already uses, is the one predicate.

Tried: `NativeCallable.application` read every Atom argument as written. The
seam (`_python-bind-call-value` and `_python-bind-call`) hands it the frames a
compiled body assembled, whose atoms are completed values, so `(+ 1 2)` bound
to an `Atom` parameter and passed on to a callback was evaluated to 3
(test_carried_native_calls_hold_completed_operand_values). Decided:
`application(..., written=)`: the Python door says written, the seam says not.
The fixed binder also took a keyword for a positional-only namesake
(`_signature(value, /, ..., **options)` called with `value=9`): Python's own
binding says where each argument went, so the binder follows `bound.arguments`
and a keyword reaches a parameter only where Python binds it there.

Tried: the compiled body of `def f(g, x): return fn.repra(g(x))` under
`(: f (-> Atom Number Atom))` (ch05 07-specializefunctiontypes). Since
e01a1a46a every call of a bound callee crossed the seam as call frames, so
the Atom result showed `(repra (let ... (_python-call-value ...)))` where the
example answers `(repra (g 42))`. The same route ran the benchmark twin's
recursive `range_(n - 1)` a million times through frame assembly: ch18
02-holbenchmark did not finish in 80 minutes on this tree and finishes in
under 600 s on trunk. Measured: the engine applies every head kind itself, a
symbol, a lambda closure, a lambda's syntax, and a grounded Python callable
(`(<host> 41)` answers 42; a bound `(+ 1 2)` reaches the host as the janus
list `['+', 1, 2]`; a `(Kwargs ...)` value, literal or bound, is read as
keywords by `metta_py_split_kwargs`). Decided: a positional call of a bound
callee compiles to the plain application `($g $x)`, the example's spelling and
trunk's; expanded and keyword calls, which MeTTa cannot spell, keep the frames
route and the seam's `pythonic` codec, as do host islands.
test_compiled_host_calls_keep_data_out_of_keyword_control loses its `_direct`
row and test_a_positional_call_of_a_bound_callee_is_the_written_application
states the positional law: the compiled body answers what the written
application answers, Kwargs convention included. Open: the engine's grounded
call converts through janus (lists, `None` as `()`) while the seam and the
islands convert through `pythonic` and `returned` (tuples, held syntax); two
codecs for one boundary, whose owner is undecided. After the change
02-holbenchmark completes inside the lane's timeout (`ai-tmp/ai-twin-02-holbenchmark.log`,
wt-battery-4).

Tried: `_x_Lambda` answered `(noeval (|-> ...))` everywhere (10ef2f6958), so
`fn.maplist(lambda a: fn.add(1, a), items)` compiled to `(maplist (noeval
(|-> ...)) $items)`; `maplist` evaluates its function position, `noeval`
answers the lambda's syntax rather than a closure, and `apply:maplist/3`
raised `Unknown procedure: '[|]'/4` (ch08 05-lambda). Measured
(`ai-tmp/ai_probe_lambda_forms.py`): a bare `|->` evaluates to a closure
`lambda_N`, which `maplist` and a `let` apply; `(= (make-inc) (|-> ($x) (+
$x 1)))` answers the closure and `((make-inc) 41)` is 42; the noeval tail
answers the syntax and applies the same. Decided: the bare `|->` everywhere a
lambda is applied or bound, the quoted syntax where a function returns one,
so a caller can rebuild it through the `@python-callable` row `_x_Lambda`
publishes (`_return_statement`).

Twins repaired beside the door: ch09 11-subtyping declared `half` with an
arrow and no equation, a data constructor whose result sort the branch widens
through its `:<` closure (bb4bbf578), while the example gives `half` an
equation and adds the `ratio` constructor claim; the twin now mirrors both.
ch17 05-channels read the engine's `existence_error(metta_channel ...)` out
of a second `channel-close`; since a9b0ddb6d a Python handle whose space was
dropped is dead and the seat refuses at the door, so the twin asserts that
refusal for the second close and the receive.
