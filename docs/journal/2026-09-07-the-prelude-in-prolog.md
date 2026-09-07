<!-- Purpose: record why the engine's prelude vocabulary became Prolog, what each head cost before and after, and which designs for the union/intersection name collision lost. -->
# The prelude in Prolog
Goal: the engine's standard vocabulary stops being a MeTTa file every boot
parses and translates, and becomes Prolog-bodied builtins, with the MeTTa
equations surviving as the executable spec and the differential oracle.
Constraint: upstream PeTTa is the arbiter, so no bag and no multiplicity may
move; every existing suite keeps its meaning; a program that defines one of
these names still takes it over entirely and one-way.

## 2026-09-07

Read first: `engine/metta.pl`'s `load_engine_prelude/0` and its five registers,
`engine/kernel.pl`'s header (the 2026-08-21 ruling this follows),
`engine/translator/lowering.pl`'s `apply_translator_rule_dl/7`,
`engine/spaces/lifecycle.pl`'s `metta_exec_module_base/2` and the shadow
repair, and the three suites that read the registers.

Tried: dumping the clause the translator derives for each of the 36 equations,
with `clause/2` over `'$metta_exec:&self'` on the pristine tree, before writing
anything. That is the specification each Prolog body has to meet, and reading
it settled three things prediction had not: the assert family's
masked-result branch is dead on every path, `for-each-in-atom`'s is NOT (a
mapped expression re-enters evaluation), and `unquote`'s first clause carries a
cut from its `(let $cut (cut) ...)`.

### What each head cost, and what it costs now

Measured with `ai-tmp/prelude-percall.pl`, 200 rounds per case over the same
corpus on both trees, the engine's own inference counter, minus a null-driver
overhead read in the same process. The `.qlf` set was cleared and warmed for
each arm.

| head | case | before | after | factor |
|---|---|---|---|---|
| `match-types` | `(match-types (List $x) (List Number) t e)` | 5,401.01 | 156.01 | 34.6x |
| `type-cast` (declared) | `(type-cast (+ 1 1) Number &self)` | 5,029.01 | 260.01 | 19.3x |
| `type-cast-holds` | `(type-cast-holds 2 Number &self)` | 4,972.01 | 203.01 | 24.5x |
| `match-type-or` | `(match-type-or False A A)` | 4,854.01 | 86.01 | 56.4x |
| `if-error` | `(if-error (Error a b) yes no)` | 3,800.01 | 127.01 | 29.9x |
| `return-on-error` | `(return-on-error 42 fallback)` | 2,968.01 | 69.01 | 43.0x |
| `throw` | `(throw plain-reason)` | 2,122.01 | 61.01 | 34.8x |
| `if-error` (a clean value) | `(if-error 42 yes no)` | 1,578.01 | 81.01 | 19.5x |
| `match-types` (wildcard) | `(match-types %Undefined% B t e)` | 1,469.01 | 94.01 | 15.6x |
| `interpret` | `(interpret (+ 1 2) %Undefined% &self)` | 834.01 | 363.01 | 2.3x |
| `is-function` | `(is-function (-> Number Number))` | 472.01 | 455.01 | 1.04x |
| `assertEqualMsg` | `(assertEqualMsg (+ 1 1) 2 m)` | 436.01 | 439.01 | 0.99x |
| `assertEqual` | `(assertEqual (+ 1 1) 2)` | 423.01 | 426.01 | 0.99x |
| `assertEqualToResultMsg` | `(assertEqualToResultMsg (superpose (1 2)) (1 2) m)` | 353.01 | 312.01 | 1.13x |
| `assertEqualToResult` | `(assertEqualToResult (superpose (1 2)) (1 2))` | 340.01 | 299.01 | 1.14x |
| `assertAlphaEqualMsg` | `(assertAlphaEqualMsg (f $x $x) (f $y $y) m)` | 324.01 | 319.01 | 1.02x |
| `assertAlphaEqual` | `(assertAlphaEqual (f $x $x) (f $y $y))` | 311.01 | 306.01 | 1.02x |
| `atomically` | `(atomically (+ 1 2))` | 299.01 | 294.01 | 1.02x |
| `assertIncludes` | `(assertIncludes (superpose (1 2 3)) (2 1))` | 296.01 | 291.01 | 1.02x |
| `assertAlphaEqualToResultMsg` | `(assertAlphaEqualToResultMsg (noeval (f $a)) ((f $b)) m)` | 232.01 | 227.01 | 1.02x |
| `for-each-in-atom` | `(for-each-in-atom (1 2 3) repr)` | 222.01 | 217.01 | 1.02x |
| `unquote` | `(unquote (quote (+ 2 3)))` | 220.01 | 215.01 | 1.02x |
| `assertAlphaEqualToResult` | `(assertAlphaEqualToResult (noeval (f $a)) ((f $b)))` | 218.01 | 213.01 | 1.02x |
| `noreduce-eq` | `(noreduce-eq (+ 1 1) (+ 1 1))` | 153.01 | 148.01 | 1.03x |
| `if-equal2` | `(if-equal2 a b yes no)` | 102.01 | 97.01 | 1.05x |
| `type-cast` (by metatype) | `(type-cast a Symbol &self)` | 100.01 | 95.01 | 1.05x |
| `if-equal` | `(if-equal 1 1 yes no)` | 97.01 | 92.01 | 1.05x |
| `unquote` (inert) | `(repr (unquote 42))` | 60.01 | 53.01 | 1.13x |
| `and-then` | `(and-then True yes)` | 59.01 | 59.01 | 1.00x |
| `or-else` | `(or-else False fallback)` | 60.01 | 60.01 | 1.00x |
| `trace!` | `(trace! m 7)` | 69.01 | 69.01 | 1.00x |
| `unique` | `(collapse (unique (superpose (1 2 1))))` | 189.01 | 189.01 | 1.00x |
| `alpha-unique` | `(collapse (alpha-unique (superpose (1 2 1))))` | 210.01 | 210.01 | 1.00x |
| `union` | `(collapse (union (superpose (1 2)) (superpose (2 3))))` | 235.01 | 235.01 | 1.00x |
| `intersection` | the same shape | 254.01 | 254.01 | 1.00x |
| `subtraction` | the same shape | 254.01 | 254.01 | 1.00x |

The eight derived forms read the same to the inference on both trees, which is
the invariant their design predicts: their expansion happens once while the
call site compiles, and the expanded code is the same code.

`assertEqual` and `assertEqualMsg` are 3 inferences WORSE, and they are the
only two heads that are. Every other non-derived head is 5 better, so the
ordinary shape change is -5 and these two are +8 against it. Not isolated
further: it is 0.7% on two heads while the same change is between 15x and 56x
on nine, and both stay inside the collapse the family pays anyway.

### The boot

`swipl -q -g "metta_bench:bench_run(boot)" -t halt engine/bench.pl`, three
identical samples per arm, `.qlf` cleared and warmed, engine C artifacts
present, loadavg 60 to 75 throughout.

| arm | inferences |
|---|---|
| `petta` at d0892040 | 272,323 |
| this branch, translator fix reverted | 247,796 |
| this branch | 248,271 |

So the prelude's own share is -24,527 (-9.01%) and the translator fix below
puts 475 back, for -24,052 (-8.83%) net. `perf stat -e instructions:u` over
`PYTHONPATH=extensions/python python -c "import metta; metta.run('!(+ 1 2)')"`,
three warm runs each, minimum of three: 2,107,333,169 before against
2,081,168,046 after, -26,165,123, -1.24%. The samples were
[2108142469, 2107337447, 2107333169] and [2081168046, 2081176464, 2081325514],
spreads 0.038% and 0.008%, at loadavg 59 to 69; the first run of a cleared
`.qlf` set reads 4,628,819,778 and is the artifact-generating boot, not this
measurement.

### Decided: the vocabulary is a module the execution chain resolves through

Rejected: putting the bodies in the engine module beside every other builtin,
which is where `engine/metta/*.pl` units put theirs. MeTTa's `union` and
`intersection` are `union/3` and `intersection/3`, and the engine module
imports both from `library(lists)`; SWI answers a local definition of an
imported name with `Local definition of user:union/3 overrides weak import from
lists` and keeps the local one, so the behaviour would be right and the boot
would print two warnings. Revisit if MeTTa ever loses those two names.

Rejected: `use_module(library(lists), except([union/3, intersection/3]))` on
every file that imports the list library into the engine module. Ten files do,
three at boot and six on `import!`, and an eleventh added later re-introduces
the warning silently. It also makes `union/3` inside engine code mean MeTTa's
rather than the list operation's, which is a surprise nothing warns about.

Rejected: importing the prelude's 32 predicates into `'$metta_exec:&self'`
explicitly rather than through the base chain, which would keep the chain the
length it was. `metta_restore_inherited_predicate/3` re-resolves a name through
the chain after a shadow is removed, and the chain would then find
`library(lists)`' `union/3`: removing a program's own `union` would replace
MeTTa's with the list operation. Revisit if that repair ever prefers the source
it recorded over the one that resolves now.

Decided: `engine/prelude.pl` is a module and
`metta_exec_module_base('&self', prelude)` puts it in the chain, so the order is
`system -> the engine's module -> prelude -> '$metta_exec:&self' -> every other
space`. The engine module still resolves `union/3` to the list operation and
every space resolves it to MeTTa's, no import list anywhere is edited, and
shadowing needs no clause eviction at all: a program's definition compiles into
its own module and wins there.

Measured, the cost of that link: `translate` reads 310,352 inferences against
trunk's 308,706, and 308,720 with the chain shortened by exactly one module
(`metta_exec_module_base/2`'s named-space clause pointed straight at the tier).
So all of the +1,646 is the extra link, which every first resolution in a fresh
space module walks; `evaluate` moves +86 the same way (560,506 against 560,438
with the link removed and 560,420 on trunk); `match`, `match-skew` and `parse`
move by exactly 0. That is the price of the two names keeping their spelling.

### Decided: the registers stay, the equations become a register row

`prelude_type_declaration/2`, `prelude_owned/1`, `prelude_cost_row/2`,
`prelude_translator_rule/1`, `prelude_equation/2`, `prelude_wrote_builtin_type/2`
and `prelude_doc_atom/2` all keep their contracts and their readers.
`prelude_clause_ref/2` goes: there are no clauses in `&self`'s module to erase.

`prelude_equation/2` stays because the effect planner reads it for a name whose
body is inherited rather than local, which is now EVERY space's view of the
prelude, and the confluence reporter reads the eight derived ones as the
shipped rewrite tier. Without it the planner would classify the whole
vocabulary `oracleIO`. It is installed at boot from `prelude_shipped_equation/2`,
a static table the artifact carries, rather than being that table: the
confluence reporter's own selftest plants rows and takes them out with
`retractall/1`, which would take a rule clause with them.

Rejected: pointing the confluence reporter at `tests/data/prelude-spec.metta`.
The register is the same 36 equations and a lane holds it to the fixture, so
the reporter needs no change and its selftest keeps working.

### The differential

`tests/prolog/suites/evaluation/prelude_spec.plt` loads the fixture's
declarations and equations into `&prelude-spec` and compares, per case, the
answer bag (as a multiset up to variable renaming), the printed output and the
raised ball. 101 ordinary cases and 15 expansion cases over all 32 heads,
including nondeterministic arguments, empty answer sets, alpha-equivalent
atoms, a variable in a type's head position, an error produced inside an
argument, and every case the other suites already carry.

Tried: comparing the eight derived forms by ANSWERS -> all eight diverge, and
correctly so. In the spec space there is no translator registration, so the
equation answers its own expansion term: `(and-then True yes)` is `(if True yes
False)` there and `yes` in the engine. Decided: a derived form is compared as
an EXPANSION, `prelude:Head(Args..., Expansion)` against the spec equation's
answer, and separately by running the spec's expansion in `&self` and requiring
the engine's rewritten answers. The second is what makes the first about
meaning rather than syntax.

Tried: `retractall(silent(_)), assertz(silent(true))` in the suite's setup, the
idiom the neighbouring suites use -> the specializer still printed `Not
specialized for-each-in-atom_Spec_[repr]/3`. `assertz/1` from a plunit unit
creates the fact in THAT unit's module. Decided: `metta_host_set_silent/1`, the
engine's own door, and the specializer's report is dropped from the compared
output anyway: it names a space's higher-order definitions and the spec space
has 36 where `&self` has none.

The engine side is collected BEFORE the spec space exists. Defining one of the
eight derived names in any space withdraws the engine's translator registration
for it, which is the design, so an engine measured afterwards is a different
engine.

### A defect the move exposed: a dead goal that desynchronised the observer

Tried: the whole engine battery -> `source_observation:exception_keeps_source_frames_and_restores_debugger`
failed, and only on this branch. The observation reported
`['source-frame-unavailable', 0, 0, 'obs-check', 'source-site-unavailable']`
where it had reported a source frame.

Localised by instrumenting `clause_shape_matches/2` inside the observation and
printing both terms: the translator emitted `D = [A, 3]` as the first goal of
the typed call branch and the stored clause had `true` there. `D` is
`typed_functioncall_dl/10`'s `RuntimeArgs`, which only the caller that reports
a call as dispatched reads; the other caller passed `_RuntimeArgs` and the goal
was emitted anyway. SWI's compiler removes a unification whose left side is a
void variable, so the emitted body and the stored body stopped being the same
term and `publish_locations/4` refused every attribution in the clause. Before
this branch `assertEqual` was an equation call, which reads `RuntimeArgs`; as a
builtin it is not.

Decided: `RuntimeArgs` becomes a REQUEST, `runtime_args(Args)` or
`no_runtime_args`, and the goal is emitted only when someone reads it. The
stored clauses are unchanged, because the goal it stops emitting is exactly the
one SWI was already removing.

Measured, and this is why the split is written inline: through a helper
predicate it cost the boot 580 inferences, through an `==/2` test 475, and as a
unification in the condition of an if-then-else 475 as well. The residual +475
is not any of the three code paths -- controls that keep the machinery and
re-emit the goal, and that inline the three rare `record_runtime_args/2` calls,
each read 248,271 -- so it is the load-structure class this repository's
benchmark ledger documents at ~142 inferences per inert fact. `translate` is 20
inferences BETTER with the fix than without it.

### Verification

`sh engine/test.sh` whole: exit 0. Two suites needed updating and both kept
their meaning: `prelude:a_user_equation_evicts_the_prelude_definition` now
asserts that `&self` holds a LOCAL definition with one clause and no import,
which is what makes the user's answer exclusive where clause eviction used to;
and `builtin_facets` asks for `prolog(prelude)` facets and checks each against
the live image.

Open: `builtin_facets`' `the_pass_removes_a_foreign_arity_and_keeps_the_described_one`
and `the_retraction_set_is_the_same_nine_on_every_build` fail when the suite is
run through a bare `swipl -g run_tests`, on this branch and on the pristine
main checkout alike. They pass through `sh engine/test.sh`, which is the gate's
own door and passes `-- extensions`; the bare invocation is the one
`engine/test.sh`'s header warns against.
