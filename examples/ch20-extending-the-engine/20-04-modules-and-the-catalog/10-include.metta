;`include` is `import!`'s other half, and the difference is where the atoms
;land. `import!` gives a module its own space and answers the unit; `include`
;PASTES the module's forms into the space that included it, and answers what
;the module's LAST directive answered.
;
;It is upstream PeTTa's one gap here: that engine has no `include`, so
;everything below is this engine's own reading rather than an arbiter's.

;The module defines a function, states a fact, and ends in a runnable.
;Including it answers that runnable's answer.
!(test (include _fixtures/included/rows) 42)

;And the function and the fact are in THIS space now, not in a module space
;the caller has to name.
!(test (included-double 5) 10)
!(test (collapse (match &self (included-fact $x) $x)) (carried))

;Which is the whole difference from `import!`: that door answers the unit and
;the module's atoms are reachable through the space it made, and this one
;answers a value and the atoms are simply here.
!(test (import! &self _fixtures/included/rows) True)

;A module with no directive has no last answer, so the include answers
;nothing at all rather than a unit standing in for one. Its facts still land.
!(test (collapse (include _fixtures/included/silent)) ())
!(test (collapse (match &self (silent-fact $x) $x)) (here))

;A name that resolves to nothing is refused by name, and so are the two
;module-path BASES: `self` and `top` name directories rather than modules, so
;including one is a category error rather than a missing file.
!(test (collapse (catch (include nosuchmodule)))
       ((Error (include nosuchmodule) "no module named nosuchmodule is available")))
!(test (collapse (catch (include self)))
       ((Error (include self) "include: the running context is not a module")))
!(test (collapse (catch (include top)))
       ((Error (include top) "include: the running context is not a module")))
