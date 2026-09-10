; Purpose: compare include's last directive with import!'s Boolean result.
; [tested: examples/ch20-extending-the-engine/20-04-modules-and-the-catalog/10-include.metta; commit=WORKTREE].
;
; `import!` merges a module into its named receiving space and answers True.
; `include` pastes its forms in order into the current space and answers what
; its last directive answered. Both put the definitions in their receiver.
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

; Importing into &self also puts the atoms here, but reports load success.
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
