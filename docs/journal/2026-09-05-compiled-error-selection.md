# Error selection beneath structural assignment

Goal: avoid destructuring an error before a compiled try handler can receive it.

## 2026-09-05

Tried: `(if-error (Error source reason) picked (empty))` and
`(if-error ordinary (empty) picked)` both answered nothing. The current
undeclared operation evaluates both arguments before selecting its result.
A compiled structural binding therefore lost its error path when its ordinary
branch attempted to unpack the Error value as a pair.

Tried: a space-local `(: if-error (-> Atom Atom Atom %Undefined%))`, matching
the declaration in `MettaHyperonFull/Minimal/Stdlib.lean`'s `if-error` definition.
The unused branch stayed inert, but the selected `(+ 1 2)` also remained data.
The arithmetic subject `(+ 1 "bad")` remained written and selected the ordinary
arm. Existing `examples/ch10-errors-and-refusals/01-he_error.metta` requires
that subject's evaluated Error instead.

Tried: `%Undefined% Atom Atom %Undefined%` retained subject evaluation but
still returned the selected branch unrun. Nested `eval` wrappers around the
written call retained its returned expression; binding its result and then
calling `eval` on that result evaluated it to 3.

Rejected: adding either signature as a compiler bug fix. It changes the existing
operation's subject or result behavior and does not implement execution of a
selected Python block. Revisit only with an explicit decision to change that
operation's native and reflected semantics together.

Decided: use existing `case` for the compiler's lazy block selection, leaving
`if-error` unchanged. `(case $held (((Error ...) (throw $held)) ($_ $body)))`
classifies every Error-headed expression and runs only its selected arm.
A fixed `(Error $source $reason)` pattern would miss empty, one-element, and
extended payloads. Direct probes of all four widths selected the error arm;
an ordinary symbol selected the ordinary arm.

Verified: `test_error_case_selection.py` uses public term builders to check
all four error widths with an unused `(empty)` branch and one ordinary value
whose selected arithmetic branch evaluates. Five tests pass. The parent
compiler regression checks the complete structural-assignment try path.
