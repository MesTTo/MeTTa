<!-- Purpose: record the re-run of every engine-defect reproduction on trunk, which findings still showed the defect, and what the two repairs on this branch decided. -->
# The defect ledger closed
Goal: re-run every reproduction and control in `ai-engine-defects.md` on trunk,
show each regression a repair added failing at the baseline it was measured
against and passing now, and repair whatever still reproduces.
Constraint: the baseline the programme measured against, `cd894c33`, is 682
commits behind `761fd85b`, so a reproduction may have moved, a repair may
predate the baseline, and a defect may have been born and died inside the
window. Each of those is attributed rather than edited away.

## 2026-09-07

Tried: the whole ledger, 46 numbered findings, each reproduction re-run on a
worktree cut from `petta` at `761fd85b` and each regression run at `cd894c33`.
Result: 42 findings answer correctly on trunk, two still show the defect, and
two of the reproductions could not be shown red at `cd894c33` because their
repair landed BEFORE it.

Decided: `cd894c33` is not the red side for every row, and saying so is part of
the record. Findings 1 and 2 were repaired by `d1318d20`, an ancestor of
`cd894c33`, so their regressions PASS there and their red side is
`12771f41`, the pre-change tree `ai-engine-defect-1-fix.md` names. Measured:
`translator_rule_module_home` is 6/6 green at `12771f41` only for the three
tests that came later, and its first three fail there with
`Unknown procedure: '$metta_exec:&plunit-tr-cross-other':'plunit-tr-cross-pick'/6`,
the ledger's own message. At `cd894c33` those three pass and the three that
findings 10 and 22 added fail.

Tried: finding 46's 149x bulk-load reproduction at `cd894c33` ->
`restore of 40 equations, no reaction 20006, one unrelated reaction 21539,
ratio 1.08x`. The 149x is not there. The defect was introduced after the
baseline, by the commit that gave the engine its own `seam:atom_added/2`
clause, and repaired by `e7d26c51` before trunk. Recorded rather than forced:
a row whose red side is inside the window names the window, not the baseline.

Tried: finding 3's reproduction, `(= (if-equal $a $b) SHADOWED)` then
`!(if-equal 1 1)`, on trunk. It still reproduces, exactly as filed:
`SHADOWED` through `sh tools/run.sh`, and
`(Error (if-equal 1 1) IncorrectNumberOfArguments)` through `MeTTa().run`.
The ledger predicted it would close with finding 2 and it did not: finding 2's
repair widened the prelude TRANSLATOR-RULE eviction to every module, and this
is the DECLARATION tier.

Measured, the discriminating experiment: in one process, run the named space
FIRST and `get-type if-equal` answers the prelude's four-input arrow both
before and after the named-space definition, and the call refuses. Run `&self`
first, and its definition evicts `prelude_type_declaration/2` globally; a
named space's identical definition then answers `SHADOWED2`. So the surviving
prelude DECLARATION is the whole cause, and eviction is the whole difference
between the two doors
(`ai-tmp/dl-repro/dl_f03_gettype2.pl`, both orders, fresh processes).

Rejected: widening `evict_prelude_definition/1` to fire from any module.
Eviction is global and one-way, so a named space defining `union` would take
the engine's `union` away from `&self` and from every sibling space. `&self`
may do it because the prelude IS its tier.

Decided: a named module SHADOWS the prelude declaration instead, keyed on the
fact the engine already uses for exactly this question. `runtime_guarded_builtin_call/1`
requires `\+ fun_in(Module, Fun)` before it will use a builtin's own guard
(`engine/translator/special_forms.pl:273-278`), and `engine/prelude.metta`
promises a prelude name is "shadowable per named space exactly as builtins
are". `prelude_declaration_governs_in/2` asks that same question of the
prelude's declaration tier, in `definition_type_declaration_in/3` and its raw
form, so every reader of a definition's declarations agrees; and
`governing_type_chains_in/4`'s `fun_in` branch, which read the prelude's rows
back in one line after they had been excluded, now selects nothing, which is
what a module-owned name with no stored declaration of its own governs by.
All four rows of the ledger's table now agree between the two doors, and
`&self` still answers `(if-equal 1 1 yes no)` -> `yes`, which is the control.

Tried: the `no-autoload` GATE, which finding 39 repaired and which nothing had
re-run on trunk. Red, on
`examples/ch18-performance/18-02-memoisation-and-tabling/16-cache_policy_restraints.metta`,
with `Unknown procedure: call_delays/2`. `lib_tabling` reads a restrained
table's delay condition through `call_delays/2`, which is `library(wfs)`'s and
which the library-index autoloader had been finding. The branch carrying
`95016842` reached the same conclusion independently and measures the two
spellings; whichever copy merges second is redundant.

Tried: the general form, because the engine's own `prolog` lane already asks
this question with the autoloader off and its comment says why -- "with
autoload on, such a name resolves at the first call and the check says
nothing" -- and it consults `engine/main.pl`, which `import!` means never
reaches `lib/`. Consulting every `lib/*/*.pl` under the same flag and running
`list_undefined` answers in 2.1 seconds and reported FOUR names: the two that
are deferred by design, `source_observation:observe_source/4` (lib_observe
loads the observer on demand) and `py_call/2` (janus's, guarded by
`current_predicate/1` at every site), and two live defects.

The second live one is the argument for the lane. `lib_crypto`'s
`crypto_random_hex/2` calls `hex_bytes/2`, which is `library(crypto)`'s and
which its `metta_platform_load/2` import list did not name. No example calls
it, so the corpus lane could never have found it. Measured:
`NO_AUTOLOAD=1 sh tools/run.sh` over `!(println! (crypto-random-hex 4))` exits 2
with `Unknown procedure: hex_bytes/2` on a platform that HAS crypto, and 0
answering `"0e2530a2"` with the name on the list.

Tried: `sh tools/check.sh prolog` on a pristine `761fd85b`. Already red, third
instance of the same class: `engine/spaces/catalog.pl:763` calls
`pairs_keys_values/3` and the `spaces` module imports no `library(pairs)`.
`engine/source_observation.pl:30-37` carries a comment recording the same name
failing the same way in September. Declared, and the lane is green.

Decided: `lib-autoload` is a GATE beside `prolog` rather than a REPORT. Its
backlog is empty after the two repairs, and a lane at zero findings has to
prove it can still see, so the driver plants a call to the first library export
this tree does not import and refuses if the walk misses it. Control, both
directions: with both declarations removed it exits 1 naming
`user:call_delays/2 lib/lib_tabling/lib_tabling.pl:1180` and
`user:hex_bytes/2 lib/lib_crypto/lib_crypto.pl:64`; restored, it exits 0.

Open: finding 24's half B, an inherited caller not seeing the child's shadow,
still reproduces on trunk (`(pick)=[mine]`, `(top)=[base]`, and the same
program in one space answering `[base, mine]` for both). The engine names the
mechanism and its own deferred repair at `engine/translator/runtime.pl:562-573`
-- SWI hands a `module_transparent` predicate Logtalk's `This` where a space
context is `Self` -- and calls the fix P11.7, which appears in no ledger. That
is a calling-convention change across every compiled clause, not this thread's.

Open: finding 15's derivation effects are deliberate and now documented, with
`speculative` as the fence; finding 9's WASM stack-limit message is unchanged
and its ~33 MB ceiling is still unattributed; finding 37 leaves 2,542 boot
inferences unattributed to a mechanism.

Corrected count, appended after the sweep finished rather than edited into the
opening paragraph above, which was written before every row had a verdict.
Three outcomes were rounded into two there. Counted row by row: **40 closed**
(the reproduction answers correctly and the regression is red at the tree it
was measured against and green now); **2 closed as a decision** rather than a
code change, findings 15 and 23; **1 repaired here**, finding 3; and **3 open**
-- finding 9 (the WASM stack-limit message, unchanged, its ceiling still
unattributed), finding 24 half B, and finding 37's 2,542-inference residue,
which cannot be re-measured against its pin today because `engine-bench`
refuses on a `prelude.metta` configuration drift that predates this branch.
40 + 2 + 1 + 3 = 46.
