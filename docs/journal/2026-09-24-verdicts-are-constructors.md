# Verdicts are constructors

Goal: what a hook handler, a typing rule or a translator rule answers stays a
verdict in any program, whatever libraries it imports, and an answer that is
no verdict is refused by name with the verdicts listed.

## 2026-09-24

### What failed

`test_pre_add_compiles_the_four_verdict_judge` failed in any pytest worker
that had run test_space's or test_manifest's `lib_reflect` import first.
`lib_reflect` pulls in `lib_functional`, whose `drop` takes two inputs. The
judge's `(= (guard (dup $x)) (drop))` was then no longer a verdict.

Test isolation or semantics? One program with no test in it answers that. Import
`lib_functional` into `&self`, declare a pre-add hook whose `(dup $x)` equation
answers `(drop)`, and `(add-atom &pool (dup 3))` raised the hook's stuck-state
error. Without the import, the same program passes.

### What upstream does

Measured against PeTTa at 43705f5d9ff8958ffe7f0aa6777fb8477f2401f2 with
`/usr/bin/swipl --stack_limit=8g -q -s src/main.pl -- FILE silent`, with a
two-input `drop` defined, typed or not:

| Form | Upstream answers | This engine answers |
|---|---|---|
| `!(drop)` | `(partial drop ())` | the same |
| `(= (verdict-for $x) (drop))`, then `(verdict-for 1)` | `verdict-for/4` exists; `Unknown procedure verdict-for/2` | `(partial verdict-for (1))` |
| `(cons-atom drop ())` built at run time | `(drop)` | the same |
| a bare `drop` | `drop` | the same |
| `(Drop)`, nothing defining it | `(Drop)` | the same |
| `(quote (drop))` | `(drop)` | the same |

A body that applies a function to fewer arguments than the function takes has
its equation extended to take the rest. So a lowercase verdict turns into a
call wherever a library defines a function with that name. The lowercase
spellings were wrong by construction, and the test leak only exposed that.

### Decided: capitalized constructors, in every protocol

| Protocol | Answers |
|---|---|
| pre-add and post-add hooks | `(Accept)`, `(Accept <atom>)`, `(Refuse <words>)`, `(Drop)` |
| typing rules | `Accept`, `(Refuse <reason>)`, `Defer` |
| translator rules | `(Refuse <reason>)` |

The reasons, as ruled:

- MeTTa already capitalizes its data and control values: `True`, `Empty`,
  `Error`, `NotReducible`. A capitalized head stays data as long as no function
  takes its name, and the convention keeps function names lowercase.
- There is one vocabulary for the one concept. The three protocols spelled
  refusal the same way on purpose, and they still do.
- Upstream shows the lowercase heads become applications as soon as a library
  defines them, so no scoping fix could have kept them safe.

Declined, each with the reason it lost:

- Restoring `&self` after each test that imports a library. The one-program
  reproduction fails with no leak at all, so this would have hidden the defect
  from the suite and left it in every program that imports `lib_functional`.
- Renaming only the hook verdicts. That fixes the collision observed, keeps the
  same hazard for `refuse`, and splits a shape the three protocols share.
- Keeping the lowercase spellings and defining each verdict as an engine
  function that answers its own quoted form. Arity dispatch would keep
  `lib_functional`'s `drop/3` apart from a `drop/1`. But a library that defines
  `accept` or `refuse` at the verdict's own arity, such as a parser's
  `(accept $token)`, would add clauses to the engine's function, and both would
  answer.

### Refusing what is not a verdict

A handler that answers anything but the four verdicts, a lowercase `(drop)`
included, is refused with `metta_hook_bad_verdict`. The message names the
verdicts. `add-typing-rule!` refuses a lowercase outcome with
`domain_error(typing_rule_outcome, ...)` and the remedy
`use Accept, (Refuse Reason), or Defer`.

The case that needed more than a rename is a handler that the claiming module
also defines at another arity. That is exactly what a lowercase verdict leaves
behind beside a library. What a one-argument request then meets depends on
whether any of the handler's equations still takes one input:

| Equations | The request meets |
|---|---|
| `(dup $x) -> (drop)` and `(plain $x) -> (Accept)`, in either order | the one-input equations: `(plain 1)` is admitted and `(dup 3)` answers nothing |
| `$x -> (drop)` alone | `(partial guard ((plain 1)))`: no one-input call site is left |

The first used to be reported as a stuck state, and the second as a bad
verdict that printed a `partial` term. Now `metta_hook_invalid_verdict/5` in
`engine/metta/space_hooks.pl` decides every answer that is not a verdict. A
request the handler leaves unanswered reaches it as its own residual call,
because answering nothing leaves the request as written, and the handler's
partial application to the request is read the same way. For either, if the
module defines the handler at another arity, it throws
`metta_hook_handler_arity`. That error names the least such arity, says how a
lowercase verdict produces one, and lists the verdicts. If not, it throws the
stuck state as before. Anything else is `metta_hook_bad_verdict`. The post
phase's refusal undoes the write, as every post-add error does. The arity check
costs +11 inferences on a stuck request, which is a cold error path. The ch15
examples 03 and 05 and their twins each make one such request and were
re-pinned by that amount.

It is one predicate on purpose. A helper beside it moved 71 library-heavy
examples and their twins by +2 to +10 inferences each, because
`existing_predicate_arities/2` in `engine/filereader.pl` walks every predicate
visible from a loading module whenever a source registers more than 40 names,
and one more engine predicate is one more step of that walk per registration.
An unused predicate appended to HEAD's `space_hooks.pl` reproduced the shift
exactly, +2 on `01-library` and +10 on `37-statistics_lib`, and every other
file of the change measured neutral. The walk itself is
`i-arity-walk-all-predicates`.

"In either order" in the first row needed a translator fix. With the one-input
equation defined first, the extended equation's compile dropped the one-input
arity from the arity registry, and every one-argument call became a partial
application: `(pj (keep 1))` answered `(partial pj ((keep 1)))` where upstream
answers `(Accept)` in both orders. `drop_superseded_arity/3` in
`engine/translator/analysis.pl` drops the arity an extended equation's head
names only when nothing defines it, and it asked that of its own module with
an unqualified `clause/2`. Equations compile into a space's execution module,
so the probe never found one. It now asks the modules `fun_in/2` names and the
engine's own, the rule `function_still_defined/2` already follows. That is its
own commit, ahead of the verdict change.

### The seats

The Python seat's builders are `Accept`, `Refuse` and `Drop`, and a compiled
body spells them by the same names. The Node seat's builders of those names
already existed, but they built the lowercase heads through `WORD_HEADS`, and
no Node test declared a hook. A words-suite case now declares a pre-add judge
built from the three, in a program that imports `lib_functional`. Against
HEAD's `WORD_HEADS` that case fails, and against the capitalized heads it
passes.
