# A namespace lists what its space can call

Goal: `dir(m.fn)`, `m.builtins()` and attribute resolution on a space's
function namespace name exactly the heads that space can call, so a typo's
suggestion survives a long process and a call never resolves to a head the
space cannot reduce.

Constraint: `fun/1` stays process-wide, because the translator reads it to
decide call against data wherever a term compiles (engine/metta/registration.pl,
the note above `register_fun_in/2`), and `m.is_function(name)` keeps
answering that question.

## 2026-09-07

Found by the merged battery (merged40 on acd04732): three of the
observation-doors branch's did-you-mean tests failed under the gate's four
workers and passed alone. The traceback text had the library's sentence and
no `Did you mean`.

Tried: in one process, 800 equations in one space, then a second space
defining `dbl` -> `len(dir(second.fn))` 1,107, `zz5 in dir(second.fn)` True,
and `traceback.format_exception` of `second.fn.dbll` without the suggestion;
the second space alone lists 306 and gets `Did you mean: 'dbl'?`. CPython's
`traceback._MAX_CANDIDATE_ITEMS` is 750 (read from the installed 3.14
source): past that many candidates the interpreter offers nothing.

Tried: `other.fn.zzq` on a space that did not define `zzq` -> resolves to an
`_EngineFunction`, and `!(zzq 1)` in that space answers `(zzq 1)` unreduced.
`other.is_function("zzq")` True, `other.is_function_here("zzq")` False. So the
namespace advertised and resolved a head whose equations live in a module
the space never sees, because `metta_py_builtins/1` and
`metta_py_catalogue_member/1` read `fun/1`, which is process-wide.

Tried: what a drop leaves -> `fun(zzq)` False, `fun_in` empty, `fun_scoped`
False after `space.drop()`; only `arity(zzq, 2)` survives (the registry
finding the test-hygiene branch recorded). So the callable set needs no
orphan rule; the leak was live spaces, not dropped ones.

Decided: the catalogue a space's namespace reads is per space,
`metta_py_builtins/2` and `metta_py_catalogue_member/2`, using the engine's
own callable-from-here rule (`fun_here/1` in registration.pl) with the module
made explicit: an unscoped name answers everywhere (builtins; Python
operations, which register into `&self`; prelude rules), a scoped name
answers where `fun_here_in/2` says its clauses are visible from (its own
module, a parent it inherits from, `&self`). `Runtime.builtins(space)` and
`Space.builtins()` answer that set; `Runtime.builtins()` without a space
keeps the process-wide union for the symbol namespace's completion pool and
the lint registry's suggestion pool, which are about names rather than
calls. `_space_builtins` was already keyed by space name and answered the
same list for every key; the key means something now.

Decided: `metta_host_function_generation/1` sums the generations of `fun/1`,
`fun_in/2`, `fun_scoped/1` and `metta_exec_module_parent/2`, because a
second space defining an already-registered name asserts `fun_in/2` and
leaves `fun/1` alone, and a cache stamped by `fun/1` alone would go on
answering the old set for that space. Plunit
`a_second_home_for_a_registered_name_bumps_the_generation` pins it; the
eleven existing generation tests still pass (`register_fun/1` twice bumps
once; translator rules stay neutral).

Rejected: capping the directory at 750 names, because the list would then be
wrong in a different way and `dir()` would depend on registration order.
Rejected: making `is_function` per space, because it mirrors the
translator's compile-time decision and `is_function_here` already asks the
per-space question; the docstrings and `llms.txt` now say which is which.

Also fixed from the same battery: `test_the_testing_module_names_both_suites_without_importing_them`
asserted `metta._compliance` absent from `sys.modules` in a process where
any earlier compliance test had imported it, so it was a coin toss under a
shuffled order; it asks a fresh interpreter now. The callback facade's owner
table gained `engine_message` (`_engine`), which the observation-doors
branch added to `metta._callbacks.__all__` without running ch01.
`examples/ORIGINS.tsv` is regenerated for the assertion example (130
original). The LeaTTa-removal journal quoted a `git grep` for the home
prefix with the literal in it, which the widened workspace-path scan then
flagged; the sentence names the prefix without spelling it.
