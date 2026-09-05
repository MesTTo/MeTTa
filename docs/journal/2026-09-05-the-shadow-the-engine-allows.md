# The shadow the engine allows
Goal: settle the backlog row asking for a lint rule on reimplementing shipped
stdlib operations in user rules.
Constraint: do not warn about a capability the engine offers deliberately
without saying that is what it is.

## 2026-09-05

Tried: the row's own case. `(= (car-atom $x) shadowed)` is REFUSED, by name:
"car-atom with 1 arguments is one of Prolog's protected core predicates, which
no space can redefine". So the dangerous half of the row is already handled, and
the refusal even documents the other half: "every other builtin name is free: an
equation for one compiles into this space's own module and shadows it there,
leaving the engine's and every other space's alone".

Tried: the free half. `!(max-atom (1 5 3))` answers `5`, and after
`(= (max-atom $x) shadowed)` it answers `shadowed`, with no finding. That is the
gap: lawful, scoped, and silent.

Rejected: a `predicate_property(Module:Head, imported_from(_))` probe, which I
built and confirmed works -- a shipped name reads `imported(user)` in a space's
module and becomes `local` once shadowed, while a genuinely new name is `local`
without ever being in `user`. It was a second implementation of a distinction
the engine already publishes.

Decided: `builtin_fun/1`, which is the engine's own answer. Its comment at
`engine/metta/registration.pl:596-607` states the split: "A builtin is visible
from every space, and stays visible when a named space defines its name.
`fun_in/2` cannot carry that ... which is exactly the test
`runtime_guarded_builtin_call/1` uses to decide a builtin was overridden. One
fact for each meaning, so neither reading breaks the other." `fun/1` cannot
serve, because it enumerates user functions too: defining one takes the count
from 298 to 299.

Decided: warning severity, and the sibling framing. `interpreter-equation-shadow`
already reports the same act over a translator-owned head, so this is that rule
for the engine's heads, with the same weight and the same "lawful, and reported
rather than blocked" test.

Found while adding it: `test_registry_queries_are_native_and_cached_per_name`
matched its goals by SUBSTRING, and `builtin_fun(F)` contains `fun(F)`, so the
engine's two separate questions counted as one. The matcher now compares whole
goals, which is what it meant, and would have hidden a duplicate `fun/1` query
behind the builtin one.

Proven to discriminate by unwiring the rule: `assert [] == ['max-atom']`.

Evidence: 3,033 Python tests pass, against 3,031 before.
