;The compiler does not emit every type check it could. A literal whose type is
;settled at compile time has its check DROPPED, an argument a caller's
;declaration already proved has it DISCHARGED, a Number parameter has the
;registry walk replaced by one VM instruction, and a metatype parameter has it
;replaced by the metatype ladder. Each is a claim that the check it removed
;could not have failed.
;
;(pragma! verify-discharges true) stops trusting those claims. The fast side
;still decides, so the program answers exactly what it answered; the check it
;replaced runs beside it, and a disagreement is raised instead of absorbed.
;That is translation validation, the discipline the specialization verifier
;already applies to specializations.
;
;The pragma has to come FIRST, because the emitted half is chosen while the
;code is being compiled and a clause compiled without it carries no trace.
!(pragma! verify-discharges true)

;An intrinsic discharge: Number compiles to a VM test with the registry walk as
;its fallback, and under the pragma the walk runs beside the test.
(: vd-double (-> Number Number))
(= (vd-double $x) (* $x 2))
!(test (vd-double 21) 42)

;A literal discharge: the argument's type is settled while the call site is
;compiled, so the check is normally dropped entirely. Under the pragma it comes
;back with `true` as its fast side, which is what a dropped check becomes.
!(test (vd-double 1.5) 3.0)

;A metatype discharge, which is the one that is NOT emitted: it lives inside
;the check itself and reads a runtime marker, so it audits code that was
;already compiled.
(: vd-name (-> Symbol %Undefined%))
(= (vd-name $x) $x)
!(test (vd-name orange) orange)
;The refusal names the argument AS WRITTEN, not the value it evaluated to,
;because the metatype parameter is checked on the written form before the
;argument runs. That is the applicability check, and it is why an Expression
;parameter can refuse `(+ 1 2)` while a Number one accepts what it answers.
!(test (vd-name (+ 1 2))
       (Error (vd-name (+ 1 2)) (BadArgType 1 Symbol Number)))

;A refusal still refuses, and it refuses for the same reason it did before: the
;audit changes which checks RUN, never which values are admitted.
!(test (vd-double "not a number")
       (Error (vd-double "not a number") (BadArgType 1 Number String)))

;And the mode turns off, leaving the engine as it found it.
!(pragma! verify-discharges false)
!(test (vd-double 4) 8)
