# Exec modules never autoload
Goal: a MeTTa name that is not yet defined in a space's module is answered by
the engine, never by SWI's library index, whatever the host has installed.
Constraint: module `user` is where a host's own goals run and keeps autoload;
libraries make modules of their own (plunit's units) that resolve names
through the index; the engine's own modules already run without index-driven
autoload (engine/check.sh `prolog`, `lib-autoload` and `no-autoload` lanes).

## 2026-09-16
Found by: examples/operations/concurrency_handles.py and the `prolog-static`
lane dying on `X_GLXCreateContext BadValue` the day this box's GLX broke
(`glxinfo -B` fails the same way), on the clean committed tree 55c26fe6b as
well as the working tree (docs/journal/2026-09-16-reclamation-counts.md).

Tried: `set_prolog_flag(verbose_autoload, true)` inside the example ->
`autoloading '$metta_exec:&pyspace_1':send/3 from
/usr/lib/swi-prolog/xpce/prolog/lib/pce`, then `pce_principal:member/2`,
`unlock_predicate/1`, then the X error. The channel door calls the MeTTa
function `send` in the owner's module before its lib_thread face stands;
boot/init.pl's `'$undefined_procedure'/4` asks `user:exception/3` first and
the library index only when no clause answers; the engine's clauses
(engine/spaces/foreign.pl for deferred definitions, engine/metta/references.pl
for reference demands) do not claim `send`, so xpce's `send/3` is imported
into the space's module and loading xpce opens the display. Any name a
library exports at the compiled arity (`last`, `sum_list`, `append`, ...) is
open to the same capture, and a later MeTTa definition of that name then
collides with the import.

Tried: `set_prolog_flag(autoload, user_or_explicit)` at engine boot (explicit
`:- autoload/1,2` declarations everywhere, index-driven autoload in module
`user` only) -> the example passed the xpce point and met
`spaces:metta_space_release_plan/2: Unknown procedure: ugraphs:append/2`
(library(ugraphs) declares only `append/3` and `top_sort/2` calls `append/2`,
ugraphs.pl:460, swipl-devel master identical); importing `lists:append/2`
into `ugraphs` cured that, and then the spaces plunit suite failed to load:
`plunit_spaces_cycles:end_tests/1: Unknown procedure`, because plunit's
generated unit modules resolve plunit's own `end_tests/1` through the index.
Rejected: the flag, at either value, because every module a library makes
for itself inherits the restriction; the process-wide dial is the wrong
grain. Revisit if SWI gains a per-module autoload switch.
Rejected: a per-name guard in the translator (`current_predicate/1` before an
emitted call), because the capture is in SWI's undefined-procedure path,
which every route into a module shares: a host goal, a hook, a plain Prolog
call.

Decided: `refuse_autoload_into_exec_modules/0` in engine/spaces/lifecycle.pl,
run from the engine's boot initialization after `protect_metta_exec_modules/0`:
it asserts `user:exception(undefined_predicate, Module:_, error) :-
spaces:metta_exec_module_known(_, Module)` once, so the clause stands last
among the hook's clauses, after the engine's `retry` clauses, and answers
`error` for every exec module: the existence error the name would have raised
had no library carried it, and no import; the flag stays `true`. Control:
spaces:an_undefined_function_named_like_a_library_export_is_not_autoloaded, a
direct call of `base32/2` in a space's module (indexed, imported by no engine
module, harmless if it ran) is an existence error and imports nothing. The
live control today: the channel example and the `prolog-static` lane pass
with `DISPLAY=:0` while `glxinfo -B` fails.

Verified: spaces plunit 220; the whole Python suite in a battery worktree,
6877 passed, no existence error anywhere in its log (the hook's only
observable), the nine failures accounted for elsewhere
(2026-09-16-reclamation-counts.md and the handoff); engine lanes prolog and
plunit; lib-autoload and no-autoload after engine/host_transactions.pl
declared the foldl/4 and reverse/2 it reached through the index (37d417bd0
left them undeclared; the no-autoload corpus died at
07-05-recursion/04-fibsmartimport.metta on `host_transactions:reverse/2`).

Found: the `prolog-static` lane still dies on X_GLXCreateContext with
DISPLAY set, and that one is not an exec module: SWI's library(check) walk
("Checking predicate options lists") autoloads
`pce_swi_hooks:pce_show_profile/0` from xpce's `swi/pce_profile`, the
profiler hook library(prolog_profile) references, so xpce initialises the
display from inside SWI's own checker. The lane passes with DISPLAY unset,
and structurally on a host built without xpce, which the host-patch track's
~/Dev/swipl-patched is (`-DSWIPL_PACKAGES_X=OFF`).

Found (the `no-autoload` corpus gate, run further than before once
host_transactions declared its names): examples/ch20-extending-the-engine/
20-03-prolog-underneath/05-the-module-doors.metta dies on
`ugraphs:append/2` under `NO_AUTOLOAD=1`, on the landed tree as well as with
the hook. That is the same ugraphs gap the flag experiment met, live in the
engine's own configuration whenever a release plan calls `top_sort/2`, so it
is a host workaround after all: `import_ugraphs_implicit_dependency/0` at
boot, ledger entry `swi-ugraphs-implicit-append`, its reproduction with
autoload off; the host-patch track adds `append/2` to ugraphs' declaration
in the patched SWI and flips the entry.

Open: whether any shipped MeTTa library's compiled code relied on autoload
INTO exec modules for a lists or apply predicate beyond what the batteries
reached; the cure is an import into the engine module.
