<!-- Purpose: record why the arity-retraction pass stopped asking built_in, what the three builds measured, and what was rejected. -->
# A namesake the build decides
Goal: an arity that belongs to a namesake predicate rather than to the
operation is removed on every build the engine runs on.
Constraint: the nine arities removed natively keep being removed; a predicate
this tree defines is never removed; a name the engine describes in neither half
of its description is not judged at all.

## 2026-09-06
Tried: reproducing the reported Node failure -> `cd extensions/node && npm test`
reads 44 failures over 621 collected tests, every one a `beforeEach` hook
raising `the engine reported 2 error(s) while booting ... Unknown error term:
unregistered_builtin_spec(sleep/0)`. The seat refuses an unnamed boot error by
contract, so one refusal takes every suite that boots.

Tried: asking the wasm engine itself, instead of the two mechanisms the report
suggested. Neither is involved. The platform census reads
`[concurrency, deadlines, subprocess, redis, crypto]` there and says nothing
about sleep; the type surface loads with 240 rows, and
`seam:builtin_type_declaration(sleep, [->, 'Number', 'Bool'])` is one of them,
so `declared_metta_arity(sleep, 2)` answers exactly as it does natively. What
differs is one property:

    sleep/1 built_in=no impl=wasm imported_from=wasm file=/swipl/library/wasm.pl

Found: swipl-wasm 8.0.6 defines `sleep/1` in `library(wasm)`, its JavaScript
interop library, as an ordinary module predicate. `unrelated_system_predicate/2`
opened with `predicate_property(Engine:Head, built_in)`, which is true of native
SWI's C-defined `sleep/1` and false of the wasm build's Prolog one, so the pass
removed `arity(sleep, 1)` natively and kept it there. `built_in` is a property
of the BUILD, not of the collision, and the branch that landed the registration
coverage check turned that latent difference into a boot refusal: MeTTa arity
`1 - 1 = 0`, and no facet describes `sleep/0`.

Tried: the whole picture on both builds, every `arity/2` row at a type-declared
name whose declaration does not claim it, with the four properties the pass
could key on. Native has 24 such rows, wasm 27. The two lists agree except for
`foldl/5,6,7`, which wasm's `library(apply)` defines and native's does not, and
`sleep/1`. Fifteen of the native rows are `built_in=plain` and every one of them
must be KEPT: `append/2` and `member/2` from `library(lists)`, `maplist/2,4,5`
and `include/3` from `library(apply)`, and nine this tree defines.

Rejected: "an arity is the operation's own when this tree defines the
predicate". It is the obvious replacement for `built_in` and it is wrong:
`library(lists)`'s `append/2` IS MeTTa's `append` and no file here defines it,
so the rule would have dropped six live library-backed builtins. Caught by
measuring the 24 rows before writing the rule rather than after.

Decided: ask the operation's own description, which this tree now has in two
independent halves. An implementation facet keyed by MeTTa arity claims the
Prolog predicate one argument wider; an arrow declaration of N links claims
Prolog arity N. Either one claiming an arity keeps it, a file in this tree
defining the predicate keeps it, and a name with neither half is not judged.
Checked row by row against both lists: every one of the 24 native and 27 wasm
rows is classified the same way, and the native retraction set is byte-identical
to what `built_in` removed.

Measured, the pass's output on three images, `forall(builtin_fun(N),
register_prolog_arities(N))` first so the question is the one the pass sees at
boot:

| image | removed |
|---|---|
| native SWI 10, `swipl -g` | `append/1 assert/1 copy_term/3 copy_term/4 not/1 sleep/1 sort/4 term_hash/4 throw/1` |
| swipl-wasm 8.0.6, inside the engine the Node seat boots | the same nine |
| native plus `extensions/cmetta/bridge.pl` | the same nine |

Found while checking: the file's own comment named the removed set as nine
including `exists_file/1` and excluding `throw/1`. `exists_file/1` is the
ENGINE's, in `engine/metta/runtime.pl`, and has been kept all along; `throw/1`
is SWI's and has been removed all along. The comment was wrong in both
directions and is corrected with the measured set.

Tried: the same question in the Python seat's own image, janus and `shim.pl`
and `extensions/python/bridge.pl` all loaded -> 18 rows the declaration does not
claim, every one of them either facet-described (`foldl`, `append`, `member`,
`maplist`, `include`) or defined by this tree (`reduce`, `git-import!`,
`random-int`, `random-float`, `library`, `exists_file`, `py-call`), and zero
foreign undescribed rows. The C seat's image gives the same nine as native. So
the class is empty on all three seats and the fix is not specific to the one
that failed.

Decided: keep `\+ declared_metta_arity/2` and `\+ builtin_tree_defined_arity/2`
even though no row on any of the three images is kept by them alone. Each is a
statement the engine makes about itself that the facet table does not subsume,
and an arity one of them claims with no facet behind it has to REACH
`validate_builtin_registration_coverage/0` as drift rather than be silently
dropped here. They cost nothing: the facet lookup answers first for every row
that survives.

Measured: `bench_run(boot)` 265,390 against trunk's 265,924, five samples per
arm with the `.qlf` set purged and warmed, so the new rule is 534 inferences
CHEAPER. It replaces a `predicate_property/2` probe on every candidate with a
first-argument-indexed `builtin_implementation/2` lookup that succeeds early for
almost all of them. parse, parse-prolog, translate, match, match-skew and
evaluate are byte identical to trunk's across three samples each.

Rejected: moving `finalize_builtin_implementations/0` ahead of the pass so the
prelude and extension facets exist when it runs. It would let the guard be the
facet table alone, but the extension half of that derivation reads `arity/2`,
which is the very table the pass is about to correct, and ordering a derivation
before the correction it depends on is the shape this file's own comment already
records going wrong once. Reading both halves of the description costs one
indexed lookup and has no ordering to get wrong. Revisit if prelude facets ever
need to exist before the arity registry settles.

Open: the pass still runs once, so a host or backend that registers a builtin
name AFTER the boot chain is not swept. That limitation predates this change and
the file records it; nothing in the tree does it today.
